local titleModules=require("./helpers/lobby_title_modules")
-- lune run tests/race_room_coordinator_validation.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local function signal()
	local callbacks = {}
	return { Connect = function(_, callback) table.insert(callbacks, callback) end,
		Fire = function(_, ...) for _, callback in callbacks do callback(...) end end }
end
local function map()
	local result = { values = {} }
	function result:SetAsync(key, value) self.values[key] = value end
	function result:GetAsync(key) return self.values[key] end
	function result:UpdateAsync(key, transform)
		local changed = transform(self.values[key])
		if changed then self.values[key] = changed end
		return changed
	end
	function result:RemoveAsync(key) self.values[key] = nil end
	function result:GetRangeAsync()
		local rows = {}
		for key, value in self.values do table.insert(rows, { key = key, value = value }) end
		return rows
	end
	return result
end
local roomMap, presenceMap, inviteMap = map(), map(), map()
local maps = { KDM_ActiveBaseRooms_v1 = roomMap, KDM_HubPresence_v1 = presenceMap }
local enum = { SortDirection = { Ascending = "Ascending", Descending = "Descending" } }
local Directory = luau.load(fs.readFile("src/server/ActiveMatchDirectory.luau"),
	{ environment = titleModules.environment(enum) })()
local Social = luau.load(fs.readFile("src/server/RoomSocialDirectory.luau"),
	{ environment = titleModules.environment(enum) })()
local directory = Directory.new(roomMap)
local social = Social.new(presenceMap, inviteMap)
local function member(userId, priority)
	return { userId = userId, name = "Racer" .. userId,
		driverId = "Driver01", kartId = "Kart01", queuedAt = userId,
		priority = priority or 3, admissionToken = "token-" .. userId }
end
local roomId, matchId = "room-aaaaaaaa", "match-aaaaaaaa"
directory:createPersistent({ id = roomId, matchId = matchId, trackId = "Track01Race",
	hostUserId = 1, hostName = "Racer1", maxPlayers = 4 }, "original-code", "private-original")
directory:stage(roomId, member(1), "token-1")
directory:stage(roomId, member(2), "token-2")
directory:confirmArrival(roomId, 1, "token-1", "race-job")
directory:confirmArrival(roomId, 2, "token-2", "race-job")
directory:startRound(roomId, 1)
directory:raceState(roomId, matchId, "RACING", 2, "private-original", "race-job")
directory:queue(roomId, member(3, 3))
directory:queue(roomId, member(4, 1))
local players = { current = {} }
function players:GetPlayers() return self.current end
function players:GetPlayerByUserId(userId)
	for _, player in self.current do if player.UserId == userId then return player end end
end
local kart = { attrs = {} }
function kart:SetAttribute(name, value) self.attrs[name] = value end
local context = { kart = kart }
function context:setSpawnCFrame(value) self.spawnCFrame = value end
local player = { UserId = 1, DisplayName = "Racer1", Parent = players,
	attrs = { SelectedDriverId = "Driver01", SelectedKartId = "Kart01" } }
function player:GetAttribute(name) return self.attrs[name] end
function player:SetAttribute(name, value) self.attrs[name] = value end
table.insert(players.current, player)
local remote = { OnServerEvent = signal(), messages = {} }
function remote:FireClient(_, action, data) table.insert(self.messages, { action, data }) end
local replicated = { WaitForChild = function(_, name)
	if name == "GarageControl" then return remote end
	return { WaitForChild = function(_, child) return { Name = child } end }
end }
local ground = { Position = rb.Vector3.zero, Size = rb.Vector3.new(10, 2, 10),
	IsA = function(_, class) return class == "BasePart" end }
local workspace = { FindFirstChild = function(_, name)
	if name == "Baseplate" then return ground end
	return nil
end }
local services = { Players = players, ReplicatedStorage = replicated,
	Workspace = workspace,
	MemoryStoreService = { GetSortedMap = function(_, name) return maps[name] end,
		GetHashMap = function() return inviteMap end } }
local modules = { ActiveMatchDirectory = Directory, RoomSocialDirectory = Social,
	RaceBotController = {removeProductionBot=function() end,hasProductionBot=function() return false end},
	RaceController = {isRosterLocked=function() return false end},
	RaceSession = {active=function() return nil end},
	RaceConfig = {INVITEABLE_BOT_ENABLED=true,MAX_BOTS_PER_ROOM=1},
	PrototypeWorld = { getKartContext = function() return context end },
	TrackCatalog = { Entries = { Track01Race = { GridSlots = {
		rb.CFrame.new(0, 0, 0), rb.CFrame.new(10, 0, 0),
		rb.CFrame.new(20, 0, 0), rb.CFrame.new(30, 0, 0) } } } } }
