-- DuelFX (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Draws everything that happens in duels, for fighters AND spectators:
-- damage numbers, hit flashes, projectiles, beams, explosions, meteors,
-- shields, freezes, plus a health bar over every fighter's head.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local AuraEffects = require(ReplicatedStorage:WaitForChild("AuraEffects"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))

local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local DuelFX = remotes:WaitForChild("DuelFX", 60)
if not DuelFX then
	return
end

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local rand = Random.new()

local folder = workspace:FindFirstChild("LocalDuelFX") or Instance.new("Folder")
folder.Name = "LocalDuelFX"
folder.Parent = workspace

local function tween(inst, duration, props, style, direction)
	local tw = TweenService:Create(inst, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = folder
	return p
end

local function rootOf(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end

local function colorsOf(info)
	local colors = info.Colors
	if type(colors) == "table" and colors[1] then
		return colors[1], colors[2] or colors[1]
	end
	return Color3.new(1, 1, 1), Color3.new(1, 1, 1)
end

-- a sound coming from a spot in the world
local function soundAt(position, name, opts)
	local holder = fxPart({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(position) })
	opts = opts or {}
	opts.Parent = holder
	opts.MaxDistance = opts.MaxDistance or 160
	SoundFX.Play(name, opts)
	Debris:AddItem(holder, 5)
end

local function line(from, to, color, width, duration)
	local length = (to - from).Magnitude
	if length < 0.05 then
		return
	end
	local beam = fxPart({
		Size = Vector3.new(width, width, length),
		CFrame = CFrame.lookAt((from + to) / 2, to),
		Color = color,
		Transparency = 0.1,
	})
	tween(beam, duration, { Size = Vector3.new(0.05, 0.05, length), Transparency = 1 })
	Debris:AddItem(beam, duration + 0.1)
	return beam
end

local function ring(position, color, startSize, endSize, duration)
	local r = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, startSize, startSize),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Transparency = 0.15,
	})
	tween(r, duration, { Size = Vector3.new(0.05, endSize, endSize), Transparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(r, duration + 0.1)
end

local function sphere(position, color, startSize, endSize, duration, material)
	local s = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * startSize,
		CFrame = CFrame.new(position),
		Color = color,
		Transparency = 0.2,
		Material = material or Enum.Material.Neon,
	})
	tween(s, duration, { Size = Vector3.one * endSize, Transparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(s, duration + 0.1)
end

---------------------------------------------------------------------
-- Floating numbers + hit flash
---------------------------------------------------------------------
local function floatingText(model, text, color, big)
	local root = rootOf(model)
	if not root then
		return
	end
	local holder = fxPart({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(root.Position + Vector3.new(rand:NextNumber(-1.5, 1.5), 2.5, rand:NextNumber(-1.5, 1.5))) })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(big and 160 or 120, big and 60 or 46)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = holder
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.Text = text
	textLabel.TextColor3 = color
	textLabel.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Thickness = 2.5
	outline.Parent = textLabel
	local scale = Instance.new("UIScale")
	scale.Scale = 1.6
	scale.Parent = textLabel
	tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(gui, 0.9, { StudsOffset = Vector3.new(0, 3, 0) })
	task.delay(0.5, function()
		tween(textLabel, 0.4, { TextTransparency = 1 })
		tween(outline, 0.4, { Transparency = 1 })
	end)
	Debris:AddItem(holder, 1)
end

local function hitFlash(model, color)
	if not model or not model.Parent then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	tween(highlight, 0.35, { FillTransparency = 1, OutlineTransparency = 1 })
	Debris:AddItem(highlight, 0.4)
end

---------------------------------------------------------------------
-- Health bars over every fighter (for spectators too)
---------------------------------------------------------------------
local bars = {} -- [model] = { Gui, Fill, Text }

local function makeBar(model)
	local head = model:FindFirstChild("Head") or rootOf(model)
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "DuelBar"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(170, 40)
	gui.StudsOffset = Vector3.new(0, 5.6, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 18)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = "⚔ " .. (model:GetAttribute("DuelName") or model.Name)
	name.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Thickness = 1.5
	outline.Parent = name
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 20)
	back.Size = UDim2.new(1, 0, 0, 14)
	back.BackgroundColor3 = Color3.fromRGB(30, 20, 40)
	back.BorderSizePixel = 0
	back.Parent = gui
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(1, 0)
	backCorner.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 130)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	bars[model] = { Gui = gui, Fill = fill }
