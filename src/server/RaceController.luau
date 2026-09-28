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
local RaceMode = requireModule(Shared:WaitForChild("RaceMode") :: ModuleScript)
local PrototypeWorld = require(script.Parent:WaitForChild("PrototypeWorld"))
local RaceSession = require(script.Parent:WaitForChild("RaceSession"))
local RacerState = require(script.Parent:WaitForChild("RacerState"))

local RaceController = {}

local DIRECTION_THRESHOLD = 0.25
local MIN_GATE_SPEED = 1
local started = false

local function initializePlayerAttributes(player: Player, checkpointCount: number)
	player:SetAttribute("RaceState", "GARAGE")
	player:SetAttribute("RaceCountdown", 0)
	player:SetAttribute("RaceCurrentLap", 1)
	player:SetAttribute("RaceCompletedLaps", 0)
	player:SetAttribute("RaceTotalLaps", RaceConfig.TOTAL_LAPS)
	player:SetAttribute("RaceNextCheckpoint", 1)
	player:SetAttribute("RaceLastLapTime", 0)
	player:SetAttribute("RaceBestLapTime", 0)
	player:SetAttribute("RaceBestLapNumber", 0)
	for lap = 1, 3 do player:SetAttribute("RaceLap" .. lap .. "Time", 0) end
	player:SetAttribute("RaceFinalTime", 0)
	player:SetAttribute("RaceFinishPhase", "NONE")
	player:SetAttribute("RaceCheckpointCount", checkpointCount)
	player:SetAttribute("RaceOffTrackRemaining", 0)
	player:SetAttribute("RaceFinishMissedSerial", 0)
end

local function isInsideGate(gate: BasePart, worldPosition: Vector3): boolean
	local localPosition = gate.CFrame:PointToObjectSpace(worldPosition)
	local halfSize = gate.Size * 0.5
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
end

local function isInsideRoadCorridor(roadParts: { BasePart }, worldPosition: Vector3): boolean
	for _, roadPart in roadParts do
		local localPosition = roadPart.CFrame:PointToObjectSpace(worldPosition)
		local halfSize = roadPart.Size * 0.5
		if math.abs(localPosition.X) <= halfSize.X + RaceConfig.ROAD_CORRIDOR_MARGIN
			and math.abs(localPosition.Z) <= halfSize.Z + RaceConfig.ROAD_CORRIDOR_MARGIN
		then
			return true
		end
	end
	return false
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

