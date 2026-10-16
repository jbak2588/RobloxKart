local titleModules=require("./helpers/lobby_title_modules")
-- lune run tests/match_room_service_validation.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local function signal()
	local callbacks = {}
	return { Connect = function(_, callback) table.insert(callbacks, callback) end,
		Fire = function(_, ...) for _, callback in callbacks do callback(...) end end }
end
local players = { PlayerAdded = signal(), PlayerRemoving = signal(), current = {} }
function players:GetPlayers() return self.current end
function players:GetPlayerByUserId(userId)
	for _, player in self.current do if player.UserId == userId then return player end end
end
local function racer(userId)
	local player = { UserId = userId, DisplayName = "Racer" .. userId,
		Parent = players, attrs = { RaceState = "GARAGE" } }
	function player:GetAttribute(name) return self.attrs[name] end
	function player:SetAttribute(name, value) self.attrs[name] = value end
	table.insert(players.current, player)
	return player
end
local a, b, c, d, e, f = racer(1), racer(2), racer(3), racer(4), racer(5), racer(6)
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
local now = 1000
local enum = { SortDirection = { Ascending = "Ascending", Descending = "Descending" } }
local Directory = luau.load(fs.readFile("src/server/ActiveMatchDirectory.luau"),
	{ environment = titleModules.environment(enum) })()
local Social = luau.load(fs.readFile("src/server/RoomSocialDirectory.luau"),
	{ environment = titleModules.environment(enum) })()
local directory = Directory.new(roomMap, function() return now end)
local social = Social.new(presenceMap, inviteMap, function() return now end)
local serial, reservations = 0, 0
local remote
local replicated = { WaitForChild = function(_, name)
	return { Name = name, WaitForChild = function(_, child) return { Name = child } end }
end }
local services = {
	Players = players, ReplicatedStorage = replicated,
	MemoryStoreService = { GetSortedMap = function(_, name)
		assert(maps[name], name)
		return maps[name]
	end,
		GetHashMap = function() return inviteMap end },
	TeleportService = { ReserveServerAsync = function()
		reservations += 1
		return "room-code-" .. reservations, "private-" .. reservations
	end },
	HttpService = { GenerateGUID = function()
		serial += 1
		return "guid-" .. serial .. "-aaaaaaaa"
	end },
}
local launches, failLaunch = {}, false
local modules = {
 RaceDiscovery=luau.load(fs.readFile('src/shared/RaceDiscovery.luau'))(),
 LobbyTitleService=titleModules.service,
	TrackCatalog = { Entries = { Track01Race = { MatchType="PUBLIC_RACE", MaxPlayers = 4 }, Track03={MatchType="PUBLIC_RACE",MaxPlayers=4}, Track02={MatchType="SOLO_PROTOTYPE",MaxPlayers=1} } },
	DriverCatalog = { Entries = { Driver01 = {} } },
	KartCatalog = { Entries = { Kart01 = {} } },
	ActiveMatchDirectory = setmetatable({new=function()return directory end},{__index=Directory}),
	RoomSocialDirectory = setmetatable({ new = function() return social end }, { __index = Social }),
	RaceLaunchPayload = { buildMatch = function(matchId, roomId, members, trackId)
		return { matchId = matchId, roomId = roomId, trackId = trackId,
			participantUserIds = { members[1].userId }, selections = {
			[tostring(members[1].userId)] = { driverId = members[1].driverId,
				kartId = members[1].kartId } } }
	end },
	RaceLaunchService = { launchMatch = function(group, payload, onFailure, code)
		table.insert(launches, { group = group, payload = payload, code = code })
		if failLaunch then onFailure(group[1]); return false end
		group[1]:SetAttribute("KDMRoutePending", "RACE_LAUNCH")
		return true
	end },
}
local background = {}
local waits = 0
local environment = {
	game = { JobId = "hub-job", PlaceId = 123,
		GetService = function(_, name) return assert(services[name], name) end },
	DateTime = { now = function() return { UnixTimestampMillis = now * 1000 + serial } end },
	task = { spawn = function(callback) table.insert(background, callback) end,
		wait = function() waits += 1; if waits > 1 then error("stop poll") end end },
	Instance = { new = function(class)
		assert(class == "RemoteEvent")
		remote = { OnServerEvent = signal(), messages = {} }
		function remote:FireClient(player, action, data)
			self.messages[player] = self.messages[player] or {}
			table.insert(self.messages[player], { action = action, data = data })
		end
		return remote
	end },
	script = { Parent = { WaitForChild = function(_, name) return { Name = name } end } },
	require = function(module) return assert(modules[module.Name], module.Name) end,
	warn = print,
}
local Service = luau.load(fs.readFile("src/server/MatchRoomService.luau"),
	{ environment = environment })()
