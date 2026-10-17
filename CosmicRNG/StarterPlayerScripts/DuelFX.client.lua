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
local CombatAnim = require(ReplicatedStorage:WaitForChild("CombatAnim"))
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
				CombatAnim.SetLoop(model, "Stance", true)
			end
			CombatAnim.SetLoop(model, "Block", model:GetAttribute("DuelBlocking") == true)
		end
		for model in pairs(bars) do
			if not alive[model] or not model.Parent then
				removeBar(model)
				if model.Parent then
					CombatAnim.SetLoop(model, "Stance", false)
					CombatAnim.SetLoop(model, "Block", false)
					CombatAnim.SetLoop(model, "Stun", false)
					task.delay(1.6, function()
						if not model:GetAttribute("InDuel") then
							CombatAnim.Release(model)
						end
					end)
				end
			end
		end
	end
end)

RunService.RenderStepped:Connect(function()
	for model, bar in pairs(bars) do
		CombatAnim.SetLoop(model, "Block", model:GetAttribute("DuelBlocking") == true)
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
	soundAt(info.Origin, "Shoot")
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
		soundAt(target, "Explosion", { Volume = 0.9 })
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
		soundAt(root.Position, "ShieldUp")
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
		local clip = (info.Combo == 3) and "Roundhouse" or ((info.Combo == 2) and "JabLeft" or "JabRight")
		local mine = info.Attacker == localPlayer.Character -- your own swing already played instantly
		if not mine then
			CombatAnim.Play(info.Attacker, clip)
		end
		if root then
			if not mine then
				soundAt(root.Position, info.Heavy and "SwingHeavy" or "SwingLight", { Volume = 0.9 })
			end
			if info.Heavy then
				task.delay(0.22, function()
					if root.Parent then
						ring(root.Position - Vector3.new(0, 2.8, 0), info.Color or Color3.new(1, 1, 1), 2, 11, 0.35)
					end
				end)
			end
		end
	elseif kind == "Damage" then
		local root = rootOf(info.Target)
		local attackerRoot = rootOf(info.Attacker)
		local big = info.Heavy or (info.Amount or 0) >= 30
		if info.Kind == "Burn" then
			if info.Amount > 0 then
				floatingText(info.Target, "-" .. info.Amount, Color3.fromRGB(255, 150, 60))
			end
			if root then
				soundAt(root.Position, "BurnCrackle", { Volume = 0.8 })
			end
		elseif info.Amount > 0 then
			-- the body reacts
			if info.WasBlocked then
				CombatAnim.Play(info.Target, "BlockHit")
			else
				CombatAnim.Play(info.Target, big and "HitHeavy" or "HitLight")
				hitFlash(info.Target, Color3.fromRGB(255, 60, 60))
			end
			-- numbers: bigger and angrier for big hits
			local text = "-" .. info.Amount .. (info.Heavy and "!" or "")
			local color = info.WasBlocked and Color3.fromRGB(160, 180, 210)
				or (info.Heavy and Color3.fromRGB(255, 140, 40) or Color3.fromRGB(255, 90, 90))
			floatingText(info.Target, text, color, big)
			if root then
				-- sparks where the hit landed (between the two fighters)
				local contact = root.Position + Vector3.new(0, 0.6, 0)
				if attackerRoot then
					contact = root.Position:Lerp(attackerRoot.Position, 0.3) + Vector3.new(0, 0.8, 0)
				end
				local c = info.Color or Color3.new(1, 1, 1)
				AuraEffects.Burst(contact, { c, Color3.new(1, 1, 1) }, big and 0.9 or 0.45)
				sphere(contact, Color3.new(1, 1, 1), 0.6, big and 6 or 3.5, big and 0.25 or 0.15)
				if not info.WasBlocked then
					soundAt(contact, big and "HeavyHit" or "Jab", { Volume = 1 })
					if big and rand:NextNumber() < 0.6 then
						soundAt(root.Position, "HurtHeavy", { Volume = 0.9 })
					elseif rand:NextNumber() < 0.25 then
						soundAt(root.Position, "HurtLight", { Volume = 0.8 })
					end
				end
				if info.Heavy then
					ring(root.Position - Vector3.new(0, 2.6, 0), c, 3, 16, 0.45)
				end
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
			soundAt(root.Position, "HealShimmer")
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
		soundAt(info.To, "Dodge", { Speed = 0.8 })
	elseif kind == "Burst" then
		local c1, c2 = colorsOf(info)
		sphere(info.Position, c1, 2, info.Radius * 2, 0.5)
		ring(info.Position - Vector3.new(0, 2.6, 0), c2, 2, info.Radius * 2.2, 0.6)
		AuraEffects.Burst(info.Position, { c1, c2 }, 1.2 + info.Radius / 15)
		soundAt(info.Position, "Explosion")
	elseif kind == "Meteor" then
		meteor(info)
	elseif kind == "Freeze" then
		local c1 = colorsOf(info)
		local root = rootOf(info.Target)
		if root then
			line(info.From, root.Position, c1, 1.6, 0.5)
			soundAt(root.Position, "IceShatter")
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
			soundAt(info.From, "Vacuum", { Speed = 1.3 })
		end
	elseif kind == "Beam" then
		local c1, c2 = colorsOf(info)
		line(info.From, info.To, c1, 3, 0.5)
		line(info.From, info.To, Color3.new(1, 1, 1), 1, 0.35)
		line(info.From, info.To, c2, 5, 0.25)
		soundAt(info.From, "BeamFire")
	elseif kind == "Pull" then
		local c1, c2 = colorsOf(info)
		line(info.From, info.To, c1, 2, 0.5)
		sphere(info.To, c2, 8, 1, 0.5, Enum.Material.ForceField)
		soundAt(info.To, "Vacuum")
	elseif kind == "Teleport" then
		local c1, c2 = colorsOf(info)
		sphere(info.From, c1, 4, 0.5, 0.4)
		sphere(info.To, c2, 0.5, 6, 0.4)
		AuraEffects.Burst(info.To, { c1, c2 }, 0.8)
		soundAt(info.To, "TeleportZap")
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

---------------------------------------------------------------------
-- Extra power effects: burning, dodging, reflected hits
---------------------------------------------------------------------
local Lighting = game:GetService("Lighting")

local function burnPuff(model)
	local root = rootOf(model)
	if not root then
		return
	end
	local holder = fxPart({ Size = Vector3.new(2, 4, 2), Transparency = 1, CFrame = root.CFrame })
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = Config.Textures.Fire
	fire.Lifetime = NumberRange.new(0.3, 0.6)
	fire.Speed = NumberRange.new(2, 4)
	fire.Acceleration = Vector3.new(0, 8, 0)
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	fire.LightEmission = 1
	fire.LightInfluence = 0
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 220, 100), Color3.fromRGB(255, 70, 30))
	fire.Enabled = false
	fire.Parent = holder
	fire:Emit(18)
	Debris:AddItem(holder, 1)
