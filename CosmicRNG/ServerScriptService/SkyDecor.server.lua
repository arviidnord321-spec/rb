-- SkyDecor (Script in ServerScriptService)
-- Fills the sky around every island with scenery, each in its own colors:
--   * glowing nebula clouds far away
--   * a slowly turning spiral galaxy
--   * little floating islets with crystals, trees and light waterfalls
--   * a big planet or sun for each rebirth island and Lucky Isle
--   * big sky isles with tiny temples, trees and waterfalls of light
--   * lots of sky creatures: whales, manta rays, jellyfish, fish schools,
--     space turtles, koi, star sprites, sky serpents, butterfly swarms and
--     lantern-fish anglers. Their fins, wings, tails and tentacles move on
--     their own (SkyFX), and many leave glowing ribbons behind them
-- Everything here is just scenery (no collisions). Things marked with FX_
-- attributes are animated by the SkyFX script on each player's screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))

local rand = Random.new(777)
local FLAT = CFrame.Angles(0, 0, math.rad(90))

local old = workspace:FindFirstChild("CosmicSkyDecor")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "CosmicSkyDecor"

local function part(props)
	local className = props.ClassName or "Part"
	local p = Instance.new(className)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		if key ~= "Parent" and key ~= "ClassName" then
			p[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

-- Sky scenery floats far from anything it could light up, so real lights
-- would only cost frame rate. Neon + bloom already makes it glow, so big
-- glowing things get a cheap "glow sprite" (a camera-facing Beam) instead.
local GLOW_TEXTURE = Config.Textures.Glow
local function addLight(target, color3, range, _brightness)
	if not target or range < 18 then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, -0.05, 0)
	a0.Parent = target
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0.05, 0)
	a1.Parent = target
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Texture = GLOW_TEXTURE
	beam.Width0 = range * 0.5
	beam.Width1 = range * 0.5
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Transparency = NumberSequence.new(0.55)
	beam.Color = ColorSequence.new(color3)
	beam.Segments = 1
	beam.Parent = target
end

