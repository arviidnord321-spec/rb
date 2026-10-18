-- QuestData (ModuleScript in ReplicatedStorage)
-- Daily login rewards + daily quests. Everything resets at midnight UTC.
--   * DAILY REWARD: log in every day for a 7-day reward streak (miss a day
--     and the streak starts over; after day 7 it loops back to day 1)
--   * DAILY QUESTS: 3 new quests every day (everyone gets the same ones),
--     each with its own reward, plus a bonus chest for finishing all 3
--
-- Reward fields (mix them as you like):
--   Potion = minutes of x2 luck        BoostRolls = Cosmic Rolls (x50 next roll)
--   Aura = "Name", Count = how many    (auras are used to buy pet eggs)

local QuestData = {}

QuestData.DailyRewards = {
	{ Potion = 5 },
	{ Aura = "Comet", Count = 3 },
	{ BoostRolls = 1 },
	{ Potion = 15 },
	{ Aura = "Nebula", Count = 2 },
	{ BoostRolls = 2 },
	{ BoostRolls = 3, Potion = 30, Aura = "Solar Flare", Count = 1 }, -- the big one
}

-- Kinds of quests (what counts):
--   Rolls      = rolls anywhere
--   LuckyRolls = rolls while standing on Lucky Isle or a rebirth island
--   Rarity     = roll an aura at least this rare (Threshold), Goal = how many
--   Parkour    = finish any parkour course
--   DuelWin    = win duels (players or bots)
--   Hatch      = hatch eggs
--   Merge      = merge pets
QuestData.Pool = {
	-- slot 1 is always a rolling quest
	{ Id = "Roll150", Slot = 1, Kind = "Rolls", Goal = 150, Text = "Roll 150 times", Reward = { Potion = 10 } },
	{ Id = "Roll400", Slot = 1, Kind = "Rolls", Goal = 400, Text = "Roll 400 times", Reward = { BoostRolls = 1, Potion = 5 } },
	{ Id = "IslandRolls", Slot = 1, Kind = "LuckyRolls", Goal = 75, Text = "Roll 75 times on a luck island", Reward = { BoostRolls = 1 } },
	-- slots 2 and 3: everything else
	{ Id = "Rare500", Kind = "Rarity", Threshold = 500, Goal = 1, Text = "Roll a 1 in 500 aura or rarer", Reward = { Aura = "Comet", Count = 3 } },
	{ Id = "Rare2500", Kind = "Rarity", Threshold = 2500, Goal = 1, Text = "Roll a 1 in 2,500 aura or rarer", Reward = { BoostRolls = 2 } },
	{ Id = "Rare128x3", Kind = "Rarity", Threshold = 128, Goal = 3, Text = "Roll 3 auras of 1 in 128 or rarer", Reward = { Potion = 15 } },
	{ Id = "Parkour1", Kind = "Parkour", Goal = 1, Text = "Finish a parkour course", Reward = { Potion = 10 } },
	{ Id = "Parkour2", Kind = "Parkour", Goal = 2, Text = "Finish 2 parkour courses", Reward = { BoostRolls = 1, Aura = "Pulsar", Count = 1 } },
	{ Id = "Duel2", Kind = "DuelWin", Goal = 2, Text = "Win 2 duels (players or bots)", Reward = { Aura = "Nebula", Count = 1 } },
	{ Id = "Duel5", Kind = "DuelWin", Goal = 5, Text = "Win 5 duels (players or bots)", Reward = { BoostRolls = 2 } },
	{ Id = "Hatch3", Kind = "Hatch", Goal = 3, Text = "Hatch 3 pet eggs", Reward = { Potion = 10, Aura = "Stardust", Count = 6 } },
	{ Id = "Hatch8", Kind = "Hatch", Goal = 8, Text = "Hatch 8 pet eggs", Reward = { BoostRolls = 1, Aura = "Comet", Count = 2 } },
	{ Id = "Merge1", Kind = "Merge", Goal = 1, Text = "Merge 3 pets into a Golden pet", Reward = { BoostRolls = 1 } },
}
QuestData.ById = {}
for _, quest in ipairs(QuestData.Pool) do
	QuestData.ById[quest.Id] = quest
end

-- finishing all 3 quests of the day
QuestData.Bonus = { BoostRolls = 2, Potion = 15 }

-- Today's number (changes at midnight UTC)
function QuestData.Today(now)
	return math.floor((now or os.time()) / 86400)
end

-- seconds until the next reset
function QuestData.SecondsToReset(now)
	now = now or os.time()
	return 86400 - (now % 86400)
end

-- The 3 quests for a day: the same for everybody on that day
function QuestData.QuestsFor(day)
	local rng = Random.new(day * 7919 + 13)
	local slotOne, others = {}, {}
	for _, quest in ipairs(QuestData.Pool) do
		table.insert(quest.Slot == 1 and slotOne or others, quest)
	end
	local picked = { slotOne[rng:NextInteger(1, #slotOne)].Id }
	while #picked < 3 do
		local quest = others[rng:NextInteger(1, #others)]
		local kindTaken = false
		for _, id in ipairs(picked) do
			if QuestData.ById[id].Kind == quest.Kind then
				kindTaken = true
			end
		end
		if not kindTaken then
			table.insert(picked, quest.Id)
		end
	end
	return picked
end

-- "x2 luck 10 min + 1 Cosmic Roll + 3x Comet"
function QuestData.RewardText(reward)
	local parts = {}
	if reward.Potion then
		table.insert(parts, ("🧪 %d min x2 luck"):format(reward.Potion))
	end
	if reward.BoostRolls then
		table.insert(parts, ("🎲 %d Cosmic Roll%s"):format(reward.BoostRolls, reward.BoostRolls == 1 and "" or "s"))
	end
	if reward.Aura then
		table.insert(parts, ("✨ %dx %s"):format(reward.Count or 1, reward.Aura))
	end
	return table.concat(parts, " + ")
end

-- the main icon for a reward tile
function QuestData.RewardIcon(reward)
	if reward.BoostRolls and reward.Potion then
		return "🎁"
	elseif reward.BoostRolls then
		return "🎲"
	elseif reward.Aura then
		return "✨"
	end
	return "🧪"
end

return QuestData
