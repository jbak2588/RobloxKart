local fs, luau, rb, serde = require("@lune/fs"),require("@lune/luau"),require("@lune/roblox"),require("@lune/serde")
local config=require("./helpers/gameplay_config")("src/shared/KartConfig.luau")
local env={Vector3=rb.Vector3,Vector2=rb.Vector2}
local resolver=luau.load(fs.readFile("src/server/KDMStraightSpeedResolver.luau"),{environment=env})()
local geometry=luau.load(fs.readFile("src/shared/TrackGeometry.luau"),{environment=env})()
local count=0
local function check(v,label) assert(v,label);count+=1 end
local function path(headings)
 local samples={rb.Vector3.zero}
 for _,degrees in headings do
  local rad=math.rad(degrees)
  table.insert(samples,samples[#samples]+rb.Vector3.new(math.cos(rad)*10,0,math.sin(rad)*10))
 end
 -- Remote closure keeps synthetic local horizons distinct from lap boundary.
 table.insert(samples,rb.Vector3.new(-2000,0,2000))
 return resolver.precompute(samples,config,60)
end
local straight=path(table.create(40,0))
check(resolver.evaluate(straight,straight.samples[10],false),"straight")
local noise={} for i=1,40 do noise[i]=if i%2==0 then .01 else -.01 end
local noisy=path(noise);check(resolver.evaluate(noisy,noisy.samples[10],false),"numeric noise")
for _,headings in {{0,0,0,0,0,0,0,0,0,0,30,30,30,30,30,30,30,30,30,30},
 {0,0,0,0,0,0,0,0,0,0,180,180,180,180,180,180,180,180,180,180},
 {0,0,0,0,0,0,0,0,0,0,15,30,15,0,0,0,0,0,0,0}} do
 local course=path(headings);check(not resolver.evaluate(course,course.samples[6],false),"corner/hairpin/S reject")
end
local h={} for i=1,40 do h[i]=if i>=16 then 5 else 0 end
local hysteresis=path(h)
check(not resolver.evaluate(hysteresis,hysteresis.samples[10],false),"5deg no enter")
check(resolver.evaluate(hysteresis,hysteresis.samples[10],true),"5deg hold")
h[16]=8;local exit=path(h);check(not resolver.evaluate(exit,exit.samples[10],true),"8deg exit")
check(not resolver.evaluate(straight,straight.samples[#straight.samples],false),"wrap sees closure bend")
check(not resolver.evaluate(straight,rb.Vector3.new(1e6,0,1e6),true),"outside no scan/eligibility")
local state={};resolver.update(state,straight,straight.samples[10],1,true)
check(state.straightEligible,"state enters")
resolver.update(state,exit,exit.samples[10],1.05,true);check(state.straightEligible,"evaluation throttled")
resolver.update(state,exit,exit.samples[10],1.11,true);check(not state.straightEligible and state.straightExitActive,"state exits")
resolver.update(state,straight,straight.samples[10],2,false);check(not state.straightEligible and not state.straightExitActive,"safety resets")
local report={}
for _,id in {"PracticeCircuitV1","PrototypeCircuitV2","HardCircuitV1"} do
 local course=resolver.get(id,geometry,config)
 local eligible, runs, run, candidates, exitDistances={}, {},0,0,{}
 for i,p in course.samples do
  local yes,index,turn,distance,work=resolver.evaluate(course,p+(course.samples[i%#course.samples+1]-p)*.1,false)
  eligible[i]=yes; candidates=math.max(candidates,work)
  check(index==i or distance<.001,"nearest actual segment")
  check(not yes or turn<=4,"no enter false positives")
 end
 local total=0
 for i=1,#eligible do
  if eligible[i] then total+=1 end
  if eligible[i] and not eligible[(i-2)%#eligible+1] then
   local length,j=0,i
   repeat length+=course.lengths[j];j=j%#eligible+1 until not eligible[j] or j==i
   table.insert(runs,length)
  end
  if course.metrics[i]<=7 and course.metrics[i%#eligible+1]>7 then
   local distance,j=0,i%#eligible+1
   for _=1,#eligible do
    if course.turns[j]>.5 then break end
    distance+=course.lengths[j];j=j%#eligible+1
   end
   table.insert(exitDistances,distance)
  end
 end
 check(total>0 and total<#eligible,"mixed mask "..id)
 table.sort(runs)
 local sum=0 for _,d in exitDistances do sum+=d end
 report[id]={samples=#eligible,eligible=total,percent=100*total/#eligible,longest=runs[#runs],shortest=runs[1],
  maxCandidateSegments=candidates,falsePositiveSamples=0,meanExitToSharpVertex=if #exitDistances>0 then sum/#exitDistances else nil}
 print(id,serde.encode("json",report[id]))
end
local oldBalance=require("@lune/process").exec("git",{"show","7b3f668:src/shared/KDMGameplayBalance.luau"})
local old=luau.load(oldBalance.stdout)();local balance=luau.load(fs.readFile("src/shared/KDMGameplayBalance.luau"))()
for k,v in old do check(serde.encode("json",v)==serde.encode("json",balance[k]),"unchanged balance "..k) end
check(table.isfrozen(balance.SPEED.Straight),"nested freeze")
for _,path in {"src/shared/TrackGeometry.luau","src/shared/TrackCatalog.luau","src/server/TrackBuilder.luau",
 "src/server/RaceBotSteering.luau","src/client/HubUiController.luau","src/client/GarageUiController.luau",
 "src/client/KartInputController.luau","tests/fixtures/garage_phase1b_geometry.json","tests/fixtures/kart_v2_geometry.json"} do
 local baseline=require("@lune/process").exec("git",{"show","7b3f668:"..path})
 local normalize=if path=="src/client/HubUiController.luau" or path=="src/client/GarageUiController.luau"
  then require("./helpers/ui_palette_freeze") else function(s)return s:gsub("\r\n","\n")end
 check(baseline.ok and normalize(baseline.stdout)==normalize(fs.readFile(path)),"K1 frozen non-palette contract "..path)
end
if require("@lune/process").args[1]=="Report" then fs.writeDir("artifacts/r7-k1a");fs.writeFile("artifacts/r7-k1a/masks.json",serde.encode("json",report)) end
print("PASS: "..count.." straight resolver checks")
