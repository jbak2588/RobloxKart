local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackCatalog = require(Shared:WaitForChild("TrackCatalog"))
local DriverCatalog = require(Shared:WaitForChild("DriverCatalog"))
local KartCatalog = require(Shared:WaitForChild("KartCatalog"))
local DriverAppearance = require(Shared:WaitForChild("DriverAppearance"))
local KartVisualFactory = require(Shared:WaitForChild("KartVisualFactory"))
local RaceLaunchPayload = require(script.Parent:WaitForChild("RaceLaunchPayload"))
local RaceArrivalPlan = require(script.Parent:WaitForChild("RaceArrivalPlan"))
local RaceLaunchService = require(script.Parent:WaitForChild("RaceLaunchService"))
local ActiveMatchDirectory = require(script.Parent:WaitForChild("ActiveMatchDirectory"))
local RaceController = require(script.Parent:WaitForChild("RaceController"))
local PrototypeWorld = require(script.Parent:WaitForChild("PrototypeWorld"))

local RaceServerBootstrap = {}
local started = false
local activeMatchId = nil

function RaceServerBootstrap.plan(payload, userId)
	return RaceArrivalPlan.forPlayer(payload, userId)
end

function RaceServerBootstrap.checkArrival(payload, player, initialPlayer, gameId)
	local listed = false
	for _, userId in payload.participantUserIds do
		if userId == player.UserId then listed = true; break end
	end
	if not listed then return nil, "USER_NOT_PARTICIPANT" end
	local plan = RaceArrivalPlan.forPlayer(payload, player.UserId)
	if not plan then return nil, "ARRIVAL_PLAN_INVALID" end
	if player == initialPlayer then return plan end

	-- Only later arrivals need another join-data check. The first player's data
	-- was already accepted by ServerRuntime.resolve at server startup.
	local ok, joinData = pcall(function() return player:GetJoinData() end)
	if not ok or type(joinData) ~= "table" then return nil, "JOIN_DATA_UNAVAILABLE" end
	if joinData.SourceGameId ~= gameId then return nil, "WRONG_SOURCE_GAME" end
	local arrivalPayload = joinData.TeleportData
	if type(arrivalPayload) ~= "table" or arrivalPayload.matchId ~= payload.matchId
		or arrivalPayload.trackId ~= payload.trackId
		or arrivalPayload.roomId ~= payload.roomId then
		return nil, "MATCH_ID_MISMATCH"
	end
	local arrivalPlan = RaceArrivalPlan.forPlayer(arrivalPayload, player.UserId)
	if not arrivalPlan or arrivalPlan.trackId ~= plan.trackId or arrivalPlan.gridSlot ~= plan.gridSlot
		or arrivalPlan.driverId ~= plan.driverId or arrivalPlan.kartId ~= plan.kartId then
		return nil, "ARRIVAL_PLAN_INVALID"
	end
	return plan
end

