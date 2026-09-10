--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

--// Configuration
local config = {
	fov_size = 75,
	aimbot_enabled = true,
	aim_part = "head",
	smoothness = 0.7,
	smoothing_curve = "Linear",
	team_check = true, -- only GUI method
	wall_check = false, -- uses workspace.map when enabled
	prediction = 0.12,
	esp_enabled = false,
	name_esp_enabled = false,
	esp_team_check = true,
	box_esp_enabled = false,
	box_esp_color = Color3.fromRGB(255, 255, 255),
	box_esp_thickness = 2,
	fov_circle_only_aiming = false,
	no_recoil = false,
	fov_color = Color3.fromRGB(54, 57, 241),
	esp_color = Color3.fromRGB(255, 0, 0),
}

--// Drawing objects
local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1
fov_circle.NumSides = 100
fov_circle.Radius = config.fov_size
fov_circle.Filled = false
fov_circle.Visible = true
fov_circle.ZIndex = 999
fov_circle.Transparency = 1
fov_circle.Color = config.fov_color

--// Caches
local esp_cache = {}
local name_esp_cache = {}
local box_esp_cache = {}
local teammate_players = {} -- [Player] = true if teammate (from GUI)
local char_to_name = {} -- [Character] = display name from GUI
local frame_to_char = {} -- [Frame] = Character
local players_cache = {}
local char_to_player = {}
local last_team_update = 0
local TEAM_UPDATE_INTERVAL = 0.5

--// Color presets
local color_presets = {
	Red = Color3.fromRGB(255, 0, 0),
	Green = Color3.fromRGB(0, 255, 0),
	Blue = Color3.fromRGB(0, 0, 255),
	Yellow = Color3.fromRGB(255, 255, 0),
	White = Color3.fromRGB(255, 255, 255),
	Cyan = Color3.fromRGB(0, 255, 255),
	Magenta = Color3.fromRGB(255, 0, 255),
	Orange = Color3.fromRGB(255, 165, 0),
}

--// Get characters folder
local charactersFolder = Workspace:FindFirstChild("characters")
if not charactersFolder then
	error("characters folder not found")
end

--// Get map (for wall check)
local map = Workspace:FindFirstChild("map")
if not map then
	warn("No 'map' found in Workspace. Wall check will not work.")
end

--// ========== PERFORMANCE: Cache Players ==========
local function updatePlayersCache()
	players_cache = Players:GetPlayers()
	char_to_player = {}
	for _, player in ipairs(players_cache) do
		if player.Character then
			char_to_player[player.Character] = player
		end
	end
end
updatePlayersCache()
Players.PlayerAdded:Connect(updatePlayersCache)
Players.PlayerRemoving:Connect(updatePlayersCache)
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		char_to_player[char] = player
	end)
end)

--// ========== GUI TEAM DETECTION (ONLY METHOD) ==========
local function findTeamLabelFrame()
	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	if not gui then
		return nil
	end
	for _, screenGui in ipairs(gui:GetChildren()) do
		if screenGui:IsA("ScreenGui") then
			local mainFrame = screenGui:FindFirstChild("Frame")
			if mainFrame and mainFrame:IsA("Frame") then
				for _, child in ipairs(mainFrame:GetChildren()) do
					if child:IsA("Frame") and child:FindFirstChild("1") then
						return mainFrame
					end
				end
			end
		end
	end
	return nil
end

