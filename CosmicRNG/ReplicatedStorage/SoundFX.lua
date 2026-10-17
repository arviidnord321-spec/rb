-- SoundFX (ModuleScript in ReplicatedStorage) - used by LocalScripts only
-- Every sound in the game. They are built from Roblox's built-in sound
-- files (always available) and shaped with pitch, echo, reverb and bass.
-- Swap any of them for a Creator Store sound in CosmicConfig.SoundOverrides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))

local SoundFX = {}

local BUILT_IN = {
	Tick = "rbxasset://sounds/volume_slider.ogg",
	Boom = "rbxasset://sounds/impact_explosion_03.mp3",
	Wind = "rbxasset://sounds/action_falling.ogg",
	Thud = "rbxasset://sounds/action_jump_land.mp3",
}

-- Effect recipes
local EFFECTS = {
	Reverb = { Class = "ReverbSoundEffect", Props = { DecayTime = 1.8, Density = 1, Diffusion = 1, DryLevel = 0, WetLevel = -4 } },
	Echo = { Class = "EchoSoundEffect", Props = { Delay = 0.22, Feedback = 0.35, DryLevel = 0, WetLevel = -6 } },
	Bass = { Class = "EqualizerSoundEffect", Props = { LowGain = 8, MidGain = 0, HighGain = -4 } },
	Muffle = { Class = "EqualizerSoundEffect", Props = { LowGain = 6, MidGain = -16, HighGain = -45 } },
	Bright = { Class = "EqualizerSoundEffect", Props = { LowGain = -10, MidGain = 0, HighGain = 4 } },
}

-- Sound recipes: which file, pitch (Speed), volume and effects
local PRESETS = {
	Tick = { Id = BUILT_IN.Tick, Speed = 1, Volume = 0.55 },
	Click = { Id = BUILT_IN.Tick, Speed = 1.35, Volume = 0.5 },
	Hover = { Id = BUILT_IN.Tick, Speed = 1.9, Volume = 0.15 },
	Whoosh = { Id = BUILT_IN.Wind, Speed = 1.8, Volume = 0.35, Duration = 0.45, Effects = { "Bright" } },
	Pop = { Id = BUILT_IN.Boom, Speed = 2.4, Volume = 0.2, Effects = { "Bright" } },
	RevealRare = { Id = BUILT_IN.Boom, Speed = 1.6, Volume = 0.32, Effects = { "Reverb" } },
	RevealEpic = { Id = BUILT_IN.Boom, Speed = 1.2, Volume = 0.42, Effects = { "Reverb" } },
	RevealLegendary = { Id = BUILT_IN.Boom, Speed = 0.85, Volume = 0.55, Effects = { "Reverb", "Echo" } },
	RevealMythic = { Id = BUILT_IN.Boom, Speed = 0.62, Volume = 0.7, Effects = { "Reverb", "Echo", "Bass" } },
	Heartbeat = { Id = BUILT_IN.Boom, Speed = 0.33, Volume = 0.9, Effects = { "Muffle" } },
	Rumble = { Id = BUILT_IN.Wind, Speed = 0.45, Volume = 0.6, Looped = true, Effects = { "Muffle" } },
	Equip = { Id = BUILT_IN.Boom, Speed = 2, Volume = 0.18, Effects = { "Bright" } },
	Purchase = { Id = BUILT_IN.Tick, Speed = 1.5, Volume = 0.5, Effects = { "Reverb" } },
	Thud = { Id = BUILT_IN.Thud, Speed = 0.8, Volume = 0.5 },
}

-- All game sounds go through one group so we can mute them together
local group = SoundService:FindFirstChild("CosmicSFX")
if not group then
	group = Instance.new("SoundGroup")
	group.Name = "CosmicSFX"
	group.Volume = Config.MasterVolume
	group.Parent = SoundService
end
local musicGroup = SoundService:FindFirstChild("CosmicMusic")
if not musicGroup then
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "CosmicMusic"
	musicGroup.Volume = 1
	musicGroup.Parent = SoundService
end

local muted = false

