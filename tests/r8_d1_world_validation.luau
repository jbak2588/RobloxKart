local fs,luau=require('@lune/fs'),require('@lune/luau')
local source=fs.readFile('tests/race_item_validation.luau')
source..=[[
local d1Rows={}
for _,mode in {'STANDARD','ARCADE'} do
 local previous=world.getKartContext(player);if previous then previous.seat.Occupant=nil end
 world.releaseKartContext(player)
 local ctx=assert(world.acquireKartContext(player,CF.new(0,2,0),'Kart05'))
 human=player.Character:FindFirstChildOfClass('Humanoid');human.Health=100
 ctx.seat.Occupant=human;human.SeatPart=ctx.seat
 player:SetAttribute('RaceState','RACING');ctx.kart:SetAttribute('RaceControlsLocked',false)
 ctx.kart:SetAttribute('KartOffTrack',false);ctx.crashActive=false;ctx.slick:stop();ctx.nitro:stop('fixture')
 ctx.missileHitActive=false;ctx.thunderHitActive=false;ctx.boostActive=false;ctx.driftActive=false
 ctx.commandedSpeed=50;ctx.smoothedSteering=0;ctx.currentYawRate=0
 ctx.chassis.AssemblyLinearVelocity=ctx.chassis.CFrame.LookVector*50
 services.Workspace:SetAttribute('KDMDriftMode',mode)
 local slips={}
 for i=1,180 do
  now+=1/60;ctx:receiveControl(player,1,.8,true);ctx:step(1/60)
  local cf=ctx.chassis.CFrame;local v=ctx.chassis.AssemblyLinearVelocity
  ctx.chassis.CFrame=CF.new(cf.Position+v/60)*cf.Rotation*CF.Angles(0,ctx.chassis.AssemblyAngularVelocity.Y/60,0)
  if i>120 then table.insert(slips,math.deg(math.atan2(v:Dot(ctx.chassis.CFrame.RightVector),v:Dot(ctx.chassis.CFrame.LookVector)))) end
 end
 check(ctx.driftActive and ctx.driftReadyLatched,'real World charge '..mode)
 local sum=0;for _,v in slips do sum+=math.abs(v)end;table.insert(d1Rows,{mode=mode,slip=sum/#slips})
 if mode=='ARCADE' then
  for _=1,30 do now+=1/60;ctx:receiveControl(player,1,-.8,true);ctx:step(1/60)
   local cf=ctx.chassis.CFrame;ctx.chassis.CFrame=CF.new(cf.Position+ctx.chassis.AssemblyLinearVelocity/60)*cf.Rotation*CF.Angles(0,ctx.chassis.AssemblyAngularVelocity.Y/60,0)
   check(ctx.driftActive and not ctx.boostActive,'countersteer retains drift without premature Boost')
  end
 end
 now+=1/60;ctx:receiveControl(player,1,.8,false);ctx:step(1/60)
 check(ctx.boostActive,'real World qualified release starts Mini Boost '..mode)
 for _=1,40 do now+=1/60;ctx:receiveControl(player,1,0,false);ctx:step(1/60)
  local cf=ctx.chassis.CFrame;ctx.chassis.CFrame=CF.new(cf.Position+ctx.chassis.AssemblyLinearVelocity/60)*cf.Rotation*CF.Angles(0,ctx.chassis.AssemblyAngularVelocity.Y/60,0)
  if mode=='ARCADE' then check(ctx.chassis.AssemblyLinearVelocity.Magnitude<=100.001,'exit cannot stack over Boost cap') end
 end
 check(ctx.commandedSpeed>=99,'Mini Boost 100 target preserved '..mode)
end
check(d1Rows[2].slip>=12 and d1Rows[2].slip<=20.1,'real World bounded slip')
services.Workspace:SetAttribute('KDMDriftMode',nil)
print('PASS: actual production World STANDARD slip '..d1Rows[1].slip..' / ARCADE '..d1Rows[2].slip..'; countersteer, charge, Mini Boost and planar cap')
]]
local helper=require('./helpers/gameplay_config')
luau.load(source,{debugName='D1-actual-World',environment={require=function(n)if n=='./helpers/gameplay_config' then return helper end;return require(n)end}})()
