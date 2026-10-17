-- CombatAnim (ModuleScript in ReplicatedStorage) - used by LocalScripts only
-- Fight animations made purely in code (no uploaded animation assets).
-- It bends the R15 joints (Motor6D.C0) on top of Roblox's normal walk/idle
-- animations, so punches, kicks, casting poses, hit reactions, blocking
-- and a fighting stance all blend smoothly. Every client animates every
-- fighter itself, so it looks smooth for players AND spectators.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))

local CombatAnim = {}

local I = CFrame.identity
local rad = math.rad

-- R15 joint name -> the body part it lives in
local JOINTS = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	RightHip = "RightUpperLeg",
	RightKnee = "RightLowerLeg",
	LeftHip = "LeftUpperLeg",
	LeftKnee = "LeftLowerLeg",
}

-- a pose offset: rotation in degrees (x = forward/back, y = twist, z = sideways) + optional move
local function P(rx, ry, rz, px, py, pz)
	return CFrame.new(px or 0, py or 0, pz or 0) * CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0))
end

---------------------------------------------------------------------
-- CLIPS: one-shot moves. Keys = { time, { Joint = P(...) } }
-- Trail = which limb glows while the move plays.
---------------------------------------------------------------------
local CLIPS = {
	-- 1st combo hit: a fast LEAD JAB with the left hand
	JabLeft = {
		Duration = 0.38,
		Trail = "LeftHand",
		Keys = {
			{ 0, {} },
			-- load up: elbow tucks back, shoulder turns a little
			{ 0.07, { LeftShoulder = P(58, 0, 16), LeftElbow = P(128), Waist = P(-6, -12, 0) } },
			-- SNAP: arm shoots straight out, body turns into it, small step forward
			{ 0.14, { LeftShoulder = P(94, 0, -10), LeftElbow = P(2), Waist = P(-10, -34, 0), Root = P(-9, 0, 0, 0, -0.25, -0.35), LeftHip = P(30), LeftKnee = P(-12), RightKnee = P(-22), Neck = P(-12, 26, 0), RightShoulder = P(50, 0, -30), RightElbow = P(108) } },
			{ 0.21, { LeftShoulder = P(92, 0, -8), LeftElbow = P(6), Waist = P(-9, -30, 0), Root = P(-8, 0, 0, 0, -0.25, -0.3), LeftHip = P(26), Neck = P(-10, 22, 0), RightShoulder = P(50, 0, -30), RightElbow = P(108) } },
			-- pull the hand back to the face
			{ 0.38, {} },
		},
	},
	-- 2nd combo hit: a heavier REAR CROSS with the right hand
	CrossRight = {
		Duration = 0.44,
		Trail = "RightHand",
		Keys = {
			{ 0, {} },
			-- coil: right shoulder pulls back, weight on the back foot
			{ 0.09, { RightShoulder = P(48, 0, 12), RightElbow = P(132), Waist = P(-4, -30, 0), Root = P(4, -8, 0, 0, -0.3, 0.1), RightKnee = P(-30) } },
			-- the punch: hips and shoulders whip around, arm fully extended
			{ 0.17, { RightShoulder = P(96, 0, -14), RightElbow = P(0), Waist = P(-12, 40, 0), Root = P(-12, 18, 0, 0, -0.3, -0.4), RightHip = P(-22), RightKnee = P(-28), LeftHip = P(22), LeftKnee = P(-18), Neck = P(-12, -32, 0), LeftShoulder = P(62, 0, 28), LeftElbow = P(96) } },
			{ 0.25, { RightShoulder = P(94, 0, -12), RightElbow = P(4), Waist = P(-10, 36, 0), Root = P(-10, 16, 0, 0, -0.3, -0.35), RightHip = P(-20), LeftHip = P(20), Neck = P(-10, -28, 0), LeftShoulder = P(62, 0, 28), LeftElbow = P(96) } },
			{ 0.44, {} },
		},
	},
	-- (kept for bots/extra variety)
	JabRight = {
		Duration = 0.36,
		Trail = "RightHand",
		Keys = {
			{ 0, {} },
			{ 0.07, { RightShoulder = P(50, 0, 14), RightElbow = P(128), Waist = P(0, -14, 0) } },
			{ 0.14, { RightShoulder = P(95, 0, -10), RightElbow = P(2), Waist = P(-8, 30, 0), Root = P(-9, 0, 0, 0, -0.25, -0.3), Neck = P(-10, -24, 0) } },
			{ 0.36, {} },
		},
	},
	-- 3rd combo hit: chambered ROUNDHOUSE KICK
	Roundhouse = {
		Duration = 0.66,
		Trail = "RightFoot",
		Keys = {
			{ 0, {} },
			-- chamber: knee comes up high, foot tucked
			{ 0.15, { RightHip = P(80, 0, 30), RightKnee = P(-115), Root = P(-4, 15, 0, 0, -0.15, 0), Waist = P(-4, -12, 0), LeftKnee = P(-18), LeftShoulder = P(62, 0, 28), LeftElbow = P(96), RightShoulder = P(50, 0, -30), RightElbow = P(108) } },
			-- snap the leg out while the hips turn through
			{ 0.28, { RightHip = P(92, 0, 40), RightKnee = P(-4), Root = P(-10, 48, 0, 0, -0.1, 0), Waist = P(-6, -22, 0), LeftKnee = P(-22), RightShoulder = P(-35, 0, 40), RightElbow = P(40), LeftShoulder = P(62, 0, 28), LeftElbow = P(96), Neck = P(-6, -34, 0) } },
			{ 0.42, { RightHip = P(88, 0, 38), RightKnee = P(-12), Root = P(-8, 45, 0, 0, -0.1, 0), Waist = P(-5, -20, 0), LeftKnee = P(-22), RightShoulder = P(-30, 0, 38), LeftShoulder = P(62, 0, 28), LeftElbow = P(96), Neck = P(-6, -32, 0) } },
			-- re-chamber and step back down
			{ 0.52, { RightHip = P(60, 0, 20), RightKnee = P(-95), Root = P(-2, 18, 0, 0, -0.2, 0), LeftKnee = P(-18) } },
			{ 0.66, {} },
		},
	},
	CastForward = { -- beams, projectiles, drains, freezes, pulls
		Duration = 0.58,
		Trail = "BothHands",
		Keys = {
			{ 0, {} },
			-- gather energy at the hip
			{ 0.13, { RightShoulder = P(20, 0, 30), LeftShoulder = P(20, 0, -30), RightElbow = P(110), LeftElbow = P(110), Root = P(6, 20, 0, 0, -0.3, 0.1), Waist = P(0, 25, 0), RightKnee = P(-25), LeftKnee = P(-25) } },
			-- PUSH both palms forward
			{ 0.23, { RightShoulder = P(96, 0, -14), LeftShoulder = P(96, 0, 14), RightElbow = P(0), LeftElbow = P(0), Root = P(-10, 0, 0, 0, -0.3, -0.3), Waist = P(-8, 0, 0), LeftHip = P(25), LeftKnee = P(-15), RightHip = P(-15), RightKnee = P(-25), Neck = P(-8) } },
			{ 0.38, { RightShoulder = P(92, 0, -12), LeftShoulder = P(92, 0, 12), Root = P(6, 0, 0, 0, -0.25, 0.15), Neck = P(-6) } },
			{ 0.58, {} },
		},
	},
	CastUp = { -- meteors, heals, shields
		Duration = 0.72,
		Trail = "BothHands",
		Keys = {
			{ 0, {} },
			{ 0.2, { RightShoulder = P(172, 0, -18), LeftShoulder = P(172, 0, 18), RightElbow = P(12), LeftElbow = P(12), Neck = P(24), Root = P(6, 0, 0, 0, 0.1, 0) } },
			{ 0.5, { RightShoulder = P(168, 0, -24), LeftShoulder = P(168, 0, 24), RightElbow = P(18), LeftElbow = P(18), Neck = P(20), Root = P(5, 0, 0, 0, 0.1, 0) } },
			{ 0.72, {} },
		},
	},
	Slam = { -- bursts / explosions: jump up and smash the ground
		Duration = 0.66,
		Trail = "BothHands",
		Keys = {
			{ 0, {} },
			{ 0.18, { RightShoulder = P(165, 0, -10), LeftShoulder = P(165, 0, 10), RightElbow = P(20), LeftElbow = P(20), Root = P(8, 0, 0, 0, 0.25, 0), Neck = P(18) } },
			{ 0.3, { RightShoulder = P(40, 0, -12), LeftShoulder = P(40, 0, 12), RightElbow = P(8), LeftElbow = P(8), Root = P(-28, 0, 0, 0, -0.55, 0), RightKnee = P(-50), LeftKnee = P(-50), RightHip = P(38), LeftHip = P(38), Neck = P(-12) } },
			{ 0.46, { RightShoulder = P(36, 0, -12), LeftShoulder = P(36, 0, 12), RightElbow = P(10), LeftElbow = P(10), Root = P(-22, 0, 0, 0, -0.5, 0), RightKnee = P(-45), LeftKnee = P(-45), RightHip = P(32), LeftHip = P(32) } },
			{ 0.66, {} },
		},
	},
	DashLean = {
		Duration = 0.4,
		Trail = "BothHands",
		Keys = {
			{ 0, {} },
			{ 0.08, { Root = P(-35, 0, 0, 0, -0.2, 0), RightShoulder = P(-55, 0, 20), LeftShoulder = P(-55, 0, -20), RightElbow = P(30), LeftElbow = P(30), Neck = P(14), RightHip = P(25), RightKnee = P(-40), LeftHip = P(-30) } },
			{ 0.28, { Root = P(-30, 0, 0, 0, -0.2, 0), RightShoulder = P(-50, 0, 20), LeftShoulder = P(-50, 0, -20), Neck = P(12) } },
			{ 0.4, {} },
		},
	},
	Dodge = { -- duck and slip to the side, hands still up
		Duration = 0.42,
		Keys = {
			{ 0, {} },
			{ 0.08, { Root = P(-22, 0, 18, 0, -0.45, 0), RightKnee = P(-55), LeftKnee = P(-55), RightHip = P(42), LeftHip = P(42), RightShoulder = P(70, 0, -20), LeftShoulder = P(70, 0, 20), RightElbow = P(130), LeftElbow = P(130), Neck = P(-10) } },
			{ 0.28, { Root = P(-15, 0, 12, 0, -0.35, 0), RightKnee = P(-40), LeftKnee = P(-40), RightHip = P(30), LeftHip = P(30), RightShoulder = P(65, 0, -18), LeftShoulder = P(65, 0, 18), RightElbow = P(125), LeftElbow = P(125) } },
			{ 0.42, {} },
		},
	},
	HitLight = { -- head snaps back, hands loosen
		Duration = 0.3,
		Keys = {
			{ 0, {} },
			{ 0.05, { Neck = P(28, 12, 0), Waist = P(15, 8, 4), Root = P(8, 0, 0, 0, -0.2, 0.25), RightShoulder = P(35, 0, 28), LeftShoulder = P(40, 0, -28), RightElbow = P(70), LeftElbow = P(70) } },
			{ 0.3, {} },
		},
	},
	HitHeavy = { -- knocked off balance, arms flung out
		Duration = 0.58,
		Keys = {
			{ 0, {} },
			{ 0.07, { Root = P(26, 0, 12, 0, -0.3, 0.55), Waist = P(22, 10, 0), Neck = P(32, 0, -12), RightShoulder = P(-30, 0, 65), LeftShoulder = P(-25, 0, -65), RightElbow = P(25), LeftElbow = P(25), RightKnee = P(-28), LeftKnee = P(-28), RightHip = P(-10), LeftHip = P(20) } },
			{ 0.26, { Root = P(16, 0, 6, 0, -0.25, 0.35), Waist = P(14, 5, 0), Neck = P(16), RightShoulder = P(10, 0, 40), LeftShoulder = P(10, 0, -40), RightKnee = P(-20), LeftKnee = P(-20) } },
			{ 0.58, {} },
		},
	},
	BlockHit = { -- the guard gets pushed back a bit
		Duration = 0.22,
		Keys = {
			{ 0, {} },
			{ 0.05, { Root = P(10, 0, 0, 0, -0.35, 0.3), Waist = P(8), Neck = P(-18) } },
			{ 0.22, {} },
		},
	},
	Victory = { -- fist pump!
		Duration = 1.6,
		Trail = "RightHand",
		Keys = {
			{ 0, {} },
			{ 0.22, { RightShoulder = P(172, 0, -12), RightElbow = P(25), LeftShoulder = P(-12, 0, -18), LeftElbow = P(95), Neck = P(20), Root = P(4, 0, 0, 0, 0.2, 0) } },
			{ 0.45, { RightShoulder = P(150, 0, -12), RightElbow = P(70), LeftShoulder = P(-12, 0, -18), LeftElbow = P(95), Neck = P(12), Root = P(0) } },
			{ 0.7, { RightShoulder = P(172, 0, -12), RightElbow = P(25), LeftShoulder = P(-12, 0, -18), LeftElbow = P(95), Neck = P(20), Root = P(4, 0, 0, 0, 0.2, 0) } },
			{ 0.95, { RightShoulder = P(150, 0, -12), RightElbow = P(70), Neck = P(12) } },
			{ 1.6, {} },
		},
	},
}
CombatAnim.Clips = CLIPS