local function sparkles(target, color3, rate, size, speed)
	local e = Instance.new("ParticleEmitter")
	e.Texture = Config.Textures.Sparkle
	e.Rate = rate
	e.Lifetime = NumberRange.new(2, 4)
	e.Speed = NumberRange.new(speed or 0.5, (speed or 0.5) * 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Color = ColorSequence.new(color3)
	e.Parent = target
	return e
end

local function newModel(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

---------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------
-- A nebula: overlapping see-through glowing clouds
local function nebula(parent, center, colors, scale)
	local model = newModel("Nebula", parent)
	for i = 1, 9 do
		local size = rand:NextNumber(60, 150) * scale
		local offset = Vector3.new(rand:NextNumber(-1, 1) * 110, rand:NextNumber(-0.5, 0.5) * 60, rand:NextNumber(-1, 1) * 110) * scale
		part({
			Name = "Cloud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size * rand:NextNumber(1, 1.8), size * 0.6, size),
			CFrame = CFrame.new(center + offset) * CFrame.Angles(0, rand:NextNumber(0, 6), rand:NextNumber(-0.3, 0.3)),
			Color = colors[(i % #colors) + 1],
			Material = Enum.Material.Neon,
			Transparency = rand:NextNumber(0.86, 0.93),
			Parent = model,
		})
	end
	-- a few bright stars inside the cloud
	for _ = 1, 6 do
		local star = part({
			Name = "NebulaStar",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rand:NextNumber(2, 5) * scale,
			CFrame = CFrame.new(center + Vector3.new(rand:NextNumber(-90, 90), rand:NextNumber(-30, 30), rand:NextNumber(-90, 90)) * scale),
			Color = Color3.new(1, 1, 1),
			Material = Enum.Material.Neon,
			Parent = model,
		})
		star:SetAttribute("FX_Twinkle", rand:NextNumber(0, 6))
	end
	return model
end

-- A spiral galaxy: arms of tiny lights, tilted, slowly turning
local function galaxy(parent, center, colors, radius, tilt)
	local model = newModel("Galaxy", parent)
	local coreBall = part({
		Name = "GalaxyCore",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(radius * 0.35, radius * 0.12, radius * 0.35),
		CFrame = CFrame.new(center),
		Color = Color3.fromRGB(255, 240, 220),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		Parent = model,
	})
	part({
		Name = "GalaxyHalo",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(radius * 1.2, radius * 0.2, radius * 1.2),
		CFrame = CFrame.new(center),
		Color = colors[1],
		Material = Enum.Material.Neon,
		Transparency = 0.92,
		Parent = model,
	})
	for arm = 0, 2 do
		for i = 1, 22 do
			local f = i / 22
			local angle = arm * (math.pi * 2 / 3) + f * 4.2
			local r = radius * (0.12 + f * 0.5)
			local jitter = Vector3.new(rand:NextNumber(-1, 1), rand:NextNumber(-0.3, 0.3), rand:NextNumber(-1, 1)) * radius * 0.03
			part({
				Name = "GalaxyStar",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * (radius * 0.035 * (1.4 - f)),
				CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r) + jitter),
				Color = colors[(i % #colors) + 1]:Lerp(Color3.new(1, 1, 1), 0.3 * (1 - f)),
				Material = Enum.Material.Neon,
				Transparency = 0.1 + f * 0.4,
				Parent = model,
			})
		end
	end
	model.WorldPivot = CFrame.new(center)
	model:PivotTo(CFrame.new(center) * tilt)
	model:SetAttribute("FX_SpinLocal", 0.05)
	return coreBall
end

-- A small floating islet with something growing on top
local function islet(parent, position, theme)
	local model = newModel("Islet", parent)
	local size = rand:NextNumber(7, 13)
	part({
		Name = "IsletTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, size * 2, size * 2),
		CFrame = CFrame.new(position) * FLAT,
		Color = theme.Top,
		Material = theme.TopMaterial,
		Parent = model,
	})
	local y = -0.7
	local r = size
	for layer = 1, 4 do
		local h = 2.2 + layer * 0.6
		r *= 0.72
		part({
			Name = "IsletRock",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h, r * 2, r * 2),
			CFrame = CFrame.new(position + Vector3.new(0, y - h / 2, 0)) * FLAT,
			Color = (layer % 2 == 0) and theme.Rock or theme.RockDark,
			Material = theme.RockMaterial,
			Parent = model,
		})
		y -= h
	end
	-- glowing crystal at the bottom tip
	local tip = part({
		Name = "IsletTip",
		Size = Vector3.new(1.4, 4, 1.4),
		CFrame = CFrame.new(position + Vector3.new(0, y - 1.5, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Color = theme.Glow,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	addLight(tip, theme.Glow, 18, 1.2)

	-- what grows on top
	local kind = rand:NextInteger(1, 3)
	local top = position + Vector3.new(0, 0.7, 0)
	if kind == 1 then
		-- crystal cluster
		for k = 1, rand:NextInteger(3, 5) do
			local h = (k == 1) and rand:NextNumber(4, 7) or rand:NextNumber(2, 4)
			part({
				Name = "IsletCrystal",
				Size = Vector3.new(h * 0.25, h, h * 0.25),
				CFrame = CFrame.new(top + Vector3.new(rand:NextNumber(-2, 2), h * 0.4, rand:NextNumber(-2, 2)))
					* CFrame.Angles(rand:NextNumber(-0.3, 0.3), rand:NextNumber(0, 3), rand:NextNumber(-0.3, 0.3)),
				Color = theme.Glow,
				Material = Enum.Material.Neon,
				Transparency = 0.1,
				Parent = model,
			})
		end
	elseif kind == 2 then
		-- a little tree with glowing leaves
		local h = rand:NextNumber(4, 6)
		part({
			Name = "IsletTrunk",
			Size = Vector3.new(0.8, h, 0.8),
			CFrame = CFrame.new(top + Vector3.new(0, h / 2, 0)),
			Color = theme.Trunk,
			Material = Enum.Material.Wood,
			Parent = model,
		})
		for k = 1, 3 do
			part({
				Name = "IsletLeaves",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * (4.2 - k * 0.7),
				CFrame = CFrame.new(top + Vector3.new(rand:NextNumber(-0.8, 0.8), h + k * 0.9, rand:NextNumber(-0.8, 0.8))),
				Color = theme.Leaves,
				Material = theme.LeavesMaterial or Enum.Material.Neon,
				Transparency = 0.05,
				Parent = model,
			})
		end
	else
		-- a tiny shrine with a floating orb
		for _, s in ipairs({ -1, 1 }) do
			part({
				Name = "ShrinePillar",
				Size = Vector3.new(0.6, 4, 0.6),
				CFrame = CFrame.new(top + Vector3.new(s * 1.6, 2, 0)),
				Color = theme.Rock,
				Material = theme.RockMaterial,
				Parent = model,
			})
		end
		part({
			Name = "ShrineTop",
			Size = Vector3.new(4.6, 0.6, 1.2),
			CFrame = CFrame.new(top + Vector3.new(0, 4.2, 0)),
			Color = theme.Rock,
			Material = theme.RockMaterial,
			Parent = model,
		})
		local orb = part({
			Name = "ShrineOrb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.4,
			CFrame = CFrame.new(top + Vector3.new(0, 2.2, 0)),
			Color = theme.Glow,
			Material = Enum.Material.Neon,
			Parent = model,
		})
		addLight(orb, theme.Glow, 14, 1.5)
	end

	-- a waterfall of light spilling off the edge
	if rand:NextNumber() < 0.6 then
		local a = rand:NextNumber(0, math.pi * 2)
		local edge = position + Vector3.new(math.cos(a) * (size - 0.6), 0, math.sin(a) * (size - 0.6))
		local fall = part({
			Name = "LightFall",
			Size = Vector3.new(2.2, 26, 0.3),
			CFrame = CFrame.lookAt(edge + Vector3.new(0, -12.5, 0), position + Vector3.new(0, -12.5, 0)),
			Color = theme.Fall,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			Parent = model,
		})
		local mist = sparkles(fall, theme.Fall, 6, 0.6, 1)
		mist.Acceleration = Vector3.new(0, -4, 0)
	end
	sparkles(model:FindFirstChild("IsletTop"), theme.Glow, 2, 0.4)
	model:SetAttribute("FX_Bob", rand:NextNumber(1.2, 2.5))
	model:SetAttribute("FX_SpinY", rand:NextNumber(-0.05, 0.05))
	model.WorldPivot = CFrame.new(position)
	return model
end

-- A planet with an optional ring and a soft glow shell
local function planet(parent, center, radius, color3, glowColor, ringColor, tilt, material)
	local model = newModel("SkyPlanet", parent)
	part({
		Name = "Planet",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * radius * 2,
		CFrame = CFrame.new(center),
		Color = color3,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = model,
	})
	part({
		Name = "PlanetShell",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * radius * 2.12,
		CFrame = CFrame.new(center),
		Color = glowColor,
		Material = Enum.Material.ForceField,
		Transparency = 0.3,
		Parent = model,
	})
	-- bands across the planet
	for k = -2, 2 do
		local y = k * radius * 0.28
		local r = math.sqrt(math.max(0, radius * radius - y * y)) + 0.4
		part({
			Name = "PlanetBand",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(radius * 0.08, r * 2, r * 2),
			CFrame = CFrame.new(center + Vector3.new(0, y, 0)) * FLAT,
			Color = color3:Lerp(glowColor, 0.35 + (k % 2) * 0.2),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end
	if ringColor then
		local ring = newModel("PlanetRing", model)
		local segments = 80
		local ringRadius = radius * 1.7
		local length = (2 * math.pi * ringRadius / segments) * 1.06
		for i = 1, segments do
			local a = (i / segments) * math.pi * 2
			local p = center + Vector3.new(math.cos(a) * ringRadius, 0, math.sin(a) * ringRadius)
			part({
				Name = "RingSegment",
				Size = Vector3.new(radius * 0.35, radius * 0.02, length),
				CFrame = CFrame.lookAt(p, center) * CFrame.Angles(0, math.pi / 2, 0),
				Color = ringColor,
				Material = Enum.Material.Neon,
				Transparency = 0.35,
				Parent = ring,
			})
		end
		ring.WorldPivot = CFrame.new(center)
		ring:PivotTo(CFrame.new(center) * (tilt or CFrame.new()))
		ring:SetAttribute("FX_SpinLocal", 0.02)
	end
	return model
end

-- A glowing star (sun) with layered corona
local function sun(parent, center, radius, core, corona)
	local model = newModel("SkySun", parent)
	part({ Name = "SunCore", Shape = Enum.PartType.Ball, Size = Vector3.one * radius * 2, CFrame = CFrame.new(center), Color = core, Material = Enum.Material.Neon, Parent = model })
	for k = 1, 3 do
		local shell = part({
			Name = "Corona",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * radius * (2 + k * 0.5),
			CFrame = CFrame.new(center),
			Color = corona,
			Material = Enum.Material.Neon,
			Transparency = 0.7 + k * 0.08,
			Parent = model,
		})
		shell:SetAttribute("FX_Breathe", k)
	end
	return model
end

---------------------------------------------------------------------
-- One themed sky around an island
---------------------------------------------------------------------
-- A BIG sky isle: a chunky floating island with trees, crystals, a tiny
-- temple and a waterfall of light
local function bigIsle(parent, position, theme)
	local model = newModel("SkyIsle", parent)
	local radius = rand:NextNumber(18, 26)
	part({ Name = "IsleTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, radius * 2, radius * 2), CFrame = CFrame.new(position) * FLAT, Color = theme.Top, Material = theme.TopMaterial, Parent = model })
	part({ Name = "IsleRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, radius * 2 + 1, radius * 2 + 1), CFrame = CFrame.new(position - Vector3.new(0, 0.6, 0)) * FLAT, Color = theme.Glow, Material = Enum.Material.Neon, Parent = model })
	local y, r = -1, radius
	for layer = 1, 6 do
		local h = 3 + layer * 1.2
		r *= 0.74
		part({ Name = "IsleRock", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, r * 2, r * 2), CFrame = CFrame.new(position + Vector3.new(rand:NextNumber(-1, 1), y - h / 2, rand:NextNumber(-1, 1))) * FLAT,
			Color = (layer % 2 == 0) and theme.Rock or theme.RockDark, Material = theme.RockMaterial, Parent = model })
		y -= h
	end
	local tip = part({ Name = "IsleTip", Size = Vector3.new(3, 9, 3), CFrame = CFrame.new(position + Vector3.new(0, y - 3.5, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = theme.Glow, Material = Enum.Material.Neon, Parent = model })
	addLight(tip, theme.Glow, 40, 2)
	-- a tiny temple in the middle
	local top = position + Vector3.new(0, 1, 0)
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		part({ Name = "TemplePillar", Size = Vector3.new(1.2, 8, 1.2), CFrame = CFrame.new(top + Vector3.new(math.cos(a) * 5, 4, math.sin(a) * 5)), Color = theme.Rock, Material = theme.RockMaterial, Parent = model })
	end
	part({ Name = "TempleRoof", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 15, 15), CFrame = CFrame.new(top + Vector3.new(0, 8.6, 0)) * FLAT, Color = theme.RockDark, Material = theme.RockMaterial, Parent = model })
	local orb = part({ Name = "TempleOrb", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = CFrame.new(top + Vector3.new(0, 3.5, 0)), Color = theme.Glow, Material = Enum.Material.Neon, Parent = model })
	orb:SetAttribute("FX_Twinkle", rand:NextNumber(0, 6))
	addLight(orb, theme.Glow, 24, 2)
	-- trees and crystals around the edge
	for k = 1, rand:NextInteger(5, 8) do
		local a = rand:NextNumber(0, math.pi * 2)
		local d = rand:NextNumber(9, radius - 3)
		local spot = top + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		if k % 2 == 0 then
			local h = rand:NextNumber(5, 9)
			part({ Name = "Trunk", Size = Vector3.new(1, h, 1), CFrame = CFrame.new(spot + Vector3.new(0, h / 2, 0)), Color = theme.Trunk, Material = Enum.Material.Wood, Parent = model })
			part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * rand:NextNumber(4, 6), CFrame = CFrame.new(spot + Vector3.new(0, h + 1, 0)), Color = theme.Leaves, Material = theme.LeavesMaterial or Enum.Material.Neon, Parent = model })
		else
			local h = rand:NextNumber(4, 8)
			part({ Name = "Crystal", Size = Vector3.new(h * 0.25, h, h * 0.25), CFrame = CFrame.new(spot + Vector3.new(0, h * 0.4, 0)) * CFrame.Angles(rand:NextNumber(-0.3, 0.3), rand:NextNumber(0, 3), rand:NextNumber(-0.3, 0.3)), Color = theme.Glow, Material = Enum.Material.Neon, Parent = model })
		end
	end
	-- waterfall of light
	local a = rand:NextNumber(0, math.pi * 2)
	local edge = position + Vector3.new(math.cos(a) * (radius - 1), 0, math.sin(a) * (radius - 1))
	local fall = part({ Name = "LightFall", Size = Vector3.new(4, 60, 0.4), CFrame = CFrame.lookAt(edge + Vector3.new(0, -30, 0), position + Vector3.new(0, -30, 0)), Color = theme.Fall, Material = Enum.Material.Neon, Transparency = 0.5, Parent = model })
	local mist = sparkles(fall, theme.Fall, 10, 1, 1.5)
	mist.Acceleration = Vector3.new(0, -6, 0)
	model:SetAttribute("FX_Bob", rand:NextNumber(2, 4))
	model:SetAttribute("FX_SpinY", rand:NextNumber(-0.02, 0.02))
	model.WorldPivot = CFrame.new(position)
	return model
end

---------------------------------------------------------------------
-- SKY CREATURES
-- Every creature is built facing -Z around (0, 0, 0) and then moved by
-- SkyFX each frame, using these attributes:
--   Motion = "Orbit" (circles), "Figure8", "Hover" (floats + spins),
--            "Wave" (circles with big ups and downs + banking), "Serpent"
--   Center, Radius, Height, Speed, Phase, Bob, Spin
---------------------------------------------------------------------
local creatureCount = 0
local function creatureModel(kind, parent)
	creatureCount += 1
	local model = newModel(kind, parent)
	model:SetAttribute("FX_Creature", true)
	return model
end

local function finishCreature(model, motion)
	model.WorldPivot = CFrame.new()
	for key, value in pairs(motion) do
		model:SetAttribute(key, value)
	end
	-- park it at its first spot (SkyFX takes over from there)
	local a = motion.Phase or 0
	local start = motion.Center + Vector3.new(math.cos(a) * (motion.Radius or 0), motion.Height or 0, math.sin(a) * (motion.Radius or 0))
	model:PivotTo(CFrame.new(start))
	return model
end

local function glowSpot(model, position, size, color3)
	local spot = part({ Name = "GlowSpot", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(position), Color = color3, Material = Enum.Material.Neon, Parent = model })
	spot:SetAttribute("FX_Twinkle", rand:NextNumber(0, 6))
	return spot
end

-- Secondary motion: SkyFX swings these parts around a joint while the
-- creature swims. Joint is in the creature's own space (built at 0, 0, 0).
--   Flap  = roll around the creature's forward axis (wings, fins)
--   Yaw   = swing left/right (tails)
--   Pitch = swing up/down (whale flukes, tentacles)
--   Pulse = grow and shrink (jelly domes)
local function wiggle(p, kind, joint, amp, speed, phase, side)
	p:SetAttribute("Wiggle", kind)
	p:SetAttribute("Joint", joint or Vector3.zero)
	p:SetAttribute("Amp", amp)
	p:SetAttribute("WSpeed", speed)
	p:SetAttribute("WPhase", phase or 0)
	p:SetAttribute("Side", side or 1)
	return p
end

-- a glowing ribbon that follows a part (Trail between two attachments)
local function trail(p, offsetA, offsetB, color3, lifetime, transparency)
	local a0 = Instance.new("Attachment")
	a0.Position = offsetA
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = offsetB
	a1.Parent = p
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Lifetime = lifetime or 2
	t.LightEmission = 1
	t.LightInfluence = 0
	t.FaceCamera = true
	t.Color = ColorSequence.new(color3, Color3.new(1, 1, 1))
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, transparency or 0.35), NumberSequenceKeypoint.new(1, 1) })
	t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15) })
	t.Parent = p
	return t
end

local function eye(model, position, size, glowColor)
	part({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(position), Color = Color3.fromRGB(245, 245, 255), Material = Enum.Material.SmoothPlastic, Parent = model })
	part({ Name = "Pupil", Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.6, CFrame = CFrame.new(position + Vector3.new(0, 0, -size * 0.25)), Color = Color3.fromRGB(15, 10, 30), Material = Enum.Material.SmoothPlastic, Parent = model })
	part({ Name = "EyeShine", Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.22, CFrame = CFrame.new(position + Vector3.new(size * 0.15, size * 0.18, -size * 0.45)), Color = glowColor or Color3.new(1, 1, 1), Material = Enum.Material.Neon, Parent = model })
end

-- WHALE: big and slow, bioluminescent spots, belly grooves, flapping fins,
-- a tail that beats up and down and a glowing ribbon behind it
local function whale(parent, colors, scale)
	local model = creatureModel("SkyWhale", parent)
	local sizes = { 13, 16, 17, 16, 14, 11, 8, 6, 4.5 }
	local phase = rand:NextNumber(0, 6)
	for i, s in ipairs(sizes) do
		s *= scale
		local z = (i - 3) * 6.5 * scale
		-- the back half of the body sways with the tail
		local function sway(p)
			if i >= 6 then
				wiggle(p, "Pitch", Vector3.new(0, 0, 13 * scale), 0.06 * (i - 5), 0.8, phase - i * 0.2)
			end
			return p
		end
		sway(part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.05, s * 0.85, s * 1.1), CFrame = CFrame.new(0, 0, z), Color = colors.Body, Material = Enum.Material.SmoothPlastic, Parent = model }))
		sway(part({ Name = "Belly", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.8, s * 0.55, s), CFrame = CFrame.new(0, -s * 0.2, z), Color = colors.Belly, Material = Enum.Material.SmoothPlastic, Parent = model }))
		if i >= 2 and i <= 7 then
			for _, side in ipairs({ -1, 1 }) do
				sway(glowSpot(model, Vector3.new(side * s * 0.47, s * 0.12, z), s * 0.12, colors.Glow))
				sway(glowSpot(model, Vector3.new(side * s * 0.38, s * 0.28, z + s * 0.25), s * 0.07, colors.Glow))
			end
			-- dorsal glow line
			sway(glowSpot(model, Vector3.new(0, s * 0.43, z), s * 0.09, colors.Glow))
		end
		if i <= 3 then
			-- belly grooves
			for g = -2, 2 do
				part({ Name = "Groove", Size = Vector3.new(0.25 * scale, 0.25 * scale, s * 0.9), CFrame = CFrame.new(g * s * 0.09, -s * 0.44, z), Color = colors.Belly:Lerp(Color3.new(1, 1, 1), 0.35), Material = Enum.Material.SmoothPlastic, Parent = model })
			end
		end
	end
	-- a soft shimmering glow around the body
	part({ Name = "Aura", Shape = Enum.PartType.Ball, Size = Vector3.new(22, 18, 46) * scale, CFrame = CFrame.new(0, 0, 4 * scale), Color = colors.Glow, Material = Enum.Material.ForceField, Transparency = 0.55, Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		eye(model, Vector3.new(side * 5.6, 1, -17) * scale, 1.8 * scale, colors.Glow)
		-- pectoral fins flap slowly
		local fin = part({ Name = "Fin", Size = Vector3.new(11, 0.7, 4.5) * scale, CFrame = CFrame.new(side * 12 * scale, -3.5 * scale, -5 * scale) * CFrame.Angles(0, side * -0.35, side * -0.3), Color = colors.Body, Material = Enum.Material.SmoothPlastic, Parent = model })
		wiggle(fin, "Flap", Vector3.new(side * 7 * scale, -3 * scale, -5 * scale), 0.35, 1.1, phase, side)
		local finEdge = part({ Name = "FinEdge", Size = Vector3.new(10, 0.3, 0.4) * scale, CFrame = fin.CFrame * CFrame.new(0, 0, -2.3 * scale), Color = colors.Glow, Material = Enum.Material.Neon, Parent = model })
		wiggle(finEdge, "Flap", Vector3.new(side * 7 * scale, -3 * scale, -5 * scale), 0.35, 1.1, phase, side)
		-- tail flukes beat up and down
		local fluke = part({ Name = "Fluke", Size = Vector3.new(9, 0.6, 5) * scale, CFrame = CFrame.new(side * 4.5 * scale, 0, 45 * scale) * CFrame.Angles(0, side * 0.45, 0), Color = colors.Body, Material = Enum.Material.SmoothPlastic, Parent = model })
		wiggle(fluke, "Pitch", Vector3.new(0, 0, 13 * scale), 0.3, 0.8, phase - 2)
		local flukeEdge = part({ Name = "FlukeEdge", Size = Vector3.new(9, 0.25, 0.4) * scale, CFrame = fluke.CFrame * CFrame.new(0, 0, 2.6 * scale), Color = colors.Glow, Material = Enum.Material.Neon, Parent = model })
		wiggle(flukeEdge, "Pitch", Vector3.new(0, 0, 13 * scale), 0.3, 0.8, phase - 2)
	end
	local tailGlow = part({ Name = "TailGlow", Shape = Enum.PartType.Ball, Size = Vector3.one * 3 * scale, CFrame = CFrame.new(0, 0, 40 * scale), Color = colors.Glow, Material = Enum.Material.Neon, Transparency = 0.3, Parent = model })
	wiggle(tailGlow, "Pitch", Vector3.new(0, 0, 13 * scale), 0.24, 0.8, phase - 1.6)
	local dust = sparkles(tailGlow, colors.Glow, 25, 1.2 * scale, 0.3)
	dust.Lifetime = NumberRange.new(4, 6)
	trail(tailGlow, Vector3.new(0, 2.5 * scale, 0), Vector3.new(0, -2.5 * scale, 0), colors.Glow, 3, 0.4)
	addLight(tailGlow, colors.Glow, 40, 2)
	return model
end

-- MANTA RAY: wide wings that flap like a bird's, glowing edges and
-- ribbons streaming from the wingtips
local function manta(parent, colors, scale)
	local model = creatureModel("SkyManta", parent)
	local phase = rand:NextNumber(0, 6)
	part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 1.8, 9) * scale, CFrame = CFrame.new(), Color = colors.Body, Material = Enum.Material.SmoothPlastic, Parent = model })
	part({ Name = "Underside", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 1.2, 8) * scale, CFrame = CFrame.new(0, -0.35 * scale, 0), Color = colors.Belly, Material = Enum.Material.SmoothPlastic, Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		local joint = Vector3.new(side * 3 * scale, 0, 0)
		local wing = part({ Name = "Wing", Size = Vector3.new(10, 0.5, 6.5) * scale, CFrame = CFrame.new(side * 7.5 * scale, 0, 0.8 * scale) * CFrame.Angles(0, side * 0.3, 0), Color = colors.Body, Material = Enum.Material.SmoothPlastic, Parent = model })
		wiggle(wing, "Flap", joint, 0.45, 1.6, phase, side)
		local inner = part({ Name = "WingPattern", Size = Vector3.new(7, 0.55, 3) * scale, CFrame = wing.CFrame * CFrame.new(side * -0.5 * scale, 0, 0.5 * scale), Color = colors.Belly, Material = Enum.Material.SmoothPlastic, Parent = model })
		wiggle(inner, "Flap", joint, 0.45, 1.6, phase, side)
		local edge = part({ Name = "WingEdge", Size = Vector3.new(10.5, 0.3, 0.35) * scale, CFrame = wing.CFrame * CFrame.new(0, 0, -3.3 * scale), Color = colors.Glow, Material = Enum.Material.Neon, Parent = model })
		wiggle(edge, "Flap", joint, 0.45, 1.6, phase, side)
		local tip = part({ Name = "WingTip", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8 * scale, CFrame = wing.CFrame * CFrame.new(side * 5.2 * scale, 0, -2 * scale), Color = colors.Glow, Material = Enum.Material.Neon, Parent = model })
		wiggle(tip, "Flap", joint, 0.45, 1.6, phase, side)
		trail(tip, Vector3.new(0, 0.4 * scale, 0), Vector3.new(0, -0.4 * scale, 0), colors.Glow, 1.6, 0.25)
		for k = 1, 3 do
			local spot = glowSpot(model, Vector3.new(side * (4 + k * 1.6), 0.35, -0.5 + k * 0.6) * scale, 0.45 * scale, colors.Glow)
			wiggle(spot, "Flap", joint, 0.45, 1.6, phase, side)
		end
		part({ Name = "Horn", Size = Vector3.new(0.5, 0.5, 2.8) * scale, CFrame = CFrame.new(side * 1.6 * scale, 0, -5 * scale) * CFrame.Angles(0, side * -0.15, 0), Color = colors.Body, Material = Enum.Material.SmoothPlastic, Parent = model })
		eye(model, Vector3.new(side * 2.4, 0.4, -3.6) * scale, 0.6 * scale, colors.Glow)
	end
	local tail = part({ Name = "Tail", Size = Vector3.new(0.3, 0.3, 11) * scale, CFrame = CFrame.new(0, 0, 9.5 * scale), Color = colors.Glow, Material = Enum.Material.Neon, Parent = model })
	wiggle(tail, "Yaw", Vector3.new(0, 0, 4 * scale), 0.3, 1.6, phase + 1)
	sparkles(tail, colors.Glow, 6, 0.6 * scale, 0.2)
	return model
end

-- JELLYFISH: a breathing see-through bell, frilly arms and long tentacles
-- that sway in waves
local function jelly(parent, colors, scale)
	local model = creatureModel("SkyJelly", parent)
	local phase = rand:NextNumber(0, 6)
	local dome = part({ Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 5.5, 8) * scale, CFrame = CFrame.new(), Color = colors.Body, Material = Enum.Material.Neon, Transparency = 0.5, Parent = model })
	wiggle(dome, "Pulse", Vector3.zero, 0.08, 1.4, phase)
	local shell = part({ Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.new(8.8, 6.2, 8.8) * scale, CFrame = CFrame.new(), Color = colors.Glow, Material = Enum.Material.ForceField, Transparency = 0.4, Parent = model })
	wiggle(shell, "Pulse", Vector3.zero, 0.08, 1.4, phase)
	part({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.one * 3 * scale, CFrame = CFrame.new(0, 0.4 * scale, 0), Color = colors.Glow, Material = Enum.Material.Neon, Parent = model })
	for k = 1, 4 do -- the four glowing rings inside the bell
		local a = k / 4 * math.pi * 2
		part({ Name = "Organ", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 0.5, 1.2) * scale, CFrame = CFrame.new(math.cos(a) * 1.6 * scale, 0.9 * scale, math.sin(a) * 1.6 * scale), Color = colors.Belly, Material = Enum.Material.Neon, Parent = model })
	end
	part({ Name = "Skirt", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 8.4, 8.4) * scale, CFrame = CFrame.new(0, -1.4 * scale, 0) * FLAT, Color = colors.Glow, Material = Enum.Material.Neon, Transparency = 0.3, Parent = model })
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2
		local length = rand:NextNumber(9, 16) * scale
		local top = Vector3.new(math.cos(a) * 3 * scale, -1.5 * scale, math.sin(a) * 3 * scale)
		local tentacle = part({ Name = "Tentacle", Size = Vector3.new(0.22 * scale, length, 0.22 * scale), CFrame = CFrame.new(top - Vector3.new(0, length / 2, 0)),
			Color = (k % 2 == 0) and colors.Glow or colors.Body, Material = Enum.Material.Neon, Transparency = 0.2, Parent = model })
		wiggle(tentacle, "Pitch", top, 0.18, 1.2, phase + k * 0.6)
		local bead = part({ Name = "Bead", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5 * scale, CFrame = CFrame.new(top - Vector3.new(0, length, 0)), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Parent = model })
		wiggle(bead, "Pitch", top, 0.18, 1.2, phase + k * 0.6)
	end
	for k = 1, 4 do -- frilly oral arms
		local a = k / 4 * math.pi * 2 + 0.4
		local top = Vector3.new(math.cos(a) * 0.8 * scale, -1.6 * scale, math.sin(a) * 0.8 * scale)
		local arm = part({ Name = "Arm", Size = Vector3.new(1.1 * scale, 7 * scale, 0.15 * scale), CFrame = CFrame.new(top - Vector3.new(0, 3.5 * scale, 0)) * CFrame.Angles(0, a, 0), Color = colors.Belly, Material = Enum.Material.Neon, Transparency = 0.35, Parent = model })
		wiggle(arm, "Pitch", top, 0.12, 0.9, phase + k)
	end
	addLight(dome, colors.Glow, 30 * scale, 1.5)
	sparkles(dome, colors.Glow, 3, 0.5 * scale, 0.3)
	return model
