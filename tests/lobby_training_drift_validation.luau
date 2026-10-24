local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local config=require('./helpers/gameplay_config')('src/shared/KartConfig.luau')
local slide=luau.load(fs.readFile('src/server/ArcadeDrift.luau'))()
local adapter=luau.load(fs.readFile('src/server/LobbyDriftSession.luau'),{environment={
 game={GetService=function()return {Shared={KartConfig='config'}}end},script={Parent={ArcadeDrift='slide'}},require=function(k)return if k=='config' then config else slide end}})()
local checks=0;local function check(v,m)checks+=1;assert(v,m)end
for _,steer in {-1,1} do
 local s=adapter.new();local cf=rb.CFrame.identity;local velocity=cf.LookVector*60;local yaw,speed=0,60;local maxSlip,boosts,reentries=0,0,0
 local previousBoost=false
 for i=1,420 do
  local now=i/60;local held=(now<2.5) or (now>=2.7 and now<5.2)
  adapter.input(s,held,now,true)
  local f,r=cf.LookVector,cf.RightVector;local a,l=velocity:Dot(f),velocity:Dot(r)
  local radius=config.TURN_RADIUS_LOW_SPEED+(config.TURN_RADIUS_HIGH_SPEED-config.TURN_RADIUS_LOW_SPEED)*math.clamp(speed/config.MAX_FORWARD_SPEED,0,1)
  local lat,turn,forward,budget=adapter.step(s,now,1/60,a,l,speed,1,steer,true,-s.steer*speed/radius,yaw,60)
  if s.boost and not previousBoost then boosts+=1 end
  if previousBoost and s.active then reentries+=1;check(not s.boost and s.boostEnd==0 and s.duration==0 and s.qualified==0,'fresh boost reentry resets all charge and bonus speed state')end
  previousBoost=s.boost
  speed=budget or speed;velocity=f*(forward or speed)+r*(lat or l*math.exp(-config.LATERAL_GRIP/60));yaw=turn or yaw
  -- The production service applies this final cap after the shared solver/fallback.
  if velocity.Magnitude>config.MINI_BOOST_MAX_SPEED then velocity=velocity.Unit*config.MINI_BOOST_MAX_SPEED end
  check(velocity.Magnitude<=100.001,'single planar speed budget')
  cf=cf*rb.CFrame.Angles(0,yaw/60,0)
  if s.active then maxSlip=math.max(maxSlip,math.abs(math.deg(math.atan2(velocity:Dot(cf.RightVector),velocity:Dot(cf.LookVector))))) end
 end
 check(maxSlip>35 and maxSlip<52,'approved rear slide reached in training')
 check(boosts==2 and reentries==1,'two qualified boosts and one cancellation/reentry')
 adapter.clear(s);check(not s.active and not s.boost and not s.slide.active and s.duration==0,'lifecycle clears transient training')
end
local s=adapter.new();s.boost=true;s.boostEnd=10;s.boostPress=0
adapter.input(s,true,1,true)
adapter.step(s,1,.05,60,0,60,1,.1,true,0,0,60)
check(s.boost,'weak steering preserves boost')
adapter.step(s,1.1,.05,60,0,60,1,1,false,0,0,60)
check(not s.boost and not s.active,'timeout clears without reward')
local source=fs.readFile('src/server/LobbyDriftSession.luau')
for _,forbidden in {'DataStore','RaceRecordService','EconomyService','RoundGuid','RaceLoadout'} do
 check(not source:find('require[^\n]*'..forbidden),'no economy/record owner imported')
end
print('PASS: '..checks..' actual shared solver training charge/boost/reentry/lifecycle checks')
-- Practice Nitro uses the shared 120/75/3s tuning and smooth 15 exit decay.
local nitro=adapter.new();local speed=60
for i=1,60 do
 local _,_,_,budget=adapter.step(nitro,i/60,1/60,speed,0,speed,1,0,true,0,0,60,true)
 local expected=math.min(config.NITRO_MAX_SPEED,speed+config.NITRO_ACCELERATION/60)
 check(math.abs(budget-expected)<1e-6,'Nitro ramps at 75 to at most 120');speed=budget
end
local _,_,_,exit=adapter.step(nitro,1.1,.05,100,0,100,1,0,true,0,0,60,false)
check(math.abs(exit-(100-config.NITRO_EXIT_DECELERATION*.05))<1e-6,'Nitro exit decays at 15')
check(config.NITRO_DURATION==3 and config.NITRO_MAX_SPEED==120,'same Nitro duration and maximum')
-- Off-track retains Nitro at 80% (96) and restores to 120 upon returning to track.
local offNitro=adapter.new();local nSpeed=120
for i=1,40 do
 local _,_,_,budget=adapter.step(offNitro,i/60,1/60,nSpeed,0,nSpeed,1,0,true,0,0,80,true,true)
 nSpeed=budget
end
check(math.abs(nSpeed-config.NITRO_MAX_SPEED*0.8)<1e-6,'off-track Nitro caps at 80% (96)')
for i=41,80 do
 local _,_,_,budget=adapter.step(offNitro,i/60,1/60,nSpeed,0,nSpeed,1,0,true,0,0,80,true,false)
 nSpeed=budget
end
check(math.abs(nSpeed-config.NITRO_MAX_SPEED)<1e-6,'returning to track restores full 120 Nitro speed')
-- Off-track retains Mini Boost at 80% (80) and restores to 100 upon returning to track.
local offBoost=adapter.new();offBoost.boost=true;offBoost.boostEnd=10;local bSpeed=100
for i=1,40 do
 local _,_,_,budget=adapter.step(offBoost,i/60,1/60,bSpeed,0,bSpeed,1,0,true,0,0,80,false,true)
 bSpeed=budget
end
check( offBoost.boost and math.abs(bSpeed-config.MINI_BOOST_MAX_SPEED*0.8)<1e-6,'off-track Mini Boost persists at 80% (80)')
for i=41,80 do
 local _,_,_,budget=adapter.step(offBoost,i/60,1/60,bSpeed,0,bSpeed,1,0,true,0,0,80,false,false)
 bSpeed=budget
end
check(offBoost.boost and math.abs(bSpeed-config.MINI_BOOST_MAX_SPEED)<1e-6,'returning to track restores full 100 Mini Boost speed')
print('PASS: practice Nitro ramp / maximum / smooth exit / off-track 80% retention checks')

local grass=adapter.new();grass.boost=true;grass.boostEnd=10
adapter.input(grass,true,0,true)
for i=1,60 do adapter.step(grass,i/60,1/60,80,0,80,1,1,true,0,0,80,false,true)end
check(grass.boost and grass.boostEnd==10 and not grass.active and not grass.ready,'grass preserves boost timer without reentering Drift or awarding another boost')
print('PASS: off-road held Drift cannot cancel active Mini Boost or award charge')
