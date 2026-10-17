-- RollUI (LocalScript in StarterPlayer > StarterPlayerScripts)
-- The main screen: roll button, auto roll, roll animation, rare
-- cutscenes, camera showcase, inventory and announcements.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))
local Luck = require(ReplicatedStorage:WaitForChild("Luck"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))

local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local RollRemote = remotes:WaitForChild("Roll")
local GetDataRemote = remotes:WaitForChild("GetData")
local EquipRemote = remotes:WaitForChild("Equip")
local DataUpdatedRemote = remotes:WaitForChild("DataUpdated")
local AnnounceRemote = remotes:WaitForChild("Announce")
local RevealRemote = remotes:WaitForChild("Reveal")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rand = Random.new()

local THEME = UIKit.Theme
local TITLE_FONT = UIKit.TitleFont
local new, corner, stroke, textStroke, tween, label =
	UIKit.new, UIKit.corner, UIKit.stroke, UIKit.textStroke, UIKit.tween, UIKit.label

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local data = { Rolls = 0, Inventory = {}, Equipped = "", BestChance = 0 }
local rolling = false
local autoRolling = false
local inventoryOpen = false
local refreshInventory -- defined later
local setInventoryOpen -- defined later

local function tierOf(aura)
	return AuraData.Tiers[aura.Tier]
end

---------------------------------------------------------------------
-- SCREEN + LAYERS
---------------------------------------------------------------------
local gui = UIKit.screen("CosmicUI", 0)

local dimLayer = new("Frame", {
	Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1, ZIndex = 2, Parent = gui,
})
local raysLayer = new("Frame", {
	Name = "Rays", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3,
	Visible = false, Parent = gui,
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
	Size = UDim2.fromOffset(260, 78),
	BackgroundColor3 = THEME.Panel,
	BackgroundTransparency = 0.25,
	ZIndex = 5,
	Parent = gui,
}, { corner(), stroke(THEME.Accent, 1.5, 0.4) })
UIKit.addAutoScale(statsPanel)
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
	Position = UDim2.new(0.5, 0, 1, -20),
	Size = UDim2.fromOffset(540, 150),
	BackgroundTransparency = 1,
	ZIndex = 5,
	Parent = gui,
})
UIKit.addAutoScale(rollBar)

local luckLine = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 60, 0, 24),
	Text = "", RichText = true, TextSize = 19, Font = TITLE_FONT, ZIndex = 5, Parent = rollBar,
})
textStroke(1.5).Parent = luckLine
local luckyLine = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.new(1, 0, 0, 22),
	Text = "", RichText = true, TextSize = 17, Font = TITLE_FONT, ZIndex = 5, Parent = rollBar,
})
textStroke(1.5).Parent = luckyLine

-- Soft glow behind the roll button
local rollGlow = new("Frame", {
	Name = "Glow",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, 6),
	Size = UDim2.fromOffset(250, 92),
	BackgroundColor3 = Color3.fromRGB(150, 110, 255),
	BackgroundTransparency = 0.7,
	ZIndex = 4,
	Parent = rollBar,
}, { corner(UDim.new(0, 24)) })

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
UIKit.addButtonFeel(rollButton, true) -- the roll itself makes sound

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
	UIKit.addButtonFeel(button)
	return button
end

local autoButton = sideButton("AutoButton", "", 1, -128)
local aurasButton = sideButton("AurasButton", "✦ AURAS", 0, 128)

---------------------------------------------------------------------
-- CENTER REVEAL: glowing card + name
---------------------------------------------------------------------
local reveal = new("Frame", {
	Name = "Reveal",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.fromOffset(700, 420),
	BackgroundTransparency = 1,
	ZIndex = 6,
	Visible = false,
	Parent = gui,
})
UIKit.addAutoScale(reveal)
-- popHolder does the "pop" while reveal handles screen size
local popHolder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6, Parent = reveal })
local popScale = new("UIScale", { Parent = popHolder })

-- The aura's picture sits above the card (hidden if it has no picture yet)
local IMAGE_SIZE = 170
local IMAGE_Y = 85 -- center of the picture
local imageGlow = new("Frame", {
	Name = "ImageGlow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, IMAGE_Y),
	Size = UDim2.fromOffset(IMAGE_SIZE + 40, IMAGE_SIZE + 40),
	BackgroundColor3 = THEME.Accent,
	BackgroundTransparency = 0.6,
	ZIndex = 6,
	Visible = false,
	Parent = popHolder,
}, { corner(UDim.new(0, 40)) })
local auraImage = new("ImageLabel", {
	Name = "AuraImage",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, IMAGE_Y),
	Size = UDim2.fromOffset(IMAGE_SIZE, IMAGE_SIZE),
	BackgroundColor3 = THEME.Panel,
	ScaleType = Enum.ScaleType.Crop,
	Image = "",
	ZIndex = 7,
	Visible = false,
	Parent = popHolder,
}, { corner(UDim.new(0, 26)) })
local imageBorder = stroke(THEME.Accent, 4, 0)
imageBorder.Parent = auraImage
local imageScale = new("UIScale", { Parent = auraImage })

