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

	-- Standing on Lucky Isle (the server sets this, so it can't be faked)
	if player:GetAttribute("OnLuckyIsland") then
		table.insert(bonuses, { Name = "Lucky Isle", Multiplier = Config.LuckyIsland.LuckMultiplier, Show = true, Island = true })
	end
	-- the VIP Sanctum on Lucky Isle stacks on top
	if player:GetAttribute("InVIPSanctum") then
		table.insert(bonuses, { Name = "VIP Sanctum", Icon = "👑", Multiplier = Config.LuckyIsland.Sanctum.LuckMultiplier, Show = true })
	end

	-- Rebirths: permanent luck
	local rebirths = player:GetAttribute("Rebirths") or 0
	if rebirths > 0 then
		table.insert(bonuses, { Name = "Rebirth", Multiplier = 1 + rebirths * Config.Rebirth.LuckPerRebirth })
	end

	-- Standing on a rebirth island (set by the RebirthIslands script)
	local islandKey = player:GetAttribute("OnRebirthIsland")
	if islandKey then
		for _, islandInfo in ipairs(Config.RebirthIslands) do
			if islandInfo.Key == islandKey then
				table.insert(bonuses, { Name = islandInfo.Name, Icon = islandInfo.Icon, Multiplier = islandInfo.LuckMultiplier, Show = true, Island = true })
			end
		end
	end

	-- Parkour reward (finish a course)
	local parkourEnd = player:GetAttribute("ParkourLuckEnd") or 0
	if parkourEnd > now then
		table.insert(bonuses, { Name = "Parkour", Multiplier = player:GetAttribute("ParkourLuckMultiplier") or 1.5, EndsAt = parkourEnd })
	end

	-- Equipped pets (the server works this out and sets it)
	local petLuck = player:GetAttribute("PetLuck") or 1
	if petLuck > 1 then
		table.insert(bonuses, { Name = "Pets", Multiplier = petLuck, Show = true })
	end

	-- Permanent luck (Limited Offer)
	local permanent = player:GetAttribute("PermanentLuck") or 1
	if permanent > 1 then
		table.insert(bonuses, { Name = "Forever", Multiplier = permanent })
	end

	-- Cosmic Roll from the Cosmic Drop: huge luck on the NEXT roll only
	if (player:GetAttribute("BoostRolls") or 0) > 0 then
		table.insert(bonuses, { Name = "Cosmic Roll", Multiplier = Config.Drop.BoostMultiplier, Show = true, NextRoll = true })
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
	if (player:GetAttribute("Rebirths") or 0) >= 4 then
		return Config.Rebirth.LuckyEveryAt4
	end
	return Config.LuckyRollEvery
end

-- The island bonus (Lucky Isle or a rebirth island) you're standing on, or nil.
-- Islands multiply ALL your other luck: x30 luck on an x2 island = x60.
function Luck.IslandBonus(player)
	for _, bonus in ipairs(Luck.GetBonuses(player)) do
		if bonus.Island then
			return bonus
		end
	end
	return nil
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
