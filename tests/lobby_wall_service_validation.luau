local training=require('./helpers/lobby_drift_session')
local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local policy=luau.load(fs.readFile('src/shared/LobbyDrivePolicy.luau'))()
local geometry=luau.load(fs.readFile('src/shared/LobbyDriveGeometry.luau'))().create(policy)
local config=require('./helpers/gameplay_config')('src/shared/KartConfig.luau')
local n=0;local function check(v,label)assert(v,label);n+=1 end
local now,heartbeat=0,nil
local signal={Connect=function(_,fn)return {Disconnect=function()end}end}
local run={Heartbeat={Connect=function(_,fn)heartbeat=fn;return {}end}}
local physics={IsCollisionGroupRegistered=function()return true end,CollisionGroupSetCollidable=function()end}
local players={GetPlayers=function()return {}end,PlayerAdded=signal,PlayerRemoving=signal}
local workspace={GetAttribute=function(_,k)return if k=='KDMServerRole' then 'HUB' else false end}
local shared={WaitForChild=function(_,name)return {Name=name}end}
local rs={WaitForChild=function()return shared end}
local source=fs.readFile('src/server/LobbyTestDriveService.luau'):gsub('return Service%s*$','Service.inject=function(player,record) records[player]=record end;return Service')
local modules={LobbyPracticeCombat=require('./helpers/lobby_practice_stub'),LobbyDrivePolicy=policy,LobbyDriveGeometry={create=function()return geometry end},KartConfig=config,KartCatalog={},KartVisualFactory={},LobbyDriftSession=training}
local service=luau.load(source,{environment={script={Parent={LobbyDriftSession={Name='LobbyDriftSession'},LobbyPracticeCombat={Name='LobbyPracticeCombat'}}},game={PrivateServerId='',GetService=function(_,name)return ({Players=players,ReplicatedStorage=rs,RunService=run,PhysicsService=physics,Workspace=workspace})[name]end},require=function(m)return modules[m.Name]end,Instance={new=function()return {OnServerEvent=signal}end},Vector3=rb.Vector3,CFrame=rb.CFrame,os={clock=function()return now end}}})()
local center=rb.Vector3.new(120,0,766)
local zone={Destroying=signal,GetAttribute=function()return center end}
service.start(zone)
local attrs={};local player={GetAttribute=function(_,k)return attrs[k]end,SetAttribute=function(_,k,v)attrs[k]=v end}
local character={};player.Character=character
local humanoid={Health=100};local seat={Occupant=humanoid};humanoid.SeatPart=seat
local body={Parent=true,CFrame=rb.CFrame.new(154.5,1.75,895.5),AssemblyLinearVelocity=rb.Vector3.zero,AssemblyAngularVelocity=rb.Vector3.zero}
body.Position=body.CFrame.Position
local pivots={};local kartAttrs={}
local kart={SetAttribute=function(_,k,v)kartAttrs[k]=v end,GetAttribute=function(_,k)return kartAttrs[k]end,PivotTo=function(_,cf)
 table.insert(pivots,{distance=(cf.Position-body.Position).Magnitude,time=now});body.CFrame=cf;body.Position=cf.Position
end}
local safe=rb.CFrame.new(200,1.75,910)
local r={seated=true,body=body,kart=kart,seat=seat,humanoid=humanoid,character=character,training=training.new(),speed=0,yaw=0,throttle=0,steering=1,lastInput=0,safe=safe}
service.inject(player,r)
for i=1,7 do now=i*.05;r.lastInput=now;heartbeat(.05) end
check(#pivots==1 and pivots[1].distance<=3,'real heartbeat delays then applies bounded escape')
check(math.abs(body.AssemblyAngularVelocity.Y)>0 and math.abs(body.AssemblyAngularVelocity.Y)<=policy.SteeringAssist,'real near-wall low speed steering responds')
local first=now
for _=1,10 do now+=.05;r.lastInput=now;heartbeat(.05) end
check(#pivots==1,'cooldown prevents repeated corrections')
-- Repeatedly obstruct the same contact to exercise the per-episode cap and fallback.
while #pivots<4 do
 now+=.05;body.CFrame=rb.CFrame.new(154.5,1.75,895.5);body.Position=body.CFrame.Position
 body.AssemblyLinearVelocity=rb.Vector3.zero;r.lastInput=now;heartbeat(.05)
 check(now<10,'bounded progress')
end
for i=1,3 do check(pivots[i].distance<=3,'all assisted corrections bounded');if i>1 then check(pivots[i].time-pivots[i-1].time>=policy.EscapeCooldown,'actual cooldown respected')end end
check(kartAttrs.LobbyEscapeSerial==3 and r.escapeCount==3,'no fourth assist in the same episode')
check(body.Position==safe.Position and attrs.LobbyDriveResetSerial==1,'blocked fourth attempt uses original safe recovery')
check(body.AssemblyLinearVelocity.Magnitude==0,'fallback creates no velocity')
-- Normal steering away from the wall retains the accepted radius.
r.throttle,r.steering,r.speed,r.yaw=1,1,60,0;body.CFrame=safe;body.Position=safe.Position;body.AssemblyLinearVelocity=rb.Vector3.new(0,0,-60)
for _=1,100 do now+=.05;r.lastInput=now;heartbeat(.05)end
-- Roblox Vector3 stores float32; the expected -1.2 rounds to -1.20000004768.
check(math.abs(body.AssemblyAngularVelocity.Y+60/(22+63*60/70))<1e-6,'race-config normal radius shared with training')
r.drift=true;r.yaw=0;training.input(r.training,true,now,true)
for _=1,100 do now+=.05;r.lastInput=now;heartbeat(.05)end
check(r.training.active and math.abs(body.AssemblyAngularVelocity.Y)<=config.ARCADE_DRIFT.MaxYawRate,'real shared slide active and yaw bounded')
-- Real heartbeat shallow-contact projection: no crash, no outward command, no overspeed.
body.CFrame=rb.CFrame.new(120,1.75,683.5)*rb.CFrame.Angles(0,-math.pi/2+math.rad(20),0);body.Position=body.CFrame.Position
body.AssemblyLinearVelocity=body.CFrame.LookVector*60;r.speed=60;r.steering=0;r.drift=false;r.yaw=0
now+=.05;r.lastInput=now;heartbeat(.05)
check(body.AssemblyLinearVelocity.Z>=-1e-8 and body.AssemblyLinearVelocity.Magnitude<=60,'real wall slide clamps outward velocity and speed')
check(not kartAttrs.LobbyBarrierSerial,'shallow contact emits no crash event')
-- Execute the real heartbeat's combat branch: physical hits block Drift, not steering/throttle.
modules.LobbyPracticeCombat.last.hit=true
body.CFrame=safe;body.Position=safe.Position;body.AssemblyLinearVelocity=rb.Vector3.new(0,0,-40)
r.training=training.new();r.speed,r.yaw,r.throttle,r.steering=40,0,1,1
for _=1,10 do
 now+=.05;r.lastInput=now;training.input(r.training,true,now,true);heartbeat(.05)
 check(not r.training.active and not r.training.boost,'hit branch cannot restart Drift or Boost')
end
check(math.abs(body.AssemblyAngularVelocity.Y)>.3 and r.training.steer>.5,'normal steering retained during hit effect')
check(r.speed>40,'throttle continues to accelerate before the combat final cap')
print('PASS: '..n..' real service heartbeat cooldown, limit, safe fallback, steering and slide checks')