local CARD_TRANSPARENCY = 0.15
local card = new("Frame", {
	Name = "Card",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 150),
	Size = UDim2.fromOffset(620, 196),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = CARD_TRANSPARENCY,
	ClipsDescendants = true,
	ZIndex = 5,
	Parent = popHolder,
}, { corner(UDim.new(0, 22)) })
local cardGradient = new("UIGradient", { Rotation = 90, Parent = card })
local cardBorder = stroke(THEME.Accent, 3, 0)
cardBorder.Parent = card

-- A white shine that sweeps across the card on reveal
local shine = new("Frame", {
	Name = "Shine",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(-0.2, 0.5),
	-- not rotated (rotated frames ignore clipping); the gradient is tilted instead
	Size = UDim2.new(0, 160, 1, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	ZIndex = 5,
	Parent = card,
}, {
	new("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}),
})

local tierLabel = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 162), Size = UDim2.new(1, 0, 0, 30),
	Text = "", Font = TITLE_FONT, TextSize = 26, ZIndex = 6, Parent = popHolder,
})
textStroke(2).Parent = tierLabel
local nameLabel = label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 242), Size = UDim2.new(1, 0, 0, 96),
	Text = "", Font = TITLE_FONT, TextSize = 84, ZIndex = 6, Parent = popHolder,
})
textStroke(3.5).Parent = nameLabel
local nameGradient = new("UIGradient", { Parent = nameLabel })
local chanceLabel = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 292), Size = UDim2.new(1, 0, 0, 34),
	Text = "", Font = TITLE_FONT, TextSize = 30, TextColor3 = THEME.SubText, ZIndex = 6, Parent = popHolder,
})
textStroke(2).Parent = chanceLabel

local badgeLabel = label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 346), Size = UDim2.fromOffset(170, 32),
	Text = "", Font = TITLE_FONT, TextSize = 20, ZIndex = 7, BackgroundTransparency = 0,
	BackgroundColor3 = THEME.Good, Visible = false, Parent = popHolder,
})
corner(UDim.new(1, 0)).Parent = badgeLabel
textStroke(1.5).Parent = badgeLabel
local badgeScale = new("UIScale", { Parent = badgeLabel })

