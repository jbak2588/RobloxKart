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
	GROUND_SIZE = Vector3.new(512, 1, 512),
	CHASSIS_SIZE = Vector3.new(6, 1, 8),
	CHASSIS_CLEARANCE = 1.75,
	PLAYER_SPAWN_OFFSET = Vector3.new(12, 0.5, 0),
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
	local spawnCFrame = CFrame.new(0, groundTop + WORLD.CHASSIS_CLEARANCE, 0)
	local kart, chassis, seat = createKart(prototype, spawnCFrame)

	if not Workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local playerSpawn = Instance.new("SpawnLocation")
		playerSpawn.Name = "PlayerSpawn"
		playerSpawn.Size = Vector3.new(8, 1, 8)
		playerSpawn.CFrame = CFrame.new(Vector3.new(spawnCFrame.Position.X, groundTop, spawnCFrame.Position.Z) + WORLD.PLAYER_SPAWN_OFFSET)
		playerSpawn.Anchored = true
		playerSpawn.Neutral = true
		playerSpawn.Parent = prototype
	end

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
			kart:PivotTo(spawnCFrame)
			commandedSpeed = 0
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
		local actualForwardSpeed = Vector3.new(chassis.AssemblyLinearVelocity.X, 0, chassis.AssemblyLinearVelocity.Z):Dot(forward)

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
		local verticalSpeed = chassis.AssemblyLinearVelocity.Y
		chassis.AssemblyLinearVelocity = forward * commandedSpeed + Vector3.new(0, verticalSpeed, 0)

		local turnRate = 0
		if math.abs(commandedSpeed) >= KartConfig.MIN_STEERING_SPEED then
			local speedScale = math.clamp(math.abs(commandedSpeed) / KartConfig.MAX_FORWARD_SPEED, 0.25, 1)
			local direction = if commandedSpeed >= 0 then 1 else -1
			turnRate = -steering * KartConfig.STEERING_RATE * speedScale * direction
		end
		chassis.AssemblyAngularVelocity = Vector3.new(0, turnRate, 0)

		if KartConfig.DEBUG_TELEMETRY and occupant then
			debugElapsed += deltaTime
			if debugElapsed >= KartConfig.DEBUG_LOG_INTERVAL then
				debugElapsed = 0
				local ageText = if inputAge then string.format("%.2f", inputAge) else "none"
				local rootPart = chassis.AssemblyRootPart
				print(string.format(
					"[KartDebug] throttle=%.2f steer=%.2f cmdSpeed=%.1f actualSpeed=%.1f inputAge=%s occupant=true root=%s",
					throttle,
					steering,
					commandedSpeed,
					actualForwardSpeed,
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
