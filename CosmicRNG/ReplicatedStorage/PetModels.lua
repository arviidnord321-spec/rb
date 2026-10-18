-- PetModels (ModuleScript in ReplicatedStorage)
-- Builds and animates the pets: chunky, soft "cosmic plushies" with big
-- glossy eyes, blushing cheeks, little feet and a cosmic touch each.
-- Used by PetClient for the pets that follow you AND the 3D previews.
--
--   PetModels.Build(petKey)                    -> Model
--   PetModels.Pose(model, cframe, t, phase, move)  (move = 0..1, how fast it walks)
--   PetModels.SetHidden(model, hidden)
--
-- Soft rounded bodies: the PetShapes script (server) makes one rounded cube
-- (ReplicatedStorage.PetShapes.RoundedCube) and every pet body is a resized
-- copy of it, so a whole body is just ONE part. If it isn't there (yet),
-- a 6-part rounded box is used instead.
-- Front of a pet = -Z (where it looks).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))

local PetModels = {}

local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local EYE_DARK = Color3.fromRGB(28, 24, 48)
local WHITE = Color3.new(1, 1, 1)
local BLUSH = Color3.fromRGB(255, 130, 170)
local GOLD = Color3.fromRGB(255, 205, 70)
local HALF_PI = math.pi / 2

local function lighter(color, amount)
	return color:Lerp(WHITE, amount)
end
local function darker(color, amount)
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

