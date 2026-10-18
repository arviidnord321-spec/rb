-- AuraData (ModuleScript in ReplicatedStorage)
-- Every aura in the game: odds, tier, colors and its duel power.
-- To add an aura, copy one entry and change it. Names must be unique.

local AuraData = {}

---------------------------------------------------------------------
-- TIERS: how strong/flashy each rarity group is.
-- Duel stats scale with the tier, so rarer auras = stronger in 1v1s.
---------------------------------------------------------------------
AuraData.Tiers = {
	Common    = { Order = 1, Color = Color3.fromRGB(200, 205, 220), MaxHealth = 100, AttackDamage = 6 },
	Uncommon  = { Order = 2, Color = Color3.fromRGB(110, 230, 140), MaxHealth = 115, AttackDamage = 7 },
	Rare      = { Order = 3, Color = Color3.fromRGB(90, 170, 255), MaxHealth = 130, AttackDamage = 8 },
	Epic      = { Order = 4, Color = Color3.fromRGB(190, 110, 255), MaxHealth = 150, AttackDamage = 10 },
	Legendary = { Order = 5, Color = Color3.fromRGB(255, 200, 70), MaxHealth = 175, AttackDamage = 12 },
	Mythic    = { Order = 6, Color = Color3.fromRGB(255, 80, 140), MaxHealth = 210, AttackDamage = 14 },
	Secret    = { Order = 7, Color = Color3.fromRGB(255, 255, 255), MaxHealth = 260, AttackDamage = 17 },
	Divine    = { Order = 8, Color = Color3.fromRGB(255, 236, 150), MaxHealth = 320, AttackDamage = 21 },
	Transcendent = { Order = 9, Color = Color3.fromRGB(140, 255, 235), MaxHealth = 400, AttackDamage = 26 },
}

