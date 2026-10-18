-- IntroCutscene (LocalScript in StarterPlayer > StarterPlayerScripts)
-- The join cutscene (about 10 seconds), only seen by the player joining:
--   1. a thin beam of light comes down from the sky and gets wider
--   2. YOUR avatar falls down the beam, spinning, with a comet trail
--   3. you smash into the ground and land on one knee with a fist down:
--      flash, shockwave, cracks, flying rocks, dust and a camera shake
--   4. you stand up, the camera swings behind you and the game starts
-- A copy of your avatar does the falling (so nobody else sees anything
-- odd); your real character waits, hidden, on the landing spot.
-- The player can press SKIP. Settings: Config.IntroCutscene.
-- When it's over, the player gets the attribute IntroDone = true (the
-- title card and popups wait for that, see UIKit.waitForIntro).

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
local FALL_HEIGHT = SETTINGS.FallHeight or 260
local rand = Random.new()
local new, corner, label, textStroke, tween = UIKit.new, UIKit.corner, UIKit.label, UIKit.textStroke, UIKit.tween

-- timeline (seconds)
local T_BEAM = 0.3 -- beam starts
local T_FALL = 2.8 -- you start falling
local T_IMPACT = 5.9 -- you hit the ground
local T_STAND = 8.3 -- you stand up
local T_END = 9.3 -- back to the game

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
-- Poses (R15). Same idea as CombatAnim: degrees forward/twist/sideways
-- plus an optional move, added on top of each joint's normal position.
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

