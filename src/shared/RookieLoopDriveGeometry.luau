-- Spatially indexed union of road/shoulder and pit corridors. No vehicle tuning.
local Layout=require(script.Parent.HubParkRookieLoopLayout)
local Geometry={}
function Geometry.create()
 local cells={};local cellSize=64
 local function key(x,z)return math.floor(x/cellSize)..':'..math.floor(z/cellSize)end
 local function addRoute(route,radius)
  local points=Layout.sample(route)
  for i=1,#points-1 do
   local a,b=points[i],points[i+1];local dx,dz=b.x-a.x,b.z-a.z
   local e={x=a.x,z=a.z,dx=dx,dz=dz,length2=dx*dx+dz*dz,r=radius}
   for x=math.floor((math.min(a.x,b.x)-radius)/cellSize),math.floor((math.max(a.x,b.x)+radius)/cellSize)do
    for z=math.floor((math.min(a.z,b.z)-radius)/cellSize),math.floor((math.max(a.z,b.z)+radius)/cellSize)do
     local k=x..':'..z;cells[k]=cells[k]or {};table.insert(cells[k],e)
    end
   end
  end
 end
 addRoute(Layout.Segments,Layout.RoadWidth/2+Layout.KerbWidth+Layout.Shoulder)
 addRoute(Layout.Pit.segments,Layout.Pit.width/2+6)
 local g={}
 function g.contact(x,z)
  local best,nx,nz=-1e6,1,0
  for _,e in cells[key(x,z)]or {}do
   local t=math.clamp(((x-e.x)*e.dx+(z-e.z)*e.dz)/e.length2,0,1)
   local dx,dz=x-e.x-t*e.dx,z-e.z-t*e.dz;local d=math.sqrt(dx*dx+dz*dz)
   if e.r-d>best then best=e.r-d
    if d>1e-6 then nx,nz=dx/d,dz/d else local l=math.sqrt(e.length2);nx,nz=-e.dz/l,e.dx/l end
   end
  end
  return best,nx,nz
 end
 function g.inside(x,z,margin)return g.contact(x,z)>=(margin or 0)-1e-6 end
 function g.crossesBoundary(x,z,toX,toZ)
  local n=math.max(1,math.ceil(math.sqrt((toX-x)^2+(toZ-z)^2)/4))
  for i=1,n do if not g.inside(x+(toX-x)*i/n,z+(toZ-z)*i/n)then return true end end
  return false
 end
 return g
end
return Geometry