---------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------
-- props: Size, Color, Offset (CFrame from the body center), Role, Joint
-- (Vector3 the piece swings around), Paint ("Main"/"Accent" = recolored on
-- rainbow pets, "Fixed" = never), Shape, ClassName, Material, Transparency
local function piece(model, props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = SMOOTH
	for key, value in pairs(props) do
		if key ~= "ClassName" and key ~= "Offset" and key ~= "Role" and key ~= "Joint" and key ~= "Paint" then
			p[key] = value
		end
	end
	p:SetAttribute("Role", props.Role or "Body")
	p:SetAttribute("Paint", props.Paint or "Fixed")
	if props.Joint then
		p:SetAttribute("Joint", props.Joint)
	end
	p:SetAttribute("Offset", props.Offset or CFrame.new())
	p.CFrame = props.Offset or CFrame.new()
	p.Parent = model
	return p
end

local function roundTemplate()
	local folder = ReplicatedStorage:FindFirstChild("PetShapes")
	return folder and folder:FindFirstChild("RoundedCube")
end

-- a soft rounded box: one part when the rounded cube is ready
local function rounded(model, props)
	local template = roundTemplate()
	local size = props.Size
	if template then
		local p = template:Clone()
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.UsePartColor = true
		p.Size = size
		p.Color = props.Color
		p.Material = props.Material or SMOOTH
		p.Transparency = props.Transparency or 0
		p.Name = props.Name or "Round"
		p:SetAttribute("Role", props.Role or "Body")
		p:SetAttribute("Paint", props.Paint or "Fixed")
		if props.Joint then
			p:SetAttribute("Joint", props.Joint)
		end
		p:SetAttribute("Offset", props.Offset or CFrame.new())
		p.CFrame = props.Offset or CFrame.new()
		p.Parent = model
		return p
	end
	-- fallback: small things are plain blocks, bigger ones get round edges
	local radius = math.min(size.X, size.Z) * 0.2
	if math.min(size.X, size.Y, size.Z) < 0.9 then
		local copy = table.clone(props)
		return piece(model, copy)
	end
	local offset = props.Offset or CFrame.new()
	local main = table.clone(props)
	main.Size = Vector3.new(size.X, size.Y, size.Z - radius * 2)
	local first = piece(model, main)
	local cross = table.clone(props)
	cross.Name = (props.Name or "Round") .. "Fill"
	cross.Size = Vector3.new(size.X - radius * 2, size.Y, size.Z)
	piece(model, cross)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local edge = table.clone(props)
			edge.Name = (props.Name or "Round") .. "Fill"
			edge.Shape = Enum.PartType.Cylinder
			edge.Size = Vector3.new(size.Y, radius * 2, radius * 2)
			edge.Offset = offset * CFrame.new(sx * (size.X / 2 - radius), 0, sz * (size.Z / 2 - radius)) * CFrame.Angles(0, 0, HALF_PI)
			piece(model, edge)
		end
	end
	return first
end

-- a flat round disc facing forward (-Z), centered at position
local function disc(model, name, diameter, position, color, props)
	local data = props or {}
	data.Name = name
	data.Shape = Enum.PartType.Cylinder
	data.Size = Vector3.new(data.Thick or 0.06, diameter, diameter)
	data.Thick = nil
	data.Color = color
	data.Offset = CFrame.new(position) * CFrame.Angles(0, HALF_PI, 0)
	return piece(model, data)
end

local function ball(model, name, diameter, position, color, props)
	local data = props or {}
	data.Name = name
	data.Shape = Enum.PartType.Ball
	data.Size = Vector3.one * diameter
	data.Color = color
	data.Offset = data.Offset or CFrame.new(position)
	return piece(model, data)
end

---------------------------------------------------------------------
-- The face: big glossy eyes, cheeks, mouth
---------------------------------------------------------------------
-- f = { Z = front of the face, Y, Spread, Eye (size), Iris (color),
--       Mouth = "w"/"smile"/"open"/"teeth"/"o"/"fang", MouthY, Blush, Glow }
local function face(model, f)
	local z = f.Z
	local size = f.Eye or 0.56
	for _, side in ipairs({ -1, 1 }) do
		local x = side * f.Spread
		if f.Glow then
			-- spirit eyes: glowing, no shine
			disc(model, "Eye", size, Vector3.new(x, f.Y, z - 0.01), f.Iris, { Role = "Eye", Material = NEON })
			disc(model, "EyeShine", size * 0.3, Vector3.new(x + size * 0.15, f.Y + size * 0.17, z - 0.04), WHITE, { Role = "Eye" })
		else
			disc(model, "Eye", size, Vector3.new(x, f.Y, z - 0.01), EYE_DARK, { Role = "Eye" })
			disc(model, "Iris", size * 0.62, Vector3.new(x, f.Y - size * 0.14, z - 0.03), f.Iris, { Role = "Eye" })
			disc(model, "EyeShine", size * 0.36, Vector3.new(x + size * 0.14, f.Y + size * 0.16, z - 0.05), WHITE, { Role = "Eye", Material = NEON })
			disc(model, "EyeShine", size * 0.15, Vector3.new(x - size * 0.17, f.Y - size * 0.2, z - 0.05), WHITE, { Role = "Eye", Material = NEON })
		end
		-- closed eye for blinking (hidden until the pet blinks)
		piece(model, {
			Name = "Lid", Size = Vector3.new(size * 0.85, 0.08, 0.05), Color = EYE_DARK, Role = "Lid", Transparency = 1,
			Offset = CFrame.new(x, f.Y - size * 0.1, z - 0.03),
		})
		if f.Blush ~= false then
			disc(model, "Blush", size * 0.5, Vector3.new(side * (f.Spread + size * 0.62), f.Y - size * 0.62, z - 0.005), BLUSH,
				{ Transparency = 0.35 })
		end
	end

	local my = f.MouthY or (f.Y - size * 0.8)
	local mouth = f.Mouth or "smile"
	if mouth == "none" then
		return
	end
	local dark = Color3.fromRGB(60, 30, 50)
	if mouth == "w" or mouth == "teeth" then
		-- a little cat/bunny "w"
		for _, side in ipairs({ -1, 1 }) do
			for k, tilt in ipairs({ 0.6, -0.6 }) do
				local x = side * 0.09 + (k == 1 and -0.045 or 0.045) * side
				piece(model, { Name = "Mouth", Size = Vector3.new(0.13, 0.045, 0.04), Color = dark,
					Offset = CFrame.new(x, my, z - 0.02) * CFrame.Angles(0, 0, tilt * side) })
			end
		end
		disc(model, "Nose", 0.13, Vector3.new(0, my + 0.11, z - 0.02), BLUSH, { Thick = 0.07 })
		if mouth == "teeth" then
			piece(model, { Name = "Teeth", Size = Vector3.new(0.16, 0.13, 0.04), Color = WHITE, Offset = CFrame.new(0, my - 0.1, z - 0.02) })
		end
	elseif mouth == "open" or mouth == "o" then
		local d = mouth == "o" and 0.18 or 0.26
		disc(model, "Mouth", d, Vector3.new(0, my, z - 0.015), dark)
		if mouth == "open" then
			disc(model, "Tongue", d * 0.55, Vector3.new(0, my - d * 0.18, z - 0.03), Color3.fromRGB(255, 120, 140))
		end
	else
		for _, side in ipairs({ -1, 1 }) do
			piece(model, { Name = "Mouth", Size = Vector3.new(0.16, 0.045, 0.04), Color = dark,
				Offset = CFrame.new(side * 0.065, my, z - 0.02) * CFrame.Angles(0, 0, side * 0.45) })
		end
		if mouth == "fang" then
			piece(model, { ClassName = "WedgePart", Name = "Fang", Size = Vector3.new(0.04, 0.12, 0.08), Color = WHITE,
				Offset = CFrame.new(0.13, my - 0.08, z - 0.03) * CFrame.Angles(math.pi, HALF_PI, 0) })
		end
	end
end

-- stubby feet (they step when the pet walks)
local function feet(model, w, h, d, color)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			ball(model, "Foot", 0.62, Vector3.new(sx * w * 0.27, -h / 2 + 0.02, sz * d * 0.25), color,
				{ Role = (sx * sz > 0) and "FootA" or "FootB", Paint = "Main" })
		end
	end
end

-- right-angled triangle in the XY plane (thin in Z): tall edge on the
-- `tall` side (-1 = left, 1 = right)
local function triangle(model, name, size, position, tall, color, props)
	local data = props or {}
	data.ClassName = "WedgePart"
	data.Name = name
	data.Size = Vector3.new(size.Z, size.Y, size.X)
	data.Color = color
	data.Offset = (data.Offset or CFrame.new(position)) * CFrame.Angles(0, tall * HALF_PI, 0)
	return piece(model, data)
end

---------------------------------------------------------------------
-- The pets (c1 = main color, c2 = accent color)
---------------------------------------------------------------------
local BUILDERS = {}

-- squishy slime with a glowing star antenna
BUILDERS.Blob = function(model, c1, c2)
	local w, h, d = 2.5, 2, 2.3
	rounded(model, { Name = "Body", Size = Vector3.new(w, h, d), Color = c1, Paint = "Main" })
	-- a glossy shine on the top corner
	disc(model, "Gloss", 0.34, Vector3.new(-0.78, 0.62, -d / 2 - 0.005), lighter(c1, 0.6), { Paint = "Main" })
	feet(model, w, h, d, darker(c1, 0.12))
	local joint = Vector3.new(0, h / 2, 0.1)
	piece(model, { Name = "Antenna", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.75, 0.13, 0.13), Color = darker(c1, 0.15),
		Role = "Antenna", Joint = joint, Paint = "Main", Offset = CFrame.new(0, h / 2 + 0.33, 0.1) * CFrame.Angles(0, 0, HALF_PI) })
	ball(model, "AntennaTip", 0.42, Vector3.new(0, h / 2 + 0.78, 0.1), c2, { Role = "Antenna", Joint = joint, Material = NEON, Paint = "Accent" })
	face(model, { Z = -d / 2, Y = 0.2, Spread = 0.52, Eye = 0.6, Iris = lighter(c2, 0.1), Mouth = "open" })
