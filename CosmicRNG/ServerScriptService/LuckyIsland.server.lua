-- LuckyIsland (Script in ServerScriptService)
-- Builds LUCKY ISLE and runs its portals:
--   * walk into the portal on the main island (or press E) to come here
--   * standing on the island gives extra luck (Config.LuckyIsland.LuckMultiplier)
--   * the return portal takes you back
--   * if Config.LuckyIsland.RequireVIP is true, only VIP pass owners may come
-- Same vibe as the main island, but white marble + gold, rose and teal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))

local LUCKY = Config.LuckyIsland
local CENTER = LUCKY.Center
local RADIUS = LUCKY.Radius
local rand = Random.new(7)

local MARBLE = Color3.fromRGB(238, 232, 220)
local MARBLE_DARK = Color3.fromRGB(205, 196, 182)
local GOLD = Color3.fromRGB(255, 200, 70)
local ROSE = Color3.fromRGB(255, 130, 190)
local TEAL = Color3.fromRGB(80, 230, 205)
local WINE = Color3.fromRGB(95, 35, 70)
local WINE_DARK = Color3.fromRGB(60, 20, 45)
local FLAT = CFrame.Angles(0, 0, math.rad(90))

-- where you arrive (next to the return portal, looking at the island)
local ARRIVAL = CFrame.lookAt(CENTER + Vector3.new(0, 4, -46), CENTER + Vector3.new(0, 4, 0))

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("CosmicRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "CosmicRemotes"
	remotes.Parent = ReplicatedStorage
end
local PortalFXRemote = remotes:FindFirstChild("PortalFX")
if not PortalFXRemote then
	PortalFXRemote = Instance.new("RemoteEvent")
	PortalFXRemote.Name = "PortalFX"
	PortalFXRemote.Parent = remotes
end

---------------------------------------------------------------------
-- Build helpers
---------------------------------------------------------------------
local old = workspace:FindFirstChild("LuckyIsland")
if old then
	old:Destroy()
end
local island = Instance.new("Model")
island.Name = "LuckyIsland"
island.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		if key ~= "Parent" then
			p[key] = value
		end
	end
	p.Parent = props.Parent or island
	return p
end

local function at(offset)
	return CENTER + offset
end

local function disc(name, radius, thickness, topY, color3, material, extra)
	local props = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(at(Vector3.new(0, topY - thickness / 2, 0))) * FLAT,
		Color = color3,
		Material = material,
	}
	for key, value in pairs(extra or {}) do
		props[key] = value
	end
	return part(props)
end

