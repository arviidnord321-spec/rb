-- LimitedOffer (LocalScript in StarterPlayer > StarterPlayerScripts)
-- The 🔥 LIMITED button + panel: 3 super strong packs (pick ONE), only on
-- sale for the first 7 days after release. Shows a live countdown, opens
-- itself once when you join, and disappears when the offer ends or you buy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local THEME = UIKit.Theme
local TITLE_FONT = UIKit.TitleFont
local new, corner, stroke, textStroke, tween, label =
	UIKit.new, UIKit.corner, UIKit.stroke, UIKit.textStroke, UIKit.tween, UIKit.label

local OFFER = Config.LimitedOffer
local HOT = Color3.fromRGB(255, 120, 60)
local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local TestProductRemote = remotes:WaitForChild("TestProduct")

local function secondsLeft()
	local ends = ReplicatedStorage:GetAttribute("LimitedOfferEnds")
	if not ends then
		return nil
	end
	return ends - os.time()
end

local function available()
	local left = secondsLeft()
	return left ~= nil and left > 0 and (player:GetAttribute("LimitedBought") or "") == ""
end

local function formatLeft(seconds)
	seconds = math.max(0, math.floor(seconds))
	local days = seconds // 86400
	local hours = (seconds % 86400) // 3600
	local minutes = (seconds % 3600) // 60
	if days > 0 then
		return ("%dd %dh %dm"):format(days, hours, minutes)
	end
	return ("%dh %dm %ds"):format(hours, minutes, seconds % 60)
end

---------------------------------------------------------------------
-- Side menu button
---------------------------------------------------------------------
local menuGui = player:WaitForChild("PlayerGui"):WaitForChild("CosmicMenu", 30)
local sideMenu = menuGui and menuGui:WaitForChild("SideMenu", 10)
local button, buttonTime
if sideMenu then
	button = new("TextButton", {
		Name = "LIMITED", LayoutOrder = -1, Size = UDim2.fromOffset(84, 84), BackgroundColor3 = Color3.fromRGB(60, 20, 20),
		BackgroundTransparency = 0.05, AutoButtonColor = false, Text = "", Visible = false, Parent = sideMenu,
	}, { corner(UDim.new(0, 18)), stroke(HOT, 3, 0) })
	label({ Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 4), Text = "🔥", TextSize = 32, Parent = button })
	local text = label({ Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 18), Text = "LIMITED", Font = TITLE_FONT, TextSize = 15, TextColor3 = Color3.fromRGB(255, 220, 150), Parent = button })
	textStroke(1.2).Parent = text
	buttonTime = label({ Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 16), Text = "", TextSize = 11, Parent = button })
	textStroke(1).Parent = buttonTime
	UIKit.addButtonFeel(button)
end

---------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------
local gui = UIKit.screen("CosmicLimited", 3)
local holder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(780, 500),
	BackgroundTransparency = 1, Visible = false, Parent = gui,
})
UIKit.addAutoScale(holder, 820)
local panel = new("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(26, 12, 22), BackgroundTransparency = 0.03, ClipsDescendants = true, Parent = holder,
}, { corner(UDim.new(0, 20)), stroke(HOT, 3, 0) })
local shine = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = HOT, BackgroundTransparency = 0.88, Parent = panel }, {
	new("UIGradient", { Name = "Shine", Rotation = 30, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1),
	}) }),
})
local title = label({
	Position = UDim2.fromOffset(24, 12), Size = UDim2.new(1, -90, 0, 44), Text = "🔥 LIMITED LAUNCH OFFER 🔥", Font = TITLE_FONT,
	TextSize = 36, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
})
UIKit.gradient(Color3.fromRGB(255, 230, 120), HOT, 0).Parent = title
textStroke(2).Parent = title
local subtitle = label({
	Position = UDim2.fromOffset(24, 56), Size = UDim2.new(1, -48, 0, 24), Text = "", TextSize = 17, RichText = true,
	TextColor3 = THEME.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
})
local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(42, 42),
	BackgroundColor3 = THEME.Bad, Text = "X", Font = TITLE_FONT, TextSize = 24, TextColor3 = THEME.Text, AutoButtonColor = false, Parent = panel,
}, { corner(UDim.new(0, 10)), textStroke(1.5) })
UIKit.addButtonFeel(closeButton)

local cards = new("Frame", {
	Position = UDim2.fromOffset(20, 96), Size = UDim2.new(1, -40, 1, -112), BackgroundTransparency = 1, Parent = panel,
}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })

local function buy(pack)
	local id = Config.Products[pack.Key]
	if id and id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, id)
	elseif Config.FreePassesInStudio and RunService:IsStudio() then
		TestProductRemote:FireServer(pack.Key)
		UIKit.toast("(Studio test) " .. pack.Name .. " given for free", THEME.Gold)
	else
		UIKit.toast("This pack isn't set up yet (CosmicConfig.Products)", THEME.Bad)
	end
end