end

-- cat / fox / pup: pointy ears, tabby stripes, curly tail
BUILDERS.Cat = function(model, c1, c2)
	local w, h, d = 2.25, 2.05, 2.05
	rounded(model, { Name = "Body", Size = Vector3.new(w, h, d), Color = c1, Paint = "Main" })
	for _, side in ipairs({ -1, 1 }) do
		local joint = Vector3.new(side * 0.6, h / 2, 0.1)
		triangle(model, "Ear", Vector3.new(0.72, 0.78, 0.3), Vector3.new(side * 0.62, h / 2 + 0.3, 0.1), side, c1,
			{ Role = "Ear", Joint = joint, Paint = "Main" })
		triangle(model, "EarInside", Vector3.new(0.42, 0.48, 0.08), Vector3.new(side * 0.7, h / 2 + 0.22, -0.08), side, lighter(c2, 0.2),
			{ Role = "Ear", Joint = joint, Paint = "Accent" })
	end
	for k = -1, 1 do
		piece(model, { Name = "Stripe", Size = Vector3.new(0.14, 0.06, 0.7 - math.abs(k) * 0.15), Color = c2, Paint = "Accent",
			Offset = CFrame.new(k * 0.3, h / 2 + 0.005, -0.35) })
	end
	feet(model, w, h, d, darker(c1, 0.1))
	local tailJoint = Vector3.new(0, -0.3, d / 2)
	piece(model, { Name = "Tail", Size = Vector3.new(0.32, 0.32, 0.8), Color = c1, Role = "Tail", Joint = tailJoint, Paint = "Main",
		Offset = CFrame.new(0, -0.15, d / 2 + 0.3) * CFrame.Angles(0.5, 0, 0) })
	piece(model, { Name = "Tail", Size = Vector3.new(0.32, 0.75, 0.32), Color = c1, Role = "Tail", Joint = tailJoint, Paint = "Main",
		Offset = CFrame.new(0, 0.35, d / 2 + 0.62) })
	ball(model, "TailTip", 0.42, Vector3.new(0, 0.78, d / 2 + 0.62), c2, { Role = "Tail", Joint = tailJoint, Paint = "Accent" })
	face(model, { Z = -d / 2, Y = 0.18, Spread = 0.48, Eye = 0.56, Iris = lighter(c2, 0.15), Mouth = "w" })
	-- cosmic gem on the forehead
	piece(model, { Name = "Gem", Size = Vector3.new(0.2, 0.2, 0.06), Color = c2, Material = NEON, Paint = "Accent",
		Offset = CFrame.new(0, 0.72, -d / 2 - 0.02) * CFrame.Angles(0, 0, math.pi / 4) })
end

