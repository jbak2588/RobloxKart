local fs,luau,rb,process=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/process')
local fixture=require('./hub_park_rookie_loop_validation')
local root,L=fixture.root,fixture.layout
local g=luau.load(fs.readFile('src/shared/RookieLoopDriveGeometry.luau'),{environment={script={Parent={HubParkRookieLoopLayout='layout'}},require=function()return L end}})().create()
local n=0;local function check(v,m)assert(v,m);n+=1 end
for _,path in {'src/shared/HubParkRookieLoopLayout.luau','src/server/HubParkRookieLoopBuilder.luau','src/shared/RookieLoopDriveGeometry.luau'}do
 check(fs.readFile(path):gsub('\r\n','\n')==process.exec('git',{'show','1329cbb:'..path}).stdout:gsub('\r\n','\n'),'approved road/drive/gate unchanged: '..path)
end
local art=assert(root:FindFirstChild('ParkLandscaping'))
check(not fs.readFile('src/server/HubParkLandscapingBuilder.luau'):match('RenderFidelity%s*='),'no runtime LOD mutation')
local parts,trees,shrubs,rocks,hills,meshes=0,0,0,0,0,0
local minClearance=math.huge
for _,v in art:GetDescendants()do
 check(not v:IsA('LuaSourceContainer')and not v:IsA('RemoteEvent')and not v:IsA('Constraint')and not v:IsA('JointInstance'),'visual props contain no gameplay/physics code or joints')
 if v:IsA('Model')then
  trees+=1;check(v:GetAttribute('CuratedPrefab')=='NaturalTreeA'or v:GetAttribute('CuratedPrefab')=='NaturalTreeB','curated tree reuse')
  local minY=math.huge
  for _,p in v:GetDescendants()do if p:IsA('BasePart')then minY=math.min(minY,p.CFrame.Position.Y-p.Size.Y/2)end end
  check(math.abs(minY+.2)<.001,'tree foot grounded, no floating prefab pivots')
 end
 if v:IsA('BasePart')then
  parts+=1;check(v.Anchored and not v.CanCollide and not v.CanTouch and not v.CanQuery and not v.CastShadow,'noninteractive static mobile art')
  if v:IsA('MeshPart')then meshes+=1 end
  if v.Name:match('^ParkShrub')then shrubs+=1 elseif v.Name:match('^ParkRock')then rocks+=1 elseif v.Name:match('^ParkBackdropHill')then hills+=1 end
  for ix=0,4 do for iz=0,4 do
   local p=v.CFrame:PointToWorldSpace(rb.Vector3.new((ix/4-.5)*v.Size.X,0,(iz/4-.5)*v.Size.Z))
   local clearance=-g.contact(p.X,p.Z);minClearance=math.min(minClearance,clearance)
   check(clearance>=12,'visual footprint clears drive/recovery corridor by 12 studs: '..v.Name..' '..tostring(clearance))
   check(not(p.X>=L.Protected.minX and p.X<=L.Protected.maxX and p.Z>=L.Protected.minZ and p.Z<=L.Protected.maxZ),'Lobby/pedestrian approach stays open')
  end end
 end
end
check(parts==30 and meshes==25,'bounded first pass: 30 parts, 25 reused meshes')
check(trees==8 and shrubs==6 and rocks==5 and hills==3,'eight trees, six shrubs, five rocks, three distant hills')
check(#root.IslandScenery:GetDescendants()==332,'A1 outer cliff/sea scenery left unchanged')
print(string.format('PASS %d A2 checks; %d static parts/%d meshes; minimum sampled corridor clearance %.2f studs',n,parts,meshes,minClearance))
