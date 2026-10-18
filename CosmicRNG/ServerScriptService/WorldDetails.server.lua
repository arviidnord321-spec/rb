-- WorldDetails (Script in ServerScriptService)
-- Small details that make every island look richer, each in its own theme:
--   * glowing grass tufts and crystal flowers on the ground
--   * soft color patches so the ground isn't one flat color
--   * constellations drawn into the ground (main island)
--   * glowing vines / icicles / lava strands hanging under the island edge
--   * waterfalls of light pouring off the edge, with mist
--   * drifting firefly motes in the air
-- Everything is scenery (no collisions).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))

local rand = Random.new(31337)
local FLAT = CFrame.Angles(0, 0, math.rad(90))

local old = workspace:FindFirstChild("IslandDetails")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "IslandDetails"

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		if key ~= "ClassName" then
			p[key] = value
		end
	end
	return p
end

local function pick(list)
	return list[rand:NextInteger(1, #list)]
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for key, value in pairs(props) do
		e[key] = value
	end
	e.LightInfluence = 0
	e.Parent = parent
	return e
end

local function fadeSeq(peak)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, peak),
		NumberSequenceKeypoint.new(0.7, peak * 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
end

---------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------
local function grassTuft(model, position, theme)
	local color = pick(theme.Grass)
	for _ = 1, rand:NextInteger(3, 6) do
		local h = rand:NextNumber(0.7, 1.9)
		part({
			Name = "Grass",
			Size = Vector3.new(0.14, h, 0.14),
			CFrame = CFrame.new(position + Vector3.new(rand:NextNumber(-0.5, 0.5), h / 2 - 0.05, rand:NextNumber(-0.5, 0.5)))
				* CFrame.Angles(rand:NextNumber(-0.35, 0.35), rand:NextNumber(0, 6), rand:NextNumber(-0.35, 0.35)),
			Color = color:Lerp(Color3.new(1, 1, 1), rand:NextNumber(0, 0.25)),
			Material = theme.GrassMaterial or Enum.Material.Neon,
			Transparency = theme.GrassTransparency or 0.1,
			Parent = model,
		})
	end
end

local function flower(model, position, theme)
	local h = rand:NextNumber(1, 1.8)
	part({
		Name = "Stem",
		Size = Vector3.new(0.12, h, 0.12),
		CFrame = CFrame.new(position + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rand:NextNumber(-0.1, 0.1), 0, rand:NextNumber(-0.1, 0.1)),
		Color = theme.Stem,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	local top = position + Vector3.new(0, h, 0)
	local petal = pick(theme.Petals)
	local spin = rand:NextNumber(0, 6)
	for k = 1, 5 do
		local a = spin + k / 5 * math.pi * 2
		part({
			Name = "Petal",
			Size = Vector3.new(0.3, 0.06, 0.62),
			CFrame = CFrame.new(top) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.05, -0.32) * CFrame.Angles(math.rad(25), 0, 0),
			Color = petal,
			Material = Enum.Material.Neon,
			Transparency = theme.PetalTransparency or 0.05,
			Parent = model,
		})
	end
	local center = part({
		Name = "FlowerHeart",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.32,
		CFrame = CFrame.new(top + Vector3.new(0, 0.1, 0)),
		Color = theme.Heart,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	if rand:NextNumber() < 0.25 then
		local light = Instance.new("PointLight")
		light.Color = petal
		light.Range = 7
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = center
	end
end

local function patch(model, position, theme, groundY)
	local r = rand:NextNumber(5, 13)
	part({
		Name = "GroundPatch",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, r * 2, r * 2 * rand:NextNumber(0.7, 1)),
		CFrame = CFrame.new(position.X, groundY + 0.04, position.Z) * CFrame.Angles(0, rand:NextNumber(0, 6), 0) * FLAT,
		Color = pick(theme.Patches),
		Material = theme.GroundMaterial,
		Parent = model,
	})
end

-- a few stars on the ground joined by thin lines
local function constellation(model, position, color, groundY)
	local points = {}
	local p = position
	for _ = 1, rand:NextInteger(4, 6) do
		table.insert(points, Vector3.new(p.X, groundY + 0.08, p.Z))
		local a = rand:NextNumber(0, math.pi * 2)
		p = p + Vector3.new(math.cos(a), 0, math.sin(a)) * rand:NextNumber(2.5, 4.5)
	end
	for i, point in ipairs(points) do
		part({ Name = "StarDot", Shape = Enum.PartType.Ball, Size = Vector3.one * (i == 1 and 0.6 or 0.4), CFrame = CFrame.new(point), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Parent = model })
		local nextPoint = points[i + 1]
		if nextPoint then
			local mid = (point + nextPoint) / 2
			part({ Name = "StarLine", Size = Vector3.new(0.08, 0.04, (nextPoint - point).Magnitude), CFrame = CFrame.lookAt(mid, nextPoint), Color = color, Material = Enum.Material.Neon, Transparency = 0.25, Parent = model })
		end
	end
end

-- a glowing strand hanging under the island edge
local function vine(model, top, outward, theme)
	local p = top
	local segments = rand:NextInteger(3, 6)
	local color = pick(theme.Vines)
	for k = 1, segments do
		local length = rand:NextNumber(2.5, 5)
		local swing = outward * rand:NextNumber(0.2, 0.9) + Vector3.new(rand:NextNumber(-0.4, 0.4), 0, rand:NextNumber(-0.4, 0.4))
		local nextP = p + Vector3.new(swing.X, -length, swing.Z)
		local mid = (p + nextP) / 2
		local thickness = math.max(0.12, 0.35 - k * 0.05)
		part({
			Name = "Vine",
			Size = Vector3.new(thickness, thickness, (nextP - p).Magnitude),
			CFrame = CFrame.lookAt(mid, nextP),
			Color = color,
			Material = theme.VineMaterial or Enum.Material.Neon,
			Transparency = theme.VineTransparency or 0.2,
			Parent = model,
		})
		p = nextP
	end
	part({ Name = "VineBulb", Shape = Enum.PartType.Ball, Size = Vector3.one * rand:NextNumber(0.4, 0.8), CFrame = CFrame.new(p), Color = theme.Bulb or color, Material = Enum.Material.Neon, Parent = model })
end

-- a spring near the edge, a stream to the edge, and a curtain of light falling off
local function lightFall(model, center, radius, angleDeg, theme, groundY)
	local a = math.rad(angleDeg)
	local out = Vector3.new(math.cos(a), 0, math.sin(a))
	local spring = Vector3.new(center.X, groundY, center.Z) + out * (radius - 9)
	local edge = Vector3.new(center.X, groundY, center.Z) + out * (radius + 0.6)
	part({ Name = "Spring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 5, 5), CFrame = CFrame.new(spring + Vector3.new(0, 0.1, 0)) * FLAT, Color = theme.Fall, Material = Enum.Material.Neon, Transparency = 0.2, Parent = model })
	part({ Name = "SpringRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 6, 6), CFrame = CFrame.new(spring + Vector3.new(0, 0.05, 0)) * FLAT, Color = theme.Rim, Material = theme.GroundMaterial, Parent = model })
	local streamMid = (spring + edge) / 2
	part({ Name = "Stream", Size = Vector3.new(2.6, 0.08, (edge - spring).Magnitude), CFrame = CFrame.lookAt(streamMid + Vector3.new(0, 0.1, 0), edge + Vector3.new(0, 0.1, 0)), Color = theme.Fall, Material = Enum.Material.Neon, Transparency = 0.3, Parent = model })
	local look = CFrame.lookAt(edge, edge + out)
	local layers = { { 4.2, 0.35 }, { 6, 0.6 }, { 8, 0.8 } }
	for i, layer in ipairs(layers) do
		local fall = part({
			Name = "LightFall",
			Size = Vector3.new(layer[1], 80, 0.25),
			CFrame = look * CFrame.new(0, -40, -0.3 - i * 0.25),
			Color = theme.Fall,
			Material = Enum.Material.Neon,
			Transparency = layer[2],
			Parent = model,
		})
		if i == 1 then
			emitter(fall, {
				Texture = Config.Textures.Glow, Rate = 18, Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(6, 10),
				SpreadAngle = Vector2.new(10, 10), EmissionDirection = Enum.NormalId.Bottom, Acceleration = Vector3.new(0, -8, 0),
				Size = fadeSeq(1.4), Transparency = NumberSequence.new(0.3), Color = ColorSequence.new(theme.Fall), LightEmission = 1,
			})
		end
	end
	-- mist where it leaves the edge
	local mistAnchor = part({ Name = "FallMist", Size = Vector3.new(5, 1, 3), CFrame = look * CFrame.new(0, -1, -1), Transparency = 1, Parent = model })
	emitter(mistAnchor, {
		Texture = Config.Textures.Smoke, Rate = 6, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(1, 2.5),
		SpreadAngle = Vector2.new(60, 60), Size = fadeSeq(4), Transparency = NumberSequence.new(0.7), Color = ColorSequence.new(theme.Fall), LightEmission = 0.6,
	})
	local light = Instance.new("PointLight")
	light.Color = theme.Fall
	light.Range = 24
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = mistAnchor
end

-- fireflies / motes drifting over the whole island
local function motes(model, center, radius, groundY, theme)
	local box = part({ Name = "Motes", Size = Vector3.new(radius * 1.9, 12, radius * 1.9), CFrame = CFrame.new(center.X, groundY + 7, center.Z), Transparency = 1, Parent = model })
	emitter(box, {
		Texture = theme.MoteTexture or Config.Textures.Glow, Rate = theme.MoteRate or 45, Lifetime = NumberRange.new(6, 10),
		Speed = NumberRange.new(0.3, 1.2), SpreadAngle = Vector2.new(180, 180), RotSpeed = NumberRange.new(-30, 30),
		Size = fadeSeq(theme.MoteSize or 0.45), Color = ColorSequence.new(theme.Motes[1], theme.Motes[2]), LightEmission = 1,
		Acceleration = Vector3.new(0, 0.15, 0),
	})
	-- a few bigger, slower glows
	emitter(box, {
		Texture = Config.Textures.Glow, Rate = 6, Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(0.2, 0.6),
		SpreadAngle = Vector2.new(180, 180), Size = fadeSeq(1.6), Transparency = NumberSequence.new(0.55),
		Color = ColorSequence.new(theme.Motes[2], theme.Motes[1]), LightEmission = 1,
	})
end

---------------------------------------------------------------------
-- Decorating an island
---------------------------------------------------------------------
local function decorate(name, center, radius, groundY, theme, blocked, options)
	local model = Instance.new("Model")
	model.Name = name .. "Details"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = root

	local function randomSpot(minR, maxR)
		for _ = 1, 30 do
			local a = rand:NextNumber(0, math.pi * 2)
			local r = rand:NextNumber(minR, maxR)
			local x, z = math.cos(a) * r, math.sin(a) * r
			if not blocked(x, z) then
				return Vector3.new(center.X + x, groundY, center.Z + z)
			end
		end
		return nil
	end

	if options.Ground then
		for _ = 1, options.Patches or 0 do
			local spot = randomSpot(12, radius - 10)
			if spot then
				patch(model, spot, theme, groundY)
			end
		end
		for _ = 1, options.Grass or 0 do
			local spot = randomSpot(10, radius - 3)
			if spot then
				grassTuft(model, spot, theme)
			end
		end
		for _ = 1, options.Flowers or 0 do
			local spot = randomSpot(12, radius - 4)
			if spot then
				flower(model, spot, theme)
			end
		end
		for _ = 1, options.Constellations or 0 do
			local spot = randomSpot(20, radius - 15)
			if spot then
				constellation(model, spot, theme.Motes[1], groundY)
			end
		end
	end

	-- hanging strands all around the edge
	for i = 1, options.Vines or 40 do
		local a = (i / (options.Vines or 40)) * math.pi * 2 + rand:NextNumber(-0.05, 0.05)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		vine(model, Vector3.new(center.X, groundY - 0.6, center.Z) + out * (radius - rand:NextNumber(1, 3)), out, theme)
	end
	for _, angle in ipairs(options.Falls or {}) do
		lightFall(model, center, radius, angle, theme, groundY)
	end
	motes(model, center, radius, groundY, theme)
end

---------------------------------------------------------------------
-- THEMES
---------------------------------------------------------------------
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local MAIN_THEME = {
	Grass = { rgb(110, 240, 220), rgb(170, 130, 255), rgb(255, 130, 210), rgb(120, 190, 255) },
	Petals = { rgb(255, 140, 220), rgb(140, 220, 255), rgb(200, 160, 255), rgb(255, 220, 140) },
	Heart = rgb(255, 250, 220), Stem = rgb(60, 50, 95),
	Patches = { rgb(70, 60, 100), rgb(56, 48, 82), rgb(66, 62, 108), rgb(74, 58, 96) },
	GroundMaterial = Enum.Material.Slate, Rim = rgb(60, 50, 95),
	Vines = { rgb(150, 110, 255), rgb(100, 220, 255), rgb(255, 120, 220) }, Bulb = rgb(255, 255, 255),
	Fall = rgb(160, 200, 255), Motes = { rgb(170, 230, 255), rgb(255, 200, 255) },
}

-- MAIN ISLAND: keep the paths and the big builds clear
do
	local P = Config.Places
	local R = Config.MainIslandRadius
	local zones = {
		{ Vector3.zero, 13 }, { P.Core, 14 }, { P.Board, 10 }, { P.PortalPlaza, 14 }, { P.Pond, 12 },
		{ P.StarstepStart, 8 }, { P.VoidTowerStart, 8 }, { P.RebirthGate, 15 }, { P.Hatchery, 20 },
	}
	local pathEnds = { P.Core, P.PortalPlaza, P.Board, P.Pond, P.StarstepStart, P.VoidTowerStart, P.RebirthGate, P.Hatchery, Vector3.new(0, 0, R) }
	local function nearPath(x, z)
		local point = Vector3.new(x, 0, z)
		for _, target in ipairs(pathEnds) do
			local flat = Vector3.new(target.X, 0, target.Z)
			local t = math.clamp(point:Dot(flat) / flat:Dot(flat), 0, 1)
			if (point - flat * t).Magnitude < 4.5 then
				return true
			end
		end
		return false
	end
	local function blocked(x, z)
		local point = Vector3.new(x, 0, z)
		for _, zone in ipairs(zones) do
			if (point - Vector3.new(zone[1].X, 0, zone[1].Z)).Magnitude < zone[2] then
				return true
			end
		end
		return nearPath(x, z) or (math.abs(x) < 8 and z > 40)
	end
	decorate("Main", Vector3.zero, R, 0, MAIN_THEME, blocked, {
		Ground = true, Patches = 40, Grass = 170, Flowers = 70, Constellations = 6, Vines = 64,
		Falls = { 15, 135, 275, 345 },
	})
end

-- LUCKY ISLE: no ground details (its buildings fill it), but vines, falls and motes
do
	local L = Config.LuckyIsland
	decorate("Lucky", L.Center, L.Radius, L.Center.Y, {
		Patches = {}, GroundMaterial = Enum.Material.Marble, Rim = rgb(238, 232, 220),
		Vines = { rgb(255, 200, 90), rgb(255, 150, 200), rgb(90, 230, 205) }, Bulb = rgb(255, 245, 210),
		Fall = rgb(255, 210, 150), Motes = { rgb(255, 220, 140), rgb(255, 170, 215) },
	}, function()
		return true
	end, { Ground = false, Vines = 48, Falls = { 60, 200, 320 } })
end

-- REBIRTH ISLANDS
local REBIRTH_THEMES = {
	Frostfall = {
		Grass = { rgb(220, 245, 255), rgb(160, 225, 255), rgb(200, 255, 245) }, GrassMaterial = Enum.Material.Ice, GrassTransparency = 0.2,
		Petals = { rgb(200, 240, 255), rgb(255, 255, 255), rgb(170, 200, 255) }, PetalTransparency = 0.2, Heart = rgb(140, 230, 255), Stem = rgb(120, 160, 200),
		Patches = { rgb(225, 238, 252), rgb(210, 228, 248), rgb(240, 248, 255) }, GroundMaterial = Enum.Material.Snow, Rim = rgb(200, 225, 250),
		Vines = { rgb(190, 235, 255), rgb(150, 210, 255) }, VineMaterial = Enum.Material.Ice, VineTransparency = 0.25, Bulb = rgb(220, 250, 255),
		Fall = rgb(170, 230, 255), Motes = { rgb(200, 240, 255), rgb(160, 255, 220) }, MoteSize = 0.35,
	},
	Ember = {
		Grass = { rgb(255, 120, 40), rgb(255, 70, 30), rgb(255, 190, 70) }, GrassTransparency = 0.15,
		Petals = { rgb(255, 110, 30), rgb(255, 60, 40), rgb(255, 200, 60) }, Heart = rgb(255, 245, 160), Stem = rgb(40, 28, 26),
		Patches = { rgb(60, 44, 40), rgb(78, 56, 50), rgb(52, 36, 36) }, GroundMaterial = Enum.Material.Basalt, Rim = rgb(40, 30, 30),
		Vines = { rgb(255, 100, 30), rgb(255, 160, 50) }, Bulb = rgb(255, 230, 120),
		Fall = rgb(255, 120, 40), Motes = { rgb(255, 170, 60), rgb(255, 80, 40) }, MoteSize = 0.3, MoteRate = 35,
	},
	Nexus = {
		Grass = { rgb(60, 230, 255), rgb(255, 70, 220), rgb(140, 80, 255) },
		Petals = { rgb(255, 80, 230), rgb(80, 240, 255), rgb(180, 120, 255) }, PetalTransparency = 0.3, Heart = rgb(255, 255, 255), Stem = rgb(40, 30, 70),
		Patches = { rgb(26, 18, 46), rgb(14, 10, 28), rgb(30, 22, 56) }, GroundMaterial = Enum.Material.SmoothPlastic, Rim = rgb(30, 20, 55),
		Vines = { rgb(60, 230, 255), rgb(255, 70, 220) }, Bulb = rgb(255, 255, 255),
		Fall = rgb(80, 220, 255), Motes = { rgb(80, 240, 255), rgb(255, 100, 230) },
		MoteTexture = "rbxasset://textures/particles/SquareParticle.png", MoteSize = 0.3,
	},
}
for _, info in ipairs(Config.RebirthIslands) do
	local theme = REBIRTH_THEMES[info.Key]
	if theme then
		local hatchery = info.Hatchery or Vector3.new(1000, 0, 1000)
		local function blocked(x, z)
			local point = Vector3.new(x, 0, z)
			return math.abs(x) < 8 -- the main path from the portal to the parkour
				or point.Magnitude < 16 -- the core
				or (point - Vector3.new(hatchery.X, 0, hatchery.Z)).Magnitude < 20
		end
		decorate(info.Key, info.Center, info.Radius, info.Center.Y, theme, blocked, {
			Ground = true, Patches = 26, Grass = 120, Flowers = 45, Vines = 56, Falls = { 0, 160, 200 },
		})
	end
end

root.Parent = workspace
