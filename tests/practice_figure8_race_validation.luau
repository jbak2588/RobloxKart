-- Real TrackBuilder gates + production RaceController. Movement/time are mocked;
-- this is race-integrity evidence, never manual-driving or real-device evidence.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local source=fs.readFile('tests/race_mode_validation.luau'):gsub('\r\n','\n')
source=source:gsub('require%("%./helpers/gameplay_config"%)','_gameplay')
local first=assert(source:find('start("Track01")\ncheck',1,true))
luau.load(source:sub(1,first-1)..[====[
local geometry=modules.TrackGeometry
local definition=geometry.getDefinition('PracticeFigure8V1')
local course=geometry.getCourse(definition)
local function lookAt(position,target)
 local forward=(target-position).Unit
 local right=forward:Cross(V.yAxis).Unit
 return CF.fromMatrix(position,right,right:Cross(forward),-forward)
end
local builderEnv=table.clone(environment);builderEnv.CFrame=table.clone(CF);builderEnv.CFrame.lookAt=lookAt
builderEnv.UDim2=rb.UDim2;builderEnv.UDim=rb.UDim
builderEnv.require=function(module)return assert(modules[module.Name],module.Name)end
local builder=luau.load(fs.readFile('src/server/TrackBuilder.luau'),{environment=builderEnv})()
modules.TrackCatalog.Entries.Track01=table.clone(catalog.Entries.Track01)
track=builder.build(prototype,catalog.Entries.Track01,0)
roads=track:FindFirstChild('Road');gates=track:FindFirstChild('RaceTriggers');finish=gates:FindFirstChild('StartFinish')
checkpoints={};for i=1,6 do checkpoints[i]=gates:FindFirstChild('Checkpoint'..i)end
kart:SetAttribute('RaceStartCFrame',catalog.Entries.Track01.GridSlots[1])
-- Derive expectations from actual course/gates; never read another test's output.
local gateDistance=0
local gatePositions={course.StartPosition}
for _,cp in course.CheckpointSamples do table.insert(gatePositions,cp.Position)end
table.insert(gatePositions,course.StartPosition)
for i=1,#gatePositions-1 do gateDistance+=(gatePositions[i+1]-gatePositions[i]).Magnitude end
local function cross2(a,b)return a.X*b.Z-a.Z*b.X end
local visits={}
for i,a in course.Samples do
 local b=course.Samples[i%#course.Samples+1]
 for j=i+3,#course.Samples do
  if i==1 and j==#course.Samples then continue end
  local d,e=course.Samples[j],course.Samples[j%#course.Samples+1]
  local u,v=b-a,e-d;local denominator=cross2(u,v)
  if math.abs(denominator)<1e-8 then continue end
  local t,q=cross2(d-a,v)/denominator,cross2(d-a,u)/denominator
  if t>0 and t<1 and q>0 and q<1 then
   table.insert(visits,(i-1+t)/#course.Samples);table.insert(visits,(j-1+q)/#course.Samples)
  end
 end
end
assert(#visits==2,'actual course has exactly two crossover visits')
local metrics={minimumValidLapTime=gateDistance/100*.65,crossingFractions=visits}
local function place(f,speed,offset)
 local t=geometry.getTangentAtFraction(course.Samples,f)
 local p=geometry.getSampleAtFraction(course.Samples,f)+V.new(-t.Z,0,t.X)*(offset or 0)
 chassis.CFrame=lookAt(p,p+t);chassis.AssemblyLinearVelocity=t*(speed or 100)
end
local function move(first,last,speed,offset)
 local steps=math.ceil(math.abs(last-first)*3000)
 for i=0,steps do
  local f=first+(last-first)*i/math.max(steps,1)
  place(f,speed,if type(offset)=='function'then offset(f)else offset)
  tick(course.CenterlineLength/3000/math.abs(speed))
 end
end
local function fresh()
 services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,'ReturnGarage')
 start('Track01')
 check(player:GetAttribute('RaceTotalLaps')==2,'actual Practice two-lap authority')
 check(math.abs(modules.RaceSession.active().trackData.minimumValidLapTime-metrics.minimumValidLapTime)<.0001,'minimum lap recalculated from actual gates')
end
fresh()
move(0,1,100)
check(player:GetAttribute('RaceCompletedLaps')==1 and player:GetAttribute('RaceState')=='RACING','fast legal first actual lap accepted')
place(.001,-70);tick(.1);place(0,-70);tick(.1);place(.001,70);tick(.1)
check(player:GetAttribute('RaceCompletedLaps')==1,'finish oscillation/recross cannot double count')
move(.001,1,100)
check(player:GetAttribute('RaceCompletedLaps')==2 and player:GetAttribute('RaceState')=='FINISHING','fast legal second actual lap finishes')
tick(raceConfig.FINISH_SEQUENCE_SECONDS+.01)
check(player:GetAttribute('RaceState')=='FINISHED' and player:GetAttribute('RaceLap1Time')>metrics.minimumValidLapTime and player:GetAttribute('RaceLap2Time')>metrics.minimumValidLapTime,'two recorded physical-gate laps / terminal result')
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,'Rematch');tick(3.1)
check(player:GetAttribute('RaceCompletedLaps')==0 and player:GetAttribute('RaceNextCheckpoint')==1 and player:GetAttribute('RaceState')=='RACING','rematch clears all actual route anchors/gates')
move(1,0,-70)
check(player:GetAttribute('RaceCompletedLaps')==0 and player:GetAttribute('RaceNextCheckpoint')==1,'reverse actual Figure-8 cannot complete')
fresh()
local visits=metrics.crossingFractions
move(0,visits[1],70)
-- Same physical crossing, but leave along the later branch (skip upper loop).
move(visits[2],1,70)
check(player:GetAttribute('RaceCompletedLaps')==0 and player:GetAttribute('RaceNextCheckpoint')<=4,'wrong-loop branch shortcut rejects finish')
fresh()
-- Out-of-order far physical gates cannot produce a lap.
for _,index in {6,4,2}do
 place(.01,100);tick(.001)
 chassis.CFrame=checkpoints[index].CFrame;chassis.AssemblyLinearVelocity=checkpoints[index].CFrame.LookVector*100;tick(.001)
end
chassis.CFrame=finish.CFrame;chassis.AssemblyLinearVelocity=finish.CFrame.LookVector*100;tick(.001)
check(player:GetAttribute('RaceCompletedLaps')==0 and player:GetAttribute('RaceNextCheckpoint')==1,'teleport/skipped/out-of-order physical gates reject')
-- Even ordered physical gate teleports cannot defeat minimumValidLapTime.
for i=1,6 do
 chassis.CFrame=CF.new(1000,0,1000);tick(.001)
 chassis.CFrame=checkpoints[i].CFrame;chassis.AssemblyLinearVelocity=checkpoints[i].CFrame.LookVector*100;tick(.001)
end
chassis.CFrame=CF.new(1000,0,1000);tick(.001)
chassis.CFrame=finish.CFrame;chassis.AssemblyLinearVelocity=finish.CFrame.LookVector*100;tick(.001)
check(player:GetAttribute('RaceCompletedLaps')==0 and player:GetAttribute('RaceNextCheckpoint')==1,'impossible ordered gate shortcut rejected by actual minimum lap')
fresh()
move(0,.2,70);local earned=player:GetAttribute('RaceNextCheckpoint')
place(.2,70,70);tick(1)
check(kart:GetAttribute('KartOffTrack')==true and player:GetAttribute('RaceCompletedLaps')==0,'offroad is not road or finish')
place(.201,70);tick(.2)
check(not kart:GetAttribute('KartOffTrack') and player:GetAttribute('RaceNextCheckpoint')==earned,'ordinary recovery preserves earned gate progress')
kart:SetAttribute('RaceResetSerial',(kart:GetAttribute('RaceResetSerial')or 0)+1);tick(.1)
check(player:GetAttribute('RaceCompletedLaps')==0 and player:GetAttribute('RaceNextCheckpoint')==1,'fall invalidates only current lap and clears stale continuity')
move(0,1,80);check(player:GetAttribute('RaceCompletedLaps')==1,'valid lap after fall/recovery')
move(0,1,80);check(player:GetAttribute('RaceCompletedLaps')==2,'second recovered lap finishes')
local report={checks=count,actualGeometry='PracticeFigure8V1',twoLaps='PASS',fastLap100='PASS',reverse='PASS',wrongLoop='PASS',teleport='PASS',impossibleMinimumLap='PASS',finishOscillation='PASS',offroadRecovery='PASS',fallReset='PASS',rematch='PASS',manualDriving=false}
if require('@lune/process').args[1]=='Report' then
 fs.writeDir('artifacts/r7-p1b')
 fs.writeFile('artifacts/r7-p1b/practice_race_integrity.json',require('@lune/serde').encode('json',report))
end
print('PASS: '..count..' actual Figure-8 production-controller integrity checks')
]====],{environment={_gameplay=require('./helpers/gameplay_config')}})()
