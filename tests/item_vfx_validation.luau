local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local n=0
local function check(v,l) assert(v,l); n+=1 end
local c=luau.load(fs.readFile("src/shared/KDMItemVFXConfig.luau"))()
local function frozen(t)
 check(table.isfrozen(t),"nested immutable config")
 for _,v in t do if type(v)=="table" then frozen(v) elseif type(v)=="number" then check(v==v and v>=0 and v<1000,"finite presentation value") end end
end
frozen(c)
for _,k in {"Missile","Thunder","Shield","Slick","Nitro","Smoke"} do check(type(c[k])=="table","category "..k) end
check(not pcall(function() c.Missile.CameraShake.Duration=100 end),"nested write rejected")
local motion=luau.load(fs.readFile("src/shared/KDMImpactCameraMotion.luau"),{environment={Vector3=rb.Vector3}})()
local m=motion.new(c)
check(not m:play("Shield",0) and not m:play("Slick",0),"no block/Slick shake")
for _,kind in {"Missile","Thunder"} do
 check(m:play(kind,0),"valid impact")
 for i=0,40 do
  local p,r,a=m:sample(i/100)
  check(math.abs(p.X)<=c.Camera.MaxPositionAmplitude and math.abs(p.Y)<=c.Camera.MaxPositionAmplitude,"position clamp")
  check(math.abs(r.X)<=c.Camera.MaxRotationAmplitude and math.abs(r.Y)<=c.Camera.MaxRotationAmplitude and math.abs(r.Z)<=c.Camera.MaxRotationAmplitude,"angle clamp")
  if i/100>=c[kind].CameraShake.Duration then check(not a and p==rb.Vector3.zero and r==rb.Vector3.zero,"exact zero expiry") end
 end
end
for i=1,100 do m:play(if i%2==0 then "Missile" else "Thunder",0) end
local p,r=m:sample(0)
check(r.X<=c.Camera.MaxRotationAmplitude,"100 impulses replace instead of stack")
m:clear();check(not select(3,m:sample(0)),"lifecycle cancellation")
-- Baseline gameplay remains unchanged, including the safe Slick fallback.
local process=require("@lune/process")
for _,path in {"src/shared/KDMGameplayBalance.luau","src/shared/KartConfig.luau","src/server/PrototypeWorld.luau","src/server/RaceBotController.luau","src/client/RaceHudController.luau"} do
 local old=process.exec("git",{"show","09f82653106f59e73089a84e43d13c58c145a928:"..path})
 local normalize=function(s)return require("./helpers/m1_presentation_freeze")(require("./helpers/p2a_bot_controller_freeze")(s))end
 check(old.ok and normalize(old.stdout)==normalize(fs.readFile(path)),"frozen gameplay/geometry/HUD "..path)
end
check(c.Slick.SpinDegrees==360 and c.Slick.SpinEnabled,"authorized spin presentation")
print("PASS: "..n.." VFX config, finite camera motion, clamps, cleanup and gameplay parity checks")
