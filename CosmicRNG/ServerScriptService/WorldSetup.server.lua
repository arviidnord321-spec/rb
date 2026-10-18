-- WorldSetup (Script in ServerScriptService)
-- Builds the space lighting and the floating island when the game starts.
-- Nothing to build by hand. Tweak colors/sizes below if you like.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))

local rand = Random.new(42) -- fixed seed = same island every time

local ISLAND_RADIUS = Config.MainIslandRadius
local SPAWN_POSITION = Vector3.new(0, 3, 0)

-- Where the bigger builds go (rocks/crystals keep out of these spots)
local P = Config.Places
local CORE_POSITION = P.Core
local BOARD_POSITION = P.Board
local PLAZA_POSITION = P.PortalPlaza

local RESERVED = {
	{ Vector3.zero, 12 }, -- spawn pad
	{ P.Core, 13 },
	{ P.Board, 10 },
	{ P.PortalPlaza, 13 },
	{ P.Pond, 11 },
	{ P.StarstepStart, 8 },
	{ P.VoidTowerStart, 8 },
	{ P.RebirthGate, 14 },
	{ P.Hatchery, 20 },
}

local function isReserved(position, margin)
	margin = margin or 0
	local flat = Vector3.new(position.X, 0, position.Z)
	for _, zone in ipairs(RESERVED) do
		if (flat - zone[1]).Magnitude < zone[2] + margin then
			return true
		end
	end
	-- the bridge to Duel Island runs south from the spawn
	return math.abs(flat.X) < 7 + margin and flat.Z > 40
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
	{ r = ISLAND_RADIUS * 0.92, y = -4, t = 6 },
	{ r = ISLAND_RADIUS * 0.76, y = -11, t = 8 },
	{ r = ISLAND_RADIUS * 0.58, y = -20, t = 9 },
	{ r = ISLAND_RADIUS * 0.4, y = -30, t = 10 },
	{ r = ISLAND_RADIUS * 0.22, y = -42, t = 12 },
}
for i, layer in ipairs(layers) do
	disc("Underside" .. i, layer.r, layer.t, layer.y, (i % 2 == 0) and ROCK_DARK or ROCK, Enum.Material.Slate,
		{ CanCollide = false })
end

-- Glowing veins running down the underside
for i = 1, 16 do
	local angle = (i / 16) * math.pi * 2 + rand:NextNumber(-0.2, 0.2)
	local r = ISLAND_RADIUS * 0.6 - rand:NextNumber(0, 20)
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

