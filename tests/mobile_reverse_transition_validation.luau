local rb=require('@lune/roblox')
local fs,luau=require('@lune/fs'),require('@lune/luau')
local cfg=require('./helpers/gameplay_config')('src/shared/KartConfig.luau')
local drift=require('./helpers/lobby_drift_session')
local n=0;local function check(v,m)assert(v,m);n+=1 end
for _,dt in {1/30,1/60}do
 local s=drift.new();local speed=70
 local function step(throttle)
  local before=speed
  local _,_,_,budget=drift.step(s,1,dt,speed,0,speed,throttle,0,true,0,0,80,false,false)
  speed=budget
  return before
 end
 local before=step(-1)
 check(math.abs(speed-(before-cfg.BRAKE_FORCE*dt))<1e-6,'tap brakes at one configured rate')
 for _=1,math.ceil(4/dt)do
  before=step(-1)
  check(speed>=-50 and speed<=before,'hold brakes then reverses without overspeed')
  if before<=0 then check(math.abs(speed-before)<=cfg.REVERSE_ACCELERATION*dt+1e-6,'reverse acceleration matches race')end
 end
 check(math.abs(speed+50)<1e-6,'hold reaches requested reverse 50')
 before=step(1)
 check(math.abs(speed-(before+cfg.BRAKE_FORCE*dt))<1e-6,'release brakes reverse motion before accelerating forward')
 for _=1,math.ceil(3/dt)do step(1)end
 check(speed>0 and speed<=80,'release resumes forward travel smoothly')
end
local service=fs.readFile('src/server/LobbyTestDriveService.luau')
check(not service:find('local target=if throttle<0',1,true),'service does not integrate brake/reverse a second time')
check(service:find('if os.clock()-r.lastInput>Policy.InputTimeout then',1,true)~=nil,'stale input retains timeout coast')
print('PASS '..n..' brake/reverse/auto-resume transition checks')
