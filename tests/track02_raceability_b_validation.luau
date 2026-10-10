-- Candidate B geometry/integrity, never claims natural driving or double BOOST.
local H=require('./helpers/track02_b_world');local G=H.geometry;local rb=H.rb
local fs,luau,process=require('@lune/fs'),require('@lune/luau'),require('@lune/process')
local count=0
local function check(v,m)assert(v,m);count+=1 end
local baseline=process.exec('git',{'show','10e59366eeaea9900cb2b2a0ca60ee611cf9b88a:src/shared/TrackGeometry.luau'});assert(baseline.ok)
local old=luau.load(baseline.stdout,{environment={Vector3=rb.Vector3,Vector2=rb.Vector2}})()
local function equal(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for k,v in a do if not equal(v,b[k]) then return false end end
 for k in b do if a[k]==nil then return false end end
 return true
end
for id,d in old.Definitions do check(equal(d,G.Definitions[id]),'unchanged exact legacy definition '..id) end
local d=G.Definitions.PrototypeCircuitV2B;local c=G.getCourse(d);local p=c.Samples;local n=#p
check(n==303 and math.abs(c.CenterlineLength-4240.853827)<.05,'supplied B length/sample count')
check(d.RoadWidth==48 and d.SampleSpacing==14 and #d.ControlPoints==24,'B contract')
for i=1,16 do check(d.ControlPoints[i]==old.Definitions.PrototypeCircuitV2.ControlPoints[i],'old P1-P16 '..i) end
check(#c.CheckpointSamples==6,'six gates retained')
check((c.StartPosition-rb.Vector3.new(-360,0,430)).Magnitude<.001,'start anchor')
check(c.StartTangent:Dot(rb.Vector3.new(0,0,-1))>.999,'finish/grid heading')
check((p[1]-p[n]).Unit:Dot((p[2]-p[1]).Unit)>.999,'continuous sampled start seam')
local minFinal,minAll=math.huge,math.huge
for i,v in p do
 check(v.X==v.X and v.Z==v.Z and math.abs(v.X)<2000 and math.abs(v.Z)<2000,'finite bounds')
 local a=v-p[(i-2)%n+1];local b=p[i%n+1]-v;local cross=a:Cross(b).Magnitude
 local r=if cross>1e-7 then a.Magnitude*b.Magnitude*(a+b).Magnitude/(2*cross) else 1e9
 check(r>24,'no sampled Road half-width offset fold at '..i)
 minAll=math.min(minAll,r);if (i-1)/n>.68 then minFinal=math.min(minFinal,r) end
end
check(minFinal>100,'expanded final sector radius >100')
local function intersect(a,b,c,d)
 local x,z=b.X-a.X,b.Z-a.Z;local u,v=d.X-c.X,d.Z-c.Z;local det=x*v-z*u
 if math.abs(det)<1e-8 then return false end
 local dx,dz=c.X-a.X,c.Z-a.Z;local t=(dx*v-dz*u)/det;local s=(dx*z-dz*x)/det
 return t>0 and t<1 and s>0 and s<1
end
for i=1,n do for j=i+2,n do if not(i==1 and j==n) then check(not intersect(p[i],p[i%n+1],p[j],p[j%n+1]),'no centerline crossing '..i..'/'..j) end end end
local world=H.build();check(#world.Road:GetChildren()==n,'actual Road segments')
for _,v in p do check(H.onRoad(world,v),'centerline legal corridor') end
for i,gate in c.CheckpointSamples do
 check(gate.Fraction>(if i==1 then 0 else c.CheckpointSamples[i-1].Fraction),'ordered CP')
 local actual=world.RaceTriggers:FindFirstChild('Checkpoint'..i)
 check((rb.Vector3.new(actual.Position.X,0,actual.Position.Z)-gate.Position).Magnitude<.001,'gate station')
 check(actual.CFrame.LookVector:Dot(gate.Tangent)>.999,'gate heading')
 check(actual.Size.X==68,'gate spans road')
 local shift=(gate.Position-old.getCourse(old.Definitions.PrototypeCircuitV2).CheckpointSamples[i].Position).Magnitude
 check(shift<(if i<=4 then .01 elseif i==5 then 3 else 161),'approved proposed station displacement '..i)
end
local catalog=luau.load(fs.readFile('src/shared/TrackCatalog.luau'),{environment={CFrame=rb.CFrame}})()
check(catalog.Entries.Track02.GeometryId=='PrototypeCircuitV2','production catalog still legacy; B diagnostic only')
check(catalog.Entries.Track02.TargetLaps==2 and catalog.Entries.Track02.MaxPlayers==4,'capacity/laps')
for _,slot in catalog.Entries.Track02.GridSlots do check(H.onRoad(world,slot.Position),'all four grid slots legal') end
local route=luau.load(fs.readFile('src/shared/RaceRouteProgress.luau'),{environment={Vector3=rb.Vector3}})()
for lap=1,2 do
 local state=route.new(c,48);local nextCP=1
 for k=0,1200 do
  local v=G.getSampleAtFraction(p,k/1200);local previous=nextCP
  nextCP=route.step(state,v,nextCP,H.onRoad(world,v));check(nextCP>=previous,'ordered lap '..lap)
 end
 check(nextCP==7,'all six checkpoints recovered lap '..lap)
end
local state=route.new(c,48);local cp=1
for k=1200,0,-1 do cp=route.step(state,G.getSampleAtFraction(p,k/1200),cp,true) end
check(cp==1,'reverse cannot award checkpoint')
print(string.format('PASS: %d V2B geometry/route checks; length %.3f / samples%d / final minR%.3f / global minR%.3f (upstream bottleneck retained); actual driving NOT VERIFIED',count,c.CenterlineLength,n,minFinal,minAll))
