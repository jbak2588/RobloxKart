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
  local outForward
  if mode~='STANDARD' then nextLat,nextYaw,target,outForward=Slide.step(state,c,if c.Angled then a else speed,l,input,normal,yaw,dt,active,true,speed) end
  if nextLat then l=nextLat;yaw=nextYaw else l*=math.exp(-(if active then 1.15 else 3.75)*dt);yaw=approach(yaw,normal*(if active then 1.3 else 1),3*dt) end
  maxDelta=math.max(maxDelta,math.abs(yaw-previousYaw))
  v=f*(outForward or speed)+r*l
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
  if mode~='STANDARD' then check(math.abs(measured)<c.SafetySlipDegrees+1,'bounded actual slip');check(math.abs(yaw)<=2.00001,'bounded spin') end
 end
 return {mode=mode,speed=speed,steer=steer,dt=dt,counter=counter or false,slip=slipSum/math.max(n,1),lateral=latSum/math.max(n,1),
  yaw=yawSum/math.max(n,1),radius=(if c.Angled and mode~='STANDARD' then speed else math.sqrt(speed^2+(latSum/math.max(n,1))^2))/math.max(yawSum/math.max(n,1),.001),
  rearEntrySpeed=entryRear,exitSeconds=exitTime,chargeReady=boostReady,maxYawDelta=maxDelta,samples=samples}
end

local current=c
local d2=table.clone(c);d2.Angled=false;d2.MaxSlipDegrees=20;d2.SafetySlipDegrees=26;d2.ExitRateDegrees=30
for _,speed in {30,50,65} do for _,side in {-1,1} do
 for _,mode in {'STANDARD','D2','D3'} do
  c=if mode=='D2' then d2 else current
  local row=trial(mode,speed,side,1/60);table.insert(rows,row)
  if mode=='D3' then
   check(row.slip>= (if speed>=50 then 35 else 12) and row.slip<=45,'actual maintained angle')
   check(row.exitSeconds and row.exitSeconds<1.2,'finite smooth exit')
   for _,sample in row.samples do
    if sample.t>=2.5 and sample.t<3 then check(math.abs(math.abs(sample.slip)-row.slip)<1,'steady angle '..speed..' '..row.slip..' '..sample.slip..' t='..sample.t) end
   end
  end
 end
end end
c=current
for _,dt in {1/30,1/120,.05} do for _,side in {-1,1} do trial('D3',65,side,dt,true) end end
local weak=trial('D3',50,.5,1/60);check(weak.slip<20,'weak steering shrinks angle')
for _,budget in {30,50,65,100} do
 local state={};local a,l,y=budget,0,0
 for i=1,240 do
  local nl,ny,_,nf=Slide.step(state,c,a,l,1,-.7,y,1/60,true,true,budget)
  check(nl~=nil,'solver stays active');a=nf;l=nl;y=ny
  check(math.sqrt(a*a+l*l)<=budget+.00001,'single total speed budget, no vector stacking')
 end
end
fs.writeFile('artifacts/r8-d3/physics-comparison.json',serde.encode('json',{checks=checks,rows=rows,status='PASS',method='rigid assembly fixture; Studio dynamic proof required separately'}))
print('PASS: '..checks..' STANDARD / D2 / D3 actual angle, rear trajectory, rate, exit and speed budget checks')
for _,r in rows do if r.steer==1 then print(r.mode..' '..r.speed..' angle='..r.slip..' radius='..r.radius..' rear='..r.rearEntrySpeed..' exit='..tostring(r.exitSeconds)) end end
