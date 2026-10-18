-- PetShapes (Script in ServerScriptService)
-- Makes ONE soft rounded cube (ReplicatedStorage.PetShapes.RoundedCube).
-- Every pet body, ear and wing is a resized copy of it, so a soft rounded
-- body costs a single part. If this fails, pets use a 6-part rounded box.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GeometryService = game:GetService("GeometryService")

local SIZE = 5 -- the cube is 5 studs...
local RADIUS = 1 -- ...with corners rounded by 1 stud (20%)

local folder = Instance.new("Folder")
folder.Name = "PetShapes"

local temp = Instance.new("Folder")
temp.Name = "PetShapeParts"
temp.Parent = workspace

local function part(shape, size, cframe)
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = CFrame.new(0, 10000, 0) * cframe
	p.Anchored = true
	p.CanCollide = false
	p.Parent = temp
	return p
end

local ok, result = pcall(function()
	local inner = SIZE - RADIUS * 2
	local half = inner / 2
	local block = Enum.PartType.Block
	local main = part(block, Vector3.new(SIZE, inner, inner), CFrame.new())
	local others = {
		part(block, Vector3.new(inner, SIZE, inner), CFrame.new()),
		part(block, Vector3.new(inner, inner, SIZE), CFrame.new()),
	}
	local diameter = RADIUS * 2
	for _, a in ipairs({ -1, 1 }) do
		for _, b in ipairs({ -1, 1 }) do
			-- the 12 rounded edges (cylinders run along X by default)
			table.insert(others, part(Enum.PartType.Cylinder, Vector3.new(inner, diameter, diameter), CFrame.new(0, a * half, b * half)))
			table.insert(others, part(Enum.PartType.Cylinder, Vector3.new(inner, diameter, diameter),
				CFrame.new(a * half, 0, b * half) * CFrame.Angles(0, 0, math.pi / 2)))
			table.insert(others, part(Enum.PartType.Cylinder, Vector3.new(inner, diameter, diameter),
				CFrame.new(a * half, b * half, 0) * CFrame.Angles(0, math.pi / 2, 0)))
			-- the 8 round corners
			for _, c in ipairs({ -1, 1 }) do
				table.insert(others, part(Enum.PartType.Ball, Vector3.one * diameter, CFrame.new(a * half, b * half, c * half)))
			end
		end
	end
	local unions = GeometryService:UnionAsync(main, others, {
		CollisionFidelity = Enum.CollisionFidelity.Box,
		RenderFidelity = Enum.RenderFidelity.Precise,
		SplitApart = false,
	})
	return unions[1]
end)
temp:Destroy()

if ok and result then
	result.Name = "RoundedCube"
	result.Anchored = true
	result.CanCollide = false
	result.CanQuery = false
	result.CanTouch = false
	result.CastShadow = false
	result.UsePartColor = true
	result.CFrame = CFrame.new()
	result.Parent = folder
else
	warn("PetShapes: couldn't make the rounded cube, pets use simpler bodies:", result)
end
folder.Parent = ReplicatedStorage
