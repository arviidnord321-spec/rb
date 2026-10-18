-- IntroCutscene (LocalScript in StarterPlayer > StarterPlayerScripts)
-- The join cutscene (about 13 seconds), only seen by the player joining:
--   1. GROUND SHOT: a thin beam comes down from a swirling portal in the
--      sky and gets wider; rune rings and spiralling lights climb it
--   2. SKY SHOT: high up next to the portal, looking down the beam at the
--      island far below. YOUR avatar bursts out of the portal, glowing
--   3. THE FALL: you dive down the beam, spinning, glowing, with a comet
--      trail and sonic-boom rings; the camera rides along, then watches
--      from the ground
--   4. THE LANDING (slow motion): superhero landing, one knee down, fist
--      in the ground. Flash, shockwaves, glowing cracks, rocks, sparks
--      and a ground shake. Close-up of the fist, then a hero shot
--   5. you stand up, the camera swings behind you, the game starts
-- A copy of your avatar does the acting (nobody else sees anything odd);
-- your real character waits, hidden, on the landing spot.
-- Players can press SKIP. Settings: Config.IntroCutscene.
-- When it's over the player gets the attribute IntroDone = true (the
-- title card and popups wait for that, see UIKit.waitForIntro).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local SETTINGS = Config.IntroCutscene or {}
local BEAM_COLOR = SETTINGS.BeamColor or Color3.fromRGB(170, 130, 255)
local BEAM_COLOR_2 = Color3.fromRGB(110, 220, 255)
local WHITE = Color3.new(1, 1, 1)
local FALL_HEIGHT = SETTINGS.FallHeight or 260
local rand = Random.new()
local new, corner, label, textStroke, tween = UIKit.new, UIKit.corner, UIKit.label, UIKit.textStroke, UIKit.tween

-- timeline (scene seconds)
local T_BEAM = 0.3 -- beam starts
local T_SKY = 2.7 -- cut to the sky shot
local T_APPEAR = 3.3 -- you burst out of the portal
local T_FALL = 4.2 -- you dive
local T_IMPACT = 7.2 -- you land on one knee
local T_PUNCH = T_IMPACT + 1.0 -- you swing your fist down...
local T_HIT = T_PUNCH + 0.14 -- ...and it smashes into the ground: BANG
local SLOWMO_FROM, SLOWMO_TO = T_PUNCH - 0.05, T_HIT + 0.4 -- the punch plays in...
local SLOWMO_RATE = 0.35 -- ...slow motion (35% speed)
local T_CLOSEUP = T_HIT + 0.9 -- close-up of the fist
local T_HERO = T_CLOSEUP + 1.4 -- hero shot
local T_STAND = T_HERO + 1.8 -- you stand up
local T_END = T_STAND + 1.1 -- back to the game

local function finish()
	player:SetAttribute("IntroDone", true)
end
local restoreAll -- set once things are hidden; gives everything back

if SETTINGS.Enabled == false then
	finish()
	return
end

---------------------------------------------------------------------
-- Black screen right away, so you never see the loading
---------------------------------------------------------------------
local gui = UIKit.screen("IntroCutscene", 100)
local cover = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 20, Parent = gui })

---------------------------------------------------------------------
-- Poses (R15): degrees forward/twist/sideways + optional move, added on
-- top of each joint's normal position (same idea as CombatAnim)
---------------------------------------------------------------------
local JOINTS = {
	Root = "LowerTorso", Waist = "UpperTorso", Neck = "Head",
	RightShoulder = "RightUpperArm", RightElbow = "RightLowerArm",
	LeftShoulder = "LeftUpperArm", LeftElbow = "LeftLowerArm",
	RightHip = "RightUpperLeg", RightKnee = "RightLowerLeg",
	LeftHip = "LeftUpperLeg", LeftKnee = "LeftLowerLeg",
}
local rad = math.rad
local function P(rx, ry, rz, px, py, pz)
	return { rx or 0, ry or 0, rz or 0, px or 0, py or 0, pz or 0 }
end

-- curled up inside the portal, about to burst out
local CURL_POSE = {
	Root = P(-25), Waist = P(-25), Neck = P(-30),
	RightShoulder = P(60, 0, 30), LeftShoulder = P(60, 0, -30), RightElbow = P(110), LeftElbow = P(110),
	RightHip = P(80), LeftHip = P(80), RightKnee = P(-110), LeftKnee = P(-110),
}

-- diving: arms up, legs loose, everything flutters in the wind
local function fallPose(t)
	local flap = math.sin(t * 13)
	return {
		RightShoulder = P(158 + flap * 8, 0, -30), LeftShoulder = P(158 - flap * 8, 0, 30),
		RightElbow = P(22 + flap * 6), LeftElbow = P(22 - flap * 6),
		Root = P(8), Neck = P(-22),
		RightHip = P(30 + flap * 6), RightKnee = P(-62), LeftHip = P(-12 - flap * 6), LeftKnee = P(-28),
	}
end

-- the superhero landing: right knee down, left foot planted in front,
-- right fist in the ground, left arm swept out behind, head up
local LAND_POSE = {
	Root = P(-18, 0, 0, 0, -1.15, 0), Waist = P(-12), Neck = P(24),
	LeftHip = P(100), LeftKnee = P(-110),
	RightHip = P(-8, 0, 8), RightKnee = P(-82),
	RightShoulder = P(28, 0, -6), RightElbow = P(0),
	LeftShoulder = P(-60, 0, -50), LeftElbow = P(15),
}
-- after landing: fist raised high behind the head, ready to punch the ground
local WINDUP_POSE = {
	Root = P(-8, 0, 0, 0, -1.1, 0), Waist = P(6, -18, 0), Neck = P(18, 10, 0),
	LeftHip = P(100), LeftKnee = P(-110),
	RightHip = P(-8, 0, 8), RightKnee = P(-82),
	RightShoulder = P(165, 0, -20), RightElbow = P(75),
	LeftShoulder = P(-50, 0, -45), LeftElbow = P(15),
}
-- the punch: the whole body drives the fist into the ground
local PUNCH_POSE = {
	Root = P(-22, 0, 0, 0, -1.2, 0), Waist = P(-16, 8, 0), Neck = P(18),
	LeftHip = P(102), LeftKnee = P(-114),
	RightHip = P(-6, 0, 8), RightKnee = P(-84),
	RightShoulder = P(24, 0, -6), RightElbow = P(0),
	LeftShoulder = P(-65, 0, -55), LeftElbow = P(12),
}
-- touching down: a deep crouch for a split second
local IMPACT_POSE = {
	Root = P(-26, 0, 0, 0, -1.35, 0), Waist = P(-20), Neck = P(10),
	LeftHip = P(108), LeftKnee = P(-122),
	RightHip = P(-4, 0, 8), RightKnee = P(-88),
	RightShoulder = P(22, 0, -6), RightElbow = P(8),
	LeftShoulder = P(-70, 0, -60), LeftElbow = P(10),
}

