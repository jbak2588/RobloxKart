local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local requireModule = require :: (ModuleScript) -> any
local KartConfig = requireModule(Shared:WaitForChild("KartConfig") :: ModuleScript)
local RaceConfig = requireModule(Shared:WaitForChild("RaceConfig") :: ModuleScript)
local TrackCatalog = requireModule(Shared:WaitForChild("TrackCatalog") :: ModuleScript)
local TrackGeometry = requireModule(Shared:WaitForChild("TrackGeometry") :: ModuleScript)
local RaceRouteProgress = requireModule(Shared:WaitForChild("RaceRouteProgress") :: ModuleScript)
local perfModule=script.Parent:FindFirstChild('RacePerformanceMonitor')
local PerformanceMonitor=perfModule and requireModule(perfModule)
local RaceMode = requireModule(Shared:WaitForChild("RaceMode") :: ModuleScript)
local PrototypeWorld = require(script.Parent:WaitForChild("PrototypeWorld"))
local RaceSession = require(script.Parent:WaitForChild("RaceSession"))
local RacerState = require(script.Parent:WaitForChild("RacerState"))
local RaceRanking = require(script.Parent:WaitForChild("RaceRanking"))
local economyModule = script.Parent:FindFirstChild("EconomyService")
local EconomyService = if economyModule then require(economyModule) else nil

local RaceController = {}

local DIRECTION_THRESHOLD = 0.25
local MIN_GATE_SPEED = 1
local started = false
local rosterLocked = false

function RaceController.isRosterLocked(): boolean
	return rosterLocked
end
function RaceController.prepareQuickArrival(player,token)
 local session=RaceSession.active()
 return session and session.prepareQuickArrival and session:prepareQuickArrival(player,token)
end

local function initializePlayerAttributes(player: Player, checkpointCount: number, initialTrackId: string)
	player:SetAttribute("RaceState", "GARAGE")
	player:SetAttribute("RaceCountdown", 0)
	player:SetAttribute("RaceCurrentLap", 1)
	player:SetAttribute("RaceCompletedLaps", 0)
	player:SetAttribute("RaceTotalLaps", RaceMode.targetLaps(RaceMode.resolve(initialTrackId), initialTrackId))
	player:SetAttribute("RaceSessionId", 0)
	player:SetAttribute("RaceHostUserId", 0)
	player:SetAttribute("RaceMapPosition", Vector3.zero)
	player:SetAttribute("RaceMapActive", false)
	player:SetAttribute("RaceParticipantCount", 1)
	player:SetAttribute("RaceMaxPlayers", TrackCatalog.Entries[initialTrackId].MaxPlayers)
	player:SetAttribute("RacePosition", 1)
	player:SetAttribute("RaceFinishPosition", 0)
	player:SetAttribute("RaceMatchStatus", "")
	player:SetAttribute("RaceMatchWaitReason", "NONE")
	player:SetAttribute("RaceMatchWaitRemaining", 0)
	player:SetAttribute("RaceSessionComplete", false)
	player:SetAttribute("RaceEndCountdownActive", false)
	player:SetAttribute("RaceEndCountdownRemaining", 0)
	player:SetAttribute("RaceDNFReason", "")
	player:SetAttribute("RaceRematchReady", false)
	player:SetAttribute("RaceRematchReadyCount", 0)
	player:SetAttribute("RaceRematchRequiredCount", 1)
	player:SetAttribute("RaceItemsReady", false)
	player:SetAttribute("RaceItemsAutoReady", false)
	player:SetAttribute("RaceItemsPrepareRemaining", 0)
	player:SetAttribute("RaceItemsReadyCount", 0)
	player:SetAttribute("RaceItemsRequiredCount", 0)
	player:SetAttribute("RaceItemsAutoReadySerial", 0)
	player:SetAttribute("RaceItemsAutoReadyName", "")
	player:SetAttribute("RaceNextCheckpoint", 1)
	player:SetAttribute("RaceLastLapTime", 0)
	player:SetAttribute("RaceBestLapTime", 0)
	player:SetAttribute("RaceBestLapNumber", 0)
	for lap = 1, 3 do player:SetAttribute("RaceLap" .. lap .. "Time", 0) end
	player:SetAttribute("RaceFinalTime", 0)
	player:SetAttribute("RaceFinishPhase", "NONE")
	player:SetAttribute("RaceWinnerAwaitingRunnerUp", false)
	player:SetAttribute("RaceCheckpointCount", checkpointCount)
	player:SetAttribute("RaceOffTrackRemaining", 0)
	player:SetAttribute("RaceFinishMissedSerial", 0)
	player:SetAttribute("RaceCheckpointMissed", 0)
end

local function isInsideGate(gate: BasePart, worldPosition: Vector3): boolean
	local localPosition = gate.CFrame:PointToObjectSpace(worldPosition)
	local halfSize = gate.Size * 0.5
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
end

-- Static track roads share a spatial index. Sloped pieces retain the original
-- unbounded-local-Y semantics through the fallback list.
local roadIndexes = setmetatable({}, {__mode="k"})
local ROAD_CELL = 64
local function roadIndex(parts)
 local cached=roadIndexes[parts];if cached then return cached end
 local cells,fallback={},{}
 for index,part in parts do
  local frame,half=part.CFrame,part.Size*.5
  if math.abs(frame.RightVector.Y)>.0001 or math.abs(frame.LookVector.Y)>.0001 then
   table.insert(fallback,index)
  else
   local x,z=half.X+RaceConfig.ROAD_CORRIDOR_MARGIN,half.Z+RaceConfig.ROAD_CORRIDOR_MARGIN
   local ex=math.abs(frame.RightVector.X)*x+math.abs(frame.LookVector.X)*z
   local ez=math.abs(frame.RightVector.Z)*x+math.abs(frame.LookVector.Z)*z
   for cx=math.floor((part.Position.X-ex)/ROAD_CELL),math.floor((part.Position.X+ex)/ROAD_CELL) do
    for cz=math.floor((part.Position.Z-ez)/ROAD_CELL),math.floor((part.Position.Z+ez)/ROAD_CELL) do
     local key=cx..":"..cz;local bucket=cells[key]
     if not bucket then bucket={};cells[key]=bucket end
     table.insert(bucket,index)
    end
   end
  end
 end
 cached={cells=cells,fallback=fallback};roadIndexes[parts]=cached;return cached
end
local function isInsideRoadCorridor(roadParts: { BasePart }, worldPosition: Vector3, lastIndexHint: number?): (boolean, number?)
 local function inside(index)
  local part=roadParts[index];if not part then return false end
  local p=part.CFrame:PointToObjectSpace(worldPosition);local half=part.Size*.5
  return math.abs(p.X)<=half.X+RaceConfig.ROAD_CORRIDOR_MARGIN
   and math.abs(p.Z)<=half.Z+RaceConfig.ROAD_CORRIDOR_MARGIN
 end
 if lastIndexHint and inside(lastIndexHint) then return true,lastIndexHint end
 local index=roadIndex(roadParts)
 local candidates=index.cells[math.floor(worldPosition.X/ROAD_CELL)..":"..math.floor(worldPosition.Z/ROAD_CELL)]
 local found=nil
 for _,i in candidates or {} do if i~=lastIndexHint and inside(i) then found=i;break end end
 for _,i in index.fallback do
  if (not found or i<found) and i~=lastIndexHint and inside(i) then found=i;break end
 end
 return found~=nil,found
end

local function isMovingThroughGate(chassis: BasePart, gate: BasePart): boolean
	local velocity = chassis.AssemblyLinearVelocity
	local planarVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	if planarVelocity.Magnitude < MIN_GATE_SPEED then
		return false
	end

	local gateLook = gate.CFrame.LookVector
	local planarGateLook = Vector3.new(gateLook.X, 0, gateLook.Z)
	if planarGateLook.Magnitude <= 0.001 then
		return false
	end

	return planarVelocity.Unit:Dot(planarGateLook.Unit) > DIRECTION_THRESHOLD
