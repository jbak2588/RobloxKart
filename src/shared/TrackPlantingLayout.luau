-- Deterministic staggered perimeter / infield groves from the real route.
local Layout={Targets={Track01=34,Track01Race=38,Track03=72}}
function Layout.plan(id,samples,width,radius,roadDistance,occupied)
 local target=assert(Layout.Targets[id]);local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
 for _,p in samples do minX=math.min(minX,p.X);maxX=math.max(maxX,p.X);minZ=math.min(minZ,p.Z);maxZ=math.max(maxZ,p.Z)end
 local candidates={};local n=0
 for z=minZ-95,maxZ+95,42 do for x=minX-95,maxX+95,42 do
  n+=1;local scale=.48+(n*37%31)/100
  local px,pz=x+math.sin(n*2.399963)*13,z+math.cos(n*1.618034)*13
  local distance=roadDistance(samples,px,pz)
  if distance>=width/2+16+radius*scale and distance<width/2+150 then
   table.insert(candidates,{x=px,z=pz,scale=scale,yaw=n*2.399963,order=(n*7919)%104729})
  end
 end end
 table.sort(candidates,function(a,b)return a.order<b.order end)
 local result={}
 local neighbors=table.clone(occupied or {})
 for _,p in candidates do
  local clear=true
  for _,q in neighbors do if (p.x-q.x)^2+(p.z-q.z)^2<(radius*(p.scale+q.scale)+8)^2 then clear=false;break end end
  if clear then table.insert(result,p);table.insert(neighbors,p);if #result==target then break end end
 end
 return result
end
return Layout
