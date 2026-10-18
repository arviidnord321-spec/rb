-- ParkourClient (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Runs the parkour bits that must be smooth on your own screen:
--   * vanishing platforms blink and disappear on a shared timer
--   * spinning laser bars turn and moving platforms slide (and carry you)
--   * jump pads launch you into the air
--   * a run timer + checkpoint counter while you're on a course
--   * messages for start / checkpoint / finish (from the Parkour script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Luck = require(ReplicatedStorage:WaitForChild("Luck"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local THEME = UIKit.Theme
local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local ParkourEvent = remotes:WaitForChild("ParkourEvent", 30)

local courses = workspace:WaitForChild("ParkourCourses", 60)
if not courses then
	warn("[ParkourClient] ParkourCourses not found")
	return
end

---------------------------------------------------------------------
-- Collect vanishing platforms, jump pads and trophies
---------------------------------------------------------------------
local vanishers, pads, trophies, spinners, movers, ices = {}, {}, {}, {}, {}, {}
for _, item in ipairs(courses:GetDescendants()) do
	if item:IsA("BasePart") then
		if item:GetAttribute("Spinner") then
			table.insert(spinners, {
				Part = item,
				Center = item:GetAttribute("SpinCenter"),
				Speed = item:GetAttribute("SpinSpeed") or 2,
				Offset = item:GetAttribute("SpinOffset") or 0,
			})
		elseif item:GetAttribute("MoveAmplitude") then
			table.insert(movers, {
				Part = item,
				Base = item.CFrame,
				Amplitude = item:GetAttribute("MoveAmplitude"),
				Period = item:GetAttribute("MovePeriod") or 3,
				Offset = item:GetAttribute("MoveOffset") or 0,
			})
		elseif item:GetAttribute("Vanish") then
			table.insert(vanishers, {
				Part = item,
				Period = item:GetAttribute("VanishPeriod") or 3,
				On = item:GetAttribute("VanishOn") or 2,
				Offset = item:GetAttribute("VanishOffset") or 0,
			})
		elseif item:GetAttribute("Slippery") then
			table.insert(ices, item)
		elseif item:GetAttribute("Launch") then
			table.insert(pads, { Part = item, Launch = item:GetAttribute("Launch") })
		elseif item.Name == "SpinGem" then
			table.insert(trophies, { Part = item, Position = item.Position })
		end
	end
end

local function standingOn(part, position)
	local localPos = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(localPos.X) <= half.X + 0.4 and math.abs(localPos.Z) <= half.Z + 0.4
		and localPos.Y > half.Y and localPos.Y < half.Y + 3.6
end

local lastLaunch = 0
local t = 0
local slideVelocity -- your sliding speed while on ice
RunService.RenderStepped:Connect(function(dt)
	t += dt
	local now = workspace:GetServerTimeNow()
	local myCharacter = player.Character
	local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")

	-- spinning laser bars (same clock as the server, so hits are fair)
	for _, spinner in ipairs(spinners) do
		if spinner.Center then
			spinner.Part.CFrame = CFrame.new(spinner.Center) * CFrame.Angles(0, now * spinner.Speed + spinner.Offset, 0)
		end
	end

	-- moving platforms; if you're standing on one it carries you along
	for _, mover in ipairs(movers) do
		local offset = mover.Amplitude * math.sin((now + mover.Offset) / mover.Period * math.pi * 2)
		local newCFrame = mover.Base + offset
		if myRoot and standingOn(mover.Part, myRoot.Position) then
			local delta = newCFrame.Position - mover.Part.Position
			myRoot.CFrame += delta
		end
		mover.Part.CFrame = newCFrame
	end

	-- ice: you keep sliding, so speeding up and stopping is slow
	local onIce = false
	if myRoot then
		for _, ice in ipairs(ices) do
			if standingOn(ice, myRoot.Position) then
				onIce = true
				break
			end
		end
	end
	if onIce then
		local velocity = myRoot.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		slideVelocity = slideVelocity and slideVelocity:Lerp(flat, math.min(1, dt * 1.6)) or flat
		myRoot.AssemblyLinearVelocity = Vector3.new(slideVelocity.X, velocity.Y, slideVelocity.Z)
	else
		slideVelocity = nil
	end

	-- vanishing platforms: solid, then blink, then gone
	for _, v in ipairs(vanishers) do
		local phase = (now + v.Offset) % v.Period
		local visible = phase < v.On
		local warning = visible and phase > v.On - 0.6
		v.Part.CanCollide = visible
		if not visible then
			v.Part.Transparency = 0.9
		elseif warning then
			v.Part.Transparency = (math.floor(phase * 12) % 2 == 0) and 0.15 or 0.6
		else
			v.Part.Transparency = 0.15
		end
	end

	-- jump pads
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and os.clock() - lastLaunch > 0.6 then
		for _, pad in ipairs(pads) do
			if standingOn(pad.Part, root.Position) then
				lastLaunch = os.clock()
				root.AssemblyLinearVelocity = pad.Launch
				SoundFX.Play("Whoosh", { Speed = 1.3, Volume = 1.2 })
				break
			end
		end
	end

	-- spinning finish trophies
	for _, trophy in ipairs(trophies) do
		trophy.Part.CFrame = CFrame.new(trophy.Position + Vector3.new(0, math.sin(t * 2) * 0.4, 0))
			* CFrame.Angles(0, t * 1.5, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	end
end)

---------------------------------------------------------------------
-- Run timer (top of the screen while you're on a course)
---------------------------------------------------------------------
local gui = UIKit.screen("CosmicParkour", 5)
local timerPanel = UIKit.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(420, 46),
	BackgroundColor3 = THEME.Panel,
	BackgroundTransparency = 0.15,
	Visible = false,
	Parent = gui,
}, { UIKit.corner(UDim.new(0, 14)), UIKit.stroke(Color3.fromRGB(90, 240, 200), 2, 0) })
UIKit.addAutoScale(timerPanel)
local timerLabel = UIKit.label({
	Size = UDim2.fromScale(1, 1),
	Text = "",
	Font = UIKit.TitleFont,
	TextSize = 22,
	RichText = true,
	Parent = timerPanel,
})

local checkpointText = ""
RunService.RenderStepped:Connect(function()
	local course = player:GetAttribute("ParkourCourse")
	local started = player:GetAttribute("ParkourStart")
	if course and started then
		timerPanel.Visible = true
		local seconds = workspace:GetServerTimeNow() - started
		timerLabel.Text = ("🏃 %s   <font color='#9fe8ff'>⏱ %d:%04.1f</font>%s"):format(
			course, seconds // 60, seconds % 60, checkpointText)
	else
		timerPanel.Visible = false
	end
end)

---------------------------------------------------------------------
-- Messages from the server
---------------------------------------------------------------------
if ParkourEvent then
	ParkourEvent.OnClientEvent:Connect(function(info)
		if info.Type == "Start" then
			checkpointText = ""
			UIKit.toast("🏁 " .. info.Course .. " - GO! No checkpoints: fall and you start over", Color3.fromRGB(120, 255, 170))
			SoundFX.Play("Pop", { Speed = 1.3 })
		elseif info.Type == "Checkpoint" then
			checkpointText = ("   <font color='#78ffaa'>✔ %d/%d</font>"):format(info.Number, info.Total)
			UIKit.toast(("✔ Checkpoint %d/%d saved!"):format(info.Number, info.Total), Color3.fromRGB(120, 255, 170))
			SoundFX.Chime(1.2, 3)
		elseif info.Type == "Ouch" then
			UIKit.toast("💥 Ouch! Back to the start", THEME.Bad)
			SoundFX.Play("Thud")
		elseif info.Type == "Left" then
			checkpointText = ""
			UIKit.toast("Run cancelled", THEME.SubText)
		elseif info.Type == "Finish" then
			checkpointText = ""
			local timeText = ("%d:%04.1f"):format(info.Time // 60, info.Time % 60)
			if info.Rewarded then
				UIKit.toast(("🏆 %s done in %s! x%s luck for %d min"):format(
					info.Course, timeText, Luck.Format(info.Multiplier), info.Minutes), THEME.Gold)
				UIKit.confetti({ THEME.Gold, Color3.fromRGB(120, 255, 170), THEME.Accent2 }, 90)
				SoundFX.Chime(1, 5)
				SoundFX.Play("RevealLegendary", { Volume = 0.6 })
			else
				UIKit.toast(("🏆 Done in %s! Reward ready again in %s"):format(
					timeText, Luck.FormatTime(info.CooldownLeft)), THEME.Gold)
				SoundFX.Chime(1.2, 3)
			end
		end
	end)
end
