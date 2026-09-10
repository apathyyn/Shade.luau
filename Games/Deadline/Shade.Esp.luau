--// Services
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--// Variables
local CharacterFolder = Workspace:WaitForChild("characters")
local IgnoreFolder = Workspace:FindFirstChild("ignore")
local HighlightCache = {}
local ModelConnections = {}

local ChildAddedConnection
local ChildRemovedConnection
local RenderSteppedConnection

--// Functions
local function Cleanup(model)
	if HighlightCache[model] then
		HighlightCache[model]:Destroy()
		HighlightCache[model] = nil
	end

	if ModelConnections[model] then
		ModelConnections[model]:Disconnect()
		ModelConnections[model] = nil
	end
end

local function IsVisible(model)
	local camera = Workspace.CurrentCamera
	if not camera then
		return false
	end

	local rootPart = model:FindFirstChild("humanoid_root_part")
	if not rootPart then
		return false
	end

	local screenPosition, onScreen = camera:WorldToScreenPoint(rootPart.Position)
	if not onScreen then
		return false
	end

	local viewportSize = camera.ViewportSize
	return screenPosition.X >= 0
		and screenPosition.X <= viewportSize.X
		and screenPosition.Y >= 0
		and screenPosition.Y <= viewportSize.Y
end

local function Setup(model)
	if
		not model:IsA("Model")
		or model.Name == "StarterCharacter"
		or HighlightCache[model]
		or (IgnoreFolder and model:IsDescendantOf(IgnoreFolder))
	then
		return
	end

	if not model:WaitForChild("humanoid_root_part", 1) then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "_{2axm2mh6a8HM2htdjIpl1niVYIlxbQ}_"
	highlight.Adornee = model
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 1
	highlight.Parent = model

	HighlightCache[model] = highlight

	local ancestryConnection
	ancestryConnection = model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			Cleanup(model)
		end
	end)
	ModelConnections[model] = ancestryConnection
end

--// Connections
ChildAddedConnection = CharacterFolder.ChildAdded:Connect(function(child)
	task.wait(0.1)
	Setup(child)
end)

ChildRemovedConnection = CharacterFolder.ChildRemoved:Connect(Cleanup)

for _, child in ipairs(CharacterFolder:GetChildren()) do
	Setup(child)
end

RenderSteppedConnection = RunService.RenderStepped:Connect(function()
	local espEnabled = _G.ESP_ENABLED
	if espEnabled == nil then
		espEnabled = true
	end

	for model, highlight in pairs(HighlightCache) do
		if not model.Parent then
			Cleanup(model)
			continue
		end

		highlight.Enabled = espEnabled and IsVisible(model)
	end
end)

--// Unload Function
_G.UnloadESP = function()
	if ChildAddedConnection then
		ChildAddedConnection:Disconnect()
		ChildAddedConnection = nil
	end
	if ChildRemovedConnection then
		ChildRemovedConnection:Disconnect()
		ChildRemovedConnection = nil
	end
	if RenderSteppedConnection then
		RenderSteppedConnection:Disconnect()
		RenderSteppedConnection = nil
	end

	for model in pairs(HighlightCache) do
		Cleanup(model)
	end

	_G.UnloadESP = nil
	_G.ESP_ENABLED = nil
end
