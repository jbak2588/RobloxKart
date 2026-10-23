-- Exact public API and immutable balance parity against R6-B2 baseline 6c7e4b39.
local fs, luau = require("@lune/fs"), require("@lune/luau")
local loadConfig = require("./helpers/gameplay_config")
local balance = luau.load(fs.readFile("src/shared/KDMGameplayBalance.luau"))()
local count = 0
local function check(value, label) assert(value, label); count += 1 end
check(balance.VERSION == "R6-C0", "version")
local expectedKartConfig = (function()
local KartConfig = {
	MAX_FORWARD_SPEED = 70,
	OFF_TRACK_MAX_SPEED = 60,
	MAX_REVERSE_SPEED = 50,
	ACCELERATION = 36,
	REVERSE_ACCELERATION = 22,
	BRAKE_FORCE = 70,
	COAST_DECELERATION = 18,
	TURN_RADIUS_LOW_SPEED = 22,
	TURN_RADIUS_HIGH_SPEED = 85,
	STEERING_RESPONSE = 4,
	YAW_ACCELERATION = 3,
	MIN_STEERING_SPEED = 2,
	LATERAL_GRIP = 3.75,
	DRIFT_MIN_SPEED = 25,
	DRIFT_EXIT_SPEED = 18,
	DRIFT_ENTRY_STEER = 0.45,
	DRIFT_EXIT_STEER = 0.12,
	DRIFT_LATERAL_GRIP = 1.15,
	DRIFT_YAW_MULTIPLIER = 1.3,
	DRIFT_MAX_SPEED = 64,
	DRIFT_SPEED_DECELERATION = 6,
	DRIFT_CHARGE_MIN_DURATION = 1.0,
	DRIFT_CHARGE_REQUIRED_TIME = 0.75,
	DRIFT_CHARGE_MIN_FORWARD_SPEED = 30,
	DRIFT_CHARGE_MIN_SLIP_DEGREES = 12,
	MINI_BOOST_MAX_SPEED = 100,
	MINI_BOOST_ACCELERATION = 65,
	MINI_BOOST_DURATION = 2.0,
	BOOST_EXIT_DECELERATION = 10,
	NITRO_MAX_SPEED = 120,
	NITRO_DURATION = 3.0,
	NITRO_ACCELERATION = 75,
	NITRO_EXIT_DECELERATION = 15,
	BARRIER_CONTACT_MIN_SPEED = 0.25,
	BARRIER_CONTACT_PUSH_SPEED = 5,
	BARRIER_CRASH_MIN_SPEED = 15,
	BARRIER_CRASH_DURATION_MIN = 0.65,
	BARRIER_CRASH_DURATION_MAX = 0.95,
	BARRIER_CRASH_BOUNCE_FACTOR = 0.30,
	BARRIER_CRASH_MIN_REBOUND_SPEED = 10,
	BARRIER_CRASH_MAX_REBOUND_SPEED = 28,
	BARRIER_CRASH_MIN_SPIN_TURNS = 0.45,
	BARRIER_CRASH_MAX_SPIN_TURNS = 1.35,
	BARRIER_CRASH_COOLDOWN = 0.75,
	BARRIER_CRASH_DAMPING = 2.2,
	KART_UPRIGHT_MIN_DOT = 0.55,
	KART_UPRIGHT_RECOVERY_DELAY = 0.12,
	KART_INVERTED_RECOVERY_DELAY = 0.04,

	CAMERA_DISTANCE = 18,
	CAMERA_HEIGHT = 8,
	CAMERA_LOOK_AHEAD = 12,
	CAMERA_RESPONSE = 6,
	CAMERA_FOV = 75,

	FALL_RESET_Y = -40,
	INPUT_SEND_INTERVAL = 0.1,
	INPUT_TIMEOUT = 0.5,
	REMOTE_EVENT_NAME = "KartControl",
	DEBUG_TELEMETRY = false,
	DEBUG_DRIFT_HUD = false,
	DEBUG_LOG_INTERVAL = 0.5,
}

return table.freeze(KartConfig)

end)()
local actualKartConfig = loadConfig("src/shared/KartConfig.luau")
for key, value in expectedKartConfig do
	check(actualKartConfig[key] == value and type(actualKartConfig[key]) == type(value), "baseline KartConfig "..key)
end
local straightKeys = {STRAIGHT_SPEED_ENABLED=true,STRAIGHT_MAX_SPEED=80,STRAIGHT_LOOK_AHEAD=90,
 STRAIGHT_ENTER_MAX_TURN=4,STRAIGHT_EXIT_MAX_TURN=7,STRAIGHT_EVALUATION_INTERVAL=.10,STRAIGHT_EXIT_DECELERATION=20}
