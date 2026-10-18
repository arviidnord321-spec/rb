-- PetData (ModuleScript in ReplicatedStorage)
-- Every pet and every egg. There are no coins: you pay for eggs with AURAS
-- from your inventory. Each island has 3 eggs; the further you get
-- (rebirth islands), the pricier the eggs and the better the pets.
-- Pets give luck: every equipped pet adds its Luck (0.25 = +25%).

local PetData = {}

PetData.MaxEquipped = 3

PetData.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(200, 205, 220) },
	Uncommon = { Order = 2, Color = Color3.fromRGB(110, 230, 140) },
	Rare = { Order = 3, Color = Color3.fromRGB(90, 170, 255) },
	Epic = { Order = 4, Color = Color3.fromRGB(190, 110, 255) },
	Legendary = { Order = 5, Color = Color3.fromRGB(255, 200, 70) },
	Mythic = { Order = 6, Color = Color3.fromRGB(255, 80, 140) },
	Exclusive = { Order = 7, Color = Color3.fromRGB(255, 255, 255) },
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Shape = how the pet is built (see PetClient): Blob, Cat, Bunny, Bird,
-- Fish, Jelly, Dragon, Star, Wisp
PetData.List = {
	-- COSMIC ISLAND ---------------------------------------------------
	{ Name = "Pebble Blob", Rarity = "Common", Luck = 0.03, Shape = "Blob", Colors = { rgb(150, 140, 190), rgb(220, 210, 255) } },
	{ Name = "Star Kitten", Rarity = "Common", Luck = 0.05, Shape = "Cat", Colors = { rgb(240, 230, 255), rgb(170, 180, 255) } },
	{ Name = "Moon Bunny", Rarity = "Uncommon", Luck = 0.08, Shape = "Bunny", Colors = { rgb(210, 230, 255), rgb(140, 170, 230) } },
	{ Name = "Comet Pup", Rarity = "Rare", Luck = 0.14, Shape = "Cat", Colors = { rgb(120, 200, 255), rgb(255, 255, 255) } },
	{ Name = "Nebula Jelly", Rarity = "Rare", Luck = 0.18, Shape = "Jelly", Colors = { rgb(190, 110, 255), rgb(255, 140, 220) } },
	{ Name = "Aurora Bird", Rarity = "Epic", Luck = 0.28, Shape = "Bird", Colors = { rgb(100, 255, 190), rgb(120, 170, 255) } },
	{ Name = "Galaxy Cat", Rarity = "Epic", Luck = 0.38, Shape = "Cat", Colors = { rgb(60, 40, 140), rgb(255, 120, 230) } },
	{ Name = "Solar Dragon", Rarity = "Legendary", Luck = 0.65, Shape = "Dragon", Colors = { rgb(255, 150, 40), rgb(255, 230, 120) } },
	{ Name = "Void Wisp", Rarity = "Mythic", Luck = 1.0, Shape = "Wisp", Colors = { rgb(20, 10, 40), rgb(255, 40, 120) } },

	-- FROSTFALL -----------------------------------------------------
	{ Name = "Snow Blob", Rarity = "Uncommon", Luck = 0.12, Shape = "Blob", Colors = { rgb(240, 248, 255), rgb(170, 220, 255) } },
	{ Name = "Frost Bunny", Rarity = "Rare", Luck = 0.2, Shape = "Bunny", Colors = { rgb(200, 235, 255), rgb(90, 180, 255) } },
	{ Name = "Ice Penguin", Rarity = "Rare", Luck = 0.26, Shape = "Bird", Colors = { rgb(30, 40, 70), rgb(240, 250, 255) } },
	{ Name = "Glacier Fox", Rarity = "Epic", Luck = 0.42, Shape = "Cat", Colors = { rgb(170, 225, 255), rgb(255, 255, 255) } },
	{ Name = "Aurora Owl", Rarity = "Epic", Luck = 0.55, Shape = "Bird", Colors = { rgb(90, 255, 180), rgb(190, 160, 255) } },
	{ Name = "Frost Dragon", Rarity = "Legendary", Luck = 0.9, Shape = "Dragon", Colors = { rgb(120, 200, 255), rgb(230, 250, 255) } },
	{ Name = "Polar Spirit", Rarity = "Mythic", Luck = 1.5, Shape = "Wisp", Colors = { rgb(200, 245, 255), rgb(120, 255, 210) } },

	-- EMBER ISLE ----------------------------------------------------
	{ Name = "Ember Blob", Rarity = "Rare", Luck = 0.3, Shape = "Blob", Colors = { rgb(255, 120, 50), rgb(255, 210, 90) } },
	{ Name = "Magma Fish", Rarity = "Epic", Luck = 0.5, Shape = "Fish", Colors = { rgb(255, 80, 30), rgb(255, 190, 60) } },
	{ Name = "Cinder Cat", Rarity = "Epic", Luck = 0.65, Shape = "Cat", Colors = { rgb(60, 30, 30), rgb(255, 120, 40) } },
	{ Name = "Phoenix Chick", Rarity = "Legendary", Luck = 1.0, Shape = "Bird", Colors = { rgb(255, 160, 40), rgb(255, 60, 40) } },
	{ Name = "Lava Dragon", Rarity = "Legendary", Luck = 1.4, Shape = "Dragon", Colors = { rgb(200, 40, 20), rgb(255, 170, 40) } },
	{ Name = "Inferno Spirit", Rarity = "Mythic", Luck = 2.5, Shape = "Wisp", Colors = { rgb(255, 90, 20), rgb(255, 240, 150) } },

	-- NEON NEXUS ----------------------------------------------------
	{ Name = "Pixel Blob", Rarity = "Epic", Luck = 0.7, Shape = "Blob", Colors = { rgb(60, 230, 255), rgb(255, 70, 220) } },
	{ Name = "Synth Fish", Rarity = "Epic", Luck = 0.9, Shape = "Fish", Colors = { rgb(255, 70, 220), rgb(60, 230, 255) } },
	{ Name = "Neon Jelly", Rarity = "Legendary", Luck = 1.3, Shape = "Jelly", Colors = { rgb(255, 90, 230), rgb(120, 255, 255) } },
	{ Name = "Cyber Dragon", Rarity = "Legendary", Luck = 2.0, Shape = "Dragon", Colors = { rgb(30, 20, 60), rgb(60, 230, 255) } },
	{ Name = "Hologram Star", Rarity = "Mythic", Luck = 3.0, Shape = "Star", Colors = { rgb(140, 255, 255), rgb(255, 120, 240) } },
	{ Name = "Nexus Overmind", Rarity = "Mythic", Luck = 4.0, Shape = "Wisp", Colors = { rgb(255, 255, 255), rgb(200, 80, 255) } },

	-- EXCLUSIVE (Limited Offer) ---------------------------------------
	{ Name = "Cosmic Overlord", Rarity = "Exclusive", Luck = 3.0, Shape = "Dragon", Colors = { rgb(255, 230, 120), rgb(150, 80, 255) } },
}

