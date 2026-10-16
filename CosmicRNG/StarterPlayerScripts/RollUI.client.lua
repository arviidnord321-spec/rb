-- RollUI (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Builds the whole roll interface in code: roll button, auto roll,
-- roll animation, rare cutscenes, inventory and announcements.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))

local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local RollRemote = remotes:WaitForChild("Roll")
local GetDataRemote = remotes:WaitForChild("GetData")
local EquipRemote = remotes:WaitForChild("Equip")
local DataUpdatedRemote = remotes:WaitForChild("DataUpdated")
local AnnounceRemote = remotes:WaitForChild("Announce")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rand = Random.new()

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local data = { Rolls = 0, Inventory = {}, Equipped = "", BestChance = 0 }
local rolling = false
local autoRolling = false
local inventoryOpen = false
local refreshInventory -- defined later

---------------------------------------------------------------------
-- Theme + UI helpers
---------------------------------------------------------------------
local THEME = {
	Panel = Color3.fromRGB(18, 14, 34),
	PanelLight = Color3.fromRGB(34, 28, 62),
	Accent = Color3.fromRGB(150, 110, 255),
	Accent2 = Color3.fromRGB(80, 190, 255),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(190, 180, 225),
	Good = Color3.fromRGB(90, 220, 130),
	Bad = Color3.fromRGB(240, 80, 100),
}
local TITLE_FONT = Enum.Font.FredokaOne
local BODY_FONT = Enum.Font.GothamBold

local function new(className, props, children)
	local inst = Instance.new(className)
	local parent
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(radius)
	return new("UICorner", { CornerRadius = radius or UDim.new(0, 12) })
end

local function stroke(color, thickness, transparency)
	return new("UIStroke", {
		Name = "Border",
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function textStroke(thickness)
	return new("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

local function gradient(c1, c2, rotation)
	return new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rotation or 90 })
end

local function tween(inst, duration, props, style, direction)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

local function label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = BODY_FONT,
		TextColor3 = THEME.Text,
		TextScaled = false,
		TextSize = 18,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return new("TextLabel", defaults)
end

-- Hover/press bounce for any button
local function addButtonFeel(button)
	local scale = button:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.06 })
	end)
	button.MouseLeave:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		tween(scale, 0.06, { Scale = 0.92 })
	end)
	button.MouseButton1Up:Connect(function()
		tween(scale, 0.18, { Scale = 1.06 }, Enum.EasingStyle.Back)
	end)
end

-- Shrinks UI on small screens (phones)
local function addAutoScale(guiObject, baseHeight)
	local scale = new("UIScale", { Parent = guiObject })
	local function update()
		scale.Scale = math.clamp(camera.ViewportSize.Y / (baseHeight or 820), 0.55, 1.1)
	end
	update()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	return scale
end

local function playSound(id, volume)
	if not id or id == "" then
		return
	end
	local sound = new("Sound", { SoundId = id, Volume = volume or 0.5, Parent = SoundService })
	sound:Play()
	Debris:AddItem(sound, 6)
end

local function tierColor(aura)
	return AuraData.Tiers[aura.Tier].Color
end

---------------------------------------------------------------------
-- SCREEN
---------------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "CosmicUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Layers (higher ZIndex = drawn on top)
local dimLayer = new("Frame", {
	Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1, ZIndex = 2, Parent = gui,
})
local raysLayer = new("Frame", {
	Name = "Rays", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3,
	Visible = false, Parent = gui,
})
local particleLayer = new("Frame", {
	Name = "UIParticles", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 7, Parent = gui,
})
local flashLayer = new("Frame", {
	Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1, ZIndex = 10, Parent = gui,
})

---------------------------------------------------------------------
-- TOP-LEFT STATS
---------------------------------------------------------------------
local statsPanel = new("Frame", {
	Name = "Stats",
	Position = UDim2.new(0, 16, 0, 64),
	Size = UDim2.fromOffset(250, 78),
	BackgroundColor3 = THEME.Panel,
	BackgroundTransparency = 0.25,
	ZIndex = 5,
	Parent = gui,
}, { corner(), stroke(THEME.Accent, 1.5, 0.4) })
addAutoScale(statsPanel)
local rollsLabel = label({
	Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 28),
	Text = "🎲 Rolls: 0", TextXAlignment = Enum.TextXAlignment.Left, TextSize = 20,
	Font = TITLE_FONT, ZIndex = 5, Parent = statsPanel,
})
local bestLabel = label({
	Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 26),
	Text = "⭐ Best: none yet", TextXAlignment = Enum.TextXAlignment.Left, TextSize = 15,
	TextColor3 = THEME.SubText, ZIndex = 5, RichText = true, TextTruncate = Enum.TextTruncate.AtEnd,
	Parent = statsPanel,
})

