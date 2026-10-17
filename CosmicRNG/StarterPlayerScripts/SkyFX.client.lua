-- SkyFX (LocalScript in StarterPlayer > StarterPlayerScripts)
-- In charge of the sky on your screen:
--   * the sky slowly drifts through different moods on the main island
--     (violet dusk, teal nebula, rose galaxy, deep indigo)
--   * every island has its own sky colors, and they blend smoothly
--   * a secret roll can take over the sky for a few seconds (RollUI)
--   * animates the sky scenery from SkyDecor: twinkling stars, turning
--     galaxies, bobbing islets, glowing suns and the swimming sky whale

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rand = Random.new()

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

---------------------------------------------------------------------
-- SKY MOODS
---------------------------------------------------------------------
-- The main island drifts through these, one after another
local MOODS = {
	{ -- violet dusk
		Ambient = rgb(70, 60, 110), Outdoor = rgb(110, 95, 170),
		Color = rgb(120, 90, 210), Decay = rgb(50, 30, 110), Tint = rgb(245, 240, 255), Saturation = 0.15, Density = 0.3,
	},
	{ -- teal nebula
		Ambient = rgb(55, 80, 110), Outdoor = rgb(90, 150, 185),
		Color = rgb(70, 175, 215), Decay = rgb(20, 60, 105), Tint = rgb(235, 250, 255), Saturation = 0.2, Density = 0.32,
	},
	{ -- rose galaxy
		Ambient = rgb(95, 60, 100), Outdoor = rgb(170, 100, 165),
		Color = rgb(220, 110, 190), Decay = rgb(90, 30, 95), Tint = rgb(255, 240, 248), Saturation = 0.2, Density = 0.3,
	},
	{ -- deep indigo with a warm glow
		Ambient = rgb(60, 55, 105), Outdoor = rgb(105, 100, 180),
		Color = rgb(95, 95, 225), Decay = rgb(35, 25, 85), Tint = rgb(252, 245, 232), Saturation = 0.12, Density = 0.34,
	},
}
local MOOD_SECONDS = 70 -- how long each mood lasts
local BLEND_SECONDS = 20 -- how long the change between moods takes

-- Each place has its own sky
local PLACES = {
	Lucky = {
		Ambient = rgb(120, 90, 100), Outdoor = rgb(190, 140, 160),
		Color = rgb(255, 170, 195), Decay = rgb(140, 70, 110), Tint = rgb(255, 238, 225), Saturation = 0.25, Density = 0.28,
	},
	Frostfall = {
		Ambient = rgb(130, 150, 190), Outdoor = rgb(170, 205, 245),
		Color = rgb(200, 230, 255), Decay = rgb(110, 150, 210), Tint = rgb(225, 240, 255), Saturation = 0.05, Density = 0.33,
	},
	Ember = {
		Ambient = rgb(130, 70, 50), Outdoor = rgb(210, 110, 70),
		Color = rgb(255, 140, 90), Decay = rgb(120, 40, 25), Tint = rgb(255, 225, 205), Saturation = 0.2, Density = 0.36,
	},
	Nexus = {
		Ambient = rgb(110, 60, 140), Outdoor = rgb(170, 90, 220),
		Color = rgb(255, 110, 230), Decay = rgb(60, 20, 120), Tint = rgb(245, 225, 255), Saturation = 0.35, Density = 0.3,
	},
	Duel = {
		Ambient = rgb(90, 55, 80), Outdoor = rgb(160, 90, 130),
		Color = rgb(210, 90, 130), Decay = rgb(80, 20, 60), Tint = rgb(255, 238, 240), Saturation = 0.18, Density = 0.3,
	},
}

local function lerpMood(a, b, t)
	return {
		Ambient = a.Ambient:Lerp(b.Ambient, t),
		Outdoor = a.Outdoor:Lerp(b.Outdoor, t),
		Color = a.Color:Lerp(b.Color, t),
		Decay = a.Decay:Lerp(b.Decay, t),
		Tint = a.Tint:Lerp(b.Tint, t),
		Saturation = a.Saturation + (b.Saturation - a.Saturation) * t,
		Density = a.Density + (b.Density - a.Density) * t,
	}
end

