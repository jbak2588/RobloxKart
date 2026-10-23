-- Shared presentation route, derived from the approved road; never drives a human kart.
local Layout=require(script.Parent.HubParkRookieLoopLayout)
local Route={Speed=70,VisualScale=1.0,PatternCount=1,StartX=Layout.TrialFinishX+12}
local points=Layout.sample(Layout.Segments)
local length,offset,best=0,0,math.huge
for i,p in points do
 if i>1 then local a=points[i-1];length+=math.sqrt((p.x-a.x)^2+(p.z-a.z)^2)end
 p.distance=length
 -- Start just ahead of the personal finish/grid, on the main straight.
 local d=math.abs(p.x-Route.StartX)+math.abs(p.z-Layout.StartStraightZ)
 if d<best then best=d;offset=length end
 local before=points[if i==1 then #points-1 else i-1]
 local after=points[if i==#points then 2 else i+1]
 local turn=before.fx*after.fz-before.fz*after.fx
 p.drift=if math.abs(turn)>1e-5 then -math.sign(turn)*math.clamp(60/p.radius,.2,.65)else 0
end
Route.CycleSeconds=length/Route.Speed
Route.LengthStuds=length
Route.Patterns=table.freeze({table.freeze({Name='ROOKIE_LOOP',StartSeconds=0,Seconds=Route.CycleSeconds})})
function Route.sample(elapsed,boostSeconds)
 local distance=(math.max(0,elapsed)*Route.Speed+offset)%length
 local low,high=1,#points-1
 while low<high do local mid=math.floor((low+high+1)/2)
  if points[mid].distance<=distance then low=mid else high=mid-1 end
 end
 local a,b=points[low],points[low+1]
 local t=math.clamp((distance-a.distance)/(b.distance-a.distance),0,1)
 local dx,dz=a.fx+(b.fx-a.fx)*t,a.fz+(b.fz-a.fz)*t
 local magnitude=math.sqrt(dx*dx+dz*dz)
 local drift=a.drift+(b.drift-a.drift)*t
 local x,z=a.x+(b.x-a.x)*t,a.z+(b.z-a.z)*t
 -- Boost from the line on entry and subsequent straight-line laps.
 local boosting=math.max(0,elapsed)%Route.CycleSeconds<(boostSeconds or 2)
 return x,z,dx/magnitude,dz/magnitude,drift,if math.abs(drift)>.01 then 'TURN'else 'CRUISE','ROOKIE_LOOP',boosting
end
return table.freeze(Route)