-- long floppy ears, buck teeth, pom-pom tail
BUILDERS.Bunny = function(model, c1, c2)
	local w, h, d = 2.15, 1.95, 1.95
	rounded(model, { Name = "Body", Size = Vector3.new(w, h, d), Color = c1, Paint = "Main" })
	for _, side in ipairs({ -1, 1 }) do
		local joint = Vector3.new(side * 0.42, h / 2, 0.1)
		local earCF = CFrame.new(side * 0.47, h / 2 + 0.68, 0.1) * CFrame.Angles(0, 0, -side * 0.16)
		rounded(model, { Name = "Ear", Size = Vector3.new(0.5, 1.55, 0.32), Color = c1, Role = "Ear", Joint = joint, Paint = "Main", Offset = earCF })
		rounded(model, { Name = "EarInside", Size = Vector3.new(0.28, 1.1, 0.06), Color = lighter(c2, 0.3), Role = "Ear", Joint = joint,
			Paint = "Accent", Offset = earCF * CFrame.new(0, -0.05, -0.17) })
	end
	feet(model, w, h, d, darker(c1, 0.08))
	ball(model, "Tail", 0.75, Vector3.new(0, -0.35, d / 2 + 0.12), WHITE, { Role = "Tail", Joint = Vector3.new(0, -0.35, d / 2) })
	face(model, { Z = -d / 2, Y = 0.18, Spread = 0.46, Eye = 0.55, Iris = c2, Mouth = "teeth" })
end

-- round little owl/penguin/phoenix: belly, beak, wing flaps, feather tufts
BUILDERS.Bird = function(model, c1, c2)
	local w, h, d = 2.1, 2.1, 2
	rounded(model, { Name = "Body", Size = Vector3.new(w, h, d), Color = c1, Paint = "Main" })
	disc(model, "Belly", 1.15, Vector3.new(0, -0.38, -d / 2 - 0.005), lighter(c2, 0.35), { Paint = "Accent" })
	piece(model, { Name = "Beak", Size = Vector3.new(0.26, 0.26, 0.16), Color = Color3.fromRGB(255, 180, 60),
		Offset = CFrame.new(0, -0.05, -d / 2 - 0.06) * CFrame.Angles(0, 0, math.pi / 4) })
	for _, side in ipairs({ -1, 1 }) do
		rounded(model, { Name = "Wing", Size = Vector3.new(0.28, 1.05, 1.15), Color = c2, Paint = "Accent",
			Role = side < 0 and "WingL" or "WingR", Joint = Vector3.new(side * w / 2, 0.35, 0.1),
			Offset = CFrame.new(side * (w / 2 + 0.1), -0.1, 0.1) })
		triangle(model, "Tuft", Vector3.new(0.4, 0.5, 0.18), Vector3.new(side * 0.32, h / 2 + 0.2, -0.2), side, c2,
			{ Paint = "Accent", Role = "Ear", Joint = Vector3.new(side * 0.32, h / 2, -0.2) })
	end
	piece(model, { ClassName = "WedgePart", Name = "TailFeather", Size = Vector3.new(0.7, 0.18, 0.6), Color = c2, Paint = "Accent",
		Role = "Tail", Joint = Vector3.new(0, -0.6, d / 2), Offset = CFrame.new(0, -0.6, d / 2 + 0.25) * CFrame.Angles(math.pi, 0, 0) })
	feet(model, w * 0.8, h, d * 0.6, Color3.fromRGB(255, 170, 60))
	face(model, { Z = -d / 2, Y = 0.32, Spread = 0.47, Eye = 0.58, Iris = lighter(c2, 0.2), Mouth = "none" })
end

-- chubby fish: tail fin, back fin, side fins, a stripe
BUILDERS.Fish = function(model, c1, c2)
	local w, h, d = 2, 1.95, 2.6
	rounded(model, { Name = "Body", Size = Vector3.new(w, h, d), Color = c1, Paint = "Main" })
	rounded(model, { Name = "Stripe", Size = Vector3.new(w + 0.05, h + 0.05, 0.28), Color = c2, Paint = "Accent", Offset = CFrame.new(0, 0, 0.45) })
	local tailJoint = Vector3.new(0, 0, d / 2)
	piece(model, { ClassName = "WedgePart", Name = "Tail", Size = Vector3.new(0.14, 0.75, 0.85), Color = c2, Paint = "Accent", Role = "Tail",
		Joint = tailJoint, Offset = CFrame.new(0, 0.37, d / 2 + 0.38) })
	piece(model, { ClassName = "WedgePart", Name = "Tail", Size = Vector3.new(0.14, 0.75, 0.85), Color = c2, Paint = "Accent", Role = "Tail",
		Joint = tailJoint, Offset = CFrame.new(0, -0.37, d / 2 + 0.38) * CFrame.Angles(0, 0, math.pi) })
	piece(model, { ClassName = "WedgePart", Name = "BackFin", Size = Vector3.new(0.12, 0.5, 0.9), Color = c2, Paint = "Accent",
		Offset = CFrame.new(0, h / 2 + 0.22, 0.15) })
	for _, side in ipairs({ -1, 1 }) do
		rounded(model, { Name = "Fin", Size = Vector3.new(0.1, 0.35, 0.6), Color = c2, Paint = "Accent",
			Role = side < 0 and "FinL" or "FinR", Joint = Vector3.new(side * w / 2, -0.3, -0.2),
			Offset = CFrame.new(side * (w / 2 + 0.08), -0.35, -0.05) * CFrame.Angles(0, side * 0.5, 0) })
	end
	face(model, { Z = -d / 2, Y = 0.18, Spread = 0.45, Eye = 0.54, Iris = lighter(c2, 0.2), Mouth = "o" })
