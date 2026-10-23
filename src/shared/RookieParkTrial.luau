-- Server-observed one-lap progress; clients only display the replicated outcome.
local Layout=require(script.Parent.HubParkRookieLoopLayout)
local Trial={Reward=5000,Countdown=3,Version='ROOKIE_PARK_SOLO_V1'}
local points=Layout.sample(Layout.Segments)
local length=0
for i,p in points do
 if i>1 then local a=points[i-1];length+=math.sqrt((p.x-a.x)^2+(p.z-a.z)^2)end
 p.distance=length
end
Trial.Length=length
local function station(d)
 d=d%length
 for i=1,#points-1 do
  local a,b=points[i],points[i+1]
  if b.distance>=d then
   local t=(d-a.distance)/(b.distance-a.distance)
   return {x=a.x+(b.x-a.x)*t,z=a.z+(b.z-a.z)*t,fx=a.fx,fz=a.fz}
  end
 end
end
local offset=Layout.TrialFinishX-points[1].x
Trial.Finish={x=Layout.TrialFinishX,z=Layout.StartStraightZ,fx=1,fz=0}
Trial.Gates={}
for i=1,6 do Trial.Gates[i]=station(offset+length*i/7)end
function Trial.allocate(occupied,nextSlot)
 for offset=0,#Layout.Slots-1 do
  local slot=(nextSlot+offset)%#Layout.Slots
  if not occupied[slot]then return slot,(slot+1)%#Layout.Slots end
 end
 return nil,nextSlot
end
function Trial.project(x,z)
 local best,arc=math.huge,0
 for i=1,#points-1 do
  local a,b=points[i],points[i+1];local dx,dz=b.x-a.x,b.z-a.z
  local t=math.clamp(((x-a.x)*dx+(z-a.z)*dz)/(dx*dx+dz*dz),0,1)
  local d=(x-a.x-dx*t)^2+(z-a.z-dz*t)^2
  if d<best then best=d;arc=a.distance+(b.distance-a.distance)*t end
 end
 return arc,math.sqrt(best)
end
local function crossing(g,a,b)
 local before=(a.x-g.x)*g.fx+(a.z-g.z)*g.fz
 local after=(b.x-g.x)*g.fx+(b.z-g.z)*g.fz
 if before>=0 or after<0 then return nil end
 local t=-before/(after-before)
 local x,z=a.x+(b.x-a.x)*t-g.x,a.z+(b.z-a.z)*t-g.z
 if math.abs(-x*g.fz+z*g.fx)>Layout.RoadWidth/2+2 then return nil end
 return t
end
function Trial.new(now,x,z)
 return {phase='COUNTDOWN',goAt=now+Trial.Countdown,next=1,previous={x=x,z=z,time=now},distance=0,invalid=false,missed=false}
end
function Trial.step(s,now,x,y,z)
 if s.phase=='COUNTDOWN' then
  if now<s.goAt then return 'LOCKED' end
  s.phase='RUNNING';s.startedAt=now;s.previous={x=x,z=z,time=now};s.arc=Trial.project(x,z)
  return 'GO'
 end
 if s.phase~='RUNNING' then return 'LOCKED' end
 local b={x=x,z=z,time=now};local a=s.previous;s.previous=b
 local dt=now-a.time
 if dt<=0 then return end
 local moved=math.sqrt((x-a.x)^2+(z-a.z)^2)
 if dt>1 or moved>110*dt+6 or math.abs(y-1.75)>8 then
  s.invalid=true;s.missed=true;s.arc=nil;return
 end
 local arc,roadDistance=Trial.project(x,z)
 if s.arc then
  local delta=(arc-s.arc+length/2)%length-length/2
  if math.abs(delta)<=moved*3+8 and roadDistance<=Layout.RoadWidth/2+6 then
   s.distance+=math.max(0,delta)
  elseif math.abs(delta)>moved*3+8 then s.invalid=true;s.missed=true end
 end
 s.arc=arc
 local expected=Trial.Gates[s.next]
 if expected and crossing(expected,a,b)then s.next+=1;s.missed=false
 else
  for i=s.next+1,6 do if crossing(Trial.Gates[i],a,b)then s.missed=true;break end end
 end
 local t=crossing(Trial.Finish,a,b)
 if t and not s.finishPassed then s.finishPassed=true;return end
 if t and now-s.startedAt>3 then
  if s.next==7 and not s.invalid and s.distance>=length*.95 then
   s.phase='FINISHED';s.milliseconds=math.max(1,math.floor((a.time+dt*t-s.startedAt)*1000+.5))
   return 'FINISHED'
  end
  s.missed=true
  if s.invalid then s.phase='INVALID';return 'INVALID'end
 end
end
function Trial.recover(s,x,z,now)
 -- Recovery grants no gate, elapsed distance or finish crossing.
 s.previous={x=x,z=z,time=now};s.arc=Trial.project(x,z)
end
return table.freeze(Trial)
