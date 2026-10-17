-- CosmicConfig (ModuleScript in ReplicatedStorage)
-- All the numbers you might want to tweak live here.

local Config = {}

---------------------------------------------------------------------
-- GAME PASSES
-- Create each pass on the Creator Dashboard (Monetization > Passes),
-- then paste its ID here.
-- While an ID is 0, the pass is FREE in Roblox Studio so you can test,
-- and nobody owns it in the live game.
---------------------------------------------------------------------
Config.GamePasses = {
	AutoRoll = 0, -- unlocks the Auto Roll button
	QuickRoll = 0, -- faster rolling (see QuickRollCooldown)
	DoubleLuck = 0, -- permanent x2 luck
	VIP = 0, -- x1.25 luck and a gold VIP tag
	MultiRoll = 0, -- every roll rolls 3 auras at once
	LuckyCharm = 0, -- lucky roll every 5 rolls instead of every 10
}
Config.FreePassesInStudio = true

-- What the store shows for each pass (order = position in the store)
Config.PassInfo = {
	{ Key = "AutoRoll", Icon = "🔁", Name = "Auto Roll", Description = "Rolls for you automatically, even while you're AFK." },
	{ Key = "QuickRoll", Icon = "⚡", Name = "Quick Roll", Description = "Roll twice as fast." },
	{ Key = "DoubleLuck", Icon = "🍀", Name = "2x Luck", Description = "Permanently doubles your luck on every roll." },
	{ Key = "MultiRoll", Icon = "🎲", Name = "Triple Roll", Description = "Every roll gives you 3 auras at once." },
	{ Key = "LuckyCharm", Icon = "✨", Name = "Lucky Charm", Description = "Lucky roll every 5 rolls instead of every 10." },
	{ Key = "VIP", Icon = "👑", Name = "VIP", Description = "x1.25 luck on every roll and a gold VIP tag." },
}

---------------------------------------------------------------------
-- DEVELOPER PRODUCTS (can be bought many times)
-- Create them on the Creator Dashboard (Monetization > Developer Products).
---------------------------------------------------------------------
Config.Products = {
	PersonalLuck = 0, -- x2 luck for you
	ServerLuck = 0, -- x2 luck for everyone in the server
}
Config.ProductInfo = {
	{ Key = "PersonalLuck", Icon = "🧪", Name = "Luck Potion", Description = "x2 luck for 10 minutes. Stacks time if you buy more." },
	{ Key = "ServerLuck", Icon = "🌌", Name = "Server Luck", Description = "x2 luck for EVERYONE in the server for 15 minutes." },
}

---------------------------------------------------------------------
-- LUCK
---------------------------------------------------------------------
Config.BaseLuck = 1 -- 1 = normal odds, 2 = everything twice as likely
Config.LuckMultipliers = {
	DoubleLuck = 2,
	VIP = 1.25,
	PersonalBoost = 2,
	ServerBoost = 2,
}
Config.PersonalBoostMinutes = 10
Config.ServerBoostMinutes = 15

---------------------------------------------------------------------
-- ROLLING
---------------------------------------------------------------------
Config.RollCooldown = 1.2 -- seconds between rolls (server enforced)
Config.QuickRollCooldown = 0.6 -- with the Quick Roll pass
Config.LuckyRollEvery = 10 -- every Nth roll gets bonus luck
Config.LuckyCharmEvery = 5 -- with the Lucky Charm pass
Config.LuckyRollMultiplier = 2
Config.MultiRollCount = 3 -- with the Triple Roll pass

-- Rolls at or above these odds get special treatment
Config.AnnounceAtChance = 1000 -- whole server gets a message
Config.CutsceneAtChance = 10000 -- dramatic reveal on the roller's screen
Config.ShowcaseAtChance = 10000 -- camera spins around you to show it off
Config.SkyShiftAtChance = 1000000 -- sky changes for everyone (secret auras)

---------------------------------------------------------------------
-- SAVING + LEADERBOARD
---------------------------------------------------------------------
Config.DataStoreName = "CosmicRNG_Data_v1"
Config.LeaderboardStoreName = "CosmicRNG_TopRolls_v1"
Config.AutosaveInterval = 120
Config.LeaderboardRefresh = 90 -- seconds

