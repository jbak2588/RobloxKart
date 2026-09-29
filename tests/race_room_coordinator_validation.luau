-- lune run tests/race_room_coordinator_validation.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local now = 1000
local map = { values = {} }
function map:SetAsync(key, value) self.values[key] = value end
function map:GetAsync(key) return self.values[key] end
function map:UpdateAsync(key, transform)
	local value = transform(self.values[key])
	if value then self.values[key] = value end
	return value
end
function map:RemoveAsync(key) self.values[key] = nil end
local Directory = luau.load(fs.readFile("src/server/ActiveMatchDirectory.luau"),
	{ environment = { Enum = { SortDirection = { Ascending = "Ascending" } } } })()
local directory = Directory.new(map, function() return now end)
local function member(userId)
	return { userId = userId, driverId = "Driver01", kartId = "Kart01", name = "Racer" .. userId }
end
local roomId = "guid-room-aaaaaaaa"
directory:create({ id = roomId, trackId = "Track01Race", hostUserId = 1,
	hostName = "Racer1", ownerJobId = "hub", maxPlayers = 4,
	members = { member(1), member(2) } })
directory:initialLaunch(roomId, 1, "match-original", "original-code", "private-original")
directory:raceState(roomId, "match-original", "ROUND_COMPLETE", 2)
directory:queue(roomId, member(3)); directory:queue(roomId, member(4))
local player = { UserId = 1, Parent = nil, attrs = {
	SelectedDriverId = "Driver01", SelectedKartId = "Kart01" } }
function player:GetAttribute(name) return self.attrs[name] end
local players = { GetPlayerByUserId = function(_, userId) return if userId == 1 then player else nil end }
player.Parent = players
local launches = {}
local modules = {
	ActiveMatchDirectory = Directory,
	RaceLaunchPayload = { buildMatch = function(matchId, id, roster, trackId)
		local ids = {}
		for _, selected in roster do table.insert(ids, selected.userId) end
		return { matchId = matchId, roomId = id, trackId = trackId,
			participantUserIds = ids, selections = {} }
	end },
	RaceLaunchService = { launchMatch = function(group, payload, _, accessCode, preserve)
		table.insert(launches, { group = group, payload = payload,
			accessCode = accessCode, preserve = preserve })
		return true
	end },
}
local services = { Players = players,
	MemoryStoreService = { GetSortedMap = function() return map end },
	TeleportService = { ReserveServerAsync = function() return "next-code", "private-next" end },
	HttpService = { GenerateGUID = function() return "match-next" end } }
local environment = {
	game = { PlaceId = 123, PrivateServerId = "private-original",
		GetService = function(_, name) return assert(services[name], name) end },
	script = { Parent = { WaitForChild = function(_, name) return { Name = name } end } },
	require = function(module) return assert(modules[module.Name], module.Name) end,
	task = { spawn = function() end },
	warn = function() end,
}
local Coordinator = luau.load(fs.readFile("src/server/RaceRoomCoordinator.luau"),
	{ environment = environment })()
local callbacks = Coordinator.start({ roomId = roomId, matchId = "match-original",
	trackId = "Track01Race" })
local count = 0
local function check(value, message) assert(value, message); count += 1 end
check(callbacks.onRoundReady({ player }), "rematch and queue claim next round")
local nextRecord = directory:get(roomId)
check(nextRecord.state == "STARTING" and nextRecord.roundId == 2
	and nextRecord.currentRacers == 3, "next round retains room identity with three racers")
check(nextRecord.launchRoster[1].userId == 1 and nextRecord.launchRoster[2].userId == 3
	and nextRecord.launchRoster[3].userId == 4, "rematch racer precedes FIFO queued racers")
check(#launches == 1 and #launches[1].group == 1
	and #launches[1].payload.participantUserIds == 3
	and launches[1].accessCode == "next-code" and launches[1].preserve,
	"old server teleports rematcher to shared new reservation")
callbacks.onRoomPhase("RACING", 1)
check(directory:get(roomId).matchId == "match-next" and directory:get(roomId).state == "STARTING",
	"old race cannot overwrite next round")
print(string.format("PASS: %d reserved next-round coordinator checks", count))
