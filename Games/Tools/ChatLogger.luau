-- Farewell Infortality - Chat GUI
-- Version: 5.0
-- A floating toolbar + card-style chat log:
--   - per-player color dots, muted message-type colors, dimmed timestamps
--   - stateful icon chips (filled = on, outline = off) for Log/Time
--   - live "online" count in the title
--   - search/filter with quick-clear
--   - hoverable message rows
--   - bottom-sheet style resize grip, draggable + screen-clamped header
--   - "new messages" pill when you've scrolled away from the bottom
--   - RightControl to show/hide the whole thing

-- ============================================================
-- Services
-- ============================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- Config / palette
-- ============================================================
local MAX_ENTRIES = 200
local MAX_RENDERED = 200
local DEFAULT_CONTENT_HEIGHT = 220
local TOGGLE_KEY = Enum.KeyCode.RightControl
local BOTTOM_THRESHOLD = 40

local COLOR = {
	HeaderBg = Color3.fromRGB(26, 26, 30),
	CardBg = Color3.fromRGB(20, 20, 23),
	Elevated = Color3.fromRGB(34, 34, 38),
	Accent = Color3.fromRGB(99, 102, 241), -- indigo
	Online = Color3.fromRGB(52, 199, 89), -- green
	Muted = Color3.fromRGB(142, 142, 150),
	Text = Color3.fromRGB(235, 235, 238),
	Danger = Color3.fromRGB(239, 83, 80),
	Emote = Color3.fromRGB(255, 118, 117),
	Whisper = Color3.fromRGB(100, 197, 255),
	Command = Color3.fromRGB(255, 202, 87),
	Normal = Color3.fromRGB(225, 225, 230),
	System = Color3.fromRGB(140, 140, 148),
}

-- ============================================================
-- Root GUI
-- ============================================================
local ChatGui = Instance.new("ScreenGui")
ChatGui.Name = "ChatGui"
ChatGui.ResetOnSpawn = false
ChatGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- Header (floating toolbar)
-- ============================================================
local Frame = Instance.new("Frame")
Frame.Name = "MainFrame"
Frame.BackgroundColor3 = COLOR.HeaderBg
Frame.BackgroundTransparency = 0.04
Frame.BorderSizePixel = 0
Frame.Position = UDim2.new(0.02, 0, 0.62, 0)
Frame.Size = UDim2.new(0, 420, 0, 36)
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ChatGui

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 10)
headerCorner.Parent = Frame

local headerStroke = Instance.new("UIStroke")
headerStroke.Color = Color3.fromRGB(255, 255, 255)
headerStroke.Thickness = 1
headerStroke.Transparency = 0.9
headerStroke.Parent = Frame

local headerPad = Instance.new("UIPadding")
headerPad.PaddingLeft = UDim.new(0, 12)
headerPad.PaddingRight = UDim.new(0, 8)
headerPad.Parent = Frame

-- Title + live online count (single rich-text label)
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 0, 0, 0)
Title.Size = UDim2.new(0, 150, 1, 0)
Title.Font = Enum.Font.GothamBold
Title.RichText = true
Title.TextColor3 = COLOR.Text
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Frame

local function updateTitle()
	local count = #Players:GetPlayers()
	local suffix = count == 1 and "" or "s"
	Title.Text = string.format('Chat GUI  <font color="#8E8E96" size="12">\u{2022} %d online%s</font>', count, suffix)
end
updateTitle()

-- Button row (right-aligned, auto-laid-out chips)
local ButtonRow = Instance.new("Frame")
ButtonRow.Name = "ButtonRow"
ButtonRow.BackgroundTransparency = 1
ButtonRow.Position = UDim2.new(0, 150, 0, 0)
ButtonRow.Size = UDim2.new(1, -150, 1, 0)
ButtonRow.Parent = Frame

local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rowLayout.Padding = UDim.new(0, 6)
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Parent = ButtonRow

