local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local function load(path,env)return luau.load(fs.readFile(path),{environment=env or {}})()end
local L=load('src/shared/HubParkRookieLoopLayout.luau')
local T=require('./helpers/rookie_park_trial')(L)
local now=0;local n=0;local function check(v,m)n+=1;assert(v,m)end
local attrs={LobbyDriveActive=true};local player={Parent=true,SetAttribute=function(_,k,v)attrs[k]=v end,GetAttribute=function(_,k)return attrs[k]end}
local body={CFrame=rb.CFrame.identity,Position=rb.Vector3.new(45,1.75,L.StartStraightZ-14),AssemblyLinearVelocity=rb.Vector3.zero,AssemblyAngularVelocity=rb.Vector3.zero,SetNetworkOwner=function(_,v)check(v==nil,'server owns GO assembly')end}
local kart={GetPivot=function()return body.CFrame end,PivotTo=function(_,v)body.Position=v.Position;body.CFrame=v end,SetAttribute=function()end}
local r={body=body,kart=kart,training={press=0},gridFrame=rb.CFrame.new(body.Position)}
local saved,confirmed,adds,removes=0,false,0,0
local practice={add=function()adds+=1 end,remove=function()removes+=1 end}
local drift={clear=function(s)s.boost=false;s.boostEnd=0;s.press=0 end}
local Config={MINI_BOOST_DURATION=2}
local world={GetServerTimeNow=function()return now end}
local env={game={GetService=function(_,name)if name=='ReplicatedStorage'then return {Shared={RookieParkTrial='T',KartConfig='C',RaceConfig='R'}}end;if name=='HttpService'then return {GenerateGUID=function()return '12345678-1234-1234-1234-000000000001'end}end end},
 workspace=world,Vector3=rb.Vector3,CFrame=rb.CFrame,DateTime={now=function()return {UnixTimestampMillis=1792800000000}end},script={Parent={LobbyDriftSession='D',EconomyService='E'}},
 require=function(ref)return ({T=T,C=Config,R=load('src/shared/RaceConfig.luau'),D=drift,E={saveParkLap=function(_,p)saved+=1;check(p.completedCheckpoints==6 and p.valid and p.milliseconds>10000,'server proof valid');return {status=if confirmed then 'SAVE_CONFIRMED'else 'SAVE_UNCONFIRMED'}end}})[ref]end,
 task={spawn=function(fn)fn()end},os={clock=function()return now end}}
local module=load('src/server/RookieParkTrialSession.luau',env)
local session=module.new({GetAttribute=function()return rb.Vector3.zero end},practice)
session:begin(player,r)
check(attrs.ParkTrialPhase=='COUNTDOWN'and body.Anchored,'grid frozen at 3')
now=2.9;check(session:step(player,r)and r.speed==0,'cannot drive before GO')
now=3;check(not session:step(player,r)and r.training.boost and r.training.boostEnd==5 and not body.Anchored,'GO uses normal 2s Mini Boost')
check(adds==1 and r.practiceBoostPress==r.training.boostPress,'launch neither consumes Nitro nor awards a Drift success')
local x,z=45,L.StartStraightZ-14
local function move(v)
 local dx,dz=v.x-x,v.z-z;now+=math.sqrt(dx*dx+dz*dz)/60;x,z=v.x,v.z
 body.Position=rb.Vector3.new(x,1.75,z);session:step(player,r)
end
local points=L.sample(L.Segments)
for _,v in points do if v.section~='StartStraight'or v.x>45 then move(v)end end
for _,v in points do if v.section~='StartStraight'or v.x>100 then break end;move(v)end
check(attrs.ParkTrialPhase=='FINISHING'and attrs.ParkTrialFinishPhase=='ROLL'and saved==1,'crossing starts official ROLL before result')
local finishAt=r.trial.finishAt
now=finishAt+2.4;session:step(player,r)
check(body.Anchored and attrs.ParkTrialFinishPhase=='PRESENT'and attrs.ParkTrialPhase=='FINISHING','same 2.4s roll then stopped front presentation')
now=finishAt+3.31;session:step(player,r)
check(attrs.ParkTrialPhase=='FINISHED','result waits for same 0.9s front camera transition')
check(attrs.ParkTrialRewardState=='UNCONFIRMED','failed ACK never displays reward earned')
local finished=r.trial
check(session:replay(player,r)and attrs.ParkTrialPhase=='COUNTDOWN','unconfirmed save does not block one-click Replay')
check(saved==2 and not finished.confirmed,'Replay retries original receipt without claiming reward success')
check(r.trial.next==1 and r.trial.route.pending==1 and body.Position==r.gridFrame.Position,'Replay clears gates, time and motion on grid')
-- A save that is still yielding may complete after Replay, but cannot replace the new HUD state.
local jobs={};env.task.spawn=function(fn)table.insert(jobs,fn)end
r.trial=finished;finished.saving=nil;finished.confirmed=nil;finished.phase='FINISHED'
check(session:replay(player,r)and #jobs==1,'pending retry starts once and new countdown begins immediately')
local replayTrial=r.trial;confirmed=true;jobs[1]()
check(finished.confirmed and r.trial==replayTrial and attrs.ParkTrialRewardState=='NONE','late save confirmation cannot overwrite newer lap state')
r.trial=finished;finished.saving=true;finished.confirmed=false;finished.phase='FINISHED'
check(session:replay(player,r)and #jobs==1,'in-flight save also permits Replay without duplicate retry')
now=r.trial.goAt;session:step(player,r)
check(attrs.ParkTrialPhase=='RUNNING'and not body.Anchored and r.training.boost,'Replay exits result and launches with boost after GO')
session:remove(player)
check(attrs.ParkTrialPhase==nil and attrs.ParkTrialTarget==nil,'return/seat-loss teardown clears HUD mirrors')
print('PASS '..n..' production Park countdown/GO/boost/finish/save-retry/Replay lifecycle checks')