-- Which casting pose each power type uses
CombatAnim.PowerPose = {
	Projectile = "CastForward",
	Beam = "CastForward",
	Drain = "CastForward",
	Freeze = "CastForward",
	Pull = "CastForward",
	Meteor = "CastUp",
	Heal = "CastUp",
	Shield = "CastUp",
	Burst = "Slam",
	Dash = "DashLean",
	Teleport = "DashLean",
}

---------------------------------------------------------------------
-- LOOPS: poses held while something is true (stance, block, stun)
---------------------------------------------------------------------
local LOOPS = {
	Stance = function(t) -- boxing guard: left side forward, fists up by the face
		local bob = math.sin(t * 5)
		return {
			RightShoulder = P(50 + bob * 3, 0, -30),
			RightElbow = P(108),
			LeftShoulder = P(62 - bob * 3, 0, 28),
			LeftElbow = P(96),
			Waist = P(-6, -20, 0),
			Root = P(0, 0, 0, 0, -0.25 + bob * 0.05, 0),
			Neck = P(-8, 16, 0),
			LeftHip = P(16),
			RightHip = P(-12),
			LeftKnee = P(-18),
			RightKnee = P(-22),
		}
	end,
	Block = function(t) -- high guard: both forearms up in front of the face, chin tucked
		local shake = math.sin(t * 14) * 1.5
		return {
			RightShoulder = P(86 + shake, 0, -52),
			RightElbow = P(92),
			LeftShoulder = P(90 - shake, 0, 50),
			LeftElbow = P(92),
			Waist = P(-14),
			Root = P(0, 0, 0, 0, -0.38, 0),
			Neck = P(-18),
			RightHip = P(14),
			LeftHip = P(18),
			RightKnee = P(-26),
			LeftKnee = P(-26),
		}
	end,
	Stun = function(t) -- dizzy: head lolls, arms hang
		return {
			Neck = P(math.sin(t * 9) * 16, math.sin(t * 5) * 20, 0),
			Waist = P(8, math.sin(t * 6) * 10, math.cos(t * 6) * 8),
			RightShoulder = P(10, 0, 20 + math.sin(t * 7) * 10),
			LeftShoulder = P(10, 0, -20 - math.sin(t * 7) * 10),
			RightElbow = P(15),
			LeftElbow = P(15),
			RightKnee = P(-15),
			LeftKnee = P(-15),
		}
	end,
}

