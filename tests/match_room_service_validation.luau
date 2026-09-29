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
		Parent = players, attrs = { RaceState = "GARAGE" }, changed = {} }
	function player:GetAttribute(name) return self.attrs[name] end
	function player:SetAttribute(name, value)
		self.attrs[name] = value
		if self.changed[name] then self.changed[name]:Fire() end
	end
	function player:GetAttributeChangedSignal(name)
		self.changed[name] = self.changed[name] or signal()
		return self.changed[name]
	end
	table.insert(players.current, player)
	return player
end
local a, b, c, d, e, f, g, h = racer(1), racer(2), racer(3), racer(4),
	racer(5), racer(6), racer(7), racer(8)
local roomRemote
local replicated = { WaitForChild = function(_, name)
	return { Name = name, WaitForChild = function(_, childName) return { Name = childName } end }
end }
local map = { values = {} }
function map:SetAsync(key, value) self.values[key] = value end
function map:GetAsync(key) return self.values[key] end
function map:UpdateAsync(key, transform)
	local value = transform(self.values[key])
	if value then self.values[key] = value end
	return value
end
function map:RemoveAsync(key) self.values[key] = nil end
function map:GetRangeAsync()
	local rows = {}
	for key, value in self.values do table.insert(rows, { key = key, value = value }) end
	return rows
end
local serial = 0
local services = { Players = players, ReplicatedStorage = replicated,
	MemoryStoreService = { GetSortedMap = function() return map end },
	TeleportService = { ReserveServerAsync = function() return "server-code", "private-server" end },
	HttpService = { GenerateGUID = function()
		serial += 1
		return "match-guid-" .. serial
	end } }
local modules = {
	TrackCatalog = { Entries = { Track01Race = { MaxPlayers = 4 } } },
	DriverCatalog = { Entries = { Driver01 = {} } },
	KartCatalog = { Entries = { Kart01 = {} } },
}
local directoryEnvironment = { Enum = { SortDirection = { Ascending = "Ascending" } } }
modules.ActiveMatchDirectory = luau.load(fs.readFile("src/server/ActiveMatchDirectory.luau"),
	{ environment = directoryEnvironment })()
local launches = {}
local failLaunch = false
modules.RaceLaunchPayload = { buildMatch = function(matchId, roomId, members, trackId)
	local ids = {}
	for _, member in members do table.insert(ids, member.userId) end
	return { matchId = matchId, roomId = roomId, trackId = trackId, participantUserIds = ids }
end }
modules.RaceLaunchService = { launchMatch = function(group, payload, onFailure, accessCode)
	table.insert(launches, { group = group, payload = payload, accessCode = accessCode })
	if failLaunch then
		for _, player in group do onFailure(player) end
		return false
	end
	return true
end }
local background = {}
local waitCalls = 0
local environment = {
	game = { JobId = "hub-job", PlaceId = 123,
		GetService = function(_, name) return assert(services[name], name) end },
	task = { spawn = function(callback) table.insert(background, callback) end,
		wait = function()
			waitCalls += 1
			if waitCalls > 1 then error("stop polling fixture") end
		end },
	warn = function() end,
	Instance = { new = function(class)
		assert(class == "RemoteEvent")
		roomRemote = { OnServerEvent = signal(), messages = {} }
		function roomRemote:FireClient(player, action, data)
			self.messages[player] = self.messages[player] or {}
			table.insert(self.messages[player], { action = action, data = data })
		end
		return roomRemote
	end },
	script = { Parent = { WaitForChild = function(_, name) return { Name = name } end } },
	require = function(module) return assert(modules[module.Name], module.Name) end,
	print = function() end,
}
local Service = luau.load(fs.readFile("src/server/MatchRoomService.luau"),
	{ environment = environment })()
Service.start()
local count = 0
local function check(value, message) assert(value, message); count += 1 end
local function action(player, name, first, second)
	roomRemote.OnServerEvent:Fire(player, name, first, second)
