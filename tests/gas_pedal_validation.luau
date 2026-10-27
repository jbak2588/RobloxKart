local fs,luau=require('@lune/fs'),require('@lune/luau')
local policy=luau.load(fs.readFile('src/shared/GasPedalPolicy.luau'))()
local checks=0;local function check(v,m)assert(v,m);checks+=1 end
check(policy.enabled(10768420544,127925465904803,true),'approved production target')
check(policy.enabled(10772198697,106553302629620,true),'exact private target')
for _,v in {{10768420544,106553302629620,true},{10772198697,1,true},{10772198697,106553302629620,false}}do check(not policy.enabled(unpack(v)),'rollout gate')end
for _,base in {70,80}do
 local cap,active=policy.cap(base,true,true,true,true,1,false,false,false)
 check(cap==90 and active,'held accelerator raises normal cap to 90')
 for i=1,8 do
  local a={base,true,true,true,true,1,false,false,false}
  if i<=4 then a[i+1]=false elseif i==5 then a[6]=-1 else a[i+1]=true end
  local n,on=policy.cap(unpack(a));check(n==base and not on,'release/gate/timeout/offroad/brake/boost/nitro/combat retains original cap')
 end
end
local loader=require('./helpers/gameplay_config')
local fixture=fs.readFile('tests/race_item_validation.luau')
fixture=fixture:sub(1,assert(fixture:find('-- Two real production contexts',1,true))-1)
local scenario=[====[
environment.game.GameId=10772198697;environment.game.PlaceId=106553302629620
services.Workspace:SetAttribute('KDMGasPedalEnabled',true)
local ctx=world.getKartContext(player)
local before=count
local function gasStep(held,throttle,dt)
 dt=dt or 1/60;now+=dt
 control.OnServerEvent:Fire(player,throttle or 1,0,false,held)
 services.RunService.Heartbeat:Fire(dt)
 return ctx.commandedSpeed
end
fresh();ctx.commandedSpeed=70
for _=1,240 do gasStep(true)end
check(math.abs(ctx.commandedSpeed-90)<.001 and kart:GetAttribute('KartGasPedalActive')==true,'production race remote + solver reaches 90')
local speed=gasStep(false)
check(speed<90 and speed>70 and not kart:GetAttribute('KartGasPedalActive'),'release immediately removes effect and uses existing smooth deceleration')
for _=1,120 do gasStep(false)end
check(ctx.commandedSpeed==70,'release restores actual normal 70')
gasStep(true);now+=config.INPUT_TIMEOUT+.01;services.RunService.Heartbeat:Fire(1/60)
check(not kart:GetAttribute('KartGasPedalActive'),'input timeout cancels pedal')
fresh();ctx.commandedSpeed=90;gasStep(true,-1)
check(ctx.commandedSpeed<90 and not kart:GetAttribute('KartGasPedalActive'),'brake precedence')
fresh();ctx.commandedSpeed=70;ctx.boostActive=true;ctx.boostEndTime=now+2;ctx.boostDriver=player
for _=1,60 do gasStep(true)end
check(ctx.commandedSpeed==config.MINI_BOOST_MAX_SPEED and not kart:GetAttribute('KartGasPedalActive'),'GAS never caps Mini Boost at 90')
fresh();ctx.commandedSpeed=70;gasStep(false)
check(world.activateNitro(player),'production Nitro starts')
for _=1,90 do gasStep(true)end
check(ctx.commandedSpeed==config.NITRO_MAX_SPEED and not kart:GetAttribute('KartGasPedalActive'),'GAS never caps Nitro at 90')
fresh();ctx.commandedSpeed=70;gasStep('true')
check(not kart:GetAttribute('KartGasPedalActive'),'nonboolean remote rejected as pedal')
services.Workspace:SetAttribute('KDMGasPedalEnabled',false);gasStep(true)
check(not kart:GetAttribute('KartGasPedalActive'),'server feature flag authoritative')
-- GAS/Boost and the five non-Shield item paths must not write ownership.
local ownershipWrites=0
local oldNetworkOwner=methods.SetNetworkOwner
function methods:SetNetworkOwner(owner)
 ownershipWrites+=1
 return oldNetworkOwner(self,owner)
end
services.Workspace:SetAttribute('KDMGasPedalEnabled',true)
for cycle=1,10 do
 fresh();local beforeWrites=ownershipWrites
 for _=1,60 do gasStep(true)end
 check(ownershipWrites==beforeWrites,'held GAS never writes network ownership')
 ctx.boostActive=true;ctx.boostEndTime=now+2;ctx.boostDriver=player
 for _=1,120 do gasStep(true)end
 check(ownershipWrites==beforeWrites,'Mini Boost and expiry never write network ownership')
 for _,id in {'Nitro','Smoke','Slick','Missile','Thunder'}do
  fresh(id);beforeWrites=ownershipWrites
  remote.OnServerEvent:Fire(player,'UseItem',id)
  for _=1,30 do gasStep(false)end
  check(ownershipWrites==beforeWrites,'non-Shield item path never writes ownership '..id)
 end
end
print('PASS70 repeated GAS / Mini Boost / non-Shield item ownership-write checks')
fresh();ctx.commandedSpeed=80
local stopped=false
for _=1,400 do
 local previous=ctx.commandedSpeed;gasStep(false,-1)
 check(ctx.commandedSpeed<=previous+1e-6 and ctx.commandedSpeed>=-70,'official reverse brakes then accelerates without overspeed')
 if previous>0 then
  check(ctx.commandedSpeed>=0,'official forward braking reaches zero before reversing')
 else
  stopped=true;check(previous-ctx.commandedSpeed<=config.REVERSE_ACCELERATION/60+1e-5,'official reverse keeps progressive acceleration')
 end
end
check(stopped and math.abs(ctx.commandedSpeed+70)<.001,'official shared reverse cap70 reached gradually')
print('PASS actual race GAS server integration: '..(count-before)..' checks; original race item fixture checks '..before)
]====]
luau.load(fixture..scenario,{environment={require=function(p)if p=='./helpers/gameplay_config'then return loader end;return require(p)end}})()
-- Park uses the real unchanged slide/boost adapter with a pedal-selected cap.
local config=loader('src/shared/KartConfig.luau')
local slide=luau.load(fs.readFile('src/server/ArcadeDrift.luau'))()
local adapter=luau.load(fs.readFile('src/server/LobbyDriftSession.luau'),{environment={
 game={GetService=function()return {Shared={KartConfig='config'}}end},script={Parent={ArcadeDrift='slide'}},require=function(k)return if k=='config'then config else slide end}})()
for _,base in {70,80}do
 local s=adapter.new();local speed=base
 for i=1,180 do local cap=policy.cap(base,true,true,true,true,1,s.boost,false,s.active);local _,_,_,n=adapter.step(s,i/60,1/60,speed,0,speed,1,0,true,0,0,cap,false,false);speed=n end
 check(math.abs(speed-90)<.001,'Park actual slide adapter reaches 90')
 local cap=policy.cap(base,false,true,true,true,1,false,false,false)
 local _,_,_,n=adapter.step(s,4,1/60,speed,0,speed,1,0,true,0,0,cap,false,false)
 check(n<90 and n>base,'Park release decelerates naturally')
end
print('PASS GAS gate/cap and Park adapter: '..checks..' checks')
