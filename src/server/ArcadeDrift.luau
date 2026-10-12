-- Server-only rear slide solver, called from the existing kart step.
-- Positive steering turns right; a negative velocity/body slip puts the tail outside.
local Slide={}
local function approach(v,target,amount) return v+math.clamp(target-v,-amount,amount) end
function Slide.clear(state) state.active=false;state.recovering=false end
function Slide.step(state,c,forwardSpeed,lateralSpeed,steering,normalYaw,currentYaw,dt,active,safe)
 if not c.Enabled or not safe or forwardSpeed<=2 or dt<=0 or dt>c.MaxStep then Slide.clear(state);return nil end
 if active then state.active=true;state.recovering=false
 elseif state.active then state.active=false;state.recovering=true end
 if not active and not state.recovering then return nil end
 local beta=math.atan2(lateralSpeed,forwardSpeed)
 -- An external impact/large discontinuity belongs to the existing recovery path.
 -- Never snap a disturbed velocity back to the arcade envelope in one frame.
 if math.abs(beta)>math.rad(c.SafetySlipDegrees) then Slide.clear(state);return nil end
 local strength=math.clamp((math.abs(steering)-c.EntrySteer)/(1-c.EntrySteer),0,1)
 local target=if active then -math.sign(steering)*math.rad(c.MinSlipDegrees+(c.MaxSlipDegrees-c.MinSlipDegrees)*strength)
  *math.clamp(math.abs(steering)/c.EntrySteer,0,1) else 0
 local rate=math.rad(if active then c.SlipRateDegrees else c.ExitRateDegrees)
 local nextBeta=approach(beta,target,rate*math.min(dt,c.MaxStep))
 local betaRate=(nextBeta-beta)/dt
 -- Body yaw = path yaw + slip-rate. This creates turn-in and real rear sweep,
 -- while keeping path curvature independent of an uncontrolled lateral-speed buildup.
 local speedBlend=math.clamp((forwardSpeed-c.RadiusSpeedLow)/(c.RadiusSpeedHigh-c.RadiusSpeedLow),0,1)
 local radiusScale=c.RadiusScale+(c.HighSpeedRadiusScale-c.RadiusScale)*speedBlend
 local pathYaw=normalYaw/(if active then radiusScale else 1)
 local yawTarget=math.clamp(pathYaw+betaRate*c.SlipYawGain,-c.MaxYawRate,c.MaxYawRate)
 local yaw=approach(currentYaw,yawTarget,c.YawAcceleration*dt)
 -- Predict the next body basis. Counter the heading rotation that would otherwise
 -- add yaw/grip slip every frame; do not write CFrame or teleport the chassis.
 local outputBeta=math.clamp(nextBeta-yaw*dt,-math.rad(c.SafetySlipDegrees),math.rad(c.SafetySlipDegrees))
 local lateral=forwardSpeed*math.tan(outputBeta)
 if not active and math.abs(nextBeta)<math.rad(c.SettledDegrees) then state.recovering=false end
 return lateral,yaw,target
end
return table.freeze(Slide)
