-- TradeClient (LocalScript in StarterPlayer > StarterPlayerScripts)
-- 🤝 TRADING on your screen:
--   * TRADE button -> list of players to send a trade request to
--     (at least one of you needs the 👑 VIP pass)
--   * a popup when someone wants to trade with you (Accept / Decline)
--   * the trade window: pick auras and pets from your inventory, see what
--     they offer, press READY - when both are ready it counts down and swaps

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local THEME = UIKit.Theme
local TITLE_FONT = UIKit.TitleFont
local new, corner, stroke, textStroke, tween, label =
	UIKit.new, UIKit.corner, UIKit.stroke, UIKit.textStroke, UIKit.tween, UIKit.label

local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local TradeRemote = remotes:WaitForChild("Trade")
local GetDataRemote = remotes:WaitForChild("GetData")
local DataUpdatedRemote = remotes:WaitForChild("DataUpdated")

local TEAL = Color3.fromRGB(90, 230, 205)
local GOLD = Color3.fromRGB(255, 200, 70)
local myData = { Inventory = {}, Pets = {} }
local state -- the current trade (from the server)

local function isVIP(who)
	return who:GetAttribute("Pass_VIP") == true
end

local function itemColor(kind, name)
	if kind == "Aura" then
		local aura = AuraData.Get(name)
		return aura and UIKit.readable(AuraData.Tiers[aura.Tier].Color) or THEME.Text
	end
	local pet = PetData.Get(name)
	if pet and pet.Variant == "Golden" then
		return Color3.fromRGB(255, 215, 90)
	end
	return pet and UIKit.readable(PetData.Rarities[pet.Rarity].Color) or THEME.Text
end

local function itemText(kind, name)
	if kind == "Aura" then
		local aura = AuraData.Get(name)
		return "✨ " .. name .. (aura and ("  <font color='#bfb4e1' size='12'>" .. AuraData.FormatChance(aura.Chance) .. "</font>") or "")
	end
	local pet = PetData.Get(name)
	local icon = (pet and pet.Variant and PetData.Variants[pet.Variant].Icon) or "🐾"
	return icon .. " " .. PetData.Display(name) .. (pet and ("  <font color='#78ffaa' size='12'>+" .. math.floor(pet.Luck * 100 + 0.5) .. "%</font>") or "")
end

---------------------------------------------------------------------
-- Menu button
---------------------------------------------------------------------
local menuGui = player:WaitForChild("PlayerGui"):WaitForChild("CosmicMenu", 30)
local sideMenu = menuGui and menuGui:WaitForChild("SideMenu", 10)
local menuButton
if sideMenu then
	menuButton = new("TextButton", {
		Name = "TRADE", LayoutOrder = 5, Size = UDim2.fromOffset(84, 84), BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.1, AutoButtonColor = false, Text = "", Parent = sideMenu,
	}, { corner(UDim.new(0, 18)), stroke(TEAL, 2.5, 0) })
	label({ Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 6), Text = "🤝", TextSize = 38, Parent = menuButton })
	local text = label({
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 20),
		Text = "TRADE", Font = TITLE_FONT, TextSize = 16, Parent = menuButton,
	})
	textStroke(1.2).Parent = text
	UIKit.addButtonFeel(menuButton)
end

local gui = UIKit.screen("CosmicTrade", 3)

local function panelFrame(size, color)
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = size,
		BackgroundTransparency = 1, Visible = false, Parent = gui,
	})
	UIKit.addAutoScale(holder, 820)
	local panel = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.04, Parent = holder,
	}, { corner(UDim.new(0, 18)), stroke(color, 2.5, 0) })
	return holder, panel
end

local function closeButton(parent)
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = THEME.Bad, Text = "X", Font = TITLE_FONT, TextSize = 22, TextColor3 = THEME.Text, AutoButtonColor = false, Parent = parent,
	}, { corner(UDim.new(0, 10)), textStroke(1.5) })
	UIKit.addButtonFeel(b)
	return b
end

local function button(parent, text, color, props)
	local b = new("TextButton", {
		BackgroundColor3 = color, Text = text, Font = TITLE_FONT, TextSize = 16, TextColor3 = THEME.Text, AutoButtonColor = false, Parent = parent,
	}, { corner(UDim.new(0, 10)), textStroke(1.2) })
	for key, value in pairs(props or {}) do
		b[key] = value
	end
	UIKit.addButtonFeel(b)
	return b
end

