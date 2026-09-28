local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local KartConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartConfig"))
local KartCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartCatalog"))
local TrackCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrackCatalog"))
local KartVisualFactory = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartVisualFactory"))
local TrackBuilder = require(script.Parent:WaitForChild("TrackBuilder"))
local NitroState = require(script.Parent:WaitForChild("NitroState"))
local SlickMotion = require(script.Parent:WaitForChild("SlickMotion"))
local DriftTelemetry = require(script.Parent:WaitForChild("DriftTelemetry"))
local RaceItemGeometry = require(script.Parent:WaitForChild("RaceItemGeometry"))
local RaceItemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaceItemConfig"))
local RaceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaceConfig"))

local PrototypeWorld = {}
local nitroActivation = nil
local raceKartProvider = nil
local slickHit = nil

function PrototypeWorld.getRaceKart(player: Player)
	if raceKartProvider then return raceKartProvider(player) end
	return nil
end

function PrototypeWorld.applySlickHit(player: Player): boolean
	return slickHit ~= nil and slickHit(player)
end

function PrototypeWorld.activateNitro(player: Player): (boolean, string?)
	if not nitroActivation then return false, "world_not_started" end
	return nitroActivation(player)
end

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
	kart:SetAttribute("KartNitroActive", false)
	kart:SetAttribute("KartSlickActive", false)
	kart:SetAttribute("KartShieldActive", false)
	kart:SetAttribute("RaceItemHitImmunity", false)
	kart:SetAttribute("KartOffTrack", false)
	kart:SetAttribute("KartVisualSteering", 0)
	kart:SetAttribute("KartCrashActive", false)
	kart:SetAttribute("RaceResetSerial", 0)
	kart:SetAttribute("RaceStartCFrame", spawnCFrame)
	kart:SetAttribute("RaceControlsLocked", true)
	kart:SetAttribute("KartFinishRollActive", false)
	kart:SetAttribute("KartFinishRollDirection", Vector3.new(0, 0, -1))

	local chassis = createPart(kart, "Chassis", WORLD.CHASSIS_SIZE, spawnCFrame, Color3.fromRGB(220, 45, 45))
	chassis.Anchored = false
	chassis.CanCollide = true
	chassis.Massless = false
	chassis.Transparency = 1
	chassis.RootPriority = 127
	chassis.CustomPhysicalProperties = PhysicalProperties.new(1, 0.05, 0, 1, 1)

	local visual = KartVisualFactory.createVisual(KartCatalog.Entries[KartCatalog.DefaultId])
	-- PrimaryPart is StaticRoot at the factory's chassis-local origin. Move the
	-- complete welded hierarchy together before binding its six assembly roots.
	visual:PivotTo(spawnCFrame)
	visual.Parent = kart
	for _, part in visual:GetChildren() do
		if part:IsA("BasePart") then
			if part.Name == "StaticRoot" then
				weldToChassis(chassis, part)
			elseif part:GetAttribute("VisualMotionRole") then
				motorToChassis(chassis, part)
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

local function isInsideBarrier(trigger: BasePart, position: Vector3): boolean
	local localPosition = trigger.CFrame:PointToObjectSpace(position)
	local halfSize = trigger.Size * 0.5
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
end

