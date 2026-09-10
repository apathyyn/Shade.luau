--// Services
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local TextService = game:GetService("TextService")

local ALLOWED_PLACE_ID = PLACE_ID_HERE
if game.PlaceId ~= ALLOWED_PLACE_ID then
	warn("Shade.Luau: Incorrect game. Script not executed.")
	return
end

if _G.ShadeLuauLoaded then
	Library:Notify("Shade.Luau is already loaded.")
	warn("Shade.Luau: Already loaded.")
	return
end

--// Variables
local UiRepo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
local Library = loadstring(game:HttpGet(UiRepo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(UiRepo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(UiRepo .. "addons/SaveManager.lua"))()

_G.ShadeLuauLoaded = true
local config = {
	MenuKeybind = Enum.KeyCode.RightShift,
	AccentColor = Color3.fromRGB(90, 140, 215),
	NoRecoil = false,
	InfiniteStamina = false,
	InfiniteHunger = false,
	InfiniteThirst = false,
	MiniMap = {
		Enabled = false,
		Position = UDim2.fromScale(0.905, 0.18),
		Scale = UDim2.fromOffset(350, 350),
	},
}

local connections = {}
local toggles = {}
local FPS = 0

--// Library Setup
local oldCreateLabel = Library.CreateLabel
function Library:CreateLabel(...)
	local label = oldCreateLabel(self, ...)
	label.RichText = true
	return label
end

local oldSetWatermark = Library.SetWatermark
function Library:SetWatermark(text)
	oldSetWatermark(self, text)
	if self.Watermark and self.WatermarkText then
		self.WatermarkText.RichText = true
		local cleanText = text:gsub("<[^>]+>", "")
		local textSize = TextService:GetTextSize(
			cleanText,
			self.WatermarkText.TextSize,
			self.WatermarkText.Font,
			Vector2.new(math.huge, math.huge)
		)
		self.Watermark.Size = UDim2.fromOffset(textSize.X + 15, 22)
	end
end

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
		if tool.Parent == player.Character then
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
	local player = Players.LocalPlayer
	if not player then
		return
	end
	local character = player.Character
	if character then
		for _, tool in ipairs(character:GetChildren()) do
			applyNoRecoil(tool)
		end
	end
	for _, tool in ipairs(player.Backpack:GetChildren()) do
		applyNoRecoil(tool)
	end
end

--// UI Creation
local CombatGroup = Tabs.CombatTab:AddLeftGroupbox("Combat")
toggles.NoRecoil = CombatGroup:AddToggle("NoRecoil", {
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
if Library.Watermark then
	Library.WatermarkText.RichText = true
end

task.spawn(function()
	Library:SetWatermark(
		'Shade<font color="#5a8cd7">.Luau</font> <font color="#909397">|</font> .. fps <font color="#909397">|</font> .. ms'
	)
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
table.insert(
	connections,
	RunService.RenderStepped:Connect(function()
		FPS = FPS + 1
	end)
)

table.insert(
	connections,
	RunService.RenderStepped:Connect(function()
		local player = Players.LocalPlayer
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
)

--// Tool Watching
local player = Players.LocalPlayer
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
	player.CharacterAdded:Connect(function(newChar)
		watchContainer(newChar)
	end)
end

--// Unload
Library.KeybindFrame.Visible = false
Library:OnUnload(function()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	print("Unloaded!")
	Library.Unloaded = true
	_G.ShadeLuauLoaded = false
end)

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
