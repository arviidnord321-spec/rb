-- TradeService (ModuleScript in ServerScriptService)
-- Player-to-player trading of auras and pets. Started by RollService (which
-- owns everyone's saved data) so a trade moves items in one safe step.
--
-- How a trade works:
--   1. Player A sends a request (🤝 TRADE menu). At least ONE of the two
--      players needs the VIP pass (Config.Trading.RequireVIP).
--   2. Player B accepts -> both see the trade window.
--   3. Both add auras / pets. Any change un-readies both players.
--   4. Both press READY -> a short countdown -> the server checks that both
--      still own everything, then swaps it all at once and saves.

return function(api)
	local Players = game:GetService("Players")
	local Config = api.Config
	local AuraData = api.AuraData
	local PetData = api.PetData
	local sessions = api.sessions
	local SETTINGS = Config.Trading

	local TradeRemote = api.getRemote("RemoteEvent", "Trade")

	local trades = {} -- [player] = trade (both players point at the same trade)
	local requests = {} -- [target] = { From = player, At = os.clock() }
	local lastAction = {} -- [player] = os.clock(), simple spam guard

	local function send(player, message)
		if player and player.Parent then
			TradeRemote:FireClient(player, message)
		end
	end

	local function hasVIP(player)
		return player:GetAttribute("Pass_VIP") == true
	end

	local function busy(player)
		return trades[player] ~= nil or player:GetAttribute("InDuel") == true
	end

	-- how many of an item the player owns right now
	local function owned(player, kind, name)
		local data = sessions[player]
		if not data then
			return 0
		end
		if kind == "Aura" then
			return (data.Inventory or {})[name] or 0
		elseif kind == "Pet" then
			return (data.Pets or {})[name] or 0
		end
		return 0
	end

	local function offerList(offer)
		local list = {}
		for key, count in pairs(offer) do
			local kind, name = string.match(key, "^(%a+)|(.+)$")
			table.insert(list, { Kind = kind, Name = name, Count = count })
		end
		table.sort(list, function(a, b)
			if a.Kind ~= b.Kind then
				return a.Kind < b.Kind
			end
			return a.Name < b.Name
		end)
		return list
	end

	local function other(trade, player)
		return trade.A == player and trade.B or trade.A
	end

	local function push(trade)
		for _, player in ipairs({ trade.A, trade.B }) do
			local partner = other(trade, player)
			send(player, {
				Type = "Update",
				Partner = partner.DisplayName,
				PartnerId = partner.UserId,
				Mine = offerList(trade.Offers[player]),
				Theirs = offerList(trade.Offers[partner]),
				MyReady = trade.Ready[player] == true,
				TheirReady = trade.Ready[partner] == true,
				Counting = trade.Counting == true,
			})
		end
	end

	local function close(trade, reason)
		for _, player in ipairs({ trade.A, trade.B }) do
			if trades[player] == trade then
				trades[player] = nil
			end
			send(player, { Type = "Closed", Reason = reason })
		end
	end

	local function startTrade(a, b)
		local trade = { A = a, B = b, Offers = { [a] = {}, [b] = {} }, Ready = {}, Version = 0 }
		trades[a] = trade
		trades[b] = trade
		for _, player in ipairs({ a, b }) do
			send(player, { Type = "Open", Partner = other(trade, player).DisplayName })
		end
		push(trade)
	end

	-- remove items from one save and give them to the other
	local function moveItems(from, to, offer)
		local fromData, toData = sessions[from], sessions[to]
		for key, count in pairs(offer) do
			local kind, name = string.match(key, "^(%a+)|(.+)$")
			if kind == "Aura" then
				fromData.Inventory[name] -= count
				if fromData.Inventory[name] <= 0 then
					fromData.Inventory[name] = nil
					if fromData.Equipped == name then
						fromData.Equipped = ""
					end
				end
				toData.Inventory[name] = (toData.Inventory[name] or 0) + count
				local aura = AuraData.Get(name)
				if aura and aura.Chance > (toData.BestChance or 0) then
					toData.BestChance = aura.Chance
				end
			elseif kind == "Pet" then
				fromData.Pets[name] -= count
				local left = fromData.Pets[name]
				if left <= 0 then
					fromData.Pets[name] = nil
					left = 0
				end
				-- unequip copies you no longer have
				local equipped = fromData.EquippedPets or {}
				local onCount = 0
				for i = #equipped, 1, -1 do
					if equipped[i] == name then
						onCount += 1
						if onCount > left then
							table.remove(equipped, i)
						end
					end
				end
				toData.Pets = toData.Pets or {}
				toData.Pets[name] = (toData.Pets[name] or 0) + count
			end
		end
	end

	local function execute(trade)
		local a, b = trade.A, trade.B
		if not sessions[a] or not sessions[b] then
			close(trade, "Someone left")
			return
		end
		-- everyone must still own what they offered
		for _, player in ipairs({ a, b }) do
			for key, count in pairs(trade.Offers[player]) do
				local kind, name = string.match(key, "^(%a+)|(.+)$")
				if owned(player, kind, name) < count then
					close(trade, player.DisplayName .. " doesn't have those items any more")
					return
				end
			end
		end
		local gaveA, gaveB = offerList(trade.Offers[a]), offerList(trade.Offers[b])
		moveItems(a, b, trade.Offers[a])
		moveItems(b, a, trade.Offers[b])
		trades[a] = nil
		trades[b] = nil
		for _, player in ipairs({ a, b }) do
			api.applyAuraToCharacter(player)
			api.refreshStats(player)
			api.DataUpdatedRemote:FireClient(player, api.snapshot(sessions[player]))
			task.spawn(api.saveData, player)
		end
		send(a, { Type = "Done", Received = gaveB, Gave = gaveA, Partner = b.DisplayName })
		send(b, { Type = "Done", Received = gaveA, Gave = gaveB, Partner = a.DisplayName })
	end

	local function unready(trade)
		trade.Ready = {}
		trade.Counting = false
		trade.Version += 1
	end

	TradeRemote.OnServerEvent:Connect(function(player, request)
		if type(request) ~= "table" or type(request.Action) ~= "string" then
			return
		end
		local now = os.clock()
		if now - (lastAction[player] or 0) < 0.12 then
			return
		end
		lastAction[player] = now
		local action = request.Action

		if action == "Request" then
			local target = request.Target
			if typeof(target) ~= "Instance" or not target:IsA("Player") or target == player or not target.Parent then
				return
			end
			if SETTINGS.RequireVIP and not hasVIP(player) and not hasVIP(target) then
				send(player, { Type = "Error", Message = "👑 One of you needs the VIP pass to trade" })
				return
			end
			if busy(player) or busy(target) then
				send(player, { Type = "Error", Message = target.DisplayName .. " is busy right now" })
				return
			end
			-- they already asked us? then just start
			local theirs = requests[player]
			if theirs and theirs.From == target and now - theirs.At < 20 then
				requests[player] = nil
				startTrade(target, player)
				return
			end
			requests[target] = { From = player, At = now }
			send(target, { Type = "Request", From = player, FromName = player.DisplayName })
			send(player, { Type = "Info", Message = "🤝 Trade request sent to " .. target.DisplayName })

		elseif action == "Respond" then
			local entry = requests[player]
			if not entry or entry.From ~= request.From or now - entry.At > 20 then
				return
			end
			requests[player] = nil
			local from = entry.From
			if request.Accept ~= true then
				send(from, { Type = "Info", Message = player.DisplayName .. " declined the trade" })
				return
			end
			if not from.Parent or busy(from) or busy(player) then
				send(player, { Type = "Error", Message = "That trade isn't possible any more" })
				return
			end
			startTrade(from, player)

		elseif action == "SetItem" then
			local trade = trades[player]
			local kind, name, count = request.Kind, request.Name, request.Count
			if not trade then
				return
			end
			if (kind ~= "Aura" and kind ~= "Pet") or type(name) ~= "string" or type(count) ~= "number" then
				return
			end
			if kind == "Aura" and not AuraData.Get(name) then
				return
			end
			if kind == "Pet" and not PetData.Get(name) then
				return
			end
			count = math.clamp(math.floor(count), 0, owned(player, kind, name))
			local offer = trade.Offers[player]
			local key = kind .. "|" .. name
			if count > 0 and not offer[key] then
				local slots = 0
				for _ in pairs(offer) do
					slots += 1
				end
				if slots >= SETTINGS.MaxSlots then
					send(player, { Type = "Error", Message = ("You can offer up to %d different items"):format(SETTINGS.MaxSlots) })
					return
				end
			end
			offer[key] = (count > 0) and count or nil
			unready(trade)
			push(trade)

		elseif action == "Ready" then
			local trade = trades[player]
			if not trade then
				return
			end
			trade.Ready[player] = request.Value == true
			if trade.Ready[trade.A] and trade.Ready[trade.B] then
				-- nothing to swap? don't bother
				if next(trade.Offers[trade.A]) == nil and next(trade.Offers[trade.B]) == nil then
					trade.Ready = {}
					send(player, { Type = "Error", Message = "Add something to the trade first" })
					push(trade)
					return
				end
				trade.Counting = true
				trade.Version += 1
				local version = trade.Version
				push(trade)
				task.delay(SETTINGS.ConfirmSeconds, function()
					if trades[trade.A] == trade and trade.Version == version and trade.Ready[trade.A] and trade.Ready[trade.B] then
						execute(trade)
					end
				end)
			else
				trade.Counting = false
				trade.Version += 1
				push(trade)
			end

		elseif action == "Cancel" then
			local trade = trades[player]
			if trade then
				close(trade, player.DisplayName .. " cancelled the trade")
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local trade = trades[player]
		if trade then
			close(trade, player.DisplayName .. " left the game")
		end
		requests[player] = nil
		lastAction[player] = nil
		for target, entry in pairs(requests) do
			if entry.From == player then
				requests[target] = nil
			end
		end
	end)
end
