-- Track-specific, reversible client scenery; native race geometry is authoritative.
local RS=game:GetService('ReplicatedStorage')
local W=game:GetService('Workspace')
local Lighting=game:GetService('Lighting')
local Geometry=require(RS.Shared.TrackGeometry)
local Layout=require(RS.Shared.MetroCityLayout)
local DesertRoad=require(script.Parent.Figure8DesertEnvironment)
local brandRail=require(RS.Shared.KDMRailBranding)
local Surface=require(RS.Shared.TrackSurfaceStandard)
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
 -- Clone the accepted Desert road variant verbatim; no global material override.
 local roadMaterial=RS:WaitForChild('KDMDesertResources').Materials.Racing_Asphalt_A:Clone()
 roadMaterial.Name='KDMMetro_Racing_Asphalt_A'
 -- Exact Desert surface; texture-map properties remain authoring-only.
 roadMaterial.Parent=materials;table.insert(copies,roadMaterial)
 for _,key in {'Brightness','ClockTime','GeographicLatitude','ExposureCompensation','Ambient','OutdoorAmbient','EnvironmentDiffuseScale','EnvironmentSpecularScale'}do oldLight[key]=Lighting[key]end
 for _,v in Lighting:GetChildren()do if v:IsA('Sky')or v:IsA('Atmosphere')or v:IsA('PostEffect')then v.Parent=backup end end
 for _,v in resources.Lighting:GetChildren()do
  if v:IsA('Atmosphere')then continue end -- Owner requested clear city visibility.
  local clone=v:Clone()
  if clone:IsA('ColorCorrectionEffect')then clone.Brightness=-.02;clone.Contrast=.08;clone.Saturation=.04 end
  clone.Parent=Lighting;table.insert(copies,clone)
 end
 for key,value in Surface.Lighting do Lighting[key]=value end
 local function appearance(p,color,material,variant,hide)
  saved[p]={p.Color,p.Material,p.MaterialVariant,p.LocalTransparencyModifier,p.Size}
  p.Color=color;p.Material=material;p.MaterialVariant=variant or ''
  if hide then p.LocalTransparencyModifier=1 end
 end
 local env=track:FindFirstChild('Environment')
 if env and env:FindFirstChild('Infield')then appearance(env.Infield,Color3.fromRGB(72,121,72),Enum.Material.Grass,'')end
 if ground then appearance(ground,Color3.fromRGB(72,121,72),Enum.Material.Grass,'')end
 local baseplate=W:FindFirstChild('Baseplate')
 if baseplate and baseplate~=ground then appearance(baseplate,Color3.fromRGB(72,121,72),Enum.Material.Grass,'')end
 if env and env:FindFirstChild('SpeedCues')then for _,p in env.SpeedCues:GetDescendants()do if p:IsA('BasePart')then appearance(p,p.Color,p.Material,p.MaterialVariant,true)end end end
 local road=track:FindFirstChild('Road')
 if road then for _,p in road:GetChildren()do if p:IsA('BasePart')then
  appearance(p,Surface.RoadTint,Enum.Material.Asphalt,'KDMMetro_Racing_Asphalt_A')
  local index=tonumber(p.Name:match('^Road(%d+)$'))
  local length=index and DesertRoad.straightRoadLength(course.Samples,index)
  if length and not p.CanCollide then p.Size=Vector3.new(p.Size.X,p.Size.Y,length)end
 end end end
 model.Destroying:Connect(function()
  alive=false
  for p,v in saved do if p.Parent then p.Color=v[1];p.Material=v[2];p.MaterialVariant=v[3];p.LocalTransparencyModifier=v[4];if p.Size~=v[5]then p.Size=v[5]end end end
  for _,v in copies do v:Destroy()end
  for _,v in backup:GetChildren()do v.Parent=Lighting end;backup:Destroy()
  for key,value in oldLight do Lighting[key]=value end
 end)
 local function part(name,size,frame,color,material,variant)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color
  p.Material=material or Enum.Material.SmoothPlastic;p.MaterialVariant=variant or '';safe(p);p.Parent=model;return p
 end
 local bounds=course.Bounds;local cx,cz=(bounds.MinX+bounds.MaxX)/2,(bounds.MinZ+bounds.MaxZ)/2
 for _,x in {-1,1}do for _,z in {-1,1}do
  part('CityGrassFoundation',Vector3.new(1800,.02,1800),CFrame.new(cx+x*900,groundY-.02,cz+z*900),Color3.fromRGB(72,121,72),Enum.Material.Grass,'')
 end end
 -- Retain the original distant-city Sky without surrounding photo walls.
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
  local lampSites,railSites=Layout.roadsidePlan(Geometry,course,width,sites)
  for i,site in lampSites do
   if not alive then return end
   local clone=resources.StreetLamp_A:Clone();clone.PrimaryPart=nil;clone.WorldPivot=CFrame.identity
   local cf,size=clone:GetBoundingBox()
   clone:PivotTo((site.frame+Vector3.new(0,groundY+size.Y/2,0))*cf:ToObjectSpace(clone:GetPivot()))
   for _,p in clone:GetDescendants()do if p:IsA('BasePart')then safe(p);if p.MaterialVariant~=''then p.MaterialVariant='KDMMetro_'..p.MaterialVariant end end end
   clone.Name='StreetLamp'..i;clone:SetAttribute('StationSide',site.side);clone.Parent=model
   if i%12==0 then task.wait()end
  end
  for i,site in railSites do
   if not alive then return end
   local rail=part('ParkAdRail'..i,Vector3.new(.5,4.5,20),site.frame+Vector3.new(0,groundY+2.25,0),if i%2==0 then Color3.fromRGB(180,65,65)else Color3.fromRGB(220,225,230))
   brandRail(rail,site.outward)
  end
  model:SetAttribute('StreetLampCount',#lampSites);model:SetAttribute('AdRailCount',#railSites)
  local parts,count,minimum=0,0,math.huge
  for _,site in sites do
   if not alive or not track.Parent then return end
   local prefab=resources:FindFirstChild(site.name);local missing=false
   for _,p in prefab:GetDescendants()do if p:IsA('MeshPart')and
    (p.MeshId==''or math.min(p.MeshSize.X,p.MeshSize.Y,p.MeshSize.Z)<=0)then missing=true;break end end
   if missing then warn('[KDMMetro] invalid mesh identity/intrinsic size: '..site.name);continue end
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
   if site.corner then clone:SetAttribute('CornerInfill',site.corner)end
   local padFrame=site.frame*CFrame.new(0,0,-10)
   local padSize=Vector3.new(size.X+.4,.04,size.Z+20)
   if Layout.footprintDistance(course.Samples,padFrame,padSize)>=width/2+6 then
    part('BuildingForecourt',padSize,padFrame+Vector3.new(0,groundY+.16,0),Color3.fromRGB(235,230,225),Enum.Material.Concrete,'KDMMetro_Sidewalk_A')
   end
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
  -- Exact dominant Rookie Park asset, planted using Park's accepted root collar.
  local tree=RS:WaitForChild('KDMHubForestTreePrefabs'):WaitForChild('CityMaple')
  local lo,hi=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
  for _,p in tree:GetDescendants()do if p:IsA('BasePart')then
   for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do
    local v=p.CFrame:PointToWorldSpace(p.Size*Vector3.new(x,y,z)/2)
    lo=Vector3.new(math.min(lo.X,v.X),math.min(lo.Y,v.Y),math.min(lo.Z,v.Z))
    hi=Vector3.new(math.max(hi.X,v.X),math.max(hi.Y,v.Y),math.max(hi.Z,v.Z))
   end end end
  end end
  local trunk=tree.Trunk
  local base=Vector3.new((lo.X+hi.X)/2,trunk.CFrame:PointToWorldSpace(Vector3.new(0,-trunk.Size.Y/2,0)).Y+2,(lo.Z+hi.Z)/2)
  local trees=Layout.forestPlan(Geometry,course,width,sites,hi-lo)
  for i,site in trees do
   if not alive then return end
   local clone=tree:Clone()
   local frame=CFrame.new(site.position+Vector3.new(0,groundY-.2,0))*CFrame.Angles(0,site.yaw,0)
   for _,p in clone:GetDescendants()do if p:IsA('BasePart')then
    local original=p.CFrame;p.Size*=site.scale
    p.CFrame=frame*CFrame.new((original.Position-base)*site.scale)*original.Rotation
    safe(p);parts+=1
   end end
   clone.Name='PocketGroveTree'..i;clone:SetAttribute('CuratedPrefab','CityMaple')
   clone:SetAttribute('PlantScale',site.scale);clone:SetAttribute('PlantYaw',site.yaw);clone.Parent=model
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
   model:SetAttribute('DistantCityStyle','ORIGINAL_TEMPLATE_SKY_CLEAR_ATMOSPHERE');model:SetAttribute('AtmosphereMode','REMOVED');model:SetAttribute('TreeSpecies','CityMaple')
   model:SetAttribute('BuildSeconds',os.clock()-started);model:SetAttribute('Ready',true)
  end
 end)
 return model
