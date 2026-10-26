local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local env={Vector3=rb.Vector3,Vector2=rb.Vector2,CFrame=rb.CFrame,Color3=rb.Color3}
local G=luau.load(fs.readFile('src/shared/TrackGeometry.luau'),{environment=env})()
local R=luau.load(fs.readFile('src/shared/MetroCityLayout.luau'),{environment=env})()
local L=luau.load(fs.readFile('src/shared/TrackPlantingLayout.luau'))()
local radius=65.403183;local checks=0
local function check(v,m)assert(v,m);checks+=1 end
for id,geometry in {Track01='PracticeFigure8V1',Track01Race='PracticeCircuitV1',Track03='HardCircuitV1'}do
 local def=G.getDefinition(geometry);local samples=G.getCourse(def).Samples
 local a=L.plan(id,samples,def.RoadWidth,radius,R.roadDistance)
 local b=L.plan(id,samples,def.RoadWidth,radius,R.roadDistance)
 check(#a>=({Track01=25,Track01Race=35,Track03=60})[id],id..' preview grove density')
 for i,p in a do
  check(p.x==b[i].x and p.z==b[i].z and p.scale==b[i].scale,'stable planting across rematch')
  check(R.roadDistance(samples,p.x,p.z)-def.RoadWidth/2-radius*p.scale>=15.999,'whole maple canopy outside recovery shoulder')
  for j=1,i-1 do local q=a[j]
   check((p.x-q.x)^2+(p.z-q.z)^2>=(radius*(p.scale+q.scale)+7.999)^2,'staggered groves / no overlapping new canopies')
  end
 end
 print(id..': '..#a..' preview maples')
end
print('PASS '..checks..' planting density / determinism / route clearance checks')
