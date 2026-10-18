-- RollService (Script in ServerScriptService)
-- The "brain" of rolling: picks auras, stores inventories, saves data,
-- checks game passes, sells luck boosts and tells everyone about rare rolls.
-- Everything important happens here so exploiters can't fake rolls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))
local Luck = require(ReplicatedStorage:WaitForChild("Luck"))
local Rebirth = require(ReplicatedStorage:WaitForChild("Rebirth"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local QuestData = require(ReplicatedStorage:WaitForChild("QuestData"))

---------------------------------------------------------------------
-- Remotes (created here so you don't have to make them by hand)
---------------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("CosmicRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "CosmicRemotes"
	remotes.Parent = ReplicatedStorage
end

local function getRemote(className, name)
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local RollRemote = getRemote("RemoteFunction", "Roll")
local GetDataRemote = getRemote("RemoteFunction", "GetData")
local EquipRemote = getRemote("RemoteEvent", "Equip")
local DataUpdatedRemote = getRemote("RemoteEvent", "DataUpdated")
local AnnounceRemote = getRemote("RemoteEvent", "Announce")
local RollFXRemote = getRemote("RemoteEvent", "RollFX") -- server -> everyone: show roll effects
local RevealRemote = getRemote("RemoteEvent", "Reveal") -- roller -> server: "my reveal animation finished"
local RebirthRemote = getRemote("RemoteFunction", "Rebirth") -- player asks to rebirth
local HatchRemote = getRemote("RemoteFunction", "HatchEgg") -- player hatches an egg
local PetRemote = getRemote("RemoteFunction", "PetAction") -- equip / unequip pets
local QuestRemote = getRemote("RemoteFunction", "Quest") -- daily reward + quests
local QuestUpdatedRemote = getRemote("RemoteEvent", "QuestUpdated") -- server -> player: quest progress
local SaveSettingsRemote = getRemote("RemoteEvent", "SaveSettings") -- player's sound settings

---------------------------------------------------------------------
-- Data saving
---------------------------------------------------------------------
local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[CosmicRNG] DataStore unavailable, progress will not save:", result)
	end
end

local sessions = {} -- [player] = data table
local canSave = {} -- [player] = true only if loading worked
local lastRollTime = {} -- [player] = os.clock()
local pendingReveal = {} -- [player] = aura name waiting to be shown to everyone
local rng = Random.new()

local function newData()
	return {
		Version = 1,
		Rolls = 0,
		Inventory = {}, -- [auraName] = how many you've rolled
		Equipped = "",
		BestChance = 0,
		PersonalLuckEnd = 0, -- potion end time (seconds since 1970)
		DuelWins = 0, -- player-vs-player duel wins
		Rebirths = 0,
		RebirthRolls = 0, -- rolls since your last rebirth
		RebirthBest = 0, -- rarest aura (chance) rolled since your last rebirth
		Pets = {}, -- [petName] = how many you own
		EquippedPets = {}, -- list of pet names (max PetData.MaxEquipped)
		BoostRolls = 0, -- Cosmic Rolls waiting (x50 luck on the next roll)
		PermanentLuck = 1, -- from the Limited Offer
		LimitedBought = "", -- which Limited Offer pack this player bought
		Daily = { Streak = 0, LastClaimDay = -1 }, -- daily login reward
		Quests = { Day = -1, List = {}, Bonus = false }, -- today's quests
		Settings = { Music = 1, Sfx = 1, Muted = false }, -- sound sliders
		Receipts = {}, -- recent purchase IDs, so nothing is granted twice
	}
end

local function keyFor(player)
	return "Player_" .. player.UserId
end

local function loadData(player)
	if not store then
		return newData(), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			local data = newData()
			if type(result) == "table" then
				for key, value in pairs(result) do
					data[key] = value
				end
			end
			return data, true
		end
		warn(("[CosmicRNG] Load failed for %s (attempt %d): %s"):format(player.Name, attempt, tostring(result)))
		task.wait(attempt)
	end
	-- Loading failed: play without saving so we never wipe real progress.
	return newData(), false
end

local function saveData(player)
	local data = sessions[player]
	if not store or not data or not canSave[player] then
		return false
	end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:SetAsync(keyFor(player), data, { player.UserId })
		end)
		if ok then
			return true
		end
		warn(("[CosmicRNG] Save failed for %s (attempt %d): %s"):format(player.Name, attempt, tostring(err)))
		task.wait(attempt)
	end
	return false
end

---------------------------------------------------------------------
-- Game passes
---------------------------------------------------------------------
local passIdToKey = {}
for key, id in pairs(Config.GamePasses) do
	if id ~= 0 then
		passIdToKey[id] = key
	end
end

local function checkPass(player, key)
	local id = Config.GamePasses[key]
	if not id or id == 0 then
		return RunService:IsStudio() and Config.FreePassesInStudio
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	return ok and owns or false
end

local function hasPass(player, key)
	return player:GetAttribute("Pass_" .. key) == true
end

-- Things a pass gives that you can also earn by rebirthing
local function rebirthGrants(player, key)
	if key == "AutoRoll" then
		return Rebirth.HasPerk(player:GetAttribute("Rebirths") or 0, "Free Auto Roll")
	end
	return false
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local key = passIdToKey[passId]
	if purchased and key then
		player:SetAttribute("Pass_" .. key, true)
		player:SetAttribute("Owns_" .. key, true)
	end
end)

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function snapshot(data)
	return {
		Rolls = data.Rolls,
		Inventory = data.Inventory,
		Equipped = data.Equipped,
		BestChance = data.BestChance,
		Pets = data.Pets,
		EquippedPets = data.EquippedPets,
		Settings = data.Settings,
	}
end

local function applyAuraToCharacter(player)
	local data = sessions[player]
	local character = player.Character
	if data and character then
		character:SetAttribute("Aura", data.Equipped ~= "" and data.Equipped or nil)
	end
end

local function refreshStats(player)
	local data = sessions[player]
	if not data then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Rolls.Value = data.Rolls
		stats.Aura.Value = data.Equipped ~= "" and data.Equipped or "-"
		stats.Wins.Value = data.DuelWins or 0
		stats.Rebirths.Value = data.Rebirths or 0
	end
	player:SetAttribute("Rolls", data.Rolls)
	player:SetAttribute("Rebirths", data.Rebirths or 0)
	player:SetAttribute("RebirthRolls", data.RebirthRolls or 0)
	player:SetAttribute("RebirthBest", data.RebirthBest or 0)
	player:SetAttribute("PetLuck", PetData.LuckFrom(data.EquippedPets))
	player:SetAttribute("EquippedPets", table.concat(data.EquippedPets or {}, ","))
	player:SetAttribute("BoostRolls", data.BoostRolls or 0)
	player:SetAttribute("PermanentLuck", data.PermanentLuck or 1)
	player:SetAttribute("LimitedBought", data.LimitedBought or "")
	-- perks that unlock passes
	for key in pairs(Config.GamePasses) do
		if rebirthGrants(player, key) and not player:GetAttribute("Pass_" .. key) then
			player:SetAttribute("Pass_" .. key, true)
		end
	end
	player:SetAttribute("EquippedAura", data.Equipped)
	player:SetAttribute("BestChance", data.BestChance)
end

-- quests are filled in further down (rolling, hatching... report progress)
local addQuestProgress = function(_player, _kind, _amount, _extra) end

---------------------------------------------------------------------
-- Rolling
---------------------------------------------------------------------
RollRemote.OnServerInvoke = function(player)
	local data = sessions[player]
	if not data then
		return { Error = "Loading" }
	end
	if player:GetAttribute("InDuel") then
		return { Error = "InDuel" }
	end

	local cooldown = hasPass(player, "QuickRoll") and Config.QuickRollCooldown or Config.RollCooldown
	cooldown *= Rebirth.CooldownScale(data.Rebirths or 0)
	local now = os.clock()
	-- small grace window for network jitter
	if now - (lastRollTime[player] or 0) < cooldown - 0.1 then
		return { Error = "Cooldown" }
	end
	lastRollTime[player] = now

	local rollNumber = data.Rolls + 1
	local lucky = rollNumber % Luck.LuckyEvery(player) == 0
	local luck = Luck.Get(player) * (lucky and Config.LuckyRollMultiplier or 1)
	-- a Cosmic Roll (from the Cosmic Drop) is used up by this roll
	local boosted = (data.BoostRolls or 0) > 0
	if boosted then
		data.BoostRolls -= 1
	end
	local count = hasPass(player, "MultiRoll") and Config.MultiRollCount or 1

	local results = {}
	local best
	for _ = 1, count do
		local aura = AuraData.RollRandom(luck, rng)
		table.insert(results, aura.Name)
		data.Inventory[aura.Name] = (data.Inventory[aura.Name] or 0) + 1
		if not best or aura.Chance > best.Chance then
			best = aura
		end
		if aura.Chance >= Config.AnnounceAtChance then
			AnnounceRemote:FireAllClients({
				Type = "Roll",
				PlayerName = player.DisplayName,
				UserId = player.UserId,
				Aura = aura.Name,
			})
		end
	end
	-- Best result first, the rest sorted rarest first
	table.sort(results, function(a, b)
		return AuraData.Get(a).Chance > AuraData.Get(b).Chance
	end)

	data.Rolls = rollNumber
	data.RebirthRolls = (data.RebirthRolls or 0) + 1
	if best.Chance > (data.RebirthBest or 0) then
		data.RebirthBest = best.Chance
	end
	local isNewBest = best.Chance > data.BestChance
	if isNewBest then
		data.BestChance = best.Chance
	end
	refreshStats(player)

	-- quest progress
	addQuestProgress(player, "Rolls", 1)
	if player:GetAttribute("OnLuckyIsland") or player:GetAttribute("OnRebirthIsland") then
		addQuestProgress(player, "LuckyRolls", 1)
	end
	for _, name in ipairs(results) do
		addQuestProgress(player, "Rarity", 1, AuraData.Get(name).Chance)
	end

	-- Everyone sees this player "charging up"; the reveal comes when the
	-- roller's animation finishes (see RevealRemote below).
	pendingReveal[player] = best.Name
	RollFXRemote:FireAllClients({ Phase = "Start", UserId = player.UserId })

	return {
		Aura = best.Name,
		Results = results,
		Rolls = data.Rolls,
		Lucky = lucky,
		Boosted = boosted,
		Luck = luck,
		IsNewBest = isNewBest,
		IsFirstTime = data.Inventory[best.Name] == 1,
		Inventory = data.Inventory,
	}
end

RevealRemote.OnServerEvent:Connect(function(player)
	local auraName = pendingReveal[player]
	if not auraName then
		return
	end
	pendingReveal[player] = nil
	RollFXRemote:FireAllClients({ Phase = "Reveal", UserId = player.UserId, Aura = auraName })
end)

GetDataRemote.OnServerInvoke = function(player)
	local data = sessions[player]
	if not data then
		return nil
	end
	return snapshot(data)
end

EquipRemote.OnServerEvent:Connect(function(player, auraName)
	local data = sessions[player]
	if not data or type(auraName) ~= "string" or player:GetAttribute("InDuel") then
		return
	end
	if auraName ~= "" then
		if not AuraData.Get(auraName) or (data.Inventory[auraName] or 0) <= 0 then
			return -- you can't equip something you don't own
		end
	end
	data.Equipped = auraName
	applyAuraToCharacter(player)
	refreshStats(player)
	DataUpdatedRemote:FireClient(player, snapshot(data))
end)

---------------------------------------------------------------------
-- Rebirth: needs enough rolls + one rare aura since the last rebirth.
-- You keep your auras; the rebirth counters start again from zero.
---------------------------------------------------------------------
local rebirthBusy = {}
RebirthRemote.OnServerInvoke = function(player)
	local data = sessions[player]
	if not data then
		return { Error = "Loading" }
	end
	if rebirthBusy[player] or player:GetAttribute("InDuel") then
		return { Error = "Busy" }
	end
	local n = data.Rebirths or 0
	local cost = Rebirth.Cost(n)
	if (data.RebirthRolls or 0) < cost.Rolls or (data.RebirthBest or 0) < cost.Rarity then
		return { Error = "NotReady" }
	end
	rebirthBusy[player] = true
	data.Rebirths = n + 1
	data.RebirthRolls = 0
	data.RebirthBest = 0
	refreshStats(player)
	AnnounceRemote:FireAllClients({
		Type = "Rebirth",
		PlayerName = player.DisplayName,
		UserId = player.UserId,
		Rebirths = data.Rebirths,
	})
	task.spawn(saveData, player)
	task.delay(1, function()
		rebirthBusy[player] = nil
	end)
	local unlocked = {}
	for _, perk in ipairs(Rebirth.PerksAt(data.Rebirths)) do
		table.insert(unlocked, perk.Name)
	end
	return { Rebirths = data.Rebirths, Unlocked = unlocked }
end



-- sound settings are saved so they're the same next time you play
SaveSettingsRemote.OnServerEvent:Connect(function(player, settings)
	local data = sessions[player]
	if not data or type(settings) ~= "table" then
		return
	end
	local function level(value, fallback)
		return (type(value) == "number" and value == value) and math.clamp(value, 0, 1) or fallback
	end
	local old = data.Settings or {}
	data.Settings = {
		Music = level(settings.Music, old.Music or 1),
		Sfx = level(settings.Sfx, old.Sfx or 1),
		Muted = settings.Muted == true,
	}
end)

---------------------------------------------------------------------
-- QUESTS + DAILY REWARD
---------------------------------------------------------------------
local function grantReward(player, data, reward)
	if reward.Potion then
		local from = math.max(Luck.Now(), data.PersonalLuckEnd or 0)
		data.PersonalLuckEnd = from + reward.Potion * 60
		player:SetAttribute("PersonalLuckEnd", data.PersonalLuckEnd)
	end
	if reward.BoostRolls then
		data.BoostRolls = (data.BoostRolls or 0) + reward.BoostRolls
	end
	if reward.Aura and AuraData.Get(reward.Aura) then
		data.Inventory[reward.Aura] = (data.Inventory[reward.Aura] or 0) + (reward.Count or 1)
		local aura = AuraData.Get(reward.Aura)
		if aura.Chance > data.BestChance then
			data.BestChance = aura.Chance
		end
	end
	refreshStats(player)
	DataUpdatedRemote:FireClient(player, snapshot(data))
end

-- make sure the player has today's quests (new ones after midnight UTC)
local function ensureQuests(data)
	local today = QuestData.Today()
	data.Quests = data.Quests or { Day = -1, List = {}, Bonus = false }
	data.Daily = data.Daily or { Streak = 0, LastClaimDay = -1 }
	if data.Quests.Day ~= today then
		local list = {}
		for _, id in ipairs(QuestData.QuestsFor(today)) do
			table.insert(list, { Id = id, Progress = 0, Claimed = false })
		end
		data.Quests = { Day = today, List = list, Bonus = false }
	end
	return today
end

local function dailyInfo(data, today)
	local daily = data.Daily
	local canClaim = daily.LastClaimDay ~= today
	local nextStreak = (daily.LastClaimDay == today - 1) and (daily.Streak + 1) or 1
	if not canClaim then
		nextStreak = daily.Streak -- already claimed today: show today's tile
	end
	return {
		CanClaim = canClaim,
		Streak = daily.Streak,
		DayIndex = ((nextStreak - 1) % #QuestData.DailyRewards) + 1,
	}
end

local function questState(data)
	local today = ensureQuests(data)
	local quests = {}
	local allDone = true
	for _, q in ipairs(data.Quests.List) do
		local def = QuestData.ById[q.Id]
		if def then
			local done = q.Progress >= def.Goal
			allDone = allDone and done and q.Claimed
			table.insert(quests, { Id = q.Id, Progress = q.Progress, Goal = def.Goal, Claimed = q.Claimed, Done = done })
		end
	end
	return {
		Daily = dailyInfo(data, today),
		Quests = quests,
		BonusReady = allDone and not data.Quests.Bonus,
		BonusClaimed = data.Quests.Bonus,
		ResetIn = QuestData.SecondsToReset(),
	}
end

-- how many things are waiting to be claimed (the red dot on the menu button)
local function pushQuests(player)
	local data = sessions[player]
	if not data then
		return
	end
	local state = questState(data)
	local ready = state.Daily.CanClaim and 1 or 0
	for _, q in ipairs(state.Quests) do
		if q.Done and not q.Claimed then
			ready += 1
		end
	end
	if state.BonusReady then
		ready += 1
	end
	player:SetAttribute("QuestsReady", ready)
	QuestUpdatedRemote:FireClient(player, state)
end

addQuestProgress = function(player, kind, amount, extra)
	local data = sessions[player]
	if not data then
		return
	end
	ensureQuests(data)
	local changed = false
	for _, q in ipairs(data.Quests.List) do
		local def = QuestData.ById[q.Id]
		if def and def.Kind == kind and not q.Claimed and q.Progress < def.Goal then
			if kind ~= "Rarity" or (extra or 0) >= def.Threshold then
				q.Progress = math.min(def.Goal, q.Progress + (amount or 1))
				changed = true
			end
		end
	end
	if changed then
		pushQuests(player)
	end
end

QuestRemote.OnServerInvoke = function(player, action, index)
	local data = sessions[player]
	if not data then
		return nil
	end
	local today = ensureQuests(data)
	local granted
	if action == "ClaimDaily" then
		local info = dailyInfo(data, today)
		if info.CanClaim then
			local streak = (data.Daily.LastClaimDay == today - 1) and (data.Daily.Streak + 1) or 1
			data.Daily = { Streak = streak, LastClaimDay = today }
			granted = QuestData.DailyRewards[((streak - 1) % #QuestData.DailyRewards) + 1]
		end
	elseif action == "ClaimQuest" and type(index) == "number" then
		local q = data.Quests.List[index]
		local def = q and QuestData.ById[q.Id]
		if def and not q.Claimed and q.Progress >= def.Goal then
			q.Claimed = true
			granted = def.Reward
		end
	elseif action == "ClaimBonus" then
		local state = questState(data)
		if state.BonusReady then
			data.Quests.Bonus = true
			granted = QuestData.Bonus
		end
	end
	if granted then
		grantReward(player, data, granted)
	end
	pushQuests(player)
	return { State = questState(data), Granted = granted }
end

-- other scripts report progress here (parkour finishes, duel wins)
do
	local events = ServerStorage:FindFirstChild("CosmicServerEvents")
	if not events then
		events = Instance.new("Folder")
		events.Name = "CosmicServerEvents"
		events.Parent = ServerStorage
	end
	local questEvent = events:FindFirstChild("QuestEvent")
	if not questEvent then
		questEvent = Instance.new("BindableEvent")
		questEvent.Name = "QuestEvent"
		questEvent.Parent = events
	end
	questEvent.Event:Connect(function(player, kind, amount)
		if typeof(player) == "Instance" and player:IsA("Player") and type(kind) == "string" then
			addQuestProgress(player, kind, amount or 1)
		end
	end)
end

-- new day while you're playing: new quests + a new daily reward
task.spawn(function()
	local lastDay = QuestData.Today()
	while true do
		task.wait(20)
		local today = QuestData.Today()
		if today ~= lastDay then
			lastDay = today
			for _, player in ipairs(Players:GetPlayers()) do
				pushQuests(player)
			end
		end
	end
end)

---------------------------------------------------------------------
-- PETS: hatch eggs by paying with auras, equip up to 3 for luck
---------------------------------------------------------------------
local hatchBusy = {}

-- the egg stand the player is hatching from must be close by
local function nearEgg(player, eggKey)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hatcheries = workspace:FindFirstChild("PetHatcheries")
	if not root or not hatcheries then
		return false
	end
	for _, item in ipairs(hatcheries:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute("EggKey") == eggKey then
			if (item.Position - root.Position).Magnitude < 24 then
				return true
			end
		end
	end
	return false
end

local function islandRebirths(islandKey)
	for _, info in ipairs(Config.RebirthIslands) do
		if info.Key == islandKey then
			return info.Rebirths
		end
	end
	return 0
end

local function removeAura(player, data, auraName, count)
	data.Inventory[auraName] = (data.Inventory[auraName] or 0) - count
	if data.Inventory[auraName] <= 0 then
		data.Inventory[auraName] = nil
		if data.Equipped == auraName then
			data.Equipped = "" -- you just spent your last one
			applyAuraToCharacter(player)
		end
	end
end

local function givePet(data, petName)
	data.Pets = data.Pets or {}
	data.Pets[petName] = (data.Pets[petName] or 0) + 1
end

HatchRemote.OnServerInvoke = function(player, eggKey)
	local data = sessions[player]
	local egg = type(eggKey) == "string" and PetData.EggByKey[eggKey]
	if not data or not egg then
		return { Error = "Unknown" }
	end
	if hatchBusy[player] then
		return { Error = "Busy" }
	end
	if (data.Rebirths or 0) < islandRebirths(egg.Island) then
		return { Error = "Locked" }
	end
	if not nearEgg(player, eggKey) then
		return { Error = "TooFar" }
	end
	local have = data.Inventory[egg.Cost.Aura] or 0
	if have < egg.Cost.Count then
		return { Error = "NotEnough", Have = have }
	end
	hatchBusy[player] = true
	removeAura(player, data, egg.Cost.Aura, egg.Cost.Count)
	local petName = PetData.Hatch(egg, rng)
	givePet(data, petName)
	-- auto-equip if there's a free slot
	data.EquippedPets = data.EquippedPets or {}
	if #data.EquippedPets < PetData.MaxEquipped then
		table.insert(data.EquippedPets, petName)
	end
	refreshStats(player)
	DataUpdatedRemote:FireClient(player, snapshot(data))
	addQuestProgress(player, "Hatch", 1)
	local pet = PetData.Get(petName)
	if pet and PetData.Rarities[pet.Rarity].Order >= 5 then
		AnnounceRemote:FireAllClients({ Type = "Pet", PlayerName = player.DisplayName, UserId = player.UserId, Pet = petName })
	end
	task.delay(0.5, function()
		hatchBusy[player] = nil
	end)
	return { Pet = petName, Pets = data.Pets, EquippedPets = data.EquippedPets }
end

local function ownedCount(data, petName)
	return (data.Pets or {})[petName] or 0
end

local function equippedCount(data, petName)
	local n = 0
	for _, name in ipairs(data.EquippedPets) do
		if name == petName then
			n += 1
		end
	end
	return n
end

PetRemote.OnServerInvoke = function(player, action, petName)
	local data = sessions[player]
	if not data or type(action) ~= "string" then
		return nil
	end
	data.EquippedPets = data.EquippedPets or {}
	if action == "Equip" and type(petName) == "string" and PetData.Get(petName) then
		if #data.EquippedPets < PetData.MaxEquipped and equippedCount(data, petName) < ownedCount(data, petName) then
			table.insert(data.EquippedPets, petName)
		end
	elseif action == "Unequip" and type(petName) == "string" then
		local index = table.find(data.EquippedPets, petName)
		if index then
			table.remove(data.EquippedPets, index)
		end
	elseif action == "EquipBest" then
		-- the luckiest pets you own
		local owned = {}
		for name, count in pairs(data.Pets or {}) do
			if PetData.Get(name) then
				for _ = 1, count do
					table.insert(owned, name)
				end
			end
		end
		table.sort(owned, function(a, b)
			return PetData.Get(a).Luck > PetData.Get(b).Luck
		end)
		data.EquippedPets = {}
		for i = 1, math.min(PetData.MaxEquipped, #owned) do
			table.insert(data.EquippedPets, owned[i])
		end
	elseif action == "UnequipAll" then
		data.EquippedPets = {}
	elseif action == "Merge" and type(petName) == "string" and PetData.Get(petName) then
		-- 3 of the same pet become 1 golden (or rainbow) pet
		local result = PetData.MergeResult(petName)
		if not result or ownedCount(data, petName) < PetData.MergeCount then
			return { Error = "CantMerge", Pets = data.Pets, EquippedPets = data.EquippedPets }
		end
		data.Pets[petName] -= PetData.MergeCount
		if data.Pets[petName] <= 0 then
			data.Pets[petName] = nil
		end
		-- if you had more of them equipped than you still own, swap in the merged pet
		local swapped = false
		while equippedCount(data, petName) > ownedCount(data, petName) do
			local index = table.find(data.EquippedPets, petName)
			if not swapped then
				data.EquippedPets[index] = result
				swapped = true
			else
				table.remove(data.EquippedPets, index)
			end
		end
		givePet(data, result)
		refreshStats(player)
		DataUpdatedRemote:FireClient(player, snapshot(data))
		addQuestProgress(player, "Merge", 1)
		return { Merged = result, Pets = data.Pets, EquippedPets = data.EquippedPets }
	end
	refreshStats(player)
	return { Pets = data.Pets, EquippedPets = data.EquippedPets }
end

---------------------------------------------------------------------
-- Cosmic Drop: the DropService tells us who grabbed the Cosmic Roll
---------------------------------------------------------------------
do
	local events = ServerStorage:FindFirstChild("CosmicServerEvents")
	if not events then
		events = Instance.new("Folder")
		events.Name = "CosmicServerEvents"
		events.Parent = ServerStorage
	end
	local grant = events:FindFirstChild("GrantBoostRoll")
	if not grant then
		grant = Instance.new("BindableEvent")
		grant.Name = "GrantBoostRoll"
		grant.Parent = events
	end
	grant.Event:Connect(function(player, amount)
		local data = sessions[player]
		if data then
			data.BoostRolls = (data.BoostRolls or 0) + (amount or 1)
			refreshStats(player)
		end
	end)
end

---------------------------------------------------------------------
-- LIMITED OFFER: when does the 7-day window end?
---------------------------------------------------------------------
task.spawn(function()
	local offer = Config.LimitedOffer
	local start = offer.StartTime
	if not start or start <= 0 then
		start = os.time()
		if store and not RunService:IsStudio() then
			-- the first live server ever remembers when the game launched
			local ok, result = pcall(function()
				local globalStore = DataStoreService:GetDataStore(Config.DataStoreName .. "_Global")
				return globalStore:UpdateAsync("LimitedOfferStart", function(old)
					return old or os.time()
				end)
			end)
			if ok and type(result) == "number" then
				start = result
			end
		end
	end
	ReplicatedStorage:SetAttribute("LimitedOfferEnds", start + offer.Days * 24 * 60 * 60)
end)

---------------------------------------------------------------------
-- Developer products (luck potions, server luck)
---------------------------------------------------------------------
local productIdToKey = {}
for key, id in pairs(Config.Products) do
	if id ~= 0 then
		productIdToKey[id] = key
	end
end

local function grantProduct(player, data, key)
	local now = Luck.Now()
	if key == "PersonalLuck" then
		local from = math.max(now, data.PersonalLuckEnd or 0)
		data.PersonalLuckEnd = from + Config.PersonalBoostMinutes * 60
		player:SetAttribute("PersonalLuckEnd", data.PersonalLuckEnd)
		return true
	elseif key == "ServerLuck" then
		local from = math.max(now, ReplicatedStorage:GetAttribute("ServerLuckEnd") or 0)
		ReplicatedStorage:SetAttribute("ServerLuckEnd", from + Config.ServerBoostMinutes * 60)
		AnnounceRemote:FireAllClients({
			Type = "ServerLuck",
			PlayerName = player.DisplayName,
			UserId = player.UserId,
		})
		return true
	elseif key == "LimitedAura" or key == "LimitedLuck" or key == "LimitedPet" then
		local function addPotion(minutes)
			local from = math.max(now, data.PersonalLuckEnd or 0)
			data.PersonalLuckEnd = from + minutes * 60
			player:SetAttribute("PersonalLuckEnd", data.PersonalLuckEnd)
		end
		if key == "LimitedAura" then
			for _, auraName in ipairs({ "Cosmic Rift", "Black Hole" }) do
				data.Inventory[auraName] = (data.Inventory[auraName] or 0) + 1
				local aura = AuraData.Get(auraName)
				if aura and aura.Chance > data.BestChance then
					data.BestChance = aura.Chance
				end
			end
			data.Equipped = "Cosmic Rift"
			applyAuraToCharacter(player)
			addPotion(120)
		elseif key == "LimitedLuck" then
			data.PermanentLuck = math.max(data.PermanentLuck or 1, 2)
			data.BoostRolls = (data.BoostRolls or 0) + 5
			addPotion(60)
		else
			givePet(data, "Cosmic Overlord")
			givePet(data, "Void Wisp")
			data.EquippedPets = data.EquippedPets or {}
			-- the new pets go straight into your best slots
			table.insert(data.EquippedPets, 1, "Void Wisp")
			table.insert(data.EquippedPets, 1, "Cosmic Overlord")
			while #data.EquippedPets > PetData.MaxEquipped do
				table.remove(data.EquippedPets)
			end
			data.BoostRolls = (data.BoostRolls or 0) + 3
		end
		data.LimitedBought = key
		refreshStats(player)
		DataUpdatedRemote:FireClient(player, snapshot(data))
		AnnounceRemote:FireAllClients({ Type = "Limited", PlayerName = player.DisplayName, UserId = player.UserId, Pack = key })
		return true
	end
	return false
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and sessions[player]
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- try again when they rejoin
	end

	data.Receipts = data.Receipts or {}
	if table.find(data.Receipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already given
	end

	local key = productIdToKey[receipt.ProductId]
	if not key or not grantProduct(player, data, key) then
		warn("[CosmicRNG] Unknown product bought:", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(data.Receipts, receipt.PurchaseId)
	while #data.Receipts > 50 do
		table.remove(data.Receipts, 1)
	end
	-- Save right away so the purchase is never lost
	if canSave[player] and not saveData(player) then
		-- Roblox will retry later; undo nothing, the receipt check stops doubles
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Studio testing: products with ID 0 are granted for free so you can test
local TestProductRemote = getRemote("RemoteEvent", "TestProduct")
TestProductRemote.OnServerEvent:Connect(function(player, key)
	if not RunService:IsStudio() or not Config.FreePassesInStudio then
		return
	end
	if type(key) ~= "string" or Config.Products[key] ~= 0 then
		return
	end
	local data = sessions[player]
	if data then
		grantProduct(player, data, key)
	end
end)

---------------------------------------------------------------------
-- Duel wins (DuelService fires this when a player beats another player)
---------------------------------------------------------------------
task.spawn(function()
	local events = ServerStorage:WaitForChild("CosmicServerEvents", 30)
	local duelWin = events and events:WaitForChild("DuelWin", 30)
	if not duelWin then
		return
	end
	duelWin.Event:Connect(function(player)
		local data = sessions[player]
		if data then
			data.DuelWins = (data.DuelWins or 0) + 1
			refreshStats(player)
		end
	end)
end)

---------------------------------------------------------------------
-- Join / leave
---------------------------------------------------------------------
local function onPlayerAdded(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local rolls = Instance.new("IntValue")
	rolls.Name = "Rolls"
	rolls.Parent = stats
	local auraValue = Instance.new("StringValue")
	auraValue.Name = "Aura"
	auraValue.Value = "-"
	auraValue.Parent = stats
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = stats
	stats.Parent = player

	for key in pairs(Config.GamePasses) do
		task.spawn(function()
			local owns = checkPass(player, key)
			player:SetAttribute("Owns_" .. key, owns)
			-- a rebirth perk can give the same thing for free
			player:SetAttribute("Pass_" .. key, owns or rebirthGrants(player, key))
		end)
	end

	player.CharacterAdded:Connect(function()
		applyAuraToCharacter(player)
	end)

	local data, ok = loadData(player)
	if not player.Parent then
		return -- left while loading
	end
	sessions[player] = data
	canSave[player] = ok
	player:SetAttribute("PersonalLuckEnd", data.PersonalLuckEnd or 0)
	player:SetAttribute("DataLoaded", true)
	refreshStats(player)
	applyAuraToCharacter(player)
	DataUpdatedRemote:FireClient(player, snapshot(data))
	pushQuests(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	sessions[player] = nil
	canSave[player] = nil
	lastRollTime[player] = nil
	pendingReveal[player] = nil
	rebirthBusy[player] = nil
	hatchBusy[player] = nil
end)

game:BindToClose(function()
	local threads = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(threads, task.spawn(saveData, player))
	end
	-- give saves up to ~20s to finish
	local start = os.clock()
	while os.clock() - start < 20 do
		local allDone = true
		for _, thread in ipairs(threads) do
			if coroutine.status(thread) ~= "dead" then
				allDone = false
			end
		end
		if allDone then
			break
		end
		task.wait(0.5)
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(saveData, player)
		end
	end
end)
