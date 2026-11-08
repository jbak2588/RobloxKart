-- Exact flat asphalt domain shared by race, item and tire contact checks.
local G = require(script.Parent:WaitForChild("EliphantGeometry"))
local Policy = {
 AsphaltCenterOffset = 0.045,
 AsphaltThickness = 0.035,
}
Policy.AsphaltTopOffset = Policy.AsphaltCenterOffset + Policy.AsphaltThickness / 2

local CELL=48
local cells={}
local function cell(x,z)return string.format("%d:%d",math.floor(x/CELL),math.floor(z/CELL))end
for _,t in G.Triangles do
 local a,b,c=table.unpack(t)
 for x=math.floor((math.min(a.X,b.X,c.X)-10)/CELL),math.floor((math.max(a.X,b.X,c.X)+10)/CELL) do
  for z=math.floor((math.min(a.Z,b.Z,c.Z)-10)/CELL),math.floor((math.max(a.Z,b.Z,c.Z)+10)/CELL) do
   local key=string.format("%d:%d",x,z)
   if not cells[key] then cells[key]={} end
   table.insert(cells[key],t)
  end
 end
end
local function signed(p,a,b)return (b.X-a.X)*(p.Z-a.Z)-(b.Z-a.Z)*(p.X-a.X)end
local function edgeDistance2(p,a,b)
 local ax,az=a.X-p.X,a.Z-p.Z
 local dx,dz=b.X-a.X,b.Z-a.Z
 local t=math.clamp(-(ax*dx+az*dz)/(dx*dx+dz*dz),0,1)
 return (ax+t*dx)^2+(az+t*dz)^2
end
function Policy.contains(p, margin)
 margin = margin or 0
 for _,t in cells[cell(p.X,p.Z)] or {} do
  local a,b,c=table.unpack(t)
  local x,y,z=signed(p,a,b),signed(p,b,c),signed(p,c,a)
  if (x>=0 and y>=0 and z>=0) or (x<=0 and y<=0 and z<=0) then return true end
  if margin>0 and math.min(edgeDistance2(p,a,b),edgeDistance2(p,b,c),edgeDistance2(p,c,a))<=margin^2 then return true end
 end
 return false
end

return table.freeze(Policy)
