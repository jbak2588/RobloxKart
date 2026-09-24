local AudioConfig = {
	-- Add only audio that this experience owns or is licensed to use.
	ASSETS = {
		ENGINE_LOOP = "rbxassetid://6667206432",
		DRIFT_LOOP = "rbxassetid://9120397552",
		BOOST_START = "rbxassetid://83211426606907",
		BOOST_LOOP = "",
		COUNTDOWN = "rbxassetid://9119144736",
		GO = "",
		LAP_COMPLETE = "",
		FINAL_LAP = "",
		FINISH = "",
		DNF = "",
	},
	ENGINE = {
		IDLE_PLAYBACK_SPEED = 0.78,
		MAX_PLAYBACK_SPEED = 1.38,
		BOOST_PLAYBACK_BONUS = 0.10,
		IDLE_VOLUME = 0.28,
		MAX_VOLUME = 0.62,
		RESPONSE = 7,
	},
	DRIFT = {
		MIN_SPEED = 8,
		MIN_SLIP_DEGREES = 8,
		FULL_SLIP_DEGREES = 28,
		MAX_VOLUME = 0.7,
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
