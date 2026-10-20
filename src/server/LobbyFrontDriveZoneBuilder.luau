local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Policy=require(Shared:WaitForChild("LobbyDrivePolicy"))
local Geometry=require(Shared:WaitForChild("LobbyDriveGeometry")).create(Policy)
local Builder={}
function Builder.build(hub,ground)
 local spawn=hub:FindFirstChild("HubSpawn")
 if not spawn or not ground then return nil end
 -- World +Z is the Lobby; the confirmed exit faces -Z. Never use rear Forecourt.
 local top=ground.Position.Y+ground.Size.Y/2
 -- Preserve the front edge facing the production track while widening toward the Lobby.
 local center=Vector3.new(spawn.Position.X+120,top,spawn.Position.Z-128+Policy.OuterRadius-84)
 local zone=Instance.new("Model");zone.Name="LobbyFrontTestDriveZone"
 zone:SetAttribute("ForwardMax",Policy.Forward);zone:SetAttribute("ReverseMax",Policy.Reverse)
 zone:SetAttribute("Center",center);zone:SetAttribute("OuterRadius",Policy.OuterRadius)
 zone:SetAttribute("FootprintVersion","REFERENCE_OVAL_V2")
 local function part(name,size,frame,color,collide)
  local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=frame
  p.Anchored=true;p.CanCollide=collide;p.CanTouch=false;p.CanQuery=collide
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.Color=color;p.Parent=zone;return p
 end
 local function frame(x,y,z) return CFrame.new(center+Vector3.new(x,y,z)) end
 local function strip(name,route,width,height,y,color,collide,open)
  for i,a in route do
   if open and i==#route then break end
   local b=route[i%#route+1]
   local first,last=center+Vector3.new(a.x,y,a.z),center+Vector3.new(b.x,y,b.z)
   local function section(f,t,extension)
    if (t-f).Magnitude<.01 then return end
    local p=part(name,Vector3.new(width,height,(t-f).Magnitude+extension),CFrame.lookAt((f+t)/2,t),color,collide)
    if name=="LobbyFrontBarrier" then p.CollisionGroup="LobbyBoundary";p.Transparency=1 end
   end
   -- End the island kerb at the 12-stud pedestrian entry.
   local gateLeft,gateRight=-126,-114
   if name=="LobbyFrontInnerKerb" and math.abs(a.z-b.z)<.001 and math.abs(a.z-(Geometry.island.minZ-Geometry.roadMargin))<.001
    and math.min(a.x,b.x)<gateRight and math.max(a.x,b.x)>gateLeft then
    local lo,hi=math.min(a.x,b.x),math.max(a.x,b.x)
    if lo<gateLeft then section(center+Vector3.new(lo,y,a.z),center+Vector3.new(gateLeft,y,a.z),0) end
    if hi>gateRight then section(center+Vector3.new(gateRight,y,a.z),center+Vector3.new(hi,y,a.z),0) end
   else section(first,last,.1) end
  end
 end
 -- Smooth continuous ring around the unchanged building island.
 local step=2
 local bounds=Geometry.bounds
 for z=bounds.minZ,bounds.maxZ-step,step do
  for _,span in Geometry.intervals(z+step/2,true) do
   local road=part("LobbyFrontFreeDriveRoad",Vector3.new(span[2]-span[1],.18,step+.02),frame((span[1]+span[2])/2,.09,z+step/2),Color3.fromRGB(62, 66, 73),false)
   road.Material=Enum.Material.Asphalt
  end
 end
 -- A single smooth collision plane avoids seam contacts from the decorative slices.
 local floor=part("LobbyFrontSmoothFloor",Vector3.new(bounds.maxX-bounds.minX,.5,bounds.maxZ-bounds.minZ),frame((bounds.minX+bounds.maxX)/2,-.07,(bounds.minZ+bounds.maxZ)/2),Color3.new(),true)
 floor.Transparency=1;floor.CustomPhysicalProperties=PhysicalProperties.new(1,.05,0,100,100)
 -- Cyan road edges; grass shoulders separate them from the restored guardrails.
 -- Both sides have 20 studs to the boundary (18.25 clear after kerb/wall widths).
 for _,loop in Geometry.roadLoops do
  strip("LobbyFrontInnerKerb",loop,1.5,.12,.23,Color3.fromRGB(111,211,245),false,false)
 end
 local railSerial=0
 for _,edge in Geometry.boundaries do
  -- Overlap adjacent collision sections, including curved seams. There is no
  -- kart gate: avatars pass through the LobbyBoundary collision group.
  local a,b=edge.a,edge.b
  local length=math.sqrt(edge.length2)
  local first=center+Vector3.new(a.x,7,a.z)
  local last=center+Vector3.new(b.x,7,b.z)
  local wall=part("LobbyFrontBarrier",Vector3.new(2,14,length+2),CFrame.lookAt((first+last)/2,last),Color3.new(),true)
  wall.CollisionGroup="LobbyBoundary";wall.Transparency=1
  local count=math.ceil(length/8)
  for i=1,count do
   railSerial+=1
   local from,to=(i-1)/count,i/count
   local x,z=a.x+edge.dx*(from+to)/2,a.z+edge.dz*(from+to)/2
   -- Keep the pedestrian bridge visually open; its kart wall stays continuous.
   if not (math.abs(a.z-Geometry.island.minZ)<.001 and math.abs(b.z-a.z)<.001 and x>-126 and x<-114) then
    local pos=center+Vector3.new(x,1.2,z)
    local rail=part("LobbyFrontGuardrail",Vector3.new(3,2.4,length/count+.12),CFrame.lookAt(pos,pos+Vector3.new(edge.dx,0,edge.dz)),
     if railSerial%2==0 then Color3.fromRGB(23,25,28) else Color3.fromRGB(246,194,36),false)
    rail.Material=Enum.Material.Plastic;rail.CollisionGroup="LobbyBoundary"
   end
  end
 end
 zone:SetAttribute("SafetyShoulder",Geometry.roadMargin)
 zone:SetAttribute("PermanentSkidMarkCount",0)
 -- Narrow shoulder/entry bridge; walkers pass the kart-only perimeter barrier.
 local railLine=center.Z+Geometry.island.minZ-Geometry.roadMargin
 local lobbyLine=spawn.Position.Z-19
 local entryLength=math.max(1,lobbyLine-railLine)
 local entry=part("LobbyFrontDriveEntry",Vector3.new(12,.18,entryLength),CFrame.new(spawn.Position.X,top+.09,(railLine+lobbyLine)/2),Color3.fromRGB(111,211,245),false)
 zone:SetAttribute("EntryRailLine",railLine);zone:SetAttribute("EntryLobbyLine",lobbyLine)
 local prompt=Instance.new("ProximityPrompt");prompt.ActionText="TEST DRIVE";prompt.ObjectText=""
 prompt.MaxActivationDistance=12;prompt.RequiresLineOfSight=false;prompt.Parent=entry
 -- Freestanding two-sided wayfinding beside the ramp, outside its 12-stud opening.
 local signFrame=CFrame.new(spawn.Position.X-11,top+4.9,lobbyLine-19)
 part("LobbyDriveSignFrame",Vector3.new(9.04,3.54,.18),signFrame,Color3.fromRGB(65,117,129),false)
 part("LobbyDriveSignPost",Vector3.new(.3,3.35,.3),
  CFrame.new(spawn.Position.X-11,top+1.675,lobbyLine-19),Color3.fromRGB(65,77,82),false)
 part("LobbyDriveSignBase",Vector3.new(1.6,.15,1),
  CFrame.new(spawn.Position.X-11,top+.075,lobbyLine-19),Color3.fromRGB(65,77,82),false)
 local discovery=part("LobbyDriveDiscovery",Vector3.new(8.8,3.3,.24),signFrame,Color3.fromRGB(16,25,35),false)
 discovery.Transparency=.08
 for _,face in {Enum.NormalId.Front,Enum.NormalId.Back} do
  local surface=Instance.new("SurfaceGui");surface.Name="DrivePresence"
  surface.Face=face;surface.CanvasSize=Vector2.new(640,240);surface.LightInfluence=0
  surface.AlwaysOnTop=false;surface.MaxDistance=100;surface.Parent=discovery
  local label=Instance.new("TextLabel");label.Name="DrivingCount"
  label.Size=UDim2.fromScale(.94,.48);label.Position=UDim2.fromScale(.03,.13)
  label.BackgroundTransparency=1;label.BorderSizePixel=0
  label.Text="LIVE TEST DRIVE"
  label.TextColor3=Color3.fromRGB(111,211,245);label.Font=Enum.Font.GothamBold
  label.TextSize=58;label.AutoLocalize=false;label.Parent=surface
  local hint=label:Clone();hint.Name="DriveHint";hint.Position=UDim2.fromScale(.03,.62)
  hint.Size=UDim2.fromScale(.94,.24);hint.TextSize=34;hint.Font=Enum.Font.GothamMedium
  hint.TextColor3=Color3.fromRGB(239,245,247);hint.Text="WATCH THE DEMO · TRY DRIVING";hint.Parent=surface
  local accent=Instance.new("Frame");accent.Name="CyanAccent";accent.BorderSizePixel=0
  accent.Size=UDim2.fromScale(.88,.018);accent.Position=UDim2.fromScale(.06,.06)
  accent.BackgroundColor3=Color3.fromRGB(111,211,245);accent.Parent=surface
 end
 local anchor=part("LobbyFrontDriveStart",Vector3.one,frame(-100,1.75,Policy.Radius)*CFrame.Angles(0,-math.pi/2,0),Color3.new(),false)
 anchor.Transparency=1
 -- Back-up protection of nearby plate edges affects Lobby karts only, not race vehicles/walkers.
 local half=ground.Size/2
 for _,d in {{Vector3.new(ground.Size.X,14,2),Vector3.new(0,7,half.Z-2)},
  {Vector3.new(ground.Size.X,14,2),Vector3.new(0,7,-half.Z+2)},
  {Vector3.new(2,14,ground.Size.Z),Vector3.new(half.X-2,7,0)},
  {Vector3.new(2,14,ground.Size.Z),Vector3.new(-half.X+2,7,0)}} do
  local p=part("LobbyFrontPlateBarrier",d[1],CFrame.new(ground.Position.X,top,ground.Position.Z)*CFrame.new(d[2]),Color3.new(),true)
  p.Transparency=1;p.CollisionGroup="LobbyBoundary"
 end
 zone.Parent=hub;return zone
end
return Builder