-- the main-island mood right now (same for everyone: it follows the server clock)
local function cycleMood()
	local now = workspace:GetServerTimeNow()
	local total = #MOODS * MOOD_SECONDS
	local phase = now % total
	local index = math.floor(phase / MOOD_SECONDS) + 1
	local into = phase % MOOD_SECONDS
	local current = MOODS[index]
	local nextMood = MOODS[(index % #MOODS) + 1]
	local blendStart = MOOD_SECONDS - BLEND_SECONDS
	if into > blendStart then
		local t = (into - blendStart) / BLEND_SECONDS
		t = t * t * (3 - 2 * t) -- smooth
		return lerpMood(current, nextMood, t)
	end
	return current
end

local function placeMood(root)
	local rebirthIsland = player:GetAttribute("OnRebirthIsland")
	if rebirthIsland and PLACES[rebirthIsland] then
		return PLACES[rebirthIsland]
	end
	if player:GetAttribute("OnLuckyIsland") then
		return PLACES.Lucky
	end
	if root then
		local duel = Config.Places.DuelIsland
		local flat = Vector3.new(root.Position.X - duel.X, 0, root.Position.Z - duel.Z)
		if flat.Magnitude < Config.Places.DuelIslandRadius + 8 then
			return PLACES.Duel
		end
	end
	return nil
end

-- secret rolls take over the sky for a moment (RollUI sets these)
local function skyShiftMood(base)
	local untilTime = Lighting:GetAttribute("SkyShiftUntil")
	if not untilTime or os.clock() > untilTime then
		return base
	end
	local a = Lighting:GetAttribute("SkyShiftA") or base.Color
	local b = Lighting:GetAttribute("SkyShiftB") or base.Decay
	return {
		Ambient = base.Ambient, Outdoor = base.Outdoor,
		Color = a, Decay = b, Tint = a:Lerp(Color3.new(1, 1, 1), 0.6),
		Saturation = base.Saturation + 0.2, Density = base.Density,
	}
end

local current -- what the sky looks like right now (blends toward the target)

local function apply(mood)
	Lighting.Ambient = mood.Ambient
	Lighting.OutdoorAmbient = mood.Outdoor
	local atmosphere = Lighting:FindFirstChild("CosmicAtmosphere") or Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Color = mood.Color
		atmosphere.Decay = mood.Decay
		atmosphere.Density = mood.Density
	end
	local grade = Lighting:FindFirstChild("CosmicColor")
	if grade then
		grade.TintColor = mood.Tint
		grade.Saturation = mood.Saturation
	end
end

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local target = skyShiftMood(placeMood(root) or cycleMood())
	if not current then
		current = target
	else
		current = lerpMood(current, target, 1 - math.exp(-dt * 0.9))
	end
	apply(current)
end)

---------------------------------------------------------------------
-- SKY SCENERY ANIMATION
---------------------------------------------------------------------
local decor = workspace:WaitForChild("CosmicSkyDecor", 60)
if not decor then
	warn("[SkyFX] CosmicSkyDecor not found")
	return
end

local twinklers, spinners, bobbers, breathers = {}, {}, {}, {}
local whale
for _, item in ipairs(decor:GetDescendants()) do
	if item:IsA("BasePart") then
		local twinkle = item:GetAttribute("FX_Twinkle")
		if twinkle then
			table.insert(twinklers, { Part = item, Phase = twinkle, Base = item.Transparency })
		end
		local breathe = item:GetAttribute("FX_Breathe")
		if breathe then
			table.insert(breathers, { Part = item, Phase = breathe, Base = item.Size, BaseT = item.Transparency })
		end
	elseif item:IsA("Model") then
		if item:GetAttribute("FX_Whale") then
			whale = { Model = item, Radius = item:GetAttribute("OrbitRadius") or 190, Height = item:GetAttribute("OrbitHeight") or 105 }
		elseif item:GetAttribute("FX_SpinLocal") then
			table.insert(spinners, { Model = item, Base = item:GetPivot(), Speed = item:GetAttribute("FX_SpinLocal") })
		elseif item:GetAttribute("FX_Bob") then
			table.insert(bobbers, {
				Model = item,
				Base = item:GetPivot(),
				Bob = item:GetAttribute("FX_Bob"),
				Spin = item:GetAttribute("FX_SpinY") or 0,
				Phase = rand:NextNumber(0, 6),
			})
		end
	end
end

local FAR = 1100 -- sky things are big, so animate them from further away
local function near(position, range)
	return (camera.CFrame.Position - position).Magnitude < (range or FAR)
end

local t = 0
local frame = 0
RunService.RenderStepped:Connect(function(dt)
	t += dt
	frame += 1

	for _, s in ipairs(twinklers) do
		s.Part.Transparency = math.clamp(s.Base + (math.sin(t * 2.3 + s.Phase * 3) + 1) * 0.3, 0, 0.95)
	end
	for _, b in ipairs(breathers) do
		local wave = math.sin(t * 0.9 + b.Phase)
		b.Part.Size = b.Base * (1 + wave * 0.04 * b.Phase)
		b.Part.Transparency = math.clamp(b.BaseT + wave * 0.05, 0, 0.98)
	end

	-- slow things only need updating every other frame
	if frame % 2 == 0 then
		for _, s in ipairs(spinners) do
			if near(s.Base.Position) then
				s.Model:PivotTo(s.Base * CFrame.Angles(0, t * s.Speed, 0))
			end
		end
		for _, b in ipairs(bobbers) do
			if near(b.Base.Position, 600) then
				b.Model:PivotTo(b.Base * CFrame.new(0, math.sin(t * 0.5 + b.Phase) * b.Bob, 0) * CFrame.Angles(0, t * b.Spin, 0))
			end
		end
	end

	-- the sky whale glides around the main island, gently rising and falling
	if whale and near(Vector3.new(0, whale.Height, 0), 900) then
		local speed = (math.pi * 2) / 140
		local angle = t * speed
		local position = Vector3.new(math.cos(angle) * whale.Radius, whale.Height + math.sin(t * 0.35) * 10, math.sin(angle) * whale.Radius)
		local ahead = Vector3.new(math.cos(angle + 0.05) * whale.Radius, whale.Height + math.sin((t + 0.4) * 0.35) * 10, math.sin(angle + 0.05) * whale.Radius)
		local look = CFrame.lookAt(position, ahead)
		-- leans into the turn and sways a little as it swims
		whale.Model:PivotTo(look * CFrame.Angles(0, math.sin(t * 0.8) * 0.06, math.rad(-12) + math.sin(t * 0.6) * 0.05))
	end
end)