local function updateTeammates()
	local mainFrame = findTeamLabelFrame()
	if not mainFrame then
		teammate_players = {}
		char_to_name = {}
		frame_to_char = {}
		return
	end

	local labelEntries = {}
	for _, playerFrame in ipairs(mainFrame:GetChildren()) do
		if playerFrame:IsA("Frame") then
			-- Extract player name: first try frame.playername (child), then TextLabel, then frame.Name
			local playerName = nil
			local label = playerFrame:FindFirstChildWhichIsA("TextLabel")
			playerName = label and label.Text or playerFrame.Name

			if playerName and playerName ~= "" then
				local posFrame = playerFrame:FindFirstChild("1")
				if posFrame and posFrame:IsA("Frame") then
					local absPos = posFrame.AbsolutePosition
					local absSize = posFrame.AbsoluteSize
					if absPos.X > 0 and absPos.Y > 0 then
						local center = absPos + absSize / 2
						table.insert(labelEntries, { pos = center, name = playerName, frame = playerFrame })
					end
				end
			end
		end
	end

	local charScreenPositions = {}
	local charDistances = {}
	for _, char in ipairs(charactersFolder:GetChildren()) do
		if char:IsA("Model") then
			local rootPart = char --:FindFirstChild("humanoid_root_part") or char:FindFirstChild("torso")
			if rootPart and rootPart:IsA("Model") then
				local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
				if onScreen then
					charScreenPositions[char] = Vector2.new(screenPos.X, screenPos.Y)
					charDistances[char] = (Camera.CFrame.Position - rootPart.Position).Magnitude
				end
			end
		end
	end

	local newTeammates = {}
	local newCharToName = {}
	local newFrameToChar = {}
	local usedChars = {}

	-- First pass: direct name matching
	for _, entry in ipairs(labelEntries) do
		for _, player in ipairs(players_cache) do
			if
				string.lower(player.Name) == string.lower(entry.name)
				or string.lower(player.DisplayName) == string.lower(entry.name)
			then
				local char = player.Character
				if char and charScreenPositions[char] and not usedChars[char] then
					newTeammates[player] = true
					newCharToName[char] = entry.name
					newFrameToChar[entry.frame] = char
					usedChars[char] = true
					break
				end
			end
		end
	end

	-- Second pass: screen proximity
	local screenThreshold = 5
	for _, entry in ipairs(labelEntries) do
		if not entry.matched then
			local bestChar = nil
			local bestScore = math.huge
			for char, screenPos in pairs(charScreenPositions) do
				if not usedChars[char] then
					local screenDist = (entry.pos - screenPos).Magnitude
					if screenDist <= screenThreshold then
						local worldDist = charDistances[char] or 9999
						local score = screenDist * 2 + worldDist * 0.1
						if score < bestScore then
							bestScore = score
							bestChar = char
						end
					end
				end
			end
			if bestChar then
				usedChars[bestChar] = true
				local player = char_to_player[bestChar]
				if player then
					newTeammates[player] = true
				end
				newCharToName[bestChar] = entry.name
				newFrameToChar[entry.frame] = bestChar
			end
		end
	end

	teammate_players = newTeammates
	char_to_name = newCharToName
	frame_to_char = newFrameToChar
end

local function isTeammate(player)
	if player == LocalPlayer then
		return true
	end
	return teammate_players[player] == true
end

local function isEnemyCharacter(character)
	if not config.team_check then
		return true
	end
	local player = char_to_player[character]
	if not player then
		-- If we have GUI mapping, treat as teammate if present; otherwise enemy
		if char_to_name[character] then
			return false
		end
		return true
	end
	return not isTeammate(player)
end

--// ========== WALL CHECK (uses workspace.map only) ==========
local function isVisible(character, target_part)
	if not config.wall_check then
		return true
	end
	local local_char = LocalPlayer.Character
	if not local_char then
		return true
	end
	if not map then
		return true
	end

	local origin = Camera.CFrame.Position
	local direction = target_part.Position - origin

	local raycast_params = RaycastParams.new()
	raycast_params.FilterType = Enum.RaycastFilterType.Include
	raycast_params.FilterDescendantsInstances = { map }

	local result = Workspace:Raycast(origin, direction, raycast_params)
	return result == nil
end

--// ========== AIMBOT ==========
local function applySmoothingCurve(delta, curve)
	if curve == "Linear" then
		return delta
	elseif curve == "Quadratic" then
		local magnitude = delta.Magnitude
		if magnitude == 0 then
			return delta
		end
		local normalized = delta / magnitude
		return normalized * (magnitude * magnitude)
	elseif curve == "Exponential" then
		local magnitude = delta.Magnitude
		if magnitude == 0 then
			return delta
		end
		local normalized = delta / magnitude
		return normalized * (1 - math.exp(-magnitude * 5))
	end
	return delta
end

