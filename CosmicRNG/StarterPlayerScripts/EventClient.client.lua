-- EventClient (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Cosmic Events on your screen:
--   * a small timer (top-left, under the Cosmic Drop timer): the event
--     that's on right now, or when the next one starts
--   * the sky changes color for the event
--   * Meteor Shower: meteors streak down around you
--   * Star Surge: golden shooting stars everywhere
--   * Rainbow Rift: the sky cycles through the rainbow

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local THEME = UIKit.Theme
local new, corner, stroke, label = UIKit.new, UIKit.corner, UIKit.stroke, UIKit.label
local rand = Random.new()

local EVENT_BY_KEY = {}
for _, event in ipairs(Config.Events.List) do
	EVENT_BY_KEY[event.Key] = event
end

-- sky colors for each event (A = haze, B = deep color)
local SKY = {
	MeteorShower = { Color3.fromRGB(255, 140, 70), Color3.fromRGB(120, 40, 30) },
	StarSurge = { Color3.fromRGB(255, 225, 140), Color3.fromRGB(90, 80, 170) },
	AuroraNight = { Color3.fromRGB(110, 255, 190), Color3.fromRGB(90, 40, 170) },
	Eclipse = { Color3.fromRGB(60, 25, 40), Color3.fromRGB(255, 110, 40) },
}

local function now()
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------------
-- The timer pill
---------------------------------------------------------------------
local gui = UIKit.screen("CosmicEvents", 4)
local pill = new("Frame", {
	Position = UDim2.new(0, 16, 0, 194),
	Size = UDim2.fromOffset(260, 34),
	BackgroundColor3 = THEME.Panel,
	BackgroundTransparency = 0.3,
	Parent = gui,
}, { corner(UDim.new(1, 0)) })
local pillStroke = stroke(Color3.fromRGB(170, 140, 255), 1.5, 0.4)
pillStroke.Parent = pill
UIKit.addAutoScale(pill)
local text = label({
	Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -20, 1, 0), Text = "", TextSize = 14, RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = pill,
})

RunService.RenderStepped:Connect(function()
	pill.Visible = not player:GetAttribute("InDuel")
	local ends = ReplicatedStorage:GetAttribute("EventEnds") or 0
	local t = now()
	if ends > t then
		local left = math.floor(ends - t)
		local event = EVENT_BY_KEY[ReplicatedStorage:GetAttribute("EventKey") or ""]
		local color = event and event.Color or THEME.Gold
		pillStroke.Color = color
		pillStroke.Transparency = 0.1
		text.Text = ("<font color='#%s'><b>%s</b></font> x%s luck • %d:%02d"):format(
			color:ToHex(), tostring(ReplicatedStorage:GetAttribute("EventName")), tostring(ReplicatedStorage:GetAttribute("EventLuck") or 1), left // 60, left % 60)
	else
		local left = math.max(0, math.floor((ReplicatedStorage:GetAttribute("EventNextAt") or t) - t))
		pillStroke.Color = Color3.fromRGB(170, 140, 255)
		pillStroke.Transparency = 0.4
		text.Text = ("✨ Next cosmic event in <b>%d:%02d</b>"):format(left // 60, left % 60)
	end
end)

---------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------
local fxFolder = Instance.new("Folder")
fxFolder.Name = "EventFX"
fxFolder.Parent = workspace

local function streak(color3, size, speed, impact)
	local eye = camera.CFrame.Position
	local target = eye + Vector3.new(rand:NextNumber(-140, 140), -rand:NextNumber(10, 60), rand:NextNumber(-140, 140))
	local direction = Vector3.new(rand:NextNumber(-0.6, 0.6), -1, rand:NextNumber(-0.6, 0.6)).Unit
	local start = target - direction * rand:NextNumber(140, 220)
	local rock = Instance.new("Part")
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	rock.CanTouch = false
	rock.CastShadow = false
	rock.Shape = Enum.PartType.Ball
	rock.Material = Enum.Material.Neon
	rock.Color = color3
	rock.Size = Vector3.one * size
	rock.CFrame = CFrame.new(start)
	rock.Parent = fxFolder
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, size * 0.4, 0)
	a0.Parent = rock
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -size * 0.4, 0)
	a1.Parent = rock
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.5
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color3)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	trail.Parent = rock
	local duration = (start - target).Magnitude / speed
	TweenService:Create(rock, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = CFrame.new(target) }):Play()
	Debris:AddItem(rock, duration + 0.6)
	if impact then
		task.delay(duration, function()
			if not rock.Parent then
				return
			end
			rock.Transparency = 1
			local burst = Instance.new("ParticleEmitter")
			burst.Texture = Config.Textures.Spark
			burst.Rate = 0
			burst.Lifetime = NumberRange.new(0.4, 0.8)
			burst.Speed = NumberRange.new(10, 22)
			burst.SpreadAngle = Vector2.new(180, 180)
			burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
			burst.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), color3)
			burst.LightEmission = 1
			burst.Parent = rock
			burst:Emit(20)
		end)
	end