local function build(name, opts)
	local preset = PRESETS[name]
	if not preset then
		warn("[SoundFX] unknown sound", name)
		return nil
	end
	opts = opts or {}

	local override = Config.SoundOverrides[name]
	local useOverride = override ~= nil and override ~= ""

	local sound = Instance.new("Sound")
	sound.Name = "SFX_" .. name
	sound.SoundId = useOverride and override or preset.Id
	sound.Volume = (useOverride and 0.5 or preset.Volume) * (opts.Volume or 1)
	sound.PlaybackSpeed = (useOverride and 1 or preset.Speed) * (opts.Speed or 1)
	sound.Looped = preset.Looped == true
	sound.SoundGroup = group

	if not useOverride and preset.Effects then
		for priority, effectName in ipairs(preset.Effects) do
			local recipe = EFFECTS[effectName]
			local effect = Instance.new(recipe.Class)
			for key, value in pairs(recipe.Props) do
				effect[key] = value
			end
			effect.Priority = priority
			effect.Parent = sound
		end
	end

	if opts.Parent then
		-- 3D sound that comes from a place in the world
		sound.RollOffMinDistance = 10
		sound.RollOffMaxDistance = opts.MaxDistance or 150
		sound.Parent = opts.Parent
	else
		sound.Parent = SoundService
	end
	return sound, preset
end

-- Play a one-shot sound. opts: { Speed = 1.2, Volume = 0.5, Parent = part }
function SoundFX.Play(name, opts)
	local sound, preset = build(name, opts)
	if not sound then
		return nil
	end
	sound:Play()
	if preset.Duration then
		task.delay(preset.Duration, function()
			if sound.Parent then
				TweenService:Create(sound, TweenInfo.new(0.15), { Volume = 0 }):Play()
			end
		end)
		Debris:AddItem(sound, preset.Duration + 0.3)
	elseif not sound.Looped then
		Debris:AddItem(sound, 8)
	end
	return sound
end

-- Start a looping sound (fades in). Stop it with SoundFX.FadeOut.
function SoundFX.Loop(name, fadeIn, opts)
	local sound = build(name, opts)
	if not sound then
		return nil
	end
	local target = sound.Volume
	sound.Looped = true
	sound.Volume = 0
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(fadeIn or 0.5), { Volume = target }):Play()
	return sound
end

function SoundFX.FadeOut(sound, duration)
	if not sound then
		return
	end
	duration = duration or 0.5
	TweenService:Create(sound, TweenInfo.new(duration), { Volume = 0 }):Play()
	Debris:AddItem(sound, duration + 0.1)
end

-- Quick rising "ding ding ding" made from ticks (new best, purchases)
function SoundFX.Chime(baseSpeed, notes)
	baseSpeed = baseSpeed or 1
	notes = notes or 4
	local steps = { 1, 1.26, 1.5, 2, 2.52 } -- a major chord going up
	task.spawn(function()
		for i = 1, math.min(notes, #steps) do
			SoundFX.Play("Purchase", { Speed = baseSpeed * steps[i] / 1.5, Volume = 0.8 })
			task.wait(0.07)
		end
	end)
end

function SoundFX.SetMuted(value)
	muted = value
	group.Volume = muted and 0 or Config.MasterVolume
	musicGroup.Volume = muted and 0 or 1
end

function SoundFX.IsMuted()
	return muted
end

-- Background ambience: your music if set, otherwise a soft space hum
local ambient
function SoundFX.StartAmbient()
	if ambient then
		return
	end
	ambient = Instance.new("Sound")
	ambient.Name = "CosmicAmbient"
	ambient.Looped = true
	ambient.SoundGroup = musicGroup
	if Config.AmbientMusic ~= "" then
		ambient.SoundId = Config.AmbientMusic
		ambient.Volume = Config.AmbientVolume
	else
		ambient.SoundId = BUILT_IN.Wind
		ambient.PlaybackSpeed = 0.22
		ambient.Volume = Config.AmbientVolume * 0.35
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = 4
		eq.MidGain = -12
		eq.HighGain = -40
		eq.Parent = ambient
	end
	ambient.Parent = SoundService
	ambient:Play()
end

return SoundFX
