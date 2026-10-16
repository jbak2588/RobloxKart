local rb=require('@lune/roblox')
local n=0
local function check(v,label)assert(v,label);n+=1 end
require('./helpers/world_vfx_harness')(1,1,function(h)
 local visual=h.object('Model')
 for _,side in {'Left','Right'}do
  local point=h.object('Attachment');point.CFrame=rb.CFrame.identity;point:SetAttribute('EffectRole','Exhaust'..side);point.Parent=visual
 end
 local effect=h.modules.exhaust.createBoostVisuals(visual)
 check(h.count(visual,'ParticleEmitter')==6,'exactly six original human template emitters')
 local initial=#visual:GetDescendants()
 for _,lod in {1,.5,0,1}do
  effect:update(true,lod)
  for _,f in visual:GetDescendants()do if f:IsA('ParticleEmitter')then
   check(f.Enabled==(lod>0),'boost obeys observer distance LOD')
   check(math.abs(f.Rate-f:GetAttribute('TemplateRate')*.7*lod)<1e-6,'same human Mini Boost density')
  end end
 end
 for cycle=1,100 do effect:update(false,1);effect:update(true,1)end
 check(#visual:GetDescendants()==initial,'repeatable boosts allocate no additional effects')
 effect:update(false,1)
 for _,f in visual:GetDescendants()do if f:IsA('ParticleEmitter')then check(not f.Enabled and f.cleared,'release clears stopped showcase flame')end end
 effect:destroy()
 check(#visual:GetDescendants()==2,'cleanup destroys both cloned template attachments')
end)
print('PASS '..n..' demo boost template / Mini density / LOD / repeated lifecycle checks')
