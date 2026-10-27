-- Training adapter for the SAME PV637 server slide solver and charge thresholds.
-- No RaceLoadout, result, wallet, receipt or persistent state belongs here.
local RS=game:GetService('ReplicatedStorage')
local Config=require(RS.Shared.KartConfig)
local Slide=require(script.Parent.ArcadeDrift)
local Session={}
local function toward(v,t,d)return v+math.clamp(t-v,-d,d) end
function Session.new()
 return {slide={},active=false,boost=false,boostEnd=0,duration=0,qualified=0,ready=false,press=0,boostPress=0,held=false,steer=0,reentry=false}
end
function Session.clear(s)
 Slide.clear(s.slide);s.active=false;s.boost=false;s.boostEnd=0;s.duration=0;s.qualified=0;s.ready=false;s.held=false;s.steer=0;s.reentry=false;s.nitroExit=false
 s.boostPress=s.press
end
function Session.input(s,held,now,fresh)
 if held and not s.held and fresh then s.press+=1;s.pressTime=now end
 s.held=held
end
function Session.step(s,now,dt,forward,lateral,speed,throttle,steering,valid,normalYaw,yaw,normalCap,nitro,offTrack)
 if not valid or dt>Config.ARCADE_DRIFT.MaxStep then Session.clear(s);return nil end
 s.steer=toward(s.steer,steering,Config.STEERING_RESPONSE*dt)
 local entered=false
 if offTrack then
  -- Leaving the road drops unearned Drift charge, not an already-running boost.
  s.active=false;s.duration=0;s.qualified=0;s.ready=false;Slide.clear(s.slide)
 end
 local clean=not s.held or (math.abs(s.steer)<Config.DRIFT_EXIT_STEER and math.abs(steering)<Config.DRIFT_EXIT_STEER)
 if s.active and (clean or forward<Config.DRIFT_EXIT_SPEED or throttle<=0) then
  local award=clean and s.ready and forward>=Config.DRIFT_MIN_SPEED and throttle>0
  s.active=false
  if award then s.boost=true;s.boostEnd=now+Config.MINI_BOOST_DURATION;s.boostPress=s.press end
  s.duration=0;s.qualified=0;s.ready=false
 elseif not offTrack and not s.active and s.held and throttle>0 and forward>=Config.DRIFT_MIN_SPEED then
  local newPress=s.press>s.boostPress and s.pressTime and now-s.pressTime<=Config.ARCADE_DRIFT.ReentryPressSeconds
  if (not s.boost or newPress) and (math.abs(s.steer)>=Config.DRIFT_ENTRY_STEER or (s.boost and newPress and math.abs(steering)>=Config.DRIFT_ENTRY_STEER)) then
   s.reentry=s.boost;s.boost=false;s.boostEnd=0;s.active=true;s.duration=0;s.qualified=0;s.ready=false;entered=true
  end
 end
 if s.active and not entered then
  s.duration=math.min(Config.DRIFT_CHARGE_MIN_DURATION,s.duration+dt)
  local slip=math.abs(math.deg(math.atan2(lateral,math.max(forward,.01))))
  if forward>=Config.DRIFT_CHARGE_MIN_FORWARD_SPEED and slip>=Config.DRIFT_CHARGE_MIN_SLIP_DEGREES then s.qualified=math.min(Config.DRIFT_CHARGE_REQUIRED_TIME,s.qualified+dt) end
  s.ready=s.duration>=Config.DRIFT_CHARGE_MIN_DURATION and s.qualified>=Config.DRIFT_CHARGE_REQUIRED_TIME
 end
 if s.boost and (now>=s.boostEnd or throttle<=0) then s.boost=false;s.boostEnd=0 end
 s.nitroExit=nitro==true or (s.nitroExit and speed>normalCap)
 local rawCap=if nitro then Config.NITRO_MAX_SPEED elseif s.boost then Config.MINI_BOOST_MAX_SPEED elseif s.active then math.min(normalCap,Config.DRIFT_MAX_SPEED) else normalCap
 local cap=if offTrack and (nitro or s.boost) then rawCap*Config.OFF_TRACK_BOOST_SPEED_MULTIPLIER elseif offTrack then Config.OFF_TRACK_MAX_SPEED else rawCap
 local accel=if nitro then Config.NITRO_ACCELERATION elseif s.boost then Config.MINI_BOOST_ACCELERATION else Config.ACCELERATION
 if throttle>0 then
  if speed<0 then
   speed=toward(speed,0,Config.BRAKE_FORCE*throttle*dt)
  else
   local rate=if speed>cap then (if offTrack then Config.BRAKE_FORCE elseif s.nitroExit and not s.boost then Config.NITRO_EXIT_DECELERATION elseif s.active then (if s.reentry then Config.ARCADE_DRIFT.ReentryDeceleration else Config.DRIFT_SPEED_DECELERATION) elseif s.straightExitActive then Config.STRAIGHT_EXIT_DECELERATION else Config.BOOST_EXIT_DECELERATION) else accel*throttle
   speed=toward(speed,cap,rate*dt)
  end
 elseif throttle<0 then
  if speed>0 then
   speed=toward(speed,0,Config.BRAKE_FORCE*-throttle*dt)
  else
   local revCap=Config.MAX_REVERSE_SPEED -- held reverse uses the same70 cap on grass and road
   speed=toward(speed,-revCap,Config.REVERSE_ACCELERATION*-throttle*dt)
  end
 else
  speed=toward(speed,0,Config.COAST_DECELERATION*dt)
 end
 local side,turn,_,projected=Slide.step(s.slide,Config.ARCADE_DRIFT,forward,lateral,s.steer,normalYaw,yaw,dt,s.active,throttle>0,speed)
 return side,turn,projected or speed,speed
end
return Session
