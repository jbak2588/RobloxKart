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
local services = { Players = players, ReplicatedStorage = replicated,
	HttpService = { GenerateGUID = function() return "match-guid-12345" end } }
local modules = {
	TrackCatalog = { Entries = { Track01Race = { MaxPlayers = 4 } } },
	DriverCatalog = { Entries = { Driver01 = {} } },
	KartCatalog = { Entries = { Kart01 = {} } },
}
local Registry = luau.load(fs.readFile("src/server/MatchRoomRegistry.luau"))()
modules.MatchRoomRegistry = Registry
local launches = {}
modules.RaceLaunchPayload = { buildMatch = function(matchId, roomId, members, trackId)
	local ids = {}
	for _, member in members do table.insert(ids, member.userId) end
	return { matchId = matchId, roomId = roomId, trackId = trackId, participantUserIds = ids }
end }
modules.RaceLaunchService = { launchMatch = function(group, payload)
	table.insert(launches, { group = group, payload = payload })
	return true
end }
local environment = {
	game = { GetService = function(_, name) return assert(services[name], name) end },
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
check(#latest(g, "Snapshot").rooms == 0, "launching rooms hidden from browser")
action(h, "Join", roomB)
check(#launches == 2, "closed room rejects further joins")
print(string.format("PASS: %d MatchRoom RemoteEvent checks", count))
