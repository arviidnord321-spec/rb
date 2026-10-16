-- AuraRenderer (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Draws every player's aura on this screen. The server just puts an
-- "Aura" attribute on each character; this script turns it into visuals.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))
local AuraEffects = require(ReplicatedStorage:WaitForChild("AuraEffects"))

local tracked = {} -- [character] = true
local handles = {} -- [character] = aura handle

-- Makes sure a character shows the right aura (or none).
local function reconcile(character, withBurst)
	local desired = character:GetAttribute("Aura")
	local root = character:FindFirstChild("HumanoidRootPart")
	local handle = handles[character]

	if handle then
		local stillValid = handle:IsAlive() and handle.Aura.Name == desired and handle.Root == root
		if not stillValid then
			handle:Destroy()
			handles[character] = nil
		end
	end

	if not handles[character] and desired and root and character.Parent then
		handles[character] = AuraEffects.Apply(character, desired)
		if withBurst and handles[character] then
			local aura = AuraData.Get(desired)
			local tier = AuraData.Tiers[aura.Tier]
			AuraEffects.Burst(root.Position, aura.Colors, 0.6 + tier.Order * 0.2)
		end
	end
end

local function track(character)
	if tracked[character] then
		return
	end
	tracked[character] = true

	character:GetAttributeChangedSignal("Aura"):Connect(function()
		reconcile(character, true)
	end)
	-- Root part can arrive late (loading / streaming)
	character.ChildAdded:Connect(function(child)
		if child.Name == "HumanoidRootPart" then
			reconcile(character, false)
		end
	end)
	character.Destroying:Connect(function()
		tracked[character] = nil
		if handles[character] then
			handles[character]:Destroy()
			handles[character] = nil
		end
	end)

	reconcile(character, false)
end

local function onPlayer(player)
	if player.Character then
		track(player.Character)
	end
	player.CharacterAdded:Connect(track)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end

-- Animate every frame
RunService.RenderStepped:Connect(function(dt)
	for character, handle in pairs(handles) do
		if handle:IsAlive() then
			handle:Update(dt)
		else
			handle:Destroy()
			handles[character] = nil
		end
	end
end)

-- Safety check twice a second (catches respawns, streaming, removed characters)
task.spawn(function()
	while true do
		task.wait(0.5)
		for character in pairs(tracked) do
			if character.Parent == nil then
				tracked[character] = nil
				if handles[character] then
					handles[character]:Destroy()
					handles[character] = nil
				end
			else
				reconcile(character, false)
			end
		end
	end
end)
