-- Lobby-only parameters. Never used by the race controller or KartConfig.
local Policy = {
 Forward = 70, Reverse = 30, Acceleration = 36, Brake = 70, Coast = 18,
 TurnRadius = 50, DriftTurnRadius = 35, InputTimeout = .5,
 Radius = 50, HalfStraight = 120, RoadWidth = 32, Shoulder = 16,
 OuterRadius = 90, FootprintMargin = 7,
}
function Policy.isGlobalHub(role, privateId, botTest)
 return role == "HUB" and privateId == "" and not botTest
end
function Policy.turnRadius(drifting)
 return if drifting then Policy.DriftTurnRadius else Policy.TurnRadius
end
function Policy.validAxes(throttle, steering)
 return type(throttle)=="number" and type(steering)=="number"
  and throttle==throttle and steering==steering and math.abs(throttle)<math.huge and math.abs(steering)<math.huge
end
function Policy.advance(speed, throttle, dt)
 local target, rate = 0, Policy.Coast
 if throttle > 0 then target,rate=Policy.Forward*throttle,if speed<0 then Policy.Brake else Policy.Acceleration
 elseif throttle < 0 then target,rate=-Policy.Reverse*-throttle,if speed>0 then Policy.Brake else Policy.Acceleration end
 local delta=math.clamp(target-speed,-rate*dt,rate*dt)
 return math.clamp(speed+delta,-Policy.Reverse,Policy.Forward)
end
function Policy.inside(x,z,margin)
 local nearest=math.clamp(x,-Policy.HalfStraight,Policy.HalfStraight)
 local radius=Policy.OuterRadius-(margin or 0)
 return (x-nearest)^2+z^2 <= radius^2
end
-- Match the existing Track Barrier severity, rebound, spin and duration policy.
function Policy.barrierImpact(approach,config)
 local strong=approach>=config.BARRIER_CRASH_MIN_SPEED
 local severity=math.clamp((approach-config.BARRIER_CRASH_MIN_SPEED)/(config.MINI_BOOST_MAX_SPEED-config.BARRIER_CRASH_MIN_SPEED),0,1)
 return {
  duration=if strong then config.BARRIER_CRASH_DURATION_MIN+(config.BARRIER_CRASH_DURATION_MAX-config.BARRIER_CRASH_DURATION_MIN)*severity else .22,
  rebound=if strong then math.clamp(approach*config.BARRIER_CRASH_BOUNCE_FACTOR,config.BARRIER_CRASH_MIN_REBOUND_SPEED,config.BARRIER_CRASH_MAX_REBOUND_SPEED) else 5+3*math.clamp(approach/config.BARRIER_CRASH_MIN_SPEED,0,1),
  turns=if strong then config.BARRIER_CRASH_MIN_SPIN_TURNS+(config.BARRIER_CRASH_MAX_SPIN_TURNS-config.BARRIER_CRASH_MIN_SPIN_TURNS)*severity else 0,
 }
end
-- Closed clockwise stadium centerline, including long acceleration straights.
function Policy.route(radius)
 local points={}
 local function add(x,z) table.insert(points,{x=x,z=z}) end
 local n=32
 for i=0,n-1 do add(-Policy.HalfStraight+2*Policy.HalfStraight*i/n,radius) end
 for i=0,39 do local a=math.pi/2-math.pi*i/40;add(Policy.HalfStraight+radius*math.cos(a),radius*math.sin(a)) end
 for i=0,n-1 do add(Policy.HalfStraight-2*Policy.HalfStraight*i/n,-radius) end
 for i=0,39 do local a=-math.pi/2-math.pi*i/40;add(-Policy.HalfStraight+radius*math.cos(a),radius*math.sin(a)) end
 return points
end
return table.freeze(Policy)
