-- DuelClient (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Everything you see and press for 1v1 duels:
--   * ⚔ DUEL button in the side menu -> list of players + bots to fight
--   * challenge pop-up (Accept / Decline)
--   * fight HUD: both health bars, timer, ATTACK + POWER buttons
--   * controls: click or F = attack, Q = aura power
-- The server (DuelService) decides every hit; this script only asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local CombatAnim = require(ReplicatedStorage:WaitForChild("CombatAnim"))

local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local DuelRequest = remotes:WaitForChild("DuelRequest", 60)
local DuelEvent = remotes:WaitForChild("DuelEvent", 60)
local DuelFX = remotes:WaitForChild("DuelFX", 60)
if not DuelRequest or not DuelEvent then
	warn("[DuelClient] duel remotes not found")
	return
end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local DUEL = Config.Duel
local THEME = UIKit.Theme
local TITLE_FONT = UIKit.TitleFont
local new, corner, stroke, textStroke, tween, label =
	UIKit.new, UIKit.corner, UIKit.stroke, UIKit.textStroke, UIKit.tween, UIKit.label
local RED = Color3.fromRGB(255, 80, 100)
local rand = Random.new()

local gui = UIKit.screen("CosmicDuel", 3)

-- state while fighting
local inDuel = false
local me, opponent -- descriptions from the server
local fightEndsAt = 0
local fighting = false
local powerReadyAt = 0
local nextAttackAt = 0
local dodgeReadyAt = 0
local blocking = false
local localCombo, lastLocalAttack = 0, 0

local function statsForAura(auraName)
	local aura = AuraData.Get(auraName or "")
	local tier = AuraData.Tiers[aura and aura.Tier or DUEL.NoAuraTier]
	return aura, tier
end

---------------------------------------------------------------------
-- DUEL PANEL (opened from the side menu)
---------------------------------------------------------------------
local holder = new("Frame", {
	Name = "DuelHolder",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.47),
	Size = UDim2.fromOffset(620, 500),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
})
UIKit.addAutoScale(holder, 780)
local panel = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = THEME.Panel,
	BackgroundTransparency = 0.05,
	Parent = holder,
}, { corner(UDim.new(0, 18)), stroke(RED, 2.5, 0) })
local titleLabel = label({
	Position = UDim2.fromOffset(22, 12), Size = UDim2.new(1, -44, 0, 40), Text = "⚔ DUELS",
	Font = TITLE_FONT, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
})
UIKit.gradient(Color3.fromRGB(255, 140, 140), Color3.fromRGB(255, 200, 120), 0).Parent = titleLabel
local myStatsLabel = label({
	Position = UDim2.fromOffset(22, 50), Size = UDim2.new(1, -44, 0, 22), Text = "", RichText = true,
	TextSize = 15, TextColor3 = THEME.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
})
local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(42, 42),
	BackgroundColor3 = THEME.Bad, Text = "X", Font = TITLE_FONT, TextSize = 24, TextColor3 = THEME.Text,
	AutoButtonColor = false, Parent = panel,
}, { corner(UDim.new(0, 10)), textStroke(1.5) })
UIKit.addButtonFeel(closeButton)

local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 84), Size = UDim2.new(1, -32, 1, -100),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
	ScrollBarImageColor3 = RED, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = panel,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
})

local function sectionTitle(order, text)
	local t = label({
		LayoutOrder = order, Size = UDim2.new(1, 0, 0, 28), Text = text, Font = TITLE_FONT, TextSize = 21,
		TextColor3 = Color3.fromRGB(255, 170, 170), TextXAlignment = Enum.TextXAlignment.Left, Parent = list,
	})
	textStroke(1.5).Parent = t
end

local function row(order, icon, title, subtitle, subtitleColor, buttonText, buttonColor, enabled, onClick)
	local frame = new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = THEME.PanelLight,
		Parent = list,
	}, { corner(UDim.new(0, 12)), stroke(RED, 1.2, 0.5) })
	label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(56, 70), Text = icon, TextSize = 34, Parent = frame })
	label({
		Position = UDim2.fromOffset(68, 10), Size = UDim2.new(1, -230, 0, 26), Text = title, Font = TITLE_FONT,
		TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame,
	})
	label({
		Position = UDim2.fromOffset(68, 38), Size = UDim2.new(1, -230, 0, 20), Text = subtitle, RichText = true,
		TextSize = 14, TextColor3 = subtitleColor or THEME.SubText, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame,
	})
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 46),
		BackgroundColor3 = enabled and buttonColor or Color3.fromRGB(70, 65, 90), AutoButtonColor = false,
		Text = buttonText, Font = TITLE_FONT, TextSize = 20, TextColor3 = THEME.Text, Parent = frame,
	}, { corner(UDim.new(0, 12)), textStroke(1.4) })
	UIKit.addButtonFeel(button)
	if enabled then
		button.Activated:Connect(onClick)
	end
end

local panelOpen = false
local function statsText(auraName)
	local aura, tier = statsForAura(auraName)
	local colorHex = tier.Color:ToHex()
	return ("<font color='#%s'>%s</font>  •  ❤ %d  ⚔ %d%s"):format(
		colorHex, aura and aura.Name or "No aura", tier.MaxHealth, tier.AttackDamage,
		aura and ("  ⚡ " .. aura.Power.Name) or "")
