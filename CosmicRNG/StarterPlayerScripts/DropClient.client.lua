-- DropClient (LocalScript in StarterPlayer > StarterPlayerScripts)
-- The Cosmic Drop on your screen:
--   * a small timer (top-left, under your stats) counting down to the next drop
--   * when a drop is out: "find it!" with an arrow pointing the way + distance
--   * the drop spins and pulses, and a burst when someone grabs it

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local THEME = UIKit.Theme
local new, corner, stroke, label = UIKit.new, UIKit.corner, UIKit.stroke, UIKit.label

local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local AnnounceRemote = remotes:WaitForChild("Announce")

local GOLD = Color3.fromRGB(255, 215, 90)

---------------------------------------------------------------------
-- The timer pill
---------------------------------------------------------------------
local gui = UIKit.screen("CosmicDrop", 4)
local pill = new("Frame", {
	Name = "DropTimer",
	Position = UDim2.new(0, 16, 0, 150),
	Size = UDim2.fromOffset(260, 38),
	BackgroundColor3 = THEME.Panel,
	BackgroundTransparency = 0.25,
	Parent = gui,
}, { corner(UDim.new(1, 0)), stroke(GOLD, 1.5, 0.35) })
UIKit.addAutoScale(pill)
local icon = label({
	Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(30, 38), Text = "🎲", TextSize = 22, Parent = pill,
})
local text = label({
	Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -80, 1, 0), Text = "", TextSize = 15, RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = pill,
})
local arrow = label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(28, 28),
	Text = "➤", TextSize = 24, TextColor3 = GOLD, Visible = false, Parent = pill,
})
local pillScale = pill:FindFirstChild("ScreenScale")

local lastWhole = -1
RunService.RenderStepped:Connect(function()
	-- hide during duels so the fight HUD stays clean
	pill.Visible = not player:GetAttribute("InDuel")
	local active = ReplicatedStorage:GetAttribute("DropActive") == true
	local nextAt = ReplicatedStorage:GetAttribute("DropNextAt")
	if active then
		local position = ReplicatedStorage:GetAttribute("DropPosition")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local where = ReplicatedStorage:GetAttribute("DropWhere") or "the island"
		if typeof(position) == "Vector3" and root then
			local distance = (position - root.Position).Magnitude
			text.Text = ("<font color='#ffd76a'><b>COSMIC ROLL</b></font> on %s • %dm"):format(where, math.floor(distance))
			-- the arrow points where the drop is, relative to where you're looking
			local look = camera.CFrame.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			local toDrop = Vector3.new(position.X - root.Position.X, 0, position.Z - root.Position.Z)
			if flatLook.Magnitude > 0.01 and toDrop.Magnitude > 0.01 then
				flatLook, toDrop = flatLook.Unit, toDrop.Unit
				local angle = math.atan2(flatLook:Cross(toDrop).Y, flatLook:Dot(toDrop))
				arrow.Rotation = -math.deg(angle) - 90
			end
			arrow.Visible = true
		else
			text.Text = "<font color='#ffd76a'><b>COSMIC ROLL</b></font> is out!"
			arrow.Visible = false
		end
		icon.Rotation = (os.clock() * 120) % 360
	else
		arrow.Visible = false
		icon.Rotation = 0
		local left = math.max(0, (nextAt or 0) - workspace:GetServerTimeNow())
		local whole = math.floor(left)
		text.Text = ("Cosmic Drop in <b>%d:%02d</b> <font color='#bfb4e1'>(x%d luck)</font>"):format(
			whole // 60, whole % 60, Config.Drop.BoostMultiplier)
		-- the last 10 seconds tick and pulse
		if whole ~= lastWhole and whole <= 10 and whole > 0 and nextAt then
			SoundFX.Play("Tick", { Speed = 1.4, Volume = 0.8 })
			if pillScale then
				local base = pillScale.Scale
				pillScale.Scale = base * 1.08
				task.delay(0.12, function()
					pillScale.Scale = base
				end)
			end
		end
		lastWhole = whole
	end
end)

---------------------------------------------------------------------
-- The drop in the world spins and bobs
---------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	local drop = workspace:FindFirstChild("CosmicDrop")
	if not drop then
		return
	end
	local center = drop:GetAttribute("DropCenter")
	local die = drop:FindFirstChild("Die")
	if typeof(center) ~= "Vector3" or not die then
		return
	end
	local t = os.clock()
	local target = CFrame.new(center + Vector3.new(0, math.sin(t * 2) * 0.6, 0)) * CFrame.Angles(t * 1.3, t * 1.9, t * 0.7)
	-- move the die and its dots together
	local delta = target * die.CFrame:Inverse()
	for _, child in ipairs(drop:GetChildren()) do
		if child:IsA("BasePart") and (child.Name == "Die" or child.Name == "Dot") then
			child.CFrame = delta * child.CFrame
		end
	end
	local glow = drop:FindFirstChild("Glow")
	if glow then
		glow.Size = Vector3.one * (5 + math.sin(t * 3) * 0.6)
		glow.CFrame = CFrame.new(center + Vector3.new(0, math.sin(t * 2) * 0.6, 0))
	end
end)

---------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------
local function burstAt(position)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace
	Debris:AddItem(holder, 3)
	local e = Instance.new("ParticleEmitter")
	e.Texture = Config.Textures.Sparkle
	e.Rate = 0
	e.Lifetime = NumberRange.new(1, 2)
	e.Speed = NumberRange.new(15, 30)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 3
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	e.LightEmission = 1
	e.Color = ColorSequence.new(GOLD, Color3.fromRGB(170, 110, 255))
	e.Parent = holder
	e:Emit(80)
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = GOLD
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(position - Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quart), { Size = Vector3.new(0.3, 30, 30), Transparency = 1 }):Play()
	Debris:AddItem(ring, 1)
end

AnnounceRemote.OnClientEvent:Connect(function(info)
	if type(info) ~= "table" then
		return
	end
	if info.Type == "DropSpawned" then
		SoundFX.Chime(1.2, 4)
		local scale = pill:FindFirstChild("ScreenScale")
		if scale then
			local base = scale.Scale
			scale.Scale = base * 1.25
			TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = base }):Play()
		end
	elseif info.Type == "DropGrabbed" then
		if typeof(info.Position) == "Vector3" then
			burstAt(info.Position)
		end
		if info.UserId == player.UserId then
			SoundFX.Jingle("Victory")
			UIKit.confetti({ GOLD, THEME.Accent, THEME.Accent2 }, 90)
			UIKit.burst({ GOLD, Color3.new(1, 1, 1) }, 40, 1.4)
			UIKit.toast(("🎲 You got the COSMIC ROLL! Your next roll has x%d luck!"):format(Config.Drop.BoostMultiplier), GOLD)
		end
	end
end)