end

-- FISH SCHOOL: a bunch of little fish, each with its own tail beat
local function school(parent, colors, count)
	local model = creatureModel("SkySchool", parent)
	for i = 1, count do
		local offset = Vector3.new(rand:NextNumber(-8, 8), rand:NextNumber(-3.5, 3.5), rand:NextNumber(-9, 9))
		local s = rand:NextNumber(0.8, 1.35)
		local color = (i % 3 == 0) and colors.Glow or colors.Body
		local phase = rand:NextNumber(0, 6)
		part({ Name = "FishBody", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1.3, 2.4) * s, CFrame = CFrame.new(offset), Color = color, Material = Enum.Material.Neon, Parent = model })
		part({ Name = "FishBelly", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.7, 1.9) * s, CFrame = CFrame.new(offset + Vector3.new(0, -0.3 * s, 0)), Color = colors.Belly, Material = Enum.Material.SmoothPlastic, Parent = model })
		local tail = part({ ClassName = "WedgePart", Name = "FishTail", Size = Vector3.new(0.15, 1.3, 1.1) * s, CFrame = CFrame.new(offset + Vector3.new(0, 0, 1.7 * s)), Color = colors.Glow, Material = Enum.Material.Neon, Parent = model })
		wiggle(tail, "Yaw", offset + Vector3.new(0, 0, 1.1 * s), 0.6, 9, phase)
		part({ Name = "FishEye", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.25 * s, CFrame = CFrame.new(offset + Vector3.new(0.35 * s, 0.25 * s, -0.75 * s)), Color = Color3.fromRGB(15, 10, 30), Material = Enum.Material.SmoothPlastic, Parent = model })
	end
	local leader = model:FindFirstChild("FishBody")
	if leader then
		trail(leader, Vector3.new(0, 0.3, 0), Vector3.new(0, -0.3, 0), colors.Glow, 1.2, 0.3)
	end
	return model