end

local function afterimage(info)
	local root = rootOf(info.Target)
	if not root then
		return
	end
	local c1, c2 = colorsOf(info)
	for i = 1, 4 do
		task.delay(i * 0.08, function()
			if root.Parent then
				local ghost = fxPart({
					Size = Vector3.new(2, 5, 1),
					CFrame = root.CFrame,
					Color = (i % 2 == 0) and c1 or c2,
					Transparency = 0.45,
					Material = Enum.Material.ForceField,
				})
				tween(ghost, 0.5, { Transparency = 1, Size = Vector3.new(3, 6, 1.5) })
				Debris:AddItem(ghost, 0.55)
			end
		end)
	end
end

---------------------------------------------------------------------
-- THE FINISHER: a sky beam obliterates the loser
---------------------------------------------------------------------
-- builds a flat ring of neon pieces that we spin each frame
local function buildRing(center, radius, segments, thickness, color)
	local pieces = {}
	for i = 1, segments do
		local piece = fxPart({
			Size = Vector3.new(thickness, thickness, (2 * math.pi * radius / segments) * 0.8),
			Color = color,
			Transparency = 1,
		})
		table.insert(pieces, { Part = piece, Angle = (i / segments) * math.pi * 2 })
	end
	return { Pieces = pieces, Center = center, Radius = radius }
end

local function placeRing(ring, spin, tilt, transparency)
	for _, piece in ipairs(ring.Pieces) do
		local a = piece.Angle + spin
		local p = ring.Center + Vector3.new(math.cos(a) * ring.Radius, math.sin(a + tilt) * tilt * 2, math.sin(a) * ring.Radius)
		piece.Part.CFrame = CFrame.lookAt(p, ring.Center) * CFrame.Angles(0, math.pi / 2, 0)
		piece.Part.Transparency = transparency
	end