modules.TrackCatalog.botAllowed=function(id)return id=="Track01Race" end
local environment = {
	game = { PrivateServerId = "private-original", JobId = "race-job",
		GetService = function(_, name) return assert(services[name]) end },
	script = { Parent = { WaitForChild = function(_, name) return { Name = name } end } },
	require = function(module) return assert(modules[module.Name]) end,
	CFrame = rb.CFrame, Enum = enum,
	task = { spawn = function() end },
	warn = function() end,
}
local Coordinator = luau.load(fs.readFile("src/server/RaceRoomCoordinator.luau"),
	{ environment = environment })()
local callbacks = Coordinator.start({ roomId = roomId, matchId = matchId,
	trackId = "Track01Race", participantUserIds = { 1 } })
local count = 0
local function check(value, message) assert(value, message); count += 1 end
check(callbacks.onRoundReady({ player }), "round completion returns to staging")
local nextRoom = directory:get(roomId)
check(nextRoom.roomId == roomId and nextRoom.matchId == matchId
	and nextRoom.reservedServerAccessCode == "original-code"
	and nextRoom.privateServerId == "private-original", "same Room and reservation survive")
check(nextRoom.state == "WAITING" and nextRoom.currentRacers == 1 and nextRoom.roundId == 1,
	"rematch does not auto-start a second round")
check(nextRoom.stagedMembers[1].userId == 1
	and nextRoom.stagedMembers[2].userId == 4
	and nextRoom.stagedMembers[3].userId == 3,
	"rematch then accepted invite then public queue priority")
check(callbacks.getRoomHostUserId() == 1 and player.attrs.GridSlot == 1
	and context.spawnCFrame ~= nil and kart.attrs.RaceStartCFrame ~= nil,
	"host identity and grid placement persist")
check(not callbacks.onRoundStart(2), "non-host cannot start")
check(not callbacks.onRoundStart(1), "host cannot launch while invited arrivals are pending")
directory:confirmArrival(roomId, 4, "token-4", "race-job")
directory:confirmArrival(roomId, 3, "token-3", "race-job")
check(callbacks.onRoundStart(1), "host starts after staged racers arrive")
check(directory:get(roomId).state == "STARTING"
	and directory:get(roomId).currentRacers == 3
	and directory:get(roomId).roundId == 2,
	"only arrived staging roster is locked into current round")
local hubPlayer = { UserId = 9, DisplayName = "HubFriend" }
social:publish(hubPlayer, "hub-job")
remote.OnServerEvent:Fire(player, "Invite", 9)
check(social:getInvite(9).roomId == roomId and social:getInvite(9).hostUserId == 1,
	"on-track host invite reaches cross-server HUB record")
