local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local physicsAvailable, PhysicsService = pcall(function() return game:GetService("PhysicsService") end)

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
local KartContext = require(script.Parent:WaitForChild("KartContext"))
local RacerCollisionIsolation = require(script.Parent:WaitForChild("RacerCollisionIsolation"))
local KartUprightRecovery = require(script.Parent:WaitForChild("KartUprightRecovery"))
local StraightSpeedResolver = require(script.Parent:WaitForChild("KDMStraightSpeedResolver"))
local TrackGeometry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrackGeometry"))

local PrototypeWorld = {}
local driftOutcomeListeners = {}

function PrototypeWorld.onDriftOutcome(callback)
	table.insert(driftOutcomeListeners, callback)
	return {Disconnect = function()
		local index = table.find(driftOutcomeListeners, callback)
		if index then table.remove(driftOutcomeListeners, index) end
	end}
end

local function emitDriftOutcome(player, outcome)
	if not player then return end
	for _, callback in driftOutcomeListeners do callback(player, outcome) end
end
local contexts = {}
local ownerContexts = {}
local botContexts = {}
local function contextsFor(participant)
	return if botContexts[participant] then botContexts else ownerContexts
end
local defaultContext = nil
local collisionIsolation = RacerCollisionIsolation.new(if physicsAvailable then PhysicsService else nil)

function PrototypeWorld.getKartContext(player: Player)
	return contextsFor(player)[player]
end

function PrototypeWorld.getRaceKart(player: Player)
	local context = contextsFor(player)[player]
	if context then return context:getRaceKart(player) end
	return nil
end

function PrototypeWorld.applySlickHit(player: Player): boolean
	local context = contextsFor(player)[player]
	return context ~= nil and context:applySlickHit(player)
end

function PrototypeWorld.applyThunderHit(player: Player): boolean
	local context = contextsFor(player)[player]
	return context ~= nil and context:applyThunderHit(player)
end

function PrototypeWorld.applyMissileHit(player: Player): boolean
	local context = contextsFor(player)[player]
	return context ~= nil and context:applyMissileHit(player)
end

function PrototypeWorld.activateNitro(player: Player): (boolean, string?)
	if botContexts[player] then return false, "bot_items_disabled" end
	local context = contextsFor(player)[player]
	if not context then return false, "kart_missing" end
	return context:activateNitro(player)
end

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

local function bindVisual(kart: Model, chassis: BasePart, definition)
	local visual = KartVisualFactory.createVisual(definition)
	visual:PivotTo(chassis.CFrame)
	local previous = kart:FindFirstChild("Visual")
	if previous then previous:Destroy() end
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
	kart:SetAttribute("KartId", definition.Id)
end

local function selectVisual(context, definition): boolean
	if context.kart:GetAttribute("KartId") == definition.Id then return true end
	-- Rebind only a vacant assembly. Never replace joints under a seated driver.
	if context.seat.Occupant then return false end
	local seatFrame = KartVisualFactory.getDriverSeatLocalCFrame(definition)
	bindVisual(context.kart, context.chassis, definition)
	-- Disconnect the vacant Seat before moving it, so CFrame does not drag the
	-- welded Chassis/visual assembly. Rebind at the model's driver-fit transform.
	for _, joint in context.seat:GetChildren() do
		if joint:IsA("WeldConstraint") and joint.Part0 == context.chassis and joint.Part1 == context.seat then
			joint:Destroy()
		end
	end
	context.seat.CFrame = context.chassis.CFrame * seatFrame
	weldToChassis(context.chassis, context.seat)
	return true
end

local function kartDefinition(kartId)
	return KartCatalog.Entries[kartId or KartCatalog.DefaultId] or KartCatalog.Entries[KartCatalog.DefaultId]
end

local function createKart(prototype: Folder, spawnCFrame: CFrame, kartName: string, kartId: string?): (Model, Part, Seat)
	local previousKart = prototype:FindFirstChild(kartName)
	if previousKart then
		previousKart:Destroy()
	end

	local kart = Instance.new("Model")
	kart.Name = kartName
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

	local definition = kartDefinition(kartId)
	bindVisual(kart, chassis, definition)

	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2.5, 1, 2.5)
	seat.CFrame = spawnCFrame * KartVisualFactory.getDriverSeatLocalCFrame(definition)
	seat.Color = Color3.fromRGB(35, 35, 40)
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Massless = true
	seat:SetAttribute("PrototypeKartSeat", true)
	seat.Parent = kart
	weldToChassis(chassis, seat)

	kart.PrimaryPart = chassis
	kart.Parent = prototype
	collisionIsolation:bindKart(kart)
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

