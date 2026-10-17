-- WorldFX (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Brings the map to life on each player's screen: spinning core rings,
-- bobbing crystals, spinning lantern gems, shooting stars, ambience and
-- the VIP door (VIPs walk through it, others bump into it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local rand = Random.new()

SoundFX.StartAmbient()

local island = workspace:WaitForChild("CosmicIsland", 60)
if not island then
	warn("[WorldFX] CosmicIsland not found")
	return
end

---------------------------------------------------------------------
-- Collect everything we animate (remembering where it started)
---------------------------------------------------------------------
local core = island:WaitForChild("CosmicCore", 10)
local orb = core and core:FindFirstChild("CoreOrb")
local orbShell = core and core:FindFirstChild("CoreOrbShell")
local rings = {}
if core then
	for i = 1, 3 do
		local ring = core:FindFirstChild("CoreRing" .. i)
		if ring then
			table.insert(rings, ring)
		end
	end
end
local orbPosition = orb and orb.Position

local floaters = {}
local gems = {}
for _, child in ipairs(island:GetChildren()) do
	if child:IsA("BasePart") then
		if child.Name == "FloatingCrystal" then
			table.insert(floaters, { Part = child, Base = child.CFrame, Phase = rand:NextNumber(0, 6) })
		elseif child.Name == "SpinGem" then
			table.insert(gems, { Part = child, Position = child.Position, Phase = rand:NextNumber(0, 6) })
		end
	end
end

---------------------------------------------------------------------
-- Per-frame animation
---------------------------------------------------------------------
local t = 0
RunService.RenderStepped:Connect(function(dt)
	t += dt

	if orb and orbPosition then
		local pulse = 5 + math.sin(t * 2) * 0.35
		orb.Size = Vector3.one * pulse
		orb.CFrame = CFrame.new(orbPosition + Vector3.new(0, math.sin(t * 1.2) * 0.4, 0))
		if orbShell then
			orbShell.CFrame = orb.CFrame * CFrame.Angles(t * 0.3, t * 0.5, 0)
		end
	end
	if orbPosition then
		if rings[1] then
			rings[1]:PivotTo(CFrame.new(orbPosition) * CFrame.Angles(t * 0.9, t * 0.4, 0))
		end
		if rings[2] then
			rings[2]:PivotTo(CFrame.new(orbPosition) * CFrame.Angles(0, t * 0.7, t * 1.1))
		end
		if rings[3] then
			rings[3]:PivotTo(CFrame.new(orbPosition) * CFrame.Angles(t * 0.5, 0, t * 0.6))
		end
	end

	for _, f in ipairs(floaters) do
		local base = f.Base
		local lift = Vector3.new(0, math.sin(t * 0.8 + f.Phase) * 1.2, 0)
		f.Part.CFrame = CFrame.new(base.Position + lift) * CFrame.Angles(0, t * 0.4 + f.Phase, 0) * base.Rotation
	end

	for _, g in ipairs(gems) do
		g.Part.CFrame = CFrame.new(g.Position + Vector3.new(0, math.sin(t * 2 + g.Phase) * 0.25, 0))
			* CFrame.Angles(0, t * 1.5 + g.Phase, 0)
			* CFrame.Angles(math.rad(45), 0, math.rad(45))
	end
end)

---------------------------------------------------------------------
-- Shooting stars
---------------------------------------------------------------------
local fxFolder = workspace:FindFirstChild("LocalAuraFX") or Instance.new("Folder")
fxFolder.Name = "LocalAuraFX"
fxFolder.Parent = workspace

local STAR_COLORS = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(170, 210, 255),
	Color3.fromRGB(220, 180, 255),
	Color3.fromRGB(255, 220, 160),
}

local function shootingStar()
	local angle = rand:NextNumber(0, math.pi * 2)
	local distance = rand:NextNumber(180, 380)
	local start = Vector3.new(math.cos(angle) * distance, rand:NextNumber(140, 260), math.sin(angle) * distance)
	local direction = Vector3.new(rand:NextNumber(-1, 1), rand:NextNumber(-0.45, -0.15), rand:NextNumber(-1, 1)).Unit
	local finish = start + direction * rand:NextNumber(220, 360)
	local color = STAR_COLORS[rand:NextInteger(1, #STAR_COLORS)]

	local star = Instance.new("Part")
	star.Name = "ShootingStar"
	star.Shape = Enum.PartType.Ball
	star.Size = Vector3.one * 1.6
	star.Material = Enum.Material.Neon
	star.Color = color
	star.Anchored = true
	star.CanCollide = false
	star.CanQuery = false
	star.CanTouch = false
	star.CastShadow = false
	star.CFrame = CFrame.new(start)

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.7, 0)
	a0.Parent = star
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.7, 0)
	a1.Parent = star
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.45
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(color, Color3.fromRGB(120, 140, 255))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	trail.Parent = star
	star.Parent = fxFolder

	local duration = rand:NextNumber(0.9, 1.6)
	TweenService:Create(star, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = CFrame.new(finish) }):Play()
	task.delay(duration * 0.75, function()
		TweenService:Create(star, TweenInfo.new(duration * 0.25), { Transparency = 1, Size = Vector3.one * 0.2 }):Play()
	end)
	Debris:AddItem(star, duration + 0.6)
end

task.spawn(function()
	while true do
		task.wait(rand:NextNumber(1.2, 3.5))
		shootingStar()
		if rand:NextNumber() < 0.15 then
			-- sometimes a little meteor shower
			for _ = 1, rand:NextInteger(2, 4) do
				task.wait(rand:NextNumber(0.1, 0.3))
				shootingStar()
			end
		end
	end
end)

---------------------------------------------------------------------
-- VIP door
---------------------------------------------------------------------
local lounge = island:WaitForChild("VIPLounge", 10)
local door = lounge and lounge:FindFirstChild("VIPDoor")
if door then
	local function updateDoor()
		local vip = player:GetAttribute("Pass_VIP") == true
		door.CanCollide = not vip -- only changes on THIS player's screen
		door.Transparency = vip and 0.55 or 0.1
	end
	updateDoor()
	player:GetAttributeChangedSignal("Pass_VIP"):Connect(updateDoor)

	local lastBump = 0
	door.Touched:Connect(function(hit)
		local character = player.Character
		if not character or not hit:IsDescendantOf(character) then
			return
		end
		if player:GetAttribute("Pass_VIP") or os.clock() - lastBump < 4 then
			return
		end
		lastBump = os.clock()
		UIKit.toast("👑 VIP only! Get VIP in the Store", UIKit.Theme.Gold)
		SoundFX.Play("Thud")
		local passId = Config.GamePasses.VIP
		if passId and passId ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, passId)
		end
	end)
end
