local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Workspace = game:GetService("Workspace")
local ActiveMatchDirectory = require(script.Parent:WaitForChild("ActiveMatchDirectory"))
local RoomSocialDirectory = require(script.Parent:WaitForChild("RoomSocialDirectory"))
local PrototypeWorld = require(script.Parent:WaitForChild("PrototypeWorld"))
local RaceBotController = require(script.Parent:WaitForChild("RaceBotController"))
local RaceController = require(script.Parent:WaitForChild("RaceController"))
local RaceSession = require(script.Parent:WaitForChild("RaceSession"))
local RaceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaceConfig"))
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
	local botActionBusy, botActionAt = false, -math.huge
	local connections = {}
	local function clearBot()
		RaceBotController.removeProductionBot("Bot01")
		pcall(function() directory:clearBots(roomId, game.JobId) end)
	end
	local function stop()
		if not active then return end
		active = false
		for _, connection in connections do connection:Disconnect() end
		clearBot()
	end
	local function botSpawnFrame()
		local prototype = Workspace:FindFirstChild("Prototype")
		local ground = Workspace:FindFirstChild("Baseplate") or (prototype and prototype:FindFirstChild("Ground"))
		local groundTop = if ground and ground:IsA("BasePart") then ground.Position.Y + ground.Size.Y * .5 else 0
		local track = TrackCatalog.Entries[payload.trackId]
		return CFrame.new(0, groundTop + 1.75, 0) * track.GridSlots[track.MaxPlayers]
	end

	local function snapshot()
		local record = directory:get(roomId)
		if not record or record.matchId ~= matchId or record.state == "CLOSING" then stop(); return end
		local bots = if record.state == "WAITING" then record.stagedBots else record.currentRoundBots
		if #(bots or {}) > 0 and not botActionBusy and not RaceBotController.hasProductionBot("Bot01") then
			directory:clearBots(roomId, game.JobId)
			record = directory:get(roomId)
			if not record then stop(); return end
		end
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
		safe.activeBots = {}
		for _, bot in (if record.state == "WAITING" then record.stagedBots else record.currentRoundBots) or {} do
			table.insert(safe.activeBots, {botId=bot.botId, name=bot.name})
		end
		safe.botCandidates = if RaceConfig.INVITEABLE_BOT_ENABLED and record.trackId == "Track01Race" then {
			{botId="Bot01", name="KDM Rookie [BOT]", available=record.state == "WAITING"
				and #safe.activeBots == 0 and (#record.stagedMembers + #(record.stagedBots or {})) < record.maxPlayers}
		} else {}
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
		if botActionBusy then return false end
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
			if player:GetAttribute("IsBot") ~= true and player.Parent == Players then
				table.insert(members, { userId = player.UserId, name = player.DisplayName,
					driverId = player:GetAttribute("SelectedDriverId"),
					kartId = player:GetAttribute("SelectedKartId") })
			end
		end
		local ok, record = pcall(function() return directory:nextStaging(roomId, members) end)
		if not ok then warn("[KDMRoom] staging failed: " .. tostring(record)); return false end
		if not record then
			pcall(function() directory:closeIfIdle(roomId, matchId) end)
			stop()
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
		if #(record.stagedBots or {}) > 0 then RaceBotController.setProductionSpawn(botSpawnFrame())
		else RaceBotController.removeProductionBot("Bot01") end
		phase, racerCount = "WAITING", record.currentRacers
		pcall(snapshot)
		return true
	end

	local function leave(userId)
		pcall(function() directory:leaveMember(roomId, userId) end)
		local session = RaceSession.active()
		if not session or session:humanCount() == 0 then
			pcall(function() directory:remove(roomId) end)
			stop()
		end
		pcall(snapshot)
	end

	local function botAction(player, action, botId)
		if botId ~= "Bot01" or not active or botActionBusy or time()-botActionAt < .75
			or not RaceConfig.INVITEABLE_BOT_ENABLED or RaceConfig.MAX_BOTS_PER_ROOM < 1
			or Workspace:GetAttribute("KDMServerRole") ~= "RACE" then return false end
		local session = RaceSession.active()
		if not session or session.phase ~= "WAITING" or not session:contains(player)
			or RaceController.isRosterLocked() then return false end
		botActionBusy = true
		local ok, accepted = pcall(function()
			local record = directory:get(roomId)
			if not record or record.matchId ~= matchId or record.state ~= "WAITING"
				or record.hostUserId ~= player.UserId or record.raceJobId ~= game.JobId
				or record.privateServerId ~= game.PrivateServerId or record.trackId ~= payload.trackId
				or record.maxPlayers ~= TrackCatalog.Entries[payload.trackId].MaxPlayers then return false end
			botActionAt = time()
			if action == "RemoveBot" then
				if not directory:removeBot(roomId, botId) then return false end
				RaceBotController.removeProductionBot(botId)
				return true
			end
			if session:count() >= session.maxPlayers or RaceBotController.hasProductionBot(botId) then return false end
			local descriptor = {botId="Bot01", name="KDM Rookie [BOT]", kartId="Kart01", gridSlot=record.maxPlayers}
			if not directory:addBot(roomId, descriptor) then return false end
			local spawned, result = pcall(function()
				return RaceBotController.addProductionBot({roomId=roomId, trackId=record.trackId,
					gridSlot=record.maxPlayers, spawnCFrame=botSpawnFrame(), canAdmit=function()
						local current = directory:get(roomId)
						return active and current and current.matchId == matchId and current.state == "WAITING"
							and current.raceJobId == game.JobId and #(current.stagedBots or {}) == 1
					end, onLost=function()
						local currentSession = RaceSession.active()
						if not currentSession or currentSession:humanCount() == 0 then
							pcall(function() directory:remove(roomId) end)
							stop();return
						end
						pcall(function() directory:clearBots(roomId, game.JobId) end)
						pcall(snapshot)
					end})
			end)
			if not spawned or not result then
				RaceBotController.removeProductionBot(botId)
				directory:removeBot(roomId, botId)
				return false
			end
			return true
		end)
		botActionBusy = false
		pcall(snapshot)
		return ok and accepted == true
	end

	local remoteConnection = remote.OnServerEvent:Connect(function(player, action, targetUserId, requestId, ...)
		if action == "AddBot" or action == "RemoveBot" then
			if requestId ~= nil or select("#",...) > 0 then return end
			local accepted = botAction(player, action, targetUserId)
			remote:FireClient(player, "BotActionResult", {accepted=accepted})
			return
		end
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
	if remoteConnection then table.insert(connections, remoteConnection) end
	if game.BindToClose then game:BindToClose(stop) end

	task.spawn(function()
		while active do
			task.wait(5)
			local ok, record = pcall(function() return directory:get(roomId) end)
			if not ok then
				warn("[KDMRoom] heartbeat lookup failed: " .. tostring(record))
			elseif record and record.matchId == matchId then
				publish(phase, racerCount)
			else stop() end
		end
	end)

	return { onRoomPhase = publish, onRoundStart = startRound,
		getRoomHostUserId = function() return hostUserId end,
		onRoundReady = nextRound, onRoomLeave = leave, stop = stop }
end

return RaceRoomCoordinator