---------------------------------------------------------------------
-- POWER TYPES (the duel code in a later part reads these):
--  Projectile : fires Count orbs (Spread degrees apart) that deal Damage
--  Dash       : dashes Distance studs forward, damages anyone hit
--  Shield     : absorbs Amount damage for Duration seconds
--  Heal       : heals Amount (and optional Shield amount)
--  Burst      : explosion around you, Radius studs, optional Knockback
--  Meteor     : drops Count meteors on the enemy after a short delay
--  Freeze     : hits the enemy and stuns them for Duration seconds
--  Drain      : damages and heals you for Lifesteal (0-1) of the damage
--  Beam       : instant laser of Range studs
--  Pull       : drags the enemy toward you, then damages (+ optional Stun)
--  Teleport   : blinks behind the enemy and strikes (+ optional Stun)
--
-- Extra effects any power can have:
--  Burn    = { Damage, Ticks, Interval }  damage over time
--  Regen   = { Amount, Ticks, Interval }  healing over time
--  Pierce  = true    ignores shields
--  Reflect = 0-1     (Shield) sends that part of each hit back
--  Dodge   = seconds (Dash) untouchable after dashing
---------------------------------------------------------------------

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Ordered from most common to rarest.
AuraData.List = {
	-- COMMON ---------------------------------------------------------
	{
		Name = "Stardust", Chance = 2, Tier = "Common",
		Colors = { rgb(235, 235, 255), rgb(170, 180, 255) },
		Power = { Name = "Star Toss", Type = "Projectile", Damage = 9, Count = 1, Speed = 75, Cooldown = 2.5,
			Description = "Throws a quick little star. Short cooldown." },
	},
	{
		Name = "Moonbeam", Chance = 4, Tier = "Common",
		Colors = { rgb(210, 230, 255), rgb(140, 170, 230) },
		Power = { Name = "Moon Shield", Type = "Shield", Amount = 18, Duration = 4, Reflect = 0.4, Cooldown = 8,
			Description = "Blocks 18 damage and reflects 40% of hits back." },
	},
	{
		Name = "Twilight", Chance = 8, Tier = "Common",
		Colors = { rgb(255, 150, 120), rgb(120, 80, 170) },
		Power = { Name = "Dusk Dash", Type = "Dash", Damage = 12, Distance = 22, Dodge = 0.7, Cooldown = 5,
			Description = "Dash through enemies and become untouchable for 0.7s." },
	},

	-- UNCOMMON -------------------------------------------------------
	{
		Name = "Comet", Chance = 16, Tier = "Uncommon",
		Colors = { rgb(120, 220, 255), rgb(255, 255, 255) },
		Power = { Name = "Comet Strike", Type = "Projectile", Damage = 14, Count = 1, Speed = 120, Cooldown = 4,
			Burn = { Damage = 2, Ticks = 4, Interval = 0.5 },
			Description = "A very fast comet that sets your opponent on fire." },
	},
	{
		Name = "Aurora", Chance = 32, Tier = "Uncommon",
		Colors = { rgb(90, 255, 170), rgb(150, 110, 255) },
		Power = { Name = "Aurora Mend", Type = "Heal", Amount = 16, Cooldown = 9,
			Regen = { Amount = 3, Ticks = 5, Interval = 1 },
			Description = "Heals 16 HP, then 3 HP every second for 5s." },
	},
	{
		Name = "Meteor", Chance = 64, Tier = "Uncommon",
		Colors = { rgb(255, 130, 50), rgb(120, 60, 40) },
		Power = { Name = "Meteor Drop", Type = "Meteor", Damage = 22, Count = 1, Radius = 8, Delay = 0.8, Cooldown = 7,
			Burn = { Damage = 3, Ticks = 3, Interval = 0.6 },
			Description = "A flaming meteor that leaves your opponent burning." },
	},

	-- RARE -----------------------------------------------------------
	{
		Name = "Nebula", Chance = 128, Tier = "Rare",
		Colors = { rgb(255, 90, 200), rgb(90, 120, 255) },
		Power = { Name = "Nebula Cloud", Type = "Burst", Damage = 18, Radius = 14, Slow = 0.5, SlowDuration = 3, Cooldown = 7,
			Description = "A gas cloud bursts out, damaging and slowing." },
	},
	{
		Name = "Pulsar", Chance = 256, Tier = "Rare",
		Colors = { rgb(80, 200, 255), rgb(30, 60, 200) },
		Power = { Name = "Pulse Wave", Type = "Burst", Damage = 22, Radius = 16, Knockback = 60, Cooldown = 6,
			Description = "A shockwave that blasts enemies away." },
	},
	{
		Name = "Frostmoon", Chance = 512, Tier = "Rare", Special = "Snow",
		Colors = { rgb(200, 240, 255), rgb(90, 170, 255) },
		Power = { Name = "Frost Lock", Type = "Freeze", Damage = 15, Duration = 1.5, Range = 40, Cooldown = 9,
			Description = "Freezes your opponent solid for 1.5s." },
	},

	-- EPIC -----------------------------------------------------------
	{
		Name = "Solar Flare", Chance = 1000, Tier = "Epic", Special = "Fire",
		Colors = { rgb(255, 210, 60), rgb(255, 90, 20) },
		Power = { Name = "Flare Beam", Type = "Beam", Damage = 32, Range = 60, Cooldown = 8,
			Burn = { Damage = 4, Ticks = 4, Interval = 0.5 },
			Description = "A searing sun beam that burns for 16 more damage." },
	},
	{
		Name = "Eclipse", Chance = 2500, Tier = "Epic", Special = "Dark",
		Colors = { rgb(30, 20, 40), rgb(255, 170, 60) },
		Power = { Name = "Shadow Drain", Type = "Drain", Damage = 30, Lifesteal = 0.5, Range = 40, Cooldown = 8,
			Description = "Steals 30 HP, healing you for half." },
	},
	{
		Name = "Starfall", Chance = 5000, Tier = "Epic",
		Colors = { rgb(255, 240, 150), rgb(120, 140, 255) },
		Power = { Name = "Star Rain", Type = "Meteor", Damage = 15, Count = 3, Radius = 7, Delay = 0.6, Cooldown = 9,
			Description = "Three falling stars rain on your opponent." },
	},

	-- LEGENDARY ------------------------------------------------------
	{
		Name = "Supernova", Chance = 10000, Tier = "Legendary", Special = "Fire",
		Colors = { rgb(255, 250, 200), rgb(255, 120, 40) },
		Power = { Name = "Nova Burst", Type = "Burst", Damage = 45, Radius = 22, Knockback = 80, Cooldown = 9,
			Description = "You explode like a dying star." },
	},
	{
		Name = "Quasar", Chance = 25000, Tier = "Legendary",
		Colors = { rgb(120, 255, 255), rgb(200, 80, 255) },
		Power = { Name = "Quasar Lance", Type = "Beam", Damage = 50, Range = 90, Pierce = true, Cooldown = 8,
			Description = "A long-range lance that goes straight through shields." },
	},
	{
		Name = "Celestial", Chance = 50000, Tier = "Legendary",
		Colors = { rgb(255, 245, 210), rgb(255, 215, 120) },
		Power = { Name = "Divine Light", Type = "Heal", Amount = 40, Shield = 30, Duration = 5, Cooldown = 12,
			Regen = { Amount = 4, Ticks = 5, Interval = 1 },
			Description = "Heals 40 HP + 4/s, and grants a 30 HP shield." },
	},

	-- MYTHIC ---------------------------------------------------------
	{
		Name = "Black Hole", Chance = 100000, Tier = "Mythic", Special = "Inward",
		Colors = { rgb(10, 0, 20), rgb(170, 60, 255) },
		Power = { Name = "Event Horizon", Type = "Pull", Damage = 55, Range = 50, Cooldown = 10,
			Description = "Sucks your opponent in and crushes them." },
	},
	{
		Name = "Galaxy", Chance = 250000, Tier = "Mythic", Special = "Rainbow",
		Colors = { rgb(255, 100, 220), rgb(80, 200, 255) },
		Power = { Name = "Galactic Barrage", Type = "Projectile", Damage = 14, Count = 5, Spread = 12, Speed = 100, Cooldown = 9,
			Description = "Fires a fan of five star orbs." },
	},
	{
		Name = "Cosmic Rift", Chance = 500000, Tier = "Mythic",
		Colors = { rgb(255, 40, 120), rgb(40, 255, 220) },
		Power = { Name = "Rift Step", Type = "Teleport", Damage = 60, Range = 60, Stun = 0.8, Cooldown = 9,
			Description = "Strikes from behind and stuns for 0.8s." },
	},

	-- SECRET ---------------------------------------------------------
	{
		Name = "Big Bang", Chance = 1000000, Tier = "Secret", Special = "Rainbow",
		Colors = { rgb(255, 255, 255), rgb(255, 200, 80) },
		Power = { Name = "Big Bang", Type = "Burst", Damage = 90, Radius = 30, Knockback = 120, Cooldown = 14,
			Burn = { Damage = 5, Ticks = 4, Interval = 0.5 },
			Description = "The birth of the universe: 90 damage + cosmic fire." },
	},
	{
		Name = "Void Sovereign", Chance = 5000000, Tier = "Secret", Special = "Inward",
		Colors = { rgb(0, 0, 0), rgb(255, 0, 80) },
		Power = { Name = "Void Collapse", Type = "Pull", Damage = 100, Range = 70, Stun = 1.5, Cooldown = 15,
			Description = "The void swallows your opponent and freezes them." },
	},

	-- DIVINE ---------------------------------------------------------
	{
		Name = "Stellar Phoenix", Chance = 10000000, Tier = "Divine", Special = "Fire",
		Colors = { rgb(255, 150, 40), rgb(255, 240, 160) },
		Power = { Name = "Rebirth Flame", Type = "Burst", Damage = 80, Radius = 26, Knockback = 90, Cooldown = 11,
			Burn = { Damage = 8, Ticks = 5, Interval = 0.5 }, Regen = { Amount = 5, Ticks = 5, Interval = 0.6 },
			Description = "A firestorm of phoenix wings: burns them, heals you." },
	},
	{
		Name = "Chronos", Chance = 25000000, Tier = "Divine",
		Colors = { rgb(255, 225, 120), rgb(120, 200, 255) },
		Power = { Name = "Time Stop", Type = "Freeze", Damage = 70, Duration = 2.5, Range = 70, Cooldown = 13,
			Description = "Stops time around your opponent for 2.5s." },
	},
	{
		Name = "Nebula Leviathan", Chance = 50000000, Tier = "Divine", Special = "Inward",
		Colors = { rgb(60, 220, 200), rgb(140, 60, 255) },
		Power = { Name = "Abyss Maw", Type = "Pull", Damage = 120, Range = 80, Stun = 1.2, Cooldown = 14,
			Description = "A cosmic sea beast drags them in and bites." },
	},

	-- TRANSCENDENT ---------------------------------------------------
	{
		Name = "Astral Dragon", Chance = 100000000, Tier = "Transcendent", Special = "Rainbow",
		Colors = { rgb(255, 80, 160), rgb(120, 230, 255) },
		Power = { Name = "Dragon Breath", Type = "Beam", Damage = 140, Range = 110, Pierce = true, Cooldown = 12,
			Burn = { Damage = 10, Ticks = 4, Interval = 0.5 },
			Description = "A star-fire beam that ignores shields and burns." },
	},
	{
		Name = "Singularity", Chance = 250000000, Tier = "Transcendent", Special = "Inward",
		Colors = { rgb(10, 0, 20), rgb(200, 120, 255) },
		Power = { Name = "Event Collapse", Type = "Pull", Damage = 160, Range = 90, Stun = 2, Cooldown = 15,
			Description = "Everything falls in. 160 damage and a 2s stun." },
	},
	{
		Name = "Omniverse", Chance = 500000000, Tier = "Transcendent", Special = "Rainbow",
		Colors = { rgb(255, 255, 255), rgb(150, 100, 255) },
		Power = { Name = "All Worlds", Type = "Meteor", Damage = 45, Count = 6, Radius = 9, Delay = 0.5, Cooldown = 14,
			Description = "Six worlds crash down on your opponent." },
	},
	{
		Name = "Genesis", Chance = 1000000000, Tier = "Transcendent", Special = "Rainbow",
		Colors = { rgb(255, 250, 220), rgb(255, 200, 80) },
		Power = { Name = "Let There Be Light", Type = "Burst", Damage = 200, Radius = 36, Knockback = 150, Cooldown = 16,
			Regen = { Amount = 10, Ticks = 5, Interval = 0.6 },
			Description = "The first light of creation: 200 damage, then you heal." },
	},
}

