-- RebirthIslands (Script in ServerScriptService)
-- Builds the REBIRTH GATE on the main island and the three rebirth islands:
--   ❄️ FROSTFALL ISLE (Rebirth 1) - snow, pines, a frozen lake, an igloo,
--                                   snowmen, icicles and an aurora sky
--   🔥 EMBER ISLE     (Rebirth 2) - a smoking volcano, lava pools, geysers,
--                                   obsidian spikes and burnt trees
--   💠 NEON NEXUS     (Rebirth 3) - a synthwave city: neon grid floor, holo
--                                   towers, neon palms, floating cubes, a
--                                   giant striped sun
-- Each island has more luck while you stand on it, its own parkour course
-- (built by the Parkour script) and a return portal.
-- The portals are checked by position (plus a "Press E" prompt), like the
-- Lucky Isle portal. Things marked with FX_ attributes are animated by the
-- IslandFX script on each player's screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))

local rand = Random.new(2024)
local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder upright

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
local old = workspace:FindFirstChild("RebirthIslands")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "RebirthIslands"

local currentParent -- the model that new parts go into

local function part(props)
	local className = props.ClassName or "Part"
	local p = Instance.new(className)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		if key ~= "Parent" and key ~= "ClassName" then
			p[key] = value
		end
	end
	p.Parent = props.Parent or currentParent
	return p
end

local function decor(props)
	props.CanCollide = false
	props.CanQuery = false
	props.CastShadow = false
	return part(props)
end

local function addLight(target, color3, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color3
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = target
	return light
end

local function emitter(target, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = props.Texture or Config.Textures.Sparkle
	e.Rate = props.Rate or 5
	e.Lifetime = props.Lifetime or NumberRange.new(1.5, 3)
	e.Speed = props.Speed or NumberRange.new(0.5, 2)
	e.SpreadAngle = props.Spread or Vector2.new(180, 180)
	e.Size = props.Size or NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = props.Transparency or NumberSequence.new(0)
	e.Acceleration = props.Acceleration or Vector3.zero
	e.LightEmission = props.LightEmission or 1
	e.LightInfluence = 0
	e.Color = props.Color or ColorSequence.new(Color3.new(1, 1, 1))
	e.Rotation = props.Rotation or NumberRange.new(0, 360)
	e.RotSpeed = props.RotSpeed or NumberRange.new(-40, 40)
	if props.Drag then
		e.Drag = props.Drag
	end
	if props.EmissionDirection then
		e.EmissionDirection = props.EmissionDirection
	end
	e.Parent = target
	return e
end

local function sizeSeq(a, b, c)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, a),
		NumberSequenceKeypoint.new(0.5, b),
		NumberSequenceKeypoint.new(1, c),
	})
end

-- upright cylinder, top surface at topY
local function disc(name, center, radius, thickness, topY, color3, material, extra)
	local props = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(center.X, topY - thickness / 2, center.Z) * FLAT,
		Color = color3,
		Material = material,
	}
	for key, value in pairs(extra or {}) do
		props[key] = value
	end
	return part(props)
end

-- flat ring of pieces (its own Model, so it can spin)
local function ringModel(name, center, radius, segments, thickness, color3, parent, material)
	local model = Instance.new("Model")
	model.Name = name
	local length = (2 * math.pi * radius / segments) * 1.06
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		decor({
			Name = "Segment",
			Size = Vector3.new(thickness, thickness, length),
			CFrame = CFrame.lookAt(p, center) * CFrame.Angles(0, math.pi / 2, 0),
			Color = color3,
			Material = material or Enum.Material.Neon,
			Parent = model,
		})
	end
	model.WorldPivot = CFrame.new(center)
	model.Parent = parent or currentParent
	return model
end

-- upright ring facing portalCF's look direction
local function portalRing(name, portalCF, radius, segments, thickness, color3, parent)
	local model = Instance.new("Model")
	model.Name = name
	local length = (2 * math.pi * radius / segments) * 1.08
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local radial = Vector3.new(math.cos(a), math.sin(a), 0)
		decor({
			Name = "Segment",
			Size = Vector3.new(thickness, thickness, length),
			CFrame = portalCF * CFrame.fromMatrix(radial * radius, radial, Vector3.new(0, 0, 1)),
			Color = color3,
			Material = Enum.Material.Neon,
			Parent = model,
		})
	end
	model.WorldPivot = portalCF
	model.Parent = parent or currentParent
	return model
end

local function billboard(target, text, color3, offset, size, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = size or UDim2.fromOffset(420, 70)
	gui.StudsOffset = offset or Vector3.new(0, 6, 0)
	gui.MaxDistance = maxDistance or 220
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.RichText = true
	label.Text = text
	label.TextColor3 = color3
	label.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Thickness = 2.5
	outline.Transparency = 0.2
	outline.Parent = label
	return gui
end

-- spike pointing up (or down with flip = true), made of two wedges
local function spike(position, width, height, color3, material, flip, collide)
	local base = CFrame.new(position) * CFrame.Angles(0, rand:NextNumber(0, math.pi), 0)
	if flip then
		base *= CFrame.Angles(math.pi, 0, 0)
	end
	for k = 0, 1 do
		local cf = base * CFrame.Angles(0, k * math.pi, 0) * CFrame.new(0, height / 2, -width / 4)
		part({
			ClassName = "WedgePart",
			Name = "Spike",
			Size = Vector3.new(width, height, width / 2),
			CFrame = cf,
			Color = color3,
			Material = material,
			CanCollide = collide == true,
			CastShadow = false,
		})
	end
end

-- 4-sided pointy tier (pines, volcano tops), made of wedges
local function pyramid(position, base, height, color3, material, collide)
	for k = 0, 3 do
		part({
			ClassName = "WedgePart",
			Name = "Tier",
			Size = Vector3.new(base, height, base / 2),
			CFrame = CFrame.new(position) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, height / 2, -base / 4),
			Color = color3,
			Material = material,
			CanCollide = collide == true,
		})
	end
end

-- marks something for IslandFX to animate
local function fx(instance, attributes)
	for key, value in pairs(attributes) do
		instance:SetAttribute(key, value)
	end
	return instance
end

