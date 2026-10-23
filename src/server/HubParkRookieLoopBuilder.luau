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
  barrier=Color3.fromRGB(115,120,130),pit=Color3.fromRGB(65,69,76),plaza=Color3.fromRGB(160,165,170)}
 local function part(parent,name,size,frame,color,collide)
  local v=Instance.new("Part");v.Name=name;v.Size=size;v.CFrame=frame
  v.Anchored=true;v.CanCollide=collide;v.CanTouch=false;v.CanQuery=collide;v.CastShadow=false
  v.TopSurface=Enum.SurfaceType.Smooth;v.BottomSurface=Enum.SurfaceType.Smooth
  v.Material=Enum.Material.SmoothPlastic;v.Color=color;v.Parent=parent;return v
 end
 local function flat(parent,name,x,z,w,l,color,y,collide)
  local _,ny,nz=Layout.normal(x,z)
  return part(parent,name,Vector3.new(w,.2,l),CFrame.new(origin+Vector3.new(x,Layout.height(x,z)+(y or -.08),z))*CFrame.Angles(math.atan2(nz,ny),0,0),color,collide==true)
 end
 local function strip(parent,name,a,b,width,offset,color,height,collide,topOffset)
  local x,z=(a.x+b.x)/2,(a.z+b.z)/2
  local dx,dz=b.x-a.x,b.z-a.z;local length=math.sqrt(dx*dx+dz*dz)
  if length<1e-6 then return end
  local sideX,sideZ=-dz/length,dx/length
  x+=sideX*offset;z+=sideZ*offset
  local yBase = if topOffset then topOffset - height/2 elseif collide then height/2+.02 elseif name=="Shoulder" then -height/2 else .02-height/2
  local pos=origin+Vector3.new(x,Layout.height(x,z)+yBase,z)
  local _,ny,nz=Layout.normal(x,z)
  -- Visual overlap only; the single flat support owns wheel contact.
  -- Asphalt top is +.02, not +.37 above the physical ground datum.
  return part(parent,name,Vector3.new(width,height,length+2),CFrame.lookAt(pos,pos+Vector3.new(dx,0,dz),Vector3.new(0,ny,nz)),color,collide)
 end
 local function label(parent,name,text,x,z,w,l,color)
  local v=flat(parent,name,x,z,w,l,color,.055,false)
  v.Size=Vector3.new(w,.01,l);v.Transparency=1 -- Text only, no raised slot/slab.
  local gui=Instance.new("SurfaceGui");gui.Face=Enum.NormalId.Top;gui.CanvasSize=Vector2.new(w*20,l*20)
  gui.LightInfluence=0;gui.Parent=v
  local textLabel=Instance.new("TextLabel");textLabel.Size=UDim2.fromScale(1,1)
  textLabel.BackgroundTransparency=1;textLabel.Text=text;textLabel.TextColor3=Color3.new(1,1,1)
  textLabel.TextScaled=true;textLabel.Font=Enum.Font.GothamBold;textLabel.AutoLocalize=false;textLabel.Parent=gui
  return v
 end
 local function triangle(parent,name,color,a,b,c)
  local ab,ac,bc=b-a,c-a,c-b
  if ab:Dot(ab)>ac:Dot(ac) and ab:Dot(ab)>bc:Dot(bc) then c,a=a,c
  elseif ac:Dot(ac)>bc:Dot(bc) then a,b=b,a end
  ab,ac,bc=b-a,c-a,c-b
  if ac:Cross(ab).Magnitude<.00001 then return end
  local right=ac:Cross(ab).Unit;local back=bc.Unit;local up=back:Cross(right)
  local h=math.abs(ab:Dot(up))
  for _,s in {{a,b,right,back},{a,c,-right,-back}}do
   local length=math.abs((s[2]-s[1]):Dot(back))
   if length<.00001 then continue end
   local v=Instance.new('WedgePart');v.Name=name
   v.Size=Vector3.new(.01,h,length);v.CFrame=CFrame.fromMatrix((s[1]+s[2])/2,s[3],up,s[4])
   v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false;v.CastShadow=false
   v.Material=Enum.Material.SmoothPlastic;v.Color=color;v.Parent=parent
  end
 end
 local function clipToPit(poly)
  local edge=Layout.StartStraightZ+Layout.RoadWidth/2+Layout.KerbWidth+.5+.001
  local out={}
  for i,p in poly do local q=poly[i%#poly+1]
   local pin,qin=p.z>=edge,q.z>=edge
   if pin then table.insert(out,p)end
   if pin~=qin then local t=(edge-p.z)/(q.z-p.z)
    table.insert(out,{x=p.x+(q.x-p.x)*t,z=edge})end
  end
  return out
 end
 local function patch(parent,name,color,poly,top)
  local function v(p)return origin+Vector3.new(p.x,top-.005,p.z)end
  for j=2,#poly-1 do triangle(parent,name,color,v(poly[1]),v(poly[j]),v(poly[j+1]))end
 end
 -- Equal arc-length colour runs, with shared polygon edges instead of
 -- overlapping red/white rectangles. Both colours have the same top plane.
 local function kerbRibbon(points,offset,route,omit)
  local edge,total={},0
  for i,p in points do
   local v={x=p.x-p.fz*offset,z=p.z+p.fx*offset,fx=p.fx,fz=p.fz,section=p.section}
   if i>1 then local a=edge[i-1];total+=math.sqrt((v.x-a.x)^2+(v.z-a.z)^2)end
   v.distance=total;table.insert(edge,v)
  end
  local runs=math.max(2,math.ceil(total/8/2)*2);local step=total/runs
  local cursor=1
  local function station(d)
   while cursor<#edge-1 and edge[cursor+1].distance<d do cursor+=1 end
   local a,b=edge[cursor],edge[cursor+1]
   local t=math.clamp((d-a.distance)/(b.distance-a.distance),0,1)
   local fx,fz=a.fx+(b.fx-a.fx)*t,a.fz+(b.fz-a.fz)*t
   local l=math.sqrt(fx*fx+fz*fz);fx/=l;fz/=l
   local x,z=a.x+(b.x-a.x)*t,a.z+(b.z-a.z)*t
   return {x=x,z=z,section=a.section,
    inner={x=x+fz*Layout.KerbWidth/2,z=z-fx*Layout.KerbWidth/2},
    outer={x=x-fz*Layout.KerbWidth/2,z=z+fx*Layout.KerbWidth/2}}
  end
  local a=station(0);local folder
  for i=1,runs do
   if (i-1)%32==0 then folder=Instance.new('Folder');folder.Name='KerbBatch' end
   local b=station(i*step)
   if not (omit and omit(a,b))then
    local poly={a.inner,b.inner,b.outer,a.outer}
    if route=='PIT' then poly=clipToPit(poly)end
    if #poly>=3 then
     local run=Instance.new('Folder');run.Name='KerbRun';run:SetAttribute('Route',route)
     run:SetAttribute('ArcLength',step);run:SetAttribute('ColorIndex',i%2);run.Parent=folder
     patch(run,'Kerb',if i%2==0 then colors.kerbA else colors.kerbB,poly,.07)
    end
   end
   a=b
   if i%32==0 or i==runs then folder.Parent=root;if task then task.wait()end end
  end
 end
 local samples=Layout.sample(Layout.Segments)
 require(script.Parent:WaitForChild('HubParkIslandBuilder')).build(root,ground,origin,Layout,game:GetService('Lighting'))
 root:SetAttribute("Segments",#samples-1)
 local batch
 for i=1,#samples-1 do
  if (i-1)%48==0 then batch=Instance.new("Folder");batch.Name="RoadBatch"..i end
  local a,b=samples[i],samples[i+1];local half=Layout.RoadWidth/2
  -- Asphalt continues underneath the kerb to the guard's inner face, so
  -- even the half-stud construction clearance cannot expose green grass.
  strip(batch,"Road",a,b,Layout.RoadWidth+2*Layout.KerbWidth+1,0,colors.road,.35,false)
  for _,side in {-1,1} do
   -- Solid continuous white edge lines (thick 1.2 stud line, with 1.2 stud road margin before kerb, raised to .045 to eliminate Z-fighting)
   if not (side==1 and (Layout.pitOpening(a) or Layout.pitOpening(b))) then
    local lineOffset = side * (half - 1.8)
    strip(batch,"EdgeLine",a,b,1.2,lineOffset,Color3.fromRGB(245,248,252),.04,false,.045)
   end
  end
  if i%48==0 or i==#samples-1 then batch.Parent=root;if task then task.wait() end end
 end
 for _,side in {-1,1}do
  kerbRibbon(samples,side*(Layout.RoadWidth/2+Layout.KerbWidth/2),'MAIN',
   if side==1 then function(a,b)return Layout.pitOpening(a)or Layout.pitOpening(b)end else nil)
 end
 -- Pit is visual/collision geometry only. Its connectors are the only intended road junctions.
 local pit=Instance.new("Folder");pit.Name="Pit";pit.Parent=root
 local ps=Layout.sample(Layout.Pit.segments)
 -- Clip pit visuals to the straight's pit-facing edge. Both surfaces keep
 -- the same .02 top and asphalt colour, with no duplicate main-road polygons.
 local pitBoundary=Layout.StartStraightZ+Layout.RoadWidth/2+Layout.KerbWidth+.5+.001
 for i=1,#ps-1 do
  local a,b=ps[i],ps[i+1];local dx,dz=b.x-a.x,b.z-a.z
  local length=math.sqrt(dx*dx+dz*dz);local fx,fz=dx/length,dz/length
  local half=Layout.Pit.width/2
  local poly={}
  for _,s in {{-1,-1},{1,-1},{1,1},{-1,1}}do
   table.insert(poly,{x=(a.x+b.x)/2+fx*s[1]*(length/2+1)-fz*s[2]*half,
    z=(a.z+b.z)/2+fz*s[1]*(length/2+1)+fx*s[2]*half})
  end
  local clipped={};local allOutside=true
  for j,p in poly do
   local q=poly[j%#poly+1];local pin,qin=p.z>=pitBoundary,q.z>=pitBoundary
   if not pin then allOutside=false end
   if pin then table.insert(clipped,p)end
   if pin~=qin then local t=(pitBoundary-p.z)/(q.z-p.z)
    table.insert(clipped,{x=p.x+(q.x-p.x)*t,z=pitBoundary})end
  end
  if allOutside then strip(pit,"PitRoad",a,b,Layout.Pit.width,0,colors.pit,.36,false)
  elseif #clipped>=3 then
   local function vertex(p)return origin+Vector3.new(p.x,.015,p.z)end
   for j=2,#clipped-1 do triangle(pit,"PitRoad",colors.pit,vertex(clipped[1]),vertex(clipped[j]),vertex(clipped[j+1]))end
  end
 end
 -- The main-road kerb is the shared road-facing pit border. Only its
 -- lobby-facing edge needs another ribbon; never double-paint that shared edge.
 kerbRibbon(ps,Layout.Pit.width/2-Layout.KerbWidth/2,'PIT')
 local q=Layout.Plaza;flat(root,"PedestrianPlaza",q.x,q.z,q.width,q.length,colors.plaza,.12,false)
 local w=Layout.Walkway;flat(root,"PedestrianLink12",w.x,w.z,w.width,w.length,colors.plaza,.12,false)
 for i,slot in Layout.PitSlots do
  -- Native painted ] bracket: closed end ahead (+X), open toward the kart.
  -- No text orientation, raised pad, touch/query or collision surface.
  local marker=Instance.new('Folder');marker.Name='SlotBracket'..i;marker.Parent=pit
  marker:SetAttribute("Active",true);marker:SetAttribute("Slot",i)
  local paint=Color3.fromRGB(235,246,250)
  local _,ny,nz=Layout.normal(slot.x,slot.z)
  local function paintFrame(x,z)return CFrame.new(origin+Vector3.new(x,Layout.height(x,z)+.07,z))*CFrame.Angles(math.atan2(nz,ny),0,0)end
  part(marker,'Front',Vector3.new(.35,.02,10),paintFrame(slot.x+7.5,slot.z),paint,false)
  for _,side in {-1,1}do
   part(marker,'Arm',Vector3.new(4,.02,.35),paintFrame(slot.x+5.5,slot.z+side*5),paint,false)
  end
 end
 local grid=Instance.new('Folder');grid.Name='SoloStartGrid';grid.Parent=root
 for i,slot in Layout.Slots do
  local marker=Instance.new('Folder');marker.Name='Grid'..i;marker.Parent=grid
  local paint=Color3.fromRGB(238,246,250)
  flat(marker,'Front',slot.x+7.5,slot.z,.35,10,paint,.07,false)
  for _,side in {-1,1}do flat(marker,'Arm',slot.x+5.5,slot.z+side*5,4,.35,paint,.07,false)end
 end
 for lane=0,15 do
  flat(grid,'StartFinish',Layout.TrialFinishX,Layout.StartStraightZ-30+lane*4,2,4,
   if lane%2==0 then Color3.new(1,1,1)else Color3.fromRGB(35,45,55),.07,false)
 end
 local starts=Instance.new('Folder');starts.Name='StartSlots';starts.Parent=root
 for i,slot in Layout.Slots do
  local pos=origin+Vector3.new(slot.x,Layout.height(slot.x,slot.z)+1.75,slot.z)
  local _,ny,nz=Layout.normal(slot.x,slot.z)
  local a=part(starts,tostring(i),Vector3.one,CFrame.lookAt(pos,pos+Vector3.xAxis,Vector3.new(0,ny,nz)),colors.pit,false);a.Transparency=1
 end
 local first=starts:FindFirstChild('1'):Clone();first.Name='LobbyFrontDriveStart';first.Parent=root
 local entry=part(root,'LobbyFrontDriveEntry',Vector3.new(12,.1,18),CFrame.new(origin+Vector3.new(0,.05,-35)),colors.plaza,false);entry.Transparency=1
 local prompt=Instance.new('ProximityPrompt');prompt.ActionText='TEST DRIVE';prompt.ObjectText='ROOKIE LOOP';prompt.MaxActivationDistance=12;prompt.RequiresLineOfSight=false;prompt.Parent=entry
 local Trial=require(game:GetService('ReplicatedStorage').Shared.RookieParkTrial)
 local checkpoints=Instance.new('Folder');checkpoints.Name='TrialCheckpoints';checkpoints.Parent=root
 for i,g in Trial.Gates do
  local pos=origin+Vector3.new(g.x,8,g.z)
  local gate=part(checkpoints,'Checkpoint'..i,Vector3.new(Layout.RoadWidth+20,20,20),CFrame.lookAt(pos,pos+Vector3.new(g.fx,0,g.fz)),colors.plaza,false)
  gate.Transparency=1;gate:SetAttribute('RaceGate',true);gate:SetAttribute('GateType','Checkpoint');gate:SetAttribute('CheckpointIndex',i)
 end
 local finish=Trial.Finish;local pos=origin+Vector3.new(finish.x,8,finish.z)
 local gate=part(checkpoints,'StartFinish',Vector3.new(Layout.RoadWidth+20,20,20),CFrame.lookAt(pos,pos+Vector3.xAxis),colors.plaza,false)
 gate.Transparency=1;gate:SetAttribute('RaceGate',true);gate:SetAttribute('GateType','StartFinish')
 root:SetAttribute('DriveIntegrated',true)
 return root
end
return Builder
