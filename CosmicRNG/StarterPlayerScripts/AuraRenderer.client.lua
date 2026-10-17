-- AuraRenderer (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Draws everything about OTHER players (and you) in the 3D world:
--   * every player's aura (the server only sets an "Aura" attribute)
--   * floating name tags with aura + VIP crown
--   * roll effects everyone can see (charge-up, reveal pillars, sky beams)
--   * [VIP] and aura tags in chat

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))
local Rebirth = require(ReplicatedStorage:WaitForChild("Rebirth"))
local AuraEffects = require(ReplicatedStorage:WaitForChild("AuraEffects"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))

local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local RollFXRemote = remotes:WaitForChild("RollFX")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local tracked = {} -- [character] = true
local handles = {} -- [character] = aura handle
local tags = {} -- [character] = { Gui, Gradient, Order, Phase }

local GOLD = Color3.fromRGB(255, 200, 70)

local function fxFolder()
	local folder = workspace:FindFirstChild("LocalAuraFX")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LocalAuraFX"
		folder.Parent = workspace
	end
	return folder
end

local function fxPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	for key, value in pairs(props) do
		part[key] = value
	end
	part.Parent = fxFolder()
	return part
end

local function tween(inst, duration, props, style, direction)
	local tw = TweenService:Create(inst, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function readable(color)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, math.max(v, 0.6))
end

---------------------------------------------------------------------
-- NAME TAGS
---------------------------------------------------------------------
local function isVIP(character)
	local player = Players:GetPlayerFromCharacter(character)
	return player ~= nil and player:GetAttribute("Pass_VIP") == true
end

local function rebirthsOf(character)
	local player = Players:GetPlayerFromCharacter(character)
	return player and (player:GetAttribute("Rebirths") or 0) or 0
end

local function removeTag(character)
	local tag = tags[character]
	if tag then
		tag.Gui:Destroy()
		tags[character] = nil
	end
end

local function buildTag(character)
	removeTag(character)
	local player = Players:GetPlayerFromCharacter(character)
	local head = character:FindFirstChild("Head")
	if not player or not head then
		return
	end
	local aura = AuraData.Get(character:GetAttribute("Aura") or "")
	local vip = isVIP(character)
	local rebirths = rebirthsOf(character)
	if not aura and not vip and rebirths <= 0 then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "AuraTag_" .. player.Name
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(240, 70)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.MaxDistance = 75
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = gui

	local function line(order, text, size, color, font)
		local l = Instance.new("TextLabel")
		l.LayoutOrder = order
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, size + 4)
		l.Font = font or Enum.Font.FredokaOne
		l.TextSize = size
		l.Text = text
		l.TextColor3 = color
		l.Parent = gui
		local outline = Instance.new("UIStroke")
		outline.Thickness = 1.6
		outline.Transparency = 0.25
		outline.Parent = l
		return l
	end

	local gradient
	if vip or rebirths > 0 then
		local parts = {}
		if rebirths > 0 then
			table.insert(parts, ("<font color='#%s'>%s Rebirth %d</font>"):format(Rebirth.Color(rebirths):ToHex(), Rebirth.Stars(rebirths), rebirths))
		end
		if vip then
			table.insert(parts, "👑 VIP")
		end
		local top = line(1, table.concat(parts, "  "), 16, GOLD)
		top.RichText = true
	end
	if aura then
		local nameLine = line(2, aura.Name, 24, Color3.new(1, 1, 1))
		gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(readable(aura.Colors[1]), readable(aura.Colors[2]))
		gradient.Parent = nameLine
		local tier = AuraData.Tiers[aura.Tier]
		line(3, ("%s • %s"):format(aura.Tier, AuraData.FormatChance(aura.Chance)), 13, tier.Color, Enum.Font.GothamBold)
	end

	tags[character] = {
		Gui = gui,
		Gradient = gradient,
		Order = aura and AuraData.Tiers[aura.Tier].Order or 0,
		Phase = math.random() * 6,
		AuraName = aura and aura.Name or nil,
		VIP = vip,
		Rebirths = rebirths,
	}
end