for i = 1, 20 do
	local angle = (i / 20) * math.pi * 2 + rand:NextNumber(-0.15, 0.15)
	local r = ISLAND_RADIUS - rand:NextNumber(6, 14)
	local position = Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
	if not isReserved(position, 3) then
		crystalCluster(position, crystalColors[(i % #crystalColors) + 1])
	end
end

-- Small rocks scattered on the ground
for _ = 1, 70 do
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
-- SAFETY NET: anyone who falls off is sent back
---------------------------------------------------------------------
-- Checked by position (more reliable than touch events): anyone who drops
-- below the islands is put back where they belong.
local Players = game:GetService("Players")
local FALL_LIMIT = -60

local function rescue(character, player)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.AssemblyLinearVelocity = Vector3.zero
	local checkpoint = player:GetAttribute("Checkpoint")
	local lucky = Config.LuckyIsland
	local flat = Vector3.new(root.Position.X - lucky.Center.X, 0, root.Position.Z - lucky.Center.Z)
	if typeof(checkpoint) == "CFrame" then
		character:PivotTo(checkpoint) -- fell off a parkour course
	elseif flat.Magnitude < lucky.Radius * 3 then
		character:PivotTo(CFrame.new(lucky.Center + Vector3.new(0, 4, -45))) -- fell off Lucky Isle
	else
		-- fell off a rebirth island?
		for _, info in ipairs(Config.RebirthIslands) do
			local offset = Vector3.new(root.Position.X - info.Center.X, 0, root.Position.Z - info.Center.Z)
			if offset.Magnitude < info.Radius * 3 then
				character:PivotTo(CFrame.lookAt(info.Center + Vector3.new(0, 4, -(info.Radius - 26)), info.Center + Vector3.new(0, 4, 0)))
				return
			end
		end
		character:PivotTo(CFrame.new(SPAWN_POSITION))
	end
end

task.spawn(function()
	while true do
		task.wait(0.25)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			-- duelists are handled by DuelService (it keeps them in the arena)
			if root and root.Position.Y < FALL_LIMIT and not character:GetAttribute("InDuel") then
				rescue(character, player)
			end
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
for i = 1, 26 do
	-- an inner ring of 10 lanterns and an outer ring of 16
	local inner = i <= 10
	local a = inner and ((i / 10) * math.pi * 2 + 0.3) or (((i - 10) / 16) * math.pi * 2 + 0.1)
	local radius = inner and 24 or 76
	local position = Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
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
for i = 1, 22 do
	local a = (i / 22) * math.pi * 2 + rand:NextNumber(-0.2, 0.2)
	local r = rand:NextNumber(30, 95)
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
-- PORTAL PLAZA: the portal to Lucky Isle
-- (the LuckyIsland script sends anyone who walks in; WorldFX spins it)
---------------------------------------------------------------------
local MARBLE = Color3.fromRGB(235, 228, 215)
local ROSE = Color3.fromRGB(255, 130, 190)
local TEAL = Color3.fromRGB(90, 230, 210)
local PATH_COLOR = Color3.fromRGB(88, 80, 120)

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

local plaza = Instance.new("Model")
plaza.Name = "PortalPlaza"
plaza.Parent = island

local PX, PZ = PLAZA_POSITION.X, PLAZA_POSITION.Z
local function plazaDisc(name, radius, thickness, topY, color3, material, collide)
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(PX, topY - thickness / 2, PZ) * FLAT,
		Color = color3,
		Material = material,
		CanCollide = collide ~= false,
		Parent = plaza,
	})
end
plazaDisc("PlazaGlow", 11.6, 0.4, 0.3, ROSE, Enum.Material.Neon, false)
plazaDisc("PlazaBase", 11, 0.8, 0.6, MARBLE, Enum.Material.Marble)
plazaDisc("PlazaRim", 11.25, 0.3, 0.55, GOLD, Enum.Material.Neon, false) -- sits just under the marble: only the edge shows
plazaDisc("PlazaInner", 7, 0.6, 1.2, Color3.fromRGB(70, 60, 100), Enum.Material.Marble)
plazaDisc("PlazaInnerGlow", 7.25, 0.3, 1.15, TEAL, Enum.Material.Neon, false) -- edge glow under the inner step

-- The portal stands on the plaza and faces the spawn
local PORTAL_CENTER = Vector3.new(PX, 1.2 + 5.8, PZ)
local portalCF = CFrame.lookAt(PORTAL_CENTER, Vector3.new(0, PORTAL_CENTER.Y, 0))
portalRing("LuckyPortalRing", portalCF, 4.8, 32, 0.6, GOLD, plaza)
portalRing("LuckyPortalRingOuter", portalCF, 5.6, 38, 0.28, ROSE, plaza)
local swirl = part({
	Name = "LuckyPortalSwirl",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.3, 9.2, 9.2),
	CFrame = portalCF * CFrame.Angles(0, math.pi / 2, 0),
	Color = Color3.fromRGB(255, 160, 220),
	Material = Enum.Material.ForceField,
	CanCollide = false,
	CanQuery = false,
	Parent = plaza,
})
part({
	Name = "LuckyPortalCore",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.2, 8.2, 8.2),
	CFrame = portalCF * CFrame.Angles(0, math.pi / 2, 0),
	Color = Color3.fromRGB(255, 205, 130),
	Material = Enum.Material.Neon,
	Transparency = 0.5,
	CanCollide = false,
	CanQuery = false,
	Parent = plaza,
})
addLight(swirl, Color3.fromRGB(255, 170, 210), 28, 3)
local portalSparkles = addSparkles(swirl, GOLD, 30, 0.5)
portalSparkles.Speed = NumberRange.new(1, 3)