end

local function refreshPanel()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	myStatsLabel.Text = "You: " .. statsText(player:GetAttribute("EquippedAura")) .. "   (rarer aura = stronger!)"

	sectionTitle(0, "✦ PLAYERS")
	local order = 1
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local busy = other:GetAttribute("InDuel") == true
			row(order, "🧑‍🚀", other.DisplayName, statsText(other:GetAttribute("EquippedAura")), nil,
				busy and "IN DUEL" or "CHALLENGE", RED, not busy and not inDuel, function()
					DuelRequest:FireServer({ Action = "Challenge", Target = other.UserId })
				end)
			order += 1
		end
	end
	if order == 1 then
		label({
			LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 40), Text = "Nobody else is here yet - try a bot!",
			TextSize = 16, TextColor3 = THEME.SubText, Parent = list,
		})
	end

	sectionTitle(100, "✦ BOTS")
	for i, bot in ipairs(DUEL.Bots) do
		local _, tier = statsForAura(bot.Aura)
		row(100 + i, "🤖", ("%s  (%s)"):format(bot.Name, bot.Key), statsText(bot.Aura), nil,
			"FIGHT", tier.Color:Lerp(RED, 0.5), not inDuel, function()
				DuelRequest:FireServer({ Action = "Bot", Difficulty = bot.Key })
				UIKit.toast("Summoning " .. bot.Name .. "...", THEME.SubText)
			end)
	end
end

local function setPanelOpen(open)
	if open == panelOpen then
		return
	end
	panelOpen = open
	if open then
		UIKit.announcePanel("Duel")
		refreshPanel()
		holder.Visible = true
		UIKit.popIn(panel)
	else
		holder.Visible = false
	end
end
closeButton.Activated:Connect(function()
	setPanelOpen(false)
end)
UIKit.PanelOpened:Connect(function(name)
	if name ~= "Duel" then
		setPanelOpen(false)
	end
end)
task.spawn(function()
	while gui.Parent do
		task.wait(3)
		if panelOpen then
			refreshPanel()
		end
	end
end)

-- ⚔ DUEL button in the side menu (made by StoreUI)
task.spawn(function()
	local menuGui = player:WaitForChild("PlayerGui"):WaitForChild("CosmicMenu", 30)
	local sideMenu = menuGui and menuGui:WaitForChild("SideMenu", 30)
	if not sideMenu then
		return
	end
	local button = new("TextButton", {
		Name = "DUEL",
		LayoutOrder = 0,
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.1,
		AutoButtonColor = false,
		Text = "",
		Parent = sideMenu,
	}, { corner(UDim.new(0, 18)), stroke(RED, 2.5, 0) })
	label({ Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 6), Text = "⚔", TextSize = 38, Parent = button })
	local text = label({
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 20),
		Text = "DUEL", Font = TITLE_FONT, TextSize = 16, Parent = button,
	})
	textStroke(1.2).Parent = text
	UIKit.addButtonFeel(button)
	button.Activated:Connect(function()
		setPanelOpen(not panelOpen)
	end)
	local size = sideMenu.Size
	sideMenu.Size = UDim2.new(size.X.Scale, size.X.Offset, size.Y.Scale, size.Y.Offset + 96)
end)

---------------------------------------------------------------------
-- CHALLENGE POP-UP
---------------------------------------------------------------------
local popup = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -200),
	Size = UDim2.fromOffset(460, 150),
	BackgroundColor3 = THEME.Panel,
	Parent = gui,
}, { corner(UDim.new(0, 18)), stroke(RED, 3, 0) })
UIKit.addAutoScale(popup)
local popupText = label({
	Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 60), Text = "", RichText = true,
	Font = TITLE_FONT, TextSize = 22, TextWrapped = true, Parent = popup,
})
local timeBar = new("Frame", {
	Position = UDim2.new(0, 16, 0, 74), Size = UDim2.new(1, -32, 0, 6), BackgroundColor3 = RED, BorderSizePixel = 0, Parent = popup,
}, { corner(UDim.new(1, 0)) })
local function popupButton(text, color, x)
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(x, 0, 1, -14), Size = UDim2.fromOffset(180, 46),
		BackgroundColor3 = color, AutoButtonColor = false, Text = text, Font = TITLE_FONT, TextSize = 22,
		TextColor3 = THEME.Text, Parent = popup,
	}, { corner(UDim.new(0, 12)), textStroke(1.4) })
	UIKit.addButtonFeel(b)
	return b
end
local acceptButton = popupButton("ACCEPT", THEME.Good, 0.27)
local declineButton = popupButton("DECLINE", THEME.Bad, 0.73)
local pendingFrom
local popupToken = 0

local function hidePopup()
	popupToken += 1
	pendingFrom = nil
	tween(popup, 0.3, { Position = UDim2.new(0.5, 0, 0, -200) })
end