end

local function removeBar(model)
	local bar = bars[model]
	if bar then
		bar.Gui:Destroy()
		bars[model] = nil
	end
end

local function fightersInWorld()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character:GetAttribute("InDuel") then
			table.insert(list, player.Character)
		end
	end
	local botFolder = workspace:FindFirstChild("DuelBots")
	if botFolder then
		for _, bot in ipairs(botFolder:GetChildren()) do
			if bot:GetAttribute("InDuel") then
				table.insert(list, bot)
			end
		end
	end
	return list
end

task.spawn(function()
	while true do
		task.wait(0.3)
		local alive = {}
		for _, model in ipairs(fightersInWorld()) do
			alive[model] = true
			if not bars[model] then
				makeBar(model)
			end
		end
		for model in pairs(bars) do
			if not alive[model] or not model.Parent then
				removeBar(model)
			end
		end
	end
end)

RunService.RenderStepped:Connect(function()
	for model, bar in pairs(bars) do
		local hp = model:GetAttribute("DuelHP") or 0
		local maxHp = math.max(model:GetAttribute("DuelMaxHP") or 1, 1)
		local fraction = math.clamp(hp / maxHp, 0, 1)
		bar.Fill.Size = UDim2.fromScale(fraction, 1)
		bar.Fill.BackgroundColor3 = Color3.fromRGB(255, 80, 90):Lerp(Color3.fromRGB(90, 220, 130), fraction)
	end
end)

---------------------------------------------------------------------
-- Projectiles (the server decides hits; we draw the same path)
---------------------------------------------------------------------
local projectiles = {} -- [id] = part

local function spawnProjectile(info)
	local c1, c2 = colorsOf(info)
	local orb = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.4,
		CFrame = CFrame.new(info.Origin),
		Color = c1,
	})
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.6, 0)
	a0.Parent = orb
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.6, 0)
	a1.Parent = orb
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.25
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(c1, c2)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	trail.Parent = orb
	local light = Instance.new("PointLight")
	light.Color = c1
	light.Range = 10
	light.Brightness = 2
	light.Parent = orb
	projectiles[info.Id] = orb
	local duration = info.Range / info.Speed
	tween(orb, duration, { CFrame = CFrame.new(info.Origin + info.Direction * info.Range) }, Enum.EasingStyle.Linear)
	Debris:AddItem(orb, duration + 0.2)
	soundAt(info.Origin, "Zap", { Speed = 1.6, Volume = 0.6 })
end

local function projectileHit(info)
	local orb = projectiles[info.Id]
	projectiles[info.Id] = nil
	local color = orb and orb.Color or Color3.new(1, 1, 1)
	if orb then
		orb:Destroy()
	end
	if not info.Miss then
		AuraEffects.Burst(info.Position, { color, Color3.new(1, 1, 1) }, 0.5)
	end
end

