local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local KartConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartConfig"))
local KartCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartCatalog"))
local TrackCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrackCatalog"))
local KartVisualFactory = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartVisualFactory"))
local TrackBuilder = require(script.Parent:WaitForChild("TrackBuilder"))

local PrototypeWorld = {}

type ControlState = {
	throttle: number,
	steering: number,
	driftRequested: boolean,
	lastUpdate: number,
}

local WORLD = {
	GROUND_SIZE = Vector3.new(2048, 1, 2048),
	CHASSIS_SIZE = Vector3.new(6, 1, 8),
	CHASSIS_CLEARANCE = 1.75,
	PLAYER_START = Vector3.new(0, 0.5, 900),
}

local function createPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function getOrCreateGround(prototype: Folder): BasePart
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		return baseplate
	end

	local ground = prototype:FindFirstChild("Ground")
	if ground and ground:IsA("BasePart") then
		return ground
	end

	ground = createPart(prototype, "Ground", WORLD.GROUND_SIZE, CFrame.new(0, -0.5, 0), Color3.fromRGB(99, 95, 99))
	ground.Anchored = true
	ground.Locked = true
	return ground
end

local function weldToChassis(chassis: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = part
	weld.Parent = part
end

local function motorToChassis(chassis: BasePart, wheel: BasePart)
	local motor = Instance.new("Motor6D")
	motor.Name = "VisualMotor"
	motor.Part0 = chassis
	motor.Part1 = wheel
	motor.C0 = chassis.CFrame:ToObjectSpace(wheel.CFrame)
	motor.C1 = CFrame.identity
	motor.Parent = wheel
end

local function createKart(prototype: Folder, spawnCFrame: CFrame): (Model, Part, Seat)
	local previousKart = prototype:FindFirstChild("Kart")
	if previousKart then
		previousKart:Destroy()
	end

	local kart = Instance.new("Model")
	kart.Name = "Kart"
	kart:SetAttribute("PrototypeKart", true)
	kart:SetAttribute("KartDrifting", false)
	kart:SetAttribute("KartBoosting", false)
	kart:SetAttribute("KartOffTrack", false)
	kart:SetAttribute("KartVisualSteering", 0)
	kart:SetAttribute("RaceResetSerial", 0)
	kart:SetAttribute("RaceStartCFrame", spawnCFrame)
	kart:SetAttribute("RaceControlsLocked", true)

	local chassis = createPart(kart, "Chassis", WORLD.CHASSIS_SIZE, spawnCFrame, Color3.fromRGB(220, 45, 45))
	chassis.Anchored = false
	chassis.CanCollide = true
	chassis.Massless = false
	chassis.Transparency = 1
	chassis.RootPriority = 127
	chassis.CustomPhysicalProperties = PhysicalProperties.new(1, 0.05, 0, 1, 1)

	local visual = KartVisualFactory.createVisual(KartCatalog.Entries[KartCatalog.DefaultId])
	visual.Parent = kart
	for _, part in visual:GetChildren() do
		if part:IsA("BasePart") then
			part.CFrame = spawnCFrame * part.CFrame
		end
	end
	for _, part in visual:GetChildren() do
		if part:IsA("BasePart") then
			local parentWheelName = part:GetAttribute("VisualParentWheel")
			if type(parentWheelName) == "string" then
				local wheel = visual:FindFirstChild(parentWheelName)
				if wheel and wheel:IsA("BasePart") then
					weldToChassis(wheel, part)
				end
			elseif part:GetAttribute("VisualMotionRole") then
				motorToChassis(chassis, part)
			else
				weldToChassis(chassis, part)
			end
		end
	end

	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2.5, 1, 2.5)
	seat.CFrame = spawnCFrame * CFrame.new(0, 1.5, 0.5)
	seat.Color = Color3.fromRGB(35, 35, 40)
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Massless = true
	seat:SetAttribute("PrototypeKartSeat", true)
	seat.Parent = kart
	weldToChassis(chassis, seat)

	kart.PrimaryPart = chassis
	kart.Parent = prototype
	chassis:SetNetworkOwner(nil)

	return kart, chassis, seat
end

local function moveToward(value: number, target: number, maximumDelta: number): number
	if value < target then
		return math.min(value + maximumDelta, target)
	end
	return math.max(value - maximumDelta, target)
end

