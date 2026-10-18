-- StoreUI (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Side menu (Store + Sound settings with music/effects sliders) and the Store panel that sells
-- game passes and luck boosts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local Luck = require(ReplicatedStorage:WaitForChild("Luck"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))

local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local TestProductRemote = remotes:WaitForChild("TestProduct")

local player = Players.LocalPlayer
local THEME = UIKit.Theme
local TITLE_FONT = UIKit.TitleFont
local new, corner, stroke, textStroke, tween, label =
	UIKit.new, UIKit.corner, UIKit.stroke, UIKit.textStroke, UIKit.tween, UIKit.label

local gui = UIKit.screen("CosmicMenu", 1)

---------------------------------------------------------------------
-- SIDE MENU (left middle of the screen)
---------------------------------------------------------------------
local menu = new("Frame", {
	Name = "SideMenu",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 0),
	-- 2 columns: other scripts add DUEL, REBIRTH, PETS and LIMITED buttons here
	Size = UDim2.fromOffset(178, 384),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(84, 84),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}),
})
UIKit.addAutoScale(menu)

local function menuButton(order, icon, text, color)
	local button = new("TextButton", {
		Name = text,
		LayoutOrder = order,
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.1,
		AutoButtonColor = false,
		Text = "",
		Parent = menu,
	}, { corner(UDim.new(0, 18)), stroke(color, 2.5, 0) })
	local iconLabel = label({
		Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 6), Text = icon, TextSize = 38, Parent = button,
	})
	local textLabel = label({
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 20),
		Text = text, Font = TITLE_FONT, TextSize = 16, Parent = button,
	})
	textStroke(1.2).Parent = textLabel
	UIKit.addButtonFeel(button)
	return button, iconLabel, textLabel
end

local storeButton, storeIcon = menuButton(1, "🛒", "STORE", THEME.Gold)
local soundButton, soundIcon, soundText = menuButton(9, "🔊", "SOUND", THEME.Accent2)

-- the store icon gently wiggles to draw attention
task.spawn(function()
	while storeIcon.Parent do
		task.wait(4)
		tween(storeIcon, 0.12, { Rotation = -14 })
		task.wait(0.12)
		tween(storeIcon, 0.12, { Rotation = 14 })
		task.wait(0.12)
		tween(storeIcon, 0.3, { Rotation = 0 }, Enum.EasingStyle.Elastic)
	end
end)

---------------------------------------------------------------------
-- SOUND SETTINGS: a slider for music and one for sound effects
---------------------------------------------------------------------
local UserInputService = game:GetService("UserInputService")
local SaveSettingsRemote = remotes:WaitForChild("SaveSettings", 10)
local GetDataRemote = remotes:WaitForChild("GetData", 10)

local soundHolder = new("Frame", {
	Name = "SoundHolder",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 210, 0.5, 0),
	Size = UDim2.fromOffset(380, 262),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
})
UIKit.addAutoScale(soundHolder)
local soundPanel = new("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.05, Parent = soundHolder,
}, { corner(UDim.new(0, 18)), stroke(THEME.Accent2, 2.5, 0) })
label({
	Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -80, 0, 34), Text = "🔊 SOUND", Font = TITLE_FONT, TextSize = 28,
	TextColor3 = THEME.Accent2, TextXAlignment = Enum.TextXAlignment.Left, Parent = soundPanel,
})
local soundClose = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(38, 38),
	BackgroundColor3 = THEME.Bad, Text = "X", Font = TITLE_FONT, TextSize = 22, TextColor3 = THEME.Text, AutoButtonColor = false, Parent = soundPanel,
}, { corner(UDim.new(0, 10)), textStroke(1.5) })
UIKit.addButtonFeel(soundClose)

local settings = { Music = 1, Sfx = 1, Muted = false }
local function saveSettings()
	if SaveSettingsRemote then
		SaveSettingsRemote:FireServer(settings)
	end
end

local function updateMenuIcon()
	local silent = settings.Muted or (settings.Music <= 0 and settings.Sfx <= 0)
	soundIcon.Text = silent and "🔇" or (settings.Sfx < 0.4 and "🔉" or "🔊")
	soundText.Text = settings.Muted and "MUTED" or "SOUND"