---------------------------------------------------------------------
-- Lookup helpers
---------------------------------------------------------------------
AuraData.ByName = {}
for index, aura in ipairs(AuraData.List) do
	aura.Index = index
	AuraData.ByName[aura.Name] = aura
end

-- Rarest first, used by the roll algorithm.
AuraData.RarestFirst = table.clone(AuraData.List)
table.sort(AuraData.RarestFirst, function(a, b)
	return a.Chance > b.Chance
end)

function AuraData.Get(name)
	return AuraData.ByName[name]
end

-- The picture for an aura ("rbxassetid://..."), or nil if not set yet.
-- Picture IDs live in the AuraImages ModuleScript.
local imagesModule = script.Parent:WaitForChild("AuraImages", 5)
local images = imagesModule and require(imagesModule) or {}
function AuraData.GetImage(name)
	local id = images[name]
	if type(id) == "number" and id > 0 then
		return "rbxassetid://" .. id
	elseif type(id) == "string" and id ~= "" then
		if id:match("^%d+$") then
			return "rbxassetid://" .. id
		end
		return id
	end
	return nil
end

function AuraData.GetTier(name)
	local aura = AuraData.ByName[name]
	return aura and AuraData.Tiers[aura.Tier]
end

-- 1234567 -> "1,234,567"
function AuraData.FormatNumber(n)
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

function AuraData.FormatChance(chance)
	return "1 in " .. AuraData.FormatNumber(chance)
end

-- Picks a random aura. Goes from rarest to most common and gives each
-- one a (luck / chance) shot, so "1 in 1,000" really feels like it.
function AuraData.RollRandom(luck, rng)
	rng = rng or Random.new()
	luck = math.max(luck or 1, 1)
	for _, aura in ipairs(AuraData.RarestFirst) do
		if rng:NextNumber() < (luck / aura.Chance) then
			return aura
		end
	end
	return AuraData.List[1]
end

return AuraData
