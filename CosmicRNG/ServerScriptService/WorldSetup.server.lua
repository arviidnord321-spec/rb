-- WorldSetup (Script in ServerScriptService)
-- Builds the space lighting and the floating island when the game starts.
-- Nothing to build by hand. Tweak colors/sizes below if you like.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))

local rand = Random.new(42) -- fixed seed = same island every time

local ISLAND_RADIUS = 70
local SPAWN_POSITION = Vector3.new(0, 3, 0)

-- Where the bigger builds go (rocks/crystals keep out of these spots)
local CORE_POSITION = Vector3.new(0, 0, -34) -- Cosmic Core altar
local LOUNGE_CENTER = Vector3.new(32, 0, 32) -- VIP Lounge
local LOUNGE_HALF = 12 -- lounge is 24 x 24 studs
local BOARD_POSITION = Vector3.new(-34, 0, 12) -- leaderboard

local function isReserved(position, margin)
	margin = margin or 0
	local flat = Vector3.new(position.X, 0, position.Z)
	if flat.Magnitude < 12 + margin then
		return true -- spawn pad
	end
	if (flat - CORE_POSITION).Magnitude < 13 + margin then
		return true
	end
	if (flat - BOARD_POSITION).Magnitude < 10 + margin then
		return true
	end
	local d = flat - LOUNGE_CENTER
	return math.abs(d.X) < LOUNGE_HALF + 3 + margin and math.abs(d.Z) < LOUNGE_HALF + 3 + margin
end

---------------------------------------------------------------------
-- LIGHTING: night sky, purple haze and bloom so neon glows
---------------------------------------------------------------------
for _, child in ipairs(Lighting:GetChildren()) do
	if child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("PostEffect") then
		child:Destroy()
	end
end

Lighting.ClockTime = 0
Lighting.GeographicLatitude = 20
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(70, 60, 110)
Lighting.OutdoorAmbient = Color3.fromRGB(110, 95, 170)
Lighting.EnvironmentDiffuseScale = 0.4
Lighting.EnvironmentSpecularScale = 0.6
Lighting.ExposureCompensation = 0.2

local sky = Instance.new("Sky")
sky.Name = "CosmicSky"
sky.StarCount = 5000
sky.CelestialBodiesShown = true
sky.MoonAngularSize = 20
sky.Parent = Lighting

local atmosphere = Instance.new("Atmosphere")
atmosphere.Name = "CosmicAtmosphere"
atmosphere.Density = 0.3
atmosphere.Offset = 0.1
atmosphere.Color = Color3.fromRGB(120, 90, 210)
atmosphere.Decay = Color3.fromRGB(50, 30, 110)
atmosphere.Glare = 0.3
atmosphere.Haze = 1.2
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Name = "CosmicBloom"
bloom.Intensity = 1
bloom.Size = 28
bloom.Threshold = 0.85
bloom.Parent = Lighting

local color = Instance.new("ColorCorrectionEffect")
color.Name = "CosmicColor"
color.Saturation = 0.15
color.Contrast = 0.08
color.TintColor = Color3.fromRGB(245, 240, 255)
color.Parent = Lighting

---------------------------------------------------------------------
-- REMOVE the template baseplate / spawn
---------------------------------------------------------------------
if Config.RemoveDefaultBaseplate then
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("SpawnLocation") and child.Name ~= "CosmicSpawn" then
			child:Destroy()
		end
	end
end

local old = workspace:FindFirstChild("CosmicIsland")
if old then
	old:Destroy()
end

local island = Instance.new("Model")
island.Name = "CosmicIsland"
-- Always send the whole island to every player (the animations need it)
island.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = props.Parent or island
	return p
end

-- A cylinder lying flat: Roblox cylinders point along X, so rotate them.
local FLAT = CFrame.Angles(0, 0, math.rad(90))
local function disc(name, radius, thickness, topY, color3, material, extra)
	local props = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(0, topY - thickness / 2, 0) * FLAT,
		Color = color3,
		Material = material,
	}
	for key, value in pairs(extra or {}) do
		props[key] = value
	end
	return part(props)
end

---------------------------------------------------------------------
-- ISLAND BODY
---------------------------------------------------------------------
local ROCK = Color3.fromRGB(48, 42, 66)
local ROCK_DARK = Color3.fromRGB(30, 26, 44)

disc("Ground", ISLAND_RADIUS, 4, 0, Color3.fromRGB(62, 54, 88), Enum.Material.Slate)
disc("EdgeGlow", ISLAND_RADIUS + 0.6, 0.6, -0.2, Color3.fromRGB(140, 100, 255), Enum.Material.Neon,
	{ CanCollide = false })

-- Stepped underside so it looks like a floating chunk of rock
local layers = {
	{ r = ISLAND_RADIUS - 6, y = -4, t = 6 },
	{ r = ISLAND_RADIUS - 18, y = -10, t = 7 },
	{ r = ISLAND_RADIUS - 32, y = -17, t = 8 },
	{ r = ISLAND_RADIUS - 46, y = -25, t = 9 },
	{ r = ISLAND_RADIUS - 58, y = -34, t = 10 },
}
for i, layer in ipairs(layers) do
	disc("Underside" .. i, layer.r, layer.t, layer.y, (i % 2 == 0) and ROCK_DARK or ROCK, Enum.Material.Slate,
		{ CanCollide = false })