local function list(parent, props)
	local frame = new("ScrollingFrame", {
		BackgroundColor3 = THEME.PanelLight, BackgroundTransparency = 0.3, BorderSizePixel = 0, ScrollBarThickness = 5,
		ScrollBarImageColor3 = TEAL, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = parent,
	}, {
		corner(UDim.new(0, 12)),
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10) }),
	})
	for key, value in pairs(props) do
		frame[key] = value
	end
	return frame
end

local function clear(frame)
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

---------------------------------------------------------------------
-- PLAYER PICKER
---------------------------------------------------------------------
local pickHolder, pickPanel = panelFrame(UDim2.fromOffset(460, 480), TEAL)
local pickTitle = label({ Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -80, 0, 38), Text = "🤝 TRADE", Font = TITLE_FONT, TextSize = 30, TextColor3 = TEAL, TextXAlignment = Enum.TextXAlignment.Left, Parent = pickPanel })
textStroke(1.5).Parent = pickTitle
local pickNote = label({ Position = UDim2.fromOffset(20, 50), Size = UDim2.new(1, -40, 0, 40), Text = "", TextSize = 14, TextWrapped = true, RichText = true, TextColor3 = THEME.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = pickPanel })
local pickList = list(pickPanel, { Position = UDim2.fromOffset(16, 96), Size = UDim2.new(1, -32, 1, -112) })
local pickClose = closeButton(pickPanel)

local pickOpen = false
local function refreshPick()
	clear(pickList)
	local meVip = isVIP(player)
	pickNote.Text = meVip and "You have <font color='#ffd76a'>👑 VIP</font>: you can trade with <b>anyone</b>!"
		or "Trading needs <font color='#ffd76a'>👑 VIP</font> for at least one of you. You can trade with players who have 👑."
	local count = 0
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			count += 1
			local allowed = not Config.Trading.RequireVIP or meVip or isVIP(other)
			local row = new("Frame", { LayoutOrder = count, Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = THEME.Panel, Parent = pickList }, { corner(UDim.new(0, 10)) })
			label({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -150, 1, 0), Text = (isVIP(other) and "👑 " or "") .. other.DisplayName, Font = TITLE_FONT, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			local b = button(row, allowed and "🤝 TRADE" or "needs VIP", allowed and THEME.Good or Color3.fromRGB(70, 66, 90), {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(120, 36),
			})
			b.Activated:Connect(function()
				if allowed then
					TradeRemote:FireServer({ Action = "Request", Target = other })
				else
					UIKit.toast("👑 One of you needs the VIP pass to trade", GOLD)
					local passId = Config.GamePasses.VIP
					if passId and passId ~= 0 then
						MarketplaceService:PromptGamePassPurchase(player, passId)
					end
				end
			end)
		end
	end
	if count == 0 then
		label({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 60), Text = "Nobody else is here yet!", TextSize = 18, TextColor3 = THEME.SubText, Parent = pickList })
	end
end

local function setPickOpen(value)
	pickOpen = value
	if value then
		UIKit.announcePanel("TradePick")
		refreshPick()
		pickHolder.Visible = true
		UIKit.popIn(pickPanel)
	else
		pickHolder.Visible = false
	end
end
if menuButton then
	menuButton.Activated:Connect(function()
		if state then
			return -- the trade window is already open
		end
		setPickOpen(not pickOpen)
	end)
end
pickClose.Activated:Connect(function()
	setPickOpen(false)
end)
Players.PlayerAdded:Connect(function()
	if pickOpen then
		refreshPick()
	end
end)
Players.PlayerRemoving:Connect(function()
	if pickOpen then
		task.defer(refreshPick)
	end
end)

---------------------------------------------------------------------
-- INCOMING REQUEST POPUP
---------------------------------------------------------------------
local popup = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -200), Size = UDim2.fromOffset(420, 120),
	BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.05, Parent = gui,
}, { corner(UDim.new(0, 16)), stroke(TEAL, 2.5, 0) })
UIKit.addAutoScale(popup)
local popupText = label({ Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 50), Text = "", Font = TITLE_FONT, TextSize = 22, TextWrapped = true, Parent = popup })
local acceptButton = button(popup, "ACCEPT", THEME.Good, { Position = UDim2.new(0.5, -170, 0, 66), Size = UDim2.fromOffset(160, 40) })
local declineButton = button(popup, "DECLINE", THEME.Bad, { Position = UDim2.new(0.5, 10, 0, 66), Size = UDim2.fromOffset(160, 40) })
local pendingFrom
local popupToken = 0
local function hidePopup()
	pendingFrom = nil
	tween(popup, 0.3, { Position = UDim2.new(0.5, 0, 0, -200) })
