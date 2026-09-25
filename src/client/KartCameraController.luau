local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local requireModule = require :: (ModuleScript) -> any
local kartConfigModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartConfig") :: ModuleScript
local KartConfig = requireModule(kartConfigModule)

local KartCameraController = {}

local RENDER_STEP_NAME = "RobloxKartChaseCamera"
local WORLD_UP = Vector3.yAxis
local DEFAULT_FORWARD = Vector3.new(0, 0, -1)
local started = false

local function getPrototypeChassis(seatPart: BasePart?): BasePart?
	if not seatPart or seatPart:GetAttribute("PrototypeKartSeat") ~= true then
		return nil
	end

	local kart = seatPart.Parent
	if not kart or not kart:IsA("Model") then
		return nil
	end

	if kart.PrimaryPart then
		return kart.PrimaryPart
	end

	local chassis = kart:FindFirstChild("Chassis")
	if chassis and chassis:IsA("BasePart") then
		return chassis
	end

	return nil
end

local function getPlanarForward(chassis: BasePart, fallback: Vector3): Vector3
	local lookVector = chassis.CFrame.LookVector
	local planarForward = Vector3.new(lookVector.X, 0, lookVector.Z)
	if planarForward.Magnitude <= 0.001 then
		return fallback
	end
	return planarForward.Unit
end

function KartCameraController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local activeChassis: BasePart? = nil
	local activeSeat: BasePart? = nil
	local currentHumanoid: Humanoid? = nil
	local seatedConnection: RBXScriptConnection? = nil
	local seatPartConnection: RBXScriptConnection? = nil
	local savedFieldOfView: number? = nil
	local lastPlanarForward = DEFAULT_FORWARD
	local chaseEnabled = false
	local seatCheckElapsed = 0

	local disableChase: () -> ()

	local function updateCamera(deltaTime: number)
		local chassis = activeChassis
		local humanoid = currentHumanoid
		local camera = Workspace.CurrentCamera
		if not chaseEnabled or not chassis or not chassis.Parent or not humanoid or humanoid.SeatPart ~= activeSeat then
			task.defer(function()
				if not activeChassis or not activeChassis.Parent
					or currentHumanoid ~= humanoid or not humanoid or humanoid.SeatPart ~= activeSeat then
					disableChase()
				end
			end)
			return
		end
		if not camera then
			return
		end

		lastPlanarForward = getPlanarForward(chassis, lastPlanarForward)
		local desiredPosition = chassis.Position
			- lastPlanarForward * KartConfig.CAMERA_DISTANCE
			+ WORLD_UP * KartConfig.CAMERA_HEIGHT
		local lookTarget = chassis.Position
			+ lastPlanarForward * KartConfig.CAMERA_LOOK_AHEAD
			+ WORLD_UP * 2
		local desiredCFrame = CFrame.lookAt(desiredPosition, lookTarget, WORLD_UP)
		local alpha = 1 - math.exp(-KartConfig.CAMERA_RESPONSE * deltaTime)

		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = KartConfig.CAMERA_FOV
		camera.CFrame = camera.CFrame:Lerp(desiredCFrame, alpha)
		camera.Focus = CFrame.new(lookTarget)
	end

	disableChase = function()
		if not chaseEnabled then
			return
		end

		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		chaseEnabled = false

		local camera = Workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			if currentHumanoid then
				camera.CameraSubject = currentHumanoid
			end
			if savedFieldOfView then
				camera.FieldOfView = savedFieldOfView
			end
		end

		activeChassis = nil
		activeSeat = nil
		savedFieldOfView = nil
		print("[RobloxKart] Chase camera disabled")
	end

	local function enableChase(seatPart: BasePart, chassis: BasePart)
		if chaseEnabled and activeSeat == seatPart and activeChassis == chassis then
			return
		end
		if chaseEnabled then
			disableChase()
		end

		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		activeSeat = seatPart
		activeChassis = chassis
		lastPlanarForward = getPlanarForward(chassis, DEFAULT_FORWARD)
		savedFieldOfView = camera.FieldOfView
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = KartConfig.CAMERA_FOV
		chaseEnabled = true

		RunService:BindToRenderStep(
			RENDER_STEP_NAME,
			Enum.RenderPriority.Camera.Value + 1,
			updateCamera
		)
		print("[RobloxKart] Chase camera enabled")
	end

	local function updateSeat(seatPart: BasePart?)
		local chassis = getPrototypeChassis(seatPart)
		if seatPart and chassis then
			enableChase(seatPart, chassis)
		else
			disableChase()
		end
	end

	local function bindCharacter(character: Model)
		disableChase()
		if seatedConnection then
			seatedConnection:Disconnect()
			seatedConnection = nil
		end
		if seatPartConnection then
			seatPartConnection:Disconnect()
			seatPartConnection = nil
		end

		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		if player.Character ~= character then
			return
		end
		currentHumanoid = humanoid
		seatedConnection = humanoid.Seated:Connect(function()
			updateSeat(humanoid.SeatPart)
		end)
		seatPartConnection = humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
			updateSeat(humanoid.SeatPart)
		end)
		updateSeat(humanoid.SeatPart)
	end

	RunService.Heartbeat:Connect(function(deltaTime: number)
		seatCheckElapsed += deltaTime
		if seatCheckElapsed < 0.25 then
			return
		end
		seatCheckElapsed = 0
		local humanoid = currentHumanoid
		local seatPart = humanoid and humanoid.SeatPart
		if seatPart ~= activeSeat or (seatPart ~= nil and not chaseEnabled) then
			updateSeat(seatPart)
		end
	end)

	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function()
		disableChase()
		if seatedConnection then
			seatedConnection:Disconnect()
			seatedConnection = nil
		end
		if seatPartConnection then
			seatPartConnection:Disconnect()
			seatPartConnection = nil
		end
		currentHumanoid = nil
	end)

	local character = player.Character
	if character then
		task.spawn(bindCharacter, character)
	end

	print("[RobloxKart] Chase camera ready")
end

return KartCameraController