---------------------------------------------------------------------
-- Shared island pieces
---------------------------------------------------------------------
-- keep-out zones on every island: return portal path, parkour start, core
local function makeIsland(info, style)
	local model = Instance.new("Model")
	model.Name = info.Key .. "Isle"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model:SetAttribute("IslandKey", info.Key)
	model.Parent = folder
	currentParent = model

	local C = info.Center
	local R = info.Radius
	local D = R - 70 -- how much bigger than the original 70-stud island
	local function at(x, y, z)
		return C + Vector3.new(x, y, z)
	end
	local function free(x, z, margin)
		margin = margin or 0
		local flat = Vector3.new(x, 0, z)
		if flat.Magnitude > R - 6 - margin then
			return false
		end
		if flat.Magnitude < 13 + margin then
			return false -- the core
		end
		if math.abs(x) < 10 + margin and z < -12 then
			return false -- portal + arrival path
		end
		if math.abs(x) < 10 + margin and z > 12 then
			return false -- path to the parkour start
		end
		if info.Hatchery and (flat - Vector3.new(info.Hatchery.X, 0, info.Hatchery.Z)).Magnitude < 19 + margin then
			return false -- pet eggs
		end
		for _, zone in ipairs(style.Reserved or {}) do
			if (flat - zone[1]).Magnitude < zone[2] + margin then
				return false
			end
		end
		return true
	end
	local function randomSpot(minR, maxR, margin, tries)
		for _ = 1, tries or 40 do
			local a = rand:NextNumber(0, math.pi * 2)
			local r = rand:NextNumber(minR, maxR)
			local x, z = math.cos(a) * r, math.sin(a) * r
			if free(x, z, margin) then
				return x, z
			end
		end
		return nil
	end

	-- ground + layered rock underneath
	disc("Ground", C, R, 4, C.Y, style.Ground, style.GroundMaterial)
	disc("EdgeGlow", C, R + 0.7, 0.7, C.Y - 0.2, style.Edge, Enum.Material.Neon, { CanCollide = false })
	local layers = {
		{ r = R - 6, y = -4, t = 6 },
		{ r = R - 18, y = -10, t = 7 },
		{ r = R - 32, y = -17, t = 8 },
		{ r = R - 46, y = -25, t = 9 },
		{ r = R - 58, y = -34, t = 10 },
	}
	for i, layer in ipairs(layers) do
		disc("Underside" .. i, C, layer.r, layer.t, C.Y + layer.y, (i % 2 == 0) and style.RockDark or style.Rock,
			style.RockMaterial, { CanCollide = false })
	end

	-- return portal (behind where you arrive)
	local portalCF = CFrame.lookAt(at(0, 6, -56 - D), at(0, 6, -80 - D)) -- faces away from the island
	disc("PortalStep", at(0, 0, -55 - D), 8, 0.6, C.Y + 0.3, style.Accent2, style.TrimMaterial or Enum.Material.Slate)
	portalRing("ReturnPortalRing", portalCF, 4.6, 36, 0.7, style.Edge)
	local outer = portalRing("ReturnPortalRingOuter", portalCF, 5.6, 40, 0.35, style.Accent)
	fx(outer, { FX_Spin = Vector3.new(0, 0, 0.6) })
	local swirl = decor({
		Name = "ReturnSwirl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 9, 9),
		CFrame = portalCF * CFrame.Angles(0, math.rad(90), 0),
		Color = style.Edge,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
	})
	emitter(swirl, { Rate = 14, Color = ColorSequence.new(style.Edge, style.Accent), Size = sizeSeq(0, 0.6, 0) })
	addLight(swirl, style.Edge, 22, 2)
	local zone = part({
		Name = "ReturnPortalZone",
		Size = Vector3.new(8, 9, 3),
		CFrame = portalCF,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	billboard(swirl, "🏠 BACK TO COSMIC ISLAND", Color3.new(1, 1, 1), Vector3.new(0, 7.5, 0), UDim2.fromOffset(380, 50))

	-- welcome sign
	local signPost = part({
		Name = "WelcomeSign",
		Size = Vector3.new(10, 4, 0.6),
		CFrame = CFrame.lookAt(at(-11, 5, -40 - D), at(-11, 5, -60 - D)),
		Color = style.RockDark,
		Material = style.RockMaterial,
	})
	for _, side in ipairs({ -4.2, 4.2 }) do
		part({
			Name = "SignLeg",
			Size = Vector3.new(0.6, 3, 0.6),
			CFrame = signPost.CFrame * CFrame.new(side, -3.5, 0),
			Color = style.RockDark,
			Material = style.RockMaterial,
		})
	end
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.LightInfluence = 0
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 40
	signGui.Parent = signPost
	local signText = Instance.new("TextLabel")
	signText.BackgroundTransparency = 1
	signText.Size = UDim2.fromScale(1, 1)
	signText.Font = Enum.Font.FredokaOne
	signText.TextScaled = true
	signText.RichText = true
	signText.Text = ("%s %s\n<font size='60'>ALL YOUR LUCK x%s HERE</font>"):format(info.Icon, info.Name:upper(), tostring(info.LuckMultiplier))
	signText.TextColor3 = info.Color
	signText.Parent = signGui

	return {
		Model = model,
		Center = C,
		Radius = R,
		At = at,
		Free = free,
		RandomSpot = randomSpot,
		ReturnZone = zone,
		Arrival = CFrame.lookAt(at(0, 4, -44 - D), at(0, 4, 0)),
	}
end

-- floating islands' core: discs + an object that spins + rings
local function islandCore(island, style, buildCenterpiece)
	local at = island.At
	local C = island.Center
	local core = Instance.new("Model")
	core.Name = "IslandCore"
	core.Parent = island.Model
	disc("CoreBase", C, 11, 0.8, C.Y + 0.6, style.RockDark, style.RockMaterial, { Parent = core })
	disc("CoreRim", C, 11.4, 0.4, C.Y + 0.25, style.Edge, Enum.Material.Neon, { Parent = core, CanCollide = false })
	disc("CoreStep", C, 7, 0.8, C.Y + 1.4, style.Rock, style.RockMaterial, { Parent = core })
	disc("CoreTop", C, 4, 0.8, C.Y + 2.2, style.Accent2, style.TrimMaterial or Enum.Material.Slate, { Parent = core })
	local center = at(0, 9, 0)
	local piece = buildCenterpiece(center, core)
	addLight(piece, style.Edge, 40, 3)
	emitter(piece, { Rate = 10, Color = ColorSequence.new(style.Edge, style.Accent), Size = sizeSeq(0, 0.7, 0), Speed = NumberRange.new(1, 3) })
	billboard(piece, ("%s %s"):format(style.CoreIcon or "✦", style.CoreName), style.Edge, Vector3.new(0, 7, 0), UDim2.fromOffset(340, 56))
	fx(ringModel("CoreRing1", center, 6, 28, 0.3, style.Edge, core), { FX_Spin = Vector3.new(0.8, 0.3, 0) })
	fx(ringModel("CoreRing2", center, 7.5, 34, 0.3, style.Accent, core), { FX_Spin = Vector3.new(0, 0.6, 0.9) })
	fx(ringModel("CoreRing3", center, 9, 40, 0.3, style.Accent2, core), { FX_Spin = Vector3.new(0.4, 0, 0.5) })
	-- 4 pillars around the core
	for i = 1, 4 do
		local a = (i / 4) * math.pi * 2 + math.pi / 4
		local p = at(math.cos(a) * 9.5, 0, math.sin(a) * 9.5)
		part({
			Name = "CorePillar",
			Size = Vector3.new(1.4, 7, 1.4),
			CFrame = CFrame.new(p + Vector3.new(0, 4, 0)),
			Color = style.RockDark,
			Material = style.RockMaterial,
			Parent = core,
		})
		local cap = decor({
			Name = "CorePillarCap",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.6,
			CFrame = CFrame.new(p + Vector3.new(0, 8.2, 0)),
			Color = style.Edge,
			Material = Enum.Material.Neon,
			Parent = core,
		})
		addLight(cap, style.Edge, 14, 1.2)
	end
	return core
end

-- lantern posts along the arrival path
local function pathLanterns(island, style)
	for _, side in ipairs({ -1, 1 }) do
		for z = -16, -(island.Radius - 30), -12 do
			local p = island.At(side * 6.5, 0, z)
			part({
				Name = "LanternPost",
				Size = Vector3.new(0.7, 6, 0.7),
				CFrame = CFrame.new(p + Vector3.new(0, 3, 0)),
				Color = style.RockDark,
				Material = style.RockMaterial,
			})
			local lamp = decor({
				Name = "Lantern",
				Size = Vector3.one * 1.3,
				CFrame = CFrame.new(p + Vector3.new(0, 6.8, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
				Color = style.Edge,
				Material = Enum.Material.Neon,
			})
			fx(lamp, { FX_Spin = Vector3.new(0, 1.2, 0) })
			addLight(lamp, style.Edge, 16, 1.3)
		end
	end
	-- path tiles from the portal to the core
	for z = -(island.Radius - 20), -12, 3 do
		part({
			Name = "PathTile",
			Size = Vector3.new(5 + rand:NextNumber(-0.3, 0.3), 0.3, 2.8),
			CFrame = CFrame.new(island.At(0, 0.12, z)) * CFrame.Angles(0, rand:NextNumber(-0.05, 0.05), 0),
			Color = style.Path,
			Material = style.PathMaterial or style.RockMaterial,
		})
	end
	-- and from the core to the parkour start
	for z = 13, island.Radius - 13, 3 do
		part({
			Name = "PathTile",
			Size = Vector3.new(4.2 + rand:NextNumber(-0.3, 0.3), 0.3, 2.8),
			CFrame = CFrame.new(island.At(0, 0.12, z)) * CFrame.Angles(0, rand:NextNumber(-0.05, 0.05), 0),
			Color = style.Path,
			Material = style.PathMaterial or style.RockMaterial,
		})
	end
end

-- a big invisible box above the island that rains particles (snow, embers...)
local function weather(island, props)
	local box = part({
		Name = "Weather",
		Size = Vector3.new(island.Radius * 2, 1, island.Radius * 2),
		CFrame = CFrame.new(island.At(0, 40, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	props.EmissionDirection = props.EmissionDirection or Enum.NormalId.Bottom
	emitter(box, props)
	return box
end

local builtIslands = {} -- [key] = island table

---------------------------------------------------------------------
-- ❄️ FROSTFALL ISLE
---------------------------------------------------------------------
do
	local info = Config.RebirthIslands[1]
	local SNOW = Color3.fromRGB(236, 244, 255)
	local ICE = Color3.fromRGB(150, 215, 255)
	local PINE = Color3.fromRGB(40, 95, 80)
	local style = {
		Ground = SNOW, GroundMaterial = Enum.Material.Snow,
		Rock = Color3.fromRGB(120, 170, 220), RockDark = Color3.fromRGB(70, 105, 160), RockMaterial = Enum.Material.Glacier,
		Edge = Color3.fromRGB(140, 230, 255), Accent = Color3.fromRGB(190, 160, 255), Accent2 = Color3.fromRGB(215, 235, 255),
		TrimMaterial = Enum.Material.Ice,
		Path = Color3.fromRGB(190, 215, 240), PathMaterial = Enum.Material.Ice,
		CoreName = "FROST CORE", CoreIcon = "❄️",
		Reserved = {
			{ Vector3.new(-32, 0, 10), 17 }, -- frozen lake
			{ Vector3.new(32, 0, -12), 10 }, -- igloo
		},
	}
	local island = makeIsland(info, style)
	local at = island.At
	local C = island.Center

	-- icicles hanging under the island
	for i = 1, 26 do
		local a = (i / 26) * math.pi * 2 + rand:NextNumber(-0.1, 0.1)
		local r = rand:NextNumber(14, info.Radius - 10)
		local layerY = -6 - (1 - r / info.Radius) * 26
		spike(at(math.cos(a) * r, layerY, math.sin(a) * r), rand:NextNumber(1.5, 3.2), rand:NextNumber(6, 16),
			(i % 3 == 0) and ICE or Color3.fromRGB(200, 235, 255), Enum.Material.Ice, true)
	end

	-- the core: a giant spinning snowflake
	islandCore(island, style, function(center, core)
		local flake = Instance.new("Model")
		flake.Name = "Snowflake"
		local hub = decor({
			Name = "Hub",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.2,
			CFrame = CFrame.new(center),
			Color = Color3.new(1, 1, 1),
			Material = Enum.Material.Neon,
			Parent = flake,
		})
		for k = 0, 5 do
			local arm = CFrame.new(center) * CFrame.Angles(0, 0, k * math.pi / 3)
			decor({ Name = "Arm", Size = Vector3.new(0.6, 9, 0.6), CFrame = arm, Color = ICE, Material = Enum.Material.Neon, Parent = flake })
			for _, s in ipairs({ -1, 1 }) do
				for _, y in ipairs({ 2.4, 3.6 }) do
					decor({
						Name = "Branch",
						Size = Vector3.new(0.4, y == 2.4 and 2.2 or 1.4, 0.4),
						CFrame = arm * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, s * math.rad(45)) * CFrame.new(0, (y == 2.4 and 1.1 or 0.7), 0),
						Color = Color3.fromRGB(220, 245, 255),
						Material = Enum.Material.Neon,
						Parent = flake,
					})
				end
			end
		end
		flake.WorldPivot = CFrame.new(center)
		flake.Parent = core
		fx(flake, { FX_Spin = Vector3.new(0, 0.7, 0), FX_Bob = 0.6 })
		return hub
	end)
	pathLanterns(island, style)

	-- frozen lake with cracks, ice blocks and a fishing hole
	local lakeCenter = at(-32, 0, 10)
	disc("FrozenLake", lakeCenter, 15, 0.4, C.Y + 0.18, Color3.fromRGB(165, 220, 255), Enum.Material.Ice,
		{ Reflectance = 0.25, CustomPhysicalProperties = PhysicalProperties.new(0.9, 0.02, 0.5, 100, 1) })
	disc("LakeRim", lakeCenter, 16, 0.5, C.Y + 0.1, Color3.fromRGB(230, 240, 255), Enum.Material.Snow)
	for i = 1, 7 do
		local a = rand:NextNumber(0, math.pi * 2)
		local p = lakeCenter + Vector3.new(math.cos(a) * 5, 0, math.sin(a) * 5)
		decor({
			Name = "IceCrack",
			Size = Vector3.new(0.15, 0.06, rand:NextNumber(5, 10)),
			CFrame = CFrame.new(p.X, C.Y + 0.4, p.Z) * CFrame.Angles(0, a + rand:NextNumber(-0.6, 0.6), 0),
			Color = Color3.fromRGB(220, 250, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.3,
		})
	end
	disc("FishingHole", lakeCenter + Vector3.new(4, 0, -3), 1.6, 0.1, C.Y + 0.43, Color3.fromRGB(20, 60, 110), Enum.Material.Water, { CanCollide = false })
	for i = 1, 5 do
		local a = (i / 5) * math.pi * 2
		part({
			Name = "IceBlock",
			Size = Vector3.new(rand:NextNumber(1.6, 3), rand:NextNumber(1.2, 2.4), rand:NextNumber(1.6, 3)),
			CFrame = CFrame.new(lakeCenter.X + math.cos(a) * 12, C.Y + 1, lakeCenter.Z + math.sin(a) * 12) * CFrame.Angles(rand:NextNumber(-0.3, 0.3), a, rand:NextNumber(-0.3, 0.3)),
			Color = ICE,
			Material = Enum.Material.Ice,
			Transparency = 0.25,
		})
	end
	-- a little sign
	local lakeSign = part({ Name = "LakeSign", Size = Vector3.new(0.4, 3.5, 0.4), CFrame = CFrame.new(lakeCenter + Vector3.new(14, 1.75, -9)), Color = Color3.fromRGB(110, 80, 60), Material = Enum.Material.Wood })
	billboard(lakeSign, "⛸ SLIPPERY!", ICE, Vector3.new(0, 3, 0), UDim2.fromOffset(200, 40), 60)

	-- igloo (dome + tunnel)
	local iglooCenter = at(32, 0, -12)
	part({
		Name = "Igloo",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 12,
		CFrame = CFrame.new(iglooCenter + Vector3.new(0, -0.5, 0)),
		Color = Color3.fromRGB(240, 248, 255),
		Material = Enum.Material.Snow,
	})
	part({
		Name = "IglooTunnel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 4.5, 4.5),
		CFrame = CFrame.lookAt(iglooCenter + Vector3.new(0, 0.9, 0), iglooCenter + Vector3.new(-1, 0.9, 0)) * CFrame.new(0, 0, -6) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(230, 240, 252),
		Material = Enum.Material.Snow,
	})
	local door = decor({
		Name = "IglooDoor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 3.2, 3.2),
		CFrame = CFrame.lookAt(iglooCenter + Vector3.new(0, 0.9, 0), iglooCenter + Vector3.new(-1, 0.9, 0)) * CFrame.new(0, 0, -8.05) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(255, 190, 110),
		Material = Enum.Material.Neon,
	})
	addLight(door, Color3.fromRGB(255, 180, 100), 14, 1.5)
	for row = 0, 3 do -- block lines on the dome
		decor({
			Name = "IglooLine",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 12.1 * math.cos(math.asin(math.min(0.95, (row * 1.4 + 0.6) / 6))), 12.1 * math.cos(math.asin(math.min(0.95, (row * 1.4 + 0.6) / 6)))),
			CFrame = CFrame.new(iglooCenter + Vector3.new(0, row * 1.4 + 0.1, 0)) * FLAT,
			Color = Color3.fromRGB(200, 220, 245),
			Material = Enum.Material.SmoothPlastic,
		})
	end

	-- pine trees with snowy tops
	local function pine(x, z)
		local base = at(x, 0, z)
		local height = rand:NextNumber(0.85, 1.3)
		part({
			Name = "PineTrunk",
			Size = Vector3.new(1.2, 3 * height, 1.2),
			CFrame = CFrame.new(base + Vector3.new(0, 1.5 * height, 0)),
			Color = Color3.fromRGB(90, 60, 45),
			Material = Enum.Material.Wood,
		})
		local y = 2.2 * height
		for tier = 1, 3 do
			local w = (7 - tier * 1.7) * height
			local h = 3.6 * height
			pyramid(base + Vector3.new(0, y, 0), w, h, PINE:Lerp(Color3.fromRGB(70, 130, 110), tier * 0.12), Enum.Material.Grass, tier == 1)
			pyramid(base + Vector3.new(0, y + h * 0.55, 0), w * 0.5, h * 0.45, SNOW, Enum.Material.Snow)
			y += 2.3 * height
		end
		local star = decor({
			Name = "PineLight",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.6,
			CFrame = CFrame.new(base + Vector3.new(0, y + 1.6 * height, 0)),
			Color = ICE,
			Material = Enum.Material.Neon,
		})
		addLight(star, ICE, 10, 0.8)
	end
	local pines = 0
	for _ = 1, 160 do
		if pines >= 32 then
			break
		end
		local x, z = island.RandomSpot(18, info.Radius - 7, 3)
		if x then
			pine(x, z)
			pines += 1
		end
	end

	-- snowmen
	local function snowman(x, z, facing)
		local base = at(x, 0, z)
		local look = CFrame.lookAt(base, base + facing)
		part({ Name = "SnowBall", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.4, CFrame = look * CFrame.new(0, 1.4, 0), Color = SNOW, Material = Enum.Material.Snow })
		part({ Name = "SnowBall", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.5, CFrame = look * CFrame.new(0, 3.6, 0), Color = SNOW, Material = Enum.Material.Snow })
		local head = part({ Name = "SnowHead", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, CFrame = look * CFrame.new(0, 5.3, 0), Color = SNOW, Material = Enum.Material.Snow })
		decor({ Name = "Carrot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.1, 0.3, 0.3), CFrame = head.CFrame * CFrame.new(0, 0, -1.2) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 140, 40), Material = Enum.Material.SmoothPlastic })
		for _, s in ipairs({ -0.35, 0.35 }) do
			decor({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.25, CFrame = head.CFrame * CFrame.new(s, 0.25, -0.82), Color = Color3.fromRGB(20, 20, 30), Material = Enum.Material.SmoothPlastic })
		end
		decor({ Name = "Scarf", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 2.1, 2.1), CFrame = look * CFrame.new(0, 4.5, 0) * FLAT, Color = Color3.fromRGB(230, 60, 80), Material = Enum.Material.Fabric })
		decor({ Name = "ScarfTail", Size = Vector3.new(0.5, 1.4, 0.2), CFrame = look * CFrame.new(0.5, 3.9, -1) * CFrame.Angles(0.2, 0, 0.15), Color = Color3.fromRGB(230, 60, 80), Material = Enum.Material.Fabric })
		decor({ Name = "Hat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 1.3, 1.3), CFrame = look * CFrame.new(0, 6.6, 0) * FLAT, Color = Color3.fromRGB(30, 30, 45), Material = Enum.Material.SmoothPlastic })
		decor({ Name = "HatBrim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 2, 2), CFrame = look * CFrame.new(0, 6.05, 0) * FLAT, Color = Color3.fromRGB(30, 30, 45), Material = Enum.Material.SmoothPlastic })
		for _, s in ipairs({ -1, 1 }) do
			decor({ Name = "StickArm", Size = Vector3.new(0.18, 0.18, 2.6), CFrame = look * CFrame.new(s * 1.9, 3.9, 0) * CFrame.Angles(0, math.rad(90), s * 0.5), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood })
		end
	end
	snowman(-14, -24, Vector3.new(0.5, 0, -1))
	snowman(20, 22, Vector3.new(-1, 0, -0.3))
	snowman(-44, 30, Vector3.new(1, 0, -0.5))
	snowman(-62, -40, Vector3.new(1, 0, 0.4))
	snowman(70, -10, Vector3.new(-1, 0, 0))

	-- ice crystal spikes
	for _ = 1, 15 do
		local x, z = island.RandomSpot(20, info.Radius - 8, 2)
		if x then
			for k = 1, rand:NextInteger(3, 5) do
				local off = (k == 1) and Vector3.zero or Vector3.new(rand:NextNumber(-2, 2), 0, rand:NextNumber(-2, 2))
				spike(at(x, 0, z) + off, rand:NextNumber(1.2, 2), (k == 1) and rand:NextNumber(6, 9) or rand:NextNumber(2.5, 5), ICE, Enum.Material.Ice, false, k == 1)
			end
			local glow = decor({ Name = "CrystalGlow", Size = Vector3.one * 0.5, CFrame = CFrame.new(at(x, 1, z)), Transparency = 1 })
			addLight(glow, ICE, 14, 1.2)
		end
	end

	-- aurora ribbons high in the sky (IslandFX makes them shimmer)
	local auroraColors = { Color3.fromRGB(90, 255, 170), Color3.fromRGB(110, 200, 255), Color3.fromRGB(190, 120, 255) }
	for band = 1, 3 do
		local ribbon = Instance.new("Model")
		ribbon.Name = "Aurora"
		local z0 = 40 + band * 22
		for i = -10, 10 do
			local x = i * 9
			local y = 75 + band * 6 + math.sin(i * 0.5 + band) * 6
			local z = z0 + math.cos(i * 0.35 + band) * 10
			decor({
				Name = "AuroraPanel",
				Size = Vector3.new(9.4, 26, 0.2),
				CFrame = CFrame.lookAt(at(x, y, z), at(x, y, z - 10)) * CFrame.Angles(0, math.sin(i * 0.4) * 0.3, 0),
				Color = auroraColors[band],
				Material = Enum.Material.Neon,
				Transparency = 0.7,
				Parent = ribbon,
			}):SetAttribute("Phase", i * 0.45 + band)
		end
		ribbon.Parent = island.Model
		fx(ribbon, { FX_Aurora = true })
	end

	-- falling snow
	weather(island, {
		Rate = 70,
		Lifetime = NumberRange.new(8, 11),
		Speed = NumberRange.new(4, 6),
		Spread = Vector2.new(25, 25),
		Size = sizeSeq(0.25, 0.35, 0.2),
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		LightEmission = 0.4,
		Acceleration = Vector3.new(1.5, 0, 0.6),
		RotSpeed = NumberRange.new(-90, 90),
	})
	builtIslands[info.Key] = island
end

---------------------------------------------------------------------
-- 🔥 EMBER ISLE
---------------------------------------------------------------------
do
	local info = Config.RebirthIslands[2]
	local BASALT = Color3.fromRGB(55, 42, 42)
	local LAVA = Color3.fromRGB(255, 110, 30)
	local LAVA_HOT = Color3.fromRGB(255, 200, 70)
	local OBSIDIAN = Color3.fromRGB(25, 15, 30)
	local style = {
		Ground = Color3.fromRGB(70, 52, 48), GroundMaterial = Enum.Material.Basalt,
		Rock = Color3.fromRGB(60, 40, 38), RockDark = Color3.fromRGB(35, 24, 26), RockMaterial = Enum.Material.Basalt,
		Edge = LAVA, Accent = Color3.fromRGB(255, 60, 60), Accent2 = Color3.fromRGB(90, 60, 55),
		Path = Color3.fromRGB(105, 85, 78), PathMaterial = Enum.Material.Cobblestone,
		CoreName = "EMBER CORE", CoreIcon = "🔥",
		Reserved = {
			{ Vector3.new(-34, 0, 6), 22 }, -- volcano
		},
	}
	local island = makeIsland(info, style)
	local at = island.At
	local C = island.Center

	-- glowing lava drips under the island
	for i = 1, 18 do
		local a = (i / 18) * math.pi * 2
		local r = rand:NextNumber(12, info.Radius - 14)
		decor({
			Name = "LavaDrip",
			Size = Vector3.new(0.7, rand:NextNumber(10, 22), 0.7),
			CFrame = CFrame.new(at(math.cos(a) * r, -16, math.sin(a) * r)),
			Color = LAVA,
			Material = Enum.Material.Neon,
		})
	end

	-- the core: a burning orb above a fire pit
	islandCore(island, style, function(center, core)
		local orb = decor({
			Name = "FireOrb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 4,
			CFrame = CFrame.new(center),
			Color = LAVA_HOT,
			Material = Enum.Material.Neon,
			Parent = core,
		})
		local fire = Instance.new("Fire")
		fire.Size = 9
		fire.Heat = 12
		fire.Color = LAVA
		fire.SecondaryColor = Color3.fromRGB(255, 40, 20)
		fire.Parent = orb
		fx(orb, { FX_Bob = 0.6, FX_Pulse = 0.4 })
		return orb
	end)
	pathLanterns(island, style)

	-- cracked lava patches in the ground
	for _ = 1, 18 do
		local x, z = island.RandomSpot(16, info.Radius - 8, 1)
		if x then
			disc("LavaCrack", at(x, 0, z), rand:NextNumber(2.5, 5), 0.2, C.Y + 0.1, Color3.fromRGB(200, 90, 40), Enum.Material.CrackedLava)
		end
	end

	-- the volcano: stacked rock rings with a lava crater and smoke
	local volcano = Instance.new("Model")
	volcano.Name = "Volcano"
	volcano.Parent = island.Model
	local vBase = at(-34, 0, 6)
	local rings = { { 18, 4 }, { 15, 5 }, { 12, 5 }, { 9.5, 5 }, { 7.5, 4 } }
	local y = 0
	for i, ring in ipairs(rings) do
		disc("VolcanoRock", vBase, ring[1], ring[2], C.Y + y + ring[2], (i % 2 == 0) and BASALT or Color3.fromRGB(70, 50, 46), Enum.Material.Basalt, { Parent = volcano })
		y += ring[2]
	end
	local crater = disc("Crater", vBase, 5.8, 1, C.Y + y + 0.3, LAVA, Enum.Material.Neon, { Parent = volcano, CanCollide = false })
	addLight(crater, LAVA, 50, 4)
	local craterFire = Instance.new("Fire")
	craterFire.Size = 14
	craterFire.Heat = 20
	craterFire.Color = LAVA
	craterFire.SecondaryColor = Color3.fromRGB(255, 50, 20)
	craterFire.Parent = crater
	emitter(crater, {
		Texture = Config.Textures.Smoke,
		Rate = 6,
		Lifetime = NumberRange.new(6, 9),
		Speed = NumberRange.new(5, 8),
		Spread = Vector2.new(12, 12),
		Size = sizeSeq(4, 10, 16),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(90, 70, 70), Color3.fromRGB(40, 35, 40)),
		LightEmission = 0,
		EmissionDirection = Enum.NormalId.Right, -- the disc is turned on its side; Right = up
	})
	emitter(crater, {
		Texture = Config.Textures.Spark,
		Rate = 25,
		Lifetime = NumberRange.new(1.5, 3),
		Speed = NumberRange.new(12, 22),
		Spread = Vector2.new(30, 30),
		Size = sizeSeq(0.3, 0.5, 0),
		Acceleration = Vector3.new(0, -18, 0),
		Color = ColorSequence.new(LAVA_HOT, LAVA),
		EmissionDirection = Enum.NormalId.Right,
	}):SetAttribute("Eruption", true)
	crater:SetAttribute("FX_Eruption", true)
	-- lava streams down the sides
	for k = 1, 5 do
		local a = (k / 5) * math.pi * 2 + 0.4
		local top = vBase + Vector3.new(math.cos(a) * 6, y - 0.5, math.sin(a) * 6)
		local bottom = vBase + Vector3.new(math.cos(a) * 18.6, 0.6, math.sin(a) * 18.6)
		local mid = (top + bottom) / 2
		decor({
			Name = "LavaStream",
			Size = Vector3.new(1.4, 0.4, (top - bottom).Magnitude + 1),
			CFrame = CFrame.lookAt(mid, bottom),
			Color = LAVA,
			Material = Enum.Material.Neon,
			Parent = volcano,
		})
	end
	billboard(crater, "🌋 MOUNT EMBER", LAVA_HOT, Vector3.new(0, 12, 0), UDim2.fromOffset(300, 50))

	-- lava pools with rock rims
	for _ = 1, 5 do
		local x, z = island.RandomSpot(22, info.Radius - 12, 5)
		if x then
			local p = at(x, 0, z)
			local r = rand:NextNumber(3.5, 5)
			disc("PoolRim", p, r + 1.2, 1, C.Y + 0.6, BASALT, Enum.Material.Basalt)
			local pool = disc("LavaPool", p, r, 0.2, C.Y + 0.65, LAVA, Enum.Material.Neon, { CanCollide = false })
			addLight(pool, LAVA, 18, 2)
			emitter(pool, { Texture = Config.Textures.Fire, Rate = 6, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(1, 3), Size = sizeSeq(0.5, 1.4, 0), Color = ColorSequence.new(LAVA_HOT, LAVA), EmissionDirection = Enum.NormalId.Right })
		end
	end

	-- geysers: vents that blast fire every few seconds (timed in IslandFX)
	for g = 1, 7 do
		local x, z = island.RandomSpot(16, info.Radius - 9, 3)
		if x then
			local p = at(x, 0, z)
			disc("GeyserVent", p, 1.8, 1, C.Y + 0.7, OBSIDIAN, Enum.Material.Glass)
			local hole = disc("GeyserHole", p, 1, 0.2, C.Y + 0.75, LAVA, Enum.Material.Neon, { CanCollide = false })
			local blast = emitter(hole, {
				Texture = Config.Textures.Fire,
				Rate = 0,
				Lifetime = NumberRange.new(0.8, 1.2),
				Speed = NumberRange.new(30, 40),
				Spread = Vector2.new(6, 6),
				Size = sizeSeq(1.2, 2.4, 0.5),
				Color = ColorSequence.new(LAVA_HOT, Color3.fromRGB(255, 60, 20)),
				EmissionDirection = Enum.NormalId.Right,
			})
			blast.Name = "Blast"
			fx(hole, { FX_Geyser = true, Phase = g * 1.3 })
		end
	end

	-- obsidian spikes
	for _ = 1, 17 do
		local x, z = island.RandomSpot(18, info.Radius - 7, 2)
		if x then
			for k = 1, rand:NextInteger(2, 4) do
				local off = (k == 1) and Vector3.zero or Vector3.new(rand:NextNumber(-2, 2), 0, rand:NextNumber(-2, 2))
				spike(at(x, 0, z) + off, rand:NextNumber(1.4, 2.4), (k == 1) and rand:NextNumber(5, 9) or rand:NextNumber(2, 4), OBSIDIAN, Enum.Material.Glass, false, k == 1)
			end
		end
	end

	-- burnt trees with glowing ember tips
	for _ = 1, 15 do
		local x, z = island.RandomSpot(18, info.Radius - 7, 3)
		if x then
			local base = at(x, 0, z)
			local h = rand:NextNumber(5, 8)
			part({ Name = "BurntTrunk", Size = Vector3.new(0.9, h, 0.9), CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rand:NextNumber(-0.1, 0.1), 0, rand:NextNumber(-0.1, 0.1)), Color = Color3.fromRGB(35, 25, 22), Material = Enum.Material.Wood })
			for b = 1, 3 do
				local a = rand:NextNumber(0, math.pi * 2)
				local by = h * (0.45 + b * 0.15)
				local branch = part({
					Name = "BurntBranch",
					Size = Vector3.new(0.4, 0.4, rand:NextNumber(2, 3.5)),
					CFrame = CFrame.new(base + Vector3.new(0, by, 0)) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, 0, -1.2),
					Color = Color3.fromRGB(35, 25, 22),
					Material = Enum.Material.Wood,
					CanCollide = false,
				})
				decor({ Name = "EmberTip", Size = Vector3.one * 0.35, CFrame = branch.CFrame * CFrame.new(0, 0, -branch.Size.Z / 2), Color = LAVA, Material = Enum.Material.Neon })
			end
		end
	end

	-- obsidian arch over the arrival path
	for _, s in ipairs({ -1, 1 }) do
		part({ Name = "ArchLeg", Size = Vector3.new(1.6, 11, 1.6), CFrame = CFrame.new(at(s * 5, 5.5, -32)), Color = OBSIDIAN, Material = Enum.Material.Glass })
		decor({ Name = "ArchVein", Size = Vector3.new(0.3, 10, 0.3), CFrame = CFrame.new(at(s * 5, 5.5, -32.85)), Color = LAVA, Material = Enum.Material.Neon })
	end
	part({ Name = "ArchTop", Size = Vector3.new(12, 1.6, 1.8), CFrame = CFrame.new(at(0, 11.5, -32)), Color = OBSIDIAN, Material = Enum.Material.Glass })
	local skull = decor({ Name = "ArchGem", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = CFrame.new(at(0, 12.9, -32)), Color = LAVA_HOT, Material = Enum.Material.Neon })
	addLight(skull, LAVA, 18, 2)

	-- floating embers everywhere
	local embers = weather(island, {
		Texture = Config.Textures.Spark,
		Rate = 30,
		Lifetime = NumberRange.new(6, 9),
		Speed = NumberRange.new(1, 3),
		Spread = Vector2.new(60, 60),
		Size = sizeSeq(0.15, 0.3, 0),
		Color = ColorSequence.new(LAVA_HOT, LAVA),
		Acceleration = Vector3.new(0.5, 1.2, 0),
		EmissionDirection = Enum.NormalId.Top,
	})
	embers.CFrame = CFrame.new(at(0, 2, 0))
	builtIslands[info.Key] = island
end

---------------------------------------------------------------------
-- 💠 NEON NEXUS
---------------------------------------------------------------------
do
	local info = Config.RebirthIslands[3]
	local PINK = Color3.fromRGB(255, 70, 220)
	local CYAN = Color3.fromRGB(60, 230, 255)
	local PURPLE = Color3.fromRGB(140, 80, 255)
	local DARK = Color3.fromRGB(18, 12, 32)
	local style = {
		Ground = DARK, GroundMaterial = Enum.Material.SmoothPlastic,
		Rock = Color3.fromRGB(35, 22, 60), RockDark = Color3.fromRGB(22, 14, 40), RockMaterial = Enum.Material.SmoothPlastic,
		Edge = PINK, Accent = CYAN, Accent2 = Color3.fromRGB(60, 40, 100),
		TrimMaterial = Enum.Material.Glass,
		Path = Color3.fromRGB(45, 30, 80), PathMaterial = Enum.Material.Glass,
		CoreName = "NEXUS CORE", CoreIcon = "💠",
	}
	local island = makeIsland(info, style)
	local at = island.At

	-- neon grid floor (lines clipped to the circle)
	for i = -9, 9 do
		local d = i * 10
		local half = math.sqrt(math.max(0, (info.Radius - 1) ^ 2 - d * d))
		if half > 2 then
			decor({ Name = "GridX", Size = Vector3.new(half * 2, 0.06, 0.18), CFrame = CFrame.new(at(0, 0.04, d)), Color = (i % 2 == 0) and CYAN or PURPLE, Material = Enum.Material.Neon })
			decor({ Name = "GridZ", Size = Vector3.new(0.18, 0.06, half * 2), CFrame = CFrame.new(at(d, 0.04, 0)), Color = (i % 2 == 0) and PINK or PURPLE, Material = Enum.Material.Neon })
		end
	end
	-- neon rings on the underside
	for k = 1, 4 do
		ringModel("UnderRing", at(0, -4 - k * 7, 0), info.Radius - 8 - k * 12, 60, 0.5, (k % 2 == 0) and PINK or CYAN, island.Model)
	end

	-- the core: a spinning crystal (two pyramids) in a cage of rings
	islandCore(island, style, function(center, core)
		local gem = Instance.new("Model")
		gem.Name = "NexusGem"
		local heart = decor({ Name = "Heart", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = CFrame.new(center), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Parent = gem })
		for k = 0, 3 do
			for _, flip in ipairs({ false, true }) do
				local cf = CFrame.new(center) * (flip and CFrame.Angles(math.pi, 0, 0) or CFrame.new()) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 2, -1)
				decor({ ClassName = "WedgePart", Name = "Facet", Size = Vector3.new(4, 4, 2), CFrame = cf, Color = flip and PURPLE or PINK, Material = Enum.Material.Glass, Transparency = 0.2, Parent = gem })
			end
		end
		gem.WorldPivot = CFrame.new(center)
		gem.Parent = core
		fx(gem, { FX_Spin = Vector3.new(0, 1.1, 0), FX_Bob = 0.8 })
		return heart
	end)
	pathLanterns(island, style)

	-- holo towers
	local towerSpots = { { 30, -30 }, { 44, 8 }, { -44, -12 }, { -30, 30 }, { 22, 40 }, { -48, 16 }, { -70, -45 }, { 75, 30 }, { -72, 50 }, { 40, 72 }, { -20, -70 } }
	for i, spot in ipairs(towerSpots) do
		local x, z = spot[1], spot[2]
		if island.Free(x, z, 2) then
			local h = rand:NextNumber(18, 34)
			local w = rand:NextNumber(5, 7)
			local base = at(x, 0, z)
			local color = (i % 2 == 0) and PINK or CYAN
			part({ Name = "Tower", Size = Vector3.new(w, h, w), CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)), Color = Color3.fromRGB(25, 18, 45), Material = Enum.Material.Glass, Reflectance = 0.15 })
			for row = 3, h - 2, 3 do -- window strips
				for _, face in ipairs({ 0, 1, 2, 3 }) do
					decor({
						Name = "Window",
						Size = Vector3.new(w * 0.7, 0.35, 0.1),
						CFrame = CFrame.new(base + Vector3.new(0, row, 0)) * CFrame.Angles(0, face * math.pi / 2, 0) * CFrame.new(0, 0, -w / 2 - 0.06),
						Color = (rand:NextNumber() < 0.75) and color or Color3.fromRGB(255, 240, 150),
						Material = Enum.Material.Neon,
					})
				end
			end
			decor({ Name = "TowerEdge", Size = Vector3.new(w + 0.3, 0.4, w + 0.3), CFrame = CFrame.new(base + Vector3.new(0, h, 0)), Color = color, Material = Enum.Material.Neon })
			local antenna = decor({ Name = "Antenna", Size = Vector3.new(0.3, 6, 0.3), CFrame = CFrame.new(base + Vector3.new(0, h + 3, 0)), Color = Color3.fromRGB(80, 80, 100), Material = Enum.Material.Metal })
			local blink = decor({ Name = "AntennaLight", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, CFrame = antenna.CFrame * CFrame.new(0, 3.2, 0), Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon })
			fx(blink, { FX_Blink = true, Phase = i })
			fx(ringModel("HoloRing", base + Vector3.new(0, h + 2.5, 0), w * 0.8, 24, 0.25, color, island.Model), { FX_Spin = Vector3.new(0, (i % 2 == 0) and 1 or -1, 0) })
			addLight(blink, color, 30, 2)
		end
	end

	-- neon palm trees
	for _ = 1, 15 do
		local x, z = island.RandomSpot(16, info.Radius - 8, 3)
		if x then
			local base = at(x, 0, z)
			local lean = rand:NextNumber(-0.25, 0.25)
			local cf = CFrame.new(base) * CFrame.Angles(lean, rand:NextNumber(0, 6), 0)
			for seg = 0, 5 do
				decor({ Name = "PalmTrunk", Size = Vector3.new(0.9, 1.4, 0.9), CFrame = cf * CFrame.new(0, 0.7 + seg * 1.35, 0) * CFrame.Angles(0, seg * 0.4, 0), Color = Color3.fromRGB(40, 25, 70), Material = Enum.Material.SmoothPlastic })
				decor({ Name = "PalmRing", Size = Vector3.new(1, 0.12, 1), CFrame = cf * CFrame.new(0, 1.35 + seg * 1.35, 0), Color = CYAN, Material = Enum.Material.Neon })
			end
			local top = cf * CFrame.new(0, 8.3, 0)
			for leaf = 1, 6 do
				decor({
					Name = "PalmLeaf",
					Size = Vector3.new(0.9, 0.15, 4.5),
					CFrame = top * CFrame.Angles(0, leaf * math.pi / 3, 0) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, -2.1),
					Color = PINK,
					Material = Enum.Material.Neon,
				})
			end
			part({ Name = "PalmHitbox", Size = Vector3.new(1, 8, 1), CFrame = cf * CFrame.new(0, 4, 0), Transparency = 1 })
		end
	end

	-- floating cubes
	for i = 1, 20 do
		local a = (i / 20) * math.pi * 2
		local r = rand:NextNumber(22, 85)
		local s = rand:NextNumber(1.5, 3)
		local cube = decor({
			Name = "FloatCube",
			Size = Vector3.one * s,
			CFrame = CFrame.new(at(math.cos(a) * r, rand:NextNumber(12, 24), math.sin(a) * r)),
			Color = ({ PINK, CYAN, PURPLE })[(i % 3) + 1],
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		})
		fx(cube, { FX_Spin = Vector3.new(rand:NextNumber(-1, 1), rand:NextNumber(0.5, 1.5), rand:NextNumber(-1, 1)), FX_Bob = 1.5 })
	end

	-- the giant striped synthwave sun behind the parkour
	local sunCF = CFrame.lookAt(at(0, 60, 230), at(0, 60, 0))
	local sun = decor({
		Name = "SynthSun",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 110, 110),
		CFrame = sunCF * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(255, 120, 90),
		Material = Enum.Material.Neon,
	})
	local glow = Instance.new("SurfaceLight") -- warm glow on the island
	glow.Face = Enum.NormalId.Right
	glow.Range = 60
	glow.Brightness = 0.5
	glow.Color = Color3.fromRGB(255, 120, 160)
	glow.Parent = sun
	for k = 1, 6 do
		local y = -10 - k * 6.5
		local half = math.sqrt(math.max(0, 55 ^ 2 - y ^ 2))
		decor({
			Name = "SunStripe",
			Size = Vector3.new(half * 2 + 2, 1 + k * 0.5, 0.5),
			CFrame = sunCF * CFrame.new(0, y, -1),
			Color = Color3.fromRGB(30, 10, 45),
			Material = Enum.Material.SmoothPlastic,
		})
	end
	decor({ Name = "SunTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 112, 112), CFrame = sunCF * CFrame.new(0, 0, 0.6) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 220, 90), Material = Enum.Material.Neon, Transparency = 0.6 })

	-- digital rain of sparkles
	weather(island, {
		Rate = 40,
		Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(8, 12),
		Spread = Vector2.new(0, 0),
		Size = sizeSeq(0.2, 0.25, 0.1),
		Color = ColorSequence.new(CYAN, PINK),
		RotSpeed = NumberRange.new(0, 0),
	})
	builtIslands[info.Key] = island
end

---------------------------------------------------------------------
-- ⭐ THE REBIRTH GATE (on the main island)
---------------------------------------------------------------------
local gate = Instance.new("Model")
gate.Name = "RebirthGate"
gate.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
gate.Parent = folder
currentParent = gate

local G = Config.Places.RebirthGate
local GOLD = Color3.fromRGB(255, 210, 90)
local toSpawn = Vector3.new(-G.X, 0, -G.Z).Unit
local baseAngle = math.atan2(-toSpawn.Z, -toSpawn.X) -- portals stand on the far side

disc("GateFloor", G, 13, 0.6, 0.3, Color3.fromRGB(45, 38, 75), Enum.Material.Marble)
ringModel("GateRing", G + Vector3.new(0, 0.36, 0), 12.4, 72, 0.35, GOLD, gate)
ringModel("GateRingInner", G + Vector3.new(0, 0.36, 0), 7, 48, 0.25, Color3.fromRGB(150, 120, 255), gate)

-- center: a pedestal with a floating star (press E to open the rebirth menu)
local pedestal = part({
	Name = "RebirthPedestal",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(3, 2.6, 2.6),
	CFrame = CFrame.new(G + Vector3.new(0, 1.8, 0)) * FLAT,
	Color = Color3.fromRGB(70, 60, 110),
	Material = Enum.Material.Marble,
})
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "RebirthAltarPrompt"
prompt.ActionText = "Rebirth"
prompt.ObjectText = "Rebirth Altar"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 10
prompt.RequiresLineOfSight = false
prompt.Parent = pedestal
local star = Instance.new("Model")
star.Name = "RebirthStar"
local starCenter = G + Vector3.new(0, 9, 0)
local starCore = decor({ Name = "StarCore", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = CFrame.new(starCenter), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Parent = star })
for k = 0, 4 do
	decor({
		ClassName = "WedgePart",
		Name = "StarPoint",
		Size = Vector3.new(0.6, 3, 1.6),
		CFrame = CFrame.new(starCenter) * CFrame.Angles(0, 0, k * math.pi * 2 / 5) * CFrame.new(0, 2.2, 0),
		Color = GOLD,
		Material = Enum.Material.Neon,
		Parent = star,
	})
end
star.WorldPivot = CFrame.new(starCenter)
star.Parent = gate
fx(star, { FX_Spin = Vector3.new(0, 1, 0), FX_Bob = 0.5 })
addLight(starCore, GOLD, 30, 2.5)
emitter(starCore, { Rate = 12, Color = ColorSequence.new(GOLD, Color3.fromRGB(150, 120, 255)), Size = sizeSeq(0, 0.6, 0), Speed = NumberRange.new(1, 3) })
billboard(starCore, "⭐ REBIRTH ALTAR", GOLD, Vector3.new(0, 4.5, 0), UDim2.fromOffset(320, 52))

-- the three portals
local gatePortals = {} -- { Zone, Island info, Exit }
for index, info in ipairs(Config.RebirthIslands) do
	local angle = baseAngle + (index - 2) * math.rad(60)
	local spot = G + Vector3.new(math.cos(angle) * 10, 0, math.sin(angle) * 10)
	local portalCF = CFrame.lookAt(spot + Vector3.new(0, 5.4, 0), G + Vector3.new(0, 5.4, 0))
	local holder = Instance.new("Model")
	holder.Name = "Portal_" .. info.Key
	holder.Parent = gate
	currentParent = holder
	-- frame: two pillars + a top beam
	for _, s in ipairs({ -1, 1 }) do
		part({ Name = "PortalPillar", Size = Vector3.new(1.2, 10, 1.2), CFrame = portalCF * CFrame.new(s * 4.8, -0.4, 0), Color = Color3.fromRGB(60, 50, 95), Material = Enum.Material.Marble })
		local gem = decor({ Name = "PillarGem", Size = Vector3.one * 1.1, CFrame = portalCF * CFrame.new(s * 4.8, 5.3, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = info.Color, Material = Enum.Material.Neon })
		fx(gem, { FX_Spin = Vector3.new(0, 1.5, 0) })
	end
	part({ Name = "PortalBeam", Size = Vector3.new(11, 1, 1.4), CFrame = portalCF * CFrame.new(0, 4.8, 0), Color = Color3.fromRGB(60, 50, 95), Material = Enum.Material.Marble })
	portalRing("PortalRing", portalCF, 3.9, 32, 0.55, info.Color, holder)
	fx(portalRing("PortalRingOuter", portalCF, 4.5, 36, 0.25, GOLD, holder), { FX_Spin = Vector3.new(0, 0, 0.7) })
	local swirl = decor({
		Name = "PortalSwirl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 7.6, 7.6),
		CFrame = portalCF * CFrame.Angles(0, math.rad(90), 0),
		Color = info.Color,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
	})
	emitter(swirl, { Rate = 10, Color = ColorSequence.new(info.Color, Color3.new(1, 1, 1)), Size = sizeSeq(0, 0.5, 0) })
	addLight(swirl, info.Color, 16, 1.6)
	-- a see-through lock pane (IslandFX hides it once you've unlocked it)
	local lock = decor({
		Name = "LockPane",
		Size = Vector3.new(8, 8, 0.3),
		CFrame = portalCF * CFrame.new(0, 0, -0.4),
		Color = Color3.fromRGB(40, 30, 60),
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
	})
	lock:SetAttribute("NeedRebirths", info.Rebirths)
	local sign = billboard(swirl, ("%s <b>%s</b>\nALL luck x%s • Rebirth %d"):format(info.Icon, info.Name:upper(), tostring(info.LuckMultiplier), info.Rebirths),
		info.Color, Vector3.new(0, 6.6, 0), UDim2.fromOffset(300, 70), 120)
	sign.Name = "PortalSign"
	sign:SetAttribute("NeedRebirths", info.Rebirths)
	local zone = part({
		Name = "PortalZone",
		Size = Vector3.new(7, 8, 2.5),
		CFrame = portalCF,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local exitSpot = (portalCF * CFrame.new(0, 0, -5.5)).Position
	exitSpot = Vector3.new(exitSpot.X, 3, exitSpot.Z)
	table.insert(gatePortals, {
		Zone = zone,
		Info = info,
		Exit = CFrame.lookAt(exitSpot, exitSpot + (exitSpot - spot) * Vector3.new(1, 0, 1)),
	})
end
currentParent = gate

-- gate sign facing the spawn
local gateSign = decor({ Name = "GateSignAnchor", Size = Vector3.one, CFrame = CFrame.new(G + toSpawn * 12 + Vector3.new(0, 1, 0)), Transparency = 1 })
billboard(gateSign, "⭐ REBIRTH GATE", GOLD, Vector3.new(0, 4, 0), UDim2.fromOffset(340, 56), 150)

folder.Parent = workspace

---------------------------------------------------------------------
-- PORTAL LOGIC
---------------------------------------------------------------------
local busy = {}
local deniedAt = {}

local function rebirthsOf(player)
	return player:GetAttribute("Rebirths") or 0
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
	task.wait(1.5)
	busy[player] = nil
end

local function enterGatePortal(player, portal)
	if rebirthsOf(player) >= portal.Info.Rebirths then
		task.spawn(teleport, player, builtIslands[portal.Info.Key].Arrival)
	elseif os.clock() - (deniedAt[player] or 0) > 3 then
		deniedAt[player] = os.clock()
		PortalFXRemote:FireClient(player, "DeniedRebirth", { Name = portal.Info.Name, Need = portal.Info.Rebirths })
	end
end

local function inZone(zone, position)
	local localPos = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

local function addPrompt(zone, objectText, onTriggered)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "Travel"
	p.ObjectText = objectText
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = zone
	p.Triggered:Connect(onTriggered)
end

local MAIN_RETURN = {} -- [key] = where you come out on the main island
for _, portal in ipairs(gatePortals) do
	MAIN_RETURN[portal.Info.Key] = portal.Exit
	addPrompt(portal.Zone, ("%s (ALL luck x%s)"):format(portal.Info.Name, tostring(portal.Info.LuckMultiplier)), function(player)
		enterGatePortal(player, portal)
	end)
end
for key, island in pairs(builtIslands) do
	addPrompt(island.ReturnZone, "Back to Cosmic Island", function(player)
		task.spawn(teleport, player, MAIN_RETURN[key])
	end)
end

local function islandAt(position)
	for _, info in ipairs(Config.RebirthIslands) do
		local offset = position - info.Center
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude < info.Radius + 8 and offset.Y > -20 and offset.Y < 90 then
			return info
		end
	end
	return nil
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
				for _, portal in ipairs(gatePortals) do
					if inZone(portal.Zone, root.Position) then
						enterGatePortal(player, portal)
					end
				end
				for key, island in pairs(builtIslands) do
					if inZone(island.ReturnZone, root.Position) then
						task.spawn(teleport, player, MAIN_RETURN[key])
					end
				end
			end
			if loops % 5 == 0 then
				local info = root and islandAt(root.Position)
				if info and rebirthsOf(player) < info.Rebirths and not busy[player] then
					task.spawn(teleport, player, CFrame.new(Vector3.new(0, 3, 0))) -- not unlocked yet
					info = nil
				end
				local key = info and info.Key or nil
				if player:GetAttribute("OnRebirthIsland") ~= key then
					player:SetAttribute("OnRebirthIsland", key)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
	deniedAt[player] = nil
end)