local function blendPose(a, b, alpha)
	local out = {}
	for joint in pairs(JOINTS) do
		local x = a[joint] or P()
		local y = b[joint] or P()
		local v = {}
		for i = 1, 6 do
			v[i] = x[i] + (y[i] - x[i]) * alpha
		end
		out[joint] = v
	end
	return out
end

local function smooth(a)
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local fxFolder = Instance.new("Folder")
fxFolder.Name = "IntroCutsceneFX"

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		if key ~= "ClassName" then
			p[key] = value
		end
	end
	p.Parent = fxFolder
	return p
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for key, value in pairs(props) do
		e[key] = value
	end
	e.Parent = parent
	return e
end

local function seq(a, b)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

-- a flat ring that expands and fades (shockwaves, sonic booms)
local function ring(cframe, fromSize, toSize, duration, color)
	local holder = part({ Name = "Ring", Size = Vector3.new(fromSize, 0.1, fromSize), CFrame = cframe, Transparency = 1 })
	for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Bottom }) do
		local decal = Instance.new("Decal")
		decal.Texture = Config.Textures.Shockwave
		decal.Face = face
		decal.Color3 = color
		decal.Parent = holder
		TweenService:Create(decal, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	end
	TweenService:Create(holder, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(toSize, 0.1, toSize) }):Play()
	task.delay(duration + 0.1, function()
		holder:Destroy()
	end)
end