end

-- glowing see-through jelly with a bright core and wavy tentacles
BUILDERS.Jelly = function(model, c1, c2)
	local w, h, d = 2.3, 1.75, 2.1
	rounded(model, { Name = "Body", Size = Vector3.new(w, h, d), Color = c1, Transparency = 0.22, Paint = "Main" })
	ball(model, "Core", 1, Vector3.new(0, 0.05, 0.25), c2, { Material = NEON, Paint = "Accent" })
	for k, x in ipairs({ -0.55, 0, 0.55 }) do
		ball(model, "Spot", 0.32, Vector3.new(x, h / 2 - 0.02, (k - 2) * 0.35 + 0.1), lighter(c2, 0.3), { Material = NEON, Paint = "Accent" })
	end
	for k = 1, 4 do
		local x = (k - 2.5) * 0.5
		local joint = Vector3.new(x, -h / 2, 0.2)
		for seg = 1, 2 do
			piece(model, { Name = "Tentacle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.55, 0.24 - seg * 0.04, 0.24 - seg * 0.04),
				Color = seg == 1 and c1 or c2, Paint = seg == 1 and "Main" or "Accent", Role = "Tentacle", Joint = joint,
				Offset = CFrame.new(x + (seg == 2 and 0.06 or 0), -h / 2 - 0.22 - (seg - 1) * 0.45, 0.2) * CFrame.Angles(0, 0, HALF_PI) })
		end
	end
	face(model, { Z = -d / 2, Y = 0.12, Spread = 0.5, Eye = 0.55, Iris = lighter(c2, 0.2), Mouth = "smile" })
end

-- baby dragon: snout, horns, little wings, back spikes, spade tail
BUILDERS.Dragon = function(model, c1, c2)
	local w, h, d = 2.25, 2.05, 2.2
	rounded(model, { Name = "Body", Size = Vector3.new(w, h, d), Color = c1, Paint = "Main" })
	local snoutZ = -d / 2 - 0.2
	rounded(model, { Name = "Snout", Size = Vector3.new(1.35, 0.7, 0.55), Color = lighter(c1, 0.3), Paint = "Main",
		Offset = CFrame.new(0, -0.42, snoutZ + 0.05) })
	for _, side in ipairs({ -1, 1 }) do
		disc(model, "Nostril", 0.1, Vector3.new(side * 0.2, -0.3, snoutZ - 0.23), darker(c1, 0.5))
		piece(model, { ClassName = "WedgePart", Name = "Horn", Size = Vector3.new(0.24, 0.6, 0.42), Color = lighter(c2, 0.2), Paint = "Accent",
			Offset = CFrame.new(side * 0.62, h / 2 + 0.24, 0.2) })
		piece(model, { ClassName = "WedgePart", Name = "Wing", Size = Vector3.new(0.1, 0.95, 1.05), Color = c2, Paint = "Accent",
			Role = side < 0 and "WingL" or "WingR", Joint = Vector3.new(side * 0.85, 0.55, 0.55),
			Offset = CFrame.new(side * 1.25, 0.95, 0.75) * CFrame.Angles(0, 0, side * -0.55) })
	end
	for k, z in ipairs({ -0.15, 0.45 }) do
		piece(model, { ClassName = "WedgePart", Name = "Spike", Size = Vector3.new(0.12, 0.34 - k * 0.04, 0.38), Color = c2, Paint = "Accent",
			Offset = CFrame.new(0, h / 2 + 0.15, z) })
	end
	feet(model, w, h, d, darker(c1, 0.12))
	local tailJoint = Vector3.new(0, -0.5, d / 2)
	piece(model, { Name = "Tail", Size = Vector3.new(0.45, 0.42, 1), Color = c1, Paint = "Main", Role = "Tail", Joint = tailJoint,
		Offset = CFrame.new(0, -0.45, d / 2 + 0.4) * CFrame.Angles(-0.25, 0, 0) })
	piece(model, { Name = "TailTip", Size = Vector3.new(0.5, 0.5, 0.12), Color = c2, Paint = "Accent", Role = "Tail", Joint = tailJoint,
		Offset = CFrame.new(0, -0.2, d / 2 + 0.95) * CFrame.Angles(0, 0, math.pi / 4) })
	face(model, { Z = -d / 2, Y = 0.35, Spread = 0.5, Eye = 0.55, Iris = lighter(c2, 0.1), Mouth = "fang", MouthY = -0.55 })
	-- the mouth sits on the snout, so push those pieces forward
	for _, p in ipairs(model:GetChildren()) do
		if p.Name == "Mouth" or p.Name == "Fang" then
			local offset = p:GetAttribute("Offset")
			offset = CFrame.new(0, 0, -0.42) * offset
			p:SetAttribute("Offset", offset)
			p.CFrame = offset
		end
	end
