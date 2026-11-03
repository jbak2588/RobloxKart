-- Rookie Park lifecycle adapter; reuses the existing kart, physics and economy.
local RS=game:GetService('ReplicatedStorage')
local Trial=require(RS.Shared.RookieParkTrial)
local Overtake=require(RS.Shared.ParkOvertakePolicy)
local Config=require(RS.Shared.KartConfig)
local RaceConfig=require(RS.Shared.RaceConfig)
local Drift=require(script.Parent.LobbyDriftSession)
local Session={}
function Session.new(zone,practice)
 local api={};local center=zone:GetAttribute('Center')
 local races,racePolicy
 function api:reserveRace(player)
  if not races then
   racePolicy=require(RS.Shared.ParkMultiplayerPolicy)
   races=require(script.Parent.ParkMultiplayerSession).new(zone,practice)
  end
  return races:reserve(player)
 end
 function api:update()if races then races:update()end end
 function api:allocate(occupied,nextSlot)return Trial.allocate(occupied,nextSlot)end
 local function setAttr(player,key,val)
  if player:GetAttribute(key)~=val then player:SetAttribute(key,val)end
 end
 local function publish(player,r)
  local s=r.trial
  for i=1,7 do setAttr(player,'ParkOvertakeFinishDistance'..i,if s.botDistances then s.botDistances[i]else nil)end
  setAttr(player,'ParkTrialPhase',s.phase)
  setAttr(player,'ParkTrialCurrentLap',s.lap)
  setAttr(player,'ParkTrialTotalLaps',s.targetLaps or Trial.Laps)
  setAttr(player,'ParkOvertakeActive',r.parkOvertake==true)
  setAttr(player,'ParkOvertakeStartArc',if r.parkOvertake then s.overtakeStartArc else nil)
  setAttr(player,'ParkOvertakeAhead',if r.parkOvertake then s.ahead or 0 else nil)
  setAttr(player,'ParkTrialCompletedLaps',s.completedLaps)
  setAttr(player,'ParkTrialRewardMultiplier',s.multiplier)
  setAttr(player,'ParkTrialRewardAmount',if r.parkMultiplayer then (if s.humanRank then racePolicy.reward(s.humanCount,s.humanRank)else 0)elseif r.parkOvertake then Overtake.reward(s.ahead or 0)else Trial.Reward*s.multiplier)
  setAttr(player,'ParkTrialGoAt',s.goAt)
  setAttr(player,'ParkTrialStartedAt',s.startedAt)
  setAttr(player,'ParkTrialCheckpoint',s.next-1)
  setAttr(player,'ParkTrialMissed',s.missed)
  setAttr(player,'ParkTrialInvalid',s.invalid)
  setAttr(player,'ParkTrialMilliseconds',s.milliseconds)
  setAttr(player,'ParkTrialFinishPhase',s.finishPhase)
  setAttr(player,'ParkTrialFinishedAt',s.finishAt)
  local target=Trial.Gates[s.next]or Trial.Finish
  setAttr(player,'ParkTrialTarget',center+Vector3.new(target.x,4,target.z))
 end
 function api:begin(player,r)
  local pos=r.body.Position-center
  r.trial=Trial.new(workspace:GetServerTimeNow(),pos.X,pos.Z,if r.parkMultiplayer then {laps=3,countdown=10}elseif r.parkOvertake then {laps=Overtake.Laps,countdown=Overtake.Countdown}else nil)
  if r.parkMultiplayer and not races:attach(player,r)then return false end
  r.trial.ahead=0
  if r.parkOvertake then r.trial.overtakeStartArc=Overtake.startArc(r.slot)end
  r.trial.multiplier=r.parkReplayMultiplier or 1
  r.trial.startSlot=r.slot
  r.trial.id=game:GetService('HttpService'):GenerateGUID(false)
  r.trial.transactionAt=DateTime.now().UnixTimestampMillis
  player:SetAttribute('ParkTrialRewardState','NONE')
  r.kart:SetAttribute('KartFinishRollActive',false);r.kart:SetAttribute('RaceControlsLocked',false)
  r.body.Anchored=true;r.speed=0;r.yaw=0
  publish(player,r)
  return true
 end
 local function save(player,r,s)
  if s.saving or s.confirmed then return end
  local slot=s.startSlot or r.slot
  s.saving=true
  if r.trial==s and player.Parent and player:GetAttribute('LobbyDriveActive')==true
   and player:GetAttribute('LobbyDriveGeneration')==r.generation then player:SetAttribute('ParkTrialRewardState','SAVING')end
  task.spawn(function()
   local ok,result=pcall(function()
    local economy=require(script.Parent.EconomyService)
    if r.parkMultiplayer then
     return economy.saveParkRace(player,{id=s.id,milliseconds=s.milliseconds,slot=slot,position=s.raceRank,
      humans=s.humanCount,humanPosition=s.humanRank,transaction={version=1,issuedAt=s.transactionAt},
      completedCheckpoints=(s.completedLaps or 0)*6,valid=not s.invalid,completedLaps=s.completedLaps})
    elseif r.parkOvertake then
     return economy.saveParkOvertake(player,{id=s.id,milliseconds=s.milliseconds,slot=r.slot,ahead=s.ahead,botDistances=s.botDistances,
      transaction={version=1,issuedAt=s.transactionAt},completedCheckpoints=(s.completedLaps or 0)*6,valid=not s.invalid,completedLaps=s.completedLaps})
    end
    return economy.saveParkLap(player,{id=s.id,milliseconds=s.milliseconds,
     transaction={version=1,issuedAt=s.transactionAt},completedCheckpoints=(s.completedLaps or 0)*6,valid=not s.invalid,
     proofVersion=2,completedLaps=s.completedLaps,bestLapMilliseconds=math.min(table.unpack(s.lapTimes)),rewardMultiplier=s.multiplier})
   end)
   s.saving=false;s.confirmed=ok and type(result)=='table' and result.status=='SAVE_CONFIRMED'
   print(string.format('[ParkSession] event=save user=%s run=%s confirmed=%s status=%s',tostring(player.UserId),tostring(s.id),tostring(s.confirmed),if ok and type(result)=='table'then tostring(result.status)else 'ERROR'))
   if r.trial==s and player.Parent and player:GetAttribute('LobbyDriveActive')==true
    and player:GetAttribute('LobbyDriveGeneration')==r.generation then
    player:SetAttribute('ParkTrialRewardState',if s.confirmed then 'CONFIRMED'else 'UNCONFIRMED')
   end
  end)
 end
 function api:replay(player,r)
  if not r.trial or (r.trial.phase~='FINISHED'and r.trial.phase~='INVALID')then return false end
  -- Retry the same immutable receipt in the background; saving never gates racing.
  if r.trial.phase=='FINISHED'and not r.trial.confirmed then save(player,r,r.trial)end
  if r.parkMultiplayer then
   if r.trial.phase=='FINISHED'and not r.trial.raceRank then return false end
   races:remove(player)
   local slot=self:reserveRace(player);if slot==nil then return false end
   r.slot=slot;r.gridFrame=zone.StartSlots[tostring(slot+1)].CFrame
  end
  r.parkReplayMultiplier=if r.parkOvertake or r.parkMultiplayer then 1 elseif r.trial.phase=='FINISHED'then (r.trial.multiplier or 1)+1 else 1
  practice:remove(player);Drift.clear(r.training)
  r.body.Anchored=true;r.body.AssemblyLinearVelocity=Vector3.zero;r.body.AssemblyAngularVelocity=Vector3.zero
  r.kart:PivotTo(r.gridFrame);r.safe=r.gridFrame;r.boundaryPrevious=r.gridFrame.Position
  r.speed,r.yaw,r.throttle,r.steering=0,0,0,0;r.launchUntil=nil
  player:SetAttribute('LobbyDriveResetSerial',(player:GetAttribute('LobbyDriveResetSerial')or 0)+1)
  self:begin(player,r);return true
 end
 function api:step(player,r)
  local now=workspace:GetServerTimeNow();local p=r.body.Position-center
  local s=r.trial
  if r.parkMultiplayer then
   local room=races:room(player)
   if not room then s.phase='INVALID';s.invalid=true;publish(player,r);return true end
   if s.raceRank and not s.saving and not s.confirmed and not s.saveAttempted then s.saveAttempted=true;save(player,r,s)end
   if room.phase=='WAITING'or room.phase=='SEATING'or room.phase=='FILLING'then
    r.body.AssemblyLinearVelocity=Vector3.zero;r.body.AssemblyAngularVelocity=Vector3.zero;r.body.Anchored=true
    publish(player,r);return true
   end
  end
  if s.phase=='FINISHING'then
   local elapsed=now-s.finishAt
   if elapsed<RaceConfig.FINISH_ROLL_SECONDS then
    local velocity=r.body.AssemblyLinearVelocity
    r.body.AssemblyLinearVelocity=Vector3.xAxis*s.rollSpeed*(1-elapsed/RaceConfig.FINISH_ROLL_SECONDS)+Vector3.new(0,velocity.Y,0)
    r.body.AssemblyAngularVelocity=Vector3.zero
   else
    if s.finishPhase~='PRESENT'then
     r.kart:SetAttribute('KartFinishRollActive',false)
     local before=r.body.CFrame;local desired=CFrame.lookAt(before.Position,before.Position+Vector3.xAxis)
     r.kart:PivotTo(desired*before:Inverse()*r.kart:GetPivot())
     r.body.AssemblyLinearVelocity=Vector3.zero;r.body.AssemblyAngularVelocity=Vector3.zero;r.body.Anchored=true
     s.finishPhase='PRESENT'
    end
    if elapsed>=RaceConfig.FINISH_SEQUENCE_SECONDS then s.phase='FINISHED'end
   end
   publish(player,r);return true
  end
  if r.trial.phase=='RUNNING'and now<(r.trial.nextSample or 0)then return false end
  r.trial.nextSample=now+.1
  local event=Trial.step(r.trial,now,p.X,p.Y,p.Z)
  if event=='GO'then
   if r.parkMultiplayer then s.startedAt=r.parkRaceRoom.goAt end
   print(string.format('[ParkSession] event=go user=%s run=%s mode=%s',tostring(player.UserId),tostring(s.id),if r.parkMultiplayer then 'MULTIPLAYER'elseif r.parkOvertake then 'OVERTAKE'else 'TIME_ATTACK'))
   r.body.Anchored=false;r.body:SetNetworkOwner(nil)
   practice:add(player,r)
   local t=os.clock();r.training.boost=true;r.training.boostEnd=t+Config.MINI_BOOST_DURATION
   r.training.boostPress=r.training.press;r.practiceBoostPress=r.training.boostPress
   r.launchUntil=t+Config.MINI_BOOST_DURATION;r.lastInput=t;r.throttle=1
  elseif event=='INVALID'then
   print(string.format('[ParkSession] event=invalid user=%s run=%s',tostring(player.UserId),tostring(s.id)))
   practice:remove(player);Drift.clear(r.training)
   r.kart:SetAttribute('KartBoosting',false);r.kart:SetAttribute('KartDrifting',false)
  elseif event=='FINISHED'then
   print(string.format('[ParkSession] event=finish user=%s run=%s milliseconds=%s',tostring(player.UserId),tostring(s.id),tostring(s.milliseconds)))
   local s=r.trial
   if r.parkOvertake then
    s.botDistances=practice:overtakeDistances(player,s.milliseconds/1000)
    s.ahead=Overtake.countAhead(Overtake.finishDistance(r.slot),s.milliseconds/1000,s.botDistances)
   end
   if r.parkMultiplayer then races:finished(player,r,function()s.saveAttempted=true;save(player,r,s)end)end
   s.phase='FINISHING';s.finishPhase='ROLL';s.finishAt=now
   s.rollSpeed=math.max(0,r.body.AssemblyLinearVelocity:Dot(Vector3.xAxis))
   r.kart:SetAttribute('KartFinishRollDirection',Vector3.xAxis);r.kart:SetAttribute('KartFinishRollActive',true)
   r.kart:SetAttribute('RaceControlsLocked',true);r.kart:SetAttribute('KartVisualSteering',0)
   practice:remove(player);Drift.clear(r.training)
   r.kart:SetAttribute('KartBoosting',false);r.kart:SetAttribute('KartDrifting',false)
   if not r.parkMultiplayer then save(player,r,r.trial)end
  end
  publish(player,r)
  if r.trial.phase=='FINISHING'then return true end
  if r.trial.phase~='RUNNING'then
   r.body.AssemblyLinearVelocity=Vector3.zero;r.body.AssemblyAngularVelocity=Vector3.zero;r.body.Anchored=true
   r.speed,r.yaw=0,0;return true
  end
  return false
 end
 function api:recover(r)
  if not r.trial then return end
  local p=r.body.Position-center;Trial.recover(r.trial,p.X,p.Z,workspace:GetServerTimeNow())
 end
 function api:remove(player)
  if races then races:remove(player)end
  for i=1,7 do player:SetAttribute('ParkOvertakeFinishDistance'..i,nil)end
  for _,key in {'Active','StartArc','Ahead'}do player:SetAttribute('ParkOvertake'..key,nil)end
  for _,key in {'Phase','GoAt','StartedAt','Checkpoint','Missed','Invalid','Milliseconds','Target','RewardState','FinishPhase','FinishedAt','CurrentLap','TotalLaps','CompletedLaps','RewardMultiplier','RewardAmount'}do player:SetAttribute('ParkTrial'..key,nil)end
 end
 return api
end
return Session
