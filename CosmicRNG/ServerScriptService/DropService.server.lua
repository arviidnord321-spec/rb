-- DropService (Script in ServerScriptService)
-- THE COSMIC DROP: every 15 minutes (Config.Drop) a Cosmic Roll appears
-- somewhere on the main island or Lucky Isle. The first player to touch it
-- gets x50 luck on their NEXT roll (one use, saved until used).
-- Everyone sees the countdown at the top of the screen (DropClient).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))

local DROP = Config.Drop
local INTERVAL = DROP.IntervalMinutes * 60
local PICKUP_RANGE = 7
local rand = Random.new()

local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local AnnounceRemote = remotes:WaitForChild("Announce")

-- RollService listens to this to hand out the Cosmic Roll
local events = ServerStorage:FindFirstChild("CosmicServerEvents")
if not events then
	events = Instance.new("Folder")
	events.Name = "CosmicServerEvents"
	events.Parent = ServerStorage
end
local grant = events:FindFirstChild("GrantBoostRoll")
if not grant then
	grant = Instance.new("BindableEvent")
	grant.Name = "GrantBoostRoll"
	grant.Parent = events
end

---------------------------------------------------------------------
-- Where can it land?
---------------------------------------------------------------------
local P = Config.Places
local AVOID = { -- big builds the drop shouldn't land inside
	{ Vector3.zero, 10 }, { P.Core, 13 }, { P.Board, 9 }, { P.PortalPlaza, 13 }, { P.Pond, 12 },
	{ P.RebirthGate, 14 }, { P.Hatchery, 20 },
}

local function pickSpot()
	if rand:NextNumber() < DROP.LuckyIsleChance then
		local lucky = Config.LuckyIsland
		local a = rand:NextNumber(0, math.pi * 2)
		local r = rand:NextNumber(16, lucky.Radius - 12)
		return lucky.Center + Vector3.new(math.cos(a) * r, 3.5, math.sin(a) * r), "Lucky Isle"
	end
	for _ = 1, 50 do
		local a = rand:NextNumber(0, math.pi * 2)
		local r = rand:NextNumber(14, Config.MainIslandRadius - 10)
		local spot = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local ok = math.abs(spot.X) > 7 or spot.Z < 40 -- not on the duel bridge path
		for _, zone in ipairs(AVOID) do
			if (spot - Vector3.new(zone[1].X, 0, zone[1].Z)).Magnitude < zone[2] then
				ok = false
			end
		end
		if ok then
			return spot + Vector3.new(0, 3.5, 0), "Cosmic Island"
		end
	end
	return Vector3.new(0, 3.5, -20), "Cosmic Island"
end

---------------------------------------------------------------------
-- The drop itself: a glowing spinning die under a beam of light
---------------------------------------------------------------------
local current -- { Model, Position }

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local GOLD = Color3.fromRGB(255, 215, 90)
local PURPLE = Color3.fromRGB(170, 110, 255)

