-- QuestClient (LocalScript in StarterPlayer > StarterPlayerScripts)
-- The 📜 QUESTS button + panel:
--   * DAILY REWARD: a 7-day streak calendar with a CLAIM button
--   * 3 DAILY QUESTS with progress bars and CLAIM buttons
--   * a bonus chest for finishing all 3
-- A red number on the button shows how many rewards are waiting. The panel
-- opens by itself when you join if today's daily reward is ready.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local QuestData = require(ReplicatedStorage:WaitForChild("QuestData"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local THEME = UIKit.Theme
local TITLE_FONT = UIKit.TitleFont
local new, corner, stroke, textStroke, tween, label =
	UIKit.new, UIKit.corner, UIKit.stroke, UIKit.textStroke, UIKit.tween, UIKit.label

local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local QuestRemote = remotes:WaitForChild("Quest")
local QuestUpdatedRemote = remotes:WaitForChild("QuestUpdated")

local PARCHMENT = Color3.fromRGB(255, 205, 120)
local state -- latest quest state from the server
local stateReceivedAt = os.clock()

---------------------------------------------------------------------
-- Menu button with a "rewards waiting" badge
---------------------------------------------------------------------
local menuGui = player:WaitForChild("PlayerGui"):WaitForChild("CosmicMenu", 30)
local sideMenu = menuGui and menuGui:WaitForChild("SideMenu", 10)
local menuButton, badge, badgeText
if sideMenu then
	menuButton = new("TextButton", {
		Name = "QUESTS", LayoutOrder = 4, Size = UDim2.fromOffset(84, 84), BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.1, AutoButtonColor = false, Text = "", Parent = sideMenu,
	}, { corner(UDim.new(0, 18)), stroke(PARCHMENT, 2.5, 0) })
	label({ Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 6), Text = "📜", TextSize = 38, Parent = menuButton })
	local text = label({
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 20),
		Text = "QUESTS", Font = TITLE_FONT, TextSize = 16, Parent = menuButton,
	})
	textStroke(1.2).Parent = text
	badge = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = THEME.Bad, Visible = false, Parent = menuButton,
	}, { corner(UDim.new(1, 0)), stroke(Color3.new(1, 1, 1), 2, 0) })
	badgeText = label({ Size = UDim2.fromScale(1, 1), Text = "", Font = TITLE_FONT, TextSize = 15, Parent = badge })
	UIKit.addButtonFeel(menuButton)
end

local function updateBadge()
	local ready = player:GetAttribute("QuestsReady") or 0
	if badge then
		badge.Visible = ready > 0
		badgeText.Text = tostring(ready)
	end
end
player:GetAttributeChangedSignal("QuestsReady"):Connect(updateBadge)
updateBadge()
task.spawn(function()
	while true do
		task.wait(0.6)
		if badge and badge.Visible then
			tween(badge, 0.3, { Size = UDim2.fromOffset(29, 29) }, Enum.EasingStyle.Sine)
			task.wait(0.3)
			tween(badge, 0.3, { Size = UDim2.fromOffset(24, 24) }, Enum.EasingStyle.Sine)
		end
	end
end)

---------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------
local gui = UIKit.screen("CosmicQuests", 2)
local holder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(680, 560),
	BackgroundTransparency = 1, Visible = false, Parent = gui,
})
UIKit.addAutoScale(holder, 820)
local panel = new("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.05, Parent = holder,
}, { corner(UDim.new(0, 18)), stroke(PARCHMENT, 2.5, 0) })
local title = label({
	Position = UDim2.fromOffset(22, 12), Size = UDim2.new(1, -80, 0, 40), Text = "📜 QUESTS & DAILY REWARDS", Font = TITLE_FONT,
	TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
})
UIKit.gradient(Color3.fromRGB(255, 230, 160), Color3.fromRGB(255, 160, 90), 0).Parent = title
local resetLabel = label({
	Position = UDim2.fromOffset(22, 50), Size = UDim2.new(1, -44, 0, 20), Text = "", TextSize = 15, RichText = true,
	TextColor3 = THEME.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
})
local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(42, 42),
	BackgroundColor3 = THEME.Bad, Text = "X", Font = TITLE_FONT, TextSize = 24, TextColor3 = THEME.Text, AutoButtonColor = false, Parent = panel,
}, { corner(UDim.new(0, 10)), textStroke(1.5) })
UIKit.addButtonFeel(closeButton)

local function sectionTitle(text, y)
	local t = label({
		Position = UDim2.fromOffset(22, y), Size = UDim2.new(1, -44, 0, 26), Text = text, Font = TITLE_FONT, TextSize = 21,
		TextColor3 = PARCHMENT, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
	})
	textStroke(1.3).Parent = t
	return t
end

local function claimButton(parent, position, size)
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = position, Size = size, BackgroundColor3 = THEME.Good,
		Text = "CLAIM", Font = TITLE_FONT, TextSize = 18, TextColor3 = THEME.Text, AutoButtonColor = false, Parent = parent,
	}, { corner(UDim.new(0, 10)), textStroke(1.3) })
	UIKit.addButtonFeel(b)
	return b