end
acceptButton.Activated:Connect(function()
	if pendingFrom then
		TradeRemote:FireServer({ Action = "Respond", From = pendingFrom, Accept = true })
	end
	hidePopup()
end)
declineButton.Activated:Connect(function()
	if pendingFrom then
		TradeRemote:FireServer({ Action = "Respond", From = pendingFrom, Accept = false })
	end
	hidePopup()
end)

---------------------------------------------------------------------
-- TRADE WINDOW
---------------------------------------------------------------------
local tradeHolder, tradePanel = panelFrame(UDim2.fromOffset(880, 540), TEAL)
local tradeTitle = label({ Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -40, 0, 36), Text = "", Font = TITLE_FONT, TextSize = 28, TextColor3 = TEAL, TextXAlignment = Enum.TextXAlignment.Left, Parent = tradePanel })
textStroke(1.5).Parent = tradeTitle

local function columnTitle(text, x, width, color)
	local t = label({ Position = UDim2.fromOffset(x, 54), Size = UDim2.fromOffset(width, 24), Text = text, Font = TITLE_FONT, TextSize = 18, TextColor3 = color, Parent = tradePanel })
	textStroke(1.2).Parent = t
	return t
end
-- left: your offer, middle: your inventory, right: their offer
columnTitle("📤 YOU GIVE", 16, 270, Color3.fromRGB(255, 170, 120))
local myReadyLabel = label({ Position = UDim2.fromOffset(16, 78), Size = UDim2.fromOffset(270, 18), Text = "", TextSize = 13, Parent = tradePanel })
local mineList = list(tradePanel, { Position = UDim2.fromOffset(16, 98), Size = UDim2.fromOffset(270, 340) })

columnTitle("🎒 YOUR STUFF (tap to add)", 300, 280, THEME.SubText)
local tabAuras = button(tradePanel, "✨ AURAS", TEAL, { Position = UDim2.fromOffset(300, 80), Size = UDim2.fromOffset(136, 28) })
local tabPets = button(tradePanel, "🐾 PETS", Color3.fromRGB(70, 66, 90), { Position = UDim2.fromOffset(444, 80), Size = UDim2.fromOffset(136, 28) })
local invList = list(tradePanel, { Position = UDim2.fromOffset(300, 114), Size = UDim2.fromOffset(280, 324) })

local theirTitle = columnTitle("📥 YOU GET", 594, 270, Color3.fromRGB(120, 255, 170))
local theirReadyLabel = label({ Position = UDim2.fromOffset(594, 78), Size = UDim2.fromOffset(270, 18), Text = "", TextSize = 13, Parent = tradePanel })
local theirList = list(tradePanel, { Position = UDim2.fromOffset(594, 98), Size = UDim2.fromOffset(270, 340) })

local statusLabel = label({ Position = UDim2.fromOffset(16, 446), Size = UDim2.new(1, -32, 0, 26), Text = "", Font = TITLE_FONT, TextSize = 18, RichText = true, Parent = tradePanel })
local readyButton = button(tradePanel, "✅ READY", THEME.Good, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, -110, 0, 478), Size = UDim2.fromOffset(200, 46), TextSize = 22 })
local cancelButton = button(tradePanel, "CANCEL", THEME.Bad, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 110, 0, 478), Size = UDim2.fromOffset(200, 46), TextSize = 22 })

local tab = "Aura"
local function offeredCount(kind, name)
	for _, item in ipairs(state and state.Mine or {}) do
		if item.Kind == kind and item.Name == name then
			return item.Count
		end
	end
	return 0
end

local function setItem(kind, name, count)
	TradeRemote:FireServer({ Action = "SetItem", Kind = kind, Name = name, Count = count })
	SoundFX.Play("Click")
end