local function showChallenge(info)
	popupToken += 1
	local token = popupToken
	pendingFrom = info.FromUserId
	popupText.Text = ("⚔ <b>%s</b> challenges you!\n<font size='16'>%s</font>"):format(info.FromName, statsText(info.FromAura))
	popup.Position = UDim2.new(0.5, 0, 0, -200)
	tween(popup, 0.45, { Position = UDim2.new(0.5, 0, 0, 80) }, Enum.EasingStyle.Back)
	timeBar.Size = UDim2.new(1, -32, 0, 6)
	tween(timeBar, info.Timeout, { Size = UDim2.new(0, 0, 0, 6) }, Enum.EasingStyle.Linear)
	SoundFX.Play("RevealEpic", { Volume = 0.6 })
	SoundFX.Chime(0.9, 3)
	task.delay(info.Timeout, function()
		if token == popupToken then
			hidePopup()
		end
	end)
end
acceptButton.Activated:Connect(function()
	if pendingFrom then
		DuelRequest:FireServer({ Action = "Respond", From = pendingFrom, Accept = true })
	end
	hidePopup()
end)
declineButton.Activated:Connect(function()
	if pendingFrom then
		DuelRequest:FireServer({ Action = "Respond", From = pendingFrom, Accept = false })
	end
	hidePopup()
end)

---------------------------------------------------------------------
-- FIGHT HUD
---------------------------------------------------------------------
local hud = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })

local topBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(760, 92),
	BackgroundTransparency = 1, Parent = hud,
})
UIKit.addAutoScale(topBar)

local function healthSide(anchorX, xScale, fillColor)
	local side = new("Frame", {
		AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.fromScale(xScale, 0), Size = UDim2.fromOffset(320, 92),
		BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.15, Parent = topBar,
	}, { corner(UDim.new(0, 14)), stroke(fillColor, 2, 0) })
	local name = label({
		Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 24), Text = "", Font = TITLE_FONT, TextSize = 21,
		TextXAlignment = (anchorX == 0) and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = side,
	})
	local aura = label({
		Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 18), Text = "", TextSize = 14, RichText = true,
		TextXAlignment = (anchorX == 0) and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right, Parent = side,
	})
	local barBack = new("Frame", {
		Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -24, 0, 26), BackgroundColor3 = Color3.fromRGB(30, 25, 45),
		ClipsDescendants = true, Parent = side,
	}, { corner(UDim.new(0, 8)) })
	local fill = new("Frame", {
		AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.fromScale(anchorX, 0), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = fillColor, BorderSizePixel = 0, Parent = barBack,
	}, { corner(UDim.new(0, 8)) })
	local trail = new("Frame", { -- white "damage taken" trail behind the fill
		AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.fromScale(anchorX, 0), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 0, Parent = barBack,
	}, { corner(UDim.new(0, 8)) })
	trail.ZIndex = fill.ZIndex - 1
	local shield = new("Frame", {
		AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.fromScale(anchorX, 0), Size = UDim2.fromScale(0, 0.35),
		BackgroundColor3 = Color3.fromRGB(120, 200, 255), BorderSizePixel = 0, ZIndex = 2, Parent = barBack,
	})
	local hpText = label({ Size = UDim2.fromScale(1, 1), Text = "", Font = TITLE_FONT, TextSize = 18, ZIndex = 3, Parent = barBack })
	textStroke(1.5).Parent = hpText
	-- guard meter (thin blue line under the health bar)
	local guardBack = new("Frame", {
		Position = UDim2.fromOffset(12, 82), Size = UDim2.new(1, -24, 0, 5), BackgroundColor3 = Color3.fromRGB(30, 25, 45),
		BorderSizePixel = 0, Parent = side,
	}, { corner(UDim.new(1, 0)) })
	local guardFill = new("Frame", {
		AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.fromScale(anchorX, 0), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(120, 200, 255), BorderSizePixel = 0, Parent = guardBack,
	}, { corner(UDim.new(1, 0)) })
	return { Name = name, Aura = aura, Fill = fill, Trail = trail, Shield = shield, Text = hpText, Guard = guardFill, LastFraction = 1 }
end

local mySide = healthSide(0, 0, Color3.fromRGB(90, 220, 130))
local theirSide = healthSide(1, 1, RED)
local timerLabel = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(110, 44),
	Text = "1:30", Font = TITLE_FONT, TextSize = 34, Parent = topBar,
})
textStroke(2).Parent = timerLabel
label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(110, 26),
	Text = "VS", Font = TITLE_FONT, TextSize = 24, TextColor3 = RED, Parent = topBar,
})

local bigText = label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(800, 140),
	Text = "", Font = TITLE_FONT, TextSize = 110, TextTransparency = 1, Parent = hud,
})
local bigStroke = textStroke(5)
bigStroke.Transparency = 1
bigStroke.Parent = bigText
local bigScale = new("UIScale", { Parent = bigText })
local bigSub = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.4, 70), Size = UDim2.fromOffset(800, 40),
	Text = "", Font = TITLE_FONT, TextSize = 30, TextTransparency = 1, Parent = hud,
})

