if _G.ShadeLoaded then
	print(Library.AccentColor:ToHex())
	Library:Notify(
		('<font color="#909397">[</font>Shade<font color="#%s">.Luau</font><font color="#909397">]</font> Already loaded. Unload the previous instance before loading again.'):format(
			Library.AccentColor:ToHex()
		)
	)
	warn("[Shade.Luau] Already loaded. Unload the previous instance before loading again.")
	return
end
_G.ShadeLoaded = true

--// Services
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local TextService = game:GetService("TextService")
local TeleportService = game:GetService("TeleportService")

--// Variables
local UiRepo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
local Library = loadstring(game:HttpGet(UiRepo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(UiRepo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(UiRepo .. "addons/SaveManager.lua"))()

-- local ALLOWED_PLACE_ID = 122789100578830
-- if game.PlaceId ~= ALLOWED_PLACE_ID then
-- 	Library:Notify("[Shade.Luau] Incorrect game. Script not executed.")
-- 	warn("[Shade.Luau] Incorrect game. Script not executed.")
-- 	task.wait(7)
-- 	Library:Unload()
-- 	return
-- end

local config = {
	MenuKeybind = Enum.KeyCode.RightShift,
	AccentColor = Color3.fromRGB(90, 140, 215),
	Aimbot = { Enabled = false },
	NoRecoil = false,
	InfiniteStamina = false,
	InfiniteHunger = false,
	InfiniteThirst = false,
	MiniMap = {
		Enabled = false,
		Position = UDim2.fromScale(0.905, 0.18),
		Scale = UDim2.fromOffset(350, 350),
	},
	Speed = {
		Enabled = false,
		Multiplier = 2.0,
		LockJump = true,
	},
	KeepScriptOnRejoin = false,
}

local connections = {}
local toggles = {}
local FPS = 0
local player = Players.LocalPlayer

--// Library Setup
-- RichText is handled natively by the UI library now (labels, watermark, notifications).
Library.RichText = true

-- Staff detection overlay (created once, toggled from the Misc tab)
local StaffOverlay = Library:CreateModListOverlay({
	Title = "Staff Watch",
	CheckInterval = 5,
	NotifyOnJoin = true,
})

--// UI Creation
local Window = Library:CreateWindow({
	Title = 'Shade<font color="#5a8cd7">.Luau</font> <font color="#909397">|</font> Infected Lands',
	Center = true,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0.2,
})

local Tabs = {
	CombatTab = Window:AddTab("Combat"),
	VisualsTab = Window:AddTab("Visuals"),
	MiscTab = Window:AddTab("Misc"),
	PlayerTab = Window:AddTab("Player"),
	SettingsTab = Window:AddTab("Settings"),
}

--// Feature Functions
local function applyNoRecoil(tool)
	if not config.NoRecoil or not tool:IsA("Tool") then
		return
	end
	local configModule = tool:FindFirstChild("WeaponConfig")
	if not configModule then
		return
	end
	local statsModule = configModule:FindFirstChild("WeaponStats")
	if not statsModule or not statsModule:IsA("ModuleScript") then
		return
	end

	local stats = require(statsModule)
	if type(stats.recoil) == "table" then
		stats.recoil.vertical = 0
		stats.recoil.horizontal = 0
		stats.recoil.camShake = 0
		stats.gunRecoil.vertical = 0
		stats.gunRecoil.horizontal = 0
		stats.gunRecoil.punchMultiplier = 0
		stats.spread = 0
		stats.moveSpread = 0
		stats.hipFireSpread = 0
		stats.hipFireMoveSpread = 0
		stats.aimSpreadMultiplier = 0
	end
end

local function hookTool(tool)
	if tool:IsA("Tool") then
		local plr = Players.LocalPlayer
		if plr and plr.Character and tool.Parent == plr.Character then
			applyNoRecoil(tool)
		end
		tool.Equipped:Connect(function()
			applyNoRecoil(tool)
		end)
	end
end

local function watchContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		hookTool(child)
	end
	container.ChildAdded:Connect(hookTool)
end

local function refreshNoRecoil()
	local plr = Players.LocalPlayer
	if not plr then
		return
	end
	local character = plr.Character
	if character then
		for _, tool in ipairs(character:GetChildren()) do
			applyNoRecoil(tool)
		end
	end
	for _, tool in ipairs(plr.Backpack:GetChildren()) do
		applyNoRecoil(tool)
	end
end

local function applyJumpLock()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(
			Enum.HumanoidStateType.Jumping,
			not (config.Speed.Enabled and config.Speed.LockJump)
		)
	end
end

--// UI Tabs
local CombatGroup = Tabs.CombatTab:AddLeftGroupbox("Aimbot")
toggles.Aimbot = CombatGroup:AddToggle("AimbotEnabled", {
	Text = "Enabled",
	Default = false,
	Tooltip = "Aimbot for Infected Lands",
	Callback = function(v)
		config.Aimbot.Enabled = v
	end,
})

local WeaponGroup = Tabs.CombatTab:AddRightGroupbox("Weapon Mods")
toggles.NoRecoil = WeaponGroup:AddToggle("NoRecoil", {
	Text = "No Recoil",
	Default = false,
	Tooltip = "Removes recoil and spread from weapons",
	Callback = function(v)
		config.NoRecoil = v
		if v then
			refreshNoRecoil()
		end
	end,
})

local PlayerGroup = Tabs.PlayerTab:AddLeftGroupbox("Survival")
toggles.InfiniteStamina = PlayerGroup:AddToggle("InfiniteStamina", {
	Text = "Infinite Stamina",
	Default = false,
	Tooltip = "Keeps stamina at maximum",
	Callback = function(v)
		config.InfiniteStamina = v
	end,
})
toggles.InfiniteHunger = PlayerGroup:AddToggle("InfiniteHunger", {
	Text = "Infinite Hunger",
	Default = false,
	Tooltip = "Keeps hunger at maximum",
	Callback = function(v)
		config.InfiniteHunger = v
	end,
})
toggles.InfiniteThirst = PlayerGroup:AddToggle("InfiniteThirst", {
	Text = "Infinite Thirst",
	Default = false,
	Tooltip = "Keeps thirst at maximum",
	Callback = function(v)
		config.InfiniteThirst = v
	end,
})

local MovementGroup = Tabs.PlayerTab:AddRightGroupbox("Movement")
toggles.Speed = MovementGroup:AddToggle("Speed", {
	Text = "Speed Boost",
	Default = false,
	Tooltip = "CFrame-based speed multiplier (server tolerated up to 3x)",
	Callback = function(v)
		config.Speed.Enabled = v
		applyJumpLock()
	end,
})
MovementGroup:AddSlider("SpeedMultiplier", {
	Text = "Multiplier",
	Default = 2,
	Min = 1,
	Max = 3,
	Rounding = 1,
	Tooltip = "Recommended max 2.0-2.5x; 3.0x survived probe but is riskier",
	Callback = function(v)
		config.Speed.Multiplier = v
	end,
})
	toggles.Speed:AddKeyPicker("SpeedKeybind", {
		Default = "CapsLock",
		Text = "Speed Boost",
		Mode = "Toggle",
		Callback = function(v)
			toggles.Speed:SetValue(v)
		end,
	})
	toggles.SpeedLockJump = MovementGroup:AddToggle("SpeedLockJump", {
	Text = "Lock Jump During Speed",
	Default = true,
	Callback = function(v)
		config.Speed.LockJump = v
		applyJumpLock()
	end,
})

local VisualsGroup = Tabs.VisualsTab:AddLeftGroupbox("MiniMap")
toggles.MiniMap = VisualsGroup:AddToggle("MiniMap", {
	Text = "Adjust MiniMap",
	Default = false,
	Tooltip = "Resize and reposition the minimap",
	Callback = function(v)
		config.MiniMap.Enabled = v
	end,
})
VisualsGroup:AddButton("Reset MiniMap Position", function()
	config.MiniMap.Position = UDim2.fromScale(0.905, 0.18)
	config.MiniMap.Scale = UDim2.fromOffset(350, 350)
	toggles.MiniMap:SetValue(false)
end)

local StaffGroup = Tabs.MiscTab:AddRightGroupbox("Staff Detector")
toggles.StaffWatch = StaffGroup:AddToggle("StaffWatch", {
	Text = "Staff Watch Overlay",
	Default = false,
	Tooltip = "Shows an overlay listing moderators/admins in the server and notifies when one joins",
	Callback = function(v)
		StaffOverlay:SetVisible(v)
	end,
})

local ServerGroup = Tabs.MiscTab:AddLeftGroupbox("Server")
ServerGroup:AddButton("Rejoin", function()
	if config.KeepScriptOnRejoin then
		queue_on_teleport("print('Rejoining server with Shade.Luau loaded...')") --// Replace with Shade Loadstring
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Players.LocalPlayer)
	else
		clear_teleport_queue()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Players.LocalPlayer)
	end
end)
ServerGroup:AddToggle("KeepScriptOnRejoin", {
	Text = "Keep Script On Rejoin",
	Default = false,
	Tooltip = "Keeps Shade.Luau loaded when rejoining the server",
	Callback = function(v)
		config.KeepScriptOnRejoin = v
	end,
})

