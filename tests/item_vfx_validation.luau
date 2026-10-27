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
-- VFX must not change gameplay. The owner-authorized private QA HUD layout is
-- covered by mobile_controls_v1_validation; keep this freeze on gameplay files.
-- Exclude only the separately validated seating
-- authority repair; speed/combat/geometry/HUD still compare byte-for-byte.
local seatingAuthorityRepair = [[
						-- SeatWeld joins the automatic character assembly after kart creation.
						-- Reassert server authority once it settles; otherwise automatic
						-- ownership can alternate with this server's velocity writes.
						task.defer(function()
							if self.owner == player and kart.Parent and chassis.Parent
								and seat.Occupant == humanoid and humanoid.SeatPart == seat then
								chassis:SetNetworkOwner(nil)
							end
						end)
]]
local function normalizeGameplay(source, path)
 source=source:gsub('\r\n','\n')
 -- Owner-authorized reverse cap50 ->70 is separately exercised by reverse tests.
 if path=='src/shared/KartConfig.luau' then source=source:gsub('MAX_REVERSE_SPEED = 50,','MAX_REVERSE_SPEED = 70,')end
 if path=='src/server/PrototypeWorld.luau' then
  local first,last=source:find(seatingAuthorityRepair,1,true)
  if first then
   check(not source:find(seatingAuthorityRepair,last+1,true),'single seating authority repair')
   source=source:sub(1,first-1)..source:sub(last+1)
  end
 end
 return source
end
local process=require("@lune/process")
-- PrototypeWorld now has the separately authorized held GAS input. Its actual
-- speed/boost/authority behavior is exercised by gas_pedal_validation instead.
for _,path in {"src/shared/KDMGameplayBalance.luau","src/shared/KartConfig.luau","src/server/RaceBotController.luau"} do
 local old=process.exec("git",{"show","HEAD:"..path})
 check(old.ok and normalizeGameplay(old.stdout,path)==normalizeGameplay(fs.readFile(path),path),"frozen gameplay/geometry/HUD "..path)
end
check(c.Slick.SpinDegrees==360 and c.Slick.SpinEnabled,"authorized spin presentation")
print("PASS: "..n.." VFX config, finite camera motion, clamps, cleanup and gameplay parity checks")
