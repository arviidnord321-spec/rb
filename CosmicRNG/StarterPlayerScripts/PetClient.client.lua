-- PetClient (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Pets on your screen:
--   * 🐾 PETS button + panel: your pets (3D previews), equip up to 3
--   * egg panel when you press E at an egg: price, odds, HATCH button
--   * the hatching animation (egg wobbles, cracks, pet pops out)
--   * everyone's equipped pets float behind them, each kind moving in its
--     own way (wings flap, fish wiggle, stars spin, wisps orbit...)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("CosmicConfig"))
local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local PetModels = require(ReplicatedStorage:WaitForChild("PetModels"))
local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local THEME = UIKit.Theme
local TITLE_FONT = UIKit.TitleFont
local new, corner, stroke, textStroke, tween, label =
	UIKit.new, UIKit.corner, UIKit.stroke, UIKit.textStroke, UIKit.tween, UIKit.label

local remotes = ReplicatedStorage:WaitForChild("CosmicRemotes")
local HatchRemote = remotes:WaitForChild("HatchEgg")
local PetRemote = remotes:WaitForChild("PetAction")
local GetDataRemote = remotes:WaitForChild("GetData")
local DataUpdatedRemote = remotes:WaitForChild("DataUpdated")

local myData = { Inventory = {}, Pets = {}, EquippedPets = {} }

---------------------------------------------------------------------
-- BUILDING A PET (the looks and moves live in the PetModels module)
---------------------------------------------------------------------
local function buildPet(petName)
	return PetModels.Build(petName)
end

local function posePet(model, base, t, phase, move)
	PetModels.Pose(model, base, t, phase, move)
end

---------------------------------------------------------------------
-- FOLLOWERS: everyone's pets float behind them
---------------------------------------------------------------------
local SLOTS = { CFrame.new(-3.6, 0, 3), CFrame.new(3.6, 0, 3), CFrame.new(0, 0, 5) }
local FLOAT_HEIGHT = { 1.2, 1.2, 2.6 }
-- these pets walk on the ground; the rest fly
local WALKERS = { Blob = true, Cat = true, Bunny = true }
local followers = {} -- [player] = { Names = "A,B", Pets = { { Model, Shape, Phase, Current } } }
local petFolder = Instance.new("Folder")
petFolder.Name = "CosmicPets"
petFolder.Parent = workspace

local function clearFollowers(who)
	local entry = followers[who]
	if entry then
		for _, pet in ipairs(entry.Pets) do
			pet.Model:Destroy()
		end
		followers[who] = nil
	end
end

local function syncFollowers(who)
	local names = who:GetAttribute("EquippedPets") or ""
	local entry = followers[who]
	if entry and entry.Names == names then
		return
	end
	clearFollowers(who)
	entry = { Names = names, Pets = {} }
	for _, petName in ipairs(PetData.Split(names)) do
		local model = buildPet(petName)
		if model then
			model.Parent = petFolder
			table.insert(entry.Pets, { Model = model, Shape = PetData.Get(petName).Shape, Phase = math.random() * 6 })
		end
	end
	followers[who] = entry
end

local function watch(who)
	who:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		syncFollowers(who)
	end)
	syncFollowers(who)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(clearFollowers)
for _, who in ipairs(Players:GetPlayers()) do
	watch(who)
end

local camera = workspace.CurrentCamera
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	for who, entry in pairs(followers) do
		local character = who.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hidden = not root or character:GetAttribute("InDuel") or character:GetAttribute("InCutscene")
			or (camera.CFrame.Position - root.Position).Magnitude > 250
		local move, groundDrop = 0, 3
		if not hidden then
			local velocity = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
			move = math.clamp(velocity.Magnitude / 16, 0, 1)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				groundDrop = humanoid.HipHeight + root.Size.Y / 2
			end
		end
		for index, pet in ipairs(entry.Pets) do
			PetModels.SetHidden(pet.Model, hidden)
			if not hidden then
				local slot = SLOTS[index] or SLOTS[1]
				local flatLook = root.CFrame.LookVector * Vector3.new(1, 0, 1)
				local facing = flatLook.Magnitude > 0.01 and CFrame.lookAt(root.Position, root.Position + flatLook) or root.CFrame
				local height
				if WALKERS[pet.Shape] then
					height = -groundDrop + 1.35 -- standing on the ground
				else
					height = (FLOAT_HEIGHT[index] or 1.2) + math.sin(t * 2 + pet.Phase) * 0.35
				end
				local target = facing * slot * CFrame.new(0, height, 0)
				pet.Current = pet.Current and pet.Current:Lerp(target, math.min(1, dt * 7)) or target
				posePet(pet.Model, pet.Current, t, pet.Phase, move)
			end
		end
	end
