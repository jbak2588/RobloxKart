-- Source-only desert scenery. Never writes a road, trigger, seat or kart.
local RS=game:GetService('ReplicatedStorage')
local W=game:GetService('Workspace')
local Lighting=game:GetService('Lighting')
local Geometry=require(RS.Shared.TrackGeometry)
local Environment={}
-- Softer mobile daylight; tint the sand instead of washing out the whole HUD.
local sandTint=Color3.fromRGB(224,218,205)
Environment.SourceScale=1
function Environment.straightRoadLength(samples,index)
 local a,b=samples[index],samples[index%#samples+1]
 local before=samples[(index-2)%#samples+1];local after=samples[(index+1)%#samples+1]
 local direction=(b-a).Unit
 if direction:Dot((a-before).Unit)>.999999 and direction:Dot((after-b).Unit)>.999999 then
  return (b-a).Magnitude
 end
 return nil
end
Environment.ClearBounds={MinX=-400,MaxX=400,MinZ=-440,MaxZ=608}
Environment.Dune={X=0,Z=338,RadiusX=84,RadiusZ=64}
Environment.Cliffs={
 {X=-230,Z=-25,RadiusX=60,RadiusZ=90,Height=110,Scale=.65,Angle=0},
 {X=230,Z=-25,RadiusX=60,RadiusZ=90,Height=110,Scale=.65,Angle=math.pi},
 {X=0,Z=190,RadiusX=45,RadiusZ=65,Height=60,Scale=.35,Angle=.35},
}
function Environment.cliffHeight(source,cliff,x,z)
 local nx,nz=(x-cliff.X)/cliff.RadiusX,(z-cliff.Z)/cliff.RadiusZ
 local r=nx*nx+nz*nz;if r>=1 then return 0 end
 local c,s=math.cos(cliff.Angle),math.sin(cliff.Angle)
 -- Original mesa face around source column (512,48), not a scaled boulder.
 local ix=512+math.floor((nx*c-nz*s)*24)
 local iz=48+math.floor((nx*s+nz*c)*24)
 local row=source.Rows[ix];local offset=(iz-1)*4
 local h=math.max(0,tonumber(row:sub(offset+1,offset+3),16)/4-8)
 return math.min(cliff.Height,h*cliff.Scale)*math.clamp((1-r)/.25,0,1)
end
function Environment.selectChevrons(parts)
 local keep={};local selected={}
 for _,arc in Geometry.getDefinition('PracticeFigure8V1').Segments do
  if arc[1]=='Arc'then for _,fraction in {.25,.5,.75}do
   local angle=arc[5]+arc[6]*fraction
   local target=Vector3.new(arc[2]+math.cos(angle)*arc[4],0,arc[3]+math.sin(angle)*arc[4])
   local best,distance=nil,math.huge
   for _,p in parts do if not keep[p]then
    local point=Vector3.new(p.Position.X,0,p.Position.Z);local d=(point-target).Magnitude
    local clear=true;for _,q in selected do if (point-q).Magnitude<20 then clear=false;break end end
    if clear and d<distance then best,distance=p,d end
   end end
   if best and distance<85 then keep[best]=true;table.insert(selected,Vector3.new(best.Position.X,0,best.Position.Z))end
  end end
 end
 return keep
end
function Environment.duneHeight(source,x,z)
 local d=Environment.Dune;local nx,nz=(x-d.X)/d.RadiusX,(z-d.Z)/d.RadiusZ
 local r=nx*nx+nz*nz;if r>=1 then return 0 end
 -- Reuse a low dune patch from the original sampled relief, tapering its edge
 -- into this island. No road/recovery point receives raised terrain.
 local row=source.Rows[336+math.floor(nx*12)]
 local offset=(372+math.floor(nz*12)-1)*4
 local h=tonumber(row:sub(offset+1,offset+3),16)/4-8
 return (12+math.max(0,h)*.65)*(1-r)^1.1
end
function Environment.protected(x,z)
 local b=Environment.ClearBounds
 return x>b.MinX and x<b.MaxX and z>b.MinZ and z<b.MaxZ
end
function Environment.roadDistance(samples,x,z)
 local best=math.huge
 for i,a in samples do
  local b=samples[i%#samples+1];local ax,az=a.X,a.Z
  local dx,dz=b.X-ax,b.Z-az
  local q=math.clamp(((x-ax)*dx+(z-az)*dz)/math.max(.001,dx*dx+dz*dz),0,1)
  best=math.min(best,math.sqrt((x-ax-q*dx)^2+(z-az-q*dz)^2))
 end
 return best
end
function Environment.build(track)
 local resources=RS:WaitForChild('KDMDesertResources')
 local source=require(RS:WaitForChild('KDMDesertSource'):WaitForChild('TerrainSurface'))
 local model=Instance.new('Model');model.Name='ClientHorizonEnvironment'
 model:SetAttribute('Theme','SOURCE_DESERT');model:SetAttribute('Source','Hub_n_lobby_original.rbxlx')
 local ground=track:FindFirstChild('SafetyGround');local groundY=if ground then ground.Position.Y+ground.Size.Y/2 else 0
 local samples=Geometry.getCourse(Geometry.getDefinition('PracticeFigure8V1')).Samples
 local saved={};local kerbFrames={};local roadColors={};local railState={};local tiles={};local alive=true
 -- Separate overlapping kerb stripes from each other and the white road edge.
 local kerbs=track:FindFirstChild('Kerbs')
 if kerbs then for _,p in kerbs:GetChildren()do if p:IsA('BasePart')then
  kerbFrames[p]=p.CFrame
  p.CFrame+=Vector3.yAxis*(if p.Color.R>p.Color.G*1.5 then .06 else .04)
 end end end
 local function softenRoad(p)
  if p:IsA('BasePart')then
   roadColors[p]={p.Color,p.MaterialVariant,p.Size}
   p.Color=Color3.fromRGB(226,220,188);p.MaterialVariant='KDMDesert_Racing_Asphalt_A'
   local index=tonumber(p.Name:match('^Road(%d+)$'))
   local length=index and Environment.straightRoadLength(samples,index)
   if length and not p.CanCollide then p.Size=Vector3.new(p.Size.X,p.Size.Y,length)end
  end
 end
 local roads=track:FindFirstChild('Road')
 if roads then for _,p in roads:GetChildren()do softenRoad(p)end end
 local roadEnv=track:FindFirstChild('Environment')
 if roadEnv then for _,p in roadEnv:GetChildren()do if p.Name:match('^CrossoverRibbon')then softenRoad(p)end end end
 local function appearance(part)
  table.insert(saved,{part=part,material=part.Material,variant=part.MaterialVariant,color=part.Color,localTransparency=part.LocalTransparencyModifier})
  part.Material=Enum.Material.Sand;part.MaterialVariant='KDMDesert_Racing_Sand_A';part.Color=sandTint
 end
 local materialService=game:GetService('MaterialService');local materialCopies={};local overrides={}
 for _,v in resources.Materials:GetChildren()do
  local c=v:Clone();c.Name='KDMDesert_'..v.Name
  -- Texture-map properties require Plugin capability. Source normal/color maps
  -- and the baked matte profile are only cloned by ordinary LocalScripts.
  c.Parent=materialService;table.insert(materialCopies,c)
  local base=c.BaseMaterial
  if overrides[base]==nil then overrides[base]=materialService:GetBaseMaterialOverride(base)end
  materialService:SetBaseMaterialOverride(base,c.Name)
 end
 local terrain=W.Terrain;local colors={}
 for _,n in {'Sand','Sandstone','Ground'}do colors[n]=terrain:GetMaterialColor(Enum.Material[n]);terrain:SetMaterialColor(Enum.Material[n],sandTint)end
 colors.Slate=terrain:GetMaterialColor(Enum.Material.Slate);terrain:SetMaterialColor(Enum.Material.Slate,Color3.fromRGB(204,190,140))
 colors.Grass=terrain:GetMaterialColor(Enum.Material.Grass);terrain:SetMaterialColor(Enum.Material.Grass,Color3.fromRGB(204,190,140))
 local env=track:FindFirstChild('Environment');local infield=env and env:FindFirstChild('Infield')
 if infield then appearance(infield);infield.LocalTransparencyModifier=1 end
 if ground then appearance(ground);ground.LocalTransparencyModifier=1 end
 local base=W:FindFirstChild('Baseplate');if base then appearance(base)end
 for _,x in {-704,704}do for _,z in {-624,784}do
  local floor=Instance.new('Part');floor.Name='SourceSandGround';floor.Size=Vector3.new(1408,.02,1408)
  floor.CFrame=CFrame.new(x,groundY+.025,z);floor.Material=Enum.Material.Sand;floor.MaterialVariant='KDMDesert_Racing_Sand_A';floor.Color=sandTint
  floor.Anchored=true;floor.CanCollide=false;floor.CanTouch=false;floor.CanQuery=false;floor.CastShadow=false;floor.Parent=model
 end end
 local oldLight={Brightness=Lighting.Brightness,ExposureCompensation=Lighting.ExposureCompensation,ClockTime=Lighting.ClockTime,Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient,EnvironmentDiffuseScale=Lighting.EnvironmentDiffuseScale,EnvironmentSpecularScale=Lighting.EnvironmentSpecularScale}
 local lightBackup=Instance.new('Folder');local newLight={}
 for _,x in Lighting:GetChildren()do if x:IsA('Sky')or x:IsA('Atmosphere')or x:IsA('PostEffect')then x.Parent=lightBackup end end
 for _,x in resources.Lighting:GetChildren()do
  local c=x:Clone()
  if c:IsA('ColorCorrectionEffect')then c.Brightness=-.02;c.Contrast=.08;c.Saturation=.04 end
  c.Parent=Lighting;table.insert(newLight,c)
 end
 Lighting.Brightness=2;Lighting.ExposureCompensation=-.2;Lighting.ClockTime=15.883889
 Lighting.Ambient=Color3.fromRGB(130,128,120);Lighting.OutdoorAmbient=Color3.fromRGB(145,145,140)
 Lighting.EnvironmentDiffuseScale=.8;Lighting.EnvironmentSpecularScale=.25
 model.Parent=track
 model.Destroying:Connect(function()
  alive=false
  for _,r in tiles do terrain:FillBlock(r.CFrame,r.Size,Enum.Material.Air)end
  for _,r in saved do if r.part.Parent then r.part.Material=r.material;r.part.MaterialVariant=r.variant;r.part.Color=r.color;r.part.LocalTransparencyModifier=r.localTransparency end end
  for p,cf in kerbFrames do if p.Parent then p.CFrame=cf end end
  for p,state in roadColors do if p.Parent then p.Color=state[1];p.MaterialVariant=state[2];p.Size=state[3]end end
  for p,state in railState do if p.Parent then
   if p:IsA('SurfaceGui')then p.Enabled=state else p.LocalTransparencyModifier=state end
  end end
  for _,x in newLight do x:Destroy()end
  for _,x in lightBackup:GetChildren()do x.Parent=Lighting end;lightBackup:Destroy()
  for k,v in oldLight do Lighting[k]=v end
  for n,c in colors do terrain:SetMaterialColor(Enum.Material[n],c)end
  for b,n in overrides do materialService:SetBaseMaterialOverride(b,n)end
  for _,v in materialCopies do v:Destroy()end
 end)
 -- Static original palette. Tumbleweed is not planted as a shrub.
 local natural=Instance.new('Folder');natural.Name='SourceNatural';natural.Parent=model
 local adRails=Instance.new('Folder');adRails.Name='ParkSizeAdRails';adRails.Parent=model
 local railSites={};local originals=env and env:FindFirstChild('VisualRails')
 local chevrons={}
 if originals then for _,p in originals:GetChildren()do
  if p:IsA('BasePart')and p:GetAttribute('ChevronDirection')then table.insert(chevrons,p)end
 end end
 local keptChevrons=Environment.selectChevrons(chevrons);local chevronCount=0
 for _,p in chevrons do
  if keptChevrons[p]then chevronCount+=1 else
   railState[p]=p.LocalTransparencyModifier;p.LocalTransparencyModifier=1
   for _,g in p:GetChildren()do if g:IsA('SurfaceGui')then railState[g]=g.Enabled;g.Enabled=false end end
  end
 end
 model:SetAttribute('ChevronSignCount',chevronCount)
 if originals then for _,p in originals:GetChildren()do
  if p:IsA('BasePart')and not p:GetAttribute('ChevronDirection')then
   local gui=p:FindFirstChild('KDMBrandSurfaceGui')
   local clear=gui~=nil
   for _,q in railSites do if (p.Position-q.Position).Magnitude<28 then clear=false;break end end
   -- Full panel footprint retains at least 14 studs beyond the 30-stud road edge.
   for _,z in {-10,0,10}do local v=p.CFrame:PointToWorldSpace(Vector3.new(0,0,z))
    if Environment.roadDistance(samples,v.X,v.Z)<44 then clear=false end
   end
   if clear then
    local clone=p:Clone();clone.Name='AdRail'..(#railSites+1);clone.LocalTransparencyModifier=0
    clone.Size=Vector3.new(.5,4.5,20)
    clone.CFrame=p.CFrame+Vector3.yAxis*(groundY+2.25-p.Position.Y)
    for _,g in clone:GetChildren()do if g:IsA('SurfaceGui')then g.ZOffset=.05;g.AlwaysOnTop=false end end
    clone.Parent=adRails;table.insert(railSites,clone)
   end
   railState[p]=p.LocalTransparencyModifier;p.LocalTransparencyModifier=1
   for _,g in p:GetChildren()do if g:IsA('SurfaceGui')then railState[g]=g.Enabled;g.Enabled=false end end
  end
 end end
 model:SetAttribute('AdRailCount',#railSites)
 local function finishLandscaping()
  local count=0
  local groundParams=RaycastParams.new();groundParams.FilterType=Enum.RaycastFilterType.Include
  groundParams.FilterDescendantsInstances={terrain}
  local function plant(name,x,z,scale,angle)
   if Environment.roadDistance(samples,x,z)<68 then return end
   local template=resources.Natural:FindFirstChild(name);if not template then return end
   local hit=W:Raycast(Vector3.new(x,groundY+300,z),Vector3.new(0,-340,0),groundParams)
   local floorY=math.max(groundY+.035,if hit then hit.Position.Y else groundY+.035)
   local clone=template:Clone()
   if clone:IsA('Model')then clone:ScaleTo(clone:GetScale()*scale)else clone.Size*=scale end
   local cf,size;if clone:IsA('Model')then cf,size=clone:GetBoundingBox()else cf,size=clone.CFrame,clone.Size end
   -- Boulders' mesh corners are hollow: embed their lower 38%, not just the bbox tip.
   local bury=if name=='Racing_Boulder_a'then size.Y*.38 else .18*scale
   local frame=CFrame.new(x,floorY+size.Y/2-bury,z)*CFrame.Angles(0,math.rad(angle),0)
   if clone:IsA('Model')then clone:PivotTo(frame*cf:Inverse()*clone:GetPivot())else clone.CFrame=frame end
   local parts=clone:GetDescendants();table.insert(parts,clone)
   for _,p in parts do if p:IsA('BasePart')then p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false end end
   clone:SetAttribute('GroundY',floorY);clone:SetAttribute('Burial',bury)
   clone.Parent=natural;count+=1
  end
  local names={'Racing_Foliage_Cactus_a','Racing_Foliage_Agave_a','Racing_Boulder_a'}
  local scatter=0
  for ix=-10,10 do for iz=-12,15 do
   local hash=((ix+31)*73856093+(iz+37)*19349663)%2147483647
   local x,z=ix*40+(hash%35)-17,80+iz*40+(math.floor(hash/43)%35)-17
   if scatter<48 and hash%7==0 and Environment.roadDistance(samples,x,z)>80 and x*x+(z+26.792)^2>130^2 then
    plant(names[hash%3+1],x,z,.8+(hash%41)/100,hash%360);scatter+=1
   end
  end end
  for i,p in railSites do
   local gui=p:FindFirstChild('KDMBrandSurfaceGui')
   local outward=p.CFrame.RightVector*(if gui.Face==Enum.NormalId.Right then -1 else 1)
   for j,s in {{22,-9,1},{30,9,3},{39,-5,2}}do
    local v=p.Position+outward*s[1]+p.CFrame.LookVector*s[2]
    plant(names[s[3]],v.X,v.Z,.82+((i*17+j*13)%37)/100,(i*71+j*59)%360)
   end
  end
  for i,s in {{-32,324,3},{28,350,1},{43,310,2},{-45,366,3}}do
   plant(names[s[3]],s[1],s[2],.85+i*.05,i*83)
  end
  model:SetAttribute('NaturalCount',count);model:SetAttribute('DryGrassClumpCount',0)
  model:SetAttribute('DryGrassStyle','SOURCE_TERRAIN_DECORATION')
 end
 -- Source height/material samples; horizontal scale only. Road/recovery rectangle
 -- is never written. Each bounded 32x64x32 voxel batch yields to rendering.
 task.spawn(function()
  local started=os.clock();local total=0
  for sx=1,source.Width,16 do for sz=1,source.Depth,16 do
   if not alive then return end
   local wx=source.SourceMinX+(sx-1)*4+576
   local wz=source.SourceMinZ+(sz-1)*4+336
   if not Environment.protected(wx+32,wz+32) or not Environment.protected(wx,wz)then
    local minY=math.floor((groundY-8)/4)*4
    local columns={};local maxHeight=minY
    for dx=1,16 do
     columns[dx]={};local row=source.Rows[sx+dx-1]
     for dz=1,16 do
      local x,z=wx+(dx-.5)*4,wz+(dz-.5)*4
      if not Environment.protected(x,z)then
       local offset=(sz+dz-2)*4
       local q=tonumber(row:sub(offset+1,offset+3),16);local mi=tonumber(row:sub(offset+4,offset+4),16)
       local b=Environment.ClearBounds
       local distance=math.max(b.MinX-x,x-b.MaxX,b.MinZ-z,z-b.MaxZ,0)
       local blend=math.clamp(distance/160,0,1);blend=blend*blend*(3-2*blend)
       local height=groundY+(q/4-8)*blend;local mn=source.Materials[mi+1]
       if mn=='Grass'or mn=='LeafyGrass'then mn='Sand'end
       columns[dx][dz]={height,Enum.Material[mn]or Enum.Material.Sand};maxHeight=math.max(maxHeight,height)
      end
     end
    end
    local ny=math.clamp(math.ceil((maxHeight-minY)/4),1,64)
    local region=Region3.new(Vector3.new(wx,minY,wz),Vector3.new(wx+64,minY+ny*4,wz+64))
    local materials,occupancy={},{}
    for dx=1,16 do
     materials[dx]={};occupancy[dx]={}
     for y=1,ny do materials[dx][y]=table.create(16,Enum.Material.Air);occupancy[dx][y]=table.create(16,0)end
     for dz=1,16 do local c=columns[dx][dz]
      if c then for y=1,math.min(ny,math.ceil((c[1]-minY)/4))do materials[dx][y][dz]=c[2];occupancy[dx][y][dz]=math.clamp((c[1]-minY)/4-y+1,0,1)end end
     end
    end
    terrain:WriteVoxels(region,4,materials,occupancy);table.insert(tiles,region);total+=1
   end
   if total%4==0 then task.wait()end
  end end
  -- One original-profile dune inside the large loop; its footprint stays >68
  -- studs from the centerline. Unlike the outer relief it is explicitly allowed
  -- inside ClearBounds by the owner's island-dune request.
  for wx=-96,32,64 do for wz=240,368,64 do
   if not alive then return end
   local minY=math.floor((groundY-8)/4)*4;local ny=10
   local region=Region3.new(Vector3.new(wx,minY,wz),Vector3.new(wx+64,minY+ny*4,wz+64))
   local materials,occupancy={},{}
   for dx=1,16 do
    materials[dx]={};occupancy[dx]={}
    for y=1,ny do materials[dx][y]=table.create(16,Enum.Material.Air);occupancy[dx][y]=table.create(16,0)end
    for dz=1,16 do
     local h=Environment.duneHeight(source,wx+(dx-.5)*4,wz+(dz-.5)*4)
     -- A buried base connects boundary voxels below the flat sand floor, avoiding
     -- an exposed vertical rim where the hill would otherwise meet pure Air.
     for y=1,ny do local o=math.clamp((groundY-3+h-minY)/4-y+1,0,1)
      local x,z=wx+(dx-.5)*4,wz+(dz-.5)*4
      local grass=h>3 and math.sin(x*.11)+math.sin(z*.09)>-.5
      materials[dx][y][dz]=if grass then Enum.Material.Grass else Enum.Material.Sand;occupancy[dx][y][dz]=o
     end
    end
   end
   terrain:WriteVoxels(region,4,materials,occupancy);table.insert(tiles,region);total+=1;task.wait()
  end end
  -- Three approved near-course mesas. Bound each write to 64x64 horizontal
  -- tiles, and keep the complete raised footprint outside road/recovery space.
  for _,cliff in Environment.Cliffs do
   local minX=math.floor((cliff.X-cliff.RadiusX)/64)*64
   local maxX=math.ceil((cliff.X+cliff.RadiusX)/64)*64
   local minZ=math.floor((cliff.Z-cliff.RadiusZ)/64)*64
   local maxZ=math.ceil((cliff.Z+cliff.RadiusZ)/64)*64
   for wx=minX,maxX-64,64 do for wz=minZ,maxZ-64,64 do
    if not alive then return end
    local minY=math.floor((groundY-8)/4)*4
    local ny=math.ceil((groundY+cliff.Height-minY)/4)
    local region=Region3.new(Vector3.new(wx,minY,wz),Vector3.new(wx+64,minY+ny*4,wz+64))
    local materials,occupancy={},{}
    for dx=1,16 do
     materials[dx]={};occupancy[dx]={}
     for y=1,ny do materials[dx][y]=table.create(16,Enum.Material.Air);occupancy[dx][y]=table.create(16,0)end
     for dz=1,16 do
      local h=Environment.cliffHeight(source,cliff,wx+(dx-.5)*4,wz+(dz-.5)*4)
      for y=1,ny do local o=math.clamp((groundY-3+h-minY)/4-y+1,0,1)
       materials[dx][y][dz]=if h>4 then Enum.Material.Sandstone else Enum.Material.Sand
       occupancy[dx][y][dz]=o
      end
     end
    end
    terrain:WriteVoxels(region,4,materials,occupancy);table.insert(tiles,region);total+=1;task.wait()
   end end
  end
  -- Occasional native dry-grass patches outside the kerb/runoff corridor.
  -- Preserve existing voxels outside each small patch, including nearby mesas.
  local shoulderPatches=0
  for i=12,#samples-1,18 do
   if not alive then return end
   local a,b=samples[i],samples[i+1];local tangent=(b-a).Unit
   local side=if i%4<2 then -1 else 1
   local center=a+Vector3.new(-tangent.Z,0,tangent.X)*(62*side)
   if Environment.roadDistance(samples,center.X,center.Z)<56 then continue end
   local wx,wz=math.floor((center.X-12)/4)*4,math.floor((center.Z-12)/4)*4
   local minY=math.floor((groundY-8)/4)*4
   local region=Region3.new(Vector3.new(wx,minY,wz),Vector3.new(wx+28,minY+16,wz+28))
   local materials,occupancy=terrain:ReadVoxels(region,4)
   for dx=1,7 do for dz=1,7 do
    local x,z=wx+(dx-.5)*4,wz+(dz-.5)*4
    if ((x-center.X)/10)^2+((z-center.Z)/7)^2<1 and Environment.roadDistance(samples,x,z)>=44 then
     for y=1,4 do
      materials[dx][y][dz]=Enum.Material.Grass
      occupancy[dx][y][dz]=math.clamp((groundY+.3-minY)/4-y+1,0,1)
     end
    end
   end end
   terrain:WriteVoxels(region,4,materials,occupancy);table.insert(tiles,region)
   total+=1;shoulderPatches+=1;task.wait()
  end
  if alive then
   finishLandscaping()
   model:SetAttribute('DryGrassShoulderPatches',shoulderPatches)
   model:SetAttribute('CliffCount',#Environment.Cliffs);model:SetAttribute('DuneCount',1);model:SetAttribute('TerrainTiles',total);model:SetAttribute('TerrainReady',true);model:SetAttribute('TerrainBuildSeconds',os.clock()-started)
  end
 end)
 return model
end
return Environment
