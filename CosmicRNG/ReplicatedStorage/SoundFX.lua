-- SoundFX (ModuleScript in ReplicatedStorage) - used by LocalScripts only
-- A small sound designer. Roblox only ships a handful of sound files with
-- every client, so each game sound is a RECIPE that stacks 1-4 layers of
-- those files, cuts out just the useful part, re-pitches them and runs them
-- through effects (distortion, compression, reverb, flange...). Every play
-- gets a tiny random pitch change so hits never sound copy-pasted.
--
-- Want a real sound instead? Put a Creator Store ID in
-- CosmicConfig.SoundOverrides for that name and it replaces the recipe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))

local SoundFX = {}
local rand = Random.new()

-- The sound files every Roblox player has
local FILES = {
	Tick = "rbxasset://sounds/volume_slider.ogg", -- short click
	Boom = "rbxasset://sounds/impact_explosion_03.mp3", -- explosion
	Wind = "rbxasset://sounds/action_falling.ogg", -- rushing air
	Thud = "rbxasset://sounds/action_jump_land.mp3", -- body landing
	Jump = "rbxasset://sounds/action_jump.mp3", -- quick "hup" swoosh
	Water = "rbxasset://sounds/impact_water.mp3", -- splash (great for ice/shimmer)
	Steps = "rbxasset://sounds/action_footsteps_plastic.mp3", -- footsteps
	Ouch = "rbxasset://sounds/ouch.ogg", -- hurt voice
	Oof = "rbxasset://sounds/oof.ogg", -- hurt voice 2
}

-- Effect settings
local EFFECTS = {
	Reverb = { Class = "ReverbSoundEffect", Props = { DecayTime = 1.6, Density = 1, Diffusion = 1, DryLevel = 0, WetLevel = -5 } },
	BigReverb = { Class = "ReverbSoundEffect", Props = { DecayTime = 4, Density = 1, Diffusion = 1, DryLevel = -2, WetLevel = 0 } },
	Echo = { Class = "EchoSoundEffect", Props = { Delay = 0.22, Feedback = 0.35, DryLevel = 0, WetLevel = -6 } },
	ShortEcho = { Class = "EchoSoundEffect", Props = { Delay = 0.06, Feedback = 0.3, DryLevel = 0, WetLevel = -4 } },
	Bass = { Class = "EqualizerSoundEffect", Props = { LowGain = 9, MidGain = 0, HighGain = -4 } },
	Muffle = { Class = "EqualizerSoundEffect", Props = { LowGain = 6, MidGain = -16, HighGain = -45 } },
	Bright = { Class = "EqualizerSoundEffect", Props = { LowGain = -10, MidGain = 0, HighGain = 5 } },
	Thin = { Class = "EqualizerSoundEffect", Props = { LowGain = -30, MidGain = -2, HighGain = 4 } },
	Distort = { Class = "DistortionSoundEffect", Props = { Level = 0.55 } },
	Crunch = { Class = "DistortionSoundEffect", Props = { Level = 0.3 } },
	Compress = { Class = "CompressorSoundEffect", Props = { Attack = 0.005, Release = 0.15, Ratio = 6, Threshold = -18, GainMakeup = 6 } },
	Flange = { Class = "FlangeSoundEffect", Props = { Depth = 0.6, Mix = 0.7, Rate = 4 } },
	Chorus = { Class = "ChorusSoundEffect", Props = { Depth = 0.4, Mix = 0.6, Rate = 1.5 } },
	Tremolo = { Class = "TremoloSoundEffect", Props = { Depth = 1, Duty = 0.5, Frequency = 22 } },
	OctaveDown = { Class = "PitchShiftSoundEffect", Props = { Octave = 0.5 } },
}