local function flashBig(text, color, sub)
	bigText.Text = text
	bigText.TextColor3 = color
	bigText.TextTransparency = 0
	bigStroke.Transparency = 0.2
	bigScale.Scale = 1.8
	tween(bigScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	bigSub.Text = sub or ""
	bigSub.TextTransparency = sub and 0 or 1
end
local function hideBig(delay)
	task.delay(delay, function()
		tween(bigText, 0.4, { TextTransparency = 1 })
		tween(bigStroke, 0.4, { Transparency = 1 })
		tween(bigSub, 0.4, { TextTransparency = 1 })
	end)
end

-- action buttons (bottom right)
local actions = new("Frame", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -24), Size = UDim2.fromOffset(300, 290),
	BackgroundTransparency = 1, Parent = hud,
})
UIKit.addAutoScale(actions)
local attackButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(140, 140),
	BackgroundColor3 = RED, AutoButtonColor = false, Text = "👊\nATTACK", Font = TITLE_FONT, TextSize = 22,
	TextColor3 = THEME.Text, Parent = actions,
}, { corner(UDim.new(1, 0)), stroke(Color3.new(1, 1, 1), 3, 0.2), textStroke(1.6) })
UIKit.addButtonFeel(attackButton, true)
local powerButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -150, 1, -20), Size = UDim2.fromOffset(120, 120),
	BackgroundColor3 = THEME.Accent, AutoButtonColor = false, Text = "", Font = TITLE_FONT, TextSize = 18,
	TextColor3 = THEME.Text, ClipsDescendants = true, Parent = actions,
}, { corner(UDim.new(1, 0)), stroke(Color3.new(1, 1, 1), 3, 0.2) })
UIKit.addButtonFeel(powerButton, true)
local powerLabel = label({
	Size = UDim2.fromScale(1, 1), Text = "⚡\nPOWER", Font = TITLE_FONT, TextSize = 17, TextWrapped = true, ZIndex = 3, Parent = powerButton,
})
textStroke(1.5).Parent = powerLabel
local powerCooldown = new("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 2, Parent = powerButton,
})
local function smallButton(text, color, x, y)
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, x, 1, y), Size = UDim2.fromOffset(88, 88),
		BackgroundColor3 = color, AutoButtonColor = false, Text = text, Font = TITLE_FONT, TextSize = 16,
		TextColor3 = THEME.Text, ClipsDescendants = true, Parent = actions,
	}, { corner(UDim.new(1, 0)), stroke(Color3.new(1, 1, 1), 2.5, 0.3), textStroke(1.4) })
	UIKit.addButtonFeel(b, true)
	return b
end
local dodgeButton = smallButton("💨\nDODGE", Color3.fromRGB(90, 110, 200), -26, -150)
local blockButton = smallButton("🛡\nBLOCK", Color3.fromRGB(60, 140, 200), -166, -150)
local dodgeCooldown = new("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = dodgeButton,
})
local keyHint = label({
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, -244), Size = UDim2.fromOffset(300, 40),
	Text = "Click/F attack (3 = combo)  •  Q power\nhold G block  •  E dodge  •  Shift sprint", TextSize = 13,
	TextColor3 = THEME.SubText, Parent = actions,
})
textStroke(1.2).Parent = keyHint
local forfeitButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 116), Size = UDim2.fromOffset(110, 34),
	BackgroundColor3 = Color3.fromRGB(70, 60, 90), AutoButtonColor = false, Text = "🏳 FORFEIT", Font = TITLE_FONT,
	TextSize = 16, TextColor3 = THEME.Text, Parent = hud,
}, { corner(UDim.new(0, 10)) })
UIKit.addButtonFeel(forfeitButton)

local comboLabel = label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(300, 50),
	Text = "", Font = TITLE_FONT, TextSize = 36, TextTransparency = 1, Parent = hud,
})
local comboStroke = textStroke(2.5)
comboStroke.Transparency = 1
comboStroke.Parent = comboLabel
local comboScale = new("UIScale", { Parent = comboLabel })
local comboToken = 0
local function showCombo(combo)
	if combo < 2 then
		return
	end
	comboToken += 1
	local token = comboToken
	comboLabel.Text = (combo == 3) and "x3  SMASH!" or ("x" .. combo)
	comboLabel.TextColor3 = (combo == 3) and Color3.fromRGB(255, 150, 50) or THEME.Gold
	comboLabel.TextTransparency = 0
	comboStroke.Transparency = 0.2
	comboScale.Scale = (combo == 3) and 1.8 or 1.4
	tween(comboScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.7, function()
		if token == comboToken then
			tween(comboLabel, 0.3, { TextTransparency = 1 })
			tween(comboStroke, 0.3, { Transparency = 1 })
		end
	end)
end

-- red flash when you get hit
local hurtFlash = new("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 30, 50), BackgroundTransparency = 1,
	BorderSizePixel = 0, ZIndex = 0, Parent = hud,
})

---------------------------------------------------------------------
-- ACTIONS
---------------------------------------------------------------------
local function myRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function opponentRoot()
	local model = opponent and opponent.Model
	return model and model:FindFirstChild("HumanoidRootPart")
end

-- turn toward the opponent when they're close, so hits feel fair
local function faceOpponent(maxDistance)
	local root, theirs = myRoot(), opponentRoot()
	if root and theirs and (theirs.Position - root.Position).Magnitude <= maxDistance then
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(theirs.Position.X, root.Position.Y, theirs.Position.Z))
	end
