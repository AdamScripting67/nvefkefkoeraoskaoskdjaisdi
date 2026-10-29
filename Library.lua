--[[
	LUMEN UI LIBRARY
	Dark sidebar-style UI library for Roblox (Luau)
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Library = {
	Flags = {},
	Options = {},
	Windows = {},
	ToggleKey = Enum.KeyCode.RightShift,
	_conns = {},
	_keybinds = {},
}

----------------------------------------------------------------------
-- THEME
----------------------------------------------------------------------
local Theme = {
	Background = Color3.fromRGB(12, 12, 14),
	Panel = Color3.fromRGB(8, 8, 10),
	TopBar = Color3.fromRGB(9, 9, 11),
	Card = Color3.fromRGB(10, 10, 12),
	Stroke = Color3.fromRGB(27, 27, 31),
	Divider = Color3.fromRGB(21, 21, 25),
	Element = Color3.fromRGB(18, 18, 22),
	ElementHover = Color3.fromRGB(24, 24, 29),
	ElementStroke = Color3.fromRGB(36, 36, 42),
	Accent = Color3.fromRGB(255, 255, 255),
	OnAccent = Color3.fromRGB(10, 10, 10),
	Text = Color3.fromRGB(236, 236, 240),
	SubText = Color3.fromRGB(104, 106, 116),
	Dim = Color3.fromRGB(70, 72, 80),
	Red = Color3.fromRGB(255, 75, 75),
}
Library.Theme = Theme

local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------
local Defaults = {
	Frame = { BorderSizePixel = 0 },
	ImageLabel = { BackgroundTransparency = 1, BorderSizePixel = 0 },
	TextLabel = {
		BackgroundTransparency = 1, BorderSizePixel = 0, Font = FONT, TextSize = 11,
		TextColor3 = Theme.Text, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
	},
	TextButton = {
		BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Font = FONT,
		TextSize = 11, TextColor3 = Theme.Text, Text = "",
	},
	TextBox = {
		BackgroundTransparency = 1, BorderSizePixel = 0, Font = FONT, TextSize = 11,
		TextColor3 = Theme.Text, Text = "", ClearTextOnFocus = false,
		PlaceholderColor3 = Theme.SubText,
	},
	ScrollingFrame = {
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
		ScrollBarImageColor3 = Theme.Dim, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarImageTransparency = 0.3,
	},
	UIListLayout = { SortOrder = Enum.SortOrder.LayoutOrder },
}

local function New(class, props, children)
	local inst = Instance.new(class)
	local d = Defaults[class]
	if d then
		for k, v in pairs(d) do inst[k] = v end
	end
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	if parent then inst.Parent = parent end
	return inst
end

local function Corner(inst, r)
	return New("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = inst })
end

local function Stroke(inst, color, thickness, transparency)
	return New("UIStroke", {
		Color = color or Theme.Stroke, Thickness = thickness or 1, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = inst,
	})
end

local function Pad(inst, l, t, r, b)
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0), Parent = inst,
	})
end

local function Tween(obj, props, time, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function Connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(Library._conns, c)
	return c
end

local function Clamp(v, a, b) return math.max(a, math.min(b, v)) end

local function Round(v, inc)
	if not inc or inc <= 0 then return v end
	return math.floor(v / inc + 0.5) * inc
end

local function DecimalsOf(n)
	local s = tostring(n)
	local dot = s:find("%.")
	return dot and (#s - dot) or 0
end

local function InputPos(input)
	return Vector2.new(input.Position.X, input.Position.Y)
end

local function IsPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function ProtectedParent()
	if typeof(gethui) == "function" then
		local ok, h = pcall(gethui)
		if ok and h then return h end
	end
	local ok = pcall(function()
		local t = Instance.new("ScreenGui")
		t.Parent = game:GetService("CoreGui")
		t:Destroy()
	end)
	if ok then return game:GetService("CoreGui") end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local activeDrag
Connect(UIS.InputChanged, function(input)
	if activeDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		activeDrag(InputPos(input))
	end
end)
Connect(UIS.InputEnded, function(input)
	if IsPress(input) and activeDrag then
		local fin = activeDrag
		activeDrag = nil
		if type(fin) == "table" then fin.done() end
	end
end)

local function BeginDrag(input, fn, onDone)
	activeDrag = fn
	if onDone then
		activeDrag = setmetatable({ done = onDone }, { __call = function(_, p) fn(p) end })
	end
	fn(InputPos(input))
end

local function MakeIcon(parent, icon, size, color)
	local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size + 2, size + 2), Parent = parent })
	local obj
	if type(icon) == "number" or (type(icon) == "string" and icon:match("^rbxasset")) then
		obj = New("ImageLabel", {
			Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), ImageColor3 = color,
			Image = type(icon) == "number" and ("rbxassetid://" .. icon) or icon, Parent = holder,
		})
	else
		obj = New("TextLabel", {
			Size = UDim2.fromScale(1, 1), Text = tostring(icon or "•"), TextSize = size, Font = FONT_BOLD,
			TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center, Parent = holder,
		})
	end
	return holder, obj
end

local function SetIconColor(obj, color, t)
	Tween(obj, { [obj:IsA("ImageLabel") and "ImageColor3" or "TextColor3"] = color }, t or 0.15)
end

local function MakeChevron(parent, color)
	local c = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(8, 5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = parent,
	})
	local a = New("Frame", {
		BackgroundColor3 = color, Size = UDim2.fromOffset(5, 1), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(2.2, 2.4), Rotation = 40, Parent = c,
	})
	local b = New("Frame", {
		BackgroundColor3 = color, Size = UDim2.fromOffset(5, 1), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(5.8, 2.4), Rotation = -40, Parent = c,
	})
	return c, { a, b }
end

local function MakeCheck(parent)
	local c = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Parent = parent,
	})
	New("Frame", {
		BackgroundColor3 = Theme.OnAccent, Size = UDim2.fromOffset(2, 3), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(2.3, 4.7), Rotation = -45, Parent = c,
	})
	New("Frame", {
		BackgroundColor3 = Theme.OnAccent, Size = UDim2.fromOffset(2, 6), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(5, 3.6), Rotation = 45, Parent = c,
	})
	local scale = New("UIScale", { Scale = 0, Parent = c })
	return c, scale
end

local function MakeSearchIcon(parent)
	local c = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(10, 10), Parent = parent })
	local ring = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(0, 0), Parent = c })
	Corner(ring, 6)
	Stroke(ring, Theme.SubText, 1.3)
	New("Frame", {
		BackgroundColor3 = Theme.SubText, Size = UDim2.fromOffset(1.4, 3), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(7.5, 7.5), Rotation = -45, Parent = c,
	})
	return c
end

local function MakeKeyboardIcon(parent)
	local c = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(10, 6), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Parent = parent,
	})
	Corner(c, 2)
	Stroke(c, Theme.SubText, 1)
	New("Frame", {
		BackgroundColor3 = Theme.SubText, Size = UDim2.fromOffset(5, 1), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -2), Parent = c,
	})
	New("Frame", {
		BackgroundColor3 = Theme.SubText, Size = UDim2.fromOffset(6, 1), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 2), Parent = c,
	})
	return c
end

----------------------------------------------------------------------
-- CLASSES
----------------------------------------------------------------------
local Window = {}
Window.__index = Window
local Category = {}
Category.__index = Category
local Tab = {}
Tab.__index = Tab
local Section = {}
Section.__index = Section

local function Register(flag, obj, value)
	if not flag then return end
	obj.Flag = flag
	Library.Flags[flag] = value
	Library.Options[flag] = obj
end

