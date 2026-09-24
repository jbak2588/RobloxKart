local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local KartConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartConfig"))

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
	KART_START = Vector3.new(-350, 0, 410),
	PLAYER_START = Vector3.new(0, 0.5, 900),
}

local TRACK = {
	ROAD_WIDTH = 60,
	SURFACE_OFFSET = 0.04,
	DASH_LENGTH = 18,
	DASH_SPACING = 40,
	MAIN_START = Vector2.new(-350, 450),
	MAIN_END = Vector2.new(-350, -300),
	LARGE_CORNER_CENTER = Vector2.new(-170, -300),
	LARGE_CORNER_RADIUS = 180,
	RETURN_END = Vector2.new(10, 200),
	MEDIUM_CORNER_CENTER = Vector2.new(110, 200),
	MEDIUM_CORNER_RADIUS = 100,
	BRAKE_END = Vector2.new(210, -260),
	START_FINISH = Vector2.new(-350, 440),
	CLOSURE_SOUTH_END = Vector2.new(210, -560),
	CLOSURE_CORNER_1_CENTER = Vector2.new(70, -560),
	CLOSURE_BOTTOM_START = Vector2.new(70, -700),
	CLOSURE_BOTTOM_END = Vector2.new(-550, -700),
	CLOSURE_CORNER_2_CENTER = Vector2.new(-550, -560),
	CLOSURE_WEST_START = Vector2.new(-690, -560),
	CLOSURE_WEST_END = Vector2.new(-690, 450),
	CLOSURE_CORNER_3_CENTER = Vector2.new(-550, 450),
	CLOSURE_TOP_START = Vector2.new(-550, 590),
	CLOSURE_TOP_END = Vector2.new(-490, 590),
	CLOSURE_CORNER_4_CENTER = Vector2.new(-490, 450),
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

local function createHandlingTestCourse(prototype: Folder, groundTop: number): number
	local previousTrack = prototype:FindFirstChild("TestTrack")
	if previousTrack then
		previousTrack:Destroy()
	end

	local testTrack = Instance.new("Model")
	testTrack.Name = "TestTrack"
	testTrack.Parent = prototype

	local roadFolder = Instance.new("Folder")
	roadFolder.Name = "Road"
	roadFolder.Parent = testTrack

	local markingFolder = Instance.new("Folder")
	markingFolder.Name = "Markings"
	markingFolder.Parent = testTrack

	local markerFolder = Instance.new("Folder")
	markerFolder.Name = "Markers"
	markerFolder.Parent = testTrack

	local raceTriggerFolder = Instance.new("Folder")
	raceTriggerFolder.Name = "RaceTriggers"
	raceTriggerFolder.Parent = testTrack

	local roadY = groundTop + TRACK.SURFACE_OFFSET
	local partCount = 0
	local roadColor = Color3.fromRGB(48, 51, 56)
	local white = Color3.fromRGB(245, 245, 235)
	local yellow = Color3.fromRGB(255, 205, 55)

	local function point2To3(point: Vector2, y: number?): Vector3
		return Vector3.new(point.X, y or roadY, point.Y)
	end

	local function createVisualPart(
		parent: Instance,
		name: string,
		size: Vector3,
		cframe: CFrame,
		color: Color3,
		material: Enum.Material?
	): Part
		local part = createPart(parent, name, size, cframe, color)
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = material or Enum.Material.SmoothPlastic
		partCount += 1
		return part
	end

	local function createSegment(
		parent: Instance,
		name: string,
		startPoint: Vector3,
		endPoint: Vector3,
		width: number,
		thickness: number,
		color: Color3,
		material: Enum.Material?
	): Part
		local delta = endPoint - startPoint
		local midpoint = (startPoint + endPoint) * 0.5
		return createVisualPart(
			parent,
			name,
			Vector3.new(width, thickness, delta.Magnitude + 0.5),
			CFrame.lookAt(midpoint, midpoint + delta.Unit),
			color,
			material
		)
	end

	local function addStraight(name: string, start2: Vector2, end2: Vector2)
		local startPoint = point2To3(start2)
		local endPoint = point2To3(end2)
		local direction = (endPoint - startPoint).Unit
		local right = Vector3.new(-direction.Z, 0, direction.X)
		local halfWidth = TRACK.ROAD_WIDTH * 0.5

		createSegment(roadFolder, `{name}Road`, startPoint, endPoint, TRACK.ROAD_WIDTH, 0.05, roadColor, Enum.Material.Asphalt)
		for side, sign in { Left = -1, Right = 1 } do
			local offset = right * halfWidth * sign + Vector3.new(0, 0.03, 0)
			createSegment(markingFolder, `{name}{side}Edge`, startPoint + offset, endPoint + offset, 1, 0.035, white, nil)
		end

		local length = (endPoint - startPoint).Magnitude
		local dashIndex = 0
		for distance = TRACK.DASH_LENGTH * 0.5, length - TRACK.DASH_LENGTH * 0.5, TRACK.DASH_SPACING do
			dashIndex += 1
			local center = startPoint + direction * distance + Vector3.new(0, 0.025, 0)
			local halfDash = direction * (TRACK.DASH_LENGTH * 0.5)
			createSegment(markingFolder, `{name}Dash{dashIndex}`, center - halfDash, center + halfDash, 0.8, 0.025, white, nil)
		end
	end

	local function arcPoint(center: Vector2, radius: number, angle: number, y: number?): Vector3
		return Vector3.new(center.X + math.cos(angle) * radius, y or roadY, center.Y + math.sin(angle) * radius)
	end

	local function addArc(name: string, center: Vector2, radius: number, startAngle: number, sweep: number, segmentCount: number)
		local halfWidth = TRACK.ROAD_WIDTH * 0.5
		for index = 1, segmentCount do
			local alpha0 = (index - 1) / segmentCount
			local alpha1 = index / segmentCount
			local angle0 = startAngle + sweep * alpha0
			local angle1 = startAngle + sweep * alpha1
			local startPoint = arcPoint(center, radius, angle0)
			local endPoint = arcPoint(center, radius, angle1)

			createSegment(roadFolder, `{name}Road{index}`, startPoint, endPoint, TRACK.ROAD_WIDTH, 0.05, roadColor, Enum.Material.Asphalt)
			createSegment(markingFolder, `{name}Inner{index}`, arcPoint(center, radius - halfWidth, angle0, roadY + 0.03), arcPoint(center, radius - halfWidth, angle1, roadY + 0.03), 1, 0.035, white, nil)
			createSegment(markingFolder, `{name}Outer{index}`, arcPoint(center, radius + halfWidth, angle0, roadY + 0.03), arcPoint(center, radius + halfWidth, angle1, roadY + 0.03), 1, 0.035, white, nil)

			if index % 2 == 1 then
				local chord = endPoint - startPoint
				local centerPoint = (startPoint + endPoint) * 0.5 + Vector3.new(0, 0.025, 0)
				local halfDash = chord.Unit * math.min(TRACK.DASH_LENGTH * 0.5, chord.Magnitude * 0.3)
				createSegment(markingFolder, `{name}Dash{index}`, centerPoint - halfDash, centerPoint + halfDash, 0.8, 0.025, white, nil)
			end
		end
	end

	local function addBillboardSign(name: string, position: Vector3, text: string, color: Color3)
		createVisualPart(markerFolder, `{name}Pole`, Vector3.new(1, 10, 1), CFrame.new(position + Vector3.new(0, 5, 0)), color, nil)
		local board = createVisualPart(markerFolder, `{name}Board`, Vector3.new(10, 5, 0.5), CFrame.new(position + Vector3.new(0, 11, 0)), color, nil)

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "Label"
		billboard.Size = UDim2.fromOffset(100, 50)
		billboard.AlwaysOnTop = true
		billboard.Adornee = board
		billboard.Parent = board

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = billboard
	end

	local function createRaceGate(
		name: string,
		position: Vector2,
		direction: Vector3,
		gateType: string,
		checkpointIndex: number?
	)
		local gatePosition = point2To3(position, groundTop + 8)
		local gate = createPart(
			raceTriggerFolder,
			name,
			Vector3.new(80, 20, 20),
			CFrame.lookAt(gatePosition, gatePosition + direction),
			Color3.new(1, 1, 1)
		)
		gate.Anchored = true
		gate.CanCollide = false
		gate.CanTouch = false
		gate.CanQuery = false
		gate.Transparency = 1
		gate:SetAttribute("RaceGate", true)
		gate:SetAttribute("GateType", gateType)
		if checkpointIndex then
			gate:SetAttribute("CheckpointIndex", checkpointIndex)
		end
	end

	addStraight("Main", TRACK.MAIN_START, TRACK.MAIN_END)
	addArc("LargeCorner", TRACK.LARGE_CORNER_CENTER, TRACK.LARGE_CORNER_RADIUS, math.pi, math.pi, 28)
	addStraight("Return", Vector2.new(10, -300), TRACK.RETURN_END)
	addArc("MediumCorner", TRACK.MEDIUM_CORNER_CENTER, TRACK.MEDIUM_CORNER_RADIUS, math.pi, -math.pi, 20)
	addStraight("Brake", Vector2.new(210, 200), TRACK.BRAKE_END)
	addStraight("ClosureSouth", TRACK.BRAKE_END, TRACK.CLOSURE_SOUTH_END)
	addArc("ClosureCorner1", TRACK.CLOSURE_CORNER_1_CENTER, 140, 0, -math.pi / 2, 10)
	addStraight("ClosureBottom", TRACK.CLOSURE_BOTTOM_START, TRACK.CLOSURE_BOTTOM_END)
	addArc("ClosureCorner2", TRACK.CLOSURE_CORNER_2_CENTER, 140, -math.pi / 2, -math.pi / 2, 10)
	addStraight("ClosureWest", TRACK.CLOSURE_WEST_START, TRACK.CLOSURE_WEST_END)
	addArc("ClosureCorner3", TRACK.CLOSURE_CORNER_3_CENTER, 140, math.pi, -math.pi / 2, 10)
	addStraight("ClosureTop", TRACK.CLOSURE_TOP_START, TRACK.CLOSURE_TOP_END)
	addArc("ClosureCorner4", TRACK.CLOSURE_CORNER_4_CENTER, 140, math.pi / 2, -math.pi / 2, 10)

	createVisualPart(
		markingFolder,
		"StartLine",
		Vector3.new(TRACK.ROAD_WIDTH, 0.03, 3),
		CFrame.new(point2To3(TRACK.START_FINISH, roadY + 0.025)),
		white,
		nil
	)

	for _, distance in { 0, 100, 200, 300, 400, 500 } do
		local z = TRACK.MAIN_START.Y - distance
		addBillboardSign(`Distance{distance}`, Vector3.new(-392, groundTop, z), tostring(distance), Color3.fromRGB(40, 115, 220))
	end

	local brakeMarkers = {
		{ label = "100", z = 100 },
		{ label = "50", z = 0 },
		{ label = "BRAKE", z = -100 },
	}
	for index, marker in brakeMarkers do
		addBillboardSign(`Brake{index}`, Vector3.new(252, groundTop, marker.z), marker.label, Color3.fromRGB(220, 70, 45))
		createVisualPart(
			markingFolder,
			`BrakeStripe{index}`,
			Vector3.new(TRACK.ROAD_WIDTH, 0.03, 2),
			CFrame.new(210, roadY + 0.025, marker.z),
			yellow,
			nil
		)
	end

	for index = 1, 8 do
		local xOffset = if index % 2 == 0 then 18 else -18
		local z = -180 + (index - 1) * 45
		createVisualPart(
			markerFolder,
			`Slalom{index}`,
			Vector3.new(3, 8, 3),
			CFrame.new(10 + xOffset, groundTop + 4, z),
			Color3.fromRGB(255, 120, 25),
			Enum.Material.Neon
		)
	end

	local poleIndex = 0
	for distance = 0, 700, 100 do
		local z = TRACK.MAIN_START.Y - distance
		for _, x in { -398, -302 } do
			poleIndex += 1
			createVisualPart(
				markerFolder,
				`ReferencePole{poleIndex}`,
				Vector3.new(1.5, 14, 1.5),
				CFrame.new(x, groundTop + 7, z),
				if poleIndex % 2 == 0 then white else Color3.fromRGB(55, 145, 240),
				nil
			)
		end
	end

	createRaceGate("StartFinish", TRACK.START_FINISH, Vector3.new(0, 0, -1), "StartFinish", nil)
	createRaceGate("Checkpoint1", Vector2.new(-350, 100), Vector3.new(0, 0, -1), "Checkpoint", 1)
	createRaceGate("Checkpoint2", Vector2.new(10, 0), Vector3.new(0, 0, 1), "Checkpoint", 2)
	createRaceGate("Checkpoint3", Vector2.new(210, 0), Vector3.new(0, 0, -1), "Checkpoint", 3)
	createRaceGate("Checkpoint4", Vector2.new(-250, -700), Vector3.new(-1, 0, 0), "Checkpoint", 4)
	createRaceGate("Checkpoint5", Vector2.new(-690, 0), Vector3.new(0, 0, 1), "Checkpoint", 5)
	createRaceGate("Checkpoint6", Vector2.new(-520, 590), Vector3.new(1, 0, 0), "Checkpoint", 6)

	testTrack:SetAttribute("VisualPartCount", partCount)
	testTrack:SetAttribute("CheckpointCount", 6)
	return partCount
end

local function weldToChassis(chassis: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = part
	weld.Parent = part
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

	local bodyShell = createPart(
		kart,
		"BodyShell",
		Vector3.new(6.2, 1.2, 8.2),
		spawnCFrame * CFrame.new(0, 0.7, 0),
		Color3.fromRGB(220, 45, 45)
	)
	bodyShell.Anchored = false
	bodyShell.CanCollide = false
	bodyShell.CanTouch = false
	bodyShell.Massless = true
	weldToChassis(chassis, bodyShell)

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

	local wheelOffsets = {
		Vector3.new(-3.35, 0.55, -2.7),
		Vector3.new(3.35, 0.55, -2.7),
		Vector3.new(-3.35, 0.55, 2.7),
		Vector3.new(3.35, 0.55, 2.7),
	}
	for index, offset in wheelOffsets do
		local wheel = createPart(kart, `Wheel{index}`, Vector3.new(0.9, 2, 2), spawnCFrame * CFrame.new(offset), Color3.fromRGB(25, 25, 25))
		wheel.Shape = Enum.PartType.Cylinder
		wheel.CanCollide = false
		wheel.CanTouch = false
		wheel.Massless = true
		weldToChassis(chassis, wheel)
	end

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

	createHandlingTestCourse(prototype, groundTop)
	print("[RobloxKart] Handling test course ready")

	local spawnCFrame = CFrame.new(WORLD.KART_START.X, groundTop + WORLD.CHASSIS_CLEARANCE, WORLD.KART_START.Z)
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

		controls[player] = {
			throttle = math.clamp(throttle, -1, 1),
			steering = math.clamp(steering, -1, 1),
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
