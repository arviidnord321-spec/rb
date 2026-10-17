-- IslandFX (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Brings the Rebirth Gate and the rebirth islands to life on your screen:
--   * spinning / bobbing / blinking things (marked with FX_ attributes)
--   * the aurora over Frostfall, geysers and eruptions on Ember Isle
--   * gate portals show 🔒 or ✅ for YOUR rebirths
--   * each island says welcome when you arrive

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")

local folder = workspace:WaitForChild("RebirthIslands", 60)
if not folder then
	warn("[IslandFX] RebirthIslands not found")
	return
end

---------------------------------------------------------------------
-- Collect everything that moves
---------------------------------------------------------------------
local movers = {} -- spin / bob / pulse
local auroras = {} -- aurora panels
local geysers = {}
local eruptions = {}
local blinkers = {}
local rand = Random.new()

local function pivotOf(instance)
	if instance:IsA("Model") then
		return instance:GetPivot()
	end
	return instance.CFrame
end

local function collect(instance)
	local spin = instance:GetAttribute("FX_Spin")
	local bob = instance:GetAttribute("FX_Bob")
	local pulse = instance:GetAttribute("FX_Pulse")
	if spin or bob or pulse then
		table.insert(movers, {
			Instance = instance,
			Base = pivotOf(instance),
			Spin = spin,
			Bob = bob,
			Pulse = pulse,
			BaseSize = instance:IsA("BasePart") and instance.Size or nil,
			Phase = rand:NextNumber(0, 6),
		})
	end
	if instance:GetAttribute("FX_Aurora") then
		for _, panel in ipairs(instance:GetChildren()) do
			if panel:IsA("BasePart") then
				table.insert(auroras, { Part = panel, Phase = panel:GetAttribute("Phase") or 0, Base = panel.Color })
			end
		end
	end
	if instance:GetAttribute("FX_Geyser") then
		table.insert(geysers, { Part = instance, Phase = instance:GetAttribute("Phase") or 0, Last = 0 })
	end
	if instance:GetAttribute("FX_Eruption") then
		table.insert(eruptions, { Part = instance, Next = os.clock() + rand:NextNumber(5, 10) })
	end
	if instance:GetAttribute("FX_Blink") then
		table.insert(blinkers, { Part = instance, Phase = instance:GetAttribute("Phase") or 0 })
	end
end

for _, instance in ipairs(folder:GetDescendants()) do
	collect(instance)
end

-- only animate what's close to you (the islands are far apart)
local NEAR = 420
local function near(position)
	return (camera.CFrame.Position - position).Magnitude < NEAR
end

local t = 0
RunService.RenderStepped:Connect(function(dt)
	t += dt
	for _, m in ipairs(movers) do
		if near(m.Base.Position) then
			local cf = m.Base
			if m.Bob then
				cf = cf + Vector3.new(0, math.sin(t * 1.3 + m.Phase) * m.Bob, 0)
			end
			if m.Spin then
				cf = cf * CFrame.Angles(m.Spin.X * t, m.Spin.Y * t, m.Spin.Z * t)
			end
			if m.Instance:IsA("Model") then
				m.Instance:PivotTo(cf)
			else
				m.Instance.CFrame = cf
				if m.Pulse and m.BaseSize then
					m.Instance.Size = m.BaseSize * (1 + math.sin(t * 2.4 + m.Phase) * m.Pulse * 0.2)
				end
			end
		end
	end
	for _, a in ipairs(auroras) do
		local wave = math.sin(t * 0.7 + a.Phase)
		a.Part.Transparency = 0.62 + wave * 0.22
		a.Part.Color = a.Base:Lerp(Color3.new(1, 1, 1), (math.sin(t * 0.4 + a.Phase * 0.5) + 1) * 0.12)
	end
	for _, b in ipairs(blinkers) do
		b.Part.Transparency = ((t + b.Phase) % 1.6 < 0.8) and 0 or 0.8
	end
end)

-- geysers blast every few seconds, the volcano erupts now and then
task.spawn(function()
	while true do
		task.wait(0.2)
		local now = workspace:GetServerTimeNow()
		for _, g in ipairs(geysers) do
			local cycle = math.floor((now + g.Phase) / 5)
			if cycle ~= g.Last then
				g.Last = cycle
				if near(g.Part.Position) then
					local blast = g.Part:FindFirstChild("Blast")
					if blast then
						blast:Emit(40)
					end
					SoundFX.Play("Swoosh", { Parent = g.Part, Speed = 0.6, Volume = 0.8, MaxDistance = 80 })
				end
			end
		end
		for _, e in ipairs(eruptions) do
			if os.clock() >= e.Next then
				e.Next = os.clock() + rand:NextNumber(9, 16)
				if near(e.Part.Position) then
					for _, child in ipairs(e.Part:GetChildren()) do
						if child:IsA("ParticleEmitter") and child:GetAttribute("Eruption") then
							child:Emit(120)
						end
					end
					SoundFX.Play("Rumble", { Parent = e.Part, Volume = 1, MaxDistance = 220 })
					SoundFX.Play("Explosion", { Parent = e.Part, Speed = 0.6, Volume = 0.7, MaxDistance = 220 })
					-- a little camera shake if you're close
					local character = player.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					if humanoid and (camera.CFrame.Position - e.Part.Position).Magnitude < 120 then
						task.spawn(function()
							for _ = 1, 12 do
								humanoid.CameraOffset = Vector3.new(rand:NextNumber(-0.3, 0.3), rand:NextNumber(-0.3, 0.3), 0)
								task.wait(0.03)
							end
							humanoid.CameraOffset = Vector3.zero
						end)
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- Gate portals: locked or unlocked for YOU
---------------------------------------------------------------------
local gate = folder:WaitForChild("RebirthGate", 30)
local function refreshLocks()
	if not gate then
		return
	end
	local n = player:GetAttribute("Rebirths") or 0
	for _, item in ipairs(gate:GetDescendants()) do
		local need = item:GetAttribute("NeedRebirths")
		if need then
			local unlocked = n >= need
			if item:IsA("BasePart") then
				item.Transparency = unlocked and 1 or 0.2
			elseif item:IsA("BillboardGui") then
				local text = item:FindFirstChild("Text")
				if text then
					local base = text:GetAttribute("BaseText") or text.Text
					text:SetAttribute("BaseText", base)
					text.Text = base .. (unlocked and "\n<font color='#78ffaa'>✅ UNLOCKED</font>" or "\n<font color='#ff8c8c'>🔒 LOCKED</font>")
					item.Size = UDim2.fromOffset(300, 96)
				end
			end
		end
	end
end
refreshLocks()
player:GetAttributeChangedSignal("Rebirths"):Connect(refreshLocks)

---------------------------------------------------------------------
-- Island welcome (each island's sky colors are done by SkyFX)
---------------------------------------------------------------------
local current = nil
player:GetAttributeChangedSignal("OnRebirthIsland"):Connect(function()
	local key = player:GetAttribute("OnRebirthIsland")
	if key == current then
		return
	end
	current = key
	if key then
		for _, info in ipairs(Config.RebirthIslands) do
			if info.Key == key then
				UIKit.toast(("%s Welcome to %s! x%s luck here"):format(info.Icon, info.Name, tostring(info.LuckMultiplier)), info.Color)
				SoundFX.Chime(0.9, 5)
			end
		end
	end
end)

---------------------------------------------------------------------
-- Locked portal message
---------------------------------------------------------------------
local PortalFXRemote = remotes:WaitForChild("PortalFX", 30)
if PortalFXRemote then
	PortalFXRemote.OnClientEvent:Connect(function(kind, data)
		if kind == "DeniedRebirth" and type(data) == "table" then
			UIKit.toast(("🔒 %s unlocks at Rebirth %d - open ⭐ REBIRTH to see your progress"):format(
				tostring(data.Name), tonumber(data.Need) or 1), Color3.fromRGB(255, 140, 140))
			SoundFX.Play("Thud")
		end
	end)
end