end

local function aimDirection()
	return camera.CFrame.LookVector
end

-- push your own character (knockback, dodge rolls)
local function push(velocity, duration)
	local root = myRoot()
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "PushAttachment"
	attachment.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Attachment0 = attachment
	mover.VectorVelocity = velocity
	mover.MaxForce = 1e6
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.Parent = root
	task.delay(duration, function()
		mover:Destroy()
		attachment:Destroy()
	end)
end

local function attack()
	local now = os.clock()
	if not fighting or blocking or now < nextAttackAt then
		return
	end
	-- predict the combo so the animation starts instantly
	if now - lastLocalAttack <= DUEL.ComboWindow then
		localCombo = (localCombo % 3) + 1
	else
		localCombo = 1
	end
	lastLocalAttack = now
	local heavy = localCombo == 3
	nextAttackAt = now + (heavy and DUEL.HeavyRecovery or DUEL.AttackCooldown)
	faceOpponent(DUEL.AttackRange + 4)
	DuelRequest:FireServer({ Action = "Attack", Aim = aimDirection() })
	local clip = heavy and "Roundhouse" or ((localCombo == 2) and "JabLeft" or "JabRight")
	CombatAnim.Play(player.Character, clip)
	SoundFX.Play(heavy and "SwingHeavy" or "SwingLight")
	attackButton:FindFirstChild("FeelScale").Scale = 0.88
	tween(attackButton:FindFirstChild("FeelScale"), 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function setBlock(on)
	if on and (not fighting) then
		return
	end
	if blocking == on then
		return
	end
	blocking = on
	DuelRequest:FireServer({ Action = "Block", On = on })
	blockButton.BackgroundColor3 = on and Color3.fromRGB(150, 220, 255) or Color3.fromRGB(60, 140, 200)
end

local function dodge()
	local now = os.clock()
	if not fighting or blocking or now < dodgeReadyAt then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = myRoot()
	if not humanoid or not root or humanoid.WalkSpeed <= 0 then
		return -- stunned
	end
	dodgeReadyAt = now + DUEL.DodgeCooldown
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = -root.CFrame.LookVector -- standing still: hop backwards
	end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	push(direction * DUEL.DodgeSpeed + Vector3.new(0, 4, 0), 0.2)
	DuelRequest:FireServer({ Action = "Dodge", Direction = direction })
	CombatAnim.Play(character, "Dodge")
	SoundFX.Play("Dodge")
end

local function usePower()
	if not fighting or os.clock() < powerReadyAt then
		return
	end
	faceOpponent(80)
	DuelRequest:FireServer({ Action = "Power", Aim = aimDirection() })
end

attackButton.Activated:Connect(attack)
powerButton.Activated:Connect(usePower)
dodgeButton.Activated:Connect(dodge)
blockButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		setBlock(true)
	end
end)
blockButton.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		setBlock(false)
	end
end)
forfeitButton.Activated:Connect(function()
	if inDuel then
		DuelRequest:FireServer({ Action = "Forfeit" })
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inDuel then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.F then
		attack()
	elseif input.KeyCode == Enum.KeyCode.Q then
		usePower()
	elseif input.KeyCode == Enum.KeyCode.G then
		setBlock(true)
	elseif input.KeyCode == Enum.KeyCode.E then
		dodge()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.G then
		setBlock(false)
	end
end)

