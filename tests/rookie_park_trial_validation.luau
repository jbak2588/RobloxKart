local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local function load(path,env)return luau.load(fs.readFile(path),{environment=env or {},debugName=path})()end
local layout=load('src/shared/HubParkRookieLoopLayout.luau')
local trial=require('./helpers/rookie_park_trial')(layout)
local n=0;local function check(v,label)n+=1;assert(v,label)end
check(#layout.Slots==8 and #layout.PitSlots==4,'eight main road grid slots, Pit decoration retained')
for i,p in layout.Slots do check(math.abs(p.z-layout.StartStraightZ)==14 and p.x==45-math.floor((i-1)/2)*30,'two columns / four rows '..i)end
local nextSlot=0
for i=0,15 do
 local chosen,nextIndex=trial.allocate({},nextSlot)
 check(chosen==i%8,'sequential allocation wraps eight grid slots');nextSlot=nextIndex
end
local full={};for i=0,7 do full[i]=true end
check(trial.allocate(full,3)==nil,'full grid refuses overlapping start')
full[6]=nil;check(trial.allocate(full,3)==6,'skip occupied slots without resetting sequence')
local points=layout.sample(layout.Segments)
local function lap(skip)
 local s=trial.new(0,45,layout.StartStraightZ)
 check(trial.step(s,2.99,45,1.75,layout.StartStraightZ)=='LOCKED','countdown holds')
 check(trial.step(s,3,45,1.75,layout.StartStraightZ)=='GO'and s.startedAt==3,'GO owns start timestamp')
 local now=3;local x,z=45,layout.StartStraightZ
 local function move(p)
  local dx,dz=p.x-x,p.z-z;local d=math.sqrt(dx*dx+dz*dz)
  now+=d/80;x,z=p.x,p.z
  return trial.step(s,now,x,1.75,z)
 end
 -- Begin partway down the start straight; finish its initial crossing without ending a lap.
 for _,p in points do
  if p.section=='StartStraight'and p.x>45 or p.section~='StartStraight'then
   local old=s.next
   move(p)
   if skip and old==skip and s.next>old then s.next=old end
  end
 end
 for _,p in points do
  if p.section~='StartStraight'or p.x>85 then break end
  move(p)
 end
 return s,now,move
end
local s=lap()
check(s.phase=='FINISHED'and s.next==7,'full sampled route crosses all six gates then finish')
check(s.milliseconds>trial.Length/110*1000,'authoritative lap duration plausible')
check(trial.step(s,1000,80,1.75,layout.StartStraightZ)=='LOCKED','finish single-shot')
local delayed=trial.new(0,45,layout.StartStraightZ)
trial.step(delayed,3,45,1.75,layout.StartStraightZ)
for tick=1,100 do trial.step(delayed,3+tick*.1,45,1.75,layout.StartStraightZ)end
for x=46,80 do trial.step(delayed,13+(x-45)/30,x,1.75,layout.StartStraightZ)end
check(delayed.finishPassed and not delayed.missed and delayed.phase=='RUNNING','initial start-line crossing is never a missing checkpoint even after delayed departure')
local bad=trial.new(0,45,layout.StartStraightZ)
trial.step(bad,3,45,1.75,layout.StartStraightZ)
for i=1,100 do trial.step(bad,3+i*.05,45+i,1.75,layout.StartStraightZ)end
-- Reverse below the start line and make a later forward finish attempt.
for x=144,60,-1 do trial.step(bad,8+(145-x)*.05,x,1.75,layout.StartStraightZ)end
for x=61,80 do trial.step(bad,12.25+(x-60)*.05,x,1.75,layout.StartStraightZ)end
check(bad.phase=='RUNNING'and bad.next==1 and bad.missed and not bad.invalid,'missing gates deny reward without permanently invalidating an off-road lap')
local reverse=trial.new(0,45,layout.StartStraightZ);trial.step(reverse,3,45,1.75,layout.StartStraightZ)
local g=trial.Gates[1];reverse.previous={x=g.x+g.fx*2,z=g.z+g.fz*2,time=4}
trial.step(reverse,4.1,g.x-g.fx*2,1.75,g.z-g.fz*2)
check(reverse.next==1,'reverse crossing cannot credit checkpoint')
local off=trial.new(0,g.x-g.fx*80,g.z-g.fz*80)
trial.step(off,3,g.x-g.fx*80,1.75,g.z-g.fz*80)
local offTime=3
for i=1,160 do
 offTime+=.05;local side=math.min(i,20)/20*50
 trial.step(off,offTime,g.x+g.fx*(i-80)-g.fz*side,1.75,g.z+g.fz*(i-80)+g.fx*side)
end
check(off.next==1 and off.route.pending==2 and not off.invalid,'Figure-8 holds off-road gate progress provisionally without INVALID')
for i=1,50 do offTime+=.05;local side=50-i
 trial.step(off,offTime,g.x+g.fx*(80+i)-g.fz*side,1.75,g.z+g.fz*(80+i)+g.fx*side)
end
check(off.next==2 and not off.invalid,'return to road accepts the same pending checkpoint as Figure-8')
local tp=trial.new(0,45,layout.StartStraightZ);trial.step(tp,3,45,1.75,layout.StartStraightZ)
trial.step(tp,3.05,g.x,1.75,g.z)
check(not tp.invalid and tp.next==1,'rejected teleport grants no gate and retains recoverable route anchors')
trial.recover(tp,45,layout.StartStraightZ,4)
check(tp.previous.x==45 and tp.next==1 and not tp.invalid,'recovery resets sweep without gate credit or validation repair')
-- Atomic wallet + personal record; same receipt survives unknown ACK/replay.
local S=load('src/shared/KDMProgressionSchema.luau')
local catalog=load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum})
local nowMs=1792800000000
local schema=S.new(catalog,{utcMs=function()return nowMs end,jsonEncode=function(v)return serde.encode('json',v)end})
local ops=load('src/server/EconomyOperations.luau')
local original=schema.default(123);original.wallet.cash=24000;original.selection.kartId='Kart09'
original.cosmetics.ownedPartIds.Wheel=true
local function op(id,ms)return {userId=123,id=string.format('12345678-1234-1234-1234-%012d',id),milliseconds=ms or s.milliseconds,completedCheckpoints=6,valid=true,transaction=schema.issueTransaction()}end
local o=op(1);local p,why=ops.parkLap(S,schema,o)(original)
check(why=='PARK_LAP_CREDITED'and schema.validate(p,S.userKey(123)),'new optional record schema valid')
check(p.wallet.cash==29000 and p.wallet.lifetimeEarned==5000 and p.parkTimeTrial.completedLaps==1,'one lap credits exactly K$5000')
local replay,status=ops.parkLap(S,schema,o)(p)
check(status=='REPLAY'and S.canonical(replay)==S.canonical(p),'unknown ACK retry never duplicates money or lap')
local faster=ops.parkLap(S,schema,op(2,s.milliseconds-1000))(p)
local slower=ops.parkLap(S,schema,op(3,s.milliseconds+1000))(faster)
check(slower.parkTimeTrial.bestMilliseconds==s.milliseconds-1000 and slower.parkTimeTrial.completedLaps==3 and slower.wallet.cash==39000,'PB takes minimum, every valid lap rewarded')
check(slower.selection.kartId=='Kart09'and slower.cosmetics.ownedPartIds.Wheel,'unrelated profile fields preserved')
for _,mutation in {function(v)v.completedCheckpoints=5 end,function(v)v.valid=false end,function(v)v.milliseconds=100 end,function(v)v.id='bad'end}do
 local badOp=op(4);mutation(badOp);check(ops.parkLap(S,schema,badOp)(slower)==nil,'invalid proof cannot award')
