-- Luck (ModuleScript in ReplicatedStorage)
-- One place that works out a player's luck, used by BOTH the server
-- (for real rolls) and the screen (to show "Luck x5"), so they always match.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))

local Luck = {}

-- Same clock on server and clients (seconds since 1970)
function Luck.Now()
	return workspace:GetServerTimeNow()
end

-- Returns a list of active bonuses: { Name, Multiplier, EndsAt (or nil) }
function Luck.GetBonuses(player)
	local bonuses = {}
	local m = Config.LuckMultipliers
	local now = Luck.Now()

	if player:GetAttribute("Pass_DoubleLuck") then
		table.insert(bonuses, { Name = "2x Luck", Multiplier = m.DoubleLuck })
	end
	if player:GetAttribute("Pass_VIP") then
		table.insert(bonuses, { Name = "VIP", Multiplier = m.VIP })
	end

	local personalEnd = player:GetAttribute("PersonalLuckEnd") or 0
	if personalEnd > now then
		table.insert(bonuses, { Name = "Potion", Multiplier = m.PersonalBoost, EndsAt = personalEnd })
	end

	local serverEnd = ReplicatedStorage:GetAttribute("ServerLuckEnd") or 0
	if serverEnd > now then
		table.insert(bonuses, { Name = "Server", Multiplier = m.ServerBoost, EndsAt = serverEnd })
	end

	-- Reserved for events in a later part
	local eventLuck = ReplicatedStorage:GetAttribute("EventLuck")
	if eventLuck and eventLuck > 1 then
		table.insert(bonuses, { Name = "Event", Multiplier = eventLuck })
	end

	return bonuses
end

function Luck.Get(player)
	local total = Config.BaseLuck
	for _, bonus in ipairs(Luck.GetBonuses(player)) do
		total *= bonus.Multiplier
	end
	return total
end

function Luck.LuckyEvery(player)
	if player:GetAttribute("Pass_LuckyCharm") then
		return Config.LuckyCharmEvery
	end
	return Config.LuckyRollEvery
end

function Luck.Format(n)
	if math.abs(n - math.floor(n + 0.5)) < 0.001 then
		return tostring(math.floor(n + 0.5))
	end
	local text = string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", "")
	return text
end

-- 125 -> "2:05"
function Luck.FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Luck