end

local function destroyRing(ring)
	for _, piece in ipairs(ring.Pieces) do
		piece.Part:Destroy()
	end
end

local function cylinder(top, bottom, width, color, transparency, material)
	local length = (top - bottom).Magnitude
	return fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, width, width),
		CFrame = CFrame.new((top + bottom) / 2) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Transparency = transparency,
		Material = material or Enum.Material.Neon,
	})
end

local function playFinisher(info)
	local loserRoot = rootOf(info.Loser)
	if not loserRoot then
		return
	end
	local c1, c2 = colorsOf(info)
	local bright1 = c1:Lerp(Color3.new(1, 1, 1), 0.25)
	local order = info.Order or 3
	local duration = info.Duration or 4.6
	local special = info.Special
	local ground = loserRoot.Position - Vector3.new(0, 2.9, 0)
	local sky = ground + Vector3.new(0, 58, 0)
	local cleanup = {}
	local function keep(inst)
		table.insert(cleanup, inst)
		return inst
	end

	local localRoot = rootOf(localPlayer.Character)
	local nearby = localRoot and (localRoot.Position - ground).Magnitude < 260

	-- 1) the world darkens and takes the winner's color
	local grade
	if nearby then
		grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "FinisherGrade"
		grade.Parent = Lighting
		tween(grade, 0.5, { Brightness = -0.12, Saturation = -0.35, Contrast = 0.25, TintColor = Color3.new(1, 1, 1):Lerp(c1, 0.35) })
	end

	-- glow on both fighters
	local loserGlow = Instance.new("Highlight")
	loserGlow.FillColor = Color3.fromRGB(255, 60, 70)
	loserGlow.OutlineColor = Color3.new(1, 1, 1)
	loserGlow.FillTransparency = 0.6
	loserGlow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	loserGlow.Parent = info.Loser
	keep(loserGlow)
	if info.Winner and info.Winner.Parent then
		local winnerGlow = Instance.new("Highlight")
		winnerGlow.FillColor = c1
		winnerGlow.OutlineColor = c2
		winnerGlow.FillTransparency = 0.75
		winnerGlow.Parent = info.Winner
		keep(winnerGlow)
	end

	-- 2) a magic circle forms in the sky
	local rings = {}
	local ringCount = math.clamp(math.ceil(order / 2), 1, 3) + 1
	for i = 1, ringCount do
		table.insert(rings, buildRing(sky, 6 + i * 4.5, 18 + i * 8, 0.6, (i % 2 == 0) and c2 or bright1))
	end
	local orb = keep(fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, CFrame = CFrame.new(sky), Color = Color3.new(1, 1, 1), Transparency = 0 }))
	local orbLight = Instance.new("PointLight")
	orbLight.Color = c1
	orbLight.Range = 40
	orbLight.Brightness = 3
	orbLight.Parent = orb
	tween(orb, 1.3, { Size = Vector3.one * (6 + order) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	-- sparkles getting sucked into the orb
	local gather = keep(fxPart({ Size = Vector3.one * 40, CFrame = CFrame.new(sky), Transparency = 1 }))
	local gatherEmitter = Instance.new("ParticleEmitter")
	gatherEmitter.Texture = Config.Textures.Sparkle
	gatherEmitter.Shape = Enum.ParticleEmitterShape.Sphere
	gatherEmitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	gatherEmitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	gatherEmitter.Rate = 120
	gatherEmitter.Lifetime = NumberRange.new(0.6, 0.9)
	gatherEmitter.Speed = NumberRange.new(25, 35)
	gatherEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	gatherEmitter.LightEmission = 1
	gatherEmitter.LightInfluence = 0
	gatherEmitter.Color = ColorSequence.new(c1, c2)
	gatherEmitter.Parent = gather

	-- rune circle on the ground under the loser
	local rune = buildRing(ground + Vector3.new(0, 0.3, 0), 7, 28, 0.35, c2)
	local runeGems = {}
	for i = 1, 6 do
		table.insert(runeGems, { Part = keep(fxPart({ Size = Vector3.one * 0.9, Color = bright1, Transparency = 1 })), Angle = (i / 6) * math.pi * 2 })
	end

	-- black holes implode before they strike
	if special == "Inward" then
		local implode = keep(fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 26, CFrame = CFrame.new(loserRoot.Position), Color = Color3.new(0, 0, 0), Transparency = 0.6, Material = Enum.Material.ForceField }))
		tween(implode, 1.3, { Size = Vector3.one * 1, Transparency = 0.1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end

	-- sounds: rumble + heartbeats while charging
	local rumbleHolder = keep(fxPart({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(ground) }))
	local rumble = SoundFX.Loop("Rumble", 0.5, { Parent = rumbleHolder, MaxDistance = 300, Volume = 1.4 })
	soundAt(ground, "Heartbeat", { Volume = 1, MaxDistance = 260 })
	task.delay(0.6, function()
		soundAt(ground, "Heartbeat", { Volume = 1.2, Speed = 1.1, MaxDistance = 260 })
	end)

	local start = os.clock()
	local strikeAt = 1.3
	local fadeAt = 2.8
	local struck = false
	local beams = {}
	local laser
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > duration then
			connection:Disconnect()
			return
		end
		-- spin the sky rings (fade in, then out after the strike)
		local ringAlpha = (t < 0.5) and (1 - t / 0.5 * 0.85) or ((t < fadeAt) and 0.15 or math.min(1, 0.15 + (t - fadeAt) / 0.6))
		for i, ring in ipairs(rings) do
			placeRing(ring, t * (i % 2 == 0 and -1.4 or 1.1) * (1 + (struck and 1.5 or 0)), 0, ringAlpha)
		end
		placeRing(rune, -t * 0.8, 0, ringAlpha)
		for _, gem in ipairs(runeGems) do
			local a = gem.Angle + t * 1.6
			gem.Part.CFrame = CFrame.new(rune.Center + Vector3.new(math.cos(a) * 9, 0.6 + math.sin(t * 4 + gem.Angle) * 0.3, math.sin(a) * 9)) * CFrame.Angles(math.rad(45), a, math.rad(45))
			gem.Part.Transparency = ringAlpha
		end
		-- flickering targeting laser before the strike
		if not struck then
			if not laser then
				laser = keep(fxPart({ Size = Vector3.new(0.3, 0.3, 58), Color = Color3.fromRGB(255, 60, 70), Transparency = 0.5 }))
			end
			laser.CFrame = CFrame.lookAt((sky + ground) / 2, ground)
			laser.Transparency = (math.floor(t * 20) % 2 == 0) and 0.2 or 0.7
		end
		-- rainbow auras: the beam cycles through colors
		if struck and special == "Rainbow" and beams[2] then
			beams[2].Color = Color3.fromHSV((t * 0.8) % 1, 0.8, 1)
		end
		-- the beam pulses while it burns
		if struck and t < fadeAt and beams[1] then
			local pulse = 1 + math.sin(t * 30) * 0.08
			for i, beam in ipairs(beams) do
				local width = ({ 5, 11, 17 })[i] * pulse * (0.8 + order * 0.05)
				beam.Size = Vector3.new(beam.Size.X, width, width)
			end
		end
	end)

	-- 3) STRIKE
	task.delay(strikeAt, function()
		struck = true
		if laser then
			laser:Destroy()
		end
		gatherEmitter.Enabled = false
		tween(orb, 0.15, { Size = Vector3.one * 2, Transparency = 0.3 })

		-- three layers of beam from the sky to the ground
		local layers = {
			{ Color = Color3.new(1, 1, 1), Transparency = 0, Material = Enum.Material.Neon },
			{ Color = c1, Transparency = 0.2, Material = Enum.Material.Neon },
			{ Color = c2, Transparency = 0.35, Material = Enum.Material.ForceField },
		}
		for _, layer in ipairs(layers) do
			local beam = keep(cylinder(sky + Vector3.new(0, 60, 0), ground, 0.5, layer.Color, layer.Transparency, layer.Material))
			table.insert(beams, beam)
		end
		local beamLight = Instance.new("PointLight")
		beamLight.Color = c1
		beamLight.Range = 60
		beamLight.Brightness = 12
		beamLight.Parent = beams[1]
		tween(beamLight, fadeAt - strikeAt + 0.5, { Brightness = 0 })

		-- impact: bursts, shockwaves, sparks, smoke
		AuraEffects.Burst(ground + Vector3.new(0, 2, 0), { c1, c2 }, 2.5 + order * 0.3)
		task.delay(0.15, function()
			AuraEffects.Burst(ground + Vector3.new(0, 4, 0), { Color3.new(1, 1, 1), c1 }, 2)
		end)
		for i = 1, 3 do
			task.delay((i - 1) * 0.18, function()
				ring(ground + Vector3.new(0, 0.3, 0), (i == 2) and c2 or c1, 4, 40 + order * 6 + i * 8, 0.9)
			end)
		end
		sphere(ground + Vector3.new(0, 3, 0), Color3.new(1, 1, 1), 4, 22 + order * 2, 0.45)

		local impact = keep(fxPart({ Size = Vector3.one, CFrame = CFrame.new(ground + Vector3.new(0, 1, 0)), Transparency = 1 }))
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = Config.Textures.Spark
		sparks.Enabled = false
		sparks.Lifetime = NumberRange.new(0.6, 1.4)
		sparks.Speed = NumberRange.new(30, 70)
		sparks.SpreadAngle = Vector2.new(80, 80)
		sparks.Acceleration = Vector3.new(0, -40, 0)
		sparks.Drag = 1.5
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), c1)
		sparks.Parent = impact
		sparks:Emit(140 + order * 20)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = Config.Textures.Smoke
		smoke.Enabled = false
		smoke.Lifetime = NumberRange.new(1.2, 2)
		smoke.Speed = NumberRange.new(12, 20)
		smoke.SpreadAngle = Vector2.new(90, 5)
		smoke.EmissionDirection = Enum.NormalId.Top
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		smoke.Color = ColorSequence.new((special == "Dark") and Color3.fromRGB(20, 10, 25) or c2:Lerp(Color3.new(1, 1, 1), 0.4))
		smoke.Parent = impact
		smoke:Emit(50)

		-- fire auras get roaring flames around the beam
		if special == "Fire" then
			local flames = Instance.new("ParticleEmitter")
			flames.Texture = Config.Textures.Fire
			flames.Rate = 90
			flames.Lifetime = NumberRange.new(0.5, 1)
			flames.Speed = NumberRange.new(8, 16)
			flames.Acceleration = Vector3.new(0, 20, 0)
			flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 0) })
			flames.LightEmission = 1
			flames.LightInfluence = 0
			flames.Color = ColorSequence.new(Color3.fromRGB(255, 220, 100), Color3.fromRGB(255, 60, 20))
			flames.Parent = impact
			task.delay(fadeAt - strikeAt, function()
				flames.Enabled = false
			end)
		end

		-- debris flies out in every direction (real physics, only on this screen)
		local debrisColor = (special == "Snow") and Color3.fromRGB(200, 240, 255) or c1
		for _ = 1, 12 + order * 4 do
			local shard = Instance.new("Part")
			shard.Size = Vector3.new(rand:NextNumber(0.6, 1.6), rand:NextNumber(0.6, 1.6), rand:NextNumber(0.6, 1.6))
			shard.Material = Enum.Material.Neon
			shard.Color = (rand:NextNumber() < 0.5) and debrisColor or c2
			shard.CanQuery = false
			shard.CanTouch = false
			shard.CFrame = CFrame.new(ground + Vector3.new(rand:NextNumber(-2, 2), 1.5, rand:NextNumber(-2, 2)))
				* CFrame.Angles(rand:NextNumber(0, 6), rand:NextNumber(0, 6), rand:NextNumber(0, 6))
			shard.Parent = folder
			local angle = rand:NextNumber(0, math.pi * 2)
			shard.AssemblyLinearVelocity = Vector3.new(math.cos(angle), 0, math.sin(angle)) * rand:NextNumber(25, 55) + Vector3.new(0, rand:NextNumber(35, 70), 0)
			shard.AssemblyAngularVelocity = Vector3.new(rand:NextNumber(-12, 12), rand:NextNumber(-12, 12), rand:NextNumber(-12, 12))
			task.delay(1.8, function()
				if shard.Parent then
					tween(shard, 0.6, { Transparency = 1, Size = Vector3.one * 0.1 })
				end
			end)
			Debris:AddItem(shard, 2.5)
		end

		-- the big sound
		soundAt(ground, "RevealMythic", { Volume = 1.6, MaxDistance = 400 })
		soundAt(ground, "Heartbeat", { Speed = 0.6, Volume = 1.6, MaxDistance = 400 })
		soundAt(ground, "Zap", { Speed = 0.6, Volume = 1.2, MaxDistance = 400 })
		SoundFX.FadeOut(rumble, 1.5)

		-- the loser glows white and dissolves into rising sparkles
		tween(loserGlow, 0.5, { FillColor = Color3.new(1, 1, 1), FillTransparency = 0 })
		task.delay(0.7, function()
			if info.Loser and info.Loser.Parent then
				for _, item in ipairs(info.Loser:GetDescendants()) do
					if item:IsA("BasePart") then
						item.LocalTransparencyModifier = 1
					end
				end
			end
			loserGlow.Enabled = false
			local soul = keep(fxPart({ Size = Vector3.new(2, 5, 2), CFrame = CFrame.new(ground + Vector3.new(0, 3, 0)), Transparency = 1 }))
			local rise = Instance.new("ParticleEmitter")
			rise.Texture = Config.Textures.Sparkle
			rise.Rate = 80
			rise.Lifetime = NumberRange.new(1, 1.6)
			rise.Speed = NumberRange.new(4, 8)
			rise.EmissionDirection = Enum.NormalId.Top
			rise.SpreadAngle = Vector2.new(25, 25)
			rise.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
			rise.LightEmission = 1
			rise.LightInfluence = 0
			rise.Color = ColorSequence.new(Color3.new(1, 1, 1), c1)
			rise.Parent = soul
			task.delay(1, function()
				rise.Enabled = false
			end)
		end)
	end)

	-- 4) the beam fades, "ELIMINATED" appears
	task.delay(fadeAt, function()
		for _, beam in ipairs(beams) do
			tween(beam, 0.5, { Size = Vector3.new(beam.Size.X, 0.1, 0.1), Transparency = 1 })
		end
		tween(orb, 0.5, { Transparency = 1, Size = Vector3.one * 12 })
		local tag = keep(fxPart({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(ground + Vector3.new(0, 7, 0)) }))
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(420, 110)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.MaxDistance = 260
		gui.Parent = tag
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 0.62)
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.Text = "ELIMINATED"
		title.TextColor3 = Color3.fromRGB(255, 70, 80)
		title.Parent = gui
		local outline = Instance.new("UIStroke")
		outline.Thickness = 3
		outline.Parent = title
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromScale(0, 0.62)
		sub.Size = UDim2.fromScale(1, 0.38)
		sub.Font = Enum.Font.FredokaOne
		sub.TextScaled = true
		sub.Text = ("by %s%s"):format(info.WinnerName or "?", info.AuraName and (" • " .. info.AuraName) or "")
		sub.TextColor3 = bright1
		sub.Parent = gui
		local subOutline = Instance.new("UIStroke")
		subOutline.Thickness = 2
		subOutline.Parent = sub
		local pop = Instance.new("UIScale")
		pop.Scale = 2
		pop.Parent = title
		tween(pop, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	end)

	-- 5) clean up and give the loser their body back
	task.delay(duration + 0.1, function()
		for _, ringItem in ipairs(rings) do
			destroyRing(ringItem)
		end
		destroyRing(rune)
		for _, inst in ipairs(cleanup) do
			if inst.Parent then
				inst:Destroy()
			end
		end
		if grade then
			tween(grade, 0.6, { Brightness = 0, Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) })
			Debris:AddItem(grade, 0.7)
		end
		if info.Loser and info.Loser.Parent then
			for _, item in ipairs(info.Loser:GetDescendants()) do
				if item:IsA("BasePart") then
					item.LocalTransparencyModifier = 0
				end
			end
		end
	end)