end)

---------------------------------------------------------------------
-- 3D preview in a ViewportFrame
---------------------------------------------------------------------
local function preview(parent, petName, zoom)
	local viewport = new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 220),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = parent,
	})
	local model = buildPet(petName)
	if model then
		model.Parent = viewport
		local cam = Instance.new("Camera")
		cam.FieldOfView = 40
		local focus = Vector3.new(0, 0.35, 0)
		cam.CFrame = CFrame.lookAt(focus + Vector3.new(2.3, 1.5, -6.2) * (zoom or 1), focus)
		cam.Parent = viewport
		viewport.CurrentCamera = cam
		posePet(model, CFrame.Angles(0, math.rad(25), 0), 0, 0, 0)
	end
	return viewport, model
end

---------------------------------------------------------------------
-- MENU BUTTON
---------------------------------------------------------------------
local menuGui = player:WaitForChild("PlayerGui"):WaitForChild("CosmicMenu", 30)
local sideMenu = menuGui and menuGui:WaitForChild("SideMenu", 10)
local menuButton
if sideMenu then
	menuButton = new("TextButton", {
		Name = "PETS", LayoutOrder = 3, Size = UDim2.fromOffset(84, 84), BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.1, AutoButtonColor = false, Text = "", Parent = sideMenu,
	}, { corner(UDim.new(0, 18)), stroke(Color3.fromRGB(255, 170, 120), 2.5, 0) })
	label({ Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 6), Text = "🐾", TextSize = 38, Parent = menuButton })
	local text = label({
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 20),
		Text = "PETS", Font = TITLE_FONT, TextSize = 16, Parent = menuButton,
	})
	textStroke(1.2).Parent = text
	UIKit.addButtonFeel(menuButton)
end

---------------------------------------------------------------------
-- PETS PANEL
---------------------------------------------------------------------
local gui = UIKit.screen("CosmicPets", 2)
local holder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(660, 520),
	BackgroundTransparency = 1, Visible = false, Parent = gui,
})
UIKit.addAutoScale(holder, 800)
local panel = new("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.05, Parent = holder,
}, { corner(UDim.new(0, 18)), stroke(Color3.fromRGB(255, 170, 120), 2.5, 0) })
local title = label({
	Position = UDim2.fromOffset(22, 12), Size = UDim2.new(1, -80, 0, 40), Text = "🐾 YOUR PETS", Font = TITLE_FONT,
	TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
})
UIKit.gradient(Color3.fromRGB(255, 210, 150), Color3.fromRGB(255, 130, 190), 0).Parent = title
local summary = label({
	Position = UDim2.fromOffset(22, 52), Size = UDim2.new(1, -44, 0, 22), Text = "", TextSize = 16, RichText = true,
	TextColor3 = THEME.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
})
local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(42, 42),
	BackgroundColor3 = THEME.Bad, Text = "X", Font = TITLE_FONT, TextSize = 24, TextColor3 = THEME.Text, AutoButtonColor = false, Parent = panel,
}, { corner(UDim.new(0, 10)), textStroke(1.5) })
UIKit.addButtonFeel(closeButton)

local function smallButton(text, color, x)
	local b = new("TextButton", {
		Position = UDim2.fromOffset(x, 82), Size = UDim2.fromOffset(150, 34), BackgroundColor3 = color,
		Text = text, Font = TITLE_FONT, TextSize = 17, TextColor3 = THEME.Text, AutoButtonColor = false, Parent = panel,
	}, { corner(UDim.new(0, 10)), textStroke(1.2) })
	UIKit.addButtonFeel(b)
	return b
end
local bestButton = smallButton("⭐ EQUIP BEST", THEME.Good, 22)
local clearButton = smallButton("UNEQUIP ALL", Color3.fromRGB(90, 80, 130), 182)

