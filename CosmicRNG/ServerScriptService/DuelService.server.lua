-- DuelService (Script in ServerScriptService)
-- 1v1 DUELS. Builds Duel Island (south of the main island, over the bridge)
-- with two arenas, and runs every fight on the server so nobody can cheat.
--
--   * Challenge a player (they accept/decline) or fight a bot (4 levels)
--   * Your EQUIPPED AURA decides your duel stats: rarer tier = more HP and
--     harder hits, and every aura's own power (AuraData.Power) is usable
--   * Basic attack: click / ATTACK button.  Power: Q / POWER button.
--   * First to 0 HP loses. When time runs out, the higher HP % wins.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))

local DUEL = Config.Duel
local P = Config.Places
local ISLAND_CENTER = P.DuelIsland
local ISLAND_RADIUS = P.DuelIslandRadius
local FLAT = CFrame.Angles(0, 0, math.rad(90))
local rng = Random.new()

---------------------------------------------------------------------
-- Remotes + a server-only event that RollService uses to count wins
---------------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("CosmicRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "CosmicRemotes"
	remotes.Parent = ReplicatedStorage
end
local function getRemote(className, name, parent)
	parent = parent or remotes
	local remote = parent:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = parent
	end
	return remote
end
local DuelRequest = getRemote("RemoteEvent", "DuelRequest") -- client -> server
local DuelEvent = getRemote("RemoteEvent", "DuelEvent") -- server -> one player
local DuelFX = getRemote("RemoteEvent", "DuelFX") -- server -> everyone (visuals)
local AnnounceRemote = getRemote("RemoteEvent", "Announce")

local serverEvents = ServerStorage:FindFirstChild("CosmicServerEvents")
if not serverEvents then
	serverEvents = Instance.new("Folder")
	serverEvents.Name = "CosmicServerEvents"
	serverEvents.Parent = ServerStorage
end
local DuelWinEvent = getRemote("BindableEvent", "DuelWin", serverEvents)

---------------------------------------------------------------------
-- BUILD DUEL ISLAND
---------------------------------------------------------------------
local old = workspace:FindFirstChild("DuelIsland")
if old then
	old:Destroy()
end
local island = Instance.new("Model")
island.Name = "DuelIsland"
island.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

local CRIMSON = Color3.fromRGB(255, 70, 90)
local STEEL = Color3.fromRGB(55, 45, 70)
local STEEL_DARK = Color3.fromRGB(32, 26, 44)
local GOLD = Color3.fromRGB(255, 200, 70)

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
	p.Parent = props.Parent or island
	return p
end

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

local function addLight(target, color3, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color3
	light.Range = range
	light.Brightness = brightness
	light.Parent = target
end

local function addFire(target)
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = Config.Textures.Fire
	fire.Rate = 24
	fire.Lifetime = NumberRange.new(0.4, 0.9)
	fire.Speed = NumberRange.new(1, 3)
	fire.Acceleration = Vector3.new(0, 5, 0)
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	fire.LightEmission = 1
	fire.LightInfluence = 0
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 200, 120), Color3.fromRGB(255, 60, 60))
	fire.Parent = target
end

local function textGui(target, face, text, color3, pixelsPerStud)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	label.TextColor3 = color3
	label.Parent = gui
	return label
end

-- ground
disc("Ground", ISLAND_CENTER, ISLAND_RADIUS, 4, 0, STEEL, Enum.Material.Slate)
disc("EdgeGlow", ISLAND_CENTER, ISLAND_RADIUS + 0.6, 0.6, -0.2, CRIMSON, Enum.Material.Neon, { CanCollide = false })
for i, layer in ipairs({ { 6, -4, 6 }, { 16, -10, 7 }, { 28, -17, 8 }, { 38, -25, 9 } }) do
	disc("Underside" .. i, ISLAND_CENTER, ISLAND_RADIUS - layer[1], layer[3], layer[2], (i % 2 == 0) and STEEL_DARK or Color3.fromRGB(70, 30, 45), Enum.Material.Slate, { CanCollide = false })
end

