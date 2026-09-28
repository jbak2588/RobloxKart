-- Mutable race progress for one participant. Track geometry remains on RaceSession.
local RacerState = {}
RacerState.__index = RacerState

function RacerState.new(player, context, routeProgress)
	return setmetatable({
		player = player,
		context = context,
		raceStartTime = 0,
		lapStartTime = 0,
		countdownEndTime = 0,
		finishRollEndTime = 0,
		finishEndTime = 0,
		lastCountdownValue = 0,
		lastResetSerial = context.kart:GetAttribute("RaceResetSerial"),
		insideGate = {},
		offTrackSampleElapsed = 0,
		offTrackElapsed = 0,
		previousChassisPosition = nil,
		routeProgress = routeProgress,
		targetLaps = 0,
	}, RacerState)
end

return RacerState
