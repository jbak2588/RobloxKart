local rb=require('@lune/roblox')
require('./helpers/world_vfx_harness')(1,1,function(h)
 local kart=h.karts[1]
 kart:SetAttribute('KartDrifting',true)
 local race=assert(h.modules.exhaust.new(kart))
 local park=h.object('Folder');park.Name='HubParkRookieLoopG2'
 park:SetAttribute('DriveGeometry','ROOKIE_LOOP_V1');park.Parent=h.workspace
 local ground=h.object('Part');ground.Name='G2SafetyGround';ground.Parent=park
 kart:SetAttribute('LobbyKart',true);kart.Parent=park
 local practice=assert(h.modules.exhaust.new(kart))
 for i,smoke in practice.smokes do
  assert(smoke.Lifetime==race.smokes[i].Lifetime,'Park/public smoke lifetime parity')
  assert(smoke.Lifetime.Min==3 and math.abs(smoke.Lifetime.Max-4.2)<1e-5,'public lifetime retained')
 end
 for _,dt in {.016,.05} do
  for _,angle in {5,10,18,24,35} do
   kart.PrimaryPart.AssemblyLinearVelocity=rb.Vector3.new(50*math.tan(math.rad(angle)),0,-50)
   race:update(dt,true);practice:update(dt,true)
   for i,smoke in practice.smokes do
    assert(smoke.Rate==race.smokes[i].Rate and smoke.Enabled==race.smokes[i].Enabled,'Park/public emission parity at matched slip and LOD')
    assert(smoke.Rate<=34,'public per-wheel rate cap')
   end
  end
 end
 kart:SetAttribute('KartDrifting',false)
 practice:update(.016,true)
 for _,smoke in practice.smokes do assert(smoke.Rate==0 and not smoke.Enabled,'release stops emission') end
 practice:destroy();race:destroy()
 kart.Parent=h.prototype;kart:SetAttribute('LobbyKart',nil);park:Destroy()
 print('PASS: Park/public smoke lifetime, slip response, LOD and release parity')
end)
