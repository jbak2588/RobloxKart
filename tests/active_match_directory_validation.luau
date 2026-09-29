-- lune run tests/active_match_directory_validation.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local now = 1000
local map = { values = {}, expires = {} }
function map:SetAsync(key, value, ttl)
	self.values[key] = value; self.expires[key] = now + ttl
end
function map:GetAsync(key)
	if self.expires[key] and self.expires[key] <= now then
		self.values[key] = nil; self.expires[key] = nil
	end
	return self.values[key]
end
function map:UpdateAsync(key, transform, ttl)
	local changed = transform(self:GetAsync(key))
	if changed then self:SetAsync(key, changed, ttl) end
	return changed
end
function map:RemoveAsync(key) self.values[key] = nil; self.expires[key] = nil end
function map:GetRangeAsync()
	local rows = {}
	for key in self.values do
		local value = self:GetAsync(key)
		if value then table.insert(rows, { key = key, value = value }) end
	end
	return rows
end
local Directory = luau.load(fs.readFile("src/server/ActiveMatchDirectory.luau"),
	{ environment = { Enum = { SortDirection = { Ascending = "Ascending" } } } })()
local directory = Directory.new(map, function() return now end)
local count = 0
local function check(value, message) assert(value, message); count += 1 end
local function member(id)
	return { userId = id, name = "Racer" .. id, driverId = "Driver01", kartId = "Kart01",
		hubJobId = "hub-a", queuedAt = now }
end
local roomA = "guid-room-aaaaaaaa"
local roomB = "guid-room-bbbbbbbb"
directory:create({ id = roomA, trackId = "Track01Race", hostUserId = 1,
	hostName = "Racer1", ownerJobId = "hub-a", maxPlayers = 4, members = { member(1) } })
directory:create({ id = roomB, trackId = "Track01Race", hostUserId = 9,
	hostName = "Racer9", ownerJobId = "hub-b", maxPlayers = 4, members = { member(9) } })
check(#directory:list() == 2 and directory:get(roomA).state == "WAITING", "two global waiting rooms")
directory:joinWaiting(roomA, member(2))
check(directory:get(roomA).currentRacers == 2 and directory:get(roomB).currentRacers == 1,
	"membership updates one room only")
directory:leaveWaiting(roomA, 1)
check(directory:get(roomA).hostUserId == 2, "earliest remaining member becomes host")
check(directory:initialLaunch(roomA, 1, "match-a", "access-secret", "private-a") == nil,
	"former host cannot launch")
local active = assert(directory:initialLaunch(roomA, 2, "match-a", "access-secret", "private-a"))
check(active.state == "STARTING" and active.roundId == 1 and active.currentUserIds[1] == 2,
	"launch captures first round roster")
check(directory:display(active).reservedServerAccessCode == nil,
	"client projection hides reserved access code")
directory:raceState(roomA, "match-a", "RACING", 1, "private-a")
check(directory:get(roomA).state == "RACING" and directory:get(roomB).state == "WAITING",
	"active race remains visible without blocking another room")
directory:raceState(roomA, "match-a", "FINISHING", 1)
check(directory:display(directory:get(roomA)).state == "FINISHING",
	"finishing room remains visible")
directory:raceState(roomA, "match-a", "STARTING", 1)
check(directory:get(roomA).state == "FINISHING", "stale state update cannot regress race")
directory:queue(roomA, member(3)); directory:queue(roomA, member(4)); directory:queue(roomA, member(5))
check(#directory:get(roomA).queued == 3 and directory:queue(roomA, member(3)) == nil,
	"queue accepts unique members in FIFO order")
directory:cancelQueue(roomA, 4)
check(directory:get(roomA).queued[1].userId == 3 and directory:get(roomA).queued[2].userId == 5,
	"cancel removes only selected queue member")
directory:raceState(roomA, "match-a", "ROUND_COMPLETE", 1)
local nextRound = assert(directory:claimNext(roomA, "match-a", "match-b", "next-secret",
	"private-b", { member(2) }))
check(nextRound.state == "STARTING" and nextRound.roundId == 2
	and nextRound.launchRoster[1].userId == 2 and nextRound.launchRoster[2].userId == 3
	and nextRound.launchRoster[3].userId == 5, "rematch priority then FIFO queue")
check(#nextRound.queued == 0 and nextRound.currentRacers == 3,
	"claimed racers leave queue and define next round count")
directory:raceState(roomA, "match-b", "ROUND_COMPLETE", 3)
for userId = 6, 11 do directory:queue(roomA, member(userId)) end
local thirdRound = assert(directory:claimNext(roomA, "match-b", "match-c", "third-secret",
	"private-c", { member(2) }))
check(#thirdRound.launchRoster == 4 and thirdRound.launchRoster[1].userId == 2
	and thirdRound.launchRoster[2].userId == 6 and thirdRound.launchRoster[4].userId == 8,
	"next round caps roster at four with rematch priority")
check(#thirdRound.queued == 3 and thirdRound.queued[1].userId == 9,
	"excess queue remains in FIFO order")
check(directory:raceState(roomA, "match-a", "RACING", 1) == nil,
	"old reserved server cannot overwrite next round")
local idleRoom = "guid-room-idle"
directory:create({ id = idleRoom, trackId = "Track01Race", hostUserId = 20,
	hostName = "Racer20", ownerJobId = "hub-c", maxPlayers = 4, members = { member(20) } })
directory:initialLaunch(idleRoom, 20, "idle-match", "idle-code", "private-idle")
directory:raceState(idleRoom, "idle-match", "ROUND_COMPLETE", 0)
check(directory:closeIfIdle(idleRoom, "idle-match") and directory:get(idleRoom) == nil,
	"finished room without racers or queue is removed")
local fullRoom = "guid-room-full"
directory:create({ id = fullRoom, trackId = "Track01Race", hostUserId = 30,
	hostName = "Racer30", ownerJobId = "hub-d", maxPlayers = 4,
	members = { member(30), member(31), member(32), member(33) } })
directory:initialLaunch(fullRoom, 30, "full-match", "full-code", "private-full")
directory:raceState(fullRoom, "full-match", "RACING", 4)
check(directory:display(directory:get(fullRoom)).count == 4,
	"full 4/4 racing room remains visible")
now += Directory.TTL_SECONDS + 1
check(directory:get(roomA) == nil and directory:get(roomB) == nil and directory:get(fullRoom) == nil,
	"stale records expire without heartbeat")
local paged = { GetRangeAsync = function(_, _, pageSize, bound)
	local rows = {}
	local start = if bound then tonumber(bound.key) + 1 else 1
	for index = start, math.min(start + pageSize - 1, 201) do
		table.insert(rows, { key = tostring(index), sortKey = index,
			value = { roomId = tostring(index), state = "RACING", queued = {} } })
	end
	return rows
end }
check(#Directory.new(paged):list() == 201,
	"browser pagination includes more than the first hundred active rooms")
print(string.format("PASS: %d ActiveMatchDirectory checks", count))
