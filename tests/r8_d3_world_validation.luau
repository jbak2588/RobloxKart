local fs,luau=require('@lune/fs'),require('@lune/luau')
local source=fs.readFile('tests/race_item_validation.luau')
source..=[[
local outcomes=0
local observer=world.onDriftOutcome(function(who,outcome) if who==player and outcome=='BOOST' then outcomes+=1 end end)
local function freshD3(mode)
 local old=world.getKartContext(player);if old then old.seat.Occupant=nil end
 world.releaseKartContext(player)
 local ctx=assert(world.acquireKartContext(player,CF.new(0,2,0),'Kart05'))
 local human=player.Character:FindFirstChildOfClass('Humanoid');human.Health=100
 ctx.seat.Occupant=human;human.SeatPart=ctx.seat
 player:SetAttribute('RaceState','RACING');ctx.kart:SetAttribute('RaceControlsLocked',false)
 ctx.kart:SetAttribute('KartOffTrack',false);ctx.crashActive=false;ctx.slick:stop();ctx.nitro:stop('fixture')
 ctx.missileHitActive=false;ctx.thunderHitActive=false;ctx.boostActive=false;ctx.driftActive=false
 ctx.commandedSpeed=50;ctx.smoothedSteering=0;ctx.currentYawRate=0
 ctx.chassis.AssemblyLinearVelocity=ctx.chassis.CFrame.LookVector*50
 services.Workspace:SetAttribute('KDMDriftMode',mode)
 return ctx
end
local function frame(ctx,steer,held,dt)
 dt=dt or 1/60;now+=dt;ctx:receiveControl(player,1,steer,held);ctx:step(dt)
 local cf=ctx.chassis.CFrame;local v=ctx.chassis.AssemblyLinearVelocity
 ctx.chassis.CFrame=CF.new(cf.Position+v*dt)*cf.Rotation*CF.Angles(0,ctx.chassis.AssemblyAngularVelocity.Y*dt,0)
 check(v.Magnitude<=100.001,'actual production total speed never bypasses 100')
 return math.deg(math.atan2(v:Dot(ctx.chassis.CFrame.RightVector),v:Dot(ctx.chassis.CFrame.LookVector)))
end
local comparisons={}
for _,mode in {'STANDARD','D2','D3'} do for _,side in {-1,1} do
 local ctx=freshD3(mode);local sum=0
 for i=1,240 do local angle=frame(ctx,side,true);if i>180 then sum+=math.abs(angle)end end
 local angle=sum/60;table.insert(comparisons,{mode=mode,side=side,angle=angle})
 check(ctx.driftReadyLatched,'production charge ready '..mode)
 if mode=='D3' then check(angle>=35 and angle<=45,'production actual 35-45 maintained') end
 if mode=='D2' then check(angle>=12 and angle<=20.1,'D2 reference preserved') end
 frame(ctx,side,false);check(ctx.boostActive,'qualified release starts Boost')
end end
local ctx=freshD3('D3')
for i=1,180 do frame(ctx,1,true)end
local before=outcomes;frame(ctx,1,false);check(outcomes==before+1 and ctx.boostActive,'one completed Drift event')
for i=1,15 do frame(ctx,0,false)end
frame(ctx,0,true);check(ctx.boostActive and not ctx.driftActive,'insufficient raw steering retains Boost')
frame(ctx,0,false)
frame(ctx,1,true)
check(ctx.driftActive and not ctx.boostActive and ctx.boostEndTime==0 and ctx.boostDriver==nil,'same fresh valid Press cancels and enters')
check(ctx.driftDuration==0 and ctx.qualifiedDuration==0 and not ctx.driftReadyLatched,'new charge exactly zero')
check(ctx.kart:GetAttribute('KartBoosting')==false and ctx.kart:GetAttribute('KartDrifting')==true,'VFX/audio/HUD mirrors cancel atomically')
check(outcomes==before+1,'cancel does not count a second Boost')
for i=1,180 do frame(ctx,1,true)end
check(ctx.driftReadyLatched,'reentered Drift charges independently')
frame(ctx,1,false);check(ctx.boostActive and outcomes==before+2,'new completed Drift has exactly one new Boost')
-- Held DRIFT predating a steer-release Boost cannot cancel that Boost.
ctx=freshD3('D3');for i=1,180 do frame(ctx,1,true)end
for i=1,50 do frame(ctx,0,true)end
check(ctx.boostActive and not ctx.driftActive,'steer release completes while DRIFT remains held')
for i=1,8 do frame(ctx,1,true)end
check(ctx.boostActive and not ctx.driftActive,'held before Boost is not a new Press')
-- Stale transport after a timeout does not invent a rising edge.
ctx.control.lastUpdate=now-config.INPUT_TIMEOUT-.01
ctx:receiveControl(player,1,1,true)
check((ctx.driftPressSerial or 0)==(ctx.boostPressSerial or 0),'timeout does not create new press')
-- Physical effect and life-cycle ownership wins over a re-entry request.
for _,kind in {'missile','thunder','slick','offTrack','nitro','locked'} do
 ctx=freshD3('D3');for i=1,180 do frame(ctx,1,true)end;frame(ctx,1,false)
 if kind=='missile' then ctx.missileHitActive=true;ctx.missileHitEndTime=now+3
 elseif kind=='thunder' then ctx.thunderHitActive=true;ctx.thunderHitEndTime=now+3
 elseif kind=='slick' then assert(world.applySlickHit(player))
 elseif kind=='offTrack' then ctx.kart:SetAttribute('KartOffTrack',true)
 elseif kind=='nitro' then ctx.nitro.active=true;ctx.nitro.driver=player;ctx.nitro.endTime=now+3
 elseif kind=='locked' then ctx.kart:SetAttribute('RaceControlsLocked',true)end
 frame(ctx,1,true);check(not ctx.driftActive,'effect prevents new Drift '..kind)
end
observer:Disconnect();services.Workspace:SetAttribute('KDMDriftMode',nil)
fs.writeFile('artifacts/r8-d3/world-comparison.json',require('@lune/serde').encode('json',{rows=comparisons,status='PASS'}))
print('PASS: D3 production World angle, total speed, fresh press, charge zero, held/timeout, one-event and effect priorities')
]]
local helper=require('./helpers/gameplay_config')
luau.load(source,{debugName='D3-actual-World',environment={require=function(n)if n=='./helpers/gameplay_config' then return helper end;return require(n)end}})()