end

DuelFX.OnClientEvent:Connect(function(info)
	local kind = info.Type
	if kind == "Burn" then
		burnPuff(info.Target)
	elseif kind == "Dodge" then
		floatingText(info.Target, "DODGE!", Color3.fromRGB(200, 180, 255))
	elseif kind == "Afterimage" then
		afterimage(info)
	elseif kind == "Finisher" then
		playFinisher(info)
	end
end)


---------------------------------------------------------------------
-- Blocks, guard breaks, dodges, casting poses, stuns, victory poses
---------------------------------------------------------------------
local function shieldFlash(model, attackerModel)
	local root = rootOf(model)
	if not root then
		return
	end
	local facing = root.CFrame.LookVector
	local attackerRoot = rootOf(attackerModel)
	if attackerRoot then
		local d = attackerRoot.Position - root.Position
		d = Vector3.new(d.X, 0, d.Z)
		if d.Magnitude > 0.1 then
			facing = d.Unit
		end
	end
	local center = root.Position + facing * 2 + Vector3.new(0, 0.5, 0)
	local shield = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 5, 5),
		CFrame = CFrame.lookAt(center, center + facing) * CFrame.Angles(0, math.pi / 2, 0),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.ForceField,
		Transparency = 0,
	})
	tween(shield, 0.3, { Size = Vector3.new(0.1, 6.5, 6.5), Transparency = 1 })
	Debris:AddItem(shield, 0.35)
	AuraEffects.Burst(center, { Color3.fromRGB(150, 220, 255), Color3.new(1, 1, 1) }, 0.35)
	soundAt(center, "Block")
