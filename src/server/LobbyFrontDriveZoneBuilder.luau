local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Policy=require(Shared:WaitForChild("LobbyDrivePolicy"))
local Geometry=require(Shared:WaitForChild("LobbyDriveGeometry")).create(Policy)
local SkidPattern=require(Shared:WaitForChild("LobbySkidPattern"))
local Builder={}
function Builder.build(hub,ground)
 local spawn=hub:FindFirstChild("HubSpawn")
 if not spawn or not ground then return nil end
 -- World +Z is the Lobby; the confirmed exit faces -Z. Never use rear Forecourt.
 local top=ground.Position.Y+ground.Size.Y/2
 -- Preserve the front edge facing the production track while widening toward the Lobby.
 local center=Vector3.new(spawn.Position.X+120,top,spawn.Position.Z-128+Policy.OuterRadius-84)
 local zone=Instance.new("Model");zone.Name="LobbyFrontTestDriveZone"
 zone:SetAttribute("ForwardMax",70);zone:SetAttribute("ReverseMax",Policy.Reverse)
 zone:SetAttribute("Center",center);zone:SetAttribute("OuterRadius",Policy.OuterRadius)
 zone:SetAttribute("FootprintVersion","SIDE_WINGS_V1")
 local function part(name,size,frame,color,collide)
  local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=frame
  p.Anchored=true;p.CanCollide=collide;p.CanTouch=false;p.CanQuery=collide
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.Color=color;p.Parent=zone;return p
 end
 local function frame(x,y,z) return CFrame.new(center+Vector3.new(x,y,z)) end
 local blockIndex=0
 local function strip(name,route,width,height,y,color,collide)
  for i,a in route do
   local b=route[i%#route+1]
   local first,last=center+Vector3.new(a.x,y,a.z),center+Vector3.new(b.x,y,b.z)
   local length=(last-first).Magnitude
   local function section(f,t,extension)
    if (t-f).Magnitude<.01 then return end
    local steps=if name=="LobbyFrontGuardrail" or name=="LobbyFrontInnerKerb" then math.max(1,math.ceil((t-f).Magnitude/8)) else 1
    for j=1,steps do
     local start,finish=f:Lerp(t,(j-1)/steps),f:Lerp(t,j/steps)
     local sectionColor=color
     if name=="LobbyFrontGuardrail" then
      blockIndex+=1;sectionColor=if blockIndex%2==0 then Color3.fromRGB(246,194,36) else Color3.fromRGB(23,25,28)
     elseif name=="LobbyFrontInnerKerb" then sectionColor=if (i+j)%2==0 then Color3.fromRGB(20,22,25) else Color3.fromRGB(240,246,250) end
     local extra=if name=="LobbyFrontGuardrail" then -.12 else extension
     local p=part(name,Vector3.new(width,height,(finish-start).Magnitude+extra),CFrame.lookAt((start+finish)/2,finish),sectionColor,collide)
     if name=="LobbyFrontGuardrail" or name=="LobbyFrontBarrier" then p.CollisionGroup="LobbyBoundary" end
     if name=="LobbyFrontGuardrail" then p.Material=Enum.Material.Plastic end
     if name=="LobbyFrontBarrier" then p.Transparency=1 end
    end
   end
   -- End visible rails and kerbs at the exact edges of the 12-stud Lobby entry.
   local gateLeft,gateRight=-126,-114
   if (name=="LobbyFrontGuardrail" or name=="LobbyFrontInnerKerb") and math.abs(a.z-b.z)<.001 and a.z>0
    and math.min(a.x,b.x)<gateRight and math.max(a.x,b.x)>gateLeft then
    local lo,hi=math.min(a.x,b.x),math.max(a.x,b.x)
    if lo<gateLeft then section(center+Vector3.new(lo,y,a.z),center+Vector3.new(gateLeft,y,a.z),0) end
    if hi>gateRight then section(center+Vector3.new(gateRight,y,a.z),center+Vector3.new(hi,y,a.z),0) end
   else section(first,last,1.5) end
  end
 end
 -- Same front apron; scanline spans also pave both wings without covering the Lobby recess.
 local step=2
 local bounds=Geometry.bounds
 for z=bounds.minZ,bounds.maxZ-step,step do
  for _,span in Geometry.intervals(z+step/2) do
   local road=part("LobbyFrontFreeDriveRoad",Vector3.new(span[2]-span[1],.18,step+.02),frame((span[1]+span[2])/2,.09,z+step/2),Color3.fromRGB(54,64,72),false)
   road.Material=Enum.Material.Asphalt
  end
 end
 -- A single smooth collision plane avoids seam contacts from the decorative slices.
 local floor=part("LobbyFrontSmoothFloor",Vector3.new(bounds.maxX-bounds.minX,.5,bounds.maxZ-bounds.minZ),frame((bounds.minX+bounds.maxX)/2,-.07,(bounds.minZ+bounds.maxZ)/2),Color3.new(),true)
 floor.Transparency=1;floor.CustomPhysicalProperties=PhysicalProperties.new(1,.05,0,100,100)
 local kerbs={}
 for _,p in Geometry.points do
  local _,nx,nz=Geometry.contact(p.x,p.z)
  table.insert(kerbs,{x=p.x-nx*2,z=p.z-nz*2})
 end
 strip("LobbyFrontInnerKerb",kerbs,2,.08,.22,Color3.fromRGB(230,240,244),false)
 strip("LobbyFrontGuardrail",Geometry.points,3,2.4,1.2,Color3.fromRGB(246,194,36),true)
 strip("LobbyFrontBarrier",Geometry.points,2,14,7,Color3.fromRGB(139,178,194),true)
 -- Static paired tire tracks sit above the asphalt, below live Drift marks.
 local marks=Instance.new("Folder");marks.Name="LobbyPermanentSkidMarks";marks.Parent=zone
 local count=0
 for _,path in SkidPattern.paths() do
  for i=1,#path.points-1 do
   local a,b=path.points[i],path.points[i+1]
   local dx,dz=b.x-a.x,b.z-a.z;local length=math.sqrt(dx*dx+dz*dz)
   if length<.1 then continue end
   for _,offset in {-2.1,2.1} do
    local ax,az=SkidPattern.tirePoint(path,i,offset)
    local bx,bz=SkidPattern.tirePoint(path,i+1,offset)
    -- Clip the entire segment, including concave building corners.
    local clear=true
    for k=0,4 do if not Geometry.inside(ax+(bx-ax)*k/4,az+(bz-az)*k/4,12) then clear=false;break end end
    if clear and count<640 then
     local first,last=center+Vector3.new(ax,.196,az),center+Vector3.new(bx,.196,bz)
     local mark=part("LobbyPermanentSkidMark",Vector3.new(path.width,.012,(last-first).Magnitude+.18),CFrame.lookAt((first+last)/2,last),Color3.fromRGB(12,14,16),false)
     mark.Transparency=1-path.opacity;mark:SetAttribute("Pattern",path.kind);mark.Parent=marks;count+=1
    end
   end
  end
 end
 zone:SetAttribute("PermanentSkidMarkCount",count)
 -- Narrow shoulder/entry bridge; walkers pass the kart-only perimeter barrier.
 local railLine=center.Z+Policy.OuterRadius
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