end

local function applySky(key, remaining)
	local colors = SKY[key]
	if colors then
		Lighting:SetAttribute("SkyShiftA", colors[1])
		Lighting:SetAttribute("SkyShiftB", colors[2])
		Lighting:SetAttribute("SkyShiftUntil", os.clock() + remaining)
	end
end

-- keep the effects running while an event is on
task.spawn(function()
	local lastRainbow = 0
	while true do
		task.wait(0.3)
		local ends = ReplicatedStorage:GetAttribute("EventEnds") or 0
		local key = ReplicatedStorage:GetAttribute("EventKey") or ""
		local remaining = ends - now()
		if remaining > 0 then
			if key == "MeteorShower" then
				streak(Color3.fromRGB(255, 120, 40), rand:NextNumber(1.6, 3.2), 140, true)
			elseif key == "StarSurge" then
				for _ = 1, 2 do
					streak(Color3.fromRGB(255, 230, 140), rand:NextNumber(0.5, 1), 260, false)
				end
			elseif key == "RainbowRift" and os.clock() - lastRainbow > 1.5 then
				lastRainbow = os.clock()
				local hue = (os.clock() * 0.08) % 1
				Lighting:SetAttribute("SkyShiftA", Color3.fromHSV(hue, 0.55, 1))
				Lighting:SetAttribute("SkyShiftB", Color3.fromHSV((hue + 0.4) % 1, 0.7, 0.6))
				Lighting:SetAttribute("SkyShiftUntil", os.clock() + 2)
				if rand:NextNumber() < 0.5 then
					streak(Color3.fromHSV(rand:NextNumber(), 0.6, 1), 1, 220, false)
				end
			end
		end
	end
end)

-- start / end messages
local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local AnnounceRemote = remotes:WaitForChild("Announce")
AnnounceRemote.OnClientEvent:Connect(function(info)
	if type(info) ~= "table" then
		return
	end
	if info.Type == "EventStart" then
		local event = EVENT_BY_KEY[info.Key]
		applySky(info.Key, Config.Events.DurationMinutes * 60)
		SoundFX.Play("RevealLegendary", { Volume = 0.6 })
		SoundFX.Chime(0.9, 5)
		UIKit.burst({ event and event.Color or THEME.Gold, Color3.new(1, 1, 1) }, 40, 1.3, Vector2.new(0.5, 0.25))
	elseif info.Type == "EventEnd" then
		Lighting:SetAttribute("SkyShiftUntil", 0)
		UIKit.toast("✨ The cosmic event is over", THEME.SubText)
	end
end)

-- joined while an event is already on? paint the sky right away
task.delay(3, function()
	local remaining = (ReplicatedStorage:GetAttribute("EventEnds") or 0) - now()
	if remaining > 0 then
		applySky(ReplicatedStorage:GetAttribute("EventKey") or "", remaining)
	end
end)
