local fs,luau,rb,serde,process=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde'),require('@lune/process')
local env={Vector3=rb.Vector3,Vector2=rb.Vector2}
local function load(path)return luau.load(fs.readFile(path),{environment=env})()end
local G,P,Ranking=load('src/shared/TrackGeometry.luau'),load('src/shared/RaceRouteProgress.luau'),load('src/server/RaceRanking.luau')
local original=process.exec('git',{'show','6a08230eb8d305547b34d8f901cd9cd8f7c164af:src/shared/RaceRouteProgress.luau'})
assert(original.ok);local Old=luau.load(original.stdout,{environment=env})()
local n=0
local function check(v,label)assert(v,label);n+=1 end
local function delta(a,b)return (a-b+.5)%1-.5 end
local function near(a,b)return math.abs(delta(a,b))<1e-6 end
local samples={}
for i=0,255 do
 local theta=math.pi/4+2*math.pi*i/256
 samples[i+1]=if i==96 or i==224 then rb.Vector3.zero else rb.Vector3.new(300*math.sin(theta),0,420*math.sin(2*theta))
end
local length=0;for i,p in samples do length+=(samples[i%#samples+1]-p).Magnitude end
local cps={};for _,f in {.10,.25,.40,.60,.75,.90}do table.insert(cps,{Fraction=f})end
local course={Samples=samples,CenterlineLength=length,CheckpointSamples=cps}
local function point(f,offset)
 local t=G.getTangentAtFraction(samples,f)
 return G.getSampleAtFraction(samples,f)+rb.Vector3.new(-t.Z,0,t.X)*(offset or 0)
end
for _,visit in {.375,.875}do
 local state=P.new(course,60)
 for _,f in {visit-.001,visit,visit+.001}do
  P.step(state,point(f),1,true);check(near(state.previous,f),'crossing exact branch '..f)
 end
 for _,offset in {-20,-15,-6,-3,-1,0,1,3,6,15,20}do
  state=P.new(course,60)
  for i=0,80 do
   local f=visit-.02+i*.0005
   P.step(state,point(f,offset),1,true)
   check(math.abs(delta(state.previous,f))<.015,'crossing lane offset '..offset)
  end
 end
end
-- The geometrically closest branch is deliberately the WRONG one.
local state=P.new(course,60);P.step(state,point(.874),1,true)
local adversarial=point(.374);local oldState=Old.new(course,60);Old.step(oldState,adversarial,1,true)
check(near(oldState.previous,.374),'adversarial global nearest really is other leg')
P.step(state,adversarial,1,true);check(math.abs(delta(state.previous,.875))<.005,'compatible leg wins over closer wrong leg')
-- Actual ranking consumes accepted progress without any ranking/controller changes.
state=P.new(course,60)
for _,f in {.874,.875,.876}do
 P.step(state,point(f),5,true)
 local entries={{userId=1,completedLaps=0,nextCheckpoint=5,routeFraction=state.previous,state='RACING'},
  {userId=2,completedLaps=0,nextCheckpoint=5,routeFraction=.85,state='RACING'}}
 Ranking.sort(entries);check(entries[1].userId==1,'no transient half-lap ranking regression')
end
-- One state crosses the finish seam; the normal caller resets ordered gates per lap.
state=P.new(course,60);local nextCP=1;local last=nil
for step=0,4096 do
 local f=step/2048
 if step==2049 then nextCP=1;state.pending=1 end
 local before=nextCP;nextCP=P.step(state,point(f),nextCP,true)
 check(near(state.previous,f),'two laps stay on their own branches')
 if last then check(math.abs(delta(state.previous,last))<.002,'two-lap continuity including seam')end
 for cp=before,nextCP-1 do check(cps[cp].Fraction<=f%1+.001,'no false early checkpoint recovery')end
 if step==2048 or step==4096 then check(nextCP==7,'all six ordered checkpoints in lap')end
 last=state.previous
end
state=P.new(course,60);nextCP=1;last=nil
for step=2048,0,-1 do
 local f=step/2048;nextCP=P.step(state,point(f),nextCP,true)
 check(near(state.previous,f) and nextCP==1,'continuous reverse without checkpoint advance')
 if last then check(math.abs(delta(state.previous,last))<.002,'reverse seam and branches')end
 last=state.previous
end
for _,fractions in {{.995,.999,.002,.006},{.005,.999}}do
 state=P.new(course,60)
 for _,f in fractions do P.step(state,point(f),1,true);check(near(state.previous,f),'explicit closed seam '..f)end
end
state=P.new(course,60);P.step(state,point(.1),1,true)
local anchor,position=state.previous,state.position
P.step(state,point(.76),1,true)
check(state.previous==anchor and state.position==position,'teleport keeps BOTH accepted anchors')
P.step(state,point(.761),1,true);check(state.previous==anchor,'staying on other loop cannot reacquire globally')
P.step(state,point(.101),1,true);check(near(state.previous,.101),'deterministic compatible return reacquires')
P.step(state,point(.106),1,true);check(near(state.previous,.106),'bounded frame hitch remains a legitimate route move')
state=P.new(course,60);P.step(state,point(.76),1,true)
check(near(state.previous,.76) and state.pending==1,'fresh/reset/respawn initializes globally without inherited recovery')
state=P.new(course,60);P.step(state,point(.874),1,true);anchor=state.previous;position=state.position
P.step(state,point(.874,150),1,true)
check(state.previous==anchor and state.position==position,'large lateral excursion holds accepted anchors')
P.step(state,point(.875),1,true);check(near(state.previous,.875),'return after rejected excursion keeps branch')
-- Off-road checkpoint recovery stays provisional until a valid on-road sample.
state=P.new(course,60);nextCP=1
for i=0,220 do
 local f=i/2000;local onRoad=f<.09 or f>.105;local before=nextCP
 nextCP=P.step(state,point(f,if onRoad then 0 else 40),nextCP,onRoad)
 if not onRoad then check(nextCP==before,'off-road checkpoints remain provisional')end
end
check(nextCP==2,'compatible return settles checkpoint recovery')
-- Tight numerical parity against the original code on all existing courses.
local parity={}
for _,id in {'PracticeCircuitV1','PrototypeCircuitV2','HardCircuitV1'} do
 local definition=G.Definitions[id]
 local c=G.getCourse(definition);local metrics={}
 for _,scenario in {'forward','left','right','reverse','excursion','wrap'}do
  local a,b=Old.new(c,definition.RoadWidth),P.new(c,definition.RoadWidth)
  local ca,cb,maxError,ordinaryMax,guardedSamples=1,1,0,0,0
  for i=0,2000 do
   local f=if scenario=='reverse' then .8-i/4000 elseif scenario=='wrap' then .99+i/100000 else i/2000
   local t=G.getTangentAtFraction(c.Samples,f)
   local offset=if scenario=='left' then -10 elseif scenario=='right' then 10 else 0
   if scenario=='excursion' then for _,cp in c.CheckpointSamples do offset=math.max(offset,(definition.RoadWidth/2+30)*math.clamp((.018-math.abs(f-cp.Fraction))/.008,0,1))end end
   local pos=G.getSampleAtFraction(c.Samples,f)+rb.Vector3.new(-t.Z,0,t.X)*offset
   local road=math.abs(offset)<=definition.RoadWidth/2+8
   local accepted,anchor=b.previous,b.position
   ca=Old.step(a,pos,ca,road);cb=P.step(b,pos,cb,road)
   local error=math.abs(delta(a.previous,b.previous));maxError=math.max(maxError,error)
   local moved=if anchor then (pos-anchor).Magnitude else 0
   local limit=math.min(80,moved*3+2)
   local oldCompatible=accepted==nil or (moved<=60 and math.abs(delta(a.previous,accepted))*c.CenterlineLength<=limit)
   if oldCompatible then
    ordinaryMax=math.max(ordinaryMax,error)
    check(error<1e-5,'ordinary fraction parity '..id..'/'..scenario..'/'..i)
   else
    guardedSamples+=1
    -- The old sampled fraction violates the SAME original movement guard; matching
    -- it would reinstate the defect. Require bounded accepted motion and no drift
    -- beyond two existing sample intervals in these inside-corner stress cases.
    check(math.abs(delta(b.previous,accepted))*c.CenterlineLength<=limit+1e-6,'guarded motion remains bounded')
    check(error<=2/#c.Samples,'no persistent/gross drift on existing corner excursions')
   end
   check(ca==cb,'existing checkpoint parity '..id..'/'..scenario)
  end
  metrics[scenario]={positions=2001,maxFractionDeviation=maxError,ordinaryMaxDeviation=ordinaryMax,
   guardedSamples=guardedSamples,maxDeviationStuds=maxError*c.CenterlineLength}
 end
 parity[id]=metrics
end
fs.writeDir('artifacts/r7-p1a');fs.writeFile('artifacts/r7-p1a/existing-track-route-parity.json',serde.encode('json',parity,true))
print('PASS: '..n..' continuity, adversarial lanes, two laps, reverse, ranking, teleport/return, reset, provisional recovery and existing route parity checks')
