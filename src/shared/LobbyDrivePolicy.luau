-- Lobby-only parameters. Never used by the race controller or KartConfig.
local Policy = {
 Forward = 60, ParkForward = 80, Reverse = 70, Acceleration = 36, Brake = 70, Coast = 18,
 TurnRadius = 50, DriftTurnRadius = 35, InputTimeout = .5,
 Radius = 50, HalfStraight = 120, RoadWidth = 32, Shoulder = 16,
 OuterRadius = 90, FootprintMargin = 7,
 GlancingNormal = .5, EscapeSpeed = 4, EscapeDelay = .35,
 EscapeDistance = 3, EscapeCooldown = .75, EscapeLimit = 3,
 EscapeClearance = 8, SteeringAssist = .65,
}
-- Scalar helpers also validate the server's contact response without physics mocks.
function Policy.forwardSpeed(geometryId,kartConfig)
 -- Owner-approved RookieLoop override. Official RACE KartConfig stays unchanged.
 return if geometryId=='ROOKIE_LOOP_V1' then Policy.ParkForward else Policy.Forward
end
-- Contact with the actual stone-rim OBB, not the road/grass boundary.
-- Return the normal pointing from the wall toward the kart and signed hull gap.
function Policy.parkReverseContact(frame,size,wallFrame,wallSize)
 local p=wallFrame:PointToObjectSpace(frame.Position)
 if math.abs(p.Y)>wallSize.Y/2+size.Y/2 then return nil end
 local normal=wallFrame.RightVector*(if p.X<0 then -1 else 1)
 if frame.LookVector:Dot(normal)>-.98 then return nil end
 local half=size/2
 local extent=math.abs(frame.RightVector:Dot(normal))*half.X+math.abs(frame.LookVector:Dot(normal))*half.Z
 local tangent=wallFrame.LookVector
 local reach=math.abs(frame.RightVector:Dot(tangent))*half.X+math.abs(frame.LookVector:Dot(tangent))*half.Z
 if math.abs(p.Z)>wallSize.Z/2+reach then return nil end
 local gap=math.abs(p.X)-wallSize.X/2-extent
 if gap< -1 or gap>.25 then return nil end
 return normal,gap
end

function Policy.slide(x,z,nx,nz)
 local outward=math.max(0,x*nx+z*nz)
 return x-nx*outward,z-nz*outward
end
function Policy.footprint(fx,fz,nx,nz)
 return 4*math.abs(fx*nx+fz*nz)+3*math.abs(-fz*nx+fx*nz)+1.35
end
function Policy.escapeDistance(clearance,footprint)
 return math.clamp(math.max(Policy.EscapeClearance,footprint+.5)-clearance,0,Policy.EscapeDistance)
end
function Policy.fits(geometry,x,z,fx,fz)
 if not geometry.inside(x,z) then return false end
 for _,front in {-4,4} do for _,side in {-3,3} do
  if not geometry.inside(x+fx*front-fz*side,z+fz*front+fx*side,1.35) then return false end
 end end
 return true
end
function Policy.escapeSteering(fx,fz,nx,nz,steering,direction)
 local yaw=-steering*Policy.SteeringAssist*direction
 local before=(fx*nx+fz*nz)*direction
 local after=(fx*nx+fz*nz+(fz*nx-fx*nz)*yaw*.1)*direction
 return if after<before then yaw else 0
end
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
