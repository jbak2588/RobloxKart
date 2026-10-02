-- lune run tests/race_launch_routing_validation.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local count = 0
local function check(value, label)
	assert(value, label)
	count += 1
end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback) table.insert(listeners, callback) end,
		Fire = function(_, ...) for _, callback in listeners do callback(...) end end,
	}
end
local function folder(name)
	return { Name = name, WaitForChild = function(_, child) return { Name = child } end }
end
local shared, server = folder("Shared"), folder("Server")
local players = { Name = "Players", PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end }
local teleport = { TeleportInitFailed = signal(), calls = {} }
function teleport:TeleportAsync(placeId, group, options)
	table.insert(self.calls, { placeId = placeId, group = group, options = options })
	if self.failNow then error("TeleportAsync failed") end
	return { PrivateServerId = if options then "private-id" else "",
		ReservedServerAccessCode = if options then "SECRET_CODE_MUST_NOT_LOG" else "" }
end
local services = {
	ReplicatedStorage = { WaitForChild = function(_, name) check(name == "Shared", "shared root"); return shared end },
	Players = players,
	TeleportService = teleport,
	HttpService = { GenerateGUID = function() return "guid-12345678" end },
	RunService = { studio = false, IsStudio = function(self) return self.studio end },
	MemoryStoreService = {},
}
local modules = {
	TrackCatalog = { Entries = {
		Track01 = { Id = "Track01", MatchType = "SOLO_PRACTICE", MinPlayers = 1, MaxPlayers = 1 },
		Track02 = { Id = "Track02", MatchType = "SOLO_PROTOTYPE", MinPlayers = 1, MaxPlayers = 1 },
		Track01Race = { Id = "Track01Race", MatchType = "PUBLIC_RACE", MinPlayers = 1, MaxPlayers = 4 },
	} },
	DriverCatalog = { Entries = { Driver01 = {}, Driver02 = {} } },
	KartCatalog = { Entries = { Kart01 = {}, Kart02 = {} } },
	RaceMode = { resolve = function(trackId) return if trackId == "Track01" then "PRACTICE" else "RACE" end },
	ActiveMatchDirectory = {},
}
local delayed = {}
local warnings = {}
local logs = {}
local environment = {
	game = { PlaceId = 123456, GameId = 987654,
		GetService = function(_, name) return assert(services[name], name) end },
	Instance = { new = function(class)
		check(class == "TeleportOptions", "TeleportOptions allocated")
		return { SetTeleportData = function(self, payload) self.payload = payload end }
	end },
	task = { delay = function(_, callback) table.insert(delayed, callback) end },
	print = function(message) table.insert(logs, message) end,
	warn = function(message) table.insert(warnings, message) end,
}
local function load(path, name)
	local env = table.clone(environment)
	env.script = { Parent = server }
	env.require = function(module) return assert(modules[module.Name], module.Name) end
	local result = luau.load(fs.readFile(path), { debugName = path, environment = env })()
	modules[name] = result
	return result
end
local Payload = load("src/server/RaceLaunchPayload.luau", "RaceLaunchPayload")
local Runtime = load("src/server/ServerRuntime.luau", "ServerRuntime")
local Arrival = load("src/server/RaceArrivalPlan.luau", "RaceArrivalPlan")
local Launch = load("src/server/RaceLaunchService.luau", "RaceLaunchService")
check(Runtime.getRole() == "HUB" and Runtime.isHub(), "runtime defaults to HUB")
Runtime.setRole("RACE")
check(Runtime.getRole() == "RACE" and Runtime.isRace(), "runtime exposes RACE role")
Runtime.setRole("HUB")
local player = { UserId = 42, Parent = players, attrs = { RaceState = "GARAGE" } }
function player:SetAttribute(name, value) self.attrs[name] = value end
function player:GetAttribute(name) return self.attrs[name] end
local function build(trackId)
	return assert(Payload.buildSolo("match-12345678", player, trackId, "Driver02", "Kart02"))
