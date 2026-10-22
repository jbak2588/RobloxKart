local fs,luau,rb,process,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/process'),require('@lune/serde')
local fixture=require('./hub_park_rookie_loop_validation')
local root,L=fixture.root,fixture.layout
local n=0;local function check(v,m)assert(v,m);n+=1 end
local function prior(path)return process.exec('git',{'show','1329cbb:'..path}).stdout end
for _,path in {'src/shared/HubParkRookieLoopLayout.luau','src/server/HubParkRookieLoopBuilder.luau','src/shared/RookieLoopDriveGeometry.luau'}do
 check(fs.readFile(path):gsub('\r\n','\n')==prior(path):gsub('\r\n','\n'),'accepted driving/gate source unchanged: '..path)
end
local env={Instance=rb.Instance,Vector3=rb.Vector3,CFrame=rb.CFrame,Color3=rb.Color3,Enum=rb.Enum,task={wait=function()end}}
local before=luau.load(prior('src/server/HubParkIslandBuilder.luau'),{environment=env})()
local old=rb.Instance.new('Model');local ground=rb.Instance.new('Part');ground.Size=rb.Vector3.new(2048,20,2048);ground.Position=rb.Vector3.new(0,-10,0)
before.build(old,ground,rb.Vector3.zero,L,nil)
local properties={'Size','CFrame','CanCollide','CanTouch','CanQuery','Anchored','Transparency'}
local function equalPart(a,b,label)
 for _,p in properties do check(a[p]==b[p],label..' '..p..' unchanged')end
end
equalPart(root.G2SafetyGround.FlatSupport,old.G2SafetyGround.FlatSupport,'FlatSupport')
local function named(r,name)
 local out={};for _,v in r:GetDescendants()do if v.Name==name then table.insert(out,v)end end;return out
end
for _,name in {'IslandEdgeGuard','IslandWater'}do
 local a,b=named(root,name),named(old,name);check(#a==#b,'original '..name..' count')
 for i,p in a do equalPart(p,b[i],name);check(p.Color==b[i].Color and p.Material==b[i].Material,name..' appearance retained')end
end
local oldCount,newCount=#old.IslandScenery:GetDescendants(),#root.IslandScenery:GetDescendants()
check(newCount<=oldCount*1.25,'A1 scenery budget at most +25%')
check(#named(root,'IslandGrass')==3 and #named(root,'IslandGrassBevel')==8,'exact chamfer cap replaces stair-step grass rows')
local waterBottom=false;local rockTones={}
local function vertices(v)
 local out={}
 for _,x in {-1,1}do for _,c in (if v:IsA('WedgePart')then {{1,1},{-1,1},{-1,-1}}else {{1,1},{1,-1},{-1,1},{-1,-1}})do
  table.insert(out,v.CFrame:PointToWorldSpace(rb.Vector3.new(x*v.Size.X/2,c[1]*v.Size.Y/2,c[2]*v.Size.Z/2)))
 end end
 return out
end
local s=L.Island
for _,v in root.IslandScenery:GetChildren()do if v:IsA('BasePart')then
 check(v.Anchored and not v.CanTouch and not v.CastShadow,'static bounded decoration')
 if v.Name~='IslandEdgeGuard'then check(not v.CanCollide and not v.CanQuery,'art cannot become kart contact or recovery query')end
 if v.Name=='IslandGrass'or v.Name=='IslandGrassBevel'then
  check(v.Material==rb.Enum.Material.Grass and v.Color==rb.Color3.fromRGB(72,121,72),'uniform grass appearance')
  for _,p in vertices(v)do
   check(p.Y<=-.199 and p.Y>=-.501,'grass stays below road without raised bands')
   check(p.X>=s.minX-.001 and p.X<=s.maxX+.001 and p.Z>=s.minZ-.001 and p.Z<=s.maxZ+.001,'cap keeps approved footprint')
   check(p.X-s.minX+p.Z-s.minZ>=s.chamfer-.001 and s.maxX-p.X+p.Z-s.minZ>=s.chamfer-.001
    and p.X-s.minX+s.maxZ-p.Z>=s.chamfer-.001 and s.maxX-p.X+s.maxZ-p.Z>=s.chamfer-.001,'corner is a true diagonal, not staircase')
  end
 elseif v.Name=='CliffRock'then
  check(v:IsA('WedgePart'),'faceted rock skin replaces repeated cuboids')
  rockTones[tostring(v.Color)]=true
  for _,p in vertices(v)do check(p.Y<-.19,'cliff never projects above grass/road')
   if p.Y<s.waterY-6 then waterBottom=true end
  end
 end
end end
local tones=0;for _ in rockTones do tones+=1 end
check(tones==3,'three restrained soil/rock tones')
check(waterBottom,'closed lower cliff band continues below sea')
local outDir='artifacts/hub-racing-park/park-a1'
if not fs.isDir(outDir)then fs.writeDir(outDir)end
fs.writeFile(outDir..'/object-counts.json',serde.encode('json',{before=oldCount,after=newCount,changePercent=(newCount/oldCount-1)*100,checks=n},true))
print(string.format('PASS %d A1 visual/immutable contact/guard/water checks; scenery %d -> %d (%.1f%%)',n,oldCount,newCount,(newCount/oldCount-1)*100))
