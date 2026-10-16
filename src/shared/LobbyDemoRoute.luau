-- Presentation-only course on the existing front apron, in zone-local X/Z.
-- A shared clock keeps late joiners on the same lap without streaming poses.
local Route = { Speed = 36, VisualScale = 1.12, PatternCount = 3 }
local paths={}
local metadata={}
local cycle=0
local function makePattern(name,donuts,radius,weave)
 local points={}
 local length=0
 local function add(x,z)
  local last=points[#points]
  if last then length+=math.sqrt((x-last.x)^2+(z-last.z)^2) end
  table.insert(points,{x=x,z=z,distance=length})
 end
 -- Every pattern enters/leaves at (-120,50), facing +X. Arc-length sampling
 -- keeps speed continuous through the weave, double donut and pattern joins.
 add(-120,50)
 local steps=math.ceil(2*math.pi*radius*donuts)
 for i=1,steps do
  local a=math.pi/2-2*math.pi*donuts*i/steps
  add(-120+radius*math.cos(a),50-radius+radius*math.sin(a))
 end
 local donutLength=length
 local function wave(u)return weave*math.sin(math.pi*u)^2*math.sin(2*math.pi*u) end
 for i=1,240 do local u=i/240;add(-120+i,50+wave(u)) end
 local arcSteps=math.ceil(math.pi*50)
 for i=1,arcSteps do local a=math.pi/2-math.pi*i/arcSteps;add(120+50*math.cos(a),50*math.sin(a)) end
 for i=1,240 do local u=i/240;add(120-i,-50-wave(u)) end
 for i=1,arcSteps do local a=-math.pi/2-math.pi*i/arcSteps;add(-120+50*math.cos(a),50*math.sin(a)) end
 for i,p in points do
  local before=points[if i==1 then #points-1 else i-1]
  local after=points[if i==#points then 2 else i+1]
  local dx,dz=after.x-before.x,after.z-before.z
  local magnitude=math.sqrt(dx*dx+dz*dz)
  p.dx,p.dz=dx/magnitude,dz/magnitude
  local ax,az=p.x-before.x,p.z-before.z
  local bx,bz=after.x-p.x,after.z-p.z
  local cross=ax*bz-az*bx
  p.drift=if math.abs(cross)>1e-6 then -math.sign(cross)*(if p.distance<donutLength then .95 else .65) else 0
 end
 local seconds=length/Route.Speed
 table.insert(paths,{points=points,length=length,donutLength=donutLength})
 table.insert(metadata,table.freeze({Name=name,StartSeconds=cycle,Seconds=seconds,DonutSeconds=donutLength/Route.Speed,DonutRadius=radius}))
 cycle+=seconds
end
makePattern("WIDE_LOOP",1,28,0)
makePattern("S_SLALOM",1,28,18)
makePattern("DOUBLE_DONUT",2,22,0)
Route.Patterns=table.freeze(metadata)
Route.CycleSeconds=cycle

function Route.hasAudience(players, departing)
 for _,player in players do
  if player~=departing then return true end
 end
 return false
end

function Route.sample(elapsed,boostSeconds)
 local t = math.max(0,elapsed)%Route.CycleSeconds
 local index=1
 for i,pattern in metadata do
  if t>=pattern.StartSeconds then index=i else break end
 end
 local path,pattern=paths[index],metadata[index]
 local localTime=t-pattern.StartSeconds
 local distance=localTime*Route.Speed
 local points=path.points
 local low,high=1,#points-1
 while low<high do
  local mid=math.floor((low+high+1)/2)
  if points[mid].distance<=distance then low=mid else high=mid-1 end
 end
 local a,b=points[low],points[low+1]
 local alpha=math.clamp((distance-a.distance)/(b.distance-a.distance),0,1)
 local dx,dz=a.dx+(b.dx-a.dx)*alpha,a.dz+(b.dz-a.dz)*alpha
 local magnitude=math.sqrt(dx*dx+dz*dz)
 local drift=a.drift+(b.drift-a.drift)*alpha
 -- Every nonzero steering bend produces friction/smoke, independent of charge.
 if math.abs(drift)>1e-6 then drift=math.sign(drift)*math.max(.2,math.abs(drift)) end
 local phase=if distance<path.donutLength then "DONUT" elseif drift~=0 then "TURN" else "CRUISE"
 local boosting=localTime>=pattern.DonutSeconds and localTime<pattern.DonutSeconds+(boostSeconds or 2)
 return a.x+(b.x-a.x)*alpha,a.z+(b.z-a.z)*alpha,dx/magnitude,dz/magnitude,drift,phase,pattern.Name,boosting
end

return table.freeze(Route)