---------------------------------------------------------------------
-- AURAS
---------------------------------------------------------------------
local function reconcile(character, withBurst)
	local desired = character:GetAttribute("Aura")
	local root = character:FindFirstChild("HumanoidRootPart")
	local handle = handles[character]

	if handle then
		local stillValid = handle:IsAlive() and handle.Aura.Name == desired and handle.Root == root
		if not stillValid then
			handle:Destroy()
			handles[character] = nil
		end
	end

	if not handles[character] and desired and root and character.Parent then
		handles[character] = AuraEffects.Apply(character, desired)
		if withBurst and handles[character] then
			local aura = AuraData.Get(desired)
			AuraEffects.Burst(root.Position, aura.Colors, 0.6 + AuraData.Tiers[aura.Tier].Order * 0.2)
		end
	end

	-- name tag follows the aura + VIP (rebuild only when something changed)
	local tag = tags[character]
	local head = character:FindFirstChild("Head")
	local vip = isVIP(character)
	local rebirths = rebirthsOf(character)
	if not head or (not desired and not vip and rebirths <= 0) then
		removeTag(character)
	elseif not tag or tag.AuraName ~= desired or tag.VIP ~= vip or tag.Rebirths ~= rebirths or tag.Gui.Adornee ~= head then
		buildTag(character)
	end
end

local function untrack(character)
	tracked[character] = nil
	if handles[character] then
		handles[character]:Destroy()
		handles[character] = nil
	end
	removeTag(character)
end

local function track(character)
	if tracked[character] then
		return
	end
	tracked[character] = true

	character:GetAttributeChangedSignal("Aura"):Connect(function()
		reconcile(character, true)
	end)
	character.ChildAdded:Connect(function(child)
		if child.Name == "HumanoidRootPart" or child.Name == "Head" then
			reconcile(character, false)
		end
	end)
	character.Destroying:Connect(function()
		untrack(character)
	end)

	reconcile(character, false)
end