end

-- DAILY REWARD calendar --------------------------------------------
local dailyTitle = sectionTitle("🎁 DAILY REWARD", 80)
local tilesRow = new("Frame", {
	Position = UDim2.fromOffset(18, 110), Size = UDim2.new(1, -36, 0, 104), BackgroundTransparency = 1, Parent = panel,
}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
local tiles = {}
for day, reward in ipairs(QuestData.DailyRewards) do
	local big = day == #QuestData.DailyRewards
	local tile = new("Frame", {
		LayoutOrder = day, Size = UDim2.fromOffset(big and 110 or 78, 104), BackgroundColor3 = THEME.PanelLight, Parent = tilesRow,
	}, { corner(UDim.new(0, 12)) })
	local tileStroke = stroke(PARCHMENT, 1.5, 0.6)
	tileStroke.Parent = tile
	label({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 18), Text = "DAY " .. day, Font = TITLE_FONT, TextSize = 14, TextColor3 = THEME.SubText, Parent = tile })
	label({ Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 34), Text = QuestData.RewardIcon(reward), TextSize = 28, Parent = tile })
	label({ Position = UDim2.fromOffset(4, 56), Size = UDim2.new(1, -8, 0, 44), Text = QuestData.RewardText(reward):gsub(" %+ ", "\n"), TextSize = 10, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, Parent = tile })
	local check = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 2), Size = UDim2.fromOffset(22, 22), Text = "", TextSize = 16, Parent = tile })
	tiles[day] = { Frame = tile, Stroke = tileStroke, Check = check }
end
local dailyButton = claimButton(panel, UDim2.new(1, -22, 0, 94), UDim2.fromOffset(150, 30))
dailyButton.AnchorPoint = Vector2.new(1, 0.5)

-- DAILY QUESTS -----------------------------------------------------
sectionTitle("📜 TODAY'S QUESTS", 226)
local questRows = {}
for i = 1, 3 do
	local row = new("Frame", {
		Position = UDim2.fromOffset(18, 256 + (i - 1) * 74), Size = UDim2.new(1, -36, 0, 66), BackgroundColor3 = THEME.PanelLight, Parent = panel,
	}, { corner(UDim.new(0, 12)) })
	local text = label({ Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -180, 0, 22), Text = "", Font = TITLE_FONT, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local reward = label({ Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -180, 0, 16), Text = "", TextSize = 13, TextColor3 = PARCHMENT, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local barBack = new("Frame", { Position = UDim2.fromOffset(14, 48), Size = UDim2.new(1, -180, 0, 10), BackgroundColor3 = Color3.fromRGB(14, 10, 26), Parent = row }, { corner(UDim.new(1, 0)) })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = barBack }, {
		corner(UDim.new(1, 0)), UIKit.gradient(Color3.fromRGB(255, 220, 120), Color3.fromRGB(120, 255, 170), 0),
	})
	local count = label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -150, 0.5, 0), Size = UDim2.fromOffset(70, 24), Text = "", Font = TITLE_FONT, TextSize = 15, Parent = row })
	local button = claimButton(row, UDim2.new(1, -12, 0.5, 0), UDim2.fromOffset(110, 38))
	questRows[i] = { Row = row, Text = text, Reward = reward, Fill = fill, Count = count, Button = button }
end

-- BONUS chest ------------------------------------------------------
local bonusRow = new("Frame", {
	Position = UDim2.fromOffset(18, 484), Size = UDim2.new(1, -36, 0, 60), BackgroundColor3 = Color3.fromRGB(60, 44, 20), Parent = panel,
}, { corner(UDim.new(0, 12)), stroke(PARCHMENT, 1.5, 0.3) })
label({ Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(44, 60), Text = "🎁", TextSize = 32, Parent = bonusRow })
label({ Position = UDim2.fromOffset(62, 8), Size = UDim2.new(1, -200, 0, 22), Text = "Finish all 3 quests", Font = TITLE_FONT, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Parent = bonusRow })
label({ Position = UDim2.fromOffset(62, 30), Size = UDim2.new(1, -200, 0, 18), Text = QuestData.RewardText(QuestData.Bonus), TextSize = 13, TextColor3 = PARCHMENT, TextXAlignment = Enum.TextXAlignment.Left, Parent = bonusRow })
local bonusButton = claimButton(bonusRow, UDim2.new(1, -12, 0.5, 0), UDim2.fromOffset(110, 38))

---------------------------------------------------------------------
-- Filling it in
---------------------------------------------------------------------
local function setButton(button, mode)
	-- mode: "ready", "done" or "locked"
	if mode == "ready" then
		button.Text = "CLAIM"
		button.BackgroundColor3 = THEME.Good
	elseif mode == "done" then
		button.Text = "✅ DONE"
		button.BackgroundColor3 = Color3.fromRGB(50, 90, 70)
	else
		button.Text = "..."
		button.BackgroundColor3 = Color3.fromRGB(70, 66, 90)
	end