---------------------------------------------------------------------
-- BOTTOM ROLL BAR
---------------------------------------------------------------------
local rollBar = new("Frame", {
	Name = "RollBar",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(530, 120),
	BackgroundTransparency = 1,
	ZIndex = 5,
	Parent = gui,
})
addAutoScale(rollBar)

local infoLabel = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 0, 0, 26),
	Text = "", RichText = true, TextSize = 18, Font = TITLE_FONT, ZIndex = 5, Parent = rollBar,
})
textStroke(1.5).Parent = infoLabel

local rollButton = new("TextButton", {
	Name = "RollButton",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, 0),
	Size = UDim2.fromOffset(230, 80),
	BackgroundColor3 = Color3.new(1, 1, 1),
	AutoButtonColor = false,
	Text = "ROLL",
	Font = TITLE_FONT,
	TextSize = 44,
	TextColor3 = THEME.Text,
	ZIndex = 5,
	Parent = rollBar,
}, { corner(UDim.new(0, 18)), stroke(Color3.new(1, 1, 1), 3, 0.2), textStroke(2.5) })
local rollGradient = new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 90, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 140, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 220, 255)),
	}),
	Parent = rollButton,
})
addButtonFeel(rollButton)

local function sideButton(name, text, anchorX, offsetX)
	local button = new("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(anchorX, 1),
		Position = UDim2.new(0.5, offsetX, 1, -10),
		Size = UDim2.fromOffset(135, 60),
		BackgroundColor3 = THEME.PanelLight,
		AutoButtonColor = false,
		Text = text,
		RichText = true,
		Font = TITLE_FONT,
		TextSize = 20,
		TextColor3 = THEME.Text,
		ZIndex = 5,
		Parent = rollBar,
	}, { corner(UDim.new(0, 14)), stroke(THEME.Accent, 2, 0.2), textStroke(1.5) })
	addButtonFeel(button)
	return button
end

local autoButton = sideButton("AutoButton", "", 1, -128)
local aurasButton = sideButton("AurasButton", "✦ AURAS", 0, 128)

---------------------------------------------------------------------
-- CENTER REVEAL DISPLAY
---------------------------------------------------------------------
local reveal = new("Frame", {
	Name = "Reveal",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.fromOffset(700, 200),
	BackgroundTransparency = 1,
	ZIndex = 6,
	Visible = false,
	Parent = gui,
})
addAutoScale(reveal)
-- The reveal frame scales to the screen; popHolder inside it does the "pop".
local popHolder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6, Parent = reveal })
local popScale = new("UIScale", { Parent = popHolder })

local tierLabel = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 0, 0, 30),
	Text = "", Font = TITLE_FONT, TextSize = 26, ZIndex = 6, Parent = popHolder,
})
textStroke(2).Parent = tierLabel
local nameLabel = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.new(1, 0, 0, 96),
	Text = "", Font = TITLE_FONT, TextSize = 84, ZIndex = 6, Parent = popHolder,
})
textStroke(3.5).Parent = nameLabel
local nameGradient = new("UIGradient", { Parent = nameLabel })
local chanceLabel = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 126), Size = UDim2.new(1, 0, 0, 34),
	Text = "", Font = TITLE_FONT, TextSize = 30, ZIndex = 6, Parent = popHolder,
})
textStroke(2).Parent = chanceLabel
local badgeLabel = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 166), Size = UDim2.fromOffset(170, 30),
	Text = "", Font = TITLE_FONT, TextSize = 20, ZIndex = 6, BackgroundTransparency = 0,
	BackgroundColor3 = THEME.Good, Visible = false, Parent = popHolder,
})
corner(UDim.new(1, 0)).Parent = badgeLabel
textStroke(1.5).Parent = badgeLabel

local revealTexts = { tierLabel, nameLabel, chanceLabel }

