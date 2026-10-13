local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MemoryStoreService = if game.PlaceId==0 and game:GetService("RunService"):IsStudio() then require(script.Parent:WaitForChild("StudioOfflineMemoryStore")) else game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackCatalog = require(Shared:WaitForChild("TrackCatalog"))
local DriverCatalog = require(Shared:WaitForChild("DriverCatalog"))
local KartCatalog = require(Shared:WaitForChild("KartCatalog"))
local LobbyTitleService = require(script.Parent:WaitForChild("LobbyTitleService"))
local ActiveMatchDirectory = require(script.Parent:WaitForChild("ActiveMatchDirectory"))
local RoomSocialDirectory = require(script.Parent:WaitForChild("RoomSocialDirectory"))
local RaceLaunchPayload = require(script.Parent:WaitForChild("RaceLaunchPayload"))
local RaceLaunchService = require(script.Parent:WaitForChild("RaceLaunchService"))

local MatchRoomService = {}
local function publicTrack(trackId)
	local track = if type(trackId) == "string" then TrackCatalog.Entries[trackId] else nil
	return if track and track.MatchType == "PUBLIC_RACE" and track.MaxPlayers >= 1 then track else nil
end
local directory = ActiveMatchDirectory.new(MemoryStoreService:GetSortedMap(ActiveMatchDirectory.MAP_NAME))
local social = RoomSocialDirectory.new(
	MemoryStoreService:GetSortedMap(RoomSocialDirectory.PRESENCE_MAP),
	MemoryStoreService:GetHashMap(RoomSocialDirectory.INVITE_MAP))
local browsing, selections, membership, launched, creating = {}, {}, {}, {}, {}
local cachedRooms, remote, started, directoryStale = {}, nil, false, false

local function eligible(player)
	return player and player.Parent == Players and player:GetAttribute("RaceState") == "GARAGE"
		and player:GetAttribute("KDMRoutePending") ~= "RACE_LAUNCH"
end

local function choose(player, driverId, kartId, trackId)
	local module = script.Parent.FindFirstChild and script.Parent:FindFirstChild("ProgressionRuntimeBinding")
	if module then kartId = require(module).selection(player, kartId) end
	if type(driverId) ~= "string" or type(kartId) ~= "string"
		or not publicTrack(trackId) or not DriverCatalog.Entries[driverId] or not KartCatalog.Entries[kartId] then return false end
	selections[player.UserId] = { driverId = driverId, kartId = kartId, trackId = trackId }
	return true
end

local function memberFor(player, priority)
	local selected = selections[player.UserId]
	local module = script.Parent.FindFirstChild and script.Parent:FindFirstChild("ProgressionRuntimeBinding")
	if module then selected.kartId = require(module).selection(player, selected.kartId) end
	return { userId = player.UserId, name = if player.DisplayName and player.DisplayName~="" then player.DisplayName else player.Name,
		driverId = selected.driverId, kartId = selected.kartId,
		hubJobId = game.JobId, queuedAt = DateTime.now().UnixTimestampMillis, priority = priority or 3,
		admissionToken = HttpService:GenerateGUID(false) }
end

local function findCached(roomId)
	for _, record in cachedRooms do if record.roomId == roomId then return record end end
end

local function snapshotFor(player)
	local own = membership[player.UserId]
	local rooms = {}
	local selected = selections[player.UserId]
	for _, record in cachedRooms do
		if selected and record.trackId == selected.trackId then table.insert(rooms, directory:display(record)) end
	end
	local ownRoom
	if own and own.kind == "QUEUED" then
		local record = findCached(own.roomId)
		if record then
			ownRoom = directory:display(record)
			ownRoom.membershipKind = "QUEUED"
			for index, member in record.queued do
				if member.userId == player.UserId then ownRoom.queuePosition = index; break end
			end
			if not ownRoom.queuePosition then
				for _, member in record.stagedMembers or {} do
					if member.userId == player.UserId then ownRoom.nextRoundStarting = true; break end
				end
			end
		end
	end
	return { visible = (browsing[player.UserId] == true or ownRoom ~= nil)
		and not (own and own.kind == "STAGED"), rooms = rooms, room = ownRoom,
		directoryStale = directoryStale, trackId = if selected then selected.trackId else nil,
		trackName = if selected then TrackCatalog.Entries[selected.trackId].DisplayName else nil,
		maxPlayers = if selected then TrackCatalog.Entries[selected.trackId].MaxPlayers else nil }
