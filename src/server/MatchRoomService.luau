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
local Discovery = require(Shared:WaitForChild("RaceDiscovery"))

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
local globalBrowsing,quickBusy={},{}
local acceptingInvite = {}

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
		if selected and (globalBrowsing[player.UserId] or record.trackId == selected.trackId) then table.insert(rooms, directory:display(record)) end
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
				for _, member in (if record.quickWarmup then record.pendingArrivals else record.stagedMembers)or {} do
					if member.userId == player.UserId then ownRoom.nextRoundStarting = true; break end
				end
			end
		end
	end
	return { visible = (browsing[player.UserId] == true or ownRoom ~= nil)
		and not (own and own.kind == "STAGED"), rooms = rooms, room = ownRoom,
		directoryStale = directoryStale,featured=if cachedRooms[1]then directory:display(cachedRooms[1])else nil,
		allTracks=globalBrowsing[player.UserId]==true, trackId = if selected then selected.trackId else nil,
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
	cachedRooms = Discovery.sort(records)
	for userId, own in membership do
		if not findCached(own.roomId) then
			local ok,private=pcall(function()return directory:get(own.roomId)end)
			if not ok or (private and private.practiceOnly and private.hostUserId==userId)then continue end
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
		for _, staged in (if record.quickWarmup then record.pendingArrivals else record.stagedMembers)or {} do
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
	for _,m in (if record.quickWarmup then record.pendingArrivals else record.stagedMembers)or {}do
		if m.userId==player.UserId then member=m end
	end
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

local function createRoom(player,mode,value,privatePractice,firstRaceOnly)
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
			lobbyTitleKind=kind,lobbyTitle=title,practiceOnly=privatePractice,firstRaceOnly=firstRaceOnly==true,quickMatch=privatePractice, maxPlayers = TrackCatalog.Entries[selectedTrackId].MaxPlayers },
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
 return eligible(player) and not acceptingInvite[player.UserId] and not browsing[player.UserId] and not membership[player.UserId] and not creating[player.UserId]
end
local function stopLobbyDrive(player, reason, returnToHub)
 if player:GetAttribute("LobbyDriveActive") ~= true and player:GetAttribute("LobbyDrivePending") ~= true then return end
 local module = script.Parent:FindFirstChild("LobbyTestDriveService")
 if module then return require(module).stop(player, reason, returnToHub ~= false) end
end
function MatchRoomService.openBrowser(player, driverId, kartId, trackId,allTracks)
	if not eligible(player) or membership[player.UserId] or creating[player.UserId] or not choose(player, driverId, kartId, trackId) then return false end
	stopLobbyDrive(player, "browse")
	browsing[player.UserId] = true
	globalBrowsing[player.UserId]=allTracks==true
	refresh()
	return true
end

local function ensureSelection(player)
	local selected = selections[player.UserId]
	if selected and publicTrack(selected.trackId) and DriverCatalog.Entries[selected.driverId] and KartCatalog.Entries[selected.kartId] then
		return selected
	end
	local driverId = player:GetAttribute("SelectedDriverId") or DriverCatalog.DefaultId
	if not DriverCatalog.Entries[driverId] then driverId = DriverCatalog.DefaultId end

	local kartId = player:GetAttribute("SelectedKartId") or KartCatalog.DefaultId
	if not KartCatalog.Entries[kartId] then kartId = KartCatalog.DefaultId end

	local trackId = (selected and selected.trackId) or Discovery.DefaultTrackId
	if not publicTrack(trackId) then trackId = Discovery.DefaultTrackId end

	choose(player, driverId, kartId, trackId)
	return selections[player.UserId]
end