end

-- SPACE TURTLE: glowing hexagon shell and slowly rowing flippers
local function turtle(parent, colors, scale)
	local model = creatureModel("SkyTurtle", parent)
	local phase = rand:NextNumber(0, 6)
	part({ Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.new(12, 5, 14) * scale, CFrame = CFrame.new(0, 0.6 * scale, 0), Color = colors.Body, Material = Enum.Material.SmoothPlastic, Parent = model })
	part({ Name = "ShellRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 12.6, 12.6) * scale, CFrame = CFrame.new(0, -0.1 * scale, 0) * FLAT, Color = colors.Glow, Material = Enum.Material.Neon, Transparency = 0.2, Parent = model })
	part({ Name = "Belly", Shape = Enum.PartType.Ball, Size = Vector3.new(11, 3, 13) * scale, CFrame = CFrame.new(0, -0.6 * scale, 0), Color = colors.Belly, Material = Enum.Material.SmoothPlastic, Parent = model })
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		local spot = (k == 0) and Vector3.new(0, 3.2, 0) or Vector3.new(math.cos(a) * 3.6, 2.5, math.sin(a) * 4.2)
		glowSpot(model, spot * scale, 1.6 * scale, colors.Glow)
	end
	part({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 2.6, 3.4) * scale, CFrame = CFrame.new(0, 0.3 * scale, -8.4 * scale), Color = colors.Belly, Material = Enum.Material.SmoothPlastic, Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		eye(model, Vector3.new(side * 1.1, 0.9, -9.6) * scale, 0.7 * scale, colors.Glow)
		local front = part({ Name = "Flipper", Size = Vector3.new(7, 0.5, 2.6) * scale, CFrame = CFrame.new(side * 7 * scale, -0.4 * scale, -3.5 * scale) * CFrame.Angles(0, side * -0.4, side * -0.2), Color = colors.Belly, Material = Enum.Material.SmoothPlastic, Parent = model })
		wiggle(front, "Flap", Vector3.new(side * 4.5 * scale, 0, -3.5 * scale), 0.4, 0.9, phase, side)
		local back = part({ Name = "Flipper", Size = Vector3.new(4.5, 0.5, 2) * scale, CFrame = CFrame.new(side * 5.5 * scale, -0.4 * scale, 5 * scale) * CFrame.Angles(0, side * 0.5, 0), Color = colors.Belly, Material = Enum.Material.SmoothPlastic, Parent = model })
		wiggle(back, "Flap", Vector3.new(side * 4 * scale, 0, 5 * scale), 0.25, 0.9, phase + 1.5, side)
	end
	return model
end

-- KOI: long fish with flowing see-through fins and a wavy body
local function koi(parent, colors, scale)
	local model = creatureModel("SkyKoi", parent)
	local phase = rand:NextNumber(0, 6)
	local sizes = { 3, 3.6, 3.4, 2.8, 2, 1.3 }
	for i, s in ipairs(sizes) do
		local seg = part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s * 0.9, s * 1.3) * scale, CFrame = CFrame.new(0, 0, (i - 2) * 1.9 * scale), Color = (i % 2 == 0) and colors.Body or colors.Belly, Material = Enum.Material.SmoothPlastic, Parent = model })
		if i >= 3 then
			wiggle(seg, "Yaw", Vector3.new(0, 0, 0), 0.08 * (i - 2), 2.2, phase - i * 0.4)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		local fin = part({ ClassName = "WedgePart", Name = "Fin", Size = Vector3.new(0.15, 1.8, 2.8) * scale, CFrame = CFrame.new(side * 2 * scale, -0.6 * scale, -0.4 * scale) * CFrame.Angles(0, 0, side * 1.1), Color = colors.Glow, Material = Enum.Material.Neon, Transparency = 0.3, Parent = model })
		wiggle(fin, "Flap", Vector3.new(side * 1.2 * scale, -0.4 * scale, -0.4 * scale), 0.35, 2, phase, side)
		eye(model, Vector3.new(side * 1.1, 0.4, -3.3) * scale, 0.55 * scale, colors.Glow)
		local whisker = part({ Name = "Whisker", Size = Vector3.new(0.1, 0.1, 2.4) * scale, CFrame = CFrame.new(side * 0.8 * scale, -0.6 * scale, -4.4 * scale) * CFrame.Angles(0.3, side * 0.5, 0), Color = colors.Glow, Material = Enum.Material.Neon, Parent = model })
		wiggle(whisker, "Yaw", Vector3.new(side * 0.6 * scale, -0.5 * scale, -3.4 * scale), 0.2, 1.5, phase + side)
		local tailFin = part({ ClassName = "WedgePart", Name = "TailFin", Size = Vector3.new(0.15, 2.6, 3.6) * scale, CFrame = CFrame.new(side * 0.6 * scale, 0, 9.4 * scale) * CFrame.Angles(0, side * 0.35, 0), Color = colors.Glow, Material = Enum.Material.Neon, Transparency = 0.2, Parent = model })
		wiggle(tailFin, "Yaw", Vector3.new(0, 0, 0), 0.4, 2.2, phase - 2.6)
	end
	local dorsal = part({ ClassName = "WedgePart", Name = "Dorsal", Size = Vector3.new(0.15, 1.6, 4.4) * scale, CFrame = CFrame.new(0, 1.8 * scale, 1 * scale), Color = colors.Glow, Material = Enum.Material.Neon, Transparency = 0.15, Parent = model })
	wiggle(dorsal, "Yaw", Vector3.new(0, 0, 0), 0.1, 2.2, phase - 1)
	local tailRoot = model:FindFirstChild("TailFin")
	if tailRoot then
		trail(tailRoot, Vector3.new(0, 1 * scale, 0), Vector3.new(0, -1 * scale, 0), colors.Glow, 1.4, 0.4)
	end
	return model
