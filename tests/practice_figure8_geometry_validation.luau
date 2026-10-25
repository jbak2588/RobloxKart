-- Actual production geometry; no synthetic geometry substitutes for this test.
local fs,luau= require('@lune/fs'),require('@lune/luau')
local harness=fs.readFile('tests/track_environment_validation.luau')
local prefix=harness:sub(1,assert(harness:find('local prototype=object("Folder")',1,true))-1)
luau.load(prefix..[====[
local serde,process=require('@lune/serde'),require('@lune/process')
local P=luau.load(fs.readFile('src/shared/RaceRouteProgress.luau'),{environment=env})()
local catalog=luau.load(fs.readFile('src/shared/TrackCatalog.luau'),{environment=env})()
local track=catalog.Entries.Track01
local def=geometry.getDefinition(track.GeometryId)
local c=geometry.getCourse(def)
-- Immutable accepted P1 fixture travels with the checkpoint; no diagnostic input.
local beforeDefinition=serde.decode('json',fs.readFile('tests/fixtures/practice_figure8_p1_baseline.json'))
local beforeCourse={CenterlineLength=beforeDefinition.CenterlineLength}
local extension=c.CenterlineLength/beforeCourse.CenterlineLength-1
check(extension>=.07 and extension<=.12,'approved minimal straight-extension envelope')
for _,index in {2,4,6,8}do
 local old,new=beforeDefinition.Segments[index],def.Segments[index]
 check(old[4]==new[4] and math.abs(old[5]-new[5])<1e-10 and math.abs(old[6]-new[6])<1e-10,'accepted corner radius/heading preserved')
end

check(track.GeometryId=='PracticeFigure8V1' and track.TargetLaps==3 and track.MaxPlayers==4 and track.MinPlayers==1 and track.MatchType=='PUBLIC_RACE' and track.BotAllowed==true,'Practice public three-lap contract')
check(track.PreviewImageAssetId=='rbxassetid://75369478362729','P1C user-approved Figure-8 selection artwork')
check(c.CenterlineLength>=1700 and c.CenterlineLength<=2500 and def.RoadWidth==60,'short forgiving practice course')
local function difference(a,b)return (a-b+.5)%1-.5 end
local function position(f,offset)
 local tangent=geometry.getTangentAtFraction(c.Samples,f)
 return geometry.getSampleAtFraction(c.Samples,f)+rb.Vector3.new(-tangent.Z,0,tangent.X)*(offset or 0)
end
local function signature(node)
 local rows={}
 local function visit(item,path)
  if item.Name:find('StartLine') or item.Name=='StartGrid' or item.Name:find('CenterDash') or item.Name:find('DirectionMarkers') or item.Name:find('ForwardChevron') or item.Name:find('CrossoverChevron') or item.Name:find('Chevron') or item.Name:find('VisualRails') then return end
  local props={};for key,value in item.props do if key~='Parent' then table.insert(props,key..'='..tostring(value))end end;table.sort(props)
  local attrs={};for key,value in item.attrs do
   if key~='CheckerPartCount' and key~='StartFinishPaintVersion' and key~='StartFinishCheckerRows' and key~='StartGridRows' and key~='StartGridColumns' and key~='ChevronStandardVersion' and key~='ChevronClusterCount' and key~='ChevronPartCount' and key~='VisualPartCount' and key~='EnvironmentPartCount' and key~='VisualRailPartCount' and key~='BrandedVisualRailCount' then
    table.insert(attrs,key..'='..tostring(value))
   end
  end;table.sort(attrs)
  table.insert(rows,path..'|'..table.concat(props,';')..'|'..table.concat(attrs,';'))
  for _,child in item:GetChildren()do visit(child,path..'/'..child.Name)end
 end
 visit(node,'');return table.concat(rows,'\n')
end
local oldSource=process.exec('git',{'show','6a08230eb8d305547b34d8f901cd9cd8f7c164af:src/server/TrackBuilder.luau'});assert(oldSource.ok)
local oldBuilder=luau.load(oldSource.stdout,{environment=env})()
local oldCatalog=process.exec('git',{'show','6a08230eb8d305547b34d8f901cd9cd8f7c164af:src/shared/TrackCatalog.luau'});assert(oldCatalog.ok)
local frozenCatalog=luau.load(oldCatalog.stdout,{environment=env})()
local function equal(a,b)
 if type(a)~='table' or type(b)~='table' then return a==b end
 for k,v in a do if not equal(v,b[k])then return false end end
 for k in b do if a[k]==nil then return false end end;return true
end
local budgets={}
local function budget(world)
 local result={Part=0,MeshPart=0,Script=0,LocalScript=0,ModuleScript=0}
 local function visit(node)
  if result[node.ClassName]~=nil then result[node.ClassName]+=1 end
  for _,child in node:GetChildren()do visit(child)end
 end;visit(world)
 for _,folder in {'Road','Markings','Kerbs','Barriers','BarrierTriggers','RaceTriggers','Environment','DirectionMarkers'}do
  local item=world:FindFirstChild(folder);local n=0
  local function parts(node)if node:IsA('BasePart')then n+=1 end;for _,child in node:GetChildren()do parts(child)end end
  if item then parts(item)end;result[folder]=n
 end;return result
end
for _,id in {'Track01Race','Track03'}do
 local entry=table.clone(catalog.Entries[id]);entry.BotAllowed=nil
 check(equal(entry,frozenCatalog.Entries[id]),'frozen full catalog except authorized Bot capability '..id)
 local now=builder.build(object('Folder'),catalog.Entries[id],0)
 local old=oldBuilder.build(object('Folder'),frozenCatalog.Entries[id],0)
 check(signature(now)==signature(old),'frozen complete generated world '..id)
 budgets[id]=budget(now)
end
for i,p in c.Samples do
 check(p.Y==0 and (c.Samples[i%#c.Samples+1]-p).Magnitude>1,'closed planar nonzero segments')
end
local crossing={}
for i,a in c.Samples do
 local b=c.Samples[i%#c.Samples+1]
 for j=i+3,#c.Samples do
  if j==#c.Samples and i==1 then continue end
  local d,e=c.Samples[j],c.Samples[j%#c.Samples+1]
  local u,v=b-a,e-d;local denominator=cross(u,v)
  if math.abs(denominator)<1e-8 then continue end
  local t,q=cross(d-a,v)/denominator,cross(d-a,u)/denominator
  if t>0 and t<1 and q>0 and q<1 then
   table.insert(crossing,{First=(i-1+t)/#c.Samples,Second=(j-1+q)/#c.Samples,Position=a+u*t})
  end
 end
end
check(#crossing==1,'exactly one self crossing / two course visits')
local visits={crossing[1].First,crossing[1].Second};local traces={}
for _,visit in visits do
 for _,offset in {0,-1,1,-3,3,-6,6,-10,10,-15,15}do
  local state=P.new(c,60);local previous
  for step=0,120 do
   local f=visit-.025+step/2400
   P.step(state,position(f,offset),1,true)
   check(math.abs(difference(state.previous,f))*c.CenterlineLength<=17,'actual crossing stays intended lane/branch')
   if previous then check(math.abs(difference(state.previous,previous))*c.CenterlineLength<8,'crossing continuity')end
   previous=state.previous
  end
 end
 local state=P.new(c,60);local trace={}
 for _,f in {visit-.001,visit,visit+.001}do P.step(state,position(f),1,true);table.insert(trace,{intended=f,actual=state.previous});check(math.abs(difference(state.previous,f))<1e-6,'actual crossover exact center trace')end
 table.insert(traces,trace)
 local other=if visit==visits[1]then visits[2]else visits[1]
 state=P.new(c,60);P.step(state,position(visit-.003),1,true)
 P.step(state,position(other+.001),1,true)
 check(math.abs(difference(state.previous,visit))*c.CenterlineLength<15,'closer wrong branch cannot steal prior route')
end
local state=P.new(c,60);local nextCP=1;local last
for step=0,6000 do
 if step==3001 then nextCP=1;state.pending=1 end
 local f=step/3000;nextCP=P.step(state,position(f),nextCP,true)
 check(math.abs(difference(state.previous,f))<1e-6,'two actual laps one continuous state')
 if last then check(math.abs(difference(state.previous,last))<.001,'no jump/stale anchor')end;last=state.previous
 if step==3000 or step==6000 then check(nextCP==7,'six ordered checkpoints each actual lap')end
end
state=P.new(c,60);nextCP=1
for step=3000,0,-1 do nextCP=P.step(state,position(step/3000),nextCP,true)end
check(nextCP==1,'actual full reverse rejected')
state=P.new(c,60);P.step(state,position(.1),1,true);local anchor=state.previous
P.step(state,position(.7),1,true);check(state.previous==anchor,'teleport holds accepted anchor')
P.step(state,position(.101),1,true);check(math.abs(difference(state.previous,.101))<1e-6,'compatible recovery works')
local zones={};local usefulExits=0
for i,zone in def.DriftZones do
 local length=(zone.EndFraction-zone.StartFraction)*c.CenterlineLength
 check(length/50>=1 and zone.Radius>=75,'sustained beginner drift sector '..i)
 local nextZone=def.DriftZones[i%#def.DriftZones+1]
 local exit=((nextZone.StartFraction-zone.EndFraction)%1)*c.CenterlineLength
 if exit>=170 then usefulExits+=1 end
 table.insert(zones,{name=zone.Name,startFraction=zone.StartFraction,endFraction=zone.EndFraction,radius=zone.Radius,headingDegrees=zone.HeadingDegrees,direction=if zone.HeadingDegrees<0 then 'LEFT'else 'RIGHT',length=length,time30=length/30,time40=length/40,time50=length/50,exitCorridor=exit,manual='PENDING'})
end
check(#zones==4 and usefulExits>=2,'eight drift attempts / two long boost exits per lap')
for i,zone in zones do
 local old=beforeDefinition.DriftZones[i]
 local oldExit=((beforeDefinition.DriftZones[i%4+1].StartFraction-old.EndFraction)%1)*beforeCourse.CenterlineLength
 check(zone.exitCorridor>=oldExit-.2,'no accepted boost corridor shortened')
end

for i,slot in track.GridSlots do
 check(slot.LookVector:Dot(c.StartTangent)>.999,'forward grid slot '..i)
 local delta=slot.Position-c.StartPosition
 check(delta:Dot(c.StartTangent)<-20 and math.abs(delta:Dot(rb.Vector3.new(-c.StartTangent.Z,0,c.StartTangent.X)))<15,'grid behind gate within asphalt')
 local d=slot.Position-def.Crossover.Position
 check(math.abs(d.Z)>def.Crossover.VisualHalfLength+6,'all grid slots outside crossing/apron')
 for j=1,i-1 do check((slot.Position-track.GridSlots[j].Position).Magnitude>=16,'grid spacing')end
end
local world=builder.build(object('Folder'),track,0);budgets.Track01=budget(world)
check(budgets.Track01.Part<=1400,'static polish remains inside mobile part budget')
check(world:GetAttribute('PracticeTreeCount')>=8 and world:GetAttribute('PracticeTreeCount')<=18,'bounded native tree family')
check(world:GetAttribute('PracticeBillboardPartCount')==42 and world:GetAttribute('PracticeSignalPartCount')==0,'sanitized donor structure / deferred signal')
check(world:GetAttribute('ChevronClusterCount')==4 and world:GetAttribute('ChevronPartCount')==12,'Figure-8 four curves with three boards each')
local visualRails=world:FindFirstChild('Environment'):FindFirstChild('VisualRails')
local fig8ChevronRails=0
for _,rail in (if visualRails then visualRails:GetChildren() else {})do
 local dir=rail:GetAttribute('ChevronDirection')
 if dir then
  fig8ChevronRails+=1
  check(math.abs(rail.Size.Y-6.0)<.001 and math.abs(rail.Size.Z-12.0)<.001,'Figure-8 chevron board is 6.0x12.0 studs')
  local expectedAsset=if dir=='Left'then'rbxassetid://125863354300599'else'rbxassetid://118109633914676'
  check(rail:GetAttribute('ChevronAssetId')==expectedAsset,'Figure-8 chevron asset matches curve direction')
  local face=if rail:FindFirstChild('KDMChevronSurfaceGui_Left')then 'Left'else 'Right'
  check(not(rail:FindFirstChild('KDMChevronSurfaceGui_Left')and rail:FindFirstChild('KDMChevronSurfaceGui_Right')),'rear face blank')
  for _,face in {face}do
   local gui=rail:FindFirstChild('KDMChevronSurfaceGui_'..face)
   local panel=gui and gui:FindFirstChild('ChevronPanel')
   local img=panel and panel:FindFirstChild('ChevronImage')
   check(img and img.Image==expectedAsset,'Figure-8 chevron board has 1024x512 asset on '..face)
  end
 end
end
check(fig8ChevronRails==12,'all 12 Figure-8 curve boards have single-sided chevron assets')
check(budgets.Track01.Script==0 and budgets.Track01.LocalScript==0 and budgets.Track01.ModuleScript==0 and budgets.Track01.MeshPart==0,'no donor code or runtime mesh dependencies')
local landmarks=world:FindFirstChild('Environment'):FindFirstChild('PracticeLandmarks')
for _,model in landmarks:GetChildren()do
 for _,part in model:GetChildren()do
  if part:IsA('BasePart')then
   check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,'sanitized landmarks nonphysical')
   for _,point in c.Samples do check((rb.Vector2.new(part.Position.X-point.X,part.Position.Z-point.Z)).Magnitude>=50,'landmark outside shoulder/camera corridor')end
  end
 end
end
local dirMarkers = world:FindFirstChild('DirectionMarkers')
for _,cluster in (if dirMarkers then dirMarkers:GetChildren() else {})do
 local index=cluster:GetAttribute('SampleIndex')
 local expected=if index then geometry.getTangentAtFraction(c.Samples,(index-1)/#c.Samples)else cluster:GetAttribute('ForwardTangent')
 local wing=cluster:GetChildren()[1];local nextWing=cluster:GetChildren()[2]
 local head=(wing.Position+nextWing.Position)*.5
 local tangent=if index then (c.Samples[index%#c.Samples+1]-c.Samples[(index-2)%#c.Samples+1]).Unit else cluster:GetAttribute('ForwardTangent')
 check(tangent:Dot(expected)>=.95,'lane-centered cue follows actual forward tangent')
end
check(world:GetAttribute('CheckpointCount')==6 and world:GetAttribute('BarrierTriggerPartCount')==0,'six physical gates / forgiving untrapped exits')
check(not world:FindFirstChild('Environment'):FindFirstChild('CrossoverApron'),'monolithic square apron removed')
for _,name in {'CrossoverRibbonA','CrossoverRibbonB'}do
 local ribbon=world:FindFirstChild('Environment'):FindFirstChild(name)
 check(ribbon and ribbon.Anchored and not ribbon.CanCollide and not ribbon.CanTouch and not ribbon.CanQuery,'branch-aligned nonphysical crossover visual')
 check(ribbon.Position.Y-ribbon.Size.Y/2>.065,'ribbon above coplanar asphalt without physical bump')
end
for _,part in world:FindFirstChild('Markings'):GetChildren()do
 if part:IsA('BasePart') and not part.Name:find('StartLine')then
  local d=part.Position-def.Crossover.Position
  check(rb.Vector2.new(d.X,d.Z).Magnitude>def.Crossover.KerbClearRadius,'legacy markings terminate outside overlap; dedicated guidance replaces them')
 end
end
for _,part in world:FindFirstChild('Kerbs'):GetChildren()do
 check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow,'all Practice kerbs visual only')
 local d=part.Position-def.Crossover.Position
 check(rb.Vector2.new(d.X,d.Z).Magnitude>def.Crossover.KerbClearRadius,'no internal crossover kerbs')
end
local renderer=luau.load(fs.readFile('src/client/TrackMapRenderer.luau'),{environment=env})()
local panel=object('Frame');local view=renderer.create(panel,def,true,track.PreviewRotationDegrees)
view:setMarkerWorldPosition(c.StartPosition)
local canvas=panel:FindFirstChild('CourseCanvas');local dot=canvas:FindFirstChild('KartPosition')
local mapPrevious
for step=0,1000 do
 view:setMarkerWorldPosition(position(step/1000));local p=dot.Position
 check(p.X.Scale>=0 and p.X.Scale<=1 and p.Y.Scale>=0 and p.Y.Scale<=1,'full Figure-8 marker fits minimap')
 if mapPrevious then check((rb.Vector2.new(p.X.Scale,p.Y.Scale)-mapPrevious).Magnitude<.01,'map player continuous at both crossings')end
 mapPrevious=rb.Vector2.new(p.X.Scale,p.Y.Scale)
end
local gateDistance=0;local gatePositions={c.StartPosition}
for _,cp in c.CheckpointSamples do table.insert(gatePositions,cp.Position)end;table.insert(gatePositions,c.StartPosition)
for i=1,#gatePositions-1 do gateDistance+=(gatePositions[i+1]-gatePositions[i]).Magnitude end
local separation=(visits[2]-visits[1])*c.CenterlineLength
local metrics={geometryId=track.GeometryId,length=c.CenterlineLength,bounds=c.Bounds,roadWidth=60,samples=#c.Samples,startFraction=0,startPosition=tostring(c.StartPosition),startTangent=tostring(c.StartTangent),launchCorridor=190,laps=2,checkpoints=def.CheckpointFractions,crossingFractions=visits,minimumValidLapTime=gateDistance/100*.65,beginnerLapSeconds={c.CenterlineLength/60,c.CenterlineLength/40},crossingSeparation=separation,crossingTiming={speed50=separation/50,speed70=separation/70,speed80=separation/80,speed100=separation/100},futurePhysicalCrossingRisk='HIGH: a phase offset equal to branch separation can produce simultaneous crossing occupancy; P1 remains solo',gridSlots={}}
for _,slot in track.GridSlots do table.insert(metrics.gridSlots,tostring(slot))end
if process.args[1]=='Report' then
 fs.writeDir('artifacts/r7-p1b')
fs.writeFile('artifacts/r7-p1b/practice_geometry_metrics.json',serde.encode('json',metrics))
fs.writeFile('artifacts/r7-p1b/practice_route_trace.json',serde.encode('json',{crossovers=traces,lateralOffsets='0 / +/-1,3,6,10,15 PASS',adversarial='PASS',twoLaps='PASS',checks=count}))
fs.writeFile('artifacts/r7-p1b/practice_drift_zones.json',serde.encode('json',{zones=zones,opportunitiesPerTwoLaps=8,usefulBoostExits=usefulExits,manual='PENDING'}))
fs.writeFile('artifacts/r7-p1b/practice_environment_budget.json',serde.encode('json',budgets))
end
print('PASS: '..count..' actual Figure-8 geometry/continuity/world freeze/minimap checks; length '..c.CenterlineLength)
]====])()
