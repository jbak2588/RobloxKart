-- One shared course and match lifecycle per server. Individual progress lives in RacerState.
local RaceSession = {}
RaceSession.__index = RaceSession
local activeSession = nil
local nextId = 0
local sessionsByPlayer = {}

function RaceSession.new(trackId, mode, targetLaps)
	nextId += 1
	local self = setmetatable({
		id = nextId,
		trackId = trackId,
		trackData = nil,
		mode = mode,
		targetLaps = targetLaps,
		participants = {},
		countdownEndTime = 0,
		startTime = 0,
		finishOrder = {},
	}, RaceSession)
	activeSession = self
	return self
end

function RaceSession.active()
	return activeSession
end

function RaceSession.forPlayer(player)
	return sessionsByPlayer[player]
end

function RaceSession:add(player, racer)
	local previous = sessionsByPlayer[player]
	if previous and previous ~= self then previous:remove(player) end
	self.participants[player] = racer
	sessionsByPlayer[player] = self
end

function RaceSession:remove(player)
	self.participants[player] = nil
	if sessionsByPlayer[player] == self then sessionsByPlayer[player] = nil end
end

function RaceSession:contains(player)
	return self.participants[player] ~= nil
end

function RaceSession:hasOtherParticipants(player)
	for participant in self.participants do
		if participant ~= player then return true end
	end
	return false
end

return RaceSession
