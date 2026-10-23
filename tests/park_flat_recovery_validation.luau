local fs,luau,process=require('@lune/fs'),require('@lune/luau'),require('@lune/process')
local fixture=require('./hub_park_rookie_loop_validation')
local L,root=fixture.layout,fixture.root
local prior=luau.load(process.exec('git',{'show','7aae5e1:src/shared/HubParkRookieLoopLayout.luau'}).stdout)()
local n=0;local function check(v,m)assert(v,m);n+=1 end
check(L.RoadWidth==68 and L.Shoulder==0,'approved 68-stud asphalt without green shoulders')
check(L.RoadWidth/2+L.KerbWidth+L.Shoulder==prior.RoadWidth/2+prior.KerbWidth+prior.Shoulder,'outside guardrail envelope preserved')
check(L.Pit.width==32 and L.PitLaneZ+L.Pit.width/2==-71,'pit expands toward road, keeps plaza-side edge')
check(L.PitLaneZ-L.Pit.width/2==L.StartStraightZ+L.RoadWidth/2,'no grass gap between pit and main road')
for i,s in L.PitSlots do check(s.x==prior.Slots[i].x and s.z==prior.Slots[i].z,'approved slot positions preserved')end
for i,s in L.Segments do for j=1,4 do
 check(s[j].x==prior.Segments[i][j].x and s[j].z==prior.Segments[i][j].z,'approved XZ preserved')
end;check(s.name==prior.Segments[i].name,'corner order preserved')end
for _,route in {L.Segments,L.Pit.segments}do for _,a in L.sample(route)do
 local nx,ny,nz=L.normal(a.x,a.z)
 check(L.height(a.x,a.z)==0 and nx==0 and ny==1 and nz==0,'flat main/pit ground source')
end end
local floor=root.G2SafetyGround.FlatSupport
check(#root.G2SafetyGround:GetChildren()==1,'no H1 triangle or inclined colliders remain')
for _,v in root:GetDescendants()do if v:IsA('BasePart')then
 if v.Name=='Road'or v.Name=='PitRoad'then
  local top=v.CFrame.Position.Y+(math.abs(v.CFrame.RightVector.Y)*v.Size.X+math.abs(v.CFrame.UpVector.Y)*v.Size.Y+math.abs(v.CFrame.LookVector.Y)*v.Size.Z)/2
  check(math.abs(top-.02)<.0001,'visible asphalt within .02 of wheel contact plane')
  check(not v.CanCollide and not v.CanQuery,'visual seams cannot catch wheels')
  if v.Name=='PitRoad'then
   check(v.Color==root:FindFirstChild('Road',true).Color,'pit and road share exact asphalt colour')
   local boundary=L.StartStraightZ+L.RoadWidth/2
   if v:IsA('WedgePart')then
    -- Native wedge triangle: upper back, lower back and lower front vertices.
    for _,side in {-1,1}do for _,corner in {{1,1},{-1,1},{-1,-1}}do
     local p=v.CFrame:PointToWorldSpace(require('@lune/roblox').Vector3.new(side*v.Size.X/2,corner[1]*v.Size.Y/2,corner[2]*v.Size.Z/2))
     check(p.Z>=boundary-.0001,'clipped pit triangle never covers main asphalt')
    end end
   else
    for _,x in {-1,1}do for _,z in {-1,1}do
     local p=v.CFrame:PointToWorldSpace(require('@lune/roblox').Vector3.new(x*v.Size.X/2,0,z*v.Size.Z/2))
     check(p.Z>=boundary-.0001,'pit rectangle never covers main asphalt')
    end end
   end
  end
 elseif v.Name=='IslandGrass'then
  check(math.abs(v.CFrame.Position.Y+v.Size.Y/2+.2)<.0001,'grass .2 below shoulder and physical contact datum')
  check(not v.CanCollide and not v.CanQuery,'grass depth separation never changes contact physics')
 elseif v.Name=='Shoulder'then
  check(false,'green shoulder parts removed')
 elseif v.Name=='Kerb'then
  local top=v.CFrame.Position.Y+(math.abs(v.CFrame.RightVector.Y)*v.Size.X+math.abs(v.CFrame.UpVector.Y)*v.Size.Y+math.abs(v.CFrame.LookVector.Y)*v.Size.Z)/2
  check(math.abs(top-.07)<.0001,'equal-height non-overlapping kerb polygons')
 end
end end
local lengths={};local colours={};local pitRuns=0
for _,v in root:GetDescendants()do if v.Name=='KerbRun'then
 local route=v:GetAttribute('Route');local l=v:GetAttribute('ArcLength');local ci=v:GetAttribute('ColorIndex')
 check(l>0 and l<=8,'bounded constant arc-length kerb block')
 if route=='PIT'then pitRuns+=1 end
 -- Each ribbon uses one common block length for red and white alike.
 local key=route..':'..string.format('%.4f',l)
 lengths[key]=lengths[key]or l;colours[key]=colours[key]or {}
 colours[key][ci]=true
end end
for _,c in colours do check(c[0]and c[1],'each kerb ribbon contains equal-length red and white')end
check(pitRuns>0,'pit has its own lobby-facing kerb ribbon and shared main-road border')
check(root:FindFirstChild('PitEntryMark')==nil and root:FindFirstChild('PitExitMark')==nil,'PIT IN/OUT text and arrows removed')
check(math.abs(floor.CFrame.Position.Y+floor.Size.Y/2)<.0001,'contact face at original flat datum')
check(root:GetAttribute('CollisionContract')=='FLAT_SUPPORT_V1','flat collision contract')
print(string.format('PASS %d PARK-FLAT-R1 XZ/flat support/skin/grass checks',n))