local function getClosestTarget()
	local closestPart = nil
	local shortestDist = config.fov_size
	local mousePos = UserInputService:GetMouseLocation()

	for _, char in ipairs(charactersFolder:GetChildren()) do
		if char:IsA("Model") and char ~= LocalPlayer.Character and isEnemyCharacter(char) then
			local targetPart = char:FindFirstChild(config.aim_part)
			if targetPart and targetPart:IsA("BasePart") then
				if not isVisible(char, targetPart) then
					continue
				end

				local predictedPos = targetPart.Position
				if targetPart.Velocity then
					predictedPos = predictedPos + targetPart.Velocity * config.prediction
				end

				local screenPos, onScreen = Camera:WorldToViewportPoint(predictedPos)
				if onScreen then
					local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
					if dist < shortestDist then
						shortestDist = dist
						closestPart = targetPart
					end
				end
			end
		end
	end
	return closestPart
end

--// ========== NO RECOIL ==========
local function applyNoRecoil()
	pcall(function()
		local stats = require(ReplicatedStorage.module.shared_state).SHARED_STATE
		if type(stats.plr_recoil) then
			stats.plr_recoil.value = 0
		end
	end)
end

--// ========== ESP FUNCTIONS (with name scaling) ==========
local function updateNameESP()
	if not config.name_esp_enabled then
		for _, obj in pairs(name_esp_cache) do
			if obj then
				obj:Remove()
			end
		end
		name_esp_cache = {}
		return
	end

	local color = config.esp_color
	local local_char = LocalPlayer.Character
	local existing = {}

	for _, char in ipairs(charactersFolder:GetChildren()) do
		if char:IsA("Model") and char ~= local_char then
			if config.esp_team_check and not isEnemyCharacter(char) then
				if name_esp_cache[char] then
					name_esp_cache[char].Visible = false
				end
				continue
			end

			local headPart = char:FindFirstChild("head") or char:FindFirstChild("Head")
			local rootPart = char:FindFirstChild("humanoid_root_part")
				or char:FindFirstChild("torso")
				or char:FindFirstChild("HumanoidRootPart")
				or char:FindFirstChild("Torso")

			if not rootPart or not rootPart:IsA("BasePart") then
				if name_esp_cache[char] then
					name_esp_cache[char].Visible = false
				end
				continue
			end

			local espPosition = (headPart and headPart.Position or rootPart.Position) + Vector3.new(0, 1.5, 0)
			local screenPos, onScreen = Camera:WorldToViewportPoint(espPosition)
			if onScreen then
				local distance = (Camera.CFrame.Position - rootPart.Position).Magnitude
				local fontSize = math.clamp(30 / (distance * 0.8), 12, 30)
				local name = char_to_name[char] or char.Name

				local textObj = name_esp_cache[char]
				if not textObj then
					textObj = Drawing.new("Text")
					textObj.Visible = true
					textObj.Center = true
					textObj.Outline = true
					textObj.OutlineColor = Color3.new(0, 0, 0)
					textObj.Color = color
					textObj.Font = 1
					name_esp_cache[char] = textObj
				end

				textObj.Text = name
				textObj.Position = Vector2.new(screenPos.X, screenPos.Y)
				textObj.Color = color
				textObj.Size = fontSize
				textObj.Visible = true
				existing[char] = true
			else
				if name_esp_cache[char] then
					name_esp_cache[char].Visible = false
				end
			end
		end
	end

	for char, obj in pairs(name_esp_cache) do
		if not existing[char] then
			obj:Remove()
			name_esp_cache[char] = nil
		end
	end
end

local function updateBoxESP()
	if not config.box_esp_enabled then
		for _, obj in pairs(box_esp_cache) do
			if obj then
				obj:Remove()
			end
		end
		box_esp_cache = {}
		return
	end
	local color = config.box_esp_color
	local thickness = config.box_esp_thickness
	local local_char = LocalPlayer.Character
	local existing = {}
	for _, char in ipairs(charactersFolder:GetChildren()) do
		if char:IsA("Model") and char ~= local_char then
			local rootPart = char:FindFirstChild("humanoid_root_part") or char:FindFirstChild("torso")
			if not rootPart or not rootPart:IsA("BasePart") then
				continue
			end
			if config.esp_team_check and not isEnemyCharacter(char) then
				continue
			end
			local headPart = char:FindFirstChild("head") or rootPart
			local bottomPos = rootPart.Position - Vector3.new(0, 3, 0)
			local topPos = headPart.Position + Vector3.new(0, 0.5, 0)
			local bottomScreen, bottomOn = Camera:WorldToViewportPoint(bottomPos)
			local topScreen, topOn = Camera:WorldToViewportPoint(topPos)
			if bottomOn and topOn then
				local box = box_esp_cache[char]
				if not box then
					box = Drawing.new("Square")
					box.Thickness = thickness
					box.Filled = false
					box.Color = color
					box.Visible = true
					box.ZIndex = 998
					box_esp_cache[char] = box
				end
				local height = math.abs(topScreen.Y - bottomScreen.Y)
				local width = height * 0.6
				local centerX = (bottomScreen.X + topScreen.X) / 2
				local topY = topScreen.Y
				box.Size = Vector2.new(width, height)
				box.Position = Vector2.new(centerX - width / 2, topY)
				box.Color = color
				box.Thickness = thickness
				box.Visible = true
				existing[char] = true
			else
				if box_esp_cache[char] then
					box_esp_cache[char].Visible = false
				end
			end
		end
	end
	for char, obj in pairs(box_esp_cache) do
		if not existing[char] then
			obj:Remove()
			box_esp_cache[char] = nil
		end
	end