-- Chip builder: "toggle" chips render filled when ON / outlined when OFF.
-- "action" chips are always outlined-neutral, with an optional danger hover tint.
local function makeChip(name, text, width, variant)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0, width, 0, 24)
	btn.Font = Enum.Font.GothamMedium
	btn.Text = text
	btn.TextSize = 12
	btn.AutoButtonColor = false
	btn.BackgroundTransparency = 1
	btn.Parent = ButtonRow

	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(0, 6)
	chipCorner.Parent = btn

	local chipStroke = Instance.new("UIStroke")
	chipStroke.Thickness = 1
	chipStroke.Parent = btn

	local state = { on = false, hovering = false, variant = variant }

	local function applyStyle()
		if state.variant == "toggle" and state.on then
			TweenService:Create(btn, TweenInfo.new(0.12), {
				BackgroundColor3 = COLOR.Accent,
				BackgroundTransparency = state.hovering and 0.05 or 0.15,
				TextColor3 = Color3.fromRGB(255, 255, 255),
			}):Play()
			chipStroke.Transparency = 1
		elseif state.variant == "danger" and state.hovering then
			TweenService:Create(btn, TweenInfo.new(0.12), {
				BackgroundColor3 = COLOR.Danger,
				BackgroundTransparency = 0.85,
				TextColor3 = COLOR.Danger,
			}):Play()
			chipStroke.Color = COLOR.Danger
			chipStroke.Transparency = 0.6
		else
			TweenService:Create(btn, TweenInfo.new(0.12), {
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = state.hovering and 0.92 or 1,
				TextColor3 = COLOR.Muted,
			}):Play()
			chipStroke.Color = Color3.fromRGB(255, 255, 255)
			chipStroke.Transparency = 0.85
		end
	end
	applyStyle()

	btn.MouseEnter:Connect(function()
		state.hovering = true
		applyStyle()
	end)
	btn.MouseLeave:Connect(function()
		state.hovering = false
		applyStyle()
	end)

	return btn, state, applyStyle
end

local ToggleLogBtn, logState, applyLogStyle = makeChip("ToggleLogBtn", "LOG", 40, "toggle")
local TimeToggleBtn, timeState, applyTimeStyle = makeChip("TimeToggleBtn", "TIME", 44, "toggle")
local MinimizeBtn = makeChip("MinimizeBtn", "\u{2013}", 26, "action")
local ClearBtn = makeChip("ClearBtn", "CLR", 34, "danger")
local CloseBtn = makeChip("CloseBtn", "\u{00D7}", 26, "danger")

logState.on = true
applyLogStyle()
timeState.on = true
applyTimeStyle()

-- ============================================================
-- Card (filter bar + log panel), floats below the header
-- ============================================================
local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.BackgroundColor3 = COLOR.CardBg
ContentFrame.BackgroundTransparency = 0.04
ContentFrame.BorderSizePixel = 0
ContentFrame.Position = UDim2.new(0, 0, 1, 6)
ContentFrame.Size = UDim2.new(1, 0, 0, DEFAULT_CONTENT_HEIGHT)
ContentFrame.ClipsDescendants = false
ContentFrame.Parent = Frame

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 10)
cardCorner.Parent = ContentFrame

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(255, 255, 255)
cardStroke.Thickness = 1
cardStroke.Transparency = 0.92
cardStroke.Parent = ContentFrame

-- Filter bar
local FilterBar = Instance.new("TextBox")
FilterBar.Name = "FilterBar"
FilterBar.BackgroundColor3 = COLOR.Elevated
FilterBar.BorderSizePixel = 0
FilterBar.Position = UDim2.new(0, 8, 0, 8)
FilterBar.Size = UDim2.new(1, -16, 0, 26)
FilterBar.Font = Enum.Font.Gotham
FilterBar.PlaceholderText = "Search player..."
FilterBar.PlaceholderColor3 = COLOR.Muted
FilterBar.Text = ""
FilterBar.ClearTextOnFocus = false
FilterBar.TextColor3 = COLOR.Text
FilterBar.TextSize = 13
FilterBar.TextXAlignment = Enum.TextXAlignment.Left
FilterBar.ClipsDescendants = true
FilterBar.Parent = ContentFrame

