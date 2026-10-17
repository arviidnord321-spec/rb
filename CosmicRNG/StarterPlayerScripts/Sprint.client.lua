-- Sprint (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Hold SHIFT (or tap RUN on phones) to sprint. Uses stamina, which
-- refills when you stop. While sprinting: wider view, speed lines and
-- dust at your feet. The server sets the real speed (Movement script).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))

local MOVE = Config.Movement
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local SprintRemote = remotes:WaitForChild("Sprint", 60)
if not SprintRemote then
	warn("[Sprint] remote missing")
	return
end

local THEME = UIKit.Theme
local new, corner, tween, label = UIKit.new, UIKit.corner, UIKit.tween, UIKit.label

local wantSprint = false
local sprinting = false
local stamina = MOVE.MaxStamina
local lastSprintTime = 0
local exhausted = false
local baseFov = camera.FieldOfView

---------------------------------------------------------------------
-- UI: stamina bar (bottom left) + speed lines + mobile RUN button
---------------------------------------------------------------------
local gui = UIKit.screen("CosmicSprint", 2)

local barHolder = new("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -18),
	Size = UDim2.fromOffset(230, 34),
	BackgroundTransparency = 1,
	Parent = gui,
})
UIKit.addAutoScale(barHolder)
local barLabel = label({
	Size = UDim2.new(1, 0, 0, 16), Text = "⚡ STAMINA  (hold Shift)", TextSize = 13, Font = UIKit.TitleFont,
	TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, Parent = barHolder,
})
local barBack = new("Frame", {
	Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 12),
	BackgroundColor3 = THEME.Panel, BackgroundTransparency = 1, Parent = barHolder,
}, { corner(UDim.new(1, 0)) })
local barFill = new("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(110, 230, 255),
	BackgroundTransparency = 1, BorderSizePixel = 0, Parent = barBack,
}, { corner(UDim.new(1, 0)), UIKit.gradient(Color3.fromRGB(120, 240, 255), Color3.fromRGB(150, 110, 255), 0) })

local barVisible = false
local function setBarVisible(visible)
	if visible == barVisible then
		return
	end
	barVisible = visible
	local t = visible and 0 or 1
	tween(barLabel, 0.3, { TextTransparency = t })
	tween(barBack, 0.3, { BackgroundTransparency = visible and 0.3 or 1 })
	tween(barFill, 0.3, { BackgroundTransparency = t })
end

-- speed lines: thin streaks sliding past the edges of the screen
local lines = {}
for i = 1, 14 do
	local left = i % 2 == 0
	local line = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(left and 0.04 or 0.96, (i / 15)),
		Size = UDim2.fromOffset(160, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
	})
	table.insert(lines, { Frame = line, Left = left, Phase = math.random() })
end

-- mobile RUN button
local runButton
if UserInputService.TouchEnabled then
	runButton = new("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -60),
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.15,
		Text = "🏃\nRUN",
		Font = UIKit.TitleFont,
		TextSize = 18,
		TextColor3 = THEME.Text,
		AutoButtonColor = false,
		Parent = gui,
	}, { corner(UDim.new(1, 0)), UIKit.stroke(THEME.Accent2, 2.5, 0) })
	runButton.Activated:Connect(function()
		wantSprint = not wantSprint
		runButton.BackgroundColor3 = wantSprint and Color3.fromRGB(40, 120, 150) or THEME.Panel
	end)
end

---------------------------------------------------------------------
-- Dust at your feet while sprinting (only on your screen)
---------------------------------------------------------------------
local dust
local function attachDust(character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "SprintDust"
	attachment.Position = Vector3.new(0, -2.8, 0)
	attachment.Parent = root
	dust = Instance.new("ParticleEmitter")
	dust.Texture = Config.Textures.Smoke
	dust.Rate = 30
	dust.Enabled = false
	dust.Lifetime = NumberRange.new(0.3, 0.6)
	dust.Speed = NumberRange.new(2, 4)
	dust.SpreadAngle = Vector2.new(40, 40)
	dust.EmissionDirection = Enum.NormalId.Back
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	dust.Color = ColorSequence.new(Color3.fromRGB(200, 190, 255))
	dust.LightEmission = 0.4
	dust.Parent = attachment
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "SprintSparks"
	sparks.Texture = Config.Textures.Sparkle
	sparks.Rate = 18
	sparks.Enabled = false
	sparks.Lifetime = NumberRange.new(0.3, 0.5)
	sparks.Speed = NumberRange.new(1, 3)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Color = ColorSequence.new(Color3.fromRGB(140, 230, 255))
	sparks.Parent = attachment
end
player.CharacterAdded:Connect(function(character)
	sprinting = false
	task.spawn(attachDust, character)
end)
if player.Character then
	task.spawn(attachDust, player.Character)
end

---------------------------------------------------------------------
-- Input
---------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		wantSprint = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		wantSprint = false
	end
end)

---------------------------------------------------------------------
-- Every frame: stamina, speed, effects
---------------------------------------------------------------------
local function setSprinting(value, humanoid)
	if value == sprinting then
		return
	end
	sprinting = value
	SprintRemote:FireServer(value)
	-- feel it right away (the server sets the same value)
	local character = player.Character
	if humanoid and character and not character:GetAttribute("InDuel") then
		humanoid.WalkSpeed = value and MOVE.SprintSpeed or MOVE.WalkSpeed
	end
	tween(camera, 0.35, { FieldOfView = value and baseFov + 9 or baseFov }, Enum.EasingStyle.Sine)
	if dust and dust.Parent then
		dust.Enabled = value
		local sparks = dust.Parent:FindFirstChild("SprintSparks")
		if sparks then
			sparks.Enabled = value
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1 and humanoid.Health > 0
		and humanoid.WalkSpeed > 0 -- frozen / stunned / in a cutscene = no sprint

	if exhausted and stamina >= MOVE.MaxStamina * 0.25 then
		exhausted = false
	end
	local shouldSprint = wantSprint and moving and not exhausted and stamina > 0
	setSprinting(shouldSprint, humanoid)

	if sprinting then
		stamina = math.max(0, stamina - MOVE.StaminaDrain * dt)
		lastSprintTime = os.clock()
		if stamina <= 0 then
			exhausted = true
		end
	elseif os.clock() - lastSprintTime > MOVE.RegenDelay then
		stamina = math.min(MOVE.MaxStamina, stamina + MOVE.StaminaRegen * dt)
	end

	local fraction = stamina / MOVE.MaxStamina
	barFill.Size = UDim2.fromScale(fraction, 1)
	setBarVisible(fraction < 0.999 or sprinting)
	barLabel.TextColor3 = exhausted and THEME.Bad or THEME.Text

	-- speed lines
	for _, l in ipairs(lines) do
		if sprinting then
			l.Phase = (l.Phase + dt * 2.2) % 1
			local x = l.Left and (0.02 + l.Phase * 0.12) or (0.98 - l.Phase * 0.12)
			l.Frame.Position = UDim2.fromScale(x, l.Frame.Position.Y.Scale)
			l.Frame.BackgroundTransparency = 0.55 + l.Phase * 0.45
		elseif l.Frame.BackgroundTransparency < 1 then
			l.Frame.BackgroundTransparency = 1
		end
	end
end)
