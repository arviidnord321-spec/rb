-- Parkour (Script in ServerScriptService)
-- Builds the obby courses and runs them. Main island:
--   STARSTEP TRAIL (medium) - a long curving trail of small platforms with
--                             moving platforms, spinning laser bars,
--                             vanishing platforms and a jump pad
--   VOID TOWER (hard)       - a 42-step spiral around a tall tower: thin
--                             beams, blinking platforms, spinners, movers,
--                             half-deadly platforms and a jump pad
-- Rebirth islands (harder, more luck):
--   GLACIER CLIMB (Frostfall)  - slippery ice floes + a spiral up an ice spire
--   MAGMA RUN     (Ember)      - over a lava sea: sinking rocks, fire bars
--   PULSE GRID    (Neon Nexus) - a square spiral of platforms blinking in a wave
-- Step on the start pad to begin. There are NO checkpoints: falling, a laser
-- or a red pad sends you back to the start. Reaching the finish gives a luck
-- boost (with a cooldown).
-- Vanishing/moving platforms, spinners and jump pads are animated by the
-- ParkourClient script. Spinners are timed by the server clock, so the
-- server knows exactly where every laser bar is.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local Luck = require(ReplicatedStorage:WaitForChild("Luck"))

local P = Config.Places
local rand = Random.new(99)
local FLAT = CFrame.Angles(0, 0, math.rad(90))

