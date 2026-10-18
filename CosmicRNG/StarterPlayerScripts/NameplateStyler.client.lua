-- NameplateStyler (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Makes every floating sign in the world (parkour, portals, eggs, cores,
-- islands...) easy to read:
--   * drawn on top of objects, so a wall or platform never cuts the text off
--   * a bit smaller and sized in the world, so far-away signs shrink instead
--     of covering your screen
--   * see-through, and they fade out more the further away you are
-- Only map signs are changed (not health bars or player name tags).

local Players = game:GetService("Players")

local camera = workspace.CurrentCamera

-- the map models whose signs we style
local ROOTS = {
	"CosmicIsland", "LuckyIsland", "ParkourCourses", "RebirthIslands",
	"PetHatcheries", "DuelIsland", "CosmicSkyDecor",
}
local PIXELS_PER_STUD = 48 -- 320 px wide sign -> about 6.7 studs wide
local NEAR = 30 -- closer than this: clearest
local BASE_TEXT = 0.12 -- text transparency up close
local FAR_TEXT = 0.6 -- text transparency at the edge of its range

local styled = {} -- [BillboardGui] = { Labels = {...}, Strokes = {...} }

local function isCharacterPart(gui)
	local node = gui.Parent
	while node and node ~= workspace do
		if node:IsA("Model") and Players:GetPlayerFromCharacter(node) then
			return true
		end
		node = node.Parent
	end
	return false
end

local function anchorPosition(gui)
	local target = gui.Adornee or gui.Parent
	if target and target:IsA("BasePart") then
		return target.Position + gui.StudsOffset
	elseif target and target:IsA("Attachment") then
		return target.WorldPosition + gui.StudsOffset
	end
	return nil
end

local applying = false
local function resize(gui)
	local size = gui.Size
	-- pixel sizes become world sizes (and 20% smaller than before)
	if size.X.Offset > 0 or size.Y.Offset > 0 then
		applying = true
		gui.Size = UDim2.new(size.X.Offset / PIXELS_PER_STUD, 0, size.Y.Offset / PIXELS_PER_STUD, 0)
		applying = false
	end
end

local function style(gui)
	if styled[gui] or isCharacterPart(gui) then
		return
	end
	local entry = { Labels = {}, Strokes = {} }
	styled[gui] = entry
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = math.min(gui.MaxDistance > 0 and gui.MaxDistance or 150, 180)
	resize(gui)
	-- if a script changes the size later, convert the new size too
	gui:GetPropertyChangedSignal("Size"):Connect(function()
		if not applying then
			resize(gui)
		end
	end)
	local function collect(item)
		if item:IsA("TextLabel") then
			table.insert(entry.Labels, item)
		elseif item:IsA("UIStroke") then
			table.insert(entry.Strokes, item)
		end
	end
	for _, item in ipairs(gui:GetDescendants()) do
		collect(item)
	end
	gui.DescendantAdded:Connect(collect)
	gui.Destroying:Connect(function()
		styled[gui] = nil
	end)
end

local function watchRoot(root)
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("BillboardGui") then
			style(item)
		end
	end
	root.DescendantAdded:Connect(function(item)
		if item:IsA("BillboardGui") then
			task.defer(style, item)
		end
	end)
end

for _, name in ipairs(ROOTS) do
	task.spawn(function()
		local root = workspace:WaitForChild(name, 60)
		if root then
			watchRoot(root)
		end
	end)
end
-- roots that get rebuilt later (or show up after we start)
workspace.ChildAdded:Connect(function(child)
	if table.find(ROOTS, child.Name) then
		watchRoot(child)
	end
end)

-- fade with distance (a few times a second is plenty)
task.spawn(function()
	while true do
		task.wait(0.2)
		local eye = camera.CFrame.Position
		for gui, entry in pairs(styled) do
			local position = anchorPosition(gui)
			if position then
				local range = math.max(gui.MaxDistance, NEAR + 1)
				local f = math.clamp(((position - eye).Magnitude - NEAR) / (range - NEAR), 0, 1)
				local textT = BASE_TEXT + (FAR_TEXT - BASE_TEXT) * f
				for _, label in ipairs(entry.Labels) do
					label.TextTransparency = textT
				end
				for _, s in ipairs(entry.Strokes) do
					s.Transparency = math.clamp(0.45 + f * 0.4, 0, 1)
				end
			end
		end
	end
end)
