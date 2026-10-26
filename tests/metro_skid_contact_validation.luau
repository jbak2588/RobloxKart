local rb=require('@lune/roblox')
require('./helpers/world_vfx_harness')(1,1,function(h)
 local track=h.prototype:FindFirstChild('TestTrack')
 track:SetAttribute('GeometryId','PracticeCircuitV1')
 track:SetAttribute('TrackId','Track01Metro')
 h.workspace.noGround=true
 local road=track:FindFirstChild('Road'):GetChildren()[1]
 road.Position=rb.Vector3.new(0,-.5,0);road.CanQuery=false
 local kart=h.karts[1];kart:SetAttribute('KartDrifting',true)
 kart.PrimaryPart.AssemblyLinearVelocity=rb.Vector3.new(20,0,-50)
 local renderer=h.modules.exhaust.new(kart)
 local before=h.workspace.rayCount or 0
 renderer:update(.05,true)
 local active=0
 for _,t in kart:GetDescendants()do if t.Name=='DriftTireTrail' and t.Enabled then
  active+=1
  assert(math.abs(t.Attachment0.WorldPosition.Y-.04)<.001,'mark lies above visual road')
 end end
 assert(active==2,'both tire marks render on non-queryable Metro road')
 assert((h.workspace.rayCount or 0)==before,'visual contact needs no query flag change/raycast')
 assert(road.CanQuery==false,'preserves visual-road query contract')
 kart.PrimaryPart.CFrame=rb.CFrame.new(0,10,0);renderer:update(.05,true)
 for _,t in kart:GetDescendants()do if t.Name=='DriftTireTrail' then assert(not t.Enabled,'airborne has no mark')end end
 kart.PrimaryPart.CFrame=rb.CFrame.new(150,0,0);renderer:update(.05,true)
 for _,t in kart:GetDescendants()do if t.Name=='DriftTireTrail' then assert(not t.Enabled,'outside road has no mark')end end
 renderer:destroy();kart:SetAttribute('KartDrifting',false)
 kart.PrimaryPart.CFrame=rb.CFrame.identity;kart.PrimaryPart.AssemblyLinearVelocity=rb.Vector3.zero
 print('PASS: Metro non-queryable road contact without Raycast hits, tire height, airborne/off-road rejection')
end)