function PrototypeWorld.start()
	local prototype = Workspace:FindFirstChild("Prototype")
	if not prototype or not prototype:IsA("Folder") then
		if prototype then
			prototype:Destroy()
		end
		prototype = Instance.new("Folder")
		prototype.Name = "Prototype"
		prototype.Parent = Workspace
	end

	local ground = getOrCreateGround(prototype)
	local groundTop = ground.Position.Y + ground.Size.Y * 0.5
	print(string.format(
		"[KartWorld] ground=%s size=(%.0f,%.0f,%.0f) position=(%.1f,%.1f,%.1f)",
		ground.Name,
		ground.Size.X,
		ground.Size.Y,
		ground.Size.Z,
		ground.Position.X,
		ground.Position.Y,
		ground.Position.Z
	))

	TrackBuilder.build(prototype, TrackCatalog.Entries[TrackCatalog.DefaultId], groundTop)
	print("[RobloxKart] Practice Circuit ready")

	local initialGrid = TrackCatalog.Entries[TrackCatalog.DefaultId].GridSlots[1]
	local spawnCFrame = CFrame.new(0, groundTop + WORLD.CHASSIS_CLEARANCE, 0) * initialGrid
	local kart, chassis, seat = createKart(prototype, spawnCFrame)

	local existingPlayerSpawn = prototype:FindFirstChild("PlayerSpawn")
	local playerSpawn: SpawnLocation
	if existingPlayerSpawn and existingPlayerSpawn:IsA("SpawnLocation") then
		playerSpawn = existingPlayerSpawn
	else
		if existingPlayerSpawn then
			existingPlayerSpawn:Destroy()
		end
		playerSpawn = Instance.new("SpawnLocation")
		playerSpawn.Name = "PlayerSpawn"
		playerSpawn.Parent = prototype
	end
	playerSpawn.Size = Vector3.new(8, 1, 8)
	playerSpawn.CFrame = CFrame.new(WORLD.PLAYER_START.X, groundTop + WORLD.PLAYER_START.Y, WORLD.PLAYER_START.Z)
	playerSpawn.Anchored = true
	playerSpawn.Neutral = true
	playerSpawn.Transparency = 1

	local remoteEvent = ReplicatedStorage:FindFirstChild(KartConfig.REMOTE_EVENT_NAME)
	if not remoteEvent or not remoteEvent:IsA("RemoteEvent") then
		if remoteEvent then
			remoteEvent:Destroy()
		end
		remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = KartConfig.REMOTE_EVENT_NAME
		remoteEvent.Parent = ReplicatedStorage
	end

	local controls: { [Player]: ControlState } = {}
	local commandedSpeed = 0
	local smoothedSteering = 0
	local currentYawRate = 0
	local driftActive = false
	local driftDuration = 0
	local qualifiedDuration = 0
	local driftDriver: Player? = nil
	local boostActive = false
	local boostEndTime = 0
	local boostDriver: Player? = nil
	local raceControlsWereLocked = kart:GetAttribute("RaceControlsLocked") == true
	local debugElapsed = 0

	local function setDriftActive(active: boolean, reason: string)
		if driftActive == active then
			return
		end
		driftActive = active
		kart:SetAttribute("KartDrifting", active)
		if KartConfig.DEBUG_TELEMETRY then
			if active then
				print(string.format("[KartDrift] START reason=%s", reason))
			else
				print(string.format(
					"[KartDrift] END reason=%s chargeDuration=%.2f qualifiedDuration=%.2f",
					reason,
					driftDuration,
					qualifiedDuration
				))
			end
		end
	end

	local function resetDriftCharge()
		driftDuration = 0
		qualifiedDuration = 0
		driftDriver = nil
	end

	local function startBoost(player: Player, now: number)
		boostActive = true
		boostDriver = player
		boostEndTime = now + KartConfig.MINI_BOOST_DURATION
		kart:SetAttribute("KartBoosting", true)
		if KartConfig.DEBUG_TELEMETRY then
			print(string.format(
				"[KartBoost] START reason=qualified_shift_release chargeDuration=%.2f qualifiedDuration=%.2f",
				driftDuration,
				qualifiedDuration
			))
		end
	end

	local function stopBoost(reason: string)
		if not boostActive then
			return
		end
		boostActive = false
		boostDriver = nil
		boostEndTime = 0
		kart:SetAttribute("KartBoosting", false)
		if KartConfig.DEBUG_TELEMETRY then
			print(string.format("[KartBoost] END reason=%s", reason))
		end
	end

	remoteEvent.OnServerEvent:Connect(function(player: Player, throttle: unknown, steering: unknown, driftRequested: unknown)
		if type(throttle) ~= "number" or type(steering) ~= "number" then
			return
		end
		if throttle ~= throttle or steering ~= steering or math.abs(throttle) == math.huge or math.abs(steering) == math.huge then
			return
		end

		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.SeatPart ~= seat then
			controls[player] = nil
			return
		end
		local validatedSteering = math.clamp(steering, -1, 1)
		local visualSteering = if kart:GetAttribute("RaceControlsLocked") == true then 0 else validatedSteering
		if kart:GetAttribute("KartVisualSteering") ~= visualSteering then
			kart:SetAttribute("KartVisualSteering", visualSteering)
		end

		controls[player] = {
			throttle = math.clamp(throttle, -1, 1),
			steering = validatedSteering,
			driftRequested = if type(driftRequested) == "boolean" then driftRequested else false,
			lastUpdate = time(),
		}
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		controls[player] = nil
	end)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		if chassis.Position.Y < KartConfig.FALL_RESET_Y then
			local fallPosition = chassis.Position
			print(string.format(
				"[KartReset] reason=fall x=%.1f y=%.1f z=%.1f",
				fallPosition.X,
				fallPosition.Y,
				fallPosition.Z
			))
			local resetSerial = kart:GetAttribute("RaceResetSerial")
			kart:SetAttribute("RaceResetSerial", if type(resetSerial) == "number" then resetSerial + 1 else 1)
			kart:PivotTo(spawnCFrame)
			commandedSpeed = 0
			smoothedSteering = 0
			currentYawRate = 0
			kart:SetAttribute("KartVisualSteering", 0)
			setDriftActive(false, "fall")
			resetDriftCharge()
			stopBoost("fall")
			chassis.AssemblyLinearVelocity = Vector3.zero
			chassis.AssemblyAngularVelocity = Vector3.zero
			return
		end

		local raceControlsLocked = kart:GetAttribute("RaceControlsLocked") == true
		if raceControlsLocked then
			if not raceControlsWereLocked then
				commandedSpeed = 0
				smoothedSteering = 0
				currentYawRate = 0
				kart:SetAttribute("KartVisualSteering", 0)
				setDriftActive(false, "race_controls_locked")
				resetDriftCharge()
				stopBoost("race_controls_locked")
			end
			raceControlsWereLocked = true
			chassis.AssemblyLinearVelocity = Vector3.zero
			chassis.AssemblyAngularVelocity = Vector3.zero
			return
		end
		raceControlsWereLocked = false

		local now = time()
		local throttle = 0
		local steering = 0
		local driftRequested = false
		local occupant = seat.Occupant
		local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
		local control = player and controls[player]
		local inputAge = if control then now - control.lastUpdate else nil
		local hasValidInput = control ~= nil and inputAge ~= nil and inputAge <= KartConfig.INPUT_TIMEOUT
		if not hasValidInput and kart:GetAttribute("KartVisualSteering") ~= 0 then
			kart:SetAttribute("KartVisualSteering", 0)
		end
		if control and hasValidInput then
			throttle = control.throttle
			steering = control.steering
			driftRequested = control.driftRequested
		end

		local lookVector = chassis.CFrame.LookVector
		local flatForward = Vector3.new(lookVector.X, 0, lookVector.Z)
		local forward = if flatForward.Magnitude > 0.001 then flatForward.Unit else Vector3.new(0, 0, -1)
		local rightVector = chassis.CFrame.RightVector
		local flatRight = Vector3.new(rightVector.X, 0, rightVector.Z)
		local right = if flatRight.Magnitude > 0.001 then flatRight.Unit else Vector3.new(1, 0, 0)
		local assemblyVelocity = chassis.AssemblyLinearVelocity
		local planarVelocity = Vector3.new(assemblyVelocity.X, 0, assemblyVelocity.Z)
		local actualForwardSpeed = planarVelocity:Dot(forward)
		local lateralSpeed = planarVelocity:Dot(right)
		local driftForwardSpeed = math.max(actualForwardSpeed, 0)
		local chargeSlipAngleDegrees = 0
		if math.abs(actualForwardSpeed) >= 1 then
			chargeSlipAngleDegrees = math.deg(math.atan2(lateralSpeed, math.abs(actualForwardSpeed)))
		end

		smoothedSteering = moveToward(smoothedSteering, steering, KartConfig.STEERING_RESPONSE * deltaTime)
		local absoluteSteering = math.abs(smoothedSteering)
		local endedDriftReason: string? = nil
		if driftActive then
			if not occupant then
				endedDriftReason = "no_occupant"
			elseif player ~= driftDriver then
				endedDriftReason = "driver_changed"
			elseif not hasValidInput then
				endedDriftReason = "input_timeout"
			elseif not driftRequested then
				endedDriftReason = "shift_release"
			elseif commandedSpeed <= 0 or actualForwardSpeed < 0 then
				endedDriftReason = "reverse"
			elseif driftForwardSpeed < KartConfig.DRIFT_EXIT_SPEED then
				endedDriftReason = "speed_below_exit"
			elseif absoluteSteering < KartConfig.DRIFT_EXIT_STEER then
				endedDriftReason = "steer_below_exit"
			end
			if endedDriftReason then
				setDriftActive(false, endedDriftReason)
			end
		elseif not boostActive
			and occupant
			and hasValidInput
			and driftRequested
			and commandedSpeed > 0
			and driftForwardSpeed >= KartConfig.DRIFT_MIN_SPEED
			and absoluteSteering >= KartConfig.DRIFT_ENTRY_STEER
		then
			resetDriftCharge()
			driftDriver = player
			setDriftActive(true, "entry")
		end

		if endedDriftReason then
			local canStartBoost = endedDriftReason == "shift_release"
				and player ~= nil
				and player == driftDriver
				and hasValidInput
				and throttle > 0
				and actualForwardSpeed >= KartConfig.DRIFT_MIN_SPEED
				and absoluteSteering >= KartConfig.DRIFT_EXIT_STEER
				and driftDuration >= KartConfig.DRIFT_CHARGE_MIN_DURATION
				and qualifiedDuration >= KartConfig.DRIFT_CHARGE_REQUIRED_TIME
			if canStartBoost and player then
				startBoost(player, now)
			end
			resetDriftCharge()
		elseif driftActive then
			local chargeDeltaTime = math.min(deltaTime, 0.05)
			driftDuration = math.min(
				driftDuration + chargeDeltaTime,
				KartConfig.DRIFT_CHARGE_MIN_DURATION
			)
			if actualForwardSpeed >= KartConfig.DRIFT_CHARGE_MIN_FORWARD_SPEED
				and math.abs(chargeSlipAngleDegrees) >= KartConfig.DRIFT_CHARGE_MIN_SLIP_DEGREES
			then
				qualifiedDuration = math.min(
					qualifiedDuration + chargeDeltaTime,
					KartConfig.DRIFT_CHARGE_REQUIRED_TIME
				)
			end
		end

		if boostActive then
			if not occupant then
				stopBoost("no_occupant")
			elseif player ~= boostDriver then
				stopBoost("driver_changed")
			elseif not hasValidInput then
				stopBoost("input_timeout")
			elseif throttle < 0 then
				stopBoost("brake")
			elseif throttle <= 0 then
				stopBoost("throttle_release")
			elseif now >= boostEndTime then
				stopBoost("duration_complete")
			end
		end

		local forwardTargetSpeed = if boostActive
			then KartConfig.MINI_BOOST_MAX_SPEED
			elseif driftActive then KartConfig.DRIFT_MAX_SPEED
			else KartConfig.MAX_FORWARD_SPEED
		local offTrack = kart:GetAttribute("KartOffTrack") == true
		if offTrack then
			forwardTargetSpeed = math.min(forwardTargetSpeed, KartConfig.OFF_TRACK_MAX_SPEED)
		end
		local forwardAcceleration = if boostActive then KartConfig.MINI_BOOST_ACCELERATION else KartConfig.ACCELERATION

		if throttle > 0 then
			if commandedSpeed < 0 then
				commandedSpeed = moveToward(commandedSpeed, 0, KartConfig.BRAKE_FORCE * throttle * deltaTime)
			elseif offTrack and commandedSpeed > forwardTargetSpeed then
				commandedSpeed = moveToward(commandedSpeed, forwardTargetSpeed, KartConfig.BRAKE_FORCE * deltaTime)
			elseif driftActive and commandedSpeed > forwardTargetSpeed then
				commandedSpeed = moveToward(
					commandedSpeed,
					forwardTargetSpeed,
					KartConfig.DRIFT_SPEED_DECELERATION * deltaTime
				)
			else
				commandedSpeed = moveToward(commandedSpeed, forwardTargetSpeed, forwardAcceleration * throttle * deltaTime)
			end
		elseif throttle < 0 then
			if commandedSpeed > 0 then
				commandedSpeed = moveToward(commandedSpeed, 0, KartConfig.BRAKE_FORCE * -throttle * deltaTime)
			else
				commandedSpeed = moveToward(commandedSpeed, -KartConfig.MAX_REVERSE_SPEED, KartConfig.REVERSE_ACCELERATION * -throttle * deltaTime)
			end
		else
			commandedSpeed = moveToward(commandedSpeed, 0, KartConfig.COAST_DECELERATION * deltaTime)
		end

		local forwardSpeedLimit = if boostActive then KartConfig.MINI_BOOST_MAX_SPEED else KartConfig.MAX_FORWARD_SPEED
		commandedSpeed = math.clamp(commandedSpeed, -KartConfig.MAX_REVERSE_SPEED, forwardSpeedLimit)

		local effectiveGrip = if driftActive then KartConfig.DRIFT_LATERAL_GRIP else KartConfig.LATERAL_GRIP
		lateralSpeed *= math.exp(-effectiveGrip * deltaTime)
		local verticalSpeed = assemblyVelocity.Y
		chassis.AssemblyLinearVelocity = forward * commandedSpeed + right * lateralSpeed + Vector3.new(0, verticalSpeed, 0)

		local targetYawRate = 0
		if math.abs(commandedSpeed) >= KartConfig.MIN_STEERING_SPEED then
			local absoluteSpeed = math.abs(commandedSpeed)
			local speedRatio = math.clamp(absoluteSpeed / KartConfig.MAX_FORWARD_SPEED, 0, 1)
			local turnRadius = KartConfig.TURN_RADIUS_LOW_SPEED
				+ (KartConfig.TURN_RADIUS_HIGH_SPEED - KartConfig.TURN_RADIUS_LOW_SPEED) * speedRatio
			local direction = if commandedSpeed >= 0 then 1 else -1
			targetYawRate = -smoothedSteering * (absoluteSpeed / turnRadius) * direction
			if driftActive then
				targetYawRate *= KartConfig.DRIFT_YAW_MULTIPLIER
			end
		end
		currentYawRate = moveToward(currentYawRate, targetYawRate, KartConfig.YAW_ACCELERATION * deltaTime)
		chassis.AssemblyAngularVelocity = Vector3.new(0, currentYawRate, 0)

		local slipAngleDegrees = 0
		if math.abs(actualForwardSpeed) >= 1 then
			slipAngleDegrees = math.deg(math.atan2(lateralSpeed, math.abs(actualForwardSpeed)))
		end

		if KartConfig.DEBUG_TELEMETRY and occupant then
			debugElapsed += deltaTime
			if debugElapsed >= KartConfig.DEBUG_LOG_INTERVAL then
				debugElapsed = 0
				local ageText = if inputAge then string.format("%.2f", inputAge) else "none"
				local rootPart = chassis.AssemblyRootPart
				local boostRemaining = if boostActive then math.max(boostEndTime - now, 0) else 0
				print(string.format(
					"[KartDebug] throttle=%.2f rawSteer=%.2f smoothSteer=%.2f driftReq=%s drift=%s chargeDuration=%.2f qualifiedDuration=%.2f chargeSlip=%.1f boost=%s boostRemaining=%.2f cmdSpeed=%.1f actualSpeed=%.1f speedTarget=%.1f lateral=%.1f slip=%.1f targetYaw=%.2f yaw=%.2f inputAge=%s occupant=true root=%s",
					throttle,
					steering,
					smoothedSteering,
					tostring(driftRequested),
					tostring(driftActive),
					driftDuration,
					qualifiedDuration,
					chargeSlipAngleDegrees,
					tostring(boostActive),
					boostRemaining,
					commandedSpeed,
					actualForwardSpeed,
					forwardTargetSpeed,
					lateralSpeed,
					slipAngleDegrees,
					targetYawRate,
					currentYawRate,
					ageText,
					if rootPart then rootPart.Name else "none"
				))
			end
		else
			debugElapsed = 0
		end
	end)

	print("[RobloxKart] Prototype world ready")
end

return PrototypeWorld
