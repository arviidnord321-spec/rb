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
	-- LIMITED OFFER packs (set the price to 399 Robux or more on the dashboard)
	LimitedAura = 0,
	LimitedLuck = 0,
	LimitedPet = 0,
}
Config.ProductInfo = {
	{ Key = "PersonalLuck", Icon = "🧪", Name = "Luck Potion", Description = "x2 luck for 10 minutes. Stacks time if you buy more." },
	{ Key = "ServerLuck", Icon = "🌌", Name = "Server Luck", Description = "x2 luck for EVERYONE in the server for 15 minutes." },
}

---------------------------------------------------------------------
-- LIMITED OFFER: on sale for the first 7 days after the game goes live.
-- The 7 days start automatically the first time a live server starts
-- (saved in a DataStore). Each player can buy ONE pack.
-- To pick the start yourself, set StartTime to a Unix time (e.g. from
-- https://www.unixtimestamp.com), or leave it 0 for automatic.
---------------------------------------------------------------------
Config.LimitedOffer = {
	Days = 7,
	StartTime = 0,
	PriceText = "399", -- shown on the button (the real price is set on the dashboard)
	Packs = {
		{
			Key = "LimitedAura", Icon = "🌌", Name = "Legend Aura Pack", Color = Color3.fromRGB(255, 80, 140),
			Gives = { "Cosmic Rift aura (1 in 500,000)", "Black Hole aura (1 in 100,000)", "x2 luck potion for 2 hours" },
		},
		{
			Key = "LimitedLuck", Icon = "🍀", Name = "Infinite Luck Pack", Color = Color3.fromRGB(120, 255, 170),
			Gives = { "x2 luck FOREVER", "5 Cosmic Rolls (x50 luck each)", "x2 luck potion for 1 hour" },
		},
		{
			Key = "LimitedPet", Icon = "🐉", Name = "Overlord Pet Pack", Color = Color3.fromRGB(255, 200, 70),
			Gives = { "Cosmic Overlord pet (+300% luck, only here)", "Void Wisp pet (+100% luck)", "3 Cosmic Rolls (x50 luck each)" },
		},
	},
}

---------------------------------------------------------------------
-- COSMIC DROP: every few minutes a Cosmic Roll appears somewhere on the
-- main island or Lucky Isle. The first player to grab it gets a huge luck
-- boost on their next roll (one use).
---------------------------------------------------------------------
Config.Drop = {
	IntervalMinutes = 15,
	BoostMultiplier = 50,
	LuckyIsleChance = 0.3, -- chance it lands on Lucky Isle instead of the main island
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
Config.MainIslandRadius = 115
Config.Places = {
	Core = Vector3.new(0, 0, -52), -- Cosmic Core altar
	PortalPlaza = Vector3.new(54, 0, 46), -- portal to Lucky Isle
	Board = Vector3.new(-52, 0, 18), -- Top Rollers board
	Pond = Vector3.new(-46, 0, -42), -- cosmic pool
	StarstepStart = Vector3.new(-104, 0, -6), -- medium parkour
	VoidTowerStart = Vector3.new(72, 0, -80), -- hard parkour
	DuelIsland = Vector3.new(0, 0, 215), -- center of the duel island
	DuelIslandRadius = 46,
	RebirthGate = Vector3.new(-62, 0, 54), -- 3 portals to the rebirth islands
	Hatchery = Vector3.new(62, 0, -18), -- the pet eggs of the main island
}

-- Lucky Isle: the island you reach through the portal
Config.LuckyIsland = {
	Center = Vector3.new(0, 30, 1000), -- middle of the island's ground
	Radius = 75,
	LuckMultiplier = 2, -- extra luck while you stand on it
	RequireVIP = false, -- true = only VIP pass owners may use the portal
}

---------------------------------------------------------------------
-- REBIRTH
-- Rebirthing needs rolls (since your last rebirth) AND one rare aura rolled
-- since your last rebirth. Both get harder every time. You KEEP your auras.
-- Every rebirth: more luck forever, faster rolling and a new star.
---------------------------------------------------------------------
Config.Rebirth = {
	BaseRolls = 150, -- rolls needed for the 1st rebirth
	RollGrowth = 2.2, -- each rebirth needs 2.2x more rolls (150, 330, 726, ...)
	BaseRarity = 100, -- 1st rebirth: roll an aura of 1 in 100 or rarer
	RarityGrowth = 4, -- then 1 in 400, 1 in 1,600, ...
	MaxRarity = 1000000,
	LuckPerRebirth = 0.25, -- +25% luck per rebirth (x1.25, x1.5, x1.75 ...)
	RollSpeedPerRebirth = 0.06, -- 6% shorter roll cooldown per rebirth
	MaxRollSpeed = 0.42, -- never more than 42% faster
	-- Unlocks (Rebirths = how many you need)
	Perks = {
		{ Rebirths = 1, Icon = "❄️", Name = "Frostfall Isle", Description = "A frozen island with x2.5 luck and the Glacier Climb." },
		{ Rebirths = 2, Icon = "🔥", Name = "Ember Isle", Description = "A volcano island with x3 luck and the Magma Run." },
		{ Rebirths = 2, Icon = "🦘", Name = "Double Jump", Description = "Press jump again in the air (not on parkour courses)." },
		{ Rebirths = 3, Icon = "💠", Name = "Neon Nexus", Description = "A neon city island with x4 luck and the Pulse Grid." },
		{ Rebirths = 3, Icon = "🌠", Name = "Rebirth Trail", Description = "A glowing trail follows you everywhere." },
		{ Rebirths = 4, Icon = "🎯", Name = "Lucky Streak", Description = "Lucky roll every 8 rolls instead of 10." },
		{ Rebirths = 5, Icon = "🔁", Name = "Free Auto Roll", Description = "Auto Roll unlocked for free, forever." },
	},
	LuckyEveryAt4 = 8,
}

-- The rebirth islands (reached through the Rebirth Gate on the main island)
Config.RebirthIslands = {
	{
		Key = "Frostfall", Name = "Frostfall Isle", Icon = "❄️", Rebirths = 1,
		Center = Vector3.new(-1000, 30, 0), Radius = 100, LuckMultiplier = 2.5,
		Hatchery = Vector3.new(50, 0, 36), -- where the eggs stand (from the island center)
		Color = Color3.fromRGB(140, 220, 255),
	},
	{
		Key = "Ember", Name = "Ember Isle", Icon = "🔥", Rebirths = 2,
		Center = Vector3.new(1000, 30, 0), Radius = 100, LuckMultiplier = 3,
		Hatchery = Vector3.new(46, 0, -34),
		Color = Color3.fromRGB(255, 120, 40),
	},
	{
		Key = "Nexus", Name = "Neon Nexus", Icon = "💠", Rebirths = 3,
		Center = Vector3.new(0, 30, -1000), Radius = 100, LuckMultiplier = 4,
		Hatchery = Vector3.new(56, 0, -40),
		Color = Color3.fromRGB(255, 70, 220),
	},
}

---------------------------------------------------------------------
-- MOVEMENT (hold Shift to sprint)
---------------------------------------------------------------------
Config.Movement = {
	WalkSpeed = 16,
	SprintSpeed = 26,
	DuelSprintMultiplier = 1.4, -- in duels sprint is a bit weaker
	MaxStamina = 100,
	StaminaDrain = 20, -- per second while sprinting
	StaminaRegen = 16, -- per second while not sprinting
	RegenDelay = 0.8, -- seconds before stamina starts coming back
}

---------------------------------------------------------------------
-- PARKOUR (finish a course = temporary luck boost)
---------------------------------------------------------------------
Config.Parkour = {
	Starstep = { Name = "Starstep Trail", LuckMultiplier = 1.75, BoostMinutes = 5, CooldownMinutes = 10 },
	VoidTower = { Name = "Void Tower", LuckMultiplier = 2.5, BoostMinutes = 6, CooldownMinutes = 10 },
	-- rebirth island courses (harder, bigger rewards)
	GlacierClimb = { Name = "Glacier Climb", LuckMultiplier = 3, BoostMinutes = 6, CooldownMinutes = 12 },
	MagmaRun = { Name = "Magma Run", LuckMultiplier = 4, BoostMinutes = 7, CooldownMinutes = 12 },
	PulseGrid = { Name = "Pulse Grid", LuckMultiplier = 5, BoostMinutes = 8, CooldownMinutes = 12 },
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
	FinisherSeconds = 4.6, -- length of the knockout cutscene
	-- combos: attack again within ComboWindow to chain jab, jab, KICK
	ComboWindow = 0.9,
	ComboDamage = { 1, 1.1, 1.8 }, -- damage multiplier for hit 1, 2, 3
	HeavyRecovery = 0.75, -- pause after the kick
	HeavyKnockback = 45,
	-- blocking (hold G): uses up a guard meter
	BlockBasic = 0.2, -- basic hits do 20% damage into a block
	BlockPower = 0.5, -- powers do 50%
	BlockSpeed = 0.45, -- you move slower while blocking
	GuardMax = 100,
	GuardDrain = 22, -- per second while blocking
	GuardHitCost = 18, -- extra per blocked hit
	GuardRegen = 25, -- per second when not blocking
	GuardBreakStun = 1, -- seconds stunned when your guard breaks
	-- dodge roll (E)
	DodgeCooldown = 2.2,
	DodgeInvincible = 0.35, -- seconds you can't be hit
	DodgeSpeed = 58,
	PowerWindup = 0.2, -- powers fire this long after you press (matches the animation)
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
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds", -- soft round glow (fireflies, motes)
	Vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds", -- swirl
	Shockwave = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
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
