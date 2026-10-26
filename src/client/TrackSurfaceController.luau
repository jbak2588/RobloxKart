-- Reversible scenery standard; physical supports, routes and karts are untouched.
local RS=game:GetService('ReplicatedStorage')
local W=game:GetService('Workspace')
local Lighting=game:GetService('Lighting')
local Geometry=require(RS.Shared.TrackGeometry)
local Standard=require(RS.Shared.TrackSurfaceStandard)
local Desert=require(script.Parent.Figure8DesertEnvironment)
local Layout=require(RS.Shared.MetroCityLayout)
local brandRail=require(RS.Shared.KDMRailBranding)
local Ribbon=require(script.Parent.TrackRoadRibbon)
local Landscape=require(script.Parent.TrackPreviewLandscape)
local Controller={};local stop
local function safe(p)
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
end
function Controller.build(track,park)
 local model=Instance.new('Model');model.Name='KDMTrackSurfaceStandard'
 local saved,light,copies={},{},{}
 local alive=true
 local function remember(p)
  if not saved[p]then saved[p]={p.Color,p.Material,p.MaterialVariant,p.CFrame,p.Size,p.LocalTransparencyModifier,p.Reflectance}end
 end
 local function hide(p)remember(p);p.LocalTransparencyModifier=1 end
 local function hideGui(g)saved[g]={g.Enabled};g.Enabled=false end
 for k,v in (if park then Standard.Sun else Standard.Lighting)do light[k]=Lighting[k];Lighting[k]=v end
 local grade=Instance.new('ColorCorrectionEffect');grade.Name='KDMDesertRoadGrade'
 if not park then grade.Brightness=-.02;grade.Contrast=.08;grade.Saturation=.04;grade.Parent=Lighting;table.insert(copies,grade)else grade:Destroy()end
 local smooth=park or track:GetAttribute('TrackId')=='Track01'
 local material=if smooth then RS:WaitForChild('KDMMetroResources').Materials.Metro_Racing_Asphalt_Matte:Clone()else RS:WaitForChild('KDMDesertResources').Materials.Racing_Asphalt_A:Clone()
 material.Name='KDMStandard_Racing_Asphalt_A';material.Parent=game.MaterialService;table.insert(copies,material)
 local samples,width,groundY
 if park then
  local origin=track:GetAttribute('Origin');groundY=origin.Y;width=track:GetAttribute('RoadWidth')
 else
  local course=Geometry.getCourse(Geometry.getDefinition(track:GetAttribute('GeometryId')))
  samples=course.Samples;width=track:GetAttribute('RoadWidth')
  local ground=track:FindFirstChild('SafetyGround')or W:FindFirstChild('Baseplate')
  groundY=if ground then ground.Position.Y+ground.Size.Y/2 else 0
 end
 local roads=0;local kerbs=0
 local roadListener,treeListener,markingListener
 local raised={};local raisedCount=0
 local function liftMarking(p)
  if not p:IsA('BasePart')or raised[p]then return end
  local target=if park then (p.Name=='Kerb'or p.Name=='EdgeLine')else (track:GetAttribute('TrackId')=='Track01'and(p.Name:match('^LeftEdge%d+$')or p.Name:match('^RightEdge%d+$')or p:GetAttribute('GuidanceKind')=='OuterEdge'))
  if not target then return end
  remember(p);raised[p]=true;p.CFrame+=Vector3.yAxis*Standard.MarkingLift;raisedCount+=1
  model:SetAttribute('RaisedMarkingCount',raisedCount)
 end
 local function road(p)
  if not p:IsA('BasePart')or p.CanCollide then return end
  remember(p);p.Color=Standard.RoadTint;p.Material=Enum.Material.Asphalt;p.MaterialVariant=material.Name
  local index=tonumber(p.Name:match('^Road(%d+)$'))
  local length=samples and index and Desert.straightRoadLength(samples,index)
  if length then p.Size=Vector3.new(p.Size.X,p.Size.Y,length)end
  if smooth then
   if (park and p.Name=='Road')or index then hide(p)else table.insert(copies,Ribbon.matte(p,if park then Standard.ParkRoadTint else nil))end
  end
  roads+=1
 end
 if park then
  for _,p in track:GetDescendants()do if p.Name=='Road'or p.Name=='PitRoad'then road(p)end end
  roadListener=track.DescendantAdded:Connect(function(p)
   if p.Name=='Road'or p.Name=='PitRoad'then road(p);model:SetAttribute('RoadCount',roads)end
  end)
 else
  for _,p in track.Road:GetChildren()do road(p)end
  local env=track:FindFirstChild('Environment')
  if env then for _,p in env:GetChildren()do if p.Name:match('^CrossoverRibbon')then road(p)end end end
  local folder=track:FindFirstChild('Kerbs')
  if folder then for _,p in folder:GetChildren()do if p:IsA('BasePart')then
   remember(p)
   local row=p:GetAttribute('KerbRow')or 1
   -- Separate overlapping red/white end caps, row two and road edge paint.
   p.CFrame+=Vector3.yAxis*(.115+(row-1)*.08+(if p.Color.R>p.Color.G*1.5 then .035 else 0))
   p.Material=Enum.Material.Concrete;p.MaterialVariant='';kerbs+=1
  end end end
 end
 if smooth then
  Ribbon.build(model,track,park,material.Name)
  for _,p in track:GetDescendants()do liftMarking(p)end
  markingListener=track.DescendantAdded:Connect(liftMarking)
 end
 model.Parent=track
 model.Destroying:Connect(function()
  alive=false
  if roadListener then roadListener:Disconnect()end
  if treeListener then treeListener:Disconnect()end
  if markingListener then markingListener:Disconnect()end
  for p,v in saved do if p.Parent then
   if p:IsA('SurfaceGui')then p.Enabled=v[1]
   else p.Color=v[1];p.Material=v[2];p.MaterialVariant=v[3];p.CFrame=v[4];p.Size=v[5];p.LocalTransparencyModifier=v[6];p.Reflectance=v[7]end
  end end
  for _,p in copies do p:Destroy()end
  for k,v in light do Lighting[k]=v end
 end)
 if not park then
  local env=track:FindFirstChild('Environment');local originals=env and env:FindFirstChild('VisualRails')
  local rails={}
  if originals then for _,p in originals:GetChildren()do
   if not p:IsA('BasePart')or p:GetAttribute('ChevronDirection')then continue end
   local clear=p:FindFirstChild('KDMBrandSurfaceGui')~=nil
   for _,q in rails do if (p.Position-q.Position).Magnitude<28 then clear=false;break end end
   for _,z in {-10,0,10}do local v=p.CFrame:PointToWorldSpace(Vector3.new(0,0,z))
    if Layout.roadDistance(samples,v.X,v.Z)<width/2+14 then clear=false end
   end
   if clear then
    local clone=p:Clone();clone.Name='ParkSizeAdRail'..(#rails+1);clone.Size=Standard.RailSize
    clone.CFrame=p.CFrame+Vector3.yAxis*(groundY+2.25-p.Position.Y);safe(clone)
    for _,g in clone:GetChildren()do if g:IsA('SurfaceGui')then g.ZOffset=.05;g.AlwaysOnTop=false end end
    clone.Parent=model;table.insert(rails,clone)
   end
   hide(p);for _,g in p:GetChildren()do if g:IsA('SurfaceGui')then hideGui(g)end end
  end end
  -- Base/Hard inherited only corner boards. Fill their open straight verges
  -- with the same bounded Park panels rather than resizing direction signs.
  if #rails==0 then
   local candidates={}
   for i=2,57 do
    local f=(i+.5)/60
    local p=Geometry.getSampleAtFraction(samples,f)
    local forward=Geometry.getTangentAtFraction(samples,f)
    local before=Geometry.getTangentAtFraction(samples,f-1/#samples)
    local after=Geometry.getTangentAtFraction(samples,f+1/#samples)
    if forward:Dot(before)<.999 or forward:Dot(after)<.999 then continue end
    for _,side in {-1,1}do
     local outward=Vector3.new(-forward.Z,0,forward.X)*side
     local center=p+outward*(width/2+25)
     local frame=CFrame.lookAt(center,center+forward)
     if Layout.footprintDistance(samples,frame,Standard.RailSize)>=width/2+16 then
      table.insert(candidates,{frame=frame,outward=outward})
     end
    end
   end
   local count=math.min(20,#candidates)
   for i=1,count do
    local site=candidates[math.floor((i-.5)*#candidates/count)+1]
    local rail=Instance.new('Part');rail.Name='ParkSizeAdRail'..i;rail.Size=Standard.RailSize
    rail.CFrame=site.frame+Vector3.yAxis*(groundY+2.25);rail.Color=if i%2==0 then Color3.fromRGB(180,65,65)else Color3.fromRGB(220,225,230)
    rail.Material=Enum.Material.SmoothPlastic;safe(rail);brandRail(rail,site.outward);rail.Parent=model;table.insert(rails,rail)
   end
  end
  model:SetAttribute('AdRailCount',#rails)
  -- Replace only the old block-tree pairs; retain all existing natural scenery.
  local anchors={};local cues=env and env:FindFirstChild('SpeedCues')
  if cues then for _,p in cues:GetChildren()do
   if p:IsA('BasePart')and p.Name:match('Trunk$')then
    local canopy=cues:FindFirstChild(p.Name:gsub('Trunk$','Canopy'))
    if canopy then hide(p);hide(canopy);table.insert(anchors,Vector3.new(p.Position.X,groundY,p.Position.Z))end
   end
  end end
  local prefab=RS:WaitForChild('KDMHubForestTreePrefabs'):WaitForChild('CityMaple')
  local lo,hi=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
  for _,p in prefab:GetDescendants()do if p:IsA('BasePart')then
   for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do
    local v=p.CFrame:PointToWorldSpace(p.Size*Vector3.new(x,y,z)/2)
    lo=Vector3.new(math.min(lo.X,v.X),math.min(lo.Y,v.Y),math.min(lo.Z,v.Z))
    hi=Vector3.new(math.max(hi.X,v.X),math.max(hi.Y,v.Y),math.max(hi.Z,v.Z))
   end end end
  end end
  local trunk=prefab.Trunk
  local base=Vector3.new((lo.X+hi.X)/2,trunk.CFrame:PointToWorldSpace(Vector3.new(0,-trunk.Size.Y/2,0)).Y+2,(lo.Z+hi.Z)/2)
  local radius=Vector2.new(hi.X-lo.X,hi.Z-lo.Z).Magnitude/2
  local trees=0
  for i,anchor in anchors do
   local nearest,distance
   for _,p in samples do local d=(p-anchor).Magnitude;if not distance or d<distance then nearest,distance=p,d end end
   local outward=(anchor-nearest).Unit;local scale=.65+(i%5)*.05
   local center=anchor
   for step=0,60 do
    center=anchor+outward*(step*12)
    if Layout.roadDistance(samples,center.X,center.Z)>=width/2+16+radius*scale then break end
   end
   local clone=prefab:Clone();local frame=CFrame.new(center-Vector3.yAxis*.2)*CFrame.Angles(0,i*2.399963,0)
   for _,p in clone:GetDescendants()do if p:IsA('BasePart')then
    local old=p.CFrame;p.Size*=scale;p.CFrame=frame*CFrame.new((old.Position-base)*scale)*old.Rotation;safe(p)
   end end
   clone.Name='ParkMapleReplacement'..i;clone:SetAttribute('PlantScale',scale);clone:SetAttribute('PlantYaw',i*2.399963)
   clone:SetAttribute('PlantCenter',center)
   clone:SetAttribute('CanopyShoulder',Layout.roadDistance(samples,center.X,center.Z)-radius*scale-width/2)
   clone.Parent=model;trees+=1
  end
  model:SetAttribute('ReplacedBlockTreeCount',trees)
  Landscape.build(model,track,samples,width,groundY,safe)
  -- The old Green horizon uses the owner's rejected round-crown species.
  -- Preview groves replace that layer; handle late horizon replication too.
  local function oldTree(p)
   if not p:IsA('BasePart')then return end
   local a=p.Parent
   while a and a~=track do if a.Name=='NaturalTrees'then hide(p);return end;a=a.Parent end
  end
  for _,p in track:GetDescendants()do oldTree(p)end
  treeListener=track.DescendantAdded:Connect(oldTree)
 end
 if alive then model:SetAttribute('RoadCount',roads);model:SetAttribute('KerbCount',kerbs);model:SetAttribute('Ready',true)end
 return model
end
function Controller.start()
 if stop then return end
 local active,watched;local links={};local trackLinks={};local pending=false;local closed=false;local schedule
 local function clear()local old=active;active=nil;if old then old:Destroy()end end
 local function update()
  if closed then return end
  local role=W:GetAttribute('KDMServerRole');local park=role=='HUB'
  local root=W:FindFirstChild(if park then 'KDMHub'else 'Prototype')
  local t=root and root:FindFirstChild(if park then 'HubParkRookieLoopG2'else 'TestTrack')
  if watched~=t then
   for _,c in trackLinks do c:Disconnect()end;table.clear(trackLinks);watched=t
   if t then for _,key in {'TrackId','GeometryId','RoadSegmentCount','KerbPartCount','SpeedCuePartCount','VisualRailPartCount','DriveIntegrated'}do table.insert(trackLinks,t:GetAttributeChangedSignal(key):Connect(function()schedule()end))end end
  end
  if not t or not Standard.eligible(role,t:GetAttribute('TrackId'),park and t:GetAttribute('DriveGeometry')=='ROOKIE_LOOP_V1')then clear();return end
  local function complete(folder,key)return folder and #folder:GetChildren()>=(t:GetAttribute(key)or math.huge)end
  local env=t:FindFirstChild('Environment')
  local ready=if park then t:GetAttribute('DriveIntegrated')==true else
   complete(t:FindFirstChild('Road'),'RoadSegmentCount')and complete(t:FindFirstChild('Kerbs'),'KerbPartCount')and
   env and complete(env:FindFirstChild('SpeedCues'),'SpeedCuePartCount')and complete(env:FindFirstChild('VisualRails'),'VisualRailPartCount')
  if ready and(not active or active.Parent~=t)then clear();active=Controller.build(t,park)end
 end
 schedule=function()if pending or closed then return end;pending=true;task.defer(function()pending=false;update()end)end
 table.insert(links,W:GetAttributeChangedSignal('KDMServerRole'):Connect(schedule))
 table.insert(links,W.DescendantAdded:Connect(function(o)
  local parent=o.Parent
  if o.Name=='TestTrack'or o.Name=='Road'or o.Name=='HubParkRookieLoopG2'or(watched and parent and
   (parent==watched:FindFirstChild('Road')or parent==watched:FindFirstChild('Kerbs')or parent.Name=='SpeedCues'or parent.Name=='VisualRails'))then schedule()end
 end))
 table.insert(links,W.DescendantRemoving:Connect(function(o)if active and(o==active or o==active.Parent)then clear();schedule()end end))
 stop=function()closed=true;clear();for _,c in links do c:Disconnect()end;for _,c in trackLinks do c:Disconnect()end;stop=nil end
 update()
end
function Controller.destroy()if stop then stop()end end
return Controller