end

local sliders = {}
local function slider(y, icon, title, key, onChange)
	label({
		Position = UDim2.fromOffset(20, y), Size = UDim2.new(1, -110, 0, 24), Text = icon .. " " .. title, Font = TITLE_FONT, TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = soundPanel,
	})
	local percent = label({
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, y), Size = UDim2.fromOffset(70, 24), Text = "", Font = TITLE_FONT,
		TextSize = 19, TextColor3 = THEME.Accent2, TextXAlignment = Enum.TextXAlignment.Right, Parent = soundPanel,
	})
	local bar = new("TextButton", {
		Position = UDim2.fromOffset(20, y + 32), Size = UDim2.new(1, -40, 0, 14), BackgroundColor3 = Color3.fromRGB(14, 10, 26),
		Text = "", AutoButtonColor = false, Parent = soundPanel,
	}, { corner(UDim.new(1, 0)) })
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar }, {
		corner(UDim.new(1, 0)), UIKit.gradient(THEME.Accent2, THEME.Accent, 0),
	})
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = bar,
	}, { corner(UDim.new(1, 0)), stroke(THEME.Accent2, 2.5, 0) })
	local entry = {}
	function entry.Show()
		local value = settings[key]
		fill.Size = UDim2.fromScale(value, 1)
		knob.Position = UDim2.fromScale(value, 0.5)
		percent.Text = math.floor(value * 100 + 0.5) .. "%"
	end
	local dragging = false
	local lastTick = 0
	local function setFromX(x)
		local value = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		value = math.floor(value * 20 + 0.5) / 20 -- steps of 5%
		if value ~= settings[key] then
			settings[key] = value
			onChange()
			entry.Show()
			if os.clock() - lastTick > 0.08 then
				lastTick = os.clock()
				SoundFX.Play("Tick", { Speed = 0.8 + value * 0.8 })
			end
		end
	end
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			saveSettings()
		end
	end)
	table.insert(sliders, entry)
	return entry
end

local function applySound()
	SoundFX.SetVolumes(settings.Sfx, settings.Music)
	SoundFX.SetMuted(settings.Muted)
	updateMenuIcon()
end
slider(62, "🎵", "Music", "Music", applySound)
slider(130, "💥", "Sound effects", "Sfx", applySound)

local muteButton = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(220, 42),
	BackgroundColor3 = THEME.PanelLight, Text = "", Font = TITLE_FONT, TextSize = 19, TextColor3 = THEME.Text,
	AutoButtonColor = false, Parent = soundPanel,
}, { corner(UDim.new(0, 12)), textStroke(1.3) })
UIKit.addButtonFeel(muteButton)
local function showMute()
	muteButton.Text = settings.Muted and "🔈 UNMUTE ALL" or "🔇 MUTE ALL"
	muteButton.BackgroundColor3 = settings.Muted and THEME.Bad or THEME.PanelLight
end
muteButton.Activated:Connect(function()
	settings.Muted = not settings.Muted
	applySound()
	showMute()
	saveSettings()
end)

local function showAll()
	for _, entry in ipairs(sliders) do
		entry.Show()
	end
	showMute()
	updateMenuIcon()
end
showAll()

local soundOpen = false
local function setSoundOpen(value)
	soundOpen = value
	if value then
		UIKit.announcePanel("Sound")
		showAll()
		soundHolder.Visible = true
		UIKit.popIn(soundPanel)
	else
		soundHolder.Visible = false
	end
end
soundButton.Activated:Connect(function()
	setSoundOpen(not soundOpen)
end)
soundClose.Activated:Connect(function()
	setSoundOpen(false)
end)
UIKit.PanelOpened:Connect(function(name)
	if name ~= "Sound" and soundOpen then
		setSoundOpen(false)
	end
end)

