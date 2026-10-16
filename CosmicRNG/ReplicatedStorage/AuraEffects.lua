-- AuraEffects (ModuleScript in ReplicatedStorage)
-- Builds and animates the aura visuals around a character.
-- Runs on each player's own computer (called by the AuraRenderer LocalScript),
-- so the animation is smooth and costs the server nothing.
--
-- Rarer tiers stack more layers:
--   Common    : glow particles + light
--   Uncommon  : + rising motes
--   Rare      : + orbiting stars with trails
--   Epic      : + body trail + ambient haze
--   Legendary : + rotating ground ring + spiral beams
--   Mythic    : + halo + shockwave pulses
--   Secret    : + everything bigger, extra sparks, lightning beams

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))
local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))

local AuraEffects = {}

local TEX = Config.Textures
local TAU = math.pi * 2

---------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------
local function seq2(a, b)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, a),
		ColorSequenceKeypoint.new(1, b),
	})
end

local function numSeq(points)
	local keypoints = {}
	for _, p in ipairs(points) do
		table.insert(keypoints, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(keypoints)
end

local function make(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function fxPart(props, parent)
	local part = make("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Massless = true,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	})
	for key, value in pairs(props) do
		part[key] = value
	end
	part.Parent = parent
	return part
end

local function getFxFolder()
	local folder = workspace:FindFirstChild("LocalAuraFX")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LocalAuraFX"
		folder.Parent = workspace
	end
	return folder
end

local function addTrail(part, color0, color1, halfLength, lifetime, parent)
	local a0 = make("Attachment", { Position = Vector3.new(0, halfLength, 0) }, part)
	local a1 = make("Attachment", { Position = Vector3.new(0, -halfLength, 0) }, part)
	return make("Trail", {
		Attachment0 = a0,
		Attachment1 = a1,
		Color = seq2(color0, color1),
		Transparency = numSeq({ { 0, 0.2 }, { 1, 1 } }),
		Lifetime = lifetime,
		LightEmission = 1,
		LightInfluence = 0,
		FaceCamera = true,
		MinLength = 0.05,
	}, parent or part)
end

---------------------------------------------------------------------
-- Aura handle (one per character)
---------------------------------------------------------------------
local Handle = {}
Handle.__index = Handle

function AuraEffects.Apply(character, auraName)
	local aura = AuraData.Get(auraName)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not aura or not root then
		return nil
	end

	local order = AuraData.Tiers[aura.Tier].Order
	local c1, c2 = aura.Colors[1], aura.Colors[2]
	local special = aura.Special

	local self = setmetatable({
		Character = character,
		Root = root,
		Aura = aura,
		Order = order,
		Time = math.random() * 10,
		PulseTimer = 0,
		ColorTimer = 0,
		Orbiters = {},
		RingParts = {},
		HaloParts = {},
		Emitters = {},
		Destroyed = false,
	}, Handle)

	local folder = make("Folder", { Name = "Aura_" .. character.Name }, getFxFolder())
	self.Folder = folder

	-- Invisible box around the body that particles spawn from.
	local body = fxPart({
		Name = "Body",
		Size = Vector3.new(3.5, 5.5, 3.5),
		Transparency = 1,
		CFrame = root.CFrame,
	}, folder)
	self.Body = body

	-- Invisible spinning pivot for beams.
	local pivot = fxPart({
		Name = "Pivot",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Transparency = 1,
		CFrame = root.CFrame,
	}, folder)
	self.Pivot = pivot

	local function emitter(props)
		local e = make("ParticleEmitter", {
			LightInfluence = 0,
			Color = seq2(c1, c2),
		}, body)
		for key, value in pairs(props) do
			e[key] = value
		end
		table.insert(self.Emitters, e)
		return e
	end

	-- Size multiplier so rarer tiers are bigger
	local scale = 0.8 + order * 0.15

	-- LAYER 1: core glow (everyone) ----------------------------------
	emitter({
		Texture = TEX.Sparkle,
		Rate = 6 + order * 4,
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Size = numSeq({ { 0, 0.15 * scale }, { 0.3, 0.45 * scale }, { 1, 0 } }),
		Transparency = numSeq({ { 0, 0.3 }, { 1, 1 } }),
		LightEmission = 1,
		RotSpeed = NumberRange.new(-90, 90),
		Rotation = NumberRange.new(0, 360),
	})

	self.Light = make("PointLight", {
		Color = c1,
		Range = 6 + order * 1.5,
		Brightness = 0.8 + order * 0.35,
		Shadows = false,
	}, body)

	-- LAYER 2: rising motes ------------------------------------------
	if order >= 2 then
		emitter({
			Texture = TEX.Spark,
			Rate = 4 + order * 3,
			Lifetime = NumberRange.new(1.2, 2),
			Speed = NumberRange.new(0, 0.5),
			Acceleration = Vector3.new(0, 2.5 + order * 0.4, 0),
			Size = numSeq({ { 0, 0.1 * scale }, { 0.5, 0.2 * scale }, { 1, 0 } }),
			Transparency = numSeq({ { 0, 0.1 }, { 1, 1 } }),
			LightEmission = 1,
			Color = seq2(c2, c1),
		})
	end

	-- LAYER 3: orbiting stars ----------------------------------------
	if order >= 3 then
		local count = order - 1 -- Rare 2, Epic 3 ... Secret 6
		for i = 1, count do
			local orb = fxPart({
				Name = "Orbiter",
				Shape = Enum.PartType.Ball,
				Material = Enum.Material.Neon,
				Size = Vector3.one * (0.3 + order * 0.04),
				Color = (i % 2 == 0) and c2 or c1,
				Transparency = 0,
				CFrame = root.CFrame,
			}, folder)
			addTrail(orb, c1, c2, orb.Size.Y * 0.5, 0.25 + order * 0.04)
			table.insert(self.Orbiters, {
				Part = orb,
				Offset = (i - 1) / count * TAU,
				Radius = 2.6 + (i % 2) * 0.6,
				Tilt = (i % 3 - 1) * 0.5,
				Speed = 2 + (i % 2) * 0.8,
			})
		end
	end

	-- LAYER 4: body trail + haze -------------------------------------
	if order >= 4 then
		addTrail(body, c1, c2, 2.4, 0.35, body)
		emitter({
			Texture = TEX.Smoke,
			Rate = 3 + order,
			Lifetime = NumberRange.new(1.5, 2.5),
			Speed = NumberRange.new(0.2, 0.8),
			SpreadAngle = Vector2.new(180, 180),
			Size = numSeq({ { 0, 1.5 }, { 1, 3.5 } }),
			Transparency = numSeq({ { 0, 1 }, { 0.3, 0.8 }, { 1, 1 } }),
			LightEmission = (special == "Dark") and 0 or 0.6,
			RotSpeed = NumberRange.new(-30, 30),
			Rotation = NumberRange.new(0, 360),
		})
	end

	-- LAYER 5: ground ring + spiral beams ----------------------------
	if order >= 5 then
		local segments = 14 + order * 2
		for i = 1, segments do
			local seg = fxPart({
				Name = "Ring",
				Material = Enum.Material.Neon,
				Size = Vector3.new(0.15, 0.15, 0.9),
				Color = (i % 2 == 0) and c1 or c2,
				Transparency = 0.15,
			}, folder)
			table.insert(self.RingParts, { Part = seg, Offset = (i - 1) / segments * TAU })
		end

		local beamCount = order - 3 -- Legendary 2, Mythic 3, Secret 4
		for i = 1, beamCount do
			local angle = (i - 1) / beamCount * TAU
			local bottom = make("Attachment", {
				Position = Vector3.new(math.cos(angle) * 2.5, -2.8, math.sin(angle) * 2.5),
			}, pivot)
			local top = make("Attachment", {
				Position = Vector3.new(math.cos(angle + 2) * 1.2, 3.2, math.sin(angle + 2) * 1.2),
			}, pivot)
			make("Beam", {
				Attachment0 = bottom,
				Attachment1 = top,
				Color = seq2(c1, c2),
				Transparency = numSeq({ { 0, 1 }, { 0.2, 0.3 }, { 0.8, 0.3 }, { 1, 1 } }),
				Width0 = 0.35,
				Width1 = 0.1,
				CurveSize0 = 3,
				CurveSize1 = -3,
				LightEmission = 1,
				LightInfluence = 0,
				FaceCamera = true,
				Segments = 20,
			}, pivot)
		end
	end

	-- LAYER 6: halo + pulses -----------------------------------------
	if order >= 6 then
		local haloSegments = 16
		for i = 1, haloSegments do
			local seg = fxPart({
				Name = "Halo",
				Material = Enum.Material.Neon,
				Size = Vector3.new(0.12, 0.12, 0.42),
				Color = c2,
				Transparency = 0.05,
			}, folder)
			table.insert(self.HaloParts, { Part = seg, Offset = (i - 1) / haloSegments * TAU })
		end
		self.PulseEvery = (order >= 7) and 1.4 or 2.2
	end

	-- LAYER 7: secret extras -----------------------------------------
	if order >= 7 then
		emitter({
			Texture = TEX.Spark,
			Rate = 25,
			Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(8, 14),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 4,
			Size = numSeq({ { 0, 0.3 }, { 1, 0 } }),
			LightEmission = 1,
		})
		-- crackling "lightning" beams between orbiters
		for i = 1, #self.Orbiters - 1, 2 do
			local a = make("Attachment", {}, self.Orbiters[i].Part)
			local b = make("Attachment", {}, self.Orbiters[i + 1].Part)
			make("Beam", {
				Attachment0 = a,
				Attachment1 = b,
				Color = seq2(c2, c1),
				Width0 = 0.08,
				Width1 = 0.08,
				LightEmission = 1,
				LightInfluence = 0,
				FaceCamera = true,
				Texture = "",
				CurveSize0 = 1.5,
				CurveSize1 = -1.5,
				Segments = 12,
			}, self.Orbiters[i].Part)
		end
	end

	-- SPECIAL EFFECTS -------------------------------------------------
	if special == "Fire" then
		emitter({
			Texture = TEX.Fire,
			Rate = 18,
			Lifetime = NumberRange.new(0.5, 1),
			Speed = NumberRange.new(1, 3),
			Acceleration = Vector3.new(0, 6, 0),
			Size = numSeq({ { 0, 1.2 }, { 1, 0 } }),
			Transparency = numSeq({ { 0, 0.4 }, { 1, 1 } }),
			LightEmission = 1,
			Color = seq2(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 70, 20)),
			RotSpeed = NumberRange.new(-60, 60),
			Rotation = NumberRange.new(0, 360),
		})
	elseif special == "Snow" then
		emitter({
			Texture = TEX.Sparkle,
			Rate = 14,
			Lifetime = NumberRange.new(2, 3),
			Speed = NumberRange.new(0, 0.5),
			Acceleration = Vector3.new(0, -1.5, 0),
			Size = numSeq({ { 0, 0.25 }, { 1, 0.15 } }),
			Transparency = numSeq({ { 0, 0.1 }, { 0.8, 0.3 }, { 1, 1 } }),
			LightEmission = 0.7,
			Color = seq2(Color3.new(1, 1, 1), c1),
			RotSpeed = NumberRange.new(-120, 120),
			Rotation = NumberRange.new(0, 360),
		})
	elseif special == "Dark" then
		emitter({
			Texture = TEX.Smoke,
			Rate = 10,
			Lifetime = NumberRange.new(1, 1.8),
			Speed = NumberRange.new(0.5, 1),
			Acceleration = Vector3.new(0, 1.5, 0),
			Size = numSeq({ { 0, 1 }, { 1, 2.5 } }),
			Transparency = numSeq({ { 0, 0.5 }, { 1, 1 } }),
			LightEmission = 0,
			Color = seq2(Color3.fromRGB(10, 5, 15), Color3.fromRGB(40, 20, 50)),
		})
	elseif special == "Inward" then
		emitter({
			Texture = TEX.Sparkle,
			Rate = 40,
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			Lifetime = NumberRange.new(0.5, 0.7),
			Speed = NumberRange.new(4, 6),
			Size = numSeq({ { 0, 0.3 }, { 1, 0 } }),
			Transparency = numSeq({ { 0, 0.6 }, { 0.5, 0 }, { 1, 1 } }),
			LightEmission = 1,
			Color = seq2(c2, c1),
		})
	end

	self.Rainbow = (special == "Rainbow")
	self:Update(0)
	return self
end

---------------------------------------------------------------------
-- Called every frame by the renderer
---------------------------------------------------------------------
function Handle:Update(dt)
	if self.Destroyed then
		return
	end
	local root = self.Root
	if not root.Parent then
		return
	end

	self.Time += dt
	local t = self.Time
	local pos = root.Position

	self.Body.CFrame = root.CFrame
	self.Pivot.CFrame = CFrame.new(pos) * CFrame.Angles(0, t * 1.6, 0)

	-- Orbiters
	for _, o in ipairs(self.Orbiters) do
		local a = t * o.Speed + o.Offset
		local offset = Vector3.new(math.cos(a) * o.Radius, math.sin(a * 1.3 + o.Offset) * 1.2 + o.Tilt, math.sin(a) * o.Radius)
		o.Part.CFrame = CFrame.new(pos + offset)
	end

	-- Ground ring (feet are ~3 studs below the root)
	if #self.RingParts > 0 then
		local radius = 3.2 + math.sin(t * 2) * 0.15
		local center = pos - Vector3.new(0, 2.9, 0)
		for _, r in ipairs(self.RingParts) do
			local a = r.Offset + t * 0.8
			local p = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
			r.Part.CFrame = CFrame.lookAt(p, center) * CFrame.Angles(0, math.pi / 2, 0)
		end
	end

	-- Halo above head
	if #self.HaloParts > 0 then
		local center = pos + Vector3.new(0, 3.1 + math.sin(t * 2.5) * 0.12, 0)
		for _, h in ipairs(self.HaloParts) do
			local a = h.Offset - t * 1.2
			local p = center + Vector3.new(math.cos(a) * 0.9, 0, math.sin(a) * 0.9)
			h.Part.CFrame = CFrame.lookAt(p, center) * CFrame.Angles(0, math.pi / 2, 0)
		end
	end

	-- Shockwave pulses
	if self.PulseEvery then
		self.PulseTimer += dt
		if self.PulseTimer >= self.PulseEvery then
			self.PulseTimer = 0
			self:Pulse()
		end
	end

	-- Rainbow color cycling
	if self.Rainbow then
		local hue = (t * 0.15) % 1
		local a = Color3.fromHSV(hue, 0.7, 1)
		local b = Color3.fromHSV((hue + 0.35) % 1, 0.7, 1)
		self.Light.Color = a
		for i, o in ipairs(self.Orbiters) do
			o.Part.Color = (i % 2 == 0) and b or a
		end
		self.ColorTimer += dt
		if self.ColorTimer > 0.2 then
			self.ColorTimer = 0
			local colorSeq = seq2(a, b)
			for _, e in ipairs(self.Emitters) do
				if e.Texture ~= TEX.Smoke then
					e.Color = colorSeq
				end
			end
		end
	end
end

function Handle:Pulse()
	local aura = self.Aura
	local root = self.Root
	local ring = fxPart({
		Name = "Pulse",
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Color = aura.Colors[2],
		Transparency = 0.3,
		Size = Vector3.new(0.15, 2, 2),
		CFrame = CFrame.new(root.Position - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.pi / 2),
	}, self.Folder)
	local grow = (self.Order >= 7) and 26 or 18
	TweenService:Create(ring, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, grow, grow),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 1.1)
end

function Handle:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	if self.Folder then
		self.Folder:Destroy()
	end
end

function Handle:IsAlive()
	return not self.Destroyed
		and self.Root.Parent ~= nil
		and self.Character.Parent ~= nil
end

---------------------------------------------------------------------
-- One-shot explosion (used when someone equips a new aura, and later
-- for duel hits). scale: 1 = normal.
---------------------------------------------------------------------
function AuraEffects.Burst(position, colors, scale)
	scale = scale or 1
	local c1, c2 = colors[1], colors[2]
	local folder = getFxFolder()

	local sphere = fxPart({
		Name = "BurstSphere",
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		Color = c1,
		Transparency = 0.2,
		Size = Vector3.one * 1,
		CFrame = CFrame.new(position),
	}, folder)
	TweenService:Create(sphere, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.one * 9 * scale,
		Transparency = 1,
	}):Play()
	Debris:AddItem(sphere, 0.5)

	local ring = fxPart({
		Name = "BurstRing",
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Color = c2,
		Transparency = 0.2,
		Size = Vector3.new(0.2, 1, 1),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
	}, folder)
	TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, 20 * scale, 20 * scale),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.8)

	local holder = fxPart({ Name = "BurstHolder", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(position) }, folder)
	local sparks = make("ParticleEmitter", {
		Texture = TEX.Sparkle,
		Enabled = false,
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(10 * scale, 22 * scale),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		Size = numSeq({ { 0, 0.6 * scale }, { 1, 0 } }),
		Transparency = numSeq({ { 0, 0 }, { 1, 1 } }),
		LightEmission = 1,
		LightInfluence = 0,
		Color = seq2(c1, c2),
		RotSpeed = NumberRange.new(-200, 200),
	}, holder)
	sparks:Emit(math.floor(40 * scale))
	local light = make("PointLight", { Color = c1, Range = 16 * scale, Brightness = 4 }, holder)
	TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
	Debris:AddItem(holder, 1.5)
end

return AuraEffects
