-- WorldFX (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Brings the map to life on each player's screen: spinning core rings,
-- bobbing crystals, spinning gems, shooting stars, ambience, the Lucky Isle
-- portals and the pink + gold sky on Lucky Isle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))
local Luck = require(ReplicatedStorage:WaitForChild("Luck"))
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
-- PORTALS + LUCKY ISLE animations
---------------------------------------------------------------------

-- things that spin around a fixed pivot: { Model, BaseCFrame, Function(t) -> CFrame offset }
local spinners = {}
local function addSpinner(model, offsetFn)
	if model then
		table.insert(spinners, { Model = model, Base = model.WorldPivot, Offset = offsetFn })
	end
end

local plaza = island:WaitForChild("PortalPlaza", 10)
if plaza then
	addSpinner(plaza:FindFirstChild("LuckyPortalRing"), function(time)
		return CFrame.Angles(0, 0, time * 0.8)
	end)
	addSpinner(plaza:FindFirstChild("LuckyPortalRingOuter"), function(time)
		return CFrame.Angles(0, 0, -time * 0.5)
	end)
	addSpinner(plaza:FindFirstChild("LuckyPortalGems"), function(time)
		return CFrame.Angles(0, 0, time * 0.35)
	end)
end

local royal = workspace:WaitForChild("LuckyIsland", 30)
local royalOrb, royalOrbBase
local lanterns = {}
if royal then
	local royalCore = royal:FindFirstChild("LuckyCore")
	if royalCore then
		royalOrb = royalCore:FindFirstChild("LuckyOrb")
		royalOrbBase = royalOrb and royalOrb.Position
		addSpinner(royalCore:FindFirstChild("LuckyRing1"), function(time)
			return CFrame.Angles(time * 0.8, time * 0.3, 0)
		end)
		addSpinner(royalCore:FindFirstChild("LuckyRing2"), function(time)
			return CFrame.Angles(0, time * 0.6, time * 0.9)
		end)
		addSpinner(royalCore:FindFirstChild("LuckyRing3"), function(time)
			return CFrame.Angles(time * 0.4, 0, time * 0.5)
		end)
	end
	addSpinner(royal:FindFirstChild("ReturnPortalRing"), function(time)
		return CFrame.Angles(0, 0, -time * 0.8)
	end)
	addSpinner(royal:FindFirstChild("ReturnPortalRingOuter"), function(time)
		return CFrame.Angles(0, 0, time * 0.5)
	end)
	for _, child in ipairs(royal:GetChildren()) do
		if child:IsA("BasePart") and child.Name == "LuckyLantern" then
			table.insert(lanterns, { Part = child, Base = child.Position, Phase = rand:NextNumber(0, 6) })
		end
	end
end

RunService.RenderStepped:Connect(function()
	for _, s in ipairs(spinners) do
		s.Model:PivotTo(s.Base * s.Offset(t))
	end
	if royalOrb and royalOrbBase then
		royalOrb.Size = Vector3.one * (5.5 + math.sin(t * 2.2) * 0.4)
		royalOrb.CFrame = CFrame.new(royalOrbBase + Vector3.new(0, math.sin(t * 1.1) * 0.5, 0))
	end
	for _, l in ipairs(lanterns) do
		l.Part.CFrame = CFrame.new(l.Base + Vector3.new(0, math.sin(t * 0.9 + l.Phase) * 1.4, 0))
			* CFrame.Angles(0, t * 0.5 + l.Phase, 0)
	end
end)

---------------------------------------------------------------------
-- Lucky Isle welcome (the pink + gold sky is done by SkyFX)
---------------------------------------------------------------------
local wasOnRoyal = false
player:GetAttributeChangedSignal("OnLuckyIsland"):Connect(function()
	local on = player:GetAttribute("OnLuckyIsland") == true
	if on == wasOnRoyal then
		return
	end
	wasOnRoyal = on
	if on then
		-- show what the island does to ALL your luck: x30 -> x60
		local multiplier = Config.LuckyIsland.LuckMultiplier
		local after = Luck.Get(player)
		UIKit.luckBoost("🍀", "Lucky Isle", multiplier, after / multiplier, after, UIKit.Theme.Gold)
	end
end)

---------------------------------------------------------------------
-- Portal travel effect (the server teleports, we make it look good)
---------------------------------------------------------------------
local portalGui = UIKit.screen("CosmicPortal", 40)
local portalFlash = UIKit.new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 220, 160),
	BackgroundTransparency = 1,
	Parent = portalGui,
}, {
	UIKit.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 200), Color3.fromRGB(255, 150, 210)),
		Rotation = 45,
	}),
})

local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local PortalFXRemote = remotes:WaitForChild("PortalFX", 30)
local camera = workspace.CurrentCamera
if PortalFXRemote then
	PortalFXRemote.OnClientEvent:Connect(function(kind)
		if kind == "Out" then
			SoundFX.Play("Whoosh", { Speed = 0.7, Volume = 1.5 })
			SoundFX.Play("RevealEpic", { Volume = 0.5 })
			UIKit.tween(portalFlash, 0.3, { BackgroundTransparency = 0 })
			local fov = camera.FieldOfView
			UIKit.tween(camera, 0.3, { FieldOfView = fov + 25 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.45, function()
				camera.FieldOfView = fov
			end)
		elseif kind == "In" then
			UIKit.tween(portalFlash, 0.8, { BackgroundTransparency = 1 })
			UIKit.burst({ Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 150, 210), Color3.fromRGB(120, 230, 210) }, 30, 1.2, Vector2.new(0.5, 0.5))
		elseif kind == "Denied" then
			UIKit.toast("👑 This portal is for VIPs only!", UIKit.Theme.Gold)
			SoundFX.Play("Thud")
			local passId = Config.GamePasses.VIP
			if passId and passId ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, passId)
			end
		end
	end)
end
