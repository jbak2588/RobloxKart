local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackCatalog = require(Shared:WaitForChild("TrackCatalog"))
local DriverCatalog = require(Shared:WaitForChild("DriverCatalog"))
local KartCatalog = require(Shared:WaitForChild("KartCatalog"))
local ActiveMatchDirectory = require(script.Parent:WaitForChild("ActiveMatchDirectory"))
local RaceLaunchPayload = require(script.Parent:WaitForChild("RaceLaunchPayload"))
local RaceLaunchService = require(script.Parent:WaitForChild("RaceLaunchService"))

local MatchRoomService = {}
local TRACK_ID = "Track01Race"
local track = TrackCatalog.Entries[TRACK_ID]
local directory = ActiveMatchDirectory.new(MemoryStoreService:GetSortedMap(ActiveMatchDirectory.MAP_NAME))
local browsing, selections, invitations, membership, launched = {}, {}, {}, {}, {}
local cachedRooms = {}
local remote
local started = false
local starting = {}
local startingQueue = {}

local function eligible(player)
	return player and player.Parent == Players and player:GetAttribute("RaceState") == "GARAGE"
		and player:GetAttribute("KDMRoutePending") ~= "RACE_LAUNCH"
end

local function choose(player, driverId, kartId)
	if type(driverId) ~= "string" or type(kartId) ~= "string"
		or not DriverCatalog.Entries[driverId] or not KartCatalog.Entries[kartId] then return false end
	selections[player.UserId] = { driverId = driverId, kartId = kartId }
	return true
end

local function findCached(roomId)
	for _, record in cachedRooms do if record.roomId == roomId then return record end end
end

local function snapshotFor(player)
	local own = membership[player.UserId]
	local rooms = {}
	for _, record in cachedRooms do table.insert(rooms, directory:display(record)) end
	local ownRoom
	if own then
		local record = findCached(own.roomId)
		if record then
			ownRoom = directory:display(record)
			ownRoom.members = {}
			ownRoom.available = {}
			ownRoom.membershipKind = own.kind
			for _, member in record.waitingMembers or {} do
				table.insert(ownRoom.members, { userId = member.userId, name = member.name })
			end
			if own.kind == "QUEUED" then
				for index, member in record.queued or {} do
					if member.userId == player.UserId then ownRoom.queuePosition = index; break end
				end
				if not ownRoom.queuePosition then
					for _, member in record.launchRoster or {} do
						if member.userId == player.UserId then ownRoom.nextRoundStarting = true; break end
					end
				end
			elseif record.hostUserId == player.UserId and record.state == "WAITING" then
				for _, other in Players:GetPlayers() do
					if other ~= player and eligible(other) and not membership[other.UserId] then
						table.insert(ownRoom.available, { userId = other.UserId, name = other.DisplayName })
					end
				end
			end
		end
	end
	return { visible = browsing[player.UserId] == true or ownRoom ~= nil,
		rooms = rooms, room = ownRoom }
end

local function broadcast()
	for _, player in Players:GetPlayers() do remote:FireClient(player, "Snapshot", snapshotFor(player)) end
end

local function refresh()
	local ok, records = pcall(function() return directory:list() end)
	if ok then
		cachedRooms = records
		for userId, own in membership do
			if not findCached(own.roomId) then
				membership[userId] = nil
				launched[userId] = nil
				local player = Players:GetPlayerByUserId(userId)
				if player then remote:FireClient(player, "Error", "ROOM EXPIRED - PLEASE CHOOSE ANOTHER") end
			end
		end
		broadcast()
	else warn("[KDMRoom] directory listing failed: " .. tostring(records)) end
	return ok
end

local function errorTo(player, message)
	if player and player.Parent == Players then remote:FireClient(player, "Error", message) end
end

local function memberFor(player)
	local selected = selections[player.UserId]
	return { userId = player.UserId, name = player.DisplayName,
		driverId = selected.driverId, kartId = selected.kartId,
		hubJobId = game.JobId, queuedAt = os.time() }
end