-- Layer fields: S = file, Speed = pitch, Volume, Fx = effects,
-- From/To = only play that part (seconds), Delay = start later,
-- Jitter = random pitch range (default 0.06), Loop = loop it
local RECIPES = {
	-- UI + rolling ----------------------------------------------------
	Tick = { { S = "Tick", Speed = 1, Volume = 0.55, Jitter = 0 } },
	Click = { { S = "Tick", Speed = 1.35, Volume = 0.5 }, { S = "Thud", Speed = 2.6, Volume = 0.15, From = 0, To = 0.1 } },
	Hover = { { S = "Tick", Speed = 1.9, Volume = 0.15 } },
	Whoosh = { { S = "Wind", Speed = 1.8, Volume = 0.35, From = 0, To = 0.45, Fx = { "Bright" } } },
	Pop = { { S = "Boom", Speed = 2.4, Volume = 0.2, From = 0, To = 0.5, Fx = { "Bright" } }, { S = "Tick", Speed = 1.6, Volume = 0.3 } },
	RevealRare = { { S = "Boom", Speed = 1.6, Volume = 0.32, Fx = { "Reverb" } }, { S = "Water", Speed = 2.2, Volume = 0.2, Fx = { "Reverb", "Bright" } } },
	RevealEpic = { { S = "Boom", Speed = 1.2, Volume = 0.42, Fx = { "Reverb" } }, { S = "Water", Speed = 1.8, Volume = 0.25, Fx = { "Chorus", "Reverb" } } },
	RevealLegendary = { { S = "Boom", Speed = 0.85, Volume = 0.55, Fx = { "Reverb", "Echo" } }, { S = "Tick", Speed = 0.5, Volume = 0.5, Fx = { "BigReverb", "Chorus" } } },
	RevealMythic = { { S = "Boom", Speed = 0.62, Volume = 0.7, Fx = { "Reverb", "Echo", "Bass" } }, { S = "Boom", Speed = 0.4, Volume = 0.4, Fx = { "BigReverb", "OctaveDown" } }, { S = "Tick", Speed = 0.35, Volume = 0.5, Fx = { "BigReverb", "Flange" } } },
	Heartbeat = { { S = "Boom", Speed = 0.33, Volume = 0.9, From = 0, To = 0.5, Fx = { "Muffle", "Compress" } } },
	Rumble = { { S = "Wind", Speed = 0.45, Volume = 0.6, Loop = true, Fx = { "Muffle" } } },
	Equip = { { S = "Boom", Speed = 2, Volume = 0.18, From = 0, To = 0.6, Fx = { "Bright" } }, { S = "Water", Speed = 2.4, Volume = 0.2, Fx = { "Reverb" } } },
	Purchase = { { S = "Tick", Speed = 1.5, Volume = 0.5, Fx = { "Reverb" }, Jitter = 0 } },
	Thud = { { S = "Thud", Speed = 0.8, Volume = 0.5 } },

	-- FIGHTING ---------------------------------------------------------
	SwingLight = {
		{ S = "Wind", Speed = 3.4, Volume = 0.5, From = 0, To = 0.28, Fx = { "Bright" } },
		{ S = "Jump", Speed = 1.7, Volume = 0.25, Fx = { "Thin" } },
	},
	SwingHeavy = {
		{ S = "Wind", Speed = 2.1, Volume = 0.85, From = 0, To = 0.5 },
		{ S = "Jump", Speed = 1.05, Volume = 0.45 },
	},
	Jab = { -- a crisp punch landing
		{ S = "Thud", Speed = 1.9, Volume = 1, Fx = { "Bass", "Compress" } },
		{ S = "Boom", Speed = 3.6, Volume = 0.3, From = 0, To = 0.18, Fx = { "Bright" } },
		{ S = "Tick", Speed = 2.6, Volume = 0.35 },
	},
	HeavyHit = { -- a big smash
		{ S = "Thud", Speed = 1.15, Volume = 1, Fx = { "Bass", "Crunch" } },
		{ S = "Boom", Speed = 1.7, Volume = 0.7, From = 0, To = 0.55, Fx = { "Distort", "Bass" } },
		{ S = "Boom", Speed = 0.75, Volume = 0.35, From = 0, To = 1.2, Fx = { "Reverb", "Muffle" } },
		{ S = "Tick", Speed = 1.4, Volume = 0.4, Fx = { "ShortEcho" } },
	},
	Block = { -- metallic clang
		{ S = "Tick", Speed = 3.4, Volume = 0.9, Fx = { "ShortEcho", "Flange" } },
		{ S = "Boom", Speed = 4, Volume = 0.3, From = 0, To = 0.15, Fx = { "Bright" } },
		{ S = "Thud", Speed = 2.3, Volume = 0.45 },
	},
	GuardBreak = { -- shield shattering
		{ S = "Boom", Speed = 2.2, Volume = 0.75, From = 0, To = 0.4, Fx = { "Distort" } },
		{ S = "Water", Speed = 2.8, Volume = 0.6, Fx = { "Bright", "ShortEcho" } },
		{ S = "Tick", Speed = 0.6, Volume = 0.8, Fx = { "Flange", "Echo" } },
	},
	Dodge = {
		{ S = "Wind", Speed = 2.7, Volume = 0.65, From = 0, To = 0.32, Fx = { "Bright" } },
		{ S = "Steps", Speed = 1.7, Volume = 0.35, From = 0, To = 0.22 },
	},
	HurtLight = { { S = "Ouch", Speed = 1.05, Volume = 0.4, Jitter = 0.1 } },
	HurtHeavy = { { S = "Oof", Speed = 0.95, Volume = 0.5, Jitter = 0.1 } },
	Shoot = {
		{ S = "Tick", Speed = 1.8, Volume = 0.6, Fx = { "Echo" } },
		{ S = "Wind", Speed = 4, Volume = 0.4, From = 0, To = 0.2, Fx = { "Bright" } },
	},
	BeamFire = {
		{ S = "Tick", Speed = 0.45, Volume = 1, Fx = { "Echo", "Flange" } },
		{ S = "Wind", Speed = 3.5, Volume = 0.6, From = 0, To = 0.7, Fx = { "Flange" } },
		{ S = "Boom", Speed = 2.4, Volume = 0.45, From = 0, To = 0.3, Fx = { "Crunch" } },
	},
	Explosion = {
		{ S = "Boom", Speed = 0.85, Volume = 1, Fx = { "Bass", "Compress" } },
		{ S = "Boom", Speed = 0.5, Volume = 0.6, Fx = { "Reverb", "OctaveDown" } },
		{ S = "Water", Speed = 0.6, Volume = 0.35, Delay = 0.05 },
	},
	IceShatter = {
		{ S = "Water", Speed = 2.9, Volume = 0.75, Fx = { "Reverb", "Bright" } },
		{ S = "Tick", Speed = 0.3, Volume = 0.8, Fx = { "Reverb" } },
		{ S = "Tick", Speed = 5, Volume = 0.3, Delay = 0.08 },
	},
	HealShimmer = {
		{ S = "Water", Speed = 1.7, Volume = 0.35, Fx = { "Reverb", "Chorus" } },
		{ S = "Tick", Speed = 1.5, Volume = 0.4, Fx = { "Reverb" } },
		{ S = "Tick", Speed = 1.89, Volume = 0.35, Delay = 0.08, Fx = { "Reverb" } },
		{ S = "Tick", Speed = 2.25, Volume = 0.3, Delay = 0.16, Fx = { "Reverb" } },
	},
	TeleportZap = {
		{ S = "Water", Speed = 3.6, Volume = 0.5, Fx = { "Flange" } },
		{ S = "Tick", Speed = 0.8, Volume = 0.7, Fx = { "Echo" } },
		{ S = "Wind", Speed = 4, Volume = 0.4, From = 0, To = 0.15 },
	},
	BurnCrackle = { { S = "Wind", Speed = 4.5, Volume = 0.3, From = 0, To = 0.22, Fx = { "Tremolo", "Bright" } } },
	Vacuum = {
		{ S = "Wind", Speed = 0.75, Volume = 0.85, From = 0, To = 0.9, Fx = { "Flange" } },
		{ S = "Boom", Speed = 0.6, Volume = 0.5, From = 0, To = 0.8, Fx = { "Muffle" }, Delay = 0.3 },
	},
	ShieldUp = {
		{ S = "Tick", Speed = 0.7, Volume = 0.7, Fx = { "Chorus", "Reverb" } },
		{ S = "Water", Speed = 2.2, Volume = 0.35, Fx = { "Flange" } },
	},
	Beep = { { S = "Tick", Speed = 1, Volume = 1, Fx = { "ShortEcho" }, Jitter = 0 }, { S = "Tick", Speed = 2, Volume = 0.4, Jitter = 0 } },
	Gong = { -- "FIGHT!"
		{ S = "Boom", Speed = 0.45, Volume = 1, Fx = { "BigReverb", "Bass" }, Jitter = 0 },
		{ S = "Tick", Speed = 0.25, Volume = 0.8, Fx = { "BigReverb", "Chorus" }, Jitter = 0 },
		{ S = "Boom", Speed = 1.2, Volume = 0.5, From = 0, To = 0.6, Jitter = 0 },
	},

	-- old names kept so nothing else breaks
	Punch = { { S = "Thud", Speed = 1.5, Volume = 0.7, Fx = { "Bass" } } },
	Hit = { { S = "Boom", Speed = 2.8, Volume = 0.3, From = 0, To = 0.3, Fx = { "Bright" } } },
	Swoosh = { { S = "Wind", Speed = 2.4, Volume = 0.4, From = 0, To = 0.25, Fx = { "Bright" } } },
	Zap = { { S = "Tick", Speed = 0.5, Volume = 0.8, Fx = { "Echo" } } },
	Freeze = { { S = "Tick", Speed = 0.35, Volume = 0.9, Fx = { "Reverb", "Bright" } }, { S = "Water", Speed = 2.6, Volume = 0.4, Fx = { "Reverb" } } },

	-- drum kit for the duel beat
	Kick = { { S = "Boom", Speed = 0.38, Volume = 0.8, From = 0, To = 0.28, Fx = { "Muffle", "Compress" }, Jitter = 0.02 } },
	Snare = {
		{ S = "Thud", Speed = 1.45, Volume = 0.55, Jitter = 0.03 },
		{ S = "Boom", Speed = 2.6, Volume = 0.3, From = 0, To = 0.12, Fx = { "Bright" }, Jitter = 0.03 },
	},
	HatClosed = { { S = "Tick", Speed = 3.2, Volume = 0.2, Fx = { "Thin" }, Jitter = 0.03 } },
	HatOpen = { { S = "Wind", Speed = 5, Volume = 0.14, From = 0, To = 0.14, Fx = { "Thin" }, Jitter = 0.03 } },
}
SoundFX.Recipes = RECIPES

