-- PetWorld (Script in ServerScriptService)
-- Builds a HATCHERY on the main island and on every rebirth island:
-- 3 giant eggs on pedestals. Walk up and press E to open the egg
-- (PetClient shows the odds and the Hatch button; RollService does the
-- hatching and takes the auras).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))

local old = workspace:FindFirstChild("PetHatcheries")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "PetHatcheries"

local FLAT = CFrame.Angles(0, 0, math.rad(90))

local function part(props, parent)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		if key ~= "ClassName" then
			p[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function addLight(target, color3, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color3
	light.Range = range
	light.Brightness = brightness
	light.Parent = target
end

local function billboard(target, text, offset, size, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.MaxDistance = maxDistance or 80
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.RichText = true
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Thickness = 2
	outline.Transparency = 0.2
	outline.Parent = label
	return gui
end

-- one giant egg on a pedestal
local function eggStand(parent, egg, position, facing, theme)
	local stand = Instance.new("Model")
	stand.Name = egg.Key
	stand.Parent = parent
	part({
		Name = "Pedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.2, 6.4, 6.4),
		CFrame = CFrame.new(position + Vector3.new(0, 1.1, 0)) * FLAT,
		Color = theme.Stone,
		Material = theme.StoneMaterial,
	}, stand)
	part({
		Name = "PedestalRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 6.9, 6.9),
		CFrame = CFrame.new(position + Vector3.new(0, 2.1, 0)) * FLAT,
		Color = egg.Color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, stand)
	local eggPart = part({
		Name = "Egg",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4.6, 6, 4.6),
		CFrame = CFrame.new(position + Vector3.new(0, 5.4, 0)),
		Color = egg.Color,
		Material = Enum.Material.SmoothPlastic,
	}, stand)
	eggPart:SetAttribute("EggKey", egg.Key)
	eggPart:SetAttribute("FX_EggBob", true)
	-- glowing spots on the egg
	for k = 1, 7 do
		local a = k * 2.4
		local y = math.sin(k * 1.7) * 1.8
		local r = 2.3 * math.sqrt(math.max(0.2, 1 - (y / 3) ^ 2))
		part({
			Name = "EggSpot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (0.5 + (k % 3) * 0.25),
			CFrame = CFrame.new(position + Vector3.new(math.cos(a) * r, 5.4 + y, math.sin(a) * r)),
			Color = egg.Color:Lerp(Color3.new(1, 1, 1), 0.6),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, stand)
	end
	addLight(eggPart, egg.Color, 16, 1.5)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = Config.Textures.Sparkle
	sparkles.Rate = 4
	sparkles.Lifetime = NumberRange.new(1.5, 2.5)
	sparkles.Speed = NumberRange.new(0.5, 1.5)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 0) })
	sparkles.LightEmission = 1
	sparkles.Color = ColorSequence.new(egg.Color, Color3.new(1, 1, 1))
	sparkles.Parent = eggPart

	-- name, price and odds
	local lines = { ("<b>%s</b>"):format(egg.Name:upper()),
		("<font color='#ffd76a'>Costs %dx %s</font>"):format(egg.Cost.Count, egg.Cost.Aura) }
	for _, entry in ipairs(egg.Pets) do
		local pet = PetData.Get(entry[1])
		local color = PetData.Rarities[pet.Rarity].Color
		table.insert(lines, ("<font color='#%s'>%s %s</font>"):format(color:ToHex(), entry[1], PetData.ChanceText(egg, entry[2])))
	end
	billboard(eggPart, table.concat(lines, "\n"), Vector3.new(0, 6.6, 0), UDim2.fromOffset(220, 150))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HatchPrompt"
	prompt.ActionText = "Open Egg"
	prompt.ObjectText = egg.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = eggPart
	return stand
end

local THEMES = {
	Main = { Stone = Color3.fromRGB(70, 60, 110), StoneMaterial = Enum.Material.Marble, Floor = Color3.fromRGB(45, 38, 75), Trim = Color3.fromRGB(255, 170, 120), Title = "🥚 COSMIC HATCHERY" },
	Frostfall = { Stone = Color3.fromRGB(150, 200, 240), StoneMaterial = Enum.Material.Ice, Floor = Color3.fromRGB(200, 225, 250), Trim = Color3.fromRGB(140, 230, 255), Title = "🥚 FROST HATCHERY" },
	Ember = { Stone = Color3.fromRGB(45, 30, 30), StoneMaterial = Enum.Material.Basalt, Floor = Color3.fromRGB(60, 42, 40), Trim = Color3.fromRGB(255, 120, 40), Title = "🥚 EMBER HATCHERY" },
	Nexus = { Stone = Color3.fromRGB(30, 20, 55), StoneMaterial = Enum.Material.Glass, Floor = Color3.fromRGB(22, 14, 40), Trim = Color3.fromRGB(255, 70, 220), Title = "🥚 NEXUS HATCHERY" },
}

local function hatchery(islandKey, center, islandCenter, needRebirths)
	local theme = THEMES[islandKey]
	local model = Instance.new("Model")
	model.Name = islandKey .. "Hatchery"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = root
	-- floor
	part({
		Name = "HatcheryFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 34, 34),
		CFrame = CFrame.new(center + Vector3.new(0, 0.3, 0)) * FLAT,
		Color = theme.Floor,
		Material = theme.StoneMaterial,
	}, model)
	part({
		Name = "HatcheryRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 35, 35),
		CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * FLAT,
		Color = theme.Trim,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, model)
	-- the eggs stand in an arc on the far side, facing the island's middle
	local toMiddle = Vector3.new(islandCenter.X - center.X, 0, islandCenter.Z - center.Z)
	toMiddle = toMiddle.Magnitude > 0.1 and toMiddle.Unit or Vector3.new(0, 0, -1)
	local side = Vector3.new(-toMiddle.Z, 0, toMiddle.X)
	for _, egg in ipairs(PetData.Eggs) do
		if egg.Island == islandKey then
			local offset = (egg.Slot - 2)
			local position = center - toMiddle * (5 + math.abs(offset) * -2.5) + side * offset * 9.5
			eggStand(model, egg, position, toMiddle, theme)
		end
	end
	-- an arch with the hatchery's name behind the eggs
	local back = center - toMiddle * 13
	local archCF = CFrame.lookAt(back, back + toMiddle)
	for _, s in ipairs({ -1, 1 }) do
		part({ Name = "ArchPillar", Size = Vector3.new(1.4, 12, 1.4), CFrame = archCF * CFrame.new(s * 14, 6, 0), Color = theme.Stone, Material = theme.StoneMaterial }, model)
		local orb = part({ Name = "ArchOrb", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, CFrame = archCF * CFrame.new(s * 14, 12.9, 0), Color = theme.Trim, Material = Enum.Material.Neon, CanCollide = false }, model)
		addLight(orb, theme.Trim, 18, 1.4)
	end
	local beam = part({ Name = "ArchBeam", Size = Vector3.new(30, 1.4, 1.6), CFrame = archCF * CFrame.new(0, 12.4, 0), Color = theme.Stone, Material = theme.StoneMaterial }, model)
	local title = theme.Title
	if needRebirths > 0 then
		title ..= ("\n<font size='40' color='#bfb4e1'>Rebirth %d island</font>"):format(needRebirths)
	end
	billboard(beam, title, Vector3.new(0, 3.2, 0), UDim2.fromOffset(380, 80), 160)
	-- a little "how it works" sign
	local sign = part({ Name = "InfoSign", Size = Vector3.new(8, 3.6, 0.4), CFrame = CFrame.lookAt(center + toMiddle * 13 + side * 10 + Vector3.new(0, 2.6, 0), center + side * 10 + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, math.pi, 0), Color = theme.Stone, Material = theme.StoneMaterial }, model)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = "🐾 Pay with AURAS!\nPets give you luck."
	text.TextColor3 = theme.Trim
	text.Parent = gui
end

hatchery("Main", Config.Places.Hatchery, Vector3.zero, 0)
for _, info in ipairs(Config.RebirthIslands) do
	if info.Hatchery then
		hatchery(info.Key, info.Center + info.Hatchery, info.Center, info.Rebirths)
	end
end

root.Parent = workspace