-- Triple Roll: the extra results appear as chips under the card
local extrasRow = new("Frame", {
	Name = "Extras",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 372),
	Size = UDim2.fromOffset(620, 36),
	BackgroundTransparency = 1,
	ZIndex = 6,
	Parent = popHolder,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local revealTexts = { tierLabel, nameLabel, chanceLabel }

local function setRevealAura(aura)
	local c1, c2 = aura.Colors[1], aura.Colors[2]
	local tierColor = tierOf(aura).Color
	nameLabel.Text = aura.Name
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameGradient.Color = ColorSequence.new(UIKit.readable(c1, 0.55), UIKit.readable(c2, 0.55))
	chanceLabel.Text = AuraData.FormatChance(aura.Chance)
	tierLabel.Text = string.upper(aura.Tier)
	tierLabel.TextColor3 = tierColor
	cardGradient.Color = ColorSequence.new(tierColor:Lerp(THEME.Panel, 0.55), THEME.Panel)
	cardBorder.Color = tierColor

	local image = AuraData.GetImage(aura.Name)
	auraImage.Visible = image ~= nil
	imageGlow.Visible = image ~= nil
	if image then
		auraImage.Image = image
		imageBorder.Color = tierColor
		imageGlow.BackgroundColor3 = tierColor
	end
end

local function setRevealVisible(visible, duration)
	local textT = visible and 0 or 1
	local strokeT = visible and 0.3 or 1
	local cardT = visible and CARD_TRANSPARENCY or 1
	local borderT = visible and 0 or 1
	local function apply(inst, props)
		if duration then
			tween(inst, duration, props)
		else
			for key, value in pairs(props) do
				inst[key] = value
			end
		end
	end
	for _, text in ipairs(revealTexts) do
		apply(text, { TextTransparency = textT })
		apply(text:FindFirstChild("TextOutline"), { Transparency = strokeT })
	end
	apply(card, { BackgroundTransparency = cardT })
	apply(cardBorder, { Transparency = borderT })
	apply(auraImage, { ImageTransparency = textT, BackgroundTransparency = textT })
	apply(imageBorder, { Transparency = borderT })
	apply(imageGlow, { BackgroundTransparency = visible and 0.6 or 1 })
end

local function clearExtras()
	for _, child in ipairs(extrasRow:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

local function showExtras(names)
	clearExtras()
	for i, auraName in ipairs(names) do
		local aura = AuraData.Get(auraName)
		local chip = label({
			Size = UDim2.fromOffset(170, 34),
			Text = "+ " .. aura.Name,
			Font = TITLE_FONT,
			TextSize = 18,
			TextColor3 = UIKit.readable(aura.Colors[1], 0.7),
			BackgroundTransparency = 0.15,
			BackgroundColor3 = THEME.Panel,
			LayoutOrder = i,
			ZIndex = 6,
			Parent = extrasRow,
		})
		corner(UDim.new(1, 0)).Parent = chip
		stroke(tierOf(aura).Color, 2, 0).Parent = chip
		textStroke(1.5).Parent = chip
		local chipScale = new("UIScale", { Scale = 0, Parent = chip })
		task.delay(0.12 * i, function()
			tween(chipScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			SoundFX.Play("Pop", { Speed = 1 + i * 0.15 })
		end)
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
UIKit.addAutoScale(cutsceneHolder)
local cutsceneText = label({
	Size = UDim2.fromScale(1, 1), Text = "", Font = TITLE_FONT, TextSize = 40, ZIndex = 6,
	TextTransparency = 1, Parent = cutsceneHolder,
})
local cutsceneStroke = textStroke(3)
cutsceneStroke.Transparency = 1
cutsceneStroke.Parent = cutsceneText
local cutsceneScale = new("UIScale", { Parent = cutsceneText })

---------------------------------------------------------------------
-- ANNOUNCEMENT BANNER
---------------------------------------------------------------------
local banner = new("Frame", {
	Name = "Banner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -90),
	Size = UDim2.fromOffset(640, 58),
	BackgroundColor3 = THEME.Panel,
	BackgroundTransparency = 0.1,
	ZIndex = 9,
	Parent = gui,
}, { corner(UDim.new(0, 14)) })
local bannerStroke = stroke(THEME.Accent, 2.5, 0)
bannerStroke.Parent = banner
UIKit.addAutoScale(banner)
local bannerLabel = label({
	Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), RichText = true,
	Text = "", Font = TITLE_FONT, TextSize = 22, ZIndex = 9, TextWrapped = true, Parent = banner,
})
local bannerIcon = new("ImageLabel", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(44, 44),
	BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, ZIndex = 9, Visible = false, Parent = banner,
}, { corner(UDim.new(0, 10)) })

---------------------------------------------------------------------
-- EFFECTS: camera shake, FOV punch, flash
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

---------------------------------------------------------------------
-- LUCK LINE + STATS
---------------------------------------------------------------------
local BONUS_ICONS = { ["2x Luck"] = "🍀", VIP = "👑", Potion = "🧪", Server = "🌌", Event = "☄️", ["Lucky Isle"] = "🏝", Parkour = "🏃" }

local function updateInfo()
	local total = Luck.Get(player)
	local parts = { ("<font color='#9fe8ff'>🍀 Luck x%s</font>"):format(Luck.Format(total)) }
	local now = Luck.Now()
	for _, bonus in ipairs(Luck.GetBonuses(player)) do
		if bonus.EndsAt then
			table.insert(parts, ("<font color='#ffd76a'>%s %s</font>"):format(
				BONUS_ICONS[bonus.Name] or "✦", Luck.FormatTime(bonus.EndsAt - now)))
		elseif bonus.Show then
			table.insert(parts, ("<font color='#ffb4dc'>%s %s x%s</font>"):format(
				BONUS_ICONS[bonus.Name] or "✦", bonus.Name, Luck.Format(bonus.Multiplier)))
		end
	end
	luckLine.Text = table.concat(parts, "   ")

	local every = Luck.LuckyEvery(player)
	local untilLucky = every - (data.Rolls % every)
	if untilLucky == 1 then
		luckyLine.Text = ("<font color='#ffd76a'>✨ NEXT ROLL IS LUCKY (x%s)</font>"):format(Luck.Format(Config.LuckyRollMultiplier))
	else
		luckyLine.Text = ("<font color='#c9bff0'>Lucky roll in %d</font>"):format(untilLucky)
	end
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
			tierOf(best).Color:ToHex(), best.Name, AuraData.FormatChance(best.Chance))
	else
		bestLabel.Text = "⭐ Best: none yet"
	end
	updateInfo()
end

