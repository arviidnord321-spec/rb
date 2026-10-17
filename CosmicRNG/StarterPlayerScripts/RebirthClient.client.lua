-- RebirthClient (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Everything about rebirths on your screen:
--   * the ⭐ REBIRTH button + panel (progress bars, rewards, all unlocks)
--   * the big rebirth celebration (and a pillar of light everyone sees)
--   * the Rebirth Trail perk (on everyone who has it)
--   * the Double Jump perk

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))
local Rebirth = require(ReplicatedStorage:WaitForChild("Rebirth"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local THEME = UIKit.Theme
local TITLE_FONT = UIKit.TitleFont
local new, corner, stroke, textStroke, tween, label =
	UIKit.new, UIKit.corner, UIKit.stroke, UIKit.textStroke, UIKit.tween, UIKit.label

local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local RebirthRemote = remotes:WaitForChild("Rebirth")
local AnnounceRemote = remotes:WaitForChild("Announce")

local STAR_GOLD = Color3.fromRGB(255, 210, 90)

local function rebirths()
	return player:GetAttribute("Rebirths") or 0
end

---------------------------------------------------------------------
-- SIDE MENU BUTTON (added to the menu the StoreUI script makes)
---------------------------------------------------------------------
local menuGui = player:WaitForChild("PlayerGui"):WaitForChild("CosmicMenu", 30)
local sideMenu = menuGui and menuGui:WaitForChild("SideMenu", 10)

local menuButton, readyDot
if sideMenu then
	menuButton = new("TextButton", {
		Name = "REBIRTH",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.1,
		AutoButtonColor = false,
		Text = "",
		Parent = sideMenu,
	}, { corner(UDim.new(0, 18)), stroke(Color3.fromRGB(140, 220, 255), 2.5, 0) })
	local icon = label({ Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 6), Text = "⭐", TextSize = 38, Parent = menuButton })
	local text = label({
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 20),
		Text = "REBIRTH", Font = TITLE_FONT, TextSize = 15, Parent = menuButton,
	})
	textStroke(1.2).Parent = text
	readyDot = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = THEME.Good, Visible = false, Parent = menuButton,
	}, { corner(UDim.new(1, 0)), stroke(Color3.new(1, 1, 1), 2, 0) })
	label({ Size = UDim2.fromScale(1, 1), Text = "!", Font = TITLE_FONT, TextSize = 16, Parent = readyDot })
	UIKit.addButtonFeel(menuButton)
	-- the star slowly spins
	task.spawn(function()
		while icon.Parent do
			tween(icon, 2, { Rotation = 360 }, Enum.EasingStyle.Linear)
			task.wait(2)
			icon.Rotation = 0
			task.wait(3)
		end
	end)
else
	warn("[RebirthClient] SideMenu not found, open the rebirth panel at the Rebirth Altar")
end

---------------------------------------------------------------------
-- REBIRTH PANEL
---------------------------------------------------------------------
local gui = UIKit.screen("CosmicRebirth", 2)
local holder = new("Frame", {
	Name = "RebirthHolder",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.47),
	Size = UDim2.fromOffset(620, 560),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
})
UIKit.addAutoScale(holder, 800)

local panel = new("Frame", {
	Name = "Rebirth",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = THEME.Panel,
	BackgroundTransparency = 0.05,
	ClipsDescendants = true,
	Parent = holder,
}, { corner(UDim.new(0, 18)), stroke(Color3.fromRGB(140, 220, 255), 2.5, 0) })

-- slow moving shine in the background
local shine = new("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 160, 255), BackgroundTransparency = 0.85,
	ZIndex = 0, Parent = panel,
}, {
	corner(UDim.new(0, 18)),
	new("UIGradient", {
		Name = "Shine",
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 25,
	}),
})

