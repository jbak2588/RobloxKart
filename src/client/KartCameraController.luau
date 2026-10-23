local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local requireModule = require :: (ModuleScript) -> any
local kartConfigModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartConfig") :: ModuleScript
local KartConfig = requireModule(kartConfigModule)
local RaceConfig = requireModule(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaceConfig"))
local ChaseMotion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ChaseCameraMotion"))
local Input = require(script.Parent:WaitForChild("KartInputController"))
local FinishComposition = require(script.Parent:WaitForChild("FinishCameraComposition"))
local SpeedSensation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KDMSpeedSensation"))

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
	local previousTarget: Vector3? = nil
	local lastCorrectionLog = 0
	local finishMode = "CHASE"
	local finishTransitionElapsed = 0
	local finishTransitionStartCFrame: CFrame? = nil
	local finishRollCameraElapsed = 0
	local wasFinishRoll = false
	local speedFieldOfView = KartConfig.CAMERA_FOV
	local speedResetSerial = nil
	local teleporting = false

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
		local raceState = player:GetAttribute("RaceState")
		local kart = chassis.Parent
		local resetSerial = kart:GetAttribute("RaceResetSerial")
		local justReset = resetSerial ~= speedResetSerial
		speedResetSerial = resetSerial
		if raceState ~= "RACING" or justReset then
			speedFieldOfView = KartConfig.CAMERA_FOV
		else
			local tier, intensity = SpeedSensation.resolve(chassis.AssemblyLinearVelocity:Dot(lastPlanarForward),
				kart:GetAttribute("KartBoosting") == true, kart:GetAttribute("KartNitroActive") == true,
				kart:GetAttribute("RaceControlsLocked") ~= true, kart:GetAttribute("KartOffTrack") == true)
			speedFieldOfView = SpeedSensation.stepFov(speedFieldOfView,
				SpeedSensation.targetFov(KartConfig.CAMERA_FOV, tier, intensity), deltaTime)
		end
		local finishPhase = player:GetAttribute("RaceFinishPhase")
		local roll = raceState == "FINISHING" and finishPhase == "ROLL"
		if roll then
			if not wasFinishRoll then finishRollCameraElapsed = 0 end
			finishRollCameraElapsed += deltaTime
		else
			finishRollCameraElapsed = 0
		end
		wasFinishRoll = roll
		-- PV633 handling: keep the view tied to the chassis during normal driving and drift.
		local present = finishPhase == "PRESENT"
			and (raceState == "FINISHING" or raceState == "FINISHED")
		local mobileFinish = false
		if (roll or present) and Input.isTouchPreferred()
			and camera.ViewportSize.X > camera.ViewportSize.Y then
			local playerGui = player:FindFirstChildOfClass("PlayerGui")
			local raceHud = playerGui and playerGui:FindFirstChild("RobloxKartRaceHud")
			local safeWidth = if raceHud and raceHud.AbsoluteSize.X > 0 then raceHud.AbsoluteSize.X
				else camera.ViewportSize.X
			mobileFinish = safeWidth >= 720
		end
		if present then
			if finishMode == "CHASE" then
				finishMode = "FINISH_FRONT_TRANSITION"
				finishTransitionElapsed = 0
				finishTransitionStartCFrame = camera.CFrame
			end
			local visual = kart:FindFirstChild("Visual")
			local v2Finish = visual and visual:GetAttribute("VisualModelName") == "KDMV2"
				and not (RunService:IsStudio() and Workspace:GetAttribute("KDMV2FinishCameraMode") == "D3")
			local frontPosition,lookTarget=FinishComposition.front(chassis.Position,lastPlanarForward,
				camera.ViewportSize,KartConfig.CAMERA_FOV,
				if v2Finish then KartConfig.V2_FINISH_CAMERA_SIDE else 2.5,
				if v2Finish then KartConfig.V2_FINISH_CAMERA_HEIGHT else 4.5,
				if mobileFinish then RaceConfig.MOBILE_FINISH_PRESENT_SCREEN_X else .5)
			local frontCFrame = CFrame.lookAt(frontPosition, lookTarget, WORLD_UP)
			camera.CameraType = Enum.CameraType.Scriptable
			camera.FieldOfView = KartConfig.CAMERA_FOV
			if finishMode == "FINISH_FRONT_TRANSITION" then
				finishTransitionElapsed += deltaTime
				local alpha = math.clamp(finishTransitionElapsed / RaceConfig.FINISH_CAMERA_TRANSITION_SECONDS, 0, 1)
				local smooth = alpha * alpha * (3 - 2 * alpha)
				camera.CFrame = (finishTransitionStartCFrame or camera.CFrame):Lerp(frontCFrame, smooth)
				if alpha >= 1 then finishMode = "FINISH_FRONT" end
			else
				camera.CFrame = frontCFrame
			end
			camera.Focus = CFrame.new(lookTarget)
			return
		elseif finishMode ~= "CHASE" then
			finishMode = "CHASE"
			finishTransitionElapsed = 0
			finishTransitionStartCFrame = nil
			previousTarget = nil
		end
		local desiredPosition = chassis.Position
			- lastPlanarForward * KartConfig.CAMERA_DISTANCE
			+ WORLD_UP * KartConfig.CAMERA_HEIGHT
		local lookTarget = chassis.Position
			+ lastPlanarForward * KartConfig.CAMERA_LOOK_AHEAD
			+ WORLD_UP * 2
		if roll and mobileFinish then
			local progress = math.clamp(finishRollCameraElapsed / RaceConfig.FINISH_ROLL_SECONDS, 0, 1)
			local drift = math.clamp((progress - RaceConfig.FINISH_DRIFT_START_RATIO)
				/ (1 - RaceConfig.FINISH_DRIFT_START_RATIO), 0, 1)
			drift = drift * drift * (3 - 2 * drift)
			local screenX = 0.5 + (RaceConfig.TARGET_FINISH_SCREEN_X - 0.5) * drift
			desiredPosition, lookTarget = FinishComposition.offset(desiredPosition, lookTarget,
				chassis.Position + WORLD_UP * 2.25, camera.ViewportSize, KartConfig.CAMERA_FOV, screenX)
		end
		local desiredCFrame = CFrame.lookAt(desiredPosition, lookTarget, WORLD_UP)
		if KartConfig.DEBUG_TELEMETRY and previousTarget and deltaTime > 0 then
			local displacement = (chassis.Position - previousTarget):Dot(lastPlanarForward)
			local speed = chassis.AssemblyLinearVelocity:Dot(lastPlanarForward)
			if displacement < -0.25 and speed > 10 and time() - lastCorrectionLog > 1 then
				lastCorrectionLog = time()
				warn(string.format("[KartMotion] client backward correction=%.3f velocity=%.1f dt=%.4f", displacement, speed, deltaTime))
			end
		end

		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = speedFieldOfView
		camera.CFrame = ChaseMotion.step(camera.CFrame, previousTarget, chassis.Position, desiredCFrame, KartConfig.CAMERA_RESPONSE, deltaTime)
		previousTarget = chassis.Position
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
		finishMode = "CHASE"
		finishTransitionElapsed = 0
		finishTransitionStartCFrame = nil
		finishRollCameraElapsed = 0
		wasFinishRoll = false
		previousTarget = nil
		speedFieldOfView = KartConfig.CAMERA_FOV
		speedResetSerial = nil
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
		previousTarget = nil
		lastPlanarForward = getPlanarForward(chassis, DEFAULT_FORWARD)
		finishMode = "CHASE"
		finishTransitionElapsed = 0
		finishTransitionStartCFrame = nil
		finishRollCameraElapsed = 0
		wasFinishRoll = false
		speedFieldOfView = KartConfig.CAMERA_FOV
		speedResetSerial = chassis.Parent:GetAttribute("RaceResetSerial")
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
		if teleporting then disableChase();return end
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
	player.OnTeleport:Connect(function(state)
		teleporting = state ~= Enum.TeleportState.Failed
		if teleporting then disableChase() end
	end)
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
