-- EventService (Script in ServerScriptService)
-- COSMIC EVENTS: every 20 minutes (Config.Events) a random server-wide event
-- starts for 5 minutes: Meteor Shower, Star Surge, Aurora Night, Cosmic
-- Eclipse or the rare Rainbow Rift. Each gives everyone extra luck (and Star
-- Surge makes rolling faster). The EventClient script shows the banner,
-- the timer and the sky effects.
--
-- Shared through ReplicatedStorage attributes:
--   EventKey, EventName, EventLuck, EventRollSpeed, EventEnds, EventNextAt

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))

local EVENTS = Config.Events
local rand = Random.new()

local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local AnnounceRemote = remotes:WaitForChild("Announce", 30)

local function now()
	return workspace:GetServerTimeNow()
end

local function pickEvent(lastKey)
	local total = 0
	for _, event in ipairs(EVENTS.List) do
		if event.Key ~= lastKey then
			total += event.Weight
		end
	end
	local value = rand:NextNumber() * total
	for _, event in ipairs(EVENTS.List) do
		if event.Key ~= lastKey then
			value -= event.Weight
			if value <= 0 then
				return event
			end
		end
	end
	return EVENTS.List[1]
end

local function clearEvent()
	ReplicatedStorage:SetAttribute("EventKey", "")
	ReplicatedStorage:SetAttribute("EventName", "")
	ReplicatedStorage:SetAttribute("EventLuck", 1)
	ReplicatedStorage:SetAttribute("EventRollSpeed", 1)
	ReplicatedStorage:SetAttribute("EventEnds", 0)
end

local function startEvent(event)
	local ends = now() + EVENTS.DurationMinutes * 60
	ReplicatedStorage:SetAttribute("EventKey", event.Key)
	ReplicatedStorage:SetAttribute("EventName", event.Name)
	ReplicatedStorage:SetAttribute("EventLuck", event.Luck or 1)
	ReplicatedStorage:SetAttribute("EventRollSpeed", event.RollSpeed or 1)
	ReplicatedStorage:SetAttribute("EventEnds", ends)
	if AnnounceRemote then
		AnnounceRemote:FireAllClients({ Type = "EventStart", Key = event.Key, Name = event.Name, Description = event.Description })
	end
end

clearEvent()
-- the first event comes a bit sooner than the rest
ReplicatedStorage:SetAttribute("EventNextAt", now() + math.min(8, EVENTS.EveryMinutes) * 60)

task.spawn(function()
	local lastKey
	while true do
		task.wait(1)
		local t = now()
		local ends = ReplicatedStorage:GetAttribute("EventEnds") or 0
		if ends > 0 and t >= ends then
			clearEvent()
			if AnnounceRemote then
				AnnounceRemote:FireAllClients({ Type = "EventEnd" })
			end
		end
		local nextAt = ReplicatedStorage:GetAttribute("EventNextAt") or t
		if t >= nextAt and (ReplicatedStorage:GetAttribute("EventEnds") or 0) == 0 then
			local event = pickEvent(lastKey)
			lastKey = event.Key
			startEvent(event)
			ReplicatedStorage:SetAttribute("EventNextAt", t + EVENTS.EveryMinutes * 60)
		end
	end
end)