local grid = new("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 128), Size = UDim2.new(1, -32, 1, -142), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, ScrollBarImageColor3 = Color3.fromRGB(255, 170, 120), CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panel,
}, {
	new("UIGridLayout", { CellSize = UDim2.fromOffset(142, 168), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }),
})
local emptyLabel = label({
	Position = UDim2.fromOffset(16, 200), Size = UDim2.new(1, -32, 0, 60), TextWrapped = true, Visible = false,
	Text = "No pets yet! Find the 🥚 Hatchery on each island and pay with your auras to hatch eggs.",
	TextSize = 18, TextColor3 = THEME.SubText, Parent = panel,
})

local open = false
local function equippedList()
	return PetData.Split(player:GetAttribute("EquippedPets") or "")
end

local function countIn(list, name)
	local n = 0
	for _, v in ipairs(list) do
		if v == name then
			n += 1
		end
	end
	return n
end

local function petAction(action, petName)
	local ok, result = pcall(function()
		return PetRemote:InvokeServer(action, petName)
	end)
	if ok and type(result) == "table" then
		myData.Pets = result.Pets or myData.Pets
		myData.EquippedPets = result.EquippedPets or myData.EquippedPets
	end
end

local refreshPanel -- defined below
local mergePets -- defined below
local setOpen -- defined below
local function refreshSoon()
	task.defer(function()
		if refreshPanel then
			refreshPanel()
		end
	end)
end


