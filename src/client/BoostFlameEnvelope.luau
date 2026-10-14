-- Visual-only tail. Unknown/cancelled exits fail closed; never infer expiry from speed.
local Envelope={}
Envelope.MAX_TAIL_SECONDS=2
Envelope.END_SPEED=82 -- Highest approved normal cap is 80; no glow in normal cruising.
function Envelope.new()return {active=false,tail=0,startSpeed=100,weight=0,mode=.7}end
function Envelope.step(s,dt,speed,nitro,boost,normalEnd,unsafe)
 if unsafe then s.active=false;s.tail=0;s.weight=0;return 0 end
 local active=nitro or boost
 if active then
  s.tail=0;s.startSpeed=math.max(speed,Envelope.END_SPEED+.01);s.mode=if nitro then 1 else .7;s.weight=s.mode
 elseif s.active then
  s.tail=if normalEnd and speed>Envelope.END_SPEED then Envelope.MAX_TAIL_SECONDS else 0
 end
 s.active=active
 if not active then
  s.tail=math.max(0,s.tail-math.max(0,dt))
  local speedWeight=math.clamp((speed-Envelope.END_SPEED)/(s.startSpeed-Envelope.END_SPEED),0,1)
  s.weight=s.mode*math.min(speedWeight,s.tail/Envelope.MAX_TAIL_SECONDS)
 end
 return s.weight
end
return Envelope