-- the two arenas
local ARENA_RADIUS = 15
local FLOOR_Y = 1
local arenas = {}
for index, offsetX in ipairs({ -21, 21 }) do
	local center = ISLAND_CENTER + Vector3.new(offsetX, 0, 4)
	local model = Instance.new("Model")
	model.Name = "Arena" .. index
	model.Parent = island

	disc("ArenaBase", center, ARENA_RADIUS + 1.2, 1.2, FLOOR_Y - 0.2, STEEL_DARK, Enum.Material.Slate, { Parent = model })
	disc("ArenaFloor", center, ARENA_RADIUS, 1, FLOOR_Y, Color3.fromRGB(45, 38, 60), Enum.Material.Marble, { Parent = model })
	for _, ring in ipairs({ { 6, 0.35 }, { 12, 0.35 } }) do
		local segments = math.floor(ring[1] * 4)
		for s = 1, segments do
			local a = (s / segments) * math.pi * 2
			local p = center + Vector3.new(math.cos(a) * ring[1], FLOOR_Y + 0.03, math.sin(a) * ring[1])
			part({
				Name = "FloorRing",
				Size = Vector3.new(ring[2], 0.1, (2 * math.pi * ring[1] / segments) * 1.05),
				CFrame = CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z)) * CFrame.Angles(0, math.pi / 2, 0),
				Color = CRIMSON,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				Parent = model,
			})
		end
	end
	for b = 0, 3 do -- star emblem in the middle
		part({
			Name = "Emblem",
			Size = Vector3.new(0.4, 0.1, 9),
			CFrame = CFrame.new(center.X, FLOOR_Y + 0.04, center.Z) * CFrame.Angles(0, b * math.pi / 4, 0),
			Color = GOLD,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
	end

	-- force-field wall that keeps fighters in (and everyone else out)
	local wallSegments = 40
	for s = 1, wallSegments do
		local a = (s / wallSegments) * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * (ARENA_RADIUS + 0.6), FLOOR_Y + 4, math.sin(a) * (ARENA_RADIUS + 0.6))
		part({
			Name = "ArenaWall",
			Size = Vector3.new(0.6, 8, (2 * math.pi * (ARENA_RADIUS + 0.6) / wallSegments) * 1.05),
			CFrame = CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z)) * CFrame.Angles(0, math.pi / 2, 0),
			Color = CRIMSON,
			Material = Enum.Material.ForceField,
			Transparency = 0.3,
			Parent = model,
		})
		part({
			Name = "WallTop",
			Size = Vector3.new(0.4, 0.4, (2 * math.pi * (ARENA_RADIUS + 0.6) / wallSegments) * 1.05),
			CFrame = CFrame.lookAt(p + Vector3.new(0, 4.2, 0), Vector3.new(center.X, p.Y + 4.2, center.Z)) * CFrame.Angles(0, math.pi / 2, 0),
			Color = CRIMSON,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
	end

	-- braziers
	for k = 1, 4 do
		local a = (k / 4) * math.pi * 2 + math.pi / 4
		local p = center + Vector3.new(math.cos(a) * (ARENA_RADIUS + 3.4), 0, math.sin(a) * (ARENA_RADIUS + 3.4))
		part({ Name = "BrazierPost", Size = Vector3.new(1.4, 6, 1.4), CFrame = CFrame.new(p + Vector3.new(0, 3, 0)), Color = STEEL_DARK, Material = Enum.Material.Metal, Parent = model })
		local bowl = part({ Name = "Brazier", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, CFrame = CFrame.new(p + Vector3.new(0, 6.4, 0)), Color = Color3.fromRGB(255, 120, 80), Material = Enum.Material.Neon, CanCollide = false, Parent = model })
		addFire(bowl)
		addLight(bowl, Color3.fromRGB(255, 120, 90), 22, 1.8)
	end

	-- spectator stands on the far side
	for row = 1, 3 do
		local radius = ARENA_RADIUS + 4 + row * 2.4
		local segments = 14
		for s = 0, segments - 1 do
			local a = math.rad(50) + (s + 0.5) / segments * math.rad(80)
			local p = center + Vector3.new(math.cos(a) * radius, row * 1.2 - 0.6, math.sin(a) * radius)
			part({
				Name = "Stand",
				Size = Vector3.new(2.4, row * 1.2, (radius * math.rad(80) / segments) * 1.05),
				CFrame = CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z)) * CFrame.Angles(0, math.pi / 2, 0),
				Color = (row % 2 == 0) and STEEL or Color3.fromRGB(80, 40, 60),
				Material = Enum.Material.Slate,
				Parent = model,
			})
		end
	end

	-- scoreboard floating above the arena
	local boardAnchor = part({
		Name = "Scoreboard",
		Size = Vector3.one * 0.2,
		CFrame = CFrame.new(center + Vector3.new(0, 15, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(460, 90)
	board.MaxDistance = 200
	board.LightInfluence = 0
	board.Parent = boardAnchor
	local boardText = Instance.new("TextLabel")
	boardText.BackgroundTransparency = 1
	boardText.Size = UDim2.fromScale(1, 1)
	boardText.Font = Enum.Font.FredokaOne
	boardText.TextScaled = true
	boardText.RichText = true
	boardText.TextColor3 = Color3.new(1, 1, 1)
	boardText.Parent = board
	local outline = Instance.new("UIStroke")
	outline.Thickness = 2.5
	outline.Parent = boardText

	local spawnA = CFrame.lookAt(center + Vector3.new(0, FLOOR_Y + 3, -9), center + Vector3.new(0, FLOOR_Y + 3, 0))
	local spawnB = CFrame.lookAt(center + Vector3.new(0, FLOOR_Y + 3, 9), center + Vector3.new(0, FLOOR_Y + 3, 0))
	arenas[index] = {
		Name = "Arena " .. index,
		Center = Vector3.new(center.X, FLOOR_Y, center.Z),
		Spawns = { spawnA, spawnB },
		Busy = false,
		BoardText = boardText,
	}
end

local function setBoard(arena, text)
	arena.BoardText.Text = text
end
for _, arena in ipairs(arenas) do
	setBoard(arena, ("⚔ %s\n<font color='#9fe8a0'>OPEN</font>"):format(string.upper(arena.Name)))
end

-- lobby sign near the bridge
local LOBBY = ISLAND_CENTER + Vector3.new(0, 0, -30)
local signPart = part({
	Name = "DuelSign",
	Size = Vector3.new(16, 7, 0.6),
	CFrame = CFrame.lookAt(LOBBY + Vector3.new(0, 6, 6), LOBBY + Vector3.new(0, 6, -20)),
	Color = STEEL_DARK,
	Material = Enum.Material.SmoothPlastic,
})
textGui(signPart, Enum.NormalId.Front,
	"⚔ DUEL ISLAND ⚔\nOpen the DUEL menu to challenge a player or a bot.\nRarer aura = more HP + harder hits!", Color3.fromRGB(255, 200, 200), 30)
for _, side in ipairs({ -1, 1 }) do
	local post = part({ Name = "SignPost", Size = Vector3.new(0.8, 10, 0.8), CFrame = CFrame.new(LOBBY + Vector3.new(side * 8.6, 5, 6)), Color = CRIMSON, Material = Enum.Material.Neon, CanCollide = false })
	addLight(post, CRIMSON, 14, 1.2)
end
local LOBBY_EXIT = CFrame.lookAt(LOBBY + Vector3.new(0, 3, 0), LOBBY + Vector3.new(0, 3, 30))

local botFolder = workspace:FindFirstChild("DuelBots") or Instance.new("Folder")
botFolder.Name = "DuelBots"
botFolder.Parent = workspace

island.Parent = workspace

---------------------------------------------------------------------
-- FIGHTERS
-- A fighter is a player or a bot taking part in a duel.
---------------------------------------------------------------------
local duels = {} -- list of active duels
local fighterOf = {} -- [player or bot model] = fighter
local pending = {} -- [targetPlayer] = { From = player, Expires = time }

local function auraFor(name)
	return AuraData.Get(name or "") or nil
end

local function statsFor(auraName)
	local aura = auraFor(auraName)
	local tier = AuraData.Tiers[aura and aura.Tier or DUEL.NoAuraTier]
	return aura, tier
end

local function isPlayerBusy(player)
	return fighterOf[player] ~= nil
end

local function setFighterAttributes(fighter)
	local model = fighter.Model
	model:SetAttribute("DuelHP", math.max(0, math.floor(fighter.HP + 0.5)))
	model:SetAttribute("DuelMaxHP", fighter.MaxHP)
	model:SetAttribute("DuelShield", math.floor(fighter.Shield + 0.5))
	model:SetAttribute("DuelGuard", math.floor((fighter.Guard or 0) + 0.5))
	model:SetAttribute("DuelBlocking", fighter.Blocking == true)
end

local function newFighter(kind, player, model, auraName, displayName)
	local aura, tier = statsFor(auraName)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local fighter = {
		Kind = kind,
		Player = player,
		Model = model,
		Humanoid = humanoid,
		Root = model:FindFirstChild("HumanoidRootPart"),
		Aura = aura,
		Tier = tier,
		Name = displayName,
		HP = tier.MaxHealth,
		MaxHP = tier.MaxHealth,
		Shield = 0,
		ShieldEnd = 0,
		NextAttack = 0,
		PowerReady = 0,
		StunnedUntil = 0,
		SlowUntil = 0,
		SlowAmount = 0,
		BaseSpeed = humanoid and humanoid.WalkSpeed or 16,
		BaseJumpPower = humanoid and humanoid.JumpPower or 50,
		BaseJumpHeight = humanoid and humanoid.JumpHeight or 7.2,
		Combo = 0,
		LastAttack = 0,
		Blocking = false,
		Guard = DUEL.GuardMax,
		NextDodge = 0,
	}
	return fighter
end

local function fighterKey(fighter)
	return fighter.Player or fighter.Model
end

local function sendTo(fighter, payload)
	if fighter.Player then
		DuelEvent:FireClient(fighter.Player, payload)
	end
end

local function flatDirection(from, to)
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if d.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return d.Unit
end

---------------------------------------------------------------------
-- BOTS
---------------------------------------------------------------------
local function botSettings(key)
	for _, bot in ipairs(DUEL.Bots) do
		if bot.Key == key then
			return bot
		end
	end
	return nil
end

local function buildSimpleBot()
	-- fallback body if Roblox can't make a full avatar
	local model = Instance.new("Model")
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.Transparency = 1
	rootPart.Parent = model
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Color = Color3.fromRGB(60, 50, 90)
	torso.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Color = Color3.fromRGB(200, 190, 255)
	head.Parent = model
	local w1 = Instance.new("WeldConstraint")
	w1.Part0 = rootPart
	w1.Part1 = torso
	w1.Parent = rootPart
	head.CFrame = rootPart.CFrame * CFrame.new(0, 1.6, 0)
	local w2 = Instance.new("WeldConstraint")
	w2.Part0 = rootPart
	w2.Part1 = head
	w2.Parent = rootPart
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2
	humanoid.Parent = model
	model.PrimaryPart = rootPart
	return model
end

local function spawnBot(settings, spawnCFrame)
	local model
	local ok = pcall(function()
		local description = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(150, 140, 200)
		description.HeadColor = skin
		description.TorsoColor = Color3.fromRGB(60, 50, 90)
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.LeftLegColor = Color3.fromRGB(40, 35, 60)
		description.RightLegColor = Color3.fromRGB(40, 35, 60)
		model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		model = buildSimpleBot()
	end
	model.Name = settings.Name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = "🤖 " .. settings.Name
	humanoid.WalkSpeed = settings.Speed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 50
	model:SetAttribute("Aura", settings.Aura)
	model:SetAttribute("IsDuelBot", true)
	model:PivotTo(spawnCFrame)
	model.Parent = botFolder
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if rootPart then
		pcall(function()
			rootPart:SetNetworkOwner(nil) -- the server moves bots
		end)
	end
	return model
end

---------------------------------------------------------------------
-- DUEL LIFECYCLE
---------------------------------------------------------------------
local endDuel -- defined below

local function freeze(fighter, frozen)
	local humanoid = fighter.Humanoid
	if not humanoid then
		return
	end
	if frozen then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	else
		humanoid.WalkSpeed = fighter.BaseSpeed
		humanoid.JumpPower = fighter.BaseJumpPower
		humanoid.JumpHeight = fighter.BaseJumpHeight
	end
end

local function describe(fighter)
	return {
		Name = fighter.Name,
		Aura = fighter.Aura and fighter.Aura.Name or nil,
		Tier = fighter.Aura and fighter.Aura.Tier or DUEL.NoAuraTier,
		MaxHP = fighter.MaxHP,
		Damage = fighter.Tier.AttackDamage,
		Power = fighter.Aura and fighter.Aura.Power or nil,
		Model = fighter.Model,
		IsBot = fighter.Kind == "Bot",
	}
end

local function freeArena()
	for _, arena in ipairs(arenas) do
		if not arena.Busy then
			return arena
		end
	end
	return nil
end

local function startDuel(fighterA, fighterB, arena)
	arena.Busy = true
	local duel = {
		Arena = arena,
		A = fighterA,
		B = fighterB,
		State = "Countdown",
		EndsAt = math.huge,
	}
	fighterA.Opponent = fighterB
	fighterB.Opponent = fighterA
	fighterA.Duel = duel
	fighterB.Duel = duel
	fighterA.Spawn = arena.Spawns[1]
	fighterB.Spawn = arena.Spawns[2]
	table.insert(duels, duel)

	for _, fighter in ipairs({ fighterA, fighterB }) do
		fighterOf[fighterKey(fighter)] = fighter
		fighter.Model:SetAttribute("InDuel", true)
		fighter.Model:SetAttribute("DuelName", fighter.Name)
		if fighter.Player then
			fighter.Player:SetAttribute("InDuel", true)
			fighter.Player:SetAttribute("Checkpoint", nil)
		end
		setFighterAttributes(fighter)
		fighter.Root.AssemblyLinearVelocity = Vector3.zero
		fighter.Model:PivotTo(fighter.Spawn)
		freeze(fighter, true)
	end

	setBoard(arena, ("⚔ <font color='#ffd76a'>%s</font> vs <font color='#ffd76a'>%s</font>"):format(fighterA.Name, fighterB.Name))
	sendTo(fighterA, { Type = "Start", Me = describe(fighterA), Opponent = describe(fighterB), Countdown = DUEL.CountdownSeconds, TimeLimit = DUEL.TimeLimit })
	sendTo(fighterB, { Type = "Start", Me = describe(fighterB), Opponent = describe(fighterA), Countdown = DUEL.CountdownSeconds, TimeLimit = DUEL.TimeLimit })
	DuelFX:FireAllClients({ Type = "DuelStart", A = fighterA.Model, B = fighterB.Model, Center = arena.Center })

	task.delay(DUEL.CountdownSeconds, function()
		if duel.State ~= "Countdown" then
			return
		end
		duel.State = "Fight"
		duel.EndsAt = os.clock() + DUEL.TimeLimit
		freeze(fighterA, false)
		freeze(fighterB, false)
		sendTo(fighterA, { Type = "Fight", EndsIn = DUEL.TimeLimit })
		sendTo(fighterB, { Type = "Fight", EndsIn = DUEL.TimeLimit })
	end)
	return duel
end

local function releaseFighter(fighter)
	fighterOf[fighterKey(fighter)] = nil
	local model = fighter.Model
	if fighter.Kind == "Bot" then
		if model then
			model:Destroy()
		end
		return
	end
	local player = fighter.Player
	if player then
		player:SetAttribute("InDuel", nil)
	end
	if model and model.Parent then
		model:SetAttribute("InDuel", nil)
		model:SetAttribute("DuelHP", nil)
		model:SetAttribute("DuelMaxHP", nil)
		model:SetAttribute("DuelShield", nil)
		model:SetAttribute("DuelName", nil)
		freeze(fighter, false)
		if fighter.Root and fighter.Root.Parent then
			fighter.Root.AssemblyLinearVelocity = Vector3.zero
			model:PivotTo(LOBBY_EXIT * CFrame.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-2, 2)))
		end
	end
end

endDuel = function(duel, winner, reason)
	if duel.State == "Over" then
		return
	end
	duel.State = "Over"
	local a, b = duel.A, duel.B
	freeze(a, true)
	freeze(b, true)

	for _, fighter in ipairs({ a, b }) do
		local result = (winner == nil) and "Draw" or (winner == fighter and "Win" or "Lose")
		sendTo(fighter, { Type = "End", Result = result, Reason = reason, Opponent = fighter.Opponent.Name })
	end
	DuelFX:FireAllClients({ Type = "DuelEnd", Winner = winner and winner.Model or nil, A = a.Model, B = b.Model })

	if winner then
		setBoard(duel.Arena, ("🏆 <font color='#ffd76a'>%s</font> WINS!"):format(winner.Name))
		-- only player-vs-player wins count (and are announced)
		local loser = winner.Opponent
		-- quests count every win, bots included
		if winner.Player then
			local questEvent = serverEvents:FindFirstChild("QuestEvent")
			if questEvent then
				questEvent:Fire(winner.Player, "DuelWin", 1)
			end
		end
		if winner.Player and loser.Kind == "Player" then
			DuelWinEvent:Fire(winner.Player, loser.Player)
			AnnounceRemote:FireAllClients({
				Type = "Duel",
				Winner = winner.Name,
				Loser = loser.Name,
				WinnerAura = winner.Aura and winner.Aura.Name or nil,
			})
		end
	else
		setBoard(duel.Arena, "⚔ DRAW!")
	end

	task.delay(3.5, function()
		releaseFighter(a)
		releaseFighter(b)
		local index = table.find(duels, duel)
		if index then
			table.remove(duels, index)
		end
		duel.Arena.Busy = false
		setBoard(duel.Arena, ("⚔ %s\n<font color='#9fe8a0'>OPEN</font>"):format(string.upper(duel.Arena.Name)))
	end)
end

---------------------------------------------------------------------
-- FINISHER: the knockout cutscene both fighters (and spectators) see
---------------------------------------------------------------------
local function startFinisher(duel, winner)
	if duel.State ~= "Fight" then
		return
	end
	duel.State = "Finisher"
	local loser = winner.Opponent
	for _, fighter in ipairs({ winner, loser }) do
		freeze(fighter, true)
		if fighter.Root and fighter.Root.Parent then
			fighter.Root.AssemblyLinearVelocity = Vector3.zero
		end
	end
	-- the winner turns to face the loser
	if winner.Root and loser.Root then
		local from, to = winner.Root.Position, loser.Root.Position
		winner.Model:PivotTo(CFrame.lookAt(from, Vector3.new(to.X, from.Y, to.Z)))
	end
	local aura = winner.Aura
	local payload = {
		Type = "Finisher",
		Winner = winner.Model,
		Loser = loser.Model,
		WinnerName = winner.Name,
		LoserName = loser.Name,
		AuraName = aura and aura.Name or nil,
		Colors = aura and aura.Colors or { Color3.new(1, 1, 1), Color3.fromRGB(255, 80, 100) },
		Special = aura and aura.Special or nil,
		Order = winner.Tier.Order,
		Duration = DUEL.FinisherSeconds,
	}
	DuelFX:FireAllClients(payload)
	sendTo(winner, payload)
	sendTo(loser, payload)
	task.delay(DUEL.FinisherSeconds, function()
		endDuel(duel, winner, "KO")
	end)
end

---------------------------------------------------------------------
-- DAMAGE + STATUS EFFECTS
---------------------------------------------------------------------
local function canAct(fighter)
	local duel = fighter.Duel
	return duel and duel.State == "Fight" and os.clock() >= fighter.StunnedUntil
		and fighter.Root and fighter.Root.Parent ~= nil
end

-- opts: { Pierce = ignore shields, NoReflect = can't be reflected, Kind = "Burn"/... }
local function damage(target, amount, source, opts)
	opts = opts or {}
	local duel = target.Duel
	if not duel or duel.State ~= "Fight" then
		return
	end
	local now = os.clock()
	if now < (target.DodgeUntil or 0) then
		DuelFX:FireAllClients({ Type = "Dodge", Target = target.Model })
		return
	end
	-- blocking soaks up most of the hit (but uses guard). Heavy hits break it.
	if target.Blocking and opts.Kind ~= "Burn" and opts.Kind ~= "Reflect" then
		if opts.Kind == "Heavy" or target.Guard <= DUEL.GuardHitCost then
			target.Blocking = false
			target.Guard = 0
			target.StunnedUntil = math.max(target.StunnedUntil, now + DUEL.GuardBreakStun)
			DuelFX:FireAllClients({ Type = "GuardBreak", Target = target.Model })
			amount *= 0.6
		else
			target.Guard -= DUEL.GuardHitCost
			amount *= (opts.Kind == "Basic") and DUEL.BlockBasic or DUEL.BlockPower
			opts.Blocked = true
			DuelFX:FireAllClients({ Type = "Block", Target = target.Model, Attacker = source and source.Model or nil })
		end
	end
	amount = math.max(1, math.floor(amount + 0.5))
	local absorbed = 0
	if not opts.Pierce and target.Shield > 0 and now < target.ShieldEnd then
		absorbed = math.min(target.Shield, amount)
		target.Shield -= absorbed
	end
	-- Moon Shield style reflect: part of the hit bounces back
	if source and source ~= target and not opts.NoReflect and now < (target.ReflectUntil or 0) then
		local reflected = math.floor(amount * (target.ReflectAmount or 0) + 0.5)
		if reflected > 0 then
			task.defer(damage, source, reflected, target, { NoReflect = true, Kind = "Reflect" })
		end
	end
	local taken = amount - absorbed
	target.HP = math.max(0, target.HP - taken)
	setFighterAttributes(target)
	DuelFX:FireAllClients({
		Type = "Damage",
		Target = target.Model,
		Amount = taken,
		Blocked = absorbed,
		Color = source and source.Aura and source.Aura.Colors[1] or Color3.new(1, 1, 1),
		Kind = opts.Kind,
		Heavy = opts.Kind == "Heavy",
		WasBlocked = opts.Blocked == true,
		Attacker = source and source.Model or nil,
	})
	if target.HP <= 0 then
		startFinisher(duel, target.Opponent)
	end
end

-- damage over time (Burn)
local function burn(target, source, spec)
	task.spawn(function()
		for _ = 1, spec.Ticks or 3 do
			task.wait(spec.Interval or 0.5)
			if not target.Duel or target.Duel.State ~= "Fight" then
				return
			end
			DuelFX:FireAllClients({ Type = "Burn", Target = target.Model })
			damage(target, spec.Damage, source, { NoReflect = true, Kind = "Burn" })
		end
	end)
end

local function heal(fighter, amount)
	fighter.HP = math.min(fighter.MaxHP, fighter.HP + amount)
	setFighterAttributes(fighter)
	DuelFX:FireAllClients({ Type = "Heal", Target = fighter.Model, Amount = amount })
end

-- healing over time (Regen)
local function regen(fighter, spec)
	task.spawn(function()
		for _ = 1, spec.Ticks or 4 do
			task.wait(spec.Interval or 1)
			if not fighter.Duel or fighter.Duel.State ~= "Fight" then
				return
			end
			heal(fighter, spec.Amount)
		end
	end)
end

-- every power can carry extra effects that trigger when it hits
local function onPowerHit(fighter, target, power)
	if power.Burn then
		burn(target, fighter, power.Burn)
	end
end

local function giveShield(fighter, amount, duration)
	fighter.Shield = amount
	fighter.ShieldEnd = os.clock() + duration
	setFighterAttributes(fighter)
	DuelFX:FireAllClients({ Type = "Shield", Target = fighter.Model, Duration = duration, Color = fighter.Aura and fighter.Aura.Colors[1] or Color3.new(1, 1, 1) })
end

local function stun(fighter, seconds)
	fighter.StunnedUntil = math.max(fighter.StunnedUntil, os.clock() + seconds)
	DuelFX:FireAllClients({ Type = "Stun", Target = fighter.Model, Duration = seconds })
end

local function slow(fighter, amount, seconds)
	fighter.SlowAmount = amount
	fighter.SlowUntil = os.clock() + seconds
end

local function knockback(fighter, direction, strength)
	local velocity = direction * strength + Vector3.new(0, strength * 0.45, 0)
	if fighter.Kind == "Bot" then
		fighter.Root.AssemblyLinearVelocity = velocity
	else
		sendTo(fighter, { Type = "Knockback", Velocity = velocity })
	end
end

-- keep a point inside the arena floor
local function clampToArena(fighter, position)
	local center = fighter.Duel.Arena.Center
	local offset = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
	if offset.Magnitude > ARENA_RADIUS - 2 then
		offset = offset.Unit * (ARENA_RADIUS - 2)
	end
	return Vector3.new(center.X + offset.X, center.Y + 3, center.Z + offset.Z)
end

local function distanceToSegment(point, a, b)
	local ab = b - a
	local t = math.clamp((point - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	return (point - (a + ab * t)).Magnitude
end

---------------------------------------------------------------------
-- ATTACKS
---------------------------------------------------------------------
-- Aim: the direction the player is looking. If the opponent is close to
-- that direction we "snap" to them (aim assist), otherwise it can miss.
local function resolveAim(fighter, aim)
	local opponent = fighter.Opponent
	local toOpponent = flatDirection(fighter.Root.Position, opponent.Root.Position)
	if typeof(aim) ~= "Vector3" or aim.Magnitude < 0.1 then
		aim = fighter.Root.CFrame.LookVector
	end
	aim = Vector3.new(aim.X, 0, aim.Z)
	aim = (aim.Magnitude > 0.01) and aim.Unit or toOpponent
	if aim:Dot(toOpponent) > math.cos(math.rad(30)) then
		return toOpponent
	end
	return aim
end

local function basicAttack(fighter, aim)
	local now = os.clock()
	if not canAct(fighter) or fighter.Blocking or now < fighter.NextAttack then
		return
	end
	-- combo: jab, jab, KICK (if you keep attacking quickly)
	if now - fighter.LastAttack <= DUEL.ComboWindow then
		fighter.Combo = (fighter.Combo % 3) + 1
	else
		fighter.Combo = 1
	end
	fighter.LastAttack = now
	local combo = fighter.Combo
	local heavy = combo == 3
	fighter.NextAttack = now + (heavy and DUEL.HeavyRecovery or DUEL.AttackCooldown)
	local direction = resolveAim(fighter, aim)
	DuelFX:FireAllClients({
		Type = "Swing",
		Attacker = fighter.Model,
		Direction = direction,
		Combo = combo,
		Heavy = heavy,
		Color = fighter.Aura and fighter.Aura.Colors[1] or Color3.new(1, 1, 1),
	})
	sendTo(fighter, { Type = "Combo", Combo = combo })

	-- the hit lands when the fist/foot connects in the animation
	task.delay(heavy and 0.27 or 0.12, function()
		if not canAct(fighter) then
			return
		end
		local opponent = fighter.Opponent
		local toOpponent = opponent.Root.Position - fighter.Root.Position
		local reach = DUEL.AttackRange + (heavy and 1.5 or 0)
		local facing = flatDirection(fighter.Root.Position, opponent.Root.Position)
		if toOpponent.Magnitude <= reach and direction:Dot(facing) > math.cos(math.rad(75)) then
			local multiplier = DUEL.ComboDamage[combo] or 1
			damage(opponent, fighter.Tier.AttackDamage * multiplier * rng:NextNumber(0.92, 1.08), fighter, {
				Kind = heavy and "Heavy" or "Basic",
			})
			if heavy and opponent.Duel and opponent.Duel.State == "Fight" then
				knockback(opponent, facing, DUEL.HeavyKnockback)
			end
		end
	end)
end

-- Blocking on/off
local function setBlocking(fighter, on)
	if on and (not canAct(fighter) or fighter.Guard < DUEL.GuardHitCost) then
		return
	end
	if fighter.Blocking ~= on then
		fighter.Blocking = on
		setFighterAttributes(fighter)
	end
end

-- Dodge roll: a quick dash with a moment of invincibility
local function dodge(fighter, direction)
	local now = os.clock()
	if not canAct(fighter) or fighter.Blocking or now < fighter.NextDodge then
		return
	end
	fighter.NextDodge = now + DUEL.DodgeCooldown
	fighter.DodgeUntil = now + DUEL.DodgeInvincible
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.1 then
		direction = fighter.Root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	direction = (direction.Magnitude > 0.01) and direction.Unit or Vector3.new(0, 0, -1)
	DuelFX:FireAllClients({ Type = "DodgeRoll", Target = fighter.Model, Direction = direction, Colors = fighter.Aura and fighter.Aura.Colors or nil })
	sendTo(fighter, { Type = "DodgeUsed", Cooldown = DUEL.DodgeCooldown })
	if fighter.Kind == "Bot" then
		fighter.Root.AssemblyLinearVelocity = direction * DUEL.DodgeSpeed + Vector3.new(0, 6, 0)
	end
end

local projectileId = 0
local function fireProjectile(fighter, direction, power)
	projectileId += 1
	local id = projectileId
	local opponent = fighter.Opponent
	local origin = fighter.Root.Position + Vector3.new(0, 1, 0) + direction * 2
	local speed = power.Speed or 80
	local range = 60
	DuelFX:FireAllClients({
		Type = "Projectile",
		Id = id,
		Origin = origin,
		Direction = direction,
		Speed = speed,
		Range = range,
		Colors = fighter.Aura.Colors,
	})
	task.spawn(function()
		local travelled = 0
		local position = origin
		local step = 1 / 30
		while travelled < range do
			task.wait(step)
			if not fighter.Duel or fighter.Duel.State ~= "Fight" then
				break
			end
			local move = speed * step
			local nextPosition = position + direction * move
			if distanceToSegment(opponent.Root.Position, position, nextPosition) < 3.2 then
				DuelFX:FireAllClients({ Type = "ProjectileHit", Id = id, Position = opponent.Root.Position })
				damage(opponent, power.Damage, fighter)
				onPowerHit(fighter, opponent, power)
				return
			end
			position = nextPosition
			travelled += move
		end
		DuelFX:FireAllClients({ Type = "ProjectileHit", Id = id, Position = position, Miss = true })
	end)
end

local function rotateY(direction, degrees)
	local r = math.rad(degrees)
	local c, s = math.cos(r), math.sin(r)
	return Vector3.new(direction.X * c - direction.Z * s, 0, direction.X * s + direction.Z * c)
end

-- Every power type. Returns false if it couldn't be used (e.g. out of range).
local POWERS = {}

POWERS.Projectile = function(fighter, power, aim)
	local count = power.Count or 1
	local spread = power.Spread or 0
	for i = 1, count do
		local offset = (count == 1) and 0 or (i - (count + 1) / 2) * spread
		fireProjectile(fighter, rotateY(aim, offset), power)
	end
	return true
end

POWERS.Dash = function(fighter, power, aim)
	local start = fighter.Root.Position
	local finish = clampToArena(fighter, start + aim * (power.Distance or 20))
	local opponent = fighter.Opponent
	local hit = distanceToSegment(opponent.Root.Position, start, finish) < 4.5
	fighter.Model:PivotTo(CFrame.lookAt(finish, finish + aim))
	DuelFX:FireAllClients({ Type = "Dash", From = start, To = finish, Colors = fighter.Aura.Colors })
	if power.Dodge then
		fighter.DodgeUntil = os.clock() + power.Dodge
		DuelFX:FireAllClients({ Type = "Afterimage", Target = fighter.Model, Duration = power.Dodge, Colors = fighter.Aura.Colors })
	end
	if hit then
		damage(opponent, power.Damage, fighter)
		onPowerHit(fighter, opponent, power)
	end
	return true
end

POWERS.Shield = function(fighter, power)
	giveShield(fighter, power.Amount, power.Duration or 4)
	if power.Reflect then
		fighter.ReflectUntil = os.clock() + (power.Duration or 4)
		fighter.ReflectAmount = power.Reflect
	end
	return true
end

POWERS.Heal = function(fighter, power)
	heal(fighter, power.Amount)
	if power.Shield then
		giveShield(fighter, power.Shield, power.Duration or 5)
	end
	if power.Regen then
		regen(fighter, power.Regen)
	end
	return true
end

POWERS.Burst = function(fighter, power)
	local opponent = fighter.Opponent
	local distance = (opponent.Root.Position - fighter.Root.Position).Magnitude
	DuelFX:FireAllClients({ Type = "Burst", Position = fighter.Root.Position, Radius = power.Radius, Colors = fighter.Aura.Colors })
	if distance <= power.Radius then
		damage(opponent, power.Damage, fighter)
		onPowerHit(fighter, opponent, power)
		if power.Slow then
			slow(opponent, power.Slow, power.SlowDuration or 3)
		end
		if power.Knockback then
			knockback(opponent, flatDirection(fighter.Root.Position, opponent.Root.Position), power.Knockback)
		end
	end
	return true
end

POWERS.Meteor = function(fighter, power)
	local opponent = fighter.Opponent
	local count = power.Count or 1
	for i = 1, count do
		local target = opponent.Root.Position - Vector3.new(0, 2.8, 0)
		if i > 1 then
			target += Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
		end
		local delayTime = (power.Delay or 0.8) + (i - 1) * 0.3
		DuelFX:FireAllClients({ Type = "Meteor", Target = target, Radius = power.Radius, Delay = delayTime, Colors = fighter.Aura.Colors })
		task.delay(delayTime, function()
			if fighter.Duel and fighter.Duel.State == "Fight" then
				local flat = Vector3.new(opponent.Root.Position.X - target.X, 0, opponent.Root.Position.Z - target.Z)
				if flat.Magnitude <= power.Radius then
					damage(opponent, power.Damage, fighter)
					onPowerHit(fighter, opponent, power)
				end
			end
		end)
	end
	return true
end

local function inRange(fighter, range)
	return (fighter.Opponent.Root.Position - fighter.Root.Position).Magnitude <= range
end

POWERS.Freeze = function(fighter, power)
	if not inRange(fighter, power.Range or 40) then
		return false
	end
	local opponent = fighter.Opponent
	DuelFX:FireAllClients({ Type = "Freeze", From = fighter.Root.Position, Target = opponent.Model, Duration = power.Duration, Colors = fighter.Aura.Colors })
	damage(opponent, power.Damage, fighter)
	stun(opponent, power.Duration or 1.5)
	return true
end

POWERS.Drain = function(fighter, power)
	if not inRange(fighter, power.Range or 40) then
		return false
	end
	local opponent = fighter.Opponent
	DuelFX:FireAllClients({ Type = "Drain", From = opponent.Root.Position, To = fighter.Model, Colors = fighter.Aura.Colors })
	local before = opponent.HP
	damage(opponent, power.Damage, fighter)
	heal(fighter, math.max(0, before - opponent.HP) * (power.Lifesteal or 0.5))
	return true
end

POWERS.Beam = function(fighter, power, aim)
	local start = fighter.Root.Position + Vector3.new(0, 1, 0)
	local finish = start + aim * (power.Range or 60)
	DuelFX:FireAllClients({ Type = "Beam", From = start, To = finish, Colors = fighter.Aura.Colors })
	if distanceToSegment(fighter.Opponent.Root.Position, start, finish) < 3.5 then
		damage(fighter.Opponent, power.Damage, fighter, { Pierce = power.Pierce })
		onPowerHit(fighter, fighter.Opponent, power)
	end
	return true
end

POWERS.Pull = function(fighter, power)
	if not inRange(fighter, power.Range or 50) then
		return false
	end
	local opponent = fighter.Opponent
	local look = flatDirection(fighter.Root.Position, opponent.Root.Position)
	local landing = clampToArena(fighter, fighter.Root.Position + look * 4)
	DuelFX:FireAllClients({ Type = "Pull", From = opponent.Root.Position, To = landing, Colors = fighter.Aura.Colors })
	opponent.Root.AssemblyLinearVelocity = Vector3.zero
	opponent.Model:PivotTo(CFrame.lookAt(landing, fighter.Root.Position * Vector3.new(1, 0, 1) + Vector3.new(0, landing.Y, 0)))
	damage(opponent, power.Damage, fighter)
	if power.Stun then
		stun(opponent, power.Stun)
	end
	return true
end

POWERS.Teleport = function(fighter, power)
	if not inRange(fighter, power.Range or 60) then
		return false
	end
	local opponent = fighter.Opponent
	local behind = clampToArena(fighter, (opponent.Root.CFrame * CFrame.new(0, 0, 4)).Position)
	local from = fighter.Root.Position
	fighter.Model:PivotTo(CFrame.lookAt(behind, opponent.Root.Position * Vector3.new(1, 0, 1) + Vector3.new(0, behind.Y, 0)))
	DuelFX:FireAllClients({ Type = "Teleport", From = from, To = behind, Colors = fighter.Aura.Colors })
	damage(opponent, power.Damage, fighter)
	if power.Stun and opponent.Duel and opponent.Duel.State == "Fight" then
		stun(opponent, power.Stun)
	end
	return true
end

local TARGETED = { Freeze = true, Drain = true, Pull = true, Teleport = true }

local function usePower(fighter, aim)
	if not canAct(fighter) or not fighter.Aura or fighter.Blocking then
		return
	end
	local now = os.clock()
	if now < fighter.PowerReady then
		return
	end
	local power = fighter.Aura.Power
	local handler = POWERS[power.Type]
	if not handler then
		return
	end
	if TARGETED[power.Type] and not inRange(fighter, power.Range or 40) then
		sendTo(fighter, { Type = "OutOfRange" })
		return
	end
	local direction = resolveAim(fighter, aim)
	fighter.PowerReady = now + power.Cooldown
	DuelFX:FireAllClients({
		Type = "PowerCast",
		Caster = fighter.Model,
		Name = power.Name,
		PowerType = power.Type,
		Windup = DUEL.PowerWindup,
		Colors = fighter.Aura.Colors,
	})
	sendTo(fighter, { Type = "PowerUsed", Cooldown = power.Cooldown })
	-- the power fires when the casting animation reaches its peak
	task.delay(DUEL.PowerWindup, function()
		if fighter.Duel and fighter.Duel.State == "Fight" and fighter.Root and fighter.Root.Parent then
			-- re-aim at the moment of release (aim assist still applies)
			handler(fighter, power, resolveAim(fighter, direction))
			-- attack powers can also heal you over time (Heal powers do it themselves)
			if power.Regen and power.Type ~= "Heal" then
				regen(fighter, power.Regen)
			end
		end
	end)
end

---------------------------------------------------------------------
-- BOT BRAIN
---------------------------------------------------------------------
local DEFENSIVE = { Heal = true, Shield = true }

local function botThink(bot)
	if not canAct(bot) then
		return
	end
	local opponent = bot.Opponent
	local settings = bot.Settings
	local now = os.clock()
	local myPosition = bot.Root.Position
	local theirPosition = opponent.Root.Position
	local distance = (theirPosition - myPosition).Magnitude
	local toThem = flatDirection(myPosition, theirPosition)

	local function faceThem()
		bot.Root.CFrame = CFrame.lookAt(myPosition, Vector3.new(theirPosition.X, myPosition.Y, theirPosition.Z))
	end

	-- react to the opponent's attacks: harder bots block or dodge more often
	local theirSwing = opponent.LastAttack or 0
	if now - theirSwing < 0.12 and bot.LastReactedTo ~= theirSwing and distance < DUEL.AttackRange + 2 then
		bot.LastReactedTo = theirSwing
		local roll = rng:NextNumber()
		local skill = settings.Accuracy
		if roll < skill * 0.25 then
			dodge(bot, rotateY(toThem, (rng:NextNumber() < 0.5) and 90 or -90))
		elseif roll < skill * 0.55 then
			setBlocking(bot, true)
			task.delay(rng:NextNumber(0.5, 0.9), function()
				setBlocking(bot, false)
			end)
		end
	end
	if bot.Blocking then
		return
	end

	-- decide every "Reaction" seconds
	if now >= (bot.NextThink or 0) then
		bot.NextThink = now + settings.Reaction * rng:NextNumber(0.7, 1.3)
		local power = bot.Aura and bot.Aura.Power
		if power and now >= bot.PowerReady then
			local want
			if DEFENSIVE[power.Type] then
				want = bot.HP < bot.MaxHP * 0.65
			elseif power.Range then
				want = distance <= power.Range * 0.9
			elseif power.Radius and power.Type == "Burst" then
				want = distance <= power.Radius * 0.85
			else
				want = distance <= 35
			end
			if want then
				local aim = toThem
				if rng:NextNumber() > settings.Accuracy then
					aim = rotateY(toThem, rng:NextNumber(-40, 40))
				end
				faceThem()
				usePower(bot, aim)
			end
		end
		-- pick where to stand: close in, but circle around a bit
		local strafe = rotateY(toThem, (rng:NextNumber() < 0.5) and 90 or -90) * rng:NextNumber(2, 6)
		local wanted = theirPosition - toThem * rng:NextNumber(3, 6) + strafe
		bot.MoveTarget = clampToArena(bot, wanted)
		if rng:NextNumber() < 0.12 then
			bot.Humanoid.Jump = true
		end
	end

	if bot.MoveTarget then
		bot.Humanoid:MoveTo(bot.MoveTarget)
	end
	if distance <= DUEL.AttackRange - 0.5 and now >= bot.NextAttack then
		local aim = toThem
		if rng:NextNumber() > settings.Accuracy then
			aim = rotateY(toThem, 85) -- whiff
		end
		faceThem()
		basicAttack(bot, aim)
		bot.NextAttack = now + DUEL.AttackCooldown * (1.6 - settings.Accuracy * 0.6)
	end
end

---------------------------------------------------------------------
-- MAIN LOOP: timers, speed effects, falling out, bots
---------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, duel in ipairs(duels) do
		if duel.State == "Fight" then
			for _, fighter in ipairs({ duel.A, duel.B }) do
				-- left the game / character gone / died
				if not fighter.Root or not fighter.Root.Parent or not fighter.Humanoid or fighter.Humanoid.Health <= 0 then
					endDuel(duel, fighter.Opponent, "Left")
					break
				end
				-- guard meter: drains while blocking, refills otherwise
				local guardBefore = math.floor(fighter.Guard)
				if fighter.Blocking then
					fighter.Guard = math.max(0, fighter.Guard - DUEL.GuardDrain * (1 / 60))
					if fighter.Guard <= 0 or now < fighter.StunnedUntil then
						fighter.Blocking = false
					end
				else
					fighter.Guard = math.min(DUEL.GuardMax, fighter.Guard + DUEL.GuardRegen * (1 / 60))
				end
				if math.floor(fighter.Guard) ~= guardBefore then
					setFighterAttributes(fighter)
				end
				-- shield runs out
				if fighter.Shield > 0 and now >= fighter.ShieldEnd then
					fighter.Shield = 0
					setFighterAttributes(fighter)
				end
				-- movement speed from stun / slow
				local humanoid = fighter.Humanoid
				if now < fighter.StunnedUntil then
					humanoid.WalkSpeed = 0
					humanoid.JumpPower = 0
					humanoid.JumpHeight = 0
				else
					local speed = fighter.BaseSpeed
					if fighter.Blocking then
						speed *= DUEL.BlockSpeed
					elseif fighter.Player and fighter.Player:GetAttribute("Sprinting") then
						speed *= Config.Movement.DuelSprintMultiplier
					end
					if now < fighter.SlowUntil then
						speed *= (1 - fighter.SlowAmount)
					end
					humanoid.WalkSpeed = speed
					humanoid.JumpPower = fighter.BaseJumpPower
					humanoid.JumpHeight = fighter.BaseJumpHeight
				end
				-- fell out of the arena: back to your spawn (and lose a little HP)
				local center = duel.Arena.Center
				local position = fighter.Root.Position
				local flat = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
				if position.Y < center.Y - 8 or flat.Magnitude > ARENA_RADIUS + 6 then
					fighter.Root.AssemblyLinearVelocity = Vector3.zero
					fighter.Model:PivotTo(fighter.Spawn)
					damage(fighter, 10, fighter.Opponent)
				end
			end
			if duel.State == "Fight" and now >= duel.EndsAt then
				-- time's up: higher HP % wins
				local a, b = duel.A, duel.B
				local pa, pb = a.HP / a.MaxHP, b.HP / b.MaxHP
				if math.abs(pa - pb) < 0.005 then
					endDuel(duel, nil, "Time")
				else
					endDuel(duel, (pa > pb) and a or b, "Time")
				end
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(0.1)
		for _, duel in ipairs(duels) do
			for _, fighter in ipairs({ duel.A, duel.B }) do
				if fighter.Kind == "Bot" and duel.State == "Fight" then
					local ok, err = pcall(botThink, fighter)
					if not ok then
						warn("[DuelService] bot error:", err)
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- REQUESTS FROM PLAYERS
---------------------------------------------------------------------
local function playerFighter(player)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local auraName = player:GetAttribute("EquippedAura")
	local fighter = newFighter("Player", player, character, auraName, player.DisplayName)
	fighter.BaseSpeed = Config.Movement.WalkSpeed
	return fighter
end

local lastRequest = {}

local function challenge(player, targetUserId)
	local target = Players:GetPlayerByUserId(tonumber(targetUserId) or 0)
	if not target or target == player then
		return
	end
	if isPlayerBusy(player) or isPlayerBusy(target) then
		DuelEvent:FireClient(player, { Type = "Notice", Text = "That player is busy right now." })
		return
	end
	if pending[target] and pending[target].Expires > os.clock() then
		DuelEvent:FireClient(player, { Type = "Notice", Text = target.DisplayName .. " already has a challenge waiting." })
		return
	end
	pending[target] = { From = player, Expires = os.clock() + DUEL.ChallengeTimeout }
	DuelEvent:FireClient(target, {
		Type = "Challenge",
		FromUserId = player.UserId,
		FromName = player.DisplayName,
		FromAura = player:GetAttribute("EquippedAura"),
		Timeout = DUEL.ChallengeTimeout,
	})
	DuelEvent:FireClient(player, { Type = "Notice", Text = "Challenge sent to " .. target.DisplayName .. "!" })
	task.delay(DUEL.ChallengeTimeout, function()
		local entry = pending[target]
		if entry and entry.From == player and entry.Expires <= os.clock() + 0.05 then
			pending[target] = nil
			if player.Parent then
				DuelEvent:FireClient(player, { Type = "Notice", Text = target.DisplayName .. " didn't answer." })
			end
		end
	end)
end

local function respond(player, fromUserId, accept)
	local entry = pending[player]
	local challenger = Players:GetPlayerByUserId(tonumber(fromUserId) or 0)
	if not entry or entry.From ~= challenger or entry.Expires < os.clock() then
		DuelEvent:FireClient(player, { Type = "Notice", Text = "That challenge has expired." })
		return
	end
	pending[player] = nil
	if not accept then
		DuelEvent:FireClient(challenger, { Type = "Notice", Text = player.DisplayName .. " declined your duel." })
		return
	end
	if isPlayerBusy(player) or isPlayerBusy(challenger) then
		DuelEvent:FireClient(player, { Type = "Notice", Text = "Someone is already in a duel." })
		return
	end
	local arena = freeArena()
	if not arena then
		DuelEvent:FireClient(player, { Type = "Notice", Text = "Both arenas are busy - try again in a moment!" })
		DuelEvent:FireClient(challenger, { Type = "Notice", Text = "Both arenas are busy - try again in a moment!" })
		return
	end
	local a, b = playerFighter(challenger), playerFighter(player)
	if not a or not b then
		return
	end
	startDuel(a, b, arena)
end

local function fightBot(player, difficulty)
	if isPlayerBusy(player) then
		return
	end
	local settings = botSettings(difficulty)
	if not settings then
		return
	end
	local arena = freeArena()
	if not arena then
		DuelEvent:FireClient(player, { Type = "Notice", Text = "Both arenas are busy - try again in a moment!" })
		return
	end
	local me = playerFighter(player)
	if not me then
		return
	end
	arena.Busy = true -- reserve while the bot loads
	local model = spawnBot(settings, arena.Spawns[2])
	arena.Busy = false
	local bot = newFighter("Bot", nil, model, settings.Aura, settings.Name)
	bot.Settings = settings
	bot.BaseSpeed = settings.Speed
	if not bot.Root or not bot.Humanoid then
		model:Destroy()
		return
	end
	startDuel(me, bot, arena)
end

DuelRequest.OnServerEvent:Connect(function(player, request)
	if type(request) ~= "table" then
		return
	end
	local action = request.Action
	-- light spam protection for menu actions
	if action == "Challenge" or action == "Respond" or action == "Bot" then
		if os.clock() - (lastRequest[player] or 0) < 0.5 then
			return
		end
		lastRequest[player] = os.clock()
	end

	if action == "Challenge" then
		challenge(player, request.Target)
	elseif action == "Respond" then
		respond(player, request.From, request.Accept == true)
	elseif action == "Bot" then
		fightBot(player, request.Difficulty)
	elseif action == "Attack" then
		local fighter = fighterOf[player]
		if fighter then
			basicAttack(fighter, request.Aim)
		end
	elseif action == "Power" then
		local fighter = fighterOf[player]
		if fighter then
			usePower(fighter, request.Aim)
		end
	elseif action == "Block" then
		local fighter = fighterOf[player]
		if fighter then
			setBlocking(fighter, request.On == true)
		end
	elseif action == "Dodge" then
		local fighter = fighterOf[player]
		if fighter then
			dodge(fighter, request.Direction)
		end
	elseif action == "Forfeit" then
		local fighter = fighterOf[player]
		if fighter and fighter.Duel then
			endDuel(fighter.Duel, fighter.Opponent, "Forfeit")
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local fighter = fighterOf[player]
	if fighter and fighter.Duel then
		endDuel(fighter.Duel, fighter.Opponent, "Left")
	end
	pending[player] = nil
	lastRequest[player] = nil
	for target, entry in pairs(pending) do
		if entry.From == player then
			pending[target] = nil
		end
	end
end)