function RaceServerBootstrap.roomPlan(payload, arrivalPayload, record, userId, privateServerId, raceJobId)
	if not RaceLaunchPayload.validate(arrivalPayload, false)
		or arrivalPayload.trackId ~= payload.trackId
		or arrivalPayload.roomId ~= payload.roomId or arrivalPayload.matchId ~= payload.matchId
		or #arrivalPayload.participantUserIds ~= 1
		or arrivalPayload.participantUserIds[1] ~= userId
		or type(record) ~= "table" or (record.state ~= "WAITING"and not(record.quickMatch and record.quickWarmup and record.state=='RACING'))
		or record.trackId ~= payload.trackId
		or record.maxPlayers ~= TrackCatalog.Entries[payload.trackId].MaxPlayers
		or #(record.stagedMembers or {}) + #(record.stagedBots or {}) > TrackCatalog.Entries[payload.trackId].MaxPlayers
		or record.roomId ~= payload.roomId or record.matchId ~= payload.matchId
		or record.privateServerId ~= privateServerId
		or (record.raceJobId ~= "" and record.raceJobId ~= raceJobId
			and record.currentRacers > 0) then return nil end
	local token = arrivalPayload.admissionToken
	if type(token) ~= "string" or #token < 8 then return nil end
	local incoming=record.quickWarmup and record.state=='RACING'
	if incoming and (#(record.currentRoundMembers or {})~=1 or #(record.pendingArrivals or {})+1>record.maxPlayers)then return nil end
	for index, member in (if incoming then record.pendingArrivals else record.stagedMembers)or {} do
		if member.userId == userId and member.admissionToken == token
			and type(member.admissionExpiresAt) == "number"
			and member.admissionExpiresAt > os.time()
			and member.driverId == arrivalPayload.selections[tostring(userId)].driverId
			and member.kartId == arrivalPayload.selections[tostring(userId)].kartId then
			local plan = RaceArrivalPlan.forPlayer(arrivalPayload, userId)
			if not plan then return nil end
			plan.rewardNextMultiplier=member.rewardNextMultiplier
			plan.gridSlot = index+(if incoming then #record.currentRoundMembers else 0)
			plan.readyOrder = plan.gridSlot
			return plan
		end
	end
	return nil
end

function RaceServerBootstrap.start(payload, initialPlayer, initialJoinData)
	if started then return type(payload) == "table" and payload.matchId == activeMatchId end
	if not RaceLaunchPayload.validate(payload, false) or not initialPlayer
		or type(initialJoinData) ~= "table" then return false end
	started = true
	activeMatchId = payload.matchId
	local processed = {}
	local arrivalSerial = 0
	local roomDirectory = if payload.roomId then ActiveMatchDirectory.new(
		MemoryStoreService:GetSortedMap(ActiveMatchDirectory.MAP_NAME)) else nil
	local track = TrackCatalog.Entries[payload.trackId]
	if not track or not track.GridSlots or not track.GridSlots[#payload.participantUserIds] then
		warn(string.format("[KDMRoute] race bootstrap reject user=%d reason=TRACK_INVALID match=%s",
			initialPlayer.UserId, payload.matchId))
		return false
	end
	local prototype = Workspace:WaitForChild("Prototype")
	local ground = Workspace:FindFirstChild("Baseplate") or prototype:FindFirstChild("Ground")
	local groundTop = if ground and ground:IsA("BasePart") then ground.Position.Y + ground.Size.Y * 0.5 else 0

	local function reject(player, reason)
		warn(string.format("[KDMRoute] race bootstrap reject user=%d reason=%s match=%s",
			player.UserId, reason, payload.matchId))
		PrototypeWorld.releaseKartContext(player)
		if roomDirectory then
			pcall(function() roomDirectory:removeStaged(payload.roomId, player.UserId) end)
		end
		player:SetAttribute("RaceEntryError", "RACE SERVER UNAVAILABLE - RETURNING TO HUB")
		if not RaceLaunchService.returnToHub(player, function()
			if player.Parent == Players then
				player:Kick("Race launch unavailable. Please rejoin Kart Drift Masters.")
			end
		end) then return end
	end

	local function arrive(player)
		if processed[player] then return end
		processed[player] = true
		-- Capture server entry order before storage/character waits can reorder it.
		arrivalSerial += 1
		local arrivalOrder = arrivalSerial
		local plan, reason
		local admissionToken
		if roomDirectory then
			local ok, joinData = pcall(function() return player:GetJoinData() end)
			local arrivalPayload = if ok and type(joinData) == "table" then joinData.TeleportData else nil
			if not ok or type(joinData) ~= "table" or joinData.SourceGameId ~= game.GameId
				or type(arrivalPayload) ~= "table" then
				reject(player, "ROOM_PAYLOAD_INVALID"); return
			end
			admissionToken = arrivalPayload.admissionToken
			local found, record = pcall(function() return roomDirectory:get(payload.roomId) end)
			if not found or not record then
				reject(player, "ROOM_UNAVAILABLE"); return
			end
			plan = RaceServerBootstrap.roomPlan(payload, arrivalPayload, record,
				player.UserId, game.PrivateServerId, game.JobId)
			if not plan then reject(player, "ROOM_ADMISSION_INVALID"); return end
		else
			plan, reason = RaceServerBootstrap.checkArrival(payload, player, initialPlayer, game.GameId)
		end
		if not plan then reject(player, reason); return end
		print(string.format("[KDMRoute] arrival user=%d", player.UserId))
		local character = player.Character
		local characterDeadline = os.clock() + 10
		while not character and player.Parent == Players and os.clock() < characterDeadline do
			task.wait(0.1)
			character = player.Character
		end
		if not player.Parent then return end
		if not character then reject(player, "CHARACTER_TIMEOUT"); return end
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then reject(player, "CHARACTER_TIMEOUT"); return end
		root.Anchored = true
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or humanoid.Health <= 0 then reject(player, "HUMANOID_INVALID"); return end
		-- Server-side seat protection before admission waits or seat:Sit().
		-- State enablement is process-local, so ReplicatedFirst also locks the client.
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoJumpEnabled = false
		humanoid.Jump = false
		if roomDirectory then
			RaceController.prepareQuickArrival(player,admissionToken)
			local deadline=os.clock()+10
			while RaceController.isRosterLocked()and player.Parent==Players and os.clock()<deadline do task.wait(.1)end
		end
		if RaceController.isRosterLocked()then reject(player,'LATE_RACE_ARRIVAL');return end
		if roomDirectory then
			local refreshed,record=pcall(function()return roomDirectory:get(payload.roomId)end)
			plan=refreshed and RaceServerBootstrap.roomPlan(payload,player:GetJoinData().TeleportData,record,player.UserId,game.PrivateServerId,game.JobId)
			if not plan then reject(player,'ROOM_ADMISSION_CHANGED');return end
		end
		local spawnCFrame = CFrame.new(0, groundTop + 1.75, 0) * track.GridSlots[plan.gridSlot]
		local context = PrototypeWorld.acquireKartContext(player, spawnCFrame, plan.kartId)
		if not context then reject(player, "KART_CONTEXT_FAILED"); return end
		local seat, kart = context.seat, context.kart
		if seat.Occupant then reject(player, "SEAT_OCCUPIED"); return end
		player:SetAttribute("SelectedDriverId", plan.driverId)
		player:SetAttribute("SelectedKartId", plan.kartId)
		player:SetAttribute("SelectedTrackId", plan.trackId)
		player:SetAttribute("RaceMaxPlayers", plan.maxPlayers)
		player:SetAttribute("RaceMode", plan.mode)
		player:SetAttribute("GridSlot", plan.gridSlot)
		player:SetAttribute("ReadyOrder", plan.readyOrder)
		player:SetAttribute("RaceArrivalOrder", arrivalOrder)
		player:SetAttribute("RaceEntryError", "")
		DriverAppearance.applyToCharacter(character, DriverCatalog.Entries[plan.driverId])
		local visual = kart:FindFirstChild("Visual")
		if visual and visual:IsA("Model") then
			KartVisualFactory.applyAppearance(visual, KartCatalog.Entries[plan.kartId])
		end
		context:setSpawnCFrame(spawnCFrame)
		kart:PivotTo(spawnCFrame)
		root.Anchored = false
		character:PivotTo(seat.CFrame * CFrame.new(0, 2.5, 0))
		seat:Sit(humanoid)
		print(string.format("[KDMRoute] seat requested user=%d match=%s", player.UserId, payload.matchId))
		local seatDeadline = os.clock() + 2.5
		while player.Parent == Players and (seat.Occupant ~= humanoid or humanoid.SeatPart ~= seat)
			and os.clock() < seatDeadline do
			task.wait(0.1)
		end
		if player.Parent ~= Players then return end
		if seat.Occupant ~= humanoid or humanoid.SeatPart ~= seat then
			warn(string.format("[KDMRoute] seat result user=%d occupant=%s seatPart=%s",
				player.UserId, tostring(seat.Occupant == humanoid), tostring(humanoid.SeatPart == seat)))
			reject(player, "SEAT_TIMEOUT")
			return
		end
		print(string.format("[KDMRoute] seat confirmed user=%d match=%s", player.UserId, payload.matchId))
		if RaceController.isRosterLocked() then reject(player, "LATE_RACE_ARRIVAL"); return end
		if roomDirectory then
			local confirmed, record = pcall(function()
				return roomDirectory:confirmArrival(payload.roomId, player.UserId, admissionToken, game.JobId)
			end)
			if not confirmed or not record then reject(player, "ROOM_ADMISSION_EXPIRED"); return end
		end
		local session=require(script.Parent:WaitForChild('RaceSession')).active()
        if session and session.seedRewardContinuation then session:seedRewardContinuation(player,plan.rewardNextMultiplier) end
        player:SetAttribute("RaceState", "PRE_RACE")
	end
	local function safeArrive(player)
		local ok, reason = pcall(arrive, player)
		if not ok then
			warn("[KDMRoute] arrival setup failed: " .. tostring(reason))
			reject(player, "SETUP_EXCEPTION")
		end
	end

	for _, player in Players:GetPlayers() do task.spawn(safeArrive, player) end
	Players.PlayerAdded:Connect(function(player) task.spawn(safeArrive, player) end)
	Players.PlayerRemoving:Connect(function(player) processed[player] = nil end)
	return true
end

return RaceServerBootstrap