end

-- Glowing veins running down the underside
for i = 1, 10 do
	local angle = (i / 10) * math.pi * 2 + rand:NextNumber(-0.2, 0.2)
	local r = ISLAND_RADIUS - 20 - rand:NextNumber(0, 15)
	part({
		Name = "Vein",
		Size = Vector3.new(0.6, rand:NextNumber(10, 22), 0.6),
		CFrame = CFrame.new(math.cos(angle) * r, -14, math.sin(angle) * r)
			* CFrame.Angles(rand:NextNumber(-0.3, 0.3), 0, rand:NextNumber(-0.3, 0.3)),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
end

---------------------------------------------------------------------
-- SPAWN PAD in the middle
---------------------------------------------------------------------
-- Invisible spawn block; the glowing discs below are what players see.
local spawn = Instance.new("SpawnLocation")
spawn.Name = "CosmicSpawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0 -- no forcefield bubble
spawn.Size = Vector3.new(10, 1, 10)
spawn.CFrame = CFrame.new(0, 1.55, 0)
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Parent = island
local decal = spawn:FindFirstChildOfClass("Decal")
if decal then
	decal:Destroy()
end

disc("SpawnRing", 8.6, 0.9, 0.95, Color3.fromRGB(180, 140, 255), Enum.Material.Neon, { CanCollide = false })
disc("SpawnTop", 8, 1, 1.05, Color3.fromRGB(90, 80, 130), Enum.Material.Marble)

---------------------------------------------------------------------
-- CRYSTALS around the island
---------------------------------------------------------------------
local crystalColors = {
	Color3.fromRGB(150, 110, 255),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(255, 110, 210),
	Color3.fromRGB(120, 255, 210),
}

local function crystalCluster(position, mainColor)
	local count = rand:NextInteger(3, 5)
	for i = 1, count do
		local height = (i == 1) and rand:NextNumber(9, 14) or rand:NextNumber(3.5, 8)
		local width = height * 0.22
		local offset = (i == 1) and Vector3.zero
			or Vector3.new(rand:NextNumber(-2.5, 2.5), 0, rand:NextNumber(-2.5, 2.5))
		local crystal = part({
			Name = "Crystal",
			Size = Vector3.new(width, height, width),
			CFrame = CFrame.new(position + offset + Vector3.new(0, height * 0.4, 0))
				* CFrame.Angles(rand:NextNumber(-0.35, 0.35), rand:NextNumber(0, math.pi), rand:NextNumber(-0.35, 0.35)),
			Color = mainColor,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
			CanCollide = (i == 1),
		})
		if i == 1 then
			local light = Instance.new("PointLight")
			light.Color = mainColor
			light.Range = 18
			light.Brightness = 1.5
			light.Parent = crystal

			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Texture = Config.Textures.Sparkle
			sparkle.Rate = 3
			sparkle.Lifetime = NumberRange.new(2, 4)
			sparkle.Speed = NumberRange.new(0.5, 1.5)
			sparkle.SpreadAngle = Vector2.new(180, 180)
			sparkle.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.5, 0.4),
				NumberSequenceKeypoint.new(1, 0),
			})
			sparkle.LightEmission = 1
			sparkle.LightInfluence = 0
			sparkle.Color = ColorSequence.new(mainColor)
			sparkle.Parent = crystal
		end
	end
end