end
for _, trackId in { "Track01", "Track02" } do
	local payload = build(trackId)
	local valid, track = Payload.validate(payload, true)
	check(valid and track.Id == trackId, trackId .. " payload validates")
	check(payload.schema == "KDM_RACE_V1" and payload.role == "RACE" and payload.source == "HUB"
		and payload.matchId == "match-12345678", "versioned server match payload")
	check(payload.participantUserIds[1] == 42 and payload.selections["42"].driverId == "Driver02"
		and payload.selections["42"].kartId == "Kart02", "participant and selection round-trip")
	local plan = Arrival.forPlayer(payload, 42)
	check(plan and plan.trackId == trackId and plan.maxPlayers == 1 and plan.gridSlot == 1
		and plan.driverId == "Driver02" and plan.kartId == "Kart02", "arrival plan restores selection/grid")
	check(Arrival.forPlayer(payload, 43) == nil, "other user cannot claim solo arrival")
	local joinData = { SourcePlaceId = 123456, SourceGameId = 987654, TeleportData = payload }
	local publicRole, _, publicReason = Runtime.resolve("", 0, joinData, 987654, 42)
	check(publicRole == "HUB" and publicReason == "PUBLIC_SERVER", "public context remains HUB")
	local role, resolved, reason = Runtime.resolve("reserved-id", 0, joinData, 987654, 42)
	check(role == "RACE" and resolved == payload and reason == "VALID_KDM_RACE",
		"same-experience reserved launch is RACE")
	local otherPlaceRole, _, otherPlaceReason = Runtime.resolve("reserved-id", 0,
		{ SourcePlaceId = 9, SourceGameId = 987654, TeleportData = payload }, 987654, 42)
	check(otherPlaceRole == "RACE" and otherPlaceReason == "VALID_KDM_RACE",
		"different source Place in same Experience is accepted")
	local wrongGameRole, _, wrongGameReason = Runtime.resolve("reserved-id", 0,
		{ SourcePlaceId = 123456, SourceGameId = 8, TeleportData = payload }, 987654, 42)
	check(wrongGameRole == "HUB" and wrongGameReason == "WRONG_SOURCE_GAME",
		"foreign Experience is rejected")
	local vipRole, _, vipReason = Runtime.resolve("vip-id", 81, joinData, 987654, 42)
	check(vipRole == "HUB" and vipReason == "PLAYER_OWNED_PRIVATE_SERVER",
		"VIP server remains HUB even with launch data")
end
local invalid = build("Track01")
invalid.schema = "KDM_RACE_V0"
check(not Payload.validate(invalid, true), "old schema rejected")
invalid = build("Track01")
invalid.trackId = "MissingTrack"
check(not Payload.validate(invalid, true), "unknown track rejected")
invalid = build("Track01")
invalid.participantUserIds = {}
check(not Payload.validate(invalid, true), "missing participant rejected")
invalid = build("Track01")
invalid.participantUserIds = { 42, 42 }
check(not Payload.validate(invalid, true), "duplicate participant rejected")
-- Build a public-shaped payload directly; M3-A0 launch still forbids this track.
invalid = build("Track01")
invalid.trackId = "Track01Race"
invalid.participantUserIds = { 42, 42 }
check(not Payload.validate(invalid, false), "duplicate IDs rejected independent of solo count")
invalid = build("Track01")
invalid.selections["42"].kartId = "MissingKart"
check(not Payload.validate(invalid, true), "invalid kart rejected")
invalid = build("Track01")
invalid.selections["42"].driverId = "MissingDriver"
check(not Payload.validate(invalid, true), "invalid driver rejected")
invalid = build("Track01")
invalid.participantUserIds = { 42, 43 }
invalid.selections["43"] = { driverId = "Driver01", kartId = "Kart01" }
check(not Payload.validate(invalid, true), "solo capacity enforced")
check(Payload.buildSolo("match-12345678", player, "Track01Race", "Driver01", "Kart01") == nil,
	"Base Circuit reserved launch deferred")
local invalidRole, _, invalidReason = Runtime.resolve("reserved-id", 0,
	{ SourceGameId = 987654, TeleportData = invalid }, 987654, 42)
check(invalidRole == "HUB" and invalidReason == "INVALID_PAYLOAD",
	"invalid reserved context cannot become RACE")
local _, _, noJoinReason = Runtime.resolve("reserved-id", 0, nil, 987654, 42)
check(noJoinReason == "NO_JOIN_DATA", "missing join data reason")
local _, _, missingDataReason = Runtime.resolve("reserved-id", 0, { SourceGameId = 987654 }, 987654, 42)
check(missingDataReason == "MISSING_TELEPORT_DATA", "missing teleport data reason")
local _, _, wrongUserReason = Runtime.resolve("reserved-id", 0,
	{ SourceGameId = 987654, TeleportData = build("Track01") }, 987654, 43)
check(wrongUserReason == "USER_NOT_PARTICIPANT", "nonparticipant reason")

