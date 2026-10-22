-- Opt-in island scenery around one continuous flat kart contact face.
-- Road, grass and cliff visuals never supply additional driving collisions.
local Builder={}
function Builder.build(root,ground,origin,layout,lighting)
 local spec=layout.Island
 local folder=Instance.new('Folder');folder.Name='IslandScenery';folder.Parent=root
 local support=Instance.new('Folder');support.Name='G2SafetyGround';support.Parent=root
 -- Called only for opt-in HUBs. Archive the alpine panorama intact and use
 -- Roblox's built-in blue sky over the island; RACE/OFF never enter this path.
 if lighting then
  local archive=Instance.new('Folder');archive.Name='ParkOriginalEnvironment';archive.Parent=root
  for _,old in lighting:GetChildren()do if old:IsA('Sky')then old.Parent=archive end end
  local sky=Instance.new('Sky');sky.Name='HubParkIslandSky';sky.CelestialBodiesShown=false;sky.StarCount=0;sky.Parent=lighting
 end
 local function part(parent,name,size,frame,color,collide,material)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame
  p.Anchored=true;p.CanCollide=collide;p.CanQuery=collide;p.CanTouch=false;p.CastShadow=false
  p.Color=color;p.Material=material or Enum.Material.Slate;p.Parent=parent;return p
 end
 local function plane(parent,name,x0,x1,z0,z1,thickness,color,collide,invisible,visualOffset)
  local top=origin+Vector3.new((x0+x1)/2,visualOffset or 0,(z0+z1)/2)
  local p=part(parent,name,Vector3.new(x1-x0,thickness,z1-z0),
   CFrame.new(top-Vector3.yAxis*thickness/2),color,collide,Enum.Material.Grass)
  if invisible then p.Transparency=1 end
  return p
 end
 -- Same flat top datum as the accepted 7aae5e1 support. One face covers
 -- main road, pit, shoulders and pedestrians; no per-strip collision seams.
 plane(support,'FlatSupport',spec.minX,spec.maxX,spec.minZ,spec.maxZ,1,Color3.new(),true,true)
 root:SetAttribute('OriginalGroundTransparency',ground.Transparency)
 root:SetAttribute('OriginalGroundCanCollide',ground.CanCollide)
 ground.Transparency=1;ground.CanCollide=false
 local grass=Color3.fromRGB(72,121,72)
 -- Roblox clamps a single Part axis to 2048 studs. Tile the ocean explicitly
 -- instead of silently producing a small rectangular pond around the island.
 local tiles=math.ceil(spec.waterSize/2000);local span=spec.waterSize/tiles
 for ix=1,tiles do for iz=1,tiles do
  local water=part(folder,'IslandWater',Vector3.new(span,.5,span),
   CFrame.new(origin+Vector3.new((spec.minX+spec.maxX)/2+(ix-(tiles+1)/2)*span,spec.waterY,(spec.minZ+spec.maxZ)/2+(iz-(tiles+1)/2)*span)),
   Color3.fromRGB(24,151,185),false,Enum.Material.SmoothPlastic)
  water.Transparency=0;water.Reflectance=.03
 end end
 local function widthAt(z)
  local inset=math.max(0,spec.chamfer-(z-spec.minZ),spec.chamfer-(spec.maxZ-z))
  return spec.minX+inset,spec.maxX-inset
 end
 local function rockEdge(x,z,width,length,index)
  local top=layout.height(x,z)-.6;local bottom=spec.waterY-7
  part(folder,'CliffRock',Vector3.new(width,top-bottom,length),
   CFrame.new(origin+Vector3.new(x,(top+bottom)/2,z)),
   Color3.fromRGB(104+index%3*8,95+index%4*5,80+index%3*6),false)
 end
 local rows={spec.minZ}
 for z=spec.minZ+30,spec.maxZ-1,30 do table.insert(rows,z)end
 table.insert(rows,spec.baseZ);table.insert(rows,spec.maxZ)
 table.sort(rows)
 local edgeIndex=0
 for i=1,#rows-1 do
  local z0,z1=rows[i],rows[i+1];if z1-z0<.001 then continue end
  local z=(z0+z1)/2
  -- Conservative row inset keeps the bevel inside its intended perimeter.
  local a,b=widthAt(z0);local c,d=widthAt(z1)
  local x0,x1=math.max(a,c),math.min(b,d)
  -- Grass previously shared the shoulder's exact top plane (Y=0), causing
  -- depth fighting from kart-height cameras. Lower only this decorative skin;
  -- the continuous physical support and shoulder height stay unchanged.
  plane(folder,'IslandGrass',x0,x1,z0,z1,.3,grass,false,false,-.2)
  edgeIndex+=1
  for _,x in {x0,x1}do
   rockEdge(x,z,22,z1-z0+1,edgeIndex)
  end
  if i%8==0 then task.wait()end
 end
 -- Close the near and far shore with chunky native rock faces.
 for _,z in {spec.minZ,spec.maxZ}do
  local x0,x1=widthAt(z)
  for x=x0+20,x1-1,40 do rockEdge(x,z,42,24,edgeIndex);edgeIndex+=1 end
 end
 -- A closed eight-sided stone rim sits inside the faceted shoreline. It never
 -- follows the decorative row steps, and remains well outside driving shoulders.
 local inset=20;local x0,x1,z0,z1=spec.minX+inset,spec.maxX-inset,spec.minZ+inset,spec.maxZ-inset
 local c=spec.chamfer
 local rim={{x0+c,z0},{x1-c,z0},{x1,z0+c},{x1,z1-c},{x1-c,z1},{x0+c,z1},{x0,z1-c},{x0,z0+c}}
 for i,a in rim do
  local b=rim[i%#rim+1];local va=origin+Vector3.new(a[1],layout.height(a[1],a[2])+1.5,a[2])
  local vb=origin+Vector3.new(b[1],layout.height(b[1],b[2])+1.5,b[2])
  part(folder,'IslandEdgeGuard',Vector3.new(2,3,(vb-va).Magnitude+2),CFrame.lookAt((va+vb)/2,vb),Color3.fromRGB(116,112,96),true)
 end
 root:SetAttribute('CollisionContract','FLAT_SUPPORT_V1')
 root:SetAttribute('IslandSlope',0)
 root:SetAttribute('FarCourseHeight',layout.height(0,-1150))
 return support
end
return Builder
