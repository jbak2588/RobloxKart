local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local function load(path,env)return luau.load(fs.readFile(path),{environment=env or {}})()end
local L=load('src/shared/HubParkRookieLoopLayout.luau')
local T=load('src/shared/RookieParkTrial.luau',{script={Parent={HubParkRookieLoopLayout='L'}},require=function()return L end})
local now=0;local n=0;local function check(v,m)n+=1;assert(v,m)end
local attrs={LobbyDriveActive=true};local player={Parent=true,SetAttribute=function(_,k,v)attrs[k]=v end,GetAttribute=function(_,k)return attrs[k]end}
local body={Position=rb.Vector3.new(45,1.75,L.StartStraightZ-14),AssemblyLinearVelocity=rb.Vector3.zero,AssemblyAngularVelocity=rb.Vector3.zero,SetNetworkOwner=function(_,v)check(v==nil,'server owns GO assembly')end}
local kart={PivotTo=function(_,v)body.Position=v.Position end,SetAttribute=function()end}
local r={body=body,kart=kart,training={press=0},gridFrame=rb.CFrame.new(body.Position)}
local saved,confirmed,adds,removes=0,false,0,0
local practice={add=function()adds+=1 end,remove=function()removes+=1 end}
local drift={clear=function(s)s.boost=false;s.boostEnd=0;s.press=0 end}
local Config={MINI_BOOST_DURATION=2}
local world={GetServerTimeNow=function()return now end}
local env={game={GetService=function(_,name)if name=='ReplicatedStorage'then return {Shared={RookieParkTrial='T',KartConfig='C'}}end;if name=='HttpService'then return {GenerateGUID=function()return '12345678-1234-1234-1234-000000000001'end}end end},
 workspace=world,Vector3=rb.Vector3,DateTime={now=function()return {UnixTimestampMillis=1792800000000}end},script={Parent={LobbyDriftSession='D',EconomyService='E'}},
 require=function(ref)return ({T=T,C=Config,D=drift,E={saveParkLap=function(_,p)saved+=1;check(p.completedCheckpoints==6 and p.valid and p.milliseconds>10000,'server proof valid');return {status=if confirmed then 'SAVE_CONFIRMED'else 'SAVE_UNCONFIRMED'}end}})[ref]end,
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
check(attrs.ParkTrialPhase=='FINISHED'and body.Anchored and saved==1,'real lifecycle completes valid one lap and freezes result')
check(attrs.ParkTrialRewardState=='UNCONFIRMED','failed ACK never displays reward earned')
confirmed=true;check(not session:replay(player,r)and saved==2 and attrs.ParkTrialRewardState=='CONFIRMED','Replay first retries same receipt when save unknown')
check(session:replay(player,r)and attrs.ParkTrialPhase=='COUNTDOWN','confirmed Replay resets same seat into countdown')
check(r.trial.next==1 and r.trial.distance==0 and body.Position==r.gridFrame.Position,'Replay clears gates, time and motion on grid')
check(saved==2,'repeated result observation creates no second reward')
session:remove(player)
check(attrs.ParkTrialPhase==nil and attrs.ParkTrialTarget==nil,'return/seat-loss teardown clears HUD mirrors')
print('PASS '..n..' production Park countdown/GO/boost/finish/save-retry/Replay lifecycle checks')