local titleLabel = label({
	Position = UDim2.fromOffset(22, 12), Size = UDim2.new(1, -80, 0, 40), Text = "⭐ REBIRTH",
	Font = TITLE_FONT, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
})
UIKit.gradient(Color3.fromRGB(150, 230, 255), Color3.fromRGB(255, 200, 110), 0).Parent = titleLabel
label({
	Position = UDim2.fromOffset(22, 50), Size = UDim2.new(1, -44, 0, 22),
	Text = "You KEEP all your auras • every rebirth is harder but better", TextSize = 15, TextColor3 = THEME.SubText,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
})
local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(42, 42),
	BackgroundColor3 = THEME.Bad, Text = "X", Font = TITLE_FONT, TextSize = 24, TextColor3 = THEME.Text,
	AutoButtonColor = false, Parent = panel,
}, { corner(UDim.new(0, 10)), textStroke(1.5) })
UIKit.addButtonFeel(closeButton)

-- current level
local levelLabel = label({
	Position = UDim2.fromOffset(22, 80), Size = UDim2.new(1, -44, 0, 34), Text = "",
	Font = TITLE_FONT, TextSize = 26, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
})
textStroke(1.5).Parent = levelLabel

-- a requirement row with a progress bar
local function requirementRow(y, icon)
	local row = new("Frame", {
		Position = UDim2.fromOffset(18, y), Size = UDim2.new(1, -36, 0, 58),
		BackgroundColor3 = THEME.PanelLight, Parent = panel,
	}, { corner(UDim.new(0, 12)) })
	label({ Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(40, 58), Text = icon, TextSize = 28, Parent = row })
	local text = label({
		Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -110, 0, 22), Text = "", TextSize = 17,
		RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})
	local barBack = new("Frame", {
		Position = UDim2.fromOffset(56, 34), Size = UDim2.new(1, -110, 0, 14),
		BackgroundColor3 = Color3.fromRGB(14, 10, 26), Parent = row,
	}, { corner(UDim.new(1, 0)) })
	local barFill = new("Frame", {
		Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = barBack,
	}, { corner(UDim.new(1, 0)), UIKit.gradient(Color3.fromRGB(110, 210, 255), Color3.fromRGB(190, 130, 255), 0) })
	local check = label({
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(40, 40),
		Text = "", TextSize = 28, Parent = row,
	})
	return { Text = text, Fill = barFill, Check = check }
end
local rollsRow = requirementRow(122, "🎲")
local rareRow = requirementRow(188, "💎")

-- rewards for the next rebirth
local rewardBox = new("Frame", {
	Position = UDim2.fromOffset(18, 256), Size = UDim2.new(1, -36, 0, 92),
	BackgroundColor3 = Color3.fromRGB(28, 40, 70), Parent = panel,
}, { corner(UDim.new(0, 12)), stroke(Color3.fromRGB(110, 210, 255), 1.5, 0.3) })
label({
	Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 22), Text = "NEXT REBIRTH GIVES",
	Font = TITLE_FONT, TextSize = 18, TextColor3 = Color3.fromRGB(150, 230, 255),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = rewardBox,
})
local rewardText = label({
	Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 1, -34), Text = "", TextSize = 16,
	RichText = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, Parent = rewardBox,
})

-- the big button
local rebirthButton = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 358), Size = UDim2.fromOffset(300, 56),
	BackgroundColor3 = THEME.Good, Text = "REBIRTH!", Font = TITLE_FONT, TextSize = 30, TextColor3 = THEME.Text,
	AutoButtonColor = false, Parent = panel,
}, { corner(UDim.new(0, 14)), textStroke(2), stroke(Color3.new(1, 1, 1), 2, 0.4) })
UIKit.addButtonFeel(rebirthButton)
local buttonGlow = new("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(120, 255, 170), Color3.fromRGB(70, 200, 255)),
	Rotation = 0,
	Parent = rebirthButton,
})

-- every unlock
local perkList = new("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 426), Size = UDim2.new(1, -32, 1, -438),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
	ScrollBarImageColor3 = Color3.fromRGB(140, 220, 255), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = panel,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6) }),
})
local perkRows = {}
for index, perk in ipairs(Config.Rebirth.Perks) do
	local row = new("Frame", {
		LayoutOrder = index, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = THEME.PanelLight, Parent = perkList,
	}, { corner(UDim.new(0, 10)) })
	label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(36, 44), Text = perk.Icon, TextSize = 24, Parent = row })
	label({
		Position = UDim2.fromOffset(50, 3), Size = UDim2.new(1, -170, 0, 20), Text = perk.Name, Font = TITLE_FONT, TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})
	label({
		Position = UDim2.fromOffset(50, 22), Size = UDim2.new(1, -170, 0, 18), Text = perk.Description, TextSize = 12,
		TextColor3 = THEME.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})
	local status = label({
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(110, 30),
		Text = "", Font = TITLE_FONT, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
	})
	perkRows[index] = { Row = row, Status = status, Perk = perk }