end

local function guardBreak(model)
	local root = rootOf(model)
	if not root then
		return
	end
	floatingText(model, "GUARD BREAK!", Color3.fromRGB(120, 200, 255), true)
	for _ = 1, 10 do
		local shard = Instance.new("Part")
		shard.Size = Vector3.new(0.5, 0.8, 0.1)
		shard.Material = Enum.Material.Glass
		shard.Color = Color3.fromRGB(150, 210, 255)
		shard.Transparency = 0.2
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CFrame = root.CFrame * CFrame.new(rand:NextNumber(-1.5, 1.5), rand:NextNumber(-0.5, 1.5), -1.5)
		shard.Parent = folder
		shard.AssemblyLinearVelocity = Vector3.new(rand:NextNumber(-20, 20), rand:NextNumber(10, 25), rand:NextNumber(-20, 20))
		Debris:AddItem(shard, 1.5)
	end
	soundAt(root.Position, "GuardBreak")
	CombatAnim.Play(model, "HitHeavy")
end

local function dodgeRoll(info)
	local mine = info.Target == localPlayer.Character -- already played on your screen
	if not mine then
		CombatAnim.Play(info.Target, "Dodge")
	end
	local root = rootOf(info.Target)
	if root then
		if not mine then
			soundAt(root.Position, "Dodge")
		end
		afterimage({ Target = info.Target, Colors = info.Colors or { Color3.fromRGB(200, 200, 255), Color3.fromRGB(140, 140, 255) } })
		ring(root.Position - Vector3.new(0, 2.8, 0), Color3.fromRGB(200, 200, 255), 2, 7, 0.3)
	end
