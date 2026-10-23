-- PARK-A3-R1: static forest bands using curated prefabs, only in opt-in HUBs.
local Builder={}
function Builder.build(root,origin,trees,mountains)
 local existing=root:FindFirstChild('ParkLandscaping');if existing then return existing end
 local folder=Instance.new('Folder');folder.Name='ParkLandscaping';folder.Parent=root
 local forest=game:GetService('ReplicatedStorage'):FindFirstChild('KDMHubForestTreePrefabs')
 local function static(p)
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  -- Preserve the curated asset's LOD. RenderFidelity is editor-write-only.
 end
 local function foot(model)
  local lo,hi=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
  for _,p in model:GetDescendants()do if p:IsA('BasePart')then
   for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do
    local v=p.CFrame:PointToWorldSpace(p.Size*Vector3.new(x,y,z)/2)
    lo=Vector3.new(math.min(lo.X,v.X),math.min(lo.Y,v.Y),math.min(lo.Z,v.Z))
    hi=Vector3.new(math.max(hi.X,v.X),math.max(hi.Y,v.Y),math.max(hi.Z,v.Z))
   end end end
  end end
  return Vector3.new((lo.X+hi.X)/2,lo.Y,(lo.Z+hi.Z)/2)
 end
 local treeSites={
  {-145,-25,.85,15,'NaturalTreeA'},{145,-25,.9,-25,'NaturalTreeB'},
  {-180,-245,1.1,35,'NaturalTreeA'},{175,-245,1.15,-40,'NaturalTreeB'},
  {-410,-285,1,70,'NaturalTreeA'},{455,-405,1,10,'NaturalTreeB'},
  {-530,-825,1.1,-20,'NaturalTreeA'},{270,-1010,1.2,45,'NaturalTreeB'},
  -- Four staggered groves: overlapping crowns, separate trunks. Keep the
  -- forward corner/chevron corridor open; these screen the distant road.
  {-790,-680,1.0,12,'NaturalTreeA'},{-792,-715,1.05,-30,'NaturalTreeB'},
  {-790,-750,.95,65,'NaturalTreeA'},{-792,-786,1.0,100,'NaturalTreeB'},
  {-238,-1010,1.05,20,'NaturalTreeB'},{-208,-1028,1.1,-40,'NaturalTreeA'},
  {-175,-1012,1.0,80,'NaturalTreeB'},{-143,-1036,1.05,135,'NaturalTreeA'},
  {690,-435,.95,35,'NaturalTreeA'},{692,-470,1.0,-20,'NaturalTreeB'},
  {690,-505,.95,90,'NaturalTreeB'},{692,-540,1.0,145,'NaturalTreeA'},
  {-155,-280,1.1,15,'NaturalTreeB'},{-121,-298,1.0,60,'NaturalTreeA'},
  {-87,-278,1.15,-35,'NaturalTreeB'},{-51,-299,1.05,110,'NaturalTreeA'},
  -- Forest bands: 56 new trees in staggered rows; original 24 sites above stay fixed.
  {-778,-490,1.0,78,'CityBroadleaf'}, -- WestBand
  {-778,-573,1.1,125,'CityBroadleaf'}, -- WestBand
  {-778,-656,1.2,172,'CityBroadleaf'}, -- WestBand
  {-810,-739,1.3,219,'CityBroadleaf'}, -- WestBand
  {-778,-822,0.8,266,'CityBroadleaf'}, -- WestBand
  {-778,-905,0.9,313,'CityBroadleaf'}, -- WestBand
  {-778,-988,1.0,0,'CityBroadleaf'}, -- WestBand
  {-778,-1071,1.1,47,'CityBroadleaf'}, -- WestBand
  {-802,-530,1.1,109,'CityMaple'}, -- WestBand
  {-802,-610,1.2,156,'CityMaple'}, -- WestBand
  {-810,-690,1.3,203,'CityMaple'}, -- WestBand
  {-810,-770,0.8,250,'CityMaple'}, -- WestBand
  {-802,-850,0.9,297,'CityMaple'}, -- WestBand
  {-802,-930,1.0,344,'CityMaple'}, -- WestBand
  {-802,-1010,1.1,31,'CityMaple'}, -- WestBand
  {-802,-1090,1.2,78,'CityMaple'}, -- WestBand
  {678,-280,1.2,140,'CityBroadleaf'}, -- EastBand
  {678,-350,1.3,187,'CityBroadleaf'}, -- EastBand
  {670,-420,0.8,234,'CityBroadleaf'}, -- EastBand
  {670,-490,0.9,281,'CityBroadleaf'}, -- EastBand
  {678,-560,1.0,328,'CityBroadleaf'}, -- EastBand
  {678,-630,1.1,15,'CityBroadleaf'}, -- EastBand
  {678,-700,1.2,62,'CityBroadleaf'}, -- EastBand
  {678,-770,1.3,109,'CityBroadleaf'}, -- EastBand
  {714,-310,1.3,171,'CityMaple'}, -- EastBand
  {706,-380,0.8,218,'CityMaple'}, -- EastBand
  {714,-450,0.9,265,'CityMaple'}, -- EastBand
  {714,-520,1.0,312,'CityMaple'}, -- EastBand
  {706,-590,1.1,359,'CityMaple'}, -- EastBand
  {706,-660,1.2,46,'CityMaple'}, -- EastBand
  {706,-730,1.3,93,'CityMaple'}, -- EastBand
  {706,-800,0.8,140,'CityMaple'}, -- EastBand
  {-620,-1220,0.8,202,'CityBroadleaf'}, -- NorthBand
  {-550,-1225,0.9,249,'CityBroadleaf'}, -- NorthBand
  {-480,-1232,1.0,296,'CityBroadleaf'}, -- NorthBand
  {-410,-1225,1.1,343,'CityBroadleaf'}, -- NorthBand
  {-340,-1220,1.2,30,'CityBroadleaf'}, -- NorthBand
  {-585,-1248,0.9,233,'CityMaple'}, -- NorthBand
  {-515,-1244,1.0,280,'CityMaple'}, -- NorthBand
  {-445,-1248,1.1,327,'CityMaple'}, -- NorthBand
  {-375,-1244,1.2,14,'CityMaple'}, -- NorthBand
  {-305,-1248,1.3,61,'CityMaple'}, -- NorthBand
  {-245,-1070,1.0,264,'CityBroadleaf'}, -- UpperS
  {-175,-1070,1.1,311,'CityBroadleaf'}, -- UpperS
  {-105,-1070,1.2,358,'CityBroadleaf'}, -- UpperS
  {-225,-1118,1.1,295,'CityMaple'}, -- UpperS
  {-155,-1110,1.2,342,'CityMaple'}, -- UpperS
  {-85,-1120,1.3,29,'CityMaple'}, -- UpperS
  {-590,-1000,1.2,326,'CityBroadleaf'}, -- Infield
  {-590,-860,1.3,13,'CityBroadleaf'}, -- Infield
  {495,-350,0.8,60,'CityBroadleaf'}, -- Infield
  {495,-510,0.9,107,'CityBroadleaf'}, -- Infield
  {-590,-930,1.3,357,'CityMaple'}, -- Infield
  {-590,-790,0.8,44,'CityMaple'}, -- Infield
  {495,-430,0.9,91,'CityMaple'}, -- Infield
  {495,-690,1.0,138,'CityMaple'}, -- Infield
 }
 for i,s in treeSites do
  local prefab=(forest and forest:FindFirstChild(s[5]))or(trees and trees:FindFirstChild(s[5]))
  if prefab then
   local model=prefab:Clone();model.Name='ParkTree'..i
   local base=foot(model);local target=CFrame.new(origin+Vector3.new(s[1],-.2,s[2]))*CFrame.Angles(0,math.rad(s[4]),0)
   for _,p in model:GetDescendants()do
    if p:IsA('BasePart')then
     local frame=p.CFrame;p.Size*=s[3]
     p.CFrame=target*CFrame.new((frame.Position-base)*s[3])*frame.Rotation;static(p)
    elseif not (p:IsA('Model')or p:IsA('Folder')or p:IsA('SurfaceAppearance'))then p:Destroy()end
   end
   model:SetAttribute('CuratedPrefab',s[5]);model.Parent=folder
  end
 end
 -- The existing asset manifest identifies this same leaf mesh as OB_Bush_a.
 local leaf=trees and trees:FindFirstChild('NaturalTreeA');leaf=leaf and leaf:FindFirstChild('Leaves')
 -- Low planted islands, built from the already audited bush/leaf mesh.
 -- Native small flower heads avoid new mesh/texture dependencies or scripts.
 local flowerColors={Color3.fromRGB(183,77,105),Color3.fromRGB(155,119,184),
  Color3.fromRGB(156,188,212),Color3.fromRGB(189,83,80)}
 for i,s in {{-156,-48},{156,-48},{-435,-302},{458,-440},
  {-770,-615},{675,-610},{-210,-995},{-65,-315}}do
  if not leaf then continue end
  local bed=Instance.new('Folder');bed.Name='ParkFlowerBed'..i;bed.Parent=folder
  local frame=CFrame.new(origin+Vector3.new(s[1],0,s[2]))*CFrame.Angles(0,i*.63,0)
  for j,offset in {Vector3.new(-3,0,0),Vector3.new(2,0,-1),Vector3.new(0,0,2)}do
   local p=leaf:Clone();p.Name='LowShrub'..j;p.Size=Vector3.new(6,2.8,5)
   p.CFrame=frame*CFrame.new(offset+Vector3.new(0,1.2,0));static(p);p.Parent=bed
  end
  for j,offset in {Vector3.new(-3,2.4,0),Vector3.new(-1,2.6,-1),
   Vector3.new(2,2.3,-1),Vector3.new(1,2.5,2),Vector3.new(-1,2.2,2)}do
   local p=Instance.new('Part');p.Name='FlowerCluster'..j;p.Shape=Enum.PartType.Cylinder
   p.Size=Vector3.new(.18,1.8,1.8);p.CFrame=frame*CFrame.new(offset)*CFrame.Angles(0,0,math.pi/2)
   p.Color=flowerColors[(i-1)%#flowerColors+1];p.Material=Enum.Material.SmoothPlastic
   static(p);p.Parent=bed
   local center=p:Clone();center.Name='FlowerCenter'..j;center.Size=Vector3.new(.2,.55,.55)
   center.CFrame=p.CFrame+Vector3.new(0,.08,0);center.Color=Color3.fromRGB(218,183,101);center.Parent=bed
  end
 end
 for i,s in {{-120,-35},{120,-35},{-155,-225},{190,-265},{-410,-305},{450,-420}}do
  if leaf then local p=leaf:Clone();p.Name='ParkShrub'..i;p.Size=Vector3.new(9,7,9)
   p.CFrame=CFrame.new(origin+Vector3.new(s[1],3.3,s[2]))*CFrame.Angles(0,i*.7,0);static(p);p.Parent=folder
  end
 end
 for i,s in {{-150,-60},{150,-60},{-200,-250},{440,-400},{-525,-800}}do
  local p=Instance.new('WedgePart');p.Name='ParkRock'..i;p.Size=Vector3.new(12,8,10)
  p.CFrame=CFrame.new(origin+Vector3.new(s[1],3.7,s[2]))*CFrame.Angles(0,i*.9,0)
  p.Material=Enum.Material.Slate;p.Color=Color3.fromRGB(115,121,115);static(p);p.Parent=folder
 end
 for i,s in {{500,-1080,180,65,150,'HorizonMountainA'},{-570,-970,150,60,150,'HorizonMountainB'},{40,-1100,200,65,150,'HorizonMountainA'}}do
  local prefab=mountains and mountains:FindFirstChild(s[6])
  if prefab then local p=prefab:Clone();p.Name='ParkBackdropHill'..i;p.Size=Vector3.new(s[3],s[4],s[5])
   p.CFrame=CFrame.new(origin+Vector3.new(s[1],s[4]/2-2.2,s[2]));static(p);p.Parent=folder
  end
 end
 return folder
end
return Builder