local function onPlayer(player)
	if player.Character then
		track(player.Character)
	end
	player.CharacterAdded:Connect(track)
	player:GetAttributeChangedSignal("Pass_VIP"):Connect(function()
		if player.Character then
			reconcile(player.Character, false)
		end
	end)
	player:GetAttributeChangedSignal("Rebirths"):Connect(function()
		if player.Character then
			reconcile(player.Character, false)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end

-- duel bots wear auras too
task.spawn(function()
	local botFolder = workspace:WaitForChild("DuelBots", 60)
	if not botFolder then
		return
	end
	botFolder.ChildAdded:Connect(function(model)
		if model:IsA("Model") then
			task.wait(0.2) -- let its parts arrive
			track(model)
		end
	end)
	for _, model in ipairs(botFolder:GetChildren()) do
		if model:IsA("Model") then
			track(model)
		end
	end
end)

-- Animate every frame
local clock = 0
RunService.RenderStepped:Connect(function(dt)
	clock += dt
	for character, handle in pairs(handles) do
		if handle:IsAlive() then
			handle:Update(dt)
		else
			handle:Destroy()
			handles[character] = nil
		end
	end
	for _, tag in pairs(tags) do
		tag.Gui.StudsOffset = Vector3.new(0, 3.4 + math.sin(clock * 2 + tag.Phase) * 0.12, 0)
		if tag.Gradient and tag.Order >= 5 then
			tag.Gradient.Offset = Vector2.new(math.sin(clock * 1.5 + tag.Phase) * 0.5, 0)
		end
	end
end)

-- Safety check twice a second (respawns, streaming, removed characters)
task.spawn(function()
	while true do
		task.wait(0.5)
		for character in pairs(tracked) do
			if character.Parent == nil then
				untrack(character)
			else
				reconcile(character, false)
			end
		end
	end
end)

---------------------------------------------------------------------
-- ROLL EFFECTS EVERYONE CAN SEE
---------------------------------------------------------------------
local function chargeUp(root)
	local feet = root.Position - Vector3.new(0, 2.9, 0)
	-- a ring of light rising from the feet to above the head
	local ring = fxPart({
		Name = "ChargeRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, 7, 7),
		CFrame = CFrame.new(feet) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(200, 170, 255),
		Transparency = 0.2,
	})
	tween(ring, 1, {
		CFrame = CFrame.new(feet + Vector3.new(0, 6.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Size = Vector3.new(0.1, 2, 2),
		Transparency = 1,
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(ring, 1.1)

	-- sparkles getting sucked in
	local sphere = fxPart({
		Name = "ChargeSphere",
		Size = Vector3.one * 9,
		CFrame = CFrame.new(root.Position),
		Transparency = 1,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Config.Textures.Sparkle
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Rate = 60
	emitter.Lifetime = NumberRange.new(0.4, 0.6)
	emitter.Speed = NumberRange.new(7, 10)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Color = ColorSequence.new(Color3.fromRGB(220, 200, 255), Color3.fromRGB(120, 200, 255))
	emitter.Parent = sphere
	task.delay(0.9, function()
		emitter.Enabled = false
	end)
	Debris:AddItem(sphere, 1.6)
end

local function floatingName(root, aura)
	local holder = fxPart({ Name = "RollName", Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(root.Position) })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 50)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Parent = holder
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = aura.Name .. "!"
	text.TextColor3 = readable(aura.Colors[1])
	text.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Thickness = 2
	outline.Parent = text
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = text
	tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(gui, 2, { StudsOffset = Vector3.new(0, 8, 0) })
	task.delay(1.2, function()
		tween(text, 0.8, { TextTransparency = 1 })
		tween(outline, 0.8, { Transparency = 1 })
	end)
	Debris:AddItem(holder, 2.2)
end

local REVEAL_SOUNDS = { "Pop", "Pop", "RevealRare", "RevealEpic", "RevealLegendary", "RevealMythic", "RevealMythic" }

local function revealFX(player, root, aura)
	local order = AuraData.Tiers[aura.Tier].Order
	local c1, c2 = aura.Colors[1], aura.Colors[2]
	local position = root.Position

	AuraEffects.Burst(position, aura.Colors, 0.5 + order * 0.2)
	floatingName(root, aura)

	-- other players hear your roll from where you are standing
	if player ~= localPlayer then
		local holder = fxPart({ Name = "RollSound", Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(position) })
		SoundFX.Play(REVEAL_SOUNDS[order], { Parent = holder, MaxDistance = 120 + order * 30, Volume = 0.8 })
		Debris:AddItem(holder, 6)
	end

	-- Epic+: a pillar of light
	if order >= 4 then
		local height = 40 + order * 10
		local pillar = fxPart({
			Name = "Pillar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, 4, 4),
			CFrame = CFrame.new(position + Vector3.new(0, height / 2 - 3, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = c1,
			Transparency = 0.2,
		})
		tween(pillar, 1.4, { Size = Vector3.new(height, 0.2, 0.2), Transparency = 1 }, Enum.EasingStyle.Quint)
		Debris:AddItem(pillar, 1.5)
	end

	-- Legendary+: a beam all the way into the sky + big shockwave
	if order >= 5 then
		local beam = fxPart({
			Name = "SkyBeam",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(800, 1.5, 1.5),
			CFrame = CFrame.new(position + Vector3.new(0, 400, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = c2,
			Transparency = 0,
		})
		tween(beam, 0.25, { Size = Vector3.new(800, 7, 7) }, Enum.EasingStyle.Quad)
		task.delay(0.6, function()
			tween(beam, 1.6, { Size = Vector3.new(800, 0.2, 0.2), Transparency = 1 })
		end)
		Debris:AddItem(beam, 2.4)

		local wave = fxPart({
			Name = "Shockwave",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 4, 4),
			CFrame = CFrame.new(position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = c1,
			Transparency = 0.1,
		})
		local size = (order >= 6) and 120 or 60
		tween(wave, 1.2, { Size = Vector3.new(0.1, size, size), Transparency = 1 }, Enum.EasingStyle.Quint)
		Debris:AddItem(wave, 1.3)
	end

	-- Mythic+: a second, delayed burst
	if order >= 6 then
		task.delay(0.35, function()
			AuraEffects.Burst(position + Vector3.new(0, 3, 0), { c2, c1 }, 2.5)
		end)
	end
end

RollFXRemote.OnClientEvent:Connect(function(info)
	local player = Players:GetPlayerByUserId(info.UserId)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if info.Phase == "Start" then
		chargeUp(root)
	elseif info.Phase == "Reveal" then
		local aura = AuraData.Get(info.Aura)
		if aura then
			revealFX(player, root, aura)
		end
	end
end)

---------------------------------------------------------------------
-- CHAT TAGS: [VIP] and your equipped aura in its tier color
---------------------------------------------------------------------
TextChatService.OnIncomingMessage = function(message)
	local source = message.TextSource
	if not source then
		return nil
	end
	local player = Players:GetPlayerByUserId(source.UserId)
	if not player then
		return nil
	end
	local prefix = ""
	local rebirths = player:GetAttribute("Rebirths") or 0
	if rebirths > 0 then
		prefix ..= ("<font color='#%s'>[%s]</font> "):format(Rebirth.Color(rebirths):ToHex(), Rebirth.Stars(rebirths))
	end
	if player:GetAttribute("Pass_VIP") then
		prefix ..= "<font color='#FFC846'>[VIP]</font> "
	end
	local aura = AuraData.Get(player:GetAttribute("EquippedAura") or "")
	if aura then
		prefix ..= ("<font color='#%s'>[%s]</font> "):format(AuraData.Tiers[aura.Tier].Color:ToHex(), aura.Name)
	end
	if prefix == "" then
		return nil
	end
	local properties = Instance.new("TextChatMessageProperties")
	properties.PrefixText = prefix .. message.PrefixText
	return properties
end