---------------------------------------------------------------------
-- MERGING: 3 of the same pet -> golden -> rainbow
---------------------------------------------------------------------
local mergeFx = UIKit.screen("CosmicMergeFX", 46)
local function mergeAnimation(fromKey, toKey)
	local from, to = PetData.Get(fromKey), PetData.Get(toKey)
	if not from or not to then
		return
	end
	local golden = to.Variant == "Golden"
	local color = golden and Color3.fromRGB(255, 210, 80) or Color3.fromRGB(200, 120, 255)
	local dim = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = mergeFx })
	tween(dim, 0.3, { BackgroundTransparency = 0.35 })
	-- three copies fly together
	local copies = {}
	for i = -1, 1 do
		local frame = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, i * 260, 0.45, 0), Size = UDim2.fromOffset(200, 200), BackgroundTransparency = 1, Parent = mergeFx })
		preview(frame, fromKey)
		local scale = new("UIScale", { Scale = 0, Parent = frame })
		tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		table.insert(copies, { Frame = frame, Scale = scale })
	end
	SoundFX.Play("Whoosh")
	task.wait(0.6)
	for _, c in ipairs(copies) do
		tween(c.Frame, 0.45, { Position = UDim2.fromScale(0.5, 0.45), Rotation = 360 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(c.Scale, 0.45, { Scale = 0.4 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	SoundFX.Riser(0.45, { Volume = 0.6 })
	task.wait(0.47)
	for _, c in ipairs(copies) do
		c.Frame:Destroy()
	end
	-- flash, then the merged pet
	local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = 0, Parent = mergeFx })
	tween(flash, 0.7, { BackgroundTransparency = 1 })
	SoundFX.Play("RevealLegendary", { Volume = 0.8 })
	UIKit.burst({ color, Color3.new(1, 1, 1) }, 50, 1.3, Vector2.new(0.5, 0.45))
	local result = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(300, 300), BackgroundTransparency = 1, Parent = mergeFx })
	local glow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(280, 280), BackgroundColor3 = color, BackgroundTransparency = 0.6, Parent = result }, { corner(UDim.new(1, 0)) })
	local _, model = preview(result, toKey, 0.8)
	local resultScale = new("UIScale", { Scale = 0.2, Parent = result })
	tween(resultScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	local variant = PetData.Variants[to.Variant]
	local name = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.fromOffset(800, 52), Text = variant.Icon .. " " .. PetData.Display(toKey):upper(), Font = TITLE_FONT, TextSize = 46, TextColor3 = color, Parent = mergeFx })
	textStroke(3).Parent = name
	local info = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.64, 56), Size = UDim2.fromOffset(800, 30),
		Text = ("+%d%% luck  →  +%d%% luck"):format(math.floor(from.Luck * 100 + 0.5), math.floor(to.Luck * 100 + 0.5)), Font = TITLE_FONT, TextSize = 28, TextColor3 = THEME.Good, Parent = mergeFx })
	textStroke(2).Parent = info
	UIKit.confetti({ color, THEME.Gold, Color3.new(1, 1, 1) }, 60)
	local start = os.clock()
	local spin = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		glow.Rotation = t * 50
		if model then
			posePet(model, CFrame.Angles(0, t * 1.6, 0), t, 0, 0)
		end
	end)
	task.wait(2.4)
	tween(dim, 0.4, { BackgroundTransparency = 1 })
	tween(name, 0.4, { TextTransparency = 1 })
	tween(info, 0.4, { TextTransparency = 1 })
	tween(resultScale, 0.4, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.wait(0.45)
	spin:Disconnect()
	for _, item in ipairs({ dim, flash, result, name, info }) do
		item:Destroy()
	end
end

local merging = false
mergePets = function(petKey)
	if merging then
		return
	end
	merging = true
	local ok, result = pcall(function()
		return PetRemote:InvokeServer("Merge", petKey)
	end)
	if ok and type(result) == "table" then
		myData.Pets = result.Pets or myData.Pets
		myData.EquippedPets = result.EquippedPets or myData.EquippedPets
		if result.Merged then
			setOpen(false)
			mergeAnimation(petKey, result.Merged)
			setOpen(true)
		else
			UIKit.toast("You need 3 of the same pet to merge", THEME.Bad)
		end
	end
	merging = false
end

refreshPanel = function()
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local equipped = equippedList()
	summary.Text = ("Equipped <b>%d/%d</b>  •  Pet luck <font color='#78ffaa'><b>x%s</b></font>"):format(
		#equipped, PetData.MaxEquipped, tostring(math.floor(PetData.LuckFrom(equipped) * 100 + 0.5) / 100))
	local owned = {}
	for name, count in pairs(myData.Pets or {}) do
		local pet = PetData.Get(name)
		if pet and count > 0 then
			table.insert(owned, pet)
		end
	end
	table.sort(owned, function(a, b)
		return a.Luck > b.Luck
	end)
	emptyLabel.Visible = #owned == 0
	for order, pet in ipairs(owned) do
		local rarity = PetData.Rarities[pet.Rarity]
		local count = myData.Pets[pet.Name]
		local on = countIn(equipped, pet.Name)
		local card = new("TextButton", {
			LayoutOrder = order, BackgroundColor3 = on > 0 and Color3.fromRGB(34, 62, 56) or THEME.PanelLight,
			Text = "", AutoButtonColor = false, Parent = grid,
		}, { corner(UDim.new(0, 12)), stroke(rarity.Color, on > 0 and 3 or 1.5, on > 0 and 0 or 0.4) })
		local view = new("Frame", { Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 90), BackgroundTransparency = 1, Parent = card })
		preview(view, pet.Name)
		local variant = pet.Variant and PetData.Variants[pet.Variant]
		local shownName = (variant and (variant.Icon .. " ") or "") .. PetData.Display(pet.Name)
		label({ Position = UDim2.fromOffset(4, 94), Size = UDim2.new(1, -8, 0, 20), Text = shownName, Font = TITLE_FONT, TextSize = 15, TextScaled = #shownName > 16,
			TextColor3 = pet.Variant == "Golden" and Color3.fromRGB(255, 215, 90) or UIKit.readable(rarity.Color), Parent = card })
		-- 3 of the same? merge them into a golden (or rainbow) pet
		local mergeInto = PetData.MergeResult(pet.Name)
		if mergeInto and count >= PetData.MergeCount then
			local nextVariant = PetData.SplitKey(mergeInto)
			local merge = new("TextButton", {
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(78, 24), ZIndex = 3,
				BackgroundColor3 = nextVariant == "Golden" and Color3.fromRGB(220, 160, 30) or Color3.fromRGB(170, 80, 220),
				Text = ("%s MERGE 3"):format(PetData.Variants[nextVariant].Icon), Font = TITLE_FONT, TextSize = 12,
				TextColor3 = THEME.Text, AutoButtonColor = false, Parent = card,
			}, { corner(UDim.new(0, 8)), textStroke(1) })
			UIKit.addButtonFeel(merge)
			merge.Activated:Connect(function()
				mergePets(pet.Name)
			end)
		end
		label({ Position = UDim2.fromOffset(4, 114), Size = UDim2.new(1, -8, 0, 16), Text = ("%s • +%d%% luck"):format(pet.Rarity, math.floor(pet.Luck * 100 + 0.5)), TextSize = 12, TextColor3 = THEME.SubText, Parent = card })
		label({ Position = UDim2.fromOffset(4, 134), Size = UDim2.new(1, -8, 0, 26), Text = on > 0 and ("✅ EQUIPPED" .. (on > 1 and (" x" .. on) or "")) or ("x" .. count .. "  • tap to equip"), Font = TITLE_FONT, TextSize = 13,
			TextColor3 = on > 0 and THEME.Good or THEME.Text, Parent = card })
		UIKit.addButtonFeel(card)
		card.Activated:Connect(function()
			if on > 0 then
				petAction("Unequip", pet.Name)
			elseif #equipped >= PetData.MaxEquipped then
				UIKit.toast(("You can equip %d pets - unequip one first"):format(PetData.MaxEquipped), THEME.Bad)
				return
			else
				petAction("Equip", pet.Name)
			end
			refreshSoon()
		end)
	end
end

setOpen = function(value)
	if value == open then
		return
	end
	open = value
	if open then
		UIKit.announcePanel("Pets")
		refreshPanel()
		holder.Visible = true
		UIKit.popIn(panel)
	else
		holder.Visible = false
	end
end
if menuButton then
	menuButton.Activated:Connect(function()
		setOpen(not open)
	end)
end
closeButton.Activated:Connect(function()
	setOpen(false)
end)
bestButton.Activated:Connect(function()
	petAction("EquipBest")
	refreshSoon()
end)
clearButton.Activated:Connect(function()
	petAction("UnequipAll")
	refreshSoon()
end)
player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
	if open then
		refreshSoon()
	end
end)

