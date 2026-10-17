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
	-- perks that unlock passes
	for key in pairs(Config.GamePasses) do
		if rebirthGrants(player, key) and not player:GetAttribute("Pass_" .. key) then
			player:SetAttribute("Pass_" .. key, true)
		end
	end
	player:SetAttribute("EquippedAura", data.Equipped)
	player:SetAttribute("BestChance", data.BestChance)
end

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

	-- Everyone sees this player "charging up"; the reveal comes when the
	-- roller's animation finishes (see RevealRemote below).
	pendingReveal[player] = best.Name
	RollFXRemote:FireAllClients({ Phase = "Start", UserId = player.UserId })

	return {
		Aura = best.Name,
		Results = results,
		Rolls = data.Rolls,
		Lucky = lucky,
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
