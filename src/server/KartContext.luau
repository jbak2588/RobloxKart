-- A server-owned kart and all mutable simulation state for one driver.
-- The controller supplies the physics callbacks; callers never select a kart by ID.
local KartContext = {}
KartContext.__index = KartContext

function KartContext.new(owner, kart, chassis, seat, spawnCFrame, config, itemConfig, NitroState, SlickMotion, DriftTelemetry)
	local self = setmetatable({
		owner = owner,
		kart = kart,
		chassis = chassis,
		seat = seat,
		spawnCFrame = spawnCFrame,
		homeCFrame = spawnCFrame,
		control = nil,
		commandedSpeed = 0,
		smoothedSteering = 0,
		currentYawRate = 0,
		driftActive = false,
		driftDuration = 0,
		qualifiedDuration = 0,
		driftReadyLatched = false,
		driftDriver = nil,
		driftTelemetry = DriftTelemetry.new(kart, config),
		pendingDriftEnd = nil,
		pendingBoostEligible = false,
		boostActive = false,
		boostEndTime = 0,
		boostDriver = nil,
		nitro = NitroState.new(config),
		slick = SlickMotion.new(itemConfig),
		raceControlsWereLocked = kart:GetAttribute("RaceControlsLocked") == true,
		debugElapsed = 0,
		cachedTrack = nil,
		barrierTriggers = {},
		insideBarrier = {},
		lastBarrierPosition = chassis.Position,
		crashActive = false,
		crashEndTime = 0,
		crashAlignStartTime = 0,
		crashAlignDeadline = 0,
		crashCooldownEndTime = 0,
		crashVelocity = Vector3.zero,
		crashSpinRate = 0,
		crashTrackForward = Vector3.new(0, 0, -1),
		lastPlanarForward = Vector3.new(0, 0, -1),
		tiltUnsafeElapsed = 0,
		lastUprightResetSerial = kart:GetAttribute("RaceResetSerial"),
		finishRollElapsed = 0,
		finishRollInitialSpeed = 0,
		finishRollDirection = Vector3.new(0, 0, -1),
	}, KartContext)
	return self
end

function KartContext:setSpawnCFrame(frame)
	self.spawnCFrame = frame
	self.kart:SetAttribute("RaceStartCFrame", frame)
end

return KartContext
