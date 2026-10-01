local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Workspace = game:GetService("Workspace")
local ActiveMatchDirectory = require(script.Parent:WaitForChild("ActiveMatchDirectory"))
local RoomSocialDirectory = require(script.Parent:WaitForChild("RoomSocialDirectory"))
local PrototypeWorld = require(script.Parent:WaitForChild("PrototypeWorld"))
local TrackCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrackCatalog"))

local RaceRoomCoordinator = {}

function RaceRoomCoordinator.start(payload)
	local directory = ActiveMatchDirectory.new(
		MemoryStoreService:GetSortedMap(ActiveMatchDirectory.MAP_NAME))
	local social = RoomSocialDirectory.new(
		MemoryStoreService:GetSortedMap(RoomSocialDirectory.PRESENCE_MAP),
		MemoryStoreService:GetHashMap(RoomSocialDirectory.INVITE_MAP))
	local roomId, matchId = payload.roomId, payload.matchId
	local remote = ReplicatedStorage:WaitForChild("GarageControl")
	local phase, racerCount = "WAITING", 0
	local hostUserId = payload.participantUserIds[1]
	local active = true
	local pendingInvites, sendingInvites = {}, {}

	local function snapshot()
		local record = directory:get(roomId)
		if not record or record.matchId ~= matchId then return end
		hostUserId = record.hostUserId
		local excluded = {}
		for _, member in record.stagedMembers do excluded[member.userId] = true end
		for _, member in record.currentRoundMembers do excluded[member.userId] = true end
		for _, member in record.queued do excluded[member.userId] = true end
		local available = {}
		for _, entry in social:list() do
			if not excluded[entry.userId] then table.insert(available, entry) end
		end
		local queued = {}
		for _, member in record.queued do
			table.insert(queued, { name = member.name,
				kind = if member.priority == 1 then "INVITED" elseif member.priority == 2 then "RIVAL" else "PUBLIC" })
		end
		local pending = {}
		for userId,cachedInvite in pendingInvites do
			local ok,invite=pcall(function() return social:getInvite(userId) end)
			if ok then
				if invite and invite.hostUserId==record.hostUserId and invite.roomId==roomId and not excluded[userId] then pending[tostring(userId)]=invite.expiresAt
				else pendingInvites[userId]=nil end
			elseif cachedInvite.expiresAt>os.time() and cachedInvite.hostUserId==record.hostUserId and not excluded[userId] then pending[tostring(userId)]=cachedInvite.expiresAt end
		end
		local safe = { roomId=roomId, pendingInvites=pending, hostUserId = record.hostUserId, hostName = record.hostName,
			state = record.state, count = record.currentRacers,
			maxPlayers = record.maxPlayers, queuedCount = #record.queued,
			queued = queued, available = available }
		for _, player in Players:GetPlayers() do remote:FireClient(player, "RoomSnapshot", safe) end
	end

	local function publish(newPhase, count)
		local ok, result = pcall(function()
			return directory:raceState(roomId, matchId, newPhase, count,
				game.PrivateServerId, game.JobId)
		end)
		if not ok then warn("[KDMRoom] publish failed: " .. tostring(result)) end
		if ok and result then phase, racerCount = newPhase, count end
		pcall(snapshot)
	end

	local function startRound(hostUserId, expectedCount)
		local ok, record = pcall(function()
			return directory:startRound(roomId, hostUserId, expectedCount)
		end)
		if not ok or not record then return false end
		phase, racerCount = "STARTING", record.currentRacers
		pcall(snapshot)
		return true
	end

	local function nextRound(players)
		publish("ROUND_COMPLETE", #players)
		local members = {}
		for _, player in players do
			if player.Parent == Players then
				table.insert(members, { userId = player.UserId, name = player.DisplayName,
					driverId = player:GetAttribute("SelectedDriverId"),
					kartId = player:GetAttribute("SelectedKartId") })
			end
		end
		local ok, record = pcall(function() return directory:nextStaging(roomId, members) end)
		if not ok then warn("[KDMRoom] staging failed: " .. tostring(record)); return false end
		if not record then
			pcall(function() directory:closeIfIdle(roomId, matchId) end)
			active = false
			return true
		end
		local prototype = Workspace:FindFirstChild("Prototype")
		local ground = Workspace:FindFirstChild("Baseplate") or (prototype and prototype:FindFirstChild("Ground"))
		local groundTop = if ground and ground:IsA("BasePart") then ground.Position.Y + ground.Size.Y * 0.5 else 0
		for index, member in record.stagedMembers do
			if member.arrived then
				local player = Players:GetPlayerByUserId(member.userId)
				local context = player and PrototypeWorld.getKartContext(player)
				if context then
					local slot = CFrame.new(0, groundTop + 1.75, 0)
						* TrackCatalog.Entries[payload.trackId].GridSlots[index]
					context:setSpawnCFrame(slot)
					context.kart:SetAttribute("RaceStartCFrame", slot)
					player:SetAttribute("GridSlot", index)
				end
			end
		end
		phase, racerCount = "WAITING", #members
		pcall(snapshot)
		return true
	end

	local function leave(userId)
		pcall(function() directory:leaveMember(roomId, userId) end)
		pcall(snapshot)
	end

	remote.OnServerEvent:Connect(function(player, action, targetUserId, requestId)
		if action ~= "Invite" or type(targetUserId) ~= "number" or targetUserId%1~=0 or targetUserId<=0 then return end
		if requestId ~= nil and (type(requestId) ~= "number" or requestId%1 ~= 0 or requestId <= 0) then return end
		local function fail() remote:FireClient(player,"InviteFailed",{targetUserId=targetUserId,requestId=requestId}) end
		local ok, record = pcall(function() return directory:get(roomId) end)
		if not ok or not record or record.matchId~=matchId or record.hostUserId ~= player.UserId then fail(); return end
		for _, collection in { record.stagedMembers, record.currentRoundMembers, record.queued } do
			for _, member in collection do if member.userId == targetUserId then fail(); return end end
		end
		local present, available = pcall(function() return social:list(player.UserId) end)
		if not present then fail(); return end
		for _, entry in available do
			if entry.userId == targetUserId then
				if sendingInvites[targetUserId] then return end
				sendingInvites[targetUserId]=true
				local sent,invite=pcall(function()
					local previous=social:getInvite(targetUserId)
					if previous and previous.hostUserId==player.UserId and previous.roomId==roomId then return previous end
					return social:sendInvite(targetUserId, record)
				end)
				sendingInvites[targetUserId]=nil
				if not sent or not invite then fail(); return end
				pendingInvites[targetUserId]=invite
				remote:FireClient(player,"InviteSent",{targetUserId=targetUserId,requestId=requestId,roomId=roomId,expiresAt=invite.expiresAt})
				return
			end
		end
		fail()
	end)

	task.spawn(function()
		while active do
			task.wait(5)
			local ok, record = pcall(function() return directory:get(roomId) end)
			if not ok then
				warn("[KDMRoom] heartbeat lookup failed: " .. tostring(record))
			elseif record and record.matchId == matchId then
				publish(phase, racerCount)
			else active = false end
		end
	end)

	return { onRoomPhase = publish, onRoundStart = startRound,
		getRoomHostUserId = function() return hostUserId end,
		onRoundReady = nextRound, onRoomLeave = leave }
end

return RaceRoomCoordinator