---------------------------------------------------------------------
-- EGG PANEL
---------------------------------------------------------------------
local eggHolder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 430),
	BackgroundTransparency = 1, Visible = false, Parent = gui,
})
UIKit.addAutoScale(eggHolder, 800)
local eggPanel = new("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.05, Parent = eggHolder,
}, { corner(UDim.new(0, 18)) })
local eggStroke = stroke(THEME.Gold, 2.5, 0)
eggStroke.Parent = eggPanel
local eggTitle = label({
	Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -80, 0, 38), Text = "", Font = TITLE_FONT, TextSize = 30,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = eggPanel,
})
textStroke(1.5).Parent = eggTitle
local eggCost = label({
	Position = UDim2.fromOffset(20, 50), Size = UDim2.new(1, -40, 0, 24), Text = "", TextSize = 17, RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = eggPanel,
})
local eggClose = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = THEME.Bad, Text = "X", Font = TITLE_FONT, TextSize = 22, TextColor3 = THEME.Text, AutoButtonColor = false, Parent = eggPanel,
}, { corner(UDim.new(0, 10)), textStroke(1.5) })
UIKit.addButtonFeel(eggClose)
local oddsRow = new("Frame", {
	Position = UDim2.fromOffset(16, 86), Size = UDim2.new(1, -32, 0, 220), BackgroundTransparency = 1, Parent = eggPanel,
}, { new("UIGridLayout", { CellSize = UDim2.fromOffset(116, 214), CellPadding = UDim2.fromOffset(6, 0), SortOrder = Enum.SortOrder.LayoutOrder }) })
local hatchButton = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 318), Size = UDim2.fromOffset(280, 58),
	BackgroundColor3 = THEME.Good, Text = "🥚 HATCH", Font = TITLE_FONT, TextSize = 30, TextColor3 = THEME.Text,
	AutoButtonColor = false, Parent = eggPanel,
}, { corner(UDim.new(0, 14)), textStroke(2) })
UIKit.addButtonFeel(hatchButton)
local eggNote = label({
	Position = UDim2.fromOffset(16, 384), Size = UDim2.new(1, -32, 0, 34), Text = "", TextSize = 13, TextWrapped = true,
	TextColor3 = THEME.SubText, Parent = eggPanel,
})