-- Cross-Hub allocation is serialized only through reservation. Teleport happens
-- after releasing the lease, so a slow network transfer cannot block new users.
local function quickPlay(player)
 if not eligible(player)or membership[player.UserId]or quickBusy[player.UserId]or creating[player.UserId]then return end
 local selected=ensureSelection(player);if not selected then return end
 quickBusy[player.UserId]=true
 local token=HttpService:GenerateGUID(false)
 local Allocator=require(script.Parent:WaitForChild('GlobalRaceAllocator'))
 local allocator=Allocator.new(MemoryStoreService:GetHashMap(Allocator.MAP_NAME))
 local reservedRecord,reservedMember,queued,newRoom
 local ok,reason=pcall(function()
  local lease
  for attempt=1,8 do
   if not eligible(player)or membership[player.UserId]then return end
   lease=allocator:acquire(token)
   if lease then break end
   task.wait(math.min(attempt,3))
  end
  if not lease then error('MATCHMAKING BUSY - PLEASE TRY AGAIN')end
  local records=directory:list()
  if lease.roomId then
   local preferred=directory:get(lease.roomId)
   if preferred and preferred.initializing then error('RACE IS OPENING - PLEASE TRY AGAIN')end
   if preferred and not table.find(records,preferred)then
    local seen=false;for _,r in records do if r.roomId==preferred.roomId then seen=true end end
    if not seen then table.insert(records,preferred)end
   end
  end
  Discovery.sort(records)
  local candidate
  for _,r in records do if publicTrack(r.trackId)and Discovery.rank(r)then candidate=r;break end end
  if not eligible(player)then return end
  if not candidate then
   local trackId=Discovery.DefaultTrackId
   local code,privateId=TeleportService:ReserveServerAsync(game.PlaceId)
   if type(code)~='string'or code==''then error('RACE SERVER UNAVAILABLE')end
   newRoom=HttpService:GenerateGUID(false)
   candidate=directory:createPersistent({id=newRoom,matchId=HttpService:GenerateGUID(false),trackId=trackId,
    hostUserId=player.UserId,hostName=player.DisplayName or player.Name,maxPlayers=TrackCatalog.Entries[trackId].MaxPlayers,
    quickMatch=true,initializing=true},code,privateId)
  end
  if not eligible(player)then return end
  selected.trackId=candidate.trackId
  local member=memberFor(player)
  if candidate.state=='WAITING' or candidate.quickWarmup then
   reservedRecord=directory:stage(candidate.roomId,member,member.admissionToken,candidate.trackId)
  else
   reservedRecord=directory:queue(candidate.roomId,member,candidate.trackId);queued=true
  end
  if not reservedRecord then error('RACE CHANGED - PLEASE TRY AGAIN')end
  reservedMember=member
  for _,m in (if reservedRecord.quickWarmup then reservedRecord.pendingArrivals else reservedRecord.stagedMembers)or {}do
   if m.userId==player.UserId then reservedMember=m end
  end
  if not allocator:finish(token,candidate.roomId)then error('RESERVATION EXPIRED - PLEASE TRY AGAIN')end
  if newRoom then
   reservedRecord=directory:update(newRoom,function(r)r.initializing=false;return r end)
   if not reservedRecord then error('RACE SERVER UNAVAILABLE')end
  end
  membership[player.UserId]={roomId=candidate.roomId,kind=if queued then 'QUEUED'else 'STAGED'}
 end)
 pcall(function()allocator:finish(token)end)
 quickBusy[player.UserId]=nil
 if not ok or not membership[player.UserId]then
  if reservedRecord then pcall(function()
   if queued then directory:cancelQueue(reservedRecord.roomId,player.UserId)end
   directory:removeStaged(reservedRecord.roomId,player.UserId)
  end)end
  if newRoom then pcall(function()
   local abandoned=directory:update(newRoom,function(r)
    if r.initializing or (#r.stagedMembers==0 and #r.currentRoundMembers==0 and #r.queued==0 and #(r.pendingArrivals or {})==0)then r.state='CLOSING';return r end
    return nil
   end)
   if abandoned then directory:remove(newRoom)end
  end)end
  if not ok then warn('[KDMMatch] allocation failed: '..tostring(reason));errorTo(player,'MATCHMAKING UNAVAILABLE - PLEASE TRY AGAIN')end
  return
 end
 pcall(function()social:remove(player.UserId)end)
 print(string.format('[KDMMatch] assigned hub=%s user=%d room=%s track=%s action=%s',game.JobId,player.UserId,
  reservedRecord.roomId,reservedRecord.trackId,if queued then 'NEXT'elseif reservedRecord.quickWarmup then 'WARMUP_JOIN'else 'JOIN'))
 refresh()
 if not queued then launchStaged(player,reservedRecord,reservedMember)end
end

function MatchRoomService.start()
	if started then return end
	started = true
	remote = Instance.new("RemoteEvent")
	remote.Name = "MatchRoomControl"
	remote.Parent = ReplicatedStorage
	remote.OnServerEvent:Connect(function(player, action, first, second, third)
		if acceptingInvite[player.UserId] then return end
		if action == "Create" or action == "Join" or action == "Queue" then
			stopLobbyDrive(player, "room_action")
		end
		local own = membership[player.UserId]
		if quickBusy[player.UserId]then return end
		if action == "BrowseAll" then
			MatchRoomService.openBrowser(player,first,second,Discovery.DefaultTrackId,true)
		elseif action == "QuickStart" then
			print(string.format("[F60] event=F60_MATCHMAKING_STARTED user=%d action=QuickStart", player.UserId))
			stopLobbyDrive(player, 'quick_start')
			ensureSelection(player)
			quickPlay(player)
		elseif action == "QuickPlay" then
			print(string.format("[F60] event=F60_MATCHMAKING_STARTED user=%d action=QuickPlay", player.UserId))
			stopLobbyDrive(player, 'quick_play')
			ensureSelection(player)
			quickPlay(player)
		elseif action == "Browse" then
			MatchRoomService.openBrowser(player, first, second, third)
		elseif action == "Back" then
			if not own then browsing[player.UserId] = nil; broadcast() end
		elseif action == "Create" then
			createRoom(player,first,second)
		elseif action=='FirstRace' then
   if not eligible(player) or own or creating[player.UserId] then return end
   if not choose(player,DriverCatalog.DefaultId,player:GetAttribute('SelectedKartId') or KartCatalog.DefaultId,'Track01') then return end
   stopLobbyDrive(player,'first_race');createRoom(player,'DEFAULT',nil,true,true)
		elseif action=='Practice' then
			stopLobbyDrive(player,'practice');createRoom(player,'DEFAULT',nil,true)
		elseif action == "Join" and type(first) == "string" then
			if eligible(player) and not own and selections[player.UserId] then
				if globalBrowsing[player.UserId]then
					local ok,r=pcall(function()return directory:get(first)end)
					if not ok then errorTo(player,'RACE INFORMATION UNAVAILABLE - TRY AGAIN');return end
					if r then selections[player.UserId].trackId=r.trackId end
				end
				stagePlayer(player, first)
			end
		elseif action == "Queue" and type(first) == "string" then
			if eligible(player) and not own and selections[player.UserId] then
				local ok, record = pcall(function() return directory:get(first) end)
				if ok and record and globalBrowsing[player.UserId]then selections[player.UserId].trackId=record.trackId end
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
			acceptingInvite[player.UserId] = true
			local processed, failure = pcall(function()
				local ok, invite = pcall(function() return social:getInvite(player.UserId) end)
				if not ok or not invite then errorTo(player, "INVITE EXPIRED"); return end
				local found, record = pcall(function() return directory:get(invite.roomId) end)
				if not found or not record or record.hostUserId ~= invite.hostUserId
					or record.trackId ~= invite.trackId or not publicTrack(invite.trackId) then
					errorTo(player, "INVITE EXPIRED"); return
				end
				if not choose(player, first, second, invite.trackId) then errorTo(player, "KART SELECTION UNAVAILABLE");return end
				-- Release the kart/seat once, without a Lobby spawn or arrival popup.
				-- This yields while seat ownership settles, so retain the acceptance lock.
				local stopped = stopLobbyDrive(player, "accept_invite", false)
				if stopped == false or not eligible(player) then
					errorTo(player, "COULD NOT LEAVE TEST DRIVE - PLEASE TRY AGAIN");return
				end
				-- The host may have started or filled the room during seat cleanup.
				found, record = pcall(function() return directory:get(invite.roomId) end)
				if not found or not record or record.hostUserId ~= invite.hostUserId
					or record.trackId ~= invite.trackId then errorTo(player, "INVITE EXPIRED");return end
				pcall(function() social:respondInvite(player.UserId,invite,'ACCEPTED') end)
				if record.state == "WAITING" and #record.stagedMembers + #(record.stagedBots or {}) < record.maxPlayers then
					stagePlayer(player, record.roomId)
				else queuePlayer(player, record.roomId, 1) end
			end)
			acceptingInvite[player.UserId] = nil
			if not processed then
				warn("[KDMRoom] invite acceptance failed: " .. tostring(failure))
				errorTo(player, "RACE ENTRY UNAVAILABLE - PLEASE TRY AGAIN")
			end
		elseif action == "DeclineInvite" then
			pcall(function()
				local invite=social:getInvite(player.UserId)
				if invite then social:respondInvite(player.UserId,invite,'DECLINED')end
			end)
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
		globalBrowsing[player.UserId]=nil
		acceptingInvite[player.UserId]=nil
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
					pcall(function()directory:renewQueue(own.roomId,player.UserId)end)
					local record = findCached(own.roomId)
					if record then
						for _, member in (if record.quickWarmup then record.pendingArrivals else record.stagedMembers)or {} do
							if member.userId == player.UserId and not member.arrived then
								launchStaged(player, record, member)
								break
							end
						end
					end
				end
				local ok, invite = pcall(function() return social:getInvite(player.UserId) end)
				if ok and invite and not acceptingInvite[player.UserId] and not membership[player.UserId] and eligible(player) then
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