for i = 1, 12 do
	local angle = (i / 12) * math.pi * 2 + rand:NextNumber(-0.15, 0.15)
	local r = ISLAND_RADIUS - rand:NextNumber(6, 14)
	local position = Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
	if not isReserved(position, 3) then
		crystalCluster(position, crystalColors[(i % #crystalColors) + 1])
	end
end

-- Small rocks scattered on the ground
for _ = 1, 30 do
	local angle = rand:NextNumber(0, math.pi * 2)
	local r = rand:NextNumber(14, ISLAND_RADIUS - 4)
	local size = rand:NextNumber(1, 3)
	local position = Vector3.new(math.cos(angle) * r, size * 0.3, math.sin(angle) * r)
	if not isReserved(position, 2) then
		part({
			Name = "Rock",
			Size = Vector3.new(size * 1.3, size, size),
			CFrame = CFrame.new(position)
				* CFrame.Angles(rand:NextNumber(0, 1), rand:NextNumber(0, 6), rand:NextNumber(0, 1)),
			Color = ROCK,
			Material = Enum.Material.Slate,
		})
	end
end

---------------------------------------------------------------------
-- ASTEROIDS floating around (just scenery)
---------------------------------------------------------------------
for _ = 1, 26 do
	local angle = rand:NextNumber(0, math.pi * 2)
	local r = rand:NextNumber(ISLAND_RADIUS + 25, ISLAND_RADIUS + 140)
	local size = rand:NextNumber(4, 16)
	local asteroid = part({
		Name = "Asteroid",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		CFrame = CFrame.new(math.cos(angle) * r, rand:NextNumber(-60, 70), math.sin(angle) * r),
		Color = (rand:NextNumber() < 0.5) and ROCK or ROCK_DARK,
		Material = Enum.Material.Slate,
		CanCollide = false,
	})
	if rand:NextNumber() < 0.35 then
		local glow = Instance.new("PointLight")
		glow.Color = crystalColors[rand:NextInteger(1, #crystalColors)]
		glow.Range = size * 1.5
		glow.Brightness = 1
		glow.Parent = asteroid
	end
end

---------------------------------------------------------------------
-- STARDUST drifting over the island
---------------------------------------------------------------------
local dustArea = part({
	Name = "StardustArea",
	Size = Vector3.new(ISLAND_RADIUS * 2, 30, ISLAND_RADIUS * 2),
	CFrame = CFrame.new(0, 15, 0),
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
})
local dust = Instance.new("ParticleEmitter")
dust.Texture = Config.Textures.Sparkle
dust.Rate = 40
dust.Lifetime = NumberRange.new(5, 9)
dust.Speed = NumberRange.new(0.2, 0.8)
dust.SpreadAngle = Vector2.new(180, 180)
dust.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0.35),
	NumberSequenceKeypoint.new(1, 0),
})
dust.LightEmission = 1
dust.LightInfluence = 0
dust.Color = ColorSequence.new(Color3.fromRGB(200, 180, 255), Color3.fromRGB(140, 220, 255))
dust.Parent = dustArea

---------------------------------------------------------------------
-- SAFETY NET: anyone who falls off is sent back to spawn
---------------------------------------------------------------------
local net = part({
	Name = "FallNet",
	Size = Vector3.new(2048, 4, 2048),
	CFrame = CFrame.new(0, -140, 0),
	Transparency = 1,
	CanCollide = false,
})
net.Touched:Connect(function(hit)
	local character = hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root then
		root.AssemblyLinearVelocity = Vector3.zero
		local vip = Config.VIPIsland
		local flat = Vector3.new(root.Position.X - vip.Center.X, 0, root.Position.Z - vip.Center.Z)
		local player = game:GetService("Players"):GetPlayerFromCharacter(character)
		if flat.Magnitude < vip.Radius * 3 and player and player:GetAttribute("Pass_VIP") then
			-- fell off Royal Island: back to its portal
			character:PivotTo(CFrame.new(vip.Center + Vector3.new(0, 4, -45)))
		else
			character:PivotTo(CFrame.new(SPAWN_POSITION))
		end
	end
end)

---------------------------------------------------------------------
-- Small helpers for the bigger builds
---------------------------------------------------------------------
local GOLD = Color3.fromRGB(255, 200, 70)

local function addLight(parentPart, color3, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color3
	light.Range = range
	light.Brightness = brightness
	light.Parent = parentPart
	return light
end

local function addSparkles(parentPart, color3, rate, size)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = Config.Textures.Sparkle
	sparkle.Rate = rate or 6
	sparkle.Lifetime = NumberRange.new(1.5, 3)
	sparkle.Speed = NumberRange.new(0.5, 2)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, size or 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkle.LightEmission = 1
	sparkle.LightInfluence = 0
	sparkle.Color = ColorSequence.new(color3)
	sparkle.Parent = parentPart
	return sparkle
end

-- A ring made of small neon pieces, lying flat, as its own Model
local function ringModel(name, center, radius, segments, thickness, color3, parent)
	local model = Instance.new("Model")
	model.Name = name
	local length = (2 * math.pi * radius / segments) * 1.05
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		part({
			Name = "Segment",
			Size = Vector3.new(thickness, thickness, length),
			CFrame = CFrame.lookAt(p, center) * CFrame.Angles(0, math.pi / 2, 0),
			Color = color3,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = model,
		})
	end
	model.WorldPivot = CFrame.new(center)
	model.Parent = parent
	return model
end

local function billboardText(parentPart, text, color3, studsOffset, size)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = size or UDim2.fromOffset(300, 50)
	gui.StudsOffset = studsOffset or Vector3.new(0, 4, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Parent = parentPart
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.Text = text
	textLabel.TextColor3 = color3
	textLabel.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Thickness = 2
	outline.Transparency = 0.3
	outline.Parent = textLabel
	return gui
end

---------------------------------------------------------------------
-- COSMIC CORE: altar with a glowing orb and 3 spinning rings
-- (the rings and orb are animated by the WorldFX LocalScript)
---------------------------------------------------------------------
local core = Instance.new("Model")
core.Name = "CosmicCore"
core.Parent = island

local function coreDisc(name, radius, thickness, topY, color3, material, collide)
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(CORE_POSITION + Vector3.new(0, topY - thickness / 2, 0)) * FLAT,
		Color = color3,
		Material = material,
		CanCollide = collide ~= false,
		Parent = core,
	})
end

coreDisc("BaseGlow", 10.4, 0.6, 0.5, Color3.fromRGB(140, 100, 255), Enum.Material.Neon, false)
coreDisc("Base", 10, 1.4, 1.4, Color3.fromRGB(70, 60, 100), Enum.Material.Marble)
coreDisc("Step", 7, 1, 2.4, Color3.fromRGB(85, 75, 120), Enum.Material.Marble)
coreDisc("StepGlow", 7.3, 0.4, 2.0, Color3.fromRGB(90, 200, 255), Enum.Material.Neon, false)
part({
	Name = "Pillar",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(5, 3.2, 3.2),
	CFrame = CFrame.new(CORE_POSITION + Vector3.new(0, 4.9, 0)) * FLAT,
	Color = Color3.fromRGB(60, 52, 90),
	Material = Enum.Material.Marble,
	Parent = core,
})
coreDisc("Cup", 2.6, 0.6, 7.7, Color3.fromRGB(180, 140, 255), Enum.Material.Neon, false)

local ORB_POSITION = CORE_POSITION + Vector3.new(0, 13, 0)
local orb = part({
	Name = "CoreOrb",
	Shape = Enum.PartType.Ball,
	Size = Vector3.one * 5,
	CFrame = CFrame.new(ORB_POSITION),
	Color = Color3.fromRGB(190, 150, 255),
	Material = Enum.Material.Neon,
	CanCollide = false,
	Parent = core,
})
addLight(orb, Color3.fromRGB(170, 130, 255), 35, 3)
addSparkles(orb, Color3.fromRGB(220, 200, 255), 14, 0.7)
part({
	Name = "CoreOrbShell",
	Shape = Enum.PartType.Ball,
	Size = Vector3.one * 7,
	CFrame = CFrame.new(ORB_POSITION),
	Color = Color3.fromRGB(120, 200, 255),
	Material = Enum.Material.ForceField,
	Transparency = 0.2,
	CanCollide = false,
	CastShadow = false,
	Parent = core,
})
billboardText(orb, "✦ COSMIC CORE ✦", Color3.fromRGB(220, 200, 255), Vector3.new(0, 9, 0))

ringModel("CoreRing1", ORB_POSITION, 5, 26, 0.3, Color3.fromRGB(150, 110, 255), core)
ringModel("CoreRing2", ORB_POSITION, 6.5, 32, 0.3, Color3.fromRGB(90, 200, 255), core)
ringModel("CoreRing3", ORB_POSITION, 8, 38, 0.3, Color3.fromRGB(255, 110, 210), core)

---------------------------------------------------------------------
-- LANTERNS around the plaza (the gems spin, see WorldFX)
---------------------------------------------------------------------
for i = 1, 10 do
	local a = (i / 10) * math.pi * 2 + 0.3
	local position = Vector3.new(math.cos(a) * 24, 0, math.sin(a) * 24)
	if not isReserved(position, 1) then
		part({
			Name = "LanternPost",
			Size = Vector3.new(0.8, 7, 0.8),
			CFrame = CFrame.new(position + Vector3.new(0, 3.5, 0)),
			Color = ROCK_DARK,
			Material = Enum.Material.Slate,
		})
		local gem = part({
			Name = "SpinGem",
			Size = Vector3.one * 1.4,
			CFrame = CFrame.new(position + Vector3.new(0, 8, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Color = crystalColors[(i % #crystalColors) + 1],
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		addLight(gem, gem.Color, 16, 1.4)
	end
end

---------------------------------------------------------------------
-- FLOATING CRYSTALS drifting above the island (bob + spin in WorldFX)
---------------------------------------------------------------------
for i = 1, 12 do
	local a = (i / 12) * math.pi * 2 + rand:NextNumber(-0.2, 0.2)
	local r = rand:NextNumber(30, 55)
	local height = rand:NextNumber(10, 20)
	local size = rand:NextNumber(1.6, 3)
	local floatPosition = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	if isReserved(floatPosition, 4) then
		continue -- keep the sky above the temple, core and board clear
	end
	local crystal = part({
		Name = "FloatingCrystal",
		Size = Vector3.new(size * 0.5, size * 1.6, size * 0.5),
		CFrame = CFrame.new(math.cos(a) * r, height, math.sin(a) * r)
			* CFrame.Angles(rand:NextNumber(-0.3, 0.3), rand:NextNumber(0, 6), rand:NextNumber(-0.3, 0.3)),
		Color = crystalColors[(i % #crystalColors) + 1],
		Material = Enum.Material.Neon,
		Transparency = 0.1,
		CanCollide = false,
	})
	addLight(crystal, crystal.Color, 12, 1)
end

---------------------------------------------------------------------
-- VIP LOUNGE (the door only lets VIPs through, see WorldFX)
---------------------------------------------------------------------
local lounge = Instance.new("Model")
lounge.Name = "VIPLounge"
lounge.Parent = island

local LX, LZ, H = LOUNGE_CENTER.X, LOUNGE_CENTER.Z, LOUNGE_HALF
local WALL_HEIGHT = 9
local DOOR_WIDTH = 6
local GLASS = Color3.fromRGB(255, 215, 120)

part({
	Name = "Floor",
	Size = Vector3.new(H * 2, 1, H * 2),
	CFrame = CFrame.new(LX, 0.5, LZ),
	Color = Color3.fromRGB(45, 36, 24),
	Material = Enum.Material.Marble,
	Parent = lounge,
})
part({
	Name = "FloorGlow",
	Size = Vector3.new(H * 2 + 0.8, 0.4, H * 2 + 0.8),
	CFrame = CFrame.new(LX, 0.2, LZ),
	Color = GOLD,
	Material = Enum.Material.Neon,
	CanCollide = false,
	Parent = lounge,
})

local function wall(name, center, size)
	part({
		Name = name,
		Size = size,
		CFrame = CFrame.new(center),
		Color = GLASS,
		Material = Enum.Material.Glass,
		Transparency = 0.55,
		Parent = lounge,
	})
	part({
		Name = name .. "Trim",
		Size = Vector3.new(size.X + 0.2, 0.4, size.Z + 0.2),
		CFrame = CFrame.new(center + Vector3.new(0, size.Y / 2, 0)),
		Color = GOLD,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = lounge,
	})
end

local wallY = 1 + WALL_HEIGHT / 2
-- north / south / east walls are solid
wall("WallNorth", Vector3.new(LX, wallY, LZ - H), Vector3.new(H * 2, WALL_HEIGHT, 0.6))
wall("WallSouth", Vector3.new(LX, wallY, LZ + H), Vector3.new(H * 2, WALL_HEIGHT, 0.6))
wall("WallEast", Vector3.new(LX + H, wallY, LZ), Vector3.new(0.6, WALL_HEIGHT, H * 2))
-- west wall faces the spawn and has the door gap in the middle
local sideLength = H - DOOR_WIDTH / 2
wall("WallWestA", Vector3.new(LX - H, wallY, LZ - H + sideLength / 2), Vector3.new(0.6, WALL_HEIGHT, sideLength))
wall("WallWestB", Vector3.new(LX - H, wallY, LZ + H - sideLength / 2), Vector3.new(0.6, WALL_HEIGHT, sideLength))

local door = part({
	Name = "VIPDoor",
	Size = Vector3.new(0.6, WALL_HEIGHT, DOOR_WIDTH),
	CFrame = CFrame.new(LX - H, wallY, LZ),
	Color = GOLD,
	Material = Enum.Material.ForceField,
	Transparency = 0.1,
	Parent = lounge,
})
addSparkles(door, GOLD, 8, 0.4)

local sign = part({
	Name = "VIPSign",
	Size = Vector3.new(10, 2.6, 0.4),
	CFrame = CFrame.lookAt(Vector3.new(LX - H - 0.4, 1 + WALL_HEIGHT + 1.8, LZ), Vector3.new(LX - H - 10, 1 + WALL_HEIGHT + 1.8, LZ)),
	Color = Color3.fromRGB(40, 30, 15),
	Material = Enum.Material.SmoothPlastic,
	CanCollide = false,
	Parent = lounge,
})
local signGui = Instance.new("SurfaceGui")
signGui.Face = Enum.NormalId.Front
signGui.LightInfluence = 0
signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
signGui.PixelsPerStud = 40
signGui.Parent = sign
local signText = Instance.new("TextLabel")
signText.BackgroundTransparency = 1
signText.Size = UDim2.fromScale(1, 1)
signText.Font = Enum.Font.FredokaOne
signText.TextScaled = true
signText.Text = "👑 VIP TEMPLE"
signText.TextColor3 = GOLD
signText.Parent = signGui

---------------------------------------------------------------------
-- VIP TEMPLE INTERIOR: red carpet leading to the Royal Portal
-- (portal, crown and chandelier are animated by WorldFX;
--  the VIPIsland script teleports VIPs who step into the portal)
---------------------------------------------------------------------
local MARBLE = Color3.fromRGB(235, 228, 215)
local RED = Color3.fromRGB(150, 30, 50)
local ROSE = Color3.fromRGB(255, 130, 190)

-- A vertical ring facing along portalCF's look direction, as its own Model
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
	model.Parent = parent
	return model
end

-- Corner pillars with gold caps
for _, corner in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
	local x, z = LX + corner[1] * H, LZ + corner[2] * H
	part({
		Name = "Pillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(12, 2.6, 2.6),
		CFrame = CFrame.new(x, 7, z) * FLAT,
		Color = MARBLE,
		Material = Enum.Material.Marble,
		Parent = lounge,
	})
	part({
		Name = "PillarBase",
		Size = Vector3.new(3.4, 1, 3.4),
		CFrame = CFrame.new(x, 1.5, z),
		Color = GOLD,
		Material = Enum.Material.Metal,
		Parent = lounge,
	})
	local cap = part({
		Name = "PillarCap",
		Size = Vector3.new(3.4, 0.8, 3.4),
		CFrame = CFrame.new(x, 13.4, z),
		Color = GOLD,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = lounge,
	})
	addLight(cap, GOLD, 14, 1)
end

-- Red carpet from the door to the portal steps
local carpetStart, carpetEnd = LX - H + 0.4, LX + H - 7
local carpetLength = carpetEnd - carpetStart
part({
	Name = "Carpet",
	Size = Vector3.new(carpetLength, 0.12, 4.4),
	CFrame = CFrame.new((carpetStart + carpetEnd) / 2, 1.06, LZ),
	Color = RED,
	Material = Enum.Material.Fabric,
	Parent = lounge,
})
for _, side in ipairs({ -1, 1 }) do
	part({
		Name = "CarpetTrim",
		Size = Vector3.new(carpetLength, 0.14, 0.35),
		CFrame = CFrame.new((carpetStart + carpetEnd) / 2, 1.07, LZ + side * 2.3),
		Color = GOLD,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = lounge,
	})
end

-- Steps up to the portal
part({ Name = "Step1", Size = Vector3.new(2, 0.4, 10), CFrame = CFrame.new(LX + H - 6, 1.2, LZ), Color = MARBLE, Material = Enum.Material.Marble, Parent = lounge })
part({ Name = "Step2", Size = Vector3.new(2, 0.8, 10.5), CFrame = CFrame.new(LX + H - 4.5, 1.4, LZ), Color = MARBLE, Material = Enum.Material.Marble, Parent = lounge })
part({ Name = "PortalDais", Size = Vector3.new(3.5, 1.2, 11), CFrame = CFrame.new(LX + H - 2, 1.6, LZ), Color = MARBLE, Material = Enum.Material.Marble, Parent = lounge })
part({ Name = "DaisTrim", Size = Vector3.new(3.7, 0.25, 11.2), CFrame = CFrame.new(LX + H - 2, 2.25, LZ), Color = GOLD, Material = Enum.Material.Neon, CanCollide = false, Parent = lounge })

-- THE ROYAL PORTAL (faces the door)
local PORTAL_CENTER = Vector3.new(LX + H - 2.6, 7.4, LZ)
local portalCF = CFrame.lookAt(PORTAL_CENTER, PORTAL_CENTER - Vector3.new(1, 0, 0))
portalRing("VIPPortalRing", portalCF, 4.6, 30, 0.55, GOLD, lounge)
portalRing("VIPPortalRingOuter", portalCF, 5.4, 36, 0.25, ROSE, lounge)
local swirl = part({
	Name = "VIPPortalSwirl",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.3, 8.8, 8.8),
	CFrame = portalCF * CFrame.Angles(0, math.pi / 2, 0),
	Color = Color3.fromRGB(255, 160, 220),
	Material = Enum.Material.ForceField,
	CanCollide = false,
	Parent = lounge,
})
part({
	Name = "VIPPortalCore",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.2, 7.8, 7.8),
	CFrame = portalCF * CFrame.Angles(0, math.pi / 2, 0),
	Color = Color3.fromRGB(255, 205, 130),
	Material = Enum.Material.Neon,
	Transparency = 0.55,
	CanCollide = false,
	Parent = lounge,
})
addLight(swirl, Color3.fromRGB(255, 170, 210), 24, 2.5)
local portalSparkles = addSparkles(swirl, GOLD, 25, 0.5)
portalSparkles.Speed = NumberRange.new(1, 3)
part({
	Name = "VIPPortalTrigger",
	Size = Vector3.new(8, 8, 2), -- wide + tall, thin in the walking direction
	CFrame = portalCF,
	Transparency = 1,
	CanCollide = false,
	Parent = lounge,
})

-- Sign above the portal
local portalSign = part({
	Name = "PortalSign",
	Size = Vector3.new(0.3, 1.8, 9),
	CFrame = CFrame.new(LX + H - 2.6, 13.6, LZ),
	Color = Color3.fromRGB(40, 25, 15),
	Material = Enum.Material.SmoothPlastic,
	CanCollide = false,
	Parent = lounge,
})
local portalSignGui = Instance.new("SurfaceGui")
portalSignGui.Face = Enum.NormalId.Left -- faces the door (-X)
portalSignGui.LightInfluence = 0
portalSignGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
portalSignGui.PixelsPerStud = 40
portalSignGui.Parent = portalSign
local portalSignText = Instance.new("TextLabel")
portalSignText.BackgroundTransparency = 1
portalSignText.Size = UDim2.fromScale(1, 1)
portalSignText.Font = Enum.Font.FredokaOne
portalSignText.TextScaled = true
portalSignText.Text = "✦ ROYAL ISLAND • x" .. Config.VIPIsland.LuckMultiplier .. " LUCK ✦"
portalSignText.TextColor3 = GOLD
portalSignText.Parent = portalSignGui

-- Statues: pedestals with floating crystals beside the portal
for _, side in ipairs({ -1, 1 }) do
	local px, pz = LX + H - 5, LZ + side * 7
	part({
		Name = "Pedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 2.4, 2.4),
		CFrame = CFrame.new(px, 2.5, pz) * FLAT,
		Color = MARBLE,
		Material = Enum.Material.Marble,
		Parent = lounge,
	})
	part({
		Name = "PedestalCap",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 2.8, 2.8),
		CFrame = CFrame.new(px, 4.1, pz) * FLAT,
		Color = GOLD,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = lounge,
	})
	local gem = part({
		Name = "FloatingCrystal", -- WorldFX makes it bob and spin
		Size = Vector3.new(1.2, 3, 1.2),
		CFrame = CFrame.new(px, 6.6, pz),
		Color = (side == 1) and ROSE or GOLD,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	addLight(gem, gem.Color, 12, 1.5)
end

-- Royal benches along the side walls
for _, side in ipairs({ -1, 1 }) do
	for _, offset in ipairs({ -6, 0 }) do
		local seat = Instance.new("Seat")
		seat.Name = "VIPSeat"
		seat.Anchored = true
		seat.Size = Vector3.new(4, 1, 2)
		seat.CFrame = CFrame.lookAt(Vector3.new(LX + offset, 1.6, LZ + side * (H - 1.6)), Vector3.new(LX + offset, 1.6, LZ))
		seat.Color = RED
		seat.Material = Enum.Material.Fabric
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.Parent = lounge
		part({
			Name = "BenchBack",
			Size = Vector3.new(4, 2.2, 0.4),
			CFrame = seat.CFrame * CFrame.new(0, 1.2, 0.9),
			Color = GOLD,
			Material = Enum.Material.Metal,
			Parent = lounge,
		})
	end
end

-- Banners with crowns on the side walls
for _, side in ipairs({ -1, 1 }) do
	for _, offset in ipairs({ -3, 3 }) do
		local position = Vector3.new(LX + offset * 2, 6.5, LZ + side * (H - 0.45))
		local bannerPart = part({
			Name = "Banner",
			Size = Vector3.new(2.6, 5, 0.12),
			CFrame = CFrame.lookAt(position, Vector3.new(position.X, position.Y, LZ)),
			Color = RED,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Parent = lounge,
		})
		local bannerGui = Instance.new("SurfaceGui")
		bannerGui.Face = Enum.NormalId.Front
		bannerGui.LightInfluence = 0
		bannerGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		bannerGui.PixelsPerStud = 30
		bannerGui.Parent = bannerPart
		local crownText = Instance.new("TextLabel")
		crownText.BackgroundTransparency = 1
		crownText.Size = UDim2.fromScale(1, 0.6)
		crownText.Position = UDim2.fromScale(0, 0.2)
		crownText.TextScaled = true
		crownText.Text = "👑"
		crownText.Parent = bannerGui
		part({
			Name = "BannerRod",
			Size = Vector3.new(3, 0.25, 0.25),
			CFrame = bannerPart.CFrame * CFrame.new(0, 2.6, 0),
			Color = GOLD,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = lounge,
		})
	end
end

-- Chandelier (spins in WorldFX)
local chandelier = ringModel("VIPChandelier", Vector3.new(LX - 3, 11, LZ), 3, 22, 0.3, GOLD, lounge)
local chandelierCore = part({
	Name = "ChandelierCore",
	Shape = Enum.PartType.Ball,
	Size = Vector3.one * 1.2,
	CFrame = CFrame.new(LX - 3, 11, LZ),
	Color = Color3.fromRGB(255, 230, 170),
	Material = Enum.Material.Neon,
	CanCollide = false,
	Parent = chandelier,
})
addLight(chandelierCore, Color3.fromRGB(255, 210, 150), 26, 2)
for i = 1, 6 do
	local a = (i / 6) * math.pi * 2
	part({
		Name = "Drop",
		Size = Vector3.new(0.4, 1.2, 0.4),
		CFrame = CFrame.new(LX - 3 + math.cos(a) * 3, 10.2, LZ + math.sin(a) * 3) * CFrame.Angles(0, a, math.rad(45)),
		Color = (i % 2 == 0) and ROSE or GOLD,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = chandelier,
	})
end
chandelier.WorldPivot = CFrame.new(LX - 3, 11, LZ)

-- Floating crown above the temple (spins + bobs in WorldFX)
local CROWN_CENTER = Vector3.new(LX, 17, LZ)
local crown = ringModel("VIPCrown", CROWN_CENTER, 4, 30, 0.6, GOLD, lounge)
for i = 1, 6 do
	local a = (i / 6) * math.pi * 2
	part({
		Name = "Spike",
		Size = Vector3.new(1, 2.6, 1),
		CFrame = CFrame.new(CROWN_CENTER + Vector3.new(math.cos(a) * 4, 1.4, math.sin(a) * 4)) * CFrame.Angles(0, -a, 0),
		Color = GOLD,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = crown,
	})
	part({
		Name = "Jewel",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.8,
		CFrame = CFrame.new(CROWN_CENTER + Vector3.new(math.cos(a) * 4, 3, math.sin(a) * 4)),
		Color = (i % 2 == 0) and ROSE or Color3.fromRGB(90, 230, 210),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = crown,
	})
end
crown.WorldPivot = CFrame.new(CROWN_CENTER)
local crownLight = part({ Name = "CrownLight", Size = Vector3.one * 0.2, Transparency = 1, CanCollide = false, CFrame = CFrame.new(CROWN_CENTER), Parent = crown })
addLight(crownLight, GOLD, 30, 2)
addSparkles(crownLight, GOLD, 10, 0.6)

-- Torches either side of the door (outside)
for _, side in ipairs({ -1, 1 }) do
	local tx, tz = LX - H - 1.2, LZ + side * 4.2
	part({ Name = "TorchPost", Size = Vector3.new(0.6, 5, 0.6), CFrame = CFrame.new(tx, 3.5, tz), Color = GOLD, Material = Enum.Material.Metal })
	local flame = part({
		Name = "TorchFlame",
		Size = Vector3.new(0.9, 0.9, 0.9),
		CFrame = CFrame.new(tx, 6.4, tz),
		Color = Color3.fromRGB(255, 170, 80),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = Config.Textures.Fire
	fire.Rate = 20
	fire.Lifetime = NumberRange.new(0.4, 0.8)
	fire.Speed = NumberRange.new(1, 2.5)
	fire.Acceleration = Vector3.new(0, 4, 0)
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	fire.LightEmission = 1
	fire.LightInfluence = 0
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 90, 40))
	fire.Parent = flame
	addLight(flame, Color3.fromRGB(255, 170, 90), 16, 1.6)
end


---------------------------------------------------------------------
-- LEADERBOARD BOARD (filled in by the Leaderboard script)
---------------------------------------------------------------------
local BOARD_CENTER = BOARD_POSITION + Vector3.new(0, 9, 0)
local boardCFrame = CFrame.lookAt(BOARD_CENTER, Vector3.new(0, BOARD_CENTER.Y, 0))
local board = part({
	Name = "LeaderboardBoard",
	Size = Vector3.new(14, 16, 0.8),
	CFrame = boardCFrame,
	Color = Color3.fromRGB(16, 12, 30),
	Material = Enum.Material.SmoothPlastic,
})
-- glowing frame around the board
for _, edge in ipairs({
	{ Vector3.new(0, 8.2, 0), Vector3.new(14.8, 0.4, 1) },
	{ Vector3.new(0, -8.2, 0), Vector3.new(14.8, 0.4, 1) },
	{ Vector3.new(7.2, 0, 0), Vector3.new(0.4, 16.8, 1) },
	{ Vector3.new(-7.2, 0, 0), Vector3.new(0.4, 16.8, 1) },
}) do
	part({
		Name = "BoardTrim",
		Size = edge[2],
		CFrame = boardCFrame * CFrame.new(edge[1]),
		Color = Color3.fromRGB(150, 110, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
end

local boardGui = Instance.new("SurfaceGui")
boardGui.Name = "Gui"
boardGui.Face = Enum.NormalId.Front
boardGui.LightInfluence = 0
boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
boardGui.PixelsPerStud = 50
boardGui.Parent = board

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromScale(1, 1)
panel.BackgroundTransparency = 1
panel.Parent = boardGui

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(20, 16)
title.Size = UDim2.new(1, -40, 0, 70)
title.Font = Enum.Font.FredokaOne
title.TextScaled = true
title.Text = "🏆 TOP ROLLERS"
title.TextColor3 = GOLD
title.Parent = panel

local boardList = Instance.new("Frame")
boardList.Name = "List"
boardList.BackgroundTransparency = 1
boardList.Position = UDim2.fromOffset(20, 100)
boardList.Size = UDim2.new(1, -40, 1, -160)
boardList.Parent = panel
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = boardList

local boardStatus = Instance.new("TextLabel")
boardStatus.Name = "Status"
boardStatus.BackgroundTransparency = 1
boardStatus.AnchorPoint = Vector2.new(0, 1)
boardStatus.Position = UDim2.new(0, 20, 1, -14)
boardStatus.Size = UDim2.new(1, -40, 0, 34)
boardStatus.Font = Enum.Font.GothamBold
boardStatus.TextScaled = true
boardStatus.Text = "Loading..."
boardStatus.TextColor3 = Color3.fromRGB(150, 140, 190)
boardStatus.Parent = panel

---------------------------------------------------------------------
-- SKY: a giant ringed planet and a moon (ring spins in WorldFX)
---------------------------------------------------------------------
local old2 = workspace:FindFirstChild("CosmicSky")
if old2 then
	old2:Destroy()
end
local skyModel = Instance.new("Model")
skyModel.Name = "CosmicSky"
skyModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

local PLANET_POSITION = Vector3.new(-320, 170, -480)
part({
	Name = "Planet",
	Shape = Enum.PartType.Ball,
	Size = Vector3.one * 210,
	CFrame = CFrame.new(PLANET_POSITION),
	Color = Color3.fromRGB(110, 70, 190),
	Material = Enum.Material.SmoothPlastic,
	CanCollide = false,
	CastShadow = false,
	Parent = skyModel,
})
part({
	Name = "PlanetGlow",
	Shape = Enum.PartType.Ball,
	Size = Vector3.one * 222,
	CFrame = CFrame.new(PLANET_POSITION),
	Color = Color3.fromRGB(170, 120, 255),
	Material = Enum.Material.ForceField,
	Transparency = 0.3,
	CanCollide = false,
	CastShadow = false,
	Parent = skyModel,
})
local planetRing = ringModel("PlanetRing", PLANET_POSITION, 175, 90, 3, Color3.fromRGB(200, 170, 255), skyModel)
local outerRing = ringModel("PlanetRingOuter", PLANET_POSITION, 195, 100, 2, Color3.fromRGB(120, 200, 255), skyModel)
local tilt = CFrame.new(PLANET_POSITION) * CFrame.Angles(math.rad(22), 0, math.rad(12))
planetRing:PivotTo(tilt)
outerRing:PivotTo(tilt)

part({
	Name = "Moon",
	Shape = Enum.PartType.Ball,
	Size = Vector3.one * 70,
	CFrame = CFrame.new(380, 210, -260),
	Color = Color3.fromRGB(150, 230, 240),
	Material = Enum.Material.Slate,
	CanCollide = false,
	CastShadow = false,
	Parent = skyModel,
})
part({
	Name = "MoonGlow",
	Shape = Enum.PartType.Ball,
	Size = Vector3.one * 76,
	CFrame = CFrame.new(380, 210, -260),
	Color = Color3.fromRGB(120, 230, 255),
	Material = Enum.Material.ForceField,
	Transparency = 0.4,
	CanCollide = false,
	CastShadow = false,
	Parent = skyModel,
})
skyModel.Parent = workspace

island.Parent = workspace
