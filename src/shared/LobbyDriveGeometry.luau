-- Reference oval around the existing Lobby; all coordinates stay zone-local.
-- Driving boundary includes a 20-stud grass safety shoulder beyond cyan kerbs.
local Geometry = {}
function Geometry.create(_policy)
 local function rounded(minX,maxX,minZ,maxZ,r)
  local points={}
  local function add(x,z)
   local last=points[#points]
   if not last or math.abs(x-last.x)+math.abs(z-last.z)>1e-6 then table.insert(points,{x=x,z=z}) end
  end
  local function arc(x,z,a,b)
   local n=math.ceil((b-a)*r/5)
   for i=1,n do local t=a+(b-a)*i/n;add(x+r*math.cos(t),z+r*math.sin(t)) end
  end
  add(minX+r,minZ);add(maxX-r,minZ)
  arc(maxX-r,minZ+r,-math.pi/2,0);add(maxX,maxZ-r)
  arc(maxX-r,maxZ-r,0,math.pi/2);add(minX+r,maxZ)
  arc(minX+r,maxZ-r,math.pi/2,math.pi);add(minX,minZ+r)
  arc(minX+r,minZ+r,math.pi,3*math.pi/2)
  table.remove(points) -- exact closing duplicate
  return points
 end
 local function reverse(points)
  local out={};for i=#points,1,-1 do table.insert(out,points[i]) end;return out
 end
 local function edgesFor(loops)
  local edges={}
  for _,loop in loops do for i,a in loop do
   local b=loop[i%#loop+1];local dx,dz=b.x-a.x,b.z-a.z
   if dx*dx+dz*dz>1e-10 then table.insert(edges,{a=a,b=b,dx=dx,dz=dz,length2=dx*dx+dz*dz}) end
  end end
  return edges
 end
 -- World bounds -230..450 / 676..1018 retain the native baseplate and track gap.
 local bounds={minX=-350,maxX=330,minZ=-90,maxZ=252}
 local island={minX=-210,maxX=30,minZ=90,maxZ=180,radius=35}
 local margin=20
 local points=rounded(bounds.minX,bounds.maxX,bounds.minZ,bounds.maxZ,171)
 local hole=reverse(rounded(island.minX,island.maxX,island.minZ,island.maxZ,island.radius))
 local edges=edgesFor({points,hole})
 local roadLoops={
  rounded(bounds.minX+margin,bounds.maxX-margin,bounds.minZ+margin,bounds.maxZ-margin,171-margin),
  reverse(rounded(island.minX-margin,island.maxX+margin,island.minZ-margin,island.maxZ+margin,island.radius+margin))
 }
 local roadEdges=edgesFor(roadLoops)
 local g={points=points,bounds=bounds,boundaries=edges,island=island,
  roadMargin=margin,roadLoops=roadLoops,roadBoundaries=roadEdges,
  rear={minZ=island.maxZ,maxZ=bounds.maxZ}}
 function g.contact(x,z)
  local inside=false;local best=math.huge;local nx,nz=0,0
  for _,e in edges do
   if (e.a.z>z)~=(e.b.z>z) and x<e.a.x+(z-e.a.z)*e.dx/e.dz then inside=not inside end
   local t=math.clamp(((x-e.a.x)*e.dx+(z-e.a.z)*e.dz)/e.length2,0,1)
   local dx,dz=x-e.a.x-e.dx*t,z-e.a.z-e.dz*t
   local d=dx*dx+dz*dz
   if d<best then
    best=d
    if d>1e-12 then local inv=1/math.sqrt(d);nx,nz=dx*inv,dz*inv
    else local inv=1/math.sqrt(e.length2);nx,nz=e.dz*inv,-e.dx*inv end
   end
  end
  local clearance=math.sqrt(best)
  if inside and clearance>1e-6 then return clearance,-nx,-nz end
  return -clearance,nx,nz
 end
 function g.inside(x,z,margin)
  local m=margin or 0
  if x<bounds.minX+m or x>bounds.maxX-m or z<bounds.minZ+m or z>bounds.maxZ-m then return false end
  return g.contact(x,z)>=m-1e-6
 end
 function g.intervals(z,roadOnly)
  local hits={}
  for _,e in (if roadOnly then roadEdges else edges) do
   if (e.a.z>z)~=(e.b.z>z) then table.insert(hits,e.a.x+(z-e.a.z)*e.dx/e.dz) end
  end
  table.sort(hits);local spans={}
  for i=1,#hits-1,2 do table.insert(spans,{hits[i],hits[i+1]}) end
  return spans
 end
 return g
end
return Geometry