end

-- STAR SPRITE: a spinning five-pointed star that leaves a sparkling ribbon
local function starSprite(parent, colors, scale)
	local model = creatureModel("SkyStar", parent)
	local core = part({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6 * scale, CFrame = CFrame.new(), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Parent = model })
	part({ Name = "Halo", Shape = Enum.PartType.Ball, Size = Vector3.one * 4.2 * scale, CFrame = CFrame.new(), Color = colors.Glow, Material = Enum.Material.ForceField, Transparency = 0.3, Parent = model })
	for k = 0, 4 do
		part({ ClassName = "WedgePart", Name = "Point", Size = Vector3.new(0.6, 2.4, 1.6) * scale, CFrame = CFrame.Angles(0, 0, k * math.pi * 2 / 5) * CFrame.new(0, 1.8 * scale, 0), Color = (k % 2 == 0) and colors.Glow or colors.Body, Material = Enum.Material.Neon, Parent = model })
	end
	sparkles(core, colors.Glow, 8, 0.5 * scale, 1)
	trail(core, Vector3.new(0, 0.8 * scale, 0), Vector3.new(0, -0.8 * scale, 0), colors.Glow, 1, 0.3)
	addLight(core, colors.Glow, 20 * scale, 1.5)
	return model
end

-- BUTTERFLY SWARM: little glowing butterflies fluttering together
local function butterflies(parent, colors, count)
	local model = creatureModel("SkyButterflies", parent)
	for i = 1, count do
		local offset = Vector3.new(rand:NextNumber(-7, 7), rand:NextNumber(-4, 4), rand:NextNumber(-7, 7))
		local s = rand:NextNumber(0.8, 1.3)
		local wingColor = (i % 2 == 0) and colors.Glow or colors.Belly
		local phase = rand:NextNumber(0, 6)
		part({ Name = "ButterflyBody", Size = Vector3.new(0.2, 0.2, 1.2) * s, CFrame = CFrame.new(offset), Color = colors.Body, Material = Enum.Material.SmoothPlastic, Parent = model })
		for _, side in ipairs({ -1, 1 }) do
			local joint = offset
			local upper = part({ Name = "Wing", Size = Vector3.new(1.5, 0.05, 1.1) * s, CFrame = CFrame.new(offset + Vector3.new(side * 0.8 * s, 0, -0.25 * s)), Color = wingColor, Material = Enum.Material.Neon, Transparency = 0.15, Parent = model })
			wiggle(upper, "Flap", joint, 0.9, 11, phase, side)
			local lower = part({ Name = "Wing", Size = Vector3.new(1, 0.05, 0.8) * s, CFrame = CFrame.new(offset + Vector3.new(side * 0.55 * s, 0, 0.45 * s)), Color = wingColor:Lerp(Color3.new(1, 1, 1), 0.3), Material = Enum.Material.Neon, Transparency = 0.2, Parent = model })
			wiggle(lower, "Flap", joint, 0.9, 11, phase, side)
		end
	end
	sparkles(model:FindFirstChild("ButterflyBody"), colors.Glow, 6, 0.4, 0.5)
	return model
