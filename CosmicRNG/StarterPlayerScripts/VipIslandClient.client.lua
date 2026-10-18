-- VipIslandClient (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Lucky Isle extras on your screen:
--   * 🎡 LUCKY WHEEL: press E to spin, the wheel spins and lands on your
--     prize, with your own countdown shown above it
--   * 🎁 VIP CHEST in the VIP Sanctum (once a day, VIP pass)
--   * 👑 VIP SANCTUM: a popup with the extra luck when you walk in, and a
--     "VIP only" message (with the VIP pass offer) if you don't have VIP

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local Luck = require(ReplicatedStorage:WaitForChild("Luck"))
local QuestData = require(ReplicatedStorage:WaitForChild("QuestData"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local THEME = UIKit.Theme
local GOLD = Color3.fromRGB(255, 200, 70)

local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local WheelRemote = remotes:WaitForChild("SpinWheel")
local VipChestRemote = remotes:WaitForChild("VipChest")
local PortalFXRemote = remotes:WaitForChild("PortalFX", 30)

local function promptVip()
	local passId = Config.GamePasses.VIP
	if passId and passId ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, passId)
	end
end

local island = workspace:WaitForChild("LuckyIsland", 60)
if not island then
	return
end
local wheel = island:WaitForChild("LuckyWheel", 30)
local spinModel = wheel and wheel:WaitForChild("WheelSpin", 10)
local stand = wheel and wheel:WaitForChild("WheelStand", 10)
local sanctum = island:WaitForChild("VipSanctum", 30)
local chest = sanctum and sanctum:WaitForChild("VipChest", 10)

---------------------------------------------------------------------
-- 🎡 LUCKY WHEEL
---------------------------------------------------------------------
local prizes = Config.LuckyWheel.Prizes
local basePivot = spinModel and spinModel:GetPivot()
local bulbs = {}
if spinModel then
	for _, p in ipairs(spinModel:GetChildren()) do
		if p:GetAttribute("Bulb") then
			table.insert(bulbs, p)
		end
	end
end
local currentAngle = 0
local spinning = false

-- your own countdown above the wheel
local timerGui
if stand then
	timerGui = Instance.new("BillboardGui")
	timerGui.Name = "WheelTimer"
	timerGui.Adornee = stand
	timerGui.Size = UDim2.new(8, 0, 1.4, 0)
	timerGui.StudsOffset = Vector3.new(0, 18, 0)
	timerGui.MaxDistance = 90
	timerGui.LightInfluence = 0
	timerGui.AlwaysOnTop = true
	timerGui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextTransparency = 0.1
	label.Parent = timerGui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = label
end

RunService.Heartbeat:Connect(function()
	if not timerGui then
		return
	end
	local label = timerGui:FindFirstChild("Text")
	local left = (player:GetAttribute("WheelNext") or 0) - os.time()
	if spinning then
		label.Text = "🎡 SPINNING..."
		label.TextColor3 = GOLD
	elseif left <= 0 then
		label.Text = "🎡 FREE SPIN READY!"
		label.TextColor3 = Color3.fromRGB(120, 255, 170)
	else
		label.Text = ("🎡 next spin in %d:%02d"):format(left // 60, left % 60)
		label.TextColor3 = Color3.fromRGB(220, 210, 255)
	end
end)

local function setWheel(angle)
	if spinModel and basePivot then
		spinModel:PivotTo(basePivot * CFrame.Angles(0, 0, angle))
	end
end

local function spinTo(index)
	spinning = true
	local count = #prizes
	local sliceAngle = (index - 1) / count * math.pi * 2
	-- a few full turns, then stop with the prize under the pointer
	local wiggleRoom = (math.random() - 0.5) * (math.pi * 2 / count) * 0.6
	local target = -sliceAngle - math.pi * 2 * 6 + wiggleRoom
	-- start from where it is now (keep it between 0 and one turn)
	local start = currentAngle % (math.pi * 2)
	local duration = 4.4
	local began = os.clock()
	local lastSlice = math.floor(start / (math.pi * 2 / count))
	SoundFX.Play("Whoosh", { Speed = 0.8 })
	while true do
		local f = math.min(1, (os.clock() - began) / duration)
		local eased = 1 - (1 - f) ^ 3
		currentAngle = start + (target - start) * eased
		setWheel(currentAngle)
		-- tick as each slice passes the pointer
		local slice = math.floor(currentAngle / (math.pi * 2 / count))
		if slice ~= lastSlice then
			lastSlice = slice
			SoundFX.Play("Tick", { Speed = 0.9 + (1 - f) * 0.6, Volume = 0.8 })
		end
		for i, bulb in ipairs(bulbs) do
			bulb.Color = ((math.floor(os.clock() * 12) + i) % 2 == 0) and GOLD or Color3.new(1, 1, 1)
		end
		if f >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	-- winner!
	local prize = prizes[index]
	for _ = 1, 6 do
		for _, bulb in ipairs(bulbs) do
			bulb.Color = prize.Color
		end
		task.wait(0.1)
		for _, bulb in ipairs(bulbs) do
			bulb.Color = Color3.new(1, 1, 1)
		end
		task.wait(0.1)
	end
	local jackpot = index >= #prizes - 1
	if jackpot then
		SoundFX.Jingle("Victory")
		UIKit.confetti({ prize.Color, GOLD, Color3.new(1, 1, 1) }, 120)
	else
		SoundFX.Chime(1, 5)
	end
	UIKit.burst({ prize.Color, GOLD, Color3.new(1, 1, 1) }, 40, 1.2, Vector2.new(0.5, 0.4))
	UIKit.toast("🎡 You won: " .. prize.Label .. "!", GOLD)
	spinning = false
end

if stand then
	local prompt = stand:WaitForChild("WheelPrompt", 10)
	if prompt then
		prompt.Triggered:Connect(function()
			if spinning then
				return
			end
			local ok, result = pcall(function()
				return WheelRemote:InvokeServer()
			end)
			if ok and type(result) == "table" and result.Index then
				spinTo(result.Index)
			elseif ok and type(result) == "table" and result.Error == "Cooldown" then
				local left = result.Left or 0
				UIKit.toast(("🎡 Next free spin in %d:%02d%s"):format(left // 60, left % 60,
					player:GetAttribute("Pass_VIP") and "" or " (VIP: every 15 min!)"), THEME.SubText)
				SoundFX.Play("Thud")
			else
				UIKit.toast("🎡 Walk up to the wheel to spin it", THEME.SubText)
			end
		end)
	end
end

---------------------------------------------------------------------
-- 🎁 VIP CHEST
---------------------------------------------------------------------
if chest then
	local prompt = chest:WaitForChild("ChestPrompt", 10)
	if prompt then
		prompt.Triggered:Connect(function()
			local ok, result = pcall(function()
				return VipChestRemote:InvokeServer()
			end)
			if ok and type(result) == "table" and result.Granted then
				SoundFX.Jingle("Victory")
				UIKit.confetti({ GOLD, Color3.fromRGB(255, 130, 190), Color3.new(1, 1, 1) }, 100)
				UIKit.toast("🎁 VIP Chest: " .. QuestData.RewardText(result.Granted), GOLD)
			elseif ok and type(result) == "table" and result.Error == "NotVIP" then
				UIKit.toast("👑 The VIP Chest is for VIP pass owners", GOLD)
				promptVip()
			elseif ok and type(result) == "table" and result.Error == "Claimed" then
				local left = result.ResetIn or 0
				UIKit.toast(("🎁 Already opened today - come back in %dh %dm"):format(left // 3600, (left % 3600) // 60), THEME.SubText)
			end
		end)
	end
end

---------------------------------------------------------------------
-- 👑 VIP SANCTUM
---------------------------------------------------------------------
local wasIn = false
player:GetAttributeChangedSignal("InVIPSanctum"):Connect(function()
	local inside = player:GetAttribute("InVIPSanctum") == true
	if inside == wasIn then
		return
	end
	wasIn = inside
	if inside then
		local multiplier = Config.LuckyIsland.Sanctum.LuckMultiplier
		local after = Luck.Get(player)
		UIKit.luckBoost("👑", "VIP Sanctum", multiplier, after / multiplier, after, GOLD)
	end
end)

if PortalFXRemote then
	local lastDenied = 0
	PortalFXRemote.OnClientEvent:Connect(function(kind)
		if kind == "DeniedSanctum" and os.clock() - lastDenied > 4 then
			lastDenied = os.clock()
			UIKit.toast("👑 The VIP Sanctum is for VIP pass owners only!", GOLD)
			SoundFX.Play("Thud")
			promptVip()
		end
	end)
end