---------------------------------------------------------------------
-- Meteors: red warning circle, then a rock falls from the sky
---------------------------------------------------------------------
local function meteor(info)
	local c1, c2 = colorsOf(info)
	local target = info.Target
	local warning = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, info.Radius * 2, info.Radius * 2),
		CFrame = CFrame.new(target + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 60, 60),
		Transparency = 0.6,
	})
	tween(warning, info.Delay, { Transparency = 0.2 }, Enum.EasingStyle.Linear)
	Debris:AddItem(warning, info.Delay + 0.1)
	local rock = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3,
		CFrame = CFrame.new(target + Vector3.new(12, 60, 6)),
		Color = c1,
	})
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = Config.Textures.Fire
	fire.Rate = 60
	fire.Lifetime = NumberRange.new(0.3, 0.6)
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 0) })
	fire.LightEmission = 1
	fire.LightInfluence = 0
	fire.Color = ColorSequence.new(c1, c2)
	fire.Parent = rock
	tween(rock, info.Delay, { CFrame = CFrame.new(target) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(info.Delay, function()
		rock:Destroy()
		AuraEffects.Burst(target + Vector3.new(0, 1, 0), { c1, c2 }, 1.2)
		ring(target + Vector3.new(0, 0.2, 0), c1, 2, info.Radius * 2.4, 0.6)
		soundAt(target, "RevealRare", { Volume = 0.8 })
	end)
end

---------------------------------------------------------------------
-- Shields + freezes stay on a fighter for a while
---------------------------------------------------------------------
local function followFor(model, part, duration, offset)
	local root = rootOf(model)
	if not root then
		part:Destroy()
		return
	end
	local stop = os.clock() + duration
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if os.clock() > stop or not root.Parent then
			connection:Disconnect()
			tween(part, 0.25, { Transparency = 1 })
			Debris:AddItem(part, 0.3)
			return
		end
		part.CFrame = root.CFrame * (offset or CFrame.new())
	end)
end

local function shieldBubble(info)
	local bubble = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 7,
		Color = info.Color or Color3.fromRGB(140, 200, 255),
		Material = Enum.Material.ForceField,
		Transparency = 0,
	})
	followFor(info.Target, bubble, info.Duration or 4)
	local root = rootOf(info.Target)
	if root then
		soundAt(root.Position, "Freeze", { Speed = 1.8, Volume = 0.6 })
	end
end

local function iceBlock(model, duration)
	local block = fxPart({
		Size = Vector3.new(4.5, 6.5, 4.5),
		Color = Color3.fromRGB(170, 230, 255),
		Material = Enum.Material.Ice,
		Transparency = 0.35,
	})
	followFor(model, block, duration, CFrame.new(0, -0.3, 0))
end

---------------------------------------------------------------------
-- Power name floating over the caster
---------------------------------------------------------------------
local function powerCallout(info)
	local c1 = colorsOf(info)
	floatingText(info.Caster, "⚡ " .. info.Name .. "!", c1:Lerp(Color3.new(1, 1, 1), 0.25), true)
	local root = rootOf(info.Caster)
	if root then
		ring(root.Position - Vector3.new(0, 2.8, 0), c1, 2, 12, 0.5)
	end
end