local filterCorner = Instance.new("UICorner")
filterCorner.CornerRadius = UDim.new(0, 6)
filterCorner.Parent = FilterBar

local filterPadding = Instance.new("UIPadding")
filterPadding.PaddingLeft = UDim.new(0, 10)
filterPadding.PaddingRight = UDim.new(0, 26)
filterPadding.Parent = FilterBar

-- Quick-clear "x" inside the filter bar, only shown while it has text
local FilterClearBtn = Instance.new("TextButton")
FilterClearBtn.Name = "FilterClearBtn"
FilterClearBtn.AnchorPoint = Vector2.new(1, 0.5)
FilterClearBtn.Position = UDim2.new(1, -6, 0.5, 0)
FilterClearBtn.Size = UDim2.new(0, 18, 0, 18)
FilterClearBtn.BackgroundTransparency = 1
FilterClearBtn.Font = Enum.Font.GothamBold
FilterClearBtn.Text = "\u{00D7}"
FilterClearBtn.TextColor3 = COLOR.Muted
FilterClearBtn.TextSize = 13
FilterClearBtn.Visible = false
FilterClearBtn.ZIndex = 3
FilterClearBtn.Parent = FilterBar

-- Divider between filter bar and log panel
local Divider = Instance.new("Frame")
Divider.Name = "Divider"
Divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Divider.BackgroundTransparency = 0.94
Divider.BorderSizePixel = 0
Divider.Position = UDim2.new(0, 8, 0, 42)
Divider.Size = UDim2.new(1, -16, 0, 1)
Divider.Parent = ContentFrame

-- Log Panel (ScrollingFrame) - fills the rest of the card
local LogPanel = Instance.new("ScrollingFrame")
LogPanel.Name = "LogPanel"
LogPanel.BackgroundTransparency = 1
LogPanel.BorderSizePixel = 0
LogPanel.Position = UDim2.new(0, 0, 0, 48)
LogPanel.Size = UDim2.new(1, 0, 1, -48)
LogPanel.ScrollBarThickness = 3
LogPanel.ScrollBarImageColor3 = COLOR.Accent
LogPanel.ScrollingEnabled = true
LogPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
LogPanel.Parent = ContentFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 1)
ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
ListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = LogPanel

local panelPadding = Instance.new("UIPadding")
panelPadding.PaddingLeft = UDim.new(0, 6)
panelPadding.PaddingRight = UDim.new(0, 6)
panelPadding.PaddingTop = UDim.new(0, 4)
panelPadding.PaddingBottom = UDim.new(0, 6)
panelPadding.Parent = LogPanel

-- Resize grip: bottom-sheet style handle, centered at the card's bottom edge
local ResizeHandle = Instance.new("TextButton")
ResizeHandle.Name = "ResizeHandle"
ResizeHandle.AnchorPoint = Vector2.new(0.5, 1)
ResizeHandle.Position = UDim2.new(0.5, 0, 1, -4)
ResizeHandle.Size = UDim2.new(0, 44, 0, 10)
ResizeHandle.BackgroundTransparency = 1
ResizeHandle.Text = ""
ResizeHandle.AutoButtonColor = false
ResizeHandle.ZIndex = 4
ResizeHandle.Parent = ContentFrame

local gripBar = Instance.new("Frame")
gripBar.Name = "GripBar"
gripBar.AnchorPoint = Vector2.new(0.5, 0.5)
gripBar.Position = UDim2.new(0.5, 0, 0.5, 0)
gripBar.Size = UDim2.new(0, 34, 0, 4)
gripBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
gripBar.BackgroundTransparency = 0.82
gripBar.BorderSizePixel = 0
gripBar.Parent = ResizeHandle

local gripCorner = Instance.new("UICorner")
gripCorner.CornerRadius = UDim.new(1, 0)
gripCorner.Parent = gripBar

