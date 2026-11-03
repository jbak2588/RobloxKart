local fs,luau=require('@lune/fs'),require('@lune/luau')
local source=fs.readFile('tests/rookie_park_trial_session_validation.luau')
local prefix=source:sub(1,assert(source:find('local module=load(',1,true))-1)
local scenario=[=[
local parent=setmetatable({},{__index=function(_,k)return k end})
local refs={RookieParkTrial=T,HubParkRookieLoopLayout=L}
local policyEnv={script={Parent=parent},require=function(k)return refs[k]end}
refs.ParkOvertakePolicy=load('src/shared/ParkOvertakePolicy.luau',policyEnv)
local P=load('src/shared/ParkMultiplayerPolicy.luau',policyEnv);refs.ParkMultiplayerPolicy=P
local zone=rb.Instance.new('Model');zone:SetAttribute('Center',rb.Vector3.zero)
local slots=rb.Instance.new('Folder');slots.Name='StartSlots';slots.Parent=zone
for i,s in L.Slots do local p=rb.Instance.new('Part');p.Name=tostring(i);p.CFrame=rb.CFrame.lookAt(rb.Vector3.new(s.x,1.75,s.z),rb.Vector3.new(s.x+1,1.75,s.z));p.Parent=slots end
practice.folder=rb.Instance.new('Folder');practice.folder.Parent=zone
practice.addParkRaceBot=function(_,room,slot,index,speed)return {slot=slot,distance=P.startProgress(slot)}end
practice.removeParkRaceBot=function()end
local getService=env.game.GetService
env.game.GetService=function(self,name)if name=='ReplicatedStorage'then return {Shared={RookieParkTrial='T',KartConfig='C',RaceConfig='R',ParkMultiplayerPolicy='P'}}end;return getService(self,name)end
local previousRequire=env.require
env.require=function(ref)
 if ref=='P'then return P elseif ref=='M'then return refs.Session elseif ref=='E'then return {saveParkRace=function(_,proof)
  saved+=1;check(proof.completedLaps==3 and proof.completedCheckpoints==18 and proof.position==1 and proof.humans==1 and proof.humanPosition==1,'server finalized three-lap rank proof')
  return {status='SAVE_CONFIRMED'}
 end}end
 return previousRequire(ref)
end
env.script.Parent.ParkMultiplayerSession='M'
local sessionEnv=table.clone(env);sessionEnv.require=function(k)return refs[k]end
sessionEnv.game={GetService=function(_,name)if name=='ReplicatedStorage'then return {Shared=parent}end;return getService(nil,name)end}
sessionEnv.Instance=rb.Instance;sessionEnv.Random={new=function()return {NextNumber=function()return .5 end,NextInteger=function(_,a,b)return b end}end}
refs.Session=load('src/server/ParkMultiplayerSession.luau',sessionEnv)
local module=load('src/server/RookieParkTrialSession.luau',env);local api=module.new(zone,practice)
r.parkMultiplayer=true;r.generation=1;attrs.LobbyDriveGeneration=1;r.slot=assert(api:reserveRace(player))
check(api:begin(player,r)and attrs.ParkTrialTotalLaps==3 and attrs.ParkRacePhase=='WAITING','new mode enters real trial adapter')
now=9.99;api:update();api:step(player,r);check(body.Anchored and adds==0 and saved==0,'human window locks physical kart')
now=10;api:update()
for i=1,8 do now+=.31;api:update();api:step(player,r)end
check(attrs.ParkRaceBots==7 and attrs.ParkRacePhase=='COUNTDOWN','seven sequential opponents then countdown')
now=r.trial.goAt;api:update();api:step(player,r)
check(attrs.ParkTrialPhase=='RUNNING'and not body.Anchored and adds==1 and r.training.boost,'ordinary launch boost and manual ownership')
local x,z=45,L.StartStraightZ-14
local function move(v)
 local dx,dz=v.x-x,v.z-z;now+=math.sqrt(dx*dx+dz*dz)/100;x,z=v.x,v.z
 body.Position=rb.Vector3.new(x,1.75,z);api:update();api:step(player,r)
end
local points=L.sample(L.Segments)
for circuit=1,3 do
 for _,v in points do if v.section~='StartStraight'or v.x>x then move(v)end end
 for _,v in points do if v.section~='StartStraight'or v.x>100 then break end;move(v)end
 check(saved==0,'no reward until complete route and final order')
end
check(attrs.ParkTrialPhase=='FINISHING','full three laps use original finish presentation')
now+=.3;api:update();api:step(player,r)
check(saved==1 and attrs.ParkTrialRewardState=='CONFIRMED'and attrs.ParkTrialRewardAmount==1500,'solo-plus-bots public base reward, confirmed only after save')
now=r.trial.finishAt+3.31;api:step(player,r)
check(api:replay(player,r)and attrs.ParkRacePhase=='WAITING'and attrs.ParkTrialRewardMultiplier==1,'Race Again joins a new roster, no Overtake/time-attack multiplier')
api:remove(player);check(attrs.ParkRaceId==nil and attrs.ParkTrialPhase==nil,'mode, session and trial cleanup')
zone:Destroy()
print('PASS '..n..' real Park multiplayer trial adapter / full route / save / replay checks')
]=]
luau.load(prefix..scenario,{environment={require=function(path)return require(path)end},debugName='park_multiplayer_trial_session'})()