end

local function render()
	if not state then
		return
	end
	-- daily calendar
	local daily = state.Daily
	for day, tile in ipairs(tiles) do
		local isToday = day == daily.DayIndex
		local claimedToday = isToday and not daily.CanClaim
		tile.Check.Text = (day < daily.DayIndex or claimedToday) and "✅" or ""
		tile.Frame.BackgroundColor3 = isToday and (daily.CanClaim and Color3.fromRGB(80, 60, 30) or Color3.fromRGB(40, 60, 50)) or THEME.PanelLight
		tile.Stroke.Transparency = isToday and 0 or 0.6
		tile.Stroke.Thickness = isToday and 3 or 1.5
	end
	dailyTitle.Text = ("🎁 DAILY REWARD  <font color='#bfb4e1' size='15'>streak: %d day%s</font>"):format(daily.Streak, daily.Streak == 1 and "" or "s")
	dailyTitle.RichText = true
	setButton(dailyButton, daily.CanClaim and "ready" or "done")
	if not daily.CanClaim then
		dailyButton.Text = "COME BACK TOMORROW"
		dailyButton.TextSize = 12
	else
		dailyButton.TextSize = 18
	end
	-- quests
	for i, rowUi in ipairs(questRows) do
		local q = state.Quests[i]
		local def = q and QuestData.ById[q.Id]
		rowUi.Row.Visible = def ~= nil
		if def then
			rowUi.Text.Text = def.Text
			rowUi.Reward.Text = "Reward: " .. QuestData.RewardText(def.Reward)
			rowUi.Count.Text = ("%d/%d"):format(q.Progress, q.Goal)
			tween(rowUi.Fill, 0.3, { Size = UDim2.fromScale(math.clamp(q.Progress / q.Goal, 0, 1), 1) })
			setButton(rowUi.Button, q.Claimed and "done" or (q.Done and "ready" or "locked"))
		end
	end
	setButton(bonusButton, state.BonusClaimed and "done" or (state.BonusReady and "ready" or "locked"))
end

local function claimed(granted)
	if granted then
		SoundFX.Chime(1, 5)
		UIKit.burst({ PARCHMENT, THEME.Good, Color3.new(1, 1, 1) }, 30, 1, Vector2.new(0.5, 0.45))
		UIKit.toast("🎁 " .. QuestData.RewardText(granted), PARCHMENT)
	end
end

local function call(action, index)
	local ok, result = pcall(function()
		return QuestRemote:InvokeServer(action, index)
	end)
	if ok and type(result) == "table" then
		state = result.State or state
		stateReceivedAt = os.clock()
		render()
		claimed(result.Granted)
	end
end

dailyButton.Activated:Connect(function()
	if state and state.Daily.CanClaim then
		call("ClaimDaily")
	end
end)
for i, rowUi in ipairs(questRows) do
	rowUi.Button.Activated:Connect(function()
		local q = state and state.Quests[i]
		if q and q.Done and not q.Claimed then
			call("ClaimQuest", i)
		end
	end)
end
bonusButton.Activated:Connect(function()
	if state and state.BonusReady then
		call("ClaimBonus")
	end
end)

QuestUpdatedRemote.OnClientEvent:Connect(function(newState)
	local hadDaily = state and state.Daily.CanClaim
	state = newState
	stateReceivedAt = os.clock()
	render()
	-- a quest just finished: let the player know
	for i, q in ipairs(newState.Quests or {}) do
		local def = QuestData.ById[q.Id]
		if def and q.Done and not q.Claimed and not (questRows[i].Announced == q.Id) then
			questRows[i].Announced = q.Id
			UIKit.toast("📜 Quest done: " .. def.Text .. " - claim it in QUESTS!", PARCHMENT)
			SoundFX.Chime(1.2, 4)
		end
	end
	if newState.Daily and newState.Daily.CanClaim and hadDaily == false then
		UIKit.toast("🎁 A new daily reward is ready!", PARCHMENT)
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
		UIKit.announcePanel("Quests")
		render()
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
	if name ~= "Quests" then
		setOpen(false)
	end
end)

-- the reset countdown
RunService.Heartbeat:Connect(function()
	if open and state then
		local left = math.max(0, (state.ResetIn or 0) - (os.clock() - stateReceivedAt))
		resetLabel.Text = ("New quests and daily reward in <b>%d:%02d:%02d</b>"):format(left // 3600, (left % 3600) // 60, left % 60)
	end
end)

-- get the quests when we start (the server also sends updates by itself)
task.spawn(function()
	for _ = 1, 20 do
		local ok, result = pcall(function()
			return QuestRemote:InvokeServer("Get")
		end)
		if ok and type(result) == "table" and result.State then
			state = result.State
			stateReceivedAt = os.clock()
			render()
			return
		end
		task.wait(1)
	end
end)

-- show the daily reward when you join (after the intro)
task.delay(5, function()
	if state and state.Daily.CanClaim then
		setOpen(true)
	end
end)