end

-- a chubby star with a face
BUILDERS.Star = function(model, c1, c2)
	piece(model, { Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.85, 1.75, 1.75), Color = c1, Paint = "Main",
		Offset = CFrame.Angles(0, HALF_PI, 0) })
	for k = 0, 4 do
		local turn = CFrame.Angles(0, 0, -k * math.pi * 2 / 5)
		for _, half in ipairs({ -1, 1 }) do
			triangle(model, "Point", Vector3.new(0.5, 1.05, 0.62), nil, -half, c1,
				{ Paint = "Main", Offset = turn * CFrame.new(half * 0.25, 1.22, 0) })
		end
	end
	ball(model, "Glow", 0.6, Vector3.new(0, 0, 0.32), c2, { Material = NEON, Paint = "Accent" })
	face(model, { Z = -0.43, Y = 0.12, Spread = 0.33, Eye = 0.44, Iris = c2, Mouth = "open", MouthY = -0.3 })
end

-- a little spirit: see-through body, flame crown, wavy bottom, orbiting sparks
BUILDERS.Wisp = function(model, c1, c2)
	local w, h, d = 2.05, 2.15, 2
	rounded(model, { Name = "Body", Size = Vector3.new(w, h, d), Color = c1, Transparency = 0.12, Paint = "Main" })
	for k, x in ipairs({ -0.62, 0, 0.62 }) do
		ball(model, "Wave", 0.72, Vector3.new(x, -h / 2 + 0.02, (k % 2) * 0.2), c1, { Paint = "Main", Transparency = 0.12 })
	end
	for k, x in ipairs({ -0.45, 0, 0.45 }) do
		local size = k == 2 and Vector3.new(0.45, 0.85, 0.3) or Vector3.new(0.4, 0.55, 0.28)
		triangle(model, "Flame", size, Vector3.new(x + (k == 2 and 0 or (x > 0 and -0.1 or 0.1)), h / 2 + size.Y / 2 - 0.05, 0), x > 0 and 1 or -1, c2,
			{ Material = NEON, Paint = "Accent", Role = "Flame", Joint = Vector3.new(x, h / 2, 0) })
	end
	for k = 1, 3 do
		ball(model, "Orbiter", 0.34, Vector3.new(1.5, 0, 0), c2, { Material = NEON, Role = "Orbit" .. k, Paint = "Accent" })
	end
	face(model, { Z = -d / 2, Y = 0.15, Spread = 0.46, Eye = 0.55, Iris = c2, Glow = true, Mouth = "o" })
end

---------------------------------------------------------------------
-- Extra flair for the best pets
---------------------------------------------------------------------
local function topOf(model)
	local top = 1
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and (p:GetAttribute("Role") == "Body" or p:GetAttribute("Role") == "Ear") then
			top = math.max(top, p.CFrame.Position.Y + p.Size.Y / 2)
		end
	end
	return top
end

local function addFlair(model, pet)
	local rarity = pet.Rarity
	local top = topOf(model)
	if rarity == "Legendary" then
		-- a tiny spinning star gem floating above
		piece(model, { Name = "FloatGem", Size = Vector3.new(0.38, 0.38, 0.12), Color = GOLD, Material = NEON, Role = "Float",
			Offset = CFrame.new(0, top + 0.55, 0) * CFrame.Angles(0, 0, math.pi / 4) })
	elseif rarity == "Mythic" then
		-- a halo of little lights
		for k = 1, 8 do
			local a = k / 8 * math.pi * 2
			ball(model, "Halo", 0.22, Vector3.new(math.cos(a) * 0.75, top + 0.45, math.sin(a) * 0.75), pet.Colors[2],
				{ Material = NEON, Role = "Halo", Paint = "Accent" })
		end
	elseif rarity == "Exclusive" then
		-- a golden crown
		piece(model, { Name = "Crown", Size = Vector3.new(1, 0.28, 1), Color = GOLD, Reflectance = 0.2, Offset = CFrame.new(0, top + 0.12, 0.1) })
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				ball(model, "CrownTip", 0.24, Vector3.new(sx * 0.42, top + 0.4, 0.1 + sz * 0.42), Color3.fromRGB(255, 120, 200), { Material = NEON })
			end
		end
	end