for key,expected in straightKeys do check(actualKartConfig[key]==expected,"K1A adapter "..key) end
for key in actualKartConfig do check(expectedKartConfig[key] ~= nil or straightKeys[key] ~= nil or key=='ARCADE_DRIFT' or key=='DRIFT_CAMERA' or key=='V2_FINISH_CAMERA_HEIGHT' or key=='V2_FINISH_CAMERA_SIDE', "no unapproved public key "..key) end
for key,value in balance.DRIFT.RearSlide do check(actualKartConfig.ARCADE_DRIFT[key]==value,'approved D1 tuning adapter '..key) end
check(type(balance.DRIFT.MinSpeed) == "number" and actualKartConfig.DRIFT_MIN_SPEED == balance.DRIFT.MinSpeed, "adapter DRIFT_MIN_SPEED")
check(type(balance.DRIFT.ExitSpeed) == "number" and actualKartConfig.DRIFT_EXIT_SPEED == balance.DRIFT.ExitSpeed, "adapter DRIFT_EXIT_SPEED")
check(type(balance.DRIFT.EntrySteer) == "number" and actualKartConfig.DRIFT_ENTRY_STEER == balance.DRIFT.EntrySteer, "adapter DRIFT_ENTRY_STEER")
check(type(balance.DRIFT.ExitSteer) == "number" and actualKartConfig.DRIFT_EXIT_STEER == balance.DRIFT.ExitSteer, "adapter DRIFT_EXIT_STEER")
check(type(balance.DRIFT.LateralGrip) == "number" and actualKartConfig.DRIFT_LATERAL_GRIP == balance.DRIFT.LateralGrip, "adapter DRIFT_LATERAL_GRIP")
check(type(balance.DRIFT.YawMultiplier) == "number" and actualKartConfig.DRIFT_YAW_MULTIPLIER == balance.DRIFT.YawMultiplier, "adapter DRIFT_YAW_MULTIPLIER")
check(type(balance.DRIFT.MaxSpeed) == "number" and actualKartConfig.DRIFT_MAX_SPEED == balance.DRIFT.MaxSpeed, "adapter DRIFT_MAX_SPEED")
check(type(balance.DRIFT.SpeedDeceleration) == "number" and actualKartConfig.DRIFT_SPEED_DECELERATION == balance.DRIFT.SpeedDeceleration, "adapter DRIFT_SPEED_DECELERATION")
check(type(balance.DRIFT.ChargeMinDuration) == "number" and actualKartConfig.DRIFT_CHARGE_MIN_DURATION == balance.DRIFT.ChargeMinDuration, "adapter DRIFT_CHARGE_MIN_DURATION")
check(type(balance.DRIFT.ChargeRequiredTime) == "number" and actualKartConfig.DRIFT_CHARGE_REQUIRED_TIME == balance.DRIFT.ChargeRequiredTime, "adapter DRIFT_CHARGE_REQUIRED_TIME")
check(type(balance.DRIFT.ChargeMinForwardSpeed) == "number" and actualKartConfig.DRIFT_CHARGE_MIN_FORWARD_SPEED == balance.DRIFT.ChargeMinForwardSpeed, "adapter DRIFT_CHARGE_MIN_FORWARD_SPEED")
check(type(balance.DRIFT.ChargeMinSlipDegrees) == "number" and actualKartConfig.DRIFT_CHARGE_MIN_SLIP_DEGREES == balance.DRIFT.ChargeMinSlipDegrees, "adapter DRIFT_CHARGE_MIN_SLIP_DEGREES")
check(type(balance.BOOST.MiniBoost.MaxSpeed) == "number" and actualKartConfig.MINI_BOOST_MAX_SPEED == balance.BOOST.MiniBoost.MaxSpeed, "adapter MINI_BOOST_MAX_SPEED")
check(type(balance.BOOST.MiniBoost.Acceleration) == "number" and actualKartConfig.MINI_BOOST_ACCELERATION == balance.BOOST.MiniBoost.Acceleration, "adapter MINI_BOOST_ACCELERATION")
check(type(balance.BOOST.MiniBoost.Duration) == "number" and actualKartConfig.MINI_BOOST_DURATION == balance.BOOST.MiniBoost.Duration, "adapter MINI_BOOST_DURATION")
check(type(balance.BOOST.MiniBoost.ExitDeceleration) == "number" and actualKartConfig.BOOST_EXIT_DECELERATION == balance.BOOST.MiniBoost.ExitDeceleration, "adapter BOOST_EXIT_DECELERATION")
check(type(balance.ITEMS.Nitro.MaxSpeed) == "number" and actualKartConfig.NITRO_MAX_SPEED == balance.ITEMS.Nitro.MaxSpeed, "adapter NITRO_MAX_SPEED")
check(type(balance.ITEMS.Nitro.Duration) == "number" and actualKartConfig.NITRO_DURATION == balance.ITEMS.Nitro.Duration, "adapter NITRO_DURATION")
check(type(balance.ITEMS.Nitro.Acceleration) == "number" and actualKartConfig.NITRO_ACCELERATION == balance.ITEMS.Nitro.Acceleration, "adapter NITRO_ACCELERATION")
check(type(balance.ITEMS.Nitro.ExitDeceleration) == "number" and actualKartConfig.NITRO_EXIT_DECELERATION == balance.ITEMS.Nitro.ExitDeceleration, "adapter NITRO_EXIT_DECELERATION")
local expectedRaceItemConfig = (function()
return table.freeze({
	DRIFT_BONUS_REQUIRED_BOOSTS = 3,
	SLICK_LIFETIME = 10.0,
	SLICK_OWNER_GRACE = 0.75,
	SLICK_EFFECT_DURATION = 0.70,
	SLICK_DROP_DISTANCE = 10,
	SLICK_WIDTH = 16,
	SLICK_LENGTH = 5,
	SLICK_TRIGGER_HEIGHT = 4,
	SLICK_MAX_HAZARDS = 16,
	SLICK_SPEED_RETAIN = 0.55,
	SLICK_YAW_AMPLITUDE = math.rad(60),
	SLICK_ALIGNMENT_GAIN = 18,
	SLICK_MAX_YAW_RATE = 10,
	RACE_ITEM_HIT_IMMUNITY = 1.0,
	SHIELD_DURATION = 5.0,
	BLOCKED_FEEDBACK_DURATION = 0.8,
	SMOKE_DROP_DISTANCE = 10,
	SMOKE_WIDTH = 36,
	SMOKE_LENGTH = 18,
	SMOKE_HEIGHT = 10,
	SMOKE_LIFETIME = 6.0,
	SMOKE_EFFECT_DURATION = 3.00,
	SMOKE_OWNER_GRACE = 0.75,
	SMOKE_MAX_HAZARDS = 12,
	THUNDER_WARNING_SECONDS = 1.00,
	THUNDER_EFFECT_DURATION = 2.00,
	THUNDER_SPEED_CAP = 60,
	THUNDER_MAX_ACTIVE = 8,
	MISSILE_WARNING_SECONDS = 0.90,
	MISSILE_SPEED = 165,
	MISSILE_LIFETIME = 7.0,
	MISSILE_HIT_RADIUS = 5.5,
	MISSILE_TURN_RATE = 8.0,
	MISSILE_MAX_ACTIVE = 16,
	MISSILE_EFFECT_DURATION = 2.50,
	MISSILE_SPEED_CAP = 55,
	MISSILE_LATERAL_GRIP_MULTIPLIER = 0.70,
})

end)()
local actualRaceItemConfig = loadConfig("src/shared/RaceItemConfig.luau")
for key, value in expectedRaceItemConfig do
	check(actualRaceItemConfig[key] == value and type(actualRaceItemConfig[key]) == type(value), "baseline RaceItemConfig "..key)
