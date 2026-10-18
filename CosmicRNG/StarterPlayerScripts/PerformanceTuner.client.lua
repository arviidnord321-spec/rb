-- PerformanceTuner (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Keeps the game smooth, even on phones:
--   * lights: only the nearest ones are switched on (a "light budget"),
--     no light casts shadows, and all scenery lights are a bit dimmer
--   * particles and trails far away from you are paused
--   * how much it allows depends on your Roblox graphics quality setting
-- Only map scenery is touched (never your character, duels or effects).

local Players = game:GetService("Players")

local camera = workspace.CurrentCamera
local player = Players.LocalPlayer

-- the map folders/models whose scenery we manage
local ROOTS = {
	"CosmicIsland", "CosmicSky", "LuckyIsland", "ParkourCourses", "RebirthIslands",
	"PetHatcheries", "DuelIsland", "CosmicSkyDecor", "IslandDetails",
}

local LIGHT_DIM = 0.7 -- scenery lights are turned down to 70%

-- budgets for low / medium / high graphics
local PRESETS = {
	Low = { Lights = 12, LightRange = 90, Particles = 120, Trails = 160, RateScale = 0.45 },
	Medium = { Lights = 24, LightRange = 130, Particles = 190, Trails = 260, RateScale = 0.7 },
	High = { Lights = 40, LightRange = 170, Particles = 260, Trails = 360, RateScale = 1 },
}

local function currentPreset()
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok or level == Enum.SavedQualitySetting.Automatic then
		return PRESETS.Medium
	end
	local number = tonumber(string.match(tostring(level), "%d+")) or 5
	if number <= 3 then
		return PRESETS.Low
	elseif number <= 7 then
		return PRESETS.Medium
	end
	return PRESETS.High
end

local lights = {} -- { Light, BaseBrightness }
local emitters = {} -- { Emitter, BaseRate }
local trails = {} -- { Trail }
local known = {}

local function positionOf(instance)
	local parent = instance.Parent
	if parent and parent:IsA("BasePart") then
		return parent.Position
	elseif parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	end
	return nil
end

local function register(item)
	if known[item] then
		return
	end
	if item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") then
		known[item] = true
		item.Shadows = false
		item.Brightness *= LIGHT_DIM
		table.insert(lights, { Light = item })
	elseif item:IsA("ParticleEmitter") then
		known[item] = true
		table.insert(emitters, { Emitter = item, BaseRate = item.Rate })
	elseif item:IsA("Trail") then
		known[item] = true
		table.insert(trails, { Trail = item })
	elseif item:IsA("BasePart") then
		-- scenery doesn't need to cast shadows (a big saving)
		if item.Transparency > 0.2 or item.Material == Enum.Material.Neon or not item.CanCollide then
			item.CastShadow = false
		end
	end
end

local function watchRoot(root)
	for _, item in ipairs(root:GetDescendants()) do
		register(item)
	end
	root.DescendantAdded:Connect(register)
end

for _, name in ipairs(ROOTS) do
	task.spawn(function()
		local root = workspace:WaitForChild(name, 60)
		if root then
			watchRoot(root)
		end
	end)
end
workspace.ChildAdded:Connect(function(child)
	if table.find(ROOTS, child.Name) then
		watchRoot(child)
	end
end)

-- every half second: switch on the nearest lights, pause far particles
task.spawn(function()
	while true do
		task.wait(0.5)
		local preset = currentPreset()
		local eye = camera.CFrame.Position
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local center = root and root.Position or eye

		-- lights: nearest first, up to the budget
		local candidates = {}
		for i = #lights, 1, -1 do
			local entry = lights[i]
			local light = entry.Light
			if not light.Parent then
				table.remove(lights, i)
			else
				local position = positionOf(light)
				local distance = position and (position - center).Magnitude or math.huge
				entry.Distance = distance
				if distance < preset.LightRange then
					table.insert(candidates, entry)
				else
					light.Enabled = false
				end
			end
		end
		table.sort(candidates, function(a, b)
			return a.Distance < b.Distance
		end)
		for index, entry in ipairs(candidates) do
			entry.Light.Enabled = index <= preset.Lights
		end

		-- particles: only near you, and fewer on low graphics
		for i = #emitters, 1, -1 do
			local entry = emitters[i]
			local emitter = entry.Emitter
			if not emitter.Parent then
				table.remove(emitters, i)
			else
				local position = positionOf(emitter)
				local near = position ~= nil and (position - eye).Magnitude < preset.Particles
				emitter.Enabled = near
				if near then
					emitter.Rate = entry.BaseRate * preset.RateScale
				end
			end
		end

		-- trails (sky creatures)
		for i = #trails, 1, -1 do
			local trail = trails[i].Trail
			if not trail.Parent then
				table.remove(trails, i)
			else
				local position = positionOf(trail)
				trail.Enabled = position ~= nil and (position - eye).Magnitude < preset.Trails
			end
		end
	end
end)