end

local function sparkles(parent, color, rate, size)
	local e = Instance.new("ParticleEmitter")
	e.Texture = Config.Textures.Sparkle
	e.Rate = rate
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(0.3, 1.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.LightEmission = 1
	e.Color = color
	e.Parent = parent
	return e
end

---------------------------------------------------------------------
-- Build
---------------------------------------------------------------------
function PetModels.Build(petKey)
	local pet = PetData.Get(petKey)
	if not pet then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Pet_" .. petKey
	model:SetAttribute("Shape", pet.Shape)
	local builder = BUILDERS[pet.Shape] or BUILDERS.Blob
	builder(model, pet.Colors[1], pet.Colors[2])
	addFlair(model, pet)
	model.PrimaryPart = model:FindFirstChild("Body")

	if pet.Variant == "Golden" then
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("Paint") ~= "Fixed" then
				p.Reflectance = 0.3
			end
		end
	elseif pet.Variant == "Rainbow" then
		model:SetAttribute("Rainbow", true)
	end

	local body = model.PrimaryPart
	if body then
		if pet.Variant then
			sparkles(body, pet.Variant == "Golden" and ColorSequence.new(Color3.fromRGB(255, 220, 90))
				or ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 80)),
					ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
				}), 10, 0.35)
		end
		local order = PetData.Rarities[pet.Rarity].Order
		if order >= 4 then
			sparkles(body, ColorSequence.new(pet.Colors[2]), order * 1.5, 0.28)
		end
	end
	return model
end

---------------------------------------------------------------------
-- Animation
---------------------------------------------------------------------
local cache = setmetatable({}, { __mode = "k" })

local function entriesFor(model)
	local entries = cache[model]
	if entries then
		return entries
	end
	entries = { Parts = {}, List = {}, CFrames = {}, Eyes = {}, Lids = {}, Paint = {} }
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			local joint = p:GetAttribute("Joint")
			table.insert(entries.List, {
				Part = p,
				Offset = p:GetAttribute("Offset") or CFrame.new(),
				Role = p:GetAttribute("Role") or "Body",
				Joint = joint,
				JointIn = joint and CFrame.new(joint) or nil,
				JointOut = joint and CFrame.new(-joint) or nil,
			})
			table.insert(entries.Parts, p)
			local role = p:GetAttribute("Role")
			if role == "Eye" then
				table.insert(entries.Eyes, { Part = p, Transparency = p.Transparency })
			elseif role == "Lid" then
				table.insert(entries.Lids, p)
			end
			if p:GetAttribute("Paint") ~= "Fixed" then
				table.insert(entries.Paint, p)
			end
		end
	end
	entries.Shape = model:GetAttribute("Shape") or "Blob"
	entries.Rainbow = model:GetAttribute("Rainbow")
	cache[model] = entries
	return entries
end

local function swing(entry, pose, rotation)
	return pose * entry.JointIn * rotation * entry.JointOut * entry.Offset
end