end

---------------------------------------------------------------------
-- Filling in the panel
---------------------------------------------------------------------
local function percent(scale)
	return math.floor((1 - scale) * 100 + 0.5)
end

local function refresh()
	local progress = Rebirth.Progress(player)
	local n = progress.Rebirths
	local color = Rebirth.Color(math.max(n, 1))
	if n > 0 then
		levelLabel.Text = ("<font color='#%s'>%s Rebirth %d</font>   <font color='#bfb4e1' size='18'>Luck x%s • rolls %d%% faster</font>"):format(
			color:ToHex(), Rebirth.Stars(n), n, tostring(Rebirth.LuckMultiplier(n)), percent(Rebirth.CooldownScale(n)))
	else
		levelLabel.Text = "<font color='#bfb4e1'>No rebirths yet - reach the goals below!</font>"
	end

	local cost = progress.Cost
	local rollsDone = math.min(progress.Rolls, cost.Rolls)
	rollsRow.Text.Text = ("Roll <b>%s</b> times <font color='#bfb4e1'>(%s / %s)</font>"):format(
		AuraData.FormatNumber(cost.Rolls), AuraData.FormatNumber(rollsDone), AuraData.FormatNumber(cost.Rolls))
	tween(rollsRow.Fill, 0.3, { Size = UDim2.fromScale(math.clamp(progress.Rolls / cost.Rolls, 0, 1), 1) })
	rollsRow.Check.Text = progress.RollsDone and "✅" or ""

	local bestText = progress.Best > 0 and AuraData.FormatChance(progress.Best) or "nothing yet"
	rareRow.Text.Text = ("Roll a <b>%s</b> aura or rarer <font color='#bfb4e1'>(best: %s)</font>"):format(
		AuraData.FormatChance(cost.Rarity), bestText)
	local rareScale = progress.Best > 0 and math.clamp(math.log(progress.Best) / math.log(cost.Rarity), 0, 1) or 0
	tween(rareRow.Fill, 0.3, { Size = UDim2.fromScale(rareScale, 1) })
	rareRow.Check.Text = progress.RarityDone and "✅" or ""

	-- what the next one gives
	local nextN = n + 1
	local lines = {
		("🍀 Luck <b>x%s</b> → <font color='#78ffaa'><b>x%s</b></font>  forever"):format(
			tostring(Rebirth.LuckMultiplier(n)), tostring(Rebirth.LuckMultiplier(nextN))),
		("⚡ Rolling <b>%d%%</b> → <font color='#78ffaa'><b>%d%%</b></font> faster"):format(
			percent(Rebirth.CooldownScale(n)), percent(Rebirth.CooldownScale(nextN))),
	}
	local perks = Rebirth.PerksAt(nextN)
	if #perks > 0 then
		local names = {}
		for _, perk in ipairs(perks) do
			table.insert(names, perk.Icon .. " " .. perk.Name)
		end
		table.insert(lines, "<font color='#ffd76a'><b>UNLOCKS: " .. table.concat(names, ", ") .. "</b></font>")
	else
		table.insert(lines, ("<font color='#%s'>%s</font> a new star on your name"):format(Rebirth.Color(nextN):ToHex(), Rebirth.Stars(nextN)))
	end
	rewardText.Text = table.concat(lines, "\n")

	-- the button
	if progress.Ready then
		rebirthButton.Text = "⭐ REBIRTH! ⭐"
		rebirthButton.BackgroundColor3 = THEME.Good
		buttonGlow.Enabled = true
	else
		rebirthButton.Text = "NOT READY YET"
		rebirthButton.BackgroundColor3 = Color3.fromRGB(70, 66, 90)
		buttonGlow.Enabled = false
	end
	if readyDot then
		readyDot.Visible = progress.Ready
	end

	-- the unlock list
	for _, entry in pairs(perkRows) do
		local unlocked = n >= entry.Perk.Rebirths
		entry.Status.Text = unlocked and "✅ UNLOCKED" or ("🔒 Rebirth %d"):format(entry.Perk.Rebirths)
		entry.Status.TextColor3 = unlocked and THEME.Good or THEME.SubText
		entry.Row.BackgroundColor3 = unlocked and Color3.fromRGB(30, 58, 52) or THEME.PanelLight
	end
