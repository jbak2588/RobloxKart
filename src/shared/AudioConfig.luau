local AudioConfig = {
	-- Add only audio that this experience owns or is licensed to use.
	ASSETS = {
		-- Rejected by real-device listening as a final continuous engine loop.
		-- Replace only after approval of a new steady-state loop asset.
		ENGINE_LOOP = "rbxassetid://6667206432",
		DRIFT_LOOP = "rbxassetid://9120397552",
		BOOST_START = "rbxassetid://83211426606907",
		BOOST_LOOP = "",
		COUNTDOWN = "rbxassetid://9119144736",
		GO = "",
		LAP_COMPLETE = "",
		FINAL_LAP = "rbxassetid://9119144736",
		FINISH = "",
		DNF = "",
	},
	ENGINE = {
		IDLE_PLAYBACK_SPEED = 0.78,
		NORMAL_PLAYBACK_SPEED = 1.30,
		MAX_PLAYBACK_SPEED = 1.38,
		BOOST_PLAYBACK_BONUS = 0.10,
		IDLE_VOLUME = 0.28,
		NORMAL_VOLUME = 0.60,
		MAX_VOLUME = 0.62,
		RESPONSE = 7,
		LOOP_TRIM_START = 0.08,
		LOOP_TRIM_END = 0.14,
		CROSSFADE_DURATION = 0.32,
		SECONDARY_DETUNE = 1.008,
		ENTRY_JITTER_MAX = 0.35,
		CROSSFADE_JITTER = 0.08,
		RPM_FLUTTER_DEPTH = 0.018,
	},
	DRIFT = {
		MIN_SPEED = 8,
		MIN_SLIP_DEGREES = 4,
		FULL_SLIP_DEGREES = 18,
		MAX_VOLUME = 0.8,
		MIN_PLAYBACK_SPEED = 0.90,
		MAX_PLAYBACK_SPEED = 1.12,
		RESPONSE = 10,
	},
	BOOST = {
		START_VOLUME = 0.75,
		LOOP_VOLUME = 0.42,
	},
	RACE = {
		COUNTDOWN_VOLUME = 0.6,
		GO_VOLUME = 0.85,
		GO_DURATION_MULTIPLIER = 2,
		GO_PITCH_RATIO = 1.18,
		FINAL_LAP_PLAYBACK_SPEED = 1.18,
		LAP_VOLUME = 0.7,
		FINISH_VOLUME = 0.85,
		DNF_VOLUME = 0.7,
	},
	SPATIAL = {
		MIN_DISTANCE = 8,
		MAX_DISTANCE = 80,
	},
}

return table.freeze(AudioConfig)