local function launchLocal(record)
	if record.state ~= "STARTING" or type(record.launchRoster) ~= "table"
		or type(record.reservedServerAccessCode) ~= "string"
		or record.reservedServerAccessCode == "" then return end
	local payload = RaceLaunchPayload.buildMatch(record.matchId, record.roomId,
		record.launchRoster, TRACK_ID)
	if not payload then return end
	local group = {}
	for _, member in record.launchRoster do
		local player = Players:GetPlayerByUserId(member.userId)
		if player and eligible(player) and membership[player.UserId]
			and membership[player.UserId].roomId == record.roomId
			and launched[player.UserId] ~= record.matchId then
			launched[player.UserId] = record.matchId
			table.insert(group, player)
		end
	end
	if #group == 0 then return end
	local requestInFlight = true
	local earlyFailures = {}
	local function requeueFailed(player)
		launched[player.UserId] = nil
		membership[player.UserId] = { roomId = record.roomId, kind = "QUEUED" }
		pcall(function() directory:queue(record.roomId, memberFor(player)) end)
		browsing[player.UserId] = true
		refresh()
	end
	local ok = RaceLaunchService.launchMatch(group, payload, function(player)
		if requestInFlight then earlyFailures[player] = true
		else requeueFailed(player) end
	end, record.reservedServerAccessCode)
	requestInFlight = false
	if not ok then
		local allLocalInitial = record.roundId == 1 and #group == #record.launchRoster
		if allLocalInitial then
			local rolledBack, restored = pcall(function()
				return directory:launchFailed(record.roomId, record.matchId)
			end)
			if rolledBack and restored then
				for _, player in group do
					membership[player.UserId] = { roomId = record.roomId, kind = "WAITING" }
					launched[player.UserId] = nil
				end
				refresh()
				for _, player in group do errorTo(player, "RACE SERVER UNAVAILABLE - PLEASE TRY AGAIN") end
				return false
			end
		end
		for player in earlyFailures do requeueFailed(player) end
		for _, player in group do
			launched[player.UserId] = nil
			errorTo(player, "RACE SERVER UNAVAILABLE - PLEASE TRY AGAIN")
		end
	else
		for player in earlyFailures do requeueFailed(player) end
	end
	return ok
end

local function startRoom(player)
	if not player or starting[player.UserId] then return end
	local own = membership[player.UserId]
	if not own or own.kind ~= "WAITING" then return end
	starting[player.UserId] = true
	local ok, record = pcall(function() return directory:get(own.roomId) end)
	if not ok or not record or record.state ~= "WAITING"
		or record.hostUserId ~= player.UserId then
		starting[player.UserId] = nil
		return
	end
	local reserved, accessCode, privateServerId = pcall(function()
		return TeleportService:ReserveServerAsync(game.PlaceId)
	end)
	if not reserved or type(accessCode) ~= "string" or accessCode == "" then
		starting[player.UserId] = nil
		errorTo(player, "RACE SERVER UNAVAILABLE - PLEASE TRY AGAIN")
		return
	end
	local matchId = HttpService:GenerateGUID(false)
	local claimed, nextRecord = pcall(function()
		return directory:initialLaunch(record.roomId, player.UserId, matchId,
			accessCode, privateServerId)
	end)
	starting[player.UserId] = nil
	if not claimed or not nextRecord then
		errorTo(player, "ROOM UNAVAILABLE")
		return
	end
	refresh()
	launchLocal(nextRecord)
end

local function recoverQueuedRound(record)
	if startingQueue[record.roomId] or #record.queued == 0
		or record.queued[1].hubJobId ~= game.JobId then return end
	startingQueue[record.roomId] = true
	local reserved, accessCode, privateServerId = pcall(function()
		return TeleportService:ReserveServerAsync(game.PlaceId)
	end)
	if reserved and type(accessCode) == "string" and accessCode ~= "" then
		local matchId = HttpService:GenerateGUID(false)
		local claimed, nextRecord = pcall(function()
			return directory:claimNext(record.roomId, record.matchId, matchId,
				accessCode, privateServerId, {})
		end)
		if claimed and nextRecord then
			refresh()
			launchLocal(nextRecord)
		end
	end
	startingQueue[record.roomId] = nil
end

function MatchRoomService.openBrowser(player, driverId, kartId)
	if not eligible(player) or not choose(player, driverId, kartId) then return false end
	browsing[player.UserId] = true
	refresh()
	return true
end