----------------------------------------------------------------------
-- NOTIFICATIONS
----------------------------------------------------------------------
local notifyGui, notifyHolder
function Library:Notify(o)
	o = o or {}
	if not notifyGui then
		notifyGui = New("ScreenGui", { Name = "LumenNotify", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 200, Parent = ProtectedParent() })
		notifyHolder = New("Frame", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16),
			Size = UDim2.fromOffset(200, 400), Parent = notifyGui,
		})
		New("UIListLayout", {
			Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = notifyHolder,
		})
	end
	local slot = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(200, 0), Parent = notifyHolder })
	local card = New("Frame", { -- Changed from CanvasGroup to Frame to fix blur
		BackgroundColor3 = Theme.Background, Size = UDim2.fromOffset(200, 48), Position = UDim2.fromOffset(220, 0),
		BackgroundTransparency = 1, Parent = slot,
	})
	Corner(card, 6)
	local cardStroke = Stroke(card, Theme.Stroke, 1, 1)
	local bar = New("Frame", { BackgroundColor3 = Theme.Accent, Size = UDim2.new(0, 2, 1, -12), Position = UDim2.fromOffset(8, 6), Parent = card, BackgroundTransparency = 1 })
	Corner(bar, 2)
	New("TextLabel", {
		Text = o.Title or "Notification", Font = FONT_BOLD, TextSize = 11, Position = UDim2.fromOffset(16, 6),
		Size = UDim2.new(1, -22, 0, 14), BackgroundTransparency = 1, Parent = card,
	})
	New("TextLabel", {
		Text = o.Content or "", TextColor3 = Theme.SubText, TextSize = 10, Position = UDim2.fromOffset(16, 20),
		Size = UDim2.new(1, -22, 0, 22), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, BackgroundTransparency = 1, Parent = card,
	})
	
	Tween(slot, { Size = UDim2.fromOffset(200, 48) }, 0.25)
	Tween(card, { Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 0 }, 0.3, Enum.EasingStyle.Quint)
	Tween(cardStroke, { Transparency = 0 }, 0.3)
	Tween(bar, { BackgroundTransparency = 0 }, 0.3)

	task.delay(o.Duration or 4, function()
		Tween(card, { Position = UDim2.fromOffset(220, 0), BackgroundTransparency = 1 }, 0.3, Enum.EasingStyle.Quint)
		Tween(cardStroke, { Transparency = 1 }, 0.3)
		Tween(bar, { BackgroundTransparency = 1 }, 0.3)
		task.wait(0.25)
		Tween(slot, { Size = UDim2.fromOffset(200, 0) }, 0.2)
		task.wait(0.25)
		slot:Destroy()
	end)
end

----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------
function Library:GetConfig()
	local out = {}
	for flag, opt in pairs(self.Options) do
		local t = opt.Type
		if t == "ColorPicker" then
			out[flag] = "#" .. opt.Value:ToHex()
		elseif t == "Keybind" then
			out[flag] = opt.Key and opt.Key.Name or ""
		elseif t == "Dropdown" or t == "Toggle" or t == "Slider" or t == "Textbox" then
			out[flag] = opt.Value
		end
	end
	return out
end

function Library:SetConfig(cfg)
	for flag, v in pairs(cfg) do
		local opt = self.Options[flag]
		if opt then
			pcall(function()
				if opt.Type == "ColorPicker" then
					opt:Set(Color3.fromHex(v))
				elseif opt.Type == "Keybind" then
					opt:Set(v ~= "" and (Enum.KeyCode[v] or Enum.UserInputType[v]) or nil)
				else
					opt:Set(v)
				end
			end)
		end
	end
end

function Library:SaveConfig(name)
	if typeof(writefile) ~= "function" then return false end
	pcall(function() if not isfolder("Lumen") then makefolder("Lumen") end end)
	writefile("Lumen/" .. name .. ".json", HttpService:JSONEncode(self:GetConfig()))
	return true
end

function Library:LoadConfig(name)
	if typeof(readfile) ~= "function" then return false end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile("Lumen/" .. name .. ".json")) end)
	if ok then self:SetConfig(data) end
	return ok
end

function Library:Unload()
	activeDrag = nil
	for _, w in ipairs(self.Windows) do
		if w.Gui then w.Gui:Destroy() end
	end
	if notifyGui then notifyGui:Destroy() end
	for _, c in ipairs(self._conns) do c:Disconnect() end
	table.clear(self._conns)
	table.clear(self.Windows)
	table.clear(self._keybinds)
end

Connect(UIS.InputBegan, function(input, gp)
	if gp then return end
	for _, kb in ipairs(Library._keybinds) do
		if not kb.Listening and kb.Key and (input.KeyCode == kb.Key or input.UserInputType == kb.Key) then
			kb.Handler(true)
		end
	end
end)
Connect(UIS.InputEnded, function(input)
	for _, kb in ipairs(Library._keybinds) do
		if kb.Key and (input.KeyCode == kb.Key or input.UserInputType == kb.Key) then
			kb.Handler(false)
		end
	end
end)

