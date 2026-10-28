local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local balance=luau.load(fs.readFile('src/shared/KDMGameplayBalance.luau'))()
local shared={WaitForChild=function()return 'balance'end}
local visual=luau.load(fs.readFile('src/client/KartVisualMotionController.luau'),{environment={
 game={GetService=function(_,name) return if name=='ReplicatedStorage' then {WaitForChild=function()return shared end} else {} end},
 require=function()return balance end,CFrame=rb.CFrame}})()
for _,side in {-1,1} do
 local normal=-side*math.rad(25)
 assert(visual.resolveDriftSteer(normal,0)==normal,'normal entry preserved')
 local counter=visual.resolveDriftSteer(normal,-side*math.rad(20))
 assert(counter*side>0 and math.abs(math.deg(counter))<=34,'visible countersteer opposes body turn')
 assert(math.abs(math.deg(visual.resolveDriftSteer(normal,-side*math.rad(70))))<=34.00001,'wheel lock bounded')
end
require('./helpers/world_vfx_harness')(4,4,function(h)
 for _,kart in h.karts do
  kart:SetAttribute('KartDrifting',true)
  kart.PrimaryPart.AssemblyLinearVelocity=rb.Vector3.new(12,0,-50)
 end
 h.tick(.05)
 for _,kart in h.karts do
  local n=0
  for _,o in kart:GetDescendants() do if o.Name=='DriftTireTrail' then
   n+=1;assert(o.Enabled and o.Lifetime==2.5,'persistent grounded marks visible')
   assert(math.abs(o.Attachment0.WorldPosition.Y-.04)<1e-6,'visual road projection above physical support')
  end end
  assert(n==2,'one rear tire pair per kart')
 end
 local allocated=h.allocated();for i=1,200 do h.tick(.04)end
 assert(allocated==h.allocated(),'no per-frame instance churn')
 h.workspace.noGround=true;h.tick(.05)
 for _,kart in h.karts do for _,o in kart:GetDescendants() do if o.Name=='DriftTireTrail' then assert(not o.Enabled,'no aerial marks')end end end
 h.workspace.noGround=false;h.tick(.05)
 for _,kart in h.karts do kart.PrimaryPart.CFrame=rb.CFrame.new(3000,0,0) end
 h.tick(.05)
 for _,kart in h.karts do for _,o in kart:GetDescendants() do if o.Name=='DriftTireTrail' then assert(not o.Enabled,'no marks outside visual road')end end end
 for _,kart in h.karts do kart.PrimaryPart.CFrame=rb.CFrame.identity end
 h.tick(.05)
 for _,kart in h.karts do kart:SetAttribute('KartDrifting',false)end
 h.tick(.05)
 for _,kart in h.karts do for _,o in kart:GetDescendants() do if o.Name=='DriftTireTrail' then assert(not o.Enabled,'release stops emission')end end end
end)
local audio=luau.load(fs.readFile('src/shared/AudioConfig.luau'))()
local factor=math.clamp((14-audio.DRIFT.MIN_SLIP_DEGREES)/(audio.DRIFT.FULL_SLIP_DEGREES-audio.DRIFT.MIN_SLIP_DEGREES),0,1)
assert(factor*audio.DRIFT.MAX_VOLUME>.5,'D1 typical slip produces audible volume')
assert(audio.ASSETS.DRIFT_LOOP=='rbxassetid://9120397552','existing licensed asset retained')
print('PASS: D2 countersteer, grounded marks, four-racer bounded lifecycle and drift gain')