Service.start()
local count = 0
local function check(value, message) assert(value, message); count += 1 end
local function action(player, name, first, second, third)
	remote.OnServerEvent:Fire(player, name, first, second, third)
end
local function latest(player, name)
	for index = #(remote.messages[player] or {}), 1, -1 do
		local message = remote.messages[player][index]
		if message.action == name then return message.data end
	end
end
local function browse(player, trackId) action(player, "Browse", "Driver01", "Kart01", trackId or "Track01Race") end

browse(a); action(a, "Create")
local roomA = launches[1].payload.roomId
check(reservations == 1 and launches[1].group[1] == a
	and launches[1].code == "room-code-1", "CREATE reserves and teleports host immediately")
check(directory:get(roomA).state == "WAITING"
	and directory:get(roomA).stagedMembers[1].userId == a.UserId
	and directory:get(roomA).reservedServerAccessCode == "room-code-1",
	"host belongs to persistent WAITING room")
check(directory:display(directory:get(roomA)).reservedServerAccessCode == nil,
	"browser never exposes reservation code")

browse(c); browse(f); action(f, "Create")
local roomB = launches[2].payload.roomId
check(roomA ~= roomB and reservations == 2 and #latest(c, "Snapshot").rooms == 2,
	"independent rooms remain discoverable")
browse(b); action(b, "Join", roomA)
check(#launches == 3 and launches[3].code == "room-code-1"
	and #directory:get(roomA).stagedMembers == 2
	and directory:get(roomA).state == "WAITING", "JOIN uses same server without starting")
check(#directory:get(roomB).stagedMembers == 1,
	"joining Room A does not change Room B")

directory:confirmArrival(roomA, a.UserId, launches[1].payload.admissionToken, "race-job")
directory:confirmArrival(roomA, b.UserId, launches[3].payload.admissionToken, "race-job")
directory:startRound(roomA, a.UserId)
directory:raceState(roomA, directory:get(roomA).matchId, "RACING", 2, "private-1", "race-job")
check(directory:display(directory:get(roomA)).state == "RACING"
	and directory:display(directory:get(roomA)).count == 2
	and directory:display(directory:get(roomA)).maxPlayers == 4,
	"two-racer race stays visible as 2/4 Room")
browse(c); action(c, "Queue", roomA)
check(#launches == 3 and #directory:get(roomA).queued == 1
	and directory:get(roomA).currentRacers == 2,
	"QUEUE NEXT does not inject into current race")