end

for _, attribute in ipairs({ "Rebirths", "RebirthRolls", "RebirthBest" }) do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end
refresh()

-- the ready dot pulses
task.spawn(function()
	while gui.Parent do
		if readyDot and readyDot.Visible then
			tween(readyDot, 0.4, { Size = UDim2.fromOffset(28, 28) }, Enum.EasingStyle.Sine)
			task.wait(0.4)
			tween(readyDot, 0.4, { Size = UDim2.fromOffset(22, 22) }, Enum.EasingStyle.Sine)
		end
		task.wait(0.5)
	end
end)

---------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------
local open = false
local function setOpen(value)
	if value == open then
		return
	end
	open = value
	if open then
		UIKit.announcePanel("Rebirth")
		refresh()
		holder.Visible = true
		UIKit.popIn(panel)
	else
		holder.Visible = false
	end
end
if menuButton then
	menuButton.Activated:Connect(function()
		setOpen(not open)
	end)
end
closeButton.Activated:Connect(function()
	setOpen(false)
end)
UIKit.PanelOpened:Connect(function(name)
	if name ~= "Rebirth" then
		setOpen(false)
	end
end)

-- pressing E at the Rebirth Altar opens the panel
task.spawn(function()
	local islands = workspace:WaitForChild("RebirthIslands", 60)
	local gate = islands and islands:WaitForChild("RebirthGate", 30)
	local pedestal = gate and gate:WaitForChild("RebirthPedestal", 30)
	local prompt = pedestal and pedestal:WaitForChild("RebirthAltarPrompt", 30)
	if prompt then
		prompt.Triggered:Connect(function()
			setOpen(true)
		end)
	end
end)

-- shine sweep + button glow animation
RunService.RenderStepped:Connect(function()
	if not open then
		return
	end
	local t = os.clock()
	local shineGradient = shine:FindFirstChild("Shine")
	if shineGradient then
		shineGradient.Offset = Vector2.new(((t * 0.25) % 2) - 1, 0)
	end
	buttonGlow.Rotation = (t * 60) % 360
end)

---------------------------------------------------------------------
-- THE CELEBRATION
---------------------------------------------------------------------
local fxGui = UIKit.screen("CosmicRebirthFX", 45)
local camera = workspace.CurrentCamera