end

local function broadcast()
	for _, player in Players:GetPlayers() do remote:FireClient(player, "Snapshot", snapshotFor(player)) end
end

local function refresh()
	local ok, records = pcall(function() return directory:list() end)
	if not ok then
		warn("[KDMRoom] directory listing failed: " .. tostring(records))
		directoryStale = true
		broadcast()
		return
	end
	directoryStale = false
	cachedRooms = records
	for userId, own in membership do
		if not findCached(own.roomId) then
			membership[userId] = nil
			launched[userId] = nil
			local player = Players:GetPlayerByUserId(userId)
			if player then
				pcall(function() social:clearInvite(userId) end)
				remote:FireClient(player, "Error", "LOBBY CLOSED - CHOOSE ANOTHER LOBBY")
			end
		end
	end
	broadcast()
end

local function errorTo(player, message)
	if player.Parent == Players then remote:FireClient(player, "Error", message) end
end

local function launchStaged(player, record, member)
	if launched[player.UserId] == member.admissionToken then return end
	if type(member.admissionExpiresAt) ~= "number"
		or member.admissionExpiresAt <= os.time() + 5 then
		local newToken = HttpService:GenerateGUID(false)
		local ok, updated = pcall(function()
			return directory:renewAdmission(record.roomId, player.UserId,
				member.admissionToken, newToken)
		end)
		if not ok or not updated then return end
		record = updated
		for _, staged in record.stagedMembers do
			if staged.userId == player.UserId then member = staged; break end
		end
	end
	local payload = RaceLaunchPayload.buildMatch(record.matchId, record.roomId, { member }, record.trackId)
	if not payload then return end
	payload.admissionToken = member.admissionToken
	launched[player.UserId] = member.admissionToken
	local function failed()
		if membership[player.UserId] == nil then return end
		launched[player.UserId] = nil
		local removed, updated = pcall(function() return directory:removeStaged(record.roomId, player.UserId) end)
		if not removed then
			warn("[KDMRoom] staged rollback failed: " .. tostring(updated))
			task.delay(2, function()
				local retry, retryError = pcall(function()
					directory:removeStaged(record.roomId, player.UserId)
				end)
				if not retry then warn("[KDMRoom] staged rollback retry failed: " .. tostring(retryError)) end
			end)
		end
		membership[player.UserId] = nil
		browsing[player.UserId] = true
		refresh()
		errorTo(player, "JOIN FAILED - PLEASE TRY AGAIN")
	end
	local ok = RaceLaunchService.launchMatch({ player }, payload, failed,
		record.reservedServerAccessCode)
	if not ok then failed() end
end

local function stagePlayer(player, roomId)
	local selected = selections[player.UserId]
	local found, current = pcall(function() return directory:get(roomId) end)
	if not selected or not found or not current or current.trackId ~= selected.trackId
		or not publicTrack(current.trackId) then errorTo(player, "LOBBY TRACK MISMATCH"); return false end
	local member = memberFor(player)
	local ok, record = pcall(function() return directory:stage(roomId, member, member.admissionToken, selected.trackId) end)
	if not ok or not record then
		if not ok then warn("[KDMRoom] staging failed: " .. tostring(record)) end
		local found, current = pcall(function() return directory:get(roomId) end)
		errorTo(player, if found and not current then "LOBBY CLOSED - CHOOSE ANOTHER LOBBY"
			elseif found and current and current.state ~= "WAITING" then "LOBBY STARTED - QUEUE FOR NEXT RACE"
			elseif found and current and #current.stagedMembers + #(current.stagedBots or {}) >= current.maxPlayers then "LOBBY FULL"
			else "LOBBY STATUS UPDATING...")
		return false
	end
	membership[player.UserId] = { roomId = roomId, kind = "STAGED" }
	pcall(function() social:remove(player.UserId) end)
	refresh()
	launchStaged(player, record, member)
	return true
end