-- falling: arms up, legs loose, everything flutters in the wind
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
-- right fist on the ground, left arm out behind, head up
local LAND_POSE = {
	Root = P(-18, 0, 0, 0, -1.15, 0), Waist = P(-12), Neck = P(24),
	LeftHip = P(100), LeftKnee = P(-110),
	RightHip = P(-8, 0, 8), RightKnee = P(-82),
	RightShoulder = P(28, 0, -6), RightElbow = P(0),
	LeftShoulder = P(-60, 0, -50), LeftElbow = P(15), -- free arm swept out behind
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

	---------------------------------------------------------------
	-- the copy of you that does the falling
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

	-- comet trail + wind streaks while falling
	local trailA = Instance.new("Attachment")
	trailA.Position = Vector3.new(-1.2, 0, 0)
	trailA.Parent = actorRoot
	local trailB = Instance.new("Attachment")
	trailB.Position = Vector3.new(1.2, 0, 0)
	trailB.Parent = actorRoot
	local trail = Instance.new("Trail")
	trail.Attachment0 = trailA
	trail.Attachment1 = trailB
	trail.Lifetime = 0.45
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), BEAM_COLOR)
	trail.Transparency = seq(0.2, 1)
	trail.WidthScale = seq(1, 0.2)
	trail.Parent = actorRoot
	local streaks = emitter(actorRoot, {
		Texture = Config.Textures.Spark, Rate = 60, Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(60, 90),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Size = seq(0.5, 0), LightEmission = 1,
		Color = ColorSequence.new(Color3.new(1, 1, 1), BEAM_COLOR), Transparency = seq(0.1, 1),
	})
	local glow = emitter(actorRoot, {
		Texture = Config.Textures.Glow, Rate = 25, Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(0, 1),
		Size = seq(7, 3), LightEmission = 1, Color = ColorSequence.new(BEAM_COLOR), Transparency = seq(0.5, 1),
	})

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

	local rumble
	local fov = camera.FieldOfView
	local restored = false
	restoreAll = function()
		if restored then
			return
		end
		restored = true
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
		finish()
		task.delay(5, function()
			fxFolder:Destroy()
			gui:Destroy()
		end)
	end

	fxFolder.Parent = workspace
	actor.Parent = fxFolder

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
		TextSize = 20, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = true, ZIndex = 30, Parent = gui,
	}, { corner(UDim.new(0, 10)) })
	local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 10, Parent = gui })
	local arrival = label({
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.86, 0), Size = UDim2.fromOffset(900, 60),
		Text = ("✦ %s HAS ARRIVED ✦"):format(string.upper(player.DisplayName)), Font = UIKit.TitleFont, TextSize = 42,
		TextTransparency = 1, ZIndex = 12, Parent = gui,
	})
	local arrivalStroke = textStroke(3)
	arrivalStroke.Transparency = 1
	arrivalStroke.Parent = arrival
	UIKit.addAutoScale(arrival)

	---------------------------------------------------------------
	-- the beam
	---------------------------------------------------------------
	local BEAM_LENGTH = FALL_HEIGHT + 500
	local beamCF = CFrame.new(ground + Vector3.new(0, BEAM_LENGTH / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local beamOuter = part({ Name = "BeamOuter", Shape = Enum.PartType.Cylinder, Size = Vector3.new(BEAM_LENGTH, 0.2, 0.2), CFrame = beamCF,
		Color = BEAM_COLOR, Material = Enum.Material.Neon, Transparency = 0.55 })
	local beamCore = part({ Name = "BeamCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(BEAM_LENGTH, 0.08, 0.08), CFrame = beamCF,
		Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.1 })
	local groundGlow = part({ Name = "GroundGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 1, 1),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = BEAM_COLOR,
		Material = Enum.Material.Neon, Transparency = 0.4 })
	local rising = emitter(groundGlow, {
		Texture = Config.Textures.Sparkle, Rate = 0, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(8, 20),
		EmissionDirection = Enum.NormalId.Right, SpreadAngle = Vector2.new(12, 12), Size = seq(0.6, 0), LightEmission = 1,
		Color = ColorSequence.new(Color3.new(1, 1, 1), BEAM_COLOR),
	})
	local light = Instance.new("PointLight")
	light.Color = BEAM_COLOR
	light.Range = 30
	light.Brightness = 0
	light.Shadows = false
	light.Parent = groundGlow

	---------------------------------------------------------------
	-- impact effects
	---------------------------------------------------------------
	local rocks = {}
	local function impact()
		SoundFX.Play("HeavyHit", { Volume = 1 })
		SoundFX.Play("Explosion", { Volume = 0.8 })
		flash.BackgroundTransparency = 0.15
		tween(flash, 0.5, { BackgroundTransparency = 1 })
		streaks.Enabled = false
		glow.Enabled = false
		trail.Enabled = false

		-- shockwave rings
		for k = 1, 2 do
			local ring = part({ Name = "Shockwave", Size = Vector3.new(2, 0.1, 2), CFrame = CFrame.new(ground + Vector3.new(0, 0.12 + k * 0.02, 0)), Transparency = 1 })
			local decal = Instance.new("Decal")
			decal.Texture = Config.Textures.Shockwave
			decal.Face = Enum.NormalId.Top
			decal.Color3 = k == 1 and Color3.new(1, 1, 1) or BEAM_COLOR
			decal.Parent = ring
			local size = k == 1 and 46 or 30
			TweenService:Create(ring, TweenInfo.new(0.9 + k * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(size, 0.1, size) }):Play()
			TweenService:Create(decal, TweenInfo.new(0.9 + k * 0.3), { Transparency = 1 }):Play()
		end

		-- cracks in the ground
		for k = 1, 9 do
			local angle = k / 9 * math.pi * 2 + rand:NextNumber(-0.2, 0.2)
			local length = rand:NextNumber(4, 8)
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local crack = part({ Name = "Crack", Size = Vector3.new(0.35, 0.06, 0.1),
				CFrame = CFrame.lookAt(ground + Vector3.new(0, 0.08, 0) + dir * 0.6, ground + Vector3.new(0, 0.08, 0) + dir * 2),
				Color = Color3.fromRGB(25, 15, 40), Material = Enum.Material.SmoothPlastic })
			local finalCF = CFrame.lookAt(ground + Vector3.new(0, 0.08, 0) + dir * (0.6 + length / 2), ground + Vector3.new(0, 0.08, 0) + dir * 20)
			TweenService:Create(crack, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Size = Vector3.new(0.35, 0.06, length), CFrame = finalCF }):Play()
			local glowLine = part({ Name = "CrackGlow", Size = Vector3.new(0.12, 0.07, length * 0.8), CFrame = finalCF * CFrame.new(0, 0.01, 0),
				Color = BEAM_COLOR, Material = Enum.Material.Neon, Transparency = 1 })
			TweenService:Create(glowLine, TweenInfo.new(0.3), { Transparency = 0.1 }):Play()
			task.delay(3.5, function()
				TweenService:Create(glowLine, TweenInfo.new(1.2), { Transparency = 1 }):Play()
				TweenService:Create(crack, TweenInfo.new(1.2), { Transparency = 1 }):Play()
			end)
		end

		-- dust
		local dustSpot = part({ Name = "Dust", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(ground + Vector3.new(0, 0.5, 0)), Transparency = 1 })
		local dust = emitter(dustSpot, {
			Texture = Config.Textures.Smoke, Rate = 0, Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(14, 26),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(88, 88), Drag = 4, Acceleration = Vector3.new(0, -4, 0),
			Size = seq(2, 5), Transparency = seq(0.35, 1), Color = ColorSequence.new(Color3.fromRGB(210, 200, 230)),
			RotSpeed = NumberRange.new(-90, 90), Rotation = NumberRange.new(0, 360),
		})
		dust:Emit(45)
		local sparks = emitter(dustSpot, {
			Texture = Config.Textures.Spark, Rate = 0, Lifetime = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(25, 45),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -50, 0),
			Size = seq(0.5, 0), LightEmission = 1, Color = ColorSequence.new(Color3.new(1, 1, 1), BEAM_COLOR),
		})
		sparks:Emit(60)

		-- rocks flying up and bouncing down
		for _ = 1, 12 do
			local angle = rand:NextNumber(0, math.pi * 2)
			local size = rand:NextNumber(0.35, 0.9)
			local rock = part({ Name = "Rock", Size = Vector3.new(size, size * 0.8, size), Color = Color3.fromRGB(110, 95, 140),
				Material = Enum.Material.Slate, CFrame = CFrame.new(ground + Vector3.new(math.cos(angle) * 1.5, 0.3, math.sin(angle) * 1.5)) })
			table.insert(rocks, {
				Part = rock,
				Velocity = Vector3.new(math.cos(angle) * rand:NextNumber(6, 16), rand:NextNumber(14, 26), math.sin(angle) * rand:NextNumber(6, 16)),
				Spin = Vector3.new(rand:NextNumber(-8, 8), rand:NextNumber(-8, 8), rand:NextNumber(-8, 8)),
			})
		end

		-- the beam bursts wide, then fades away
		TweenService:Create(beamOuter, TweenInfo.new(0.25), { Size = Vector3.new(BEAM_LENGTH, 16, 16), Transparency = 0.75 }):Play()
		task.delay(0.3, function()
			TweenService:Create(beamOuter, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { Size = Vector3.new(BEAM_LENGTH, 0.1, 0.1), Transparency = 1 }):Play()
			TweenService:Create(beamCore, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { Size = Vector3.new(BEAM_LENGTH, 0.05, 0.05), Transparency = 1 }):Play()
			TweenService:Create(groundGlow, TweenInfo.new(2), { Transparency = 1 }):Play()
			TweenService:Create(light, TweenInfo.new(2), { Brightness = 0 }):Play()
		end)
		rising.Enabled = false

		-- the name
		tween(arrival, 0.5, { TextTransparency = 0 })
		tween(arrivalStroke, 0.5, { Transparency = 0 })
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
	local stage = 0
	local shakeUntil = 0
	local finalCam = CFrame.lookAt(ground - look * 12 + Vector3.new(0, 5.5, 0), ground + Vector3.new(0, 2.5, 0))

	local done = false
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local dt = now - last
		last = now
		local t = now - start
		if skipped then
			t = T_END
			stage = 3
		end

		-- sounds & one-shot moments
		if stage == 0 and t >= T_BEAM then
			stage = 1
			SoundFX.Play("IntroSwell")
			rising.Rate = 30
		elseif stage == 1 and t >= T_FALL then
			stage = 2
			SoundFX.Riser(T_IMPACT - T_FALL, { Volume = 0.8 })
			SoundFX.Play("Whoosh", { Volume = 0.8 })
		elseif stage == 2 and t >= T_IMPACT then
			stage = 3
			shakeUntil = now + 1.3
			if not skipped then
				impact()
			end
		end

		-- the beam grows
		local beamAlpha = smooth((t - T_BEAM) / 2.4)
		if t < T_IMPACT then
			local pulse = 1 + math.sin(t * 9) * 0.06
			local width = (0.2 + beamAlpha * 7.5) * pulse
			beamOuter.Size = Vector3.new(BEAM_LENGTH, width, width)
			beamCore.Size = Vector3.new(BEAM_LENGTH, width * 0.35, width * 0.35)
			beamOuter.Transparency = 0.7 - beamAlpha * 0.35
			groundGlow.Size = Vector3.new(0.12, 2 + beamAlpha * 12, 2 + beamAlpha * 12)
			light.Brightness = beamAlpha * 3
		end

		-- where the falling you is, and the pose
		local actorCF
		if t < T_FALL then
			actorCF = CFrame.new(ground + Vector3.new(0, FALL_HEIGHT + 40, 0)) * landCF.Rotation
			applyPose(fallPose(t))
		elseif t < T_IMPACT then
			local a = (t - T_FALL) / (T_IMPACT - T_FALL)
			local height = FALL_HEIGHT * (1 - a * a)
			local spin = (1 - a) ^ 2 * math.pi * 4
			actorCF = CFrame.new(landCF.Position + Vector3.new(0, height, 0)) * landCF.Rotation * CFrame.Angles(0, spin, 0)
				* CFrame.Angles(math.sin(t * 3) * 0.15 * (1 - a), 0, 0)
			-- tuck into the landing just before hitting the ground
			local tuck = smooth((a - 0.9) / 0.1)
			applyPose(blendPose(fallPose(t), LAND_POSE, tuck))
		elseif t < T_STAND then
			-- small bounce from the impact
			local since = t - T_IMPACT
			local dip = math.exp(-since * 9) * math.sin(since * 25) * 0.25
			actorCF = landCF * CFrame.new(0, -math.abs(dip), 0)
			applyPose(LAND_POSE)
		else
			actorCF = landCF
			applyPose(blendPose(LAND_POSE, {}, smooth((t - T_STAND) / 0.7)))
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

		-- camera
		local cam
		if t < T_FALL then
			-- on the ground, looking up the beam
			local a = smooth(t / T_FALL)
			local eye = ground + look * (24 - a * 4) + right * 4 + Vector3.new(0, 3, 0)
			cam = CFrame.lookAt(eye, ground + Vector3.new(0, 25 + a * 60, 0))
		elseif t < T_IMPACT then
			local height = actorPos.Y - groundY
			-- up high: fly next to you; close to the ground: watch from the ground
			local follow = CFrame.lookAt(actorPos + right * 13 + look * 7 + Vector3.new(0, -5, 0), actorPos + Vector3.new(0, -2, 0))
			local fromGround = CFrame.lookAt(ground + look * 15 - right * 5 + Vector3.new(0, 2.2, 0), actorPos)
			cam = follow:Lerp(fromGround, smooth(1 - (height - 15) / 70))
		elseif t < T_STAND then
			-- low and in front: the hero shot
			local a = smooth((t - T_IMPACT) / (T_STAND - T_IMPACT))
			local eye = ground + look * (9.5 - a * 2.2) + right * 3.2 + Vector3.new(0, 1.4 + a * 0.4, 0)
			cam = CFrame.lookAt(eye, ground + Vector3.new(0, 1.3 * rigScale, 0))
		else
			-- swing round behind you
			local a = smooth((t - T_STAND) / (T_END - T_STAND))
			local eye = ground + look * 7.3 + right * 3.2 + Vector3.new(0, 1.8, 0)
			cam = CFrame.lookAt(eye, ground + Vector3.new(0, 1.3 * rigScale, 0)):Lerp(finalCam, a)
		end
		-- the ground shakes
		if now < shakeUntil then
			local strength = ((shakeUntil - now) / 1.3) ^ 2
			cam = cam * CFrame.new(rand:NextNumber(-1, 1) * strength * 0.9, rand:NextNumber(-1, 1) * strength * 0.9, 0)
				* CFrame.Angles(0, 0, rand:NextNumber(-1, 1) * strength * 0.05)
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
	while not done and os.clock() - start < T_END + 4 do
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