----------------------------------------------------------------------
-- WINDOW
----------------------------------------------------------------------
function Library:CreateWindow(o)
	o = o or {}
	if o.Accent then Theme.Accent = o.Accent end
	if o.ToggleKey then Library.ToggleKey = o.ToggleKey end

	local self = setmetatable({
		Categories = {}, Searchables = {}, Visible = true, Popup = nil,
		MinSize = o.MinSize or Vector2.new(400, 300), MaxSize = o.MaxSize or Vector2.new(1100, 800),
	}, Window)
	table.insert(Library.Windows, self)

	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local size = o.Size or Vector2.new(520, 380) -- More compact default size
	size = Vector2.new(math.min(size.X, vp.X - 20), math.min(size.Y, vp.Y - 20))

	local gui = New("ScreenGui", {
		Name = "LumenUI", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100,
	})
	gui.Parent = ProtectedParent()
	self.Gui = gui

	local main = New("Frame", { -- Changed from CanvasGroup to Frame to eliminate ALL blurriness
		Name = "Main", BackgroundColor3 = Theme.Background, BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(math.floor((vp.X - size.X) / 2), math.floor((vp.Y - size.Y) / 2)),
		AnchorPoint = Vector2.new(0, 0), Parent = gui,
	})
	Corner(main, 6)
	local mainStroke = Stroke(main, Theme.Stroke, 1, 1)
	local mainScale = New("UIScale", { Scale = 0.92, Parent = main })
	self.Main, self.Scale = main, mainScale

	local overlay = New("Frame", { Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = gui })
	local catcher = New("TextButton", { Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 50, Parent = overlay })
	self.Overlay, self.Catcher = overlay, catcher
	catcher.MouseButton1Down:Connect(function() self:ClosePopups() end)

	-- Compact Layout frames
	local rail = New("Frame", { Name = "Rail", BackgroundColor3 = Theme.Panel, Size = UDim2.new(0, 48, 1, 0), Parent = main })
	Corner(rail, 6)
	New("Frame", { BackgroundColor3 = Theme.Panel, Size = UDim2.new(0, 6, 1, 0), Position = UDim2.new(1, -6, 0, 0), Parent = rail })
	New("Frame", { BackgroundColor3 = Theme.Stroke, Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), Parent = rail })

	local topbar = New("Frame", { Name = "TopBar", BackgroundColor3 = Theme.TopBar, Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -48, 0, 44), Parent = main })

	local tabList = New("Frame", { Name = "TabList", BackgroundColor3 = Theme.Panel, Position = UDim2.fromOffset(48, 44), Size = UDim2.new(0, 120, 1, -44), Parent = main })
	New("Frame", { BackgroundColor3 = Theme.Divider, Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), Parent = tabList })
	New("Frame", { BackgroundColor3 = Theme.Divider, Size = UDim2.new(1, 0, 0, 1), Parent = tabList })

	local content = New("Frame", { Name = "Content", BackgroundColor3 = Theme.Background, ClipsDescendants = true, Position = UDim2.fromOffset(168, 44), Size = UDim2.new(1, -168, 1, -44), Parent = main })
	New("Frame", { BackgroundColor3 = Theme.Divider, Size = UDim2.new(1, 0, 0, 1), Parent = content })

	self.Rail, self.TabListFrame, self.Content = rail, tabList, content

	-- Logo
	local logoHolder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(48, 44), Parent = rail })
	if o.LogoImage then
		New("ImageLabel", {
			Image = o.LogoImage, Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(24, 24), Parent = logoHolder,
		})
	else
		New("TextLabel", {
			Text = o.Logo or "LU", Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = Theme.Accent,
			TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 1),
			Rotation = -4, Parent = logoHolder,
		})
	end

	-- Rail list + active indicator
	local railList = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 1, -120), Parent = rail })
	New("UIListLayout", { Parent = railList })
	local indicator = New("Frame", {
		BackgroundColor3 = Theme.Accent, Size = UDim2.fromOffset(3, 14), Position = UDim2.fromOffset(0, 69),
		Visible = false, Parent = rail,
	})
	Corner(indicator, 2)
	self.RailList, self.Indicator = railList, indicator

	-- Search
	local searchBox = New("Frame", { BackgroundColor3 = Theme.Element, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(120, 28), Parent = topbar })
	Corner(searchBox, 6)
	local searchStroke = Stroke(searchBox, Theme.ElementStroke, 1, 1)
	local sIcon = MakeSearchIcon(searchBox)
	sIcon.Position = UDim2.fromOffset(10, 9)
	local search = New("TextBox", {
		PlaceholderText = "Search...", Text = "", TextSize = 10, Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -32, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true, Parent = searchBox,
	})
	search.Focused:Connect(function() Tween(searchStroke, { Transparency = 0 }, 0.15) end)
	search.FocusLost:Connect(function() Tween(searchStroke, { Transparency = 1 }, 0.15) end)
	search:GetPropertyChangedSignal("Text"):Connect(function() self:_applySearch() end)
	self.SearchBox = search

	-- Profile card
	local user = o.User or {}
	local card = New("Frame", {
		Name = "Profile", BackgroundColor3 = Theme.Element, AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 6, 1, -6), Size = UDim2.fromOffset(156, 34), ZIndex = 5, Parent = main,
	})
	Corner(card, 6)
	Stroke(card, Theme.Stroke)
	local avatar = New("ImageLabel", { BackgroundColor3 = Theme.ElementHover, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(22, 22), ZIndex = 6, Parent = card })
	Corner(avatar, 11)
	task.spawn(function()
		local id = user.UserId or LocalPlayer.UserId
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		if ok and img then avatar.Image = img end
	end)
	New("TextLabel", { Text = user.Name or LocalPlayer.DisplayName, Font = FONT_BOLD, TextSize = 10, Position = UDim2.fromOffset(34, 5), Size = UDim2.new(1, -66, 0, 12), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6, Parent = card })
	New("TextLabel", { Text = user.Subtitle or "Lifetime", TextSize = 9, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(34, 16), Size = UDim2.new(1, -66, 0, 11), ZIndex = 6, Parent = card })
	
	local gear = New("TextButton", { Text = "⚙", TextSize = 12, TextColor3 = Theme.SubText, Position = UDim2.new(1, -24, 0, 0), Size = UDim2.fromOffset(24, 34), ZIndex = 7, Parent = card })
	gear.MouseEnter:Connect(function() if not self.SettingsOpen then Tween(gear, { TextColor3 = Theme.Text, Rotation = 45 }, 0.2) end end)
	gear.MouseLeave:Connect(function() if not self.SettingsOpen then Tween(gear, { TextColor3 = Theme.SubText, Rotation = 0 }, 0.2) end end)

	-- Sleek Settings Menu (Popup)
	local settingsFrame = New("Frame", {
		Name = "SettingsMenu", BackgroundColor3 = Theme.Panel, BackgroundTransparency = 1,
		Size = UDim2.fromOffset(156, 84), Visible = false, ZIndex = 10, Parent = main,
		Position = UDim2.new(0, 6, 1, -46), AnchorPoint = Vector2.new(0, 1)
	})
	Corner(settingsFrame, 6)
	local sStroke = Stroke(settingsFrame, Theme.Stroke, 1, 1)

	-- Settings Title
	New("TextLabel", { Text = "OPTIONS", Font = FONT_BOLD, TextSize = 9, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 12), BackgroundTransparency = 1, Parent = settingsFrame })
	
	-- Keybind Button
	local keyBtn = New("TextButton", { BackgroundColor3 = Theme.Element, Position = UDim2.fromOffset(8, 20), Size = UDim2.new(1, -16, 0, 24), Text = "", Parent = settingsFrame, BackgroundTransparency = 1 })
	Corner(keyBtn, 4)
	local keyStroke = Stroke(keyBtn, Theme.ElementStroke, 1, 1)
	New("TextLabel", { Text = "Toggle Menu", TextSize = 10, TextColor3 = Theme.Text, Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -30, 1, 0), BackgroundTransparency = 1, Parent = keyBtn })
	local keyText = New("TextLabel", { Text = tostring(Library.ToggleKey.Name):upper(), TextSize = 9, TextColor3 = Theme.Accent, Font = FONT_BOLD, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, -8, 1, 0), BackgroundTransparency = 1, Parent = keyBtn })
	
	-- Unload Button
	local unloadBtn = New("TextButton", { BackgroundColor3 = Theme.Element, Position = UDim2.fromOffset(8, 48), Size = UDim2.new(1, -16, 0, 24), Text = "Unload UI", TextSize = 10, TextColor3 = Theme.Red, Font = FONT_BOLD, Parent = settingsFrame, BackgroundTransparency = 1 })
	Corner(unloadBtn, 4)
	local unloadStroke = Stroke(unloadBtn, Theme.ElementStroke, 1, 1)
	
	local listeningKey = false
	keyBtn.MouseButton1Click:Connect(function()
		if listeningKey then return end
		listeningKey = true
		keyText.Text = "..."
		local conn
		conn = UIS.InputBegan:Connect(function(input, gp)
			if gp then return end
			if input.UserInputType == Enum.UserInputType.Keyboard then
				Library.ToggleKey = input.KeyCode
				keyText.Text = tostring(input.KeyCode.Name):upper()
				listeningKey = false
				conn:Disconnect()
				if o.OnSettings then task.spawn(o.OnSettings) end
			end
		end)
	end)
	
	unloadBtn.MouseEnter:Connect(function() Tween(unloadBtn, { BackgroundColor3 = Theme.Red }, 0.15); Tween(unloadBtn, { TextColor3 = Theme.OnAccent }, 0.15) end)
	unloadBtn.MouseLeave:Connect(function() Tween(unloadBtn, { BackgroundColor3 = Theme.Element }, 0.15); Tween(unloadBtn, { TextColor3 = Theme.Red }, 0.15) end)
	unloadBtn.MouseButton1Click:Connect(function() Library:Unload() end)

	self.SettingsOpen = false
	local function toggleSettings()
		self.SettingsOpen = not self.SettingsOpen
		if self.SettingsOpen then
			settingsFrame.Visible = true
			settingsFrame.BackgroundTransparency = 1
			settingsFrame.Position = UDim2.new(0, 6, 1, -50) -- start slightly lower
			sStroke.Transparency = 1
			keyBtn.BackgroundTransparency = 1
			keyStroke.Transparency = 1
			unloadBtn.BackgroundTransparency = 1
			unloadStroke.Transparency = 1
			
			Tween(settingsFrame, { BackgroundTransparency = 0, Position = UDim2.new(0, 6, 1, -46) }, 0.25, Enum.EasingStyle.Quint)
			Tween(sStroke, { Transparency = 0 }, 0.25)
			Tween(keyBtn, { BackgroundTransparency = 0 }, 0.25)
			Tween(keyStroke, { Transparency = 0 }, 0.25)
			Tween(unloadBtn, { BackgroundTransparency = 0 }, 0.25)
			Tween(unloadStroke, { Transparency = 0 }, 0.25)
			Tween(gear, { TextColor3 = Theme.Accent, Rotation = 45 }, 0.2)
		else
			Tween(settingsFrame, { BackgroundTransparency = 1, Position = UDim2.new(0, 6, 1, -50) }, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Tween(sStroke, { Transparency = 1 }, 0.2)
			Tween(keyBtn, { BackgroundTransparency = 1 }, 0.2)
			Tween(keyStroke, { Transparency = 1 }, 0.2)
			Tween(unloadBtn, { BackgroundTransparency = 1 }, 0.2)
			Tween(unloadStroke, { Transparency = 1 }, 0.2)
			Tween(gear, { TextColor3 = Theme.SubText, Rotation = 0 }, 0.2)
			task.delay(0.2, function() if not self.SettingsOpen then settingsFrame.Visible = false end end)
			if o.OnSettings then task.spawn(o.OnSettings) end
		end
	end
	gear.MouseButton1Click:Connect(toggleSettings)

	-- Dragging
	for _, inst in ipairs({ main, rail, topbar, tabList, content, logoHolder, card, railList }) do
		self:_makeDraggable(inst)
	end

	-- Resize handles
	local E, C = 5, 14
	local function handle(dx, dy, pos, sz)
		local h = New("TextButton", { Name = "Resize", Position = pos, Size = sz, ZIndex = 40, Parent = main })
		h.InputBegan:Connect(function(input)
			if not IsPress(input) then return end
			self:ClosePopups()
			local start = InputPos(input)
			local sx, sy = main.AbsolutePosition.X, main.AbsolutePosition.Y
			local sw, sh = main.AbsoluteSize.X / mainScale.Scale, main.AbsoluteSize.Y / mainScale.Scale
			BeginDrag(input, function(p)
				local d = p - start
				local w, hgt, x, y = sw, sh, sx, sy
				if dx == 1 then
					w = Clamp(sw + d.X, self.MinSize.X, self.MaxSize.X)
				elseif dx == -1 then
					w = Clamp(sw - d.X, self.MinSize.X, self.MaxSize.X)
					x = sx + (sw - w)
				end
				if dy == 1 then
					hgt = Clamp(sh + d.Y, self.MinSize.Y, self.MaxSize.Y)
				elseif dy == -1 then
					hgt = Clamp(sh - d.Y, self.MinSize.Y, self.MaxSize.Y)
					y = sy + (sh - hgt)
				end
				main.Size = UDim2.fromOffset(w, hgt)
				main.Position = UDim2.fromOffset(x, y)
			end)
		end)
		return h
	end
	handle(1, 0, UDim2.new(1, -E, 0, C), UDim2.new(0, E, 1, -C * 2))
	handle(-1, 0, UDim2.new(0, 0, 0, C), UDim2.new(0, E, 1, -C * 2))
	handle(0, 1, UDim2.new(0, C, 1, -E), UDim2.new(1, -C * 2, 0, E))
	handle(0, -1, UDim2.new(0, C, 0, 0), UDim2.new(1, -C * 2, 0, E))
	handle(1, 1, UDim2.new(1, -C, 1, -C), UDim2.fromOffset(C, C))
	handle(-1, 1, UDim2.new(0, 0, 1, -C), UDim2.fromOffset(C, C))
	handle(1, -1, UDim2.new(1, -C, 0, 0), UDim2.fromOffset(C, C))
	handle(-1, -1, UDim2.new(0, 0, 0, 0), UDim2.fromOffset(C, C))

	Connect(UIS.InputBegan, function(input, gp)
		if not gp and input.KeyCode == Library.ToggleKey then self:SetVisible(not self.Visible) end
	end)

	-- Intro animation (Using Frame properties to avoid blur)
	task.defer(function()
		Tween(main, { BackgroundTransparency = 0 }, 0.35)
		Tween(mainStroke, { Transparency = 0 }, 0.35)
		Tween(mainScale, { Scale = 1 }, 0.45, Enum.EasingStyle.Back)
	end)

	return self
end

function Window:_makeDraggable(inst)
	inst.InputBegan:Connect(function(input)
		if IsPress(input) and not activeDrag then
			self:ClosePopups()
			local start = InputPos(input)
			local origin = self.Main.AbsolutePosition
			local vp = workspace.CurrentCamera.ViewportSize
			BeginDrag(input, function(p)
				local d = p - start
				local sz = self.Main.AbsoluteSize
				local x = Clamp(origin.X + d.X, -sz.X + 80, vp.X - 80)
				local y = Clamp(origin.Y + d.Y, 0, vp.Y - 40)
				self.Main.Position = UDim2.fromOffset(x, y)
			end)
		end
	end)
end

function Window:SetVisible(v)
	self.Visible = v
	if v then
		self.Main.Visible = true
		self.Main.BackgroundTransparency = 1
		Tween(self.Main, { BackgroundTransparency = 0 }, 0.25)
		Tween(self.Scale, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)
	else
		self:ClosePopups()
		Tween(self.Main, { BackgroundTransparency = 1 }, 0.2)
		Tween(self.Scale, { Scale = 0.94 }, 0.2)
		task.delay(0.2, function() if not self.Visible then self.Main.Visible = false end end)
	end
end

function Window:Destroy()
	self.Gui:Destroy()
end

function Window:_applySearch()
	local q = self.SearchBox.Text:lower()
	for _, s in ipairs(self.Searchables) do
		s.Row.Visible = (q == "" or s.Name:lower():find(q, 1, true) ~= nil)
	end
end

function Window:ClosePopups()
	if self.Popup and self.Popup.Close then self.Popup.Close() end
end

----------------------------------------------------------------------
-- CATEGORIES / TABS
----------------------------------------------------------------------
function Window:AddCategory(o)
	o = o or {}
	local cat = setmetatable({ Window = self, Name = o.Name or "Options", Tabs = {}, Index = #self.Categories + 1 }, Category)
	table.insert(self.Categories, cat)

	local btn = New("TextButton", { Size = UDim2.new(1, 0, 0, 30), Parent = self.RailList })
	local holder, icon = MakeIcon(btn, o.Icon or "●", 13, Theme.SubText)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	cat.Button, cat.Icon = btn, icon

	btn.MouseEnter:Connect(function()
		if self.ActiveCategory ~= cat then SetIconColor(icon, Theme.Text) end
	end)
	btn.MouseLeave:Connect(function()
		if self.ActiveCategory ~= cat then SetIconColor(icon, Theme.SubText) end
	end)
	btn.MouseButton1Click:Connect(function() self:SelectCategory(cat) end)

	local h = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = self.TabListFrame })
	local label = New("TextLabel", { Text = cat.Name, TextSize = 10, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(9, 12), Size = UDim2.new(1, -18, 0, 12), Parent = h })
	local list = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 24), Size = UDim2.new(1, -12, 1, -80), Parent = h })
	New("UIListLayout", { Padding = UDim.new(0, 3), Parent = list })
	cat.Holder, cat.List = h, list

	if not self.ActiveCategory then self:SelectCategory(cat) end
	return cat
