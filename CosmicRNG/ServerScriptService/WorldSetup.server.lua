-- WorldSetup (Script in ServerScriptService)
-- Builds the space lighting and the floating island when the game starts.
-- Nothing to build by hand. Tweak colors/sizes below if you like.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))

local rand = Random.new(42) -- fixed seed = same island every time

local ISLAND_RADIUS = 70
local SPAWN_POSITION = Vector3.new(0, 3, 0)

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
	crystalCluster(Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r), crystalColors[(i % #crystalColors) + 1])
end

-- Small rocks scattered on the ground
for _ = 1, 30 do
	local angle = rand:NextNumber(0, math.pi * 2)
	local r = rand:NextNumber(14, ISLAND_RADIUS - 4)
	local size = rand:NextNumber(1, 3)
	part({
		Name = "Rock",
		Size = Vector3.new(size * 1.3, size, size),
		CFrame = CFrame.new(math.cos(angle) * r, size * 0.3, math.sin(angle) * r)
			* CFrame.Angles(rand:NextNumber(0, 1), rand:NextNumber(0, 6), rand:NextNumber(0, 1)),
		Color = ROCK,
		Material = Enum.Material.Slate,
	})
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
		character:PivotTo(CFrame.new(SPAWN_POSITION))
	end
end)

island.Parent = workspace