end

local function updateHighlightESP()
	if not config.esp_enabled then
		for char, hl in pairs(esp_cache) do
			if hl then
				hl:Destroy()
			end
		end
		esp_cache = {}
		return
	end
	local color = config.esp_color
	local local_char = LocalPlayer.Character
	for _, char in ipairs(charactersFolder:GetChildren()) do
		if char:IsA("Model") and char ~= local_char then
			if config.esp_team_check and not isEnemyCharacter(char) then
				if esp_cache[char] then
					esp_cache[char]:Destroy()
					esp_cache[char] = nil
				end
			else
				if not esp_cache[char] then
					local hl = Instance.new("Highlight")
					hl.Name = "__shade_esp"
					hl.Adornee = char
					hl.FillColor = color
					hl.FillTransparency = 0.7
					hl.OutlineTransparency = 1
					hl.Parent = char
					esp_cache[char] = hl
				else
					esp_cache[char].FillColor = color
				end
			end
		end
	end
end

--// ========== UI ==========
local Library =
	loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua"))()
if not Library then
	error("Failed to load LinoriaLib")
end

local dark_theme = {
	Main = Color3.fromRGB(32, 34, 37),
	Text = Color3.fromRGB(210, 212, 215),
	Subtext = Color3.fromRGB(150, 152, 156),
	Tab = Color3.fromRGB(42, 45, 48),
	TabText = Color3.fromRGB(210, 212, 215),
	Button = Color3.fromRGB(52, 55, 59),
	ButtonText = Color3.fromRGB(210, 212, 215),
	Accent = Color3.fromRGB(54, 57, 241),
	Element = Color3.fromRGB(42, 45, 48),
	ElementText = Color3.fromRGB(210, 212, 215),
	Border = Color3.new(0, 0, 0),
	Frame = Color3.fromRGB(24, 26, 28),
}
pcall(function()
	Library:SetTheme(dark_theme)
end)

local Window = Library:CreateWindow({
	Title = "Shade",
	Center = true,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0.2,
})

local AimbotTab = Window:AddTab("Aimbot")
local ESPTab = Window:AddTab("ESP")
local MiscTab = Window:AddTab("Misc")
local AimbotGeneral = AimbotTab:AddLeftTabbox("General")
local ESPTabBox = ESPTab:AddLeftTabbox("Main")
local ESPBox = ESPTabBox:AddTab("ESP Settings")
local MiscBox = MiscTab:AddLeftTabbox("Miscellaneous")

