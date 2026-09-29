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
local players = { Name = "Players", PlayerRemoving = signal() }
local teleport = { TeleportInitFailed = signal(), calls = {} }
function teleport:TeleportAsync(placeId, group, options)
	table.insert(self.calls, { placeId = placeId, group = group, options = options })
	if self.failNow then error("TeleportAsync failed") end
end
local services = {
	ReplicatedStorage = { WaitForChild = function(_, name) check(name == "Shared", "shared root"); return shared end },
	Players = players,
	TeleportService = teleport,
	HttpService = { GenerateGUID = function() return "guid-12345678" end },
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
}
local delayed = {}
local environment = {
	game = { PlaceId = 123456, GetService = function(_, name) return assert(services[name], name) end },
	Instance = { new = function(class)
		check(class == "TeleportOptions", "TeleportOptions allocated")
		return { SetTeleportData = function(self, payload) self.payload = payload end }
	end },
	task = { delay = function(_, callback) table.insert(delayed, callback) end },
	print = function() end,
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
	check(Runtime.resolve("", { SourcePlaceId = 123456, TeleportData = payload }, 123456, 42) == "HUB",
		"public context remains HUB")
	local role, resolved = Runtime.resolve("reserved-id", { SourcePlaceId = 123456, TeleportData = payload }, 123456, 42)
	check(role == "RACE" and resolved == payload, "same-place reserved launch is RACE")
	check(Runtime.resolve("reserved-id", { SourcePlaceId = 9, TeleportData = payload }, 123456, 42) == "HUB",
		"foreign source cannot start race")
	check(Runtime.resolve("vip-id", { SourcePlaceId = 123456, TeleportData = payload }, 123456, 42, 81) == "HUB",
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
check(Runtime.resolve("reserved-id", { SourcePlaceId = 123456, TeleportData = invalid }, 123456, 42) == "HUB",
	"invalid reserved context cannot become RACE")

Launch.start()
local failed = 0
check(Launch.launchSolo(player, "Track02", "Driver02", "Kart02", function() failed += 1 end),
	"server launches V2")
local call = teleport.calls[#teleport.calls]
check(call.placeId == 123456 and call.group[1] == player and call.options.ShouldReserveServer == true,
	"same PlaceId receives new reserved server")
check(call.options.payload.trackId == "Track02" and call.options.payload.matchId == "guid-12345678",
	"server GUID and selected track transmitted")
teleport.TeleportInitFailed:Fire(player)
check(failed == 1 and player:GetAttribute("RaceState") == "GARAGE"
	and player:GetAttribute("RaceEntryError") ~= "", "failed launch restores Garage and visible error")
check(player:GetAttribute("SelectedDriverId") == "Driver02"
	and player:GetAttribute("SelectedKartId") == "Kart02"
	and player:GetAttribute("SelectedTrackId") == "Track02", "failure preserves selections")
player:SetAttribute("RaceState", "FINISHED")
check(Launch.returnToHub(player), "Result GARAGE requests public HUB")
call = teleport.calls[#teleport.calls]
check(call.placeId == 123456 and call.options == nil, "return omits reserved-server option")
teleport.TeleportInitFailed:Fire(player)
check(player:GetAttribute("RaceState") == "FINISHED" and player:GetAttribute("RaceEntryError") ~= "",
	"failed HUB return preserves result for retry")
player:SetAttribute("RaceState", "GARAGE")
teleport.failNow = true
check(not Launch.launchSolo(player, "Track01", "Driver01", "Kart01", function() failed += 1 end)
	and failed == 2 and player:GetAttribute("RaceEntryError") ~= "",
	"synchronous teleport exception restores retryable Garage")
teleport.failNow = false
check(Launch.launchSolo(player, "Track01", "Driver01", "Kart01", function() failed += 1 end),
	"failure clears pending reservation for retry")

-- Exercise the production arrival path with simulated server objects.
local CF, V = rb.CFrame, rb.Vector3
modules.TrackCatalog.Entries.Track01.GridSlots = { CF.new(10, 0, 20) }
modules.TrackCatalog.Entries.Track02.GridSlots = { CF.new(30, 0, 40) }
modules.DriverAppearance = { applyToCharacter = function(character, driver) character.appliedDriver = driver end }
modules.KartVisualFactory = { applyColors = function(visual, kart) visual.appliedKart = kart end }
local appearance = {}
modules.DriverCatalog.Entries.Driver02 = appearance
local kartSelection = {}
modules.KartCatalog.Entries.Kart02 = kartSelection
local contextCount = 0
local seats = {}
modules.PrototypeWorld = { acquireKartContext = function(_, spawn)
	contextCount += 1
	local visual = { IsA = function(_, class) return class == "Model" end }
	local kart = { FindFirstChild = function(_, name) return if name == "Visual" then visual else nil end,
		PivotTo = function(self, frame) self.pivot = frame end }
	local seat = { CFrame = CF.identity, Sit = function(self, humanoid) self.Occupant = humanoid end }
	table.insert(seats, seat)
	return { kart = kart, seat = seat, visual = visual,
		setSpawnCFrame = function(self, frame) self.spawn = frame end }
end }
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
	delay = function(_, callback) table.insert(delayed, callback) end }
for _, trackId in { "Track01", "Track02" } do
	local payload = build(trackId)
	player.GetJoinData = function() return { SourcePlaceId = 123456, TeleportData = payload } end
	local Bootstrap = load("src/server/RaceServerBootstrap.luau", "RaceServerBootstrap" .. trackId)
	check(Bootstrap.plan(payload, 42).trackId == trackId, "bootstrap plan selects " .. trackId)
	Bootstrap.start(payload)
	check(player:GetAttribute("SelectedTrackId") == trackId and player:GetAttribute("SelectedDriverId") == "Driver02"
		and player:GetAttribute("SelectedKartId") == "Kart02" and player:GetAttribute("RaceMaxPlayers") == 1
		and player:GetAttribute("GridSlot") == 1 and player:GetAttribute("RaceState") == "PRE_RACE",
		"arrival restores validated selections and grid for " .. trackId)
	check(seats[#seats].Occupant == humanoid and root.Anchored == false
		and character.appliedDriver == appearance, "arriving driver is styled and seated")
	local before = contextCount
	players.PlayerAdded:Fire(player)
	check(Bootstrap.start(payload), "same match startup is idempotent")
	local otherMatch = build(trackId)
	otherMatch.matchId = "different-match-123"
	check(not Bootstrap.start(otherMatch), "different match cannot restart reserved server")
	check(contextCount == before, "duplicate arrival/start does not create a second kart")
end
local unexpected = { UserId = 43, Parent = players, attrs = {} }
function unexpected:SetAttribute(name, value) self.attrs[name] = value end
function unexpected:GetJoinData() return { SourcePlaceId = 123456, TeleportData = build("Track01") } end
local contextsBefore = contextCount
players.PlayerAdded:Fire(unexpected)
check(contextCount == contextsBefore and unexpected.attrs.RaceEntryError ~= nil,
	"unlisted arrival cannot create a kart and is directed to HUB")

local function runServerInit(privateId, launchPayload, studio, failRace)
	local calls = {}
	local first = { UserId = 42, GetJoinData = function()
		return { SourcePlaceId = 123456, TeleportData = launchPayload }
	end }
	local startupPlayers = { GetPlayers = function()
		return if privateId == "" or studio then {} else { first }
	end }
	local startupWorkspace = { SetAttribute = function(_, name, value) calls[name] = value end }
	local startupReplicated = {}
	local startupServices = { Players = startupPlayers, Workspace = startupWorkspace,
		ReplicatedStorage = startupReplicated,
		RunService = { IsStudio = function() return studio end } }
	local startupModules = {
		ServerRuntime = Runtime,
		RaceLaunchService = { start = function() calls.launchService = true end,
			returnToHub = function() calls.returnToHub = true; return true end },
		PrototypeWorld = { start = function(options) calls.world = options or "default" end },
		RaceItemController = { start = function() calls.items = true end },
		RaceController = { start = function(options) calls.race = options or "default"; return not failRace end },
		GarageController = { start = function() calls.garage = true end },
		RaceServerBootstrap = { start = function(value) calls.bootstrap = value; return true end },
		PlayerPreferences = { start = function() calls.preferences = true end },
	}
	local env = { game = { PrivateServerId = privateId, PrivateServerOwnerId = 0,
		PlaceId = 123456, JobId = "test-job",
		GetService = function(_, name) return assert(startupServices[name], name) end },
		Instance = { new = function() return {} end }, print = function() end,
		warn = function() calls.warned = true end,
		script = { WaitForChild = function(_, name) return { Name = name } end },
		require = function(module) return assert(startupModules[module.Name], module.Name) end }
	luau.load(fs.readFile("src/server/init.server.luau"), { environment = env })()
	return calls
end
local publicInit = runServerInit("", nil, false)
check(publicInit.KDMServerRole == "HUB" and publicInit.garage and publicInit.world == "default"
	and publicInit.race == "default" and not publicInit.bootstrap, "public startup retains Base HUB flow")
local racePayload = build("Track02")
local reservedInit = runServerInit("reserved-id", racePayload, false)
check(reservedInit.KDMServerRole == "RACE" and reservedInit.world.trackId == "Track02"
	and reservedInit.race.trackId == "Track02" and reservedInit.bootstrap == racePayload
	and not reservedInit.garage, "reserved startup builds only selected V2 and skips Garage admission")
local malformedInit = runServerInit("reserved-id", { schema = "bad" }, false)
check(malformedInit.KDMServerRole == "HUB" and malformedInit.returnToHub and not malformedInit.world,
	"malformed reserved startup returns to HUB without default track")
local failedInit = runServerInit("reserved-id", racePayload, false, true)
check(failedInit.KDMServerRole == "RACE" and failedInit.returnToHub and failedInit.warned
	and not failedInit.bootstrap, "race initialization failure returns arrival to HUB")
local studioInit = runServerInit("studio-private-id", nil, true)
check(studioInit.KDMServerRole == "HUB" and studioInit.garage and studioInit.world == "default",
	"Studio startup remains HUB")
print(string.format("PASS race launch routing: %d checks", count))