end
function Environment.start()
 if stop then return end
 local connections={};local trackConnections={};local watched;local active;local pending=false;local closed=false
 local schedule
 local function clear()local previous=active;active=nil;if previous then previous:Destroy()end end
 local function update()
  if closed then return end
  local proto=W:FindFirstChild('Prototype');local track=proto and proto:FindFirstChild('TestTrack')
  if watched~=track then
   for _,c in trackConnections do c:Disconnect()end;table.clear(trackConnections);watched=track
   if track then for _,key in {'TrackId','GeometryId','RoadSegmentCount'}do
    table.insert(trackConnections,track:GetAttributeChangedSignal(key):Connect(function()schedule()end))
   end end
  end
  if track and Layout.eligible(W:GetAttribute('KDMServerRole'),track:GetAttribute('TrackId'),track:GetAttribute('GeometryId'))then
   local road=track:FindFirstChild('Road')
   local expected=track:GetAttribute('RoadSegmentCount')or math.huge
   if road and #road:GetChildren()>=expected and (not active or active.Parent~=track)then clear();active=Environment.build(track)end
  else clear()end
 end
 schedule=function()
  if pending or closed then return end;pending=true
  task.defer(function()pending=false;update()end)
 end
 table.insert(connections,W.DescendantAdded:Connect(function(o)if o.Name=='TestTrack'or o.Name=='Road'or (watched and o.Parent==watched:FindFirstChild('Road'))then schedule()end end))
 table.insert(connections,W.DescendantRemoving:Connect(function(o)if active and (o==active.Parent or o==active)then clear();schedule()end end))
 table.insert(connections,W:GetAttributeChangedSignal('KDMServerRole'):Connect(schedule))
 stop=function()closed=true;clear();for _,c in connections do c:Disconnect()end;for _,c in trackConnections do c:Disconnect()end;stop=nil end
 update()
end
function Environment.destroy()if stop then stop()end end
return Environment