function PrototypeWorld.start(options)
	local initialTrackId = if options and options.trackId then options.trackId else TrackCatalog.DefaultId
	local initialTrack = assert(TrackCatalog.Entries[initialTrackId], "Unknown initial track")
	collisionIsolation:configure()
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

	TrackBuilder.build(prototype, initialTrack, groundTop)
	-- Analyze each shared geometry once during world load, never in a physics frame.
	if KartConfig.STRAIGHT_SPEED_ENABLED then
		for _, entry in TrackCatalog.Entries do
			StraightSpeedResolver.get(entry.GeometryId, TrackGeometry, KartConfig)
		end
	end
	print(string.format("[RobloxKart] %s ready", initialTrack.DisplayName or initialTrackId))

	local initialGrid = initialTrack.GridSlots[1]
	local spawnCFrame = CFrame.new(0, groundTop + WORLD.CHASSIS_CLEARANCE, 0) * initialGrid
	local kart, chassis, seat = createKart(prototype, spawnCFrame, "Kart")

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

	local function createContext(owner: Player?, kart: Model, chassis: BasePart, seat: Seat, spawnCFrame: CFrame)
		local context = KartContext.new(nil, kart, chassis, seat, spawnCFrame, KartConfig, RaceItemConfig, NitroState, SlickMotion, DriftTelemetry)
		contexts[context] = true
		local driverCollisionBinding = nil
		local function restoreDriverCollision()
			if driverCollisionBinding then driverCollisionBinding:restore(); driverCollisionBinding = nil end
		end
		local function bindDriverCollision(player: Player)
			restoreDriverCollision()
			local character = player.Character
			if not character then return end
			driverCollisionBinding = collisionIsolation:bindDriver(character)
			if physicsAvailable and RunService:IsStudio() then
				local kartParts, driverParts, mismatches = collisionIsolation:audit(kart, character)
				print(string.format("[KartCollision] kart=%d driver=%d mismatches=%d", kartParts, driverParts, mismatches))
			end
		end

		local function stopSlick()
			context.slick:stop()
			kart:SetAttribute("KartSlickActive", false)
		end
		local function stopMissileHit()
			context.missileHitActive, context.missileHitEndTime = false, 0
			kart:SetAttribute("KartMissileHitActive", false)
		end
		local function stopThunderHit()
			context.thunderHitActive, context.thunderHitEndTime = false, 0
			kart:SetAttribute("KartThunderHitActive", false)
		end
		stopMissileHit()
		stopThunderHit()
		function context:getRaceKart(player: Player)
			if context.owner ~= player or not kart.Parent or not chassis.Parent or not seat.Parent or context.crashActive then return nil end
			local character = if context.botParticipant == player then context.botDriver else player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart ~= seat or seat.Occupant ~= humanoid then return nil end
			if player:GetAttribute("RaceState") ~= "RACING" or kart:GetAttribute("RaceControlsLocked") ~= false then return nil end
			return kart, chassis
		end

		local function stopNitro(reason: string)
			context.nitro:stop(reason)
			kart:SetAttribute("KartNitroActive", false)
		end
		function context:activateNitro(player: Player)
			if context.botParticipant then return false, "bot_items_disabled" end
			if context.owner ~= player or not kart.Parent or not chassis.Parent or not seat.Parent then return false, "kart_missing" end
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 or seat.Occupant ~= humanoid or humanoid.SeatPart ~= seat then
				return false, "not_driver"
			end
			if kart:GetAttribute("RaceControlsLocked") ~= false or player:GetAttribute("RaceState") ~= "RACING" then
				return false, "race_locked"
			end
			if context.crashActive or context.slick.active or context.missileHitActive or context.thunderHitActive
				or kart:GetAttribute("KartOffTrack") == true then return false, "unsafe_state" end
			local control = context.control
			if not control or time() - control.lastUpdate > KartConfig.INPUT_TIMEOUT then return false, "input_timeout" end
			local accepted, reason = context.nitro:activate(player, time())
			if accepted then kart:SetAttribute("KartNitroActive", true) end
			return accepted, reason
		end
		kart:GetAttributeChangedSignal("RaceControlsLocked"):Connect(function()
			if kart:GetAttribute("RaceControlsLocked") then stopNitro("locked"); stopSlick(); stopMissileHit(); stopThunderHit() end
		end)
		kart:GetAttributeChangedSignal("RaceResetSerial"):Connect(function()
			stopNitro("reset"); stopSlick(); stopMissileHit(); stopThunderHit()
			emitDriftOutcome(context.owner, "RESET")
		end)
		seat:GetPropertyChangedSignal("Occupant"):Connect(function() stopNitro("occupant_changed"); stopSlick(); stopMissileHit(); stopThunderHit() end)


		local function setDriftActive(active: boolean, reason: string)
			if context.driftActive == active then
				return
			end
			context.driftActive = active
			if active then context.driftTelemetry:begin()
			else context.pendingDriftEnd = reason end
			kart:SetAttribute("KartDrifting", active)
			if KartConfig.DEBUG_TELEMETRY then
				if active then
					print(string.format("[KartDrift] START reason=%s", reason))
				else
					print(string.format(
						"[KartDrift] END reason=%s chargeDuration=%.2f qualifiedDuration=%.2f",
						reason,
						context.driftDuration,
						context.qualifiedDuration
					))
				end
			end
		end

		local function resetDriftCharge()
			if context.pendingDriftEnd then
				context.driftTelemetry:finish(context.pendingDriftEnd, context.driftDuration, context.qualifiedDuration, context.pendingBoostEligible)
				if not context.pendingBoostEligible then emitDriftOutcome(context.driftDriver, "RESET") end
			end
			context.pendingDriftEnd, context.pendingBoostEligible = nil, false
			context.driftTelemetry:clearCharge()
			context.driftDuration = 0
			context.qualifiedDuration = 0
			context.driftReadyLatched = false
			context.driftDriver = nil
		end

		local function startBoost(player: Player, now: number)
			context.boostActive = true
			context.boostDriver = player
			context.boostEndTime = now + KartConfig.MINI_BOOST_DURATION
			kart:SetAttribute("KartBoosting", true)
			emitDriftOutcome(player, "BOOST")
			if KartConfig.DEBUG_TELEMETRY then
				print(string.format(
					"[KartBoost] START reason=qualified_clean_exit chargeDuration=%.2f qualifiedDuration=%.2f",
					context.driftDuration,
					context.qualifiedDuration
				))
			end
		end

		-- Reset display state immediately at lifecycle boundaries; simulation reset
		-- remains in its existing paths below.
		kart:GetAttributeChangedSignal("RaceResetSerial"):Connect(function() context.driftTelemetry:clear() end)
		kart:GetAttributeChangedSignal("RaceControlsLocked"):Connect(function()
			if kart:GetAttribute("RaceControlsLocked") then context.driftTelemetry:clear() end
		end)
		seat:GetPropertyChangedSignal("Occupant"):Connect(function() context.driftTelemetry:clear() end)

		local function stopBoost(reason: string)
			if not context.boostActive then
				return
			end
			context.boostActive = false
			context.boostDriver = nil
			context.boostEndTime = 0
			kart:SetAttribute("KartBoosting", false)
			if KartConfig.DEBUG_TELEMETRY then
				print(string.format("[KartBoost] END reason=%s", reason))
			end
		end
		function context:applyMissileHit(player: Player): boolean
			if not context:getRaceKart(player) or context.missileHitActive or context.thunderHitActive or context.slick.active
				or kart:GetAttribute("KartOffTrack") == true then return false end
			stopNitro("missile")
			stopBoost("missile")
			setDriftActive(false, "missile")
			resetDriftCharge()
			context.driftTelemetry:clear()
			context.missileHitActive = true
			context.missileHitEndTime = time() + RaceItemConfig.MISSILE_EFFECT_DURATION
			context.commandedSpeed = math.min(context.commandedSpeed, RaceItemConfig.MISSILE_SPEED_CAP)
			local velocity = chassis.AssemblyLinearVelocity
			local planar = Vector3.new(velocity.X, 0, velocity.Z)
			if planar.Magnitude > RaceItemConfig.MISSILE_SPEED_CAP then planar = planar.Unit * RaceItemConfig.MISSILE_SPEED_CAP end
			-- No position, yaw, steering or vertical-velocity write.
			chassis.AssemblyLinearVelocity = planar + Vector3.new(0, velocity.Y, 0)
			kart:SetAttribute("KartMissileHitActive", true)
			return true
		end
		function context:applyThunderHit(player: Player): boolean
			if not context:getRaceKart(player) or context.thunderHitActive or context.missileHitActive or context.slick.active
				or kart:GetAttribute("KartOffTrack") == true then return false end
			stopNitro("thunder")
			stopBoost("thunder")
			setDriftActive(false, "thunder")
			resetDriftCharge()
			context.driftTelemetry:clear()
			context.thunderHitActive = true
			context.thunderHitEndTime = time() + RaceItemConfig.THUNDER_EFFECT_DURATION
			context.commandedSpeed = math.min(context.commandedSpeed, RaceItemConfig.THUNDER_SPEED_CAP)
			local velocity = chassis.AssemblyLinearVelocity
			local planar = Vector3.new(velocity.X, 0, velocity.Z)
			if planar.Magnitude > RaceItemConfig.THUNDER_SPEED_CAP then planar = planar.Unit * RaceItemConfig.THUNDER_SPEED_CAP end
			-- No position, yaw, steering or vertical-velocity write.
			chassis.AssemblyLinearVelocity = planar + Vector3.new(0, velocity.Y, 0)
			kart:SetAttribute("KartThunderHitActive", true)
			return true
		end
		kart:GetAttributeChangedSignal("KartOffTrack"):Connect(function()
			if kart:GetAttribute("KartOffTrack") then
				emitDriftOutcome(context.owner, "RESET")
				setDriftActive(false, "off_track")
				resetDriftCharge()
				context.commandedSpeed = math.min(context.commandedSpeed, KartConfig.OFF_TRACK_MAX_SPEED)
				stopBoost("off_track")
				stopNitro("off_track")
				stopSlick()
			end
		end)

		local function refreshBarrierTriggers()
			local currentTrack = prototype:FindFirstChild("TestTrack")
			if currentTrack == context.cachedTrack then
				return
			end
			context.cachedTrack = if currentTrack and currentTrack:IsA("Model") then currentTrack else nil
			table.clear(context.barrierTriggers)
			table.clear(context.insideBarrier)
			context.lastBarrierPosition = chassis.Position
			if context.cachedTrack then
				local folder = context.cachedTrack:FindFirstChild("BarrierTriggers")
				if folder then
					for _, child in folder:GetChildren() do
						if child:IsA("BasePart") then
							table.insert(context.barrierTriggers, child)
						end
					end
				end
			end
		end

		function context:applySlickHit(player: Player): boolean
			if not context:getRaceKart(player) or context.slick.active or context.missileHitActive or context.thunderHitActive
				or kart:GetAttribute("KartOffTrack") == true then return false end
			emitDriftOutcome(player, "RESET")
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
			context.commandedSpeed, context.smoothedSteering, context.currentYawRate = 0, 0, 0
			kart:SetAttribute("KartVisualSteering", 0)
			context.slick:start(player, time(), forward.Unit, legal.Unit, speed)
			kart:SetAttribute("KartSlickActive", true)
			return true
		end

		local function stopCrash()
			if not context.crashActive then
				return
			end
			context.crashActive = false
			context.crashSpinRate = 0
			kart:SetAttribute("KartCrashActive", false)
			chassis.AssemblyAngularVelocity = Vector3.zero
		end

		kart:GetAttributeChangedSignal("KartFinishRollActive"):Connect(function()
			if kart:GetAttribute("KartFinishRollActive") ~= true then
				context.finishRollElapsed, context.finishRollInitialSpeed = 0, 0
				return
			end
			local direction = kart:GetAttribute("KartFinishRollDirection")
			if typeof(direction) == "Vector3" then
				local flat = Vector3.new(direction.X, 0, direction.Z)
				if flat.Magnitude > 0.001 then context.finishRollDirection = flat.Unit end
			end
			local velocity = chassis.AssemblyLinearVelocity
			context.finishRollInitialSpeed = math.max(0, Vector3.new(velocity.X, 0, velocity.Z):Dot(context.finishRollDirection))
			context.finishRollElapsed = 0
			stopNitro("finish")
			stopBoost("finish")
			stopSlick()
			stopCrash()
			setDriftActive(false, "finish")
			resetDriftCharge()
			context.commandedSpeed, context.smoothedSteering, context.currentYawRate = 0, 0, 0
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
			context.crashVelocity = reboundDirection * reboundSpeed
			context.crashTrackForward = trackForward
			local spinTurns = KartConfig.BARRIER_CRASH_MIN_SPIN_TURNS
				+ (KartConfig.BARRIER_CRASH_MAX_SPIN_TURNS - KartConfig.BARRIER_CRASH_MIN_SPIN_TURNS) * severity
			local cross = planarVelocity:Cross(inwardNormal).Y
			local spinDirection = if cross < 0 then -1 else 1
			context.crashSpinRate = if strongImpact then spinDirection * spinTurns * 2 * math.pi / duration else 0
			context.crashEndTime = now + duration
			context.crashAlignStartTime = context.crashEndTime - math.min(0.35, duration * 0.54)
			context.crashAlignDeadline = context.crashEndTime + 0.2
			context.crashCooldownEndTime = context.crashEndTime + KartConfig.BARRIER_CRASH_COOLDOWN
			context.crashActive = true
			context.commandedSpeed = 0
			context.smoothedSteering = 0
			context.currentYawRate = 0
			kart:SetAttribute("KartVisualSteering", 0)
			setDriftActive(false, "barrier")
			emitDriftOutcome(context.owner, "RESET")
			resetDriftCharge()
			stopBoost("barrier")
			stopNitro("barrier")
			stopSlick()
			kart:SetAttribute("KartCrashActive", true)
			chassis.AssemblyLinearVelocity = context.crashVelocity
			chassis.AssemblyAngularVelocity = Vector3.new(0, context.crashSpinRate, 0)
			print(string.format("[KartBarrier] impact approach=%.1f rebound=%.1f spin=%.2f duration=%.2f", approachSpeed, reboundSpeed, if strongImpact then spinTurns else 0, duration))
		end

		local function checkBarrierEntries(now: number, fromPosition: Vector3, planarVelocity: Vector3): boolean
			local bestNormal: Vector3? = nil
			local bestForward: Vector3? = nil
			local bestApproach = KartConfig.BARRIER_CONTACT_MIN_SPEED
			local pushNormal: Vector3? = nil
			local pushApproach = KartConfig.BARRIER_CONTACT_MIN_SPEED
			for _, trigger in context.barrierTriggers do
				local inside = isInsideBarrier(trigger, chassis.Position)
				local entered = not context.insideBarrier[trigger]
					and (inside or crossedBarrier(trigger, fromPosition, chassis.Position))
				context.insideBarrier[trigger] = inside
				if (entered or inside) and not context.crashActive then
					local normal = trigger:GetAttribute("BarrierInwardNormal")
					local trackForward = trigger:GetAttribute("BarrierForwardTangent")
					if typeof(normal) == "Vector3" and typeof(trackForward) == "Vector3" then
						local approach = -planarVelocity:Dot(normal)
						if entered and now >= context.crashCooldownEndTime and approach >= bestApproach then
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
				context.commandedSpeed = 0
				chassis.AssemblyLinearVelocity = pushNormal * KartConfig.BARRIER_CONTACT_PUSH_SPEED
				chassis.AssemblyAngularVelocity = Vector3.zero
				return true
			end
			return false
		end

		function context:receiveControl(player: Player, throttle: unknown, steering: unknown, driftRequested: unknown)
			if context.botParticipant then return end
			if type(throttle) ~= "number" or type(steering) ~= "number" then
				return
			end
			if throttle ~= throttle or steering ~= steering or math.abs(throttle) == math.huge or math.abs(steering) == math.huge then
				return
			end

			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if self.owner ~= player then return end
			if not humanoid or humanoid.SeatPart ~= seat or seat.Occupant ~= humanoid then
				context.control = nil
				return
			end
			local validatedSteering = math.clamp(steering, -1, 1)
			local visualSteering = if kart:GetAttribute("RaceControlsLocked") == true or context.crashActive or context.slick.active then 0 else validatedSteering
			if kart:GetAttribute("KartVisualSteering") ~= visualSteering then
				kart:SetAttribute("KartVisualSteering", visualSteering)
			end

			context.control = {
				throttle = math.clamp(throttle, -1, 1),
				steering = validatedSteering,
				driftRequested = if type(driftRequested) == "boolean" then driftRequested else false,
				lastUpdate = time(),
			}
		end


		-- Server internal NPC input; no remote can choose a bot context.
		function context:setServerControl(steering: number)
			local permitted = if self.botSource == "PRODUCTION_ROOM"
				then RaceConfig.INVITEABLE_BOT_ENABLED and Workspace:GetAttribute("KDMServerRole") == "RACE"
				else RunService:IsStudio() and Workspace:GetAttribute("KDMEnableRaceBot") == true
			if not self.botParticipant or not permitted then return false end
			local humanoid=self.botDriver:FindFirstChildOfClass("Humanoid")
			if not humanoid or seat.Occupant~=humanoid or humanoid.SeatPart~=seat
				or self.botParticipant:GetAttribute("RaceState")~="RACING" then self.control=nil;return false end
			if type(steering)~="number" or steering~=steering or math.abs(steering)==math.huge then return false end
			self.control={throttle=1,steering=math.clamp(steering,-1,1),driftRequested=false,lastUpdate=time()}
			kart:SetAttribute("KartVisualSteering",if context.crashActive or context.slick.active then 0 else self.control.steering)
			return true
		end
		local function occupantDriver(occupant)
			if occupant and context.botParticipant and occupant.Parent==context.botDriver then return context.botParticipant end
			return occupant and Players:GetPlayerFromCharacter(occupant.Parent)
		end
		function context:step(deltaTime: number)
			if context.botControl then context:setServerControl(context.botControl().steering) end
			-- Snapshot before early exits or collision responses alter motion. This is
			-- diagnostic-only; input validation and simulation below are unchanged.
			do
				local occupant = seat.Occupant
				local driver = occupantDriver(occupant)
				local control = if driver == context.owner then context.control else nil
				local age = control and time()-control.lastUpdate
				local valid = age ~= nil and age <= KartConfig.INPUT_TIMEOUT
				local look, right = chassis.CFrame.LookVector, chassis.CFrame.RightVector
				local flatLook, flatRight = Vector3.new(look.X,0,look.Z), Vector3.new(right.X,0,right.Z)
				local forward = if flatLook.Magnitude>0.001 then flatLook.Unit else Vector3.new(0,0,-1)
				local sideways = if flatRight.Magnitude>0.001 then flatRight.Unit else Vector3.new(1,0,0)
				local velocity = chassis.AssemblyLinearVelocity
				local speed = velocity:Dot(forward)
				local slip = if math.abs(speed)>=1 then math.deg(math.atan2(velocity:Dot(sideways),math.abs(speed))) else 0
				context.driftTelemetry:observe(age,deltaTime,speed,slip,if control then control.steering else 0,
					context.smoothedSteering,if control and valid then control.throttle else 0,valid)
			end
			refreshBarrierTriggers()
			local previousBarrierPosition = context.lastBarrierPosition
			context.lastBarrierPosition = chassis.Position
			if context.botParticipant and chassis.Position.Y < KartConfig.FALL_RESET_Y then
				context.botParticipant:SetAttribute("RaceState","DNF")
				context.botParticipant:SetAttribute("RaceDNFReason","FALL")
				kart:SetAttribute("RaceControlsLocked",true)
				return
			end
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
				kart:PivotTo(context.spawnCFrame)
				context.commandedSpeed = 0
				context.smoothedSteering = 0
				context.currentYawRate = 0
				context.tiltUnsafeElapsed = 0
				kart:SetAttribute("KartVisualSteering", 0)
				setDriftActive(false, "fall")
				emitDriftOutcome(context.owner, "RESET")
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
				context.finishRollElapsed += deltaTime
				local alpha = math.clamp(context.finishRollElapsed / RaceConfig.FINISH_ROLL_SECONDS, 0, 1)
				local verticalSpeed = chassis.AssemblyLinearVelocity.Y
				chassis.AssemblyLinearVelocity = context.finishRollDirection * (context.finishRollInitialSpeed * (1 - alpha))
					+ Vector3.new(0, verticalSpeed, 0)
				chassis.AssemblyAngularVelocity = Vector3.zero
				context.raceControlsWereLocked = true
				return
			end
			if raceControlsLocked then
				context.straightEligible, context.straightExitActive, context.straightLastEvaluation = false, false, nil
				context.straightBoostReturnActive = false
				context.tiltUnsafeElapsed = 0
				stopNitro("locked")
				stopSlick()
				stopCrash()
				if not context.raceControlsWereLocked then
					context.commandedSpeed = 0
					context.smoothedSteering = 0
					context.currentYawRate = 0
					kart:SetAttribute("KartVisualSteering", 0)
					setDriftActive(false, "race_controls_locked")
					resetDriftCharge()
					stopBoost("race_controls_locked")
				end
				context.raceControlsWereLocked = true
				chassis.AssemblyLinearVelocity = Vector3.zero
				chassis.AssemblyAngularVelocity = Vector3.zero
				return
			end
			context.raceControlsWereLocked = false

			local now = time()
			if context.missileHitActive and now >= context.missileHitEndTime then stopMissileHit() end
			if context.thunderHitActive and now >= context.thunderHitEndTime then stopThunderHit() end
			local throttle = 0
			local steering = 0
			local driftRequested = false
			local occupant = seat.Occupant
			local player = occupantDriver(occupant)
			local resetSerial = kart:GetAttribute("RaceResetSerial")
			if resetSerial ~= context.lastUprightResetSerial then
				context.lastUprightResetSerial = resetSerial
				context.tiltUnsafeElapsed = 0
			elseif not context.botParticipant and player == context.owner and player:GetAttribute("RaceState") == "RACING"
				and not context.crashActive then
				local upDot = chassis.CFrame.UpVector:Dot(Vector3.yAxis)
				local elapsed, recover = KartUprightRecovery.advance(upDot, context.tiltUnsafeElapsed, deltaTime, KartConfig)
				context.tiltUnsafeElapsed = elapsed
				if recover then
					context.lastPlanarForward = KartUprightRecovery.apply(kart, chassis, context.lastPlanarForward)
					context.tiltUnsafeElapsed = 0
					return
				end
			else
				context.tiltUnsafeElapsed = 0
			end
			local control = player and context.control
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
			context.nitro:update(now, player, player ~= nil and player:GetAttribute("RaceState") == "RACING",
				kart:GetAttribute("KartOffTrack") == true, context.crashActive, hasValidInput)
			kart:SetAttribute("KartNitroActive", context.nitro.active)

			local assemblyVelocity = chassis.AssemblyLinearVelocity
			local planarVelocity = Vector3.new(assemblyVelocity.X, 0, assemblyVelocity.Z)
			local barrierHandled = if occupant and player
				then checkBarrierEntries(now, previousBarrierPosition, planarVelocity)
				else false
			if context.crashActive then
				if chassis.CFrame.UpVector.Y < KartConfig.KART_UPRIGHT_MIN_DOT then
					local look = chassis.CFrame.LookVector
					local flatLook = Vector3.new(look.X, 0, look.Z)
					local heading = if flatLook.Magnitude > 0.001 then flatLook.Unit else context.lastPlanarForward
					kart:PivotTo(CFrame.lookAt(chassis.Position, chassis.Position + heading))
				end
				local look = chassis.CFrame.LookVector
				local flatLook = Vector3.new(look.X, 0, look.Z)
				local forward = if flatLook.Magnitude > 0.001 then flatLook.Unit else context.lastPlanarForward
				local headingError = math.atan2(forward:Cross(context.crashTrackForward).Y, forward:Dot(context.crashTrackForward))
				if now >= context.crashEndTime and (math.abs(headingError) <= math.rad(20) or now >= context.crashAlignDeadline) then
					chassis.AssemblyLinearVelocity = Vector3.zero
					stopCrash()
					return
				end
				context.crashVelocity *= math.exp(-KartConfig.BARRIER_CRASH_DAMPING * deltaTime)
				chassis.AssemblyLinearVelocity = context.crashVelocity
				local spinWeight = math.clamp((context.crashAlignStartTime + 0.08 - now) / 0.08, 0, 1)
				local alignmentYawRate = math.clamp(headingError * 16, -12, 12)
				local yawRate = context.crashSpinRate * spinWeight + alignmentYawRate * (1 - spinWeight)
				chassis.AssemblyAngularVelocity = Vector3.new(0, yawRate, 0)
				return
			end
			if barrierHandled then
				return
			end
			if context.slick.active then
				if context.slick.driver ~= player or not player or player:GetAttribute("RaceState") ~= "RACING"
					or kart:GetAttribute("KartOffTrack") == true then
					stopSlick()
				else
					local look = chassis.CFrame.LookVector
					local flat = Vector3.new(look.X, 0, look.Z)
					local heading = if flat.Magnitude > 0.001 then flat.Unit else context.lastPlanarForward
					local velocity, yaw, complete = context.slick:sample(now, heading)
					-- No teleport, roll or pitch impulse; preserve existing vertical motion.
					chassis.AssemblyLinearVelocity = velocity + Vector3.new(0, assemblyVelocity.Y, 0)
					chassis.AssemblyAngularVelocity = Vector3.new(0, yaw, 0)
					if complete then
						context.commandedSpeed = math.max(0, velocity:Dot(heading))
						context.currentYawRate = 0
						chassis.AssemblyAngularVelocity = Vector3.zero
						stopSlick()
					end
					return
				end
			end

			local lookVector = chassis.CFrame.LookVector
			local flatForward = Vector3.new(lookVector.X, 0, lookVector.Z)
			local forward = if flatForward.Magnitude > 0.001 then flatForward.Unit else Vector3.new(0, 0, -1)
			if chassis.CFrame.UpVector.Y >= KartConfig.KART_UPRIGHT_MIN_DOT then
				context.lastPlanarForward = forward
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

			context.smoothedSteering = moveToward(context.smoothedSteering, steering, KartConfig.STEERING_RESPONSE * deltaTime)
			context.driftTelemetry.frame.steer = context.smoothedSteering
			local absoluteSteering = math.abs(context.smoothedSteering)
			local endedDriftReason: string? = nil
			if context.driftActive then
				if not occupant then
					endedDriftReason = "no_occupant"
				elseif player ~= context.driftDriver then
					endedDriftReason = "driver_changed"
				elseif not hasValidInput then
					endedDriftReason = "input_timeout"
				elseif not driftRequested then
					endedDriftReason = "shift_release"
				elseif context.commandedSpeed <= 0 or actualForwardSpeed < 0 then
					endedDriftReason = "reverse"
				elseif driftForwardSpeed < KartConfig.DRIFT_EXIT_SPEED then
					endedDriftReason = "speed_below_exit"
				elseif absoluteSteering < KartConfig.DRIFT_EXIT_STEER then
					endedDriftReason = "steer_below_exit"
				end
				if endedDriftReason then
					setDriftActive(false, endedDriftReason)
				end
			elseif not context.boostActive and not context.missileHitActive and not context.thunderHitActive
				and occupant
				and hasValidInput
				and driftRequested
				and kart:GetAttribute("KartOffTrack") ~= true
				and context.commandedSpeed > 0
				and driftForwardSpeed >= KartConfig.DRIFT_MIN_SPEED
				and absoluteSteering >= KartConfig.DRIFT_ENTRY_STEER
			then
				resetDriftCharge()
				context.driftDriver = player
				setDriftActive(true, "entry")
			end

			if endedDriftReason then
				local cleanExit = endedDriftReason == "shift_release" or endedDriftReason == "steer_below_exit"
				local canStartBoost = cleanExit and context.driftReadyLatched
					and player ~= nil
					and player == context.driftDriver
					and occupant ~= nil
					and hasValidInput
					and throttle > 0
					and context.commandedSpeed > 0
					and actualForwardSpeed >= KartConfig.DRIFT_MIN_SPEED
					and kart:GetAttribute("KartOffTrack") ~= true
					and not context.crashActive
					and not context.slick.active
					and not context.missileHitActive and not context.thunderHitActive
					and player:GetAttribute("RaceState") == "RACING"
					and kart:GetAttribute("RaceControlsLocked") == false
				context.pendingBoostEligible = canStartBoost
				if canStartBoost and player then
					startBoost(player, now)
				end
				resetDriftCharge()
			elseif context.driftActive then
				local chargeDeltaTime = math.min(deltaTime, 0.05)
				context.driftDuration = math.min(
					context.driftDuration + chargeDeltaTime,
					KartConfig.DRIFT_CHARGE_MIN_DURATION
				)
				if actualForwardSpeed >= KartConfig.DRIFT_CHARGE_MIN_FORWARD_SPEED
					and math.abs(chargeSlipAngleDegrees) >= KartConfig.DRIFT_CHARGE_MIN_SLIP_DEGREES
				then
					context.qualifiedDuration = math.min(
						context.qualifiedDuration + chargeDeltaTime,
						KartConfig.DRIFT_CHARGE_REQUIRED_TIME
					)
				end
				if context.driftDuration >= KartConfig.DRIFT_CHARGE_MIN_DURATION
					and context.qualifiedDuration >= KartConfig.DRIFT_CHARGE_REQUIRED_TIME then
					context.driftReadyLatched = true
				end
			end

			context.driftTelemetry:update(context.driftDuration, context.qualifiedDuration)
			if context.boostActive then
				if not occupant then
					stopBoost("no_occupant")
				elseif player ~= context.boostDriver then
					stopBoost("driver_changed")
				elseif not hasValidInput then
					stopBoost("input_timeout")
				elseif throttle < 0 then
					stopBoost("brake")
				elseif throttle <= 0 then
					stopBoost("throttle_release")
				elseif now >= context.boostEndTime then
					stopBoost("duration_complete")
				end
			end

			local offTrack = kart:GetAttribute("KartOffTrack") == true
			local trackWorld = prototype:FindFirstChild("TestTrack")
			local geometryId = if trackWorld then trackWorld:GetAttribute("GeometryId") else nil
			if context.straightGeometryId ~= geometryId then
				context.straightGeometryId = geometryId
				context.straightEligible, context.straightLastEvaluation, context.straightExitActive = false, nil, false
			end
			local straightCourse = if KartConfig.STRAIGHT_SPEED_ENABLED then StraightSpeedResolver.get(geometryId, TrackGeometry, KartConfig) else nil
			StraightSpeedResolver.update(context, straightCourse, chassis.Position, now,
				player ~= nil and player:GetAttribute("RaceState") == "RACING" and not offTrack
				and not context.driftActive and not context.missileHitActive and not context.thunderHitActive)
			local normalForwardCap = if context.straightEligible then KartConfig.STRAIGHT_MAX_SPEED else KartConfig.MAX_FORWARD_SPEED
			context.normalForwardCap = normalForwardCap
			if context.nitro.active or context.nitro.exiting or context.boostActive then context.straightBoostReturnActive = true end
			-- Natural Boost overspeed keeps its existing return rate, even when the
			-- straight mask exits on the very same expiry frame.
			if context.straightBoostReturnActive then context.straightExitActive = false end
			local forwardTargetSpeed = if context.nitro.active then KartConfig.NITRO_MAX_SPEED elseif context.boostActive
				then KartConfig.MINI_BOOST_MAX_SPEED
				elseif context.driftActive then KartConfig.DRIFT_MAX_SPEED
				else normalForwardCap
			if context.thunderHitActive then forwardTargetSpeed = math.min(forwardTargetSpeed, RaceItemConfig.THUNDER_SPEED_CAP) end
			if context.missileHitActive then forwardTargetSpeed = math.min(forwardTargetSpeed, RaceItemConfig.MISSILE_SPEED_CAP) end
			if offTrack then
				forwardTargetSpeed = math.min(forwardTargetSpeed, KartConfig.OFF_TRACK_MAX_SPEED)
			end
			local forwardAcceleration = if context.boostActive then KartConfig.MINI_BOOST_ACCELERATION else KartConfig.ACCELERATION

			if throttle > 0 then
				if context.commandedSpeed < 0 then
					context.commandedSpeed = moveToward(context.commandedSpeed, 0, KartConfig.BRAKE_FORCE * throttle * deltaTime)
				elseif (context.nitro.active or context.nitro.exiting) and not offTrack then
					context.commandedSpeed = context.nitro:forwardSpeed(context.commandedSpeed, context.boostActive, throttle, deltaTime, normalForwardCap)
				elseif offTrack and context.commandedSpeed > forwardTargetSpeed then
					context.commandedSpeed = moveToward(context.commandedSpeed, forwardTargetSpeed, KartConfig.BRAKE_FORCE * deltaTime)
				elseif context.driftActive and context.commandedSpeed > forwardTargetSpeed then
					context.commandedSpeed = moveToward(
						context.commandedSpeed,
						forwardTargetSpeed,
						KartConfig.DRIFT_SPEED_DECELERATION * deltaTime
					)
				elseif not context.boostActive and not context.driftActive and not offTrack
					and context.commandedSpeed > normalForwardCap then
					context.commandedSpeed = moveToward(
						context.commandedSpeed,
						normalForwardCap,
						(if context.straightExitActive then KartConfig.STRAIGHT_EXIT_DECELERATION else KartConfig.BOOST_EXIT_DECELERATION) * deltaTime
					)
				else
					context.commandedSpeed = moveToward(context.commandedSpeed, forwardTargetSpeed, forwardAcceleration * throttle * deltaTime)
				end
			elseif throttle < 0 then
				if context.commandedSpeed > 0 then
					context.commandedSpeed = moveToward(context.commandedSpeed, 0, KartConfig.BRAKE_FORCE * -throttle * deltaTime)
				else
					context.commandedSpeed = moveToward(context.commandedSpeed, -KartConfig.MAX_REVERSE_SPEED, KartConfig.REVERSE_ACCELERATION * -throttle * deltaTime)
				end
			else
				context.commandedSpeed = moveToward(context.commandedSpeed, 0, KartConfig.COAST_DECELERATION * deltaTime)
			end

			local nitroSpeed = context.nitro.active or context.nitro.exiting
			context.commandedSpeed = math.clamp(context.commandedSpeed, -KartConfig.MAX_REVERSE_SPEED,
				if nitroSpeed then KartConfig.NITRO_MAX_SPEED else KartConfig.MINI_BOOST_MAX_SPEED)
			context.nitro:finishStep(context.commandedSpeed, normalForwardCap)
			if context.commandedSpeed <= normalForwardCap then
				context.straightExitActive = false
				context.straightBoostReturnActive = false
			end

			local effectiveGrip = if context.driftActive then KartConfig.DRIFT_LATERAL_GRIP else KartConfig.LATERAL_GRIP
			if context.missileHitActive then effectiveGrip *= RaceItemConfig.MISSILE_LATERAL_GRIP_MULTIPLIER end
			lateralSpeed *= math.exp(-effectiveGrip * deltaTime)
			-- Preserve lateral handling, but Nitro must never create planar speed >100.
			if nitroSpeed then
				local maxLateral = math.sqrt(math.max(0, KartConfig.NITRO_MAX_SPEED ^ 2 - context.commandedSpeed ^ 2))
				lateralSpeed = math.clamp(lateralSpeed, -maxLateral, maxLateral)
			end
			local verticalSpeed = assemblyVelocity.Y
			local outputPlanar = forward * context.commandedSpeed + right * lateralSpeed
			if context.thunderHitActive and outputPlanar.Magnitude > RaceItemConfig.THUNDER_SPEED_CAP then
				outputPlanar = outputPlanar.Unit * RaceItemConfig.THUNDER_SPEED_CAP
				context.commandedSpeed = outputPlanar:Dot(forward)
			end
			if context.missileHitActive and outputPlanar.Magnitude > RaceItemConfig.MISSILE_SPEED_CAP then
				outputPlanar = outputPlanar.Unit * RaceItemConfig.MISSILE_SPEED_CAP
				context.commandedSpeed = outputPlanar:Dot(forward)
			end
			chassis.AssemblyLinearVelocity = outputPlanar + Vector3.new(0, verticalSpeed, 0)

			local targetYawRate = 0
			if math.abs(context.commandedSpeed) >= KartConfig.MIN_STEERING_SPEED then
				local absoluteSpeed = math.abs(context.commandedSpeed)
				local speedRatio = math.clamp(absoluteSpeed / KartConfig.MAX_FORWARD_SPEED, 0, 1)
				local turnRadius = KartConfig.TURN_RADIUS_LOW_SPEED
					+ (KartConfig.TURN_RADIUS_HIGH_SPEED - KartConfig.TURN_RADIUS_LOW_SPEED) * speedRatio
				local direction = if context.commandedSpeed >= 0 then 1 else -1
				targetYawRate = -context.smoothedSteering * (absoluteSpeed / turnRadius) * direction
				if context.driftActive then
					targetYawRate *= KartConfig.DRIFT_YAW_MULTIPLIER
				end
			end
			context.currentYawRate = moveToward(context.currentYawRate, targetYawRate, KartConfig.YAW_ACCELERATION * deltaTime)
			chassis.AssemblyAngularVelocity = Vector3.new(0, context.currentYawRate, 0)

			local slipAngleDegrees = 0
			if math.abs(actualForwardSpeed) >= 1 then
				slipAngleDegrees = math.deg(math.atan2(lateralSpeed, math.abs(actualForwardSpeed)))
			end

			if KartConfig.DEBUG_TELEMETRY and occupant then
				context.debugElapsed += deltaTime
				if context.debugElapsed >= KartConfig.DEBUG_LOG_INTERVAL then
					context.debugElapsed = 0
					local ageText = if inputAge then string.format("%.2f", inputAge) else "none"
					local rootPart = chassis.AssemblyRootPart
					local boostRemaining = if context.boostActive then math.max(context.boostEndTime - now, 0) else 0
					print(string.format(
						"[KartDebug] throttle=%.2f rawSteer=%.2f smoothSteer=%.2f driftReq=%s drift=%s chargeDuration=%.2f qualifiedDuration=%.2f chargeSlip=%.1f boost=%s boostRemaining=%.2f cmdSpeed=%.1f actualSpeed=%.1f speedTarget=%.1f lateral=%.1f slip=%.1f targetYaw=%.2f yaw=%.2f inputAge=%s occupant=true root=%s",
						throttle,
						steering,
						context.smoothedSteering,
						tostring(driftRequested),
						tostring(context.driftActive),
						context.driftDuration,
						context.qualifiedDuration,
						chargeSlipAngleDegrees,
						tostring(context.boostActive),
						boostRemaining,
						context.commandedSpeed,
						actualForwardSpeed,
						forwardTargetSpeed,
						lateralSpeed,
						slipAngleDegrees,
						targetYawRate,
						context.currentYawRate,
						ageText,
						if rootPart then rootPart.Name else "none"
					))
				end
			else
				context.debugElapsed = 0
			end
		end

		function context:assignOwner(player: Player): boolean
			if self.owner == player then return true end
			if self.owner or ownerContexts[player] then return false end
			self.owner = player
			ownerContexts[player] = self
			kart:SetAttribute("KartOwnerUserId", player.UserId)
			bindDriverCollision(player)
			self.ownerConnections = {
				player.CharacterRemoving:Connect(function()
					stopMissileHit(); stopThunderHit()
					restoreDriverCollision()
					if self.nitro.driver == player then stopNitro("character_removed") end
					if self.slick.driver == player then stopSlick() end
				end),
				player:GetAttributeChangedSignal("RaceState"):Connect(function()
					if player:GetAttribute("RaceState") == "GARAGE" then restoreDriverCollision() end
					if player:GetAttribute("RaceState") ~= "RACING" then
						stopMissileHit(); stopThunderHit()
						if self.nitro.driver == player then stopNitro("race_state") end
						if self.slick.driver == player then stopSlick() end
					end
				end),
				seat:GetPropertyChangedSignal("Occupant"):Connect(function()
					local character = player.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					if humanoid and seat.Occupant == humanoid then
						if not driverCollisionBinding then bindDriverCollision(player) end
					else
						restoreDriverCollision()
					end
				end),
			}
			return true
		end

		function context:clearOwner()
			stopMissileHit(); stopThunderHit()
			local player = self.owner
			if not player then return end
			for _, connection in self.ownerConnections or {} do connection:Disconnect() end
			restoreDriverCollision()
			self.tiltUnsafeElapsed = 0
			self.ownerConnections = nil
			self.control = nil
			if self.nitro.driver == player then stopNitro("player_removed") end
			if self.slick.driver == player then stopSlick() end
			ownerContexts[player] = nil
			self.owner = nil
			kart:SetAttribute("KartOwnerUserId", 0)
		end

		kart.Destroying:Connect(function()
			if context.botParticipant then
				botContexts[context.botParticipant]=nil
				if context.botCollision then context.botCollision:restore();context.botCollision=nil end
				context.owner=nil
			end
			stopMissileHit(); stopThunderHit()
			context:clearOwner()
			if context == defaultContext then defaultContext = nil end
			stopNitro("destroyed")
			stopSlick()
			contexts[context] = nil
		end)
		if owner then context:assignOwner(owner) end
		return context
	end

	defaultContext = createContext(nil, kart, chassis, seat, spawnCFrame)
	kart:SetAttribute("KartOwnerUserId", 0)
	function PrototypeWorld.acquireKartContext(player: Player, startCFrame: CFrame, kartId: string?)
		local definition = kartDefinition(kartId)
		local existing = ownerContexts[player]
		if existing then
			if not selectVisual(existing, definition) then return nil end
			existing:setSpawnCFrame(startCFrame)
			return existing
		end
		if defaultContext and defaultContext.kart.Parent and not defaultContext.seat.Occupant
			and selectVisual(defaultContext, definition) and defaultContext:assignOwner(player) then
			defaultContext:setSpawnCFrame(startCFrame)
			return defaultContext
		end
		if not defaultContext then
			local newKart, newChassis, newSeat = createKart(prototype, startCFrame, "Kart", definition.Id)
			defaultContext = createContext(player, newKart, newChassis, newSeat, startCFrame)
			return defaultContext
		end
		return PrototypeWorld.createKartContext(player, startCFrame, definition.Id)
	end
	function PrototypeWorld.assignDefaultKart(player: Player)
		if defaultContext and defaultContext.kart.Parent and defaultContext:assignOwner(player) then
			return defaultContext
		end
		return nil
	end
	function PrototypeWorld.createKartContext(player: Player, startCFrame: CFrame, kartId: string?)
		if ownerContexts[player] then return nil end
		local newKart, newChassis, newSeat = createKart(prototype, startCFrame, "Kart_" .. tostring(player.UserId), kartId)
		return createContext(player, newKart, newChassis, newSeat, startCFrame)
	end
	function PrototypeWorld.createBotKartContext(state: Folder, driver: Model, startCFrame: CFrame, source: string?, roomId: string?)
		local production = source == "PRODUCTION_ROOM" and type(roomId) == "string" and roomId ~= ""
			and RaceConfig.INVITEABLE_BOT_ENABLED and Workspace:GetAttribute("KDMServerRole") == "RACE"
		assert(production or (source ~= "PRODUCTION_ROOM" and RunService:IsStudio()
			and Workspace:GetAttribute("KDMEnableRaceBot")==true),"Bot gate required")
		assert(state:GetAttribute("IsBot")==true and not botContexts[state],"Unique explicit bot state required")
		local model,body,botSeat=createKart(prototype,startCFrame,"KDM_Rookie_Bot","Kart01")
		local context=createContext(nil,model,body,botSeat,startCFrame)
		context.botParticipant=state;context.botDriver=driver;context.owner=state
		context.botSource=if production then "PRODUCTION_ROOM" else "STUDIO_TEST"
		botContexts[state]=context
		body:SetNetworkOwner(nil)
		context.botCollision=collisionIsolation:bindDriver(driver)
		model:SetAttribute("RaceControlsLocked",true);model:SetAttribute("KartIsBot",true)
		return context
	end
	function PrototypeWorld.releaseBotKartContext(state: Folder)
		local context=botContexts[state];if not context then return end
		botContexts[state]=nil
		if context.botCollision then context.botCollision:restore();context.botCollision=nil end
		context.owner=nil;context.botControl=nil;context.kart:Destroy()
	end
	function PrototypeWorld.destroyKartContext(player: Player)
		PrototypeWorld.releaseKartContext(player)
	end
	function PrototypeWorld.releaseKartContext(player: Player)
		local context = ownerContexts[player]
		if not context then return end
		context.kart:SetAttribute("RaceControlsLocked", true)
		context.kart:SetAttribute("KartFinishRollActive", false)
		context.kart:SetAttribute("RaceResetSerial", (context.kart:GetAttribute("RaceResetSerial") or 0) + 1)
		context.chassis.AssemblyLinearVelocity = Vector3.zero
		context.chassis.AssemblyAngularVelocity = Vector3.zero
		context:clearOwner()
		if context == defaultContext then
			defaultContext = nil
		end
		context.kart:Destroy()
	end
	remoteEvent.OnServerEvent:Connect(function(player: Player, throttle: unknown, steering: unknown, driftRequested: unknown)
		local context = ownerContexts[player]
		if context then context:receiveControl(player, throttle, steering, driftRequested) end
	end)
	Players.PlayerRemoving:Connect(function(player)
		PrototypeWorld.destroyKartContext(player)
	end)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		for context in contexts do
			if context.kart.Parent then context:step(deltaTime) end
		end
	end)

	print("[RobloxKart] Prototype world ready")
end

return PrototypeWorld
