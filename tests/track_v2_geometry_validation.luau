-- Static raceability envelope; does not substitute for actual mobile Drift acceptance.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local g = luau.load(fs.readFile("src/shared/TrackGeometry.luau"), {environment={Vector3=rb.Vector3,Vector2=rb.Vector2}})()
local config = require("./helpers/gameplay_config")("src/shared/KartConfig.luau")
local checks = 0
local function check(value, label) assert(value, label); checks += 1 end
local d = g.Definitions.HardCircuitV1
local c = g.getCourse(d)
local p = c.Samples
local n = #p
check(d.RoadWidth==48 and d.SampleSpacing==14,"approved width/spacing")
local turns = {}
for i, point in p do
 local prev, next = p[(i-2)%n+1], p[i%n+1]
 local arriving, leaving = (point-prev).Unit, (next-point).Unit
 local distance = (next-point).Magnitude
 check(point.X==point.X and point.Z==point.Z,"finite point")
 check(distance>d.SampleSpacing*0.9 and distance<d.SampleSpacing*1.1,"uniform closed sample length")
 check(g.getTangentAtFraction(p,(i-1)/n).Magnitude>0.99,"nonzero unit tangent")
 turns[i]=math.acos(math.clamp(arriving:Dot(leaving),-1,1))
end
-- Exact segment crossings, including closure (not only control-point inspection).
local function cross(a,b) return a.X*b.Z-a.Z*b.X end
for i,a in p do
 local b=p[i%n+1]
 for j=i+2,n do
  if not (i==1 and j==n) then
   local u,v=p[j],p[j%n+1]
   local r,s=b-a,v-u
   local denom=cross(r,s)
   local intersects=false
   if math.abs(denom)>1e-8 then
    local t,q=cross(u-a,s)/denom,cross(u-a,r)/denom
    intersects=t>=0 and t<=1 and q>=0 and q<=1
   end
   check(not intersects,"sampled centerline self intersection")
   local along=math.min(j-i,n-(j-i))*d.SampleSpacing
   if along>d.RoadWidth*4 then
    check((u-a).Magnitude>d.RoadWidth+8,"nonadjacent road ribbons do not overlap")
   end
  end
 end