---------------------------------------------------------------------
-- Handle every effect message
---------------------------------------------------------------------
DuelFX.OnClientEvent:Connect(function(info)
	local kind = info.Type
	if kind == "Swing" then
		local root = rootOf(info.Attacker)
		if root then
			local from = root.Position + Vector3.new(0, 0.5, 0)
			local to = from + info.Direction * 6
			line(from, to, info.Color or Color3.new(1, 1, 1), info.Hit and 1 or 0.5, 0.2)
			if info.Hit then
				soundAt(to, "Punch")
			else
				soundAt(from, "Swoosh", { Volume = 0.7 })
			end
		end
	elseif kind == "Damage" then
		if info.Amount > 0 then
			floatingText(info.Target, "-" .. info.Amount, Color3.fromRGB(255, 90, 90), info.Amount >= 30)
			hitFlash(info.Target, Color3.fromRGB(255, 60, 60))
			local root = rootOf(info.Target)
			if root then
				soundAt(root.Position, "Hit")
				sphere(root.Position, info.Color or Color3.new(1, 1, 1), 1, 5, 0.3)
			end
		end
		if info.Blocked and info.Blocked > 0 then
			floatingText(info.Target, "🛡" .. info.Blocked, Color3.fromRGB(140, 200, 255))
		end
	elseif kind == "Heal" then
		floatingText(info.Target, "+" .. math.floor(info.Amount + 0.5), Color3.fromRGB(110, 255, 150), true)
		hitFlash(info.Target, Color3.fromRGB(110, 255, 150))
		local root = rootOf(info.Target)
		if root then
			AuraEffects.Burst(root.Position, { Color3.fromRGB(110, 255, 150), Color3.new(1, 1, 1) }, 0.6)
			soundAt(root.Position, "Purchase", { Speed = 1.2 })
		end
	elseif kind == "Shield" then
		shieldBubble(info)
	elseif kind == "Stun" then
		iceBlock(info.Target, info.Duration)
	elseif kind == "PowerCast" then
		powerCallout(info)
	elseif kind == "Projectile" then
		spawnProjectile(info)
	elseif kind == "ProjectileHit" then
		projectileHit(info)
	elseif kind == "Dash" then
		local c1, c2 = colorsOf(info)
		line(info.From, info.To, c1, 2.5, 0.4)
		line(info.From, info.To, c2, 1, 0.6)
		AuraEffects.Burst(info.To, { c1, c2 }, 0.6)
		soundAt(info.To, "Swoosh", { Speed = 0.8 })
	elseif kind == "Burst" then
		local c1, c2 = colorsOf(info)
		sphere(info.Position, c1, 2, info.Radius * 2, 0.5)
		ring(info.Position - Vector3.new(0, 2.6, 0), c2, 2, info.Radius * 2.2, 0.6)
		AuraEffects.Burst(info.Position, { c1, c2 }, 1.2 + info.Radius / 15)
		soundAt(info.Position, "RevealLegendary", { Volume = 0.8 })
	elseif kind == "Meteor" then
		meteor(info)
	elseif kind == "Freeze" then
		local c1 = colorsOf(info)
		local root = rootOf(info.Target)
		if root then
			line(info.From, root.Position, c1, 1.6, 0.5)
			soundAt(root.Position, "Freeze")
		end
	elseif kind == "Drain" then
		local c1, c2 = colorsOf(info)
		local root = rootOf(info.To)
		if root then
			for i = 1, 3 do
				task.delay(i * 0.08, function()
					line(info.From, root.Position, (i % 2 == 0) and c1 or c2, 1.2, 0.5)
				end)
			end
			soundAt(info.From, "Zap", { Speed = 0.7 })
		end
	elseif kind == "Beam" then
		local c1, c2 = colorsOf(info)
		line(info.From, info.To, c1, 3, 0.5)
		line(info.From, info.To, Color3.new(1, 1, 1), 1, 0.35)
		line(info.From, info.To, c2, 5, 0.25)
		soundAt(info.From, "Zap")
	elseif kind == "Pull" then
		local c1, c2 = colorsOf(info)
		line(info.From, info.To, c1, 2, 0.5)
		sphere(info.To, c2, 8, 1, 0.5, Enum.Material.ForceField)
		soundAt(info.To, "RevealMythic", { Volume = 0.6 })
	elseif kind == "Teleport" then
		local c1, c2 = colorsOf(info)
		sphere(info.From, c1, 4, 0.5, 0.4)
		sphere(info.To, c2, 0.5, 6, 0.4)
		AuraEffects.Burst(info.To, { c1, c2 }, 0.8)
		soundAt(info.To, "Zap", { Speed = 1.3 })
	elseif kind == "DuelStart" then
		if info.Center then
			ring(info.Center + Vector3.new(0, 0.3, 0), Color3.fromRGB(255, 80, 100), 4, 34, 1)
		end
	elseif kind == "DuelEnd" then
		local root = rootOf(info.Winner)
		if root then
			AuraEffects.Burst(root.Position, { Color3.fromRGB(255, 210, 90), Color3.new(1, 1, 1) }, 2)
			local beam = fxPart({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(300, 6, 6),
				CFrame = CFrame.new(root.Position + Vector3.new(0, 150, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				Color = Color3.fromRGB(255, 210, 90),
				Transparency = 0.2,
			})
			tween(beam, 2, { Size = Vector3.new(300, 0.2, 0.2), Transparency = 1 })
			Debris:AddItem(beam, 2.1)
		end
	end
end)