end

function Window:SelectCategory(cat)
	if self.ActiveCategory == cat then return end
	local old = self.ActiveCategory
	self.ActiveCategory = cat
	for _, c in ipairs(self.Categories) do
		c.Holder.Visible = (c == cat)
		SetIconColor(c.Icon, c == cat and Theme.Accent or Theme.SubText)
	end
	self.Indicator.Visible = true
	local y = 60 + (cat.Index - 1) * 30 + 8
	if old then
		Tween(self.Indicator, { Position = UDim2.fromOffset(0, y) }, 0.3, Enum.EasingStyle.Quint)
	else
		self.Indicator.Position = UDim2.fromOffset(0, y)
	end
	local t = cat.ActiveTab or cat.Tabs[1]
	if t then 
		self:SelectTab(t, true) 
	else
		if self.ActiveTab then
			local oldTab = self.ActiveTab
			self.ActiveTab = nil
			StyleTab(oldTab, false)
			if oldTab.Page then
				oldTab.Page.Visible = false
			end
		end
	end
end

function Category:AddTab(o)
	o = o or {}
	local win = self.Window
	local tab = setmetatable({ Window = win, Category = self, Name = o.Name or "Tab" }, Tab)
	table.insert(self.Tabs, tab)

	local btn = New("TextButton", { BackgroundColor3 = Theme.Element, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = #self.Tabs, Parent = self.List })
	Corner(btn, 5)
	local stroke = Stroke(btn, Theme.ElementStroke, 1, 1)
	local holder, icon = MakeIcon(btn, o.Icon or "•", 12, Theme.SubText)
	holder.Position = UDim2.fromOffset(7, 7)
	local label = New("TextLabel", { Text = tab.Name, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -30, 1, 0), Parent = btn })
	tab.Button, tab.Icon, tab.Label, tab.BtnStroke = btn, icon, label, stroke

	btn.MouseEnter:Connect(function()
		if win.ActiveTab ~= tab then
			Tween(btn, { BackgroundTransparency = 0.6 }, 0.15)
			Tween(label, { TextColor3 = Theme.Text }, 0.15)
		end
	end)
	btn.MouseLeave:Connect(function()
		if win.ActiveTab ~= tab then
			Tween(btn, { BackgroundTransparency = 1 }, 0.15)
			Tween(label, { TextColor3 = Theme.SubText }, 0.15)
		end
	end)
	btn.MouseButton1Click:Connect(function() win:SelectTab(tab) end)

	local page = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = win.Content })
	local cols = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 10), Size = UDim2.new(1, -19, 1, -24), Parent = page })
	tab.Page = page

	local function makeColumn(pos)
		local f = New("ScrollingFrame", { Position = pos, Size = UDim2.new(0.5, -4, 1, 0), Parent = cols })
		New("UIListLayout", { Padding = UDim.new(0, 8), Parent = f })
		return { Frame = f, Sections = {} }
	end
	tab.Left = makeColumn(UDim2.fromOffset(0, 0))
	tab.Right = makeColumn(UDim2.new(0.5, 4, 0, 0))

	if win.ActiveCategory == self and not self.ActiveTab then win:SelectTab(tab, true) end
	return tab