-- The zone the LuckyIsland script watches (anyone inside it is sent)
part({
	Name = "LuckyPortalZone",
	Size = Vector3.new(9, 10, 3),
	CFrame = portalCF,
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Parent = plaza,
})

-- Pillars either side + a sign on top
for _, side in ipairs({ -1, 1 }) do
	local base = (portalCF * CFrame.new(side * 6.9, 0, 0)).Position
	part({
		Name = "PortalPillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(12, 2, 2),
		CFrame = CFrame.new(base.X, 1.2 + 6, base.Z) * FLAT,
		Color = MARBLE,
		Material = Enum.Material.Marble,
		Parent = plaza,
	})
	local cap = part({
		Name = "PortalPillarGem",
		Size = Vector3.one * 1.6,
		CFrame = CFrame.new(base.X, 14.4, base.Z) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color = (side == 1) and ROSE or TEAL,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = plaza,
	})
	addLight(cap, cap.Color, 16, 1.5)
end
local portalSign = part({
	Name = "PortalSign",
	Size = Vector3.new(11, 1.9, 0.3),
	CFrame = portalCF * CFrame.new(0, 7.6, 0),
	Color = Color3.fromRGB(30, 22, 50),
	Material = Enum.Material.SmoothPlastic,
	CanCollide = false,
	Parent = plaza,
})
local portalSignGui = Instance.new("SurfaceGui")
portalSignGui.Face = Enum.NormalId.Front
portalSignGui.LightInfluence = 0
portalSignGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
portalSignGui.PixelsPerStud = 40
portalSignGui.Parent = portalSign
local portalSignText = Instance.new("TextLabel")
portalSignText.BackgroundTransparency = 1
portalSignText.Size = UDim2.fromScale(1, 1)
portalSignText.Font = Enum.Font.FredokaOne
portalSignText.TextScaled = true
portalSignText.Text = "🌀 LUCKY ISLE • ALL LUCK x" .. Config.LuckyIsland.LuckMultiplier
portalSignText.TextColor3 = GOLD
portalSignText.Parent = portalSignGui

