-- Presentation-only course on the existing front apron, in zone-local X/Z.
-- A shared clock keeps late joiners on the same lap without streaming poses.
local Route = { Speed = 36, Radius = 50, HalfStraight = 120, DonutRadius = 28 }
Route.DonutSeconds = 2*math.pi*Route.DonutRadius/Route.Speed
Route.LapSeconds = (4*Route.HalfStraight+2*math.pi*Route.Radius)/Route.Speed
Route.CycleSeconds = Route.DonutSeconds+Route.LapSeconds

function Route.hasAudience(players, departing)
 for _,player in players do
  if player~=departing and player:GetAttribute("RaceState")=="GARAGE"
   and player:GetAttribute("KDMRoutePending")~="RACE_LAUNCH" then return true end
 end
 return false
end

function Route.sample(elapsed)
 local t = math.max(0,elapsed)%Route.CycleSeconds
 if t<Route.DonutSeconds then
  local a=math.pi/2-t*Route.Speed/Route.DonutRadius
  local fade=math.clamp(math.min(t,Route.DonutSeconds-t)/.45,0,1)
  fade=fade*fade*(3-2*fade)
  return -120+Route.DonutRadius*math.cos(a),50-Route.DonutRadius+Route.DonutRadius*math.sin(a),
   math.sin(a),-math.cos(a),fade,"DONUT"
 end
 local s=(t-Route.DonutSeconds)*Route.Speed
 if s<240 then return -120+s,50,1,0,0,"CRUISE" end
 s-=240
 if s<math.pi*50 then
  local a=math.pi/2-s/50
  return 120+50*math.cos(a),50*math.sin(a),math.sin(a),-math.cos(a),0,"CRUISE"
 end
 s-=math.pi*50
 if s<240 then return 120-s,-50,-1,0,0,"CRUISE" end
 local a=-math.pi/2-(s-240)/50
 return -120+50*math.cos(a),50*math.sin(a),math.sin(a),-math.cos(a),0,"CRUISE"
end

return table.freeze(Route)