local function setRevealAura(aura)
	local c1, c2 = aura.Colors[1], aura.Colors[2]
	-- very dark colors are unreadable as text, so brighten them
	local function readable(c)
		local h, s, v = c:ToHSV()
		return Color3.fromHSV(h, s, math.max(v, 0.55))
	end
	nameLabel.Text = aura.Name
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameGradient.Color = ColorSequence.new(readable(c1), readable(c2))
	chanceLabel.Text = AuraData.FormatChance(aura.Chance)
	chanceLabel.TextColor3 = THEME.SubText
	tierLabel.Text = string.upper(aura.Tier)
	tierLabel.TextColor3 = tierColor(aura)
end

local function setRevealTransparency(value, duration)
	for _, text in ipairs(revealTexts) do
		if duration then
			tween(text, duration, { TextTransparency = value })
		else
			text.TextTransparency = value
		end
		local s = text:FindFirstChildOfClass("UIStroke")
		if s then
			if duration then
				tween(s, duration, { Transparency = math.max(value, 0.3) })
			else
				s.Transparency = math.max(value, 0.3)
			end
		end
	end
end

---------------------------------------------------------------------
-- CUTSCENE RAYS
---------------------------------------------------------------------
local rays = {}
for i = 1, 8 do
	local ray = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(0, 46, 2.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Rotation = (i - 1) * (180 / 8),
		ZIndex = 3,
		Parent = raysLayer,
	})
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 0.55),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(0.58, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = ray,
	})
	table.insert(rays, ray)
end

local cutsceneHolder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(900, 60),
	BackgroundTransparency = 1, ZIndex = 6, Parent = gui,
})
addAutoScale(cutsceneHolder)
local cutsceneText = label({
	Size = UDim2.fromScale(1, 1), Text = "", Font = TITLE_FONT, TextSize = 40, ZIndex = 6,
	TextTransparency = 1, Parent = cutsceneHolder,
})
local cutsceneStroke = textStroke(3)
cutsceneStroke.Transparency = 1
cutsceneStroke.Parent = cutsceneText
local cutsceneScale = new("UIScale", { Parent = cutsceneText })

---------------------------------------------------------------------
-- ANNOUNCEMENT BANNER + TOASTS
---------------------------------------------------------------------
local banner = new("Frame", {
	Name = "Banner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -90),
	Size = UDim2.fromOffset(620, 58),
	BackgroundColor3 = THEME.Panel,
	BackgroundTransparency = 0.1,
	ZIndex = 9,
	Parent = gui,
}, { corner(UDim.new(0, 14)) })
local bannerStroke = stroke(THEME.Accent, 2.5, 0)
bannerStroke.Parent = banner
addAutoScale(banner)
local bannerLabel = label({
	Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), RichText = true,
	Text = "", Font = TITLE_FONT, TextSize = 22, ZIndex = 9, TextWrapped = true, Parent = banner,
})

local toast = label({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -170), Size = UDim2.fromOffset(600, 30),
	Text = "", Font = TITLE_FONT, TextSize = 22, ZIndex = 9, TextTransparency = 1, Parent = gui,
})
local toastStroke = textStroke(2)
toastStroke.Parent = toast
local toastToken = 0
local function showToast(text, color)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.TextColor3 = color or THEME.Text
	toast.TextTransparency = 0
	toastStroke.Transparency = 0.3
	task.delay(2.5, function()
		if token == toastToken then
			tween(toast, 0.4, { TextTransparency = 1 })
			tween(toastStroke, 0.4, { Transparency = 1 })
		end
	end)
end

---------------------------------------------------------------------
-- EFFECTS: camera shake, FOV punch, flash, UI particle bursts
---------------------------------------------------------------------
local shake = 0
local shaking = false
RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if shake > 0.01 then
		shaking = true
		local m = shake * 0.35
		if humanoid then
			humanoid.CameraOffset = Vector3.new(rand:NextNumber(-m, m), rand:NextNumber(-m, m), rand:NextNumber(-m, m))
		end
		shake = math.max(0, shake - dt * 2.5)
	elseif shaking then
		shaking = false
		if humanoid then
			humanoid.CameraOffset = Vector3.zero
		end
	end
end)

local function addShake(amount)
	shake = math.max(shake, amount)
end

