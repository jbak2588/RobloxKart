-- KDM gameplay tuning single source of truth.
-- Consume through RaceItemConfig / KartConfig compatibility adapters.
-- Changing a value changes gameplay balance; R6-C0 preserves all baseline values.
-- Excludes networking, UI, assets, geometry, routing and base vehicle physics.
-- Units: durations/grace/warnings/lifetimes are seconds; distances are studs;
-- speeds are studs/sec, acceleration/deceleration studs/sec^2, yaw angles radians
-- and yaw/turn rates radians/sec. SlipDegrees uses degrees; ratios are unitless.
local Balance = {
	VERSION = "R6-C0",
	SPEED = {
		Straight = {
			Enabled = true,
			MaxSpeed = 80,
			LookAheadStuds = 90,
			EnterMaxTurnDegrees = 4,
			ExitMaxTurnDegrees = 7,
			EvaluationInterval = 0.10,
			ExitDeceleration = 20,
		},
	},
	ITEM_ECONOMY = {
		LapRefill = {
			Enabled = true,
			RefillTo = 1,
			EmptyOnly = true,
			NonFinalLapsOnly = true,
			Eligible = { Shield = true, Slick = true, Missile = true, Thunder = true, Smoke = true },
			ExcludeNitro = true,
		},
	},
	ITEMS = {
		Nitro = {
			MaxSpeed = 100,
			Duration = 3.0,
			Acceleration = 75,
			ExitDeceleration = 15,
		},
		Shield = {
			Duration = 5.0,
		},
		Slick = {
			Lifetime = 10.0,
			OwnerGrace = 0.75,
			EffectDuration = 0.70,
			DropDistance = 10,
			Width = 16,
			Length = 5,
			TriggerHeight = 4,
			MaxHazards = 16,
			SpeedRetain = 0.55,
			YawAmplitude = math.rad(60),
			AlignmentGain = 18,
			MaxYawRate = 10,
		},
		Missile = {
			WarningSeconds = 0.90,
			Speed = 165,
			Lifetime = 7.0,
			HitRadius = 5.5,
			TurnRate = 8.0,
			MaxActive = 16,
			EffectDuration = 2.50,
			SpeedCap = 55,
			LateralGripMultiplier = 0.70,
		},
		Thunder = {
			WarningSeconds = 1.00,
			EffectDuration = 2.00,
			SpeedCap = 60,
			MaxActive = 8,
		},
		Smoke = {
			DropDistance = 10,
			Width = 36,
			Length = 18,
			Height = 10,
			Lifetime = 6.0,
			EffectDuration = 3.00,
			OwnerGrace = 0.75,
			MaxHazards = 12,
		},
	},
	DRIFT = {
		MinSpeed = 25,
		ExitSpeed = 18,
		EntrySteer = 0.45,
		ExitSteer = 0.12,
		LateralGrip = 1.15,
		YawMultiplier = 1.3,
		MaxSpeed = 64,
		SpeedDeceleration = 6,
		ChargeMinDuration = 1.0,
		ChargeRequiredTime = 0.75,
		ChargeMinForwardSpeed = 30,
		ChargeMinSlipDegrees = 12,
		BonusRequiredBoosts = 5,
	},
	BOOST = {
		MiniBoost = {
			MaxSpeed = 100,
			Acceleration = 65,
			Duration = 2.0,
			ExitDeceleration = 10,
		},
	},
	COMMON = {
		HitImmunity = 1.0,
		BlockedFeedbackDuration = 0.8,
	},
}

-- Freeze every tuning table once at module initialization.
local function freezeNested(value)
	for _, child in value do
		if type(child) == "table" then freezeNested(child) end
	end
	return table.freeze(value)
end

return freezeNested(Balance)