end
check(#c.CheckpointSamples==6,"six checkpoints")
-- Evaluate named corridors against actual production samples, never control-point chords.
check(#d.NitroStraights==2,"two distinct named Nitro corridors")
local corridors={}
for id,straight in d.NitroStraights do
 local first=math.round(straight.StartFraction*n)+1
 local last=math.round(straight.EndFraction*n)+1
 local length,heading=0,0
 for index=first,last-1 do
  length+=(p[index+1]-p[index]).Magnitude
  heading+=turns[index]
 end
 check(length>=330 and length<=450,"Full Nitro length 330..450")
 check(heading<=math.rad(10),"Full Nitro heading change <=10 degrees")
 for index=last,last+4 do check(turns[index]<math.rad(1),"70-stud low-curvature setup beyond Nitro corridor") end
 table.insert(corridors,{first=first,last=last})
 print(string.format("Nitro %s: samples %d..%d length %.2f heading %.3f setup 70 studs",if id==1 then "A" else "B",first,last,length,math.deg(heading)))
end
check(corridors[2].first-corridors[1].last>n*.5,"Nitro corridors are separate physical track sections")
-- Baseline definitions/catalog entries must remain byte-equivalent after removing Hard additions.
local process=require("@lune/process")
local baseline=process.exec("git",{"show","647be04b28e63f23e2826cfb0bc1e50b9cad2232:src/shared/TrackGeometry.luau"})
assert(baseline.ok)
local legacy=luau.load(baseline.stdout,{environment={Vector3=rb.Vector3,Vector2=rb.Vector2}})()
local function definitionSignature(def)
 local rows={tostring(def.RoadWidth),tostring(def.SampleSpacing)}
 for _,point in def.ControlPoints or {} do table.insert(rows,tostring(point)) end
 for _,fraction in def.CheckpointFractions or {} do table.insert(rows,tostring(fraction)) end
 return table.concat(rows,"|")
end
for id,def in legacy.Definitions do
 check(definitionSignature(g.Definitions[id])==definitionSignature(def),"exact unchanged baseline geometry "..id)
end
check(#g.Definitions.PrototypeCircuitV2.ControlPoints==20,"Legacy retains exactly 20 controls")
local catalogBaseline=process.exec("git",{"show","647be04b28e63f23e2826cfb0bc1e50b9cad2232:src/shared/TrackCatalog.luau"})
assert(catalogBaseline.ok)
local baselineCatalog=luau.load(catalogBaseline.stdout,{environment={CFrame=rb.CFrame}})()
local currentCatalog=luau.load(fs.readFile("src/shared/TrackCatalog.luau"),{environment={CFrame=rb.CFrame}})()
local function valueSignature(value)
 if type(value)~="table" then return tostring(value) end
 local keys={};for key in value do table.insert(keys,key) end
 table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local parts={};for _,key in keys do table.insert(parts,tostring(key).."="..valueSignature(value[key]))end
 return "{"..table.concat(parts,";").."}"
end
for id,entry in baselineCatalog.Entries do local gameplay=table.clone(currentCatalog.Entries[id]); gameplay.PreviewImageAssetId=nil; if id=="Track02" then gameplay.MatchType=entry.MatchType; gameplay.MaxPlayers=entry.MaxPlayers; gameplay.TargetLaps=entry.TargetLaps end; check(valueSignature(entry)==valueSignature(gameplay),"unchanged catalog gameplay entry "..id) end
local serde=require("@lune/serde")
print("Legacy geometry SHA256",serde.hash("sha256",definitionSignature(g.Definitions.PrototypeCircuitV2)))

local previous=0
for _, cp in c.CheckpointSamples do
 check(cp.Fraction>previous and cp.Fraction<1,"ordered checkpoint fractions")
 check((cp.Fraction-previous)*c.CenterlineLength>config.MAX_FORWARD_SPEED,"checkpoint separation over normal one-second travel")
 check((cp.Position-g.getSampleAtFraction(p,cp.Fraction)).Magnitude<0.001,"checkpoint on centerline")
 previous=cp.Fraction
end
-- Final 250 studs are an alignment corridor, independent of Nitro tuning.
for offset=-math.ceil(250/d.SampleSpacing),0 do
 check(turns[offset%n+1]<math.atan(d.SampleSpacing/700),"finish recovery alignment corridor")
end
local zones={}
local i=1
while i<=n do
 if turns[i]>=math.atan(d.SampleSpacing/350) then
  local first=i
  local function sign(index)
   local a=(p[index]-p[(index-2)%n+1]).Unit
   local b=(p[index%n+1]-p[index]).Unit
   return if a:Cross(b).Y>0 then "LEFT" else "RIGHT"
  end
  local side=sign(i)
  while i<=n and turns[i]>=math.atan(d.SampleSpacing/350) and sign(i)==side do i+=1 end
  local angle=0 local minimum=math.huge local radii={}
  for k=first,i-1 do
   angle+=turns[k]
   local radius=(c.CenterlineLength/n)/turns[k]
   minimum=math.min(minimum,radius);table.insert(radii,radius)
  end
  if (i-first)*d.SampleSpacing>60 and angle>math.rad(35) then
   table.sort(radii)
   local half=math.floor(#radii/2)
   local median=if #radii%2==0 then (radii[half]+radii[half+1])/2 else radii[half+1]
   table.insert(zones,{first=first,last=i-1,side=side,minimum=minimum,median=median})
  end
 else i+=1 end
end
local function zoneAt(fraction)
 local index=fraction*n+1
 for _,zone in zones do if index>=zone.first and index<=zone.last then return zone end end
 error("missing semantic corner at "..fraction)
end
check(#d.ControlPoints<=80 and #d.ControlPoints>=40,"compact production control budget")
check(c.CenterlineLength>=5600 and c.CenterlineLength<=6300,"two-lap track length budget")
check(n>=400 and n<=450,"sample budget")
local globalMinimum=math.huge
for _,turn in turns do globalMinimum=math.min(globalMinimum,(c.CenterlineLength/n)/math.max(turn,1e-9)) end
check(globalMinimum>=70,"refined global minimum radius preserved")
local zone2,zone8=zoneAt(.190),zoneAt(.523)
check(zone2.side=="LEFT" and zone2.minimum>=72 and zone2.median>=90,"refined Zone 2 envelope")
check(zone8.side=="LEFT" and zone8.minimum>=70 and zone8.median>=85,"refined Zone 8 envelope")
local a,b,candidateC=zoneAt(.473),zoneAt(.190),zoneAt(.683)
check(a.side=="RIGHT" and b.side=="LEFT" and candidateC.side=="RIGHT","three mixed-direction major Drift candidates")
check(a.minimum>=80 and candidateC.minimum>=80,"major right candidates retain broad radius cores")
check((c.StartPosition-rb.Vector3.new(-360,0,430)).Magnitude<.01,"original grid/start position")
check(c.StartTangent:Dot(rb.Vector3.new(0,0,-1))>.999,"northbound grid/start tangent")
local catalog=luau.load(fs.readFile("src/shared/TrackCatalog.luau"),{environment={CFrame=rb.CFrame}})()
check(catalog.Entries.Track01.TargetLaps==1 and catalog.Entries.Track01Race.TargetLaps==2 and catalog.Entries.Track02.TargetLaps==2 and catalog.Entries.Track03.TargetLaps==2,"production lap contracts")
check(catalog.Entries.Track02.MatchType=="PUBLIC_RACE" and catalog.Entries.Track02.DisplayName=="Prototype Circuit V2","V2 route identity unchanged")
for _,slot in catalog.Entries.Track03.GridSlots do
 local delta=slot.Position-c.StartPosition
 check(delta:Dot(c.StartTangent)<0,"grid behind finish line")
 check(math.abs(delta:Dot(rb.Vector3.new(-c.StartTangent.Z,0,c.StartTangent.X)))<d.RoadWidth/2-3,"grid inside road corridor")
 check(slot.LookVector:Dot(c.StartTangent)>.999,"grid forward matches start")
end
-- Exact segment distance / boundary crossings, including opposite ribbon edges.
local function pointDistance(q,a,b)
 local ab=b-a
 local t=math.clamp((q-a):Dot(ab)/ab:Dot(ab),0,1)
 return (q-(a+ab*t)).Magnitude
end
local function segmentDistance(a,b,u,v)
 local r,s=b-a,v-u local denom=cross(r,s)
 if math.abs(denom)>1e-8 then
  local t,q=cross(u-a,s)/denom,cross(u-a,r)/denom
  if t>=0 and t<=1 and q>=0 and q<=1 then return 0 end
 end
 return math.min(pointDistance(a,u,v),pointDistance(b,u,v),pointDistance(u,a,b),pointDistance(v,a,b))
end
local clearance=math.huge
for j=1,n do for k=j+2,n do
 if math.min(k-j,n-k+j)*c.CenterlineLength/n>140 then
  clearance=math.min(clearance,segmentDistance(p[j],p[j%n+1],p[k],p[k%n+1]))
 end
end end
check(clearance>=95,"exact nonadjacent centerline clearance")
for _,width in {24,27.65} do
 local rings={}
 for _,side in {-1,1} do
  local ring={}
  for index,point in p do
   local tangent=(p[index%n+1]-p[(index-2)%n+1]).Unit
   ring[index]=point+rb.Vector3.new(-tangent.Z,0,tangent.X)*width*side
  end
  table.insert(rings,ring)
 end
 for _,ring in rings do for j=1,n do for k=j+2,n do
  if not (j==1 and k==n) then check(segmentDistance(ring[j],ring[j%n+1],ring[k],ring[k%n+1])>1e-5,"road/kerb self crossing") end
 end end end
 for j=1,n do for k=1,n do check(segmentDistance(rings[1][j],rings[1][j%n+1],rings[2][k],rings[2][k%n+1])>1e-5,"opposite road/kerb edges crossing") end end
end
print(string.format("PASS: %d Hard geometry checks; length %.2f; samples %d; corners %d; clearance %.2f; min R%.2f",checks,c.CenterlineLength,n,#zones,clearance,globalMinimum))
-- Static raceability envelope; does not substitute for actual mobile Drift acceptance.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local g = luau.load(fs.readFile("src/shared/TrackGeometry.luau"), {environment={Vector3=rb.Vector3,Vector2=rb.Vector2}})()
local config = require("./helpers/gameplay_config")("src/shared/KartConfig.luau")
local checks = 0
local function check(value, label) assert(value, label); checks += 1 end
local d = g.Definitions.HardCircuitV1
local c = g.getCourse(d)
local p = c.Samples
local n = #p
check(d.RoadWidth==48 and d.SampleSpacing==14,"approved width/spacing")
local turns = {}
for i, point in p do
 local prev, next = p[(i-2)%n+1], p[i%n+1]
 local arriving, leaving = (point-prev).Unit, (next-point).Unit
 local distance = (next-point).Magnitude
 check(point.X==point.X and point.Z==point.Z,"finite point")
 check(distance>d.SampleSpacing*0.9 and distance<d.SampleSpacing*1.1,"uniform closed sample length")
 check(g.getTangentAtFraction(p,(i-1)/n).Magnitude>0.99,"nonzero unit tangent")
 turns[i]=math.acos(math.clamp(arriving:Dot(leaving),-1,1))
end
-- Exact segment crossings, including closure (not only control-point inspection).
local function cross(a,b) return a.X*b.Z-a.Z*b.X end
for i,a in p do
 local b=p[i%n+1]
 for j=i+2,n do
  if not (i==1 and j==n) then
   local u,v=p[j],p[j%n+1]
   local r,s=b-a,v-u
   local denom=cross(r,s)
   local intersects=false
   if math.abs(denom)>1e-8 then
    local t,q=cross(u-a,s)/denom,cross(u-a,r)/denom
    intersects=t>=0 and t<=1 and q>=0 and q<=1
   end
   check(not intersects,"sampled centerline self intersection")
   local along=math.min(j-i,n-(j-i))*d.SampleSpacing
   if along>d.RoadWidth*4 then
    check((u-a).Magnitude>d.RoadWidth+8,"nonadjacent road ribbons do not overlap")
   end
  end
 end
end
check(#c.CheckpointSamples==6,"six checkpoints")
-- Evaluate named corridors against actual production samples, never control-point chords.
check(#d.NitroStraights==2,"two distinct named Nitro corridors")
local corridors={}
for id,straight in d.NitroStraights do
 local first=math.round(straight.StartFraction*n)+1
 local last=math.round(straight.EndFraction*n)+1
 local length,heading=0,0
 for index=first,last-1 do
  length+=(p[index+1]-p[index]).Magnitude
  heading+=turns[index]
 end
 check(length>=330 and length<=450,"Full Nitro length 330..450")
 check(heading<=math.rad(10),"Full Nitro heading change <=10 degrees")
 for index=last,last+4 do check(turns[index]<math.rad(1),"70-stud low-curvature setup beyond Nitro corridor") end
 table.insert(corridors,{first=first,last=last})
 print(string.format("Nitro %s: samples %d..%d length %.2f heading %.3f setup 70 studs",if id==1 then "A" else "B",first,last,length,math.deg(heading)))
end
check(corridors[2].first-corridors[1].last>n*.5,"Nitro corridors are separate physical track sections")
-- Baseline definitions/catalog entries must remain byte-equivalent after removing Hard additions.
local process=require("@lune/process")
local baseline=process.exec("git",{"show","647be04b28e63f23e2826cfb0bc1e50b9cad2232:src/shared/TrackGeometry.luau"})
assert(baseline.ok)
local legacy=luau.load(baseline.stdout,{environment={Vector3=rb.Vector3,Vector2=rb.Vector2}})()
local function definitionSignature(def)
 local rows={tostring(def.RoadWidth),tostring(def.SampleSpacing)}
 for _,point in def.ControlPoints or {} do table.insert(rows,tostring(point)) end
 for _,fraction in def.CheckpointFractions or {} do table.insert(rows,tostring(fraction)) end
 return table.concat(rows,"|")
end
for id,def in legacy.Definitions do
 check(definitionSignature(g.Definitions[id])==definitionSignature(def),"exact unchanged baseline geometry "..id)
end
check(#g.Definitions.PrototypeCircuitV2.ControlPoints==20,"Legacy retains exactly 20 controls")
local catalogBaseline=process.exec("git",{"show","647be04b28e63f23e2826cfb0bc1e50b9cad2232:src/shared/TrackCatalog.luau"})
assert(catalogBaseline.ok)
local baselineCatalog=luau.load(catalogBaseline.stdout,{environment={CFrame=rb.CFrame}})()
local currentCatalog=luau.load(fs.readFile("src/shared/TrackCatalog.luau"),{environment={CFrame=rb.CFrame}})()
local function valueSignature(value)
 if type(value)~="table" then return tostring(value) end
 local keys={};for key in value do table.insert(keys,key) end
 table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local parts={};for _,key in keys do table.insert(parts,tostring(key).."="..valueSignature(value[key]))end
 return "{"..table.concat(parts,";").."}"
end
for id,entry in baselineCatalog.Entries do local gameplay=table.clone(currentCatalog.Entries[id]); gameplay.PreviewImageAssetId=nil; if id=="Track02" then gameplay.MatchType=entry.MatchType; gameplay.MaxPlayers=entry.MaxPlayers; gameplay.TargetLaps=entry.TargetLaps end; check(valueSignature(entry)==valueSignature(gameplay),"unchanged catalog gameplay entry "..id) end
local serde=require("@lune/serde")
print("Legacy geometry SHA256",serde.hash("sha256",definitionSignature(g.Definitions.PrototypeCircuitV2)))

local previous=0
for _, cp in c.CheckpointSamples do
 check(cp.Fraction>previous and cp.Fraction<1,"ordered checkpoint fractions")
 check((cp.Fraction-previous)*c.CenterlineLength>config.MAX_FORWARD_SPEED,"checkpoint separation over normal one-second travel")
 check((cp.Position-g.getSampleAtFraction(p,cp.Fraction)).Magnitude<0.001,"checkpoint on centerline")
 previous=cp.Fraction
end
-- Final 250 studs are an alignment corridor, independent of Nitro tuning.
for offset=-math.ceil(250/d.SampleSpacing),0 do
 check(turns[offset%n+1]<math.atan(d.SampleSpacing/700),"finish recovery alignment corridor")
end
local zones={}
local i=1
while i<=n do
 if turns[i]>=math.atan(d.SampleSpacing/350) then
  local first=i
  local function sign(index)
   local a=(p[index]-p[(index-2)%n+1]).Unit
   local b=(p[index%n+1]-p[index]).Unit
   return if a:Cross(b).Y>0 then "LEFT" else "RIGHT"
  end
  local side=sign(i)
  while i<=n and turns[i]>=math.atan(d.SampleSpacing/350) and sign(i)==side do i+=1 end
  local angle=0 local minimum=math.huge local radii={}
  for k=first,i-1 do
   angle+=turns[k]
   local radius=(c.CenterlineLength/n)/turns[k]
   minimum=math.min(minimum,radius);table.insert(radii,radius)
  end
  if (i-first)*d.SampleSpacing>60 and angle>math.rad(35) then
   table.sort(radii)
   local half=math.floor(#radii/2)
   local median=if #radii%2==0 then (radii[half]+radii[half+1])/2 else radii[half+1]
   table.insert(zones,{first=first,last=i-1,side=side,minimum=minimum,median=median})
  end
 else i+=1 end
end
local function zoneAt(fraction)
 local index=fraction*n+1
 for _,zone in zones do if index>=zone.first and index<=zone.last then return zone end end
 error("missing semantic corner at "..fraction)
end
check(#d.ControlPoints<=80 and #d.ControlPoints>=40,"compact production control budget")
check(c.CenterlineLength>=5600 and c.CenterlineLength<=6300,"two-lap track length budget")
check(n>=400 and n<=450,"sample budget")
local globalMinimum=math.huge
for _,turn in turns do globalMinimum=math.min(globalMinimum,(c.CenterlineLength/n)/math.max(turn,1e-9)) end
check(globalMinimum>=70,"refined global minimum radius preserved")
local zone2,zone8=zoneAt(.190),zoneAt(.523)
check(zone2.side=="LEFT" and zone2.minimum>=72 and zone2.median>=90,"refined Zone 2 envelope")
check(zone8.side=="LEFT" and zone8.minimum>=70 and zone8.median>=85,"refined Zone 8 envelope")
local a,b,candidateC=zoneAt(.473),zoneAt(.190),zoneAt(.683)
check(a.side=="RIGHT" and b.side=="LEFT" and candidateC.side=="RIGHT","three mixed-direction major Drift candidates")
check(a.minimum>=80 and candidateC.minimum>=80,"major right candidates retain broad radius cores")
check((c.StartPosition-rb.Vector3.new(-360,0,430)).Magnitude<.01,"original grid/start position")
check(c.StartTangent:Dot(rb.Vector3.new(0,0,-1))>.999,"northbound grid/start tangent")
local catalog=luau.load(fs.readFile("src/shared/TrackCatalog.luau"),{environment={CFrame=rb.CFrame}})()
check(catalog.Entries.Track01.TargetLaps==1 and catalog.Entries.Track01Race.TargetLaps==2 and catalog.Entries.Track02.TargetLaps==2 and catalog.Entries.Track03.TargetLaps==2,"production lap contracts")
check(catalog.Entries.Track02.MatchType=="PUBLIC_RACE" and catalog.Entries.Track02.DisplayName=="Prototype Circuit V2","V2 route identity unchanged")
for _,slot in catalog.Entries.Track03.GridSlots do
 local delta=slot.Position-c.StartPosition
 check(delta:Dot(c.StartTangent)<0,"grid behind finish line")
 check(math.abs(delta:Dot(rb.Vector3.new(-c.StartTangent.Z,0,c.StartTangent.X)))<d.RoadWidth/2-3,"grid inside road corridor")
 check(slot.LookVector:Dot(c.StartTangent)>.999,"grid forward matches start")
end
-- Exact segment distance / boundary crossings, including opposite ribbon edges.
local function pointDistance(q,a,b)
 local ab=b-a
 local t=math.clamp((q-a):Dot(ab)/ab:Dot(ab),0,1)
 return (q-(a+ab*t)).Magnitude
end
local function segmentDistance(a,b,u,v)
 local r,s=b-a,v-u local denom=cross(r,s)
 if math.abs(denom)>1e-8 then
  local t,q=cross(u-a,s)/denom,cross(u-a,r)/denom
  if t>=0 and t<=1 and q>=0 and q<=1 then return 0 end
 end
 return math.min(pointDistance(a,u,v),pointDistance(b,u,v),pointDistance(u,a,b),pointDistance(v,a,b))
end
local clearance=math.huge
for j=1,n do for k=j+2,n do
 if math.min(k-j,n-k+j)*c.CenterlineLength/n>140 then
  clearance=math.min(clearance,segmentDistance(p[j],p[j%n+1],p[k],p[k%n+1]))
 end
end end
check(clearance>=95,"exact nonadjacent centerline clearance")
for _,width in {24,27.65} do
 local rings={}
 for _,side in {-1,1} do
  local ring={}
  for index,point in p do
   local tangent=(p[index%n+1]-p[(index-2)%n+1]).Unit
   ring[index]=point+rb.Vector3.new(-tangent.Z,0,tangent.X)*width*side
  end
  table.insert(rings,ring)
 end
 for _,ring in rings do for j=1,n do for k=j+2,n do
  if not (j==1 and k==n) then check(segmentDistance(ring[j],ring[j%n+1],ring[k],ring[k%n+1])>1e-5,"road/kerb self crossing") end
 end end end
 for j=1,n do for k=1,n do check(segmentDistance(rings[1][j],rings[1][j%n+1],rings[2][k],rings[2][k%n+1])>1e-5,"opposite road/kerb edges crossing") end end
end
print(string.format("PASS: %d Hard geometry checks; length %.2f; samples %d; corners %d; clearance %.2f; min R%.2f",checks,c.CenterlineLength,n,#zones,clearance,globalMinimum))

check(catalog.Entries.Track03.MaxPlayers==4 and #catalog.Entries.Track03.GridSlots==4,"Hard exactly four active grids")
for index,a in catalog.Entries.Track03.GridSlots do
 for other=index+1,#catalog.Entries.Track03.GridSlots do
  local delta=catalog.Entries.Track03.GridSlots[other].Position-a.Position
  check(math.abs(delta:Dot(c.StartTangent))>=16 or math.abs(delta:Dot(rb.Vector3.new(-c.StartTangent.Z,0,c.StartTangent.X)))>=12,"Hard kart grid envelopes do not overlap")
 end
end
print("PASS: Hard grid capacity and nonoverlap")