-- Gems orbiting the portal (spun by WorldFX)
local gems = Instance.new("Model")
gems.Name = "LuckyPortalGems"
for i = 1, 8 do
	local a = (i / 8) * math.pi * 2
	part({
		Name = "Gem",
		Size = Vector3.one * 0.9,
		CFrame = portalCF * CFrame.new(math.cos(a) * 6.6, math.sin(a) * 6.6, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color = (i % 2 == 0) and ROSE or TEAL,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		Parent = gems,
	})
end
gems.WorldPivot = portalCF
gems.Parent = plaza

---------------------------------------------------------------------
-- PATHS: stone tiles from the spawn to every place
---------------------------------------------------------------------
local paths = Instance.new("Model")
paths.Name = "Paths"
paths.Parent = island

local function path(from, to, width)
	local flatFrom = Vector3.new(from.X, 0, from.Z)
	local flatTo = Vector3.new(to.X, 0, to.Z)
	local direction = flatTo - flatFrom
	local length = direction.Magnitude
	local steps = math.floor(length / 3.2)
	for i = 0, steps - 1 do
		local center = flatFrom + direction * ((i + 0.5) / steps)
		part({
			Name = "PathTile",
			Size = Vector3.new(width + rand:NextNumber(-0.4, 0.4), 0.3, 2.9),
			CFrame = CFrame.lookAt(center + Vector3.new(0, 0.1, 0), flatTo + Vector3.new(0, 0.1, 0))
				* CFrame.Angles(0, rand:NextNumber(-0.04, 0.04), 0),
			Color = PATH_COLOR:Lerp(Color3.fromRGB(120, 110, 160), rand:NextNumber(0, 0.4)),
			Material = Enum.Material.Slate,
			Parent = paths,
		})
		-- little glowing studs along the edges every few tiles
		if i % 3 == 1 then
			for _, side in ipairs({ -1, 1 }) do
				local edge = CFrame.lookAt(center, flatTo) * CFrame.new(side * (width / 2 + 0.6), 0.35, 0)
				part({
					Name = "PathLight",
					Shape = Enum.PartType.Ball,
					Size = Vector3.one * 0.5,
					CFrame = edge,
					Color = Color3.fromRGB(170, 140, 255),
					Material = Enum.Material.Neon,
					CanCollide = false,
					Parent = paths,
				})
			end
		end
	end
end

local function toward(target, stopShort)
	local flat = Vector3.new(target.X, 0, target.Z)
	return flat - flat.Unit * stopShort
end
local PATH_START = 8.6 -- edge of the spawn pad
path(toward(CORE_POSITION, -PATH_START + CORE_POSITION.Magnitude), toward(CORE_POSITION, 10.5), 4)
path(toward(PLAZA_POSITION, -PATH_START + PLAZA_POSITION.Magnitude), toward(PLAZA_POSITION, 11.5), 4)
path(toward(BOARD_POSITION, -PATH_START + BOARD_POSITION.Magnitude), toward(BOARD_POSITION, 4), 3.4)
path(toward(P.StarstepStart, -PATH_START + P.StarstepStart.Magnitude), toward(P.StarstepStart, 4), 3.4)
path(toward(P.VoidTowerStart, -PATH_START + P.VoidTowerStart.Magnitude), toward(P.VoidTowerStart, 4), 3.4)
path(Vector3.new(0, 0, PATH_START), Vector3.new(0, 0, ISLAND_RADIUS - 4), 5) -- to the Duel Island bridge
path(toward(P.Hatchery, -PATH_START + P.Hatchery.Magnitude), toward(P.Hatchery, 18), 4)
path(toward(P.Pond, -PATH_START + P.Pond.Magnitude), toward(P.Pond, 9), 3)
path(toward(P.RebirthGate, -PATH_START + P.RebirthGate.Magnitude), toward(P.RebirthGate, 12.5), 4)

---------------------------------------------------------------------
-- SIGNPOST at the spawn pointing to everything
---------------------------------------------------------------------
local SIGN_POST = Vector3.new(-6.5, 0, 6.5)
part({
	Name = "SignPost",
	Size = Vector3.new(0.6, 9, 0.6),
	CFrame = CFrame.new(SIGN_POST + Vector3.new(0, 5.5, 0)),
	Color = Color3.fromRGB(60, 50, 85),
	Material = Enum.Material.Wood,
})
local signTargets = {
	{ "⚔ DUELS", P.DuelIsland, Color3.fromRGB(255, 110, 110) },
	{ "🌀 LUCKY ISLE", PLAZA_POSITION, Color3.fromRGB(255, 200, 90) },
	{ "✦ COSMIC CORE", CORE_POSITION, Color3.fromRGB(190, 150, 255) },
	{ "🏃 STARSTEP OBBY", P.StarstepStart, Color3.fromRGB(110, 230, 150) },
	{ "🗼 VOID TOWER", P.VoidTowerStart, Color3.fromRGB(120, 200, 255) },
	{ "🏆 TOP ROLLERS", BOARD_POSITION, Color3.fromRGB(255, 220, 120) },
	{ "🥚 PET EGGS", P.Hatchery, Color3.fromRGB(255, 170, 120) },
	{ "⭐ REBIRTH GATE", P.RebirthGate, Color3.fromRGB(140, 220, 255) },
}
for i, target in ipairs(signTargets) do
	local height = 9.6 - i * 0.98
	local postTop = SIGN_POST + Vector3.new(0, height, 0)
	local dest = Vector3.new(target[2].X, height, target[2].Z)
	local look = CFrame.lookAt(postTop, dest)
	local board = part({
		Name = "SignBoard",
		Size = Vector3.new(0.25, 0.95, 5.2),
		CFrame = look * CFrame.new(0, 0, -2.9),
		Color = Color3.fromRGB(40, 32, 62),
		Material = Enum.Material.Wood,
		CanCollide = false,
	})
	for _, face in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = board
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.Text = target[1]
		text.TextColor3 = target[3]
		text.Parent = gui
	end
end

---------------------------------------------------------------------
-- BENCHES around the spawn
---------------------------------------------------------------------
for _, angle in ipairs({ 0.55, 2.35, 3.75, 5.3 }) do
	local position = Vector3.new(math.cos(angle) * 15, 1.1, math.sin(angle) * 15)
	local seat = Instance.new("Seat")
	seat.Name = "Bench"
	seat.Anchored = true
	seat.Size = Vector3.new(5, 0.6, 1.8)
	seat.CFrame = CFrame.lookAt(position, Vector3.new(0, 1.1, 0))
	seat.Color = Color3.fromRGB(80, 65, 120)
	seat.Material = Enum.Material.Wood
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.Parent = island
	part({ Name = "BenchBack", Size = Vector3.new(5, 1.6, 0.3), CFrame = seat.CFrame * CFrame.new(0, 1, 0.8), Color = Color3.fromRGB(60, 50, 95), Material = Enum.Material.Wood })
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "BenchLeg", Size = Vector3.new(0.3, 0.9, 1.6), CFrame = seat.CFrame * CFrame.new(side * 2.2, -0.65, 0), Color = ROCK_DARK, Material = Enum.Material.Slate })
	end
