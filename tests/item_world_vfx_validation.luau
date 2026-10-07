local fs,luau,rb=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local cfg=luau.load(fs.readFile("src/shared/KDMItemVFXConfig.luau"))()
local node={WaitForChild=function(self)return self end}
local v=luau.load(fs.readFile("src/server/RaceItemVisuals.luau"),{environment={game={GetService=function()return node end},require=function()return cfg end,
 Instance=rb.Instance,Vector3=rb.Vector3,CFrame=rb.CFrame,Color3=rb.Color3,ColorSequence=rb.ColorSequence,NumberSequence=rb.NumberSequence,Enum=rb.Enum}})()
local n=0
local function check(x,l)assert(x,l);n+=1 end
local folder=rb.Instance.new("Folder")
local chassis=rb.Instance.new("Part");chassis.CFrame=rb.CFrame.identity;chassis.Position=rb.Vector3.zero
local missile=v.missile(folder,rb.CFrame.identity)
check(math.abs(missile.Body.ExhaustTrail.Lifetime-cfg.Missile.TrailLifetime)<1e-6 and math.abs(missile.Body.SmokeTrail.Lifetime-cfg.Missile.SmokeLifetime)<1e-6,"bounded attached fire/smoke trails")
v.updateMissile(missile,.19);check(not missile:FindFirstChild("LaunchFlash"),"launch flash finite")
for _,blocked in {false,true} do
 local impact=v.missileImpact(folder,rb.Vector3.zero,blocked)
 check((impact:FindFirstChild("Burst1")~=nil)==not blocked,"no full explosion on block")
 check(v.updateMissileImpact(impact,cfg.Missile.ImpactLifetime),"impact expiration")
 for _,part in impact:GetDescendants() do if part:IsA("BasePart") then check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow,"visual-only burst") end end
 impact:Destroy()
 local strike=v.thunderStrike(folder,chassis,blocked)
 check((strike.Impact:FindFirstChild("ElectricArc1")~=nil)==not blocked,"electric arcs only actual hit")
 check(strike.Bolt1.Color~=missile.Nose.Color,"electric/physical color languages differ")
 strike:Destroy()
end
local kart=rb.Instance.new("Model")
local pulse=v.shieldPulse(kart,chassis)
check(pulse.BlockRipple.Adornee==pulse and pulse.BlockRipple.DepthMode==rb.Enum.HighlightDepthMode.Occluded,"Shield surface outline follows expanding pulse")
pulse:Destroy();check(#kart:GetChildren()==0,"block ripple shares cleanup owner")
missile:Destroy();check(#folder:GetChildren()==0,"no residual world effects")
print("PASS: "..n.." actual native world VFX budgets, block distinction, finite lifetime and cleanup checks")
