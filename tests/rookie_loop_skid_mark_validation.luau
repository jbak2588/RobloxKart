local rb=require('@lune/roblox')
require('./helpers/world_vfx_harness')(2,1,function(h)
 local k=h.karts[2]
 local zone=h.object('Model');zone.Name='HubParkRookieLoopG2';zone.Parent=h.workspace
 zone:SetAttribute('DriveGeometry','ROOKIE_LOOP_V1')
 local floor=h.object('Part');floor.Name='G2SafetyGround';floor.CanQuery=true;floor.Parent=zone
 k.Parent=zone;k:SetAttribute('LobbyKart',true);k:SetAttribute('KartDrifting',true)
 k.PrimaryPart.AssemblyLinearVelocity=rb.Vector3.new(20,0,-50)
 local r=assert(h.modules.exhaust.new(k))
 r:update(.05,true)
 assert(h.workspace.lastRayParams.FilterDescendantsInstances[1]==floor,'park tire contact targets queryable support')
 for _,t in r.trails do
  assert(t.Enabled,'both tire marks enabled during grounded drift')
  assert(math.abs(t.Attachment0.WorldPosition.Y-.41)<.0001,'mark above .37 visual road, not hidden at support height')
 end
 h.workspace.noGround=true;r:update(.05,true)
 for _,t in r.trails do assert(not t.Enabled,'airborne drift leaves no floating tire mark')end
 h.workspace.noGround=false;r:update(.05,true)
 k:SetAttribute('KartDrifting',false);r:update(.05,true)
 for _,t in r.trails do assert(not t.Enabled,'normal driving does not leave marks')end
 r:destroy()
 -- Existing oval keeps the original floor and .04 drawing offset.
 floor.Name='LobbyFrontSmoothFloor';zone:SetAttribute('DriveGeometry',nil)
 k:SetAttribute('KartDrifting',true)
 local legacy=assert(h.modules.exhaust.new(k));legacy:update(.05,true)
 assert(h.workspace.lastRayParams.FilterDescendantsInstances[1]==floor,'legacy floor unchanged')
 for _,t in legacy.trails do assert(t.Enabled and math.abs(t.Attachment0.WorldPosition.Y-.04)<.0001,'legacy mark height unchanged')end
 legacy:destroy();k:SetAttribute('KartDrifting',false);k:SetAttribute('LobbyKart',nil);k.Parent=h.prototype
 zone:Destroy()
 print('PASS RookieLoop skid marks: grounded pair, visible height, airborne/idle suppression, legacy floor preserved')
end)
