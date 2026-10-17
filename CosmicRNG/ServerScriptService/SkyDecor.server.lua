-- SkyDecor (Script in ServerScriptService)
-- Fills the sky around every island with scenery, each in its own colors:
--   * glowing nebula clouds far away
--   * a slowly turning spiral galaxy
--   * little floating islets with crystals, trees and light waterfalls
--   * a big planet or sun for each rebirth island and Lucky Isle
--   * a cosmic sky whale that swims around the main island
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

local function addLight(target, color3, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color3
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = target
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
local function decorate(name, center, theme)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = root

	-- nebulae, far out in different directions
	for i = 1, theme.Nebulae do
		local a = (i / theme.Nebulae) * math.pi * 2 + rand:NextNumber(-0.3, 0.3)
		local dist = rand:NextNumber(380, 520)
		nebula(folder, center + Vector3.new(math.cos(a) * dist, rand:NextNumber(120, 260), math.sin(a) * dist), theme.Nebula, rand:NextNumber(0.8, 1.2))
	end

	-- a spiral galaxy
	local ga = rand:NextNumber(0, math.pi * 2)
	galaxy(folder, center + Vector3.new(math.cos(ga) * 450, 300, math.sin(ga) * 450), theme.Galaxy, 160,
		CFrame.Angles(math.rad(rand:NextNumber(25, 55)), 0, math.rad(rand:NextNumber(-20, 20))))

	-- floating islets in a loose ring around the island
	for i = 1, theme.Islets do
		local a = (i / theme.Islets) * math.pi * 2 + rand:NextNumber(-0.2, 0.2)
		local dist = rand:NextNumber(120, 175)
		local spot = center + Vector3.new(math.cos(a) * dist, rand:NextNumber(-15, 45), math.sin(a) * dist)
		-- keep the parkour lane (straight out along +Z) clear on rebirth islands
		local offset = spot - center
		local blocked = theme.KeepLaneClear and math.abs(offset.X) < 60 and offset.Z > 40
		if theme.Exclude and theme.Exclude(offset) then
			blocked = true
		end
		if not blocked then
			islet(folder, spot, theme.Islet)
		end
	end

	if theme.Extra then
		theme.Extra(folder, center)
	end
end

local MAIN = Vector3.new(0, 0, 0)

-- MAIN ISLAND: violet, teal and pink
decorate("MainSky", MAIN, {
	Nebulae = 4,
	Nebula = { Color3.fromRGB(150, 90, 255), Color3.fromRGB(80, 200, 255), Color3.fromRGB(255, 110, 210) },
	Galaxy = { Color3.fromRGB(160, 140, 255), Color3.fromRGB(120, 220, 255) },
	Islets = 9,
	-- keep clear of the Starstep Trail (west) and the Duel Island bridge (south)
	Exclude = function(offset)
		local angle = math.deg(math.atan2(offset.Z, offset.X)) % 360
		return (angle > 165 and angle < 245) or (math.abs(offset.X) < 75 and offset.Z > 30)
	end,
	Islet = {
		Top = Color3.fromRGB(80, 70, 120), TopMaterial = Enum.Material.Slate,
		Rock = Color3.fromRGB(60, 50, 95), RockDark = Color3.fromRGB(40, 32, 66), RockMaterial = Enum.Material.Slate,
		Glow = Color3.fromRGB(120, 230, 255), Fall = Color3.fromRGB(170, 140, 255),
		Trunk = Color3.fromRGB(70, 50, 90), Leaves = Color3.fromRGB(255, 120, 220),
	},
	Extra = function(folder)
		-- the sky whale (SkyFX makes it swim around the island)
		local whale = newModel("SkyWhale", folder)
		local BODY = Color3.fromRGB(60, 70, 150)
		local BELLY = Color3.fromRGB(150, 190, 255)
		local GLOW = Color3.fromRGB(120, 230, 255)
		local origin = Vector3.new(0, 110, 0)
		local sizes = { 13, 16, 17, 16, 14, 11, 8, 6, 4.5 }
		for i, s in ipairs(sizes) do
			local z = (i - 3) * 6.5 -- head points to -Z
			part({ Name = "WhaleBody", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.05, s * 0.85, s * 1.1), CFrame = CFrame.new(origin + Vector3.new(0, 0, z)), Color = BODY, Material = Enum.Material.SmoothPlastic, Parent = whale })
			part({ Name = "WhaleBelly", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.8, s * 0.55, s * 1.0), CFrame = CFrame.new(origin + Vector3.new(0, -s * 0.2, z)), Color = BELLY, Material = Enum.Material.SmoothPlastic, Parent = whale })
			if i >= 2 and i <= 7 then
				for _, side in ipairs({ -1, 1 }) do
					local spot = part({ Name = "WhaleSpot", Shape = Enum.PartType.Ball, Size = Vector3.one * (s * 0.12), CFrame = CFrame.new(origin + Vector3.new(side * s * 0.47, s * 0.12, z)), Color = GLOW, Material = Enum.Material.Neon, Parent = whale })
					spot:SetAttribute("FX_Twinkle", i * 0.7)
				end
			end
		end
		-- eyes
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "WhaleEye", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = CFrame.new(origin + Vector3.new(side * 5.6, 1, -17)), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Parent = whale })
		end
		-- fins + tail
		for _, side in ipairs({ -1, 1 }) do
			part({ ClassName = "WedgePart", Name = "WhaleFin", Size = Vector3.new(1, 3, 12), CFrame = CFrame.new(origin + Vector3.new(side * 11, -3, -6)) * CFrame.Angles(0, side * 0.5, side * 0.4), Color = BODY, Material = Enum.Material.SmoothPlastic, Parent = whale })
			part({ ClassName = "WedgePart", Name = "WhaleTail", Size = Vector3.new(1, 2, 10), CFrame = CFrame.new(origin + Vector3.new(side * 5, 0, 43)) * CFrame.Angles(0, math.pi + side * 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = BODY, Material = Enum.Material.SmoothPlastic, Parent = whale })
		end
		local tailGlow = part({ Name = "WhaleTailGlow", Shape = Enum.PartType.Ball, Size = Vector3.one * 3, CFrame = CFrame.new(origin + Vector3.new(0, 0, 40)), Color = GLOW, Material = Enum.Material.Neon, Transparency = 0.3, Parent = whale })
		local trail = sparkles(tailGlow, GLOW, 25, 1.2, 0.3)
		trail.Lifetime = NumberRange.new(4, 6)
		addLight(tailGlow, GLOW, 40, 2)
		whale.WorldPivot = CFrame.new(origin)
		whale:SetAttribute("FX_Whale", true)
		whale:SetAttribute("OrbitRadius", 190)
		whale:SetAttribute("OrbitHeight", 105)
	end,
})