function RaceController.start()
	if started then
		return
	end
	started = true

	local prototype = Workspace:WaitForChild("Prototype")
	local session = RaceSession.new(TrackCatalog.DefaultId, RaceMode.resolve(TrackCatalog.DefaultId), RaceConfig.TOTAL_LAPS)
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

	if not bindTrackForRace(TrackCatalog.DefaultId) then
		return
	end

	for _, player in Players:GetPlayers() do
		initializePlayerAttributes(player, checkpointCount)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		initializePlayerAttributes(player, checkpointCount)
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

	local function createRacer(player: Player, context)
		local kart, chassis, seat = context.kart, context.chassis, context.seat
		local racer = RacerState.new(player, context,
			if routeCourse then RaceRouteProgress.new(routeCourse, routeRoadWidth) else nil)
		racer.targetLaps = RaceConfig.TOTAL_LAPS
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
			kart:SetAttribute("KartOffTrack", false)
			player:SetAttribute("RaceOffTrackRemaining", 0)
		end

		local function setRaceState(player: Player, state: string)
			local previousState = player:GetAttribute("RaceState")
			if previousState == state then
				return
			end
			player:SetAttribute("RaceState", state)
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
			player:SetAttribute("RaceFinishMissedSerial", 0)
			racer.raceStartTime = 0
			racer.lapStartTime = 0
			racer.finishEndTime = 0
			racer.finishRollEndTime = 0
			player:SetAttribute("RaceFinishPhase", "NONE")
			kart:SetAttribute("KartFinishRollActive", false)
			resetOffTrackState(player)
			clearGateState()
		end

		local function beginCountdown(player: Player, now: number)
			local trackId = player:GetAttribute("SelectedTrackId")
			local mode = RaceMode.resolve(trackId)
			player:SetAttribute("RaceMode", mode)
			racer.targetLaps = RaceMode.targetLaps(mode)
			if type(trackId) ~= "string" or (session:hasOtherParticipants(player) and session.trackId ~= trackId)
				or not bindTrackForRace(trackId) then
				kart:SetAttribute("RaceControlsLocked", true)
				kart:SetAttribute("KartFinishRollActive", false)
				player:SetAttribute("RaceFinishPhase", "NONE")
				player:SetAttribute("RaceEntryError", "Track unavailable")
				setRaceState(player, "GARAGE")
				return
			end
			if not session:hasOtherParticipants(player) then
				table.clear(session.finishOrder)
				session.startTime = 0
			end
			session.trackId, session.mode, session.targetLaps = trackId, mode, racer.targetLaps
			kart:SetAttribute("RaceControlsLocked", true)
			kart:SetAttribute("KartFinishRollActive", false)
			resetKartToStart()
			resetRaceProgress(player)
			racer.countdownEndTime = now + RaceConfig.COUNTDOWN_SECONDS
			session.countdownEndTime = racer.countdownEndTime
			racer.lastCountdownValue = RaceConfig.COUNTDOWN_SECONDS
			player:SetAttribute("RaceCountdown", racer.lastCountdownValue)
			setRaceState(player, "COUNTDOWN")
			print(string.format("[Race] countdown=%d", racer.lastCountdownValue))
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
		end

		local function invalidateCurrentLap(player: Player, now: number, reason: string)
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
			racer.lapStartTime = now
			resetOffTrackState(player)
			clearGateState()
		end

		local function endRaceOffTrack(player: Player)
			print(string.format("[Race] DNF reason=off_track lap=%d completed=%d nextCheckpoint=%d", (player:GetAttribute("RaceCurrentLap") :: number?) or 1, (player:GetAttribute("RaceCompletedLaps") :: number?) or 0, (player:GetAttribute("RaceNextCheckpoint") :: number?) or 1))
			kart:SetAttribute("RaceControlsLocked", true)
			resetOffTrackState(player)
			clearGateState()
			setRaceState(player, "DNF")
		end

		local function beginFinishSequence(player: Player, now: number)
			player:SetAttribute("RaceCurrentLap", racer.targetLaps)
			player:SetAttribute("RaceNextCheckpoint", 1)
			player:SetAttribute("RaceCountdown", 0)
			local finalTime = now - racer.raceStartTime
			player:SetAttribute("RaceFinalTime", finalTime)
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
			chassis.AssemblyLinearVelocity = Vector3.zero
			chassis.AssemblyAngularVelocity = Vector3.zero
			player:SetAttribute("RaceFinishPhase", "PRESENT")
		end

		local function endFinishSequence(player: Player)
			if player:GetAttribute("RaceFinishPhase") == "ROLL" then beginFinishPresentation(player) end
			racer.finishRollEndTime = 0
			racer.finishEndTime = 0
			setRaceState(player, "FINISHED")
			table.insert(session.finishOrder, player)
		end

		local function completeLap(player: Player, now: number)
			local lapTime = now - racer.lapStartTime
			if lapTime < minimumValidLapTime then
				invalidateCurrentLap(player, now, "lap_too_fast")
				return
			end

			local completedLaps = (player:GetAttribute("RaceCompletedLaps") :: number?) or 0
			completedLaps += 1
			local bestLap = (player:GetAttribute("RaceBestLapTime") :: number?) or 0

			player:SetAttribute("RaceLastLapTime", lapTime)
			player:SetAttribute("RaceLap" .. completedLaps .. "Time", lapTime)
			if bestLap == 0 or lapTime < bestLap then
				player:SetAttribute("RaceBestLapTime", lapTime)
				player:SetAttribute("RaceBestLapNumber", completedLaps)
			end
			player:SetAttribute("RaceCompletedLaps", completedLaps)
			player:SetAttribute("RaceNextCheckpoint", 1)
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
					print(string.format("[Race] checkpoint accepted cp=%d next=%d lap=%d", nextCheckpoint, nextCheckpoint + 1, (player:GetAttribute("RaceCurrentLap") :: number?) or 1))
				end
			elseif gateType == "StartFinish" and gate == startFinishGate then
				print(string.format("[Race] finish crossed lap=%d nextCheckpoint=%d", (player:GetAttribute("RaceCurrentLap") :: number?) or 1, nextCheckpoint))
				if nextCheckpoint == checkpointCount + 1 then
					completeLap(player, now)
				else
					print(string.format("[Race] finish rejected reason=missing_checkpoint expected=%d total=%d", nextCheckpoint, checkpointCount))
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
			if isInsideRoadCorridor(roadParts, chassis.Position) then
				if racer.offTrackElapsed > 0 then
					print(string.format("[Race] back_on_track after=%.2fs lap=%d nextCheckpoint=%d", racer.offTrackElapsed, (player:GetAttribute("RaceCurrentLap") :: number?) or 1, (player:GetAttribute("RaceNextCheckpoint") :: number?) or 1))
				end
				racer.offTrackElapsed = 0
				kart:SetAttribute("KartOffTrack", false)
				player:SetAttribute("RaceOffTrackRemaining", 0)
				return
			end

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

		function racer:begin(now: number)
			beginCountdown(player, now)
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
			if action == "Rematch" then
				print("[Race] rematch accepted")
				beginCountdown(player, now)
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
				if now >= racer.finishEndTime then endFinishSequence(player) end
				return
			end
			if raceState == "COUNTDOWN" then
				racer.lastResetSerial = kart:GetAttribute("RaceResetSerial")
				local countdownValue = math.max(math.ceil(racer.countdownEndTime - now), 0)
				if countdownValue ~= racer.lastCountdownValue then
					racer.lastCountdownValue = countdownValue
					player:SetAttribute("RaceCountdown", countdownValue)
					if countdownValue > 0 then
						print(string.format("[Race] countdown=%d", countdownValue))
					end
				end
				if countdownValue <= 0 then
					racer.raceStartTime = now
					if session.startTime == 0 then session.startTime = now end
					racer.lapStartTime = now
					resetOffTrackState(player)
					clearGateState()
					setRaceState(player, "RACING")
					kart:SetAttribute("RaceControlsLocked", false)
				end
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

			local onRoadAtGate = isInsideRoadCorridor(roadParts, chassis.Position)
			if racer.routeProgress then
				local nextCheckpoint = (player:GetAttribute("RaceNextCheckpoint") :: number?) or 1
				local recoveredNext = RaceRouteProgress.step(racer.routeProgress, chassis.Position, nextCheckpoint, onRoadAtGate)
				if recoveredNext > nextCheckpoint then
					player:SetAttribute("RaceNextCheckpoint", recoveredNext)
					print(string.format("[Race] checkpoint route accepted from=%d next=%d lap=%d", nextCheckpoint, recoveredNext, (player:GetAttribute("RaceCurrentLap") :: number?) or 1))
				end
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

	raceRemote.OnServerEvent:Connect(function(player: Player, action: unknown)
		local racer = racers[player]
		if racer and racer:handleRemote(action, time()) then
			session:remove(player)
			racers[player] = nil
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local racer = racers[player]
		if racer then
			racer:finish()
			session:remove(player)
			racers[player] = nil
		end
	end)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		local now = time()
		for _, player in Players:GetPlayers() do
			local context = PrototypeWorld.getKartContext(player)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local seated = context and humanoid and humanoid.SeatPart == context.seat
				and context.seat.Occupant == humanoid
			local racer = racers[player]
			if racer and (not seated or racer.context ~= context or player:GetAttribute("RaceState") == "GARAGE") then
				racer:finish()
				session:remove(player)
				racers[player] = nil
			elseif not racer and seated and player:GetAttribute("RaceState") == "PRE_RACE" then
				racer = createRacer(player, context)
				racers[player] = racer
				session:add(player, racer)
				racer:begin(now)
			elseif racer then
				racer:step(deltaTime, now)
			end
		end
	end)

	print(string.format("[Race] minimumValidLapTime=%.2f", minimumValidLapTime))
	print("[RobloxKart] Race controller ready")
end

return RaceController