players.GetPlayers = function() return { player } end
Launch.start()
check(player:GetAttribute("KDMRoutePending") == "", "HUB player starts without routing transition")
local joiningPlayer = { UserId = 99, Parent = players, attrs = {} }
function joiningPlayer:SetAttribute(name, value) self.attrs[name] = value end
function joiningPlayer:GetAttribute(name) return self.attrs[name] end
players.PlayerAdded:Fire(joiningPlayer)
check(joiningPlayer:GetAttribute("KDMRoutePending") == "", "new HUB player starts without routing transition")
local failed = 0
check(Launch.launchSolo(player, "Track02", "Driver02", "Kart02", function() failed += 1 end),
	"server launches V2")
check(player:GetAttribute("KDMRoutePending") == "RACE_LAUNCH", "solo launch publishes routing transition")
local call = teleport.calls[#teleport.calls]
check(call.placeId == 123456 and call.group[1] == player and call.options.ShouldReserveServer == true,
	"same PlaceId receives new reserved server")
check(call.options.payload.trackId == "Track02" and call.options.payload.matchId == "guid-12345678",
	"server GUID and selected track transmitted")
teleport.TeleportInitFailed:Fire(player, "Failure", "network error", 123456, {})
check(failed == 1 and player:GetAttribute("RaceState") == "GARAGE"
	and player:GetAttribute("RaceEntryError") ~= "" and player:GetAttribute("KDMRoutePending") == "",
	"failed launch restores Garage, clears transition and shows error")
check(string.find(warnings[#warnings], "result=Failure", 1, true) ~= nil
	and string.find(warnings[#warnings], "network error", 1, true) ~= nil,
	"TeleportInitFailed logs result and engine error on server")
check(string.find(table.concat(logs, "\n"), "teleport accepted", 1, true) ~= nil
	and not string.find(table.concat(logs, "\n"), "SECRET_CODE_MUST_NOT_LOG", 1, true),
	"accepted teleport logs presence without access code")
check(player:GetAttribute("SelectedDriverId") == "Driver02"
	and player:GetAttribute("SelectedKartId") == "Kart02"
	and player:GetAttribute("SelectedTrackId") == "Track02", "failure preserves selections")
player:SetAttribute("RaceState", "FINISHED")
check(Launch.returnToHub(player), "Result GARAGE requests public HUB")
check(player:GetAttribute("KDMRoutePending") == "HUB_RETURN", "HUB return publishes routing transition")
call = teleport.calls[#teleport.calls]
check(call.placeId == 123456 and call.options == nil, "return omits reserved-server option")
teleport.TeleportInitFailed:Fire(player, "Failure", "return error", 123456, {})
check(player:GetAttribute("RaceState") == "FINISHED" and player:GetAttribute("RaceEntryError") ~= ""
	and player:GetAttribute("KDMRoutePending") == "",
	"failed HUB return preserves result for retry")
player:SetAttribute("RaceState", "GARAGE")
teleport.failNow = true
check(not Launch.launchSolo(player, "Track01", "Driver01", "Kart01", function() failed += 1 end)
	and failed == 2 and player:GetAttribute("RaceEntryError") ~= "",
	"synchronous teleport exception restores retryable Garage")
check(string.find(warnings[#warnings], "teleport request failed", 1, true) ~= nil,
	"request exception logged with route context")
teleport.failNow = false
check(Launch.launchSolo(player, "Track01", "Driver01", "Kart01", function() failed += 1 end),
	"failure clears pending reservation for retry")
player.Parent = nil
players.PlayerRemoving:Fire(player)
for _, callback in delayed do callback() end
check(failed == 2, "successful departure clears pending watchdog without false failure")
player.Parent = players
services.RunService.studio = true
teleport.failNow = true
Launch.launchSolo(player, "Track01", "Driver01", "Kart01", function() failed += 1 end)
check(player:GetAttribute("RaceEntryError") == "TELEPORT TEST REQUIRES PUBLISHED ROBLOX CLIENT",
	"Studio teleport displays development-only guidance")
teleport.failNow = false
services.RunService.studio = false

local members = {
	{ userId = 42, driverId = "Driver02", kartId = "Kart02" },
	{ userId = 99, driverId = "Driver01", kartId = "Kart01" },
}
local matchPayload = assert(Payload.buildMatch("group-match-123", "base-room-123", members, "Track01Race"))
for rosterSize = 1, 4 do
	local roster = {}
	for index = 1, rosterSize do
		table.insert(roster, { userId = 100 + index, driverId = "Driver01", kartId = "Kart01" })
	end
	local generated = assert(Payload.buildMatch("group-match-123", "base-room-123", roster, "Track01Race"))
	check(Payload.validate(generated, false), "Base payload supports " .. rosterSize .. " racers")
	for index = rosterSize, 1, -1 do
		local plan = Arrival.forPlayer(generated, 100 + index)
		check(plan and plan.gridSlot == index and plan.readyOrder == index,
			"grid order remains payload order across reversed arrival")
	end
end
local oversized = {}
for index = 1, 5 do
	table.insert(oversized, { userId = 100 + index, driverId = "Driver01", kartId = "Kart01" })
end
check(Payload.buildMatch("group-match-123", "base-room-123", oversized, "Track01Race") == nil,
	"fifth Base racer rejected")
check(Payload.buildMatch("group-match-123", "base-room-123", { members[1], members[1] }, "Track01Race") == nil,
	"duplicate group user rejected")
check(Payload.buildMatch("group-match-123", "base-room-123",
	{ { userId = 42, driverId = "Driver02", kartId = "MissingKart" } }, "Track01Race") == nil,
	"missing group selection rejected")
check(Payload.validate(matchPayload, false), "multiplayer payload validates")
check(not Payload.validate(matchPayload, true), "multiplayer payload cannot masquerade as Solo")
check(Arrival.forPlayer(matchPayload, 99).gridSlot == 2
	and Arrival.forPlayer(matchPayload, 99).readyOrder == 2, "ordered payload assigns second grid slot")
local matchRole, _, matchReason = Runtime.resolve("reserved-id", 0,
	{ SourceGameId = 987654, TeleportData = matchPayload }, 987654, 99)
check(matchRole == "RACE" and matchReason == "VALID_KDM_RACE", "listed group member enters reserved RACE")
check(not Payload.validate({ schema = matchPayload.schema, role = matchPayload.role,
	source = matchPayload.source, matchId = matchPayload.matchId, trackId = matchPayload.trackId,
	participantUserIds = matchPayload.participantUserIds, selections = matchPayload.selections }, false),
	"public race requires room identity")
local groupFailures = {}
check(Launch.launchMatch({ player, joiningPlayer }, matchPayload, function(failedPlayer)
	table.insert(groupFailures, failedPlayer.UserId)
end), "group launch accepted")
call = teleport.calls[#teleport.calls]
check(#call.group == 2 and call.group[1] == player and call.group[2] == joiningPlayer
	and call.options.ShouldReserveServer and call.options.payload == matchPayload,
	"one TeleportAsync transports ordered group with shared payload")
check(player:GetAttribute("KDMRoutePending") == "RACE_LAUNCH"
	and joiningPlayer:GetAttribute("KDMRoutePending") == "RACE_LAUNCH", "all group members show transition")
teleport.TeleportInitFailed:Fire(joiningPlayer, "Failure", "second player failed", 123456, {})
check(#groupFailures == 1 and groupFailures[1] == 99
	and joiningPlayer:GetAttribute("KDMRoutePending") == ""
	and player:GetAttribute("KDMRoutePending") == "RACE_LAUNCH",
	"per-player failure does not clear surviving participant")
player.Parent = nil
players.PlayerRemoving:Fire(player)
joiningPlayer.Parent = nil
players.PlayerRemoving:Fire(joiningPlayer)
player.Parent = players
joiningPlayer.Parent = players
teleport.failNow = true
local synchronousFailures = 0
check(not Launch.launchMatch({ player, joiningPlayer }, matchPayload, function()
	synchronousFailures += 1
end), "group request failure reported")
check(synchronousFailures == 2 and player:GetAttribute("KDMRoutePending") == ""
	and joiningPlayer:GetAttribute("KDMRoutePending") == "",
	"group request failure restores every HUB participant")
teleport.failNow = false
check(Launch.launchMatch({ joiningPlayer }, matchPayload, nil, "same-room-code"),
	"queued roster subset launches to existing reservation")
call = teleport.calls[#teleport.calls]
check(call.group[1] == joiningPlayer and call.options.ReservedServerAccessCode == "same-room-code"
	and call.options.ShouldReserveServer ~= true, "existing reservation uses access code")
teleport.TeleportInitFailed:Fire(joiningPlayer, "Failure", "queued launch failed", 123456, {})
player:SetAttribute("RaceState", "FINISHED")
check(Launch.launchMatch({ player }, matchPayload, nil, "next-round-code", true),
	"rematch voter requests next reserved server")
teleport.TeleportInitFailed:Fire(player, "Failure", "rematch launch failed", 123456, {})
check(player:GetAttribute("RaceState") == "FINISHED" and player:GetAttribute("KDMRoutePending") == "",
	"failed rematch teleport preserves result and Garage exit")
player:SetAttribute("RaceState", "GARAGE")

-- Exercise the production arrival path with simulated server objects.
local CF, V = rb.CFrame, rb.Vector3
modules.TrackCatalog.Entries.Track01.GridSlots = { CF.new(10, 0, 20) }
modules.TrackCatalog.Entries.Track02.GridSlots = { CF.new(30, 0, 40) }
modules.DriverAppearance = { applyToCharacter = function(character, driver) character.appliedDriver = driver end }
modules.KartVisualFactory = { applyAppearance = function(visual, kart) visual.appliedKart = kart end }
local appearance = {}
modules.DriverCatalog.Entries.Driver02 = appearance
local kartSelection = {}
modules.KartCatalog.Entries.Kart02 = kartSelection
local contextCount = 0
local seats = {}
modules.PrototypeWorld = { acquireKartContext = function(_, spawn, kartId)
	check(kartId=="Kart02", "arrival forwards validated selected kart to creation")
	contextCount += 1
	local visual = { IsA = function(_, class) return class == "Model" end }
	local kart = { FindFirstChild = function(_, name) return if name == "Visual" then visual else nil end,
		PivotTo = function(self, frame) self.pivot = frame end }
	local seat = { CFrame = CF.identity, Sit = function(self, humanoid)
		self.Occupant = humanoid; humanoid.SeatPart = self
	end }
	table.insert(seats, seat)
	return { kart = kart, seat = seat, visual = visual,
		setSpawnCFrame = function(self, frame) self.spawn = frame end }
end, releaseKartContext = function() end }
modules.RaceController = { isRosterLocked = function() return false end }
local baseplate = { Position = V.new(0, -10, 0), Size = V.new(2048, 20, 2048),
	IsA = function(_, class) return class == "BasePart" end }
services.Workspace = {
	FindFirstChild = function(_, name) return if name == "Baseplate" then baseplate else nil end,
	WaitForChild = function(_, name) return if name == "Prototype" then {} else nil end,
}
players.PlayerAdded = signal()
players.GetPlayers = function() return { player } end
local humanoid = { Health = 100 }
local root = { Anchored = true }
local character = { WaitForChild = function(_, name)
	return if name == "Humanoid" then humanoid else root
end, PivotTo = function(self, frame) self.pivot = frame end }
player.Character = character
environment.CFrame = CF
environment.task = { spawn = function(callback, argument) callback(argument) end,
	delay = function(_, callback) table.insert(delayed, callback) end,
	wait = function() end }
for _, trackId in { "Track01", "Track02" } do
	local payload = build(trackId)
	local initialJoinData = { SourcePlaceId = 999, SourceGameId = 987654, TeleportData = payload }
	player.GetJoinData = function() return initialJoinData end
	local Bootstrap = load("src/server/RaceServerBootstrap.luau", "RaceServerBootstrap" .. trackId)
	check(Bootstrap.plan(payload, 42).trackId == trackId, "bootstrap plan selects " .. trackId)
	check(Bootstrap.start(payload, player, initialJoinData), "validated initial arrival starts")
	check(player:GetAttribute("SelectedTrackId") == trackId and player:GetAttribute("SelectedDriverId") == "Driver02"
		and player:GetAttribute("SelectedKartId") == "Kart02" and player:GetAttribute("RaceMaxPlayers") == 1
		and player:GetAttribute("GridSlot") == 1 and player:GetAttribute("RaceState") == "PRE_RACE",
		"arrival restores validated selections and grid for " .. trackId)
	check(seats[#seats].Occupant == humanoid and root.Anchored == false
		and character.appliedDriver == appearance, "arriving driver is styled and seated")
	local before = contextCount
	players.PlayerAdded:Fire(player)
	check(Bootstrap.start(payload, player, initialJoinData), "same match startup is idempotent")
	local otherMatch = build(trackId)
	otherMatch.matchId = "different-match-123"
	check(not Bootstrap.start(otherMatch, player, initialJoinData), "different match cannot restart reserved server")
	check(contextCount == before, "duplicate arrival/start does not create a second kart")
end
local checkPayload = build("Track01")
local Checker = load("src/server/RaceServerBootstrap.luau", "RaceServerBootstrapChecker")
local unlistedPlan, unlistedReason = Checker.checkArrival(checkPayload, { UserId = 43 }, player, 987654)
check(unlistedPlan == nil and unlistedReason == "USER_NOT_PARTICIPANT", "unlisted arrival reason")
local later = { UserId = 42, GetJoinData = function()
	return { SourceGameId = 987654, TeleportData = { matchId = "other-match" } }
end }
local laterPlan, laterReason = Checker.checkArrival(checkPayload, later, player, 987654)
check(laterPlan == nil and laterReason == "MATCH_ID_MISMATCH", "later arrival wrong MatchId reason")
later.GetJoinData = function() return { SourceGameId = 12, TeleportData = checkPayload } end
laterPlan, laterReason = Checker.checkArrival(checkPayload, later, player, 987654)
check(laterPlan == nil and laterReason == "WRONG_SOURCE_GAME", "later arrival wrong Experience reason")
later.GetJoinData = function() error("GetJoinData failed") end
laterPlan, laterReason = Checker.checkArrival(checkPayload, later, player, 987654)
check(laterPlan == nil and laterReason == "JOIN_DATA_UNAVAILABLE", "later arrival missing join data reason")
local roomArrival = assert(Payload.buildMatch(matchPayload.matchId, matchPayload.roomId,
	{ members[2] }, "Track01Race"))
roomArrival.admissionToken = "admission-token-99"
local roomRecord = { roomId = matchPayload.roomId, matchId = matchPayload.matchId,
	state = "WAITING", privateServerId = "room-private", raceJobId = "race-job",
	currentRacers = 1, stagedMembers = {
		{ userId = 42, driverId = "Driver02", kartId = "Kart02", arrived = true },
		{ userId = 99, driverId = "Driver01", kartId = "Kart01",
			admissionToken = "admission-token-99", admissionExpiresAt = os.time() + 60 },
	} }
local roomPlan = Checker.roomPlan(matchPayload, roomArrival, roomRecord, 99,
	"room-private", "race-job")
check(roomPlan and roomPlan.gridSlot == 2 and roomPlan.readyOrder == 2,
	"authorized late Room JOIN receives second staging slot")
local wrongToken = table.clone(roomArrival); wrongToken.admissionToken = "wrong-token-99"
check(Checker.roomPlan(matchPayload, wrongToken, roomRecord, 99,
	"room-private", "race-job") == nil, "forged Room admission token rejected")
local expiredRecord = table.clone(roomRecord)
expiredRecord.stagedMembers = { roomRecord.stagedMembers[1], table.clone(roomRecord.stagedMembers[2]) }
expiredRecord.stagedMembers[2].admissionExpiresAt = os.time() - 1
check(Checker.roomPlan(matchPayload, roomArrival, expiredRecord, 99,
	"room-private", "race-job") == nil, "expired Room admission rejected")
check(Checker.roomPlan(matchPayload, roomArrival, roomRecord, 99,
	"other-private", "race-job") == nil, "different reserved server rejected")
check(Checker.roomPlan(matchPayload, roomArrival, roomRecord, 99,
	"room-private", "other-job") == nil, "different active Room job rejected")
local racingRecord = table.clone(roomRecord); racingRecord.state = "RACING"
check(Checker.roomPlan(matchPayload, roomArrival, racingRecord, 99,
	"room-private", "race-job") == nil, "mid-race arrival rejected")
local wrongRoom = table.clone(roomRecord); wrongRoom.roomId = "unrelated-room"
check(Checker.roomPlan(matchPayload, roomArrival, wrongRoom, 99,
	"room-private", "race-job") == nil, "stale Room identity rejected")
local unexpected = { UserId = 43, Parent = players, attrs = {} }
function unexpected:SetAttribute(name, value) self.attrs[name] = value end
function unexpected:GetJoinData() return { SourcePlaceId = 123456, SourceGameId = 987654,
	TeleportData = build("Track01") } end
local contextsBefore = contextCount
players.PlayerAdded:Fire(unexpected)
check(contextCount == contextsBefore and unexpected.attrs.RaceEntryError ~= nil,
	"unlisted arrival cannot create a kart and is directed to HUB")
check(string.find(warnings[#warnings], "reason=USER_NOT_PARTICIPANT", 1, true) ~= nil,
	"bootstrap rejection logs concrete reason")

local normalWorld = modules.PrototypeWorld
local virtualNow = 0
environment.os = { clock = function() return virtualNow end }
environment.task = { spawn = function(callback, argument) callback(argument) end,
	wait = function(seconds) virtualNow += seconds end,
	delay = function(_, callback) table.insert(delayed, callback) end }
local failureSerial = 0
local function runBootstrapFailure(expectedReason, scenario)
	failureSerial += 1
	virtualNow = 0
	local payload = build("Track01")
	local casePlayer = { UserId = 42, Parent = players, attrs = { RaceState = "GARAGE" } }
	function casePlayer:SetAttribute(name, value) self.attrs[name] = value end
	function casePlayer:GetAttribute(name) return self.attrs[name] end
	casePlayer.GetJoinData = function() return { SourceGameId = 987654, TeleportData = payload } end
	local caseRoot = { Anchored = false }
	local caseHumanoid = { Health = 100 }
	if scenario ~= "no_character" then
		casePlayer.Character = { WaitForChild = function(_, name)
			if name == "HumanoidRootPart" then return caseRoot end
			return if scenario == "no_humanoid" then nil else caseHumanoid
		end, PivotTo = function() end }
	end
	players.GetPlayers = function() return { casePlayer } end
	local releases = 0
	modules.PrototypeWorld = { releaseKartContext = function() releases += 1 end,
		acquireKartContext = function()
			if scenario == "no_context" then return nil end
			local seat = { CFrame = CF.identity, Sit = function(self, humanoid)
				if scenario ~= "seat_timeout" then self.Occupant = humanoid; humanoid.SeatPart = self end
			end }
			return { seat = seat,
				kart = { FindFirstChild = function() end, PivotTo = function() end },
				setSpawnCFrame = function() end }
		end }
	local Bootstrap = load("src/server/RaceServerBootstrap.luau", "RaceServerBootstrapFailure" .. failureSerial)
	local beforeWarning = #warnings
	check(Bootstrap.start(payload, casePlayer, casePlayer:GetJoinData()), "failure case handler starts")
	local reasonFound = false
	for index = beforeWarning + 1, #warnings do
		if string.find(warnings[index], "reason=" .. expectedReason, 1, true) then reasonFound = true end
	end
	check(reasonFound, scenario .. " logs " .. expectedReason)
	check(casePlayer:GetAttribute("RaceState") ~= "PRE_RACE", scenario .. " never enters countdown")
	check(casePlayer:GetAttribute("RaceEntryError") == "RACE SERVER UNAVAILABLE - RETURNING TO HUB",
		scenario .. " keeps a player-facing fallback while returning")
	if scenario == "seat_timeout" then check(releases == 1, "seat timeout releases KartContext") end
end
runBootstrapFailure("CHARACTER_TIMEOUT", "no_character")
runBootstrapFailure("HUMANOID_INVALID", "no_humanoid")
runBootstrapFailure("KART_CONTEXT_FAILED", "no_context")
runBootstrapFailure("SEAT_TIMEOUT", "seat_timeout")
modules.PrototypeWorld = normalWorld

virtualNow = 0
local delayedPayload = build("Track01")
local delayedPlayer = { UserId = 42, Parent = players, attrs = { RaceState = "GARAGE" } }
function delayedPlayer:SetAttribute(name, value) self.attrs[name] = value end
function delayedPlayer:GetAttribute(name) return self.attrs[name] end
local delayedRoot = { Anchored = false }
local delayedHumanoid = { Health = 100 }
delayedPlayer.Character = { WaitForChild = function(_, name)
	return if name == "HumanoidRootPart" then delayedRoot else delayedHumanoid
end, PivotTo = function() end }
players.GetPlayers = function() return { delayedPlayer } end
local delayedSeat = { CFrame = CF.identity, Sit = function() end }
modules.PrototypeWorld = { releaseKartContext = function() error("must stay seated") end,
	acquireKartContext = function()
		return { seat = delayedSeat,
			kart = { FindFirstChild = function() end, PivotTo = function() end },
			setSpawnCFrame = function() end }
	end }
environment.task.wait = function(seconds)
	virtualNow += seconds
	if virtualNow >= 0.5 then delayedSeat.Occupant = delayedHumanoid; delayedHumanoid.SeatPart = delayedSeat end
end
local DelayedBootstrap = load("src/server/RaceServerBootstrap.luau", "RaceServerBootstrapDelayed")
check(DelayedBootstrap.start(delayedPayload, delayedPlayer,
	{ SourceGameId = 987654, TeleportData = delayedPayload }), "delayed seat bootstrap starts")
check(delayedPlayer:GetAttribute("RaceState") == "PRE_RACE" and virtualNow >= 0.5
	and virtualNow < 2.5, "delayed seat confirms before PRE_RACE and within handshake window")
modules.PrototypeWorld = normalWorld

local function runServerInit(privateId, launchPayload, studio, failRace)
	local calls = { logs = {}, warnings = {} }
	local first = { UserId = 42, GetJoinData = function()
		return { SourcePlaceId = 999, SourceGameId = 987654, TeleportData = launchPayload }
	end }
	local startupPlayers = { PlayerRemoving = signal(), GetPlayers = function()
		return if privateId == "" or studio then {} else { first }
	end }
	local startupWorkspace = { SetAttribute = function(_, name, value) calls[name] = value end }
	local startupReplicated = {}
	local startupServices = { Players = startupPlayers, Workspace = startupWorkspace,
		ReplicatedStorage = startupReplicated,
		MemoryStoreService = { GetSortedMap = function() return {} end },
		RunService = { IsStudio = function() return studio end } }
	local startupModules = {
		ServerRuntime = Runtime,
		RaceLaunchService = { start = function() calls.launchService = true end,
			returnToHub = function() calls.returnToHub = true; return true end },
		PrototypeWorld = { start = function(options) calls.world = options or "default" end },
		RaceItemController = { start = function() calls.items = true end },
		RaceController = { start = function(options) calls.race = options or "default"; return not failRace end },
		GarageController = { start = function() calls.garage = true end },
		MatchRoomService = { start = function() calls.matchRooms = true end },
		RaceRoomCoordinator = { start = function() return {} end },
		RaceServerBootstrap = { start = function(value, initialPlayer, initialJoinData)
			calls.bootstrap = value; calls.initialPlayer = initialPlayer; calls.initialJoinData = initialJoinData
			return true
		end },
		PlayerPreferences = { start = function() calls.preferences = true end },
		KDMServerPresence = { MAP_NAME = "KDM_ServerPresence_v1", HEARTBEAT_SECONDS = 9,
			new = function() return { publish = function() end, remove = function() end,
				aggregate = function() return { stale = true } end } end },
	}
	local env = { game = { PrivateServerId = privateId, PrivateServerOwnerId = 0,
		PlaceId = 123456, GameId = 987654, JobId = "test-job",
		BindToClose = function() end,
		GetService = function(_, name) return assert(startupServices[name], name) end },
		Instance = { new = function() return {} end },
		task = { spawn = function() end },
		print = function(message) table.insert(calls.logs, message) end,
		warn = function(message) calls.warned = true; table.insert(calls.warnings, message) end,
		script = { WaitForChild = function(_, name) return { Name = name } end },
		require = function(module) return assert(startupModules[module.Name], module.Name) end }
	luau.load(fs.readFile("src/server/init.server.luau"), { environment = env })()
	return calls
end
local publicInit = runServerInit("", nil, false)
check(publicInit.KDMServerRole == "HUB" and publicInit.garage and publicInit.world == "default"
	and publicInit.race == "default" and publicInit.matchRooms and not publicInit.bootstrap,
	"public startup initializes concurrent MatchRooms")
local racePayload = build("Track02")
local reservedInit = runServerInit("reserved-id", racePayload, false)
check(reservedInit.KDMServerRole == "RACE" and reservedInit.world.trackId == "Track02"
	and reservedInit.race.trackId == "Track02" and reservedInit.bootstrap == racePayload
	and not reservedInit.garage, "reserved startup builds only selected V2 and skips Garage admission")
check(reservedInit.initialJoinData.SourceGameId == 987654 and reservedInit.initialPlayer.UserId == 42
	and string.find(reservedInit.logs[1], "reason=VALID_KDM_RACE", 1, true) ~= nil,
	"initial validated join context passed through with resolve diagnostic")
local malformedInit = runServerInit("reserved-id", { schema = "bad" }, false)
check(malformedInit.KDMServerRole == "HUB" and malformedInit.returnToHub and not malformedInit.world,
	"malformed reserved startup returns to HUB without default track")
check(string.find(malformedInit.warnings[1], "reason=INVALID_PAYLOAD", 1, true) ~= nil,
	"reserved rejection logs precise resolver reason")
local failedInit = runServerInit("reserved-id", racePayload, false, true)
check(failedInit.KDMServerRole == "RACE" and failedInit.returnToHub and failedInit.warned
	and not failedInit.bootstrap, "race initialization failure returns arrival to HUB")
local studioInit = runServerInit("studio-private-id", nil, true)
check(studioInit.KDMServerRole == "HUB" and studioInit.garage and studioInit.world == "default",
	"Studio startup remains HUB")
print(string.format("PASS race launch routing: %d checks", count))