-- All game sounds go through one group so they can be muted together
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
SoundFX.MusicGroup = musicGroup

local muted = false
local DEFAULT_JITTER = 0.06

local function addEffects(sound, list)
	for priority, effectName in ipairs(list or {}) do
		local recipe = EFFECTS[effectName]
		if recipe then
			local effect = Instance.new(recipe.Class)
			for key, value in pairs(recipe.Props) do
				effect[key] = value
			end
			effect.Priority = priority
			effect.Parent = sound
		end
	end
end

local function place(sound, opts)
	if opts.Parent then
		-- 3D sound that comes from a place in the world
		sound.RollOffMinDistance = 10
		sound.RollOffMaxDistance = opts.MaxDistance or 150
		sound.Parent = opts.Parent
	else
		sound.Parent = SoundService
	end
end

local function buildLayer(layer, opts)
	local sound = Instance.new("Sound")
	sound.Name = "SFX"
	sound.SoundId = FILES[layer.S] or FILES.Tick
	local jitter = opts.NoJitter and 0 or (layer.Jitter or DEFAULT_JITTER)
	sound.PlaybackSpeed = layer.Speed * (opts.Speed or 1) * (1 + rand:NextNumber(-jitter, jitter))
	sound.Volume = layer.Volume * (opts.Volume or 1)
	sound.Looped = layer.Loop == true
	sound.SoundGroup = opts.Music and musicGroup or group
	if layer.From then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(layer.From, layer.To or (layer.From + 1))
	end
	addEffects(sound, layer.Fx)
	place(sound, opts)
	return sound