-- load the saved settings
task.spawn(function()
	if not GetDataRemote then
		return
	end
	for _ = 1, 20 do
		local ok, snapshot = pcall(function()
			return GetDataRemote:InvokeServer()
		end)
		if ok and type(snapshot) == "table" then
			local saved = snapshot.Settings
			if type(saved) == "table" then
				settings.Music = tonumber(saved.Music) or 1
				settings.Sfx = tonumber(saved.Sfx) or 1
				settings.Muted = saved.Muted == true
				applySound()
				showAll()
			end
			return
		end
		task.wait(1)
	end
end)

---------------------------------------------------------------------
-- STORE PANEL
---------------------------------------------------------------------
local holder = new("Frame", {
	Name = "StoreHolder",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.47),
	Size = UDim2.fromOffset(640, 500),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
})
UIKit.addAutoScale(holder, 780)

local panel = new("Frame", {
	Name = "Store",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = THEME.Panel,
	BackgroundTransparency = 0.05,
	Parent = holder,
}, { corner(UDim.new(0, 18)), stroke(THEME.Gold, 2.5, 0) })

local titleLabel = label({
	Position = UDim2.fromOffset(22, 12), Size = UDim2.new(1, -44, 0, 40), Text = "🛒 COSMIC STORE",
	Font = TITLE_FONT, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
})
UIKit.gradient(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 150, 80), 0).Parent = titleLabel
label({
	Position = UDim2.fromOffset(22, 50), Size = UDim2.new(1, -44, 0, 22),
	Text = "Passes are forever • Boosts stack their time", TextSize = 15, TextColor3 = THEME.SubText,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
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
	ScrollBarImageColor3 = THEME.Gold, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = panel,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
})

local function sectionTitle(order, text)
	local t = label({
		LayoutOrder = order, Size = UDim2.new(1, 0, 0, 30), Text = text, Font = TITLE_FONT, TextSize = 22,
		TextColor3 = THEME.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = list,
	})
	textStroke(1.5).Parent = t
end

-- Prices are looked up once and remembered
local priceCache = {}
local function fetchPrice(id, infoType, priceLabel)
	if id == 0 then
		priceLabel.Text = "Set ID"
		return
	end
	local cacheKey = tostring(infoType) .. id
	if priceCache[cacheKey] then
		priceLabel.Text = priceCache[cacheKey]
		return
	end
	priceLabel.Text = "..."
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		local text = (ok and info and info.PriceInRobux) and ("R$ " .. info.PriceInRobux) or "R$ ?"
		priceCache[cacheKey] = text
		priceLabel.Text = text
	end)
end

local itemRefreshers = {}

