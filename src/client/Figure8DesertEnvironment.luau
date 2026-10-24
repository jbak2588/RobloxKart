-- Source-only desert scenery. Never writes a road, trigger, seat or kart.
local RS=game:GetService('ReplicatedStorage')
local W=game:GetService('Workspace')
local Lighting=game:GetService('Lighting')
local Geometry=require(RS.Shared.TrackGeometry)
local Environment={}
Environment.SourceScale=1
Environment.ClearBounds={MinX=-400,MaxX=400,MinZ=-440,MaxZ=608}
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
 local saved={};local tiles={};local alive=true
 local function appearance(part)
  table.insert(saved,{part=part,material=part.Material,variant=part.MaterialVariant,color=part.Color,localTransparency=part.LocalTransparencyModifier})
  part.Material=Enum.Material.Sand;part.MaterialVariant='KDMDesert_Racing_Sand_A';part.Color=Color3.new(1,1,1)
 end
 local materialService=game:GetService('MaterialService');local materialCopies={};local overrides={}
 for _,v in resources.Materials:GetChildren()do
  local c=v:Clone();c.Name='KDMDesert_'..v.Name;c.Parent=materialService;table.insert(materialCopies,c)
  local base=c.BaseMaterial
  if overrides[base]==nil then overrides[base]=materialService:GetBaseMaterialOverride(base)end
  materialService:SetBaseMaterialOverride(base,c.Name)
 end
 local terrain=W.Terrain;local colors={}
 for _,n in {'Sand','Sandstone','Ground'}do colors[n]=terrain:GetMaterialColor(Enum.Material[n]);terrain:SetMaterialColor(Enum.Material[n],Color3.new(1,1,1))end
 colors.Slate=terrain:GetMaterialColor(Enum.Material.Slate);terrain:SetMaterialColor(Enum.Material.Slate,Color3.fromRGB(204,190,140))
 local env=track:FindFirstChild('Environment');local infield=env and env:FindFirstChild('Infield')
 if infield then appearance(infield);infield.LocalTransparencyModifier=1 end
 if ground then appearance(ground);ground.LocalTransparencyModifier=1 end
 local base=W:FindFirstChild('Baseplate');if base then appearance(base)end
 for _,x in {-704,704}do for _,z in {-624,784}do
  local floor=Instance.new('Part');floor.Name='SourceSandGround';floor.Size=Vector3.new(1408,.02,1408)
  floor.CFrame=CFrame.new(x,groundY+.025,z);floor.Material=Enum.Material.Sand;floor.MaterialVariant='KDMDesert_Racing_Sand_A';floor.Color=Color3.new(1,1,1)
  floor.Anchored=true;floor.CanCollide=false;floor.CanTouch=false;floor.CanQuery=false;floor.CastShadow=false;floor.Parent=model
 end end
 local oldLight={Brightness=Lighting.Brightness,ClockTime=Lighting.ClockTime,Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient}
 local lightBackup=Instance.new('Folder');local newLight={}
 for _,x in Lighting:GetChildren()do if x:IsA('Sky')or x:IsA('Atmosphere')or x:IsA('PostEffect')then x.Parent=lightBackup end end
 for _,x in resources.Lighting:GetChildren()do local c=x:Clone();c.Parent=Lighting;table.insert(newLight,c)end
 Lighting.Brightness=3;Lighting.ClockTime=15.883889;Lighting.Ambient=Color3.fromRGB(99,92,77);Lighting.OutdoorAmbient=Color3.fromRGB(66,94,143)
 model.Parent=track
 model.Destroying:Connect(function()
  alive=false
  for _,r in tiles do terrain:FillBlock(r.CFrame,r.Size,Enum.Material.Air)end
  for _,r in saved do if r.part.Parent then r.part.Material=r.material;r.part.MaterialVariant=r.variant;r.part.Color=r.color;r.part.LocalTransparencyModifier=r.localTransparency end end
  for _,x in newLight do x:Destroy()end
  for _,x in lightBackup:GetChildren()do x.Parent=Lighting end;lightBackup:Destroy()
  for k,v in oldLight do Lighting[k]=v end
  for n,c in colors do terrain:SetMaterialColor(Enum.Material[n],c)end
  for b,n in overrides do materialService:SetBaseMaterialOverride(b,n)end
  for _,v in materialCopies do v:Destroy()end
 end)
 -- Original palette meshes only. No Grass_b, grass material or turf carpet.
 local natural=Instance.new('Folder');natural.Name='SourceNatural';natural.Parent=model
 local samples=Geometry.getCourse(Geometry.getDefinition('PracticeFigure8V1')).Samples
 local names={'Racing_Foliage_Cactus_a','Racing_Foliage_Agave_a','Racing_Foliage_Tumbleweed_a','Racing_Boulder_a'}
 local candidates={}
 for ix=-10,10 do for iz=-12,15 do
  local hash=((ix+31)*73856093+(iz+37)*19349663)%2147483647
  local x,z=ix*40+(hash%35)-17,80+iz*40+(math.floor(hash/43)%35)-17
  if hash%5<3 and Environment.roadDistance(samples,x,z)>68 and x*x+(z+26.792)^2>130^2 then
   table.insert(candidates,{x=x,z=z,hash=hash,order=(hash*48271)%2147483647})
  end
 end end
 table.sort(candidates,function(a,b)return a.order<b.order end)
 local count=0
 for _,site in candidates do
  if count>=120 then break end
  local x,z,hash=site.x,site.z,site.hash
  local name=names[math.floor(hash/97)%4+1];local template=resources.Natural:FindFirstChild(name)
  if template then
   local clone=template:Clone();local scale=.8+(hash%51)/100
   if clone:IsA('Model')then clone:ScaleTo(clone:GetScale()*scale)else clone.Size*=scale end
   local cf,size;if clone:IsA('Model')then cf,size=clone:GetBoundingBox()else cf,size=clone.CFrame,clone.Size end
   local frame=CFrame.new(x,groundY+size.Y/2-.15,z)*CFrame.Angles(0,math.rad(hash%360),0)
   if clone:IsA('Model')then clone:PivotTo(frame*cf:Inverse()*clone:GetPivot())else clone.CFrame=frame end
   local parts=clone:GetDescendants();table.insert(parts,clone)
   for _,p in parts do if p:IsA('BasePart')then p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false end end
   clone.Parent=natural;count+=1
  end
 end
 model:SetAttribute('NaturalCount',count)
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
  if alive then model:SetAttribute('TerrainTiles',total);model:SetAttribute('TerrainReady',true);model:SetAttribute('TerrainBuildSeconds',os.clock()-started)end
 end)
 return model
end
return Environment