---------------------------------------------------------------------
-- HUD updates every frame
---------------------------------------------------------------------
local function updateSide(side, model)
	if not model then
		return
	end
	local hp = model:GetAttribute("DuelHP") or 0
	local maxHp = math.max(model:GetAttribute("DuelMaxHP") or 1, 1)
	local shieldAmount = model:GetAttribute("DuelShield") or 0
	local fraction = math.clamp(hp / maxHp, 0, 1)
	if math.abs(fraction - side.LastFraction) > 0.001 then
		tween(side.Fill, 0.15, { Size = UDim2.fromScale(fraction, 1) })
		tween(side.Trail, 0.8, { Size = UDim2.fromScale(fraction, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		side.LastFraction = fraction
	end
	side.Shield.Size = UDim2.fromScale(math.clamp(shieldAmount / maxHp, 0, 1), 0.35)
	local guard = (model:GetAttribute("DuelGuard") or DUEL.GuardMax) / DUEL.GuardMax
	side.Guard.Size = UDim2.fromScale(math.clamp(guard, 0, 1), 1)
	side.Guard.BackgroundColor3 = model:GetAttribute("DuelBlocking") and Color3.fromRGB(200, 240, 255) or Color3.fromRGB(120, 200, 255)
	side.Text.Text = ("%d / %d%s"):format(hp, maxHp, shieldAmount > 0 and ("  🛡" .. shieldAmount) or "")
end

RunService.RenderStepped:Connect(function()
	if not inDuel then
		return
	end
	updateSide(mySide, me and me.Model)
	updateSide(theirSide, opponent and opponent.Model)
	if fighting then
		local left = math.max(0, math.ceil(fightEndsAt - os.clock()))
		timerLabel.Text = ("%d:%02d"):format(left // 60, left % 60)
		timerLabel.TextColor3 = (left < 10) and RED or THEME.Text
	end
	local dodgeLeft = dodgeReadyAt - os.clock()
	dodgeCooldown.Size = UDim2.fromScale(1, math.clamp(dodgeLeft / DUEL.DodgeCooldown, 0, 1))
	local cooldownLeft = powerReadyAt - os.clock()
	local total = (me and me.Power and me.Power.Cooldown) or 1
	if cooldownLeft > 0 then
		powerCooldown.Size = UDim2.fromScale(1, math.clamp(cooldownLeft / total, 0, 1))
		powerLabel.Text = ("%.1f"):format(cooldownLeft)
	else
		powerCooldown.Size = UDim2.fromScale(1, 0)
		powerLabel.Text = me and me.Power and ("⚡\n" .. me.Power.Name) or "⚡\nNo power"
	end
end)

---------------------------------------------------------------------
-- BATTLE BEAT: a drum loop made from the sound designer's drum kit.
-- It gets more intense when someone is low on HP or time is running out.
---------------------------------------------------------------------
local beatOn = false
local BPM = 132
-- 16 steps per bar: K = kick, S = snare, h = closed hat, o = open hat
local PATTERN_CALM = { "Kh", "h", "h", "Kh", "Sh", "h", "Kh", "h", "Kh", "h", "Kh", "h", "Sh", "h", "h", "o" }
local PATTERN_HYPE = { "Kh", "h", "Kh", "h", "Sh", "h", "Kh", "Kh", "Kh", "h", "Kh", "h", "Sh", "Kh", "Sh", "So" }
local DRUMS = { K = "Kick", S = "Snare", h = "HatClosed", o = "HatOpen" }

local function intense()
	if not me or not opponent then
		return false
	end
	local function low(info)
		local model = info.Model
		return model and (model:GetAttribute("DuelHP") or 1) / math.max(model:GetAttribute("DuelMaxHP") or 1, 1) <= 0.3
	end
	return low(me) or low(opponent) or (fightEndsAt - os.clock() <= 15)
end

local function startBeat()
	if beatOn then
		return
	end
	beatOn = true
	SoundFX.SetAmbientVolume(0.15, 1)
	task.spawn(function()
		local stepLength = 60 / BPM / 4
		local nextTime = os.clock()
		local step = 0
		while beatOn do
			local pattern = intense() and PATTERN_HYPE or PATTERN_CALM
			local hits = pattern[(step % 16) + 1]
			for letter in hits:gmatch(".") do
				local drum = DRUMS[letter]
				if drum then
					SoundFX.Play(drum, { Music = true, Volume = (letter == "h") and 0.8 or 1 })
				end
			end
			step += 1
			nextTime += stepLength
			local waitTime = nextTime - os.clock()
			if waitTime > 0 then
				task.wait(waitTime)
			else
				nextTime = os.clock() -- fell behind (lag): don't machine-gun to catch up
			end
		end
	end)
end

local function stopBeat()
	beatOn = false
	SoundFX.SetAmbientVolume(1, 2)
end

---------------------------------------------------------------------
-- SERVER MESSAGES
---------------------------------------------------------------------
local function describeAura(info)
	local aura, tier = statsForAura(info.Aura)
	return ("<font color='#%s'>%s</font>  ❤ %d  ⚔ %d"):format(tier.Color:ToHex(), aura and aura.Name or "No aura", info.MaxHP, info.Damage)
end

DuelEvent.OnClientEvent:Connect(function(info)
	local kind = info.Type
	if kind == "Challenge" then
		showChallenge(info)
	elseif kind == "Notice" then
		UIKit.toast(info.Text, THEME.SubText)
	elseif kind == "Start" then
		setPanelOpen(false)
		hidePopup()
		inDuel = true
		fighting = false
		me, opponent = info.Me, info.Opponent
		powerReadyAt = 0
		mySide.Name.Text = me.Name .. " (you)"
		mySide.Aura.Text = describeAura(me)
		theirSide.Name.Text = (opponent.IsBot and "🤖 " or "") .. opponent.Name
		theirSide.Aura.Text = describeAura(opponent)
		mySide.LastFraction, theirSide.LastFraction = -1, -1
		powerButton.BackgroundColor3 = me.Aura and AuraData.Get(me.Aura).Colors[1]:Lerp(THEME.Accent, 0.4) or THEME.Accent
		local limit = math.floor(info.TimeLimit)
		timerLabel.Text = ("%d:%02d"):format(limit // 60, limit % 60)
		hud.Visible = true
		-- 3, 2, 1...
		task.spawn(function()
			for n = info.Countdown, 1, -1 do
				if not inDuel then
					return
				end
				flashBig(tostring(n), THEME.Text, (n == info.Countdown) and ("vs " .. opponent.Name) or nil)
				SoundFX.Play("Beep", { Speed = (n == 1) and 1.25 or 1 })
				task.wait(1)
			end
		end)
	elseif kind == "Fight" then
		fighting = true
		fightEndsAt = os.clock() + info.EndsIn
		flashBig("FIGHT!", RED)
		hideBig(0.9)
		SoundFX.Play("Gong")
		startBeat()
	elseif kind == "PowerUsed" then
		powerReadyAt = os.clock() + info.Cooldown
	elseif kind == "OutOfRange" then
		UIKit.toast("Too far away for your power!", THEME.Bad)
	elseif kind == "Knockback" then
		push(info.Velocity, 0.15)
	elseif kind == "Combo" then
		showCombo(info.Combo)
	elseif kind == "DodgeUsed" then
		dodgeReadyAt = os.clock() + info.Cooldown
	elseif kind == "End" then
		fighting = false
		stopBeat()
		setBlock(false)
		local reasonText = ({ KO = "Knockout!", Time = "Time's up!", Forfeit = "Forfeit", Left = "Opponent left" })[info.Reason] or ""
		if info.Result == "Win" then
			flashBig("VICTORY!", THEME.Gold, reasonText)
			UIKit.confetti({ THEME.Gold, Color3.fromRGB(120, 255, 170), THEME.Accent2 }, 110)
			SoundFX.Jingle("Victory")
		elseif info.Result == "Lose" then
			flashBig("DEFEAT", RED, reasonText)
			SoundFX.Jingle("Defeat")
		else
			flashBig("DRAW", THEME.SubText, reasonText)
		end
		task.delay(3.4, function()
			hideBig(0)
			inDuel = false
			hud.Visible = false
			me, opponent = nil, nil
		end)
	end
end)

---------------------------------------------------------------------
-- "FINISH THEM!" when the opponent is on their last hits,
-- and a red screen edge when YOU are low
---------------------------------------------------------------------
local finishLabel = label({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(500, 44),
	Text = "💀 FINISH THEM! 💀", Font = TITLE_FONT, TextSize = 34, TextColor3 = RED, Visible = false, Parent = hud,
})
textStroke(2.5).Parent = finishLabel
local finishScale = new("UIScale", { Parent = finishLabel })

local vignette = {}
for i, spec in ipairs({
	{ Vector2.new(0, 0), UDim2.fromScale(1, 0.18), 90 }, -- top
	{ Vector2.new(0, 1), UDim2.fromScale(1, 0.18), -90 }, -- bottom
	{ Vector2.new(0, 0), UDim2.fromScale(0.12, 1), 0 }, -- left
	{ Vector2.new(1, 0), UDim2.fromScale(0.12, 1), 180 }, -- right
}) do
	local edge = new("Frame", {
		AnchorPoint = spec[1],
		Position = UDim2.fromScale(spec[1].X, spec[1].Y),
		Size = spec[2],
		BackgroundColor3 = Color3.fromRGB(255, 0, 30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = hud,
	}, {
		new("UIGradient", {
			Rotation = spec[3],
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		}),
	})
	vignette[i] = edge
end

local function fractionOf(info)
	local model = info and info.Model
	if not model then
		return 1
	end
	return (model:GetAttribute("DuelHP") or 0) / math.max(model:GetAttribute("DuelMaxHP") or 1, 1)
end

RunService.RenderStepped:Connect(function()
	if not inDuel or not fighting then
		finishLabel.Visible = false
		for _, edge in ipairs(vignette) do
			edge.BackgroundTransparency = 1
		end
		return
	end
	local theirs, mine = fractionOf(opponent), fractionOf(me)
	finishLabel.Visible = theirs > 0 and theirs <= 0.2
	if finishLabel.Visible then
		finishScale.Scale = 1 + math.sin(os.clock() * 10) * 0.08
	end
	local danger = (mine <= 0.25) and (0.55 + math.sin(os.clock() * 6) * 0.2) or 1
	for _, edge in ipairs(vignette) do
		edge.BackgroundTransparency = danger
	end
end)

---------------------------------------------------------------------
-- FINISHER CUTSCENE (camera + cinema bars for the two fighters)
---------------------------------------------------------------------
local barTop = new("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.13),
	BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 20, Parent = gui,
})
local barBottom = new("Frame", {
	AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.13),
	BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 20, Parent = gui,
})
local caption = label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.935), Size = UDim2.fromOffset(700, 40),
	Text = "", Font = TITLE_FONT, TextSize = 30, ZIndex = 21, TextTransparency = 1, RichText = true, Parent = gui,
})
local captionStroke = textStroke(2)
captionStroke.Transparency = 1
captionStroke.Parent = caption

local function cinemaBars(show)
	tween(barTop, 0.4, { Position = UDim2.fromScale(0, show and 0.13 or 0) })
	tween(barBottom, 0.4, { Position = UDim2.fromScale(0, show and 0.87 or 1) })
end

local function playFinisherCamera(info)
	local loserRoot = info.Loser and info.Loser:FindFirstChild("HumanoidRootPart")
	local winnerRoot = info.Winner and info.Winner:FindFirstChild("HumanoidRootPart")
	if not loserRoot then
		return
	end
	local iWon = info.Winner == player.Character
	local c1 = (info.Colors and info.Colors[1]) or Color3.new(1, 1, 1)
	local duration = info.Duration or 4.6
	actions.Visible = false
	forfeitButton.Visible = false
	cinemaBars(true)

	local loserPos = loserRoot.Position
	local side = winnerRoot and (loserPos - winnerRoot.Position) or Vector3.new(1, 0, 0)
	side = Vector3.new(side.X, 0, side.Z)
	side = (side.Magnitude > 0.1) and side.Unit or Vector3.new(1, 0, 0)
	local across = Vector3.new(-side.Z, 0, side.X)

	camera.CameraType = Enum.CameraType.Scriptable
	local start = os.clock()
	local shake = 0
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local shot
		if t < 1.3 then
			-- low angle beside the loser, looking up at the magic circle
			local a = t * 0.25
			local offset = (across * math.cos(a) + side * math.sin(a)) * 14 + Vector3.new(0, 2.5, 0)
			shot = CFrame.lookAt(loserPos + offset, loserPos + Vector3.new(0, 14 + t * 6, 0))
		elseif t < 2.9 then
			-- pull back to see the whole beam
			local k = math.clamp((t - 1.3) / 0.6, 0, 1)
			local offset = across * (14 + k * 16) + side * 6 + Vector3.new(0, 4 + k * 8, 0)
			shot = CFrame.lookAt(loserPos + offset, loserPos + Vector3.new(0, 10, 0))
		elseif winnerRoot and winnerRoot.Parent then
			-- hero shot of the winner
			local k = math.clamp((t - 2.9) / 1.5, 0, 1)
			local look = winnerRoot.CFrame.LookVector
			local eye = winnerRoot.Position + look * (10 - k * 3) + Vector3.new(0, 2.2 - k * 0.6, 0) + across * 2
			shot = CFrame.lookAt(eye, winnerRoot.Position + Vector3.new(0, 1.5, 0))
		else
			shot = camera.CFrame
		end
		if shake > 0.01 then
			shot *= CFrame.Angles(rand:NextNumber(-shake, shake) * 0.03, rand:NextNumber(-shake, shake) * 0.03, 0)
			shake *= 0.9
		end
		camera.CFrame = shot
	end)

	-- the strike moment
	task.delay(1.3, function()
		shake = 3
		flashBig(iWon and "💀 FINISHED!" or "ELIMINATED", iWon and THEME.Gold or RED)
		hideBig(1.2)
	end)
	task.delay(2.9, function()
		caption.Text = ("⚡ FINISHED BY <font color='#%s'>%s</font>%s"):format(
			c1:Lerp(Color3.new(1, 1, 1), 0.3):ToHex(), info.WinnerName or "?", info.AuraName and (" • " .. info.AuraName) or "")
		tween(caption, 0.3, { TextTransparency = 0 })
		tween(captionStroke, 0.3, { Transparency = 0.2 })
	end)
	task.delay(duration, function()
		connection:Disconnect()
		camera.CameraType = Enum.CameraType.Custom
		cinemaBars(false)
		tween(caption, 0.3, { TextTransparency = 1 })
		tween(captionStroke, 0.3, { Transparency = 1 })
		actions.Visible = true
		forfeitButton.Visible = true
	end)