remote.OnServerEvent:Fire(player, "Invite", 10)
check(social:getInvite(10) == nil, "unavailable user cannot be invited")
check(remote.messages[#remote.messages][1] == "InviteFailed", "unavailable target reports failure")
local first = social:getInvite(9)
remote.OnServerEvent:Fire(player, "Invite", 9, 17)
local ack = remote.messages[#remote.messages]
check(ack[1] == "InviteSent" and ack[2].targetUserId == 9 and ack[2].requestId == 17
	and ack[2].expiresAt == first.expiresAt, "duplicate acknowledges original stored expiry")
check(social:getInvite(9).expiresAt == first.expiresAt, "duplicate does not extend invitation")
social:publish({UserId=10, DisplayName="Another Friend"}, "hub-job")
remote.OnServerEvent:Fire(player, "Invite", 10, 18)
check(social:getInvite(9) ~= nil and social:getInvite(10) ~= nil,
	"targets have independent stored invitations")
social:clearInvite(9)
callbacks.onRoomPhase("WAITING", 3)
local snapshot = remote.messages[#remote.messages][2]
check(snapshot.pendingInvites["9"] == nil and snapshot.pendingInvites["10"] ~= nil,
	"authoritative decline snapshot clears only declined target")
local oldSet = inviteMap.SetAsync
inviteMap.SetAsync = function() error("storage unavailable") end
remote.OnServerEvent:Fire(player, "Invite", 9, 19)
check(remote.messages[#remote.messages][1] == "InviteFailed"
	and remote.messages[#remote.messages][2].requestId == 19 and social:getInvite(9) == nil,
	"failed storage never acknowledges success")
inviteMap.SetAsync = oldSet
local messagesBefore = #remote.messages
remote.OnServerEvent:Fire(player, "Invite", 9, {})
check(#remote.messages == messagesBefore, "invalid request token is rejected")
print(string.format("PASS: %d persistent room coordinator checks", count))
check(callbacks.requiresHostStart(),'host invitation latches manual start for this room')
check(not callbacks.onRoundStart(1),'unanswered stored invitation blocks start')
local invite=social:getInvite(10)
social:respondInvite(10,invite,'DECLINED')
check(not social:getInvite(10)and social:getInviteStatus(10).response=='DECLINED','decline is consumed but observable by host')
callbacks.onRoomPhase('WAITING',3)
local replies=remote.messages[#remote.messages][2]
check(replies.invitationResponses['10'].state=='DECLINED'and not replies.pendingInvites['10'],'decline displayed and no longer pending')
social:sendInvite(9,directory:get(roomId));remote.OnServerEvent:Fire(player,'Invite',9,20)
local accepted=social:getInvite(9);social:respondInvite(9,accepted,'ACCEPTED')
callbacks.onRoomPhase('WAITING',3)
replies=remote.messages[#remote.messages][2]
check(replies.invitationResponses['9'].state=='ACCEPTED'and replies.pendingInvites['9'],'accepted entrant remains guarded until admission')
check(not callbacks.onRoundStart(1),'accepted but absent entrant cannot be skipped')
directory:queue(roomId,member(9,1));callbacks.onRoomPhase('WAITING',3)
replies=remote.messages[#remote.messages][2]
check(not replies.pendingInvites['9']and replies.invitationResponses['9'].state=='ACCEPTED','accepted member no longer awaiting response')
print('PASS '..count..' coordinator checks including invitation decisions')

-- Fresh reserved job experiment: only the affected unqueued1H+1B Quick Race.
local freshId='room-fresh-bot';local oldId='match-old-bot'
directory:createPersistent({id=freshId,matchId=oldId,trackId='Track01Race',hostUserId=1,hostName='Racer1',maxPlayers=4,quickMatch=true},'old-code','old-private')
directory:stage(freshId,member(1),'fresh-original-token');directory:confirmArrival(freshId,1,'fresh-original-token','race-job')
directory:addBot(freshId,{botId='Bot01',name='KDM Rookie [BOT]',kartId='Kart01',gridSlot=4})
directory:startRound(freshId,1,2);directory:raceState(freshId,oldId,'RACING',2,'old-private','race-job')
services.RunService={IsStudio=function()return false end}
services.TeleportService={ReserveServerAsync=function()return 'fresh-access-code','fresh-private' end}
local serial=0;services.HttpService={GenerateGUID=function()serial+=1;return 'fresh-server-token-'..serial end}
modules.RaceConfig.FRESH_BOT_REMATCH_ENABLED=true
local session={rewardRuns={[player]={completed=true,requested=true,multiplier=2}},rematchVotes={[player]=true}}
modules.RaceSession.active=function()return session end
local launches={};local failure
modules.RaceLaunchPayload={buildMatch=function(mid,rid,ms,tid)return {matchId=mid,roomId=rid,trackId=tid,participantUserIds={ms[1].userId},selections={['1']={driverId=ms[1].driverId,kartId=ms[1].kartId}}}end}
modules.RaceLaunchService={launchMatch=function(group,payload,failed,code,preserve)
 failure=failed;table.insert(launches,{payload=payload,code=code,preserve=preserve});player:SetAttribute('KDMRoutePending','RACE_LAUNCH');return true
end}
modules.RaceBotController.hasProductionBot=function()return true end
local fresh=Coordinator.start({roomId=freshId,matchId=oldId,trackId='Track01Race',participantUserIds={1}})
check(fresh.onRoundReady({player})=='TRANSFER','fresh rematch suppresses same-job countdown')
local migrated=directory:get(freshId)
check(migrated.roomId==freshId and migrated.trackId=='Track01Race' and migrated.matchId~=oldId and migrated.privateServerId=='fresh-private','same room/track but fresh match and reserved job')
check(migrated.state=='WAITING' and migrated.raceJobId=='' and #migrated.stagedBots==0,'destination rebuilds bot through normal Quick Race admission')
check(migrated.stagedMembers[1].rewardNextMultiplier==3 and not migrated.stagedMembers[1].arrived,'authoritative continuation and unconsumed arrival token')
check(launches[1].payload.rewardNextMultiplier==nil and launches[1].payload.admissionToken==migrated.stagedMembers[1].admissionToken,'payload carries admission only; reward read from server directory')
check(launches[1].preserve and launches[1].code=='fresh-access-code','existing safe teleport failure mode retained')
fresh.onRoomLeave(1)
check(directory:get(freshId)~=nil and #directory:get(freshId).stagedMembers==1,'old job departure cannot delete new admission')
player:SetAttribute('KDMRoutePending','');failure();check(not player:GetAttribute('RaceRematchReady') and session.rematchVotes[player]==nil,'failed transfer allows Rematch retry')
check(fresh.onRoundReady({player})=='TRANSFER' and launches[2].code==launches[1].code and launches[2].payload.matchId==launches[1].payload.matchId,'retry reuses same reservation and continuation')
check(not directory:freshBotRematch(freshId,oldId,'bad-match','bad-code','bad-private',member(1)),'stale source cannot claim a second destination')
print('PASS '..count..' coordinator checks including fresh job/token/retry/reward continuation')
