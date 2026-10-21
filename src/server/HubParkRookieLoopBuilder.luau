-- Opt-in RookieLoop zone. The existing service owns manual boarding and simulation.
local Layout=require(game:GetService("ReplicatedStorage").Shared.HubParkRookieLoopLayout)
local Policy=require(game:GetService("ReplicatedStorage").Shared:WaitForChild("HubParkRuntimePolicy"))
local Builder={}
function Builder.enabled(workspace,isStudio)
 return Policy.enabled(workspace,isStudio,game.GameId,game.PlaceId)
end
function Builder.build(hub,ground)
 local workspace=hub.Parent
 if not Builder.enabled(workspace,game:GetService("RunService"):IsStudio()) then return nil end
 local existing=hub:FindFirstChild(Layout.PrototypeName);if existing then return existing end
 assert(not hub:FindFirstChild("LobbyFrontTestDriveZone"),"G2 preview requires a fresh HUB; do not toggle over a live drive zone")
 local spawn=assert(hub:FindFirstChild("HubSpawn"),"Missing HubSpawn")
 local origin=Vector3.new(spawn.Position.X,ground.Position.Y+ground.Size.Y/2,spawn.Position.Z)
 local root=Instance.new("Model");root.Name=Layout.PrototypeName
 root:SetAttribute("Stage",Layout.Stage);root:SetAttribute("DriveIntegrated",false)
 root:SetAttribute("CourseLengthStuds",Layout.measure().length)
 root:SetAttribute("NitroStraightStuds",Layout.NitroStraightLength)
 root:SetAttribute('DriveGeometry','ROOKIE_LOOP_V1');root:SetAttribute('Center',origin)
 root:SetAttribute("RoadWidth",Layout.RoadWidth);root:SetAttribute("Shoulder",Layout.Shoulder)
 root:SetAttribute("Origin",origin);root:SetAttribute("OneWay",true);root.Parent=hub
 local colors={road=Color3.fromRGB(65,69,76),kerbA=Color3.fromRGB(220,225,230),
  kerbB=Color3.fromRGB(180,65,65),shoulder=Color3.fromRGB(108,125,105),
  barrier=Color3.fromRGB(115,120,130),pit=Color3.fromRGB(75,110,125),plaza=Color3.fromRGB(160,165,170)}
 local function part(parent,name,size,frame,color,collide)
  local v=Instance.new("Part");v.Name=name;v.Size=size;v.CFrame=frame
  v.Anchored=true;v.CanCollide=collide;v.CanTouch=false;v.CanQuery=collide;v.CastShadow=false
  v.TopSurface=Enum.SurfaceType.Smooth;v.BottomSurface=Enum.SurfaceType.Smooth
  v.Material=Enum.Material.SmoothPlastic;v.Color=color;v.Parent=parent;return v
 end
 local function flat(parent,name,x,z,w,l,color,y,collide)
  return part(parent,name,Vector3.new(w,.2,l),CFrame.new(origin+Vector3.new(x,y or .12,z)),color,collide==true)
 end
 local function strip(parent,name,a,b,width,offset,color,height,collide)
  local x,z=(a.x+b.x)/2,(a.z+b.z)/2
  local dx,dz=b.x-a.x,b.z-a.z;local length=math.sqrt(dx*dx+dz*dz)
  if length<1e-6 then return end
  local sideX,sideZ=-dz/length,dx/length
  local pos=origin+Vector3.new(x+sideX*offset,height/2+.02,z+sideZ*offset)
  -- Two-stud overlap covers outer corners at the <=4-stud sample spacing.
  return part(parent,name,Vector3.new(width,height,length+2),CFrame.lookAt(pos,pos+Vector3.new(dx,0,dz)),color,collide)
 end
 local function label(parent,name,text,x,z,w,l,color)
  local v=flat(parent,name,x,z,w,l,color,.405,false)
  v.Size=Vector3.new(w,.01,l);v.Transparency=1 -- Text only, no raised slot/slab.
  local gui=Instance.new("SurfaceGui");gui.Face=Enum.NormalId.Top;gui.CanvasSize=Vector2.new(w*20,l*20)
  gui.LightInfluence=0;gui.Parent=v
  local textLabel=Instance.new("TextLabel");textLabel.Size=UDim2.fromScale(1,1)
  textLabel.BackgroundTransparency=1;textLabel.Text=text;textLabel.TextColor3=Color3.new(1,1,1)
  textLabel.TextScaled=true;textLabel.Font=Enum.Font.GothamBold;textLabel.AutoLocalize=false;textLabel.Parent=gui
  return v
 end
 local samples=Layout.sample(Layout.Segments)
 local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
 for _,a in samples do minX=math.min(minX,a.x);maxX=math.max(maxX,a.x);minZ=math.min(minZ,a.z);maxZ=math.max(maxZ,a.z) end
 local apron=Layout.RoadWidth/2+Layout.KerbWidth+Layout.Shoulder+18
 -- The loop may extend past the original plate. Keep a continuous physical fallback
 -- at the original ground's exact top. All road/pit slices are visual-only:
 -- no raised slice ends or different collision heights at merges/Baseplate edges.
 local floor=part(root,"G2SafetyGround",Vector3.new(maxX-minX+apron*2,1,maxZ-minZ+apron*2),
  CFrame.new(origin+Vector3.new((minX+maxX)/2,-.5,(minZ+maxZ)/2)),colors.shoulder,true)
 floor.Transparency=1 -- A coplanar collider must not compete with visible Baseplate.
 -- Render only the area outside Baseplate; disjoint rectangles have no Z-fighting.
 local left,right=origin.X+minX-apron,origin.X+maxX+apron
 local near,far=origin.Z+minZ-apron,origin.Z+maxZ+apron
 local gx0,gx1=ground.Position.X-ground.Size.X/2,ground.Position.X+ground.Size.X/2
 local gz0,gz1=ground.Position.Z-ground.Size.Z/2,ground.Position.Z+ground.Size.Z/2
 local function grass(x0,x1,z0,z1)
  if x1<=x0 or z1<=z0 then return end
  local p=part(root,'GroundVisual',Vector3.new(x1-x0,.1,z1-z0),CFrame.new((x0+x1)/2,origin.Y-.05,(z0+z1)/2),ground.Color,false)
  p.Material=ground.Material
 end
 grass(left,math.min(right,gx0),near,far);grass(math.max(left,gx1),right,near,far)
 local ix0,ix1=math.max(left,gx0),math.min(right,gx1)
 grass(ix0,ix1,near,math.min(far,gz0));grass(ix0,ix1,math.max(near,gz1),far)
 root:SetAttribute('CollisionContract','FLAT_SUPPORT_V1')
 root:SetAttribute("Segments",#samples-1)
 local batch
 for i=1,#samples-1 do
  if (i-1)%48==0 then batch=Instance.new("Folder");batch.Name="RoadBatch"..i end
  local a,b=samples[i],samples[i+1];local half=Layout.RoadWidth/2
  strip(batch,"Road",a,b,Layout.RoadWidth,0,colors.road,.35,false)
  for _,side in {-1,1} do
   -- In travel direction +X, +Z is the inner/pit-facing edge.
   if not (side==1 and Layout.pitOpening(a)) then
    local kerb=if i%2==0 then colors.kerbA else colors.kerbB
    strip(batch,"Kerb",a,b,Layout.KerbWidth,side*(half+1),kerb,.4,false)
    strip(batch,"Shoulder",a,b,Layout.Shoulder,side*(half+2+Layout.Shoulder/2),colors.shoulder,.18,false)
    strip(batch,"Barrier",a,b,1,side*(half+2+Layout.Shoulder+1),colors.barrier,2,true)
   end
  end
  if i%48==0 or i==#samples-1 then batch.Parent=root;if task then task.wait() end end
 end
 -- Pit is visual/collision geometry only. Its connectors are the only intended road junctions.
 local pit=Instance.new("Folder");pit.Name="Pit";pit.Parent=root
 local ps=Layout.sample(Layout.Pit.segments)
 for i=1,#ps-1 do strip(pit,"PitRoad",ps[i],ps[i+1],Layout.Pit.width,0,colors.pit,.36,false) end
 local q=Layout.Plaza;flat(root,"PedestrianPlaza",q.x,q.z,q.width,q.length,colors.plaza,.12,false)
 local w=Layout.Walkway;flat(root,"PedestrianLink12",w.x,w.z,w.width,w.length,colors.plaza,.12,false)
 for i,slot in Layout.Slots do
  -- Native painted ] bracket: closed end ahead (+X), open toward the kart.
  -- No text orientation, raised pad, touch/query or collision surface.
  local marker=Instance.new('Folder');marker.Name='SlotBracket'..i;marker.Parent=pit
  marker:SetAttribute("Active",true);marker:SetAttribute("Slot",i)
  local paint=Color3.fromRGB(235,246,250)
  part(marker,'Front',Vector3.new(.35,.02,10),CFrame.new(origin+Vector3.new(slot.x+7.5,.42,slot.z)),paint,false)
  for _,side in {-1,1}do
   part(marker,'Arm',Vector3.new(4,.02,.35),CFrame.new(origin+Vector3.new(slot.x+5.5,.42,slot.z+side*5)),paint,false)
  end
 end
 local starts=Instance.new('Folder');starts.Name='StartSlots';starts.Parent=root
 for i,slot in Layout.Slots do
  local pos=origin+Vector3.new(slot.x,1.75,slot.z)
  local a=part(starts,tostring(i),Vector3.one,CFrame.lookAt(pos,pos+Vector3.xAxis),colors.pit,false);a.Transparency=1
 end
 local first=starts:FindFirstChild('1'):Clone();first.Name='LobbyFrontDriveStart';first.Parent=root
 local entry=part(root,'LobbyFrontDriveEntry',Vector3.new(12,.1,18),CFrame.new(origin+Vector3.new(0,.05,-35)),colors.plaza,false);entry.Transparency=1
 local prompt=Instance.new('ProximityPrompt');prompt.ActionText='TEST DRIVE';prompt.ObjectText='ROOKIE LOOP';prompt.MaxActivationDistance=12;prompt.RequiresLineOfSight=false;prompt.Parent=entry
 label(root,"StartMark","ROOKIE LOOP",-35,Layout.StartStraightZ,75,8,colors.road)
 label(root,"PitEntryMark","PIT IN  →",-138,Layout.StartStraightZ+33,32,7,colors.pit)
 label(root,"PitExitMark","PIT OUT  →",142,Layout.StartStraightZ+33,32,7,colors.pit)
 -- Two lane-centered chevrons at each station, using the sampled forward tangent.
 for i=1,#samples-1,26 do
  local a=samples[i]
  for _,lane in {-Layout.RoadWidth/4,Layout.RoadWidth/4} do
   local v=Vector3.new(a.x-a.fz*lane,.5,a.z+a.fx*lane)+origin
   local f=Vector3.new(a.fx,0,a.fz);local right=Vector3.new(-a.fz,0,a.fx)
   for _,side in {-1,1} do
    local tail=v-f*2+right*side*1.6
    local delta=v-tail
    part(root,"ForwardChevron",Vector3.new(.4,.12,delta.Magnitude),CFrame.lookAt((tail+v)/2,v),Color3.fromRGB(240,220,90),false)
   end
  end
 end
 root:SetAttribute('DriveIntegrated',true)
 return root
end
return Builder
