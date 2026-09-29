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
	{ environment = { Enum = enum } })()
local Social = luau.load(fs.readFile("src/server/RoomSocialDirectory.luau"),
	{ environment = { Enum = enum } })()
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
	PrototypeWorld = { getKartContext = function() return context end },
	TrackCatalog = { Entries = { Track01Race = { GridSlots = {
		rb.CFrame.new(0, 0, 0), rb.CFrame.new(10, 0, 0),
		rb.CFrame.new(20, 0, 0), rb.CFrame.new(30, 0, 0) } } } } }
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
print(string.format("PASS: %d persistent room coordinator checks", count))