for index, pack in ipairs(OFFER.Packs) do
	local card = new("Frame", {
		LayoutOrder = index, Size = UDim2.fromOffset(234, 380), BackgroundColor3 = Color3.fromRGB(40, 20, 36), Parent = cards,
	}, { corner(UDim.new(0, 16)), stroke(pack.Color, 2.5, 0) })
	local badge = label({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 60), Text = pack.Icon, TextSize = 52, Parent = card })
	task.spawn(function()
		while badge.Parent do
			tween(badge, 0.8, { Rotation = 8 }, Enum.EasingStyle.Sine)
			task.wait(0.8)
			tween(badge, 0.8, { Rotation = -8 }, Enum.EasingStyle.Sine)
			task.wait(0.8)
		end
	end)
	local name = label({ Position = UDim2.fromOffset(8, 72), Size = UDim2.new(1, -16, 0, 30), Text = pack.Name, Font = TITLE_FONT, TextSize = 22, TextColor3 = UIKit.readable(pack.Color, 0.85), Parent = card })
	textStroke(1.5).Parent = name
	local list = {}
	for _, line in ipairs(pack.Gives) do
		table.insert(list, "✔ " .. line)
	end
	label({
		Position = UDim2.fromOffset(14, 110), Size = UDim2.new(1, -28, 0, 170), Text = table.concat(list, "\n\n"), TextSize = 15,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = card,
	})
	local buyButton = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(1, -28, 0, 52),
		BackgroundColor3 = pack.Color, Text = ("R$ %s"):format(pack.PriceText or OFFER.PriceText), Font = TITLE_FONT, TextSize = 26,
		TextColor3 = THEME.Text, AutoButtonColor = false, Parent = card,
	}, { corner(UDim.new(0, 12)), textStroke(2) })
	UIKit.addButtonFeel(buyButton)
	-- once the product exists, show its real price from Roblox
	local productId = Config.Products[pack.Key] or 0
	if productId ~= 0 then
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				buyButton.Text = ("R$ %d"):format(info.PriceInRobux)
			end
		end)
	end
	buyButton.Activated:Connect(function()
		buy(pack)
	end)
end

local open = false
local function setOpen(value)
	if value == open then
		return
	end
	open = value and available()
	if open then
		UIKit.announcePanel("Limited")
		holder.Visible = true
		UIKit.popIn(panel)
		SoundFX.Chime(1, 4)
	else
		holder.Visible = false
	end
end
if button then
	button.Activated:Connect(function()
		setOpen(not open)
	end)
end
closeButton.Activated:Connect(function()
	setOpen(false)
end)
UIKit.PanelOpened:Connect(function(name)
	if name ~= "Limited" then
		setOpen(false)
	end
end)

-- countdown + pulsing button
RunService.RenderStepped:Connect(function()
	local isOn = available()
	if button then
		button.Visible = isOn
		if isOn then
			buttonTime.Text = formatLeft(secondsLeft())
			local pulse = (math.sin(os.clock() * 4) + 1) / 2
			button.BackgroundColor3 = Color3.fromRGB(60, 20, 20):Lerp(Color3.fromRGB(120, 40, 20), pulse)
		end
	end
	if open then
		if not isOn then
			setOpen(false)
			return
		end
		subtitle.Text = ("Pick <b>ONE</b> pack • super strong • ends in <font color='#ffb46a'><b>%s</b></font>"):format(formatLeft(secondsLeft()))
		local g = shine:FindFirstChild("Shine")
		if g then
			g.Offset = Vector2.new(((os.clock() * 0.3) % 2) - 1, 0)
		end
	end
end)

-- show it once, a little after joining (waits until other windows, like the
-- daily reward, are closed)
local function anyPanelOpen()
	local playerGui = player:FindFirstChild("PlayerGui")
	for _, name in ipairs({ "CosmicQuests", "CosmicPets", "CosmicRebirth", "CosmicMenu" }) do
		local screen = playerGui and playerGui:FindFirstChild(name)
		if screen then
			for _, child in ipairs(screen:GetChildren()) do
				if child:IsA("Frame") and child.Name ~= "SideMenu" and child.Visible then
					return true
				end
			end
		end
	end
	return false
end
task.spawn(function()
	UIKit.waitForIntro()
	task.wait(7)
	for _ = 1, 120 do
		if not available() then
			return
		end
		if not anyPanelOpen() then
			task.wait(1.5)
			if not anyPanelOpen() then
				setOpen(true)
				return
			end
		end
		task.wait(1)
	end
end)

player:GetAttributeChangedSignal("LimitedBought"):Connect(function()
	if (player:GetAttribute("LimitedBought") or "") ~= "" then
		setOpen(false)
		SoundFX.Jingle("Victory")
		UIKit.confetti({ HOT, THEME.Gold, Color3.new(1, 1, 1) }, 120)
		UIKit.toast("🔥 Limited pack unlocked! Thank you!", THEME.Gold)
	end
end)
