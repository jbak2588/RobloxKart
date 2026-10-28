-- Execute the common production observer/Shield renderer for local and remote
-- practice karts, then retain the existing race lifecycle checks.
local n=0;local function check(v,label)assert(v,label);n+=1 end
require('./helpers/world_vfx_harness')(2,2,function(h)
 local hub=h.object('Model');hub.Name='KDMHub';hub.Parent=h.workspace
 local zone=h.object('Model');zone.Name='LobbyFrontTestDriveZone';zone.Parent=hub
 for i,k in h.karts do
  k.Parent=zone;k:SetAttribute('PrototypeKart',false);k:SetAttribute('LobbyKart',true);k:SetAttribute('LobbyOwnerUserId',i)
  h.players[i]:SetAttribute('RaceState','GARAGE');h.players[i]:SetAttribute('LobbyCombatSessionId','practice')
 end
 h.tick(.3)
 -- Simulate the separate local driving controller's already-owned exhaust.
 local exhaust=h.modules.exhaust.new(h.karts[1])
 for _,k in h.karts do
  local shell=h.object('Part');shell.Name='RaceItemShield';shell.LocalTransparencyModifier=0;shell.Parent=k
  k:SetAttribute('KartShieldActive',true)
 end
 h.tick(.01)
 for _,k in h.karts do
  local effect=k:FindFirstChild('KDMShieldWorld')
  print('R3_TRACE Shield',k.Name,effect~=nil,h.count(k,'Model','KDMShieldWorld'))
  check(effect~=nil and h.count(k,'Model','KDMShieldWorld')==1,'same Shield renderer used by both practice clients')
  check(effect:FindFirstChild('EnergyShell').Material==h.karts[2]:FindFirstChild('KDMShieldWorld'):FindFirstChild('EnergyShell').Material,'same ForceField material')
  check(effect:FindFirstChild('SoftGlow')~=nil and h.count(effect,'Trail')==8 and h.count(effect,'Part','Orbit')==8,'full race soft glow and eight orbit trails')
  check(k:FindFirstChild('RaceItemShield').LocalTransparencyModifier==1,'plain server shell hidden under rendered race shell')
  check(h.count(k,'ParticleEmitter','RearEmitter')==2,'local exhaust remains exactly one pair')
 end
 local effect=h.karts[1]:FindFirstChild('KDMShieldWorld')
 local before=effect:FindFirstChild('Orbit1').CFrame;h.tick(.1)
 check(effect:FindFirstChild('Orbit1').CFrame~=before,'local practice orbits animate')
 local alpha=effect:FindFirstChild('EnergyShell').Transparency
 h.players[1]:SetAttribute('LobbyItemBlockedSerial',1);h.tick(.001)
 check(effect:FindFirstChild('EnergyShell').Transparency<alpha,'practice block uses same race shell flash')
 for _,k in h.karts do k:SetAttribute('KartShieldActive',false);k:FindFirstChild('RaceItemShield'):Destroy()end
 h.tick(.01);h.tick(.31)
 for _,k in h.karts do check(not k:FindFirstChild('KDMShieldWorld'),'same expiry fade and cleanup')end
 exhaust:destroy()
 for i,k in h.karts do
  k.Parent=h.prototype;k:SetAttribute('LobbyKart',false);k:SetAttribute('PrototypeKart',true)
  h.players[i]:SetAttribute('RaceState','RACING')
 end
 h.tick(.01);hub:Destroy()
end)
print('PASS: '..n..' actual local/remote practice Shield parity, block flash, exhaust ownership and expiry checks')
