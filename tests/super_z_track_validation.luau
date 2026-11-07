local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local V,CF=rb.Vector3,rb.CFrame;local checks=0
local function check(ok,label)assert(ok,label);checks+=1 end
local geometry=luau.load(fs.readFile('src/shared/TrackGeometry.luau'),{environment={Vector3=V,Vector2=rb.Vector2}})()
local definition=geometry.getDefinition('SuperZV1');local course=geometry.getCourse(definition)
local catalog=luau.load(fs.readFile('src/shared/TrackCatalog.luau'),{environment={Vector3=V,CFrame=CF}})()
local track=catalog.Entries.SuperZ
check(track.MaxPlayers==4 and track.TargetLaps==3 and #track.GridSlots==4,'four racers three laps')
check(track.PreviewImageAssetId=='rbxassetid://104331982200577','owner preview asset')
check(catalog.botAllowed('SuperZ')and track.MatchType=='PUBLIC_RACE','existing official race bot policy')
check(catalog.Order[1]=='Track01'and table.find(catalog.Order,'SuperZ')~=nil and catalog.Entries.Track01.TargetLaps==3 and catalog.Entries.Track01Race.TargetLaps==2,'additive catalog, existing default preserved')
check(#course.Samples==600 and course.CenterlineLength>5695 and course.CenterlineLength<5703,'revised reference follows widened corners, unchanged native road')
check(course.StartPosition.Magnitude<.02 and course.StartTangent.X>.999,'actual finish origin and forward heading')
check(#course.CheckpointSamples==12,'all route arms gated')
local node={};local policy=luau.load(fs.readFile('src/shared/SuperZRoadPolicy.luau'),{environment={script={Parent={WaitForChild=function()return node end}},require=function(n)assert(n==node);return geometry end}})()
for _,p in course.Samples do check(policy.contains(p),'centerline belongs to road '..tostring(p))end
check(policy.contains(V.new(100,0,470)),'rounded central road addition')
check(policy.contains(V.new(620,0,486)),'wide bowl road addition')
check(not policy.contains(V.new(-100,0,-100)),'north grass excluded')
check(not policy.contains(V.new(0,0,250)),'inner island grass excluded')
check(not policy.contains(V.new(450,0,480)),'remaining bowl grass excluded')
for _,f in track.GridSlots do check(policy.contains(f.Position),'four slot centers on asphalt')end
local route=luau.load(fs.readFile('src/shared/RaceRouteProgress.luau'),{environment={Vector3=V}})()
-- Four independent progress states, three full ordered laps: real geometry/query.
for racer=1,4 do
 for lap=1,3 do
  local state=route.new(course,definition.RouteCorridorWidth);local nextGate=1
  for i=0,1200 do
   local f=(i%1200)/1200;local p=geometry.getSampleAtFraction(course.Samples,f)
   nextGate=route.step(state,p,nextGate,policy.contains(p,8))
  end
  check(nextGate==13,'four-player three-lap ordered route proof')
 end
end
local state=route.new(course,definition.RouteCorridorWidth)
route.step(state,course.StartPosition,1,true)
check(route.step(state,geometry.getSampleAtFraction(course.Samples,.5),1,true)==1,'half-course teleport cannot recover checkpoints')
local serde=require('@lune/serde')
local lines=serde.decode('json',fs.readFile('tests/fixtures/super_z_line_probes_20261107.json'))
for label,variant in lines.variants do
 local progress=route.new(course,definition.RouteCorridorWidth);local nextGate=1
 for i,base in lines.base do local q=variant.points[i-variant.first+1]or base;local p=V.new(q[1],0,q[2]);check(policy.contains(p,8),label..' legal lane')
  nextGate=route.step(progress,p,nextGate,true)
 end
 check(nextGate==13,label..' legal lane recovers all12 gates')
end
local scene=rb.deserializeModel(fs.readFile('src/assets/KDMSuperZResources.rbxmx'))[1]
local model=scene:FindFirstChild('SuperZTrack');check(model~=nil,'native scene serialized')
check(#model.ParkLandscaping:GetChildren()==73,'owner retained tree count')
check(#model.ContinuousSurfaceMeshes:GetChildren()==7,'fixed continuous visual mesh budget')
for _,p in model:GetDescendants()do
 check(not p:IsA('LuaSourceContainer'),'no prototype behavior imported')
end
local meshSizes=0
for body in fs.readFile('src/assets/KDMSuperZResources.rbxmx'):gmatch('<Vector3 name="InitialSize">(.-)</Vector3>')do
 for _,axis in {'X','Y','Z'}do check(tonumber(body:match('<'..axis..'>(.-)</'..axis..'>'))>0,'serialized native intrinsic '..axis)end
 meshSizes+=1
end
check(meshSizes==153,'seven road plus146 tree MeshPart intrinsic records')
local ui=fs.readFile('src/client/GarageUiController.luau')
local first=assert(ui:find('table.insert(trackOrder,Overtake.Id)',1,true));local second=assert(ui:find("table.insert(trackOrder,'SuperZ')",1,true));local third=assert(ui:find('table.insert(trackOrder,ParkRace.Id)',1,true))
check(first<second and second<third,'immediately after Overtake, Park multiplayer retained')
print('PASS Super Z catalog/geometry/boundaries/4P3lap route/assets: '..checks..' checks')
local pin=serde.decode('json',fs.readFile('tests/fixtures/super_z_release_20261107.json'))
local manifest=serde.decode('json',fs.readFile('tests/fixtures/source_freeze_release_f5ebec8.json'))
local freeze=require('./helpers/release_source_freeze')
for path,hash in pin.hashes do
 local source=fs.readFile(path)
 check(manifest.superZPatches[path]==hash and serde.hash('sha256',freeze.canonical(source))==hash,'exact independently recorded Super Z pin '..path)
 check(freeze.accepts(manifest,path,source),'approved Super Z source '..path)
 check(not freeze.accepts(manifest,path,source..'\n-- unauthorized')and not freeze.accepts(manifest,path,source:sub(2)),'Super Z mutation/deletion rejected '..path)
end
print('PASS Super Z exact source and mutation rejection: '..checks..' total checks')
