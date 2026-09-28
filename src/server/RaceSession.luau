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
		roundId = 0,
		phase = "EMPTY",
		trackId = trackId,
		trackData = nil,
		mode = mode,
		targetLaps = targetLaps,
		participants = {},
		maxPlayers = 2,
		waitDeadline = 0,
		waitingReason = "NONE",
		countdownEndTime = 0,
		startTime = 0,
		startingParticipantCount = 0,
		finishOrder = {},
		rematchVotes = {},
		terminal = {},
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
	self.rematchVotes[player] = nil
	if sessionsByPlayer[player] == self then sessionsByPlayer[player] = nil end
end

function RaceSession:count()
	local count = 0
	for _ in self.participants do count += 1 end
	return count
end

function RaceSession:orderedParticipants()
	local players = {}
	for player in self.participants do table.insert(players, player) end
	table.sort(players, function(a, b)
		local orderA = a:GetAttribute("ReadyOrder") or 0
		local orderB = b:GetAttribute("ReadyOrder") or 0
		if orderA == orderB then return (a.UserId or 0) < (b.UserId or 0) end
		return orderA < orderB
	end)
	return players
end

function RaceSession:recordFinish(player, officialTime)
	if not self:contains(player) then return nil end
	for place, entry in self.finishOrder do
		if entry.player == player then return place end
	end
	table.insert(self.finishOrder, {player = player, time = officialTime,
		readyOrder = player:GetAttribute("ReadyOrder") or 0})
	table.sort(self.finishOrder, function(a, b)
		if a.time ~= b.time then return a.time < b.time end
		return a.readyOrder < b.readyOrder
	end)
	for place, entry in self.finishOrder do
		entry.player:SetAttribute("RaceFinishPosition", place)
	end
	return player:GetAttribute("RaceFinishPosition")
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