end

-- ANGLER: a deep-sky lantern fish with teeth and a glowing lure
local function angler(parent, colors, scale)
	local model = creatureModel("SkyAngler", parent)
	local phase = rand:NextNumber(0, 6)
	part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 5.5, 7) * scale, CFrame = CFrame.new(), Color = colors.Body, Material = Enum.Material.SmoothPlastic, Parent = model })
	local jaw = part({ Name = "Jaw", Shape = Enum.PartType.Ball, Size = Vector3.new(5.2, 2.4, 4.4) * scale, CFrame = CFrame.new(0, -1.9 * scale, -1.6 * scale), Color = colors.Body, Material = Enum.Material.SmoothPlastic, Parent = model })
	wiggle(jaw, "Pitch", Vector3.new(0, -1 * scale, 0), 0.08, 1.3, phase)
	for k = -3, 3 do -- teeth
		local tooth = part({ ClassName = "WedgePart", Name = "Tooth", Size = Vector3.new(0.3, 0.7, 0.3) * scale, CFrame = CFrame.new(k * 0.6 * scale, -0.9 * scale, -3.5 * scale + math.abs(k) * 0.25 * scale), Color = Color3.fromRGB(240, 240, 250), Material = Enum.Material.SmoothPlastic, Parent = model })
		wiggle(tooth, "Pitch", Vector3.new(0, -1 * scale, 0), 0.08, 1.3, phase)
	end
	for _, side in ipairs({ -1, 1 }) do
		eye(model, Vector3.new(side * 1.8, 1.2, -2.6) * scale, 0.8 * scale, colors.Glow)
		local fin = part({ ClassName = "WedgePart", Name = "Fin", Size = Vector3.new(0.15, 1.6, 2) * scale, CFrame = CFrame.new(side * 3 * scale, -0.4 * scale, 0.5 * scale) * CFrame.Angles(0, 0, side * 1.2), Color = colors.Glow, Material = Enum.Material.Neon, Transparency = 0.3, Parent = model })
		wiggle(fin, "Flap", Vector3.new(side * 2.6 * scale, -0.4 * scale, 0.5 * scale), 0.4, 2.5, phase, side)
		for k = 1, 3 do
			glowSpot(model, Vector3.new(side * 2.6, -0.5 + k * 0.6, -1 + k * 1.2) * scale, 0.35 * scale, colors.Glow)
		end
	end
	local tail = part({ ClassName = "WedgePart", Name = "Tail", Size = Vector3.new(0.2, 3, 2.6) * scale, CFrame = CFrame.new(0, 0, 4.6 * scale), Color = colors.Body, Material = Enum.Material.SmoothPlastic, Parent = model })
	wiggle(tail, "Yaw", Vector3.new(0, 0, 3.3 * scale), 0.45, 3, phase)
	-- the lure: a bent stalk with a glowing bulb
	local stalk = part({ Name = "Stalk", Size = Vector3.new(0.18, 0.18, 4.5) * scale, CFrame = CFrame.lookAt(Vector3.new(0, 3.6, -1) * scale, Vector3.new(0, 5, -4.5) * scale) * CFrame.new(0, 0, -2.2 * scale), Color = colors.Body, Material = Enum.Material.SmoothPlastic, Parent = model })
	wiggle(stalk, "Pitch", Vector3.new(0, 2.6 * scale, -0.5 * scale), 0.15, 1, phase + 1)
	local lure = part({ Name = "Lure", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3 * scale, CFrame = CFrame.new(Vector3.new(0, 5.2, -5.4) * scale), Color = colors.Glow, Material = Enum.Material.Neon, Parent = model })
	wiggle(lure, "Pitch", Vector3.new(0, 2.6 * scale, -0.5 * scale), 0.15, 1, phase + 1)
	lure:SetAttribute("FX_Twinkle", phase)
	addLight(lure, colors.Glow, 26 * scale, 2.5)
	sparkles(lure, colors.Glow, 8, 0.4 * scale, 0.3)
	return model
end

-- SKY SERPENT: a long glowing dragon made of segments that follow each other
local function serpent(parent, colors, segments, scale)
	local model = creatureModel("SkySerpent", parent)
	for i = 1, segments do
		local f = (i - 1) / (segments - 1)
		local size = (i == 1) and 5.5 or (5 - f * 3.4)
		local seg = part({ Name = "Seg" .. i, Shape = Enum.PartType.Ball, Size = Vector3.one * size * scale, CFrame = CFrame.new(0, 0, (i - 1) * 3.6 * scale),
			Color = (i % 2 == 0) and colors.Body or colors.Belly, Material = Enum.Material.SmoothPlastic, Parent = model })
		seg:SetAttribute("Segment", i)
		if i > 1 and i % 2 == 1 then
			local spine = part({ ClassName = "WedgePart", Name = "Spine", Size = Vector3.new(0.4, 1.6, 1.6) * scale, CFrame = CFrame.new(0, size * 0.5 * scale + 0.6 * scale, (i - 1) * 3.6 * scale), Color = colors.Glow, Material = Enum.Material.Neon, Parent = model })
			spine:SetAttribute("Segment", i)
		end
	end
	-- the head gets horns, eyes and whiskers
	for _, side in ipairs({ -1, 1 }) do
		local horn = part({ ClassName = "WedgePart", Name = "Horn", Size = Vector3.new(0.5, 3, 1.6) * scale, CFrame = CFrame.new(side * 1.6 * scale, 2.8 * scale, 0.8 * scale) * CFrame.Angles(-0.5, 0, side * 0.3), Color = colors.Glow, Material = Enum.Material.Neon, Parent = model })
		horn:SetAttribute("Segment", 1)
		local eye = part({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1 * scale, CFrame = CFrame.new(side * 1.7 * scale, 0.8 * scale, -1.8 * scale), Color = colors.Glow, Material = Enum.Material.Neon, Parent = model })
		eye:SetAttribute("Segment", 1)
		local whisker = part({ Name = "Whisker", Size = Vector3.new(0.2, 0.2, 5) * scale, CFrame = CFrame.new(side * 2.2 * scale, -0.6 * scale, -1 * scale) * CFrame.Angles(0, side * 0.7, 0), Color = colors.Glow, Material = Enum.Material.Neon, Parent = model })
		whisker:SetAttribute("Segment", 1)
	end
	local head = model:FindFirstChild("Seg1")
	addLight(head, colors.Glow, 40, 2)
	local tailEnd = model:FindFirstChild("Seg" .. segments)
	sparkles(tailEnd, colors.Glow, 20, 0.8 * scale, 0.3).Lifetime = NumberRange.new(3, 5)
	trail(tailEnd, Vector3.new(0, 1.2 * scale, 0), Vector3.new(0, -1.2 * scale, 0), colors.Glow, 2.5, 0.35)
	model:SetAttribute("Segments", segments)
	model:SetAttribute("Spacing", 3.6 * scale)
	return model
