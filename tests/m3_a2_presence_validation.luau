local fs = require("@lune/fs")
local luau = require("@lune/luau")
local now = 1000
local map = { values = {}, expires = {}, fail = false, publishedKeys = {}, removedKeys = {} }
function map:SetAsync(key, value, ttl)
	assert(type(key) == "string" and key ~= "", "MemoryStore key must be nonempty")
	table.insert(self.publishedKeys, key)
	self.values[key], self.expires[key] = value, now + ttl
end
function map:GetRangeAsync()
	if self.fail then error("MemoryStore unavailable") end
	local rows = {}
	for key, value in self.values do
		if self.expires[key] > now then table.insert(rows, { key = key, value = value }) end
	end
	return rows
end
function map:RemoveAsync(key)
	table.insert(self.removedKeys, key)
	self.values[key], self.expires[key] = nil, nil
end
local Presence = luau.load(fs.readFile("src/server/KDMServerPresence.luau"),
	{ environment = { Enum = { SortDirection = { Ascending = "Ascending" } }, warn = function() end } })()
local function player(leaving)
	return { GetAttribute = function(_, key) if key == "KDMRoutePending" and leaving then return "RACE_LAUNCH" end end }
end
local guidCalls = 0
local function guid() guidCalls += 1; return "abc-123" end
assert(Presence.resolveJobKey("real-job-123", false, guid) == "real-job-123" and guidCalls == 0)
assert(Presence.resolveJobKey("studio-real-job", true, guid) == "studio-real-job" and guidCalls == 0)
local studioKey = Presence.resolveJobKey("", true, guid)
assert(studioKey == "studio-abc-123" and guidCalls == 1)
assert(Presence.resolveJobKey("", false, guid) == "" and guidCalls == 1, "no synthetic production identity")
local studio = Presence.new(map, studioKey, "HUB", nil, function() return now end)
for _ = 1, 3 do studio:publish({ player() }) end
studio:remove()
assert(guidCalls == 1 and #map.publishedKeys == 3)
for _, key in map.publishedKeys do assert(key == studioKey) end
assert(map.removedKeys[1] == studioKey and map.values[studioKey] == nil)
assert(Presence.MAP_NAME == "KDM_ServerPresence_v1" and Presence.TTL_SECONDS == 30 and Presence.HEARTBEAT_SECONDS == 9)
local hub = Presence.new(map, "hub-a", "HUB", nil, function() return now end)
hub:publish({ player(), player(), player() })
local result = hub:aggregate()
assert(result.online == 3 and result.lobby == 3 and result.inRace == 0)
hub:publish({ player(), player(true), player() })
local race = Presence.new(map, "race-a", "RACE", "Track01Race", function() return now end)
race:publish({ player(), player(), player() })
result = hub:aggregate()
assert(result.online == 5 and result.lobby == 2 and result.inRace == 3)
local solo = Presence.new(map, "race-b", "RACE", "Track02", function() return now end)
solo:publish({ player() })
result = hub:aggregate()
assert(result.online == 6 and result.inRace == 4)
assert(result.accessCode == nil and result.admissionToken == nil)
map.fail = true
result = hub:aggregate()
assert(result.stale and result.online == 6)
map.fail = false
now += 31
result = hub:aggregate()
assert(result.online == 0 and result.lobby == 0 and result.inRace == 0)
print("M3-A2 server presence validation PASS")