local function crossedBarrier(trigger: BasePart, fromPosition: Vector3, toPosition: Vector3): boolean
	local start = trigger.CFrame:PointToObjectSpace(fromPosition)
	local finish = trigger.CFrame:PointToObjectSpace(toPosition)
	local half = trigger.Size * 0.5
	local starts = { start.X, start.Y, start.Z }
	local steps = { finish.X - start.X, finish.Y - start.Y, finish.Z - start.Z }
	local limits = { half.X, half.Y, half.Z }
	local entry = 0
	local exit = 1
	for axis = 1, 3 do
		local origin = starts[axis]
		local step = steps[axis]
		local limit = limits[axis]
		if math.abs(step) < 0.0001 then
			if math.abs(origin) > limit then
				return false
			end
		else
			local first = (-limit - origin) / step
			local second = (limit - origin) / step
			entry = math.max(entry, math.min(first, second))
			exit = math.min(exit, math.max(first, second))
			if entry > exit then
				return false
			end
		end
	end
	return true
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
	local driftTelemetry = DriftTelemetry.new(kart, KartConfig)
	local pendingDriftEnd: string? = nil
	local pendingBoostEligible = false
	local boostActive = false
	local boostEndTime = 0
	local boostDriver: Player? = nil
	local nitro = NitroState.new(KartConfig)
	local slick = SlickMotion.new(RaceItemConfig)
	local raceControlsWereLocked = kart:GetAttribute("RaceControlsLocked") == true
	local debugElapsed = 0
	local cachedTrack: Model? = nil
	local barrierTriggers: { BasePart } = {}
	local insideBarrier: { [BasePart]: boolean } = {}
	local lastBarrierPosition = chassis.Position
	local crashActive = false
	local crashEndTime = 0
	local crashAlignStartTime = 0
	local crashAlignDeadline = 0
	local crashCooldownEndTime = 0
	local crashVelocity = Vector3.zero
	local crashSpinRate = 0
	local crashTrackForward = Vector3.new(0, 0, -1)
	local lastPlanarForward = Vector3.new(0, 0, -1)
	local finishRollElapsed = 0
	local finishRollInitialSpeed = 0
	local finishRollDirection = Vector3.new(0, 0, -1)

	local function stopSlick()
		slick:stop()
		kart:SetAttribute("KartSlickActive", false)
	end
	raceKartProvider = function(player: Player)
		if not kart.Parent or not chassis.Parent or not seat.Parent or crashActive then return nil end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart ~= seat or seat.Occupant ~= humanoid then return nil end
		if player:GetAttribute("RaceState") ~= "RACING" or kart:GetAttribute("RaceControlsLocked") ~= false then return nil end
		return kart, chassis
	end

	local function stopNitro(reason: string)
		nitro:stop(reason)
		kart:SetAttribute("KartNitroActive", false)
	end
	nitroActivation = function(player: Player)
		if not kart.Parent or not chassis.Parent or not seat.Parent then return false, "kart_missing" end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or seat.Occupant ~= humanoid or humanoid.SeatPart ~= seat then
			return false, "not_driver"
		end
		if kart:GetAttribute("RaceControlsLocked") ~= false or player:GetAttribute("RaceState") ~= "RACING" then
			return false, "race_locked"
		end
		if crashActive or slick.active or kart:GetAttribute("KartOffTrack") == true then return false, "unsafe_state" end
		local control = controls[player]
		if not control or time() - control.lastUpdate > KartConfig.INPUT_TIMEOUT then return false, "input_timeout" end
		local accepted, reason = nitro:activate(player, time())
		if accepted then kart:SetAttribute("KartNitroActive", true) end
		return accepted, reason
	end
	kart:GetAttributeChangedSignal("RaceControlsLocked"):Connect(function()
		if kart:GetAttribute("RaceControlsLocked") then stopNitro("locked"); stopSlick() end
	end)
	kart:GetAttributeChangedSignal("KartOffTrack"):Connect(function()
		if kart:GetAttribute("KartOffTrack") then
			if nitro.active or nitro.exiting then
				commandedSpeed = math.min(commandedSpeed, KartConfig.OFF_TRACK_MAX_SPEED)
			end
			stopNitro("off_track")
			stopSlick()
		end
	end)
	kart:GetAttributeChangedSignal("RaceResetSerial"):Connect(function() stopNitro("reset"); stopSlick() end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function() stopNitro("occupant_changed"); stopSlick() end)
	kart.Destroying:Connect(function()
		stopNitro("destroyed")
		stopSlick()
		nitroActivation = nil
		raceKartProvider, slickHit = nil, nil
	end)
	local function bindNitroLifecycle(player)
		player.CharacterRemoving:Connect(function()
			if nitro.driver == player then stopNitro("character_removed") end
			if slick.driver == player then stopSlick() end
		end)
		player:GetAttributeChangedSignal("RaceState"):Connect(function()
			if player:GetAttribute("RaceState") ~= "RACING" and nitro.driver == player then stopNitro("race_state") end
			if player:GetAttribute("RaceState") ~= "RACING" and slick.driver == player then stopSlick() end
		end)
	end
	Players.PlayerAdded:Connect(bindNitroLifecycle)
	for _, player in Players:GetPlayers() do bindNitroLifecycle(player) end

	local function setDriftActive(active: boolean, reason: string)
		if driftActive == active then
			return
		end
		driftActive = active
		if active then driftTelemetry:begin()
		else pendingDriftEnd = reason end
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
		if pendingDriftEnd then
			driftTelemetry:finish(pendingDriftEnd, driftDuration, qualifiedDuration, pendingBoostEligible)
		end
		pendingDriftEnd, pendingBoostEligible = nil, false
		driftTelemetry:clearCharge()
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

	-- Reset display state immediately at lifecycle boundaries; simulation reset
	-- remains in its existing paths below.
	kart:GetAttributeChangedSignal("RaceResetSerial"):Connect(function() driftTelemetry:clear() end)
	kart:GetAttributeChangedSignal("RaceControlsLocked"):Connect(function()
		if kart:GetAttribute("RaceControlsLocked") then driftTelemetry:clear() end
	end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function() driftTelemetry:clear() end)

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

	local function refreshBarrierTriggers()
		local currentTrack = prototype:FindFirstChild("TestTrack")
		if currentTrack == cachedTrack then
			return
		end
		cachedTrack = if currentTrack and currentTrack:IsA("Model") then currentTrack else nil
		table.clear(barrierTriggers)
		table.clear(insideBarrier)
		lastBarrierPosition = chassis.Position
		if cachedTrack then
			local folder = cachedTrack:FindFirstChild("BarrierTriggers")
			if folder then
				for _, child in folder:GetChildren() do
					if child:IsA("BasePart") then
						table.insert(barrierTriggers, child)
					end
				end
			end
		end
	end

	slickHit = function(player: Player): boolean
		if not raceKartProvider(player) or slick.active or kart:GetAttribute("KartOffTrack") == true then return false end
		local road = RaceItemGeometry.roadAt(prototype, chassis.Position)
		if not road then return false end
		local look = chassis.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z)
		local legal = road.CFrame.LookVector
		legal = Vector3.new(legal.X, 0, legal.Z)
		if forward.Magnitude < 0.001 or legal.Magnitude < 0.001 then return false end
		local velocity = chassis.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		stopNitro("slick")
		stopBoost("slick")
		setDriftActive(false, "slick")
		resetDriftCharge()
		commandedSpeed, smoothedSteering, currentYawRate = 0, 0, 0
		kart:SetAttribute("KartVisualSteering", 0)
		slick:start(player, time(), forward.Unit, legal.Unit, speed)
		kart:SetAttribute("KartSlickActive", true)
		return true
	end

	local function stopCrash()
		if not crashActive then
			return
		end
		crashActive = false
		crashSpinRate = 0
		kart:SetAttribute("KartCrashActive", false)
		chassis.AssemblyAngularVelocity = Vector3.zero
	end

	kart:GetAttributeChangedSignal("KartFinishRollActive"):Connect(function()
		if kart:GetAttribute("KartFinishRollActive") ~= true then
			finishRollElapsed, finishRollInitialSpeed = 0, 0
			return
		end
		local direction = kart:GetAttribute("KartFinishRollDirection")
		if typeof(direction) == "Vector3" then
			local flat = Vector3.new(direction.X, 0, direction.Z)
			if flat.Magnitude > 0.001 then finishRollDirection = flat.Unit end
		end
		local velocity = chassis.AssemblyLinearVelocity
		finishRollInitialSpeed = math.max(0, Vector3.new(velocity.X, 0, velocity.Z):Dot(finishRollDirection))
		finishRollElapsed = 0
		stopNitro("finish")
		stopBoost("finish")
		stopSlick()
		stopCrash()
		setDriftActive(false, "finish")
		resetDriftCharge()
		commandedSpeed, smoothedSteering, currentYawRate = 0, 0, 0
		kart:SetAttribute("KartVisualSteering", 0)
	end)

	local function startBarrierResponse(inwardNormal: Vector3, trackForward: Vector3, approachSpeed: number, planarVelocity: Vector3, now: number)
		local strongImpact = approachSpeed >= KartConfig.BARRIER_CRASH_MIN_SPEED
		local severity = math.clamp(
			(approachSpeed - KartConfig.BARRIER_CRASH_MIN_SPEED)
				/ (KartConfig.MINI_BOOST_MAX_SPEED - KartConfig.BARRIER_CRASH_MIN_SPEED), 0, 1
		)
		local duration = if strongImpact
			then KartConfig.BARRIER_CRASH_DURATION_MIN
				+ (KartConfig.BARRIER_CRASH_DURATION_MAX - KartConfig.BARRIER_CRASH_DURATION_MIN) * severity
			else 0.22
		local reboundSpeed = if strongImpact
			then math.clamp(
				approachSpeed * KartConfig.BARRIER_CRASH_BOUNCE_FACTOR,
				KartConfig.BARRIER_CRASH_MIN_REBOUND_SPEED,
				KartConfig.BARRIER_CRASH_MAX_REBOUND_SPEED
			)
			else 5 + 3 * math.clamp(approachSpeed / KartConfig.BARRIER_CRASH_MIN_SPEED, 0, 1)
		-- The forward component keeps the rebound on the legal side of the race direction.
		local lateralInward = inwardNormal - trackForward * inwardNormal:Dot(trackForward)
		if lateralInward.Magnitude < 0.001 then
			local right = Vector3.new(-trackForward.Z, 0, trackForward.X)
			lateralInward = right * (if right:Dot(inwardNormal) >= 0 then 1 else -1)
		end
		local reboundDirection = (lateralInward.Unit * 0.75 + trackForward * 0.4).Unit
		crashVelocity = reboundDirection * reboundSpeed
		crashTrackForward = trackForward
		local spinTurns = KartConfig.BARRIER_CRASH_MIN_SPIN_TURNS
			+ (KartConfig.BARRIER_CRASH_MAX_SPIN_TURNS - KartConfig.BARRIER_CRASH_MIN_SPIN_TURNS) * severity
		local cross = planarVelocity:Cross(inwardNormal).Y
		local spinDirection = if cross < 0 then -1 else 1
		crashSpinRate = if strongImpact then spinDirection * spinTurns * 2 * math.pi / duration else 0
		crashEndTime = now + duration
		crashAlignStartTime = crashEndTime - math.min(0.35, duration * 0.54)
		crashAlignDeadline = crashEndTime + 0.2
		crashCooldownEndTime = crashEndTime + KartConfig.BARRIER_CRASH_COOLDOWN
		crashActive = true
		commandedSpeed = 0
		smoothedSteering = 0
		currentYawRate = 0
		kart:SetAttribute("KartVisualSteering", 0)
		setDriftActive(false, "barrier")
		resetDriftCharge()
		stopBoost("barrier")
		stopNitro("barrier")
		stopSlick()
		kart:SetAttribute("KartCrashActive", true)
		chassis.AssemblyLinearVelocity = crashVelocity
		chassis.AssemblyAngularVelocity = Vector3.new(0, crashSpinRate, 0)
		print(string.format("[KartBarrier] impact approach=%.1f rebound=%.1f spin=%.2f duration=%.2f", approachSpeed, reboundSpeed, if strongImpact then spinTurns else 0, duration))
	end

	local function checkBarrierEntries(now: number, fromPosition: Vector3, planarVelocity: Vector3): boolean
		local bestNormal: Vector3? = nil
		local bestForward: Vector3? = nil
		local bestApproach = KartConfig.BARRIER_CONTACT_MIN_SPEED
		local pushNormal: Vector3? = nil
		local pushApproach = KartConfig.BARRIER_CONTACT_MIN_SPEED
		for _, trigger in barrierTriggers do
			local inside = isInsideBarrier(trigger, chassis.Position)
			local entered = not insideBarrier[trigger]
				and (inside or crossedBarrier(trigger, fromPosition, chassis.Position))
			insideBarrier[trigger] = inside
			if (entered or inside) and not crashActive then
				local normal = trigger:GetAttribute("BarrierInwardNormal")
				local trackForward = trigger:GetAttribute("BarrierForwardTangent")
				if typeof(normal) == "Vector3" and typeof(trackForward) == "Vector3" then
					local approach = -planarVelocity:Dot(normal)
					if entered and now >= crashCooldownEndTime and approach >= bestApproach then
						bestNormal = normal
						bestForward = trackForward
						bestApproach = approach
					elseif approach >= pushApproach then
						pushNormal = normal
						pushApproach = approach
					end
				end
			end
		end
		if bestNormal and bestForward then
			startBarrierResponse(bestNormal, bestForward, bestApproach, planarVelocity, now)
			return true
		end
		if pushNormal then
			-- Keep the kart outside a trigger during cooldown without a second spin.
			commandedSpeed = 0
			chassis.AssemblyLinearVelocity = pushNormal * KartConfig.BARRIER_CONTACT_PUSH_SPEED
			chassis.AssemblyAngularVelocity = Vector3.zero
			return true
		end
		return false
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
		local visualSteering = if kart:GetAttribute("RaceControlsLocked") == true or crashActive or slick.active then 0 else validatedSteering
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
		if nitro.driver == player then stopNitro("player_removed") end
		if slick.driver == player then stopSlick() end
	end)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		-- Snapshot before early exits or collision responses alter motion. This is
		-- diagnostic-only; input validation and simulation below are unchanged.
		do
			local occupant = seat.Occupant
			local driver = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
			local control = driver and controls[driver]
			local age = control and time()-control.lastUpdate
			local valid = age ~= nil and age <= KartConfig.INPUT_TIMEOUT
			local look, right = chassis.CFrame.LookVector, chassis.CFrame.RightVector
			local flatLook, flatRight = Vector3.new(look.X,0,look.Z), Vector3.new(right.X,0,right.Z)
			local forward = if flatLook.Magnitude>0.001 then flatLook.Unit else Vector3.new(0,0,-1)
			local sideways = if flatRight.Magnitude>0.001 then flatRight.Unit else Vector3.new(1,0,0)
			local velocity = chassis.AssemblyLinearVelocity
			local speed = velocity:Dot(forward)
			local slip = if math.abs(speed)>=1 then math.deg(math.atan2(velocity:Dot(sideways),math.abs(speed))) else 0
			driftTelemetry:observe(age,deltaTime,speed,slip,if control then control.steering else 0,
				smoothedSteering,if control and valid then control.throttle else 0,valid)
		end
		refreshBarrierTriggers()
		local previousBarrierPosition = lastBarrierPosition
		lastBarrierPosition = chassis.Position
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
			stopNitro("fall")
			stopSlick()
			stopCrash()
			chassis.AssemblyLinearVelocity = Vector3.zero
			chassis.AssemblyAngularVelocity = Vector3.zero
			return
		end

		local raceControlsLocked = kart:GetAttribute("RaceControlsLocked") == true
		if kart:GetAttribute("KartFinishRollActive") == true then
			finishRollElapsed += deltaTime
			local alpha = math.clamp(finishRollElapsed / RaceConfig.FINISH_ROLL_SECONDS, 0, 1)
			local verticalSpeed = chassis.AssemblyLinearVelocity.Y
			chassis.AssemblyLinearVelocity = finishRollDirection * (finishRollInitialSpeed * (1 - alpha))
				+ Vector3.new(0, verticalSpeed, 0)
			chassis.AssemblyAngularVelocity = Vector3.zero
			raceControlsWereLocked = true
			return
		end
		if raceControlsLocked then
			stopNitro("locked")
			stopSlick()
			stopCrash()
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
		nitro:update(now, player, player ~= nil and player:GetAttribute("RaceState") == "RACING",
			kart:GetAttribute("KartOffTrack") == true, crashActive, hasValidInput)
		kart:SetAttribute("KartNitroActive", nitro.active)

		local assemblyVelocity = chassis.AssemblyLinearVelocity
		local planarVelocity = Vector3.new(assemblyVelocity.X, 0, assemblyVelocity.Z)
		local barrierHandled = if occupant and player
			then checkBarrierEntries(now, previousBarrierPosition, planarVelocity)
			else false
		if crashActive then
			if chassis.CFrame.UpVector.Y < 0.55 then
				local look = chassis.CFrame.LookVector
				local flatLook = Vector3.new(look.X, 0, look.Z)
				local heading = if flatLook.Magnitude > 0.001 then flatLook.Unit else lastPlanarForward
				kart:PivotTo(CFrame.lookAt(chassis.Position, chassis.Position + heading))
			end
			local look = chassis.CFrame.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			local forward = if flatLook.Magnitude > 0.001 then flatLook.Unit else lastPlanarForward
			local headingError = math.atan2(forward:Cross(crashTrackForward).Y, forward:Dot(crashTrackForward))
			if now >= crashEndTime and (math.abs(headingError) <= math.rad(20) or now >= crashAlignDeadline) then
				chassis.AssemblyLinearVelocity = Vector3.zero
				stopCrash()
				return
			end
			crashVelocity *= math.exp(-KartConfig.BARRIER_CRASH_DAMPING * deltaTime)
			chassis.AssemblyLinearVelocity = crashVelocity
			local spinWeight = math.clamp((crashAlignStartTime + 0.08 - now) / 0.08, 0, 1)
			local alignmentYawRate = math.clamp(headingError * 16, -12, 12)
			local yawRate = crashSpinRate * spinWeight + alignmentYawRate * (1 - spinWeight)
			chassis.AssemblyAngularVelocity = Vector3.new(0, yawRate, 0)
			return
		end
		if barrierHandled then
			return
		end
		if slick.active then
			if slick.driver ~= player or not player or player:GetAttribute("RaceState") ~= "RACING"
				or kart:GetAttribute("KartOffTrack") == true then
				stopSlick()
			else
				local look = chassis.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				local heading = if flat.Magnitude > 0.001 then flat.Unit else lastPlanarForward
				local velocity, yaw, complete = slick:sample(now, heading)
				-- No teleport, roll or pitch impulse; preserve existing vertical motion.
				chassis.AssemblyLinearVelocity = velocity + Vector3.new(0, assemblyVelocity.Y, 0)
				chassis.AssemblyAngularVelocity = Vector3.new(0, yaw, 0)
				if complete then
					commandedSpeed = math.max(0, velocity:Dot(heading))
					currentYawRate = 0
					chassis.AssemblyAngularVelocity = Vector3.zero
					stopSlick()
				end
				return
			end
		end

		local lookVector = chassis.CFrame.LookVector
		local flatForward = Vector3.new(lookVector.X, 0, lookVector.Z)
		local forward = if flatForward.Magnitude > 0.001 then flatForward.Unit else Vector3.new(0, 0, -1)
		if chassis.CFrame.UpVector.Y >= 0.55 then
			lastPlanarForward = forward
		end
		local rightVector = chassis.CFrame.RightVector
		local flatRight = Vector3.new(rightVector.X, 0, rightVector.Z)
		local right = if flatRight.Magnitude > 0.001 then flatRight.Unit else Vector3.new(1, 0, 0)
		local actualForwardSpeed = planarVelocity:Dot(forward)
		local lateralSpeed = planarVelocity:Dot(right)
		local driftForwardSpeed = math.max(actualForwardSpeed, 0)
		local chargeSlipAngleDegrees = 0
		if math.abs(actualForwardSpeed) >= 1 then
			chargeSlipAngleDegrees = math.deg(math.atan2(lateralSpeed, math.abs(actualForwardSpeed)))
		end

		smoothedSteering = moveToward(smoothedSteering, steering, KartConfig.STEERING_RESPONSE * deltaTime)
		driftTelemetry.frame.steer = smoothedSteering
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
			pendingBoostEligible = canStartBoost
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

		driftTelemetry:update(driftDuration, qualifiedDuration)
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

		local forwardTargetSpeed = if nitro.active then KartConfig.NITRO_MAX_SPEED elseif boostActive
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
			elseif (nitro.active or nitro.exiting) and not offTrack then
				commandedSpeed = nitro:forwardSpeed(commandedSpeed, boostActive, throttle, deltaTime)
			elseif offTrack and commandedSpeed > forwardTargetSpeed then
				commandedSpeed = moveToward(commandedSpeed, forwardTargetSpeed, KartConfig.BRAKE_FORCE * deltaTime)
			elseif driftActive and commandedSpeed > forwardTargetSpeed then
				commandedSpeed = moveToward(
					commandedSpeed,
					forwardTargetSpeed,
					KartConfig.DRIFT_SPEED_DECELERATION * deltaTime
				)
			elseif not boostActive and not driftActive and not offTrack
				and commandedSpeed > KartConfig.MAX_FORWARD_SPEED then
				commandedSpeed = moveToward(
					commandedSpeed,
					KartConfig.MAX_FORWARD_SPEED,
					KartConfig.BOOST_EXIT_DECELERATION * deltaTime
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

		local nitroSpeed = nitro.active or nitro.exiting
		commandedSpeed = math.clamp(commandedSpeed, -KartConfig.MAX_REVERSE_SPEED,
			if nitroSpeed then KartConfig.NITRO_MAX_SPEED else KartConfig.MINI_BOOST_MAX_SPEED)
		nitro:finishStep(commandedSpeed)

		local effectiveGrip = if driftActive then KartConfig.DRIFT_LATERAL_GRIP else KartConfig.LATERAL_GRIP
		lateralSpeed *= math.exp(-effectiveGrip * deltaTime)
		-- Preserve lateral handling, but Nitro must never create planar speed >100.
		if nitroSpeed then
			local maxLateral = math.sqrt(math.max(0, KartConfig.NITRO_MAX_SPEED ^ 2 - commandedSpeed ^ 2))
			lateralSpeed = math.clamp(lateralSpeed, -maxLateral, maxLateral)
		end
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
