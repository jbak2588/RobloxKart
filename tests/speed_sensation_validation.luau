local fs,luau,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/serde')
local speed=luau.load(fs.readFile('src/shared/KDMSpeedSensation.luau'))()
local n=0
local function check(v,label)assert(v,label);n+=1 end
local function fov(v,mini,nitro,enabled,off)
 local tier,alpha=speed.resolve(v,mini,nitro,enabled,off)
 return speed.targetFov(75,tier,alpha),tier,alpha
end
for _,v in {0,30,55,60,70,80,100,-20} do
 for _,state in {{false,false},{true,false},{false,true},{true,true}} do
  local f,t=fov(v,state[1],state[2],true,false)
  local expected=if v<0 then 'NONE' elseif state[2] then 'NITRO' elseif state[1] then 'MINI_BOOST' elseif v>55 then 'HIGH_SPEED' else 'NONE'
  check(t==expected,'tier state/speed '..v..' '..t)
  check(f>=75 and f<=85,'bounded FOV')
  check(select(2,fov(v,state[1],state[2],false,false))=='NONE','locked/non-racing suppressed')
  check(select(2,fov(v,state[1],state[2],true,true))=='NONE','off-track suppresses stale flags')
 end
end
check(fov(70,false,false,true,false)<fov(80,false,false,true,false),'Straight80 greater than normal70')
check(fov(100,true,false,true,false)==81 and fov(100,false,true,true,false)==85,'equal physical speed different boost state')
local prior=75
for v=0,120 do local f=fov(v,false,false,true,false);check(f>=prior and f<=78,'smooth capped high ramp');prior=f end
for _,v in {0/0,math.huge,-math.huge} do check(select(2,fov(v,true,true,true,false))=='NONE','invalid speed suppressed')end
for _,fps in {30,60,120} do
 local current=75
 for _,target in {78,81,85,78,75} do
  local initial=current
  for frame=1,fps do
   local nextValue=speed.stepFov(current,target,1/fps)
   check(nextValue>=math.min(initial,target) and nextValue<=math.max(initial,target),'no overshoot / no oscillation')
   current=nextValue
  end
  local response=if target>initial then 10 else 5
  check(math.abs(current-(target+(initial-target)*math.exp(-response)))<1e-10,'cadence equivalent elapsed time')
 end
end
check(speed.stepFov(81,85,0/0)==81 and speed.stepFov(81,85,-1)==81,'invalid dt cannot corrupt FOV')
check(not pcall(function()speed.Profiles.NITRO.FovDelta=99 end),'frozen cosmetic profile')
check(not fs.readFile('src/shared/KDMSpeedSensation.luau'):find('KartShieldActive',1,true),'no Shield input in pure resolver')
local fixture=serde.decode('json',fs.readFile('tests/fixtures/speed_sensation_starting_hashes.json'))
check(fixture.baseline=='5c704d5b0caf2b73e76c545617447006d14247bb','explicit N1 baseline')
for path,hash in fixture.hashes do
 -- The committed baseline always remains valid. An exact, separately approved
 -- working-tree Hub repair is an exception, never a required N1 dependency.
 local repair=fixture.unstagedPresentationExceptions and fixture.unstagedPresentationExceptions[path]
 if repair then
  check(path=='src/server/CompactHubBuilder.luau' and type(repair.reason)=='string','explicit unstaged Hub-only exception')
 end
 local actual=serde.hash('sha256',(fs.readFile(path):gsub('\r\n','\n')))
 local hotfix=fixture.approvedSourceHotfixes and fixture.approvedSourceHotfixes[path]
 if hotfix then
  check(path=='src/client/RaceResultsCache.luau' and hotfix.task=='R7-N1B'
   and hotfix.parent=='fc5baa5c8238ff35b9eef226d52f37e915c5579e','explicit approved result-cache hotfix only')
 end
 local expected=if hotfix then hotfix.sha256 else hash
 local presentation=fixture.approvedPresentationCandidates and fixture.approvedPresentationCandidates[path]
 if presentation then
  check((path=='src/client/RaceHudController.luau' or path=='src/client/DriverCelebrationController.luau'
   or path=='src/client/init.client.luau') and presentation.task=='R7-N2'
   and presentation.parent=='a7e551fac3031c395f4febf6e4ebfc208f8b4639','exact approved N2 presentation scope')
  expected=presentation.sha256
 end
 check(actual==expected or (repair~=nil and actual==repair.sha256),'frozen gameplay/geometry/audio/exhaust '..path)
end
print('PASS: '..n..' cosmetic speed profile, priority, cadence, immutable configuration and source freeze checks')