action(c, "Queue", roomB)
check(#directory:get(roomB).queued == 0, "queued racer cannot enter another room")

social:publish(d, "hub-job")
social:sendInvite(d.UserId, directory:get(roomA))
browse(d); action(d, "AcceptInvite", "Driver01", "Kart01")
check(#directory:get(roomA).queued == 2 and directory:get(roomA).queued[2].priority == 1,
	"accepted racing invite enters priority queue")
social:sendInvite(e.UserId, directory:get(roomA))
now += Social.INVITE_TTL + 1
browse(e); action(e, "AcceptInvite", "Driver01", "Kart01")
check(latest(e, "Error") == "INVITE EXPIRED", "expired invite is rejected")

directory:raceState(roomA, directory:get(roomA).matchId, "ROUND_COMPLETE", 2)
local nextRoom = directory:nextStaging(roomA, { { userId = a.UserId,
	name = a.DisplayName, driverId = "Driver01", kartId = "Kart01" } })
check(nextRoom.state == "WAITING" and nextRoom.roomId == roomA
	and nextRoom.stagedMembers[1].userId == a.UserId
	and nextRoom.stagedMembers[2].userId == d.UserId
	and nextRoom.stagedMembers[3].userId == c.UserId,
	"rematch then invited then public queue reach same Room staging")
check(nextRoom.currentRacers == 1 and reservations == 2,
	"round completion neither auto-starts nor reserves a new server")
local pollStopped = pcall(background[1])
check(not pollStopped and #launches == 5
	and launches[4].code == "room-code-1" and launches[5].code == "room-code-1",
	"HUB poll sends promoted queue to original Room server")
local visible = {}
for _, entry in social:list() do visible[entry.userId] = true end
check(visible[e.UserId] and not visible[a.UserId] and not visible[c.UserId]
	and not visible[d.UserId],
	"HUB presence excludes staged and queued racers")
social:sendInvite(e.UserId, directory:get(roomA))
directory:removeStaged(roomA, a.UserId)
action(e, "AcceptInvite", "Driver01", "Kart01")
check(latest(e, "Error") == "INVITE EXPIRED" and directory:get(roomA).hostUserId == d.UserId,
	"host transfer invalidates the former host invitation")

failLaunch = true
browse(e); action(e, "Create")
check(latest(e, "Error") == "JOIN FAILED - PLEASE TRY AGAIN",
	"failed host teleport reports retry error")
action(e, "Join", roomB)
check(directory:get(roomB) ~= nil and #directory:get(roomB).stagedMembers == 1
	and directory:get(roomB).stagedMembers[1].userId == f.UserId,
	"failed JOIN releases staged slot without closing occupied Room")
local originalRange = roomMap.GetRangeAsync
roomMap.GetRangeAsync = function() error("directory unavailable") end
browse(e)
local stale = latest(e, "Snapshot")
check(stale.directoryStale and #stale.rooms > 0,
	"directory failure retains last good Browser list")
roomMap.GetRangeAsync = originalRange
directory:remove(roomA)
browse(e)
check(latest(c, "Error") == "LOBBY CLOSED - CHOOSE ANOTHER LOBBY"
	and latest(c, "Snapshot").visible,
	"expired queued Room returns player to Browser")
-- Additional selected-track, malicious cross-track, invite and launch cases.
failLaunch=false
local h,i,j,k=racer(7),racer(8),racer(9),racer(10)
browse(h,"Track03");action(h,"Create")
local hardRoom=launches[#launches].payload.roomId
check(directory:get(hardRoom).trackId=="Track03" and directory:get(hardRoom).maxPlayers==4
 and launches[#launches].payload.trackId=="Track03","Track03 creation and launch use selected track")
browse(i,"Track01Race")
for _,record in latest(i,"Snapshot").rooms do check(record.trackId=="Track01Race","Base browser filters Hard rooms") end
local before=#launches
action(i,"Join",hardRoom);action(i,"Queue",hardRoom)
check(#launches==before and #directory:get(hardRoom).stagedMembers==1 and #directory:get(hardRoom).queued==0,"cross-track join and queue reject")
browse(j,"Track03")
for _,record in latest(j,"Snapshot").rooms do check(record.trackId=="Track03","Hard browser filters Base rooms") end
action(j,"Join",roomB);action(j,"Queue",roomB)
check(#launches==before,"reverse cross-track join and queue reject")
check(not Service.openBrowser(j,"Driver01","Kart01","Track02")
 and not Service.openBrowser(j,"Driver01","Kart01","Unknown"),"solo and unknown tracks cannot open public browser")
social:publish(i,"hub-job");social:sendInvite(i.UserId,directory:get(hardRoom))
action(i,"AcceptInvite","Driver01","Kart01")
check(launches[#launches].payload.trackId=="Track03" and #directory:get(hardRoom).stagedMembers==2,"invite moves Base selection to authoritative Hard track")
local current=directory:get(hardRoom)
check(directory:stage(hardRoom,{userId=100},"token-100","Track01Race")==nil
 and directory:queue(hardRoom,{userId=100},"Track01Race")==nil,"atomic directory admission rejects cross-track expected identity")
directory:confirmArrival(hardRoom,h.UserId,current.stagedMembers[1].admissionToken,"hard-job")
directory:confirmArrival(hardRoom,i.UserId,current.stagedMembers[2].admissionToken,"hard-job")
directory:startRound(hardRoom,h.UserId)
browse(k,"Track03");action(k,"Queue",hardRoom)
check(#directory:get(hardRoom).queued==1,"Track03 racing room accepts same-track next-round queue")
social:publish(j,"hub-job");social:sendInvite(j.UserId,directory:get(hardRoom));action(j,"AcceptInvite","Driver01","Kart01")
check(#directory:get(hardRoom).queued==2 and directory:get(hardRoom).queued[2].priority==1,"Hard racing invite queues with invited priority")
directory:raceState(hardRoom,current.matchId,"ROUND_COMPLETE",2)
local nextHard=directory:nextStaging(hardRoom,{{userId=h.UserId,name=h.DisplayName,driverId="Driver01",kartId="Kart01"}})
check(nextHard.trackId=="Track03" and nextHard.roomId==hardRoom and nextHard.stagedMembers[2].userId==j.UserId
 and nextHard.stagedMembers[3].userId==k.UserId,"Hard rematch preserves room and invited/public queue ordering")
waits=0;pcall(background[1])
check(launches[#launches].payload.trackId=="Track03","promoted Hard queue retains authoritative track at launch")
print(string.format("PASS: %d persistent MatchRoom service checks", count))
