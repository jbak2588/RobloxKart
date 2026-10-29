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
 function api:allocate(occupied,nextSlot)return Trial.allocate(occupied,nextSlot)end
 local function publish(player,r)
  local s=r.trial
  for i=1,7 do player:SetAttribute('ParkOvertakeFinishDistance'..i,if s.botDistances then s.botDistances[i]else nil)end
  player:SetAttribute('ParkTrialPhase',s.phase)
  player:SetAttribute('ParkTrialCurrentLap',s.lap)
  player:SetAttribute('ParkTrialTotalLaps',s.targetLaps or Trial.Laps)
  player:SetAttribute('ParkOvertakeActive',r.parkOvertake==true)
  player:SetAttribute('ParkOvertakeStartArc',if r.parkOvertake then s.overtakeStartArc else nil)
  player:SetAttribute('ParkOvertakeAhead',if r.parkOvertake then s.ahead or 0 else nil)
  player:SetAttribute('ParkTrialCompletedLaps',s.completedLaps)
  player:SetAttribute('ParkTrialRewardMultiplier',s.multiplier)
  player:SetAttribute('ParkTrialRewardAmount',if r.parkOvertake then Overtake.reward(s.ahead or 0)else Trial.Reward*s.multiplier)
  player:SetAttribute('ParkTrialGoAt',s.goAt)
  player:SetAttribute('ParkTrialStartedAt',s.startedAt)
  player:SetAttribute('ParkTrialCheckpoint',s.next-1)
  player:SetAttribute('ParkTrialMissed',s.missed)
  player:SetAttribute('ParkTrialInvalid',s.invalid)
  player:SetAttribute('ParkTrialMilliseconds',s.milliseconds)
  player:SetAttribute('ParkTrialFinishPhase',s.finishPhase)
  player:SetAttribute('ParkTrialFinishedAt',s.finishAt)
  local target=Trial.Gates[s.next]or Trial.Finish
  player:SetAttribute('ParkTrialTarget',center+Vector3.new(target.x,4,target.z))
 end
 function api:begin(player,r)
  local pos=r.body.Position-center
  r.trial=Trial.new(workspace:GetServerTimeNow(),pos.X,pos.Z,if r.parkOvertake then {laps=Overtake.Laps,countdown=Overtake.Countdown}else nil)
  r.trial.ahead=0
  if r.parkOvertake then r.trial.overtakeStartArc=Overtake.startArc(r.slot)end
  r.trial.multiplier=r.parkReplayMultiplier or 1
  r.trial.id=game:GetService('HttpService'):GenerateGUID(false)
  r.trial.transactionAt=DateTime.now().UnixTimestampMillis
  player:SetAttribute('ParkTrialRewardState','NONE')
  r.kart:SetAttribute('KartFinishRollActive',false);r.kart:SetAttribute('RaceControlsLocked',false)
  r.body.Anchored=true;r.speed=0;r.yaw=0
  publish(player,r)
 end
 local function save(player,r,s)
  if s.saving or s.confirmed then return end
  s.saving=true;player:SetAttribute('ParkTrialRewardState','SAVING')
  task.spawn(function()
   local ok,result=pcall(function()
    local economy=require(script.Parent.EconomyService)
    if r.parkOvertake then
     return economy.saveParkOvertake(player,{id=s.id,milliseconds=s.milliseconds,slot=r.slot,ahead=s.ahead,botDistances=s.botDistances,
      transaction={version=1,issuedAt=s.transactionAt},completedCheckpoints=(s.completedLaps or 0)*6,valid=not s.invalid,completedLaps=s.completedLaps})
    end
    return economy.saveParkLap(player,{id=s.id,milliseconds=s.milliseconds,
     transaction={version=1,issuedAt=s.transactionAt},completedCheckpoints=(s.completedLaps or 0)*6,valid=not s.invalid,
     proofVersion=2,completedLaps=s.completedLaps,bestLapMilliseconds=math.min(table.unpack(s.lapTimes)),rewardMultiplier=s.multiplier})
   end)
   s.saving=false;s.confirmed=ok and type(result)=='table' and result.status=='SAVE_CONFIRMED'
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
  r.parkReplayMultiplier=if r.parkOvertake then 1 elseif r.trial.phase=='FINISHED'then (r.trial.multiplier or 1)+1 else 1
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
   r.body.Anchored=false;r.body:SetNetworkOwner(nil)
   practice:add(player,r)
   local t=os.clock();r.training.boost=true;r.training.boostEnd=t+Config.MINI_BOOST_DURATION
   r.training.boostPress=r.training.press;r.practiceBoostPress=r.training.boostPress
   r.launchUntil=t+Config.MINI_BOOST_DURATION;r.lastInput=t;r.throttle=1
  elseif event=='INVALID'then
   practice:remove(player);Drift.clear(r.training)
   r.kart:SetAttribute('KartBoosting',false);r.kart:SetAttribute('KartDrifting',false)
  elseif event=='FINISHED'then
   local s=r.trial
   if r.parkOvertake then
    s.botDistances=practice:overtakeDistances(player,s.milliseconds/1000)
    s.ahead=Overtake.countAhead(Overtake.finishDistance(r.slot),s.milliseconds/1000,s.botDistances)
   end
   s.phase='FINISHING';s.finishPhase='ROLL';s.finishAt=now
   s.rollSpeed=math.max(0,r.body.AssemblyLinearVelocity:Dot(Vector3.xAxis))
   r.kart:SetAttribute('KartFinishRollDirection',Vector3.xAxis);r.kart:SetAttribute('KartFinishRollActive',true)
   r.kart:SetAttribute('RaceControlsLocked',true);r.kart:SetAttribute('KartVisualSteering',0)
   practice:remove(player);Drift.clear(r.training)
   r.kart:SetAttribute('KartBoosting',false);r.kart:SetAttribute('KartDrifting',false)
   save(player,r,r.trial)
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
  for i=1,7 do player:SetAttribute('ParkOvertakeFinishDistance'..i,nil)end
  for _,key in {'Active','StartArc','Ahead'}do player:SetAttribute('ParkOvertake'..key,nil)end
  for _,key in {'Phase','GoAt','StartedAt','Checkpoint','Missed','Invalid','Milliseconds','Target','RewardState','FinishPhase','FinishedAt','CurrentLap','TotalLaps','CompletedLaps','RewardMultiplier','RewardAmount'}do player:SetAttribute('ParkTrial'..key,nil)end
 end
 return api
end
return Session