local baseFov = camera.FieldOfView
local function fovPunch(amount)
	camera.FieldOfView = baseFov + amount
	tween(camera, 0.6, { FieldOfView = baseFov }, Enum.EasingStyle.Quint)
end

local function flash(strength, duration)
	flashLayer.BackgroundTransparency = 1 - strength
	tween(flashLayer, duration or 0.5, { BackgroundTransparency = 1 })
end

local STAR_GLYPHS = { "✦", "✧", "★", "✶" }
local function uiBurst(colors, count, power, origin)
	origin = origin or Vector2.new(0.5, 0.4)
	power = power or 1
	for _ = 1, count do
		local angle = rand:NextNumber(0, math.pi * 2)
		local dist = rand:NextNumber(120, 380) * power
		local color = colors[rand:NextInteger(1, #colors)]
		local startPos = UDim2.fromScale(origin.X, origin.Y)
		local endPos = UDim2.new(origin.X, math.cos(angle) * dist, origin.Y, math.sin(angle) * dist)
		local duration = rand:NextNumber(0.6, 1.2)
		local piece
		if rand:NextNumber() < 0.5 then
			local size = rand:NextInteger(6, 14)
			piece = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = startPos, Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 7, Parent = particleLayer,
			}, { corner(UDim.new(1, 0)) })
			tween(piece, duration, { Position = endPos, Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, Enum.EasingStyle.Quart)
		else
			piece = label({
				AnchorPoint = Vector2.new(0.5, 0.5), Position = startPos, Size = UDim2.fromOffset(40, 40),
				Text = STAR_GLYPHS[rand:NextInteger(1, #STAR_GLYPHS)], TextColor3 = color,
				TextSize = rand:NextInteger(18, 36), Font = Enum.Font.GothamBlack, ZIndex = 7,
				Rotation = rand:NextNumber(0, 360), Parent = particleLayer,
			})
			tween(piece, duration, {
				Position = endPos, TextTransparency = 1, Rotation = piece.Rotation + rand:NextNumber(-270, 270),
			}, Enum.EasingStyle.Quart)
		end
		Debris:AddItem(piece, duration + 0.1)
	end
end

---------------------------------------------------------------------
-- INFO LINE (luck + lucky roll counter)
---------------------------------------------------------------------
local function currentLuck()
	local luck = Config.BaseLuck
	if player:GetAttribute("Pass_DoubleLuck") then
		luck *= 2
	end
	luck *= (player:GetAttribute("BonusLuck") or 1)
	return luck
end

local function formatLuck(n)
	if n == math.floor(n) then
		return tostring(n)
	end
	return string.format("%.1f", n)
end

local function updateInfo()
	local every = Config.LuckyRollEvery
	local untilLucky = every - (data.Rolls % every)
	local luckText = ("<font color='#9fe8ff'>🍀 Luck x%s</font>"):format(formatLuck(currentLuck()))
	local luckyText
	if untilLucky == 1 then
		luckyText = ("<font color='#ffd76a'>✨ NEXT ROLL IS LUCKY (x%s)</font>"):format(formatLuck(Config.LuckyRollMultiplier))
	else
		luckyText = ("<font color='#c9bff0'>Lucky roll in %d</font>"):format(untilLucky)
	end
	infoLabel.Text = luckText .. "   •   " .. luckyText
end

local function updateStats()
	rollsLabel.Text = "🎲 Rolls: " .. AuraData.FormatNumber(data.Rolls)
	local best
	for name, count in pairs(data.Inventory) do
		local aura = AuraData.Get(name)
		if aura and count > 0 and (not best or aura.Chance > best.Chance) then
			best = aura
		end
	end
	if best then
		bestLabel.Text = ("⭐ Best: <font color='#%s'>%s</font> (%s)"):format(
			tierColor(best):ToHex(), best.Name, AuraData.FormatChance(best.Chance))
	else
		bestLabel.Text = "⭐ Best: none yet"
	end
	updateInfo()
end

---------------------------------------------------------------------
-- AUTO ROLL BUTTON
---------------------------------------------------------------------
local function ownsAutoRoll()
	return player:GetAttribute("Pass_AutoRoll") == true
end

local function updateAutoButton()
	local autoStroke = autoButton:FindFirstChild("Border")
	if not ownsAutoRoll() then
		autoButton.Text = "🔒 AUTO\n<font size='13'>Game Pass</font>"
		autoButton.BackgroundColor3 = THEME.PanelLight
		autoStroke.Color = Color3.fromRGB(255, 200, 70)
	elseif autoRolling then
		autoButton.Text = "AUTO: ON"
		autoButton.BackgroundColor3 = Color3.fromRGB(40, 120, 70)
		autoStroke.Color = THEME.Good
	else
		autoButton.Text = "AUTO: OFF"
		autoButton.BackgroundColor3 = THEME.PanelLight
		autoStroke.Color = THEME.Accent
	end
end

---------------------------------------------------------------------
-- RARE ROLL CUTSCENE
---------------------------------------------------------------------
local raysConnection
local function playCutscene(aura)
	local order = AuraData.Tiers[aura.Tier].Order
	local duration = (order >= 7) and 3.6 or (order >= 6) and 2.8 or 2
	local color = tierColor(aura)

	-- darken + spinning light rays
	tween(dimLayer, 0.5, { BackgroundTransparency = 0.25 })
	raysLayer.Visible = true
	for _, ray in ipairs(rays) do
		ray.BackgroundColor3 = aura.Colors[1]
		ray.BackgroundTransparency = 1
		tween(ray, 0.6, { BackgroundTransparency = 0 })
	end
	if raysConnection then
		raysConnection:Disconnect()
	end
	raysConnection = RunService.RenderStepped:Connect(function(dt)
		for i, ray in ipairs(rays) do
			ray.Rotation += dt * ((i % 2 == 0) and 25 or 40)
		end
	end)

	cutsceneText.Text = (order >= 7) and "THE UNIVERSE TREMBLES..."
		or (order >= 6) and "Something MYTHIC approaches..."
		or "A LEGENDARY aura approaches..."
	cutsceneText.TextColor3 = color
	tween(cutsceneText, 0.4, { TextTransparency = 0 })
	tween(cutsceneStroke, 0.4, { Transparency = 0.3 })

	-- heartbeat pulses with growing shake
	local beats = math.floor(duration / 0.5)
	for i = 1, beats do
		cutsceneScale.Scale = 1.15
		tween(cutsceneScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Quad)
		addShake(0.3 + i / beats * 1.2)
		uiBurst(aura.Colors, 6, 0.6)
		playSound(Config.Sounds.RollTick, 0.4)
		task.wait(0.5)
	end

	tween(cutsceneText, 0.2, { TextTransparency = 1 })
	tween(cutsceneStroke, 0.2, { Transparency = 1 })
	flash(1, 0.9)
	addShake(2.5)
	tween(dimLayer, 1.2, { BackgroundTransparency = 1 })
	for _, ray in ipairs(rays) do
		tween(ray, 1.2, { BackgroundTransparency = 1 })
	end
	task.delay(1.3, function()
		if raysConnection then
			raysConnection:Disconnect()
			raysConnection = nil
		end
		raysLayer.Visible = false
	end)
end

---------------------------------------------------------------------
-- ROLL ANIMATION
---------------------------------------------------------------------
local function playRollAnimation(result, fast)
	local final = AuraData.Get(result.Aura)
	local order = AuraData.Tiers[final.Tier].Order

	reveal.Visible = true
	badgeLabel.Visible = false
	setRevealTransparency(0)
	reveal.Position = UDim2.fromScale(0.5, 0.4)

	if result.Lucky then
		showToast("✨ LUCKY ROLL! x" .. formatLuck(Config.LuckyRollMultiplier) .. " luck", Color3.fromRGB(255, 215, 106))
	end

	-- Spin through random auras, slowing down at the end
	local steps = fast and 7 or 16
	local showLuck = math.max(result.Luck or 1, 1) * 40 -- show some exciting names while spinning
	for i = 1, steps do
		local fake = AuraData.RollRandom(showLuck, rand)
		setRevealAura(fake)
		popScale.Scale = 1.12
		tween(popScale, 0.08, { Scale = 1 })
		playSound(Config.Sounds.RollTick, 0.3)
		local progress = i / steps
		task.wait((fast and 0.03 or 0.04) + progress ^ 3 * (fast and 0.12 or 0.28))
	end

	-- Big rolls get a cutscene first
	if final.Chance >= Config.CutsceneAtChance then
		setRevealTransparency(1)
		playCutscene(final)
		setRevealTransparency(0)
	end

	-- REVEAL
	setRevealAura(final)
	popScale.Scale = 1.7
	tween(popScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	local burstCount = 10 + order * 8
	uiBurst({ final.Colors[1], final.Colors[2], tierColor(final) }, burstCount, 0.7 + order * 0.15)
	if order >= 3 then
		flash(math.min(0.15 + order * 0.08, 0.7), 0.4)
		addShake(0.2 + order * 0.2)
		fovPunch(order * 1.5)
	end
	if order >= 5 then
		playSound(Config.Sounds.RevealLegendary, 0.7)
	elseif order >= 3 then
		playSound(Config.Sounds.RevealRare, 0.6)
	else
		playSound(Config.Sounds.RevealCommon, 0.5)
	end

	if result.IsNewBest and data.Rolls > 1 then
		badgeLabel.Text = "NEW BEST!"
		badgeLabel.BackgroundColor3 = Color3.fromRGB(255, 190, 60)
		badgeLabel.Visible = true
	elseif result.IsFirstTime then
		badgeLabel.Text = "NEW!"
		badgeLabel.BackgroundColor3 = THEME.Good
		badgeLabel.Visible = true
	end

	-- hold, then float up and fade
	task.wait(fast and 0.55 or (1.1 + order * 0.15))
	badgeLabel.Visible = false
	tween(reveal, 0.35, { Position = UDim2.fromScale(0.5, 0.36) })
	setRevealTransparency(1, 0.35)
	task.wait(0.35)
	reveal.Visible = false
end

---------------------------------------------------------------------
-- ROLLING
---------------------------------------------------------------------
local function doRoll(fast)
	if rolling then
		return
	end
	rolling = true

	local ok, result = pcall(function()
		return RollRemote:InvokeServer()
	end)
	if not ok or type(result) ~= "table" or result.Error then
		rolling = false
		if ok and type(result) == "table" and result.Error == "Loading" then
			showToast("Loading your data...", THEME.SubText)
		end
		task.wait(0.2)
		return
	end

	data.Rolls = result.Rolls
	data.Inventory = result.Inventory or data.Inventory
	updateInfo()

	playRollAnimation(result, fast)

	-- Equip automatically when you beat your best aura
	local final = AuraData.Get(result.Aura)
	if result.IsNewBest or data.Equipped == "" then
		data.Equipped = final.Name
		EquipRemote:FireServer(final.Name)
	end
	if final.Chance > data.BestChance then
		data.BestChance = final.Chance
	end

	updateStats()
	if inventoryOpen then
		refreshInventory()
	end
	rolling = false
end

rollButton.MouseButton1Click:Connect(function()
	if not autoRolling then
		doRoll(false)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R and not autoRolling then
		doRoll(false)
	end
end)

autoButton.MouseButton1Click:Connect(function()
	if not ownsAutoRoll() then
		local passId = Config.GamePasses.AutoRoll
		if passId and passId ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, passId)
		else
			showToast("Auto Roll pass not set up yet (CosmicConfig)", THEME.Bad)
		end
		return
	end
	autoRolling = not autoRolling
	updateAutoButton()
	if autoRolling then
		task.spawn(function()
			while autoRolling and ownsAutoRoll() do
				doRoll(true)
				task.wait(0.05)
			end
			autoRolling = false
			updateAutoButton()
		end)
	end
end)

player:GetAttributeChangedSignal("Pass_AutoRoll"):Connect(updateAutoButton)
player:GetAttributeChangedSignal("Pass_DoubleLuck"):Connect(updateInfo)
player:GetAttributeChangedSignal("BonusLuck"):Connect(updateInfo)

-- Animated shimmer on the roll button
task.spawn(function()
	while rollButton.Parent do
		rollGradient.Offset = Vector2.new(-1, 0)
		tween(rollGradient, 2.2, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(2.2)
		tween(rollGradient, 2.2, { Offset = Vector2.new(-1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(2.2)
	end
end)

---------------------------------------------------------------------
-- INVENTORY PANEL
---------------------------------------------------------------------
local inventoryHolder = new("Frame", {
	Name = "InventoryHolder",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.47),
	Size = UDim2.fromOffset(680, 470),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 8,
	Parent = gui,
})
addAutoScale(inventoryHolder, 760)
local inventory = new("Frame", {
	Name = "Inventory",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = THEME.Panel,
	BackgroundTransparency = 0.05,
	ZIndex = 8,
	Parent = inventoryHolder,
}, { corner(UDim.new(0, 18)), stroke(THEME.Accent, 2.5, 0) })
local inventoryPop = new("UIScale", { Parent = inventory })

label({
	Position = UDim2.fromOffset(22, 12), Size = UDim2.new(1, -44, 0, 40), Text = "✦ YOUR AURAS",
	Font = TITLE_FONT, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = inventory,
})
local discoveredLabel = label({
	Position = UDim2.fromOffset(22, 50), Size = UDim2.new(1, -44, 0, 22), Text = "",
	TextSize = 15, TextColor3 = THEME.SubText, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = inventory,
})
local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(42, 42),
	BackgroundColor3 = THEME.Bad, Text = "X", Font = TITLE_FONT, TextSize = 24, TextColor3 = THEME.Text,
	AutoButtonColor = false, ZIndex = 8, Parent = inventory,
}, { corner(UDim.new(0, 10)), textStroke(1.5) })
addButtonFeel(closeButton)

local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 82), Size = UDim2.new(1, -32, 1, -98),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
	ScrollBarImageColor3 = THEME.Accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ZIndex = 8, Parent = inventory,
}, {
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(200, 170), CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }),
})

