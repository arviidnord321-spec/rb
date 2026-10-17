-- Rebirth (ModuleScript in ReplicatedStorage)
-- The rebirth rules in one place, used by the server (to check and grant
-- rebirths) and by the screen (to show progress), so they always match.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))

local R = Config.Rebirth
local Rebirth = {}

-- What rebirth number n+1 costs when you have n rebirths
function Rebirth.Cost(n)
	n = n or 0
	local rolls = math.floor(R.BaseRolls * R.RollGrowth ^ n / 10 + 0.5) * 10
	local rarity = math.min(R.MaxRarity, R.BaseRarity * R.RarityGrowth ^ n)
	return { Rolls = rolls, Rarity = rarity }
end

-- Permanent luck from rebirths (1 = none)
function Rebirth.LuckMultiplier(n)
	return 1 + (n or 0) * R.LuckPerRebirth
end

-- Roll cooldown is multiplied by this (1 = normal, 0.7 = 30% faster)
function Rebirth.CooldownScale(n)
	return 1 - math.min(R.MaxRollSpeed, (n or 0) * R.RollSpeedPerRebirth)
end

function Rebirth.HasPerk(n, perkName)
	for _, perk in ipairs(R.Perks) do
		if perk.Name == perkName then
			return (n or 0) >= perk.Rebirths
		end
	end
	return false
end

-- Perks you get on exactly this rebirth number
function Rebirth.PerksAt(n)
	local list = {}
	for _, perk in ipairs(R.Perks) do
		if perk.Rebirths == n then
			table.insert(list, perk)
		end
	end
	return list
end

-- Progress for the screen: rolls done / needed, best aura since last rebirth
function Rebirth.Progress(player)
	local n = player:GetAttribute("Rebirths") or 0
	local cost = Rebirth.Cost(n)
	local rolls = player:GetAttribute("RebirthRolls") or 0
	local best = player:GetAttribute("RebirthBest") or 0
	return {
		Rebirths = n,
		Cost = cost,
		Rolls = rolls,
		Best = best,
		RollsDone = rolls >= cost.Rolls,
		RarityDone = best >= cost.Rarity,
		Ready = rolls >= cost.Rolls and best >= cost.Rarity,
	}
end

-- ⭐ text for name tags: "★3"
function Rebirth.Stars(n)
	if not n or n <= 0 then
		return ""
	end
	if n <= 3 then
		return string.rep("★", n)
	end
	return "★" .. n
end

-- Each rebirth level gets its own color (tags, trail)
local COLORS = {
	Color3.fromRGB(140, 220, 255), -- 1 ice
	Color3.fromRGB(255, 140, 50), -- 2 ember
	Color3.fromRGB(255, 80, 220), -- 3 neon
	Color3.fromRGB(120, 255, 150), -- 4 emerald
	Color3.fromRGB(255, 215, 80), -- 5+ gold
}
function Rebirth.Color(n)
	if not n or n <= 0 then
		return Color3.new(1, 1, 1)
	end
	return COLORS[math.min(n, #COLORS)]
end

return Rebirth
