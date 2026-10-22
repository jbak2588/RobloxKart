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
 -- Exact chamfered octagon: shared edges replace 30-stud stair-step rows.
 local x0,x1,z0,z1,c=spec.minX,spec.maxX,spec.minZ,spec.maxZ,spec.chamfer
 local outline={{x0+c,z0},{x1-c,z0},{x1,z0+c},{x1,z1-c},
  {x1-c,z1},{x0+c,z1},{x0,z1-c},{x0,z0+c}}
 local function triangle(name,a,b,c,color,material)
  local ab,ac,bc=b-a,c-a,c-b
  if ab:Dot(ab)>ac:Dot(ac) and ab:Dot(ab)>bc:Dot(bc)then c,a=a,c
  elseif ac:Dot(ac)>bc:Dot(bc)then a,b=b,a end
  ab,ac,bc=b-a,c-a,c-b
  if ac:Cross(ab).Magnitude<.00001 then return end
  local right=ac:Cross(ab).Unit;local back=bc.Unit;local up=back:Cross(right)
  local h=math.abs(ab:Dot(up))
  for _,e in {{a,b,right,back},{a,c,-right,-back}}do
   local length=math.abs((e[2]-e[1]):Dot(back))
   if length<.00001 then continue end
   local v=Instance.new('WedgePart');v.Name=name
   v.Size=Vector3.new(.01,h,length);v.CFrame=CFrame.fromMatrix((e[1]+e[2])/2,e[3],up,e[4])
   v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false;v.CastShadow=false
   v.Color=color;v.Material=material;v.Parent=folder
  end
 end
 -- Three rectangular grass panels and four triangular corners share exact
 -- boundaries. Keep the accepted -.2 top offset below all driving visuals.
 plane(folder,'IslandGrass',x0,x1,z0+c,z1-c,.3,grass,false,false,-.2)
 plane(folder,'IslandGrass',x0+c,x1-c,z0,z0+c,.3,grass,false,false,-.2)
 plane(folder,'IslandGrass',x0+c,x1-c,z1-c,z1,.3,grass,false,false,-.2)
 for _,corner in {
  {{x0+c,z0},{x0,z0+c},{x0+c,z0+c}},
  {{x1-c,z0},{x1,z0+c},{x1-c,z0+c}},
  {{x1,z1-c},{x1-c,z1},{x1-c,z1-c}},
  {{x0+c,z1},{x0,z1-c},{x0+c,z1-c}},
 }do
  local function v(p)return origin+Vector3.new(p[1],-.205,p[2])end
  triangle('IslandGrassBevel',v(corner[1]),v(corner[2]),v(corner[3]),grass,Enum.Material.Grass)
 end
 -- Broad deterministic facets, not stacks of identical cuboids. Twenty-two
 -- shared shoreline stations form three closed bands down below the sea.
 local edge={};local center=Vector3.new((x0+x1)/2,0,(z0+z1)/2)
 for i,a in outline do
  local b=outline[i%#outline+1]
  local length=math.sqrt((b[1]-a[1])^2+(b[2]-a[2])^2)
  local n=math.ceil(length/300)
  for j=0,n-1 do local t=j/n
   table.insert(edge,Vector3.new(a[1]+(b[1]-a[1])*t,0,a[2]+(b[2]-a[2])*t))
  end
 end
 local rings={{},{},{},{}}
 for i,p in edge do
  local inward=(center-p).Unit
  rings[1][i]=origin+p+Vector3.new(0,-.205,0)
  rings[2][i]=origin+p+inward*2+Vector3.new(0,-6,0)
  rings[3][i]=origin+p+inward*(5+i%3*3)+Vector3.new(0,-25-i%3*3,0)
  rings[4][i]=origin+p+inward*(18+i%3*2)+Vector3.new(0,spec.waterY-7,0)
 end
 local soil=Color3.fromRGB(115,99,77)
 local rock={Color3.fromRGB(104,112,116),Color3.fromRGB(124,129,127)}
 for band=1,3 do for i=1,#edge do
  local j=i%#edge+1
  local a,b,c,d=rings[band][i],rings[band][j],rings[band+1][j],rings[band+1][i]
  local color=if band==1 then soil else rock[(i+band)%2+1]
  triangle('CliffRock',a,b,c,color,Enum.Material.Slate)
  triangle('CliffRock',a,c,d,color,Enum.Material.Slate)
  if i%8==0 then task.wait()end
 end end
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
 local storage=game:GetService('ReplicatedStorage')
 require(script.Parent:WaitForChild('HubParkLandscapingBuilder')).build(root,origin,
  storage:FindFirstChild('KDMHorizonTreePrefabs'),storage:FindFirstChild('KDMHorizonMountainPrefabs'))
 local lights=storage:FindFirstChild('KDMTrackLightingPrefabs')
 require(script.Parent:WaitForChild('HubParkCircuitDecorBuilder')).build(root,origin,layout,lights and lights:FindFirstChild('OB_Spotlight_a'))
 return support
end
return Builder
