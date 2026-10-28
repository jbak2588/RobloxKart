local rb=require('@lune/roblox')
local n=0
local function check(v,label)assert(v,label);n+=1 end
require('./helpers/world_vfx_harness')(4,20,function(h)
 local function effects(k,class,prefix)
  local result={};for _,o in k:GetDescendants()do if o:IsA(class) and o.Name:find(prefix,1,true)then result[#result+1]=o end end;return result
 end
 local function enabled(list)local count=0;for _,o in list do if o.Enabled then count+=1 end end;return count end
 local states={
  {0,false,false,0,0,'NONE'},
  {70,false,false,2,4,'HIGH_SPEED'},
  {80,false,false,2,4,'HIGH_SPEED'},
  {85,false,false,4,4,'HIGH_SPEED'}, -- smoothstep(.875) rounds to bucket19: secondary ribbons active
  {90,false,false,4,4,'HIGH_SPEED'},
  {100,true,false,0,4,'MINI_BOOST'},
  {100,false,true,0,6,'NITRO'},
  {100,true,true,0,6,'NITRO'}
 }
 local function set(state)
  for _,k in h.karts do k.PrimaryPart.AssemblyLinearVelocity=rb.Vector3.new(0,0,-state[1]);k:SetAttribute('KartBoosting',state[2]);k:SetAttribute('KartNitroActive',state[3])end
  h.tick(.01)
 end
 for _,k in h.karts do
  -- Primary trail points (rear bumper)
  for index=1,2 do
   local a=k.PrimaryPart:FindFirstChild('KDMSpeedPoint'..index..'_1');local b=k.PrimaryPart:FindFirstChild('KDMSpeedPoint'..index..'_2')
   local center=(a.Position+b.Position)*.5;local side=if index==1 then -1 else 1
   check(math.abs(center.X-side*(4+.5+.12)*.85)<1e-5,'accepted rear bumper corner Primary origin')
   check(math.abs(center.Y-.60)<1e-5 and math.abs(center.Z-4.40)<1e-5,'accepted rear bumper Primary height and trailing Z')
  end
  -- Secondary trail points (upper cowl slipstream)
  for index=3,4 do
   local a=k.PrimaryPart:FindFirstChild('KDMSpeedPoint'..index..'_1');local b=k.PrimaryPart:FindFirstChild('KDMSpeedPoint'..index..'_2')
   local center=(a.Position+b.Position)*.5;local side=if index==3 then -1 else 1
   check(math.abs(center.X-(side*(4+.5+.12)*.85+side*.70))<1e-5,'secondary upper cowl wider origin')
   check(math.abs(center.Y-1.25)<1e-5 and math.abs(center.Z-3.90)<1e-5,'secondary upper cowl elevated and forward Z origin')
  end
  -- Exhaust jet points
  for _,point in effects(k,'Attachment','KDMSpeedJetPoint')do
   check(point.CFrame.Position.Z==3,'actual exhaust metadata position')
   check(point.CFrame:VectorToWorldSpace(rb.Vector3.zAxis):Dot(rb.Vector3.zAxis)>.999,'rearward Back orientation independent of camera')
  end
  check(h.count(k,'Attachment','KDMSpeedVortexPoint')==0 and #effects(k,'ParticleEmitter','KDMSpeedVortex')==0,'vortex retired')
 end
 local allocations=h.allocated()
 for cycle=1,20 do
  for _,state in states do
   set(state)
   for _,k in h.karts do
    local trails=effects(k,'Trail','KDMSpeed')
    local jetEmitters=effects(k,'ParticleEmitter','KDMSpeedJet')
    check(enabled(trails)==state[4] and enabled(jetEmitters)==state[5],'self/remote tier configuration '..state[6]..' spd '..state[1])
    check(#trails==4 and h.count(k,'Attachment','KDMSpeedPoint')==8 and h.count(k,'Attachment','KDMSpeedJetPoint')==2 and #jetEmitters==6,'fixed 20-instance V2 arcade airflow budget')
    local jetRate=0;local jetProfile={}
    for _,e in jetEmitters do
     if e.Enabled then
      jetRate+=e.Rate
      check(e.Acceleration==rb.Vector3.zero and e.EmissionDirection==rb.Enum.NormalId.Back,'no aura/upward acceleration')
      check((if e.Name=='KDMSpeedJetSpark' then e.Orientation==rb.Enum.ParticleOrientation.FacingCamera else e.Orientation==rb.Enum.ParticleOrientation.VelocityParallel) and e.LockedToPart,'rear jet locked to kart and parallel orientation')
      check(e.Lifetime.Max<=.38 and e.Speed.Max<=42 and e.SpreadAngle.X<=13,'short directional bounded particles')
      check(e.LightEmission<=1 and e.VelocityInheritance==0,'bounded light/inheritance')
      check(e.Texture:find('rbxasset://textures/particles/',1,true)==1,'built-in texture only')
      check(e.Transparency.Keypoints[#e.Transparency.Keypoints].Value==1 and e.Size.Keypoints[1].Value<=1.75,'fade and compact source')
      local mini=state[6]=='MINI_BOOST'
      local nitro=state[6]=='NITRO'
      if e.Name=='KDMSpeedJetCore' then
       local expCore = if nitro then 65 elseif mini then 45 elseif state[1]==70 then 31 elseif state[1]==80 then 34 elseif state[1]==85 then 36 elseif state[1]==90 then 38 else 0
       check(e.Rate==expCore and (expCore==0 or math.abs(e.Lifetime.Min-(if nitro then .14 elseif mini then .12 else .11))<1e-6),'Core exact tier profile')
      elseif e.Name=='KDMSpeedJetPlume' then
       local expPlume = if nitro then 35 elseif mini then 25 elseif state[1]==70 then 22 elseif state[1]==80 then 25 elseif state[1]==85 then 26 elseif state[1]==90 then 28 else 0
       check(e.Rate==expPlume,'Plume exact tier profile')
      else check(if nitro then e.Rate==18 else e.Rate==0,'Nitro-only small spark')end
     end
     jetProfile[e]={e.Enabled,e.Rate,e.Size,e.Transparency,e.Speed,e.Lifetime,e.LightEmission,e.SpreadAngle,e.Color}
    end
    local expJetRate = if state[6]=='NITRO' then 236 elseif state[6]=='MINI_BOOST' then 140
     elseif state[1]==70 then 106 elseif state[1]==80 then 118 elseif state[1]==85 then 124 elseif state[1]==90 then 132 else 0
    check(jetRate==expJetRate,'total rate bounded and Nitro wins simultaneous flags')
    check(#effects(k,'ParticleEmitter','KDMSpeedVortex')==0,'no wheel wake grey smoke puffs')

    if state[6]=='HIGH_SPEED' then
     for i,t in trails do
      if i<=2 then
       local expLife = if state[1]==70 then .086 elseif state[1]==80 then .075 elseif state[1]==85 then (.075-(.075-.0667)*2/3) elseif state[1]==90 then .0667 else .086
       check(math.abs(t.Lifetime-expLife)<1e-3 and t.LightEmission==.18,'Primary High trail lifetime <= 6 studs')
       local expW = if state[1]==70 then .12 elseif state[1]==80 then .16 elseif state[1]==85 then (.16+.04*2/3) elseif state[1]==90 then .20 else .12
       check(math.abs(t.WidthScale.Keypoints[1].Value - expW) < 1e-3 and t.WidthScale.Keypoints[#t.WidthScale.Keypoints].Value == 0, 'tapered width scale ending at 0')
       check(math.abs(t.Transparency.Keypoints[1].Value - 0.75) < 1e-3 and t.Transparency.Keypoints[#t.Transparency.Keypoints].Value == 1, 'fading transparency ending at 1.0')
      else
       local expLife = if state[1]==70 then (.086*.60) elseif state[1]==80 then (.075*.60) elseif state[1]==85 then ((.075-(.075-.0667)*2/3)*.60) elseif state[1]==90 then (.0667*.60) else (.086*.60)
       check(math.abs(t.Lifetime-expLife)<1e-3 and t.LightEmission==.14,'Secondary High trail lifetime')
      end
     end
    end
    if state[6]=='MINI_BOOST' or state[6]=='NITRO' then check(enabled(trails)==0,'no boost road-line ribbons')end
    k:SetAttribute('KartShieldActive',true);h.tick(.01)
    for e,p in jetProfile do check(e.Enabled==p[1] and e.Rate==p[2] and e.Size==p[3] and e.Transparency==p[4] and e.Speed==p[5] and e.Lifetime==p[6] and e.LightEmission==p[7] and e.SpreadAngle==p[8] and e.Color==p[9],'Shield excludes all jet profile inputs')end
    k:SetAttribute('KartShieldActive',false)
   end
  end
  set(states[6]);for _,k in h.karts do for _,e in effects(k,'ParticleEmitter','KDMSpeedJet')do e.cleared=false end end
  set(states[2]);for _,k in h.karts do for _,e in effects(k,'ParticleEmitter','KDMSpeedJet')do check(not e.cleared,'expiry does not clear live particles')end end
  set(states[7]);set(states[2]);set(states[1])
  for _,k in h.karts do
   for _,e in effects(k,'ParticleEmitter','KDMSpeedJet')do check(e.cleared and not e.Enabled,'NONE clears suppressed particles')end
  end
 end
 check(h.allocated()==allocations,'20 cycles do not create emitters/attachments/trails')
 check(h.run.Heartbeat.Count()==1,'single shared observer')
 set(states[2]);for _,k in h.karts do k:SetAttribute('KartDrifting',true)end;h.tick(.01)
 for _,k in h.karts do check(enabled(effects(k,'Trail','KDMSpeed'))==0 and enabled(effects(k,'ParticleEmitter','KDMSpeedJet'))==4,'Trails yield to Drift but cruise flame remains active')end
 set(states[6]);for _,k in h.karts do check(enabled(effects(k,'ParticleEmitter','KDMSpeedJet'))==4,'Mini follows authoritative state while Drifting')end
 for _,key in {'KartOffTrack','RaceControlsLocked'}do
  for _,k in h.karts do k:SetAttribute(key,true)end;h.tick(.01)
  for _,k in h.karts do check(enabled(effects(k,'ParticleEmitter','KDMSpeedJet'))==0 and enabled(effects(k,'Trail','KDMSpeed'))==0,'suppression '..key)end
  for _,k in h.karts do k:SetAttribute(key,false)end;h.tick(.01)
 end
 local localPark=h.karts[1];localPark:SetAttribute('LobbyKart',true);localPark:SetAttribute('LobbyOwnerUserId',1)
 for _,k in h.karts do k:SetAttribute('KartDrifting',false)end
 set(states[5]);check(enabled(effects(localPark,'Trail','KDMSpeed'))==4 and enabled(effects(localPark,'ParticleEmitter','KDMSpeedJet'))==4,'local Park kart has the same full 90-stud air trails and cruise jet')
 localPark:SetAttribute('LobbyKart',false);h.tick(.01)
 local bot=h.karts[4];bot:SetAttribute('KartOwnerUserId',nil)
 for _,k in h.karts do k:SetAttribute('KartDrifting',false)end;set(states[2])
 check(enabled(effects(bot,'Trail','KDMSpeed'))==2 and enabled(effects(bot,'ParticleEmitter','KDMSpeedJet'))==4,'Bot motion is High baseline only')
 bot:SetAttribute('KartOwnerUserId',4);set(states[1])
end)
print('PASS: '..n..' V2 arcade airflow particle profile, direction, Shield, 20-cycle self/remote budget and line-regression checks')
