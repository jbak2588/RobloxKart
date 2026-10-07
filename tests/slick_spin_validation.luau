local fs,luau,rb=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local config=require("./helpers/gameplay_config")("src/shared/RaceItemConfig.luau")
local vfx=luau.load(fs.readFile("src/shared/KDMItemVFXConfig.luau"))()
local node={WaitForChild=function(self)return self end}
local motion=luau.load(fs.readFile("src/server/SlickMotion.luau"),{environment={game={GetService=function()return node end},require=function()return vfx end}})()
local n=0
local function check(v,l)assert(v,l);n+=1 end
check(config.SLICK_EFFECT_DURATION==.7 and config.SLICK_SPEED_RETAIN==.55 and config.SLICK_MAX_YAW_RATE==10,"frozen duration/retain/yaw cap")
for _,fps in {30,60,120,240} do
 for _,initial in {0,math.rad(10),math.rad(-10),math.pi/2,-math.pi/2,math.pi} do
  local m=motion.new(config)
  local frame=rb.CFrame.Angles(0,initial,0)
  m:start("driver",0,frame.LookVector,rb.Vector3.new(0,0,-1),70)
  local total=0
  for i=0,math.ceil(.7*fps)-1 do
   local v,yaw,done=m:sample(i/fps,frame.LookVector)
   check(math.abs(v.Magnitude-38.5)<.0001 and v.Y==0,"unchanged planar slowdown")
   check(math.abs(yaw)<=10,"existing angular limit")
   check(not done,"effect remains finite before deadline")
   frame=frame*rb.CFrame.Angles(0,yaw/fps,0);total+=yaw/fps
  end
  check(select(3,m:sample(.7,frame.LookVector)),"exact gameplay deadline")
  check(frame.LookVector:Dot(rb.Vector3.new(0,0,-1))>.94,"heading recovered "..fps.."/"..initial)
  if math.abs(initial)<=math.rad(10) then check(total>math.rad(330) and total<math.rad(390),"approximate full revolution") end
  m:stop();check(not m.active and m.driver==nil,"yaw owner released")
 end
end
-- Worst misaligned entry cannot safely add 360 and realign under .7s/10rad/s.
check((math.pi*3)/.7>config.SLICK_MAX_YAW_RATE,"legacy fallback required for reverse entry")
print("PASS: "..n.." actual Slick spin, aligned revolution, safe misaligned recovery, duration, slowdown and cleanup checks")
