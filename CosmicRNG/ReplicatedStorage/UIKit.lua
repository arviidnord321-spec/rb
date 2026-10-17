-- UIKit (ModuleScript in ReplicatedStorage) - used by LocalScripts only
-- Shared look + helpers for every screen in the game: colors, fonts,
-- buttons with bounce + sound, particle bursts, confetti, toasts and
-- "only one panel open at a time".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local SoundFX = require(ReplicatedStorage:WaitForChild("SoundFX"))

local UIKit = {}

UIKit.Theme = {
	Panel = Color3.fromRGB(18, 14, 34),
	PanelLight = Color3.fromRGB(34, 28, 62),
	Accent = Color3.fromRGB(150, 110, 255),
	Accent2 = Color3.fromRGB(80, 190, 255),
	Gold = Color3.fromRGB(255, 200, 70),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(190, 180, 225),
	Good = Color3.fromRGB(90, 220, 130),
	Bad = Color3.fromRGB(240, 80, 100),
}
UIKit.TitleFont = Enum.Font.FredokaOne
UIKit.BodyFont = Enum.Font.GothamBold

local THEME = UIKit.Theme
local rand = Random.new()

---------------------------------------------------------------------
-- Building blocks
---------------------------------------------------------------------
function UIKit.new(className, props, children)
	local inst = Instance.new(className)
	local parent
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local new = UIKit.new

function UIKit.corner(radius)
	return new("UICorner", { CornerRadius = radius or UDim.new(0, 12) })
end

-- Outline around a frame/button (named "Border" so it is easy to find)
function UIKit.stroke(color, thickness, transparency)
	return new("UIStroke", {
		Name = "Border",
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Black outline around text
function UIKit.textStroke(thickness)
	return new("UIStroke", {
		Name = "TextOutline",
		Color = Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function UIKit.gradient(c1, c2, rotation)
	return new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rotation or 90 })
end

function UIKit.tween(inst, duration, props, style, direction)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end
local tween = UIKit.tween

function UIKit.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = UIKit.BodyFont,
		TextColor3 = THEME.Text,
		TextSize = 18,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return new("TextLabel", defaults)
end

-- Very dark colors are unreadable as text; this brightens them.
function UIKit.readable(color, minValue)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, math.max(v, minValue or 0.6))
end

-- Hover/press bounce + sounds for any button
function UIKit.addButtonFeel(button, noSound)
	local scale = button:FindFirstChild("FeelScale") or new("UIScale", { Name = "FeelScale", Parent = button })
	button.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.06 })
		if not noSound then
			SoundFX.Play("Hover")
		end
	end)
	button.MouseLeave:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		tween(scale, 0.06, { Scale = 0.92 })
	end)
	button.MouseButton1Up:Connect(function()
		tween(scale, 0.18, { Scale = 1.06 }, Enum.EasingStyle.Back)
	end)
	button.Activated:Connect(function()
		if not noSound then
			SoundFX.Play("Click")
		end
	end)
end

-- Shrinks UI on small screens (phones). Returns the UIScale.
function UIKit.addAutoScale(guiObject, baseHeight)
	local camera = workspace.CurrentCamera
	local scale = new("UIScale", { Name = "ScreenScale", Parent = guiObject })
	local function update()
		scale.Scale = math.clamp(camera.ViewportSize.Y / (baseHeight or 820), 0.55, 1.1)
	end
	update()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	return scale
end

-- A ScreenGui for this player
function UIKit.screen(name, displayOrder)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	return new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		Parent = playerGui,
	})
end

---------------------------------------------------------------------
-- Effects layer (bursts, confetti, toasts) on top of everything
---------------------------------------------------------------------
local fxGui
local function getFxGui()
	if not fxGui or not fxGui.Parent then
		fxGui = UIKit.screen("CosmicFX", 50)
	end
	return fxGui
end

local STAR_GLYPHS = { "✦", "✧", "★", "✶" }