--// UI - Aimbot
do
	local Main = AimbotGeneral:AddTab("General")
	Main:AddToggle("aimbot_enabled", { Text = "Aimbot", Default = config.aimbot_enabled }):OnChanged(function()
		config.aimbot_enabled = Toggles.aimbot_enabled.Value
	end)
	Main:AddToggle("team_check", { Text = "Team Check (GUI)", Default = config.team_check }):OnChanged(function()
		config.team_check = Toggles.team_check.Value
	end)
	Main:AddToggle("wall_check", { Text = "Wall Check (Map Only)", Default = config.wall_check }):OnChanged(function()
		config.wall_check = Toggles.wall_check.Value
	end)
	Main:AddDropdown("aim_part", {
		Text = "Target Part",
		Default = config.aim_part,
		Values = { "head", "torso" },
	}):OnChanged(function()
		config.aim_part = Options.aim_part.Value
	end)
	Main:AddSlider("smoothness", {
		Text = "Smoothness",
		Default = config.smoothness,
		Min = 0.01,
		Max = 1,
		Rounding = 2,
	}):OnChanged(function()
		config.smoothness = Options.smoothness.Value
	end)
	Main:AddDropdown("smoothing_curve", {
		Text = "Smoothing Curve",
		Default = config.smoothing_curve,
		Values = { "Linear", "Quadratic", "Exponential" },
	}):OnChanged(function()
		config.smoothing_curve = Options.smoothing_curve.Value
	end)
	Main:AddSlider("fov_size", {
		Text = "FOV Size",
		Default = config.fov_size,
		Min = 0,
		Max = 1000,
		Rounding = 0,
	}):OnChanged(function()
		config.fov_size = Options.fov_size.Value
		fov_circle.Radius = config.fov_size
	end)
	Main:AddToggle("fov_circle_only_aiming", {
		Text = "Show FOV Only When Aiming",
		Default = config.fov_circle_only_aiming,
	}):OnChanged(function()
		config.fov_circle_only_aiming = Toggles.fov_circle_only_aiming.Value
	end)
	Main:AddSlider("prediction", {
		Text = "Prediction",
		Default = config.prediction,
		Min = 0,
		Max = 1,
		Rounding = 2,
	}):OnChanged(function()
		config.prediction = Options.prediction.Value
	end)

	local ColorTab = AimbotGeneral:AddTab("Colors")
	ColorTab:AddDropdown("fov_color", {
		Text = "FOV Color",
		Default = "Blue",
		Values = { "Red", "Green", "Blue", "Yellow", "White", "Cyan", "Magenta", "Orange" },
	}):OnChanged(function()
		config.fov_color = color_presets[Options.fov_color.Value]
		fov_circle.Color = config.fov_color
	end)
	ColorTab:AddDropdown("esp_color", {
		Text = "ESP Color",
		Default = "Red",
		Values = { "Red", "Green", "Blue", "Yellow", "White", "Cyan", "Magenta", "Orange" },
	}):OnChanged(function()
		config.esp_color = color_presets[Options.esp_color.Value]
		for _, hl in pairs(esp_cache) do
			if hl then
				hl.FillColor = config.esp_color
			end
		end
		for _, obj in pairs(name_esp_cache) do
			if obj then
				obj.Color = config.esp_color
			end
		end
	end)
end

--// UI - ESP
do
	ESPBox:AddToggle("esp_enabled", { Text = "Highlight ESP", Default = config.esp_enabled }):OnChanged(function()
		config.esp_enabled = Toggles.esp_enabled.Value
		updateHighlightESP()
	end)
	ESPBox:AddToggle("name_esp_enabled", { Text = "Name ESP", Default = config.name_esp_enabled }):OnChanged(function()
		config.name_esp_enabled = Toggles.name_esp_enabled.Value
		if not config.name_esp_enabled then
			for _, obj in pairs(name_esp_cache) do
				if obj then
					obj:Remove()
				end
			end
			name_esp_cache = {}
		end
	end)
	ESPBox:AddToggle("box_esp_enabled", { Text = "Box ESP", Default = config.box_esp_enabled }):OnChanged(function()
		config.box_esp_enabled = Toggles.box_esp_enabled.Value
		if not config.box_esp_enabled then
			for _, obj in pairs(box_esp_cache) do
				if obj then
					obj:Remove()
				end
			end
			box_esp_cache = {}
		end
	end)
	ESPBox:AddToggle("esp_team_check", { Text = "ESP Team Check", Default = config.esp_team_check })
		:OnChanged(function()
			config.esp_team_check = Toggles.esp_team_check.Value
			if config.esp_enabled then
				updateHighlightESP()
			end
			if config.name_esp_enabled then
				updateNameESP()
			end
			if config.box_esp_enabled then
				updateBoxESP()
			end
		end)
	ESPBox:AddSlider("box_esp_thickness", {
		Text = "Box Thickness",
		Default = config.box_esp_thickness,
		Min = 1,
		Max = 5,
		Rounding = 0,
	}):OnChanged(function()
		config.box_esp_thickness = Options.box_esp_thickness.Value
	end)
	ESPBox:AddDropdown("box_esp_color", {
		Text = "Box Color",
		Default = "White",
		Values = { "Red", "Green", "Blue", "Yellow", "White", "Cyan", "Magenta", "Orange" },
	}):OnChanged(function()
		config.box_esp_color = color_presets[Options.box_esp_color.Value]
	end)
