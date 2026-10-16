-- CosmicConfig (ModuleScript in ReplicatedStorage)
-- All the numbers you might want to tweak live here.

local Config = {}

---------------------------------------------------------------------
-- GAME PASSES
-- Create the pass on the Creator Dashboard, then paste its ID here.
-- While an ID is 0, the pass is FREE in Roblox Studio so you can test,
-- and nobody owns it in the live game.
---------------------------------------------------------------------
Config.GamePasses = {
	AutoRoll = 0, -- unlocks the Auto Roll button
	QuickRoll = 0, -- faster rolling (see QuickRollCooldown)
	DoubleLuck = 0, -- permanent x2 luck
}
Config.FreePassesInStudio = true

---------------------------------------------------------------------
-- ROLLING
---------------------------------------------------------------------
Config.RollCooldown = 1.2 -- seconds between rolls (server enforced)
Config.QuickRollCooldown = 0.6 -- with the Quick Roll pass
Config.BaseLuck = 1 -- 1 = normal odds, 2 = everything twice as likely
Config.LuckyRollEvery = 10 -- every Nth roll gets bonus luck
Config.LuckyRollMultiplier = 2

-- Rolls at or above these odds get special treatment
Config.AnnounceAtChance = 1000 -- whole server gets a message
Config.CutsceneAtChance = 10000 -- dramatic reveal on the roller's screen
Config.SkyShiftAtChance = 1000000 -- sky changes for everyone (secret auras)

---------------------------------------------------------------------
-- SAVING
---------------------------------------------------------------------
Config.DataStoreName = "CosmicRNG_Data_v1"
Config.AutosaveInterval = 120

---------------------------------------------------------------------
-- WORLD
---------------------------------------------------------------------
Config.RemoveDefaultBaseplate = true -- deletes the part named "Baseplate"

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
-- SOUNDS (optional). Put "rbxassetid://123456" to enable, "" = silent.
---------------------------------------------------------------------
Config.Sounds = {
	RollTick = "",
	RevealCommon = "",
	RevealRare = "",
	RevealLegendary = "",
}

return Config
