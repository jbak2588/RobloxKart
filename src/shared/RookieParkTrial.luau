-- Server-observed one-lap progress; clients only display the replicated outcome.
local Layout=require(script.Parent.HubParkRookieLoopLayout)
local Progress=require(script.Parent.RaceRouteProgress)
local RaceConfig=require(script.Parent.RaceConfig)
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
 if math.abs(-x*g.fz+z*g.fx)>Layout.RoadWidth/2+10 then return nil end
 return t
end
-- Use the same indexed course and provisional off-road progress as Figure-8.
local samples,checkpoints={},{}
local first,best=1,math.huge
for i=1,#points-1 do local p=points[i];local d=(p.x-Trial.Finish.x)^2+(p.z-Trial.Finish.z)^2
 if d<best then first,best=i,d end
end
for j=0,#points-2 do local p=points[(first+j-1)%(#points-1)+1];table.insert(samples,Vector3.new(p.x,0,p.z))end
for _,g in Trial.Gates do
 local index,distance=1,math.huge
 for i,p in samples do local d=(p.X-g.x)^2+(p.Z-g.z)^2;if d<distance then index,distance=i,d end end
 table.insert(checkpoints,{Fraction=(index-1)/#samples})
end
local course={Samples=samples,CenterlineLength=length,CheckpointSamples=checkpoints}
function Trial.new(now,x,z)
 return {phase='COUNTDOWN',goAt=now+Trial.Countdown,next=1,previous={x=x,z=z,time=now},invalid=false,missed=false,
  route=Progress.new(course,Layout.RoadWidth)}
end
function Trial.step(s,now,x,y,z)
 local position=Vector3.new(x,0,z)
 if s.phase=='COUNTDOWN' then
  if now<s.goAt then return 'LOCKED' end
  s.phase='RUNNING';s.startedAt=now;s.previous={x=x,z=z,time=now}
  Progress.step(s.route,position,s.next,true)
  return 'GO'
 end
 if s.phase~='RUNNING' then return 'LOCKED' end
 local b={x=x,z=z,time=now};local a=s.previous;s.previous=b
 local dt=now-a.time;if dt<=0 then return end
 local moved=math.sqrt((x-a.x)^2+(z-a.z)^2)
 local _,roadDistance=Trial.project(x,z)
 local onRoad=roadDistance<=Layout.RoadWidth/2+RaceConfig.ROAD_CORRIDOR_MARGIN
 -- Sample continuity is independent from the older accepted route anchor.
 -- Never rebase a teleport itself or award gates during reacquisition.
 if dt>.5 or moved>110*dt+6 then s.rejoinSince=nil;return end
 local previousNext=s.next
 local nextGate=Progress.step(s.route,position,s.next,onRoad)
 -- A rejected discontinuity retains the Figure-8 route anchors. It does not
 -- poison the whole lap; normal compatible motion can resume after recovery.
 if s.route.position and (position-s.route.position).Magnitude>60 then
  if onRoad then
   s.rejoinSince=s.rejoinSince or now
   if now-s.rejoinSince>=.5 then
    s.route=Progress.new(course,Layout.RoadWidth)
    Progress.step(s.route,position,s.next,true)
    s.rejoinSince=nil
   end
  else s.rejoinSince=nil end
  return
 end
 s.rejoinSince=nil
 s.next=nextGate
 local g=Trial.Gates[s.next]
 if g and onRoad and moved/dt>=1 then
  local forward=((x-a.x)*g.fx+(z-a.z)*g.fz)/math.max(moved,.001)
  local longitudinal=(x-g.x)*g.fx+(z-g.z)*g.fz
  local lateral=-(x-g.x)*g.fz+(z-g.z)*g.fx
  if forward>=.25 and math.abs(longitudinal)<=10 and math.abs(lateral)<=Layout.RoadWidth/2+10 and y>=-2 and y<=18 then s.next+=1 end
 end
 if s.next>previousNext then s.missed=false end
 for i=s.next+1,6 do if crossing(Trial.Gates[i],a,b)then s.missed=true;break end end
 local t=crossing(Trial.Finish,a,b)
 if t and not s.finishPassed then s.finishPassed=true;return end
 if t and now-s.startedAt>3 then
  if s.next==7 then
   s.phase='FINISHED';s.milliseconds=math.max(1,math.floor((a.time+dt*t-s.startedAt)*1000+.5))
   return 'FINISHED'
  end
  s.missed=true
 end
end
function Trial.recover(s,x,z,now)
 s.rejoinSince=nil
 s.previous={x=x,z=z,time=now};s.route=Progress.new(course,Layout.RoadWidth)
 Progress.step(s.route,Vector3.new(x,0,z),s.next,true)
end
return table.freeze(Trial)