---------------------------------------------------------------------
-- Remote for messages to the player (start / checkpoint / finish)
---------------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("CosmicRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "CosmicRemotes"
	remotes.Parent = ReplicatedStorage
end
local ParkourEvent = remotes:FindFirstChild("ParkourEvent")
if not ParkourEvent then
	ParkourEvent = Instance.new("RemoteEvent")
	ParkourEvent.Name = "ParkourEvent"
	ParkourEvent.Parent = remotes
end

-- Quests count finished courses (RollService listens)
local ServerStorage = game:GetService("ServerStorage")
local serverEvents = ServerStorage:FindFirstChild("CosmicServerEvents")
if not serverEvents then
	serverEvents = Instance.new("Folder")
	serverEvents.Name = "CosmicServerEvents"
	serverEvents.Parent = ServerStorage
end
local questEvent = serverEvents:FindFirstChild("QuestEvent")
if not questEvent then
	questEvent = Instance.new("BindableEvent")
	questEvent.Name = "QuestEvent"
	questEvent.Parent = serverEvents
end

---------------------------------------------------------------------
-- Build helpers
---------------------------------------------------------------------
local old = workspace:FindFirstChild("ParkourCourses")
if old then
	old:Destroy()
end
local root = Instance.new("Model")
root.Name = "ParkourCourses"
root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

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
	p.Parent = props.Parent or root
	return p
end

local function addLight(target, color3, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color3
	light.Range = range
	light.Brightness = brightness
	light.Parent = target
end

local function billboard(target, title, subtitle, color3, offset)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(320, 80)
	gui.StudsOffset = offset or Vector3.new(0, 6, 0)
	gui.MaxDistance = 160
	gui.LightInfluence = 0
	gui.Parent = target
	local function line(text, y, height, color, font)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, y)
		label.Size = UDim2.fromScale(1, height)
		label.Font = font
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = color
		label.Parent = gui
		local outline = Instance.new("UIStroke")
		outline.Thickness = 2
		outline.Transparency = 0.2
		outline.Parent = label
	end
	line(title, 0, 0.6, color3, Enum.Font.FredokaOne)
	if subtitle then
		line(subtitle, 0.6, 0.4, Color3.fromRGB(230, 225, 255), Enum.Font.GothamBold)
	end
end

local function rewardText(course)
	return ("Finish for x%s luck (%d min)"):format(Luck.Format(course.LuckMultiplier), course.BoostMinutes)
end

---------------------------------------------------------------------
-- Course data, filled while building:
--   Start / Finish = pad parts, Checkpoints = { pad, ... }, Kills = { part, ... }
---------------------------------------------------------------------
local courses = {}

local function newCourse(key, model)
	local course = {
		Key = key,
		Settings = Config.Parkour[key],
		Model = model,
		Checkpoints = {},
		Kills = {},
		Spinners = {},
	}
	courses[key] = course
	return course
end

-- A normal platform: dark top with a glowing rim
local function platform(model, cf, size, topColor, rimColor)
	local top = part({
		Name = "Platform",
		Size = size,
		CFrame = cf,
		Color = topColor,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	part({
		Name = "Rim",
		Size = size + Vector3.new(0.35, -0.6, 0.35),
		CFrame = cf * CFrame.new(0, -0.15, 0),
		Color = rimColor,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	return top
end

local function vanishPlatform(model, cf, size, period, onTime, offset, color3)
	local p = part({
		Name = "VanishPlatform",
		Size = size,
		CFrame = cf,
		Color = color3 or Color3.fromRGB(255, 200, 80),
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		Parent = model,
	})
	p:SetAttribute("Vanish", true)
	p:SetAttribute("VanishPeriod", period)
	p:SetAttribute("VanishOn", onTime)
	p:SetAttribute("VanishOffset", offset)
	return p
end

local function jumpPad(model, cf, size, launch)
	local p = part({
		Name = "JumpPad",
		Size = size,
		CFrame = cf,
		Color = Color3.fromRGB(80, 255, 140),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	p:SetAttribute("Launch", launch)
	local arrow = part({
		Name = "JumpArrow",
		Size = Vector3.new(1, 0.2, 1),
		CFrame = cf * CFrame.new(0, size.Y / 2 + 0.15, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = Color3.new(1, 1, 1),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	arrow.Name = "JumpArrow"
	billboard(p, "⬆ JUMP PAD", nil, Color3.fromRGB(120, 255, 170), Vector3.new(0, 3, 0))
	return p
end

local function killPad(course, model, cf, size, color3)
	local p = part({
		Name = "KillPad",
		Size = size,
		CFrame = cf,
		Color = color3 or Color3.fromRGB(255, 40, 70),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	table.insert(course.Kills, p)
	return p
end


-- A platform with a spinning red laser bar on top: jump over it!
local function spinnerPlatform(course, model, cf, topColor, rimColor, speed, offset)
	platform(model, cf, Vector3.new(6, 1, 6), topColor, rimColor)
	local center = (cf * CFrame.new(0, 0.5 + 1.2, 0)).Position
	local length = 6.6
	local bar = part({
		Name = "SpinnerBar",
		Size = Vector3.new(0.7, 0.7, length),
		CFrame = CFrame.new(center),
		Color = Color3.fromRGB(255, 40, 70),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	bar:SetAttribute("Spinner", true)
	bar:SetAttribute("SpinSpeed", speed)
	bar:SetAttribute("SpinOffset", offset)
	bar:SetAttribute("SpinCenter", center)
	part({
		Name = "SpinnerHub",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.2,
		CFrame = CFrame.new(center),
		Color = Color3.fromRGB(255, 120, 140),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	table.insert(course.Spinners, { Center = center, Length = length, Speed = speed, Offset = offset })
end

-- A platform that slides back and forth (it carries you, see ParkourClient)
local function movingPlatform(model, cf, size, amplitude, period, offset, color3)
	local p = part({
		Name = "MovingPlatform",
		Size = size,
		CFrame = cf,
		Color = color3 or Color3.fromRGB(90, 200, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.1,
		Parent = model,
	})
	p:SetAttribute("MoveAmplitude", amplitude)
	p:SetAttribute("MovePeriod", period)
	p:SetAttribute("MoveOffset", offset)
	return p
end

-- Slippery ice: you keep sliding (ParkourClient handles the sliding)
local function icePlatform(model, cf, size)
	local p = part({
		Name = "IcePlatform",
		Size = size,
		CFrame = cf,
		Color = Color3.fromRGB(170, 225, 255),
		Material = Enum.Material.Ice,
		Transparency = 0.1,
		Reflectance = 0.2,
		CustomPhysicalProperties = PhysicalProperties.new(0.9, 0, 0, 100, 1),
		Parent = model,
	})
	p:SetAttribute("Slippery", true)
	part({
		Name = "Rim",
		Size = size + Vector3.new(0.3, -0.6, 0.3),
		CFrame = cf * CFrame.new(0, -0.15, 0),
		Color = Color3.fromRGB(120, 230, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	return p
end

-- There are no checkpoints any more: these spots are just wider "rest"
-- platforms. Falling (or a laser / red pad) always sends you back to the START.
local function checkpointPad(_course, model, cf, _number, color3)
	local pad = platform(model, cf, Vector3.new(5, 1, 5), Color3.fromRGB(40, 34, 64), color3)
	pad.Name = "RestPlatform"
	return pad
end

local function startPad(course, model, position, color3)
	local pad = part({
		Name = "StartPad",
		Size = Vector3.new(8, 1, 8),
		CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)),
		Color = Color3.fromRGB(40, 34, 64),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	part({
		Name = "StartGlow",
		Size = Vector3.new(8.6, 0.4, 8.6),
		CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)),
		Color = color3,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	billboard(pad, "🏁 " .. string.upper(course.Settings.Name), rewardText(course.Settings), color3, Vector3.new(0, 7, 0))
	course.Start = pad
	return pad
end

local function finishPad(course, model, cf, color3)
	local pad = platform(model, cf, Vector3.new(12, 1, 12), Color3.fromRGB(40, 34, 64), color3)
	pad.Name = "FinishPad"
	-- an arch over the finish
	for _, side in ipairs({ -1, 1 }) do
		part({
			Name = "FinishPost",
			Size = Vector3.new(0.8, 8, 0.8),
			CFrame = cf * CFrame.new(side * 5, 4.5, 0),
			Color = color3,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = model,
		})
	end
	part({
		Name = "FinishBar",
		Size = Vector3.new(10.8, 0.8, 0.8),
		CFrame = cf * CFrame.new(0, 8.9, 0),
		Color = color3,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	local trophy = part({
		Name = "SpinGem",
		Size = Vector3.one * 1.8,
		CFrame = cf * CFrame.new(0, 4, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color = Color3.fromRGB(255, 220, 90),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	addLight(trophy, Color3.fromRGB(255, 220, 120), 24, 2)
	billboard(pad, "🏆 FINISH", rewardText(course.Settings), Color3.fromRGB(255, 220, 90), Vector3.new(0, 11, 0))
	course.Finish = pad
	return pad
end

---------------------------------------------------------------------
-- STARSTEP TRAIL (medium): a long curve of small platforms
---------------------------------------------------------------------
do
	local model = Instance.new("Model")
	model.Name = "StarstepTrail"
	model.Parent = root
	local course = newCourse("Starstep", model)
	local TOP = Color3.fromRGB(40, 60, 70)
	local RIM = Color3.fromRGB(90, 240, 200)

	local start = P.StarstepStart
	startPad(course, model, start, RIM)

	local STEPS = 26
	local position = Vector3.new(start.X, 1, start.Z)
	local checkpointNumber = 0
	for i = 1, STEPS do
		local heading = math.pi + i * math.rad(4.5)
		local direction = Vector3.new(math.cos(heading), 0, math.sin(heading))
		local across = Vector3.new(-direction.Z, 0, direction.X)
		local gap, rise = 10, 1.3
		if i == 21 then
			gap, rise = 6.5, 10 -- high up past the jump pad
		end
		position += direction * gap + Vector3.new(0, rise, 0)
		local cf = CFrame.lookAt(position, position + direction) * CFrame.new(0, -0.5, 0)

		if i == STEPS then
			finishPad(course, model, cf * CFrame.new(0, 0, -3), RIM)
		elseif i == 9 or i == 18 then
			checkpointNumber += 1
			checkpointPad(course, model, cf, checkpointNumber, RIM)
		elseif i == 20 then
			jumpPad(model, cf, Vector3.new(4, 1, 4), Vector3.new(0, 75, 0))
		elseif i == 5 or i == 14 or i == 24 then
			spinnerPlatform(course, model, cf, TOP, RIM, 2.2, i * 0.7)
		elseif i % 5 == 2 then
			movingPlatform(model, cf, Vector3.new(3.6, 1, 3.6), across * 5, 3.2, i * 0.4)
		elseif i == 10 or i == 11 or i == 19 then
			vanishPlatform(model, cf, Vector3.new(3.6, 1, 3.6), 2.6, 1.6, i * 0.9)
		else
			platform(model, cf, Vector3.new(3.2, 1, 3.2), TOP, RIM)
		end

		if i % 3 == 0 then
			local star = part({
				Name = "TrailStar",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.8,
				CFrame = CFrame.new(position + Vector3.new(rand:NextNumber(-5, 5), rand:NextNumber(4, 7), rand:NextNumber(-5, 5))),
				Color = RIM,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = model,
			})
			addLight(star, RIM, 8, 0.8)
		end
	end
end

---------------------------------------------------------------------
-- VOID TOWER (hard): a 42-step spiral climb around a dark tower
---------------------------------------------------------------------
do
	local model = Instance.new("Model")
	model.Name = "VoidTower"
	model.Parent = root
	local course = newCourse("VoidTower", model)
	local TOP = Color3.fromRGB(30, 20, 45)
	local RIM = Color3.fromRGB(170, 90, 255)

	local start = P.VoidTowerStart
	startPad(course, model, start, RIM)

	local outward = Vector3.new(start.X, 0, start.Z).Unit
	local towerCenter = Vector3.new(start.X, 0, start.Z) + outward * 21
	local RADIUS = 13
	local STEPS = 42
	local toStart = Vector3.new(start.X, 0, start.Z) - towerCenter
	local angle0 = math.atan2(toStart.Z, toStart.X)

	local BEAMS = { [7] = true, [16] = true, [25] = true, [34] = true, [39] = true }
	local SPINNERS = { [11] = true, [23] = true, [31] = true, [37] = true }
	local MOVERS = { [13] = true, [26] = true, [35] = true }
	local HALF_DEADLY = { [5] = true, [17] = true, [29] = true, [40] = true }

	local height = 3
	local checkpointNumber = 0
	local finishY
	for i = 1, STEPS do
		local angle = angle0 + (i - 1) * 0.6
		if i == 21 then
			height += 10 -- above the jump pad
		elseif i > 1 then
			height += 2.6
		end
		local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local position = towerCenter + radial * RADIUS + Vector3.new(0, height, 0)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local cf = CFrame.lookAt(position, position + tangent)

		if i == STEPS then
			finishY = height
			finishPad(course, model, CFrame.new(towerCenter + Vector3.new(0, height, 0)) * CFrame.lookAt(Vector3.zero, -tangent).Rotation, RIM)
		elseif i == 14 or i == 28 then
			checkpointNumber += 1
			checkpointPad(course, model, cf, checkpointNumber, RIM)
		elseif i == 20 then
			jumpPad(model, cf, Vector3.new(3.5, 1, 3.5), Vector3.new(0, 80, 0))
		elseif BEAMS[i] then
			platform(model, cf, Vector3.new(1, 0.5, 7.5), TOP, RIM)
		elseif SPINNERS[i] then
			spinnerPlatform(course, model, cf, TOP, RIM, 2.8, i * 0.53)
		elseif MOVERS[i] then
			movingPlatform(model, cf, Vector3.new(3, 1, 3), radial * 3.5, 2.4, i * 0.31)
		elseif HALF_DEADLY[i] then
			-- half safe, half deadly: land on the inner side
			local inward = -radial
			platform(model, CFrame.new(position + inward * 1.1) * cf.Rotation, Vector3.new(2.2, 1, 3.4), TOP, RIM)
			killPad(course, model, CFrame.new(position - inward * 1.1) * cf.Rotation, Vector3.new(2.2, 1, 3.4))
		elseif i % 3 == 0 then
			vanishPlatform(model, cf, Vector3.new(3, 1, 3), 2.2, 1.2, i * 0.37)
		else
			platform(model, cf, Vector3.new(3, 1, 3), TOP, RIM)
		end
	end

	local towerHeight = finishY + 22
	part({
		Name = "Tower",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(towerHeight, 8, 8),
		CFrame = CFrame.new(towerCenter + Vector3.new(0, finishY - towerHeight / 2 - 0.6, 0)) * FLAT,
		Color = Color3.fromRGB(25, 15, 40),
		Material = Enum.Material.Slate,
		Parent = model,
	})
	for y = -10, finishY - 5, 10 do
		part({
			Name = "TowerRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 8.6, 8.6),
			CFrame = CFrame.new(towerCenter + Vector3.new(0, y, 0)) * FLAT,
			Color = RIM,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = model,
		})
	end
	local beacon = part({
		Name = "Beacon",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3,
		CFrame = CFrame.new(towerCenter + Vector3.new(0, finishY + 12, 0)),
		Color = RIM,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	addLight(beacon, RIM, 40, 3)
end


---------------------------------------------------------------------
-- REBIRTH ISLAND COURSES
-- Each starts at the far edge of its island and heads out over the void.
---------------------------------------------------------------------
local function islandGround(info)
	return function(position)
		local offset = position - info.Center
		local flat = Vector3.new(offset.X, 0, offset.Z)
		return flat.Magnitude < info.Radius - 2 and offset.Y < 6 and offset.Y > -3
	end
end

local function islandInfo(key)
	for _, info in ipairs(Config.RebirthIslands) do
		if info.Key == key then
			return info
		end
	end
	return nil
end

-- start pad on the island edge + a little gateway behind it
local function islandStart(course, model, info, color3)
	local C = info.Center
	local start = C + Vector3.new(0, 0, info.Radius - 8)
	startPad(course, model, start, color3)
	course.OnGround = islandGround(info)
	for _, side in ipairs({ -1, 1 }) do
		part({
			Name = "StartGatePost",
			Size = Vector3.new(0.8, 7, 0.8),
			CFrame = CFrame.new(start + Vector3.new(side * 4.6, 3.5, -4.6)),
			Color = color3,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = model,
		})
	end
	return start
end

---------------------------------------------------------------------
-- ❄️ GLACIER CLIMB: slippery ice floes, then a spiral up an ice spire
---------------------------------------------------------------------
do
	local info = islandInfo("Frostfall")
	local model = Instance.new("Model")
	model.Name = "GlacierClimb"
	model.Parent = root
	local course = newCourse("GlacierClimb", model)
	local TOP = Color3.fromRGB(60, 90, 130)
	local RIM = Color3.fromRGB(140, 230, 255)
	local C = info.Center
	local start = islandStart(course, model, info, RIM)

	-- part 1: ice floes zig-zagging out over the void
	local position = Vector3.new(start.X, C.Y + 1, start.Z + 4)
	for i = 1, 12 do
		local side = (i % 2 == 0) and 1 or -1
		position = Vector3.new(C.X + side * 4.5, position.Y + 1, position.Z + 8.5)
		local cf = CFrame.new(position) * CFrame.new(0, -0.5, 0)
		if i == 12 then
			checkpointPad(course, model, cf, 1, RIM)
		elseif i == 4 or i == 9 then
			movingPlatform(model, cf, Vector3.new(4, 1, 4), Vector3.new(6, 0, 0), 2.8, i * 0.5, Color3.fromRGB(150, 220, 255))
		elseif i == 6 then
			spinnerPlatform(course, model, cf, TOP, RIM, 2.6, 0.4)
		elseif i % 3 == 2 then
			vanishPlatform(model, cf, Vector3.new(3.6, 1, 3.6), 2.4, 1.4, i * 0.6, Color3.fromRGB(200, 240, 255))
		else
			icePlatform(model, cf, Vector3.new(4, 1, 4))
		end
	end

	-- part 2: spiral around the ice spire
	local spire = Vector3.new(C.X, 0, position.Z + 20)
	local toCheckpoint = Vector3.new(position.X, 0, position.Z) - spire
	local angle0 = math.atan2(toCheckpoint.Z, toCheckpoint.X)
	local height = position.Y
	local RADIUS = 14
	local STEPS = 24
	local finishY
	for k = 1, STEPS do
		local angle = angle0 + k * 0.55
		if k == 17 then
			height += 10
		else
			height += 2.4
		end
		local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local p = spire + radial * RADIUS + Vector3.new(0, height, 0)
		local cf = CFrame.lookAt(p, p + tangent) * CFrame.new(0, -0.5, 0)
		if k == STEPS then
			finishY = height
			finishPad(course, model, CFrame.new(spire + Vector3.new(0, height, 0)) * CFrame.lookAt(Vector3.zero, -tangent).Rotation, RIM)
		elseif k == 12 then
			checkpointPad(course, model, cf, 2, RIM)
		elseif k == 16 then
			jumpPad(model, cf, Vector3.new(3.5, 1, 3.5), Vector3.new(0, 80, 0))
		elseif k == 5 or k == 14 or k == 21 then
			spinnerPlatform(course, model, cf, TOP, RIM, 3, k * 0.6)
		elseif k == 8 or k == 19 then
			icePlatform(model, cf, Vector3.new(1.2, 0.6, 7)) -- thin icy beam
		elseif k == 10 or k == 22 then
			movingPlatform(model, cf, Vector3.new(3.4, 1, 3.4), radial * 4, 2.2, k * 0.4, Color3.fromRGB(150, 220, 255))
		elseif k % 4 == 3 then
			vanishPlatform(model, cf, Vector3.new(3.2, 1, 3.2), 2.2, 1.2, k * 0.45, Color3.fromRGB(200, 240, 255))
		else
			icePlatform(model, cf, Vector3.new(3.6, 1, 3.6))
		end
	end

	-- the spire itself, with icicles
	local spireHeight = finishY + 40
	part({
		Name = "IceSpire",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(spireHeight, 9, 9),
		CFrame = CFrame.new(spire + Vector3.new(0, finishY - spireHeight / 2 - 0.6, 0)) * FLAT,
		Color = Color3.fromRGB(120, 190, 240),
		Material = Enum.Material.Glacier,
		Parent = model,
	})
	for y = C.Y, finishY - 6, 12 do
		part({
			Name = "SpireRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 9.6, 9.6),
			CFrame = CFrame.new(spire + Vector3.new(0, y, 0)) * FLAT,
			Color = RIM,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = model,
		})
	end
	local beacon = part({
		Name = "Beacon",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3,
		CFrame = CFrame.new(spire + Vector3.new(0, finishY + 12, 0)),
		Color = RIM,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	addLight(beacon, RIM, 40, 3)
end

---------------------------------------------------------------------
-- 🔥 MAGMA RUN: over a lava sea - sinking rocks, fire bars, lava halves
---------------------------------------------------------------------
do
	local info = islandInfo("Ember")
	local model = Instance.new("Model")
	model.Name = "MagmaRun"
	model.Parent = root
	local course = newCourse("MagmaRun", model)
	local TOP = Color3.fromRGB(50, 35, 35)
	local RIM = Color3.fromRGB(255, 120, 40)
	local LAVA = Color3.fromRGB(255, 100, 25)
	local C = info.Center
	local start = islandStart(course, model, info, RIM)

	local STEPS = 38
	local SPINNERS = { [6] = true, [15] = true, [24] = true, [33] = true }
	local HALF_LAVA = { [4] = true, [13] = true, [28] = true, [35] = true }
	local BEAMS = { [9] = true, [22] = true, [30] = true }
	local SINKERS = { [3] = true, [10] = true, [17] = true, [21] = true, [31] = true, [36] = true }
	local SLIDERS = { [11] = true, [25] = true }
	local position = Vector3.new(start.X, C.Y + 1, start.Z + 4)
	local lastZ
	for i = 1, STEPS do
		local x = math.sin(i * 0.38) * 14
		local rise = (i == 20) and 10 or 1.1
		position = Vector3.new(C.X + x, position.Y + rise, position.Z + 7.6)
		local nextPos = Vector3.new(C.X + math.sin((i + 1) * 0.38) * 14, position.Y, position.Z + 7.6)
		local direction = (nextPos - position).Unit
		local across = Vector3.new(-direction.Z, 0, direction.X)
		local cf = CFrame.lookAt(position, position + direction) * CFrame.new(0, -0.5, 0)
		lastZ = position.Z
		if i == STEPS then
			finishPad(course, model, cf * CFrame.new(0, 0, -4), RIM)
		elseif i == 12 or i == 26 then
			checkpointPad(course, model, cf, (i == 12) and 1 or 2, RIM)
		elseif i == 19 then
			jumpPad(model, cf, Vector3.new(3.5, 1, 3.5), Vector3.new(0, 82, 0))
		elseif SPINNERS[i] then
			spinnerPlatform(course, model, cf, TOP, RIM, 3, i * 0.5)
		elseif HALF_LAVA[i] then
			local p = platform(model, cf * CFrame.new(-1.1, 0, 0), Vector3.new(2.2, 1, 3.6), TOP, RIM)
			p.Material = Enum.Material.Basalt
			killPad(course, model, cf * CFrame.new(1.1, 0, 0), Vector3.new(2.2, 1, 3.6), LAVA)
		elseif BEAMS[i] then
			local p = platform(model, cf, Vector3.new(1, 0.6, 7), TOP, RIM)
			p.Material = Enum.Material.Basalt
		elseif SINKERS[i] then
			-- rocks that bob up and down out of the lava
			movingPlatform(model, cf, Vector3.new(3.6, 1, 3.6), Vector3.new(0, 3, 0), 2.6, i * 0.7, Color3.fromRGB(110, 70, 60))
		elseif SLIDERS[i] then
			movingPlatform(model, cf, Vector3.new(3.4, 1, 3.4), across * 6, 2.2, i * 0.3, Color3.fromRGB(255, 160, 80))
		elseif i % 4 == 2 then
			vanishPlatform(model, cf, Vector3.new(3.4, 1, 3.4), 2.3, 1.3, i * 0.55, Color3.fromRGB(255, 150, 60))
		else
			local p = platform(model, cf, Vector3.new(3.4, 1, 3.4), TOP, RIM)
			p.Material = Enum.Material.Basalt
		end
	end

	-- the lava sea under the whole course (touch it = back to checkpoint)
	local seaStart, seaEnd = start.Z + 8, lastZ + 14
	local sea = part({
		Name = "LavaSea",
		Size = Vector3.new(60, 1, seaEnd - seaStart),
		CFrame = CFrame.new(C.X, C.Y - 4, (seaStart + seaEnd) / 2),
		Color = LAVA,
		Material = Enum.Material.Neon,
		Transparency = 0.05,
		Parent = model,
	})
	table.insert(course.Kills, sea)
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = Config.Textures.Fire
	fire.Rate = 40
	fire.Lifetime = NumberRange.new(0.8, 1.6)
	fire.Speed = NumberRange.new(1, 4)
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), LAVA)
	fire.LightEmission = 1
	fire.EmissionDirection = Enum.NormalId.Top
	fire.Parent = sea
	for z = seaStart + 10, seaEnd - 5, 30 do
		local glow = part({ Name = "LavaGlow", Size = Vector3.one, CFrame = CFrame.new(C.X, C.Y - 2, z), Transparency = 1, CanCollide = false, Parent = model })
		addLight(glow, LAVA, 40, 2)
	end
	-- dark rock walls along the sides of the sea
	for _, side in ipairs({ -1, 1 }) do
		part({
			Name = "SeaWall",
			Size = Vector3.new(3, 6, seaEnd - seaStart),
			CFrame = CFrame.new(C.X + side * 31.5, C.Y - 2.5, (seaStart + seaEnd) / 2),
			Color = Color3.fromRGB(40, 28, 28),
			Material = Enum.Material.Basalt,
			Parent = model,
		})
	end
end

---------------------------------------------------------------------
-- 💠 PULSE GRID: a square spiral of platforms that pulse to a beat
---------------------------------------------------------------------
do
	local info = islandInfo("Nexus")
	local model = Instance.new("Model")
	model.Name = "PulseGrid"
	model.Parent = root
	local course = newCourse("PulseGrid", model)
	local TOP = Color3.fromRGB(25, 15, 45)
	local RIM = Color3.fromRGB(255, 70, 220)
	local CYAN = Color3.fromRGB(60, 230, 255)
	local C = info.Center
	local start = islandStart(course, model, info, RIM)

	-- legs of the square spiral: direction + number of steps
	local legs = {
		{ Vector3.new(0, 0, 1), 10 },
		{ Vector3.new(1, 0, 0), 8 },
		{ Vector3.new(0, 0, 1), 8 },
		{ Vector3.new(-1, 0, 0), 14 },
	}
	local SPINNERS = { [7] = true, [16] = true, [25] = true, [34] = true }
	local BEAMS = { [4] = true, [19] = true, [29] = true }
	local MOVERS = { [12] = true, [21] = true, [31] = true, [37] = true }
	local HALF_DEADLY = { [9] = true, [33] = true }
	local position = Vector3.new(start.X, C.Y + 1, start.Z + 2)
	local i = 0
	local total = 0
	for _, leg in ipairs(legs) do
		total += leg[2]
	end
	for _, leg in ipairs(legs) do
		local direction = leg[1]
		local across = Vector3.new(-direction.Z, 0, direction.X)
		for _ = 1, leg[2] do
			i += 1
			local rise = (i == 24) and 10 or 1.3
			position += direction * 8 + Vector3.new(0, rise, 0)
			local cf = CFrame.lookAt(position, position + direction) * CFrame.new(0, -0.5, 0)
			if i == total then
				finishPad(course, model, cf * CFrame.new(0, 0, -4), RIM)
			elseif i == 13 or i == 27 then
				checkpointPad(course, model, cf, (i == 13) and 1 or 2, RIM)
			elseif i == 23 then
				jumpPad(model, cf, Vector3.new(3.5, 1, 3.5), Vector3.new(0, 82, 0))
			elseif SPINNERS[i] then
				spinnerPlatform(course, model, cf, TOP, RIM, 3.3, i * 0.45)
			elseif BEAMS[i] then
				platform(model, cf, Vector3.new(0.9, 0.6, 7), TOP, CYAN)
			elseif MOVERS[i] then
				movingPlatform(model, cf, Vector3.new(3.2, 1, 3.2), across * 6.5, 1.9, i * 0.33, CYAN)
			elseif HALF_DEADLY[i] then
				platform(model, cf * CFrame.new(-1.1, 0, 0), Vector3.new(2.2, 1, 3.4), TOP, RIM)
				killPad(course, model, cf * CFrame.new(1.1, 0, 0), Vector3.new(2.2, 1, 3.4))
			elseif i % 2 == 0 then
				-- pulse platforms: they blink in a wave along the course
				vanishPlatform(model, cf, Vector3.new(3.4, 1, 3.4), 2.4, 1.5, -i * 0.3, (i % 4 == 0) and RIM or CYAN)
			else
				platform(model, cf, Vector3.new(3.2, 1, 3.2), TOP, (i % 3 == 0) and CYAN or RIM)
			end
			-- neon grid posts under each step
			if i % 2 == 1 then
				part({
					Name = "GridPost",
					Size = Vector3.new(0.3, 14, 0.3),
					CFrame = CFrame.new(position + Vector3.new(0, -8, 0)),
					Color = (i % 4 == 1) and CYAN or RIM,
					Material = Enum.Material.Neon,
					CanCollide = false,
					CanQuery = false,
					Parent = model,
				})
			end
		end
	end
end

root.Parent = workspace

---------------------------------------------------------------------
-- RUNNING THE COURSES (checked by position every 0.1s)
---------------------------------------------------------------------
local runs = {} -- [player] = { Course = course, Started = time, Checkpoint = number }

-- Is this position standing on (or touching) the given pad?
local function onPad(pad, position, extraHeight)
	local localPos = pad.CFrame:PointToObjectSpace(position)
	local half = pad.Size / 2
	return math.abs(localPos.X) <= half.X + 0.6
		and math.abs(localPos.Z) <= half.Z + 0.6
		and localPos.Y >= -half.Y - 1
		and localPos.Y <= half.Y + (extraHeight or 4)
end

-- Is this player being hit by a spinning laser bar right now?
local function hitBySpinner(spinner, position)
	local feet, head = position.Y - 3.1, position.Y + 1.6
	if spinner.Center.Y < feet or spinner.Center.Y > head then
		return false
	end
	local angle = Luck.Now() * spinner.Speed + spinner.Offset
	local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
	local a = spinner.Center - direction * (spinner.Length / 2)
	local b = spinner.Center + direction * (spinner.Length / 2)
	local point = Vector3.new(position.X, spinner.Center.Y, position.Z)
	local ab = b - a
	local t = math.clamp((point - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (point - (a + ab * t)).Magnitude < 1.1
end

local function spotAbove(pad)
	return CFrame.new(pad.Position + Vector3.new(0, pad.Size.Y / 2 + 3, 0))
end

local function stopRun(player, reason)
	if runs[player] then
		runs[player] = nil
		player:SetAttribute("Checkpoint", nil)
		player:SetAttribute("ParkourCourse", nil)
		player:SetAttribute("ParkourStart", nil)
		if reason then
			ParkourEvent:FireClient(player, { Type = reason })
		end
	end
end

local function startRun(player, course)
	runs[player] = { Course = course, Started = Luck.Now(), Checkpoint = 0 }
	player:SetAttribute("Checkpoint", spotAbove(course.Start))
	player:SetAttribute("ParkourCourse", course.Settings.Name)
	player:SetAttribute("ParkourStart", Luck.Now())
	ParkourEvent:FireClient(player, { Type = "Start", Course = course.Settings.Name })
end

local function finishRun(player, course)
	local run = runs[player]
	local seconds = Luck.Now() - run.Started
	local now = Luck.Now()
	local cooldownKey = "ParkourCooldown_" .. course.Key
	local cooldownEnd = player:GetAttribute(cooldownKey) or 0
	local rewarded = cooldownEnd <= now
	if rewarded then
		local settings = course.Settings
		local currentEnd = player:GetAttribute("ParkourLuckEnd") or 0
		local currentMultiplier = (currentEnd > now) and (player:GetAttribute("ParkourLuckMultiplier") or 1) or 1
		player:SetAttribute("ParkourLuckMultiplier", math.max(currentMultiplier, settings.LuckMultiplier))
		player:SetAttribute("ParkourLuckEnd", math.max(currentEnd, now) + settings.BoostMinutes * 60)
		player:SetAttribute(cooldownKey, now + settings.CooldownMinutes * 60)
	end
	runs[player] = nil
	player:SetAttribute("Checkpoint", nil)
	player:SetAttribute("ParkourCourse", nil)
	player:SetAttribute("ParkourStart", nil)
	questEvent:Fire(player, "Parkour", 1)
	ParkourEvent:FireClient(player, {
		Type = "Finish",
		Course = course.Settings.Name,
		Time = seconds,
		Rewarded = rewarded,
		Multiplier = course.Settings.LuckMultiplier,
		Minutes = course.Settings.BoostMinutes,
		CooldownLeft = rewarded and 0 or (cooldownEnd - now),
	})
end

local function onMainIslandGround(position)
	local flat = Vector3.new(position.X, 0, position.Z)
	return flat.Magnitude < Config.MainIslandRadius - 6 and position.Y < 8 and position.Y > -2
end

task.spawn(function()
	while true do
		task.wait(0.1)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not hrp or not humanoid or humanoid.Health <= 0 or character:GetAttribute("InDuel") then
				stopRun(player)
				continue
			end
			local position = hrp.Position
			local run = runs[player]

			-- stepping on a start pad starts (or restarts) that course
			for _, course in pairs(courses) do
				if onPad(course.Start, position) and (not run or run.Course ~= course or run.Checkpoint > 0) then
					startRun(player, course)
					run = runs[player]
				end
			end

			if run then
				local course = run.Course
				-- checkpoints
				for number, pad in ipairs(course.Checkpoints) do
					if number > run.Checkpoint and onPad(pad, position) then
						run.Checkpoint = number
						player:SetAttribute("Checkpoint", spotAbove(pad))
						ParkourEvent:FireClient(player, { Type = "Checkpoint", Number = number, Total = #course.Checkpoints })
					end
				end
				-- kill pads and spinning lasers send you back
				local ouch = false
				for _, kill in ipairs(course.Kills) do
					if onPad(kill, position, 3.5) then
						ouch = true
						break
					end
				end
				if not ouch then
					for _, spinner in ipairs(course.Spinners) do
						if hitBySpinner(spinner, position) then
							ouch = true
							break
						end
					end
				end
				if ouch then
					hrp.AssemblyLinearVelocity = Vector3.zero
					character:PivotTo(player:GetAttribute("Checkpoint") or spotAbove(course.Start))
					ParkourEvent:FireClient(player, { Type = "Ouch" })
				end
				-- finish
				if onPad(course.Finish, position, 6) then
					finishRun(player, course)
				-- walking around the island again ends the run
				elseif (course.OnGround or onMainIslandGround)(position) and not onPad(course.Start, position, 8) then
					stopRun(player, "Left")
				end
			end
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		stopRun(player)
	end)
end)
for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function()
		stopRun(player)
	end)
end
Players.PlayerRemoving:Connect(function(player)
	runs[player] = nil
end)