local function buildDrop(position)
	local model = Instance.new("Model")
	model.Name = "CosmicDrop"
	local die = part({
		Name = "Die",
		Size = Vector3.one * 2.6,
		CFrame = CFrame.new(position),
		Color = Color3.fromRGB(255, 250, 235),
		Material = Enum.Material.Neon,
	}, model)
	-- dots on every face
	local faces = {
		{ Vector3.new(0, 0, -1), { Vector2.new(0, 0) } },
		{ Vector3.new(0, 0, 1), { Vector2.new(-0.5, -0.5), Vector2.new(0.5, 0.5) } },
		{ Vector3.new(1, 0, 0), { Vector2.new(-0.5, -0.5), Vector2.new(0, 0), Vector2.new(0.5, 0.5) } },
		{ Vector3.new(-1, 0, 0), { Vector2.new(-0.5, -0.5), Vector2.new(0.5, -0.5), Vector2.new(-0.5, 0.5), Vector2.new(0.5, 0.5) } },
		{ Vector3.new(0, 1, 0), { Vector2.new(-0.5, -0.5), Vector2.new(0.5, -0.5), Vector2.new(0, 0), Vector2.new(-0.5, 0.5), Vector2.new(0.5, 0.5) } },
		{ Vector3.new(0, -1, 0), { Vector2.new(-0.5, -0.6), Vector2.new(0.5, -0.6), Vector2.new(-0.5, 0), Vector2.new(0.5, 0), Vector2.new(-0.5, 0.6), Vector2.new(0.5, 0.6) } },
	}
	for _, face in ipairs(faces) do
		local normal = face[1]
		local right = (math.abs(normal.Y) > 0.5) and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0):Cross(normal)
		local up = normal:Cross(right)
		for _, dot in ipairs(face[2]) do
			part({
				Name = "Dot",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.45,
				CFrame = CFrame.new(position + normal * 1.3 + right * dot.X * 1.3 + up * dot.Y * 1.3),
				Color = PURPLE,
				Material = Enum.Material.Neon,
			}, model)
		end
	end
	local glow = part({
		Name = "Glow",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 5,
		CFrame = CFrame.new(position),
		Color = GOLD,
		Material = Enum.Material.Neon,
		Transparency = 0.75,
	}, model)
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 30
	light.Brightness = 4
	light.Parent = glow
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = Config.Textures.Sparkle
	sparkle.Rate = 30
	sparkle.Lifetime = NumberRange.new(1, 2)
	sparkle.Speed = NumberRange.new(2, 6)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	sparkle.LightEmission = 1
	sparkle.Color = ColorSequence.new(GOLD, PURPLE)
	sparkle.Parent = glow
	-- a beam of light so everybody can find it from far away
	part({
		Name = "Beam",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(400, 2.4, 2.4),
		CFrame = CFrame.new(position + Vector3.new(0, 200, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = GOLD,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
	}, model)
	part({
		Name = "GroundRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 9, 9),
		CFrame = CFrame.new(position - Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = PURPLE,
		Material = Enum.Material.Neon,
		Transparency = 0.3,
	}, model)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 60)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 500
	gui.LightInfluence = 0
	gui.Parent = die
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = ("🎲 COSMIC ROLL\nx%d LUCK"):format(DROP.BoostMultiplier)
	label.TextColor3 = GOLD
	label.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Thickness = 2.5
	outline.Parent = label
	model.PrimaryPart = die
	model:SetAttribute("DropCenter", position)
	model.Parent = workspace
	return model
end

local function clearDrop()
	if current then
		current.Model:Destroy()
		current = nil
	end
	ReplicatedStorage:SetAttribute("DropActive", false)
end

local function spawnDrop()
	clearDrop()
	local position, where = pickSpot()
	current = { Model = buildDrop(position), Position = position }
	ReplicatedStorage:SetAttribute("DropPosition", position)
	ReplicatedStorage:SetAttribute("DropWhere", where)
	ReplicatedStorage:SetAttribute("DropActive", true)
	AnnounceRemote:FireAllClients({ Type = "DropSpawned", Where = where })
end

local function grab(player)
	if not current then
		return
	end
	local position = current.Position
	clearDrop()
	grant:Fire(player, 1)
	AnnounceRemote:FireAllClients({ Type = "DropGrabbed", PlayerName = player.DisplayName, UserId = player.UserId, Position = position })
end

---------------------------------------------------------------------
-- The clock
---------------------------------------------------------------------
ReplicatedStorage:SetAttribute("DropActive", false)
ReplicatedStorage:SetAttribute("DropNextAt", workspace:GetServerTimeNow() + INTERVAL)

task.spawn(function()
	while true do
		task.wait(0.15)
		local now = workspace:GetServerTimeNow()
		local nextAt = ReplicatedStorage:GetAttribute("DropNextAt") or now
		if now >= nextAt then
			ReplicatedStorage:SetAttribute("DropNextAt", nextAt + INTERVAL)
			spawnDrop()
		end
		if current then
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid and humanoid.Health > 0 and not character:GetAttribute("InDuel")
					and (root.Position - current.Position).Magnitude < PICKUP_RANGE then
					grab(player)
					break
				end
			end
		end
	end
end)
