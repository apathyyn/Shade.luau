--[[
    Luau Mouse Aimbot (Distance‑Scaled Bezier Curve)
    Features: FOV, Smoothness, Wall Check, Team Check
    Keybind: Right Mouse Button (Mouse2)
    Mouse path uses a quadratic Bézier curve whose strength depends on target distance.
    No vertical correction – all aiming is automatic.
    Disclaimer: Educational purposes only.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- =============== CONFIGURATION ===============
local Settings = {
	FOV = 18, -- Aim assist radius (degrees)
	Smoothness = 0.6, -- Smoothing factor (0 = instant, higher = slower)
	WallCheck = false, -- Ignore walls
	TeamCheck = false, -- Ignore teammates
	AimPart = "Head", -- Part to aim at (use "Head" for headshots)
	MouseSensitivityX = 0.5, -- Horizontal mouse sensitivity multiplier
	MouseSensitivityY = 0.5, -- Vertical mouse sensitivity multiplier (keep low to avoid overshoot)
	CurveStrength = 0, -- Maximum curve strength (at close range)
	CurveDistanceFalloff = 0, -- Distance (studs) at which the curve strength halves
}
-- =============================================

-- Check if mousemoverel is available
local hasMouseMoveRel = (mousemoverel ~= nil)
if not hasMouseMoveRel then
	warn("[Aimbot] mousemoverel not found! Falling back to camera aimbot.")
end

-- FOV circle
local FOVCircle = nil
if Drawing then
	FOVCircle = Drawing.new("Circle")
	FOVCircle.Thickness = 1
	FOVCircle.Color = Color3.new(1, 0, 0)
	FOVCircle.Transparency = 0.5
	FOVCircle.Visible = true
end

-- Utility
local function getCharacter(p)
	return p.Character
end

local function getHumanoid(p)
	local c = getCharacter(p)
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function isAlive(p)
	local h = getHumanoid(p)
	return h and h.Health > 0
end

local function getTeam(p)
	return p.Team
end

local function getAimPart(p)
	local c = getCharacter(p)
	if not c then
		return nil
	end
	return c:FindFirstChild(Settings.AimPart) or c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
end

-- Wall check
local function isVisible(targetPos)
	if not Settings.WallCheck then
		return true
	end
	local camPos = Camera.CFrame.Position
	local dir = (targetPos - camPos)
	local dist = dir.Magnitude
	if dist == 0 then
		return true
	end
	dir = dir.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	return Workspace:Raycast(camPos, dir * dist, params) == nil
end

local function angleBetween(v1, v2)
	return math.acos(math.clamp(v1.Unit:Dot(v2.Unit), -1, 1))
end

-- Linear interpolation
local function lerp(t, a, b)
	return a + (b - a) * t
end

-- Quadratic Bezier on 2D vectors
local function quadBezier2D(t, p0, p1, p2)
	local l1 = Vector2.new(lerp(t, p0.X, p1.X), lerp(t, p0.Y, p1.Y))
	local l2 = Vector2.new(lerp(t, p1.X, p2.X), lerp(t, p1.Y, p2.Y))
	return Vector2.new(lerp(t, l1.X, l2.X), lerp(t, l1.Y, l2.Y))
end

-- Find best target
local function findBestTarget()
	local best = nil
	local bestAngle = math.huge
	local bestDist = math.huge
	local camCF = Camera.CFrame
	local camPos = camCF.Position
	local camLook = camCF.LookVector

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and isAlive(player) then
			if not (Settings.TeamCheck and getTeam(player) == getTeam(LocalPlayer)) then
				local aimPart = getAimPart(player)
				if aimPart then
					local targetPos = aimPart.Position
					local dirTo = (targetPos - camPos).Unit
					local angle = angleBetween(camLook, dirTo)
					if angle <= math.rad(Settings.FOV) and isVisible(targetPos) then
						local dist = (targetPos - camPos).Magnitude
						if angle < bestAngle or (angle == bestAngle and dist < bestDist) then
							best = player
							bestAngle = angle
							bestDist = dist
						end
					end
				end
			end
		end
	end
	return best
end

-- Update FOV circle
local function updateFOVCircle()
	if not FOVCircle or not Camera then
		return
	end
	local vs = Camera.ViewportSize
	local center = Vector2.new(vs.X / 2, vs.Y / 2)
	FOVCircle.Position = center
	FOVCircle.Radius = math.tan(math.rad(Settings.FOV)) * (vs.Y / 2)
end

-- Convert target 3D position to screen delta from center (no vertical correction)
local function getScreenDelta(targetPos)
	local screenPos, onScreen = Camera:WorldToScreenPoint(targetPos)
	if not onScreen then
		return nil
	end
	local viewportSize = Camera.ViewportSize
	local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
	return Vector2.new(screenPos.X - center.X, screenPos.Y - center.Y)
end

-- Main loop
RunService.RenderStepped:Connect(function(dt)
	updateFOVCircle()

	if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		return
	end
	if not Camera then
		return
	end

	local target = findBestTarget()
	if not target then
		return
	end

	local aimPart = getAimPart(target)
	if not aimPart then
		return
	end

	local targetPos = aimPart.Position
	local screenDelta = getScreenDelta(targetPos)
	if not screenDelta or screenDelta.Magnitude < 1 then
		return
	end

	-- Compute distance to target for curve scaling
	local distance = (targetPos - Camera.CFrame.Position).Magnitude

	-- Frame‑rate independent smoothing factor
	local alpha = 1 - math.pow(1 - Settings.Smoothness, dt * 60)
	alpha = math.clamp(alpha, 0, 1)

	-- Adjust curve strength based on distance
	-- Closer targets get stronger curve, farther targets get weaker curve
	local distanceFactor = 1 - math.clamp(distance / Settings.CurveDistanceFalloff, 0, 1)
	local curveStrength = Settings.CurveStrength * distanceFactor

	-- Use Bezier curve for mouse path
	local startDelta = Vector2.new(0, 0)
	local endDelta = screenDelta
	local mid = (startDelta + endDelta) / 2
	local perpendicular = Vector2.new(-endDelta.Y, endDelta.X).Unit
	local control = mid + perpendicular * (endDelta.Magnitude * curveStrength)

	local bezierDelta = quadBezier2D(alpha, startDelta, control, endDelta)

	-- Apply sensitivity scaling
	local moveX = bezierDelta.X * Settings.MouseSensitivityX
	local moveY = bezierDelta.Y * Settings.MouseSensitivityY

	if hasMouseMoveRel then
		mousemoverel(moveX, moveY)
	else
		-- Fallback: camera aim (not mouse)
		local camPos = Camera.CFrame.Position
		local targetDir = (targetPos - camPos).Unit
		local currentDir = Camera.CFrame.LookVector
		local newDir = currentDir:Lerp(targetDir, alpha)
		Camera.CFrame = CFrame.lookAt(camPos, camPos + newDir, Camera.CFrame.UpVector)
	end
end)