end

local function lifetime(layer, speed)
	if layer.To then
		return (layer.To - (layer.From or 0)) / math.max(speed, 0.05) + 1.5
	end
	return 6
end

local function buildOverride(id, opts)
	local sound = Instance.new("Sound")
	sound.Name = "SFX"
	sound.SoundId = id
	sound.Volume = 0.5 * (opts.Volume or 1)
	sound.PlaybackSpeed = opts.Speed or 1
	sound.SoundGroup = opts.Music and musicGroup or group
	place(sound, opts)
	return sound
end

-- Play a sound by name. opts: { Speed, Volume, Parent = part (3D), MaxDistance, NoJitter }
-- Returns the first layer's Sound.
function SoundFX.Play(name, opts)
	opts = opts or {}
	local override = Config.SoundOverrides[name]
	if override ~= nil and override ~= "" then
		local sound = buildOverride(override, opts)
		sound:Play()
		Debris:AddItem(sound, 8)
		return sound
	end
	local recipe = RECIPES[name]
	if not recipe then
		warn("[SoundFX] unknown sound", name)
		return nil
	end
	local first
	for _, layer in ipairs(recipe) do
		local function go()
			if opts.Parent and not opts.Parent.Parent then
				return -- the thing making the sound is gone
			end
			local sound = buildLayer(layer, opts)
			sound:Play()
			if not sound.Looped then
				Debris:AddItem(sound, lifetime(layer, sound.PlaybackSpeed))
			end
			return sound
		end
		if layer.Delay then
			task.delay(layer.Delay, go)
		else
			local sound = go()
			first = first or sound
		end
	end
	return first
