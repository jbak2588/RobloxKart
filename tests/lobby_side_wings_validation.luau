-- The reference oval replaces the historical side-wing union.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local p=luau.load(fs.readFile('src/shared/LobbyDrivePolicy.luau'))()
local g=luau.load(fs.readFile('src/shared/LobbyDriveGeometry.luau'))().create(p)
local n=0;local function check(v,label)assert(v,label);n+=1 end
check(g.bounds.minX+120==-230 and g.bounds.maxX+120==450,'existing baseplate side limits')
check(g.bounds.minZ+766==676 and g.bounds.maxZ+766==1018,'track-facing edge and rear bounds retained')
for z=-88,88,2 do for x=-208,208,2 do
 if p.inside(x,z,2) then check(g.inside(x,z,1),'original training apron retained') end
end end
for z=875,932,3 do for x=-65,95,3 do check(not g.inside(x-120,z-766),'native building protected') end end
check(#g.roadLoops==2 and g.roadMargin==20,'continuous kerbs with safety shoulders')
local split=false
for z=g.bounds.minZ+1,g.bounds.maxZ-1,2 do
 local spans=g.intervals(z);split=split or #spans==2
 for _,span in spans do for x=span[1]+2,span[2]-2,9 do check(g.inside(x,z),'driving spans agree with admission') end end
 for _,span in g.intervals(z,true) do
  for x=span[1]+2,span[2]-2,9 do check(g.inside(x,z,19.85),'asphalt has full shoulder clearance') end
 end
end
check(split,'central island remains unpaved')
for _,edge in g.boundaries do
 local x,z=(edge.a.x+edge.b.x)/2,(edge.a.z+edge.b.z)/2
 local inv=1/math.sqrt(edge.length2);local nx,nz=edge.dz*inv,-edge.dx*inv
 local c,qx,qz=g.contact(x-nx*2,z-nz*2)
 check(c>1.99 and qx*nx+qz*nz>.99,'outer and island collision normals')
 check(not g.inside(x+nx*.01,z+nz*.01),'outside rejected')
 check(g.inside(x-nx*10,z-nz*10,7),'recovery footprint fits every boundary')
end
local rb=require('@lune/roblox')
local tracks=luau.load(fs.readFile('src/shared/TrackGeometry.luau'),{environment={Vector3=rb.Vector3,Vector2=rb.Vector2}})()
local d=tracks.Definitions.PracticeFigure8V1;local gap=math.huge
for _,s in tracks.getCourse(d).Samples do gap=math.min(gap,-g.contact(s.X-120,s.Z-766)-d.RoadWidth/2) end
check(gap>100,'production Practice separation')
print('PASS: '..n..' reference oval / protected island / asphalt / normals / track separation checks')
