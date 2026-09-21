local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local KartConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartConfig"))

local PrototypeWorld = {}

type ControlState = {
	throttle: number,
	steering: number,
	lastUpdate: number,
}

local WORLD = {
	GROUND_SIZE = Vector3.new(4096, 1, 4096),
	CHASSIS_SIZE = Vector3.new(6, 1, 8),
	CHASSIS_CLEARANCE = 1.75,
	KART_START = Vector3.new(-350, 0, 410),
	PLAYER_START = Vector3.new(-310, 0.5, 430),
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

	addStraight("Main", TRACK.MAIN_START, TRACK.MAIN_END)
	addArc("LargeCorner", TRACK.LARGE_CORNER_CENTER, TRACK.LARGE_CORNER_RADIUS, math.pi, math.pi, 28)
	addStraight("Return", Vector2.new(10, -300), TRACK.RETURN_END)
	addArc("MediumCorner", TRACK.MEDIUM_CORNER_CENTER, TRACK.MEDIUM_CORNER_RADIUS, math.pi, -math.pi, 20)
	addStraight("Brake", Vector2.new(210, 200), TRACK.BRAKE_END)

	createVisualPart(
		markingFolder,
		"StartLine",
		Vector3.new(TRACK.ROAD_WIDTH, 0.03, 3),
		CFrame.new(point2To3(TRACK.MAIN_START, roadY + 0.025)),
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

	testTrack:SetAttribute("VisualPartCount", partCount)
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

	local chassis = createPart(kart, "Chassis", WORLD.CHASSIS_SIZE, spawnCFrame, Color3.fromRGB(220, 45, 45))
	chassis.Anchored = false
	chassis.RootPriority = 127
	chassis.CustomPhysicalProperties = PhysicalProperties.new(1, 0.05, 0, 1, 1)

	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2.5, 1, 2.5)
	seat.CFrame = spawnCFrame * CFrame.new(0, 1, 0.5)
	seat.Color = Color3.fromRGB(35, 35, 40)
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Massless = true
	seat:SetAttribute("PrototypeKartSeat", true)
	seat.Parent = kart
	weldToChassis(chassis, seat)

	local wheelOffsets = {
		Vector3.new(-3.1, -0.35, -2.5),
		Vector3.new(3.1, -0.35, -2.5),
		Vector3.new(-3.1, -0.35, 2.5),
		Vector3.new(3.1, -0.35, 2.5),
	}
	for index, offset in wheelOffsets do
		local wheel = createPart(kart, `Wheel{index}`, Vector3.new(0.8, 1.8, 1.8), spawnCFrame * CFrame.new(offset), Color3.fromRGB(25, 25, 25))
		wheel.Shape = Enum.PartType.Cylinder
		wheel.CanCollide = false
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
	local debugElapsed = 0

	remoteEvent.OnServerEvent:Connect(function(player: Player, throttle: unknown, steering: unknown)
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
			kart:PivotTo(spawnCFrame)
			commandedSpeed = 0
			smoothedSteering = 0
			currentYawRate = 0
			chassis.AssemblyLinearVelocity = Vector3.zero
			chassis.AssemblyAngularVelocity = Vector3.zero
			return
		end

		local now = time()
		local throttle = 0
		local steering = 0
		local occupant = seat.Occupant
		local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
		local control = player and controls[player]
		local inputAge = if control then now - control.lastUpdate else nil
		if control and inputAge and inputAge <= KartConfig.INPUT_TIMEOUT then
			throttle = control.throttle
			steering = control.steering
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

		if throttle > 0 then
			if commandedSpeed < 0 then
				commandedSpeed = moveToward(commandedSpeed, 0, KartConfig.BRAKE_FORCE * throttle * deltaTime)
			else
				commandedSpeed = moveToward(commandedSpeed, KartConfig.MAX_FORWARD_SPEED, KartConfig.ACCELERATION * throttle * deltaTime)
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

		commandedSpeed = math.clamp(commandedSpeed, -KartConfig.MAX_REVERSE_SPEED, KartConfig.MAX_FORWARD_SPEED)
		lateralSpeed *= math.exp(-KartConfig.LATERAL_GRIP * deltaTime)
		local verticalSpeed = assemblyVelocity.Y
		chassis.AssemblyLinearVelocity = forward * commandedSpeed + right * lateralSpeed + Vector3.new(0, verticalSpeed, 0)

		smoothedSteering = moveToward(smoothedSteering, steering, KartConfig.STEERING_RESPONSE * deltaTime)
		local targetYawRate = 0
		if math.abs(commandedSpeed) >= KartConfig.MIN_STEERING_SPEED then
			local absoluteSpeed = math.abs(commandedSpeed)
			local speedRatio = math.clamp(absoluteSpeed / KartConfig.MAX_FORWARD_SPEED, 0, 1)
			local turnRadius = KartConfig.TURN_RADIUS_LOW_SPEED
				+ (KartConfig.TURN_RADIUS_HIGH_SPEED - KartConfig.TURN_RADIUS_LOW_SPEED) * speedRatio
			local direction = if commandedSpeed >= 0 then 1 else -1
			targetYawRate = -smoothedSteering * (absoluteSpeed / turnRadius) * direction
		end
		currentYawRate = moveToward(currentYawRate, targetYawRate, KartConfig.YAW_ACCELERATION * deltaTime)
		chassis.AssemblyAngularVelocity = Vector3.new(0, currentYawRate, 0)

		if KartConfig.DEBUG_TELEMETRY and occupant then
			debugElapsed += deltaTime
			if debugElapsed >= KartConfig.DEBUG_LOG_INTERVAL then
				debugElapsed = 0
				local ageText = if inputAge then string.format("%.2f", inputAge) else "none"
				local rootPart = chassis.AssemblyRootPart
				print(string.format(
					"[KartDebug] throttle=%.2f rawSteer=%.2f smoothSteer=%.2f cmdSpeed=%.1f actualSpeed=%.1f lateral=%.1f targetYaw=%.2f yaw=%.2f inputAge=%s occupant=true root=%s",
					throttle,
					steering,
					smoothedSteering,
					commandedSpeed,
					actualForwardSpeed,
					lateralSpeed,
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
