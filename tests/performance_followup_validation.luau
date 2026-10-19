local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local n=0
local function check(v,label) assert(v,label);n+=1 end
local source=fs.readFile('src/server/RaceController.luau')
local block=source:sub(assert(source:find('local roadIndexes',1,true)),assert(source:find('local function isMovingThroughGate',1,true))-1)
local indexed=luau.load(block..'\nreturn isInsideRoadCorridor',{environment={RaceConfig={ROAD_CORRIDOR_MARGIN=2},Vector3=rb.Vector3}})()
local roads={}
for i=1,100 do
 local cf=rb.CFrame.new((i%10)*110-500,0,math.floor(i/10)*110-500)*rb.CFrame.Angles(0,i*.3,0)
 roads[i]={CFrame=cf,Size=rb.Vector3.new(48,1,70),Position=cf.Position}
end
local function brute(pos)
 for i,p in roads do local v=p.CFrame:PointToObjectSpace(pos)
  if math.abs(v.X)<=p.Size.X*.5+2 and math.abs(v.Z)<=p.Size.Z*.5+2 then return true,i end
 end
 return false,nil
end
for x=-600,650,13 do for z=-600,650,17 do
 local pos=rb.Vector3.new(x,20,z);local a,b=indexed(roads,pos);local c,d=brute(pos)
 check(a==c and b==d,'indexed corridor matches full scan')
end end
-- Sloped roads preserve the former local-Y-unbounded test.
local cf=rb.CFrame.new(-50,10,0)*rb.CFrame.Angles(.3,.4,.1)
roads={{CFrame=cf,Size=rb.Vector3.new(48,1,70),Position=cf.Position}}
for y=-500,500,10 do
 local pos=cf:PointToWorldSpace(rb.Vector3.new(25,y,36))
 local a,b=indexed(roads,pos);local c,d=brute(pos);check(a==c and b==d,'slope semantics')
end
local routeSource=fs.readFile('src/shared/RaceRouteProgress.luau')
local env={Vector3=rb.Vector3,Vector2=rb.Vector2}
local optimized=luau.load(routeSource,{environment=env})()
local reference=luau.load((routeSource:gsub('local bounded=previous~=nil and radius%*2%+1<count','local bounded=false')),{environment=env})()
local G=luau.load(fs.readFile('src/shared/TrackGeometry.luau'),{environment=env})()
for _,definition in G.Definitions do
 local course=G.getCourse(definition)
 if not course or not course.Samples then continue end
 for _,lateral in {0,12,-20} do
  local a,b=optimized.new(course,48),reference.new(course,48)
  local ca,cb=1,1
  for lap=1,2 do for i,p in course.Samples do
   local tangent=(course.Samples[i%#course.Samples+1]-p).Unit
   local pos=p+rb.Vector3.new(-tangent.Z,0,tangent.X)*lateral
   ca=optimized.step(a,pos,ca,true);cb=reference.step(b,pos,cb,true)
   check(ca==cb and a.previous==b.previous,'bounded route matches full projection')
  end end
 end
end
local B=luau.load(fs.readFile('src/shared/KDMPerformanceBuffer.luau'))()
check(B.allowed(false,11700555357,10768420544,127925465904803),'Mozzy diagnostic access')
check(B.allowed(false,11734277722,10768420544,127925465904803),'Synister diagnostic access')
check(not B.allowed(false,11736539305,10768420544,127925465904803),'old ID excluded')
check(not B.allowed(false,1,10768420544,127925465904803),'ordinary users excluded')
print('PASS: '..n..' spatial corridor, route equivalence and live tester checks')