local function buildCard(aura, count)
	local owned = count > 0
	local tier = AuraData.Tiers[aura.Tier]
	local equipped = data.Equipped == aura.Name

	local card = new("Frame", {
		Name = aura.Name,
		BackgroundColor3 = THEME.PanelLight,
		LayoutOrder = -aura.Chance, -- rarest first
		ZIndex = 8,
		Parent = list,
	}, { corner(UDim.new(0, 12)), stroke(equipped and THEME.Good or tier.Color, equipped and 3 or 1.5, owned and 0 or 0.6) })

	local nameText = label({
		Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 28),
		Text = owned and aura.Name or "???", Font = TITLE_FONT, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = card,
	})
	if owned then
		local function readable(c)
			local h, s, v = c:ToHSV()
			return Color3.fromHSV(h, s, math.max(v, 0.6))
		end
		gradient(readable(aura.Colors[1]), readable(aura.Colors[2]), 0).Parent = nameText
	else
		nameText.TextColor3 = Color3.fromRGB(110, 100, 140)
	end

	label({
		Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 18),
		Text = ("%s • %s"):format(aura.Tier, AuraData.FormatChance(aura.Chance)),
		TextSize = 13, TextColor3 = tier.Color, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = card,
	})

	if owned then
		label({
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(60, 22),
			Text = "x" .. AuraData.FormatNumber(count), TextSize = 15, TextColor3 = THEME.SubText,
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8, Parent = card,
		})
		label({
			Position = UDim2.fromOffset(10, 54), Size = UDim2.new(1, -20, 0, 18),
			Text = ("⚡ %s"):format(aura.Power.Name), TextSize = 14, TextColor3 = Color3.fromRGB(255, 220, 120),
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = card,
		})
		label({
			Position = UDim2.fromOffset(10, 72), Size = UDim2.new(1, -20, 0, 34),
			Text = aura.Power.Description, TextSize = 12, Font = Enum.Font.Gotham, TextWrapped = true,
			TextColor3 = THEME.SubText, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 8, Parent = card,
		})
		label({
			Position = UDim2.fromOffset(10, 106), Size = UDim2.new(1, -20, 0, 16),
			Text = ("❤ %d HP   ⚔ %d DMG"):format(tier.MaxHealth, tier.AttackDamage),
			TextSize = 12, TextColor3 = Color3.fromRGB(255, 150, 160),
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = card,
		})

		local equipButton = new("TextButton", {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -20, 0, 32),
			BackgroundColor3 = equipped and THEME.Good or THEME.Accent, AutoButtonColor = false,
			Text = equipped and "EQUIPPED" or "EQUIP", Font = TITLE_FONT, TextSize = 18,
			TextColor3 = THEME.Text, ZIndex = 8, Parent = card,
		}, { corner(UDim.new(0, 8)), textStroke(1.2) })
		addButtonFeel(equipButton)
		equipButton.MouseButton1Click:Connect(function()
			if data.Equipped ~= aura.Name then
				data.Equipped = aura.Name
				EquipRemote:FireServer(aura.Name)
				refreshInventory()
			end
		end)
	else
		label({
			Position = UDim2.fromOffset(10, 60), Size = UDim2.new(1, -20, 0, 60),
			Text = "Not discovered yet.\nKeep rolling!", TextSize = 14, Font = Enum.Font.Gotham,
			TextColor3 = Color3.fromRGB(130, 120, 160), TextWrapped = true, ZIndex = 8, Parent = card,
		})
	end
