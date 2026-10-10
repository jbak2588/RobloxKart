-- Server-only observer. No physics, lap adjudication or I/O ownership.
local Records = {}
function Records.new(S, deps)
 local round, states = nil, {}
 local api = {}
 function api.begin(input, participants, checkpointCount, targetLaps, length)
  round = S.freezeRound(input)
  states = {}
  for _, player in participants do
   if player:GetAttribute("IsBot") ~= true then
    states[player] = {nextCheckpoint=1,lap=1,best=nil,boosts=0,events={},invalid=false,
     checkpoints=checkpointCount,targetLaps=targetLaps,length=length,progress=0,finished=false}
   end
  end
  return round
 end
 function api.start(player, now)
  local s=states[player];if not s then return end
  s.start=now;s.lastTime=now;s.invalid=false;s.progress=0;s.previous=nil;s.position=nil
 end
 function api.invalidate(player)
  local s=states[player];if s then s.invalid=true;s.nextCheckpoint=1 end
 end
 function api.checkpoints(player, nextCheckpoint)
  local s=states[player]
  if s and nextCheckpoint>=s.nextCheckpoint and nextCheckpoint<=s.checkpoints+1 then s.nextCheckpoint=nextCheckpoint end
 end
 function api.sample(player, now, position, fraction)
  local s=states[player];if not s or not s.start or s.finished then return end
  if type(fraction)~="number" or fraction~=fraction or fraction<0 or fraction>=1 then s.invalid=true;return end
  if s.position then
   local moved=(position-s.position).Magnitude
   -- Reject teleport/hitch discontinuity independently of the gameplay timer.
   if now<=s.lastTime or moved>math.min(60,110*(now-s.lastTime)+12) then s.invalid=true end
   local advance=(fraction-s.previous+0.5)%1-0.5
   if math.abs(advance)*s.length>moved*3+4 then s.invalid=true end
   s.progress+=advance
  else
   -- Grid is near the start plane, on either side of fraction zero.
   if math.min(fraction,1-fraction)*s.length>100 then s.invalid=true end
  end
  s.position=position;s.previous=fraction;s.lastTime=now
 end
 function api.lap(player, now)
  local s=states[player];if not s or not s.start or s.finished then return false end
  local elapsed=now-s.start
  local valid=not s.invalid and s.nextCheckpoint==s.checkpoints+1 and s.progress>=0.94
   and elapsed>0 and elapsed>=s.length/110*0.8
  if valid then local ms=math.floor(elapsed*1000+0.5);s.best=if s.best then math.min(s.best,ms) else ms end
  s.lap+=1;s.start=now;s.invalid=false;s.nextCheckpoint=1;s.progress=0
  -- A new full lap begins only at the server-accepted finish boundary.
  s.previous=0;s.position=nil;s.lastTime=now
  return valid
 end
 function api.boost(player, eventId)
  local s=states[player]
  if not s or not s.start or s.finished or player:GetAttribute("RaceState")~="RACING"
   or type(eventId)~="string" or #eventId>128 or not round
   or eventId:sub(1,43)~=round.RoundGuid..":boost:" or s.events[eventId] then return false end
  if s.boosts>=10000 then return false end
  s.events[eventId]=true;s.boosts+=1;return true
 end
 function api.finish(player)
  local s=states[player]
  if not s or s.finished or player:GetAttribute("RaceState")~="FINISHED"
   or s.lap~=s.targetLaps+1 or not s.start or not round or round.diagnostic then return nil end
  s.finished=true
  return S.freeze({kind="OFFICIAL_RECORD",round=round,userId=player.UserId,
   bestLapMilliseconds=s.best,bestRaceBoosts=s.boosts,achievedAt=deps.utcMs(),
   verification={serverAccepted=true,state="FINISHED",targetLaps=s.targetLaps,
    completedLaps=s.lap-1,fullLapValid=s.best~=nil,provenance="FULL_ROUTE_V1",boostIdentity="SERVER_SERIAL_V1"}})
 end
 function api.round() return round end
 return api
end
return table.freeze(Records)
