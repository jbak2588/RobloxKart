-- Track-specific, reversible client scenery; native race geometry is authoritative.
local RS=game:GetService('ReplicatedStorage')
local W=game:GetService('Workspace')
local Lighting=game:GetService('Lighting')
local Geometry=require(RS.Shared.TrackGeometry)
local Layout=require(RS.Shared.MetroCityLayout)
local Environment={}
local stop
local function safe(p)
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
end
function Environment.build(track)
 local resources=RS:WaitForChild('KDMMetroResources')
 if not track.Parent then return nil end
 local model=Instance.new('Model');model.Name='MetroCityEnvironment'
 model:SetAttribute('Theme','SOURCE_CITY');model:SetAttribute('Source','city.rbxlx')
 local ground=track:FindFirstChild('SafetyGround')or W:FindFirstChild('Baseplate')
 local groundY=if ground then ground.Position.Y+ground.Size.Y/2 else 0
 local course=Geometry.getCourse(Geometry.getDefinition(Layout.GeometryId))
 local width=Geometry.getDefinition(Layout.GeometryId).RoadWidth
 local saved={};local copies={};local oldLight={};local alive=true
 local backup=Instance.new('Folder')
 local materials=game:GetService('MaterialService')
 for _,v in resources.Materials:GetChildren()do
  local clone=v:Clone();clone.Name='KDMMetro_'..v.Name;clone.Parent=materials;table.insert(copies,clone)
 end
 for _,key in {'Brightness','ClockTime','ExposureCompensation','Ambient','OutdoorAmbient','EnvironmentDiffuseScale','EnvironmentSpecularScale'}do oldLight[key]=Lighting[key]end
 for _,v in Lighting:GetChildren()do if v:IsA('Sky')or v:IsA('Atmosphere')or v:IsA('PostEffect')then v.Parent=backup end end
 for _,v in resources.Lighting:GetChildren()do
  local clone=v:Clone()
  clone.Parent=Lighting;table.insert(copies,clone)
 end
 Lighting.Brightness=2;Lighting.ClockTime=15.5;Lighting.ExposureCompensation=0
 Lighting.Ambient=Color3.fromRGB(10,9,12);Lighting.OutdoorAmbient=Color3.fromRGB(34,26,36)
 Lighting.EnvironmentDiffuseScale=1;Lighting.EnvironmentSpecularScale=1
 local function appearance(p,color,material,variant,hide)
  saved[p]={p.Color,p.Material,p.MaterialVariant,p.LocalTransparencyModifier}
  p.Color=color;p.Material=material;p.MaterialVariant=variant or ''
  if hide then p.LocalTransparencyModifier=1 end
 end
 local env=track:FindFirstChild('Environment')
 if env and env:FindFirstChild('Infield')then appearance(env.Infield,Color3.fromRGB(115,114,119),Enum.Material.Concrete,'')end
 if ground then appearance(ground,Color3.fromRGB(115,114,119),Enum.Material.Concrete,'')end
 if env and env:FindFirstChild('SpeedCues')then for _,p in env.SpeedCues:GetDescendants()do if p:IsA('BasePart')then appearance(p,p.Color,p.Material,p.MaterialVariant,true)end end end
 local road=track:FindFirstChild('Road')
 if road then for _,p in road:GetChildren()do if p:IsA('BasePart')then appearance(p,Color3.fromRGB(60,61,68),Enum.Material.Asphalt,'')end end end
 model.Destroying:Connect(function()
  alive=false
  for p,v in saved do if p.Parent then p.Color=v[1];p.Material=v[2];p.MaterialVariant=v[3];p.LocalTransparencyModifier=v[4]end end
  for _,v in copies do v:Destroy()end
  for _,v in backup:GetChildren()do v.Parent=Lighting end;backup:Destroy()
  for key,value in oldLight do Lighting[key]=value end
 end)
 local function part(name,size,frame,color,material,variant)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color
  p.Material=material or Enum.Material.SmoothPlastic;p.MaterialVariant=variant or '';safe(p);p.Parent=model;return p
 end
 local bounds=course.Bounds;local cx,cz=(bounds.MinX+bounds.MaxX)/2,(bounds.MinZ+bounds.MaxZ)/2
 part('CityFoundation',Vector3.new(3600,.02,3600),CFrame.new(cx,groundY-.02,cz),Color3.fromRGB(116,113,114),Enum.Material.Concrete,'')
 -- Original Sky already contains the distant hazy city. No surrounding photo walls.
 model.Parent=track
 task.spawn(function()
  local started=os.clock();local profiles={}
  for _,name in Layout.Names do
   local prefab=resources:FindFirstChild(name)
   if prefab then
    -- A first mesh can give a Model an implicit 90/180-degree pivot. The facade
    -- is canonical -Z; set its bounds axes without moving any source parts.
    prefab.PrimaryPart=nil;prefab.WorldPivot=CFrame.identity
    local _,size=prefab:GetBoundingBox();profiles[name]=size
   end
  end
  local sites=Layout.plan(Geometry,course,width,profiles)
  local parts,count,minimum=0,0,math.huge
  for _,site in sites do
   if not alive or not track.Parent then return end
   local prefab=resources:FindFirstChild(site.name);local missing=false
   for _,p in prefab:GetDescendants()do if p:IsA('MeshPart')and p.MeshId==''then missing=true;break end end
   if missing then warn('[KDMMetro] missing mesh: '..site.name);continue end
   local clone=prefab:Clone();clone:ScaleTo(clone:GetScale()*site.scale)
   local cf,size=clone:GetBoundingBox()
   local target=site.frame+Vector3.new(0,groundY+size.Y/2,0)
   clone:PivotTo(target*cf:ToObjectSpace(clone:GetPivot()))
   for _,p in clone:GetDescendants()do if p:IsA('BasePart')then
    -- Shared side/rear decoration is invisible inside a continuous street block.
    if (p.Name:match('_Rear$') and site.exposedRear==false)or (p.Name:match('_Side$') and not site.exposedSide and not site.bridge)then p:Destroy();continue end
    safe(p);parts+=1
    if p.MaterialVariant~=''then p.MaterialVariant='KDMMetro_'..p.MaterialVariant end
   end end
   clone.Name='StreetBuilding'..(count+1);clone:SetAttribute('SourceBuilding',site.name)
   clone:SetAttribute('RoadClearance',site.clearance-width/2);clone:SetAttribute('StreetBlock',site.block);clone.Parent=model
   count+=1;minimum=math.min(minimum,site.clearance-width/2)
   if count%3==0 then task.wait()end
  end
  local buildingParts=parts
  -- Reuse the original upper-floor bridge mesh between paired native towers.
  local bridges=0
  for i,b in Layout.Bridges do
   if not alive then return end
   local pair=0;for _,site in sites do if site.bridge==i then pair+=1 end end
   if pair~=2 then continue end
   local prefab=resources:FindFirstChild(b.name);prefab.PrimaryPart=nil;prefab.WorldPivot=CFrame.identity
   local clone=prefab:Clone();local _,original=clone:GetBoundingBox()
   clone:ScaleTo((width+2*Layout.ShoulderClearance+28)/original.Z)
   local cf,size=clone:GetBoundingBox();local right=Vector3.new(-b.forward.Z,0,b.forward.X)
   local frame=CFrame.lookAt(b.point+Vector3.new(0,groundY+55+size.Y/2,0),b.point+right+Vector3.new(0,groundY+55+size.Y/2,0))
   clone:PivotTo(frame*cf:ToObjectSpace(clone:GetPivot()))
   for _,p in clone:GetDescendants()do if p:IsA('BasePart')then safe(p);parts+=1;if p.MaterialVariant~=''then p.MaterialVariant='KDMMetro_'..p.MaterialVariant end end end
   clone.Name='UpperFloorSkybridge'..i;clone:SetAttribute('MinimumClearance',55);clone.Parent=model;bridges+=1
  end
  -- Small native beech groves occupy curved verges / deliberate gaps between blocks.
  local tree=resources.CityBeech;tree.PrimaryPart=nil;tree.WorldPivot=CFrame.identity
  local _,treeSize=tree:GetBoundingBox();local trees=Layout.forestPlan(Geometry,course,width,sites,treeSize)
  for i,site in trees do
   if not alive then return end
   local clone=tree:Clone();clone:ScaleTo(site.scale);local cf,size=clone:GetBoundingBox()
   local frame=CFrame.new(site.position+Vector3.new(0,groundY+size.Y/2,0))*CFrame.Angles(0,site.yaw,0)
   clone:PivotTo(frame*cf:ToObjectSpace(clone:GetPivot()))
   for _,p in clone:GetDescendants()do if p:IsA('BasePart')then safe(p);parts+=1;if p.MaterialVariant~=''then p.MaterialVariant='KDMMetro_'..p.MaterialVariant end end end
   clone.Name='PocketGroveTree'..i;clone.Parent=model
   if i%3==1 then part('PocketGroveBed',Vector3.new(22,.03,22),CFrame.new(site.position+Vector3.new(0,groundY+.045,0)),Color3.fromRGB(76,99,64),Enum.Material.Grass)end
   if i%8==0 then task.wait()end
  end
  local sidewalks=0
  for i=1,#course.Samples,2 do
   if not alive or not track.Parent then return end
   local a,b=course.Samples[i],course.Samples[(i+1)%#course.Samples+1]
   local tangent=(b-a).Unit;local right=Vector3.new(-tangent.Z,0,tangent.X)
   for _,side in {-1,1}do
    local center=(a+b)/2+right*(side*(width/2+25))
    part('ContinuousSidewalk',Vector3.new(34,.04,(b-a).Magnitude+2),CFrame.lookAt(Vector3.new(center.X,groundY+.10+(i%4)*.01,center.Z),Vector3.new(center.X,groundY+.10+(i%4)*.01,center.Z)+tangent),Color3.fromRGB(235,230,225),Enum.Material.Concrete,'KDMMetro_Sidewalk_A')
    sidewalks+=1
   end
   if i%16==1 then task.wait()end
  end
  if alive then
   model:SetAttribute('SkybridgeCount',bridges);model:SetAttribute('PocketGroveTreeCount',#trees)
   model:SetAttribute('BuildingCount',count);model:SetAttribute('BuildingPartCount',buildingParts)
   local sceneParts=0;for _,p in model:GetDescendants()do if p:IsA('BasePart')then sceneParts+=1 end end
   model:SetAttribute('ScenePartCount',sceneParts)
   model:SetAttribute('MinimumBuildingShoulder',if minimum<math.huge then minimum else 0)
   model:SetAttribute('SidewalkCount',sidewalks);model:SetAttribute('BackdropCount',0)
   model:SetAttribute('DistantCityStyle','ORIGINAL_TEMPLATE_SKY_AND_ATMOSPHERE')
   model:SetAttribute('BuildSeconds',os.clock()-started);model:SetAttribute('Ready',true)
  end
 end)
 return model
end
function Environment.start()
 if stop then return end
 local connections={};local active;local pending=false;local closed=false
 local function clear()local previous=active;active=nil;if previous then previous:Destroy()end end
 local function update()
  if closed then return end
  local proto=W:FindFirstChild('Prototype');local track=proto and proto:FindFirstChild('TestTrack')
  if track and Layout.eligible(W:GetAttribute('KDMServerRole'),track:GetAttribute('TrackId'),track:GetAttribute('GeometryId'))then
   if not active or active.Parent~=track then clear();active=Environment.build(track)end
  else clear()end
 end
 local function schedule()
  if pending or closed then return end;pending=true
  task.defer(function()pending=false;update()end)
 end
 table.insert(connections,W.DescendantAdded:Connect(function(o)if o.Name=='TestTrack'or o.Name=='Road'then schedule()end end))
 table.insert(connections,W.DescendantRemoving:Connect(function(o)if active and (o==active.Parent or o==active)then clear();schedule()end end))
 table.insert(connections,W:GetAttributeChangedSignal('KDMServerRole'):Connect(schedule))
 stop=function()closed=true;clear();for _,c in connections do c:Disconnect()end;stop=nil end
 update()
end
function Environment.destroy()if stop then stop()end end
return Environment