end

-- Warn only for a forward plane crossing close to the physical finish gate.
-- The gate itself remains the sole authority for lap completion.
local function missedFinishPlane(previousPosition: Vector3, currentPosition: Vector3, gate: BasePart, roadWidth: number): boolean
	local look = gate.CFrame.LookVector
	local before = (previousPosition - gate.Position):Dot(look)
	local after = (currentPosition - gate.Position):Dot(look)
	if before > 0 or after <= 0 or after == before then return false end
	local crossing = previousPosition:Lerp(currentPosition, -before / (after - before))
	local localCrossing = gate.CFrame:PointToObjectSpace(crossing)
	return math.abs(localCrossing.X) > gate.Size.X * 0.5
		and math.abs(localCrossing.X) <= gate.Size.X * 0.5 + roadWidth * 0.5
		and math.abs(localCrossing.Y) <= gate.Size.Y * 0.5 + 8
end

local function planarDistance(first: Vector3, second: Vector3): number
	local delta = second - first
	return Vector2.new(delta.X, delta.Z).Magnitude
end

function RaceController.start(options)
	if started then
		return true
	end
	started = true
	rosterLocked = false
	local preformedMatch = options and options.preformedMatch == true
	local persistentRoom = options and options.persistentRoom == true
	local expectedParticipantCount = if preformedMatch then options.expectedParticipantCount else 0
	local arrivalDeadline = 0
	local nextRoundPending = false
	local publicNextAt,lastPublicStart=0,-math.huge
	local roomPresentationPhase = "STARTING"
	local function publishRoomPhase(phase, count)
		roomPresentationPhase = phase
		if options and options.onRoomPhase then
			task.spawn(options.onRoomPhase, phase, count)
		end
	end
	local initialTrackId = if options and options.trackId then options.trackId else TrackCatalog.DefaultId
	local hubParkPreview = PrototypeWorld.isHubParkPreview and PrototypeWorld.isHubParkPreview()
	local publicWarmup=false
	-- Optional server observer: persistence failure must never change race adjudication.
	local recordModule = script.Parent:FindFirstChild("RaceRecordService")
	local recordLoaded, records = false, nil
	if recordModule then recordLoaded, records = pcall(require, recordModule) end
	if not recordLoaded then records = nil end
	local function record(method, ...)
		if records then
			local ok = pcall(records[method], ...)
			if not ok then
				warn("[KDMRecords] observer unavailable method=" .. method)
				records = nil -- Disable a broken observer once; never spam every Heartbeat.
			end
		end
	end
	if records then
		PrototypeWorld.onDriftOutcome(function(player, outcome, eventId)
			if outcome == "BOOST" then record("boost", player, eventId) end
		end)
	end

	local prototype = Workspace:WaitForChild("Prototype")
	local session = RaceSession.new(initialTrackId, RaceMode.resolve(initialTrackId),
		RaceMode.targetLaps(RaceMode.resolve(initialTrackId), initialTrackId))
	local checkpointCount = 0
	local gates: { BasePart } = {}
	local roadParts: { BasePart } = {}
	local finishRoadWidth = 0
	local startFinishGate: BasePart? = nil
	local checkpoints: { [number]: BasePart } = {}
	local minimumValidLapTime = 0
	local routeCourse = nil
	local routeRoadWidth = 0

	local function bindTrackForRace(trackId: string): boolean
		local track = TrackCatalog.Entries[trackId]
		local testTrack = prototype:FindFirstChild("TestTrack")
		if not track or not testTrack or not testTrack:IsA("Model")
			or testTrack:GetAttribute("TrackId") ~= track.Id
			or testTrack:GetAttribute("GeometryId") ~= track.GeometryId
		then
			warn("[Race] Selected track does not match the active world track")
			return false
		end
		local roadFolder = testTrack:FindFirstChild("Road")
		local raceTriggers = testTrack:FindFirstChild("RaceTriggers")
		local newCheckpointCount = testTrack:GetAttribute("CheckpointCount")
		if not roadFolder or not raceTriggers or type(newCheckpointCount) ~= "number" or newCheckpointCount < 1 then
			warn("[Race] Track geometry or race triggers are incomplete")
			return false
		end
		local newRoadParts: { BasePart } = {}
		local newGates: { BasePart } = {}
		local newCheckpoints: { [number]: BasePart } = {}
		local newStartFinish: BasePart? = nil
		for _, child in roadFolder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(newRoadParts, child)
			end
		end
		for _, child in raceTriggers:GetChildren() do
			if child:IsA("BasePart") and child:GetAttribute("RaceGate") == true then
				table.insert(newGates, child)
				if child:GetAttribute("GateType") == "StartFinish" then
					newStartFinish = child
				elseif child:GetAttribute("GateType") == "Checkpoint" then
					local checkpointIndex = child:GetAttribute("CheckpointIndex")
					if type(checkpointIndex) == "number" then
						newCheckpoints[checkpointIndex] = child
					end
				end
			end
		end
		if not newStartFinish or #newRoadParts < 1 then
			warn("[Race] StartFinish or road is missing")
			return false
		end
		local orderedGates: { BasePart } = { newStartFinish :: BasePart }
		for checkpointIndex = 1, newCheckpointCount do
			local checkpoint = newCheckpoints[checkpointIndex]
			if not checkpoint then
				warn(string.format("[Race] Checkpoint %d is missing", checkpointIndex))
				return false
			end
			table.insert(orderedGates, checkpoint)
		end
		table.insert(orderedGates, newStartFinish :: BasePart)
		local minimumPathDistance = 0
		for index = 1, #orderedGates - 1 do
			minimumPathDistance += planarDistance(orderedGates[index].Position, orderedGates[index + 1].Position)
		end
		local definition = TrackGeometry.getDefinition(track.GeometryId)
		routeCourse = TrackGeometry.getCourse(definition)
		routeRoadWidth = definition.RoadWidth
		checkpointCount = newCheckpointCount
		roadParts = newRoadParts
		roadIndex(roadParts) -- Build once at track binding, never during a driving frame.
		finishRoadWidth = definition.RoadWidth
		gates = newGates
		checkpoints = newCheckpoints
		startFinishGate = newStartFinish
		minimumValidLapTime = minimumPathDistance / KartConfig.MINI_BOOST_MAX_SPEED
			* RaceConfig.MIN_LAP_TIME_SAFETY_FACTOR
		session.trackData = {
			checkpointCount = checkpointCount, roadParts = roadParts, gates = gates,
			checkpoints = checkpoints, startFinishGate = startFinishGate,
			routeCourse = routeCourse, roadWidth = routeRoadWidth,
			minimumValidLapTime = minimumValidLapTime,
		}
		print(string.format("[Race] bound track=%s minimumValidLapTime=%.2f", trackId, minimumValidLapTime))
		return true
	end

	-- Keep Garage attributes/remotes initialized without inventing a fake TestTrack.
	if not hubParkPreview and not bindTrackForRace(initialTrackId) then
		return false
	end

	for _, player in Players:GetPlayers() do
		initializePlayerAttributes(player, checkpointCount, initialTrackId)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		initializePlayerAttributes(player, checkpointCount, initialTrackId)
	end)

	local remoteEvent = ReplicatedStorage:FindFirstChild(RaceConfig.CONTROL_REMOTE_EVENT_NAME)
	if not remoteEvent or not remoteEvent:IsA("RemoteEvent") then
		if remoteEvent then
			remoteEvent:Destroy()
		end
		remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = RaceConfig.CONTROL_REMOTE_EVENT_NAME
		remoteEvent.Parent = ReplicatedStorage
	end
	local raceRemote = remoteEvent :: RemoteEvent

	local racers = {}
	local sessionElapsed = 0
	local publishSession: (now: number) -> ()

	local function createRacer(player: Player, context)
		local kart, chassis, seat = context.kart, context.chassis, context.seat
		local racer = RacerState.new(player, context,
			if routeCourse then RaceRouteProgress.new(routeCourse, routeRoadWidth) else nil)
		racer.targetLaps = RaceMode.targetLaps(RaceMode.resolve(initialTrackId), initialTrackId)
		racer.lastRoadIndex = nil
		racer.progressRecordElapsed = 0
		local function clearGateState()
			table.clear(racer.insideGate)
			racer.previousChassisPosition = nil
			if routeCourse then
				racer.routeProgress = RaceRouteProgress.new(routeCourse, routeRoadWidth)
			end
		end

		local function resetOffTrackState(player: Player)
			racer.offTrackSampleElapsed = 0
			racer.offTrackElapsed = 0
			racer.lastRoadIndex = nil
			kart:SetAttribute("KartOffTrack", false)
			player:SetAttribute("RaceOffTrackRemaining", 0)
		end

		local function setRaceState(player: Player, state: string)
			local previousState = player:GetAttribute("RaceState")
			if previousState == state then
				return
			end
			player:SetAttribute("RaceState", state)
			if state == "FINISHING" then publishRoomPhase("FINISHING", session:count()) end
			print(string.format("[Race] state %s -> %s", tostring(previousState), state))
		end

		local function resetKartToStart()
			local raceStartCFrame = kart:GetAttribute("RaceStartCFrame")
			if typeof(raceStartCFrame) == "CFrame" then
				kart:PivotTo(raceStartCFrame)
			else
				warn("[Race] RaceStartCFrame is missing")
			end
			chassis.AssemblyLinearVelocity = Vector3.zero
			chassis.AssemblyAngularVelocity = Vector3.zero
		end

		local function resetRaceProgress(player: Player)
			player:SetAttribute("RaceCurrentLap", 1)
			player:SetAttribute("RaceCompletedLaps", 0)
			player:SetAttribute("RaceTotalLaps", racer.targetLaps)
			player:SetAttribute("RaceNextCheckpoint", 1)
			player:SetAttribute("RaceCheckpointCount", checkpointCount)
			player:SetAttribute("RaceLastLapTime", 0)
			player:SetAttribute("RaceBestLapTime", 0)
			player:SetAttribute("RaceBestLapNumber", 0)
			for lap = 1, 3 do player:SetAttribute("RaceLap" .. lap .. "Time", 0) end
			player:SetAttribute("RaceFinalTime", 0)
			player:SetAttribute("RaceDNFReason", "")
			player:SetAttribute("RaceFinishMissedSerial", 0)
			player:SetAttribute("RaceCheckpointMissed", 0)
			racer.raceStartTime = 0
			racer.lapStartTime = 0
			racer.finishEndTime = 0
			racer.finishRollEndTime = 0
			racer.lastRoadIndex = nil
			racer.progressRecordElapsed = 0
			player:SetAttribute("RaceFinishPhase", "NONE")
			kart:SetAttribute("KartFinishRollActive", false)
			resetOffTrackState(player)
			clearGateState()
		end

		local function prepareCountdown()
			kart:SetAttribute("RaceControlsLocked", true)
			kart:SetAttribute("KartFinishRollActive", false)
			resetKartToStart()
			resetRaceProgress(player)
			racer.countdownEndTime = session.countdownEndTime
			racer.lastCountdownValue = RaceConfig.COUNTDOWN_SECONDS
			player:SetAttribute("RaceCountdown", racer.lastCountdownValue)
			setRaceState(player, "COUNTDOWN")
		end

		function racer:enterWaitingLobby()
			kart:SetAttribute("RaceControlsLocked", true)
			kart:SetAttribute("KartFinishRollActive", false)
			racer.countdownEndTime = 0
			racer.finishRollEndTime = 0
			racer.finishEndTime = 0
			player:SetAttribute("RaceFinishPhase", "NONE")
			player:SetAttribute("RaceCountdown", 0)
			resetKartToStart()
			resetOffTrackState(player)
			clearGateState()
			setRaceState(player, "PRE_RACE")
		end

		local function endActiveRace(player: Player)
			player:SetAttribute("RaceCountdown", 0)
			setRaceState(player, "GARAGE")
			kart:SetAttribute("RaceControlsLocked", true)
			kart:SetAttribute("KartFinishRollActive", false)
			racer.countdownEndTime = 0
			racer.finishRollEndTime = 0
			racer.finishEndTime = 0
			player:SetAttribute("RaceFinishPhase", "NONE")
			racer.raceStartTime = 0
			racer.lapStartTime = 0
			resetOffTrackState(player)
			clearGateState()
			player:SetAttribute("RaceMatchStatus", "")
			player:SetAttribute("RaceMatchWaitReason", "NONE")
			player:SetAttribute("RaceSessionComplete", false)
			player:SetAttribute("RaceEndCountdownActive", false)
			player:SetAttribute("RaceEndCountdownRemaining", 0)
			player:SetAttribute("RaceMapActive", false)
		end

		local function invalidateCurrentLap(player: Player, now: number, reason: string)
			record("invalidate", player)
			local completedLaps = (player:GetAttribute("RaceCompletedLaps") :: number?) or 0
			local previousNext = (player:GetAttribute("RaceNextCheckpoint") :: number?) or 1
			print(string.format(
				"[Race] lap invalidated reason=%s lap=%d completed=%d previousNext=%d x=%.1f z=%.1f",
				reason,
				math.min(completedLaps + 1, racer.targetLaps),
				completedLaps,
				previousNext,
				chassis.Position.X,
				chassis.Position.Z
			))
			player:SetAttribute("RaceCurrentLap", math.min(completedLaps + 1, racer.targetLaps))
			player:SetAttribute("RaceNextCheckpoint", 1)
			player:SetAttribute("RaceCheckpointMissed", 0)
			racer.lapStartTime = now
			resetOffTrackState(player)
			clearGateState()
		end

		local function endRaceOffTrack(player: Player)
			print(string.format("[Race] DNF reason=off_track lap=%d completed=%d nextCheckpoint=%d", (player:GetAttribute("RaceCurrentLap") :: number?) or 1, (player:GetAttribute("RaceCompletedLaps") :: number?) or 0, (player:GetAttribute("RaceNextCheckpoint") :: number?) or 1))
			kart:SetAttribute("RaceControlsLocked", true)
			resetOffTrackState(player)
			clearGateState()
			player:SetAttribute("RaceDNFReason", "OFF_TRACK")
			player:SetAttribute("RaceMapActive", false)
			setRaceState(player, "DNF")
			session.terminal[player] = "DNF"
			publishSession(time())
		end

		function racer:timeoutRace()
			if player:GetAttribute("RaceState") ~= "RACING" then return end
			local velocity = chassis.AssemblyLinearVelocity
			local planarSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local offTrack = racer.offTrackElapsed > 0 or kart:GetAttribute("KartOffTrack") == true
			local completedLaps = (player:GetAttribute("RaceCompletedLaps") :: number?) or 0
			local isCrashed = kart:GetAttribute("KartCrashActive") == true
			local isActiveRacer = not offTrack and not isCrashed and planarSpeed >= 15 and completedLaps >= 1

			kart:SetAttribute("RaceControlsLocked", true)
			kart:SetAttribute("KartFinishRollActive", false)
			chassis.AssemblyLinearVelocity = Vector3.zero
			chassis.AssemblyAngularVelocity = Vector3.zero
			resetOffTrackState(player)
			clearGateState()
			player:SetAttribute("RaceDNFReason", "RACE_TIMEOUT")
			player:SetAttribute("RaceMapActive", false)
			setRaceState(player, "DNF")
			session.terminal[player] = "RACE_TIMEOUT"
			publishSession(time())

			if isActiveRacer and EconomyService and EconomyService.creditReward then
				local identity=racer.transactionIdentity -- Capture before a queued task or Rematch.
				task.spawn(function()
					local credited = EconomyService.creditReward(player, 1500, "ACTIVE_DNF_COMPLETION",identity)
					if credited and identity and player:GetAttribute("OfficialRoundGuid")==identity.RoundGuid then
						player:SetAttribute("RaceActiveDnfBonus", true)
						print(string.format("[Race] active racer timeout rewarded user=%d amount=1500 speed=%.1f laps=%d", player.UserId, planarSpeed, completedLaps))
					end
				end)
			end
		end

		function racer:forfeit()
			if player:GetAttribute("RaceState") ~= "RACING" then return false end
			kart:SetAttribute("RaceControlsLocked", true)
			kart:SetAttribute("KartFinishRollActive", false)
			chassis.AssemblyLinearVelocity = Vector3.zero
			chassis.AssemblyAngularVelocity = Vector3.zero
			resetOffTrackState(player)
			clearGateState()
			player:SetAttribute("RaceCountdown", 0)
			player:SetAttribute("RaceDNFReason", "FORFEIT")
			player:SetAttribute("RaceMapActive", false)
			setRaceState(player, "DNF")
			session.terminal[player] = "FORFEIT"
			publishSession(time())
			return true
		end

		local function beginFinishSequence(player: Player, now: number)
			player:SetAttribute("RaceCurrentLap", racer.targetLaps)
			player:SetAttribute("RaceNextCheckpoint", 1)
			player:SetAttribute("RaceCheckpointMissed", 0)
			player:SetAttribute("RaceCountdown", 0)
			local finalTime = now - racer.raceStartTime
			player:SetAttribute("RaceFinalTime", finalTime)
			session:recordFinish(player, finalTime)
			if session.startingParticipantCount > 1 and session.raceEndDeadline == 0 then
				session.firstFinishAt = now
				session.raceEndDeadline = now + RaceConfig.POST_FIRST_FINISH_GRACE_SECONDS
			end
			local gate = startFinishGate :: BasePart
			local look = gate.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			kart:SetAttribute("KartFinishRollDirection", flat.Unit)
			kart:SetAttribute("KartFinishRollActive", true)
			kart:SetAttribute("RaceControlsLocked", true)
			player:SetAttribute("RaceFinishPhase", "ROLL")
			racer.finishRollEndTime = now + RaceConfig.FINISH_ROLL_SECONDS
			racer.finishEndTime = now + RaceConfig.FINISH_SEQUENCE_SECONDS
			setRaceState(player, "FINISHING")
			resetOffTrackState(player)
			clearGateState()
			local bestLap = (player:GetAttribute("RaceBestLapTime") :: number?) or 0
			print(string.format("[Race] FINISHING total=%.2f best=%.2f", finalTime, bestLap))
		end

		local function beginFinishPresentation(player: Player)
			kart:SetAttribute("KartFinishRollActive", false)
			-- Official result and ROLL are already complete. Rotate the entire
			-- model around the chassis center; retain every local visual/seat offset.
			local gateFrame = (startFinishGate :: BasePart).CFrame
			local before = chassis.CFrame
			local desired = CFrame.fromMatrix(before.Position, gateFrame.RightVector, gateFrame.UpVector, -gateFrame.LookVector)
			kart:PivotTo(desired * before:Inverse() * kart:GetPivot())
			chassis.AssemblyLinearVelocity = Vector3.zero
			chassis.AssemblyAngularVelocity = Vector3.zero
			player:SetAttribute("RaceFinishPhase", "PRESENT")
		end

		local function endFinishSequence(player: Player, now: number)
			if player:GetAttribute("RaceFinishPhase") == "ROLL" then beginFinishPresentation(player) end
			racer.finishRollEndTime = 0
			racer.finishEndTime = 0
			setRaceState(player, "FINISHED")
			session.terminal[player] = "FINISHED"
			local officialResult = session:finalizedFinish(player, now)
			if officialResult then record("finish", player, officialResult) end
			publishSession(now)
		end

		local function completeLap(player: Player, now: number)
			local lapTime = now - racer.lapStartTime
			if lapTime < minimumValidLapTime then
				invalidateCurrentLap(player, now, "lap_too_fast")
				return
			end

			local completedLaps = (player:GetAttribute("RaceCompletedLaps") :: number?) or 0
			completedLaps += 1
			if racer.lastProgressRecordAt ~= now then
				record("progress", player, now, Vector3.new(chassis.Position.X,0,chassis.Position.Z),
					if racer.routeProgress then racer.routeProgress.previous else nil, player:GetAttribute("RaceNextCheckpoint"))
			end
			racer.progressRecordElapsed, racer.lastProgressRecordAt = 0, now
			record("checkpoints", player, player:GetAttribute("RaceNextCheckpoint"))
			record("lap", player, now, lapTime)
			local bestLap = (player:GetAttribute("RaceBestLapTime") :: number?) or 0

			player:SetAttribute("RaceLastLapTime", lapTime)
			player:SetAttribute("RaceLap" .. completedLaps .. "Time", lapTime)
			if bestLap == 0 or lapTime < bestLap then
				player:SetAttribute("RaceBestLapTime", lapTime)
				player:SetAttribute("RaceBestLapNumber", completedLaps)
			end
			player:SetAttribute("RaceCompletedLaps", completedLaps)
			player:SetAttribute("RaceNextCheckpoint", 1)
			player:SetAttribute("RaceCheckpointMissed", 0)
			print(string.format("[Race] Lap %d complete: %.2fs", completedLaps, lapTime))

			if completedLaps >= racer.targetLaps then
				beginFinishSequence(player, now)
			else
				player:SetAttribute("RaceCurrentLap", completedLaps + 1)
				racer.lapStartTime = now
				clearGateState()
			end
		end

		local function processGate(player: Player, gate: BasePart, now: number)
			if not isMovingThroughGate(chassis, gate) then
				return
			end

			local gateType = gate:GetAttribute("GateType")
			local nextCheckpoint = (player:GetAttribute("RaceNextCheckpoint") :: number?) or 1
			if gateType == "Checkpoint" then
				local checkpointIndex = gate:GetAttribute("CheckpointIndex")
				if checkpointIndex == nextCheckpoint and checkpoints[nextCheckpoint] == gate then
					player:SetAttribute("RaceNextCheckpoint", nextCheckpoint + 1)
					player:SetAttribute("RaceCheckpointMissed", 0)
					print(string.format("[Race] checkpoint accepted cp=%d next=%d lap=%d", nextCheckpoint, nextCheckpoint + 1, (player:GetAttribute("RaceCurrentLap") :: number?) or 1))
				end
			elseif gateType == "StartFinish" and gate == startFinishGate then
				print(string.format("[Race] finish crossed lap=%d nextCheckpoint=%d", (player:GetAttribute("RaceCurrentLap") :: number?) or 1, nextCheckpoint))
				if nextCheckpoint == checkpointCount + 1 then
					player:SetAttribute("RaceCheckpointMissed", 0)
					completeLap(player, now)
				else
					local lapElapsed = now - racer.lapStartTime
					local currentLap = (player:GetAttribute("RaceCurrentLap") :: number?) or 1
					local isStartingLap = (currentLap == 1 and lapElapsed < 12.0) or (nextCheckpoint == 1 and lapElapsed < 6.0)
					if not isStartingLap then
						player:SetAttribute("RaceCheckpointMissed", nextCheckpoint)
						player:SetAttribute("RaceFinishMissedSerial", ((player:GetAttribute("RaceFinishMissedSerial") :: number?) or 0) + 1)
						print(string.format("[Race] finish rejected reason=missing_checkpoint expected=%d total=%d", nextCheckpoint, checkpointCount))
					end
				end
			end
		end

		local function sampleRoadCorridor(player: Player, deltaTime: number)
			racer.offTrackSampleElapsed += deltaTime
			local timeoutReached = racer.offTrackElapsed > 0
				and racer.offTrackElapsed + racer.offTrackSampleElapsed >= RaceConfig.OFF_TRACK_TIMEOUT_SECONDS
			if racer.offTrackSampleElapsed < RaceConfig.OFF_TRACK_SAMPLE_INTERVAL and not timeoutReached then
				return
			end

			local sampleElapsed = racer.offTrackSampleElapsed
			racer.offTrackSampleElapsed = 0
			local inside, hitIndex = isInsideRoadCorridor(roadParts, chassis.Position, racer.lastRoadIndex)
			racer.roadSamplePosition, racer.roadSampleInside = chassis.Position, inside
			if inside then
				racer.lastRoadIndex = hitIndex
				if racer.offTrackElapsed > 0 then
					print(string.format("[Race] back_on_track after=%.2fs lap=%d nextCheckpoint=%d", racer.offTrackElapsed, (player:GetAttribute("RaceCurrentLap") :: number?) or 1, (player:GetAttribute("RaceNextCheckpoint") :: number?) or 1))
				end
				racer.offTrackElapsed = 0
				kart:SetAttribute("KartOffTrack", false)
				player:SetAttribute("RaceOffTrackRemaining", 0)
				return
			end

			racer.lastRoadIndex = nil
			if racer.offTrackElapsed == 0 then
				print(string.format("[Race] off_track lap=%d nextCheckpoint=%d x=%.1f z=%.1f", (player:GetAttribute("RaceCurrentLap") :: number?) or 1, (player:GetAttribute("RaceNextCheckpoint") :: number?) or 1, chassis.Position.X, chassis.Position.Z))
				kart:SetAttribute("KartOffTrack", true)
			end

			racer.offTrackElapsed += sampleElapsed
			if racer.offTrackElapsed >= RaceConfig.OFF_TRACK_TIMEOUT_SECONDS then
				endRaceOffTrack(player)
			else
				player:SetAttribute("RaceOffTrackRemaining", math.ceil(RaceConfig.OFF_TRACK_TIMEOUT_SECONDS - racer.offTrackElapsed))
			end
		end

		function racer:begin()
			prepareCountdown()
		end

		function racer:startRace(startTime: number)
			racer.raceStartTime = startTime
			racer.lapStartTime = startTime
			racer.lastResetSerial = kart:GetAttribute("RaceResetSerial")
			resetOffTrackState(player)
			clearGateState()
			player:SetAttribute("RaceCountdown", 0)
			setRaceState(player, "RACING")
			kart:SetAttribute("RaceControlsLocked", false)
			record("start", player, startTime)
		end

		function racer:finish()
			endActiveRace(player)
		end

		function racer:handleRemote(action: unknown, now: number): boolean
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local state = player:GetAttribute("RaceState")
			if not humanoid or humanoid.SeatPart ~= seat or seat.Occupant ~= humanoid
				or (state ~= "FINISHED" and state ~= "DNF") then return false end
			if action == "ReturnGarage" then
				endActiveRace(player)
				return true
			end
			return false
		end

		function racer:step(deltaTime: number, now: number)
			local player = self.player
			local raceState = player:GetAttribute("RaceState")
			if raceState == "FINISHING" then
				if now >= racer.finishRollEndTime and player:GetAttribute("RaceFinishPhase") == "ROLL" then
					beginFinishPresentation(player)
				end
				if now >= racer.finishEndTime then endFinishSequence(player, now) end
				return
			end
			if raceState == "COUNTDOWN" then
				return
			end

			local resetSerial = kart:GetAttribute("RaceResetSerial")
			if resetSerial ~= racer.lastResetSerial then
				racer.lastResetSerial = resetSerial
				if raceState == "RACING" then
					invalidateCurrentLap(player, now, "fall")
					resetOffTrackState(player)
					return
				end
			end

			if raceState ~= "RACING" then
				return
			end

			sampleRoadCorridor(player, deltaTime)
			-- The off-track timeout can end the race; it must win before any finish crossing.
			if player:GetAttribute("RaceState") ~= "RACING" then
				return
			end

			local onRoadAtGate
			if racer.roadSamplePosition == chassis.Position then
				onRoadAtGate = racer.roadSampleInside
			else
				local inside, hitIdx = isInsideRoadCorridor(roadParts, chassis.Position, racer.lastRoadIndex)
				onRoadAtGate = inside
				racer.lastRoadIndex = hitIdx
				racer.roadSamplePosition, racer.roadSampleInside = chassis.Position, inside
			end

			if racer.routeProgress then
				local nextCheckpoint = (player:GetAttribute("RaceNextCheckpoint") :: number?) or 1
				local recoveredNext = RaceRouteProgress.step(racer.routeProgress, chassis.Position, nextCheckpoint, onRoadAtGate)
				if recoveredNext > nextCheckpoint then
					player:SetAttribute("RaceNextCheckpoint", recoveredNext)
					player:SetAttribute("RaceCheckpointMissed", 0)
					print(string.format("[Race] checkpoint route accepted from=%d next=%d lap=%d", nextCheckpoint, recoveredNext, (player:GetAttribute("RaceCurrentLap") :: number?) or 1))
				elseif not onRoadAtGate and racer.routeProgress.previous then
					local currentFraction = racer.routeProgress.previous
					local cpSample = routeCourse and routeCourse.CheckpointSamples and routeCourse.CheckpointSamples[nextCheckpoint]
					if cpSample and currentFraction then
						local ahead = (currentFraction - cpSample.Fraction + 0.5) % 1 - 0.5
						if ahead > 0.035 and ahead < 0.35 then
							if player:GetAttribute("RaceCheckpointMissed") ~= nextCheckpoint then
								player:SetAttribute("RaceCheckpointMissed", nextCheckpoint)
								player:SetAttribute("RaceFinishMissedSerial", ((player:GetAttribute("RaceFinishMissedSerial") :: number?) or 0) + 1)
								print(string.format("[Race] checkpoint bypassed off-road cp=%d ahead=%.3f", nextCheckpoint, ahead))
							end
						end
					end
				end
			end
			racer.progressRecordElapsed = (racer.progressRecordElapsed or 0) + deltaTime
			if racer.progressRecordElapsed >= 0.2 then
				racer.progressRecordElapsed = 0
				racer.lastProgressRecordAt = now
				record("progress", player, now, Vector3.new(chassis.Position.X, 0, chassis.Position.Z),
					if racer.routeProgress then racer.routeProgress.previous else nil,
					player:GetAttribute("RaceNextCheckpoint"))
			end
			for _, gate in gates do
				local inside = isInsideGate(gate, chassis.Position)
				if inside and not racer.insideGate[gate] then
					if onRoadAtGate or (gate == startFinishGate
						and player:GetAttribute("RaceNextCheckpoint") == checkpointCount + 1) then
						processGate(player, gate, now)
					end
				end
				racer.insideGate[gate] = inside
			end
			local currentPosition = chassis.Position
			local finishGate = startFinishGate
			if racer.previousChassisPosition and finishGate
				and player:GetAttribute("RaceNextCheckpoint") == checkpointCount + 1
				and isMovingThroughGate(chassis, finishGate)
				and missedFinishPlane(racer.previousChassisPosition, currentPosition, finishGate, finishRoadWidth) then
				player:SetAttribute("RaceFinishMissedSerial", ((player:GetAttribute("RaceFinishMissedSerial") :: number?) or 0) + 1)
			end
			racer.previousChassisPosition = currentPosition
		end
		return racer
	end

	local function setChanged(player: Player, name: string, value)
		if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end
	end

	-- RaceController owns deadlines/readiness; replicated attributes are mirrors.
	session.itemPrepareDeadlines = {}
	session.itemsReady = {}
	local countdownStarting = false
	local lastStartRejection,lastStartRejectionAt=nil,-math.huge
	local function setStartBlocked(reason)
		for player in session.participants do setChanged(player,"RaceStartBlockedReason",reason or "")end
	end
	-- Compatibility mirrors only: item selection and preparation are retired.
	local quickStartAt = 0
	local function readyLoadout(player)
		session.itemsReady[player] = true
		session.itemPrepareDeadlines[player] = nil
		setChanged(player, "RaceItemsReady", true)
		setChanged(player, "RaceItemsAutoReady", false)
		setChanged(player, "RaceItemsPrepareRemaining", 0)
	end

	publishSession = function(now: number)
		sessionElapsed = 0
		if persistentRoom and options.getRoomHostUserId then
			session.hostUserId = options.getRoomHostUserId()
		end
		local count = session:count()
		local required = math.max(session:humanCount(), 1)
		local ready = 0
		local itemsReady = 0
		for player in session.participants do if session.itemsReady[player] then itemsReady += 1 end end
		for player in session.rematchVotes do
			if session:contains(player) then ready += 1 end
		end
		for player in session.participants do
			setChanged(player,'RacePublicMatch',options and options.isQuickMatch and options.isQuickMatch()or false)
			-- Presentation only; never extend the result, grace timer or reward lifecycle.
			setChanged(player, "RaceWinnerAwaitingRunnerUp", session.phase == "RACING"
				and session.startingParticipantCount > 1 and #session.finishOrder == 1
				and session.finishOrder[1].player == player)
			setChanged(player,'RacePrivatePractice',options and options.isPractice and options.isPractice()or false)
			setChanged(player, "RaceItemsReadyCount", itemsReady)
			setChanged(player, "RaceItemsRequiredCount", count)
			setChanged(player, "RaceParticipantCount", if session.startingParticipantCount > 0 then session.startingParticipantCount else count)
			setChanged(player, "RaceMaxPlayers", if preformedMatch and session.phase == "ARRIVAL"
				then expectedParticipantCount else session.maxPlayers)
			setChanged(player, "RaceMatchStatus", session.phase)
			setChanged(player, "RaceMatchWaitReason", session.waitingReason)
			setChanged(player, "RaceMatchWaitRemaining", 0)
			setChanged(player, "RaceHostUserId", session.hostUserId)
			setChanged(player, "RaceSessionComplete", session.phase == "COMPLETE")
			local graceActive = session.phase == "RACING" and session.raceEndDeadline > 0
			setChanged(player, "RaceEndCountdownActive", graceActive)
			setChanged(player, "RaceEndCountdownRemaining", if graceActive
				then math.max(math.ceil(session.raceEndDeadline - now), 0) else 0)
			setChanged(player, "RaceRematchReady", session.rematchVotes[player] == true)
			setChanged(player, "RaceRematchReadyCount", ready)
			setChanged(player, "RaceRematchRequiredCount", required)
		end
	end

	session.confirmItems = function() return false end

	local function startSharedCountdown(now: number)
		if countdownStarting or session:count() == 0 or (session.phase ~= "WAITING"
			and session.phase ~= "ARRIVAL" and session.phase ~= "COMPLETE" and session.phase ~= "EMPTY") then return end
  -- Event practice must wait for the actual admitted Bot, including retries.
  if options and options.isFirstRace and options.isFirstRace()
   and session:count()~=session:humanCount()+1 then setStartBlocked("BOT_PREPARING");return end
		countdownStarting = true
		if persistentRoom and options.getRoomHostUserId then
			session.hostUserId = options.getRoomHostUserId()
		end
		if persistentRoom and options.onRoundStart then
			for player in session.participants do
				if player:GetAttribute("KDMRoutePending") == "HUB_RETURN" then countdownStarting = false;setStartBlocked("RACER_RETURNING");return end
			end
			local ok, accepted, reason, detail = pcall(options.onRoundStart, session.hostUserId, session:count())
			if not ok or not accepted then
				countdownStarting = false
				reason=if not ok then "ROOM_STORAGE_UNAVAILABLE" else reason or "ROOM_START_REJECTED"
				setStartBlocked(reason)
				if reason~=lastStartRejection or now-lastStartRejectionAt>=5 then
					lastStartRejection,lastStartRejectionAt=reason,now
					warn(string.format("[KDMRoom] round start rejected reason=%s phase=%s localRacers=%d humans=%d storedState=%s arrived=%s reserved=%s bots=%s",
						reason,session.phase,session:count(),session:humanCount(),tostring(detail and detail.state),
						tostring(detail and detail.arrived),tostring(detail and detail.reserved),tostring(detail and detail.bots)))
				end
				return
			end
		end
		if session:count() == 0 then
			countdownStarting = false; return
		end
		rosterLocked = true
		setStartBlocked("");lastStartRejection=nil
		publicWarmup=options and options.isQuickMatch and options.isQuickMatch()and session:humanCount()==1 and session:count()>1 or false
		session.roundId += 1
		session.phase = "COUNTDOWN"
		session.waitingReason = "NONE"
		session.countdownEndTime = now + RaceConfig.COUNTDOWN_SECONDS
		session.startTime = 0
		session.startingParticipantCount = session:count()
		session.firstFinishAt = 0
		session.raceEndDeadline = 0
		table.clear(session.finishOrder)
		table.clear(session.rematchVotes)
		table.clear(session.terminal)
		for place, player in session:orderedParticipants() do
			setChanged(player,'RacePublicWarmup',publicWarmup)
			local racer = racers[player]
			racer.targetLaps = session.targetLaps
			setChanged(player, "RaceSessionId", session.roundId)
			setChanged(player, "RaceFinishPosition", 0)
			setChanged(player, "RacePosition", place)
			racer:begin()
			setChanged(player, "RaceMapPosition", racer.context.chassis.Position)
			setChanged(player, "RaceMapActive", true)
		end
		publishSession(now)
		publishRoomPhase("STARTING", session:count())
		countdownStarting = false
	end

	local function startSharedRace()
		-- Gameplay owns economic identity even when the optional records observer fails.
		local identity=table.freeze({RoundGuid=game:GetService("HttpService"):GenerateGUID(false),
		 IssuedAt=DateTime.now().UnixTimestampMillis})
		for _,player in session:orderedParticipants() do
			racers[player].transactionIdentity=identity
			player:SetAttribute("OfficialRoundGuid",identity.RoundGuid)
			player:SetAttribute("OfficialRoundIssuedAt",identity.IssuedAt)
		end
		session.phase = "RACING"
		session.startTime = session.countdownEndTime
		-- Freeze the actual GO roster; a departure during COUNTDOWN is not a starter.
		record("begin", session, routeCourse, checkpointCount, identity)
		for _, player in session:orderedParticipants() do
			racers[player]:startRace(session.startTime)
		end
		publishSession(session.startTime)
		publishRoomPhase("RACING", session:count())
	end

	local function updateComplete()
		if session.phase ~= "RACING" then return end
		local count = session:count()
		if count == 0 then
			session.phase = "EMPTY"
			session.firstFinishAt = 0
			session.raceEndDeadline = 0
			return
		end
		for player in session.participants do
			local state = player:GetAttribute("RaceState")
			if state ~= "FINISHED" and state ~= "DNF"
				and (state ~= "FINISHING" or session.startingParticipantCount == 1) then return end
		end
		session.phase = "COMPLETE"
		publishSession(time())
		publishRoomPhase("ROUND_COMPLETE", session:count())
	end

	local function updateRanking()
		if session.phase ~= "RACING" and session.phase ~= "COMPLETE" then return end
		local entries = {}
		for player, racer in session.participants do
			table.insert(entries, {
				player = player, userId = if player:GetAttribute("IsBot")==true then 0 else player.UserId or 0,
				state = player:GetAttribute("RaceState"),
				finishPosition = player:GetAttribute("RaceFinishPosition") or 0,
				completedLaps = player:GetAttribute("RaceCompletedLaps") or 0,
				nextCheckpoint = player:GetAttribute("RaceNextCheckpoint") or 1,
				routeFraction = (racer.routeProgress and racer.routeProgress.previous) or 0,
				readyOrder = player:GetAttribute("ReadyOrder") or 0,
			})
		end
		RaceRanking.sort(entries)
		for place, entry in entries do setChanged(entry.player, "RacePosition", place) end
	end

	local function publishMapPositions()
		for player, racer in session.participants do
			local context = racer.context
			if (session.phase == "COUNTDOWN" or session.phase == "RACING")
				and player:GetAttribute("RaceState") ~= "DNF"
				and context and context.kart.Parent and context.chassis.Parent
				and PrototypeWorld.getKartContext(player) == context then
				setChanged(player, "RaceMapPosition", context.chassis.Position)
				setChanged(player, "RaceMapActive", true)
			else
				setChanged(player, "RaceMapActive", false)
			end
		end
	end

	local function enterWaitingLobby(now: number, reason: string)
		publicNextAt=0
		setStartBlocked("")
		session.phase = "WAITING"
		session.waitingReason = reason
		if reason ~= "INITIAL" then
			session.startingParticipantCount = 0
			session.firstFinishAt = 0
			session.raceEndDeadline = 0
			session.countdownEndTime = 0
			session.startTime = 0
			table.clear(session.rematchVotes)
			table.clear(session.terminal)
			table.clear(session.finishOrder)
			local ordered = session:orderedParticipants()
			session.hostUserId = if ordered[1] then ordered[1]:GetAttribute("IsBot")==true and 0 or ordered[1].UserId else 0
			for _, player in ordered do
				local racer = racers[player]
				racer:enterWaitingLobby()
				setChanged(player, "RaceMapActive", false)
			end
		end
		if quickStartAt == 0 or reason ~= "INITIAL" then quickStartAt = now + RaceConfig.QUICK_RACE_ARRIVAL_WAIT_SECONDS end
		for player in session.participants do readyLoadout(player) end
		publishSession(now)
	end

	local function allRematchVotes(): boolean
		if session:count() == 0 then return false end
		for player in session.participants do
			if player:GetAttribute("IsBot")~=true and not session.rematchVotes[player] then return false end
		end
		return true
	end

	local function beginVotedRound(now: number)
		if preformedMatch then
			startSharedCountdown(now)
		else
			enterWaitingLobby(now, "REMATCH")
		end
	end

	local function prepareNextRoomRound()
		if nextRoundPending or not options or not options.onRoundReady then return end
		nextRoundPending = true
		local participants = session:orderedParticipants()
		task.spawn(function()
			local ok, accepted = pcall(options.onRoundReady, participants)
			if ok and accepted then
				enterWaitingLobby(time(), "REMATCH")
				rosterLocked = false
				publishRoomPhase("WAITING", session:count())
			else warn("[KDMRoom] next staging unavailable") end
			nextRoundPending = false
		end)
	end

	local function removeRacer(player: Player)
		local racer = racers[player]
		if not racer then return end
		local previousPhase = session.phase
		if session.phase == "RACING" and player:GetAttribute("RaceState") ~= "FINISHED"
			and player:GetAttribute("RaceState") ~= "DNF" then
			if not session.terminal[player] then session.terminal[player] = "LEFT" end
		end
		setChanged(player, "RaceMapActive", false)
		setChanged(player, "RaceHostUserId", 0)
		if racer.context.kart.Parent then racer:finish() end
		session:remove(player)
		session.itemPrepareDeadlines[player], session.itemsReady[player] = nil, nil
		setChanged(player, "RaceItemsReady", false)
		setChanged(player, "RaceItemsAutoReady", false)
		setChanged(player, "RaceItemsPrepareRemaining", 0)
		setChanged(player, "RaceItemsReadyCount", 0)
		setChanged(player, "RaceItemsRequiredCount", 0)
		racers[player] = nil
		if player:GetAttribute("IsBot")~=true and PrototypeWorld.releaseKartContext then PrototypeWorld.releaseKartContext(player) end
		if persistentRoom and options.onRoomLeave and player:GetAttribute("IsBot")~=true then
			task.spawn(options.onRoomLeave, player.UserId)
		end
		if player:GetAttribute("IsBot")~=true and session.hostUserId == player.UserId then
			local remaining = session:orderedParticipants()
			session.hostUserId = if remaining[1] then remaining[1]:GetAttribute("IsBot")==true and 0 or remaining[1].UserId else 0
		end
		if session:count() == 0 then
			quickStartAt = 0
			session.phase = "EMPTY"
			if persistentRoom and previousPhase ~= "WAITING" then
				publishRoomPhase("ROUND_COMPLETE", 0)
				prepareNextRoomRound()
			elseif persistentRoom then
				publishRoomPhase("WAITING", 0)
			end
			arrivalDeadline = 0
			session.firstFinishAt = 0
			session.raceEndDeadline = 0
			session.waitingReason = "NONE"
			session.startingParticipantCount = 0
			session.hostUserId = 0
			return
		end
		if session.phase == "COMPLETE" and allRematchVotes() then
			if persistentRoom then prepareNextRoomRound() else beginVotedRound(time()) end
			return
		end
		updateComplete()
		publishSession(time())
		updateRanking()
		if persistentRoom and (session.phase == "RACING" or session.phase == "COMPLETE") then
			publishRoomPhase(if session.phase == "COMPLETE" then "ROUND_COMPLETE"
				else roomPresentationPhase, session:count())
		end
	end

	local function admitRacer(player: Player, context, now: number)
		if hubParkPreview then return end -- G2 is geometry-only; official racing remains in RACE.
		if preformedMatch and rosterLocked then
			warn(string.format("[KDMRoute] race admission reject user=%d reason=LATE_RACE_ARRIVAL", player.UserId))
			player:SetAttribute("RaceEntryError", "RACE SERVER UNAVAILABLE - RETURNING TO HUB")
			PrototypeWorld.releaseKartContext(player)
			if options.returnToHub then options.returnToHub(player) end
			return
		end
		local trackId = player:GetAttribute("SelectedTrackId")
		local track = if type(trackId) == "string" then TrackCatalog.Entries[trackId] else nil
		if not track then player:SetAttribute("RaceEntryError", "Track unavailable"); player:SetAttribute("RaceState", "GARAGE"); return end
		if session:count() == 0 then
			if not bindTrackForRace(trackId) then
				player:SetAttribute("RaceEntryError", "Track unavailable")
				player:SetAttribute("RaceState", "GARAGE")
				return
			end
			quickStartAt = now + RaceConfig.QUICK_RACE_ARRIVAL_WAIT_SECONDS
			session.trackId = trackId
			session.maxPlayers = track.MaxPlayers
			session.mode = RaceMode.resolve(trackId)
			session.targetLaps = RaceMode.targetLaps(session.mode, trackId)
			session.startingParticipantCount = 0
			session.hostUserId = player.UserId
		elseif (session.phase ~= "WAITING" and (not preformedMatch or session.phase ~= "ARRIVAL"))
			or track.MatchType ~= "PUBLIC_RACE" or session.trackId ~= trackId or session:count() >= session.maxPlayers then
			player:SetAttribute("RaceEntryError", if session.phase == "COUNTDOWN" or session.phase == "RACING" then "Race in progress" else "Racer not ready")
			player:SetAttribute("RaceState", "GARAGE")
			return
		end
		local racer = createRacer(player, context)
		racer.targetLaps = session.targetLaps
		racers[player] = racer
		session:add(player, racer)
		player:SetAttribute("RaceMode", session.mode)
		setChanged(player, "RaceSessionId", session.roundId + 1)
		context.kart:SetAttribute("RaceControlsLocked", true)
		if preformedMatch then
			if arrivalDeadline == 0 then arrivalDeadline = now + RaceConfig.RESERVED_ROSTER_WAIT_SECONDS end
			session.phase = "ARRIVAL"
			session.waitingReason = "ARRIVAL"
			racer:enterWaitingLobby()
			publishSession(now)
			if session:count() >= expectedParticipantCount then startSharedCountdown(now) end
		elseif track.MatchType == "PUBLIC_RACE" then
			enterWaitingLobby(now, "INITIAL")
		else
			startSharedCountdown(now)
		end
	end

	raceRemote.OnServerEvent:Connect(function(player: Player, action: unknown)
		local racer = racers[player]
		if not racer then return end
		if action == "ReturnGarage" then
			if options and options.returnToHub then
				local state = player:GetAttribute("RaceState")
				if state == "FINISHED" or state == "DNF" then options.returnToHub(player) end
			elseif racer:handleRemote(action, time()) then removeRacer(player) end
		elseif action == "CancelWait" and session.phase == "WAITING" and session:contains(player) then
			if persistentRoom and options.returnToHub then options.returnToHub(player)
			else removeRacer(player) end
		elseif (action == "StartRace" or (action == "StartSolo" and session:count() == 1))
			and session.phase == "WAITING" and session:count() >= 1
			and TrackCatalog.Entries[session.trackId].MatchType == "PUBLIC_RACE"
			and (if persistentRoom and options.getRoomHostUserId
				then options.getRoomHostUserId() else session.hostUserId) == player.UserId then
			startSharedCountdown(time())
		elseif action == "QuitRace" and session:contains(player) and session.phase == "RACING"
			and player:GetAttribute("RaceState") == "RACING"
			and PrototypeWorld.getKartContext(player) == racer.context and racer.context.owner == player then
			if options and options.returnToHub then
				if racer:forfeit() then
					updateComplete()
					publishSession(time())
					options.returnToHub(player)
				end
			else
				session.terminal[player] = "FORFEIT"
				removeRacer(player)
			end
		elseif action == "Rematch" and session.phase == "COMPLETE"
			and (player:GetAttribute("RaceState") == "FINISHED" or player:GetAttribute("RaceState") == "DNF"
				and player:GetAttribute("RaceDNFReason") ~= "FORFEIT") then
			session.rematchVotes[player] = true
			publishSession(time())
			if allRematchVotes() then
				if persistentRoom then prepareNextRoomRound()
				elseif TrackCatalog.Entries[session.trackId].MatchType == "PUBLIC_RACE" then beginVotedRound(time())
				else startSharedCountdown(time()) end
			end
		end
	end)

	Players.PlayerRemoving:Connect(removeRacer)

	-- Explicit Studio harness admission only. Normal Player admission is unchanged.
	function session:addServerBot(state,context,source)
		local permitted = if source == "PRODUCTION_ROOM" then persistentRoom
			and RaceConfig.INVITEABLE_BOT_ENABLED and Workspace:GetAttribute("KDMServerRole") == "RACE"
			else source == "STUDIO_TEST" and RunService:IsStudio() and Workspace:GetAttribute("KDMEnableRaceBot")==true
		if not permitted or state:GetAttribute("IsBot")~=true or self:contains(state)
			or self:count()>=self.maxPlayers or self:humanCount()==0 or rosterLocked
			or not context or not context.kart.Parent or PrototypeWorld.getKartContext(state)~=context
			or not TrackCatalog.botAllowed(self.trackId) or self.phase~="WAITING" then return false end
		initializePlayerAttributes(state,checkpointCount,self.trackId)
		state:SetAttribute("RaceSessionId",self.roundId+1)
		local racer=createRacer(state,context);racer.targetLaps=self.targetLaps
		racers[state]=racer;self:addBot(state,racer);self.itemsReady[state]=true
		setChanged(state,"RaceItemsReady",true)
		racer:enterWaitingLobby();publishSession(time());return true
	end
	function session:addTestBot(state,context)
		if self:count()~=1 or self:humanCount()~=1 then return false end
		return self:addServerBot(state,context,"STUDIO_TEST")
	end
	function session:startBotTest()
		if RunService:IsStudio() and Workspace:GetAttribute("KDMEnableRaceBot")==true then startSharedCountdown(time()) end
	end
	function session:removeTestBot(state)
		if state:GetAttribute("IsBot")==true then removeRacer(state) end
	end
	session.removeServerBot=session.removeTestBot
	local warmupTransition=false
	function session:prepareQuickArrival(player,token)
		if self.phase=='WAITING'and options and options.onWaitingArrival then
			local ok,accepted=pcall(options.onWaitingArrival,player,token)
			return ok and accepted==true
		end
		if not publicWarmup or self:humanCount()~=1 or self.phase~='RACING'or not options.onWarmupArrival then return false end
		if warmupTransition then
			local deadline=time()+8
			while warmupTransition and time()<deadline do task.wait(.1)end
			return not rosterLocked
		end
		warmupTransition=true
		local ok,accepted=pcall(options.onWarmupArrival,player,token)
		if ok and accepted then
			rosterLocked=false;countdownStarting=false
			enterWaitingLobby(time(),'PUBLIC_JOIN')
			publicWarmup=false
			for p in self.participants do setChanged(p,'RacePublicWarmup',false)end
		end
		warmupTransition=false
		return ok and accepted==true
	end
	local rankElapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		local diagnostic=PerformanceMonitor and PerformanceMonitor.active()
		local loopStarted=if diagnostic then os.clock() else 0
		local now = time()
		for _, player in Players:GetPlayers() do
			local context = PrototypeWorld.getKartContext(player)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local seated = context and humanoid and humanoid.SeatPart == context.seat
				and context.seat.Occupant == humanoid
			local racer = racers[player]
			if racer and (not seated or racer.context ~= context or player:GetAttribute("RaceState") == "GARAGE") then
				removeRacer(player)
			elseif not racer and seated and player:GetAttribute("RaceState") == "PRE_RACE" then
				admitRacer(player, context, now)
			end
		end
		if preformedMatch and session.phase == "ARRIVAL" and arrivalDeadline > 0
			and now >= arrivalDeadline and session:count() > 0 then
			startSharedCountdown(now)
		end
		if session.phase == "WAITING" then
			local quick = options and options.isQuickMatch and options.isQuickMatch()
			local hostStart = options and options.requiresHostStart and options.requiresHostStart()
			local publicReady = quick and session:humanCount() >= 1 and now >= quickStartAt
			if quick and not publicReady then setStartBlocked("WAITING_FOR_RACERS") end
			if not hostStart and (session:count() == session.maxPlayers or publicReady) and now-lastPublicStart>=1 then
				lastPublicStart=now;startSharedCountdown(now)
			end
		end
		if session.phase == "COUNTDOWN" then
			local remaining = math.max(math.ceil(session.countdownEndTime - now), 0)
			for player, racer in session.participants do
				setChanged(player, "RaceCountdown", remaining)
				racer.lastCountdownValue = remaining
			end
			if remaining == 0 then startSharedRace() end
		end
		for player, racer in session.participants do racer:step(deltaTime, now) end
		if session.phase == "RACING" and session.raceEndDeadline > 0
			and now >= session.raceEndDeadline then
			for player, racer in session.participants do
				if player:GetAttribute("RaceState") == "RACING" then racer:timeoutRace() end
			end
		end
		updateComplete()
		if session.phase=='COMPLETE'and options and options.isQuickMatch and options.isQuickMatch()and not warmupTransition
   and not (options.isFirstRace and options.isFirstRace()) then
			if publicNextAt==0 then
				-- Always provide the full 8-second window to view results and rewards.
				publicNextAt = now + 8
			end
			if now>=publicNextAt then publicNextAt=now+5;prepareNextRoomRound()end
		end
		rankElapsed += deltaTime
		if rankElapsed >= RaceConfig.RANK_UPDATE_INTERVAL then
			rankElapsed = 0
			updateRanking()
			publishMapPositions()
		end
		sessionElapsed += deltaTime
		if sessionElapsed >= 0.2 then
			publishSession(now)
		end
		if diagnostic then PerformanceMonitor.route(deltaTime,(os.clock()-loopStarted)*1000,session:count()) end
	end)

	print(string.format("[Race] minimumValidLapTime=%.2f", minimumValidLapTime))
	print("[RobloxKart] Race controller ready")
	return true
end

return RaceController