---------------------------------------------------------------------
-- Rigs we are animating
---------------------------------------------------------------------
local rigs = {} -- [model] = rig

local function smooth(a)
	return a * a * (3 - 2 * a)
end

local function sampleClip(clip, elapsed)
	local keys = clip.Keys
	local previous, nextKey = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if elapsed >= keys[i][1] and elapsed <= keys[i + 1][1] then
			previous, nextKey = keys[i], keys[i + 1]
			break
		end
	end
	local span = nextKey[1] - previous[1]
	local alpha = (span > 0) and smooth(math.clamp((elapsed - previous[1]) / span, 0, 1)) or 1
	local pose = {}
	for joint in pairs(clip.Joints) do
		local a = previous[2][joint] or I
		local b = nextKey[2][joint] or I
		pose[joint] = a:Lerp(b, alpha)
	end
	return pose
end

-- remember every joint each clip touches
for _, clip in pairs(CLIPS) do
	clip.Joints = {}
	for _, key in ipairs(clip.Keys) do
		for joint in pairs(key[2]) do
			clip.Joints[joint] = true
		end
	end
end

local function makeTrail(part, color0, color1)
	local a0 = Instance.new("Attachment")
	a0.Name = "CombatTrailA"
	a0.Position = Vector3.new(0, 0.35, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Name = "CombatTrailB"
	a1.Position = Vector3.new(0, -0.35, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Name = "CombatTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.18
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
	trail.Color = ColorSequence.new(color0, color1)
	trail.Enabled = false
	trail.Parent = part
	return trail
end

local function getRig(model)
	local rig = rigs[model]
	if rig then
		return rig
	end
	local motors, baseC0 = {}, {}
	for joint, partName in pairs(JOINTS) do
		local holder = model:FindFirstChild(partName)
		local motor = holder and holder:FindFirstChild(joint)
		if motor and motor:IsA("Motor6D") then
			motors[joint] = motor
			baseC0[joint] = motor.C0
		end
	end
	if not motors.RightShoulder or not motors.Root then
		return nil -- not an R15 body; skip
	end
	local aura = AuraData.Get(model:GetAttribute("Aura") or "")
	local c0 = aura and aura.Colors[1] or Color3.fromRGB(220, 220, 255)
	local c1 = aura and aura.Colors[2] or Color3.fromRGB(150, 150, 255)
	local trails = {}
	for _, limb in ipairs({ "RightHand", "LeftHand", "RightFoot" }) do
		local part = model:FindFirstChild(limb)
		if part then
			trails[limb] = makeTrail(part, c0:Lerp(Color3.new(1, 1, 1), 0.2), c1)
		end
	end
	rig = {
		Model = model,
		Motors = motors,
		BaseC0 = baseC0,
		Clips = {}, -- { Clip, Start, Speed }
		Loops = {}, -- [name] = target weight (0 or 1)
		LoopWeights = {},
		Trails = trails,
		LastPosition = nil,
		WalkPhase = 0,
	}
	rigs[model] = rig
	return rig
end

local function restore(rig)
	for joint, motor in pairs(rig.Motors) do
		if motor.Parent then
			motor.C0 = rig.BaseC0[joint]
		end
	end
	for _, trail in pairs(rig.Trails) do
		if trail.Parent then
			trail.Enabled = false
		end
	end
end

---------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------
-- Play a one-shot move on a model. speed = 1 is normal.
function CombatAnim.Play(model, clipName, speed)
	local clip = CLIPS[clipName]
	local rig = model and getRig(model)
	if not clip or not rig then
		return
	end
	-- a new move of the same kind restarts instead of stacking
	for i = #rig.Clips, 1, -1 do
		if rig.Clips[i].Clip == clip then
			table.remove(rig.Clips, i)
		end
	end
	table.insert(rig.Clips, { Clip = clip, Start = os.clock(), Speed = speed or 1 })
end

-- Turn a held pose on/off: "Stance", "Block", "Stun"
function CombatAnim.SetLoop(model, loopName, on)
	local rig = model and getRig(model)
	if rig then
		rig.Loops[loopName] = on and 1 or 0
	end
end

-- Stop animating a model and put its joints back
function CombatAnim.Release(model)
	local rig = rigs[model]
	if rig then
		restore(rig)
		rigs[model] = nil
	end
end

function CombatAnim.IsAnimating(model)
	return rigs[model] ~= nil
end

---------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------
local TRAIL_LIMBS = {
	RightHand = { "RightHand" },
	LeftHand = { "LeftHand" },
	RightFoot = { "RightFoot" },
	BothHands = { "RightHand", "LeftHand" },
}

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for model, rig in pairs(rigs) do
		if not model.Parent or not rig.Motors.Root.Parent then
			rigs[model] = nil
			continue
		end
		local offsets = {}
		local driven = {}
		local trailsOn = {}

		-- one-shot clips (they win over held poses for the joints they use)
		for i = #rig.Clips, 1, -1 do
			local playing = rig.Clips[i]
			local clip = playing.Clip
			local elapsed = (now - playing.Start) * playing.Speed
			if elapsed >= clip.Duration then
				table.remove(rig.Clips, i)
			else
				local pose = sampleClip(clip, elapsed)
				for joint, cf in pairs(pose) do
					offsets[joint] = (offsets[joint] or I) * cf
					driven[joint] = true
				end
				if clip.Trail and elapsed < clip.Duration * 0.75 then
					for _, limb in ipairs(TRAIL_LIMBS[clip.Trail] or {}) do
						trailsOn[limb] = true
					end
				end
			end
		end

		-- held poses fade in/out smoothly
		for name, poseFn in pairs(LOOPS) do
			local target = rig.Loops[name] or 0
			local weight = rig.LoopWeights[name] or 0
			weight += math.clamp(target - weight, -dt * 8, dt * 8)
			rig.LoopWeights[name] = weight
			if weight > 0.001 then
				for joint, cf in pairs(poseFn(now)) do
					if not driven[joint] then
						offsets[joint] = (offsets[joint] or I) * I:Lerp(cf, weight)
					end
				end
			end
		end

		-- bots have no walk animation of their own: swing their legs and arms
		if model:GetAttribute("IsDuelBot") then
			local root = model:FindFirstChild("HumanoidRootPart")
			if root then
				local velocity = root.AssemblyLinearVelocity
				local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				rig.WalkPhase += dt * speed * 0.55
				local amount = math.clamp(speed / 16, 0, 1)
				local swing = math.sin(rig.WalkPhase) * 38 * amount
				local walk = {
					RightHip = P(swing),
					LeftHip = P(-swing),
					RightKnee = P(-math.max(0, -math.sin(rig.WalkPhase)) * 40 * amount),
					LeftKnee = P(-math.max(0, math.sin(rig.WalkPhase)) * 40 * amount),
					RightShoulder = P(-swing * 0.6),
					LeftShoulder = P(swing * 0.6),
				}
				for joint, cf in pairs(walk) do
					if not driven[joint] then
						offsets[joint] = (offsets[joint] or I) * cf
					end
				end
			end
		end

		for joint, motor in pairs(rig.Motors) do
			motor.C0 = rig.BaseC0[joint] * (offsets[joint] or I)
		end
		for limb, trail in pairs(rig.Trails) do
			trail.Enabled = trailsOn[limb] == true
		end
	end
end)

return CombatAnim
