-- lune run tests/multiplayer_foundation_validation.luau
-- State isolation contracts; race_item_validation additionally runs production controllers with two karts.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local checks = 0
local function check(value, label)
	assert(value, label)
	checks += 1
end
local function load(path, environment)
	return luau.load(fs.readFile(path), { debugName = path, environment = environment })()
end
local contextType = load("src/server/KartContext.luau", { Vector3 = rb.Vector3 })
local racerType = load("src/server/RacerState.luau", {})
local sessionType = load("src/server/RaceSession.luau", {})
local config = load("src/shared/RaceItemConfig.luau", {})
local function kart()
	return { GetAttribute = function(_, name) return name == "RaceControlsLocked" end }
end
local function context(player)
	local chassis = { Position = rb.Vector3.zero }
	return contextType.new(player, kart(), chassis, {}, rb.CFrame.identity, {}, {},
		{ new = function() return { active = false } end },
		{ new = function() return { active = false } end },
		{ new = function() return { clear = function() end } end })
end
local a, b = {}, {}
local ca, cb = context(a), context(b)
check(ca ~= cb and ca.owner == a and cb.owner == b, "separate kart identities")
ca.control = { throttle = 1, steering = -1, driftRequested = true }
cb.control = { throttle = -1, steering = 0.7, driftRequested = false }
check(ca.control ~= cb.control and ca.control.throttle ~= cb.control.throttle
	and ca.control.steering ~= cb.control.steering, "independent control input")
ca.commandedSpeed, ca.smoothedSteering, ca.currentYawRate = 70, -0.6, 1
check(cb.commandedSpeed == 0 and cb.smoothedSteering == 0 and cb.currentYawRate == 0,
	"independent speed and yaw")
ca.driftActive, ca.driftDuration, ca.qualifiedDuration = true, 1, 0.75
cb.boostActive, cb.boostEndTime = true, 5
check(not cb.driftActive and cb.driftDuration == 0 and cb.qualifiedDuration == 0
	and not ca.boostActive and cb.boostActive, "Drift and Mini Boost coexist across karts")
ca.nitro.active = true
cb.slick.active = true
check(not cb.nitro.active and not ca.slick.active, "Nitro and Slick victim motion isolated")
ca.crashActive, ca.crashSpinRate = true, 4
cb.finishRollElapsed, cb.finishRollInitialSpeed = 1, 50
check(not cb.crashActive and ca.finishRollElapsed == 0 and cb.finishRollInitialSpeed == 50,
	"crash and finish roll isolated")
ca.insideBarrier.test = true
check(cb.insideBarrier.test == nil and ca.barrierTriggers ~= cb.barrierTriggers,
	"barrier runtime tables independent")
ca.control, ca.nitro.active, ca.driftActive = nil, false, false
check(cb.control.steering == 0.7 and cb.boostActive and cb.slick.active,
	"resetting first context preserves second")

local ra = racerType.new(a, ca, { checkpoint = 1 })
local rbState = racerType.new(b, cb, { checkpoint = 1 })
ra.insideGate.checkpoint = true
ra.routeProgress.checkpoint = 2
ra.offTrackElapsed = 4
ra.lapStartTime = 12
ra.finishEndTime = 30
check(not rbState.insideGate.checkpoint and rbState.routeProgress.checkpoint == 1,
	"checkpoint and route progress isolated")
check(rbState.offTrackElapsed == 0 and rbState.lapStartTime == 0
	and rbState.finishEndTime == 0, "off-track, lap, finish timing isolated")
ra.lastResetSerial = 9
check(rbState.lastResetSerial ~= 9, "reset serial isolated")

local session = sessionType.new("Track01Race", "RACE", 2)
session:add(a, ra)
session:add(b, rbState)
check(sessionType.forPlayer(a) == session and sessionType.forPlayer(b) == session,
	"both racers share one match and track")
session:remove(a)
check(sessionType.forPlayer(a) == nil and sessionType.forPlayer(b) == session,
	"removing one racer preserves the other")
local other = sessionType.new("Track02", "RACE", 3)
other:add(a, ra)
check(sessionType.forPlayer(a) ~= sessionType.forPlayer(b), "cross-session identity differs")
check(config.SLICK_LIFETIME == 10 and config.SLICK_OWNER_GRACE == 0.75,
	"Slick lifetime and owner grace unchanged")
local worldSource = fs.readFile("src/server/PrototypeWorld.luau")
local itemSource = fs.readFile("src/server/RaceItemController.luau")
local raceSource = fs.readFile("src/server/RaceController.luau")
check(string.find(worldSource, "ownerContexts[player]", 1, true) ~= nil
	and string.find(worldSource, "self.owner ~= player then return end", 1, true) ~= nil,
	"server maps caller to owner and rejects foreign control")
check(string.find(itemSource, "owner=player", 1, true) ~= nil
	and string.find(itemSource, "session=RaceSession.forPlayer(player)", 1, true) ~= nil,
	"Slick records owner and session")
check(string.find(itemSource, "clearSession()", 1, true) == nil
	and string.find(itemSource, "clearPlayer(player)", 1, true) ~= nil,
	"player lifecycle does not invoke global cleanup")
check(string.find(raceSource, "activePlayer", 1, true) == nil
	and string.find(raceSource, "racers[player]", 1, true) ~= nil,
	"race controller is player keyed")
print("PASS: " .. checks .. " multiplayer foundation isolation checks")