task.spawn(function()
	while gui.Parent do
		updateInfo()
		task.wait(0.5)
	end
end)

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
		autoStroke.Color = THEME.Gold
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
	local order = tierOf(aura).Order
	local duration = (order >= 7) and 3.6 or (order >= 6) and 2.8 or 2
	local color = tierOf(aura).Color

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

	local rumble = SoundFX.Loop("Rumble", 0.8)

	cutsceneText.Text = (order >= 7) and "THE UNIVERSE TREMBLES..."
		or (order >= 6) and "Something MYTHIC approaches..."
		or "A LEGENDARY aura approaches..."
	cutsceneText.TextColor3 = color
	tween(cutsceneText, 0.4, { TextTransparency = 0 })
	tween(cutsceneStroke, 0.4, { Transparency = 0.3 })

	-- heartbeat: "lub-dub", getting stronger
	local beats = math.floor(duration / 0.5)
	for i = 1, beats do
		local strength = i / beats
		cutsceneScale.Scale = 1.15 + strength * 0.1
		tween(cutsceneScale, 0.35, { Scale = 1 })
		addShake(0.3 + strength * 1.2)
		UIKit.burst(aura.Colors, 6, 0.6)
		SoundFX.Play("Heartbeat", { Volume = 0.6 + strength * 0.4 })
		task.delay(0.13, function()
			SoundFX.Play("Heartbeat", { Speed = 1.15, Volume = 0.4 + strength * 0.3 })
		end)
		task.wait(0.5)
	end

	SoundFX.FadeOut(rumble, 0.6)
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
-- CAMERA SHOWCASE: camera circles your character to show off the aura
---------------------------------------------------------------------
local function showcase(duration)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	tween(rollBar, 0.3, { Position = UDim2.new(0.5, 0, 1, 220) })
	tween(statsPanel, 0.3, { Position = UDim2.new(0, -320, 0, 64) })

	camera.CameraType = Enum.CameraType.Scriptable
	local look = root.CFrame.LookVector
	local baseAngle = math.atan2(look.Z, look.X)
	local start = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		if not root.Parent then
			return
		end
		local alpha = math.clamp((os.clock() - start) / duration, 0, 1)
		local eased = 1 - (1 - alpha) ^ 2
		local angle = baseAngle + eased * math.pi * 1.4
		local radius = 13 - eased * 4
		local height = 2.5 + math.sin(alpha * math.pi) * 2.5
		local focus = root.Position + Vector3.new(0, 1, 0)
		camera.CFrame = CFrame.lookAt(focus + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius), focus)
	end)
	task.wait(duration)
	connection:Disconnect()
	camera.CameraType = Enum.CameraType.Custom

	tween(rollBar, 0.4, { Position = UDim2.new(0.5, 0, 1, -20) }, Enum.EasingStyle.Back)
	tween(statsPanel, 0.4, { Position = UDim2.new(0, 16, 0, 64) }, Enum.EasingStyle.Back)
end

---------------------------------------------------------------------
-- ROLL ANIMATION
---------------------------------------------------------------------
local function revealSoundFor(order)
	if order >= 6 then
		return "RevealMythic"
	elseif order == 5 then
		return "RevealLegendary"
	elseif order == 4 then
		return "RevealEpic"
	elseif order == 3 then
		return "RevealRare"
	end
	return "Pop"
end