local function itemRow(parent, order, item, editable)
	local row = new("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = THEME.Panel, Parent = parent }, { corner(UDim.new(0, 8)) })
	label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, editable and -110 or -60, 1, 0), Text = itemText(item.Kind, item.Name), RichText = true,
		TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = itemColor(item.Kind, item.Name), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, editable and -62 or -8, 0.5, 0), Size = UDim2.fromOffset(46, 24), Text = "x" .. item.Count, Font = TITLE_FONT, TextSize = 16, Parent = row })
	if editable then
		local minus = button(row, "−", THEME.Bad, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -32, 0.5, 0), Size = UDim2.fromOffset(26, 26), TextSize = 18 })
		local plus = button(row, "+", THEME.Good, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(26, 26), TextSize = 18 })
		minus.Activated:Connect(function()
			setItem(item.Kind, item.Name, item.Count - 1)
		end)
		plus.Activated:Connect(function()
			setItem(item.Kind, item.Name, item.Count + 1)
		end)
	end
end

local function renderInventory()
	clear(invList)
	local items = {}
	if tab == "Aura" then
		for name, count in pairs(myData.Inventory or {}) do
			local aura = AuraData.Get(name)
			if aura and count > 0 then
				table.insert(items, { Kind = "Aura", Name = name, Count = count, Sort = aura.Chance })
			end
		end
	else
		for name, count in pairs(myData.Pets or {}) do
			local pet = PetData.Get(name)
			if pet and count > 0 then
				table.insert(items, { Kind = "Pet", Name = name, Count = count, Sort = pet.Luck })
			end
		end
	end
	table.sort(items, function(a, b)
		return a.Sort > b.Sort
	end)
	for order, item in ipairs(items) do
		local left = item.Count - offeredCount(item.Kind, item.Name)
		local row = new("TextButton", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = left > 0 and THEME.Panel or Color3.fromRGB(30, 26, 44),
			Text = "", AutoButtonColor = false, Parent = invList }, { corner(UDim.new(0, 8)) })
		label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -60, 1, 0), Text = itemText(item.Kind, item.Name), RichText = true, TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = itemColor(item.Kind, item.Name), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(48, 24), Text = "x" .. left, Font = TITLE_FONT, TextSize = 15,
			TextColor3 = left > 0 and THEME.Text or THEME.SubText, Parent = row })
		UIKit.addButtonFeel(row, true)
		row.Activated:Connect(function()
			if left > 0 then
				setItem(item.Kind, item.Name, offeredCount(item.Kind, item.Name) + 1)
			end
		end)
	end
	if #items == 0 then
		label({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 50), Text = tab == "Aura" and "No auras yet" or "No pets yet", TextSize = 16, TextColor3 = THEME.SubText, Parent = invList })
	end
end

local function renderTrade()
	if not state then
		return
	end
	tradeTitle.Text = "🤝 TRADING WITH " .. string.upper(state.Partner or "?")
	theirTitle.Text = "📥 YOU GET FROM " .. string.upper(state.Partner or "?")
	clear(mineList)
	clear(theirList)
	for order, item in ipairs(state.Mine or {}) do
		itemRow(mineList, order, item, true)
	end
	for order, item in ipairs(state.Theirs or {}) do
		itemRow(theirList, order, item, false)
	end
	if #(state.Mine or {}) == 0 then
		label({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 50), Text = "Tap your stuff in the middle to add it", TextSize = 14, TextWrapped = true, TextColor3 = THEME.SubText, Parent = mineList })
	end
	if #(state.Theirs or {}) == 0 then
		label({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 50), Text = "Nothing offered yet", TextSize = 14, TextColor3 = THEME.SubText, Parent = theirList })
	end
	myReadyLabel.Text = state.MyReady and "✅ you are ready" or "not ready"
	myReadyLabel.TextColor3 = state.MyReady and THEME.Good or THEME.SubText
	theirReadyLabel.Text = state.TheirReady and "✅ they are ready" or "not ready"
	theirReadyLabel.TextColor3 = state.TheirReady and THEME.Good or THEME.SubText
	readyButton.Text = state.MyReady and "↩ UNREADY" or "✅ READY"
	readyButton.BackgroundColor3 = state.MyReady and Color3.fromRGB(90, 80, 130) or THEME.Good
	if state.Counting then
		statusLabel.Text = ("<font color='#78ffaa'>Both ready! Trading in %d...</font>"):format(Config.Trading.ConfirmSeconds)
	elseif state.MyReady then
		statusLabel.Text = "Waiting for " .. (state.Partner or "them") .. " to press READY..."
	else
		statusLabel.Text = "Check both sides carefully, then press READY. Any change un-readies you both."
	end
	renderInventory()
end