end

local function castPose(info)
	local pose = CombatAnim.PowerPose[info.PowerType] or "CastForward"
	CombatAnim.Play(info.Caster, pose)
	local c1 = colorsOf(info)
	-- energy gathers in the hands while winding up
	for _, handName in ipairs({ "RightHand", "LeftHand" }) do
		local hand = info.Caster and info.Caster:FindFirstChild(handName)
		if hand then
			local orb = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4, CFrame = hand.CFrame, Color = c1, Transparency = 0.1 })
			local light = Instance.new("PointLight")
			light.Color = c1
			light.Range = 8
			light.Brightness = 3
			light.Parent = orb
			local start = os.clock()
			local windup = info.Windup or 0.2
			local connection
			connection = RunService.RenderStepped:Connect(function()
				local t = os.clock() - start
				if t > windup + 0.15 or not hand.Parent then
					connection:Disconnect()
					orb:Destroy()
					return
				end
				orb.CFrame = hand.CFrame
				orb.Size = Vector3.one * (0.4 + math.min(t / windup, 1) * 1.4)
			end)
		end
	end
	local root = rootOf(info.Caster)
	if root then
		soundAt(root.Position, "Zap", { Speed = 2.2, Volume = 0.6 })
	end
end

DuelFX.OnClientEvent:Connect(function(info)
	local kind = info.Type
	if kind == "Block" then
		shieldFlash(info.Target, info.Attacker)
	elseif kind == "GuardBreak" then
		guardBreak(info.Target)
		CombatAnim.SetLoop(info.Target, "Stun", true)
		task.delay(1, function()
			if info.Target then
				CombatAnim.SetLoop(info.Target, "Stun", false)
			end
		end)
	elseif kind == "DodgeRoll" then
		dodgeRoll(info)
	elseif kind == "PowerCast" then
		castPose(info)
	elseif kind == "Stun" then
		CombatAnim.SetLoop(info.Target, "Stun", true)
		task.delay(info.Duration or 1, function()
			if info.Target then
				CombatAnim.SetLoop(info.Target, "Stun", false)
			end
		end)
	elseif kind == "Dash" then
		-- the caster leans into the dash (DashLean comes from the cast pose)
	elseif kind == "DuelEnd" then
		if info.Winner then
			CombatAnim.Play(info.Winner, "Victory")
		end
	end
end)
