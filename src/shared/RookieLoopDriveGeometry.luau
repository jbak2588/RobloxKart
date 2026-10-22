-- Spatially indexed union of road/shoulder and pit corridors. No vehicle tuning.
local Layout=require(script.Parent.HubParkRookieLoopLayout)
local Geometry={}
function Geometry.create()
 local cells={};local cellSize=64
 local function key(x,z)return math.floor(x/cellSize)..':'..math.floor(z/cellSize)end
 local searchRadius=160 -- Covers up to 160 studs of grass runoff from track centerline
 local roadRadius=Layout.RoadWidth/2+Layout.KerbWidth -- 27 studs
 local pitRadius=Layout.Pit.width/2+6

 local function addRoute(route,radius)
  local points=Layout.sample(route)
  for i=1,#points-1 do
   local a,b=points[i],points[i+1];local dx,dz=b.x-a.x,b.z-a.z
   local e={x=a.x,z=a.z,dx=dx,dz=dz,length2=dx*dx+dz*dz,roadRadius=radius}
   for x=math.floor((math.min(a.x,b.x)-searchRadius)/cellSize),math.floor((math.max(a.x,b.x)+searchRadius)/cellSize)do
    for z=math.floor((math.min(a.z,b.z)-searchRadius)/cellSize),math.floor((math.max(a.z,b.z)+searchRadius)/cellSize)do
     local k=x..':'..z;cells[k]=cells[k]or {};table.insert(cells[k],e)
    end
   end
  end
 end

 addRoute(Layout.Segments,roadRadius)
 addRoute(Layout.Pit.segments,pitRadius)
 local g={}
 g.height=Layout.height
 g.normal=Layout.normal
 g.itemDropOffset=.12 -- .02 asphalt top + .08 Slick half-thickness + .02 clearance.
 function g.contact(x,z)
  local best,nx,nz=-1e6,1,0
  for _,e in cells[key(x,z)]or {}do
   local t=math.clamp(((x-e.x)*e.dx+(z-e.z)*e.dz)/e.length2,0,1)
   local dx,dz=x-e.x-t*e.dx,z-e.z-t*e.dz;local d=math.sqrt(dx*dx+dz*dz)
   local cl=e.roadRadius-d
   if cl>best then best=cl
    if d>1e-6 then nx,nz=dx/d,dz/d else local l=math.sqrt(e.length2);nx,nz=-e.dz/l,e.dx/l end
   end
  end
  return best,nx,nz
 end

 local spec = Layout.Island
 local function islandInside(x, z, margin)
  local m = margin or 0
  if x < spec.minX + m or x > spec.maxX - m or z < spec.minZ + m or z > spec.maxZ - m then return false end
  local c = spec.chamfer - m
  if (x - spec.minX) + (z - spec.minZ) < c then return false end
  if (spec.maxX - x) + (z - spec.minZ) < c then return false end
  if (x - spec.minX) + (spec.maxZ - z) < c then return false end
  if (spec.maxX - x) + (spec.maxZ - z) < c then return false end
  return true
 end

 function g.inside(x,z,margin)
  return islandInside(x, z, margin)
 end
 function g.crossesBoundary(x,z,toX,toZ)
  local n=math.max(1,math.ceil(math.sqrt((toX-x)^2+(toZ-z)^2)/16))
  for i=1,n do if not g.inside(x+(toX-x)*i/n,z+(toZ-z)*i/n,0)then return true end end
  return false
 end
 return g
end
return Geometry