ResizeHandle.MouseEnter:Connect(function()
	TweenService:Create(gripBar, TweenInfo.new(0.12), { BackgroundTransparency = 0.4 }):Play()
end)
ResizeHandle.MouseLeave:Connect(function()
	TweenService:Create(gripBar, TweenInfo.new(0.12), { BackgroundTransparency = 0.82 }):Play()
end)

-- "New messages" pill - shown when the user has scrolled up and new
-- messages have arrived, so we don't yank their view down mid-read.
local NewMessagesPill = Instance.new("TextButton")
NewMessagesPill.Name = "NewMessagesPill"
NewMessagesPill.AnchorPoint = Vector2.new(0.5, 1)
NewMessagesPill.Position = UDim2.new(0.5, 0, 1, -18)
NewMessagesPill.Size = UDim2.new(0, 150, 0, 24)
NewMessagesPill.BackgroundColor3 = COLOR.Accent
NewMessagesPill.BackgroundTransparency = 0.05
NewMessagesPill.TextColor3 = Color3.fromRGB(255, 255, 255)
NewMessagesPill.Font = Enum.Font.GothamBold
NewMessagesPill.TextSize = 12
NewMessagesPill.Text = "\u{2193} New messages"
NewMessagesPill.Visible = false
NewMessagesPill.AutoButtonColor = false
NewMessagesPill.ZIndex = 5
NewMessagesPill.Parent = ContentFrame

local pillCorner = Instance.new("UICorner")
pillCorner.CornerRadius = UDim.new(1, 0)
pillCorner.Parent = NewMessagesPill

-- ============================================================
-- State
-- ============================================================
local logging = true
local showTimestamps = true
local minimized = false
local filterText = ""
local contentHeight = DEFAULT_CONTENT_HEIGHT

local chatLog = {}
local renderedRows = {}
local entryCounter = 0
local playerColors = {}

local stickToBottom = true
local pendingNewCount = 0

-- ============================================================
-- Helpers
-- ============================================================
local function toHex(color)
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function escapeRichText(text)
	text = text:gsub("&", "&amp;")
	text = text:gsub("<", "&lt;")
	text = text:gsub(">", "&gt;")
	text = text:gsub('"', "&quot;")
	text = text:gsub("'", "&apos;")
	return text
end

-- Consistent, distinct-ish color per player name (used for the identity dot)
local function getPlayerColor(name)
	if not playerColors[name] then
		local hash = 0
		for i = 1, #name do
			hash = (hash * 31 + string.byte(name, i)) % 360
		end
		playerColors[name] = Color3.fromHSV(hash / 360, 0.6, 1)
	end
	return playerColors[name]
end

-- Message-type color (emote / whisper / command / normal)
local function getMessageColor(msg)
	local firstChar = msg:sub(1, 1)
	local lowerMsg = msg:lower()

	if firstChar == ":" or firstChar == ";" then
		return COLOR.Emote
	elseif
		lowerMsg:match("^/w%s")
		or lowerMsg:match("^/whisper%s")
		or lowerMsg:match("^/t%s")
		or lowerMsg:match("^/team%s")
	then
		return COLOR.Whisper
	elseif lowerMsg:match("^/") then
		return COLOR.Command
	else
		return COLOR.Normal
	end
end

-- Roblox clamps CanvasPosition to the valid range automatically, so a
-- large Y value always lands exactly at the bottom - more reliable than
-- reading CanvasSize.Y.Offset, which can lag a frame behind AutomaticCanvasSize.
local function scrollToBottom()
	task.defer(function()
		LogPanel.CanvasPosition = Vector2.new(0, 1e7)
	end)
end

local function isNearBottom()
	local maxY = math.max(0, LogPanel.CanvasSize.Y.Offset - LogPanel.AbsoluteWindowSize.Y)
	return (maxY - LogPanel.CanvasPosition.Y) <= BOTTOM_THRESHOLD
end

