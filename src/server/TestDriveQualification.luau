-- Server-only movement qualification. No client timestamps, idle time or teleport distance.
local Activity={}
function Activity.new()return {seconds=0,distance=0,complete=false}end
function Activity.step(s,dt,x,z,valid)
 if s.complete then return true end
 if type(dt)~='number' or dt~=dt or dt<=0 or dt>.2 or not valid then s.x=nil;s.z=nil;return false end
 if type(x)~='number' or type(z)~='number' or x~=x or z~=z or math.abs(x)==math.huge or math.abs(z)==math.huge then s.x=nil;s.z=nil;return false end
 local px,pz=s.x,s.z;s.x=x;s.z=z
 if px then
  local distance=math.sqrt((x-px)^2+(z-pz)^2)
  if distance>=3*dt and distance<=110*dt+.25 then
   s.seconds+=dt;s.distance+=distance
  end
 end
 s.complete=s.seconds>=30 and s.distance>=300
 return s.complete
end
function Activity.proof(s)return {complete=s.complete,movingMilliseconds=math.floor(s.seconds*1000+.5),distance=s.distance}end
return table.freeze(Activity)
