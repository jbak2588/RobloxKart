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
   local road=part("LobbyFrontFreeDriveRoad",Vector3.new(span[2]-span[1],.18,step+.02),frame((span[1]+span[2])/2,.09,z+step/2),Color3.fromRGB(38,43,49),false)
   road.Material=Enum.Material.Asphalt
  end
 end
 -- A single smooth collision plane avoids seam contacts from the decorative slices.
 local floor=part("LobbyFrontSmoothFloor",Vector3.new(bounds.maxX-bounds.minX,.5,bounds.maxZ-bounds.minZ),frame((bounds.minX+bounds.maxX)/2,-.07,(bounds.minZ+bounds.maxZ)/2),Color3.new(),true)
 floor.Transparency=1;floor.CustomPhysicalProperties=PhysicalProperties.new(1,.05,0,100,100)
 -- Cyan road edges; grass shoulders separate them from invisible kart-only walls.
 -- Both sides have 20 studs to the boundary (18.25 clear after kerb/wall widths).
 for _,loop in Geometry.roadLoops do
  strip("LobbyFrontInnerKerb",loop,1.5,.12,.23,Color3.fromRGB(111,211,245),false,false)
 end
 for _,edge in Geometry.boundaries do
  strip("LobbyFrontBarrier",{edge.a,edge.b},2,14,7,Color3.fromRGB(139,178,194),true,true)
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
