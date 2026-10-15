-- Lobby-only apron. Coordinates share the unchanged front stadium's center.
-- The original apron plus a rear connector share one exact union boundary.
-- Paving, fences, clearance and recovery admission use the same edges.
local Geometry = {}
function Geometry.create(policy)
 local points = {}
 local function add(x,z) table.insert(points,{x=x-120,z=z-766}) end
 local function line(x,z)
  local last=points[#points]
  if not last then add(x,z);return end
  local ax,az=last.x+120,last.z+766
  if math.abs(x-ax)+math.abs(z-az)>1e-6 then add(x,z) end
 end
 local function arc(x,z,r,a,b)
  local count=math.ceil(math.abs(b-a)*r/6)
  for i=1,count do local t=a+(b-a)*i/count;add(x+r*math.cos(t),z+r*math.sin(t)) end
 end
 -- Exact original front straight and front semicircle quadrants remain in place.
 local r=policy.OuterRadius
 local left,right=120-policy.HalfStraight,120+policy.HalfStraight
 add(left,766-r);line(right,766-r)
 arc(right,766,r,-math.pi/2,0)
 -- Rounded wings extend sideways and behind the front apron, not toward the race track.
 arc(right+r+35,766,35,math.pi,math.pi/2)
 line(390,801);arc(390,861,60,-math.pi/2,0)
 line(450,900);arc(360,900,90,0,math.pi/2)
 line(230,990);arc(230,900,90,math.pi/2,math.pi)
 line(140,891);arc(105,891,35,0,-math.pi/2)
 -- Recess protects the building, grass and central pedestrian entry.
 line(-45,856);arc(-45,891,35,-math.pi/2,-math.pi)
 line(-80,915);arc(-155,915,75,0,math.pi)
 line(-230,861);arc(-170,861,60,math.pi,3*math.pi/2)
 line(-125,801);arc(-125,766,35,math.pi/2,0)
 arc(left,766,r,math.pi,3*math.pi/2)
 table.remove(points) -- last arc ends exactly at the first point
 local bounds={minX=math.huge,maxX=-math.huge,minZ=math.huge,maxZ=-math.huge}
 for _,p in points do
  bounds.minX=math.min(bounds.minX,p.x);bounds.maxX=math.max(bounds.maxX,p.x)
  bounds.minZ=math.min(bounds.minZ,p.z);bounds.maxZ=math.max(bounds.maxZ,p.z)
 end
 local edges={}
 for i,a in points do
  local b=points[i%#points+1];local dx,dz=b.x-a.x,b.z-a.z
  table.insert(edges,{a=a,b=b,dx=dx,dz=dz,length2=dx*dx+dz*dz})
 end
 -- Measured PV681 art ends at world Z932.074; the connector starts at958.
 -- Keep the old apron coordinates intact. Split intersections and remove only
 -- interior edges, including the obsolete barriers across the two rear joins.
 local rear={minX=-180-120,maxX=340-120,minZ=958-766,maxZ=1018-766}
 local oldEdges=edges
 local function polygonInside(x,z)
  local yes=false
  for _,e in oldEdges do
   if (e.a.z>z)~=(e.b.z>z) and x<e.a.x+(z-e.a.z)*e.dx/e.dz then yes=not yes end
  end
  return yes
 end
 local function rearInside(x,z)
  return x>rear.minX and x<rear.maxX and z>rear.minZ and z<rear.maxZ
 end
 local corners={{x=rear.minX,z=rear.minZ},{x=rear.maxX,z=rear.minZ},{x=rear.maxX,z=rear.maxZ},{x=rear.minX,z=rear.maxZ}}
 local rearEdges={}
 for i,a in corners do local b=corners[i%4+1];table.insert(rearEdges,{a=a,b=b,dx=b.x-a.x,dz=b.z-a.z}) end
 local unionEdges={}
 local function split(source,other,hidden)
  for _,e in source do
   local cuts={0,1}
   for _,f in other do
    local cross=e.dx*f.dz-e.dz*f.dx
    if math.abs(cross)>1e-8 then
     local qx,qz=f.a.x-e.a.x,f.a.z-e.a.z
     local t=(qx*f.dz-qz*f.dx)/cross
     local u=(qx*e.dz-qz*e.dx)/cross
     if t>1e-8 and t<1-1e-8 and u>=0 and u<=1 then table.insert(cuts,t) end
    end
   end
   table.sort(cuts)
   for i=1,#cuts-1 do
    local a,b=cuts[i],cuts[i+1];local mid=(a+b)/2
    if b-a>1e-8 and not hidden(e.a.x+e.dx*mid,e.a.z+e.dz*mid) then
     local start={x=e.a.x+e.dx*a,z=e.a.z+e.dz*a}
     local finish={x=e.a.x+e.dx*b,z=e.a.z+e.dz*b}
     local dx,dz=finish.x-start.x,finish.z-start.z
     table.insert(unionEdges,{a=start,b=finish,dx=dx,dz=dz,length2=dx*dx+dz*dz})
    end
   end
  end
 end
 split(oldEdges,rearEdges,rearInside)
 split(rearEdges,oldEdges,polygonInside)
 edges=unionEdges
 bounds.maxZ=rear.maxZ
 local g={points=points,bounds=bounds,boundaries=edges,rear=rear}
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
 function g.intervals(z)
  local hits={}
  for _,e in edges do
   if (e.a.z>z)~=(e.b.z>z) then table.insert(hits,e.a.x+(z-e.a.z)*e.dx/e.dz) end
  end
  table.sort(hits);local spans={}
  for i=1,#hits-1,2 do table.insert(spans,{hits[i],hits[i+1]}) end
  return spans
 end
 return g
end
return Geometry
