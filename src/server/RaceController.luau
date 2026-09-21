local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RaceController = {}

local DIRECTION_THRESHOLD = 0.25
local MIN_GATE_SPEED = 1
local started = false

local function initializePlayerAttributes(player: Player, checkpointCount: number)
	player:SetAttribute("RaceCurrentLap", 1)
	player:SetAttribute("RaceCompletedLaps", 0)
	player:SetAttribute("RaceNextCheckpoint", 1)
	player:SetAttribute("RaceLastLapTime", 0)
	player:SetAttribute("RaceBestLapTime", 0)
	player:SetAttribute("RaceCheckpointCount", checkpointCount)
end

local function isInsideGate(gate: BasePart, worldPosition: Vector3): boolean
	local localPosition = gate.CFrame:PointToObjectSpace(worldPosition)
	local halfSize = gate.Size * 0.5
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
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
	local testTrack = prototype:WaitForChild("TestTrack")
	local raceTriggers = testTrack:WaitForChild("RaceTriggers")
	local checkpointCountAttribute = testTrack:GetAttribute("CheckpointCount")
	local checkpointCount = if type(checkpointCountAttribute) == "number" then checkpointCountAttribute else 0

	local gates: { BasePart } = {}
	local startFinish: BasePart? = nil
	local checkpoints: { [number]: BasePart } = {}
	for _, child in raceTriggers:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("RaceGate") == true then
			table.insert(gates, child)
			if child:GetAttribute("GateType") == "StartFinish" then
				startFinish = child
			elseif child:GetAttribute("GateType") == "Checkpoint" then
				local checkpointIndex = child:GetAttribute("CheckpointIndex")
				if type(checkpointIndex) == "number" then
					checkpoints[checkpointIndex] = child
				end
			end
		end
	end

	if not startFinish or checkpointCount < 1 then
		warn("[Race] Race triggers are incomplete")
		return
	end
	for checkpointIndex = 1, checkpointCount do
		if not checkpoints[checkpointIndex] then
			warn(string.format("[Race] Checkpoint %d is missing", checkpointIndex))
			return
		end
	end

	for _, player in Players:GetPlayers() do
		initializePlayerAttributes(player, checkpointCount)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		initializePlayerAttributes(player, checkpointCount)
	end)

	local activePlayer: Player? = nil
	local lapStartTime = 0
	local lastResetSerial = kart:GetAttribute("RaceResetSerial")
	local insideGate: { [BasePart]: boolean } = {}

	local function clearGateState()
		table.clear(insideGate)
	end

	local function resetProgress(player: Player, now: number, resetLapTimes: boolean)
		player:SetAttribute("RaceCurrentLap", 1)
		player:SetAttribute("RaceCompletedLaps", 0)
		player:SetAttribute("RaceNextCheckpoint", 1)
		player:SetAttribute("RaceCheckpointCount", checkpointCount)
		if resetLapTimes then
			player:SetAttribute("RaceLastLapTime", 0)
			player:SetAttribute("RaceBestLapTime", 0)
		end
		lapStartTime = now
		clearGateState()
	end

	local function completeLap(player: Player, now: number)
		local completedLaps = (player:GetAttribute("RaceCompletedLaps") :: number?) or 0
		completedLaps += 1
		local lapTime = now - lapStartTime
		local bestLap = (player:GetAttribute("RaceBestLapTime") :: number?) or 0

		player:SetAttribute("RaceCompletedLaps", completedLaps)
		player:SetAttribute("RaceCurrentLap", completedLaps + 1)
		player:SetAttribute("RaceNextCheckpoint", 1)
		player:SetAttribute("RaceLastLapTime", lapTime)
		if bestLap == 0 or lapTime < bestLap then
			player:SetAttribute("RaceBestLapTime", lapTime)
		end
		lapStartTime = now
		print(string.format("[Race] Lap %d complete: %.2fs", completedLaps, lapTime))
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
			end
		elseif gateType == "StartFinish" and gate == startFinish and nextCheckpoint == checkpointCount + 1 then
			completeLap(player, now)
		end
	end

	RunService.Heartbeat:Connect(function()
		local now = time()
		local occupant = seat.Occupant
		local occupantCharacter = occupant and occupant.Parent
		local occupantPlayer = if occupantCharacter and occupantCharacter:IsA("Model")
			then Players:GetPlayerFromCharacter(occupantCharacter)
			else nil
		if occupantPlayer ~= activePlayer then
			activePlayer = occupantPlayer
			clearGateState()
			if activePlayer then
				lastResetSerial = kart:GetAttribute("RaceResetSerial")
				resetProgress(activePlayer, now, true)
			end
		end

		local resetSerial = kart:GetAttribute("RaceResetSerial")
		if resetSerial ~= lastResetSerial then
			lastResetSerial = resetSerial
			if activePlayer then
				resetProgress(activePlayer, now, false)
				print("[Race] Progress reset after kart recovery")
			end
		end

		local player = activePlayer
		if not player then
			return
		end

		for _, gate in gates do
			local inside = isInsideGate(gate, chassis.Position)
			if inside and not insideGate[gate] then
				processGate(player, gate, now)
			end
			insideGate[gate] = inside
		end
	end)

	print("[RobloxKart] Race controller ready")
end

return RaceController