local function playRollAnimation(result, fast)
	local final = AuraData.Get(result.Aura)
	local order = tierOf(final).Order

	reveal.Visible = true
	reveal.Position = UDim2.fromScale(0.5, 0.4)
	badgeLabel.Visible = false
	clearExtras()
	setRevealVisible(true)
	popScale.Scale = 0.6
	tween(popScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)

	if result.Lucky then
		UIKit.toast("✨ LUCKY ROLL! x" .. Luck.Format(Config.LuckyRollMultiplier) .. " luck", THEME.Gold)
	end

	-- 1) Spin through random auras, slowing down at the end
	local steps = fast and 7 or 16
	local showLuck = math.max(result.Luck or 1, 1) * 40 -- show exciting names while spinning
	for i = 1, steps do
		local progress = i / steps
		local fake = AuraData.RollRandom(showLuck, rand)
		setRevealAura(fake)
		popScale.Scale = 1.1
		tween(popScale, 0.08, { Scale = 1 })
		imageScale.Scale = 0.9
		tween(imageScale, 0.08, { Scale = 1 })
		nameLabel.Rotation = rand:NextNumber(-3, 3)
		SoundFX.Play("Tick", { Speed = 0.85 + progress * 0.9 })
		task.wait((fast and 0.03 or 0.04) + progress ^ 3 * (fast and 0.12 or 0.28))
	end
	nameLabel.Rotation = 0

	-- 2) Big rolls get a cutscene first
	if final.Chance >= Config.CutsceneAtChance then
		setRevealVisible(false)
		playCutscene(final)
		setRevealVisible(true)
	end

	-- 3) REVEAL
	setRevealAura(final)
	RevealRemote:FireServer() -- everyone nearby sees the 3D reveal effect
	popScale.Scale = 1.7
	tween(popScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	nameLabel.Rotation = -8
	tween(nameLabel, 0.8, { Rotation = 0 }, Enum.EasingStyle.Elastic)
	cardBorder.Thickness = 8
	tween(cardBorder, 0.6, { Thickness = 3 })
	if auraImage.Visible then
		imageScale.Scale = 0.3
		auraImage.Rotation = -25
		tween(imageScale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(auraImage, 0.9, { Rotation = 0 }, Enum.EasingStyle.Elastic)
		imageGlow.Size = UDim2.fromOffset(IMAGE_SIZE + 140, IMAGE_SIZE + 140)
		imageGlow.BackgroundTransparency = 0.2
		tween(imageGlow, 0.7, { Size = UDim2.fromOffset(IMAGE_SIZE + 40, IMAGE_SIZE + 40), BackgroundTransparency = 0.6 }, Enum.EasingStyle.Quint)
	end
	shine.Position = UDim2.fromScale(-0.2, 0.5)
	tween(shine, 0.7, { Position = UDim2.fromScale(1.2, 0.5) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

	local colors = { final.Colors[1], final.Colors[2], tierOf(final).Color }
	UIKit.burst(colors, 10 + order * 8, 0.7 + order * 0.15)
	SoundFX.Play(revealSoundFor(order))
	if order >= 3 then
		flash(math.min(0.15 + order * 0.08, 0.7), 0.4)
		addShake(0.2 + order * 0.2)
		fovPunch(order * 1.5)
	end

	if result.IsNewBest and data.Rolls > 1 then
		badgeLabel.Text = "★ NEW BEST! ★"
		badgeLabel.BackgroundColor3 = THEME.Gold
		badgeLabel.Visible = true
		UIKit.confetti(colors, 70)
		SoundFX.Chime(1, 5)
	elseif result.IsFirstTime then
		badgeLabel.Text = "NEW!"
		badgeLabel.BackgroundColor3 = THEME.Good
		badgeLabel.Visible = true
		SoundFX.Chime(1.2, 3)
	end
	if badgeLabel.Visible then
		badgeScale.Scale = 0
		tween(badgeScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	if result.Results and #result.Results > 1 then
		local extras = {}
		for i = 2, #result.Results do
			table.insert(extras, result.Results[i])
		end
		showExtras(extras)
	end

	-- 4) Hold, maybe show off with the camera, then float away
	local doShowcase = final.Chance >= Config.ShowcaseAtChance and (not fast or final.Chance >= 100000)
	task.wait(fast and 0.6 or (1.2 + order * 0.15))
	if doShowcase then
		tween(reveal, 0.35, { Position = UDim2.fromScale(0.5, 0.14) })
		tween(popScale, 0.35, { Scale = 0.55 })
		showcase(2.8)
	end
	badgeLabel.Visible = false
	tween(reveal, 0.35, { Position = UDim2.fromScale(0.5, 0.34) })
	setRevealVisible(false, 0.35)
	for _, chip in ipairs(extrasRow:GetChildren()) do
		if chip:IsA("TextLabel") then
			tween(chip, 0.3, { TextTransparency = 1, BackgroundTransparency = 1 })
		end
	end
	task.wait(0.35)
	reveal.Visible = false
	clearExtras()
end

---------------------------------------------------------------------
-- ROLLING
---------------------------------------------------------------------
local function setRollingLook(isRolling)
	if isRolling then
		rollButton.Text = autoRolling and "AUTO" or "..."
		tween(rollButton, 0.15, { TextTransparency = 0.3 })
	else
		rollButton.Text = "ROLL"
		tween(rollButton, 0.15, { TextTransparency = 0 })
	end
end

local function doRoll(fast)
	if rolling then
		return
	end
	rolling = true
	setRollingLook(true)

	local ok, result = pcall(function()
		return RollRemote:InvokeServer()
	end)
	if not ok or type(result) ~= "table" or result.Error then
		rolling = false
		setRollingLook(false)
		if ok and type(result) == "table" and result.Error == "Loading" then
			UIKit.toast("Loading your data...", THEME.SubText)
		elseif ok and type(result) == "table" and result.Error == "InDuel" then
			UIKit.toast("You can't roll during a duel!", THEME.Bad)
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
	setRollingLook(false)
end

rollButton.Activated:Connect(function()
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

autoButton.Activated:Connect(function()
	if not ownsAutoRoll() then
		local passId = Config.GamePasses.AutoRoll
		if passId and passId ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, passId)
		else
			UIKit.toast("Auto Roll pass not set up yet (CosmicConfig)", THEME.Bad)
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

-- Duels: hide the roll bar and pause auto roll while fighting
player:GetAttributeChangedSignal("InDuel"):Connect(function()
	if player:GetAttribute("InDuel") then
		autoRolling = false
		updateAutoButton()
		setInventoryOpen(false)
		tween(rollBar, 0.35, { Position = UDim2.new(0.5, 0, 1, 220) })
		tween(statsPanel, 0.35, { Position = UDim2.new(0, -320, 0, 64) })
	else
		tween(rollBar, 0.5, { Position = UDim2.new(0.5, 0, 1, -20) }, Enum.EasingStyle.Back)
		tween(statsPanel, 0.5, { Position = UDim2.new(0, 16, 0, 64) }, Enum.EasingStyle.Back)
	end
end)

-- Shimmer + breathing glow on the roll button
task.spawn(function()
	while rollButton.Parent do
		rollGradient.Offset = Vector2.new(-1, 0)
		tween(rollGradient, 2.2, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		tween(rollGlow, 1.1, { BackgroundTransparency = 0.45, Size = UDim2.fromOffset(262, 98) }, Enum.EasingStyle.Sine)
		task.wait(1.1)
		tween(rollGlow, 1.1, { BackgroundTransparency = 0.75, Size = UDim2.fromOffset(250, 92) }, Enum.EasingStyle.Sine)
		task.wait(1.1)
		tween(rollGradient, 2.2, { Offset = Vector2.new(-1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		tween(rollGlow, 1.1, { BackgroundTransparency = 0.45, Size = UDim2.fromOffset(262, 98) }, Enum.EasingStyle.Sine)
		task.wait(1.1)
		tween(rollGlow, 1.1, { BackgroundTransparency = 0.75, Size = UDim2.fromOffset(250, 92) }, Enum.EasingStyle.Sine)
		task.wait(1.1)
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
UIKit.addAutoScale(inventoryHolder, 760)
local inventory = new("Frame", {
	Name = "Inventory",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = THEME.Panel,
	BackgroundTransparency = 0.05,
	ZIndex = 8,
	Parent = inventoryHolder,
}, { corner(UDim.new(0, 18)), stroke(THEME.Accent, 2.5, 0) })

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
UIKit.addButtonFeel(closeButton)

local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 82), Size = UDim2.new(1, -32, 1, -98),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
	ScrollBarImageColor3 = THEME.Accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ZIndex = 8, Parent = inventory,
}, {
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(200, 214), CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }),
})

local function buildCard(aura, count, index, animate)
	local owned = count > 0
	local tier = tierOf(aura)
	local equipped = data.Equipped == aura.Name

	local cardFrame = new("Frame", {
		Name = aura.Name,
		BackgroundColor3 = THEME.PanelLight,
		LayoutOrder = -aura.Chance, -- rarest first
		ZIndex = 8,
		Parent = list,
	}, { corner(UDim.new(0, 12)), stroke(equipped and THEME.Good or tier.Color, equipped and 3 or 1.5, owned and 0 or 0.6) })
	local cardScale = new("UIScale", { Parent = cardFrame })
	if animate then
		cardScale.Scale = 0.6
		task.delay(index * 0.015, function()
			tween(cardScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end
	cardFrame.MouseEnter:Connect(function()
		tween(cardScale, 0.12, { Scale = 1.04 })
	end)
	cardFrame.MouseLeave:Connect(function()
		tween(cardScale, 0.12, { Scale = 1 })
	end)

	-- picture (or a placeholder) in the top-left corner
	local image = AuraData.GetImage(aura.Name)
	local thumb
	if owned and image then
		thumb = new("ImageLabel", {
			Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(58, 58),
			BackgroundColor3 = THEME.Panel, Image = image, ScaleType = Enum.ScaleType.Crop,
			ZIndex = 8, Parent = cardFrame,
		}, { corner(UDim.new(0, 10)) })
	else
		thumb = new("Frame", {
			Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(58, 58),
			BackgroundColor3 = owned and Color3.new(1, 1, 1) or Color3.fromRGB(24, 20, 44),
			ZIndex = 8, Parent = cardFrame,
		}, { corner(UDim.new(0, 10)) })
		if owned then
			UIKit.gradient(aura.Colors[1], aura.Colors[2], 45).Parent = thumb
		end
		label({
			Size = UDim2.fromScale(1, 1), Text = owned and "✦" or "?", Font = TITLE_FONT, TextSize = 30,
			TextColor3 = owned and Color3.new(1, 1, 1) or Color3.fromRGB(110, 100, 140), ZIndex = 8, Parent = thumb,
		})
	end
	stroke(tier.Color, 2, owned and 0 or 0.6).Parent = thumb

	local nameText = label({
		Position = UDim2.fromOffset(76, 10), Size = UDim2.new(1, -86, 0, 24),
		Text = owned and aura.Name or "???", Font = TITLE_FONT, TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = cardFrame,
	})
	new("UITextSizeConstraint", { MaxTextSize = 20, Parent = nameText })
	if owned then
		UIKit.gradient(UIKit.readable(aura.Colors[1]), UIKit.readable(aura.Colors[2]), 0).Parent = nameText
	else
		nameText.TextColor3 = Color3.fromRGB(110, 100, 140)
	end

	local tierText = label({
		Position = UDim2.fromOffset(76, 36), Size = UDim2.new(1, -86, 0, 14),
		Text = aura.Tier, TextScaled = true, TextColor3 = tier.Color,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = cardFrame,
	})
	new("UITextSizeConstraint", { MaxTextSize = 13, Parent = tierText })
	local chanceText = label({
		Position = UDim2.fromOffset(76, 52), Size = UDim2.new(1, -86, 0, 14),
		Text = AuraData.FormatChance(aura.Chance) .. (owned and ("  •  x" .. AuraData.FormatNumber(count)) or ""),
		TextScaled = true, TextColor3 = THEME.SubText,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = cardFrame,
	})
	new("UITextSizeConstraint", { MaxTextSize = 12, Parent = chanceText })

	if owned then
		label({
			Position = UDim2.fromOffset(10, 78), Size = UDim2.new(1, -20, 0, 18),
			Text = ("⚡ %s"):format(aura.Power.Name), TextSize = 14, TextColor3 = Color3.fromRGB(255, 220, 120),
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = cardFrame,
		})
		label({
			Position = UDim2.fromOffset(10, 96), Size = UDim2.new(1, -20, 0, 34),
			Text = aura.Power.Description, TextSize = 12, Font = Enum.Font.Gotham, TextWrapped = true,
			TextColor3 = THEME.SubText, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 8, Parent = cardFrame,
		})
		label({
			Position = UDim2.fromOffset(10, 132), Size = UDim2.new(1, -20, 0, 16),
			Text = ("❤ %d HP   ⚔ %d DMG"):format(tier.MaxHealth, tier.AttackDamage),
			TextSize = 12, TextColor3 = Color3.fromRGB(255, 150, 160),
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = cardFrame,
		})

		local equipButton = new("TextButton", {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 34),
			BackgroundColor3 = equipped and THEME.Good or THEME.Accent, AutoButtonColor = false,
			Text = equipped and "EQUIPPED" or "EQUIP", Font = TITLE_FONT, TextSize = 18,
			TextColor3 = THEME.Text, ZIndex = 8, Parent = cardFrame,
		}, { corner(UDim.new(0, 8)), textStroke(1.2) })
		UIKit.addButtonFeel(equipButton, true)
		equipButton.Activated:Connect(function()
			if data.Equipped ~= aura.Name then
				data.Equipped = aura.Name
				EquipRemote:FireServer(aura.Name)
				SoundFX.Play("Equip")
				UIKit.burst({ aura.Colors[1], aura.Colors[2] }, 14, 0.5, Vector2.new(0.5, 0.5))
				refreshInventory(false)
			end
		end)
	else
		label({
			Position = UDim2.fromOffset(10, 90), Size = UDim2.new(1, -20, 0, 60),
			Text = "Not discovered yet.\nKeep rolling!", TextSize = 14, Font = Enum.Font.Gotham,
			TextColor3 = Color3.fromRGB(130, 120, 160), TextWrapped = true, ZIndex = 8, Parent = cardFrame,
		})
	end
end

refreshInventory = function(animate)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local discovered = 0
	for index, aura in ipairs(AuraData.List) do
		local count = data.Inventory[aura.Name] or 0
		if count > 0 then
			discovered += 1
		end
		buildCard(aura, count, #AuraData.List - index, animate)
	end
	discoveredLabel.Text = ("Discovered %d / %d auras  •  Rarer auras = stronger duel powers"):format(
		discovered, #AuraData.List)
end

setInventoryOpen = function(open)
	if open == inventoryOpen then
		return
	end
	inventoryOpen = open
	if open then
		UIKit.announcePanel("Inventory")
		refreshInventory(true)
		inventoryHolder.Visible = true
		UIKit.popIn(inventory)
	else
		inventoryHolder.Visible = false
	end
end

aurasButton.Activated:Connect(function()
	setInventoryOpen(not inventoryOpen)
end)
closeButton.Activated:Connect(function()
	setInventoryOpen(false)
end)
UIKit.PanelOpened:Connect(function(name)
	if name ~= "Inventory" then
		setInventoryOpen(false)
	end
end)

---------------------------------------------------------------------
-- ANNOUNCEMENTS
---------------------------------------------------------------------
local bannerToken = 0
local function showBanner(message, color, image)
	bannerIcon.Visible = image ~= nil
	bannerIcon.Image = image or ""
	bannerLabel.Position = UDim2.fromOffset(image and 58 or 10, 0)
	bannerLabel.Size = UDim2.new(1, image and -68 or -20, 1, 0)
	bannerToken += 1
	local token = bannerToken
	bannerLabel.Text = message
	bannerStroke.Color = color
	banner.Position = UDim2.new(0.5, 0, 0, -90)
	tween(banner, 0.5, { Position = UDim2.new(0.5, 0, 0, 70) }, Enum.EasingStyle.Back)
	task.delay(5, function()
		if token == bannerToken then
			tween(banner, 0.4, { Position = UDim2.new(0.5, 0, 0, -90) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			general:DisplaySystemMessage(message)
		end
	end)
end

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
	if info.Type == "Duel" then
		local aura = AuraData.Get(info.WinnerAura or "")
		showBanner(("⚔ <b>%s</b> defeated <b>%s</b> in a duel%s!"):format(
			info.Winner, info.Loser, aura and (" with <font color='#" .. tierOf(aura).Color:ToHex() .. "'>" .. aura.Name .. "</font>") or ""),
			Color3.fromRGB(255, 90, 100), aura and AuraData.GetImage(aura.Name) or nil)
		SoundFX.Play("Pop", { Volume = 0.7 })
		return
	end
	if info.Type == "ServerLuck" then
		showBanner(("🌌 <b>%s</b> activated <font color='#ffd76a'><b>SERVER LUCK</b></font>! x%s luck for everyone!"):format(
			info.PlayerName, Luck.Format(Config.LuckMultipliers.ServerBoost)), THEME.Gold)
		UIKit.confetti({ THEME.Gold, THEME.Accent, THEME.Accent2 }, 80)
		SoundFX.Chime(1, 5)
		return
	end

	local aura = AuraData.Get(info.Aura)
	if not aura then
		return
	end
	local hex = tierOf(aura).Color:ToHex()
	showBanner(("✦ <b>%s</b> rolled <font color='#%s'><b>%s</b></font> (%s) ✦"):format(
		info.PlayerName, hex, aura.Name, AuraData.FormatChance(aura.Chance)), tierOf(aura).Color, AuraData.GetImage(aura.Name))
	if info.UserId ~= player.UserId then
		SoundFX.Play("Pop", { Volume = 0.7 })
	end
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
		refreshInventory(false)
	end
end)

updateAutoButton()
updateStats()

---------------------------------------------------------------------
-- INTRO: title card, then the UI slides in
---------------------------------------------------------------------
local function playIntro()
	rollBar.Position = UDim2.new(0.5, 0, 1, 220)
	statsPanel.Position = UDim2.new(0, -320, 0, 64)

	local holder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(800, 200),
		BackgroundTransparency = 1, ZIndex = 9, Parent = gui,
	})
	UIKit.addAutoScale(holder)
	local title = label({
		Size = UDim2.new(1, 0, 0, 130), Text = "COSMIC RNG", Font = TITLE_FONT, TextSize = 120, ZIndex = 9, Parent = holder,
	})
	textStroke(5).Parent = title
	local titleGradient = UIKit.gradient(Color3.fromRGB(190, 140, 255), Color3.fromRGB(90, 220, 255), 0)
	titleGradient.Parent = title
	local subtitle = label({
		Position = UDim2.fromOffset(0, 130), Size = UDim2.new(1, 0, 0, 40), Text = "roll the universe",
		Font = TITLE_FONT, TextSize = 32, TextColor3 = THEME.SubText, TextTransparency = 1, ZIndex = 9, Parent = holder,
	})
	local titleScale = new("UIScale", { Scale = 0.3, Parent = title })

	tween(titleScale, 0.8, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(titleGradient, 2.5, { Rotation = 360 }, Enum.EasingStyle.Linear)
	SoundFX.Play("RevealEpic", { Volume = 0.6 })
	UIKit.burst({ Color3.fromRGB(190, 140, 255), Color3.fromRGB(90, 220, 255), Color3.new(1, 1, 1) }, 40, 1.2, Vector2.new(0.5, 0.42))
	task.wait(0.5)
	tween(subtitle, 0.6, { TextTransparency = 0 })
	task.wait(1.6)
	tween(title, 0.5, { TextTransparency = 1 })
	tween(title:FindFirstChild("TextOutline"), 0.5, { Transparency = 1 })
	tween(subtitle, 0.5, { TextTransparency = 1 })
	tween(titleScale, 0.5, { Scale = 1.3 })
	SoundFX.Play("Whoosh")
	tween(rollBar, 0.6, { Position = UDim2.new(0.5, 0, 1, -20) }, Enum.EasingStyle.Back)
	tween(statsPanel, 0.6, { Position = UDim2.new(0, 16, 0, 64) }, Enum.EasingStyle.Back)
	task.wait(0.6)
	holder:Destroy()
end

task.spawn(function()
	local introOk, introError = pcall(playIntro)
	if not introOk then
		warn("[RollUI] intro failed:", introError)
		rollBar.Position = UDim2.new(0.5, 0, 1, -20)
		statsPanel.Position = UDim2.new(0, 16, 0, 64)
	end
	for _ = 1, 30 do
		local ok, snapshot = pcall(function()
			return GetDataRemote:InvokeServer()
		end)
		if ok and snapshot then
			data = snapshot
			updateStats()
			if data.Rolls == 0 then
				UIKit.toast("Press ROLL (or R) to discover your first aura!", THEME.Accent2)
			end
			return
		end
		task.wait(1)
	end
end)
