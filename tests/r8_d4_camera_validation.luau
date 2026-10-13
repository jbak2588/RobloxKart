local fs,rb,luau=require('@lune/fs'),require('@lune/roblox'),require('@lune/luau')
local V,CF=rb.Vector3,rb.CFrame
local heading=luau.load(fs.readFile('src/shared/DriftCameraHeading.luau'),{environment={Vector3=V,CFrame=CF}})()
local balance=luau.load(fs.readFile('src/shared/KDMGameplayBalance.luau'))()
local config=luau.load(fs.readFile('src/shared/KartConfig.luau'),{environment={script={Parent={WaitForChild=function()end}},require=function()return balance end}})().DRIFT_CAMERA
local n=0
local function check(v,label) assert(v,label);n+=1 end
local function degrees(a,b) return math.deg(math.acos(math.clamp(a:Dot(b),-1,1)))end
for _,rate in {30,60,120} do for _,slip in {-42,-20,20,42} do
 local f=V.new(0,0,-1);local v=CF.fromAxisAngle(V.yAxis,math.rad(slip)):VectorToWorldSpace(f)*64
 local s={};local prior=0;local result
 for i=1,rate*3 do
  result=heading.step(s,f,v,1/rate,true,true,config)
  check(math.abs(s.offset-prior)<=math.rad(config.MaxRotationDegreesPerSecond)/rate+1e-6,'bounded camera offset rate')
  prior=s.offset
 end
 check(degrees(result,v.Unit)<.05,'velocity direction matches; no invented extra slip')
 for i=1,rate*2 do result=heading.step(s,f,v,1/rate,false,true,config) end
 check(degrees(result,f)<.05,'smooth exit returns body framing')
end end
for _,speed in {0,5,17,-24} do
 local s={};local f=V.new(0,0,-1)
 check(heading.step(s,f,V.new(5,0,-speed),1/60,true,true,config):FuzzyEq(f,.0001),'low/reverse speed stays body')
end
local f=V.new(0,0,-1);local s={}
for i=1,120 do heading.step(s,f,V.new(40,0,-50),1/60,true,true,config)end
local old=s.offset;heading.step(s,f,V.new(-40,0,-50),1/60,true,true,config)
check(math.abs(s.offset-old)<math.rad(2),'abrupt velocity flip cannot snap camera')
check(heading.step(s,f,V.new(40,0,-50),1/60,true,false,config)==f,'combat/reset/finish safe fallback')
check(s.offset==0 and s.velocityDirection==nil,'lifecycle discards old offset')
check(heading.step(s,f,V.new(40,0,-50),.3,true,true,config)==f,'hitch safe fallback')
for i=1,60 do check(heading.step(s,f,V.new(0,0,-70),1/60,false,true,config)==f,'normal chase unchanged')end
-- Digital mobile drift now requests the same full steering as PC.
local mobile=luau.load(fs.readFile('src/client/TouchDrivingModel.luau'))()
local b=balance.DRIFT.RearSlide
local target=b.MinSlipDegrees+(b.MaxSlipDegrees-b.MinSlipDegrees)*(mobile.DIGITAL_DRIFT_STEERING-b.EntrySteer)/(1-b.EntrySteer)
check(math.abs(target-42)<.0001,'mobile full-speed target matches PC 42 degrees')
print('PASS: '..n..' D4 heading checks; digital-mobile full-speed target '..target..' degrees')