-- LUCKY ISLE: rose and gold, with twin golden moons
decorate("LuckySky", Config.LuckyIsland.Center, {
	Nebulae = 3,
	Nebula = { Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 210, 120), Color3.fromRGB(120, 230, 210) },
	Galaxy = { Color3.fromRGB(255, 200, 120), Color3.fromRGB(255, 150, 200) },
	Islets = 6,
	Islet = {
		Top = Color3.fromRGB(238, 232, 220), TopMaterial = Enum.Material.Marble,
		Rock = Color3.fromRGB(95, 35, 70), RockDark = Color3.fromRGB(60, 20, 45), RockMaterial = Enum.Material.Slate,
		Glow = Color3.fromRGB(255, 200, 70), Fall = Color3.fromRGB(255, 180, 210),
		Trunk = Color3.fromRGB(120, 80, 60), Leaves = Color3.fromRGB(255, 150, 200),
	},
	Extra = function(folder, center)
		planet(folder, center + Vector3.new(-260, 200, 300), 55, Color3.fromRGB(255, 205, 110), Color3.fromRGB(255, 240, 190), nil)
		planet(folder, center + Vector3.new(-150, 260, 380), 26, Color3.fromRGB(255, 160, 200), Color3.fromRGB(255, 220, 235), nil)
	end,
})