end

-- Start a looping sound (fades in). Stop it with SoundFX.FadeOut.
function SoundFX.Loop(name, fadeIn, opts)
	opts = opts or {}
	local recipe = RECIPES[name]
	if not recipe then
		return nil
	end
	local layer = table.clone(recipe[1])
	layer.Loop = true
	layer.From, layer.To = nil, nil
	local sound = buildLayer(layer, opts)
	local target = sound.Volume
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

-- A rising "charging up" whoosh that lasts `duration` seconds
function SoundFX.Riser(duration, opts)
	opts = opts or {}
	local sound = buildLayer({ S = "Wind", Speed = 0.5, Volume = 0.7, Loop = true, Fx = { "Flange", "Bright" }, Jitter = 0 }, opts)
	sound.Volume = 0.1 * (opts.Volume or 1)
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		PlaybackSpeed = 2.2,
		Volume = 0.8 * (opts.Volume or 1),
	}):Play()
	task.delay(duration, function()
		SoundFX.FadeOut(sound, 0.15)
	end)
	return sound
end

-- Notes made from the click sound. steps = list of pitch ratios.
function SoundFX.Notes(steps, gap, opts)
	opts = opts or {}
	task.spawn(function()
		for _, ratio in ipairs(steps) do
			if type(ratio) == "table" then -- a chord: several notes at once
				for _, r in ipairs(ratio) do
					SoundFX.Play("Purchase", { Speed = r / 1.5, Volume = (opts.Volume or 0.8) * 0.7, NoJitter = true, Parent = opts.Parent })
				end
			else
				SoundFX.Play("Purchase", { Speed = ratio / 1.5, Volume = opts.Volume or 0.8, NoJitter = true, Parent = opts.Parent })
			end
			task.wait(gap or 0.08)
		end
	end)
end

-- Quick rising "ding ding ding" (new best, purchases)
function SoundFX.Chime(baseSpeed, notes)
	baseSpeed = baseSpeed or 1
	local scale = { 1, 1.26, 1.5, 2, 2.52 }
	local steps = {}
	for i = 1, math.min(notes or 4, #scale) do
		steps[i] = scale[i] * baseSpeed
	end
	SoundFX.Notes(steps, 0.07)
end

-- Short tunes
function SoundFX.Jingle(name)
	if name == "Victory" then
		SoundFX.Notes({ 1, 1.26, 1.5, 2, 1.5, 2, { 2, 2.52, 3 } }, 0.1, { Volume = 0.9 })
		task.delay(0.65, function()
			SoundFX.Play("Gong", { Volume = 0.6, Speed = 1.4 })
		end)
	elseif name == "Defeat" then
		SoundFX.Notes({ 1.5, 1.33, 1.19, 1, { 0.75, 0.89, 1.12 } }, 0.16, { Volume = 0.8 })
		task.delay(0.7, function()
			SoundFX.Play("Heartbeat", { Volume = 1 })
		end)
	elseif name == "Rebirth" then
		-- rising riser, a big boom, then a bright fanfare
		SoundFX.Riser(1.1, { Volume = 0.9 })
		task.delay(1.1, function()
			SoundFX.Play("Explosion", { Volume = 0.7, Speed = 0.8 })
			SoundFX.Play("Gong", { Volume = 0.8, Speed = 1.1 })
			SoundFX.Play("RevealMythic", { Volume = 0.7 })
			SoundFX.Notes({ 1, 1.26, 1.5, 2, { 1.5, 2, 2.52 }, 2.52, { 2, 2.52, 3 } }, 0.09, { Volume = 0.9 })
		end)
	elseif name == "Countdown" then
		SoundFX.Play("Beep")
	end
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
		ambient.SoundId = FILES.Wind
		ambient.PlaybackSpeed = 0.22
		ambient.Volume = Config.AmbientVolume * 0.35
		addEffects(ambient, { "Muffle" })
	end
	ambient.Parent = SoundService
	ambient:Play()
end

function SoundFX.SetAmbientVolume(fraction, duration)
	if ambient then
		local base = (Config.AmbientMusic ~= "") and Config.AmbientVolume or Config.AmbientVolume * 0.35
		TweenService:Create(ambient, TweenInfo.new(duration or 1), { Volume = base * fraction }):Play()
	end
end

return SoundFX
