-- Leaderboard (Script in ServerScriptService)
-- Fills the "TOP ROLLERS" board on the island with the top 10 players
-- of ALL servers (needs saving enabled, see README).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))

local island = workspace:WaitForChild("CosmicIsland")
local board = island:WaitForChild("LeaderboardBoard")
local list = board:WaitForChild("Gui"):WaitForChild("Panel"):WaitForChild("List")
local status = board.Gui.Panel:WaitForChild("Status")

local ok, orderedStore = pcall(function()
	return DataStoreService:GetOrderedDataStore(Config.LeaderboardStoreName)
end)
if not ok then
	orderedStore = nil
end

local nameCache = {}
local function getName(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local success, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = success and name or ("Player " .. userId)
	return nameCache[userId]
end

local RANK_COLORS = {
	Color3.fromRGB(255, 210, 80), -- gold
	Color3.fromRGB(210, 220, 235), -- silver
	Color3.fromRGB(230, 150, 90), -- bronze
}

local function makeRow(rank, name, rolls)
	local row = Instance.new("Frame")
	row.Name = "Row" .. rank
	row.LayoutOrder = rank
	row.Size = UDim2.new(1, 0, 0, 52)
	row.BackgroundColor3 = (rank % 2 == 0) and Color3.fromRGB(34, 28, 62) or Color3.fromRGB(26, 21, 48)
	row.BackgroundTransparency = 0.15
	row.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = row

	local function text(value, x, width, align, color, font)
		local labelObj = Instance.new("TextLabel")
		labelObj.BackgroundTransparency = 1
		labelObj.Position = UDim2.new(x, 0, 0, 0)
		labelObj.Size = UDim2.new(width, 0, 1, 0)
		labelObj.Font = font or Enum.Font.GothamBold
		labelObj.TextScaled = true
		labelObj.TextColor3 = color or Color3.new(1, 1, 1)
		labelObj.TextXAlignment = align
		labelObj.Text = value
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 10)
		pad.PaddingBottom = UDim.new(0, 10)
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = labelObj
		labelObj.Parent = row
	end

	text("#" .. rank, 0, 0.18, Enum.TextXAlignment.Left, RANK_COLORS[rank] or Color3.fromRGB(190, 180, 225), Enum.Font.FredokaOne)
	text(name, 0.16, 0.5, Enum.TextXAlignment.Left)
	text(AuraData.FormatNumber(rolls), 0.62, 0.38, Enum.TextXAlignment.Right, Color3.fromRGB(140, 220, 255), Enum.Font.FredokaOne)
	row.Parent = list
end

local function clearRows()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

-- Fallback when saving is off: show players in this server
local function showLocal()
	clearRows()
	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		return (a:GetAttribute("Rolls") or 0) > (b:GetAttribute("Rolls") or 0)
	end)
	for rank = 1, math.min(10, #players) do
		makeRow(rank, players[rank].DisplayName, players[rank]:GetAttribute("Rolls") or 0)
	end
	status.Text = "This server (enable saving for global)"
end

local function refresh()
	if not orderedStore then
		showLocal()
		return
	end
	-- 1) push current players' roll counts
	for _, player in ipairs(Players:GetPlayers()) do
		local rolls = player:GetAttribute("Rolls")
		if rolls and rolls > 0 then
			pcall(function()
				orderedStore:SetAsync(tostring(player.UserId), rolls)
			end)
		end
	end
	-- 2) read the top 10
	local success, pages = pcall(function()
		return orderedStore:GetSortedAsync(false, 10)
	end)
	if not success then
		showLocal()
		return
	end
	clearRows()
	for rank, entry in ipairs(pages:GetCurrentPage()) do
		makeRow(rank, getName(tonumber(entry.key)), entry.value)
	end
	status.Text = "All servers • updates every " .. Config.LeaderboardRefresh .. "s"
end

Players.PlayerRemoving:Connect(function(player)
	local rolls = player:GetAttribute("Rolls")
	if orderedStore and rolls and rolls > 0 then
		pcall(function()
			orderedStore:SetAsync(tostring(player.UserId), rolls)
		end)
	end
end)

task.wait(5) -- let players load first
while true do
	refresh()
	task.wait(Config.LeaderboardRefresh)
end
