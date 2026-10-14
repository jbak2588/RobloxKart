local rb=require('@lune/roblox')
local n=0
local function check(v,label)assert(v,label);n+=1 end
require('./helpers/world_vfx_harness')(4,2,function(h)
 for _,k in h.karts do
  local body=k:FindFirstChild('Chassis')
  body.AssemblyLinearVelocity=rb.Vector3.new(0,0,-100)
  k:SetAttribute('KartNitroActive',true)
 end
 h.tick(.016)
 local allocated=h.allocated()
 for _,k in h.karts do k:SetAttribute('KartNitroEndReason','duration_complete');k:SetAttribute('KartNitroActive',false)end
 h.tick(.016)
 for _,k in h.karts do for _,f in k:GetDescendants()do if f.Name=='RearEmitter'then check(f.Enabled and f.Rate>0,'normal expiry keeps tail')end end end
 for _,k in h.karts do k:FindFirstChild('Chassis').AssemblyLinearVelocity=rb.Vector3.new(0,0,-90)end
 h.tick(.3)
 for _,k in h.karts do for _,f in k:GetDescendants()do if f.Name=='RearEmitter'then check(f.Rate>0 and f.Rate<80,'speed dependent fading')end end end
 for _,k in h.karts do k:SetAttribute('KartDrifting',true)end
 h.tick(.016)
 for _,k in h.karts do for _,f in k:GetDescendants()do if f.Name=='RearEmitter'then check(not f.Enabled and f.cleared,'redrift clears residual particles')end end;k:SetAttribute('KartDrifting',false)end
 check(h.allocated()==allocated,'fade allocates no new instances')
 for _,k in h.karts do
  k:SetAttribute('KartBoosting',true);k:SetAttribute('KartBoostEndReason','');k:FindFirstChild('Chassis').AssemblyLinearVelocity=rb.Vector3.new(0,0,-100)
 end
 h.tick(.016)
 for _,k in h.karts do k:SetAttribute('KartBoosting',false);k:SetAttribute('KartBoostEndReason','duration_complete')end
 h.tick(.016)
 for _,k in h.karts do k:FindFirstChild('Chassis').AssemblyLinearVelocity=rb.Vector3.new(0,0,-82)end
 h.tick(.016)
 for _,k in h.karts do for _,f in k:GetDescendants()do if f.Name=='RearEmitter'then check(not f.Enabled and f.Rate==0,'82 ends Mini Boost tail')end end end
 for _,k in h.karts do k:FindFirstChild('Chassis').AssemblyLinearVelocity=rb.Vector3.zero end
 h.tick(.016)
end)
print('PASS: '..n..' production flame fade / emergency / allocation checks')
