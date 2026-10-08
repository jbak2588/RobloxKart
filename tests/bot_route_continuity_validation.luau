-- Actual production courses and the immutable pre-P2A steering implementation.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local harness=fs.readFile('tests/track_environment_validation.luau')
local prefix=harness:sub(1,assert(harness:find('local prototype=object("Folder")',1,true))-1)
luau.load(prefix..[====[
local process,serde=require('@lune/process'),require('@lune/serde')
local S=luau.load(fs.readFile('src/server/RaceBotSteering.luau'),{environment=env})()
local balance=luau.load(fs.readFile('src/shared/KDMGameplayBalance.luau'))()
local config=luau.load(fs.readFile('src/shared/KartConfig.luau'),{environment={script={Parent={WaitForChild=function()return {}end}},require=function()return balance end}})()
local new=S.new
S.new=function(course,width)return new(course,width,config)end
local old=process.exec('git',{'show','c815d2fd0ef174e20631a9f034f43c3d7f75c9cc:src/server/RaceBotSteering.luau'})
assert(old.ok);local Old=luau.load(old.stdout,{environment=env})()
local c=geometry.getCourse(geometry.getDefinition('PracticeFigure8V1'))
local samples=c.Samples
local function delta(a,b)return (a-b+.5)%1-.5 end
local function point(course,f,offset)
 local tangent=geometry.getTangentAtFraction(course.Samples,f)
 return geometry.getSampleAtFraction(course.Samples,f)+rb.Vector3.new(-tangent.Z,0,tangent.X)*(offset or 0),tangent
end
local function frame(course,f,offset,heading)
 local p,t=point(course,f,offset);local a=math.rad(heading or 0)
 local direction=rb.Vector3.new(t.X*math.cos(a)-t.Z*math.sin(a),0,t.X*math.sin(a)+t.Z*math.cos(a))
 return frames.lookAt(p,p+direction)
end
local visits={}
for i,a in samples do
 local u=samples[i%#samples+1]-a
 for j=i+3,#samples do
  if i==1 and j==#samples then continue end
  local b=samples[j];local v=samples[j%#samples+1]-b;local denominator=cross(u,v)
  if math.abs(denominator)<1e-8 then continue end
  local t,q=cross(b-a,v)/denominator,cross(b-a,u)/denominator
  if t>0 and t<1 and q>0 and q<1 then
   table.insert(visits,(i-1+t)/#samples);table.insert(visits,(j-1+q)/#samples)
  end
 end
end
check(#visits==2,'actual Figure-8 self-intersection detected without fractions')
local function project(course,p,anchor)
 local best=math.huge;local result
 for i,a in course.Samples do
  local edge=course.Samples[i%#course.Samples+1]-a
  local alpha=math.clamp((p-a):Dot(edge)/edge:Dot(edge),0,1)
  local f=((i-1+alpha)/#course.Samples)%1
  if anchor and math.abs(delta(f,anchor))*course.CenterlineLength>40 then continue end
  local distance=(p-a-edge*alpha).Magnitude
  if distance<best then best=distance;result={fraction=f,index=i,alpha=alpha,distance=distance}end
 end
 return assert(result)
end
local function arc(course,f)
 local scaled=(f%1)*#course.Samples;local index=math.floor(scaled)+1;local result=0
 for i=1,index-1 do result+=(course.Samples[i%#course.Samples+1]-course.Samples[i]).Magnitude end
 return result+(course.Samples[index%#course.Samples+1]-course.Samples[index]).Magnitude*(scaled%1)
end
local maxTargetError=0
local function commandCheck(course,command)
 check(command.targetSpeed==70 and (command.throttle==0 or command.throttle==1) and not command.driftRequested,'nominal speed and nonnegative Bot output')
 check(command.steering==command.steering and math.abs(command.steering)<=1,'finite bounded steering')
 local target=project(course,command.target,command.routeFraction)
 local advance=(arc(course,target.fraction)-arc(course,command.routeFraction))%course.CenterlineLength
 local error=math.abs(advance-18);maxTargetError=math.max(maxTargetError,error)
 check(target.distance<.001 and error<.001,'target remains 18 studs ahead on accepted branch')
end
local oldWrong,newWrong,cases,adversarial=0,0,0,0
local examples={}
for _,visit in visits do
 for _,offset in {0,-1,1,-3,3,-6,6,-10,10,-15,15}do
  for _,heading in {-15,-8,0,8,15}do
   local state=S.new(c,60);local previous;local lastSteering
   for step=0,120 do
    local f=visit-.025+step/2400
    local cf=frame(c,f,offset,heading)
    local command=S.command(state,cf)
    check(math.abs(delta(command.routeFraction,f))*c.CenterlineLength<17,'actual crossover retains intended lane/branch')
    if previous then check(math.abs(delta(command.routeFraction,previous))*c.CenterlineLength<8,'continuous crossing approach/center/exit')end
    if lastSteering then check(math.abs(command.steering-lastSteering)<.25,'no wrong-leg steering flip')end
    commandCheck(c,command)
    previous,lastSteering=command.routeFraction,command.steering
    if step>=58 and step<=62 then
     cases+=1;local before=Old.command(samples,cf);local chosen=project(c,cf.Position)
     local wrong=math.abs(delta(chosen.fraction,f))>.05
     if wrong then oldWrong+=1 end
     if math.abs(delta(command.routeFraction,f))>.05 then newWrong+=1 end
     if wrong and chosen.distance+.001<command.distance then adversarial+=1 end
     table.insert(examples,{visit=visit,intended=f,lateral=offset,heading=heading,oldFraction=chosen.fraction,
      oldSegment=chosen.index,intendedSegment=math.floor((f%1)*#samples)+1,newSegment=command.segmentIndex,
      newFraction=command.routeFraction,oldSteering=before.steering,newSteering=command.steering,
      oldTarget={before.target.X,before.target.Z},newTarget={command.target.X,command.target.Z},wrongBefore=wrong})
    end
   end
  end
 end
end
check(oldWrong>0 and newWrong==0,'old defect reproduced; no new wrong-branch cases')
check(adversarial>0,'wrong branch strictly closer yet accepted branch wins')
local state=S.new(c,60);local trace={};local previous
for step=0,4096 do
 local f=step/2048;local command=S.command(state,frame(c,f))
 check(math.abs(delta(command.routeFraction,f))<1e-6,'two complete production Practice laps')
 if previous then check(math.abs(delta(command.routeFraction,previous))<.002,'two-lap seam continuity')end
 commandCheck(c,command);previous=command.routeFraction
 table.insert(trace,{frame=step,fraction=command.routeFraction,target={command.target.X,command.target.Z},steering=command.steering})
end
for _,fractions in {{.995,.999,.002,.006},{visits[2]+.003,visits[2]+.002,visits[2]+.001,visits[2],visits[2]-.001}}do
 S.reset(state)
 for _,f in fractions do
  local command=S.command(state,frame(c,f));check(math.abs(delta(command.routeFraction,f))<1e-6,'seam and backward motion')
  commandCheck(c,command)
 end
end
S.reset(state);S.command(state,frame(c,.10));local anchor,position=state.previous,state.position
for _,cf in {frame(c,.76),frames.lookAt(position+rb.Vector3.new(200,0,200),position)}do
 local held=S.command(state,cf)
 check(held.heldPrevious and state.previous==anchor and state.position==position,'teleport/excursion retains both accepted anchors')
 commandCheck(c,held)
end
local recovered=S.command(state,frame(c,.101));check(not recovered.heldPrevious and math.abs(delta(state.previous,.101))<1e-6,'return reacquires original leg')
S.reset(state);local reset=S.command(state,frame(c,.76));check(not reset.heldPrevious and math.abs(delta(state.previous,.76))<1e-6,'explicit reset allows fresh acquisition')
-- Corridor rejection independently of the 60-stud physical bound.
state=S.new(c,10);S.command(state,frame(c,.10));anchor,position=state.previous,state.position
local outside=S.command(state,frame(c,.10,30))
check(outside.heldPrevious and state.position==position and state.previous==anchor,'bounded corridor rejection')
check(not S.command(state,frame(c,.101)).heldPrevious,'corridor return reacquisition')
-- Vertical heading and target-at-chassis recovery must not normalize zero vectors.
state=S.new(c,60);local seed=S.command(state,frame(c,.1));local atTarget=seed.target
local zero=S.command(state,rb.CFrame.fromMatrix(atTarget,rb.Vector3.xAxis,rb.Vector3.zAxis,rb.Vector3.yAxis),0)
check(zero.steering==zero.steering and math.abs(zero.steering)<=1,'zero planar heading and zero lookahead finite')
local base=geometry.getCourse(geometry.getDefinition('PracticeCircuitV1'))
local parity={cases=0,maxTargetDeviation=0,maxSteeringDeviation=0,maxDistanceDeviation=0}
for _,offset in {0,-15,15}do
 local tracker=S.new(base,60)
 for step=0,4096 do
  local cf=frame(base,step/2048,offset);local before=Old.command(base.Samples,cf);local after=S.command(tracker,cf)
  local targetError=(before.target-after.target).Magnitude;local steeringError=math.abs(before.steering-after.steering)
  parity.cases+=1;parity.maxTargetDeviation=math.max(parity.maxTargetDeviation,targetError)
  parity.maxSteeringDeviation=math.max(parity.maxSteeringDeviation,steeringError)
  parity.maxDistanceDeviation=math.max(parity.maxDistanceDeviation,math.abs(before.distance-after.distance))
  check(targetError<.0001 and steeringError<.0001,'Base parity step '..step..' offset '..offset..' target '..targetError..' steering '..steeringError..' fraction '..after.routeFraction..' held '..tostring(after.heldPrevious))
  check(before.targetSpeed==after.targetSpeed and before.throttle==after.throttle and before.driftRequested==after.driftRequested,'Base frozen input contract')
 end
end
local performance={}
for _,id in {'PracticeCircuitV1','PracticeFigure8V1','PrototypeCircuitV2','HardCircuitV1'}do
 local definition=geometry.getDefinition(id)
 if not definition then continue end
 local course=geometry.getCourse(definition);local tracker=S.new(course,definition.RoadWidth)
 local framesToRun={};for i=0,999 do framesToRun[i+1]=frame(course,i/1000)end
 local start=os.clock()
 for _,cf in framesToRun do S.command(tracker,cf)end
 local elapsed=os.clock()-start
 performance[id]={samples=#course.Samples,segmentsPerCommand=#course.Samples,commands=1000,seconds=elapsed,
  millisecondsPerCommand=elapsed,estimated60HzMillisecondsPerSecond=elapsed*60}
end
if process.args[1]=='Report' then
 local function write(name,value)fs.writeFile('artifacts/r7-p2a/'..name..'.json',serde.encode('json',value))end
 write('bot-crossover-before-after',{visits=visits,totalCases=cases,oldWrong=oldWrong,newWrong=newWrong,strictCloserCases=adversarial,maxTargetDistanceError=maxTargetError,cases=examples})
 write('two-lap-bot-route-trace',{laps=2,frames=#trace,trace=trace})
 write('base-steering-parity',parity);write('performance',performance)
end
print('PASS: '..count..' Bot branch continuity checks; old wrong '..oldWrong..'/'..cases..'; new '..newWrong..'; strict closer '..adversarial..'; Base parity '..parity.cases)
]====],{debugName='bot-route-continuity'})()