-- Eggs: Cost = { Aura = name, Count = how many of that aura it takes }
-- Pets = { { Name, Weight } } (weights don't have to add up to 100)
PetData.Eggs = {
	-- COSMIC ISLAND (everyone)
	{ Key = "StardustEgg", Name = "Stardust Egg", Island = "Main", Slot = 1, Color = rgb(220, 215, 255),
		Cost = { Aura = "Stardust", Count = 4 },
		Pets = { { "Pebble Blob", 50 }, { "Star Kitten", 32 }, { "Moon Bunny", 15 }, { "Comet Pup", 3 } } },
	{ Key = "CometEgg", Name = "Comet Egg", Island = "Main", Slot = 2, Color = rgb(120, 200, 255),
		Cost = { Aura = "Comet", Count = 2 },
		Pets = { { "Comet Pup", 45 }, { "Nebula Jelly", 35 }, { "Aurora Bird", 17 }, { "Galaxy Cat", 3 } } },
	{ Key = "NebulaEgg", Name = "Nebula Egg", Island = "Main", Slot = 3, Color = rgb(190, 110, 255),
		Cost = { Aura = "Nebula", Count = 1 },
		Pets = { { "Aurora Bird", 45 }, { "Galaxy Cat", 35 }, { "Solar Dragon", 17 }, { "Void Wisp", 3 } } },

	-- FROSTFALL (rebirth 1)
	{ Key = "SnowEgg", Name = "Snow Egg", Island = "Frostfall", Slot = 1, Color = rgb(235, 245, 255),
		Cost = { Aura = "Aurora", Count = 3 },
		Pets = { { "Snow Blob", 50 }, { "Frost Bunny", 32 }, { "Ice Penguin", 15 }, { "Glacier Fox", 3 } } },
	{ Key = "GlacierEgg", Name = "Glacier Egg", Island = "Frostfall", Slot = 2, Color = rgb(140, 210, 255),
		Cost = { Aura = "Pulsar", Count = 2 },
		Pets = { { "Ice Penguin", 45 }, { "Glacier Fox", 35 }, { "Aurora Owl", 17 }, { "Frost Dragon", 3 } } },
	{ Key = "AuroraEgg", Name = "Aurora Egg", Island = "Frostfall", Slot = 3, Color = rgb(120, 255, 200),
		Cost = { Aura = "Solar Flare", Count = 1 },
		Pets = { { "Glacier Fox", 45 }, { "Aurora Owl", 35 }, { "Frost Dragon", 17 }, { "Polar Spirit", 3 } } },

	-- EMBER ISLE (rebirth 2)
	{ Key = "CinderEgg", Name = "Cinder Egg", Island = "Ember", Slot = 1, Color = rgb(120, 80, 70),
		Cost = { Aura = "Frostmoon", Count = 2 },
		Pets = { { "Ember Blob", 50 }, { "Magma Fish", 32 }, { "Cinder Cat", 15 }, { "Phoenix Chick", 3 } } },
	{ Key = "MagmaEgg", Name = "Magma Egg", Island = "Ember", Slot = 2, Color = rgb(255, 110, 40),
		Cost = { Aura = "Starfall", Count = 1 },
		Pets = { { "Magma Fish", 45 }, { "Cinder Cat", 35 }, { "Phoenix Chick", 17 }, { "Lava Dragon", 3 } } },
	{ Key = "PhoenixEgg", Name = "Phoenix Egg", Island = "Ember", Slot = 3, Color = rgb(255, 200, 60),
		Cost = { Aura = "Supernova", Count = 1 },
		Pets = { { "Cinder Cat", 45 }, { "Phoenix Chick", 35 }, { "Lava Dragon", 17 }, { "Inferno Spirit", 3 } } },

	-- NEON NEXUS (rebirth 3)
	{ Key = "PixelEgg", Name = "Pixel Egg", Island = "Nexus", Slot = 1, Color = rgb(60, 230, 255),
		Cost = { Aura = "Quasar", Count = 1 },
		Pets = { { "Pixel Blob", 50 }, { "Synth Fish", 32 }, { "Neon Jelly", 15 }, { "Cyber Dragon", 3 } } },
	{ Key = "SynthEgg", Name = "Synth Egg", Island = "Nexus", Slot = 2, Color = rgb(255, 70, 220),
		Cost = { Aura = "Celestial", Count = 1 },
		Pets = { { "Synth Fish", 45 }, { "Neon Jelly", 35 }, { "Cyber Dragon", 17 }, { "Hologram Star", 3 } } },
	{ Key = "OvermindEgg", Name = "Overmind Egg", Island = "Nexus", Slot = 3, Color = rgb(200, 120, 255),
		Cost = { Aura = "Black Hole", Count = 1 },
		Pets = { { "Neon Jelly", 45 }, { "Cyber Dragon", 35 }, { "Hologram Star", 17 }, { "Nexus Overmind", 3 } } },
}

PetData.ByName = {}
for index, pet in ipairs(PetData.List) do
	pet.Index = index
	PetData.ByName[pet.Name] = pet
end
PetData.EggByKey = {}
for _, egg in ipairs(PetData.Eggs) do
	PetData.EggByKey[egg.Key] = egg
	local total = 0
	for _, entry in ipairs(egg.Pets) do
		total += entry[2]
	end
	egg.TotalWeight = total
end

---------------------------------------------------------------------
-- MERGING: 3 of the same pet -> 1 GOLDEN pet, 3 golden -> 1 RAINBOW pet.
-- Merged pets are saved as "Golden:Star Kitten" / "Rainbow:Star Kitten".
---------------------------------------------------------------------
PetData.MergeCount = 3
PetData.Variants = {
	Golden = { Order = 2, Icon = "✨", Multiplier = 1.25, Next = "Rainbow" }, -- 24% luck -> 30%
	Rainbow = { Order = 3, Icon = "🌈", Multiplier = 1.6 }, -- 24% luck -> 38%
}
local GOLD_COLORS = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 245, 170) }

