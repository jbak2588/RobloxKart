-- One shared course and match lifecycle per server. Individual progress lives in RacerState.
local RaceSession = {}
local RaceConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RaceConfig"))
local TrackCatalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("TrackCatalog"))
RaceSession.__index = RaceSession
local activeSession = nil
local nextId = 0
local sessionsByPlayer = {}
local sessionsByBot = {}

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
		maxPlayers = (TrackCatalog.Entries[trackId] and TrackCatalog.Entries[trackId].MaxPlayers) or RaceConfig.PUBLIC_RACE_MAX_PLAYERS,
		hostUserId = 0,
		waitingReason = "NONE",
		countdownEndTime = 0,
		startTime = 0,
		startingParticipantCount = 0,
		firstFinishAt = 0,
		raceEndDeadline = 0,
		finishOrder = {},
		rematchVotes = {},
		rewardRuns = {},
		terminal = {},
	}, RaceSession)
	activeSession = self
	return self
end

function RaceSession.active()
	return activeSession
end

function RaceSession.forPlayer(player)
	return sessionsByBot[player] or sessionsByPlayer[player]
end

function RaceSession:add(player, racer)
	local previous = sessionsByPlayer[player]
	if previous and previous ~= self then previous:remove(player) end
	self.participants[player] = racer
	sessionsByPlayer[player] = self
end

function RaceSession:addBot(state, racer)
	assert(state:GetAttribute("IsBot")==true,"Bot state required")
	self.participants[state]=racer;sessionsByBot[state]=self
end
-- Session-owned per-human continuation; votes cannot directly grant money.
function RaceSession:requestRewardRematch(player)
 local run=self.rewardRuns[player]
 if run then run.requested=true end
end
function RaceSession:beginRewardRound()
 local multiplayer=self.mode=="RACE" and self:humanCount()>=1 and self:count()>=2
 for player in self.participants do
  if player:GetAttribute("IsBot")==true then continue end
  local old=self.rewardRuns[player]
  local multiplier=if multiplayer and old and old.trackId==self.trackId and old.completed and old.requested then old.multiplier+1 else 1
  self.rewardRuns[player]={multiplier=multiplier,completed=false,requested=false,multiplayer=multiplayer,roundId=self.roundId,trackId=self.trackId}
  player:SetAttribute("RaceRewardMultiplier",multiplier)
  player:SetAttribute("RaceNextRematchMultiplier",nil)
 end
end
function RaceSession:rewardMultiplier(player)
 local run=self.rewardRuns[player]
 return if run and run.roundId==self.roundId then run.multiplier else 1
end
function RaceSession:completeRewardRound(player,eligible)
 local run=self.rewardRuns[player]
 if not run or run.roundId~=self.roundId then return end
 run.completed=run.multiplayer and eligible==true
 player:SetAttribute("RaceNextRematchMultiplier",if run.completed then run.multiplier+1 else nil)
end

function RaceSession:humanCount()
	local count=0;for participant in self.participants do
		if participant:GetAttribute("IsBot")~=true then count+=1 end
	end;return count
end
function RaceSession:remove(player)
	self.rewardRuns[player] = nil
	player:SetAttribute("RaceRewardMultiplier", nil)
	player:SetAttribute("RaceNextRematchMultiplier", nil)
	self.participants[player] = nil
	if sessionsByBot[player]==self then sessionsByBot[player]=nil end
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
		if orderA == orderB then return (if a:GetAttribute("IsBot")==true then 0 else a.UserId or 0) < (if b:GetAttribute("IsBot")==true then 0 else b.UserId or 0) end
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

-- A settled prefix is final even while slower racers continue. Every racer shares GO.
-- Read the sorted official results only after the server clock has passed that finish;
-- a remaining racer cannot subsequently produce an earlier/equal official time.
function RaceSession:finalizedFinish(player, now)
 for position,entry in self.finishOrder do
  if entry.player~=player then continue end
  if now-self.startTime<=entry.time then return nil end
  for other,racer in self.participants do
   if other:GetAttribute("RaceState")=="RACING" and racer.raceStartTime~=self.startTime then return nil end
  end
  local humanPosition=0
  for i=1,position do
   if self.finishOrder[i].player:GetAttribute('IsBot')~=true then humanPosition+=1 end
  end
  return {totalTime=entry.time,position=position,positionFinalized=true,humanPosition=humanPosition}
 end
 return nil
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