local function queuePlayer(player, roomId, priority)
	local selected = selections[player.UserId]
	local found, current = pcall(function() return directory:get(roomId) end)
	if not selected or not found or not current or current.trackId ~= selected.trackId
		or not publicTrack(current.trackId) then errorTo(player, "LOBBY TRACK MISMATCH"); return false end
	local member = memberFor(player, priority)
	local ok, record = pcall(function() return directory:queue(roomId, member, selected.trackId) end)
	if not ok or not record then
		local found, current = pcall(function() return directory:get(roomId) end)
		errorTo(player, if found and not current then "LOBBY CLOSED - CHOOSE ANOTHER LOBBY"
			else "LOBBY STATUS UPDATING...")
		return false
	end
	membership[player.UserId] = { roomId = roomId, kind = "QUEUED" }
	pcall(function() social:remove(player.UserId) end)
	refresh()
	return true
end

local function createRoom(player,mode,value)
	if not eligible(player) or membership[player.UserId] or not selections[player.UserId]
		or creating[player.UserId] then return end
	local selectedTrackId = selections[player.UserId].trackId
	if not publicTrack(selectedTrackId) then return end
	local selected=selections[player.UserId]
	local selectedAttribute=player:GetAttribute("SelectedTrackId")
	creating[player.UserId] = selected
	local function clearCreating()
		if creating[player.UserId]==selected then creating[player.UserId]=nil end
	end
	local function stillEligible()
		return eligible(player) and not membership[player.UserId] and selections[player.UserId]==selected
			and player:GetAttribute("SelectedTrackId")==selectedAttribute
	end
	local resolved,kind,title=pcall(function()
		return LobbyTitleService.resolve(player,mode,value,if mode=="CUSTOM" then game:GetService("TextService") else nil)
	end)
	if not resolved or not kind then clearCreating();errorTo(player,LobbyTitleService.ERROR);return end
	if not stillEligible() then clearCreating();return end
	local reserved, code, privateId = pcall(function()
		return TeleportService:ReserveServerAsync(game.PlaceId)
	end)
	if not reserved or type(code) ~= "string" or code == "" then
		clearCreating()
		errorTo(player, "RACE SERVER UNAVAILABLE - PLEASE TRY AGAIN"); return
	end
	if not stillEligible() then
		clearCreating()
		return
	end
	local roomId = HttpService:GenerateGUID(false)
	local created, createError = pcall(function()
		directory:createPersistent({ id = roomId, matchId = HttpService:GenerateGUID(false),
			trackId = selectedTrackId, hostUserId = player.UserId,
			hostName = if player.DisplayName and player.DisplayName~="" then player.DisplayName else player.Name,
			lobbyTitleKind=kind,lobbyTitle=title, maxPlayers = TrackCatalog.Entries[selectedTrackId].MaxPlayers },
			code, privateId)
	end)
	if not created then
		clearCreating()
		warn("[KDMRoom] create failed: " .. tostring(createError))
		errorTo(player, "LOBBY STATUS UPDATING...")
		return
	end
	if not stillEligible() then
		pcall(function() directory:remove(roomId) end);clearCreating();return
	end
	if not stagePlayer(player, roomId) then
		pcall(function() directory:remove(roomId) end)
	end
	clearCreating()
end

function MatchRoomService.canTestDrive(player)
 return eligible(player) and not browsing[player.UserId] and not membership[player.UserId] and not creating[player.UserId]
end
local function stopLobbyDrive(player, reason)
 if player:GetAttribute("LobbyDriveActive") ~= true and player:GetAttribute("LobbyDrivePending") ~= true then return end
 local module = script.Parent:FindFirstChild("LobbyTestDriveService")
 if module then require(module).stop(player, reason, true) end