---------------------------------------------------------------------
-- WORLD
---------------------------------------------------------------------
Config.RemoveDefaultBaseplate = true -- deletes the part named "Baseplate"

-- Where things are on the main island (every script uses these)
Config.Places = {
	Core = Vector3.new(0, 0, -34), -- Cosmic Core altar
	PortalPlaza = Vector3.new(34, 0, 30), -- portal to Lucky Isle
	Board = Vector3.new(-34, 0, 12), -- Top Rollers board
	Pond = Vector3.new(-30, 0, -26), -- cosmic pool
	StarstepStart = Vector3.new(-60, 0, -4), -- easy parkour
	VoidTowerStart = Vector3.new(44, 0, -46), -- hard parkour
	DuelIsland = Vector3.new(0, 0, 140), -- center of the duel island
	DuelIslandRadius = 46,
}

-- Lucky Isle: the island you reach through the portal
Config.LuckyIsland = {
	Center = Vector3.new(0, 30, 1000), -- middle of the island's ground
	Radius = 75,
	LuckMultiplier = 2, -- extra luck while you stand on it
	RequireVIP = false, -- true = only VIP pass owners may use the portal
}

---------------------------------------------------------------------
-- PARKOUR (finish a course = temporary luck boost)
---------------------------------------------------------------------
Config.Parkour = {
	Starstep = { Name = "Starstep Trail", LuckMultiplier = 1.5, BoostMinutes = 5, CooldownMinutes = 10 },
	VoidTower = { Name = "Void Tower", LuckMultiplier = 2, BoostMinutes = 5, CooldownMinutes = 10 },
}

---------------------------------------------------------------------
-- DUELS
---------------------------------------------------------------------
Config.Duel = {
	CountdownSeconds = 3,
	TimeLimit = 90, -- seconds; when time runs out the higher HP % wins
	ChallengeTimeout = 15, -- seconds to accept a challenge
	AttackCooldown = 0.55, -- basic attack
	AttackRange = 8, -- studs
	NoAuraTier = "Common", -- stats used if you have no aura equipped
	-- Bots: which aura they use and how sharp they are
	Bots = {
		{ Key = "Easy", Name = "Rookie Bot", Aura = "Moonbeam", Reaction = 1.1, Accuracy = 0.55, Speed = 13 },
		{ Key = "Normal", Name = "Cosmic Bot", Aura = "Pulsar", Reaction = 0.8, Accuracy = 0.7, Speed = 15 },
		{ Key = "Hard", Name = "Nova Bot", Aura = "Supernova", Reaction = 0.55, Accuracy = 0.85, Speed = 16 },
		{ Key = "Nightmare", Name = "Void Bot", Aura = "Black Hole", Reaction = 0.4, Accuracy = 0.95, Speed = 17 },
	},
}

---------------------------------------------------------------------
-- PARTICLE TEXTURES (built into Roblox, always available)
-- You can swap these for your own uploaded decal IDs later.
---------------------------------------------------------------------
Config.Textures = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Spark = "rbxasset://textures/particles/fire_sparks_main.dds",
}

---------------------------------------------------------------------
-- SOUNDS
-- The game makes its sounds from Roblox's built-in sound files, so they
-- always work. To use a better sound, find one in the Creator Store
-- (Toolbox > Audio), copy its ID and paste it here, e.g.
--   RevealLegendary = "rbxassetid://1234567890",
-- Leave "" to keep the built-in version.
---------------------------------------------------------------------
Config.SoundOverrides = {
	Tick = "", -- each name flicking past while rolling
	Click = "", -- pressing buttons
	Hover = "", -- mouse over buttons
	Whoosh = "", -- panels opening
	Pop = "", -- common/uncommon reveal
	RevealRare = "",
	RevealEpic = "",
	RevealLegendary = "",
	RevealMythic = "", -- mythic + secret
	Heartbeat = "", -- rare roll cutscene
	Rumble = "", -- rare roll cutscene background
	Equip = "",
	Purchase = "",
	Punch = "", -- duel basic attack
	Hit = "", -- duel damage
	Swoosh = "", -- duel dash / swing
	Zap = "", -- duel beams
	Freeze = "", -- duel freeze
}
Config.AmbientMusic = "" -- background music ID, "" = soft space hum
Config.AmbientVolume = 0.25
Config.MasterVolume = 1

return Config
