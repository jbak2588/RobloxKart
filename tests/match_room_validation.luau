-- lune run tests/match_room_validation.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Registry = luau.load(fs.readFile("src/server/MatchRoomRegistry.luau"))()
local count = 0
local function check(value, message) assert(value, message); count += 1 end

local nextId = 0
local function testId()
	nextId += 1
	return "test-room-" .. nextId
end
local hub = Registry.new("Track01Race", 4, testId)
local a = assert(hub:create(1, "Driver01", "Kart01"))
local b = assert(hub:create(5, "Driver02", "Kart02"))
local c = assert(hub:create(8, "Driver01", "Kart01"))
for _, userId in { 2, 3, 4 } do assert(hub:join(a.id, userId, "Driver01", "Kart01")) end
for _, userId in { 6, 7 } do assert(hub:join(b.id, userId, "Driver01", "Kart01")) end
assert(hub:join(c.id, 9, "Driver01", "Kart01"))
check(#a.members == 4 and #b.members == 3 and #c.members == 2, "three rooms hold independent rosters")
check(#hub:snapshot() == 3, "three waiting rooms visible")
check(hub:roomFor(10) == nil and hub:roomFor(11) == nil and hub:roomFor(12) == nil,
	"three Garage users remain unassigned")
check(hub:join(b.id, 2, "Driver01", "Kart01") == nil, "member cannot join another room")
check(hub:join(a.id, 10, "Driver01", "Kart01") == nil, "fifth racer rejected")
check(hub:launch(a.id, 2) == nil, "non-host cannot start")
check(hub:launch(a.id, 1) == a, "Room A launches")
check(#b.members == 3 and #c.members == 2 and b.state == "WAITING" and c.state == "WAITING",
	"Room A launch leaves B and C unchanged")
check(#hub:snapshot() == 2, "launching A hidden from browser")
check(hub:launch(b.id, 5) == b and c.state == "WAITING", "Room B launches independently")
for _, userId in { 1, 2, 3, 4, 5, 6, 7 } do hub:leave(userId) end
check(hub.rooms[a.id] == nil and hub.rooms[b.id] == nil and hub.rooms[c.id] == c,
	"departed race rooms removed, Room C stays available")
check(#hub:snapshot() == 1 and hub:snapshot()[1].id == c.id,
	"browser retains only Room C")
check(hub:join(c.id, 10, "Driver01", "Kart01") == c, "Garage user may join unaffected room")
hub:leave(8)
check(c.hostUserId == 9 and c.members[1].joinOrder < c.members[2].joinOrder,
	"host transfer follows earliest join order")
hub:leave(9); hub:leave(10)
check(#hub:snapshot() == 0 and hub.rooms[c.id] == nil, "last departure deletes room")
for size = 1, 3 do
	local standalone = Registry.new("Track01Race", 4, testId)
	local room = assert(standalone:create(100, "Driver01", "Kart01"))
	for index = 2, size do assert(standalone:join(room.id, 99 + index, "Driver01", "Kart01")) end
	check(standalone:launch(room.id, 100) == room, "host may start at " .. size .. "/4")
end
print(string.format("PASS: %d concurrent MatchRoom checks", count))
