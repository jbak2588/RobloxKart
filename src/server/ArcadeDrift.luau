-- Server-only rear slide solver, called from the existing kart step.
-- Positive steering turns right; a negative velocity/body slip puts the tail outside.
local Slide={}
local function approach(v,target,amount) return v+math.clamp(target-v,-amount,amount) end
function Slide.clear(state) state.active=false;state.recovering=false;state.side=nil;state.entry=0;state.planarSpeed=nil end
function Slide.step(state,c,forwardSpeed,lateralSpeed,steering,normalYaw,currentYaw,dt,active,safe,speedBudget)
 if not c.Enabled or not safe or forwardSpeed<=2 or dt<=0 or dt>c.MaxStep then Slide.clear(state);return nil end
 if active then
  local side=if math.abs(steering)>=c.EntrySteer then math.sign(steering) else nil
  if not state.active or (side and state.side and side~=state.side) then state.entry=c.EntrySeconds end
  if side then state.side=side end
  state.active=true;state.recovering=false
 elseif state.active then state.active=false;state.recovering=true end
 if not active and not state.recovering then return nil end
 local beta=math.atan2(lateralSpeed,forwardSpeed)
 -- An external impact/large discontinuity belongs to the existing recovery path.
 -- Never snap a disturbed velocity back to the arcade envelope in one frame.
 if math.abs(beta)>math.rad(c.SafetySlipDegrees) then Slide.clear(state);return nil end
 local strength=math.clamp((math.abs(steering)-c.EntrySteer)/(1-c.EntrySteer),0,1)
 local budget=speedBudget or math.sqrt(forwardSpeed^2+lateralSpeed^2)
 local maxSlip=c.MaxSlipDegrees
 if c.Angled then
  local speedWeight=math.clamp((budget-c.FullAngleSpeedLow)/(c.FullAngleSpeedHigh-c.FullAngleSpeedLow),0,1)
  maxSlip=c.LowSpeedMaxSlipDegrees+(c.MaxSlipDegrees-c.LowSpeedMaxSlipDegrees)*speedWeight
 end
 local target=if active then -math.sign(steering)*math.rad(c.MinSlipDegrees+(maxSlip-c.MinSlipDegrees)*strength)
  *math.clamp(math.abs(steering)/c.EntrySteer,0,1) else 0
 if active and (state.entry or 0)>0 then
  target-=math.sign(steering)*math.rad(c.EntryExtraDegrees)*(state.entry/c.EntrySeconds)
  state.entry=math.max(0,state.entry-dt)
 end
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
 local outputForward=nil
 if c.Angled then
  -- Redistribute a single planar speed budget. Large angles never add energy.
  state.planarSpeed=budget
  lateral=budget*math.sin(outputBeta)
  outputForward=budget*math.cos(outputBeta)
 end
 if not active and math.abs(nextBeta)<math.rad(c.SettledDegrees) then state.recovering=false end
 return lateral,yaw,target,outputForward
end
return table.freeze(Slide)
