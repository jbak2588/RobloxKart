-- Cosmetic presentation only. Gameplay durations/caps belong to KDMGameplayBalance.
local okRb, rb = pcall(function() return require("@lune/roblox") end)
local V3 = Vector3 or (okRb and rb and rb.Vector3) or { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
local NS = NumberSequence or (okRb and rb and rb.NumberSequence) or { new = function(a, b) return { a, b } end }

local Config = {
	Missile = {
		LaunchFlashLifetime = 0.18, TrailLifetime = 0.18, SmokeLifetime = 0.28,
		ImpactLifetime = 0.42, BurstRadius = 3.5, SparkCount = 12,
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
	Shield = { BlockPulseLifetime = 0.30, RippleLifetime = 0.30 },
	-- Only the authorized yaw presentation changes; duration/retain stay gameplay-owned.
	Slick = { SpinDegrees = 360, SpinEnabled = true, MaxApproachAngle = math.rad(20), VisualSmokeLifetime = 0.18 },
	Nitro = { Unchanged = true }, Smoke = { Unchanged = true },
	Camera = { MaxPositionAmplitude = 0.06, MaxRotationAmplitude = math.rad(1.8) },

	MissileImpact = {
		Size = 28,
		ShockwaveSize = 36,
		LightRadius = 38,
		LightBrightness = 9,
		Duration = 0.85,
		DebrisCount = 24,
		SmokeDuration = 1.4,
	},

	ThunderWarning = {
		CloudSize = V3.new(12.5, 4.5, 9.5),
		CloudOffset = V3.new(0, 7.8, 0),
		ParticleSize = NS.new(3.8, 7.5),
		LightRadius = 32,
	},

	ThunderImpact = {
		StrikeThickness = 3.2,
		FlashDuration = 0.22,
		ShockShellDuration = 1.6,
		ShockwaveSize = 32,
	},

	SlickSpin = {
		Duration = 1.25,
		SpinDegrees = 180,
		AudioScreechPitch = 1.08,
	},
}
local function freeze(value)
	for _, child in value do if type(child) == "table" then freeze(child) end end
	return table.freeze(value)
end
return freeze(Config)
