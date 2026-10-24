local fs,luau,rb,process=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/process')
local fixture=require('./hub_park_rookie_loop_validation')
local root,L=fixture.root,fixture.layout
local g=luau.load(fs.readFile('src/shared/RookieLoopDriveGeometry.luau'),{environment={script={Parent={HubParkRookieLoopLayout='layout'}},require=function()return L end}})().create()
local n=0;local function check(v,m)assert(v,m);n+=1 end
local forest=rb.deserializeModel(fs.readFile('src/assets/KDMHubForestTreePrefabs.rbxmx'))[1]
check(#forest:GetChildren()==7,'four City trees and three understory prefabs, no whole City import')
for _,model in forest:GetChildren()do
 check(model:IsA('Model')and #model:GetChildren()==(if model.Name=='CityFern'then 1 else 2),'one/two-mesh prefab budget')
 for _,v in model:GetDescendants()do
  check(v:IsA('MeshPart')or v:IsA('SurfaceAppearance'),'prefab contains visual data only')
  if v:IsA('MeshPart')then check(tostring(v.MeshContent):find('rbxassetid://')~=nil and v:FindFirstChildOfClass('SurfaceAppearance')~=nil,'real mesh and appearance, no empty placeholder')end
 end
end
for _,path in {'src/shared/HubParkRookieLoopLayout.luau','src/server/HubParkRookieLoopBuilder.luau','src/shared/RookieLoopDriveGeometry.luau'}do
 check(fs.readFile(path):gsub('\r\n','\n')==process.exec('git',{'show','4fc6ead:'..path}).stdout:gsub('\r\n','\n'),'approved road/drive/gate unchanged: '..path)
end
local art=assert(root:FindFirstChild('ParkLandscaping'))
check(not fs.readFile('src/server/HubParkLandscapingBuilder.luau'):match('RenderFidelity%s*='),'no runtime LOD mutation')
local parts,trees,shrubs,rocks,hills,meshes,beds,understory=0,0,0,0,0,0,0,0
local interior={west=0,northeast=0,lower=0}
local minClearance=math.huge
for _,v in art:GetDescendants()do
 if v:IsA('Folder')and v.Name:match('^ParkFlowerBed')then
  beds+=1;check(#v:GetChildren()==13,'bounded low bed: three shrubs/five flowers with centers')
 end
 check(not v:IsA('LuaSourceContainer')and not v:IsA('RemoteEvent')and not v:IsA('Constraint')and not v:IsA('JointInstance'),'visual props contain no gameplay/physics code or joints')
 if v:IsA('Model')then
  local key=v:GetAttribute('CuratedPrefab')
  if v:GetAttribute('ForestUnderstory')then understory+=1 else
   trees+=1;local p=v:FindFirstChildOfClass('MeshPart').CFrame.Position
   if p.X>-650 and p.X< -400 and p.Z< -500 and p.Z> -1100 then interior.west+=1 end
   if p.X>280 and p.X<660 and p.Z< -930 then interior.northeast+=1 end
   if p.X> -420 and p.X<260 and p.Z> -330 and p.Z< -230 then interior.lower+=1 end
  end
  check(key=='NaturalTreeA'or key=='NaturalTreeB'or forest:FindFirstChild(key)~=nil,'curated vegetation reuse')
  local minY=math.huge
  for _,p in v:GetDescendants()do if p:IsA('BasePart')then
   local cf=p.CFrame
   local halfHeight=(math.abs(cf.RightVector.Y)*p.Size.X+math.abs(cf.UpVector.Y)*p.Size.Y+math.abs(cf.LookVector.Y)*p.Size.Z)/2
   minY=math.min(minY,cf.Position.Y-halfHeight)
  end end
  if key=='CityMaple'then
   local trunk=v:FindFirstChild('Trunk')
   local scale=trunk.Size.Y/forest.CityMaple.Trunk.Size.Y
   local collarY=trunk.CFrame:PointToWorldSpace(rb.Vector3.new(0,-trunk.Size.Y/2,0)).Y+2*scale
   check(math.abs(collarY+.2)<.001,'tilted Maple root collar meets grass at every scale/yaw')
   check(minY< -4,'Maple empty bbox corners buried rather than mistaken for visible roots')
  else
   check(math.abs(minY+.2)<.001,'other vegetation grounding preserved')
  end
 end
 if v:IsA('BasePart')then
  parts+=1;check(v.Anchored and not v.CanCollide and not v.CanTouch and not v.CanQuery and not v.CastShadow,'noninteractive static mobile art')
  if v:IsA('MeshPart')then meshes+=1 end
  if v.Name:match('^ParkShrub')then shrubs+=1 elseif v.Name:match('^ParkRock')then rocks+=1 elseif v.Name:match('^ParkBackdropHill')then hills+=1 end
  for ix=0,4 do for iz=0,4 do
   local p=v.CFrame:PointToWorldSpace(rb.Vector3.new((ix/4-.5)*v.Size.X,0,(iz/4-.5)*v.Size.Z))
   local clearance=-g.contact(p.X,p.Z);minClearance=math.min(minClearance,clearance)
   check(clearance>=12,'visual footprint clears drive/recovery corridor by 12 studs: '..v.Parent.Name..'/'..v.Name..' '..tostring(clearance))
   check(not(p.X>=L.Protected.minX and p.X<=L.Protected.maxX and p.Z>=L.Protected.minZ and p.Z<=L.Protected.maxZ),'Lobby/pedestrian approach stays open')
  end end
 end
end
check(parts==781 and meshes==696,'reduced vegetation budget: 781 static parts / 696 reused meshes')
check(trees==308 and understory==30 and shrubs==6 and rocks==5 and hills==0 and beds==8,'308 trees and 30 Lobby understory groups; existing low beds/rocks preserved, no mountains')
check(interior.west>=15 and interior.northeast>=20 and interior.lower>=10,'forest occupies broad land interiors, not only roadside rows')
-- Check source planting anchors: grounding changes mesh-center positions by species.
local source=fs.readFile('src/server/HubParkLandscapingBuilder.luau')
local sites={}
local function outsideClearing(x,z)return ((x-300)/220)^2+((z+1080)/120)^2>=1 end
local treeBlock=assert(source:match('local treeSites={(.-)\n }'))
for x,z in treeBlock:gmatch('{([%d%.%-]+),([%d%.%-]+),')do
 x,z=tonumber(x),tonumber(z)
 check(outsideClearing(x,z),'northeast grove center cleared')
 for _,p in sites do check((x-p.x)^2+(z-p.z)^2>=31^2,'staggered trees separated by at least 31 studs')end
 table.insert(sites,{x=x,z=z})
end
check(#sites==308,'exactly 30 percent of the 440 original trees removed')
local underBlock=assert(source:match('local understorySites={(.-)\n }'))
local left,right=0,0
for x,z in underBlock:gmatch('{([%d%.%-]+),([%d%.%-]+),')do
 x,z=tonumber(x),tonumber(z)
 local radius=math.sqrt((math.abs(x)-145)^2+(z+25)^2)
 check(radius>=7 and radius<=18,'mixed understory wraps Lobby tree bases with clear trunk collars; none in forest')
 if x<0 then left+=1 else right+=1 end
end
check(left==15 and right==15,'15 low plants around each Lobby tree')
check(#root.IslandScenery:GetDescendants()==332,'A1 outer cliff/sea scenery left unchanged')
print(string.format('PASS %d A2 checks; %d static parts/%d meshes; minimum sampled corridor clearance %.2f studs',n,parts,meshes,minClearance))