end

local BUILD = {
	Whale = function(parent, colors) return whale(parent, colors, rand:NextNumber(0.8, 1.1)) end,
	Manta = function(parent, colors) return manta(parent, colors, rand:NextNumber(1.2, 1.8)) end,
	Jelly = function(parent, colors) return jelly(parent, colors, rand:NextNumber(0.7, 1.3)) end,
	School = function(parent, colors) return school(parent, colors, rand:NextInteger(7, 11)) end,
	Turtle = function(parent, colors) return turtle(parent, colors, rand:NextNumber(0.9, 1.3)) end,
	Koi = function(parent, colors) return koi(parent, colors, rand:NextNumber(1.2, 1.8)) end,
	Star = function(parent, colors) return starSprite(parent, colors, rand:NextNumber(1, 1.8)) end,
	Serpent = function(parent, colors) return serpent(parent, colors, 16, rand:NextNumber(1, 1.3)) end,
	Butterflies = function(parent, colors) return butterflies(parent, colors, rand:NextInteger(6, 10)) end,
	Angler = function(parent, colors) return angler(parent, colors, rand:NextNumber(1.1, 1.6)) end,
}
-- how each kind likes to move
local MOTION = {
	Whale = { "Orbit", 0.035, 0.05 },
	Manta = { "Wave", 0.06, 0.1 },
	Jelly = { "Hover", 0, 0 },
	School = { "Figure8", 0.08, 0.14 },
	Turtle = { "Orbit", 0.025, 0.04 },
	Koi = { "Figure8", 0.05, 0.09 },
	Star = { "Hover", 0, 0 },
	Serpent = { "Serpent", 0.05, 0.07 },
	Butterflies = { "Figure8", 0.06, 0.1 },
	Angler = { "Orbit", 0.04, 0.06 },
}

-- spawns a set of creatures around a center
local function populate(folder, center, list, colorsList, ring, heights)
	for _, entry in ipairs(list) do
		local kind, count = entry[1], entry[2]
		for i = 1, count do
			local colors = colorsList[((i - 1) % #colorsList) + 1]
			local model = BUILD[kind](folder, colors)
			local motion = MOTION[kind]
			local radius = rand:NextNumber(ring[1], ring[2])
			local height = rand:NextNumber(heights[1], heights[2])
			local direction = (rand:NextNumber() < 0.5) and -1 or 1
			local settings = {
				Motion = motion[1],
				Center = center,
				Radius = radius,
				Height = height,
				Speed = rand:NextNumber(motion[2], motion[3]) * direction * (180 / radius),
				Phase = rand:NextNumber(0, math.pi * 2),
				Bob = rand:NextNumber(3, 8),
			}
			if motion[1] == "Hover" then
				-- hoverers float in one spot and spin
				local a = rand:NextNumber(0, math.pi * 2)
				settings.Center = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
				settings.Radius = 0
				settings.Spin = (kind == "Star") and rand:NextNumber(1, 2.2) * direction or rand:NextNumber(0.1, 0.3) * direction
			end
			finishCreature(model, settings)
		end
	end
end

---------------------------------------------------------------------
-- One themed sky around an island
---------------------------------------------------------------------
local function decorate(name, center, theme)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = root

	local function blocked(offset)
		if theme.KeepLaneClear and math.abs(offset.X) < 80 and offset.Z > 40 then
			return true -- the rebirth island parkour heads out this way
		end
		return theme.Exclude ~= nil and theme.Exclude(offset)
	end

	-- nebulae, far out in different directions
	for i = 1, theme.Nebulae do
		local a = (i / theme.Nebulae) * math.pi * 2 + rand:NextNumber(-0.3, 0.3)
		local dist = rand:NextNumber(420, 560)
		nebula(folder, center + Vector3.new(math.cos(a) * dist, rand:NextNumber(140, 280), math.sin(a) * dist), theme.Nebula, rand:NextNumber(0.9, 1.3))
	end

	-- a spiral galaxy
	local ga = rand:NextNumber(0, math.pi * 2)
	galaxy(folder, center + Vector3.new(math.cos(ga) * 480, 320, math.sin(ga) * 480), theme.Galaxy, 170,
		CFrame.Angles(math.rad(rand:NextNumber(25, 55)), 0, math.rad(rand:NextNumber(-20, 20))))

	-- small floating islets in a loose ring around the island
	local near, far = theme.IsletRing[1], theme.IsletRing[2]
	for i = 1, theme.Islets do
		local a = (i / theme.Islets) * math.pi * 2 + rand:NextNumber(-0.2, 0.2)
		local dist = rand:NextNumber(near, far)
		local spot = center + Vector3.new(math.cos(a) * dist, rand:NextNumber(-20, 50), math.sin(a) * dist)
		if not blocked(spot - center) then
			islet(folder, spot, theme.Islet)
		end
	end

	-- big sky isles further out
	for i = 1, theme.BigIsles do
		local a = (i / theme.BigIsles) * math.pi * 2 + rand:NextNumber(-0.4, 0.4)
		local dist = rand:NextNumber(far + 40, far + 110)
		local spot = center + Vector3.new(math.cos(a) * dist, rand:NextNumber(30, 90), math.sin(a) * dist)
		if not blocked(spot - center) then
			bigIsle(folder, spot, theme.Islet)
		end
	end

	-- creatures
	populate(folder, center, theme.Creatures, theme.CreatureColors, theme.CreatureRing, theme.CreatureHeight)

	if theme.Extra then
		theme.Extra(folder, center)
	end
end

local MAIN = Vector3.new(0, 0, 0)
local MAIN_R = Config.MainIslandRadius

-- creature color sets
local function palette(body, belly, glow)
	return { Body = body, Belly = belly, Glow = glow }
end

-- MAIN ISLAND: violet, teal and pink
decorate("MainSky", MAIN, {
	Nebulae = 5,
	Nebula = { Color3.fromRGB(150, 90, 255), Color3.fromRGB(80, 200, 255), Color3.fromRGB(255, 110, 210) },
	Galaxy = { Color3.fromRGB(160, 140, 255), Color3.fromRGB(120, 220, 255) },
	Islets = 14,
	IsletRing = { MAIN_R + 45, MAIN_R + 115 },
	BigIsles = 5,
	-- keep clear of the Starstep Trail (west) and the Duel Island bridge (south)
	Exclude = function(offset)
		local angle = math.deg(math.atan2(offset.Z, offset.X)) % 360
		return (angle > 165 and angle < 245) or (math.abs(offset.X) < 80 and offset.Z > 30)
	end,
	Islet = {
		Top = Color3.fromRGB(80, 70, 120), TopMaterial = Enum.Material.Slate,
		Rock = Color3.fromRGB(60, 50, 95), RockDark = Color3.fromRGB(40, 32, 66), RockMaterial = Enum.Material.Slate,
		Glow = Color3.fromRGB(120, 230, 255), Fall = Color3.fromRGB(170, 140, 255),
		Trunk = Color3.fromRGB(70, 50, 90), Leaves = Color3.fromRGB(255, 120, 220),
	},
	Creatures = { { "Whale", 2 }, { "Manta", 4 }, { "Jelly", 7 }, { "School", 5 }, { "Turtle", 2 }, { "Koi", 4 }, { "Star", 8 }, { "Serpent", 1 }, { "Butterflies", 3 }, { "Angler", 2 } },
	CreatureColors = {
		palette(Color3.fromRGB(60, 70, 150), Color3.fromRGB(150, 190, 255), Color3.fromRGB(120, 230, 255)),
		palette(Color3.fromRGB(120, 60, 160), Color3.fromRGB(240, 170, 255), Color3.fromRGB(255, 120, 220)),
		palette(Color3.fromRGB(40, 110, 120), Color3.fromRGB(150, 255, 220), Color3.fromRGB(90, 255, 200)),
		palette(Color3.fromRGB(200, 120, 60), Color3.fromRGB(255, 230, 190), Color3.fromRGB(255, 200, 90)),
	},
	CreatureRing = { MAIN_R + 50, MAIN_R + 190 },
	CreatureHeight = { 75, 150 },
})

-- LUCKY ISLE: rose and gold, with twin golden moons
local LUCKY = Config.LuckyIsland
decorate("LuckySky", LUCKY.Center, {
	Nebulae = 4,
	Nebula = { Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 210, 120), Color3.fromRGB(120, 230, 210) },
	Galaxy = { Color3.fromRGB(255, 200, 120), Color3.fromRGB(255, 150, 200) },
	Islets = 10,
	IsletRing = { LUCKY.Radius + 40, LUCKY.Radius + 100 },
	BigIsles = 3,
	Islet = {
		Top = Color3.fromRGB(238, 232, 220), TopMaterial = Enum.Material.Marble,
		Rock = Color3.fromRGB(95, 35, 70), RockDark = Color3.fromRGB(60, 20, 45), RockMaterial = Enum.Material.Slate,
		Glow = Color3.fromRGB(255, 200, 70), Fall = Color3.fromRGB(255, 180, 210),
		Trunk = Color3.fromRGB(120, 80, 60), Leaves = Color3.fromRGB(255, 150, 200),
	},
	Creatures = { { "Koi", 5 }, { "Manta", 2 }, { "Jelly", 5 }, { "School", 3 }, { "Turtle", 1 }, { "Star", 6 }, { "Butterflies", 4 } },
	CreatureColors = {
		palette(Color3.fromRGB(255, 120, 60), Color3.fromRGB(255, 245, 235), Color3.fromRGB(255, 200, 80)),
		palette(Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 235, 245), Color3.fromRGB(255, 120, 190)),
		palette(Color3.fromRGB(80, 200, 180), Color3.fromRGB(220, 255, 245), Color3.fromRGB(120, 255, 220)),
	},
	CreatureRing = { LUCKY.Radius + 40, LUCKY.Radius + 170 },
	CreatureHeight = { 60, 130 },
	Extra = function(folder, center)
		planet(folder, center + Vector3.new(-260, 200, 300), 55, Color3.fromRGB(255, 205, 110), Color3.fromRGB(255, 240, 190), nil)
		planet(folder, center + Vector3.new(-150, 260, 380), 26, Color3.fromRGB(255, 160, 200), Color3.fromRGB(255, 220, 235), nil)
	end,
})