end
function MatchRoomService.openBrowser(player, driverId, kartId, trackId)
	if not eligible(player) or membership[player.UserId] or creating[player.UserId] or not choose(player, driverId, kartId, trackId) then return false end
	stopLobbyDrive(player, "browse")
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
	remote.OnServerEvent:Connect(function(player, action, first, second, third)
		if action == "Create" or action == "Join" or action == "Queue" or action == "AcceptInvite" then
			stopLobbyDrive(player, "room_action")
		end
		local own = membership[player.UserId]
		if action == "Browse" then
			MatchRoomService.openBrowser(player, first, second, third)
		elseif action == "Back" then
			if not own then browsing[player.UserId] = nil; broadcast() end
		elseif action == "Create" then
			createRoom(player,first,second)
		elseif action == "Join" and type(first) == "string" then
			if eligible(player) and not own and selections[player.UserId] then
				stagePlayer(player, first)
			end
		elseif action == "Queue" and type(first) == "string" then
			if eligible(player) and not own and selections[player.UserId] then
				local ok, record = pcall(function() return directory:get(first) end)
				local priority = 3
				if ok and record then
					for _, userId in record.rivalUserIds or {} do
						if userId == player.UserId then priority = 2; break end
					end
					for _, member in record.currentRoundMembers or {} do
						if member.userId == player.UserId then priority = 2; break end
					end
				end
				queuePlayer(player, first, priority)
			end
		elseif action == "CancelQueue" then
			if not own or own.kind ~= "QUEUED" then return end
			pcall(function() directory:cancelQueue(own.roomId, player.UserId) end)
			pcall(function() directory:removeStaged(own.roomId, player.UserId) end)
			membership[player.UserId] = nil
			launched[player.UserId] = nil
			refresh()
		elseif action == "AcceptInvite" then
			if own or creating[player.UserId] or not eligible(player) then return end
			local ok, invite = pcall(function() return social:getInvite(player.UserId) end)
			if not ok or not invite then errorTo(player, "INVITE EXPIRED"); return end
			local found, record = pcall(function() return directory:get(invite.roomId) end)
			if not found or not record or record.hostUserId ~= invite.hostUserId
				or record.trackId ~= invite.trackId or not publicTrack(invite.trackId) then
				errorTo(player, "INVITE EXPIRED"); return
			end
			if not choose(player, first, second, invite.trackId) then return end
			pcall(function() social:clearInvite(player.UserId) end)
			if record.state == "WAITING" and #record.stagedMembers + #(record.stagedBots or {}) < record.maxPlayers then
				stagePlayer(player, record.roomId)
			else queuePlayer(player, record.roomId, 1) end
		elseif action == "DeclineInvite" then
			pcall(function() social:clearInvite(player.UserId) end)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local own = membership[player.UserId]
		if own and own.kind == "QUEUED" then
			pcall(function() directory:cancelQueue(own.roomId, player.UserId) end)
		elseif own and own.kind == "STAGED"
			and player:GetAttribute("KDMRoutePending") ~= "RACE_LAUNCH" then
			pcall(function() directory:removeStaged(own.roomId, player.UserId) end)
		end
		pcall(function() social:remove(player.UserId) end)
		membership[player.UserId], browsing[player.UserId] = nil, nil
		selections[player.UserId], launched[player.UserId] = nil, nil
		creating[player.UserId] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(5)
			refresh()
			for _, player in Players:GetPlayers() do
				if eligible(player) and not membership[player.UserId] then
					pcall(function() social:publish(player, game.JobId) end)
				else pcall(function() social:remove(player.UserId) end) end
				local own = membership[player.UserId]
				if own and own.kind == "QUEUED" then
					local record = findCached(own.roomId)
					if record then
						for _, member in record.stagedMembers or {} do
							if member.userId == player.UserId and not member.arrived then
								launchStaged(player, record, member)
								break
							end
						end
					end
				end
				local ok, invite = pcall(function() return social:getInvite(player.UserId) end)
				if ok and invite and not membership[player.UserId] and eligible(player) then
					local record = findCached(invite.roomId)
					if record and record.hostUserId == invite.hostUserId then
						remote:FireClient(player, "Invite", { roomId = invite.roomId,
							hostUserId = invite.hostUserId, hostName = invite.hostName,
							trackId = invite.trackId, state = record.state,
							lobbyTitle=directory:display(record).lobbyTitle,lobbyTitleKind=directory:display(record).lobbyTitleKind,
							count = directory:display(record).count,
							maxPlayers = record.maxPlayers })
					elseif not directoryStale then
						pcall(function() social:clearInvite(player.UserId) end)
						errorTo(player, if record then "INVITE EXPIRED"
							else "LOBBY CLOSED - CHOOSE ANOTHER LOBBY")
					end
				end
			end
		end
	end)
	refresh()
end

return MatchRoomService