end
local function latest(player, name)
	for index = #(roomRemote.messages[player] or {}), 1, -1 do
		local message = roomRemote.messages[player][index]
		if message.action == name then return message.data end
	end
end
local function browse(player) action(player, "Browse", "Driver01", "Kart01") end
browse(a); action(a, "Create")
local roomA = latest(a, "Snapshot").room.id
browse(c); action(c, "Create")
local roomB = latest(c, "Snapshot").room.id
check(roomA ~= roomB and #latest(b, "Snapshot").rooms == 2, "two rooms visible")
browse(b); action(b, "Join", roomA)
browse(d); action(d, "Join", roomB)
check(#latest(a, "Snapshot").room.members == 2 and #latest(c, "Snapshot").room.members == 2,
	"members stay in separate rooms")
action(b, "Start")
check(#launches == 0, "non-host cannot start")
action(a, "Invite", e.UserId)
check(latest(e, "Invite").roomId == roomA and latest(e, "Invite").trackId == "Track01Race",
	"invite identifies originating room")
action(a, "Leave")
action(e, "AcceptInvite", "Driver01", "Kart01")
check(latest(e, "Error") == "INVITE EXPIRED" and latest(b, "Snapshot").room.hostUserId == b.UserId,
	"host departure transfers authority and invalidates stale invite")
action(b, "Start")
check(#launches == 1 and launches[1].payload.roomId == roomA
	and #launches[1].group == 1, "new host starts one-player Base race")
check(#latest(c, "Snapshot").room.members == 2 and latest(c, "Snapshot").room.state == "WAITING",
	"launching Room A does not affect Room B")
action(c, "Invite", e.UserId)
action(e, "AcceptInvite", "Driver01", "Kart01")
check(#latest(c, "Snapshot").room.members == 3, "valid invite joins only Room B")
browse(f); action(f, "Join", roomB)
check(#launches == 2 and launches[2].payload.roomId == roomB
	and #launches[2].group == 4, "fourth member auto-launches one shared group")
check(#latest(g, "Snapshot").rooms == 2
	and latest(g, "Snapshot").rooms[1].state == "STARTING",
	"launched rooms remain in active browser")
browse(h); action(h, "Join", roomB)
check(#launches == 2, "closed room rejects further joins")
check(latest(h, "Error") == "ROOM UNAVAILABLE", "active room rejects current-race JOIN")
browse(g); action(g, "Queue", roomA)
check(latest(g, "Snapshot").room.membershipKind == "QUEUED"
	and map.values[roomA].queued[1].userId == g.UserId, "queue targets active room")
action(g, "Queue", roomB)
check(#map.values[roomB].queued == 0, "queued racer cannot enter a second room")
action(g, "CancelQueue")
check(#map.values[roomA].queued == 0, "queue cancellation removes entry")
browse(g); action(g, "Queue", roomA)
map.values[roomA].state = "ROUND_COMPLETE"
local sharedDirectory = modules.ActiveMatchDirectory.new(map)
local nextRound = assert(sharedDirectory:claimNext(roomA, map.values[roomA].matchId,
	"match-guid-next", "next-round-code", "private-next", {}))
check(nextRound.launchRoster[1].userId == g.UserId, "queued racer claimed for next round")
local stopped = pcall(background[1])
check(not stopped and #launches == 3 and launches[3].group[1] == g
	and launches[3].accessCode == "next-round-code",
	"HUB polling sends queued racer to the claimed reserved server")
failLaunch = true
action(h, "Create")
local roomC = latest(h, "Snapshot").room.id
action(h, "Start")
check(map.values[roomC].state == "WAITING" and latest(h, "Snapshot").room.state == "WAITING",
	"complete initial launch failure restores room and host membership")
check(latest(h, "Error") == "RACE SERVER UNAVAILABLE - PLEASE TRY AGAIN",
	"failed group launch displays retry error")
print(string.format("PASS: %d MatchRoom RemoteEvent checks", count))