local variantCache = {}

-- "Golden:Star Kitten" -> "Golden", "Star Kitten"   ("Star Kitten" -> nil, "Star Kitten")
function PetData.SplitKey(key)
	local variant, base = string.match(key, "^(%a+):(.+)$")
	if variant and PetData.Variants[variant] then
		return variant, base
	end
	return nil, key
end

-- Works for normal pets AND merged pets. For a merged pet you get a copy
-- with the boosted Luck, Name = the saved key, DisplayName = "Golden Star Kitten".
function PetData.Get(key)
	if type(key) ~= "string" then
		return nil
	end
	local plain = PetData.ByName[key]
	if plain then
		return plain
	end
	if variantCache[key] then
		return variantCache[key]
	end
	local variant, baseName = PetData.SplitKey(key)
	local base = variant and PetData.ByName[baseName]
	if not base then
		return nil
	end
	local info = PetData.Variants[variant]
	local pet = table.clone(base)
	pet.Name = key
	pet.BaseName = base.Name
	pet.DisplayName = variant .. " " .. base.Name
	pet.Variant = variant
	pet.Luck = math.floor(base.Luck * info.Multiplier * 1000 + 0.5) / 1000
	if variant == "Golden" then
		pet.Colors = GOLD_COLORS
	end
	variantCache[key] = pet
	return pet
