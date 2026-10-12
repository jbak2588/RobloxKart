local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local Slide=luau.load(fs.readFile('src/server/ArcadeDrift.luau'))()
local Balance=luau.load(fs.readFile('src/shared/KDMGameplayBalance.luau'))()
local c=Balance.DRIFT.RearSlide
local rows={};local checks=0
local function check(v,m)checks+=1;assert(v,m)end
local function approach(v,target,amount)return v+math.clamp(target-v,-amount,amount)end
local function trial(mode,speed,steer,dt,counter)
 local cf=rb.CFrame.identity;local v=cf.LookVector*speed;local yaw=0;local state={};local slipSum,latSum,yawSum,n=0,0,0,0
 local qualified,boostReady,exitTime=0,false,nil;local samples={};local maxDelta,entryRear=0,0
 local rearStart=nil;local turnCenter=nil
 local settledPosition,settledForward
 for i=1,math.floor(8/dt) do
  local t=i*dt;local active=t>=1 and t<5
  local input=if t>=5 then 0 elseif counter and t>=3 and t<4 then -steer else steer
  local f,r=cf.LookVector,cf.RightVector;local a,l=v:Dot(f),v:Dot(r)
  local slip=math.deg(math.atan2(l,a))
  if active and a>=30 and math.abs(slip)>=12 then qualified+=math.min(dt,.05) end
  if qualified>=.75 and t>=2 then boostReady=true end
  local radius=22+63*math.clamp(speed/70,0,1);local normal=-input*speed/radius
  local previousYaw=yaw
  local nextLat,nextYaw,target
  if mode=='ARCADE' then nextLat,nextYaw,target=Slide.step(state,c,speed,l,input,normal,yaw,dt,active,true) end
  if nextLat then l=nextLat;yaw=nextYaw else l*=math.exp(-(if active then 1.15 else 3.75)*dt);yaw=approach(yaw,normal*(if active then 1.3 else 1),3*dt) end
  maxDelta=math.max(maxDelta,math.abs(yaw-previousYaw))
  v=f*speed+r*l
  cf=rb.CFrame.new(cf.Position+v*dt)*cf.Rotation*rb.CFrame.Angles(0,yaw*dt,0)
  local measured=math.deg(math.atan2(v:Dot(cf.RightVector),v:Dot(cf.LookVector)))
  if t>=2.5 and t<3 and not counter then slipSum+=math.abs(measured);latSum+=math.abs(v:Dot(cf.RightVector));yawSum+=math.abs(yaw);n+=1 end
  if t>=2.5 and t<3 and not settledPosition then settledPosition=cf.Position;settledForward=cf.LookVector end
  if t>=5 and not exitTime and math.abs(measured)<1 then exitTime=t-5 end
  if t>=1 and not rearStart then rearStart=cf.Position-cf.LookVector*4 end
  if t>=1 and t<=1.4 then
   local rear=cf.Position-cf.LookVector*4
   -- Rear's body-local lateral velocity: actual CM side speed minus lever-arm yaw.
   entryRear=math.max(entryRear,math.abs(l+4*yaw))
  end
  if i%math.max(1,math.floor(.1/dt))==0 then table.insert(samples,{t=t,x=cf.Position.X,z=cf.Position.Z,yaw=yaw,slip=measured,lateral=v:Dot(cf.RightVector),rearX=(cf.Position-cf.LookVector*4).X,rearZ=(cf.Position-cf.LookVector*4).Z}) end
  check(v.Magnitude>speed*.99,'no new zero/deceleration')
  if mode=='ARCADE' then check(math.abs(measured)<27,'bounded actual slip');check(math.abs(yaw)<=2.00001,'bounded spin') end
 end
 return {mode=mode,speed=speed,steer=steer,dt=dt,counter=counter or false,slip=slipSum/math.max(n,1),lateral=latSum/math.max(n,1),
  yaw=yawSum/math.max(n,1),radius=math.sqrt(speed^2+(latSum/math.max(n,1))^2)/math.max(yawSum/math.max(n,1),.001),
  rearEntrySpeed=entryRear,exitSeconds=exitTime,chargeReady=boostReady,maxYawDelta=maxDelta,samples=samples}
end
for _,speed in {30,50,65} do for _,steer in {-.55,-1,.55,1} do
 local a=trial('STANDARD',speed,steer,1/60);local b=trial('ARCADE',speed,steer,1/60)
 table.insert(rows,a);table.insert(rows,b)
 check(b.slip>=12 and b.slip<=20.1,'target slip attained')
 check(b.radius<=a.radius*(if math.abs(steer)==1 then 1 else 1.05),'no wider sharp corner / bounded mild-turn radius '..speed..'/'..steer..' '..a.radius..'/'..b.radius)
 check(b.exitSeconds and b.exitSeconds<1,'smooth finite recovery')
 check(b.maxYawDelta<=3/60+.00001,'existing yaw acceleration bound')
 if speed>=50 then check(b.chargeReady,'existing charge qualifies') end
end end
for _,dt in {1/30,1/120,.05} do trial('ARCADE',50,.8,dt,true) end
local disabled=table.clone(c);disabled.Enabled=false
local s={active=true,recovering=true}
check(Slide.step(s,c,50,20,1,-1,0,.2,true,true)==nil and not s.active,'hitch yields to existing physics')
check(Slide.step(s,c,50,70,1,-1,0,1/60,true,true)==nil,'external large slip never snapped by solver')
check(Slide.step(s,disabled,50,20,1,-1,0,1/60,true,true)==nil and not s.active,'STANDARD bypass')
for _,reason in {'timeout','barrier','offTrack','reset','seat','slick','thunder','missile','finish','bot','brake','nitro'} do
 s={active=true,recovering=true};check(Slide.step(s,c,50,20,1,-1,0,1/60,true,false)==nil and not s.recovering,'safe yield '..reason)
end
local start=os.clock();s={};for i=1,100000 do Slide.step(s,c,50,-16,.8,-.7,-.8,1/60,true,true) end
local cost=(os.clock()-start)*1000000/100000
fs.writeFile('artifacts/r8-d1/solver-ab.json',serde.encode('json',{checks=checks,rows=rows,microsecondsPerStep=cost,method='fixed-step kinematic assembly integration; not Studio contact physics',trackExitCounts='measured separately against track geometry'}))
print('PASS: '..checks..' slide safety / A-B checks; solver '..cost..' us/step')
for _,row in rows do if row.steer==1 then print(row.mode..' '..row.speed..' slip='..row.slip..' radius='..row.radius..' exit='..tostring(row.exitSeconds)..' charge='..tostring(row.chargeReady)) end end
