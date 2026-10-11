local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local function load(path,env)return luau.load(fs.readFile(path),{environment=env or {Vector3=rb.Vector3,Vector2=rb.Vector2}})() end
local G=load('src/shared/TrackGeometry.luau');local R=load('src/shared/RaceRouteProgress.luau');local S=load('src/shared/KDMProgressionSchema.luau');local O=load('src/server/OfficialRaceRecords.luau')
local course=G.getCourse(G.Definitions.PrototypeCircuitV2B);local points=course.Samples
local player={UserId=11700555357,GetAttribute=function(_,k)return if k=='RaceState' then 'FINISHED' else false end}
local checks=0
for _,case in {{offset=0},{offset=12},{offset=-12},{offset=20},{offset=-20},{offset=12,fault='teleport'}} do
 local offset=case.offset
 local collector=O.new(S,{utcMs=function()return 1791650000000 end});collector.begin({RoundGuid='12345678-1234-1234-1234-000000000001',TrackId='Track02',GeometryId='PrototypeCircuitV2B',RulesetId='KDM_R8A3_RULES_V1',diagnostic=false,roster={{UserId=player.UserId,IsBot=false}}},{player},6,2,course.CenterlineLength);collector.start(player,0)
 local now=0;local last=nil;local valid={}
 for lap=1,2 do
  local route=R.new(course,48);local nextCP=1;local begin=now
  for i=1,#points do
   local a,b=points[i],points[i%#points+1];local tangent=(b-a).Unit;local normal=rb.Vector3.new(-tangent.Z,0,tangent.X)
   for step=0,9 do
    local pos=a:Lerp(b,step/10)+normal*offset
    if case.fault=='teleport' and lap==1 and i==100 and step==0 then pos+=rb.Vector3.new(500,0,500) end
    local dt=if last then math.max(1/60,(pos-last).Magnitude/70) else 1/60;if case.fault=='teleport' and lap==1 and i==100 and step<=1 then dt=1/60 end;now+=dt;last=pos
    nextCP=R.step(route,pos,nextCP,true);collector.sample(player,now,pos,route.previous);collector.checkpoints(player,nextCP)
   end
  end
  valid[lap]=collector.lap(player,now,now-begin)
 end
 local op=collector.finish(player,{positionFinalized=true,position=1,totalTime=now});assert(op and op.race.eligible==(case.fault==nil),'normal inside-line false rejection or teleport accepted '..offset);assert(#op.race.laps==2,'lap array retained');checks+=2
end


print('PASS: '..checks..' actual V2B centerline/inside/outside full-route snapshots and per-frame teleport rejection checks')
