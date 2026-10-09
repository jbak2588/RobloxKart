local fs,luau=require('@lune/fs'),require('@lune/luau')
local p=luau.load(fs.readFile('src/shared/LobbyDrivePolicy.luau'))()
local g=luau.load(fs.readFile('src/shared/LobbyDriveGeometry.luau'))().create(p)
local pattern=luau.load(fs.readFile('src/shared/LobbySkidPattern.luau'))()
local patterns=pattern.paths()
local n=0;local function check(v,label) assert(v,label);n+=1 end
local function at(x,z,m) return g.inside(x-120,z-766,m or 0) end
check(g.bounds.minX+120==-230 and g.bounds.maxX+120==450,'side bounds')
check(math.abs(g.bounds.minZ+766-676)<1e-6 and math.abs(g.bounds.maxZ+766-990)<1e-6,'front preserved and rear bounded')
-- All safely interior points in the accepted front stadium remain usable.
for z=-88,88,2 do for x=-208,208,2 do
 if p.inside(x,z,2) then check(g.inside(x,z,1),'original front apron preserved') end
end end
check(at(-155,904,35),'left wing fits a 35-stud Drift circle')
check(at(306,902,60),'right wing has broad Drift clearance')
check(at(0,845,8),'central entry approach remains usable')
check(not at(0,869) and not at(0,900) and not at(0,950),'central pedestrian recess excluded')
for z=875,940,5 do for x=-65,95,5 do check(not at(x,z),'building excluded from driving') end end
-- Asphalt intervals must agree with the same admission outline, including two-span recess rows.
local split=false
for z=g.bounds.minZ+1,g.bounds.maxZ-1,2 do
 local spans=g.intervals(z);split=split or #spans==2
 for _,span in spans do
  check(g.inside((span[1]+span[2])/2,z),'pavement midpoint admitted')
  for x=span[1]+3,span[2]-3,9 do check(g.inside(x,z),'paving never fills excluded building recess') end
 end
 for x=g.bounds.minX+3,g.bounds.maxX-3,9 do
  if g.inside(x,z,3) then
   local paved=false
   for _,s in spans do if x>=s[1] and x<=s[2] then paved=true end end
   check(paved,'all safe interior has asphalt')
  end
 end
end
check(split,'rear paving splits around building')
-- Outward normals point through each wall, including concave inside corners.
for i,a in g.points do
 local b=g.points[i%#g.points+1]
 local x,z=(a.x+b.x)/2,(a.z+b.z)/2
 local dx,dz=b.x-a.x,b.z-a.z;local len=math.sqrt(dx*dx+dz*dz)
 local nx,nz=dz/len,-dx/len
 local clearance,qx,qz=g.contact(x-nx*2,z-nz*2)
 check(clearance>1.9 and qx*nx+qz*nz>.98,'correct inward clearance and outward normal')
 check(not g.inside(x+nx*2,z+nz*2),'outside wall rejected')
 check(g.inside(x-nx*10,z-nz*10,7),'kart shoulder and recovery point inside each wall')
end
-- Fixed marks clip paired paths with a 12-stud margin; every requested pattern survives.
local count,kinds=0,{}
for _,path in patterns do
 for i=1,#path.points-1 do
  local a,b=path.points[i],path.points[i+1];local dx,dz=b.x-a.x,b.z-a.z
  local len=math.sqrt(dx*dx+dz*dz)
  for _,offset in {-2.1,2.1} do
   local ax,az=pattern.tirePoint(path,i,offset)
   local bx,bz=pattern.tirePoint(path,i+1,offset)
   local clear=true
   for k=0,4 do if not g.inside(ax+(bx-ax)*k/4,az+(bz-az)*k/4,12) then clear=false end end
   if clear then count+=1;kinds[path.kind]=true end
  end
 end
end
for _,kind in {'LargeArc','OldLargeArc','S','OldS','FigureEight','Circle','LeftWingCircle','RightWingCircle','OldRightArc'} do check(kinds[kind],'visible '..kind) end
check(count>300 and count<=640,'bounded permanent paired marks')
-- Compare road clearance against production Practice course via native Vector3 implementation.
local rb=require('@lune/roblox')
local tracks=luau.load(fs.readFile('src/shared/TrackGeometry.luau'),{environment={Vector3=rb.Vector3,Vector2=rb.Vector2}})()
local definition=tracks.Definitions.PracticeFigure8V1
local minGap=math.huge
for _,sample in tracks.getCourse(definition).Samples do
 local clearance=g.contact(sample.X-120,sample.Z-766)
 minGap=math.min(minGap,-clearance-definition.RoadWidth/2)
end
check(minGap>100,'production Practice road safely separated')
print('PASS: '..n..' side-wing geometry / original apron / concave walls / paving / paired static skid checks; '..count..' marks; Practice road gap '..string.format('%.1f',minGap))
