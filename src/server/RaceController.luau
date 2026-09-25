local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local requireModule = require :: (ModuleScript) -> any
local KartConfig = requireModule(Shared:WaitForChild("KartConfig") :: ModuleScript)
local RaceConfig = requireModule(Shared:WaitForChild("RaceConfig") :: ModuleScript)
local TrackCatalog = requireModule(Shared:WaitForChild("TrackCatalog") :: ModuleScript)

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
	player:SetAttribute("RaceFinalTime", 0)
	player:SetAttribute("RaceCheckpointCount", checkpointCount)
	player:SetAttribute("RaceOffTrackRemaining", 0)
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
	local kart = prototype:WaitForChild("Kart") :: Model
	local seat = kart:WaitForChild("Seat") :: Seat
	local chassis: BasePart
	if kart.PrimaryPart then
		chassis = kart.PrimaryPart
	else
		chassis = kart:WaitForChild("Chassis") :: BasePart
	end
	local checkpointCount = 0
	local gates: { BasePart } = {}
	local roadParts: { BasePart } = {}
	local startFinishGate: BasePart? = nil
	local checkpoints: { [number]: BasePart } = {}
	local minimumValidLapTime = 0

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
		checkpointCount = newCheckpointCount
		roadParts = newRoadParts
		gates = newGates
		checkpoints = newCheckpoints
		startFinishGate = newStartFinish
		minimumValidLapTime = minimumPathDistance / KartConfig.MINI_BOOST_MAX_SPEED
			* RaceConfig.MIN_LAP_TIME_SAFETY_FACTOR
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

	local activePlayer: Player? = nil
	local raceStartTime = 0
	local lapStartTime = 0
	local countdownEndTime = 0
	local lastCountdownValue = 0
	local lastResetSerial = kart:GetAttribute("RaceResetSerial")
	local insideGate: { [BasePart]: boolean } = {}
	local offTrackSampleElapsed = 0
	local offTrackElapsed = 0

	local function clearGateState()
		table.clear(insideGate)
	end

	local function resetOffTrackState(player: Player)
		offTrackSampleElapsed = 0
		offTrackElapsed = 0
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
		player:SetAttribute("RaceTotalLaps", RaceConfig.TOTAL_LAPS)
		player:SetAttribute("RaceNextCheckpoint", 1)
		player:SetAttribute("RaceCheckpointCount", checkpointCount)
		player:SetAttribute("RaceLastLapTime", 0)
		player:SetAttribute("RaceBestLapTime", 0)
		player:SetAttribute("RaceFinalTime", 0)
		raceStartTime = 0
		lapStartTime = 0
		resetOffTrackState(player)
		clearGateState()
	end

	local function beginCountdown(player: Player, now: number)
		local trackId = player:GetAttribute("SelectedTrackId")
		if type(trackId) ~= "string" or not bindTrackForRace(trackId) then
			kart:SetAttribute("RaceControlsLocked", true)
			player:SetAttribute("RaceEntryError", "Track unavailable")
			setRaceState(player, "GARAGE")
			return
		end
		kart:SetAttribute("RaceControlsLocked", true)
		resetKartToStart()
		resetRaceProgress(player)
		countdownEndTime = now + RaceConfig.COUNTDOWN_SECONDS
		lastCountdownValue = RaceConfig.COUNTDOWN_SECONDS
		player:SetAttribute("RaceCountdown", lastCountdownValue)
		setRaceState(player, "COUNTDOWN")
		print(string.format("[Race] countdown=%d", lastCountdownValue))
	end

	local function endActiveRace(player: Player)
		player:SetAttribute("RaceCountdown", 0)
		setRaceState(player, "GARAGE")
		kart:SetAttribute("RaceControlsLocked", true)
		countdownEndTime = 0
		raceStartTime = 0
		lapStartTime = 0
		resetOffTrackState(player)
		clearGateState()
	end

	local function invalidateCurrentLap(player: Player, now: number, reason: string)
		local completedLaps = (player:GetAttribute("RaceCompletedLaps") :: number?) or 0
		local previousNext = (player:GetAttribute("RaceNextCheckpoint") :: number?) or 1
		print(string.format(
			"[Race] lap invalidated reason=%s lap=%d completed=%d previousNext=%d x=%.1f z=%.1f",
			reason,
			math.min(completedLaps + 1, RaceConfig.TOTAL_LAPS),
			completedLaps,
			previousNext,
			chassis.Position.X,
			chassis.Position.Z
		))
		player:SetAttribute("RaceCurrentLap", math.min(completedLaps + 1, RaceConfig.TOTAL_LAPS))
		player:SetAttribute("RaceNextCheckpoint", 1)
		lapStartTime = now
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

	local function finishRace(player: Player, now: number, completedLaps: number)
		player:SetAttribute("RaceCompletedLaps", completedLaps)
		player:SetAttribute("RaceCurrentLap", RaceConfig.TOTAL_LAPS)
		player:SetAttribute("RaceNextCheckpoint", 1)
		player:SetAttribute("RaceCountdown", 0)
		local finalTime = now - raceStartTime
		player:SetAttribute("RaceFinalTime", finalTime)
		kart:SetAttribute("RaceControlsLocked", true)
		setRaceState(player, "FINISHED")
		resetOffTrackState(player)
		clearGateState()
		local bestLap = (player:GetAttribute("RaceBestLapTime") :: number?) or 0
		print(string.format("[Race] FINISHED total=%.2f best=%.2f", finalTime, bestLap))
	end

	local function completeLap(player: Player, now: number)
		local lapTime = now - lapStartTime
		if lapTime < minimumValidLapTime then
			invalidateCurrentLap(player, now, "lap_too_fast")
			return
		end

		local completedLaps = (player:GetAttribute("RaceCompletedLaps") :: number?) or 0
		completedLaps += 1
		local bestLap = (player:GetAttribute("RaceBestLapTime") :: number?) or 0

		player:SetAttribute("RaceCompletedLaps", completedLaps)
		player:SetAttribute("RaceNextCheckpoint", 1)
		player:SetAttribute("RaceLastLapTime", lapTime)
		if bestLap == 0 or lapTime < bestLap then
			player:SetAttribute("RaceBestLapTime", lapTime)
		end
		print(string.format("[Race] Lap %d complete: %.2fs", completedLaps, lapTime))

		if completedLaps >= RaceConfig.TOTAL_LAPS then
			finishRace(player, now, RaceConfig.TOTAL_LAPS)
		else
			player:SetAttribute("RaceCurrentLap", completedLaps + 1)
			lapStartTime = now
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
			end
		end
	end

	local function sampleRoadCorridor(player: Player, deltaTime: number)
		offTrackSampleElapsed += deltaTime
		local timeoutReached = offTrackElapsed > 0
			and offTrackElapsed + offTrackSampleElapsed >= RaceConfig.OFF_TRACK_TIMEOUT_SECONDS
		if offTrackSampleElapsed < RaceConfig.OFF_TRACK_SAMPLE_INTERVAL and not timeoutReached then
			return
		end

		local sampleElapsed = offTrackSampleElapsed
		offTrackSampleElapsed = 0
		if isInsideRoadCorridor(roadParts, chassis.Position) then
			if offTrackElapsed > 0 then
				print(string.format("[Race] back_on_track after=%.2fs lap=%d nextCheckpoint=%d", offTrackElapsed, (player:GetAttribute("RaceCurrentLap") :: number?) or 1, (player:GetAttribute("RaceNextCheckpoint") :: number?) or 1))
			end
			offTrackElapsed = 0
			kart:SetAttribute("KartOffTrack", false)
			player:SetAttribute("RaceOffTrackRemaining", 0)
			return
		end

		if offTrackElapsed == 0 then
			print(string.format("[Race] off_track lap=%d nextCheckpoint=%d x=%.1f z=%.1f", (player:GetAttribute("RaceCurrentLap") :: number?) or 1, (player:GetAttribute("RaceNextCheckpoint") :: number?) or 1, chassis.Position.X, chassis.Position.Z))
			kart:SetAttribute("KartOffTrack", true)
		end

		offTrackElapsed += sampleElapsed
		if offTrackElapsed >= RaceConfig.OFF_TRACK_TIMEOUT_SECONDS then
			endRaceOffTrack(player)
		else
			player:SetAttribute("RaceOffTrackRemaining", math.ceil(RaceConfig.OFF_TRACK_TIMEOUT_SECONDS - offTrackElapsed))
		end
	end

	raceRemote.OnServerEvent:Connect(function(player: Player, action: unknown)
		if player ~= activePlayer then
			return
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local state = player:GetAttribute("RaceState")
		if not humanoid or humanoid.SeatPart ~= seat or (state ~= "FINISHED" and state ~= "DNF") then
			return
		end
		if action == "ReturnGarage" then
			activePlayer = nil
			endActiveRace(player)
			return
		end
		if action ~= "Rematch" then
			return
		end

		print("[Race] rematch accepted")
		beginCountdown(player, time())
	end)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		local now = time()
		local occupant = seat.Occupant
		local occupantCharacter = occupant and occupant.Parent
		local occupantPlayer = if occupantCharacter and occupantCharacter:IsA("Model")
			then Players:GetPlayerFromCharacter(occupantCharacter)
			else nil
		if occupantPlayer ~= activePlayer then
			if activePlayer then
				endActiveRace(activePlayer)
			end
			activePlayer = occupantPlayer
			lastResetSerial = kart:GetAttribute("RaceResetSerial")
			if activePlayer and activePlayer:GetAttribute("RaceState") == "PRE_RACE" then
				beginCountdown(activePlayer, now)
			elseif activePlayer then
				activePlayer = nil
			end
		end

		local player = activePlayer
		if not player then
			return
		end

		local raceState = player:GetAttribute("RaceState")
		if raceState == "COUNTDOWN" then
			lastResetSerial = kart:GetAttribute("RaceResetSerial")
			local countdownValue = math.max(math.ceil(countdownEndTime - now), 0)
			if countdownValue ~= lastCountdownValue then
				lastCountdownValue = countdownValue
				player:SetAttribute("RaceCountdown", countdownValue)
				if countdownValue > 0 then
					print(string.format("[Race] countdown=%d", countdownValue))
				end
			end
			if countdownValue <= 0 then
				raceStartTime = now
				lapStartTime = now
				resetOffTrackState(player)
				clearGateState()
				setRaceState(player, "RACING")
				kart:SetAttribute("RaceControlsLocked", false)
			end
			return
		end

		local resetSerial = kart:GetAttribute("RaceResetSerial")
		if resetSerial ~= lastResetSerial then
			lastResetSerial = resetSerial
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

		local onRoadAtGate: boolean? = nil
		for _, gate in gates do
			local inside = isInsideGate(gate, chassis.Position)
			if inside and not insideGate[gate] then
				-- Check the actual corridor on entry, including between timed off-track samples.
				if onRoadAtGate == nil then
					onRoadAtGate = isInsideRoadCorridor(roadParts, chassis.Position)
				end
				if onRoadAtGate or (gate == startFinishGate
					and player:GetAttribute("RaceNextCheckpoint") == checkpointCount + 1) then
					processGate(player, gate, now)
				end
			end
			insideGate[gate] = inside
		end
	end)

	kart:SetAttribute("RaceControlsLocked", true)
	kart:SetAttribute("KartOffTrack", false)
	print(string.format("[Race] minimumValidLapTime=%.2f", minimumValidLapTime))
	print("[RobloxKart] Race controller ready")
end

return RaceController
