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
 check((impact:FindFirstChild("Shockwave1")~=nil)==not blocked,"real world shockwave only on accepted hit")
 if not blocked then
  v.updateMissileImpact(impact,.425)
  check(math.abs(impact.Size.X-16)<1e-5,"production service expands visible blast using live config")
  check(math.abs(impact.Shockwave1.Size.X-.55)<1e-5 and impact.Shockwave1.Size.Z>3,"ring is geometry rather than SelectionBox")
  check(impact.Shockwave1.Transparency<.6,"ring remains visible halfway through impact")
  check(not impact:FindFirstChild("Shockwave17"),"bounded sixteen-segment ring")
 end
 check(v.updateMissileImpact(impact,cfg.Missile.ImpactLifetime),"impact expiration")
 for _,part in impact:GetDescendants() do if part:IsA("BasePart") then check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow,"visual-only burst") end end
 impact:Destroy()
 local strike=v.thunderStrike(folder,chassis,blocked)
 check((strike.Impact:FindFirstChild("ElectricArc1")~=nil)==not blocked,"electric arcs only actual hit")
 check(strike.Bolt1.Color~=missile.Nose.Color,"electric/physical color languages differ")
 local burst=strike:FindFirstChild('ThunderExplosion')
 check((burst~=nil)==not blocked,'delayed explosion only for unshielded Thunder')
 if burst then
  local count=#strike:GetDescendants()
  check(burst.Transparency==1 and not burst.ImpactLight.Enabled,'bolt appears before explosion or light')
  for _,p in burst:GetDescendants()do if p:IsA('BasePart')then
   check(p.Transparency==1 and p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery,'initial burst hidden and noninteractive')
  end end
  v.updateThunderStrike(strike,cfg.ThunderImpact.Delay-.001)
  check(burst.Transparency==1 and burst.ImpactLight.Brightness==0,'no premature explosion')
  v.updateThunderStrike(strike,cfg.ThunderImpact.Delay)
  check(burst.Transparency<1 and burst.ImpactLight.Enabled,'explosion starts immediately after primary bolt')
  check(burst.ImpactLight.Range==38 and burst.ImpactLight.Brightness==9 and not burst.ImpactLight.Shadows,'requested bounded world light, no shadow pass')
  v.updateThunderStrike(strike,cfg.ThunderImpact.Delay+cfg.Missile.ImpactLifetime/2)
  check(math.abs(burst.Size.X-16)<1e-5 and burst.Transparency<.7,'shared missile expansion remains visible halfway')
  check(math.abs(burst.ImpactLight.Brightness-2.25)<1e-5,'light fades smoothly instead of staying at full brightness')
  check(burst.Shockwave1.Transparency<.6 and not burst:FindFirstChild('Shockwave17'),'visible bounded sixteen-segment shockwave')
  v.updateThunderStrike(strike,v.thunderStrikeLifetime())
  check(burst.Size.X==28 and math.abs((burst.Shockwave1.CFrame.Position-burst.CFrame.Position).Magnitude-math.sqrt(18*18+.35*.35))<1e-4,'maximum explosion 28 and ring diameter 36')
  check(burst.Transparency==1 and not burst.ImpactLight.Enabled and burst.ImpactLight.Brightness==0,'all explosion/light fades expire exactly')
  check(strike.Bolt1.Transparency==1 and #strike:GetDescendants()==count,'bolt never extended; updates allocate no extra effects')
  check(math.abs(v.thunderStrikeLifetime()-(.10+.85))<1e-5,'service owns the entire delayed explosion lifetime')
 else check(v.thunderStrikeLifetime(true)==cfg.Thunder.StrikeLifetime,'blocked strike retains original short cleanup')end
 strike:Destroy()
end
local warning=v.thunderWarning(folder,chassis)
local minX,maxX=math.huge,-math.huge
for i=1,3 do
 local cloud=warning:FindFirstChild("Cloud"..i)
 minX=math.min(minX,cloud.CFrame.Position.X-cloud.Size.X/2)
 maxX=math.max(maxX,cloud.CFrame.Position.X+cloud.Size.X/2)
 check(cloud.Size.Y==cfg.ThunderWarning.Height and cloud.Size.Z==cfg.ThunderWarning.Depth,"live cloud height/depth")
 check(cloud.Transparency<.2 and cloud.Anchored and not cloud.CanCollide and not cloud.CanQuery,"solid dark cosmetic cloud")
end
check(math.abs(maxX-minX-cfg.ThunderWarning.Width)<1e-5,"full cloud width actually 12.5 studs")
chassis.Position=rb.Vector3.new(100,10,30)
v.updateThunderWarning(warning,chassis)
check((warning.Cloud2.CFrame.Position-(chassis.Position+rb.Vector3.new(0,cfg.ThunderWarning.OffsetY+.4,0))).Magnitude<1e-4,"cloud follows target with live offset")
warning:Destroy()
local kart=rb.Instance.new("Model")
local pulse=v.shieldPulse(kart,chassis)
check(pulse.BlockRipple.Adornee==pulse and pulse.BlockRipple.DepthMode==rb.Enum.HighlightDepthMode.Occluded,"Shield surface outline follows expanding pulse")
pulse:Destroy();check(#kart:GetChildren()==0,"block ripple shares cleanup owner")
missile:Destroy();check(#folder:GetChildren()==0,"no residual world effects")
print("PASS: "..n.." actual native world VFX budgets, block distinction, finite lifetime and cleanup checks")
