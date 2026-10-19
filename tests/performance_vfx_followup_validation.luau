local rb=require('@lune/roblox')
require('./helpers/world_vfx_harness')(2,1,function(h)
 local k=h.karts[2];k.PrimaryPart.Position=rb.Vector3.zero
 h.karts[1].PrimaryPart.Position=rb.Vector3.zero
 h.workspace.CurrentCamera={CFrame=rb.CFrame.new(0,0,200)}
 -- Isolate the remote renderer: the observer also updates the local kart.
 k:SetAttribute('KartDrifting',true);k.PrimaryPart.AssemblyLinearVelocity=rb.Vector3.new(20,0,-50)
 local renderer=h.modules.exhaust.new(k)
 local before=h.workspace.rayCount or 0
 renderer:update(.1,true);renderer:update(.1,true)
 assert((h.workspace.rayCount or 0)==before,'culled remote does not raycast')
 h.workspace.CurrentCamera.CFrame=rb.CFrame.new(0,0,110)
 for i=1,20 do renderer:update(.01,true) end
 local rays=(h.workspace.rayCount or 0)-before
 assert(rays==2,'far update throttled to one rear-wheel pair')
 assert(h.workspace.lastRayParams.FilterType==rb.Enum.RaycastFilterType.Include,'road-only filter')
 assert(h.workspace.lastRayParams.FilterDescendantsInstances[1].Name=='Road','road target retained')
 h.workspace.CurrentCamera.CFrame=rb.CFrame.identity
 renderer:update(.05,true)
 assert(h.workspace.rayCount>before+rays,'near reentry resumes contacts')
 renderer:destroy()
 h.workspace.CurrentCamera=nil
 k:SetAttribute('KartDrifting',false)
 -- Attributes can replicate after the fully constructed kart is parented.
 k.Parent=nil;k:SetAttribute('PrototypeKart',nil);k.Parent=h.prototype
 k:SetAttribute('PrototypeKart',true);h.tick(.05)
 assert(h.count(k,'ParticleEmitter','RearEmitter')==2,'late attribute discovery without periodic scan')
 print('PASS: remote culling, raycast cadence/filter, reentry and late attributes')
end)