end
local lapKeys = { LAP_REFILL_ENABLED=true, LAP_REFILL_TO=true, LAP_REFILL_EMPTY_ONLY=true,
	LAP_REFILL_NON_FINAL_ONLY=true, LAP_REFILL_ELIGIBLE=true, LAP_REFILL_EXCLUDE_NITRO=true }
for key in actualRaceItemConfig do check(expectedRaceItemConfig[key] ~= nil or lapKeys[key], "no unexpected public key "..key) end
check(type(balance.DRIFT.BonusRequiredBoosts) == "number" and actualRaceItemConfig.DRIFT_BONUS_REQUIRED_BOOSTS == balance.DRIFT.BonusRequiredBoosts, "adapter DRIFT_BONUS_REQUIRED_BOOSTS")
check(type(balance.ITEMS.Slick.Lifetime) == "number" and actualRaceItemConfig.SLICK_LIFETIME == balance.ITEMS.Slick.Lifetime, "adapter SLICK_LIFETIME")
check(type(balance.ITEMS.Slick.OwnerGrace) == "number" and actualRaceItemConfig.SLICK_OWNER_GRACE == balance.ITEMS.Slick.OwnerGrace, "adapter SLICK_OWNER_GRACE")
check(type(balance.ITEMS.Slick.EffectDuration) == "number" and actualRaceItemConfig.SLICK_EFFECT_DURATION == balance.ITEMS.Slick.EffectDuration, "adapter SLICK_EFFECT_DURATION")
check(type(balance.ITEMS.Slick.DropDistance) == "number" and actualRaceItemConfig.SLICK_DROP_DISTANCE == balance.ITEMS.Slick.DropDistance, "adapter SLICK_DROP_DISTANCE")
check(type(balance.ITEMS.Slick.Width) == "number" and actualRaceItemConfig.SLICK_WIDTH == balance.ITEMS.Slick.Width, "adapter SLICK_WIDTH")
check(type(balance.ITEMS.Slick.Length) == "number" and actualRaceItemConfig.SLICK_LENGTH == balance.ITEMS.Slick.Length, "adapter SLICK_LENGTH")
check(type(balance.ITEMS.Slick.TriggerHeight) == "number" and actualRaceItemConfig.SLICK_TRIGGER_HEIGHT == balance.ITEMS.Slick.TriggerHeight, "adapter SLICK_TRIGGER_HEIGHT")
check(type(balance.ITEMS.Slick.MaxHazards) == "number" and actualRaceItemConfig.SLICK_MAX_HAZARDS == balance.ITEMS.Slick.MaxHazards, "adapter SLICK_MAX_HAZARDS")
check(type(balance.ITEMS.Slick.SpeedRetain) == "number" and actualRaceItemConfig.SLICK_SPEED_RETAIN == balance.ITEMS.Slick.SpeedRetain, "adapter SLICK_SPEED_RETAIN")
check(type(balance.ITEMS.Slick.YawAmplitude) == "number" and actualRaceItemConfig.SLICK_YAW_AMPLITUDE == balance.ITEMS.Slick.YawAmplitude, "adapter SLICK_YAW_AMPLITUDE")
check(type(balance.ITEMS.Slick.AlignmentGain) == "number" and actualRaceItemConfig.SLICK_ALIGNMENT_GAIN == balance.ITEMS.Slick.AlignmentGain, "adapter SLICK_ALIGNMENT_GAIN")
check(type(balance.ITEMS.Slick.MaxYawRate) == "number" and actualRaceItemConfig.SLICK_MAX_YAW_RATE == balance.ITEMS.Slick.MaxYawRate, "adapter SLICK_MAX_YAW_RATE")
check(type(balance.COMMON.HitImmunity) == "number" and actualRaceItemConfig.RACE_ITEM_HIT_IMMUNITY == balance.COMMON.HitImmunity, "adapter RACE_ITEM_HIT_IMMUNITY")
check(type(balance.ITEMS.Shield.Duration) == "number" and actualRaceItemConfig.SHIELD_DURATION == balance.ITEMS.Shield.Duration, "adapter SHIELD_DURATION")
check(type(balance.COMMON.BlockedFeedbackDuration) == "number" and actualRaceItemConfig.BLOCKED_FEEDBACK_DURATION == balance.COMMON.BlockedFeedbackDuration, "adapter BLOCKED_FEEDBACK_DURATION")
check(type(balance.ITEMS.Smoke.DropDistance) == "number" and actualRaceItemConfig.SMOKE_DROP_DISTANCE == balance.ITEMS.Smoke.DropDistance, "adapter SMOKE_DROP_DISTANCE")
check(type(balance.ITEMS.Smoke.Width) == "number" and actualRaceItemConfig.SMOKE_WIDTH == balance.ITEMS.Smoke.Width, "adapter SMOKE_WIDTH")
check(type(balance.ITEMS.Smoke.Length) == "number" and actualRaceItemConfig.SMOKE_LENGTH == balance.ITEMS.Smoke.Length, "adapter SMOKE_LENGTH")
check(type(balance.ITEMS.Smoke.Height) == "number" and actualRaceItemConfig.SMOKE_HEIGHT == balance.ITEMS.Smoke.Height, "adapter SMOKE_HEIGHT")
check(type(balance.ITEMS.Smoke.Lifetime) == "number" and actualRaceItemConfig.SMOKE_LIFETIME == balance.ITEMS.Smoke.Lifetime, "adapter SMOKE_LIFETIME")
check(type(balance.ITEMS.Smoke.EffectDuration) == "number" and actualRaceItemConfig.SMOKE_EFFECT_DURATION == balance.ITEMS.Smoke.EffectDuration, "adapter SMOKE_EFFECT_DURATION")
check(type(balance.ITEMS.Smoke.OwnerGrace) == "number" and actualRaceItemConfig.SMOKE_OWNER_GRACE == balance.ITEMS.Smoke.OwnerGrace, "adapter SMOKE_OWNER_GRACE")
check(type(balance.ITEMS.Smoke.MaxHazards) == "number" and actualRaceItemConfig.SMOKE_MAX_HAZARDS == balance.ITEMS.Smoke.MaxHazards, "adapter SMOKE_MAX_HAZARDS")
check(type(balance.ITEMS.Thunder.WarningSeconds) == "number" and actualRaceItemConfig.THUNDER_WARNING_SECONDS == balance.ITEMS.Thunder.WarningSeconds, "adapter THUNDER_WARNING_SECONDS")
check(type(balance.ITEMS.Thunder.EffectDuration) == "number" and actualRaceItemConfig.THUNDER_EFFECT_DURATION == balance.ITEMS.Thunder.EffectDuration, "adapter THUNDER_EFFECT_DURATION")
check(type(balance.ITEMS.Thunder.SpeedCap) == "number" and actualRaceItemConfig.THUNDER_SPEED_CAP == balance.ITEMS.Thunder.SpeedCap, "adapter THUNDER_SPEED_CAP")
check(type(balance.ITEMS.Thunder.MaxActive) == "number" and actualRaceItemConfig.THUNDER_MAX_ACTIVE == balance.ITEMS.Thunder.MaxActive, "adapter THUNDER_MAX_ACTIVE")
check(type(balance.ITEMS.Missile.WarningSeconds) == "number" and actualRaceItemConfig.MISSILE_WARNING_SECONDS == balance.ITEMS.Missile.WarningSeconds, "adapter MISSILE_WARNING_SECONDS")
check(type(balance.ITEMS.Missile.Speed) == "number" and actualRaceItemConfig.MISSILE_SPEED == balance.ITEMS.Missile.Speed, "adapter MISSILE_SPEED")
check(type(balance.ITEMS.Missile.Lifetime) == "number" and actualRaceItemConfig.MISSILE_LIFETIME == balance.ITEMS.Missile.Lifetime, "adapter MISSILE_LIFETIME")
check(type(balance.ITEMS.Missile.HitRadius) == "number" and actualRaceItemConfig.MISSILE_HIT_RADIUS == balance.ITEMS.Missile.HitRadius, "adapter MISSILE_HIT_RADIUS")
check(type(balance.ITEMS.Missile.TurnRate) == "number" and actualRaceItemConfig.MISSILE_TURN_RATE == balance.ITEMS.Missile.TurnRate, "adapter MISSILE_TURN_RATE")
check(type(balance.ITEMS.Missile.MaxActive) == "number" and actualRaceItemConfig.MISSILE_MAX_ACTIVE == balance.ITEMS.Missile.MaxActive, "adapter MISSILE_MAX_ACTIVE")
check(type(balance.ITEMS.Missile.EffectDuration) == "number" and actualRaceItemConfig.MISSILE_EFFECT_DURATION == balance.ITEMS.Missile.EffectDuration, "adapter MISSILE_EFFECT_DURATION")
check(type(balance.ITEMS.Missile.SpeedCap) == "number" and actualRaceItemConfig.MISSILE_SPEED_CAP == balance.ITEMS.Missile.SpeedCap, "adapter MISSILE_SPEED_CAP")
check(type(balance.ITEMS.Missile.LateralGripMultiplier) == "number" and actualRaceItemConfig.MISSILE_LATERAL_GRIP_MULTIPLIER == balance.ITEMS.Missile.LateralGripMultiplier, "adapter MISSILE_LATERAL_GRIP_MULTIPLIER")
local function validateFrozen(value, path)
	check(table.isfrozen(value), "frozen "..path)
	check(not pcall(function() value.__MutationProbe = true end), "reject insertion "..path)
	for key, child in value do
		check(not pcall(function() value[key] = child end), "reject overwrite "..path.."."..key)
		if type(child) == "table" then validateFrozen(child, path.."."..key) end
	end
end
validateFrozen(balance, "Balance")
print("Gameplay balance validation PASS: "..count.." checks; exact public API parity")