local function hideNewMessagesPill()
	pendingNewCount = 0
	NewMessagesPill.Visible = false
end

local function jumpToLatest()
	stickToBottom = true
	hideNewMessagesPill()
	scrollToBottom()
end

NewMessagesPill.MouseButton1Click:Connect(jumpToLatest)

LogPanel:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
	stickToBottom = isNearBottom()
	if stickToBottom then
		hideNewMessagesPill()
	end
end)

-- ============================================================
-- Rendering
-- ============================================================
local function createLogEntry(entry)
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Active = true
	row.LayoutOrder = entry.order
	row.Parent = LogPanel

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 4)
	rowCorner.Parent = row

	local rowPad = Instance.new("UIPadding")
	rowPad.PaddingTop = UDim.new(0, 2)
	rowPad.PaddingBottom = UDim.new(0, 2)
	rowPad.PaddingLeft = UDim.new(0, 4)
	rowPad.PaddingRight = UDim.new(0, 4)
	rowPad.Parent = row

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.Size = UDim2.new(0, 6, 0, 6)
	dot.Position = UDim2.new(0, 2, 0, 7)
	dot.BackgroundColor3 = entry.dotColor
	dot.BorderSizePixel = 0
	dot.Parent = row

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	local label = Instance.new("TextLabel")
	label.Name = "MsgLabel"
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 15, 0, 0)
	label.Size = UDim2.new(1, -15, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Font = Enum.Font.Gotham
	label.RichText = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextSize = 14
	label.Parent = row

	local text = ""
	if showTimestamps then
		text = text .. '<font color="#6E6E76" size="12">' .. entry.time .. "  </font>"
	end
	text = text .. '<font color="#E8E8EA"><b>' .. escapeRichText(entry.name) .. "</b></font>  "
	text = text .. '<font color="' .. toHex(entry.msgColor) .. '">' .. escapeRichText(entry.msg) .. "</font>"
	label.Text = text
	label.Parent = row

	row.MouseEnter:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.12), { BackgroundTransparency = 0.95 }):Play()
	end)
	row.MouseLeave:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.12), { BackgroundTransparency = 1 }):Play()
	end)

	table.insert(renderedRows, row)
	if #renderedRows > MAX_RENDERED then
		local old = table.remove(renderedRows, 1)
		if old then
			old:Destroy()
		end
	end
end

local function clearRenderedRows()
	for _, row in ipairs(renderedRows) do
		if row and row.Parent then
			row:Destroy()
		end
	end
	renderedRows = {}
end

local function renderLog()
	clearRenderedRows()
	local needle = filterText:lower()
	for _, entry in ipairs(chatLog) do
		if needle == "" or entry.name:lower():find(needle, 1, true) then
			createLogEntry(entry)
		end
	end
	jumpToLatest()
end

local function addChatMessage(name, msg, isSystem)
	entryCounter = entryCounter + 1
	local entry = {
		order = entryCounter,
		name = name,
		msg = msg,
		time = os.date("%H:%M:%S"),
		dotColor = isSystem and COLOR.System or getPlayerColor(name),
		msgColor = isSystem and COLOR.System or getMessageColor(msg),
	}

	table.insert(chatLog, entry)
	if #chatLog > MAX_ENTRIES then
		table.remove(chatLog, 1)
	end

	local needle = filterText:lower()
	if needle == "" or name:lower():find(needle, 1, true) then
		createLogEntry(entry)
		if stickToBottom then
			scrollToBottom()
		else
			pendingNewCount = pendingNewCount + 1
			NewMessagesPill.Text = "\u{2193} "
				.. pendingNewCount
				.. " new message"
				.. (pendingNewCount > 1 and "s" or "")
			NewMessagesPill.Visible = true
		end
	end
end

-- ============================================================
-- Chat + player connections
-- ============================================================
local connections = {}
local function connectToPlayer(player)
	local conn = player.Chatted:Connect(function(msg)
		if logging then
			addChatMessage(player.Name, msg, false)
		end
	end)
	table.insert(connections, { player = player, connection = conn })
