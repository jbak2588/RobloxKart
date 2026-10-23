-- Rookie Park lifecycle adapter; reuses the existing kart, physics and economy.
local RS=game:GetService('ReplicatedStorage')
local Trial=require(RS.Shared.RookieParkTrial)
local Config=require(RS.Shared.KartConfig)
local Drift=require(script.Parent.LobbyDriftSession)
local Session={}
function Session.new(zone,practice)
 local api={};local center=zone:GetAttribute('Center')
 function api:allocate(occupied,nextSlot)return Trial.allocate(occupied,nextSlot)end
 local function publish(player,r)
  local s=r.trial
  player:SetAttribute('ParkTrialPhase',s.phase)
  player:SetAttribute('ParkTrialGoAt',s.goAt)
  player:SetAttribute('ParkTrialStartedAt',s.startedAt)
  player:SetAttribute('ParkTrialCheckpoint',s.next-1)
  player:SetAttribute('ParkTrialMissed',s.missed)
  player:SetAttribute('ParkTrialInvalid',s.invalid)
  player:SetAttribute('ParkTrialMilliseconds',s.milliseconds)
  local target=Trial.Gates[s.next]or Trial.Finish
  player:SetAttribute('ParkTrialTarget',center+Vector3.new(target.x,4,target.z))
 end
 function api:begin(player,r)
  local pos=r.body.Position-center
  r.trial=Trial.new(workspace:GetServerTimeNow(),pos.X,pos.Z)
  r.trial.id=game:GetService('HttpService'):GenerateGUID(false)
  r.trial.transactionAt=DateTime.now().UnixTimestampMillis
  player:SetAttribute('ParkTrialRewardState','NONE')
  r.body.Anchored=true;r.speed=0;r.yaw=0
  publish(player,r)
 end
 local function save(player,r,s)
  s.saving=true;player:SetAttribute('ParkTrialRewardState','SAVING')
  task.spawn(function()
   local ok,result=pcall(function()
    return require(script.Parent.EconomyService).saveParkLap(player,{id=s.id,milliseconds=s.milliseconds,
     transaction={version=1,issuedAt=s.transactionAt},completedCheckpoints=s.next-1,valid=not s.invalid})
   end)
   s.saving=false;s.confirmed=ok and result.status=='SAVE_CONFIRMED'
   if r.trial==s and player.Parent and player:GetAttribute('LobbyDriveActive')==true
    and player:GetAttribute('LobbyDriveGeneration')==r.generation then
    player:SetAttribute('ParkTrialRewardState',if s.confirmed then 'CONFIRMED'else 'UNCONFIRMED')
   end
  end)
 end
 function api:replay(player,r)
  if not r.trial or (r.trial.phase~='FINISHED'and r.trial.phase~='INVALID')or r.trial.saving then return false end
  if r.trial.phase=='FINISHED'and not r.trial.confirmed then save(player,r,r.trial);return false end
  practice:remove(player);Drift.clear(r.training)
  r.body.Anchored=true;r.body.AssemblyLinearVelocity=Vector3.zero;r.body.AssemblyAngularVelocity=Vector3.zero
  r.kart:PivotTo(r.gridFrame);r.safe=r.gridFrame;r.boundaryPrevious=r.gridFrame.Position
  r.speed,r.yaw,r.throttle,r.steering=0,0,0,0;r.launchUntil=nil
  player:SetAttribute('LobbyDriveResetSerial',(player:GetAttribute('LobbyDriveResetSerial')or 0)+1)
  self:begin(player,r);return true
 end
 function api:step(player,r)
  local now=workspace:GetServerTimeNow();local p=r.body.Position-center
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
   practice:remove(player);Drift.clear(r.training)
   r.kart:SetAttribute('KartBoosting',false);r.kart:SetAttribute('KartDrifting',false)
   save(player,r,r.trial)
  end
  publish(player,r)
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
  for _,key in {'Phase','GoAt','StartedAt','Checkpoint','Missed','Invalid','Milliseconds','Target','RewardState'}do player:SetAttribute('ParkTrial'..key,nil)end
 end
 return api
end
return Session