-- REBIRTH ISLANDS
local islandThemes = {
	Frostfall = {
		Nebulae = 4,
		Nebula = { Color3.fromRGB(90, 255, 180), Color3.fromRGB(110, 200, 255), Color3.fromRGB(190, 160, 255) },
		Galaxy = { Color3.fromRGB(170, 230, 255), Color3.fromRGB(120, 255, 200) },
		Islets = 11,
		BigIsles = 3,
		Islet = {
			Top = Color3.fromRGB(236, 244, 255), TopMaterial = Enum.Material.Snow,
			Rock = Color3.fromRGB(120, 170, 220), RockDark = Color3.fromRGB(70, 105, 160), RockMaterial = Enum.Material.Glacier,
			Glow = Color3.fromRGB(140, 230, 255), Fall = Color3.fromRGB(200, 240, 255),
			Trunk = Color3.fromRGB(90, 60, 45), Leaves = Color3.fromRGB(70, 140, 120), LeavesMaterial = Enum.Material.Grass,
		},
		Creatures = { { "Whale", 1 }, { "Jelly", 6 }, { "Manta", 3 }, { "School", 4 }, { "Turtle", 1 }, { "Star", 6 }, { "Angler", 1 } },
		CreatureColors = {
			palette(Color3.fromRGB(200, 230, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 230, 255)),
			palette(Color3.fromRGB(110, 200, 255), Color3.fromRGB(230, 250, 255), Color3.fromRGB(90, 255, 190)),
		},
		Extra = function(folder, center)
			planet(folder, center + Vector3.new(320, 230, -260), 70, Color3.fromRGB(170, 215, 245), Color3.fromRGB(220, 245, 255),
				Color3.fromRGB(190, 240, 255), CFrame.Angles(math.rad(18), 0, math.rad(-14)), Enum.Material.Glacier)
		end,
	},
	Ember = {
		Nebulae = 4,
		Nebula = { Color3.fromRGB(255, 90, 40), Color3.fromRGB(255, 170, 60), Color3.fromRGB(200, 40, 80) },
		Galaxy = { Color3.fromRGB(255, 160, 80), Color3.fromRGB(255, 80, 60) },
		Islets = 11,
		BigIsles = 3,
		Islet = {
			Top = Color3.fromRGB(70, 52, 48), TopMaterial = Enum.Material.Basalt,
			Rock = Color3.fromRGB(60, 40, 38), RockDark = Color3.fromRGB(35, 24, 26), RockMaterial = Enum.Material.Basalt,
			Glow = Color3.fromRGB(255, 120, 40), Fall = Color3.fromRGB(255, 110, 30),
			Trunk = Color3.fromRGB(35, 25, 22), Leaves = Color3.fromRGB(255, 120, 40),
		},
		Creatures = { { "Serpent", 1 }, { "Manta", 3 }, { "School", 4 }, { "Koi", 3 }, { "Star", 6 }, { "Angler", 2 }, { "Butterflies", 2 } },
		CreatureColors = {
			palette(Color3.fromRGB(120, 30, 20), Color3.fromRGB(255, 150, 60), Color3.fromRGB(255, 200, 70)),
			palette(Color3.fromRGB(40, 25, 25), Color3.fromRGB(200, 60, 30), Color3.fromRGB(255, 110, 30)),
		},
		Extra = function(folder, center)
			sun(folder, center + Vector3.new(-300, 220, -280), 60, Color3.fromRGB(255, 120, 50), Color3.fromRGB(255, 60, 30))
		end,
	},
	Nexus = {
		Nebulae = 4,
		Nebula = { Color3.fromRGB(255, 70, 220), Color3.fromRGB(60, 230, 255), Color3.fromRGB(140, 80, 255) },
		Galaxy = { Color3.fromRGB(255, 90, 230), Color3.fromRGB(80, 230, 255) },
		Islets = 11,
		BigIsles = 3,
		Islet = {
			Top = Color3.fromRGB(25, 18, 45), TopMaterial = Enum.Material.Glass,
			Rock = Color3.fromRGB(35, 22, 60), RockDark = Color3.fromRGB(22, 14, 40), RockMaterial = Enum.Material.SmoothPlastic,
			Glow = Color3.fromRGB(60, 230, 255), Fall = Color3.fromRGB(255, 70, 220),
			Trunk = Color3.fromRGB(40, 25, 70), Leaves = Color3.fromRGB(255, 70, 220),
		},
		Creatures = { { "Whale", 1 }, { "Jelly", 6 }, { "Manta", 3 }, { "School", 4 }, { "Serpent", 1 }, { "Star", 7 }, { "Butterflies", 3 }, { "Angler", 1 } },
		CreatureColors = {
			palette(Color3.fromRGB(30, 20, 60), Color3.fromRGB(60, 230, 255), Color3.fromRGB(255, 70, 220)),
			palette(Color3.fromRGB(60, 20, 80), Color3.fromRGB(255, 120, 240), Color3.fromRGB(60, 230, 255)),
		},
		Extra = function(folder, center)
			planet(folder, center + Vector3.new(-330, 210, -200), 60, Color3.fromRGB(40, 20, 80), Color3.fromRGB(255, 80, 230),
				Color3.fromRGB(60, 230, 255), CFrame.Angles(math.rad(70), 0, math.rad(10)), Enum.Material.Glass)
		end,
	},
}
for _, info in ipairs(Config.RebirthIslands) do
	local theme = islandThemes[info.Key]
	if theme then
		theme.KeepLaneClear = true
		theme.IsletRing = { info.Radius + 45, info.Radius + 110 }
		-- creatures fly high here so they stay above the parkour
		theme.CreatureRing = { info.Radius + 40, info.Radius + 180 }
		theme.CreatureHeight = { 110, 170 }
		decorate(info.Key .. "Sky", info.Center, theme)
	end
end

root:SetAttribute("CreatureCount", creatureCount)
root.Parent = workspace