local function celebrate(n, unlocked)
	setOpen(false)
	local color = Rebirth.Color(n)
	SoundFX.Jingle("Rebirth")

	-- 1) build-up: screen darkens, the camera zooms in
	local dark = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = fxGui,
	})
	tween(dark, 1, { BackgroundTransparency = 0.45 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local fov = camera.FieldOfView
	tween(camera, 1.1, { FieldOfView = fov - 18 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local rings = {}
	for i = 1, 3 do
		local ring = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(900 - i * 150, 900 - i * 150), BackgroundTransparency = 1, Parent = fxGui,
		}, { corner(UDim.new(1, 0)), stroke(color, 4, 0.2) })
		tween(ring, 1.1, { Size = UDim2.fromOffset(20, 20) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		table.insert(rings, ring)
	end
	task.wait(1.1)
	for _, ring in ipairs(rings) do
		ring:Destroy()
	end

	-- 2) BOOM
	camera.FieldOfView = fov + 14
	tween(camera, 0.8, { FieldOfView = fov }, Enum.EasingStyle.Quart)
	local flash = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, Parent = fxGui,
	})
	tween(flash, 0.25, { BackgroundColor3 = color }, Enum.EasingStyle.Linear)
	task.delay(0.25, function()
		tween(flash, 0.9, { BackgroundTransparency = 1 })
	end)
	tween(dark, 1.2, { BackgroundTransparency = 1 })
	UIKit.burst({ color, STAR_GOLD, Color3.new(1, 1, 1) }, 60, 1.6, Vector2.new(0.5, 0.45))
	UIKit.confetti({ color, STAR_GOLD, THEME.Accent, THEME.Accent2 }, 120)

	-- shockwave ring
	local wave = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1, Parent = fxGui,
	}, { corner(UDim.new(1, 0)), stroke(Color3.new(1, 1, 1), 10, 0) })
	tween(wave, 0.8, { Size = UDim2.fromOffset(1600, 1600) }, Enum.EasingStyle.Quart)
	tween(wave:FindFirstChildOfClass("UIStroke"), 0.8, { Transparency = 1, Thickness = 1 })

	-- big title
	local title = label({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(900, 110),
		Text = "REBIRTH " .. n .. "!", Font = TITLE_FONT, TextSize = 96, Parent = fxGui,
	})
	UIKit.gradient(Color3.new(1, 1, 1), color, 90).Parent = title
	textStroke(4).Parent = title
	local titleScale = new("UIScale", { Scale = 3, Parent = title })
	tween(titleScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	local stars = label({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(600, 60),
		Text = Rebirth.Stars(n), Font = TITLE_FONT, TextSize = 54, TextColor3 = STAR_GOLD, Parent = fxGui,
	})
	textStroke(3).Parent = stars
	local sub = label({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(800, 36),
		Text = ("Luck x%s forever  •  rolling %d%% faster"):format(tostring(Rebirth.LuckMultiplier(n)), percent(Rebirth.CooldownScale(n))),
		Font = TITLE_FONT, TextSize = 28, TextColor3 = Color3.fromRGB(150, 255, 190), TextTransparency = 1, Parent = fxGui,
	})
	textStroke(2).Parent = sub
	task.delay(0.4, function()
		tween(sub, 0.4, { TextTransparency = 0 })
	end)

	-- 3) one card per unlock
	local cards = {}
	for index, perkName in ipairs(unlocked or {}) do
		local perk
		for _, p in ipairs(Config.Rebirth.Perks) do
			if p.Name == perkName then
				perk = p
			end
		end
		if perk then
			local card = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, (index - (#unlocked + 1) / 2) * 270, 0.6, 0),
				Size = UDim2.fromOffset(250, 120), BackgroundColor3 = THEME.Panel, Parent = fxGui,
			}, { corner(UDim.new(0, 16)), stroke(color, 3, 0) })
			label({ Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 6), Text = perk.Icon, TextSize = 40, Parent = card })
			label({ Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 26), Text = "UNLOCKED: " .. perk.Name, Font = TITLE_FONT, TextSize = 18, TextColor3 = STAR_GOLD, Parent = card })
			label({ Position = UDim2.fromOffset(10, 82), Size = UDim2.new(1, -20, 0, 32), Text = perk.Description, TextSize = 12, TextWrapped = true, TextColor3 = THEME.SubText, Parent = card })
			local cardScale = new("UIScale", { Scale = 0, Parent = card })
			task.delay(0.6 + index * 0.25, function()
				tween(cardScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
				SoundFX.Play("Pop", { Speed = 1 + index * 0.1 })
			end)
			table.insert(cards, card)
		end
	end

	task.wait(4.2)
	for _, item in ipairs({ title, stars, sub }) do
		tween(item, 0.5, { TextTransparency = 1 })
	end
	for _, card in ipairs(cards) do
		tween(card, 0.5, { BackgroundTransparency = 1 })
		for _, child in ipairs(card:GetDescendants()) do
			if child:IsA("TextLabel") then
				tween(child, 0.5, { TextTransparency = 1 })
			elseif child:IsA("UIStroke") then
				tween(child, 0.5, { Transparency = 1 })
			end
		end
	end
	task.wait(0.6)
	for _, item in ipairs({ dark, flash, wave, title, stars, sub }) do
		item:Destroy()
	end
	for _, card in ipairs(cards) do
		card:Destroy()
	end
	-- tell them where to go next
	for _, perkName in ipairs(unlocked or {}) do
		for _, info in ipairs(Config.RebirthIslands) do
			if info.Name == perkName then
				UIKit.toast(("%s %s is open! Go to the ⭐ Rebirth Gate"):format(info.Icon, info.Name), info.Color)
			end
		end
	end
end

local busy = false
rebirthButton.Activated:Connect(function()
	if busy then
		return
	end
	local progress = Rebirth.Progress(player)
	if not progress.Ready then
		UIKit.toast("Reach both goals first!", THEME.Bad)
		SoundFX.Play("Thud")
		return
	end
	if player:GetAttribute("InDuel") then
		UIKit.toast("You can't rebirth during a duel!", THEME.Bad)
		return
	end
	busy = true
	local ok, result = pcall(function()
		return RebirthRemote:InvokeServer()
	end)
	if ok and type(result) == "table" and result.Rebirths then
		celebrate(result.Rebirths, result.Unlocked)
	else
		UIKit.toast("Rebirth failed, try again", THEME.Bad)
	end
	busy = false
end)

---------------------------------------------------------------------
-- PILLAR OF LIGHT (everyone sees it on the player who rebirthed)
---------------------------------------------------------------------
local function worldPillar(character, n)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local color = Rebirth.Color(n)
	local base = root.Position - Vector3.new(0, 3, 0)
	local folder = Instance.new("Folder")
	folder.Name = "RebirthPillar"
	folder.Parent = workspace
	Debris:AddItem(folder, 4)
	local function fxPart(props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		for key, value in pairs(props) do
			p[key] = value
		end
		p.Parent = folder
		return p
	end
	-- the beam from the sky
	local beam = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(300, 1, 1),
		CFrame = CFrame.new(base + Vector3.new(0, 150, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.1,
	})
	TweenService:Create(beam, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = Vector3.new(300, 9, 9) }):Play()
	task.delay(0.5, function()
		TweenService:Create(beam, TweenInfo.new(1.8, Enum.EasingStyle.Quad), { Size = Vector3.new(300, 0.2, 0.2), Transparency = 1 }):Play()
	end)
	local core = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(300, 0.5, 0.5),
		CFrame = beam.CFrame,
		Color = Color3.new(1, 1, 1),
	})
	TweenService:Create(core, TweenInfo.new(0.35), { Size = Vector3.new(300, 4, 4) }):Play()
	task.delay(0.5, function()
		TweenService:Create(core, TweenInfo.new(1.6), { Size = Vector3.new(300, 0.1, 0.1), Transparency = 1 }):Play()
	end)
	-- ground shockwaves
	for i = 0, 2 do
		task.delay(i * 0.18, function()
			local ring = fxPart({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, 2, 2),
				CFrame = CFrame.new(base + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = (i == 1) and STAR_GOLD or color,
				Transparency = 0.2,
			})
			TweenService:Create(ring, TweenInfo.new(1.1, Enum.EasingStyle.Quart), { Size = Vector3.new(0.3, 44, 44), Transparency = 1 }):Play()
		end)
	end
	-- stars bursting out
	local burstPart = fxPart({ Size = Vector3.one, CFrame = CFrame.new(base + Vector3.new(0, 3, 0)), Transparency = 1 })
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = Config.Textures.Sparkle
	stars.Rate = 0
	stars.Lifetime = NumberRange.new(1, 2)
	stars.Speed = NumberRange.new(15, 35)
	stars.SpreadAngle = Vector2.new(180, 180)
	stars.Drag = 3
	stars.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	stars.Color = ColorSequence.new(color, STAR_GOLD)
	stars.LightEmission = 1
	stars.Parent = burstPart
	stars:Emit(90)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 50
	light.Brightness = 6
	light.Parent = burstPart
	TweenService:Create(light, TweenInfo.new(2), { Brightness = 0 }):Play()
	SoundFX.Play("Explosion", { Parent = burstPart, Volume = 0.8, MaxDistance = 250 })
