-- RollService (Script in ServerScriptService)
-- The "brain" of rolling: picks auras, stores inventories, saves data,
-- checks game passes and tells everyone about rare rolls.
-- Everything important happens here so exploiters can't fake rolls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))

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
local rng = Random.new()

local function newData()
	return {
		Version = 1,
		Rolls = 0,
		Inventory = {}, -- [auraName] = how many you've rolled
		Equipped = "",
		BestChance = 0,
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
		return
	end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:SetAsync(keyFor(player), data, { player.UserId })
		end)
		if ok then
			return
		end
		warn(("[CosmicRNG] Save failed for %s (attempt %d): %s"):format(player.Name, attempt, tostring(err)))
		task.wait(attempt)
	end
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

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local key = passIdToKey[passId]
	if purchased and key then
		player:SetAttribute("Pass_" .. key, true)
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
	end
	player:SetAttribute("Rolls", data.Rolls)
	player:SetAttribute("EquippedAura", data.Equipped)
end

local function getLuck(player, data, rollNumber)
	local luck = Config.BaseLuck
	if hasPass(player, "DoubleLuck") then
		luck *= 2
	end
	-- Potions and events will multiply in here in a later part.
	luck *= (player:GetAttribute("BonusLuck") or 1)
	local lucky = rollNumber % Config.LuckyRollEvery == 0
	if lucky then
		luck *= Config.LuckyRollMultiplier
	end
	return luck, lucky
end

---------------------------------------------------------------------
-- Rolling
---------------------------------------------------------------------
RollRemote.OnServerInvoke = function(player)
	local data = sessions[player]
	if not data then
		return { Error = "Loading" }
	end

	local cooldown = hasPass(player, "QuickRoll") and Config.QuickRollCooldown or Config.RollCooldown
	local now = os.clock()
	-- small grace window for network jitter
	if now - (lastRollTime[player] or 0) < cooldown - 0.1 then
		return { Error = "Cooldown" }
	end
	lastRollTime[player] = now

	local rollNumber = data.Rolls + 1
	local luck, lucky = getLuck(player, data, rollNumber)
	local aura = AuraData.RollRandom(luck, rng)

	data.Rolls = rollNumber
	data.Inventory[aura.Name] = (data.Inventory[aura.Name] or 0) + 1

	local isNewBest = aura.Chance > data.BestChance
	if isNewBest then
		data.BestChance = aura.Chance
	end
	refreshStats(player)

	if aura.Chance >= Config.AnnounceAtChance then
		AnnounceRemote:FireAllClients({
			PlayerName = player.DisplayName,
			UserId = player.UserId,
			Aura = aura.Name,
		})
	end

	return {
		Aura = aura.Name,
		Rolls = data.Rolls,
		Lucky = lucky,
		Luck = luck,
		IsNewBest = isNewBest,
		IsFirstTime = data.Inventory[aura.Name] == 1,
		Inventory = data.Inventory,
	}
end

GetDataRemote.OnServerInvoke = function(player)
	local data = sessions[player]
	if not data then
		return nil
	end
	return snapshot(data)
end

EquipRemote.OnServerEvent:Connect(function(player, auraName)
	local data = sessions[player]
	if not data or type(auraName) ~= "string" then
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
	stats.Parent = player

	for key in pairs(Config.GamePasses) do
		task.spawn(function()
			player:SetAttribute("Pass_" .. key, checkPass(player, key))
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
