--// Debug: GUI-to-Character Mapping – uses Shade's EXACT team detection
--// Team detection: root parts, 100px threshold, name match + proximity scoring.
--// Press F9 to toggle overlay.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

local charactersFolder = Workspace:FindFirstChild("characters")
if not charactersFolder then
	warn("'characters' folder not found.")
end

--// ========== TEAM DETECTION (EXACTLY FROM SHADE AIMBOT) ==========
local players_cache = {}
local char_to_player = {}
local teammate_players = {}
local char_to_name = {}
local frame_to_char = {}
local last_team_update = 0
local TEAM_UPDATE_INTERVAL = 0.5

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

--// ====== EXACT updateTeammates FROM SHADE ======
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
			local playernameChild = playerFrame:FindFirstChild("playername")
			if playernameChild and playernameChild:IsA("StringValue") then
				playerName = playernameChild.Value
			elseif playernameChild and playernameChild:IsA("TextLabel") then
				playerName = playernameChild.Text
			else
				local label = playerFrame:FindFirstChildWhichIsA("TextLabel")
				playerName = label and label.Text or playerFrame.Name
			end

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

	-- Get character root part screen positions (using humanoid_root_part or torso)
	local charScreenPositions = {}
	local charDistances = {}
	for _, char in ipairs(charactersFolder:GetChildren()) do
		if char:IsA("Model") then
			local rootPart = char:FindFirstChild("humanoid_root_part") or char:FindFirstChild("torso")
			if rootPart and rootPart:IsA("BasePart") then
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

	-- Second pass: screen proximity (threshold = 100, scoring)
	local screenThreshold = 100
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
--// ==============================================================

local function isTeammate(player)
	if player == LocalPlayer then
		return true
	end
	return teammate_players[player] == true
end

--// ========== DRAWING ==========
local textCache = {}
local localCharacter = nil
local localPlayerInfo = { name = "Unknown", path = "N/A" }

-- Corner HUD
local cornerText = Drawing.new("Text")
cornerText.Visible = true
cornerText.Size = 14
cornerText.Font = 1
cornerText.Color = Color3.new(1, 1, 1)
cornerText.Outline = true
cornerText.OutlineColor = Color3.new(0, 0, 0)
cornerText.Position = Vector2.new(10, 10)
cornerText.Text = "Initializing..."

local function getFullPath(instance)
	if not instance then
		return "nil"
	end
	local parts = {}
	while instance and instance ~= game do
		table.insert(parts, 1, instance.Name)
		instance = instance.Parent
	end
	return table.concat(parts, ".")
end

local function updateLocalPlayer()
	local char = LocalPlayer.Character
	if char and char:IsA("Model") and charactersFolder and char.Parent == charactersFolder then
		localCharacter = char
		localPlayerInfo.name = LocalPlayer.DisplayName .. " (" .. LocalPlayer.Name .. ")"
		localPlayerInfo.path = getFullPath(char)
	else
		localCharacter = nil
		localPlayerInfo.name = "Not found"
		localPlayerInfo.path = "N/A"
	end
end

--// Helper to get GUI labels (same as in Shade for consistency)
local function getGUILabels()
	local mainFrame = findTeamLabelFrame()
	if not mainFrame then
		return {}
	end
	local labels = {}
	for _, playerFrame in ipairs(mainFrame:GetChildren()) do
		if playerFrame:IsA("Frame") then
			local posFrame = playerFrame:FindFirstChild("1")
			if posFrame and posFrame:IsA("Frame") then
				local absPos = posFrame.AbsolutePosition
				local absSize = posFrame.AbsoluteSize
				if absPos.X > 0 and absPos.Y > 0 then
					local center = absPos + absSize / 2
					local name = nil
					local playernameChild = playerFrame:FindFirstChild("playername")
					if playernameChild and playernameChild:IsA("StringValue") then
						name = playernameChild.Value
					elseif playernameChild and playernameChild:IsA("TextLabel") then
						name = playernameChild.Text
					else
						local label = playerFrame:FindFirstChildWhichIsA("TextLabel")
						name = label and label.Text or playerFrame.Name
					end
					table.insert(labels, {
						pos = center,
						name = name or playerFrame.Name,
						frame = playerFrame,
					})
				end
			end
		end
	end
	return labels