end

local function StyleTab(tab, active)
	Tween(tab.Button, { BackgroundTransparency = active and 0 or 1 }, 0.2)
	Tween(tab.BtnStroke, { Transparency = active and 0 or 1 }, 0.2)
	Tween(tab.Label, { TextColor3 = active and Theme.Text or Theme.SubText }, 0.2)
	SetIconColor(tab.Icon, active and Theme.Accent or Theme.SubText, 0.2)
end

function Window:SelectTab(tab, instant)
	if self.ActiveCategory ~= tab.Category then
		tab.Category.ActiveTab = tab
		self:SelectCategory(tab.Category)
		return
	end
	local old = self.ActiveTab
	if old == tab then return end
	self.ActiveTab = tab
	tab.Category.ActiveTab = tab

	if old then
		StyleTab(old, false)
		if old.Page then
			old.Page.Visible = false
		end
	end
	StyleTab(tab, true)
	local p = tab.Page
	p.Visible = true
	
	task.defer(function()
		for _, col in ipairs({ tab.Left, tab.Right }) do
			if col.Relayout then col.Relayout() end
		end
	end)
end

----------------------------------------------------------------------
-- SECTIONS
----------------------------------------------------------------------
function Tab:AddSection(o)
	o = o or {}
	local win = self.Window
	local col = (o.Side == "Right") and self.Right or self.Left
	local sec = setmetatable({ Tab = self, Window = win, Name = o.Name or "Section", Fill = o.Fill, _order = 0 }, Section)

	local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = #col.Sections + 1, Parent = col.Frame })
	New("TextLabel", { Text = sec.Name, TextSize = 9, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(2, 0), Size = UDim2.new(1, -4, 0, 12), Parent = holder })
	local box = New("Frame", {
		BackgroundColor3 = Theme.Card, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, Parent = holder,
	})
	Corner(box, 5)
	Stroke(box, Theme.Stroke)
	New("UIListLayout", { Parent = box })
	local constraint = New("UISizeConstraint", { MinSize = Vector2.new(0, 0), Parent = box })

	sec.Holder, sec.Box, sec.Constraint = holder, box, constraint
	table.insert(col.Sections, sec)

	col.Relayout = function()
		local fill
		local used, n = 0, #col.Sections
		for _, s in ipairs(col.Sections) do
			if s.Fill then fill = s else used = used + s.Holder.AbsoluteSize.Y end
		end
		if fill then
			local avail = col.Frame.AbsoluteSize.Y - used - (n - 1) * 8 - 14
			avail = math.max(0, math.floor(avail))
			if math.abs(fill.Constraint.MinSize.Y - avail) >= 1 then
				fill.Constraint.MinSize = Vector2.new(0, avail)
			end
		end
	end
	col.Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(col.Relayout)
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(col.Relayout)
	task.defer(col.Relayout)

	return sec
end

local function MakeRow(sec, height, name)
	local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height), LayoutOrder = sec._order, Parent = sec.Box })
	sec._order = sec._order + 1
	row.Name = name or "Row"
	New("Frame", { Name = "Divider", BackgroundColor3 = Theme.Divider, Position = UDim2.new(0, 6, 1, -1), Size = UDim2.new(1, -12, 0, 1), Parent = row })
	table.insert(sec.Window.Searchables, { Row = row, Name = name or "" })
	return row
end

local function Addons(row)
	local f = New("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 4, Parent = row,
	})
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f,
	})
	return f
end

