-- Movement (Script in ServerScriptService)
-- Sprinting: the Sprint LocalScript tells us when you start/stop running
-- (hold Shift, or the RUN button on mobile) and we set your speed.
-- In duels, DuelService reads the same "Sprinting" flag and uses its own speed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local MOVE = Config.Movement

-- Shift is the sprint key, so turn off Roblox's Shift Lock option
pcall(function()
	game:GetService("StarterPlayer").EnableMouseLockOption = false
end)

local remotes = ReplicatedStorage:FindFirstChild("CosmicRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "CosmicRemotes"
	remotes.Parent = ReplicatedStorage
end
local SprintRemote = remotes:FindFirstChild("Sprint")
if not SprintRemote then
	SprintRemote = Instance.new("RemoteEvent")
	SprintRemote.Name = "Sprint"
	SprintRemote.Parent = remotes
end

local function applySpeed(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or character:GetAttribute("InDuel") then
		return -- DuelService controls speed during duels
	end
	humanoid.WalkSpeed = player:GetAttribute("Sprinting") and MOVE.SprintSpeed or MOVE.WalkSpeed
end

SprintRemote.OnServerEvent:Connect(function(player, sprinting)
	sprinting = sprinting == true
	if player:GetAttribute("Sprinting") ~= sprinting then
		player:SetAttribute("Sprinting", sprinting)
		applySpeed(player)
	end
end)

local function onPlayer(player)
	player:SetAttribute("Sprinting", false)
	player.CharacterAdded:Connect(function()
		player:SetAttribute("Sprinting", false)
		task.defer(applySpeed, player)
	end)
	-- after a duel ends, put the right speed back
	player:GetAttributeChangedSignal("InDuel"):Connect(function()
		if not player:GetAttribute("InDuel") then
			task.delay(0.1, applySpeed, player)
		end
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end