-- REBIRTH ISLANDS
local islandThemes = {
	Frostfall = {
		Nebulae = 3,
		Nebula = { Color3.fromRGB(90, 255, 180), Color3.fromRGB(110, 200, 255), Color3.fromRGB(190, 160, 255) },
		Galaxy = { Color3.fromRGB(170, 230, 255), Color3.fromRGB(120, 255, 200) },
		Islets = 7,
		Islet = {
			Top = Color3.fromRGB(236, 244, 255), TopMaterial = Enum.Material.Snow,
			Rock = Color3.fromRGB(120, 170, 220), RockDark = Color3.fromRGB(70, 105, 160), RockMaterial = Enum.Material.Glacier,
			Glow = Color3.fromRGB(140, 230, 255), Fall = Color3.fromRGB(200, 240, 255),
			Trunk = Color3.fromRGB(90, 60, 45), Leaves = Color3.fromRGB(70, 140, 120), LeavesMaterial = Enum.Material.Grass,
		},
		Extra = function(folder, center)
			-- a frozen ringed planet
			planet(folder, center + Vector3.new(320, 230, -260), 70, Color3.fromRGB(170, 215, 245), Color3.fromRGB(220, 245, 255),
				Color3.fromRGB(190, 240, 255), CFrame.Angles(math.rad(18), 0, math.rad(-14)), Enum.Material.Glacier)
		end,
	},
	Ember = {
		Nebulae = 3,
		Nebula = { Color3.fromRGB(255, 90, 40), Color3.fromRGB(255, 170, 60), Color3.fromRGB(200, 40, 80) },
		Galaxy = { Color3.fromRGB(255, 160, 80), Color3.fromRGB(255, 80, 60) },
		Islets = 7,
		Islet = {
			Top = Color3.fromRGB(70, 52, 48), TopMaterial = Enum.Material.Basalt,
			Rock = Color3.fromRGB(60, 40, 38), RockDark = Color3.fromRGB(35, 24, 26), RockMaterial = Enum.Material.Basalt,
			Glow = Color3.fromRGB(255, 120, 40), Fall = Color3.fromRGB(255, 110, 30),
			Trunk = Color3.fromRGB(35, 25, 22), Leaves = Color3.fromRGB(255, 120, 40),
		},
		Extra = function(folder, center)
			-- a red dwarf sun burning in the sky
			sun(folder, center + Vector3.new(-300, 220, -280), 60, Color3.fromRGB(255, 120, 50), Color3.fromRGB(255, 60, 30))
		end,
	},
	Nexus = {
		Nebulae = 3,
		Nebula = { Color3.fromRGB(255, 70, 220), Color3.fromRGB(60, 230, 255), Color3.fromRGB(140, 80, 255) },
		Galaxy = { Color3.fromRGB(255, 90, 230), Color3.fromRGB(80, 230, 255) },
		Islets = 7,
		Islet = {
			Top = Color3.fromRGB(25, 18, 45), TopMaterial = Enum.Material.Glass,
			Rock = Color3.fromRGB(35, 22, 60), RockDark = Color3.fromRGB(22, 14, 40), RockMaterial = Enum.Material.SmoothPlastic,
			Glow = Color3.fromRGB(60, 230, 255), Fall = Color3.fromRGB(255, 70, 220),
			Trunk = Color3.fromRGB(40, 25, 70), Leaves = Color3.fromRGB(255, 70, 220),
		},
		Extra = function(folder, center)
			-- a wireframe-looking planet with two neon rings
			planet(folder, center + Vector3.new(-330, 210, -200), 60, Color3.fromRGB(40, 20, 80), Color3.fromRGB(255, 80, 230),
				Color3.fromRGB(60, 230, 255), CFrame.Angles(math.rad(70), 0, math.rad(10)), Enum.Material.Glass)
		end,
	},
}
for _, info in ipairs(Config.RebirthIslands) do
	local theme = islandThemes[info.Key]
	if theme then
		theme.KeepLaneClear = true
		decorate(info.Key .. "Sky", info.Center, theme)
	end
end

root.Parent = workspace