end

AnnounceRemote.OnClientEvent:Connect(function(info)
	if type(info) ~= "table" or info.Type ~= "Rebirth" then
		return
	end
	local who = Players:GetPlayerByUserId(info.UserId)
	if who and who.Character then
		-- matches the moment the rebirther's own screen goes BOOM
		task.delay(1.1, worldPillar, who.Character, info.Rebirths)
	end
end)

---------------------------------------------------------------------
-- REBIRTH TRAIL perk (shown on everyone who has it)
---------------------------------------------------------------------
local function updateTrail(who)
	local character = who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local n = who:GetAttribute("Rebirths") or 0
	local existing = root:FindFirstChild("RebirthTrail")
	if not Rebirth.HasPerk(n, "Rebirth Trail") then
		if existing then
			existing:Destroy()
		end
		for _, name in ipairs({ "RebirthTrailA", "RebirthTrailB" }) do
			local a = root:FindFirstChild(name)
			if a then
				a:Destroy()
			end
		end
		return
	end
	local a0 = root:FindFirstChild("RebirthTrailA") or Instance.new("Attachment")
	a0.Name = "RebirthTrailA"
	a0.Position = Vector3.new(0, 0.9, 0.4)
	a0.Parent = root
	local a1 = root:FindFirstChild("RebirthTrailB") or Instance.new("Attachment")
	a1.Name = "RebirthTrailB"
	a1.Position = Vector3.new(0, -1.4, 0.4)
	a1.Parent = root
	local trail = existing or Instance.new("Trail")
	trail.Name = "RebirthTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.45
	trail.MinLength = 0.1
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.LightInfluence = 0
	local color = Rebirth.Color(n)
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
	trail.Parent = root