end

-- the name to show on screen
function PetData.Display(key)
	local pet = PetData.Get(key)
	return pet and (pet.DisplayName or pet.Name) or tostring(key)
end

-- what 3 of this pet merge into (nil if it can't merge any further)
function PetData.MergeResult(key)
	local variant, baseName = PetData.SplitKey(key)
	if not PetData.ByName[baseName] then
		return nil
	end
	if not variant then
		return "Golden:" .. baseName
	end
	local nextVariant = PetData.Variants[variant].Next
	return nextVariant and (nextVariant .. ":" .. baseName) or nil
end

function PetData.RarityOf(name)
	local pet = PetData.Get(name)
	return pet and PetData.Rarities[pet.Rarity]
end

-- Picks a pet from an egg
function PetData.Hatch(egg, rng)
	rng = rng or Random.new()
	local pick = rng:NextNumber() * egg.TotalWeight
	for _, entry in ipairs(egg.Pets) do
		pick -= entry[2]
		if pick <= 0 then
			return entry[1]
		end
	end
	return egg.Pets[1][1]
end

-- Chance text for an egg entry, e.g. "17%"
function PetData.ChanceText(egg, weight)
	local percent = weight / egg.TotalWeight * 100
	if percent < 1 then
		return ("%.1f%%"):format(percent)
	end
	return ("%d%%"):format(math.floor(percent + 0.5))
end

-- Luck from a list of equipped pet names: 1 + sum of their Luck
function PetData.LuckFrom(names)
	local total = 1
	for _, name in ipairs(names or {}) do
		local pet = PetData.Get(name)
		if pet then
			total += pet.Luck
		end
	end
	return total
end

-- "A,B,C" <-> { "A", "B", "C" } (pets are shared with everyone as a player attribute)
function PetData.Split(text)
	local list = {}
	if type(text) == "string" then
		for name in text:gmatch("[^,]+") do
			table.insert(list, name)
		end
	end
	return list
end

return PetData