local currentEgg
local function islandNeeds(islandKey)
	for _, info in ipairs(Config.RebirthIslands) do
		if info.Key == islandKey then
			return info.Rebirths
		end
	end
	return 0
end

local function refreshEgg()
	local egg = currentEgg
	if not egg then
		return
	end
	eggTitle.Text = "🥚 " .. egg.Name
	eggTitle.TextColor3 = UIKit.readable(egg.Color, 0.8)
	eggStroke.Color = egg.Color
	local have = (myData.Inventory or {})[egg.Cost.Aura] or 0
	local aura = AuraData.Get(egg.Cost.Aura)
	local tierColor = aura and AuraData.Tiers[aura.Tier].Color or Color3.new(1, 1, 1)
	eggCost.Text = ("Costs <b>%dx <font color='#%s'>%s</font></b> aura  <font color='#bfb4e1'>(you have %d)</font>"):format(
		egg.Cost.Count, tierColor:ToHex(), egg.Cost.Aura, have)
	for _, child in ipairs(oddsRow:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for order, entry in ipairs(egg.Pets) do
		local pet = PetData.Get(entry[1])
		local rarity = PetData.Rarities[pet.Rarity]
		local card = new("Frame", { LayoutOrder = order, BackgroundColor3 = THEME.PanelLight, Parent = oddsRow }, { corner(UDim.new(0, 12)), stroke(rarity.Color, 1.5, 0.3) })
		local view = new("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 100), BackgroundTransparency = 1, Parent = card })
		preview(view, pet.Name)
		label({ Position = UDim2.fromOffset(4, 106), Size = UDim2.new(1, -8, 0, 36), Text = pet.Name, Font = TITLE_FONT, TextSize = 15, TextWrapped = true, TextColor3 = UIKit.readable(rarity.Color), Parent = card })
		label({ Position = UDim2.fromOffset(4, 142), Size = UDim2.new(1, -8, 0, 18), Text = pet.Rarity, TextSize = 12, TextColor3 = rarity.Color, Parent = card })
		label({ Position = UDim2.fromOffset(4, 160), Size = UDim2.new(1, -8, 0, 18), Text = ("+%d%% luck"):format(math.floor(pet.Luck * 100 + 0.5)), TextSize = 13, TextColor3 = THEME.Good, Parent = card })
		label({ Position = UDim2.fromOffset(4, 182), Size = UDim2.new(1, -8, 0, 26), Text = PetData.ChanceText(egg, entry[2]), Font = TITLE_FONT, TextSize = 20, Parent = card })
	end
	local need = islandNeeds(egg.Island)
	if (player:GetAttribute("Rebirths") or 0) < need then
		hatchButton.Text = ("🔒 REBIRTH %d"):format(need)
		hatchButton.BackgroundColor3 = Color3.fromRGB(70, 66, 90)
	elseif have < egg.Cost.Count then
		hatchButton.Text = "NEED MORE AURAS"
		hatchButton.BackgroundColor3 = Color3.fromRGB(70, 66, 90)
	else
		hatchButton.Text = "🥚 HATCH"
		hatchButton.BackgroundColor3 = THEME.Good
	end
	eggNote.Text = ("Hatching uses up %d of your %s auras. If it's the aura you're wearing and it's your last one, you'll take it off."):format(egg.Cost.Count, egg.Cost.Aura)
end

local function openEgg(egg)
	currentEgg = egg
	UIKit.announcePanel("Egg")
	refreshEgg()
	eggHolder.Visible = true
	UIKit.popIn(eggPanel)
end
local function closeEgg()
	eggHolder.Visible = false
	currentEgg = nil
end
eggClose.Activated:Connect(closeEgg)
UIKit.PanelOpened:Connect(function(name)
	if name ~= "Pets" then
		setOpen(false)
	end
	if name ~= "Egg" then
		closeEgg()
	end
end)

---------------------------------------------------------------------
-- HATCH ANIMATION
---------------------------------------------------------------------
local fxGui = UIKit.screen("CosmicHatchFX", 46)
local function hatchAnimation(egg, petName)
	local pet = PetData.Get(petName)
	local rarity = PetData.Rarities[pet.Rarity]
	local dim = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = fxGui })
	tween(dim, 0.3, { BackgroundTransparency = 0.35 })
	-- the egg (a 3D egg in a viewport)
	local eggFrame = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(300, 300), BackgroundTransparency = 1, Parent = fxGui })
	local viewport = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(200, 200, 220), LightDirection = Vector3.new(-1, -1, -1), Parent = eggFrame })
	local eggPart = Instance.new("Part")
	eggPart.Shape = Enum.PartType.Ball
	eggPart.Size = Vector3.new(4.6, 6, 4.6)
	eggPart.Color = egg.Color
	eggPart.Material = Enum.Material.SmoothPlastic
	eggPart.CFrame = CFrame.new()
	eggPart.Parent = viewport
	for k = 1, 6 do
		local spot = Instance.new("Part")
		spot.Shape = Enum.PartType.Ball
		spot.Size = Vector3.one * 0.7
		spot.Color = egg.Color:Lerp(Color3.new(1, 1, 1), 0.6)
		spot.Material = Enum.Material.Neon
		local a = k * 1.1 - 2.5
		spot.CFrame = CFrame.new(math.sin(a) * 2.1, math.cos(k * 1.9) * 1.8, -math.cos(a) * 2.1)
		spot.Parent = viewport
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, -12), Vector3.zero)
	cam.Parent = viewport
	viewport.CurrentCamera = cam
	local eggScale = new("UIScale", { Scale = 0.3, Parent = eggFrame })
	tween(eggScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	SoundFX.Play("Whoosh")
	task.wait(0.4)
	-- three wobbles, each bigger
	for wobble = 1, 3 do
		for _, angle in ipairs({ 12, -12, 8, 0 }) do
			tween(eggFrame, 0.07, { Rotation = angle * wobble * 0.8 })
			task.wait(0.07)
		end
		SoundFX.Play("Tick", { Speed = 0.8 + wobble * 0.2, Volume = 1 })
		task.wait(0.3 - wobble * 0.05)
	end
	-- crack!
	local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, Parent = fxGui })
	tween(flash, 0.6, { BackgroundTransparency = 1 })
	SoundFX.Play("IceShatter", { Volume = 0.6 })
	eggFrame:Destroy()
	-- the pet!
	local petFrame = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(320, 320), BackgroundTransparency = 1, Parent = fxGui })
	local glow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(300, 300), BackgroundColor3 = rarity.Color, BackgroundTransparency = 0.6, Parent = petFrame }, { corner(UDim.new(1, 0)) })
	local _, petModel = preview(petFrame, petName, 0.8)
	local petScale = new("UIScale", { Scale = 0.2, Parent = petFrame })
	tween(petScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	local name = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromOffset(700, 56), Text = pet.Name, Font = TITLE_FONT, TextSize = 52, TextColor3 = UIKit.readable(rarity.Color, 0.8), Parent = fxGui })
	textStroke(3).Parent = name
	local info = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromOffset(700, 30), Text = ("%s  •  +%d%% luck"):format(pet.Rarity, math.floor(pet.Luck * 100 + 0.5)), Font = TITLE_FONT, TextSize = 26, TextColor3 = THEME.Good, Parent = fxGui })
	info.Position = UDim2.new(0.5, 0, 0.66, 60)
	textStroke(2).Parent = info
	UIKit.burst({ rarity.Color, egg.Color, Color3.new(1, 1, 1) }, 20 + rarity.Order * 8, 0.8 + rarity.Order * 0.15)
	if rarity.Order >= 5 then
		UIKit.confetti({ rarity.Color, THEME.Gold, Color3.new(1, 1, 1) }, 80)
		SoundFX.Jingle("Victory")
	else
		SoundFX.Chime(1, 3 + math.min(2, rarity.Order - 1))
	end
	-- spin the pet while you admire it
	local spinStart = os.clock()
	local spin = RunService.RenderStepped:Connect(function()
		local t = os.clock() - spinStart
		glow.Rotation = t * 40
		if petModel then
			posePet(petModel, CFrame.Angles(0, t * 1.5, 0), t, 0, 0)
		end
	end)
	task.wait(2.6)
	tween(dim, 0.4, { BackgroundTransparency = 1 })
	tween(name, 0.4, { TextTransparency = 1 })
	tween(info, 0.4, { TextTransparency = 1 })
	tween(petScale, 0.4, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.wait(0.45)
	spin:Disconnect()
	for _, item in ipairs({ dim, flash, petFrame, name, info }) do
		item:Destroy()
	end
end

local hatching = false
hatchButton.Activated:Connect(function()
	local egg = currentEgg
	if not egg or hatching then
		return
	end
	hatching = true
	local ok, result = pcall(function()
		return HatchRemote:InvokeServer(egg.Key)
	end)
	if ok and type(result) == "table" and result.Pet then
		myData.Pets = result.Pets or myData.Pets
		closeEgg()
		hatchAnimation(egg, result.Pet)
		openEgg(egg) -- straight back to the egg so you can hatch again
	else
		local reason = ok and type(result) == "table" and result.Error or "Error"
		local messages = {
			NotEnough = ("You need %dx %s to hatch this egg"):format(egg.Cost.Count, egg.Cost.Aura),
			Locked = "This island's eggs unlock with rebirths!",
			TooFar = "Walk closer to the egg",
			Busy = "Hatching...",
		}
		UIKit.toast("🥚 " .. (messages[reason] or "Couldn't hatch, try again"), THEME.Bad)
		SoundFX.Play("Thud")
	end
	hatching = false
end)

-- pressing E at an egg opens its panel
local function hookPrompts()
	local hatcheries = workspace:WaitForChild("PetHatcheries", 60)
	if not hatcheries then
		return
	end
	local function hook(item)
		if item:IsA("ProximityPrompt") and item.Name == "HatchPrompt" then
			item.Triggered:Connect(function()
				local key = item.Parent and item.Parent:GetAttribute("EggKey")
				local egg = key and PetData.EggByKey[key]
				if egg then
					openEgg(egg)
				end
			end)
		end
	end
	for _, item in ipairs(hatcheries:GetDescendants()) do
		hook(item)
	end
	hatcheries.DescendantAdded:Connect(hook)
	-- the eggs gently bob
	local eggs = {}
	for _, item in ipairs(hatcheries:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute("FX_EggBob") then
			table.insert(eggs, { Part = item, Base = item.CFrame, Phase = math.random() * 6 })
		end
	end
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, e in ipairs(eggs) do
			if (camera.CFrame.Position - e.Base.Position).Magnitude < 200 then
				e.Part.CFrame = e.Base * CFrame.new(0, math.sin(t * 1.6 + e.Phase) * 0.35, 0) * CFrame.Angles(0, 0, math.sin(t * 2.2 + e.Phase) * 0.06)
			end
		end
	end)
end
task.spawn(hookPrompts)

---------------------------------------------------------------------
-- DATA
---------------------------------------------------------------------
DataUpdatedRemote.OnClientEvent:Connect(function(snapshot)
	if type(snapshot) == "table" then
		myData.Inventory = snapshot.Inventory or myData.Inventory
		myData.Pets = snapshot.Pets or myData.Pets
		myData.EquippedPets = snapshot.EquippedPets or myData.EquippedPets
		if open then
			refreshPanel()
		end
		if currentEgg then
			refreshEgg()
		end
	end
end)
task.spawn(function()
	for _ = 1, 30 do
		local ok, snapshot = pcall(function()
			return GetDataRemote:InvokeServer()
		end)
		if ok and type(snapshot) == "table" then
			myData.Inventory = snapshot.Inventory or {}
			myData.Pets = snapshot.Pets or {}
			myData.EquippedPets = snapshot.EquippedPets or {}
			return
		end
		task.wait(1)
	end
end)
-- rolls change your inventory too: keep the egg panel's "you have" honest
player:GetAttributeChangedSignal("Rolls"):Connect(function()
	if not currentEgg then
		return
	end
	task.delay(0.3, function()
		local ok, snapshot = pcall(function()
			return GetDataRemote:InvokeServer()
		end)
		if ok and type(snapshot) == "table" then
			myData.Inventory = snapshot.Inventory or myData.Inventory
			if currentEgg then
				refreshEgg()
			end
		end
	end)
end)
