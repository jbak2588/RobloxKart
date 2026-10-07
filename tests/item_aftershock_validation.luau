local fs,luau,rb=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local n=0
local function check(v,l)assert(v,l);n+=1 end
local c=luau.load(fs.readFile("src/shared/KDMItemVFXConfig.luau"))()
local node={WaitForChild=function(self)return self end}
local v=luau.load(fs.readFile("src/server/RaceItemVisuals.luau"),{environment={game={GetService=function()return node end},require=function()return c end,
 Instance=rb.Instance,Vector3=rb.Vector3,CFrame=rb.CFrame,Color3=rb.Color3,ColorSequence=rb.ColorSequence,NumberSequence=rb.NumberSequence,Enum=rb.Enum}})()
local motion=luau.load(fs.readFile("src/shared/KDMImpactCameraMotion.luau"),{environment={Vector3=rb.Vector3}})()
local folder=rb.Instance.new("Folder");local chassis=rb.Instance.new("Part");chassis.CFrame=rb.CFrame.identity;chassis.Position=rb.Vector3.zero
check(c.Missile.ImpactLifetime==.42 and c.Missile.SparkCount==12 and c.Missile.PuffScale==1.35,"requested bounded Missile tuning")
check(c.Thunder.StrikeLifetime==.46 and c.Thunder.ArcLifetime==.46,"requested Thunder residual")
check(c.Camera.MaxPositionAmplitude==.06 and c.Camera.MaxRotationAmplitude==math.rad(1.8),"original camera ceilings")
for round=1,20 do
 for _,blocked in {false,true} do
  local flash=v.missileImpact(folder,rb.Vector3.zero,blocked)
  local count=#flash:GetDescendants()
  v.updateMissileImpact(flash,0)
  check(blocked or flash.Aftershock.Transparency==1,"primary has no premature aftershock")
  v.updateMissileImpact(flash,.119)
  check(blocked or flash.Aftershock.Transparency==1,"aftershock respects delay")
  v.updateMissileImpact(flash,.12)
  check(blocked or math.abs(flash.Aftershock.Transparency-.55)<1e-5,"single weaker aftershock")
  check((flash:FindFirstChild("Burst12")~=nil)==not blocked and not flash:FindFirstChild("Burst13"),"spark budget and block distinction")
  check((flash:FindFirstChild("Aftershock")~=nil)==not blocked,"no ordinary residual on Shield")
  for i=13,43 do v.updateMissileImpact(flash,i/100);check(#flash:GetDescendants()==count,"updates allocate no extra waves") end
  check(v.updateMissileImpact(flash,.42),"finite lifetime");flash:Destroy()
  local strike=v.thunderStrike(folder,chassis,blocked)
  local count2=#strike:GetDescendants()
  v.updateThunderStrike(strike,0);local primary=strike.Bolt1.Transparency
  v.updateThunderStrike(strike,.11);local gap=strike.Bolt1.Transparency
  v.updateThunderStrike(strike,.12);local second=strike.Bolt1.Transparency
  check(blocked or primary<second and second<gap,"weaker delayed after-flash")
  check((strike.Impact:FindFirstChild("ElectricArc1")~=nil)==not blocked,"no blocked arcs")
  check(not blocked or primary>=.83,"blocked dim only")
  for i=13,47 do v.updateThunderStrike(strike,i/100);check(#strike:GetDescendants()==count2,"residual reuses finite geometry") end
  v.updateThunderStrike(strike,.46);check(strike.Bolt1.Transparency==1,"not sustained opaque lightning");strike:Destroy()
 end
 check(#folder:GetChildren()==0,"20-hit cleanup baseline")
 for _,kind in {"Missile","Thunder"} do
  local m=motion.new(c);m:play(kind,0);local cfg=c[kind].CameraShake
  local _,a=m:sample(0);local _,b=m:sample(cfg.AftershockDelay)
  check(math.abs(b.X/a.X-cfg.AftershockScale)<1e-5,"secondary camera amplitude ratio")
  local _,before=m:sample(cfg.AftershockDelay-.001);check(before.Magnitude<b.Magnitude,"distinct delayed residual kick")
  for i=0,100 do local p,r=m:sample(i/200);check(p.Magnitude<=.060001 and r.Magnitude<=math.rad(1.80001),"repeated sequences vector clamps") end
  local p,r,active=m:sample(cfg.Duration);check(not active and p==rb.Vector3.zero and r==rb.Vector3.zero,"exact zero residual")
  m:play(kind,1);m:play(kind,1.01);check(m.born==1.01,"whole sequence replaces, no queued secondary")
 end
end
local fixturePath="tests/fixtures/item_aftershock_starting_hashes.json"
check(fs.isFile(fixturePath),"versioned freeze fixture exists")
local serde=require("@lune/serde")
local fixture=serde.decode("json",fs.readFile(fixturePath))
check(fixture.hash_mode=="sha256-canonical-lf-v1","explicit canonical hash mode")
local hashes=fixture.files
local function canonicalHash(source)
 return serde.hash("sha256",(source:gsub("\r\n","\n"):gsub("\r","\n")))
end
check(canonicalHash("abc\n123\n")==canonicalHash("abc\r\n123\r\n"),"LF and CRLF equivalent")
check(canonicalHash("abc\n123\n")==canonicalHash("abc\r123\r"),"lone CR equivalent")
check(canonicalHash("abc\n123\n")~=canonicalHash("abc\n124\n"),"content mutation detected")
check(canonicalHash("abc  \n")~=canonicalHash("abc\n"),"space mutation detected")
check(canonicalHash("abc\n\n")~=canonicalHash("abc\n"),"blank-line mutation detected")
local freezePaths={"src/server/SlickMotion.luau","src/client/KDMItemVFXController.luau","src/shared/KDMGameplayBalance.luau","src/server/RaceBotController.luau","src/server/PrototypeWorld.luau","src/client/GarageUiController.luau"}
local hashCount=0
for _ in hashes do hashCount+=1 end
check(hashCount==#freezePaths,"exact intended freeze hash count")
for _,path in freezePaths do
 local expected=hashes[path:gsub("/","\\")]
 check(type(expected)=="string" and #expected==64 and expected:match("^[0-9a-f]+$")~=nil,"valid expected SHA256 "..path)
end
for _,path in freezePaths do
 local key=path:gsub("/","\\")
 check(canonicalHash(require("./helpers/m1_presentation_freeze")(fs.readFile(path)))==hashes[key],"exact L1/K2 canonical freeze "..path)
end
print("PASS: "..n.." L1A actual two-stage world/camera, 20-hit cleanup and L1/K2 freeze checks")
