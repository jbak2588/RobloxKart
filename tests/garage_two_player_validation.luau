-- lune run tests/garage_two_player_validation.luau
-- HUB Base Circuit uses in-memory rooms; no Garage kart is allocated.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Registry = luau.load(fs.readFile("src/server/MatchRoomRegistry.luau"))()
local count = 0
local function check(condition, message)
	assert(condition, message)
	count += 1
end

local rooms = Registry.new("Track01Race", 4)
local alpha = assert(rooms:create(1, "Driver01", "Kart01"))
local beta = assert(rooms:create(2, "Driver02", "Kart02"))
check(alpha.id ~= beta.id and #rooms:snapshot() == 2, "independent rooms coexist")
check(rooms:roomFor(1) == alpha and rooms:roomFor(2) == beta, "one membership per user")
check(rooms:join(beta.id, 1, "Driver01", "Kart01") == nil, "duplicate membership rejected")
check(rooms:join(alpha.id, 3, "Driver01", "Kart01") == alpha, "join first room")
check(rooms:join(beta.id, 4, "Driver01", "Kart01") == beta, "join second room")
check(#alpha.members == 2 and #beta.members == 2, "room counts independent")
check(rooms:launch(alpha.id, 3) == nil, "only host can launch")
rooms:leave(1)
check(alpha.hostUserId == 3 and rooms:roomFor(1) == nil, "host transfers to earliest remaining member")
check(rooms:launch(alpha.id, 3) == alpha and alpha.state == "LAUNCHING", "new host launches")
check(rooms:join(alpha.id, 5, "Driver01", "Kart01") == nil, "launching room closed to joins")
check(#rooms:snapshot() == 1 and rooms:snapshot()[1].id == beta.id, "browser hides launching room")
rooms:leave(3)
check(rooms.rooms[alpha.id] == nil and rooms:roomFor(3) == nil, "empty room removed")
rooms:join(beta.id, 5, "Driver01", "Kart01")
rooms:join(beta.id, 6, "Driver01", "Kart01")
check(#beta.members == 4 and rooms:join(beta.id, 7, "Driver01", "Kart01") == nil,
	"four racer limit enforced")
rooms:leave(2)
check(beta.hostUserId == 4, "second room host transfers independently")
print(string.format("PASS: %d MatchRoom registry checks", count))