local function itemRow(order, item, kind)
	local row = new("Frame", {
		Name = item.Key,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 86),
		BackgroundColor3 = THEME.PanelLight,
		Parent = list,
	}, { corner(UDim.new(0, 14)), stroke(THEME.Accent, 1.5, 0.4) })
	local rowScale = new("UIScale", { Parent = row })
	row.MouseEnter:Connect(function()
		tween(rowScale, 0.12, { Scale = 1.02 })
	end)
	row.MouseLeave:Connect(function()
		tween(rowScale, 0.12, { Scale = 1 })
	end)

	local icon = label({
		Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(70, 86), Text = item.Icon, TextSize = 44, Parent = row,
	})
	label({
		Position = UDim2.fromOffset(86, 12), Size = UDim2.new(1, -250, 0, 28), Text = item.Name, Font = TITLE_FONT,
		TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})
	local desc = label({
		Position = UDim2.fromOffset(86, 40), Size = UDim2.new(1, -250, 0, 38), Text = item.Description,
		Font = Enum.Font.Gotham, TextSize = 14, TextWrapped = true, TextColor3 = THEME.SubText,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = row,
	})

	local buyButton = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(140, 50),
		BackgroundColor3 = THEME.Good, AutoButtonColor = false, Text = "", Font = TITLE_FONT, TextSize = 22,
		TextColor3 = THEME.Text, Parent = row,
	}, { corner(UDim.new(0, 12)), textStroke(1.5) })
	UIKit.addButtonFeel(buyButton, true)

	local id = (kind == "Pass") and Config.GamePasses[item.Key] or Config.Products[item.Key]
	local infoType = (kind == "Pass") and Enum.InfoType.GamePass or Enum.InfoType.Product

	local function refresh()
		if kind == "Pass" and player:GetAttribute("Pass_" .. item.Key) then
			buyButton.Text = "OWNED ✓"
			buyButton.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
			row:FindFirstChild("Border").Color = THEME.Good
			return
		end
		buyButton.BackgroundColor3 = THEME.Good
		fetchPrice(id, infoType, buyButton)
		if kind == "Product" then
			-- show the remaining time of an active boost
			local endsAt = (item.Key == "PersonalLuck") and (player:GetAttribute("PersonalLuckEnd") or 0)
				or (ReplicatedStorage:GetAttribute("ServerLuckEnd") or 0)
			local left = endsAt - Luck.Now()
			if left > 0 then
				desc.Text = item.Description .. "\n<font color='#ffd76a'>Active: " .. Luck.FormatTime(left) .. " left</font>"
				desc.RichText = true
			else
				desc.Text = item.Description
			end
		end
	end
	itemRefreshers[item.Key] = refresh
	refresh()

	buyButton.Activated:Connect(function()
		if kind == "Pass" and player:GetAttribute("Pass_" .. item.Key) then
			return
		end
		SoundFX.Play("Click")
		if id == 0 then
			if kind == "Product" and RunService:IsStudio() and Config.FreePassesInStudio then
				-- Studio test: free boost
				TestProductRemote:FireServer(item.Key)
				SoundFX.Chime(1, 4)
				UIKit.toast("Studio test: " .. item.Name .. " activated!", THEME.Gold)
			else
				UIKit.toast("Put the " .. kind .. " ID for " .. item.Name .. " in CosmicConfig", THEME.Bad)
			end
			return
		end
		if kind == "Pass" then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)

	-- bounce the icon now and then
	task.spawn(function()
		task.wait(order * 0.3)
		while icon.Parent do
			tween(icon, 0.25, { Rotation = -10 })
			task.wait(0.25)
			tween(icon, 0.5, { Rotation = 0 }, Enum.EasingStyle.Elastic)
			task.wait(3 + order * 0.2)
		end
	end)
end

sectionTitle(0, "✦ GAME PASSES")
for i, item in ipairs(Config.PassInfo) do
	itemRow(i, item, "Pass")
end
sectionTitle(100, "✦ BOOSTS")
for i, item in ipairs(Config.ProductInfo) do
	itemRow(100 + i, item, "Product")
end

local function refreshAll()
	for _, refresh in pairs(itemRefreshers) do
		refresh()
	end
end

-- Update when passes/boosts change
for key in pairs(Config.GamePasses) do
	player:GetAttributeChangedSignal("Pass_" .. key):Connect(function()
		refreshAll()
		if player:GetAttribute("Pass_" .. key) and holder.Visible then
			SoundFX.Chime(1, 5)
			UIKit.confetti({ THEME.Gold, THEME.Accent, THEME.Good }, 60)
		end
	end)
end
player:GetAttributeChangedSignal("PersonalLuckEnd"):Connect(refreshAll)
ReplicatedStorage:GetAttributeChangedSignal("ServerLuckEnd"):Connect(refreshAll)

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
		UIKit.announcePanel("Store")
		refreshAll()
		holder.Visible = true
		UIKit.popIn(panel)
	else
		holder.Visible = false
	end
end

storeButton.Activated:Connect(function()
	setOpen(not open)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)
UIKit.PanelOpened:Connect(function(name)
	if name ~= "Store" then
		setOpen(false)
	end
end)

-- keep boost timers ticking while the store is open
task.spawn(function()
	while gui.Parent do
		task.wait(1)
		if open then
			for _, item in ipairs(Config.ProductInfo) do
				itemRefreshers[item.Key]()
			end
		end
	end
end)

-- Purchase feedback
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _, purchased)
	if userId == player.UserId and purchased then
		SoundFX.Chime(1, 5)
		UIKit.confetti({ THEME.Gold, THEME.Accent2, THEME.Good }, 50)
		UIKit.toast("Thank you! Boost activated 🍀", THEME.Gold)
	end
end)
