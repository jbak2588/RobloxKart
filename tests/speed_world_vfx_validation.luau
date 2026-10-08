local rb=require('@lune/roblox')
local n=0
local function check(v,label)assert(v,label);n+=1 end
require('./helpers/world_vfx_harness')(4,20,function(h)
 local function effects(k,class,prefix)
  local result={};for _,o in k:GetDescendants()do if o:IsA(class) and o.Name:find(prefix,1,true)then result[#result+1]=o end end;return result
 end
 local function enabled(list)local count=0;for _,o in list do if o.Enabled then count+=1 end end;return count end
 local states={{0,false,false,0,0,'NONE'},{70,false,false,2,0,'HIGH_SPEED'},{80,false,false,2,0,'HIGH_SPEED'},
  {100,true,false,0,4,'MINI_BOOST'},{100,false,true,0,6,'NITRO'},{100,true,true,0,6,'NITRO'}}
 local function set(state)
  for _,k in h.karts do k.PrimaryPart.AssemblyLinearVelocity=rb.Vector3.new(0,0,-state[1]);k:SetAttribute('KartBoosting',state[2]);k:SetAttribute('KartNitroActive',state[3])end
  h.tick(.01)
 end
 for _,k in h.karts do
  for index=1,2 do
   local a=k.PrimaryPart:FindFirstChild('KDMSpeedPoint'..index..'_1');local b=k.PrimaryPart:FindFirstChild('KDMSpeedPoint'..index..'_2')
   local center=(a.Position+b.Position)*.5;local side=if index==1 then -1 else 1
   check(math.abs(center.X-side*(4+.5+.12))<1e-5,'accepted wheel-face High origin')
   check(math.abs(center.Y)<1e-5 and math.abs(center.Z-3)<1e-5,'accepted rear axle High height')
  end
  for _,point in effects(k,'Attachment','KDMSpeedJetPoint')do
   check(point.CFrame.Position.Z==3,'actual exhaust metadata position')
   check(point.CFrame:VectorToWorldSpace(rb.Vector3.zAxis):Dot(rb.Vector3.zAxis)>.999,'rearward Back orientation independent of camera')
  end
 end
 local allocations=h.allocated()
 for cycle=1,20 do
  for _,state in states do
   set(state)
   for _,k in h.karts do
    local trails=effects(k,'Trail','KDMSpeed');local emitters=effects(k,'ParticleEmitter','KDMSpeedJet')
    check(enabled(trails)==state[4] and enabled(emitters)==state[5],'self/remote tier configuration '..state[6])
    check(#trails==2 and h.count(k,'Attachment','KDMSpeedPoint')==4 and h.count(k,'Attachment','KDMSpeedJetPoint')==2 and #emitters==6,'fixed 14-instance N1A budget')
    local rate=0;local profile={}
    for _,e in emitters do
     if e.Enabled then
      rate+=e.Rate
      check(e.Acceleration==rb.Vector3.zero and e.EmissionDirection==rb.Enum.NormalId.Back,'no aura/upward acceleration')
      check(e.Orientation==rb.Enum.ParticleOrientation.FacingCamera and not e.LockedToPart,'rear jet remains visible from chase camera')
      check(e.Lifetime.Max<=.38 and e.Speed.Max<=42 and e.SpreadAngle.X<=13,'short directional bounded particles')
      check(e.LightEmission<=1 and e.VelocityInheritance==.15,'bounded light/inheritance')
      check(e.Texture:find('rbxasset://textures/particles/',1,true)==1,'built-in texture only')
      check(e.Transparency.Keypoints[#e.Transparency.Keypoints].Value==1 and e.Size.Keypoints[1].Value<=.850001,'fade and compact source')
      local mini=state[6]=='MINI_BOOST'
      if e.Name=='KDMSpeedJetCore' then check(e.Rate==(if mini then 36 else 55) and math.abs(e.Lifetime.Min-(if mini then .14 else .20))<1e-6,'Core exact tier profile')
      elseif e.Name=='KDMSpeedJetPlume' then check(e.Rate==(if mini then 18 else 30),'Plume exact tier profile')
      else check(not mini and e.Rate==12,'Nitro-only small spark')end
     end
     profile[e]={e.Enabled,e.Rate,e.Size,e.Transparency,e.Speed,e.Lifetime,e.LightEmission,e.SpreadAngle,e.Color}
    end
    check(rate==(if state[6]=='NITRO' then 194 elseif state[6]=='MINI_BOOST' then 108 else 0),'total rate bounded and Nitro wins simultaneous flags')
    if state[6]=='HIGH_SPEED' then for _,t in trails do check(t.Lifetime==.10 and t.LightEmission==.10,'accepted High profile unchanged')end end
    if state[5]>0 then check(enabled(trails)==0,'no boost road-line ribbons')end
    k:SetAttribute('KartShieldActive',true);h.tick(.01)
    for e,p in profile do check(e.Enabled==p[1] and e.Rate==p[2] and e.Size==p[3] and e.Transparency==p[4] and e.Speed==p[5] and e.Lifetime==p[6] and e.LightEmission==p[7] and e.SpreadAngle==p[8] and e.Color==p[9],'Shield excludes all emitter profile inputs')end
    k:SetAttribute('KartShieldActive',false)
   end
  end
  set(states[4]);for _,k in h.karts do for _,e in effects(k,'ParticleEmitter','KDMSpeedJet')do e.cleared=false end end
  set(states[2]);for _,k in h.karts do for _,e in effects(k,'ParticleEmitter','KDMSpeedJet')do check(not e.cleared,'expiry does not clear live particles')end end
  set(states[5]);set(states[2]);set(states[1])
  for _,k in h.karts do for _,e in effects(k,'ParticleEmitter','KDMSpeedJet')do check(e.cleared and not e.Enabled,'NONE clears suppressed particles')end end
 end
 check(h.allocated()==allocations,'20 cycles do not create emitters/attachments/trails')
 check(h.run.Heartbeat.Count()==1,'single shared observer')
 set(states[2]);for _,k in h.karts do k:SetAttribute('KartDrifting',true)end;h.tick(.01)
 for _,k in h.karts do check(enabled(effects(k,'Trail','KDMSpeed'))==0,'High yields to Drift')end
 set(states[4]);for _,k in h.karts do check(enabled(effects(k,'ParticleEmitter','KDMSpeedJet'))==4,'Mini follows authoritative state while Drifting')end
 for _,key in {'KartOffTrack','RaceControlsLocked'}do
  for _,k in h.karts do k:SetAttribute(key,true)end;h.tick(.01)
  for _,k in h.karts do check(enabled(effects(k,'ParticleEmitter','KDMSpeedJet'))==0 and enabled(effects(k,'Trail','KDMSpeed'))==0,'suppression '..key)end
  for _,k in h.karts do k:SetAttribute(key,false)end;h.tick(.01)
 end
 local bot=h.karts[4];bot:SetAttribute('KartOwnerUserId',nil)
 for _,k in h.karts do k:SetAttribute('KartDrifting',false)end;set(states[2])
 check(enabled(effects(bot,'Trail','KDMSpeed'))==2 and enabled(effects(bot,'ParticleEmitter','KDMSpeedJet'))==0,'Bot motion is High only')
 bot:SetAttribute('KartOwnerUserId',4);set(states[1])
end)
print('PASS: '..n..' N1A particle profile, direction, Shield, 20-cycle self/remote budget and line-regression checks')
