-- New Metro identity, preserved official tracks, and exact scenery clearance.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local harness=fs.readFile('tests/track_environment_validation.luau')
local prefix=harness:sub(1,assert(harness:find('local prototype=object("Folder")',1,true))-1)
luau.load(prefix..[====[
local process=require('@lune/process')
local catalog=luau.load(fs.readFile('src/shared/TrackCatalog.luau'),{environment=env})()
local layout=luau.load(fs.readFile('src/shared/MetroCityLayout.luau'),{environment=env})()
local old=process.exec('git',{'show','13c1f483eddb957f0441dfd6aca410bf0f0421f4:src/shared/TrackCatalog.luau'})
assert(old.ok)
local oldCatalog=luau.load(old.stdout,{environment=env})()
local oldBuilderSource=process.exec('git',{'show','13c1f483eddb957f0441dfd6aca410bf0f0421f4:src/server/TrackBuilder.luau'})
assert(oldBuilderSource.ok)
local oldBuilder=luau.load(oldBuilderSource.stdout,{environment=env})()
local function equal(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 for k,v in a do if not equal(v,b[k])then return false end end
 for k in b do if a[k]==nil then return false end end
 return true
end
local function signature(root)
 local result={}
 local function visit(n,path)
  local values={}
  for k,v in n.props do if k~='Parent'then table.insert(values,k..'='..tostring(v))end end
  for k,v in n.attrs do table.insert(values,'@'..k..'='..tostring(v))end
  table.sort(values);table.insert(result,path..'|'..table.concat(values,';'))
  for _,c in n:GetChildren()do visit(c,path..'/'..c.Name)end
 end
 visit(root,'');return table.concat(result,'\n')
end
for _,id in oldCatalog.Order do
 check(equal(catalog.Entries[id],oldCatalog.Entries[id]),id..' entire catalog entry unchanged')
 check(signature(builder.build(object('Folder'),catalog.Entries[id],0))==signature(oldBuilder.build(object('Folder'),oldCatalog.Entries[id],0)),id..' every generated property unchanged')
end
check(catalog.RaceNowDefaultId==oldCatalog.RaceNowDefaultId,'Race Now routing unchanged')
local metro=catalog.Entries.Track01Metro
check(metro.Id=='Track01Metro' and metro.GeometryId=='PracticeCircuitV1' and metro.MaxPlayers==4 and metro.TargetLaps==2 and catalog.botAllowed(metro.Id),'distinct Metro identity with existing race capacity/bot contract')
check(catalog.previewKey(metro)~=catalog.previewKey(catalog.Entries.Track01Race),'distinct preview cache')
for _,role in {'HUB','RACE'}do for _,id in catalog.Order do
 check(layout.eligible(role,id,catalog.Entries[id].GeometryId)==(role=='RACE' and id=='Track01Metro'),'only Metro RACE eligible')
end end
check(not layout.eligible('RACE','Track01Metro','PracticeFigure8V1'),'reject foreign geometry')
local asset=rb.deserializeModel(fs.readFile('src/assets/KDMMetroResources.rbxmx'))[1]
local profiles={};local partCount=0
for _,name in layout.Names do
 local prefab=asset:FindFirstChild(name);check(prefab~=nil,'source exterior '..name)
 local low,high=rb.Vector3.new(math.huge,math.huge,math.huge),rb.Vector3.new(-math.huge,-math.huge,-math.huge)
 for _,p in prefab:GetChildren()do
  check(p:IsA('BasePart') and p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery and not p.CastShadow,'inert exterior')
  partCount+=1
  for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do
   local v=p.CFrame:PointToWorldSpace(p.Size*rb.Vector3.new(x,y,z)/2)
   low=low:Min(v);high=high:Max(v)
  end end end
 end
 profiles[name]=high-low;check(math.abs(low.Y)<.001,'building grounded in source prefab')
end
check(partCount==2622,'complete kit and two low shops with bounded palette')
local course=geometry.getCourse(geometry.getDefinition(metro.GeometryId))
local width=geometry.getDefinition(metro.GeometryId).RoadWidth
local sites=layout.plan(geometry,course,width,profiles)
check(#sites>=40 and #sites<=68,'bounded dense streets')
local sides={[-1]=0,[1]=0};local paired={0,0};local adjacent=0
for i,s in sites do
 check(layout.footprintDistance(course.Samples,s.frame,s.size)>=width/2+24,'entire building footprint outside drift shoulder')
 check(math.abs(s.frame.LookVector:Dot(s.forward))<.00001,'facade parallel to road')
 sides[s.side]+=1
 if s.bridge then paired[s.bridge]+=1 end
 for j=1,i-1 do local other=sites[j]
  check(layout.separated(s,other,.14),'building rectangles do not overlap')
  if s.block==other.block then
   local delta=math.abs((s.frame.Position-other.frame.Position):Dot(s.forward))-(s.size.X+other.size.X)/2
   if delta>.1 and delta<1 then adjacent+=1 end
  end
 end
end
check(sides[-1]>15 and sides[1]>15,'buildings on both road sides')
check(paired[1]==2 and paired[2]==2,'two complete bridge/tower pairs')
check(adjacent>=15,'continuous adjoining street fronts')
local tree=asset:FindFirstChild('CityBeech');local treeLow,treeHigh=rb.Vector3.new(math.huge,math.huge,math.huge),rb.Vector3.new(-math.huge,-math.huge,-math.huge)
for _,p in tree:GetChildren()do for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do
 local v=p.CFrame:PointToWorldSpace(p.Size*rb.Vector3.new(x,y,z)/2);treeLow=treeLow:Min(v);treeHigh=treeHigh:Max(v)
end end end end
local trees=layout.forestPlan(geometry,course,width,sites,treeHigh-treeLow)
check(#trees>=35 and #trees<=100,'native pocket groves fill gaps / corners')
for _,t in trees do
 local frame=rb.CFrame.new(t.position)*rb.CFrame.Angles(0,t.yaw,0)
 check(layout.footprintDistance(course.Samples,frame,(treeHigh-treeLow)*t.scale)>=width/2+24,'complete rotated grove footprint outside recovery shoulder')
end
local samples={rb.Vector3.new(-20,0,0),rb.Vector3.new(20,0,0)}
check(layout.footprintDistance(samples,frames.identity,rb.Vector3.new(10,10,10))==0,'detect crossing through rectangle without endpoint inside')
check(math.abs(layout.footprintDistance(samples,rb.CFrame.new(0,0,10),rb.Vector3.new(10,10,10))-5)<.0001,'exact edge distance')
local world=builder.build(object('Folder'),metro,0)
check(#world:FindFirstChild('Road'):GetChildren()==#course.Samples,'Base route geometry retained')
check(world:FindFirstChild('SafetyGround')~=nil,'physical recovery support')
check(world:GetAttribute('BarrierTriggerPartCount')==0,'no close collision triggers')
check(world:GetAttribute('DoubleKerbPartCount')>0,'sharp bends have outward double kerbs')
local coverage={[-1]={},[1]={}}
for _,part in world:FindFirstChild('Kerbs'):GetChildren()do
 check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow,'kerbs visual only')
 if part:GetAttribute('KerbRow')==1 then
  for i=part:GetAttribute('FirstSegment'),part:GetAttribute('LastSegment')do coverage[part:GetAttribute('KerbSide')][i]=true end
 end
end
for i=1,#course.Samples do check(coverage[-1][i] and coverage[1][i],'both road edges continuously kerbed')end
local curves={}
for _,rail in world:FindFirstChild('Environment'):FindFirstChild('VisualRails'):GetChildren()do
 local id=rail:GetAttribute('ChevronCurveId')
 if id then curves[id]=(curves[id]or 0)+1 end
end
for _,n in curves do check(n==3,'exactly three boards per connected corner')end
check(next(curves)~=nil,'corner chevrons present')
local policy=luau.load(fs.readFile('src/server/RaceRecordPolicy.luau'))()
local config={GeometryTokens={PracticeCircuitV1='P1'},RulesetId='KDM_R1'}
local entry={geometryId='PracticeCircuitV1',rulesetId='KDM_R1',category='SOLO_1H_0B',trackId='Track01Metro'}
local metroKey=policy.indexScope(config,entry);entry.trackId='Track01Race'
check(metroKey~=nil and metroKey~=policy.indexScope(config,entry),'records isolated from Base')
print('Metro city PASS',count,'checks;',#sites,'buildings;',partCount,'palette parts')
]====],{debugName='MetroCityValidation'})()