----------------------------------------------------------------------
-- COLOUR PICKER
----------------------------------------------------------------------
local function BuildColorPopup(win)
	local pop = New("Frame", {
		BackgroundColor3 = Theme.Background, Size = UDim2.fromOffset(156, 144), Visible = false,
		BackgroundTransparency = 1, ZIndex = 60, Parent = win.Overlay,
	})
	Corner(pop, 6)
	local popStroke = Stroke(pop, Theme.Stroke, 1, 1)
	local scale = New("UIScale", { Scale = 0.9, Parent = pop })

	local svFrame = New("Frame", { BackgroundColor3 = Color3.new(1, 0, 0), Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(140, 88), ZIndex = 61, ClipsDescendants = true, Parent = pop })
	Corner(svFrame, 4)
	
	local white = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 62, Parent = svFrame })
	New("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1)), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = white })
	local black = New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 63, Parent = svFrame })
	New("UIGradient", { Color = ColorSequence.new(Color3.new(0, 0, 0)), Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Parent = black })
	
	local svCursor = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 64, Parent = svFrame })
	Corner(svCursor, 8)
	Stroke(svCursor, Color3.new(1, 1, 1), 2)
	local svHit = New("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 65, Parent = svFrame })

	local hue = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(8, 102), Size = UDim2.fromOffset(140, 8), ZIndex = 61, ClipsDescendants = true, Parent = pop })
	Corner(hue, 4)
	New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)), ColorSequenceKeypoint.new(0.167, Color3.fromHSV(0.167, 1, 1)),
			ColorSequenceKeypoint.new(0.333, Color3.fromHSV(0.333, 1, 1)), ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
			ColorSequenceKeypoint.new(0.667, Color3.fromHSV(0.667, 1, 1)), ColorSequenceKeypoint.new(0.833, Color3.fromHSV(0.833, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
		}), Parent = hue,
	})
	local hueCursor = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(3, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), ZIndex = 62, Parent = hue })
	Corner(hueCursor, 2)
	Stroke(hueCursor, Color3.new(0, 0, 0), 1, 0.5)
	local hueHit = New("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 63, Parent = hue })

	local hexBox = New("TextBox", {
		BackgroundColor3 = Theme.Element, Position = UDim2.fromOffset(8, 116), Size = UDim2.fromOffset(140, 20),
		Text = "#FFFFFF", TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 61, Parent = pop,
	})
	Corner(hexBox, 5)
	Stroke(hexBox, Theme.ElementStroke)

	local state = { cp = nil, h = 0, s = 1, v = 1 }
	local isDragging = false

	local function refresh()
		local c = Color3.fromHSV(state.h, state.s, state.v)
		svFrame.BackgroundColor3 = Color3.fromHSV(state.h, 1, 1)
		svCursor.Position = UDim2.fromScale(state.s, 1 - state.v)
		hueCursor.Position = UDim2.fromScale(state.h, 0.5)
		hexBox.Text = "#" .. c:ToHex():upper()
	end
	local function push()
		if state.cp then state.cp:Set(Color3.fromHSV(state.h, state.s, state.v)) end
		refresh()
	end

	svHit.InputBegan:Connect(function(input)
		if IsPress(input) then
			isDragging = true
			BeginDrag(input, function(p)
				state.s = Clamp((p.X - svFrame.AbsolutePosition.X) / svFrame.AbsoluteSize.X, 0, 1)
				state.v = 1 - Clamp((p.Y - svFrame.AbsolutePosition.Y) / svFrame.AbsoluteSize.Y, 0, 1)
				push()
			end, function() isDragging = false end)
		end
	end)
	hueHit.InputBegan:Connect(function(input)
		if IsPress(input) then
			isDragging = true
			BeginDrag(input, function(p)
				state.h = Clamp((p.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 0.999)
				push()
			end, function() isDragging = false end)
		end
	end)
	hexBox.FocusLost:Connect(function()
		local ok, c = pcall(Color3.fromHex, hexBox.Text)
		if ok and state.cp then
			state.h, state.s, state.v = c:ToHSV()
			push()
		else
			refresh()
		end
	end)

	local api = {}
	function api.Open(cp, anchor)
		win:ClosePopups()
		state.cp = cp
		state.h, state.s, state.v = cp.Value:ToHSV()
		refresh()
		local vp = workspace.CurrentCamera.ViewportSize
		local ap, as = anchor.AbsolutePosition, anchor.AbsoluteSize
		local x = Clamp(ap.X + as.X - 156, 6, vp.X - 162)
		local y = ap.Y + as.Y + 6
		if y + 144 > vp.Y - 6 then y = ap.Y - 150 end
		pop.Position = UDim2.fromOffset(x, y)
		win.Catcher.Visible = true
		pop.Visible = true
		scale.Scale = 0.9
		pop.BackgroundTransparency = 1
		popStroke.Transparency = 1
		Tween(pop, { BackgroundTransparency = 0 }, 0.18)
		Tween(popStroke, { Transparency = 0 }, 0.18)
		Tween(scale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
		win.Popup = api
	end
	function api.Close()
		if win.Popup ~= api then return end
		win.Popup = nil
		state.cp = nil
		win.Catcher.Visible = false
		Tween(pop, { BackgroundTransparency = 1 }, 0.12)
		Tween(popStroke, { Transparency = 1 }, 0.12)
		Tween(scale, { Scale = 0.94 }, 0.12)
		task.delay(0.12, function() if win.Popup ~= api then pop.Visible = false end end)
	end
	api.Refresh = function(cp)
		if state.cp == cp and not isDragging then
			state.h, state.s, state.v = cp.Value:ToHSV()
			refresh()
		end
	end
	return api
end

local function CreateColorPicker(win, parent, o)
	local cp = { Type = "ColorPicker", Value = o.Default or Color3.new(1, 1, 1), Callback = o.Callback or function() end }
	local swatch = New("TextButton", {
		BackgroundColor3 = cp.Value, Size = UDim2.fromOffset(20, 10), LayoutOrder = 2, ZIndex = 4, Parent = parent,
	})
	Corner(swatch, 3)
	local st = Stroke(swatch, Color3.new(1, 1, 1), 1, 0.85)
	swatch.MouseEnter:Connect(function() Tween(st, { Transparency = 0.5 }, 0.15) end)
	swatch.MouseLeave:Connect(function() Tween(st, { Transparency = 0.85 }, 0.15) end)

	function cp:Set(c, silent)
		self.Value = c
		swatch.BackgroundColor3 = c
		if self.Flag then Library.Flags[self.Flag] = c end
		if win.ColorPopup then win.ColorPopup.Refresh(self) end
		if not silent then task.spawn(self.Callback, c) end
	end
	function cp:Get() return self.Value end

	swatch.MouseButton1Click:Connect(function()
		win.ColorPopup = win.ColorPopup or BuildColorPopup(win)
		if win.Popup == win.ColorPopup then
			win:ClosePopups()
		else
			win.ColorPopup.Open(cp, swatch)
		end
	end)
	Register(o.Flag, cp, cp.Value)
	return cp
end

----------------------------------------------------------------------
-- KEYBIND
----------------------------------------------------------------------
local function KeyName(k)
	if not k then return "" end
	local map = {
		LeftShift = "LSHFT", RightShift = "RSHFT", LeftControl = "LCTRL", RightControl = "RCTRL", LeftAlt = "LALT",
		RightAlt = "RALT", MouseButton2 = "M2", MouseButton3 = "M3", Return = "ENTER", Backspace = "BKSP", Space = "SPACE",
	}
	return (map[k.Name] or k.Name):upper()
end

local function CreateKeybind(win, parent, o, handler)
	local kb = { Type = "Keybind", Key = o.Default, Mode = o.Mode or "Toggle", Listening = false, Handler = handler, Callback = o.Callback or function() end }
	local chip = New("TextButton", {
		BackgroundColor3 = Theme.Element, Size = UDim2.fromOffset(0, 14), AutomaticSize = Enum.AutomaticSize.X,
		Text = "", TextSize = 9, TextColor3 = Theme.SubText, Font = FONT_BOLD, LayoutOrder = 1, ZIndex = 4, Parent = parent,
	})
	Corner(chip, 4)
	local st = Stroke(chip, Theme.ElementStroke, 1, 1)
	Pad(chip, 5, 0, 5, 0)
	New("UISizeConstraint", { MinSize = Vector2.new(20, 14), Parent = chip })
	local icon = MakeKeyboardIcon(chip)

	local function render()
		if kb.Listening then
			chip.Text = "..."
			icon.Visible = false
		elseif kb.Key then
			chip.Text = KeyName(kb.Key)
			icon.Visible = false
		else
			chip.Text = ""
			icon.Visible = true
		end
		Tween(st, { Transparency = (kb.Key or kb.Listening) and 0 or 1 }, 0.15)
		Tween(chip, { TextColor3 = kb.Listening and Theme.Accent or Theme.SubText }, 0.15)
	end
	render()

	function kb:Set(k)
		self.Key = k
		if self.Flag then Library.Flags[self.Flag] = k end
		render()
	end
	function kb:Get() return self.Key end

	chip.MouseEnter:Connect(function() if not kb.Listening then Tween(st, { Transparency = 0 }, 0.15) end end)
	chip.MouseLeave:Connect(function() if not kb.Listening and not kb.Key then Tween(st, { Transparency = 1 }, 0.15) end end)
	chip.MouseButton2Click:Connect(function()
		kb.Mode = (kb.Mode == "Toggle") and "Hold" or "Toggle"
		Library:Notify({ Title = "Keybind mode", Content = "Mode set to " .. kb.Mode, Duration = 1.5 })
	end)
	chip.MouseButton1Click:Connect(function()
		if kb.Listening then return end
		kb.Listening = true
		render()
		local c
		c = UIS.InputBegan:Connect(function(input)
			local k
			if input.UserInputType == Enum.UserInputType.Keyboard then
				k = input.KeyCode
				if k == Enum.KeyCode.Escape or k == Enum.KeyCode.Backspace then k = false end
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
				k = input.UserInputType
			else
				return
			end
			c:Disconnect()
			task.defer(function()
				kb.Listening = false
				kb:Set(k or nil)
				if o.OnChange then task.spawn(o.OnChange, kb.Key) end
			end)
		end)
	end)

	table.insert(Library._keybinds, kb)
	Register(o.Flag, kb, kb.Key)
	return kb
end

----------------------------------------------------------------------
-- ELEMENTS (COMPACT)
----------------------------------------------------------------------
function Section:AddToggle(o)
	o = o or {}
	local win = self.Window
	local toggle = { Type = "Toggle", Value = false, Name = o.Name or "Toggle", Callback = o.Callback or function() end }
	local row = MakeRow(self, 26, toggle.Name)

	local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), Parent = row })
	local box = New("Frame", { BackgroundColor3 = Theme.Element, Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(12, 12), Parent = row })
	Corner(box, 3)
	local boxStroke = Stroke(box, Theme.ElementStroke)
	local _, scale = MakeCheck(box)
	local label = New("TextLabel", { Text = toggle.Name, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -70, 1, 0), Parent = row })
	local addons = Addons(row)

	function toggle:Set(v, silent)
		v = v and true or false
		self.Value = v
		Tween(box, { BackgroundColor3 = v and Theme.Accent or Theme.Element }, 0.15)
		Tween(boxStroke, { Color = v and Theme.Accent or Theme.ElementStroke }, 0.15)
		Tween(label, { TextColor3 = v and Theme.Text or Theme.SubText }, 0.15)
		Tween(scale, { Scale = v and 1 or 0 }, 0.22, v and Enum.EasingStyle.Back or Enum.EasingStyle.Quad)
		if self.Flag then Library.Flags[self.Flag] = v end
		if not silent then task.spawn(self.Callback, v) end
	end
	function toggle:Get() return self.Value end

	hit.MouseButton1Click:Connect(function() toggle:Set(not toggle.Value) end)
	hit.MouseEnter:Connect(function()
		if not toggle.Value then Tween(label, { TextColor3 = Theme.Text }, 0.15); Tween(boxStroke, { Color = Theme.Dim }, 0.15) end
	end)
	hit.MouseLeave:Connect(function()
		if not toggle.Value then Tween(label, { TextColor3 = Theme.SubText }, 0.15); Tween(boxStroke, { Color = Theme.ElementStroke }, 0.15) end
	end)

	function toggle:AddColorPicker(co)
		co = co or {}
		return CreateColorPicker(win, addons, co)
	end
	function toggle:AddKeybind(ko)
		ko = ko or {}
		local kb
		kb = CreateKeybind(win, addons, ko, function(pressed)
			if kb.Mode == "Hold" then toggle:Set(pressed) elseif pressed then toggle:Set(not toggle.Value) end
		end)
		return kb
	end

	Register(o.Flag, toggle, false)
	toggle:Set(o.Default or false, true)
	if o.Default then task.defer(function() task.spawn(toggle.Callback, true) end) end
	return toggle