---------------------------------------------------------------------
-- The cutscene
---------------------------------------------------------------------
local function run()
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 15)
	local humanoid = character:WaitForChild("Humanoid", 15)
	if not root or not humanoid then
		return
	end
	if not player:HasAppearanceLoaded() then
		local loaded = false
		local connection = player.CharacterAppearanceLoaded:Connect(function()
			loaded = true
		end)
		local deadline = os.clock() + 5
		while not loaded and os.clock() < deadline do
			task.wait(0.1)
		end
		connection:Disconnect()
	end
	task.wait(0.4) -- let the character settle on the spawn pad

	-- where you land
	local landCF = root.CFrame
	local rigScale = humanoid.RigType == Enum.HumanoidRigType.R15 and math.max(0.3, humanoid.HipHeight / 2) or 1
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -30, 0), params)
	local groundY = hit and hit.Position.Y or (root.Position.Y - humanoid.HipHeight - root.Size.Y / 2)
	local ground = Vector3.new(landCF.Position.X, groundY, landCF.Position.Z)
	local look = (landCF.LookVector * Vector3.new(1, 0, 1)).Unit
	local right = look:Cross(Vector3.yAxis)
	local portalY = groundY + FALL_HEIGHT + 18

	---------------------------------------------------------------
	-- the copy of you that does the acting
	---------------------------------------------------------------
	local wasArchivable = character.Archivable
	character.Archivable = true
	local actor = character:Clone()
	character.Archivable = wasArchivable
	if not actor then
		return
	end
	actor.Name = "IntroActor"
	for _, item in ipairs(actor:GetDescendants()) do
		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ForceField") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.Massless = true
			item.Anchored = item.Name == "HumanoidRootPart"
			item.LocalTransparencyModifier = 0
		end
	end
	local actorHumanoid = actor:FindFirstChildOfClass("Humanoid")
	if actorHumanoid then
		actorHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		actorHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		actorHumanoid.BreakJointsOnDeath = false
		local animator = actorHumanoid:FindFirstChildOfClass("Animator")
		if animator then
			animator:Destroy() -- nothing may play over our poses
		end
	end
	local actorRoot = actor:FindFirstChild("HumanoidRootPart")
	if not actorRoot then
		actor:Destroy()
		return
	end
	local motors, baseC0 = {}, {}
	for joint, partName in pairs(JOINTS) do
		local holder = actor:FindFirstChild(partName)
		local motor = holder and holder:FindFirstChild(joint)
		if motor and motor:IsA("Motor6D") then
			motors[joint] = motor
			baseC0[joint] = motor.C0
		end
	end
	local canPose = motors.Root ~= nil and motors.RightShoulder ~= nil
	local function applyPose(pose)
		if not canPose then
			return
		end
		for joint, motor in pairs(motors) do
			local v = pose[joint]
			if v then
				motor.C0 = baseC0[joint] * CFrame.new(v[4] * rigScale, v[5] * rigScale, v[6] * rigScale)
					* CFrame.Angles(rad(v[1]), rad(v[2]), rad(v[3]))
			else
				motor.C0 = baseC0[joint]
			end
		end
	end
	local fist = actor:FindFirstChild("RightHand") or actor:FindFirstChild("Right Arm") or actorRoot
	local torso = actor:FindFirstChild("UpperTorso") or actor:FindFirstChild("Torso") or actorRoot

	-- the glow around you
	local outline = Instance.new("Highlight")
	outline.FillColor = BEAM_COLOR
	outline.OutlineColor = WHITE
	outline.FillTransparency = 0.5
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = actor
	local aura = emitter(torso, {
		Texture = Config.Textures.Glow, Rate = 22, Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(0, 1),
		Size = seq(8, 4), LightEmission = 1, Color = ColorSequence.new(BEAM_COLOR), Transparency = seq(0.55, 1),
	})
	local motes = emitter(torso, {
		Texture = Config.Textures.Sparkle, Rate = 30, Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(180, 180), Size = seq(0.45, 0), LightEmission = 1, Rotation = NumberRange.new(0, 360),
		Color = ColorSequence.new(WHITE, BEAM_COLOR_2),
	})
	local auraLight = Instance.new("PointLight")
	auraLight.Color = BEAM_COLOR
	auraLight.Range = 16
	auraLight.Brightness = 2
	auraLight.Shadows = false
	auraLight.Parent = torso

	-- comet trail + wind streaks while falling
	local trailA = Instance.new("Attachment")
	trailA.Position = Vector3.new(-1.3, 0, 0)
	trailA.Parent = actorRoot
	local trailB = Instance.new("Attachment")
	trailB.Position = Vector3.new(1.3, 0, 0)
	trailB.Parent = actorRoot
	local trail = Instance.new("Trail")
	trail.Attachment0 = trailA
	trail.Attachment1 = trailB
	trail.Lifetime = 0.5
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(WHITE, BEAM_COLOR)
	trail.Transparency = seq(0.15, 1)
	trail.WidthScale = seq(1, 0.15)
	trail.Enabled = false
	trail.Parent = actorRoot
	local streaks = emitter(actorRoot, {
		Texture = Config.Textures.Spark, Rate = 0, Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(60, 90),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Size = seq(0.5, 0), LightEmission = 1,
		Color = ColorSequence.new(WHITE, BEAM_COLOR), Transparency = seq(0.1, 1),
	})

	-- after landing: crackling energy around the fist
	local fistSparks = emitter(fist, {
		Texture = Config.Textures.Spark, Rate = 0, Lifetime = NumberRange.new(0.2, 0.45), Speed = NumberRange.new(4, 10),
		SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -20, 0), Size = seq(0.3, 0), LightEmission = 1,
		Color = ColorSequence.new(WHITE, BEAM_COLOR_2),
	})
	local fistLight = Instance.new("PointLight")
	fistLight.Color = BEAM_COLOR_2
	fistLight.Range = 10
	fistLight.Brightness = 0
	fistLight.Shadows = false
	fistLight.Parent = fist

	---------------------------------------------------------------
	-- hide the real you (and everything else on screen) for now
	---------------------------------------------------------------
	local hiddenParts, hiddenEffects = {}, {}
	local function hide(item)
		if item:IsA("BasePart") or item:IsA("Decal") then
			hiddenParts[item] = true
			item.LocalTransparencyModifier = 1
		elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") or item:IsA("Light")
			or item:IsA("BillboardGui") or item:IsA("SurfaceGui") or item:IsA("Highlight") then
			if item.Enabled then
				hiddenEffects[item] = true
				item.Enabled = false
			end
		end
	end
	for _, item in ipairs(character:GetDescendants()) do
		hide(item)
	end
	local addedConnection = character.DescendantAdded:Connect(hide)
	character:SetAttribute("InCutscene", true)
	-- Roblox's camera scripts can switch your character back to visible,
	-- so ALSO park the real you out of sight, under the island, until the
	-- cutscene is over (otherwise a standing you overlaps the landing)
	local rootWasAnchored = root.Anchored
	root.Anchored = true
	root.CFrame = CFrame.new(ground.X, math.max(groundY - 30, -40), ground.Z) * landCF.Rotation

	local hiddenGuis = {}
	local playerGui = player:WaitForChild("PlayerGui")
	local function hideGui(item)
		if item:IsA("ScreenGui") and item ~= gui and item.Enabled then
			hiddenGuis[item] = true
			item.Enabled = false
		end
	end
	for _, item in ipairs(playerGui:GetChildren()) do
		hideGui(item)
	end
	local guiConnection = playerGui.ChildAdded:Connect(hideGui)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)

	local controls
	pcall(function()
		local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		controls = playerModule:GetControls()
		controls:Disable()
	end)

	-- moodier colors while it plays
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "IntroGrade"
	grade.Parent = Lighting
	TweenService:Create(grade, TweenInfo.new(1.5), {
		Brightness = -0.04, Contrast = 0.12, Saturation = 0.2, TintColor = Color3.fromRGB(235, 225, 255),
	}):Play()

	local rumble
	local fov = camera.FieldOfView
	local restored = false
	restoreAll = function()
		if restored then
			return
		end
		restored = true
		if root.Parent then
			root.CFrame = landCF
			root.AssemblyLinearVelocity = Vector3.zero
			root.Anchored = rootWasAnchored
		end
		SoundFX.FadeOut(rumble, 0.8)
		camera.FieldOfView = fov
		camera.CameraType = Enum.CameraType.Custom
		addedConnection:Disconnect()
		for item in pairs(hiddenParts) do
			if item.Parent then
				item.LocalTransparencyModifier = 0
			end
		end
		for item in pairs(hiddenEffects) do
			if item.Parent then
				item.Enabled = true
			end
		end
		character:SetAttribute("InCutscene", nil)
		guiConnection:Disconnect()
		for item in pairs(hiddenGuis) do
			if item.Parent then
				item.Enabled = true
			end
		end
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
		end)
		if controls then
			controls:Enable()
		end
		actor:Destroy()
		TweenService:Create(grade, TweenInfo.new(1), { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = WHITE }):Play()
		finish()
		task.delay(5, function()
			grade:Destroy()
			fxFolder:Destroy()
			gui:Destroy()
		end)
	end

	fxFolder.Parent = workspace

	---------------------------------------------------------------
	-- screen: movie bars, skip button, name text
	---------------------------------------------------------------
	local topBar = new("Frame", { Size = UDim2.new(1, 0, 0.11, 0), Position = UDim2.fromScale(0, -0.11), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5, Parent = gui })
	local bottomBar = new("Frame", { Size = UDim2.new(1, 0, 0.11, 0), Position = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5, Parent = gui })
	tween(topBar, 0.6, { Position = UDim2.fromScale(0, 0) })
	tween(bottomBar, 0.6, { Position = UDim2.fromScale(0, 0.89) })
	local skip = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -16), Size = UDim2.fromOffset(110, 40),
		BackgroundColor3 = Color3.fromRGB(30, 26, 50), BackgroundTransparency = 0.3, Text = "SKIP ▸", Font = UIKit.TitleFont,
		TextSize = 20, TextColor3 = WHITE, AutoButtonColor = true, ZIndex = 30, Parent = gui,
	}, { corner(UDim.new(0, 10)) })
	local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 10, Parent = gui })
	local arrival = label({
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.86, 0), Size = UDim2.fromOffset(900, 60),
		Text = ("✦ %s HAS ARRIVED ✦"):format(string.upper(player.DisplayName)), Font = UIKit.TitleFont, TextSize = 42,
		TextTransparency = 1, ZIndex = 12, Parent = gui,
	})
	local arrivalStroke = textStroke(3)
	arrivalStroke.Transparency = 1
	arrivalStroke.Parent = arrival
	local arrivalGradient = UIKit.gradient(Color3.fromRGB(220, 190, 255), BEAM_COLOR_2, 0)
	arrivalGradient.Parent = arrival
	UIKit.addAutoScale(arrival)

	---------------------------------------------------------------
	-- the beam, the portal and the magic circle
	---------------------------------------------------------------
	local BEAM_LENGTH = portalY - groundY + 300
	local beamCF = CFrame.new(ground + Vector3.new(0, BEAM_LENGTH / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local beamOuter = part({ Name = "BeamOuter", Shape = Enum.PartType.Cylinder, Size = Vector3.new(BEAM_LENGTH, 0.2, 0.2), CFrame = beamCF,
		Color = BEAM_COLOR, Material = Enum.Material.Neon, Transparency = 0.6 })
	local beamMid = part({ Name = "BeamMid", Shape = Enum.PartType.Cylinder, Size = Vector3.new(BEAM_LENGTH, 0.12, 0.12), CFrame = beamCF,
		Color = BEAM_COLOR_2, Material = Enum.Material.Neon, Transparency = 0.5 })
	local beamCore = part({ Name = "BeamCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(BEAM_LENGTH, 0.08, 0.08), CFrame = beamCF,
		Color = WHITE, Material = Enum.Material.Neon, Transparency = 0.1 })
	-- glittering dust all along the beam
	local beamDust = emitter(beamOuter, {
		Texture = Config.Textures.Sparkle, Rate = 0, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(1, 4),
		SpreadAngle = Vector2.new(180, 180), Size = seq(1.2, 0), LightEmission = 1, Rotation = NumberRange.new(0, 360),
		Color = ColorSequence.new(WHITE, BEAM_COLOR), Transparency = seq(0.1, 1),
	})

	-- the swirling portal in the sky
	local portal = part({ Name = "Portal", Size = Vector3.new(4, 0.2, 4), CFrame = CFrame.new(ground.X, portalY, ground.Z), Transparency = 1 })
	local portalDecals = {}
	for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Bottom }) do
		for k = 1, 2 do
			local decal = Instance.new("Decal")
			decal.Texture = Config.Textures.Vortex
			decal.Face = face
			decal.Color3 = k == 1 and BEAM_COLOR or BEAM_COLOR_2
			decal.Transparency = 1
			decal.Parent = portal
			table.insert(portalDecals, decal)
		end
	end
	local portalGlow = emitter(portal, {
		Texture = Config.Textures.Glow, Rate = 0, Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(0, 0),
		Size = seq(40, 60), LightEmission = 1, Color = ColorSequence.new(BEAM_COLOR), Transparency = seq(0.6, 1),
	})
	local portalSwirl = emitter(portal, {
		Texture = Config.Textures.Sparkle, Rate = 0, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(10, 20),
		SpreadAngle = Vector2.new(180, 10), Size = seq(1.6, 0), LightEmission = 1, Color = ColorSequence.new(WHITE, BEAM_COLOR_2),
		RotSpeed = NumberRange.new(-200, 200),
	})

	-- magic circle on the ground
	local groundGlow = part({ Name = "GroundGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 1, 1),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = BEAM_COLOR,
		Material = Enum.Material.Neon, Transparency = 0.45 })
	local rising = emitter(groundGlow, {
		Texture = Config.Textures.Sparkle, Rate = 0, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(8, 22),
		EmissionDirection = Enum.NormalId.Right, SpreadAngle = Vector2.new(14, 14), Size = seq(0.7, 0), LightEmission = 1,
		Color = ColorSequence.new(WHITE, BEAM_COLOR),
	})
	local light = Instance.new("PointLight")
	light.Color = BEAM_COLOR
	light.Range = 30
	light.Brightness = 0
	light.Shadows = false
	light.Parent = groundGlow

	-- rune rings around the beam (they spin and climb) + the ground circle
	local RUNES_PER_RING = 12
	local runeRings = {}
	local runeParts, runeCFrames = {}, {}
	for k = 1, 4 do
		local runes = {}
		for i = 1, RUNES_PER_RING do
			local rune = part({ Name = "Rune", Size = Vector3.new(0.5, 0.5, 0.12), Color = (i % 2 == 0) and BEAM_COLOR_2 or WHITE,
				Material = Enum.Material.Neon, Transparency = 1 })
			table.insert(runes, rune)
			table.insert(runeParts, rune)
		end
		runeRings[k] = runes
	end
	-- lights that spiral up the beam, leaving trails
	local spirals = {}
	for k = 1, 4 do
		local orb = part({ Name = "Spiral", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Color = (k % 2 == 0) and BEAM_COLOR_2 or WHITE,
			Material = Enum.Material.Neon, Transparency = 1 })
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.4, 0)
		a0.Parent = orb
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.4, 0)
		a1.Parent = orb
		local orbTrail = Instance.new("Trail")
		orbTrail.Attachment0 = a0
		orbTrail.Attachment1 = a1
		orbTrail.Lifetime = 0.6
		orbTrail.LightEmission = 1
		orbTrail.FaceCamera = true
		orbTrail.WidthScale = seq(1, 0)
		orbTrail.Transparency = seq(0.1, 1)
		orbTrail.Color = ColorSequence.new(orb.Color, BEAM_COLOR)
		orbTrail.Parent = orb
		table.insert(spirals, { Part = orb, Offset = k / 4, Speed = 0.12 + k * 0.015 })
	end

	---------------------------------------------------------------
	-- the moments
	---------------------------------------------------------------
	local rocks = {}
	local function appear()
		actor.Parent = fxFolder
		SoundFX.Play("TeleportZap", { Volume = 0.8 })
		SoundFX.Play("RevealLegendary", { Volume = 0.6 })
		ring(CFrame.new(ground.X, portalY - 1, ground.Z), 4, 70, 0.9, WHITE)
		ring(CFrame.new(ground.X, portalY - 1.2, ground.Z), 4, 45, 0.7, BEAM_COLOR_2)
		portalSwirl:Emit(80)
		local burst = emitter(torso, {
			Texture = Config.Textures.Spark, Rate = 0, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(20, 40),
			SpreadAngle = Vector2.new(180, 180), Size = seq(0.8, 0), LightEmission = 1, Color = ColorSequence.new(WHITE, BEAM_COLOR),
		})
		burst:Emit(70)
	end

	-- landing on one knee: a smaller thud before the big punch
	local function touchdown()
		SoundFX.Play("Thud", { Volume = 1 })
		SoundFX.Play("Kick", { Volume = 0.7 })
		streaks.Rate = 0
		trail.Enabled = false
		ring(CFrame.new(ground + Vector3.new(0, 0.12, 0)), 2, 16, 0.6, WHITE)
		local puffSpot = part({ Name = "Puff", Size = Vector3.new(2, 0.2, 2), CFrame = CFrame.new(ground + Vector3.new(0, 0.3, 0)), Transparency = 1 })
		local puff = emitter(puffSpot, {
			Texture = Config.Textures.Smoke, Rate = 0, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(14, 22),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(86, 86), Drag = 6,
			Size = seq(0.8, 2), Transparency = seq(0.6, 1), Color = ColorSequence.new(Color3.fromRGB(215, 205, 235)),
		})
		puff:Emit(12)
	end

	local function impact()
		SoundFX.Play("HeavyHit", { Volume = 1 })
		SoundFX.Play("Explosion", { Volume = 0.8 })
		task.delay(0.15, function()
			SoundFX.Play("Thud", { Volume = 1 })
		end)
		-- short flash, so you can still see the landing
		flash.BackgroundTransparency = 0.45
		tween(flash, 0.25, { BackgroundTransparency = 1 })
		streaks.Rate = 0
		trail.Enabled = false

		ring(CFrame.new(ground + Vector3.new(0, 0.14, 0)), 2, 52, 1.2, WHITE)
		ring(CFrame.new(ground + Vector3.new(0, 0.16, 0)), 2, 34, 1.5, BEAM_COLOR)
		task.delay(0.25, function()
			ring(CFrame.new(ground + Vector3.new(0, 0.18, 0)), 2, 24, 1.1, BEAM_COLOR_2)
		end)

		-- glowing cracks spreading out from the fist
		local fistGround = Vector3.new(fist.Position.X, groundY, fist.Position.Z)
		for k = 1, 11 do
			local angle = k / 11 * math.pi * 2 + rand:NextNumber(-0.2, 0.2)
			local length = rand:NextNumber(4, 9)
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local from = fistGround + Vector3.new(0, 0.08, 0)
			local crack = part({ Name = "Crack", Size = Vector3.new(0.4, 0.06, 0.1),
				CFrame = CFrame.lookAt(from + dir * 0.3, from + dir * 2), Color = Color3.fromRGB(25, 15, 40) })
			local finalCF = CFrame.lookAt(from + dir * (0.3 + length / 2), from + dir * 30)
			TweenService:Create(crack, TweenInfo.new(0.22, Enum.EasingStyle.Quad), { Size = Vector3.new(0.4, 0.06, length), CFrame = finalCF }):Play()
			local glowLine = part({ Name = "CrackGlow", Size = Vector3.new(0.14, 0.07, length * 0.85), CFrame = finalCF * CFrame.new(0, 0.01, 0),
				Color = (k % 2 == 0) and BEAM_COLOR_2 or BEAM_COLOR, Material = Enum.Material.Neon, Transparency = 1 })
			TweenService:Create(glowLine, TweenInfo.new(0.35), { Transparency = 0.05 }):Play()
			task.delay(4.5, function()
				TweenService:Create(glowLine, TweenInfo.new(1.5), { Transparency = 1 }):Play()
				TweenService:Create(crack, TweenInfo.new(1.5), { Transparency = 1 }):Play()
			end)
		end
		-- a little crater under the fist
		part({ Name = "Crater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 2.6, 2.6),
			CFrame = CFrame.new(fistGround + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(35, 25, 55) })

		-- dust that rolls OUTWARD (low and quick, so it doesn't hide you)
		local dustSpot = part({ Name = "Dust", Size = Vector3.new(3, 0.2, 3), CFrame = CFrame.new(ground + Vector3.new(0, 0.3, 0)), Transparency = 1 })
		local dust = emitter(dustSpot, {
			Texture = Config.Textures.Smoke, Rate = 0, Lifetime = NumberRange.new(0.7, 1.2), Speed = NumberRange.new(28, 40),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(84, 84), Drag = 5, Acceleration = Vector3.new(0, -6, 0),
			Size = seq(1.2, 3.2), Transparency = seq(0.55, 1), Color = ColorSequence.new(Color3.fromRGB(215, 205, 235)),
			RotSpeed = NumberRange.new(-90, 90), Rotation = NumberRange.new(0, 360),
		})
		dust:Emit(28)
		local sparks = emitter(dustSpot, {
			Texture = Config.Textures.Spark, Rate = 0, Lifetime = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(25, 45),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -50, 0),
			Size = seq(0.5, 0), LightEmission = 1, Color = ColorSequence.new(WHITE, BEAM_COLOR),
		})
		sparks:Emit(70)

		-- rocks flying up and bouncing down
		for _ = 1, 14 do
			local angle = rand:NextNumber(0, math.pi * 2)
			local size = rand:NextNumber(0.35, 0.9)
			local rock = part({ Name = "Rock", Size = Vector3.new(size, size * 0.8, size), Color = Color3.fromRGB(110, 95, 140),
				Material = Enum.Material.Slate, CFrame = CFrame.new(ground + Vector3.new(math.cos(angle) * 1.8, 0.3, math.sin(angle) * 1.8)) })
			table.insert(rocks, {
				Part = rock,
				Velocity = Vector3.new(math.cos(angle) * rand:NextNumber(6, 16), rand:NextNumber(14, 26), math.sin(angle) * rand:NextNumber(6, 16)),
				Spin = Vector3.new(rand:NextNumber(-8, 8), rand:NextNumber(-8, 8), rand:NextNumber(-8, 8)),
			})
		end

		-- energy keeps crackling around the fist
		fistSparks.Rate = 40
		fistLight.Brightness = 3
		aura.Rate = 12
		motes.Rate = 18

		-- the beam bursts wide, then fades away
		TweenService:Create(beamOuter, TweenInfo.new(0.25), { Size = Vector3.new(BEAM_LENGTH, 16, 16), Transparency = 0.8 }):Play()
		task.delay(0.3, function()
			for _, beamPart in ipairs({ beamOuter, beamMid, beamCore }) do
				TweenService:Create(beamPart, TweenInfo.new(1.8, Enum.EasingStyle.Quad), { Size = Vector3.new(BEAM_LENGTH, 0.05, 0.05), Transparency = 1 }):Play()
			end
			for _, decal in ipairs(portalDecals) do
				TweenService:Create(decal, TweenInfo.new(1.5), { Transparency = 1 }):Play()
			end
			TweenService:Create(groundGlow, TweenInfo.new(3), { Transparency = 1 }):Play()
			TweenService:Create(light, TweenInfo.new(3), { Brightness = 0 }):Play()
		end)
		beamDust.Rate = 0
		rising.Rate = 0
		portalGlow.Rate = 0
	end

	---------------------------------------------------------------
	-- play it
	---------------------------------------------------------------
	camera.CameraType = Enum.CameraType.Scriptable
	rumble = SoundFX.Loop("Rumble", 1.2, { Volume = 0.7 })
	local skipped = false
	skip.Activated:Connect(function()
		skipped = true
	end)
	tween(cover, 0.7, { BackgroundTransparency = 1 })

	local start = os.clock()
	local last = start
	local t = 0 -- scene time (runs slower right after the impact)
	local stage = 0
	local shakeUntil, shakeLength, shakePower = 0, 1, 1
	local nextBoom = 0
	local headY = ground.Y + 2.2 * rigScale
	local finalCam = CFrame.lookAt(ground - look * 12 + Vector3.new(0, 5.5, 0), ground + Vector3.new(0, 2.5, 0))

	local done = false
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local dt = math.min(now - last, 0.1)
		last = now
		local rate = (t >= SLOWMO_FROM and t < SLOWMO_TO) and SLOWMO_RATE or 1
		t += dt * rate
		if skipped then
			t = T_END
			stage = 99
		end
		-- keep the real you hidden (the camera scripts may undo it)
		for item in pairs(hiddenParts) do
			item.LocalTransparencyModifier = 1
		end

		-- one-shot moments
		if stage == 0 and t >= T_BEAM then
			stage = 1
			SoundFX.Play("IntroSwell")
			rising.Rate = 35
			beamDust.Rate = 120
			portalGlow.Rate = 6
			portalSwirl.Rate = 25
		elseif stage == 1 and t >= T_APPEAR then
			stage = 2
			appear()
		elseif stage == 2 and t >= T_FALL then
			stage = 3
			SoundFX.Riser(T_IMPACT - T_FALL, { Volume = 0.8 })
			SoundFX.Play("Whoosh", { Volume = 0.8 })
			trail.Enabled = true
			streaks.Rate = 70
		elseif stage == 3 and t >= T_IMPACT then
			stage = 4
			shakeUntil, shakeLength, shakePower = now + 0.45, 0.45, 0.5
			touchdown()
		elseif stage == 4 and t >= T_PUNCH then
			stage = 5
			SoundFX.Play("SwingHeavy", { Volume = 1 })
		elseif stage == 5 and t >= T_HIT then
			stage = 6
			shakeUntil, shakeLength, shakePower = now + 1.6, 1.6, 1
			impact()
		elseif stage == 6 and t >= T_CLOSEUP then
			stage = 7
			-- a second, smaller rumble as the cracks glow
			shakeUntil, shakeLength, shakePower = now + 0.5, 0.5, 0.6
			SoundFX.Play("Thud", { Volume = 0.6 })
		elseif stage == 7 and t >= T_HERO then
			stage = 8
			tween(arrival, 0.6, { TextTransparency = 0 })
			tween(arrivalStroke, 0.6, { Transparency = 0 })
			tween(arrivalGradient, 3, { Rotation = 180 }, Enum.EasingStyle.Linear)
			SoundFX.Chime(1, 4)
		elseif stage == 8 and t >= T_STAND then
			stage = 9
			SoundFX.Play("Whoosh", { Volume = 0.5 })
			TweenService:Create(outline, TweenInfo.new(1), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
			aura.Rate = 0
			motes.Rate = 0
			fistSparks.Rate = 0
			TweenService:Create(fistLight, TweenInfo.new(0.8), { Brightness = 0 }):Play()
			TweenService:Create(auraLight, TweenInfo.new(0.8), { Brightness = 0 }):Play()
		end

		-- the beam grows and pulses
		local beamAlpha = smooth((t - T_BEAM) / 2.4)
		if t < T_HIT then
			local pulse = 1 + math.sin(t * 9) * 0.06
			local width = (0.2 + beamAlpha * 7.5) * pulse
			beamOuter.Size = Vector3.new(BEAM_LENGTH, width, width)
			beamMid.Size = Vector3.new(BEAM_LENGTH, width * 0.6, width * 0.6)
			beamCore.Size = Vector3.new(BEAM_LENGTH, width * 0.3, width * 0.3)
			beamOuter.Transparency = 0.75 - beamAlpha * 0.4
			beamMid.Transparency = 0.7 - beamAlpha * 0.3
			groundGlow.Size = Vector3.new(0.12, 2 + beamAlpha * 14, 2 + beamAlpha * 14)
			light.Brightness = beamAlpha * 3
			local portalSize = 4 + beamAlpha * 56
			portal.Size = Vector3.new(portalSize, 0.2, portalSize)
			for index, decal in ipairs(portalDecals) do
				decal.Transparency = 1 - beamAlpha * (index % 2 == 1 and 0.85 or 0.6)
			end
		end
		portal.CFrame = CFrame.new(ground.X, portalY, ground.Z) * CFrame.Angles(0, t * 1.4, 0)

		-- rune rings: one on the ground, three climbing the beam
		local runeAlpha = smooth((t - T_BEAM - 0.4) / 1.5) * (1 - smooth((t - T_HIT - 0.3) / 1.2))
		local index = 0
		for k, runes in ipairs(runeRings) do
			local radius, height, spin
			if k == 1 then
				radius, height, spin = 7.5, 0.3, t * 0.6
			else
				radius = 5 + k
				height = ((t * 18 + k * 60) % (FALL_HEIGHT * 0.9)) + 6
				spin = -t * (1 + k * 0.3)
			end
			for i, rune in ipairs(runes) do
				index += 1
				local angle = spin + i / RUNES_PER_RING * math.pi * 2
				local position = ground + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
				local facing = k == 1 and CFrame.lookAt(position, position + Vector3.yAxis) or CFrame.lookAt(position, Vector3.new(ground.X, position.Y, ground.Z))
				runeCFrames[index] = facing * CFrame.Angles(0, 0, math.pi / 4)
				rune.Transparency = 1 - runeAlpha * 0.9
			end
		end
		workspace:BulkMoveTo(runeParts, runeCFrames, Enum.BulkMoveMode.FireCFrameChanged)

		-- spiralling lights
		for _, spiral in ipairs(spirals) do
			local u = (t * spiral.Speed + spiral.Offset) % 1
			local angle = u * math.pi * 14 + spiral.Offset * math.pi * 2
			local radius = 3 + beamAlpha * 3
			spiral.Part.CFrame = CFrame.new(ground + Vector3.new(math.cos(angle) * radius, u * FALL_HEIGHT, math.sin(angle) * radius))
			spiral.Part.Transparency = 1 - runeAlpha
		end

		-- where you are, and your pose
		local actorCF
		if t < T_FALL then
			-- curled up in the portal, then hanging there for a moment
			local since = math.max(0, t - T_APPEAR)
			local drop = math.min(since, 0.5) * 18
			actorCF = CFrame.new(ground.X, portalY - 4 - drop, ground.Z) * landCF.Rotation * CFrame.Angles(0, since * 2, 0)
			applyPose(blendPose(CURL_POSE, fallPose(t), smooth(since / 0.6)))
		elseif t < T_IMPACT then
			local a = (t - T_FALL) / (T_IMPACT - T_FALL)
			local top = portalY - 13 - groundY
			local height = top * (1 - a * a)
			local spin = (1 - a) ^ 2 * math.pi * 4
			actorCF = CFrame.new(landCF.Position + Vector3.new(0, height, 0)) * landCF.Rotation * CFrame.Angles(0, spin, 0)
				* CFrame.Angles(math.sin(t * 3) * 0.15 * (1 - a), 0, 0)
			-- tuck into the landing just before hitting the ground
			applyPose(blendPose(fallPose(t), IMPACT_POSE, smooth((a - 0.88) / 0.12)))
			-- sonic boom rings while diving
			if now >= nextBoom and a > 0.15 and a < 0.9 then
				nextBoom = now + 0.32
				ring(CFrame.new(actorCF.Position + Vector3.new(0, -2, 0)), 3, 16, 0.45, WHITE)
			end
		elseif t < T_STAND then
			local since = t - T_IMPACT
			local pose
			if t < T_PUNCH then
				-- touch down in a deep crouch, then raise the fist high
				pose = blendPose(IMPACT_POSE, WINDUP_POSE, smooth((since - 0.15) / 0.6))
			elseif t < T_HIT then
				-- PUNCH: the fist drives down, speeding up until it hits
				local a = (t - T_PUNCH) / (T_HIT - T_PUNCH)
				pose = blendPose(WINDUP_POSE, PUNCH_POSE, a * a)
			else
				-- fist in the ground; ease into the hero landing pose
				pose = blendPose(PUNCH_POSE, LAND_POSE, smooth((t - T_HIT - 0.3) / 0.6))
				-- breathing, and the head slowly lifts for the hero shot
				pose.Waist[1] += math.sin((t - T_HIT) * 2.4) * 2
				pose.Neck[1] += smooth((t - T_HERO) / 1.2) * 8
			end
			applyPose(pose)
			actorCF = landCF
			-- the glow pulses
			outline.FillTransparency = 0.55 + math.sin(since * 4) * 0.15
		else
			actorCF = landCF
			applyPose(blendPose(LAND_POSE, {}, smooth((t - T_STAND) / 0.8)))
		end
		actorRoot.CFrame = actorCF
		local actorPos = actorCF.Position

		-- flying rocks
		for _, rock in ipairs(rocks) do
			if rock.Part.Parent then
				rock.Velocity += Vector3.new(0, -60 * dt, 0)
				local nextPos = rock.Part.Position + rock.Velocity * dt
				if nextPos.Y < groundY + rock.Part.Size.Y / 2 then
					nextPos = Vector3.new(nextPos.X, groundY + rock.Part.Size.Y / 2, nextPos.Z)
					rock.Velocity = Vector3.new(rock.Velocity.X * 0.5, -rock.Velocity.Y * 0.3, rock.Velocity.Z * 0.5)
					rock.Spin *= 0.5
				end
				local s = rock.Spin * dt
				rock.Part.CFrame = CFrame.new(nextPos) * rock.Part.CFrame.Rotation * CFrame.Angles(s.X, s.Y, s.Z)
			end
		end

		-- CAMERA
		local cam
		if t < T_SKY then
			-- 1. on the ground, looking up the beam at the portal
			local a = smooth(t / T_SKY)
			local eye = ground + look * (24 - a * 5) + right * 4 + Vector3.new(0, 3, 0)
			cam = CFrame.lookAt(eye, ground + Vector3.new(0, 30 + a * 90, 0))
		elseif t < T_FALL then
			-- 2. up in the sky beside the portal, looking down the beam;
			-- then turning to you as you burst out
			local a = smooth((t - T_SKY) / (T_FALL - T_SKY))
			local orbit = a * 0.5
			local side = right * math.cos(orbit) + look * math.sin(orbit)
			local eye = Vector3.new(ground.X, portalY - 6 + a * 4, ground.Z) + side * (34 - a * 12) - look * 10
			local downBeam = ground + Vector3.new(0, FALL_HEIGHT * 0.25, 0)
			local target = downBeam:Lerp(actorPos, smooth((t - T_APPEAR) / 0.7))
			cam = CFrame.lookAt(eye, target)
		elseif t < T_IMPACT then
			-- 3. ride along: above you (the island below), then beside and
			-- below you, then from the ground as you come in
			local height = actorPos.Y - groundY
			local above = CFrame.lookAt(actorPos + right * 9 - look * 5 + Vector3.new(0, 9, 0), actorPos + Vector3.new(0, -8, 0))
			local beside = CFrame.lookAt(actorPos + right * 13 + look * 7 + Vector3.new(0, -5, 0), actorPos + Vector3.new(0, -2, 0))
			local fromGround = CFrame.lookAt(ground + look * 15 - right * 5 + Vector3.new(0, 2.2, 0), actorPos)
			local fallA = (t - T_FALL) / (T_IMPACT - T_FALL)
			cam = above:Lerp(beside, smooth((fallA - 0.15) / 0.35))
			cam = cam:Lerp(fromGround, smooth(1 - (height - 15) / 70))
		elseif t < T_CLOSEUP then
			-- 4. the impact: low wide shot from the side, whole body in view
			local a = smooth((t - T_IMPACT) / (T_CLOSEUP - T_IMPACT))
			local eye = ground + right * (7.5 - a * 1.2) + look * (3.5 + a * 1) + Vector3.new(0, 1.2, 0)
			cam = CFrame.lookAt(eye, ground + Vector3.new(0, 1.4 * rigScale, 0) + look * 0.5)
		elseif t < T_HERO then
			-- 5. close-up: the fist in the ground, cracks glowing
			local a = smooth((t - T_CLOSEUP) / (T_HERO - T_CLOSEUP))
			local fistPos = fist.Position
			local eye = fistPos + look * (2.6 - a * 0.8) + right * (2.8 - a * 0.6) + Vector3.new(0, 0.5 + a * 0.2, 0)
			cam = CFrame.lookAt(eye, fistPos + Vector3.new(0, 0.2, 0))
		elseif t < T_STAND then
			-- 6. hero shot: rises from low in front up to your face
			local a = smooth((t - T_HERO) / (T_STAND - T_HERO))
			local eye = ground + look * (8 - a * 2) + right * (2.5 - a * 1.2) + Vector3.new(0, 0.5 + a * 1.4, 0)
			cam = CFrame.lookAt(eye, Vector3.new(ground.X, headY - 0.6 + a * 0.3, ground.Z))
		else
			-- 7. swing round behind you
			local a = smooth((t - T_STAND) / (T_END - T_STAND))
			local heroEye = ground + look * 6 + right * 1.3 + Vector3.new(0, 1.9, 0)
			cam = CFrame.lookAt(heroEye, Vector3.new(ground.X, headY - 0.3, ground.Z)):Lerp(finalCam, a)
		end
		-- the ground shakes
		if now < shakeUntil then
			local strength = ((shakeUntil - now) / shakeLength) ^ 2 * shakePower
			cam = cam * CFrame.new(rand:NextNumber(-1, 1) * strength * 0.6, rand:NextNumber(-1, 1) * strength * 0.6, 0)
				* CFrame.Angles(0, 0, rand:NextNumber(-1, 1) * strength * 0.04)
			camera.FieldOfView = fov + strength * 10
		else
			camera.FieldOfView = fov
		end
		camera.CFrame = cam

		if t >= T_END then
			done = true
			connection:Disconnect()
		end
	end)

	-- (safety: never get stuck, even if a frame errors)
	while not done and os.clock() - start < T_END + 5 do
		task.wait()
	end
	connection:Disconnect()

	---------------------------------------------------------------
	-- back to the game
	---------------------------------------------------------------
	camera.CFrame = finalCam
	restoreAll()
	tween(topBar, 0.5, { Position = UDim2.fromScale(0, -0.11) })
	tween(bottomBar, 0.5, { Position = UDim2.fromScale(0, 1) })
	tween(arrival, 0.5, { TextTransparency = 1 })
	tween(arrivalStroke, 0.5, { Transparency = 1 })
	skip.Visible = false
end

local ok, err = pcall(run)
if not ok then
	warn("[IntroCutscene] failed:", err)
	if restoreAll then
		pcall(restoreAll)
	end
	camera.CameraType = Enum.CameraType.Custom
end
-- whatever happened, give the game back
if not player:GetAttribute("IntroDone") then
	finish()
end
tween(cover, 0.4, { BackgroundTransparency = 1 })
