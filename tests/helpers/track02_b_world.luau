-- Real Builder under the existing Roblox mock boundary, never a replacement geometry.
local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local source=fs.readFile('tests/track_environment_validation.luau')
local boundary=assert(source:find('local prototype=object("Folder")',1,true),'existing mock boundary moved')
local loaded=luau.load(source:sub(1,boundary-1)..'\nreturn {geometry=geometry,builder=builder,object=object,frames=frames}\n')()
local H={geometry=loaded.geometry,rb=rb}
function H.build(id)
 local track={Id='Track02',GeometryId=id or 'PrototypeCircuitV2B'}
 local world=loaded.builder.build(loaded.object('Folder'),track,0)
 -- Existing lightweight mocks require explicit named-child convenience properties.
 for _,child in world:GetChildren() do world[child.Name]=child end
 return world
end
function H.quad(part)
 local half=part.Size*.5;local p={}
 for _,xz in {{-1,-1},{-1,1},{1,1},{1,-1}} do
  local q=part.CFrame:PointToWorldSpace(rb.Vector3.new(half.X*xz[1],0,half.Z*xz[2]))
  table.insert(p,rb.Vector2.new(q.X,q.Z))
 end
 return p
end
function H.overlap(a,b)
 for _,p in {a,b} do
  for i,v in p do
   local e=p[i%4+1]-v;local axis=rb.Vector2.new(-e.Y,e.X)
   local amin,amax,bmin,bmax=math.huge,-math.huge,math.huge,-math.huge
   for _,v in a do local q=v:Dot(axis);amin=math.min(amin,q);amax=math.max(amax,q) end
   for _,v in b do local q=v:Dot(axis);bmin=math.min(bmin,q);bmax=math.max(bmax,q) end
   if amax<bmin or bmax<amin then return false end
  end
 end
 return true
end
local function pointDistance(p,a,b)
 local v=b-a;return (p-a-v*math.clamp((p-a):Dot(v)/v:Dot(v),0,1)).Magnitude
end
function H.gap(a,b)
 if H.overlap(a,b) then return 0 end
 local d=math.huge
 for i,p in a do for j,q in b do d=math.min(d,pointDistance(p,q,b[j%4+1]),pointDistance(q,p,a[i%4+1])) end end
 return d
end
function H.onRoad(world,p)
 for _,r in world.Road:GetChildren() do
  local q=r.CFrame:PointToObjectSpace(p)
  if math.abs(q.X)<=r.Size.X*.5+8 and math.abs(q.Z)<=r.Size.Z*.5+8 then return true end
 end
 return false
end
return H
