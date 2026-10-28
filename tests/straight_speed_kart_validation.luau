-- Extend the existing production KartContext/service fixture; no substitute speed policy.
local fs,luau=require("@lune/fs"),require("@lune/luau")
local configLoader=require("./helpers/gameplay_config")
local fixture=fs.readFile("tests/race_item_validation.luau")
fixture=fixture:sub(1,assert(fixture:find('-- Two real production contexts',1,true))-1)
luau.load(fixture..[====[
do
local before=count
local g=modules.TrackGeometry
local samples=g.getCourse(g.getDefinition("PracticeCircuitV1")).Samples
local r=modules.KDMStraightSpeedResolver
local course=r.get("PracticeCircuitV1",g,config)
local straightIndex,cornerIndex
for i,p in samples do
 local yes=r.evaluate(course,p+(samples[i%#samples+1]-p)*.1,false)
 if yes then straightIndex=straightIndex or i else cornerIndex=cornerIndex or i end
end
local function place(i)
 local a,b=samples[i],samples[i%#samples+1]
 chassis.CFrame=CF.new(a+(b-a)*.1)
end
local ctx=world.getKartContext(player)
local function drive(dt,throttle)
 step(throttle or 1,dt)
 return ctx.commandedSpeed
end
local function resetAt(i)
 fresh();ctx.control=nil;ctx.straightLastEvaluation=nil
 services.Workspace.Prototype.TestTrack:SetAttribute("GeometryId","PracticeCircuitV1")
 place(i);ctx.commandedSpeed=0
end
resetAt(straightIndex)
for _=1,120 do drive(1/60) end
check(ctx.normalForwardCap==80 and math.abs(ctx.commandedSpeed-72)<.001,"normal acceleration unchanged 36")
for _=1,30 do drive(1/60) end
check(math.abs(ctx.commandedSpeed-80)<.001,"actual production integration reaches 80")
place(cornerIndex);ctx.straightLastEvaluation=nil
local elapsed=0
repeat local old=ctx.commandedSpeed;drive(1/60);elapsed+=1/60
 check(old-ctx.commandedSpeed<=20/60+.001,"exit no snap") until ctx.commandedSpeed<=70+.001
check(elapsed>=.4 and elapsed<=.65 and ctx.normalForwardCap==70,"80 to 70 smooth .5s")
print("Straight exit seconds",elapsed)
resetAt(cornerIndex);for _=1,160 do drive(1/60) end
check(ctx.commandedSpeed==70,"corner 70")
for _,index in {straightIndex,cornerIndex} do
 resetAt(index);drive(1/60);local accepted,reason=world.activateNitro(player);check(accepted,"Nitro activation "..tostring(reason))
 for _=1,110 do drive(1/60) end
 check(ctx.commandedSpeed==120,"Nitro 120 both contexts")
 resetAt(index);successfulDrift();for _=1,60 do drive(1/60) end
 check(ctx.commandedSpeed==100,"Mini Boost 100 both contexts")
 resetAt(index);ctx.commandedSpeed=64
 -- Controlled qualified drift input uses the existing fixture's native branch.
 for _=1,120 do driftFrame(true,0,1/60,true,1,.6) end
 check(ctx.driftActive and ctx.commandedSpeed<=64+.001,"Drift64 both contexts")
end
for _,effect in {"Missile","Thunder","OffTrack"} do
 resetAt(straightIndex);for _=1,160 do drive(1/60) end
 if effect=="Missile" then assert(world.applyMissileHit(player))
 elseif effect=="Thunder" then assert(world.applyThunderHit(player))
 else kart:SetAttribute("KartOffTrack",true) end
 drive(.01)
 local cap=if effect=="Missile" then 55 elseif effect=="Thunder" then 60 else config.OFF_TRACK_MAX_SPEED
 check(ctx.commandedSpeed<=cap and chassis.AssemblyLinearVelocity.Magnitude<=cap+.001,effect.." safety cap")
end
resetAt(straightIndex);for _=1,480 do local previous=ctx.commandedSpeed;drive(1/60,-1);check(math.abs(ctx.commandedSpeed-previous)<=70/60+.001,"reverse is gradual, never jumps to cap")end
check(ctx.commandedSpeed==-70,"gradual reverse70")
kart:SetAttribute("RaceControlsLocked",true);drive(.1)
check(ctx.commandedSpeed==0,"lock0")
check(config.MAX_FORWARD_SPEED==70 and config.ACCELERATION==36,"base frozen")
resetAt(straightIndex);successfulDrift();for _=1,60 do drive(1/60) end
check(ctx.boostActive and ctx.commandedSpeed==100,"Boost before boundary expiry")
-- Move the fixture to a corner on the exact Mini Boost natural expiry step.
ctx.boostEndTime=now;place(cornerIndex);ctx.straightLastEvaluation=nil
local priorSpeed=ctx.commandedSpeed;drive(1/60)
check(not ctx.boostActive and math.abs(priorSpeed-ctx.commandedSpeed-10/60)<.001,"Mini Boost expiry + straight exit retains deceleration10")
resetAt(straightIndex);drive(1/60);assert(world.activateNitro(player));for _=1,110 do drive(1/60) end
ctx.nitro.endTime=now;place(cornerIndex);ctx.straightLastEvaluation=nil
priorSpeed=ctx.commandedSpeed;drive(1/60)
check(ctx.nitro.exiting and math.abs(priorSpeed-ctx.commandedSpeed-15/60)<.001,"Nitro expiry + straight exit retains deceleration15")
local botState=object("Folder","StraightBot");botState:SetAttribute("IsBot",true)
local driver=object("Model","StraightBotDriver")
local botHuman=child(driver,"Humanoid","Humanoid");botHuman.Health=100
services.Workspace:SetAttribute("KDMServerRole","RACE")
local bot=world.createBotKartContext(botState,driver,CF.identity,"PRODUCTION_ROOM","K1A-fixture-room")
botState:SetAttribute("RaceState","RACING");bot.kart:SetAttribute("RaceControlsLocked",false)
bot.seat.Occupant=botHuman;botHuman.SeatPart=bot.seat
bot.chassis.CFrame=CF.new(samples[straightIndex]+(samples[straightIndex%#samples+1]-samples[straightIndex])*.1)
for _=1,160 do now+=1/60;assert(bot:setServerControl(0));bot:step(1/60) end
check(bot.normalForwardCap==80 and bot.commandedSpeed==80 and not bot.driftActive and not bot.boostActive,"production Bot same straight80")
bot.chassis.CFrame=CF.new(samples[cornerIndex]+(samples[cornerIndex%#samples+1]-samples[cornerIndex])*.1)
bot.straightLastEvaluation=nil
for _=1,31 do now+=1/60;assert(bot:setServerControl(0));bot:step(1/60) end
check(bot.normalForwardCap==70 and bot.commandedSpeed==70,"production Bot same corner70/exit")
world.releaseBotKartContext(botState)
print("PASS: "..(count-before).." additional straight production speed matrix checks")
end
]====],{environment={require=function(path)
 if path=="./helpers/gameplay_config" then return configLoader end
 return require(path)
end}})()