-- Stars and dots flying out from a point (origin in screen scale 0-1)
function UIKit.burst(colors, count, power, origin)
	local layer = getFxGui()
	origin = origin or Vector2.new(0.5, 0.4)
	power = power or 1
	for _ = 1, count do
		local angle = rand:NextNumber(0, math.pi * 2)
		local dist = rand:NextNumber(120, 380) * power
		local color = colors[rand:NextInteger(1, #colors)]
		local startPos = UDim2.fromScale(origin.X, origin.Y)
		local endPos = UDim2.new(origin.X, math.cos(angle) * dist, origin.Y, math.sin(angle) * dist)
		local duration = rand:NextNumber(0.6, 1.2)
		local piece
		if rand:NextNumber() < 0.5 then
			local size = rand:NextInteger(6, 14)
			piece = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = startPos, Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = color, BorderSizePixel = 0, Parent = layer,
			}, { UIKit.corner(UDim.new(1, 0)) })
			tween(piece, duration, { Position = endPos, Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, Enum.EasingStyle.Quart)
		else
			piece = UIKit.label({
				AnchorPoint = Vector2.new(0.5, 0.5), Position = startPos, Size = UDim2.fromOffset(40, 40),
				Text = STAR_GLYPHS[rand:NextInteger(1, #STAR_GLYPHS)], TextColor3 = color,
				TextSize = rand:NextInteger(18, 36), Font = Enum.Font.GothamBlack,
				Rotation = rand:NextNumber(0, 360), Parent = layer,
			})
			tween(piece, duration, {
				Position = endPos, TextTransparency = 1, Rotation = piece.Rotation + rand:NextNumber(-270, 270),
			}, Enum.EasingStyle.Quart)
		end
		Debris:AddItem(piece, duration + 0.1)
	end
end

-- Confetti raining from the top of the screen
function UIKit.confetti(colors, count)
	local layer = getFxGui()
	for _ = 1, count or 60 do
		local x = rand:NextNumber(0, 1)
		local w, h = rand:NextInteger(6, 12), rand:NextInteger(10, 18)
		local piece = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, 0, 0, -20),
			Size = UDim2.fromOffset(w, h),
			Rotation = rand:NextNumber(0, 360),
			BackgroundColor3 = colors[rand:NextInteger(1, #colors)],
			BorderSizePixel = 0,
			Parent = layer,
		}, { UIKit.corner(UDim.new(0, 2)) })
		local duration = rand:NextNumber(1.6, 2.8)
		task.delay(rand:NextNumber(0, 0.5), function()
			tween(piece, duration, {
				Position = UDim2.new(x + rand:NextNumber(-0.15, 0.15), 0, 1, 40),
				Rotation = piece.Rotation + rand:NextNumber(-540, 540),
			}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		end)
		Debris:AddItem(piece, duration + 0.7)
	end
end

-- Little message that slides up near the bottom of the screen
local toastLabel, toastStroke, toastToken = nil, nil, 0
function UIKit.toast(text, color)
	local layer = getFxGui()
	if not toastLabel or toastLabel.Parent ~= layer then
		toastLabel = UIKit.label({
			Name = "Toast",
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -175), Size = UDim2.fromOffset(700, 34),
			Text = "", Font = UIKit.TitleFont, TextSize = 24, TextTransparency = 1, Parent = layer,
		})
		toastStroke = UIKit.textStroke(2)
		toastStroke.Transparency = 1
		toastStroke.Parent = toastLabel
	end
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.TextColor3 = color or THEME.Text
	toastLabel.Position = UDim2.new(0.5, 0, 1, -150)
	toastLabel.TextTransparency = 0
	toastStroke.Transparency = 0.3
	tween(toastLabel, 0.25, { Position = UDim2.new(0.5, 0, 1, -175) }, Enum.EasingStyle.Back)
	task.delay(2.5, function()
		if token == toastToken then
			tween(toastLabel, 0.4, { TextTransparency = 1 })
			tween(toastStroke, 0.4, { Transparency = 1 })
		end
	end)
end

---------------------------------------------------------------------
-- Panels: open one and the others close
---------------------------------------------------------------------
local panelEvent = Instance.new("BindableEvent")
UIKit.PanelOpened = panelEvent.Event -- fires with the panel's name

function UIKit.announcePanel(name)
	panelEvent:Fire(name)
end

-- Pop-in animation for a panel (needs a UIScale named "PopScale")
function UIKit.popIn(guiObject)
	local pop = guiObject:FindFirstChild("PopScale") or new("UIScale", { Name = "PopScale", Parent = guiObject })
	pop.Scale = 0.8
	tween(pop, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
	SoundFX.Play("Whoosh")
end

return UIKit
