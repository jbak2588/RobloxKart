local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local layout=luau.load(fs.readFile('src/shared/HubParkRookieLoopLayout.luau'))()
local policy=luau.load(fs.readFile('src/shared/HubParkRuntimePolicy.luau'))()
local checks=0
local function check(v,label) assert(v,label);checks+=1 end
local function distance(a,b)return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)end
local function cross(a,b,c)return (b.x-a.x)*(c.z-a.z)-(b.z-a.z)*(c.x-a.x)end
local points=layout.sample(layout.Segments)
check(layout.DefaultEnabled==false,'default OFF')
check(#layout.Slots==4,'four reserved slots')
local minRadius=math.huge
for i,s in layout.Segments do
 local next=layout.Segments[i%#layout.Segments+1]
 local a,b=layout.evaluate(s,1),layout.evaluate(next,0)
 check(distance(a,b)<1e-6,'closed endpoint '..s.name)
 check(a.fx*b.fx+a.fz*b.fz>.99999,'continuous tangent '..s.name)
 for t=0,100 do minRadius=math.min(minRadius,layout.evaluate(s,t/100).radius)end
end
check(minRadius>=layout.MinimumRadius,'minimum radius supports existing 50-stud normal turn')
-- Check both full road/kerb/shoulder/barrier envelopes, not just the centerline.
for _,side in {-1,1}do
 local edge={};local width=layout.RoadWidth/2+layout.KerbWidth+layout.Shoulder+1.5
 for _,a in points do table.insert(edge,{x=a.x-a.fz*width*side,z=a.z+a.fx*width*side})end
 for i=1,#edge-1 do for j=i+2,#edge-1 do
  if i==1 and j==#edge-1 then continue end
  check(not(cross(edge[i],edge[i+1],edge[j])*cross(edge[i],edge[i+1],edge[j+1])<-1e-8
   and cross(edge[j],edge[j+1],edge[i])*cross(edge[j],edge[j+1],edge[i+1])<-1e-8),'no full-envelope self intersection')
 end end
end
for i=1,#points-1 do
 local a,b=points[i],points[i+1]
 check(distance(a,b)<=layout.SampleLength+.01,'bounded tessellation')
 check(a.fx*b.fx+a.fz*b.fz>.99,'no sharp sample direction break')
 local r=layout.Protected
 local dx=math.max(r.minX-a.x,0,a.x-r.maxX);local dz=math.max(r.minZ-a.z,0,a.z-r.maxZ)
 check(math.sqrt(dx*dx+dz*dz)>layout.RoadWidth/2+layout.KerbWidth+layout.Shoulder+2,'road/shoulder/barrier clear protected HUB')
 for j=i+2,#points-1 do
  if i==1 and j==#points-1 then continue end
  local c,d=points[j],points[j+1]
  check(not (cross(a,b,c)*cross(a,b,d)<-1e-8 and cross(c,d,a)*cross(c,d,b)<-1e-8),'no nonadjacent centerline intersection')
 end
end
local pit=layout.sample(layout.Pit.segments)
check(math.abs(pit[1].z-layout.StartStraightZ)<1e-6 and math.abs(pit[#pit].z-layout.StartStraightZ)<1e-6,'both pit ends join relocated main straight')
check(layout.pitOpening(pit[1])==false,'pit segment labels cannot silently open unrelated edges')
for _,slot in layout.Slots do
 check(slot.x-9>=-95 and slot.x+9<=100 and math.abs(slot.z-layout.PitLaneZ)+5<=layout.Pit.width/2,'full slot footprint fits asymmetrically widened pit lane')
 check(math.abs(slot.x)+9<=layout.Plaza.width/2,'all four slots directly across T plaza width')
 check(math.abs(slot.z-(layout.Plaza.z-layout.Plaza.length/2))<=12,'slot center within two approximate walking steps')
end
check(layout.Plaza.z-layout.Plaza.length/2 > layout.PitLaneZ+layout.Pit.width/2,'plaza physically separate from pit lane')
check(layout.Walkway.width==12,'12-stud pedestrian connection')
local workspace=rb.Instance.new('Workspace');workspace:SetAttribute('KDMServerRole','HUB')
local hub=rb.Instance.new('Model');hub.Name='KDMHub';hub.Parent=workspace
local spawn=rb.Instance.new('Part');spawn.Name='HubSpawn';spawn.Position=rb.Vector3.new(0,1,0);spawn.Parent=hub
local ground=rb.Instance.new('Part');ground.Size=rb.Vector3.new(2048,20,2048);ground.Position=rb.Vector3.new(0,-10,0)
local shared={HubParkRookieLoopLayout='layout',WaitForChild=function(_,n)return n end}
local lighting=rb.Instance.new('Lighting')
local originalSky=rb.Instance.new('Sky');originalSky.Name='OriginalSky';originalSky.Parent=lighting
local game={GetService=function(_,n)
 if n=='ReplicatedStorage'then return {Shared=shared,WaitForChild=function()return shared end}end
 if n=='RunService'then return {IsStudio=function()return true end}end
 if n=='Lighting'then return lighting end
 error(n)
end}
local env={game=game,Instance=rb.Instance,Vector3=rb.Vector3,Vector2=rb.Vector2,CFrame=rb.CFrame,
 Color3=rb.Color3,UDim2=rb.UDim2,Enum=rb.Enum,task={wait=function()end},script={Parent={WaitForChild=function(_,n)return n end}}}
local island=luau.load(fs.readFile('src/server/HubParkIslandBuilder.luau'),{environment=env})()
env.require=function(ref)return if ref=='HubParkRuntimePolicy'then policy elseif ref=='HubParkIslandBuilder'then island else layout end
local builder=luau.load(fs.readFile('src/server/HubParkRookieLoopBuilder.luau'),{environment=env})()
check(not builder.enabled(workspace,true) and builder.build(hub,ground)==nil,'OFF creates nothing')
check(ground.Transparency==0,'OFF leaves original ground appearance untouched')
check(originalSky.Parent==lighting,'OFF leaves original sky untouched')
workspace:SetAttribute('HubParkV1Enabled',true)
check(not builder.enabled(workspace,false),'production cannot enable G2')
workspace:SetAttribute('KDMServerRole','RACE');check(builder.build(hub,ground)==nil,'RACE creates nothing')
workspace:SetAttribute('KDMServerRole','HUB')
local root=assert(builder.build(hub,ground));check(builder.build(hub,ground)==root,'idempotent ON')
check(lighting:FindFirstChild('HubParkIslandSky')~=nil and originalSky.Parent==root.ParkOriginalEnvironment,'ON-only sky swap preserves original panorama')
local safety=root:FindFirstChild('G2SafetyGround')
local floor=assert(safety:FindFirstChild('FlatSupport'))
check(#safety:GetChildren()==1 and floor.CanCollide and floor.Transparency==1,'one continuous invisible flat support')
check(floor.CFrame.UpVector.Y>.999999,'flat support normal')
for _,a in points do
 local v=floor.CFrame:PointToObjectSpace(rb.Vector3.new(a.x,layout.height(a.x,a.z),a.z))
 check(math.abs(v.Y-floor.Size.Y/2)<.0001 and math.abs(v.X)<floor.Size.X/2-36 and math.abs(v.Z)<floor.Size.Z/2-36,'flat support covers complete approved road and shoulders')
end
local road,slots=0,0
for _,v in root:GetDescendants()do
 check(not v:IsA('LuaSourceContainer') and not v:IsA('RemoteEvent') and not v:IsA('Seat') and not v:IsA('SpawnLocation'),'no auto seating or new remote')
 if v:IsA('TextLabel')then check(not v.Text:match('SLOT'),'no SLOT lettering remains on road')end
 if v:IsA('Folder') and v.Name:match('^SlotBracket%d+$')then
  slots+=1;local slot=layout.Slots[v:GetAttribute('Slot')]
  check(v:GetAttribute('Active')==true and #v:GetChildren()==3,'four native three-stroke slot brackets')
  local front=v:FindFirstChild('Front')
  check(front.CFrame.Position.X==slot.x+7.5 and front.CFrame.Position.Z==slot.z,'closed bracket ahead in +X direction')
  for _,paint in v:GetChildren()do
   check(not paint.CanCollide and not paint.CanQuery and not paint.CanTouch and math.abs(paint.Size.Y-.02)<1e-4,'slot paint cannot catch wheels (Part size quantization allowed)')
   check(paint.CFrame.Position.X>slot.x and math.abs(paint.CFrame.Position.Z-slot.z)<=5,'entire bracket ahead, opening toward kart')
  end
 end
 if v:IsA('BasePart')then
  check(v.Anchored and not v.CanTouch,'static non-touch geometry')
  if v.Name=='Road'then road+=1;check(not v.CanCollide and not v.CanQuery,'visual road slices cannot snag chassis')end
  if v.Name=='PitRoad' or v.Name=='PedestrianPlaza' or v.Name=='PedestrianLink12' then check(not v.CanCollide and not v.CanQuery,'one common support at pit/road/walk merges')end
  if v.CanCollide then check(v.Parent==safety or v.Name=='Barrier'or v.Name=='IslandEdgeGuard','only continuous support and safety boundaries collide')end
  if v.Name=='Kerb'then check(not v.CanCollide and not v.CanQuery and not v.CastShadow,'visual-only kerbs')end
  if v.Name=='ForwardChevron' or v.Name=='StartMark' or v.Parent.Name:match('^SlotBracket%d+$')then
   check(v.CFrame.Position.Y-layout.height(v.CFrame.Position.X,v.CFrame.Position.Z)-v.Size.Y/2>=.019,'markings do not sink below the .02 flat asphalt skin')
  end
 end
end
check(road==#points-1 and slots==4,'complete road and four bracket markers')
-- Exercise actual CompactHubBuilder entry point; OFF uses the old builder unchanged.
local oldCalls=0
local compact=luau.load(fs.readFile('src/server/CompactHubBuilder.luau'),{environment={
 game=game,script={Parent={WaitForChild=function(_,n)return n end}},require=function(ref)
  if ref=='HubParkRookieLoopBuilder'then return builder end
  if ref=='HubParkRuntimePolicy'then return policy end
  if ref=='LobbyFrontDriveZoneBuilder'then return {build=function()oldCalls+=1;return 'legacy'end}end
  return {}
 end}})()
workspace:SetAttribute('HubParkV1Enabled',false)
check(compact.buildFrontDriveZone(hub,ground)=='legacy' and oldCalls==1,'OFF exact legacy dispatch')
workspace:SetAttribute('HubParkV1Enabled',true)
check(compact.buildFrontDriveZone(hub,ground)==root and oldCalls==1,'ON connects only the approved RookieLoop, never old H1 geometry')
local fresh=rb.Instance.new('Model');fresh.Parent=workspace
local stale=rb.Instance.new('Model');stale.Name='LobbyFrontTestDriveZone';stale.Parent=fresh
check(not pcall(builder.build,fresh,ground),'refuse overlapping a live legacy zone')
local edgeHub=rb.Instance.new('Model');edgeHub.Parent=workspace
-- The revised front-only loop extends toward negative Z. Exercise that edge
-- beyond Baseplate, rather than assuming the old rear extension still exists.
local edgeSpawn=rb.Instance.new('Part');edgeSpawn.Name='HubSpawn';edgeSpawn.Position=rb.Vector3.new(0,1,-900);edgeSpawn.Parent=edgeHub
local edgeRoot=builder.build(edgeHub,ground);local visuals=0
for _,v in edgeRoot.IslandScenery:GetChildren()do if v.Name=='IslandGrass'then
 visuals+=1;check(not v.CanCollide and not v.CanQuery,'grass cap visual only')
end end
check(visuals>0 and ground.Transparency==1,'island outside Baseplate has grass; old rectangle cannot z-fight')
check(root.StartSlots:FindFirstChild('1')~=nil and root:GetAttribute('DriveIntegrated')==true,'manual integration exposes start anchors')
local leading=root.StartSlots:FindFirstChild('1')
check(leading.CFrame.LookVector.X>.999 and leading.CFrame.Position.X==45,'first manual spawn is the forwardmost bracket, facing +X')
for i=2,4 do check(leading.CFrame.Position.X>root.StartSlots:FindFirstChild(tostring(i)).CFrame.Position.X,'all remaining slots are behind first spawn')end
print(string.format('PASS: %d G2/manual-zone checks; %d road strips; min radius %.2f; OFF/ON/RACE/grass validated',checks,road,minRadius))
return {root=root,layout=layout,origin=rb.Vector3.zero}
