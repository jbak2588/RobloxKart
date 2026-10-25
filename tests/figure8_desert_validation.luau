local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local count=0;local function check(v,m)count+=1;assert(v,m)end
local policy=luau.load(fs.readFile('src/shared/Figure8DesertPolicy.luau'))()
local ws={GetAttribute=function()return true end}
check(policy.enabled(ws,false,10772198697,106553302629620),'exact authorized staging pair')
for _,pair in {{10772198697,127925465904803},{10768420544,106553302629620},{0,0}}do
 check(not policy.enabled(ws,false,pair[1],pair[2]),'no production, mixed pair or live flag bypass')
end
check(policy.enabled(ws,true,0,0),'explicit Studio preview')
check(not policy.enabled({GetAttribute=function()return nil end},true,0,0),'Studio requires opt-in')
local geometry=luau.load(fs.readFile('src/shared/TrackGeometry.luau'),{environment={Vector3=rb.Vector3,Vector2=rb.Vector2,CFrame=rb.CFrame}})()
local env=luau.load(fs.readFile('src/client/Figure8DesertEnvironment.luau'),{environment={Vector3=rb.Vector3,Color3=rb.Color3,game={GetService=function(_,n)return if n=='ReplicatedStorage'then {Shared={TrackGeometry='geometry'}}else {} end},require=function()return geometry end}})()
check(policy.enabled(ws,false,10768420544,127925465904803),'approved production pair')
check(policy.TrackId=='Track01Desert','distinct desert identity')
local catalog=luau.load(fs.readFile('src/shared/TrackCatalog.luau'),{environment={CFrame=rb.CFrame}})()
local green,desert=catalog.Entries.Track01,catalog.Entries.Track01Desert
check(green.Id~=desert.Id and green.GeometryId==desert.GeometryId,'two themes share accepted planar geometry only')
check(green.TargetLaps==desert.TargetLaps and #green.GridSlots==#desert.GridSlots,'same laps and capacity')
for i,cf in green.GridSlots do check(cf==desert.GridSlots[i],'identical safe grid')end
local discovery=luau.load(fs.readFile('src/shared/RaceDiscovery.luau'))()
check(discovery.RaceNowTrackId==desert.Id and discovery.DefaultTrackId==green.Id,'Race Now desert; existing browser default preserved')
local function node(name)return {Name=name,Parent={WaitForChild=function(_,n)return node(n)end},WaitForChild=function(_,n)return node(n)end}end
local modules={TrackCatalog=catalog,DriverCatalog={Entries={Driver01={}}},KartCatalog={Entries={Kart01={}}}}
modules.RaceMode=luau.load(fs.readFile('src/shared/RaceMode.luau'),{environment={script=node('RaceMode'),game={GetService=function()return node('RS')end},require=function(n)return modules[n.Name]end}})()
local function serverModule(name)
 return luau.load(fs.readFile('src/server/'..name..'.luau'),{environment={game={GetService=function()return node('RS')end},script=node(name),require=function(n)return modules[n.Name]end}})()
end
modules.RaceLaunchPayload=serverModule('RaceLaunchPayload')
local arrival=serverModule('RaceArrivalPlan')
for _,id in {'Track01','Track01Desert'}do
 local payload=assert(modules.RaceLaunchPayload.buildMatch('match-dual-theme','room-'..id,{{userId=1,driverId='Driver01',kartId='Kart01'}},id))
 local plan=arrival.forPlayer(payload,1)
 check(plan.trackId==id and plan.maxPlayers==4 and plan.mode=='RACE','real launch/arrival preserves separate public track identity')
end
local recordPolicy=serverModule('RaceRecordPolicy')
local config={GeometryTokens={PracticeFigure8V1='F8'},RulesetId='r1'}
local scopes={}
for _,id in {'Track01','Track01Desert'}do
 scopes[id]=recordPolicy.indexScope(config,{trackId=id,geometryId='PracticeFigure8V1',rulesetId='r1',category='SOLO_1H_0B'})
end
check(scopes.Track01~=nil and scopes.Track01Desert~=nil and scopes.Track01~=scopes.Track01Desert,'record indexes remain separate for themes')
local course=geometry.getCourse(geometry.getDefinition('PracticeFigure8V1'))
local straightCount=0
for i=1,#course.Samples do
 local length=env.straightRoadLength(course.Samples,i)
 if length then straightCount+=1;check(math.abs(length-(course.Samples[i%#course.Samples+1]-course.Samples[i]).Magnitude)<.001,'straight visual span has no overhang or height offset')end
end
check(straightCount>100,'straight visual road seam coverage')
for _,p in course.Samples do
 for _,dx in {-90,0,90}do for _,dz in {-90,0,90}do check(env.protected(p.X+dx,p.Z+dz),'terrain exclusion preserves road plus 90-stud recovery envelope')end end
 check(env.roadDistance(course.Samples,p.X,p.Z)<.001,'actual polyline clearance evaluator')
end
local surface=luau.load(fs.readFile('src/assets/DesertSource/TerrainSurface.luau'),{environment={script={Parent={WaitForChild=function(_,name)return name end}},require=function(name)return luau.load(fs.readFile('src/assets/DesertSource/'..name..'.luau'))()end}})()
check(#surface.Rows==608 and surface.Width==608 and surface.Depth==448,'source terrain sample dimensions')
local max=0
for _,row in surface.Rows do
 check(#row==surface.Depth*4,'untruncated source row')
 for z=1,surface.Depth do local q=tonumber(row:sub((z-1)*4+1,(z-1)*4+3),16);local m=tonumber(row:sub(z*4,z*4),16)
  check(q~=nil and surface.Materials[m+1]~=nil,'valid original height/material encoding');max=math.max(max,q/4-8)
 end
end
check(max>140 and max<=256,'source contains real tall cliff relief')
local dunePeak=0
for x=-96,96,4 do for z=240,432,4 do
 local height=env.duneHeight(surface,x,z);dunePeak=math.max(dunePeak,height)
 if height>0 then check(env.roadDistance(course.Samples,x,z)>=68,'island dune preserves road and recovery clearance')end
end end
check(dunePeak>8 and dunePeak<30,'one restrained original-profile island dune')
for _,cliff in env.Cliffs do
 local peak=0
 for x=cliff.X-cliff.RadiusX,cliff.X+cliff.RadiusX,4 do
  for z=cliff.Z-cliff.RadiusZ,cliff.Z+cliff.RadiusZ,4 do
   local h=env.cliffHeight(surface,cliff,x,z);peak=math.max(peak,h)
   if h>0 then
    check(env.roadDistance(course.Samples,x,z)>=68,'cliff footprint outside road/recovery corridor')
    check((rb.Vector3.new(x,0,z+26.79245283)).Magnitude>=130,'intersection center remains open')
   end
  end
 end
 check(peak>40 and peak<=cliff.Height,'original cliff profile has approved restrained height')
end
local signs={};local arcIndex=0
for _,arc in geometry.getDefinition('PracticeFigure8V1').Segments do if arc[1]=='Arc'then
 arcIndex+=1
 for i=1,11 do local a=arc[5]+arc[6]*i/12
  table.insert(signs,{Arc=arcIndex,Position=rb.Vector3.new(arc[2]+math.cos(a)*(arc[4]+48.5),0,arc[3]+math.sin(a)*(arc[4]+48.5))})
 end
end end
local kept=env.selectChevrons(signs);local perArc={0,0,0,0}
for p in kept do perArc[p.Arc]+=1 end
for _,n in perArc do check(n==3,'three spaced signs per corner')end
local square={rb.Vector3.new(-10,0,-10),rb.Vector3.new(10,0,-10),rb.Vector3.new(10,0,10),rb.Vector3.new(-10,0,10)}
for _,side in {-1,1}do
 local position=rb.Vector3.new(side*20,0,0)
 check(env.chevronFacesRoad(square,position,rb.Vector3.xAxis,side<0),'road-facing chevron retained on either side')
 check(not env.chevronFacesRoad(square,position,rb.Vector3.xAxis,side>0),'rear-facing chevron blank on either side')
end
local resources=rb.deserializeModel(fs.readFile('src/assets/KDMDesertResources.rbxmx'))[1]
check(#resources.Natural:GetChildren()==3,'cactus/agave/boulder only; no round dry-grass or tumbleweed models')
for _,x in resources:GetDescendants()do check(not x:IsA('LuaSourceContainer'),'no imported template scripts')end
local meshIds={Cactus_a='rbxassetid://15491325754',Agave_a='rbxassetid://15169965752',Racing_Boulder_a='rbxassetid://15171684910'}
local meshes=0
for _,p in resources.Natural:GetDescendants()do if p:IsA('MeshPart')then
 check(meshIds[p.Name]~=nil and fs.readFile('src/assets/KDMDesertResources.rbxmx'):find(meshIds[p.Name],1,true)~=nil,'source prefab contains original mesh asset ID');meshes+=1
end end
check(meshes==3,'three original natural meshes verified')
check(resources.Natural:FindFirstChild('Racing_Foliage_Cactus_a')~=nil,'original cactus is present')
check(resources.Materials:FindFirstChild('Racing_Buttes_A')~=nil,'original cliff material present')
check(resources.Materials:FindFirstChild('Racing_Asphalt_A')~=nil,'original desert asphalt present')
local bakedMatte,sourceNormal=false,false
for item in fs.readFile('src/assets/KDMDesertResources.rbxmx'):gmatch('<Item class="MaterialVariant".-</Item>')do
 if item:find('<string name="Name">Racing_Asphalt_A</string>',1,true)then
  bakedMatte=item:match('<Content name="MetalnessMap">%s*<null%s*/>')~=nil
  sourceNormal=item:find('rbxassetid://15217430764',1,true)~=nil
 end
end
check(bakedMatte,'matte map baked into prefab; client has no Plugin map-write capability')
check(sourceNormal,'original road normal map retained; fix visual overlap instead')
check(resources.Materials:FindFirstChild('Racing_Sand_Grass')~=nil,'original native dry-grass terrain material')
print('PASS: '..count..' staging isolation, original resources/terrain and actual Figure-8 road/recovery clearance checks')