-- t = time, phase = a per-pet random number, move = 0 (standing) .. 1 (running)
function PetModels.Pose(model, base, t, phase, move)
	local entries = entriesFor(model)
	local shape = entries.Shape
	move = move or 0
	phase = phase or 0
	local idle = 1 - move

	-- whole-body motion
	local pose = base
	if shape == "Blob" then
		pose = base * CFrame.new(0, math.abs(math.sin(t * (3 + move * 4) + phase)) * (0.25 + move * 0.4), 0)
	elseif shape == "Bunny" then
		pose = base * CFrame.new(0, math.abs(math.sin(t * (2.5 + move * 3) + phase)) * (0.25 + move * 0.7), 0)
	elseif shape == "Fish" then
		pose = base * CFrame.Angles(0, math.sin(t * 4 + phase) * 0.15, 0) * CFrame.new(0, math.sin(t * 2 + phase) * 0.15, 0)
	elseif shape == "Jelly" then
		pose = base * CFrame.new(0, math.sin(t * 1.6 + phase) * 0.35, 0)
	elseif shape == "Star" then
		pose = base * CFrame.Angles(0, 0, math.sin(t * 2 + phase) * 0.22)
	elseif shape == "Wisp" then
		pose = base * CFrame.new(0, math.sin(t * 2.2 + phase) * 0.25, 0) * CFrame.Angles(0, 0, math.sin(t * 1.3 + phase) * 0.06)
	elseif shape == "Bird" or shape == "Dragon" then
		pose = base * CFrame.new(0, math.sin(t * 3 + phase) * 0.12, 0) * CFrame.Angles(-move * 0.12, 0, 0)
	else
		-- walking waddle
		pose = base * CFrame.new(0, math.abs(math.sin(t * 8 + phase)) * 0.18 * move, 0)
			* CFrame.Angles(0, 0, math.sin(t * 8 + phase) * 0.07 * move)
	end
	-- breathing / squish when standing still
	pose = pose * CFrame.Angles(math.sin(t * 1.7 + phase) * 0.03 * idle, 0, 0)

	local step = math.sin(t * 9 + phase) * move
	local cframes = entries.CFrames
	for index, entry in ipairs(entries.List) do
		local role = entry.Role
		local cf
		if entry.Joint then
			local rotation
			if role == "WingL" then
				rotation = CFrame.Angles(0, 0, math.sin(t * 11 + phase) * 0.55)
			elseif role == "WingR" then
				rotation = CFrame.Angles(0, 0, -math.sin(t * 11 + phase) * 0.55)
			elseif role == "FinL" then
				rotation = CFrame.Angles(0, math.sin(t * 6 + phase) * 0.4, 0)
			elseif role == "FinR" then
				rotation = CFrame.Angles(0, -math.sin(t * 6 + phase) * 0.4, 0)
			elseif role == "Tail" then
				rotation = CFrame.Angles(0, math.sin(t * (shape == "Fish" and 7 or 3.5) + phase) * 0.4, 0)
			elseif role == "Ear" then
				rotation = CFrame.Angles(math.sin(t * 2.2 + phase) * 0.08 - move * 0.15, 0, 0)
			elseif role == "Tentacle" then
				rotation = CFrame.Angles(math.sin(t * 3 + phase + entry.Joint.X * 2) * 0.35, 0, math.cos(t * 2.4 + phase + entry.Joint.X) * 0.2)
			elseif role == "Antenna" then
				rotation = CFrame.Angles(math.sin(t * 3 + phase) * 0.2, 0, math.sin(t * 2.3 + phase) * 0.25)
			elseif role == "Flame" then
				rotation = CFrame.Angles(math.sin(t * 7 + phase + entry.Joint.X * 3) * 0.12, 0, math.sin(t * 5 + phase + entry.Joint.X) * 0.15)
			else
				rotation = CFrame.new()
			end
			cf = swing(entry, pose, rotation)
		elseif role == "FootA" then
			cf = pose * CFrame.new(0, math.max(0, step) * 0.25, 0) * entry.Offset
		elseif role == "FootB" then
			cf = pose * CFrame.new(0, math.max(0, -step) * 0.25, 0) * entry.Offset
		elseif role == "Halo" then
			cf = pose * CFrame.Angles(0, t * 1.2, 0) * entry.Offset
		elseif role == "Float" then
			local offset = entry.Offset
			cf = pose * CFrame.new(offset.Position + Vector3.new(0, math.sin(t * 2.5 + phase) * 0.12, 0)) * CFrame.Angles(0, t * 2, math.pi / 4)
		elseif string.sub(role, 1, 5) == "Orbit" then
			local k = tonumber(string.sub(role, 6)) or 1
			local a = t * 2.6 + k * (math.pi * 2 / 3)
			cf = pose * CFrame.new(math.cos(a) * 1.65, math.sin(a * 2) * 0.4 + 0.1, math.sin(a) * 1.65)
		else
			cf = pose * entry.Offset
		end
		cframes[index] = cf
	end

	if model:IsDescendantOf(workspace) then
		workspace:BulkMoveTo(entries.Parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	else
		for index, entry in ipairs(entries.List) do
			entry.Part.CFrame = cframes[index]
		end
	end

	-- blink every few seconds
	local blinking = (t + phase * 2.3) % 3.6 < 0.13
	if blinking ~= entries.Blinking then
		entries.Blinking = blinking
		for _, eye in ipairs(entries.Eyes) do
			eye.Part.Transparency = blinking and 1 or eye.Transparency
		end
		for _, lid in ipairs(entries.Lids) do
			lid.Transparency = blinking and 0 or 1
		end
	end

	-- rainbow pets slowly cycle through every color
	if entries.Rainbow then
		for index, p in ipairs(entries.Paint) do
			p.Color = Color3.fromHSV((t * 0.2 + phase + index * 0.035) % 1, 0.6, 1)
		end
	end
end

-- hide/show a pet for this player (far away, in a duel...)
function PetModels.SetHidden(model, hidden)
	local entries = entriesFor(model)
	if entries.Hidden == hidden then
		return
	end
	entries.Hidden = hidden
	local value = hidden and 1 or 0
	for _, p in ipairs(entries.Parts) do
		p.LocalTransparencyModifier = value
	end
	local body = model.PrimaryPart
	if body then
		for _, child in ipairs(body:GetChildren()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = not hidden
			end
		end
	end
end

return PetModels