local function setTab(kind)
	tab = kind
	tabAuras.BackgroundColor3 = kind == "Aura" and TEAL or Color3.fromRGB(70, 66, 90)
	tabPets.BackgroundColor3 = kind == "Pet" and TEAL or Color3.fromRGB(70, 66, 90)
	renderInventory()
end
tabAuras.Activated:Connect(function()
	setTab("Aura")
end)
tabPets.Activated:Connect(function()
	setTab("Pet")
end)
readyButton.Activated:Connect(function()
	if state then
		TradeRemote:FireServer({ Action = "Ready", Value = not state.MyReady })
	end
end)
cancelButton.Activated:Connect(function()
	TradeRemote:FireServer({ Action = "Cancel" })
end)

local function openTrade()
	setPickOpen(false)
	UIKit.announcePanel("Trade")
	tradeHolder.Visible = true
	UIKit.popIn(tradePanel)
	setTab("Aura")
end
local function closeTrade()
	state = nil
	tradeHolder.Visible = false
end
UIKit.PanelOpened:Connect(function(name)
	if name ~= "TradePick" and pickOpen then
		setPickOpen(false)
	end
end)

---------------------------------------------------------------------
-- Messages from the server
---------------------------------------------------------------------
TradeRemote.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" then
		return
	end
	local kind = message.Type
	if kind == "Request" then
		pendingFrom = message.From
		popupText.Text = ("🤝 %s wants to trade with you!"):format(tostring(message.FromName))
		popup.Position = UDim2.new(0.5, 0, 0, -200)
		tween(popup, 0.45, { Position = UDim2.new(0.5, 0, 0, 90) }, Enum.EasingStyle.Back)
		SoundFX.Chime(1.1, 3)
		popupToken += 1
		local token = popupToken
		task.delay(15, function()
			if token == popupToken and pendingFrom then
				hidePopup()
			end
		end)
	elseif kind == "Open" then
		state = { Partner = message.Partner, Mine = {}, Theirs = {} }
		openTrade()
		renderTrade()
		SoundFX.Play("Whoosh")
	elseif kind == "Update" then
		local wasCounting = state and state.Counting
		state = message
		if not tradeHolder.Visible then
			openTrade()
		end
		renderTrade()
		if message.Counting and not wasCounting then
			SoundFX.Play("Beep")
		end
	elseif kind == "Done" then
		closeTrade()
		SoundFX.Jingle("Victory")
		UIKit.confetti({ TEAL, GOLD, Color3.new(1, 1, 1) }, 90)
		local got = {}
		for _, item in ipairs(message.Received or {}) do
			table.insert(got, ("%dx %s"):format(item.Count, item.Kind == "Pet" and PetData.Display(item.Name) or item.Name))
		end
		UIKit.toast("🤝 Trade done! You got: " .. (#got > 0 and table.concat(got, ", ") or "nothing"), TEAL)
	elseif kind == "Closed" then
		if state then
			closeTrade()
			UIKit.toast("🤝 " .. tostring(message.Reason or "Trade closed"), THEME.SubText)
		end
	elseif kind == "Error" or kind == "Info" then
		UIKit.toast(tostring(message.Message), kind == "Error" and THEME.Bad or TEAL)
		if kind == "Error" then
			SoundFX.Play("Thud")
		end
	end
end)

---------------------------------------------------------------------
-- Your inventory (for the middle column)
---------------------------------------------------------------------
DataUpdatedRemote.OnClientEvent:Connect(function(snapshot)
	if type(snapshot) == "table" then
		myData.Inventory = snapshot.Inventory or myData.Inventory
		myData.Pets = snapshot.Pets or myData.Pets
		if state then
			renderInventory()
		end
	end
end)
task.spawn(function()
	for _ = 1, 20 do
		local ok, snapshot = pcall(function()
			return GetDataRemote:InvokeServer()
		end)
		if ok and type(snapshot) == "table" then
			myData.Inventory = snapshot.Inventory or {}
			myData.Pets = snapshot.Pets or {}
			return
		end
		task.wait(1)
	end
end)
-- rolling changes your auras: refresh while trading
player:GetAttributeChangedSignal("Rolls"):Connect(function()
	if state then
		task.delay(0.3, function()
			local ok, snapshot = pcall(function()
				return GetDataRemote:InvokeServer()
			end)
			if ok and type(snapshot) == "table" then
				myData.Inventory = snapshot.Inventory or myData.Inventory
				myData.Pets = snapshot.Pets or myData.Pets
				renderInventory()
			end
		end)
	end
end)