end

for _, player in ipairs(Players:GetPlayers()) do
	connectToPlayer(player)
end

local playerAddedConn = Players.PlayerAdded:Connect(function(player)
	connectToPlayer(player)
	updateTitle()
	if logging then
		addChatMessage("System", player.Name .. " joined the game", true)
	end
end)

local playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
	for i, entry in ipairs(connections) do
		if entry.player == player then
			entry.connection:Disconnect()
			table.remove(connections, i)
			break
		end
	end
	updateTitle()
	if logging then
		addChatMessage("System", player.Name .. " left the game", true)
	end
end)

-- ============================================================
-- Button behavior
-- ============================================================
ToggleLogBtn.MouseButton1Click:Connect(function()
	logging = not logging
	logState.on = logging
	applyLogStyle()
end)

TimeToggleBtn.MouseButton1Click:Connect(function()
	showTimestamps = not showTimestamps
	timeState.on = showTimestamps
	applyTimeStyle()
	renderLog()
end)

MinimizeBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	MinimizeBtn.Text = minimized and "+" or "\u{2013}"
	local targetHeight = minimized and 0 or contentHeight
	TweenService:Create(
		ContentFrame,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(1, 0, 0, targetHeight) }
	):Play()
	ResizeHandle.Visible = not minimized
end)

ClearBtn.MouseButton1Click:Connect(function()
	chatLog = {}
	entryCounter = 0
	clearRenderedRows()
	LogPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
	hideNewMessagesPill()
	stickToBottom = true
	scrollToBottom()
end)

CloseBtn.MouseButton1Click:Connect(function()
	for _, entry in ipairs(connections) do
		entry.connection:Disconnect()
	end
	connections = {}
	playerAddedConn:Disconnect()
	playerRemovingConn:Disconnect()
	ChatGui:Destroy()
end)

FilterBar:GetPropertyChangedSignal("Text"):Connect(function()
	filterText = FilterBar.Text
	FilterClearBtn.Visible = filterText ~= ""
	renderLog()
end)

FilterClearBtn.MouseButton1Click:Connect(function()
	FilterBar.Text = ""
	FilterBar:CaptureFocus()
end)

-- ============================================================
-- Resize handle drag
-- ============================================================
local resizing = false
local resizeStartY = 0
local resizeStartHeight = 0

ResizeHandle.InputBegan:Connect(function(input)
	if minimized then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		resizing = true
		resizeStartY = input.Position.Y
		resizeStartHeight = contentHeight
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if
		resizing
		and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
	then
		local delta = input.Position.Y - resizeStartY
		contentHeight = math.clamp(resizeStartHeight + delta, 100, 600)
		ContentFrame.Size = UDim2.new(1, 0, 0, contentHeight)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		resizing = false
	end
end)

-- ============================================================
-- Keep the header on-screen while dragging
-- ============================================================
local function clampFramePosition()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local absPos = Frame.AbsolutePosition
	local absSize = Frame.AbsoluteSize

	local clampedX = math.clamp(absPos.X, 0, math.max(0, viewport.X - absSize.X))
	local clampedY = math.clamp(absPos.Y, 0, math.max(0, viewport.Y - absSize.Y))

	if math.abs(clampedX - absPos.X) > 0.5 or math.abs(clampedY - absPos.Y) > 0.5 then
		local dx = clampedX - absPos.X
		local dy = clampedY - absPos.Y
		Frame.Position = UDim2.new(
			Frame.Position.X.Scale,
			Frame.Position.X.Offset + dx,
			Frame.Position.Y.Scale,
			Frame.Position.Y.Offset + dy
		)
	end
end
Frame:GetPropertyChangedSignal("Position"):Connect(clampFramePosition)

-- ============================================================
-- Show/hide keybind
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.KeyCode == TOGGLE_KEY then
		ChatGui.Enabled = not ChatGui.Enabled
	end
end)
