-- Static City forest masses and understory, only in opt-in HUBs.
local Builder={}
function Builder.build(root,origin,trees,mountains)
 local existing=root:FindFirstChild('ParkLandscaping');if existing then return existing end
 local folder=Instance.new('Folder');folder.Name='ParkLandscaping';folder.Parent=root
 local forest=game:GetService('ReplicatedStorage'):FindFirstChild('KDMHubForestTreePrefabs')
 local function static(p)
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  -- Preserve the curated asset's LOD. RenderFidelity is editor-write-only.
 end
 local function foot(model,prefabName)
  local lo,hi=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
  for _,p in model:GetDescendants()do if p:IsA('BasePart')then
   for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do
    local v=p.CFrame:PointToWorldSpace(p.Size*Vector3.new(x,y,z)/2)
    lo=Vector3.new(math.min(lo.X,v.X),math.min(lo.Y,v.Y),math.min(lo.Z,v.Z))
    hi=Vector3.new(math.max(hi.X,v.X),math.max(hi.Y,v.Y),math.max(hi.Z,v.Z))
   end end end
  end end
  local groundY=lo.Y
  if prefabName=='CityMaple'then
   -- This tilted mesh's empty bounding-box corners extend below its roots.
   -- Plant at the trunk's root collar, burying the lowest 2 source studs
   -- so the spreading roots meet the grass instead of hovering above it.
   local trunk=model:FindFirstChild('Trunk')
   if trunk and trunk:IsA('BasePart')then
    groundY=trunk.CFrame:PointToWorldSpace(Vector3.new(0,-trunk.Size.Y/2,0)).Y+2
   end
  end
  return Vector3.new((lo.X+hi.X)/2,groundY,(lo.Z+hi.Z)/2)
 end
 -- Mobile forest: dark CityBroadleaf placements removed. Retain offset sites rather
 -- than continuous overlapping rows. The northeast grove has an open center
 -- (ellipse centered at 300,-1080; radii 220/120), with its perimeter retained.
 -- Owner approved removing the 15-tree third Lobby verge row (z=145).
 -- Keep the other two offset rows and 243 total trees; approach stays open.
 local treeSites={
  {-145,-25,.85,15,'NaturalTreeA'},
  {145,-25,.9,-25,'NaturalTreeB'},
  {-180,-245,1.1,35,'NaturalTreeA'},
  {175,-245,1.15,-40,'NaturalTreeB'},
  {-410,-285,1,70,'NaturalTreeA'},
  {455,-405,1,10,'NaturalTreeB'},
  {-200,65,1.2,55,'NaturalTreeA'},
  {-792,-786,1.0,100,'NaturalTreeB'},
  {-238,-1010,1.05,20,'NaturalTreeB'},
  {-208,-1028,1.1,-40,'NaturalTreeA'},
  {-175,-1012,1.0,80,'NaturalTreeB'},
  {-51,-299,1.05,110,'NaturalTreeA'},
  {-802,-530,1.1,109,'CityMaple'},
  {-802,-610,1.2,156,'CityMaple'},
  {-810,-690,1.3,203,'CityMaple'},
  {-802,-850,0.9,297,'CityMaple'},
  {-802,-930,1.0,344,'CityMaple'},
  {-802,-1010,1.1,31,'CityMaple'},
  {-802,-1090,1.2,78,'CityMaple'},
  {714,-310,1.3,171,'CityMaple'},
  {706,-380,0.8,218,'CityMaple'},
  {714,-450,0.9,265,'CityMaple'},
  {714,-520,1.0,312,'CityMaple'},
  {706,-590,1.1,359,'CityMaple'},
  {706,-660,1.2,46,'CityMaple'},
  {706,-730,1.3,93,'CityMaple'},
  {706,-800,0.8,140,'CityMaple'},
  {-585,-1248,0.9,233,'CityMaple'},
  {-515,-1244,1.0,280,'CityMaple'},
  {-445,-1248,1.1,327,'CityMaple'},
  {-375,-1244,1.2,14,'CityMaple'},
  {-305,-1248,1.3,61,'CityMaple'},
  {-225,-1118,1.1,295,'CityMaple'},
  {-155,-1110,1.2,342,'CityMaple'},
  {-85,-1120,1.3,29,'CityMaple'},
  {-590,-930,1.3,357,'CityMaple'},
  {650,65,0.8,165,'CityMaple'},
  {495,-430,0.9,91,'CityMaple'},
  {604,-1005,1.25,43,'CityMaple'},
  {-290,-1209,1.20,234,'CityMaple'},
  {-355,-564,1.20,301,'CityMaple'},
  {-6,-901,1.30,93,'CityMaple'},
  {-380,-350,1.10,308,'CityMaple'},
  {-692,-1244,1.25,189,'CityMaple'},
  {-400,-15,1.1,290,'CityMaple'},
  {-254,-763,1.15,233,'CityMaple'},
  {-17,-253,1.10,224,'CityMaple'},
  {604,-1138,1.20,276,'CityMaple'},
  {-108,-1168,1.10,165,'CityMaple'},
  {-217,-283,1.20,251,'CityMaple'},
  {-214,-1166,1.30,9,'CityMaple'},
  {-794,-258,1.25,74,'CityMaple'},
  {-187,-1202,1.20,287,'CityMaple'},
  {-754,-428,1.25,170,'CityMaple'},
  {-325,-15,1.2,0,'CityMaple'},
  {-588,-664,1.25,347,'CityMaple'},
  {-6,-287,1.25,116,'CityMaple'},
  {662,-827,1.15,156,'CityMaple'},
  {-757,-284,1.10,142,'CityMaple'},
  {255,-492,1.10,323,'CityMaple'},
  {424,-659,1.30,284,'CityMaple'},
  {-795,-321,1.10,304,'CityMaple'},
  {-346,-697,1.10,318,'CityMaple'},
  {23,-964,1.30,29,'CityMaple'},
  {189,-936,1.10,237,'CityMaple'},
  {332,-934,1.10,119,'CityMaple'},
  {-660,-464,1.30,205,'CityMaple'},
  {425,65,0.9,325,'CityMaple'},
  {640,-1176,1.10,41,'CityMaple'},
  {157,-288,1.30,203,'CityMaple'},
  {-248,-1239,1.20,98,'CityMaple'},
  {-526,-1035,1.20,16,'CityMaple'},
  {-250,-15,0.8,65,'CityMaple'},
  {-118,-1098,1.15,9,'CityMaple'},
  {-351,-282,1.25,156,'CityMaple'},
  {663,-1103,1.15,132,'CityMaple'},
  {-386,-385,1.15,182,'CityMaple'},
  {-688,-327,1.30,299,'CityMaple'},
  {-382,-827,1.20,326,'CityMaple'},
  {-755,-249,1.25,281,'CityMaple'},
  {-175,-15,1,130,'CityMaple'},
  {500,-293,1.30,226,'CityMaple'},
  {175,-15,1.1,200,'CityMaple'},
  {-354,-731,1.20,39,'CityMaple'},
  {536,-1177,1.25,304,'CityMaple'},
  {-354,-804,1.30,74,'CityMaple'},
  {96,-252,1.10,333,'CityMaple'},
  {-452,-939,1.15,53,'CityMaple'},
  {632,-1038,1.30,0,'CityMaple'},
  {92,-967,1.25,58,'CityMaple'},
  {52,-940,1.25,304,'CityMaple'},
  {670,-932,1.10,176,'CityMaple'},
  {-40,-971,1.10,16,'CityMaple'},
  {672,-898,1.30,292,'CityMaple'},
  {527,-1142,1.20,68,'CityMaple'},
  {-9,-997,1.25,332,'CityMaple'},
  {431,-254,1.15,294,'CityMaple'},
  {250,-15,0.9,265,'CityMaple'},
  {-486,-997,1.30,170,'CityMaple'},
  {565,-1072,1.10,257,'CityMaple'},
  {637,-1071,1.10,40,'CityMaple'},
  {596,-1169,1.15,221,'CityMaple'},
  {-216,-1235,1.30,315,'CityMaple'},
  {575,65,1.2,100,'CityMaple'},
  {-417,-725,1.20,52,'CityMaple'},
  {325,-15,1.1,335,'CityMaple'},
  {568,-1140,1.20,285,'CityMaple'},
  {-700,-15,0.8,25,'CityMaple'},
  {-555,-1005,1.25,125,'CityMaple'},
  {-81,-1039,1.15,213,'CityMaple'},
  {197,-905,1.10,65,'CityMaple'},
  {-625,-15,1,90,'CityMaple'},
  {400,-15,1.2,40,'CityMaple'},
  {-354,-423,1.10,328,'CityMaple'},
  {-279,-736,1.30,118,'CityMaple'},
  {257,-931,1.25,357,'CityMaple'},
  {130,-520,1.15,128,'CityMaple'},
  {163,-493,1.15,326,'CityMaple'},
  {-788,-426,1.25,169,'CityMaple'},
  {300,-248,1.25,179,'CityMaple'},
  {-417,-663,1.15,164,'CityMaple'},
  {595,-1098,1.15,81,'CityMaple'},
  {-151,-1166,1.30,121,'CityMaple'},
  {604,-894,1.20,203,'CityMaple'},
  {475,-15,0.8,105,'CityMaple'},
  {550,-15,1,175,'CityMaple'},
  {392,-694,1.10,358,'CityMaple'},
  {625,-15,1.1,240,'CityMaple'},
  {163,-970,1.10,62,'CityMaple'},
  {-316,-769,1.15,1,'CityMaple'},
  {-285,-292,1.20,214,'CityMaple'},
  {-355,-324,1.30,313,'CityMaple'},
  {-553,-690,1.10,159,'CityMaple'},
  {470,-698,1.15,333,'CityMaple'},
  {-732,-396,1.30,43,'CityMaple'},
  {275,65,1.3,210,'CityMaple'},
  {119,-935,1.20,129,'CityMaple'},
  {-350,-599,1.20,192,'CityMaple'},
  {-725,65,1.1,310,'CityMaple'},
  {-524,-962,1.25,191,'CityMaple'},
  {-391,-524,1.25,62,'CityMaple'},
  {498,-634,1.15,8,'CityMaple'},
  {500,65,1.3,30,'CityMaple'},
  {-50,-1107,1.25,116,'CityMaple'},
  {200,65,1,140,'CityMaple'},
  {-695,-283,1.30,221,'CityMaple'},
  {-346,-532,1.10,324,'CityMaple'},
  {-650,65,1.2,0,'CityMaple'},
  {-79,-252,1.30,202,'CityMaple'},
  {664,-1036,1.10,221,'CityMaple'},
  {-575,65,0.8,65,'CityMaple'},
  {-663,-255,1.25,319,'CityMaple'},
  {220,-259,1.30,262,'CityMaple'},
  {-9,-1176,1.30,354,'CityMaple'},
  {-500,65,1,150,'CityMaple'},
  {600,-970,1.15,63,'CityMaple'},
  {60,-971,1.10,238,'CityMaple'},
  {429,-292,1.15,239,'CityMaple'},
  {-322,-357,1.10,292,'CityMaple'},
  {570,-1004,1.15,38,'CityMaple'},
  {-352,-488,1.15,308,'CityMaple'},
  {-387,-556,1.20,299,'CityMaple'},
  {350,65,0.8,275,'CityMaple'},
  {-630,-355,1.25,205,'CityMaple'},
  {-459,-634,1.10,203,'CityMaple'},
  {-284,-799,1.20,96,'CityMaple'},
  {-654,-289,1.30,199,'CityMaple'},
  {-550,-15,1.1,175,'CityMaple'},
  {222,-965,1.30,139,'CityMaple'},
  {124,-289,1.25,96,'CityMaple'},
  {-764,-1170,1.25,71,'CityMaple'},
  {-15,-869,1.20,99,'CityMaple'},
  {529,-1041,1.20,259,'CityMaple'},
  {-323,-661,1.15,297,'CityMaple'},
  {130,-868,1.20,149,'CityMaple'},
  {-490,-697,1.15,117,'CityMaple'},
  {-425,65,1.3,215,'CityMaple'},
  {-452,-1031,1.10,133,'CityMaple'},
  {-350,65,0.9,265,'CityMaple'},
  {58,-902,1.10,308,'CityMaple'},
  {-118,-256,1.30,225,'CityMaple'},
  {-251,-320,1.30,202,'CityMaple'},
  {-41,-1072,1.15,222,'CityMaple'},
  {265,-290,1.25,146,'CityMaple'},
  {-323,-258,1.25,349,'CityMaple'},
  {-728,-326,1.15,169,'CityMaple'},
  {-289,-832,1.00,308,'CityBeech'},
  {-216,-769,1.05,89,'CityBeech'},
  {-289,-1143,1.10,278,'CityDogwood'},
  {92,-492,1.15,178,'CityDogwood'},
  {432,-736,1.15,33,'CityBeech'},
  {-78,-972,0.95,226,'CityBeech'},
  {-659,-1240,1.25,249,'CityDogwood'},
  {463,-599,1.25,52,'CityBeech'},
  {-418,-322,1.10,122,'CityBeech'},
  {-222,-665,1.15,49,'CityBeech'},
  {-627,-965,0.95,98,'CityDogwood'},
  {87,-318,1.05,6,'CityDogwood'},
  {368,-897,1.30,155,'CityBeech'},
  {-414,-964,1.20,16,'CityBeech'},
  {257,-698,1.05,323,'CityBeech'},
  {-249,-836,0.90,208,'CityBeech'},
  {153,-556,1.20,333,'CityBeech'},
  {-50,-940,1.10,128,'CityBeech'},
  {669,-589,0.90,217,'CityBeech'},
  {500,-725,1.05,115,'CityDogwood'},
  {-83,-527,0.95,151,'CityBeech'},
  {-562,-1065,1.20,100,'CityBeech'},
  {21,-323,1.10,343,'CityDogwood'},
  {468,-529,1.10,78,'CityBeech'},
  {359,-351,0.90,65,'CityBeech'},
  {-313,-599,1.15,70,'CityDogwood'},
  {329,-895,1.25,259,'CityBeech'},
  {358,-667,0.95,325,'CityBeech'},
  {531,-254,1.00,151,'CityBeech'},
  {-732,-1178,1.10,95,'CityDogwood'},
  {427,-388,1.30,304,'CityDogwood'},
  {-592,-361,1.20,177,'CityDogwood'},
  {-286,-622,1.15,137,'CityBeech'},
  {674,-384,1.10,270,'CityDogwood'},
  {-688,-488,1.05,245,'CityBeech'},
  {672,-455,1.05,292,'CityBeech'},
  {297,-294,0.90,236,'CityDogwood'},
  {-623,-1033,1.05,169,'CityDogwood'},
  {464,-497,1.05,305,'CityDogwood'},
  {-485,-1065,1.25,217,'CityBeech'},
  {292,-725,1.15,101,'CityBeech'},
  {-475,-15,0.9,225,'CityDogwood'},
  {22,-497,1.00,125,'CityBeech'},
  {532,-906,1.30,230,'CityBeech'},
  {-44,-491,1.20,116,'CityDogwood'},
  {-44,-895,0.95,81,'CityBeech'},
  {-525,-622,0.95,359,'CityDogwood'},
  {162,-861,1.30,220,'CityBeech'},
  {671,-521,1.00,271,'CityBeech'},
  {-46,-861,1.00,200,'CityDogwood'},
  {-384,-589,0.90,333,'CityDogwood'},
  {-421,-429,1.05,218,'CityDogwood'},
  {495,-557,1.00,126,'CityBeech'},
  {-621,-282,0.95,154,'CityDogwood'},
  {-275,65,1.2,350,'CityBeech'},
  {469,-260,1.00,120,'CityDogwood'},
  {93,-867,1.10,141,'CityBeech'},
 }
 local function plant(s,name,understory)
  local prefab=(forest and forest:FindFirstChild(s[5]))or(trees and trees:FindFirstChild(s[5]))
  if prefab then
   local model=prefab:Clone();model.Name=name
   local base=foot(model,s[5]);local target=CFrame.new(origin+Vector3.new(s[1],-.2,s[2]))*CFrame.Angles(0,math.rad(s[4]),0)
   for _,p in model:GetDescendants()do
    if p:IsA('BasePart')then
     local frame=p.CFrame;p.Size*=s[3]
     p.CFrame=target*CFrame.new((frame.Position-base)*s[3])*frame.Rotation;static(p)
    elseif not (p:IsA('Model')or p:IsA('Folder')or p:IsA('SurfaceAppearance'))then p:Destroy()end
   end
   model:SetAttribute('CuratedPrefab',s[5]);model:SetAttribute('ForestUnderstory',understory==true);model.Parent=folder
  end
 end
 for i,s in treeSites do plant(s,'ParkTree'..i,false)end
 -- No forest understory. Fifteen mixed low plants wrap each Lobby tree
 -- at (+/-145,-25), with irregular inner/outer arcs and a clear trunk collar.
 local understorySites={
  {-134,-32,0.80,317,'CityRhododendron'},
  {-140,-39,0.75,36,'CityLaurel'},
  {-148,-39,0.90,115,'CityFern'},
  {-155,-34,0.85,194,'CityRhododendron'},
  {-160,-27,0.80,273,'CityLaurel'},
  {-158,-18,0.95,352,'CityFern'},
  {-151,-12,0.75,71,'CityRhododendron'},
  {-143,-11,0.70,150,'CityLaurel'},
  {-135,-15,0.85,229,'CityFern'},
  {-130,-23,0.80,308,'CityRhododendron'},
  {-135,-24,0.75,27,'CityLaurel'},
  {-142,-34,0.90,106,'CityFern'},
  {-153,-31,0.85,185,'CityRhododendron'},
  {-153,-19,0.80,264,'CityLaurel'},
  {-141,-17,0.95,343,'CityFern'},
  {134,-32,0.80,43,'CityRhododendron'},
  {140,-39,0.75,122,'CityLaurel'},
  {148,-39,0.90,201,'CityFern'},
  {155,-34,0.85,280,'CityRhododendron'},
  {160,-27,0.80,359,'CityLaurel'},
  {158,-18,0.95,78,'CityFern'},
  {151,-12,0.75,157,'CityRhododendron'},
  {143,-11,0.70,236,'CityLaurel'},
  {135,-15,0.85,315,'CityFern'},
  {130,-23,0.80,34,'CityRhododendron'},
  {135,-24,0.75,113,'CityLaurel'},
  {142,-34,0.90,192,'CityFern'},
  {153,-31,0.85,271,'CityRhododendron'},
  {153,-19,0.80,350,'CityLaurel'},
  {141,-17,0.95,69,'CityFern'},
 }
 for i,s in understorySites do plant(s,'ParkUnderstory'..i,true)end
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
 return folder
end
return Builder