end

local function watchPlayer(who)
	who.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		updateTrail(who)
	end)
	who:GetAttributeChangedSignal("Rebirths"):Connect(function()
		updateTrail(who)
	end)
	if who.Character then
		task.spawn(updateTrail, who)
	end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, who in ipairs(Players:GetPlayers()) do
	watchPlayer(who)
end

---------------------------------------------------------------------
-- DOUBLE JUMP perk
---------------------------------------------------------------------
local airborneSince = nil
local usedDouble = false

local function canDoubleJump()
	if not Rebirth.HasPerk(rebirths(), "Double Jump") then
		return false
	end
	-- parkour stays fair, and duels stay duels
	if player:GetAttribute("ParkourCourse") or player:GetAttribute("InDuel") then
		return false
	end
	return true
end

local function hookHumanoid(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.StateChanged:Connect(function(_, state)
		if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
			airborneSince = airborneSince or os.clock()
		elseif state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Running
			or state == Enum.HumanoidStateType.Swimming or state == Enum.HumanoidStateType.Seated then
			airborneSince = nil
			usedDouble = false
		end
	end)
end
player.CharacterAdded:Connect(hookHumanoid)
if player.Character then
	task.spawn(hookHumanoid, player.Character)
end

UserInputService.JumpRequest:Connect(function()
	if usedDouble or not airborneSince or os.clock() - airborneSince < 0.18 then
		return
	end
	if not canDoubleJump() then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	usedDouble = true
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, 48, velocity.Z)
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	SoundFX.Play("Whoosh", { Speed = 1.5, Volume = 0.8 })
	-- a little ring puff under your feet
	local color = Rebirth.Color(rebirths())
	local puff = Instance.new("Part")
	puff.Anchored = true
	puff.CanCollide = false
	puff.CanQuery = false
	puff.CanTouch = false
	puff.Shape = Enum.PartType.Cylinder
	puff.Material = Enum.Material.Neon
	puff.Color = color
	puff.Transparency = 0.2
	puff.Size = Vector3.new(0.2, 1.5, 1.5)
	puff.CFrame = CFrame.new(root.Position - Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	puff.Parent = workspace
	TweenService:Create(puff, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = Vector3.new(0.1, 7, 7), Transparency = 1 }):Play()
	Debris:AddItem(puff, 0.5)
	local spark = Instance.new("ParticleEmitter")
	spark.Texture = Config.Textures.Sparkle
	spark.Rate = 0
	spark.Lifetime = NumberRange.new(0.4, 0.7)
	spark.Speed = NumberRange.new(6, 12)
	spark.SpreadAngle = Vector2.new(180, 20)
	spark.EmissionDirection = Enum.NormalId.Right
	spark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	spark.Color = ColorSequence.new(color)
	spark.LightEmission = 1
	spark.Parent = puff
	spark:Emit(18)
end)