function MatchRoomService.start()
	if started then return end
	started = true
	remote = Instance.new("RemoteEvent")
	remote.Name = "MatchRoomControl"
	remote.Parent = ReplicatedStorage
	remote.OnServerEvent:Connect(function(player, action, first, second)
		local own = membership[player.UserId]
		if action == "Browse" then
			MatchRoomService.openBrowser(player, first, second)
		elseif action == "Back" then
			if not own then browsing[player.UserId] = nil; broadcast() end
		elseif action == "Create" then
			if not eligible(player) or own or not selections[player.UserId] then return end
			local roomId = HttpService:GenerateGUID(false)
			local member = memberFor(player)
			local ok = pcall(function()
				directory:create({ id = roomId, trackId = TRACK_ID,
					hostUserId = player.UserId, hostName = player.DisplayName,
					ownerJobId = game.JobId, maxPlayers = track.MaxPlayers,
					members = { member } })
			end)
			if not ok then errorTo(player, "ROOM UNAVAILABLE"); return end
			membership[player.UserId] = { roomId = roomId, kind = "WAITING" }
			refresh()
		elseif action == "Join" and type(first) == "string" then
			if not eligible(player) or own or not selections[player.UserId] then return end
			local ok, record = pcall(function() return directory:joinWaiting(first, memberFor(player)) end)
			if not ok or not record then errorTo(player, "ROOM UNAVAILABLE"); return end
			membership[player.UserId] = { roomId = first, kind = "WAITING" }
			refresh()
			if #record.waitingMembers == record.maxPlayers then
				local host = Players:GetPlayerByUserId(record.hostUserId)
				if host then startRoom(host) end
			end
		elseif action == "Queue" and type(first) == "string" then
			if not eligible(player) or own or not selections[player.UserId] then return end
			local ok, record = pcall(function() return directory:queue(first, memberFor(player)) end)
			if not ok or not record then errorTo(player, "QUEUE UNAVAILABLE"); return end
			membership[player.UserId] = { roomId = first, kind = "QUEUED" }
			refresh()
		elseif action == "CancelQueue" then
			if not own or own.kind ~= "QUEUED" then return end
			local ok, removed = pcall(function() return directory:cancelQueue(own.roomId, player.UserId) end)
			if not ok or not removed then return end
			membership[player.UserId] = nil
			refresh()
		elseif action == "Leave" then
			if not own or own.kind ~= "WAITING" then return end
			pcall(function() directory:leaveWaiting(own.roomId, player.UserId) end)
			membership[player.UserId] = nil
			refresh()
		elseif action == "Start" then
			startRoom(player)
		elseif action == "Invite" and type(first) == "number" then
			if not own or own.kind ~= "WAITING" then return end
			local target = Players:GetPlayerByUserId(first)
			local ok, record = pcall(function() return directory:get(own.roomId) end)
			if not ok or not record or record.state ~= "WAITING" or record.hostUserId ~= player.UserId
				or record.currentRacers >= record.maxPlayers or not eligible(target)
				or membership[first] then return end
			invitations[first] = { roomId = record.roomId, hostUserId = player.UserId,
				sentAt = os.clock() }
			remote:FireClient(target, "Invite", { roomId = record.roomId,
				hostUserId = player.UserId, hostName = player.DisplayName,
				trackId = TRACK_ID, count = record.currentRacers, maxPlayers = record.maxPlayers })
		elseif action == "AcceptInvite" then
			local invite = invitations[player.UserId]
			invitations[player.UserId] = nil
			if not invite or os.clock() - invite.sentAt > 30 or own
				or not eligible(player) or not choose(player, first, second) then
				errorTo(player, "INVITE EXPIRED"); return
			end
			local ok, record = pcall(function() return directory:get(invite.roomId) end)
			if not ok or not record or record.hostUserId ~= invite.hostUserId
				or record.state ~= "WAITING" then errorTo(player, "INVITE EXPIRED"); return end
			local joined, updated = pcall(function()
				return directory:joinWaiting(invite.roomId, memberFor(player))
			end)
			if not joined or not updated then errorTo(player, "INVITE EXPIRED"); return end
			membership[player.UserId] = { roomId = invite.roomId, kind = "WAITING" }
			browsing[player.UserId] = true
			refresh()
			if #updated.waitingMembers == updated.maxPlayers then
				local host = Players:GetPlayerByUserId(updated.hostUserId)
				if host then startRoom(host) end
			end
		elseif action == "DeclineInvite" then
			invitations[player.UserId] = nil
		end
	end)
	local function watchPlayer(player)
		player:GetAttributeChangedSignal("RaceState"):Connect(broadcast)
	end
	for _, player in Players:GetPlayers() do watchPlayer(player) end
	Players.PlayerAdded:Connect(function(player) watchPlayer(player); broadcast() end)
	Players.PlayerRemoving:Connect(function(player)
		local own = membership[player.UserId]
		if own then
			if own.kind == "WAITING" then
				pcall(function() directory:leaveWaiting(own.roomId, player.UserId) end)
			elseif own.kind == "QUEUED" then
				pcall(function() directory:cancelQueue(own.roomId, player.UserId) end)
			end
		end
		membership[player.UserId] = nil
		browsing[player.UserId] = nil
		selections[player.UserId] = nil
		invitations[player.UserId] = nil
		launched[player.UserId] = nil
		refresh()
	end)
	task.spawn(function()
		local heartbeatElapsed = 0
		while true do
			task.wait(5)
			heartbeatElapsed += 5
			if refresh() then
				for _, record in cachedRooms do
					if heartbeatElapsed >= 15 and record.state == "WAITING"
						and record.ownerJobId == game.JobId then
						pcall(function() directory:heartbeatWaiting(record.roomId, game.JobId) end)
					end
					if record.state == "STARTING" then launchLocal(record)
					elseif record.state == "WAITING" and record.currentRacers == record.maxPlayers then
						local host = Players:GetPlayerByUserId(record.hostUserId)
						if host then startRoom(host) end
					elseif record.state == "ROUND_COMPLETE" and #record.queued > 0
						and (record.currentRacers == 0 or os.time() - record.updatedAt > 20) then
						recoverQueuedRound(record)
					end
				end
			end
			if heartbeatElapsed >= 15 then heartbeatElapsed = 0 end
		end
	end)
	refresh()
end

return MatchRoomService