end

refreshInventory = function()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local discovered = 0
	for _, aura in ipairs(AuraData.List) do
		local count = data.Inventory[aura.Name] or 0
		if count > 0 then
			discovered += 1
		end
		buildCard(aura, count)
	end
	discoveredLabel.Text = ("Discovered %d / %d auras  •  Rarer auras = stronger duel powers"):format(
		discovered, #AuraData.List)
end

local function setInventoryOpen(open)
	inventoryOpen = open
	if open then
		refreshInventory()
		inventoryHolder.Visible = true
		inventoryPop.Scale = 0.8
		tween(inventoryPop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	else
		inventoryHolder.Visible = false
	end
end

aurasButton.MouseButton1Click:Connect(function()
	setInventoryOpen(not inventoryOpen)
end)
closeButton.MouseButton1Click:Connect(function()
	setInventoryOpen(false)
end)

---------------------------------------------------------------------
-- ANNOUNCEMENTS (someone in the server rolled something rare)
---------------------------------------------------------------------
local bannerToken = 0
local function skyShift(aura)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local colorFx = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if atmosphere then
		local oldColor, oldDecay = atmosphere.Color, atmosphere.Decay
		tween(atmosphere, 1.5, { Color = aura.Colors[2], Decay = aura.Colors[1] })
		task.delay(10, function()
			tween(atmosphere, 3, { Color = oldColor, Decay = oldDecay })
		end)
	end
	if colorFx then
		local oldTint = colorFx.TintColor
		tween(colorFx, 1.5, { TintColor = aura.Colors[2]:Lerp(Color3.new(1, 1, 1), 0.6) })
		task.delay(10, function()
			tween(colorFx, 3, { TintColor = oldTint })
		end)
	end
	flash(0.8, 1.5)
	addShake(1.5)
end

AnnounceRemote.OnClientEvent:Connect(function(info)
	local aura = AuraData.Get(info.Aura)
	if not aura then
		return
	end
	local hex = tierColor(aura):ToHex()
	local message = ("✦ <b>%s</b> rolled <font color='#%s'><b>%s</b></font> (%s) ✦"):format(
		info.PlayerName, hex, aura.Name, AuraData.FormatChance(aura.Chance))

	bannerToken += 1
	local token = bannerToken
	bannerLabel.Text = message
	bannerStroke.Color = tierColor(aura)
	banner.Position = UDim2.new(0.5, 0, 0, -90)
	tween(banner, 0.5, { Position = UDim2.new(0.5, 0, 0, 70) }, Enum.EasingStyle.Back)
	task.delay(5, function()
		if token == bannerToken then
			tween(banner, 0.4, { Position = UDim2.new(0.5, 0, 0, -90) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end)

	-- also post it in chat
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			general:DisplaySystemMessage(message)
		end
	end)

	if aura.Chance >= Config.SkyShiftAtChance then
		skyShift(aura)
	end
end)

---------------------------------------------------------------------
-- DATA SYNC
---------------------------------------------------------------------
DataUpdatedRemote.OnClientEvent:Connect(function(snapshot)
	data = snapshot
	updateStats()
	if inventoryOpen then
		refreshInventory()
	end
end)

updateAutoButton()
updateStats()

task.spawn(function()
	for _ = 1, 30 do
		local ok, snapshot = pcall(function()
			return GetDataRemote:InvokeServer()
		end)
		if ok and snapshot then
			data = snapshot
			updateStats()
			if data.Rolls == 0 then
				showToast("Press ROLL (or R) to discover your first aura!", THEME.Accent2)
			end
			return
		end
		task.wait(1)
	end
end)