local MenuGroup = Tabs.SettingsTab:AddLeftGroupbox("Menu")
MenuGroup:AddButton("Unload", function()
	Library:Unload()
end)
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
	Default = "RS",
	NoUI = true,
	Text = "Menu keybind",
})
Library.ToggleKeybind = config.MenuKeybind

--// Watermark
Library:SetWatermarkVisibility(true)
Library.Watermark.Position = UDim2.fromOffset(15, 5)

Library:SetWatermark(
	'Shade<font color="#5a8cd7">.Luau</font> <font color="#909397">|</font> .. fps <font color="#909397">|</font> .. ms'
)

task.spawn(function()
	while task.wait(1) do
		Library:SetWatermark(
			('Shade<font color="#5a8cd7">.Luau</font> <font color="#909397">|</font> %d fps <font color="#909397">|</font> %d ms'):format(
				math.floor(FPS),
				math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
			)
		)
		FPS = 0
	end
end)

--// Feature Connections
local renderConnection = RunService.RenderStepped:Connect(function()
	FPS = FPS + 1

	if not player then
		return
	end

	if config.InfiniteStamina then
		player:SetAttribute("Stamina", 100)
		player:SetAttribute("StaminaExhausted", false)
	end
	if config.InfiniteHunger then
		player:SetAttribute("Hunger", 100)
	end
	if config.InfiniteThirst then
		player:SetAttribute("Thirst", 100)
	end

	if config.InfiniteStamina or config.InfiniteHunger or config.InfiniteThirst then
		local survivalBlur = Lighting:FindFirstChild("SurvivalDepletionBlur")
		if survivalBlur then
			survivalBlur.Enabled = false
		end
		local staminaBlur = Lighting:FindFirstChild("LowStaminaBlur")
		if staminaBlur then
			staminaBlur.Enabled = false
		end
	end

	if config.MiniMap.Enabled then
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		local mapContainer = playerGui and playerGui:FindFirstChild("MapUI")
		local mapUI = mapContainer and mapContainer:FindFirstChild("Map")
		local backdrop = mapContainer and mapContainer:FindFirstChild("Backdrop")

		if mapUI and mapUI:IsA("GuiObject") and mapUI.Visible then
			if backdrop and backdrop:IsA("GuiObject") then
				backdrop.Visible = false
			end
			mapUI.Size = config.MiniMap.Scale
			mapUI.Position = config.MiniMap.Position
		end
	end
end)
table.insert(connections, renderConnection)