end
local mismatch=op(1,s.milliseconds+1);check(ops.parkLap(S,schema,mismatch)(p)==nil,'receipt identity mismatch rejected')
local recreated=ops.parkLap(S,schema,op(5))(nil)
check(schema.validate(recreated,S.userKey(123))and recreated.wallet.cash==10000,'valid first lap may initialize guest, separate starter cash retained')
local corrupt=S.clone(p);corrupt.parkTimeTrial.bestMilliseconds=-1
check(not schema.validate(corrupt,S.userKey(123)),'corrupt PB denied')
local policy=load('src/server/EconomyPolicy.luau');local config=load('src/server/EconomyConfig.luau')
local ctx={isStudio=false,role='HUB',experienceId=config.ExperienceId,placeId=config.PlaceId,privateServerId=''}
check(policy.allowed(config,ctx,123,'parkReward'),'production public HUB lap reward authorized')
ctx.role='RACE';ctx.privateServerId='reserved';ctx.privateServerOwnerId=0
check(not policy.allowed(config,ctx,123,'parkReward'),'Park reward cannot leak into official Race')
ctx.role='HUB';check(not policy.allowed(config,ctx,123,'parkReward'),'foreign private Hub excluded')
print('PASS '..n..' Rookie Park full-route, checkpoint, grid and idempotent persistent lap reward checks')