end

---------------------------------------------------------------------
-- GLOW MUSHROOMS: little alien plants all over the island
---------------------------------------------------------------------
local shroomColors = { Color3.fromRGB(90, 230, 210), Color3.fromRGB(255, 120, 200), Color3.fromRGB(160, 120, 255), Color3.fromRGB(120, 200, 255) }
local function shroomCluster(position, color3)
	for i = 1, rand:NextInteger(3, 6) do
		local offset = (i == 1) and Vector3.zero or Vector3.new(rand:NextNumber(-2.2, 2.2), 0, rand:NextNumber(-2.2, 2.2))
		local height = (i == 1) and rand:NextNumber(1.8, 3) or rand:NextNumber(0.7, 1.8)
		local base = position + offset
		part({
			Name = "ShroomStem",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, height * 0.28, height * 0.28),
			CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * FLAT,
			Color = Color3.fromRGB(220, 210, 235),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		local cap = part({
			Name = "ShroomCap",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * height * 0.9,
			CFrame = CFrame.new(base + Vector3.new(0, height, 0)),
			Color = color3,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		if i == 1 then
			addLight(cap, color3, 10, 1)
		end
	end
end
local placedShrooms = 0
for _ = 1, 140 do
	if placedShrooms >= 34 then
		break
	end
	local a = rand:NextNumber(0, math.pi * 2)
	local r = rand:NextNumber(16, ISLAND_RADIUS - 6)
	local position = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	if not isReserved(position, 3) then
		shroomCluster(position, shroomColors[rand:NextInteger(1, #shroomColors)])
		placedShrooms += 1
	end
end

---------------------------------------------------------------------
-- RUINS: broken marble columns from an old observatory
---------------------------------------------------------------------
local function ruins(center)
	for i = 1, 5 do
		local a = (i / 5) * math.pi * 2
		local position = center + Vector3.new(math.cos(a) * 6, 0, math.sin(a) * 6)
		local height = rand:NextNumber(2.5, 8)
		part({
			Name = "BrokenColumn",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, 2, 2),
			CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(rand:NextNumber(-0.08, 0.08), 0, rand:NextNumber(-0.08, 0.08)) * FLAT,
			Color = Color3.fromRGB(200, 195, 215),
			Material = Enum.Material.Marble,
		})
		part({
			Name = "ColumnBase",
			Size = Vector3.new(2.8, 0.6, 2.8),
			CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)),
			Color = Color3.fromRGB(170, 165, 190),
			Material = Enum.Material.Marble,
		})
		-- glowing vine wrapped around some columns
		if i % 2 == 0 then
			part({
				Name = "Vine",
				Size = Vector3.new(0.25, height * 0.9, 0.25),
				CFrame = CFrame.new(position + Vector3.new(1.05, height * 0.45, 0)) * CFrame.Angles(0, 0, 0.15),
				Color = Color3.fromRGB(110, 255, 170),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
		end
	end
	-- a fallen column lying across the middle
	part({
		Name = "FallenColumn",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(7, 1.8, 1.8),
		CFrame = CFrame.new(center + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, rand:NextNumber(0, 3), 0),
		Color = Color3.fromRGB(190, 185, 205),
		Material = Enum.Material.Marble,
	})
	local relic = part({
		Name = "Relic",
		Size = Vector3.one * 1.2,
		CFrame = CFrame.new(center + Vector3.new(0, 3.2, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color = Color3.fromRGB(255, 220, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	relic.Name = "SpinGem" -- WorldFX spins these
	addLight(relic, relic.Color, 14, 1.2)
end
for _, spot in ipairs({ Vector3.new(-80, 0, -62), Vector3.new(88, 0, 22), Vector3.new(-30, 0, 82), Vector3.new(30, 0, -92) }) do
	if not isReserved(spot, -4) then
		ruins(spot)
	end
end

---------------------------------------------------------------------
-- COSMIC POOL: a glowing pond with floating lily lights
---------------------------------------------------------------------
local POND = P.Pond
local function pondDisc(name, radius, thickness, topY, color3, material, extra)
	local props = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(POND.X, topY - thickness / 2, POND.Z) * FLAT,
		Color = color3,
		Material = material,
	}
	for key, value in pairs(extra or {}) do
		props[key] = value
	end
	return part(props)
end
pondDisc("PoolRim", 8.6, 0.8, 0.6, Color3.fromRGB(170, 160, 200), Enum.Material.Marble)
pondDisc("PoolGlow", 7.6, 0.2, 0.62, Color3.fromRGB(80, 160, 255), Enum.Material.Neon)
local water = pondDisc("PoolWater", 7.6, 0.3, 0.9, Color3.fromRGB(110, 90, 255), Enum.Material.Glass, { Transparency = 0.35 })
local mist = addSparkles(water, Color3.fromRGB(160, 200, 255), 10, 0.4)
mist.Speed = NumberRange.new(0.2, 0.6)
for i = 1, 6 do
	local a = (i / 6) * math.pi * 2 + rand:NextNumber(-0.3, 0.3)
	local r = rand:NextNumber(2, 5.5)
	local lily = part({
		Name = "LilyLight",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, 1.6, 1.6),
		CFrame = CFrame.new(POND.X + math.cos(a) * r, 0.98, POND.Z + math.sin(a) * r) * FLAT,
		Color = (i % 2 == 0) and ROSE or TEAL,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	if i % 3 == 0 then
		addLight(lily, lily.Color, 8, 0.8)
	end
end
part({
	Name = "PoolCrystal",
	Size = Vector3.new(1.4, 6, 1.4),
	CFrame = CFrame.new(POND.X, 4, POND.Z) * CFrame.Angles(0.1, 0.4, -0.08),
	Color = Color3.fromRGB(150, 200, 255),
	Material = Enum.Material.Neon,
	Transparency = 0.15,
	CanCollide = false,
})

---------------------------------------------------------------------
-- BRIDGE to Duel Island (south). The island itself is built by DuelService.
---------------------------------------------------------------------
local bridge = Instance.new("Model")
bridge.Name = "DuelBridge"
bridge.Parent = island
local BRIDGE_START, BRIDGE_END = ISLAND_RADIUS - 6, P.DuelIsland.Z - P.DuelIslandRadius + 4
local bridgeLength = BRIDGE_END - BRIDGE_START
local bridgeMid = (BRIDGE_START + BRIDGE_END) / 2
part({
	Name = "BridgeDeck",
	Size = Vector3.new(8, 1, bridgeLength),
	CFrame = CFrame.new(0, -0.5, bridgeMid),
	Color = Color3.fromRGB(70, 62, 100),
	Material = Enum.Material.Slate,
	Parent = bridge,
})
part({
	Name = "BridgeUnder",
	Size = Vector3.new(6, 1.5, bridgeLength),
	CFrame = CFrame.new(0, -1.6, bridgeMid),
	Color = ROCK_DARK,
	Material = Enum.Material.Slate,
	Parent = bridge,
})
for _, side in ipairs({ -1, 1 }) do
	part({
		Name = "Railing",
		Size = Vector3.new(0.4, 0.4, bridgeLength),
		CFrame = CFrame.new(side * 3.8, 2.4, bridgeMid),
		Color = Color3.fromRGB(255, 110, 110),
		Material = Enum.Material.Neon,
		Parent = bridge,
	})
	part({
		Name = "RailingWall",
		Size = Vector3.new(0.3, 2.4, bridgeLength),
		CFrame = CFrame.new(side * 3.8, 1.2, bridgeMid),
		Color = Color3.fromRGB(255, 150, 150),
		Material = Enum.Material.Glass,
		Transparency = 0.7,
		Parent = bridge,
	})
	for z = BRIDGE_START + 3, BRIDGE_END - 2, 8 do
		local lamp = part({
			Name = "BridgeLamp",
			Size = Vector3.new(0.7, 0.7, 0.7),
			CFrame = CFrame.new(side * 3.8, 3, z) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Color = Color3.fromRGB(255, 150, 120),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = bridge,
		})
		addLight(lamp, lamp.Color, 10, 1)
	end
end
-- gate at the start of the bridge
for _, side in ipairs({ -1, 1 }) do
	part({
		Name = "GatePillar",
		Size = Vector3.new(1.4, 10, 1.4),
		CFrame = CFrame.new(side * 4.8, 5, BRIDGE_START + 1),
		Color = Color3.fromRGB(60, 40, 70),
		Material = Enum.Material.Slate,
		Parent = bridge,
	})
end
local gateTop = part({
	Name = "GateTop",
	Size = Vector3.new(11, 1.6, 1.2),
	CFrame = CFrame.lookAt(Vector3.new(0, 10.6, BRIDGE_START + 1), Vector3.new(0, 10.6, 0)),
	Color = Color3.fromRGB(40, 20, 40),
	Material = Enum.Material.SmoothPlastic,
	Parent = bridge,
})
local gateGui = Instance.new("SurfaceGui")
gateGui.Face = Enum.NormalId.Front
gateGui.LightInfluence = 0
gateGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gateGui.PixelsPerStud = 40
gateGui.Parent = gateTop
local gateText = Instance.new("TextLabel")
gateText.BackgroundTransparency = 1
gateText.Size = UDim2.fromScale(1, 1)
gateText.Font = Enum.Font.FredokaOne
gateText.TextScaled = true
gateText.Text = "⚔ DUEL ISLAND ⚔"
gateText.TextColor3 = Color3.fromRGB(255, 120, 120)
gateText.Parent = gateGui

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