--// Speed Connection (CFrame mover, ground-only)
local speedConnection = RunService.Heartbeat:Connect(function(dt)
	if not config.Speed.Enabled then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local dir = humanoid.MoveDirection
	if dir.Magnitude < 0.01 then
		return
	end
	if not humanoid.FloorMaterial or humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	root.CFrame = root.CFrame + (dir.Unit * humanoid.WalkSpeed * dt) * (config.Speed.Multiplier - 1)
end)
table.insert(connections, speedConnection)

--// Tool Watching
if player then
	player:SetAttribute("MaxStamina", 100)
	player:SetAttribute("Stamina", 100)
	player:SetAttribute("StaminaExhausted", false)
	player:SetAttribute("MaxHunger", 100)
	player:SetAttribute("MaxThirst", 100)
	player:SetAttribute("Hunger", 100)
	player:SetAttribute("Thirst", 100)

	watchContainer(player.Backpack)
	local character = player.Character
	if character then
		watchContainer(character)
	end
	player.CharacterAdded:Connect(function(char)
		watchContainer(char)
		char:WaitForChild("Humanoid")
		applyJumpLock()
	end)
end

--// Unload
Library.KeybindFrame.Visible = false
Library:OnUnload(function()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
	_G.ShadeLoaded = false
	print("Unloaded!")
	Library.Unloaded = true
end)

Library.AccentColor = config.AccentColor
Library:Notify("Loaded Shade.Luau | Infected Lands")

--// Theme & Save Manager
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("Shade.luau")
SaveManager:SetFolder("Shade.luau/Infected_Lands")
SaveManager:BuildConfigSection(Tabs.SettingsTab)
ThemeManager:ApplyToTab(Tabs.SettingsTab)
SaveManager:LoadAutoloadConfig()