end

--// Corner HUD – shows stats and closest GUI->character (using root parts for consistency)
local function updateCornerHUD()
	local totalChars = 0
	local teamCount = 0
	local enemyCount = 0
	local counted = {}

	for char, _ in pairs(char_to_name) do
		totalChars = totalChars + 1
		local player = char_to_player[char]
		if player and isTeammate(player) then
			teamCount = teamCount + 1
		else
			enemyCount = enemyCount + 1
		end
		counted[char] = true
	end

	if charactersFolder then
		for _, char in ipairs(charactersFolder:GetChildren()) do
			if char:IsA("Model") and not counted[char] then
				totalChars = totalChars + 1
				local player = char_to_player[char]
				if player and isTeammate(player) then
					teamCount = teamCount + 1
				else
					enemyCount = enemyCount + 1
				end
			end
		end
	end

	if localCharacter and not counted[localCharacter] then
		totalChars = totalChars + 1
		teamCount = teamCount + 1
	end

	local mainFrame = findTeamLabelFrame()
	local guiPath = mainFrame and getFullPath(mainFrame) or "Not found"

	-- Build list of closest GUI->character using root part positions (like Shade)
	local labels = getGUILabels()
	local closestList = {}
	for _, entry in ipairs(labels) do
		local bestChar = nil
		local bestDist = math.huge
		for _, char in ipairs(charactersFolder:GetChildren()) do
			if char:IsA("Model") then
				local rootPart = char:FindFirstChild("humanoid_root_part") or char:FindFirstChild("torso")
				if rootPart and rootPart:IsA("BasePart") then
					local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
					if onScreen then
						local dist = (entry.pos - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
						if dist < bestDist then
							bestDist = dist
							bestChar = char
						end
					end
				end
			end
		end
		if bestChar then
			local player = char_to_player[bestChar]
			local name = player and player.Name or bestChar.Name
			table.insert(closestList, string.format("%s → %s (%.1f px)", entry.name, name, bestDist))
		end
	end

	if #closestList > 10 then
		closestList = { table.unpack(closestList, 1, 10) }
		table.insert(closestList, "... and " .. (#closestList - 10) .. " more")
	end

	local listStr = table.concat(closestList, "\n")
	local text = string.format(
		[[Local Player: %s
Character Path: %s
Total Characters: %d
Teammates: %d
Enemies: %d
GUI Frame: %s

Closest GUI→Character (root parts, 100px threshold):
%s]],
		localPlayerInfo.name,
		localPlayerInfo.path,
		totalChars,
		teamCount,
		enemyCount,
		guiPath,
		listStr
	)
	cornerText.Text = text
end

--// Per‑character overhead – shows closest GUI (using pivot for visual) and mapped GUI
local function updateCharacterDebug()
	local toRemove = {}
	for char, drawObj in pairs(textCache) do
		if not char or not char.Parent then
			toRemove[char] = true
		end
	end
	for char in pairs(toRemove) do
		if textCache[char] then
			textCache[char]:Remove()
			textCache[char] = nil
		end
	end

	if not charactersFolder then
		return
	end

	local labels = getGUILabels()

	for _, char in ipairs(charactersFolder:GetChildren()) do
		if char:IsA("Model") then
			local player = char_to_player[char]
			local isLocal = (char == localCharacter)
			if isLocal then
				localCharacter = char
			end
			local isTeammateBool = player and isTeammate(player) or false

			-- Use pivot for overhead display (as before)
			local pivotPos = char:GetPivot().Position
			local rootScreenPos, rootOn = Camera:WorldToViewportPoint(pivotPos)
			if not rootOn then
				if textCache[char] then
					textCache[char].Visible = false
				end
				continue
			end
			local rootScreenVec = Vector2.new(rootScreenPos.X, rootScreenPos.Y)

			-- Find closest GUI label (based on pivot)
			local closestLabel = nil
			local closestDist = math.huge
			for _, entry in ipairs(labels) do
				local dist = (entry.pos - rootScreenVec).Magnitude
				if dist < closestDist then
					closestDist = dist
					closestLabel = entry
				end
			end

			local closestGUIName = closestLabel and closestLabel.name or "None"
			local closestGUIDist = closestDist ~= math.huge and string.format("%.1f px", closestDist) or "N/A"

			-- Mapped GUI info (from team detection)
			local mappedGUIName = char_to_name[char] or "None"
			local guiFrameObj = nil
			for frame, mappedChar in pairs(frame_to_char) do
				if mappedChar == char then
					guiFrameObj = frame
					break
				end
			end
			local guiPath = guiFrameObj and getFullPath(guiFrameObj) or "Not mapped"

			local guiScreenVec = nil
			if guiFrameObj and guiFrameObj:IsA("Frame") then
				local pos = guiFrameObj.AbsolutePosition
				local size = guiFrameObj.AbsoluteSize
				if pos.X > 0 and pos.Y > 0 then
					guiScreenVec = Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2)
				end
			end
			local diffStr = "N/A"
			if guiScreenVec then
				local diff = (guiScreenVec - rootScreenVec).Magnitude
				diffStr = string.format("%.1f px", diff)
			end

			local statusColor
			if isLocal then
				statusColor = Color3.new(1, 1, 0)
			elseif isTeammateBool then
				statusColor = Color3.new(0, 1, 0)
			else
				statusColor = Color3.new(1, 0, 0)
			end

			local headPart = char:FindFirstChild("head") or char:FindFirstChild("Head")
			local headPos = headPart and headPart.Position or pivotPos
			local worldPos = headPos + Vector3.new(0, 2.8, 0)
			local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)

			if onScreen then
				local lines = {
					string.format("Closest GUI: %s (dist %s)", closestGUIName, closestGUIDist),
					string.format("Mapped GUI: %s", mappedGUIName),
					string.format("[%s]", isLocal and "LOCAL" or (isTeammateBool and "TEAM" or "ENEMY")),
					string.format("GUI Frame: %s", guiPath),
					string.format(
						"GUI Screen: %s",
						guiScreenVec and string.format("(%.0f, %.0f)", guiScreenVec.X, guiScreenVec.Y) or "N/A"
					),
					string.format("Pivot Screen: (%.0f, %.0f)", rootScreenVec.X, rootScreenVec.Y),
					string.format("Diff (mapped): %s", diffStr),
				}
				local text = table.concat(lines, "\n")

				local draw = textCache[char]
				if not draw then
					draw = Drawing.new("Text")
					draw.Visible = true
					draw.Center = true
					draw.Outline = true
					draw.OutlineColor = Color3.new(0, 0, 0)
					draw.Font = 1
					draw.Size = 12
					textCache[char] = draw
				end

				draw.Text = text
				draw.Position = Vector2.new(screenPos.X, screenPos.Y)
				draw.Color = statusColor
				draw.Size = 12
				draw.Visible = true
			else
				if textCache[char] then
					textCache[char].Visible = false
				end
			end
		end
	end
end

--// Toggle overlay with F9
local enabled = true
local function setOverlayVisible(visible)
	cornerText.Visible = visible
	for _, draw in pairs(textCache) do
		draw.Visible = visible
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F5 then
		enabled = not enabled
		if not enabled then
			setOverlayVisible(false)
		else
			cornerText.Visible = true
		end
		print("Debug overlay " .. (enabled and "enabled" or "disabled"))
	end
end)

local function update()
	if not enabled then
		cornerText.Visible = false
		for _, draw in pairs(textCache) do
			draw.Visible = false
		end
		return
	end

	cornerText.Visible = true

	if tick() - last_team_update > TEAM_UPDATE_INTERVAL then
		pcall(updateTeammates)
		last_team_update = tick()
	end

	pcall(updateLocalPlayer)
	pcall(updateCornerHUD)
	pcall(updateCharacterDebug)
end

local renderConnection = RunService.RenderStepped:Connect(update)

print("Debug script loaded (Shade team detection, 100px threshold). Press F5 to toggle overlay.")
-- To stop: renderConnection:Disconnect()
