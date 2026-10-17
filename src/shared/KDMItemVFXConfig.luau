-- Cosmetic presentation only. Gameplay durations/caps belong to KDMGameplayBalance.

local Config = {
	Missile = {
		LaunchFlashLifetime = 0.18, TrailLifetime = 0.18, SmokeLifetime = 0.28,
		ImpactLifetime = 0.85, BurstRadius = 14, SparkCount = 12,
		AftershockDelay = 0.12, AftershockScale = 0.45, PuffScale = 1.35, PuffTransparency = 0.62,
		CameraShake = { Duration = 0.42, PrimaryDuration = 0.12, AftershockDelay = 0.12, AftershockScale = 0.50,
			PositionAmplitude = 0.055, RotationAmplitude = math.rad(1.5), Frequency = 23, PulseCount = 2 },
	},
	Thunder = {
		StrikeLifetime = 0.46, ArcLifetime = 0.46, ArcCount = 4,
		PrimaryDuration = 0.10, AfterFlashDelay = 0.12, AfterFlashScale = 0.45,
		CameraShake = { Duration = 0.40, PrimaryDuration = 0.10, AftershockDelay = 0.12, AftershockScale = 0.55,
			PositionAmplitude = 0.035, RotationAmplitude = math.rad(1.1), Frequency = 31, PulseCount = 2 },
	},
	Shield = { BlockPulseLifetime = 0.30, RippleLifetime = 0.30, MissileImpactLifetime = 0.42 },
	-- Only the authorized yaw presentation changes; duration/retain stay gameplay-owned.
	Slick = { SpinDegrees = 360, SpinEnabled = true, MaxApproachAngle = math.rad(20), VisualSmokeLifetime = 0.18 },
	Nitro = { Unchanged = true }, Smoke = { Unchanged = true },
	Camera = { MaxPositionAmplitude = 0.06, MaxRotationAmplitude = math.rad(1.8) },

	-- Consumed by RaceItemVisuals, the replicated production service path.
	MissileImpact = { Size = 28, ShockwaveSize = 36, RingSegments = 16 },
	ThunderWarning = { Width = 12.5, Height = 4.5, Depth = 9.5, OffsetY = 7.8 },
	-- After the primary bolt, reuse the live 28 / 36-stud Missile burst.
	ThunderImpact = { Delay = 0.10, LightRange = 38, LightBrightness = 9 },

}
local function freeze(value)
	for _, child in value do if type(child) == "table" then freeze(child) end end
	return table.freeze(value)
end
return freeze(Config)