end

function Section:AddSlider(o)
	o = o or {}
	local min, max = o.Min or 0, o.Max or 100
	local inc = o.Increment or 1
	local slider = { Type = "Slider", Name = o.Name or "Slider", Value = min, Callback = o.Callback or function() end }
	local suffix = o.Suffix or ""
	local decimals = o.Decimals or DecimalsOf(inc)
	local row = MakeRow(self, 28, slider.Name)

	New("TextLabel", { Text = slider.Name, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -80, 0, 12), Parent = row })
	local valueLabel = New("TextLabel", { Text = "", TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -68, 0, 3), Size = UDim2.fromOffset(60, 12), Parent = row })

	local hit = New("TextButton", { Position = UDim2.fromOffset(8, 14), Size = UDim2.new(1, -16, 0, 14), Parent = row })
	local track = New("Frame", { BackgroundColor3 = Theme.Element, Position = UDim2.new(0, 0, 0.5, -2), Size = UDim2.new(1, 0, 0, 3), Parent = hit })
	Corner(track, 2)
	local fill = New("Frame", { BackgroundColor3 = Theme.Accent, Size = UDim2.new(0, 0, 1, 0), Parent = track })
	Corner(fill, 2)
	local KW = 14
	local knob = New("Frame", { BackgroundColor3 = Color3.fromRGB(42, 42, 48), Size = UDim2.fromOffset(KW, 9), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), ZIndex = 3, Parent = hit })
	Corner(knob, 3)
	local knobStroke = Stroke(knob, Color3.fromRGB(62, 62, 70))

	local function fmt(v)
		if o.Format then return o.Format(v) end
		local s = string.format("%." .. decimals .. "f", v)
		if decimals > 0 then
			s = s:gsub("0+$", "")
			s = s:gsub("%.$", "")
		end
		return s .. suffix
	end

	local function visual(pct, animate)
		local pos = UDim2.new(pct, (0.5 - pct) * KW, 0.5, 0)
		local fsz = UDim2.new(pct, (0.5 - pct) * KW, 1, 0)
		if animate then
			Tween(knob, { Position = pos }, 0.08)
			Tween(fill, { Size = fsz }, 0.08)
		else
			knob.Position, fill.Size = pos, fsz
		end
	end

	function slider:Set(v, silent, animate)
		v = Clamp(Round(tonumber(v) or min, inc), min, max)
		v = tonumber(string.format("%." .. math.max(decimals, 0) .. "f", v))
		self.Value = v
		visual((v - min) / (max - min), animate ~= false)
		valueLabel.Text = fmt(v)
		if self.Flag then Library.Flags[self.Flag] = v end
		if not silent then task.spawn(self.Callback, v) end
	end
	function slider:Get() return self.Value end

	hit.InputBegan:Connect(function(input)
		if IsPress(input) then
			Tween(knobStroke, { Color = Theme.Accent }, 0.15)
			BeginDrag(input, function(p)
				local pct = Clamp((p.X - hit.AbsolutePosition.X - KW / 2) / math.max(1, hit.AbsoluteSize.X - KW), 0, 1)
				slider:Set(min + pct * (max - min))
			end, function() Tween(knobStroke, { Color = Color3.fromRGB(62, 62, 70) }, 0.2) end)
		end
	end)
	hit.MouseEnter:Connect(function() Tween(knob, { BackgroundColor3 = Color3.fromRGB(54, 54, 62) }, 0.15) end)
	hit.MouseLeave:Connect(function() Tween(knob, { BackgroundColor3 = Color3.fromRGB(42, 42, 48) }, 0.15) end)

	Register(o.Flag, slider, o.Default or min)
	slider:Set(o.Default or min, true, false)
	return slider
end