local function column(position, height, radius, parent)
	part({
		Name = "Column",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * FLAT,
		Color = MARBLE,
		Material = Enum.Material.Marble,
		Parent = parent,
	})
	part({
		Name = "ColumnBase",
		Size = Vector3.new(radius * 2.6, 0.8, radius * 2.6),
		CFrame = CFrame.new(position + Vector3.new(0, 0.4, 0)),
		Color = GOLD,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	part({
		Name = "ColumnCap",
		Size = Vector3.new(radius * 2.8, 0.8, radius * 2.8),
		CFrame = CFrame.new(position + Vector3.new(0, height + 0.2, 0)),
		Color = GOLD,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})
end

local function addLight(target, color3, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color3
	light.Range = range
	light.Brightness = brightness
	light.Parent = target
	return light
end

local function addSparkles(target, color3, rate, size)
	local e = Instance.new("ParticleEmitter")
	e.Texture = Config.Textures.Sparkle
	e.Rate = rate
	e.Lifetime = NumberRange.new(1.5, 3)
	e.Speed = NumberRange.new(0.5, 2)
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

-- flat ring of neon pieces as its own Model (WorldFX spins some of these)
local function ringModel(name, center, radius, segments, thickness, color3, parent, material)
	local model = Instance.new("Model")
	model.Name = name
	local length = (2 * math.pi * radius / segments) * 1.06
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		part({
			Name = "Segment",
			Size = Vector3.new(thickness, thickness, length),
			CFrame = CFrame.lookAt(p, center) * CFrame.Angles(0, math.pi / 2, 0),
			Color = color3,
			Material = material or Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = model,
		})
	end
	model.WorldPivot = CFrame.new(center)
	model.Parent = parent or island
	return model
end

-- vertical ring facing portalCF's look direction
local function portalRing(name, portalCF, radius, segments, thickness, color3, parent)
	local model = Instance.new("Model")
	model.Name = name
	local length = (2 * math.pi * radius / segments) * 1.08
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local radial = Vector3.new(math.cos(a), math.sin(a), 0)
		part({
			Name = "Segment",
			Size = Vector3.new(thickness, thickness, length),
			CFrame = portalCF * CFrame.fromMatrix(radial * radius, radial, Vector3.new(0, 0, 1)),
			Color = color3,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = model,
		})
	end
	model.WorldPivot = portalCF
	model.Parent = parent or island
	return model
end

local function crystalCluster(position, color3)
	local count = rand:NextInteger(3, 5)
	for i = 1, count do
		local height = (i == 1) and rand:NextNumber(8, 12) or rand:NextNumber(3, 7)
		local width = height * 0.22
		local offset = (i == 1) and Vector3.zero or Vector3.new(rand:NextNumber(-2.5, 2.5), 0, rand:NextNumber(-2.5, 2.5))
		local crystal = part({
			Name = "Crystal",
			Size = Vector3.new(width, height, width),
			CFrame = CFrame.new(position + offset + Vector3.new(0, height * 0.4, 0))
				* CFrame.Angles(rand:NextNumber(-0.35, 0.35), rand:NextNumber(0, math.pi), rand:NextNumber(-0.35, 0.35)),
			Color = color3,
			Material = Enum.Material.Neon,
			Transparency = 0.1,
			CanCollide = (i == 1),
		})
		if i == 1 then
			addLight(crystal, color3, 18, 1.4)
			addSparkles(crystal, color3, 3, 0.4)
		end
	end
end

local function billboard(target, text, color3, offset, size)
	local gui = Instance.new("BillboardGui")
	gui.Size = size or UDim2.fromOffset(420, 70)
	gui.StudsOffset = offset or Vector3.new(0, 6, 0)
	gui.MaxDistance = 220
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color3
	label.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Thickness = 2.5
	outline.Transparency = 0.2
	outline.Parent = label
end

---------------------------------------------------------------------
-- GROUND: white marble top, wine-red rock underneath, teal veins
---------------------------------------------------------------------
disc("Ground", RADIUS, 4, 0, MARBLE, Enum.Material.Marble)
disc("EdgeGlow", RADIUS + 0.7, 0.7, -0.2, ROSE, Enum.Material.Neon, { CanCollide = false })
-- (the gold trim is a thin ring along the edge, built once ringModel exists below)

local layers = {
	{ r = RADIUS - 6, y = -4, t = 6 },
	{ r = RADIUS - 18, y = -10, t = 7 },
	{ r = RADIUS - 32, y = -17, t = 8 },
	{ r = RADIUS - 46, y = -25, t = 9 },
	{ r = RADIUS - 60, y = -34, t = 10 },
}
for i, layer in ipairs(layers) do
	disc("Underside" .. i, layer.r, layer.t, layer.y, (i % 2 == 0) and WINE_DARK or WINE, Enum.Material.Slate, { CanCollide = false })
end
for i = 1, 12 do
	local a = (i / 12) * math.pi * 2
	local r = RADIUS - 22 - rand:NextNumber(0, 14)
	part({
		Name = "Vein",
		Size = Vector3.new(0.6, rand:NextNumber(10, 22), 0.6),
		CFrame = CFrame.new(at(Vector3.new(math.cos(a) * r, -14, math.sin(a) * r)))
			* CFrame.Angles(rand:NextNumber(-0.3, 0.3), 0, rand:NextNumber(-0.3, 0.3)),
		Color = TEAL,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
end

ringModel("EdgeTrim", at(Vector3.new(0, 0.2, 0)), RADIUS - 0.4, 120, 0.5, GOLD)

-- Mosaic floor: rings of rose and teal set into the marble
disc("Plaza", 24, 0.3, 0.15, MARBLE_DARK, Enum.Material.Marble)
ringModel("MosaicOuter", at(Vector3.new(0, 0.32, 0)), 23.5, 64, 0.25, GOLD)
ringModel("MosaicRose", at(Vector3.new(0, 0.32, 0)), 19, 56, 0.25, ROSE)
ringModel("MosaicTeal", at(Vector3.new(0, 0.32, 0)), 15, 48, 0.25, TEAL)
for i = 1, 8 do -- star lines between the rings
	local a = (i / 8) * math.pi * 2
	local p = at(Vector3.new(math.cos(a) * 19.2, 0.32, math.sin(a) * 19.2))
	part({
		Name = "MosaicLine",
		Size = Vector3.new(0.25, 0.25, 8.5),
		CFrame = CFrame.lookAt(p, at(Vector3.new(0, 0.32, 0))),
		Color = GOLD,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
end

---------------------------------------------------------------------
-- GOLDEN CORE: royal altar with a sun orb and 3 spinning rings
---------------------------------------------------------------------
local core = Instance.new("Model")
core.Name = "LuckyCore"
core.Parent = island
local function coreDisc(name, radius, thickness, topY, color3, material, collide)
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(at(Vector3.new(0, topY - thickness / 2, 0))) * FLAT,
		Color = color3,
		Material = material,
		CanCollide = collide ~= false,
		Parent = core,
	})
end
coreDisc("Base", 8, 1.4, 1.6, MARBLE, Enum.Material.Marble)
coreDisc("BaseTrim", 8.3, 0.4, 1.0, GOLD, Enum.Material.Neon, false)
coreDisc("Step", 5.5, 1, 2.6, MARBLE_DARK, Enum.Material.Marble)
coreDisc("StepTrim", 5.8, 0.3, 2.2, ROSE, Enum.Material.Neon, false)
part({
	Name = "Pillar",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(5, 2.8, 2.8),
	CFrame = CFrame.new(at(Vector3.new(0, 5.1, 0))) * FLAT,
	Color = GOLD,
	Material = Enum.Material.Metal,
	Parent = core,
})
local ORB = at(Vector3.new(0, 13, 0))
local orb = part({
	Name = "LuckyOrb",
	Shape = Enum.PartType.Ball,
	Size = Vector3.one * 5.5,
	CFrame = CFrame.new(ORB),
	Color = Color3.fromRGB(255, 215, 120),
	Material = Enum.Material.Neon,
	CanCollide = false,
	Parent = core,
})
addLight(orb, Color3.fromRGB(255, 200, 120), 40, 3)
addSparkles(orb, Color3.fromRGB(255, 230, 170), 16, 0.7)
ringModel("LuckyRing1", ORB, 5.2, 28, 0.35, GOLD, core)
ringModel("LuckyRing2", ORB, 6.8, 34, 0.3, ROSE, core)
ringModel("LuckyRing3", ORB, 8.4, 40, 0.3, TEAL, core)
billboard(orb, "🍀 LUCKY ISLE • ALL YOUR LUCK x" .. LUCKY.LuckMultiplier, GOLD, Vector3.new(0, 10, 0))

---------------------------------------------------------------------
-- COLONNADE: a circle of marble columns with a golden ring on top
---------------------------------------------------------------------
local colonnade = Instance.new("Model")
colonnade.Name = "Colonnade"
colonnade.Parent = island
local COLUMN_RADIUS = 31
local COLUMN_HEIGHT = 14
for i = 1, 16 do
	local a = (i / 16) * math.pi * 2 + math.pi / 16
	-- leave a wide gap facing the return portal (north, -Z)
	if math.abs(math.sin(a) + 1) > 0.08 then
		column(at(Vector3.new(math.cos(a) * COLUMN_RADIUS, 0, math.sin(a) * COLUMN_RADIUS)), COLUMN_HEIGHT, 1.2, colonnade)
	end
end
ringModel("ColonnadeTop", at(Vector3.new(0, COLUMN_HEIGHT + 0.9, 0)), COLUMN_RADIUS, 72, 1.2, MARBLE, colonnade, Enum.Material.Marble)
ringModel("ColonnadeGlow", at(Vector3.new(0, COLUMN_HEIGHT + 1.6, 0)), COLUMN_RADIUS, 72, 0.3, GOLD, colonnade)

---------------------------------------------------------------------
-- GRAND ARCHES at the four diagonals
---------------------------------------------------------------------
for i = 1, 4 do
	local a = (i / 4) * math.pi * 2 + math.pi / 4
	local base = at(Vector3.new(math.cos(a) * 55, 0, math.sin(a) * 55))
	local archCF = CFrame.lookAt(base, at(Vector3.zero) + Vector3.new(0, 0, 0))
	local arch = Instance.new("Model")
	arch.Name = "Arch"
	arch.Parent = island
	for _, side in ipairs({ -1, 1 }) do
		local pillarPos = (archCF * CFrame.new(side * 6, 0, 0)).Position
		column(pillarPos, 12, 1.4, arch)
	end
	-- the curved top: a half ring of gold pieces
	local segments = 14
	for s = 0, segments do
		local t = s / segments * math.pi
		local localPos = Vector3.new(math.cos(t) * 6, 12.6 + math.sin(t) * 4, 0)
		local nextT = (s + 1) / segments * math.pi
		local nextPos = Vector3.new(math.cos(nextT) * 6, 12.6 + math.sin(nextT) * 4, 0)
		if s < segments then
			local mid = (localPos + nextPos) / 2
			local worldMid = (archCF * CFrame.new(mid)).Position
			local worldNext = (archCF * CFrame.new(nextPos)).Position
			part({
				Name = "ArchPiece",
				Size = Vector3.new(1.4, 1.4, (nextPos - localPos).Magnitude + 0.3),
				CFrame = CFrame.lookAt(worldMid, worldNext),
				Color = GOLD,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = arch,
			})
		end
	end
	local gem = part({
		Name = "ArchGem",
		Size = Vector3.one * 1.8,
		CFrame = (archCF * CFrame.new(0, 17.4, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color = (i % 2 == 0) and ROSE or TEAL,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = arch,
	})
	addLight(gem, gem.Color, 20, 1.5)
end

---------------------------------------------------------------------
-- DOMED PAVILIONS east and west
---------------------------------------------------------------------
for _, side in ipairs({ -1, 1 }) do
	local center = at(Vector3.new(side * 52, 0, 8))
	local pavilion = Instance.new("Model")
	pavilion.Name = "Pavilion"
	pavilion.Parent = island
	part({
		Name = "Floor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 16, 16),
		CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0)) * FLAT,
		Color = MARBLE_DARK,
		Material = Enum.Material.Marble,
		Parent = pavilion,
	})
	for c = 1, 6 do
		local a = (c / 6) * math.pi * 2
		column(center + Vector3.new(math.cos(a) * 6.5, 1, math.sin(a) * 6.5), 9, 0.7, pavilion)
	end
	part({
		Name = "Roof",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 16, 16),
		CFrame = CFrame.new(center + Vector3.new(0, 11, 0)) * FLAT,
		Color = MARBLE,
		Material = Enum.Material.Marble,
		Parent = pavilion,
	})
	part({
		Name = "Dome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 13,
		CFrame = CFrame.new(center + Vector3.new(0, 11.5, 0)),
		Color = (side == 1) and ROSE or TEAL,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Parent = pavilion,
	})
	part({
		Name = "Spire",
		Size = Vector3.new(0.6, 5, 0.6),
		CFrame = CFrame.new(center + Vector3.new(0, 20, 0)),
		Color = GOLD,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = pavilion,
	})
	local light = part({
		Name = "PavilionLight",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.6,
		CFrame = CFrame.new(center + Vector3.new(0, 8, 0)),
		Color = Color3.fromRGB(255, 230, 180),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = pavilion,
	})
	addLight(light, Color3.fromRGB(255, 210, 160), 22, 2)
	for _, z in ipairs({ -2.5, 2.5 }) do
		local seat = Instance.new("Seat")
		seat.Name = "LuckySeat"
		seat.Anchored = true
		seat.Size = Vector3.new(2.5, 0.8, 2.5)
		seat.CFrame = CFrame.lookAt(center + Vector3.new(0, 1.4, z), center + Vector3.new(-side * 10, 1.4, z))
		seat.Color = Color3.fromRGB(150, 30, 50)
		seat.Material = Enum.Material.Fabric
		seat.Parent = pavilion
	end
end

---------------------------------------------------------------------
-- LIGHT WATERFALLS pouring off the edge
---------------------------------------------------------------------
for i = 1, 8 do
	local a = (i / 8) * math.pi * 2 + math.pi / 8
	local edge = at(Vector3.new(math.cos(a) * (RADIUS + 0.6), 0, math.sin(a) * (RADIUS + 0.6)))
	local color3 = (i % 2 == 0) and ROSE or TEAL
	local fall = part({
		Name = "LightFall",
		Size = Vector3.new(6, 46, 0.3),
		CFrame = CFrame.lookAt(edge - Vector3.new(0, 23, 0), at(Vector3.new(0, -23, 0))),
		Color = color3,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
	})
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = Config.Textures.Sparkle
	mist.Rate = 12
	mist.Lifetime = NumberRange.new(1.5, 2.5)
	mist.Speed = NumberRange.new(0, 1)
	mist.Acceleration = Vector3.new(0, -8, 0)
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	mist.LightEmission = 1
	mist.LightInfluence = 0
	mist.Color = ColorSequence.new(color3, Color3.new(1, 1, 1))
	mist.Parent = fall
end

---------------------------------------------------------------------
-- DECORATION: crystals, floating lanterns, golden dust
---------------------------------------------------------------------
local crystalSpots = { 0.4, 1.2, 2.0, 2.7, 3.6, 4.4, 5.2, 5.9 }
for i, a in ipairs(crystalSpots) do
	local r = RADIUS - rand:NextNumber(7, 12)
	local position = at(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
	-- keep clear of the return portal path (north) and pavilions
	local nearPortal = math.abs(position.X - CENTER.X) < 12 and position.Z < CENTER.Z - 30
	if not nearPortal then
		crystalCluster(position, (i % 3 == 0) and GOLD or (i % 3 == 1) and ROSE or TEAL)
	end
end

local lanternColors = { Color3.fromRGB(255, 210, 140), ROSE, TEAL, GOLD }
for i = 1, 18 do
	local a = rand:NextNumber(0, math.pi * 2)
	local r = rand:NextNumber(14, RADIUS - 5)
	local lantern = part({
		Name = "LuckyLantern", -- WorldFX makes these bob
		Size = Vector3.new(1.1, 1.5, 1.1),
		CFrame = CFrame.new(at(Vector3.new(math.cos(a) * r, rand:NextNumber(9, 24), math.sin(a) * r))),
		Color = lanternColors[(i % #lanternColors) + 1],
		Material = Enum.Material.Neon,
		Transparency = 0.1,
		CanCollide = false,
	})
	addLight(lantern, lantern.Color, 10, 1)
end

local dust = part({
	Name = "GoldenDust",
	Size = Vector3.new(RADIUS * 2, 30, RADIUS * 2),
	CFrame = CFrame.new(at(Vector3.new(0, 15, 0))),
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
})
local dustEmitter = addSparkles(dust, GOLD, 45, 0.35)
dustEmitter.Lifetime = NumberRange.new(5, 9)
dustEmitter.Speed = NumberRange.new(0.2, 0.8)
dustEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 150), ROSE)

---------------------------------------------------------------------
-- RETURN PORTAL (north edge, facing the island)
---------------------------------------------------------------------
local RETURN_CENTER = at(Vector3.new(0, 6.4, -56))
local returnCF = CFrame.lookAt(RETURN_CENTER, RETURN_CENTER + Vector3.new(0, 0, 1))
part({
	Name = "ReturnDais",
	Size = Vector3.new(12, 1, 5),
	CFrame = CFrame.new(at(Vector3.new(0, 0.5, -56))),
	Color = MARBLE_DARK,
	Material = Enum.Material.Marble,
})
for _, side in ipairs({ -1, 1 }) do
	column(at(Vector3.new(side * 6.6, 0, -56)), 12, 1, island)
end
portalRing("ReturnPortalRing", returnCF, 4.6, 30, 0.55, TEAL)
portalRing("ReturnPortalRingOuter", returnCF, 5.4, 36, 0.25, GOLD)
local returnSwirl = part({
	Name = "ReturnPortalSwirl",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.3, 8.8, 8.8),
	CFrame = returnCF * CFrame.Angles(0, math.pi / 2, 0),
	Color = Color3.fromRGB(140, 120, 255),
	Material = Enum.Material.ForceField,
	CanCollide = false,
})
part({
	Name = "ReturnPortalCore",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.2, 7.8, 7.8),
	CFrame = returnCF * CFrame.Angles(0, math.pi / 2, 0),
	Color = Color3.fromRGB(150, 110, 255),
	Material = Enum.Material.Neon,
	Transparency = 0.55,
	CanCollide = false,
})
addLight(returnSwirl, Color3.fromRGB(150, 130, 255), 24, 2.5)
addSparkles(returnSwirl, Color3.fromRGB(190, 170, 255), 20, 0.5)
billboard(returnSwirl, "⟲ BACK TO COSMIC ISLAND", Color3.fromRGB(200, 190, 255), Vector3.new(0, 7, 0), UDim2.fromOffset(360, 50))
local returnZone = part({
	Name = "ReturnPortalZone",
	Size = Vector3.new(9, 10, 3),
	CFrame = returnCF,
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
})

island.Parent = workspace

---------------------------------------------------------------------
-- PORTAL LOGIC
-- Checked by position every 0.1s (works even when touch events don't),
-- plus a "Press E" prompt on each portal.
---------------------------------------------------------------------
local mainIsland = workspace:WaitForChild("CosmicIsland")
local plaza = mainIsland:WaitForChild("PortalPlaza")
local mainZone = plaza:WaitForChild("LuckyPortalZone")

-- where you come out: a few studs in front of each portal, facing away from it
local function exitFrom(zone)
	local spot = (zone.CFrame * CFrame.new(0, 0, -7)).Position
	spot = Vector3.new(spot.X, zone.Position.Y - 3, spot.Z)
	return CFrame.lookAt(spot, spot + zone.CFrame.LookVector * Vector3.new(1, 0, 1))
end
local MAIN_EXIT = exitFrom(mainZone)

local busy = {} -- [player] = true while teleporting

local function allowed(player)
	return not LUCKY.RequireVIP or player:GetAttribute("Pass_VIP") == true
end

local function teleport(player, destination)
	if busy[player] then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or character:GetAttribute("InDuel") then
		return
	end
	busy[player] = true
	PortalFXRemote:FireClient(player, "Out")
	task.wait(0.35)
	if character.Parent then
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(destination)
	end
	PortalFXRemote:FireClient(player, "In")
	task.wait(1.5) -- don't bounce straight back through the other portal
	busy[player] = nil
end

local deniedAt = {}
local function enterMainPortal(player)
	if allowed(player) then
		task.spawn(teleport, player, ARRIVAL)
	elseif os.clock() - (deniedAt[player] or 0) > 3 then
		deniedAt[player] = os.clock()
		PortalFXRemote:FireClient(player, "Denied")
	end
end
local function enterReturnPortal(player)
	task.spawn(teleport, player, MAIN_EXIT)
end

local function inZone(zone, position)
	local localPos = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

local function addPrompt(zone, actionText, objectText, onTriggered)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = zone
	prompt.Triggered:Connect(onTriggered)
end
addPrompt(mainZone, "Travel", "Lucky Isle (ALL luck x" .. LUCKY.LuckMultiplier .. ")", enterMainPortal)
addPrompt(returnZone, "Travel", "Back to Cosmic Island", enterReturnPortal)

-- Who is standing on Lucky Isle? (gives the luck bonus)
local function onIsland(position)
	local offset = position - CENTER
	local flat = Vector3.new(offset.X, 0, offset.Z)
	return flat.Magnitude < RADIUS + 8 and offset.Y > -20 and offset.Y < 80
end

task.spawn(function()
	local loops = 0
	while true do
		task.wait(0.1)
		loops += 1
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and not busy[player] then
				if inZone(mainZone, root.Position) then
					enterMainPortal(player)
				elseif inZone(returnZone, root.Position) then
					enterReturnPortal(player)
				end
			end
			if loops % 5 == 0 then
				local here = root ~= nil and onIsland(root.Position)
				if here and not allowed(player) and not busy[player] then
					task.spawn(teleport, player, MAIN_EXIT) -- not allowed here
					here = false
				end
				if player:GetAttribute("OnLuckyIsland") ~= here then
					player:SetAttribute("OnLuckyIsland", here)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
	deniedAt[player] = nil
end)