end

DuelEvent.OnClientEvent:Connect(function(info)
	if info.Type == "Finisher" then
		fighting = false
		stopBeat()
		setBlock(false)
		playFinisherCamera(info)
	end
end)


---------------------------------------------------------------------
-- FEEL THE HITS: screen shake, red flash, zoom punch
---------------------------------------------------------------------
local shakeAmount = 0
local shaking = false
RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if shakeAmount > 0.01 then
		shaking = true
		local m = shakeAmount * 0.3
		if humanoid then
			humanoid.CameraOffset = Vector3.new(rand:NextNumber(-m, m), rand:NextNumber(-m, m), rand:NextNumber(-m, m))
		end
		shakeAmount = math.max(0, shakeAmount - dt * 4)
	elseif shaking then
		shaking = false
		if humanoid then
			humanoid.CameraOffset = Vector3.zero
		end
	end
end)

local baseFov = camera.FieldOfView
if DuelFX then
	DuelFX.OnClientEvent:Connect(function(info)
		if not inDuel then
			return
		end
		local character = player.Character
		if info.Type == "Damage" and (info.Amount or 0) > 0 and info.Kind ~= "Burn" then
			local big = info.Heavy or info.Amount >= 30
			if info.Target == character then
				shakeAmount = math.max(shakeAmount, big and 1.6 or 0.7)
				hurtFlash.BackgroundTransparency = big and 0.55 or 0.75
				tween(hurtFlash, 0.35, { BackgroundTransparency = 1 })
			elseif info.Attacker == character then
				shakeAmount = math.max(shakeAmount, big and 1 or 0.3)
				if big then
					camera.FieldOfView = baseFov - 6
					tween(camera, 0.35, { FieldOfView = baseFov }, Enum.EasingStyle.Quint)
				end
			end
		elseif info.Type == "GuardBreak" and info.Target == character then
			shakeAmount = math.max(shakeAmount, 1.2)
			setBlock(false)
		elseif info.Type == "Block" and info.Target == character then
			shakeAmount = math.max(shakeAmount, 0.35)
		end
	end)
end