function Section:AddDropdown(o)
	o = o or {}
	local multi = o.Multi
	local options = o.Options or {}
	local dd = { Type = "Dropdown", Name = o.Name or "Dropdown", Callback = o.Callback or function() end, Open = false }
	local sel = {}
	local row = MakeRow(self, 44, dd.Name)
	row.ClipsDescendants = true
	row.Divider.Visible = false

	New("TextLabel", { Text = dd.Name, TextColor3 = Theme.Text, Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 12), Parent = row })
	local header = New("TextButton", { BackgroundColor3 = Theme.Element, Position = UDim2.fromOffset(8, 18), Size = UDim2.new(1, -16, 0, 20), Parent = row })
	Corner(header, 5)
	local hs = Stroke(header, Theme.ElementStroke)
	local selText = New("TextLabel", { Text = "", TextColor3 = Theme.SubText, TextSize = 9, Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -30, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = header })
	local chev = MakeChevron(header, Theme.SubText)
	chev.Position = UDim2.new(1, -12, 0.5, 0)

	local list = New("ScrollingFrame", { BackgroundColor3 = Theme.Element, Position = UDim2.fromOffset(8, 42), Size = UDim2.new(1, -16, 0, 0), ScrollBarThickness = 2, ClipsDescendants = true, Parent = row })
	Corner(list, 5)
	Stroke(list, Theme.ElementStroke)
	New("UIListLayout", { Parent = list })

	local function rebuildValue()
		if multi then
			local t = {}
			for _, opt in ipairs(options) do if sel[opt] then t[#t + 1] = opt end end
			dd.Value = t
			selText.Text = #t > 0 and table.concat(t, ", ") or "None"
		else
			selText.Text = dd.Value ~= nil and tostring(dd.Value) or "None"
		end
		Tween(selText, { TextColor3 = (dd.Value ~= nil and (not multi or #dd.Value > 0)) and Theme.Text or Theme.SubText }, 0.15)
		if dd.Flag then Library.Flags[dd.Flag] = dd.Value end
	end

	local buttons = {}
	local function restyle()
		for opt, b in pairs(buttons) do
			local on = multi and sel[opt] or (not multi and dd.Value == opt)
			Tween(b, { TextColor3 = on and Theme.Accent or Theme.SubText }, 0.15)
		end
	end

	local function listHeight() return math.min(#options, 5) * 20 end
	local function applyOpen(open, instant)
		dd.Open = open
		local h = open and (42 + listHeight() + 6) or 44
		local info = { Size = UDim2.new(1, 0, 0, h) }
		if instant then row.Size = info.Size else Tween(row, info, 0.25, Enum.EasingStyle.Quint) end
		Tween(list, { Size = UDim2.new(1, -16, 0, listHeight()) }, 0.25, Enum.EasingStyle.Quint)
		Tween(chev, { Rotation = open and 180 or 0 }, 0.25, Enum.EasingStyle.Quint)
		Tween(hs, { Color = open and Theme.Accent or Theme.ElementStroke }, 0.2)
	end

	local function build()
		for _, b in pairs(buttons) do b:Destroy() end
		table.clear(buttons)
		for i, opt in ipairs(options) do
			local b = New("TextButton", { Text = tostring(opt), TextSize = 9, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = i, BackgroundTransparency = 1, BackgroundColor3 = Theme.ElementHover, Parent = list })
			Pad(b, 8, 0, 0, 0)
			buttons[opt] = b
			b.MouseEnter:Connect(function() Tween(b, { BackgroundTransparency = 0 }, 0.12) end)
			b.MouseLeave:Connect(function() Tween(b, { BackgroundTransparency = 1 }, 0.12) end)
			b.MouseButton1Click:Connect(function()
				if multi then
					sel[opt] = not sel[opt] or nil
				else
					dd.Value = opt
					applyOpen(false)
				end
				rebuildValue()
				restyle()
				task.spawn(dd.Callback, dd.Value)
			end)
		end
		restyle()
		if dd.Open then applyOpen(true, true) end
	end

	function dd:Set(v, silent)
		if multi then
			sel = {}
			for _, x in ipairs(type(v) == "table" and v or {}) do sel[x] = true end
		else
			dd.Value = v
		end
		rebuildValue()
		restyle()
		if not silent then task.spawn(self.Callback, self.Value) end
	end
	function dd:Get() return self.Value end
	function dd:Refresh(newOptions, keep)
		options = newOptions
		if not keep then
			if multi then sel = {} else dd.Value = nil end
		end
		rebuildValue()
		build()
	end

	header.MouseButton1Click:Connect(function() applyOpen(not dd.Open) end)
	header.MouseEnter:Connect(function() if not dd.Open then Tween(hs, { Color = Theme.Dim }, 0.15) end end)
	header.MouseLeave:Connect(function() if not dd.Open then Tween(hs, { Color = Theme.ElementStroke }, 0.15) end end)

	if multi then
		for _, x in ipairs(o.Default or {}) do sel[x] = true end
	else
		dd.Value = o.Default
	end
	Register(o.Flag, dd, dd.Value)
	rebuildValue()
	build()
	return dd
end

function Section:AddButton(o)
	o = o or {}
	local row = MakeRow(self, 28, o.Name or "Button")
	local btn = New("TextButton", {
		BackgroundColor3 = Theme.Element, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 20),
		Text = o.Name or "Button", TextSize = 10, TextColor3 = Theme.Text, Parent = row,
	})
	Corner(btn, 5)
	local st = Stroke(btn, Theme.ElementStroke)
	btn.MouseEnter:Connect(function() Tween(btn, { BackgroundColor3 = Theme.ElementHover }, 0.15); Tween(st, { Color = Theme.Dim }, 0.15) end)
	btn.MouseLeave:Connect(function() Tween(btn, { BackgroundColor3 = Theme.Element }, 0.15); Tween(st, { Color = Theme.ElementStroke }, 0.15) end)
	btn.MouseButton1Down:Connect(function() Tween(btn, { BackgroundColor3 = Theme.Accent, TextColor3 = Theme.OnAccent }, 0.08) end)
	btn.MouseButton1Up:Connect(function() Tween(btn, { BackgroundColor3 = Theme.ElementHover, TextColor3 = Theme.Text }, 0.25) end)
	btn.MouseButton1Click:Connect(function() if o.Callback then task.spawn(o.Callback) end end)
	return { Set = function(_, t) btn.Text = t end }
end

function Section:AddLabel(o)
	if type(o) == "string" then o = { Text = o } end
	o = o or {}
	local row = MakeRow(self, 20, o.Text or "")
	row.Divider.Visible = false
	local l = New("TextLabel", { Text = o.Text or "", TextColor3 = Theme.SubText, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), TextWrapped = true, Parent = row })
	return { Set = function(_, t) l.Text = t end }
end

function Section:AddTextbox(o)
	o = o or {}
	local tb = { Type = "Textbox", Name = o.Name or "Textbox", Value = o.Default or "", Callback = o.Callback or function() end }
	local row = MakeRow(self, 26, tb.Name)
	New("TextLabel", { Text = tb.Name, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.45, -8, 1, 0), Parent = row })
	local frame = New("Frame", { BackgroundColor3 = Theme.Element, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0.55, -8, 0, 18), Parent = row })
	Corner(frame, 5)
	local st = Stroke(frame, Theme.ElementStroke)
	local box = New("TextBox", { Text = tb.Value, PlaceholderText = o.Placeholder or "", TextSize = 9, Position = UDim2.fromOffset(7, 0), Size = UDim2.new(1, -14, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true, Parent = frame })
	box.Focused:Connect(function() Tween(st, { Color = Theme.Accent }, 0.15) end)
	box.FocusLost:Connect(function(enter)
		Tween(st, { Color = Theme.ElementStroke }, 0.15)
		tb:Set(box.Text)
	end)
	function tb:Set(v, silent)
		self.Value = tostring(v)
		box.Text = self.Value
		if self.Flag then Library.Flags[self.Flag] = self.Value end
		if not silent then task.spawn(self.Callback, self.Value) end
	end
	function tb:Get() return self.Value end
	Register(o.Flag, tb, tb.Value)
	return tb
end

function Section:AddColorPicker(o)
	o = o or {}
	local row = MakeRow(self, 26, o.Name or "Colour")
	New("TextLabel", { Text = o.Name or "Colour", TextColor3 = Theme.SubText, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -60, 1, 0), Parent = row })
	return CreateColorPicker(self.Window, Addons(row), o)
end

function Section:AddKeybind(o)
	o = o or {}
	local row = MakeRow(self, 26, o.Name or "Keybind")
	New("TextLabel", { Text = o.Name or "Keybind", TextColor3 = Theme.SubText, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -70, 1, 0), Parent = row })
	local kb
	kb = CreateKeybind(self.Window, Addons(row), o, function(pressed)
		if kb.Mode == "Hold" then task.spawn(kb.Callback, pressed) elseif pressed then task.spawn(kb.Callback, true) end
	end)
	return kb
end

return Library