end

--// UI - Misc
do
	local Main = MiscBox:AddTab("Miscellaneous")
	Main:AddButton({
		Text = "No Recoil",
		Func = function()
			config.no_recoil = true
			applyNoRecoil()
		end,
	})
end

--// ========== MAIN LOOP ==========
local currentTarget = nil
local connections = {}

local function updateTeamList()
	if tick() - last_team_update > TEAM_UPDATE_INTERVAL then
		pcall(updateTeammates)
		last_team_update = tick()
		if config.esp_enabled then
			updateHighlightESP()
		end
		if config.name_esp_enabled then
			updateNameESP()
		end
		if config.box_esp_enabled then
			updateBoxESP()
		end
	end
end

connections.render = RunService.RenderStepped:Connect(function()
	updateTeamList()

	fov_circle.Position = UserInputService:GetMouseLocation()
	if config.aimbot_enabled then
		if config.fov_circle_only_aiming then
			fov_circle.Visible = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		else
			fov_circle.Visible = true
		end
	else
		fov_circle.Visible = false
	end

	if config.aimbot_enabled then
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			currentTarget = getClosestTarget()
		else
			currentTarget = nil
		end

		if currentTarget then
			local predictedPosition = currentTarget.Position
			if currentTarget.Velocity then
				predictedPosition = predictedPosition + currentTarget.Velocity * config.prediction
			end
			local screenPos = Camera:WorldToViewportPoint(predictedPosition)
			local mousePos = UserInputService:GetMouseLocation()
			local delta = Vector2.new(screenPos.X, screenPos.Y) - mousePos
			delta = applySmoothingCurve(delta, config.smoothing_curve)
			local move = delta * config.smoothness
			move = Vector2.new(math.clamp(move.X, -100, 100), math.clamp(move.Y, -100, 100))
			pcall(mousemoverel, move.X, move.Y)
		end
	end

	if config.name_esp_enabled then
		updateNameESP()
	end
	if config.box_esp_enabled then
		updateBoxESP()
	end
end)

connections.char_added = charactersFolder.ChildAdded:Connect(function(char)
	task.spawn(function()
		task.wait(0.1)
		if config.esp_enabled then
			updateHighlightESP()
		end
		if config.name_esp_enabled then
			updateNameESP()
		end
		if config.box_esp_enabled then
			updateBoxESP()
		end
	end)
end)

connections.char_removed = charactersFolder.ChildRemoved:Connect(function(char)
	if esp_cache[char] then
		esp_cache[char]:Destroy()
		esp_cache[char] = nil
	end
	if name_esp_cache[char] then
		name_esp_cache[char]:Remove()
		name_esp_cache[char] = nil
	end
	if box_esp_cache[char] then
		box_esp_cache[char]:Remove()
		box_esp_cache[char] = nil
	end
	char_to_name[char] = nil
	char_to_player[char] = nil
	for frame, mappedChar in pairs(frame_to_char) do
		if mappedChar == char then
			frame_to_char[frame] = nil
		end
	end
end)

--// Initial setup
updatePlayersCache()
task.spawn(function()
	task.wait(0.5)
	updateTeammates()
	updateHighlightESP()
	updateNameESP()
	updateBoxESP()
end)
applyNoRecoil()

connections.unload = function()
	for _, conn in pairs(connections) do
		if conn and conn.Disconnect then
			conn:Disconnect()
		end
	end
	for _, hl in pairs(esp_cache) do
		if hl then
			hl:Destroy()
		end
	end
	esp_cache = {}
	for _, obj in pairs(name_esp_cache) do
		if obj then
			obj:Remove()
		end
	end
	name_esp_cache = {}
	for _, obj in pairs(box_esp_cache) do
		if obj then
			obj:Remove()
		end
	end
	box_esp_cache = {}
	if fov_circle then
		fov_circle:Remove()
	end
end
_G.unload = connections.unload

print("Shade loaded with GUI-only team check, map-based wall check, and Name ESP using GUI names.")
