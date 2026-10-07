-- Test-only smooth self-crossing course. No production geometry definition is added.
local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local env={Vector3=rb.Vector3,Vector2=rb.Vector2}
local function load(path)return luau.load(fs.readFile(path),{environment=env})()end
local G=load('src/shared/TrackGeometry.luau')
local P=load('src/shared/RaceRouteProgress.luau')
local samples={}
for i=0,255 do
 local theta=math.pi/4+2*math.pi*i/256
 local point=rb.Vector3.new(300*math.sin(theta),0,420*math.sin(2*theta))
 if i==96 or i==224 then point=rb.Vector3.zero end
 table.insert(samples,point)
end
local length=0
for i,p in samples do length+=(samples[i%#samples+1]-p).Magnitude end
local checkpoints={}
for _,fraction in {.10,.25,.40,.60,.75,.90}do table.insert(checkpoints,{Fraction=fraction})end
local course={Samples=samples,CenterlineLength=length,CheckpointSamples=checkpoints}
local function trace(visit,elevated)
 local used=course
 if elevated then
  used=table.clone(course);used.Samples=table.clone(samples)
  for i=193,256 do local p=used.Samples[i];used.Samples[i]=rb.Vector3.new(p.X,40,p.Z)end
 end
 local state=P.new(used,60);local nextCP=1;local rows={}
 for _,fraction in {visit-.001,visit,visit+.001}do
  local p=G.getSampleAtFraction(used.Samples,fraction)
  nextCP=P.step(state,p,nextCP,true)
  table.insert(rows,{expected=fraction,projected=state.previous,position={p.X,p.Y,p.Z},nextCheckpoint=nextCP})
 end
 return rows
end
local result={fixture='Smooth analytical figure-8, 256 samples, crossing at .375 and .875; synthetic feasibility only',crossingFractions={.375,.875},centerlineLength=length,firstLeg=trace(.375,false),secondLeg=trace(.875,false),elevatedSecondLeg=trace(.875,true),lapTests={},reverse={},shortcut={}}
for lap=1,2 do
 local state=P.new(course,60);local nextCP=1;local jumps={};local falseRecovery=0
 for step=0,2048 do
  local fraction=step/2048;local prior=state.previous;local priorCP=nextCP
  nextCP=P.step(state,G.getSampleAtFraction(samples,fraction),nextCP,true)
  if prior then
   local delta=(state.previous-prior+.5)%1-.5
   if math.abs(delta)>0.01 then table.insert(jumps,{input=fraction,previous=prior,projected=state.previous,delta=delta})end
  end
  for cp=priorCP,nextCP-1 do if checkpoints[cp].Fraction>fraction+.001 then falseRecovery+=1 end end
 end
 table.insert(result.lapTests,{lap=lap,orderedCheckpointsComplete=nextCP==7,nextCheckpoint=nextCP,falseRecovery=falseRecovery,branchJumps=jumps})
end
local state=P.new(course,60);local nextCP=1
for step=2048,0,-1 do nextCP=P.step(state,G.getSampleAtFraction(samples,step/2048),nextCP,true)end
result.reverse={nextCheckpoint=nextCP,rejected=nextCP==1}
state=P.new(course,60)
P.step(state,G.getSampleAtFraction(samples,0),1,true)
result.shortcut={nextCheckpoint=P.step(state,G.getSampleAtFraction(samples,.76),1,true)}
local nextAfterReset=P.step(P.new(course,60),G.getSampleAtFraction(samples,.76),1,true)
result.recoveryReset={nextCheckpoint=nextAfterReset}
-- Sensitivity: an ordered recovery checkpoint at the second crossing is missed.
local crossingCourse=table.clone(course);crossingCourse.CheckpointSamples={}
for _,fraction in {.1,.25,.4,.875,.9,.95}do table.insert(crossingCourse.CheckpointSamples,{Fraction=fraction})end
state=P.new(crossingCourse,60);nextCP=1
for step=0,2048 do nextCP=P.step(state,G.getSampleAtFraction(samples,step/2048),nextCP,true)end
result.crossingCheckpointSensitivity={fractions={.1,.25,.4,.875,.9,.95},nextCheckpoint=nextCP,complete=nextCP==7,scope='Route recovery only; not a physical-gate/controller completion test'}
result.distanceBetweenVisits=length/2
result.visitTimes={at50=length/2/50,at70=length/2/70,at80=length/2/80}
result.verdict='PASS: planar second-leg branch continuity; elevated Y routing remains outside P1A scope'
assert(math.abs(result.firstLeg[2].projected-.375)<1e-6,'first crossing expected leg')
assert(math.abs(result.secondLeg[2].projected-.875)<1e-6,'second crossing retains its accepted route branch')
assert(math.abs(result.elevatedSecondLeg[2].projected-.375)<1e-6,'vertical bridge alone cannot fix flattened kart Y')
assert(result.reverse.rejected and result.shortcut.nextCheckpoint==1 and nextAfterReset==1,'existing reverse/shortcut/reset guards preserved')
assert(result.lapTests[1].orderedCheckpointsComplete and result.lapTests[2].orderedCheckpointsComplete,'two traversals with checkpoints away from crossing complete in order')
assert(#result.lapTests[1].branchJumps==0 and #result.lapTests[2].branchJumps==0 and result.crossingCheckpointSensitivity.nextCheckpoint==7,'both traversals continuous; crossing checkpoint recovered')
fs.writeDir('artifacts/r7-p1a')
fs.writeFile('artifacts/r7-p1a/crossover-after.json',serde.encode('json',result,true))
print(serde.encode('json',result,true))
print('PASS: planar figure-8 continuity and ordered route recovery; not production geometry or mobile driving acceptance')
