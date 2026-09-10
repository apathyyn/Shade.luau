--// Variables
local player = game:GetService("Players").LocalPlayer
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local connections = {}
local pos = UDim2.fromScale(0.905, 0.18)
local size = UDim2.fromOffset(350, 350)

--// Functions
local function applyNoRecoil(tool)
	if not tool:IsA("Tool") then
		return
	end
	local config = tool:FindFirstChild("WeaponConfig")
	if not config then
		return
	end
	local statsModule = config:FindFirstChild("WeaponStats")
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

--// Stamina & Survival Setup
player:SetAttribute("MaxStamina", 100)
player:SetAttribute("Stamina", 100)
player:SetAttribute("StaminaExhausted", false)
player:SetAttribute("MaxHunger", 100)
player:SetAttribute("MaxThirst", 100)
player:SetAttribute("Hunger", 100)
player:SetAttribute("Thirst", 100)

--// Connections
table.insert(
	connections,
	RunService.RenderStepped:Connect(function()
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		local mapContainer = playerGui and playerGui:FindFirstChild("MapUI")
		local mapUI = mapContainer and mapContainer:FindFirstChild("Map")
		local backdrop = mapContainer and mapContainer:FindFirstChild("Backdrop")

		if mapUI and mapUI:IsA("GuiObject") and mapUI.Visible then
			if backdrop and backdrop:IsA("GuiObject") then
				backdrop.Visible = false
			end
			mapUI.Size = size
			mapUI.Position = pos
		end

		if player:GetAttribute("Stamina") < 100 then
			player:SetAttribute("Stamina", 100)
		end
		player:SetAttribute("StaminaExhausted", false)
		player:SetAttribute("Hunger", 100)
		player:SetAttribute("Thirst", 100)

		if Lighting:FindFirstChild("SurvivalDepletionBlur") then
			Lighting.SurvivalDepletionBlur.Enabled = false
		end
		if Lighting:FindFirstChild("LowStaminaBlur") then
			Lighting.LowStaminaBlur.Enabled = false
		end
	end)
)

watchContainer(player.Backpack)

local character = player.Character
if character then
	watchContainer(character)
end

player.CharacterAdded:Connect(function(newChar)
	watchContainer(newChar)
end)

--// Unload
_G.UnloadShade = function()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}
end
