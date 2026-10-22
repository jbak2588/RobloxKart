local fs,luau,rb,process=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/process')
local L=luau.load(fs.readFile('src/shared/HubParkRookieLoopLayout.luau'))()
local env={script={Parent={HubParkRookieLoopLayout='layout'}},require=function()return L end}
local route=luau.load(fs.readFile('src/shared/RookieLoopDemoRoute.luau'),{environment=env})()
local geometry=luau.load(fs.readFile('src/shared/RookieLoopDriveGeometry.luau'),{environment=env})().create()
local n=0;local function check(v,m)assert(v,m);n+=1 end
local turns,boosts=0,0
for i=0,math.ceil(route.CycleSeconds*120)do
 local t=i/120
 local x,z,dx,dz,drift,_,pattern,boost=route.sample(t,2)
 check(geometry.inside(x,z,12),'demo route stays well inside approved road')
 local yaw=math.atan2(dz,dx)-math.rad(32)*drift
 for _,front in {-6,6}do for _,side in {-4.2,4.2}do
  check(geometry.inside(x+math.cos(yaw)*front-math.sin(yaw)*side,z+math.sin(yaw)*front+math.cos(yaw)*side,1.35),'enlarged drifting kart footprint stays on road')
 end end
 local bx,bz,bdx,bdz=route.sample(t+route.CycleSeconds,2)
 check(math.abs(x-bx)+math.abs(z-bz)<1e-8 and dx*bdx+dz*bdz>.999999,'shared clock and repeatable lap')
 if math.abs(drift)>.01 then turns+=1 end
 if boost then boosts+=1;check(math.abs(z-L.StartStraightZ)<.001 and math.abs(drift)<.01 and x>=220 and x<=292.1,'boost only on clear straight beyond pit exit')end
 local ax,az,adx,adz=route.sample(t+1/120,2)
 check(math.sqrt((ax-x)^2+(az-z)^2)<=route.Speed/120+.001,'no position jump at joins or lap seam')
 check(dx*adx+dz*adz>.999,'smooth tangent at joins')
end
check(turns>100 and boosts>100,'both drift and boost demonstrations present')
for _,path in {'src/shared/LobbyDemoRoute.luau','src/server/LobbyDemoService.luau','src/server/LobbyTestDriveService.luau','src/server/RaceBotController.luau','src/shared/KartConfig.luau'}do
 check(fs.readFile(path):gsub('\r\n','\n')==process.exec('git',{'show','f25f853:'..path}).stdout:gsub('\r\n','\n'),'legacy demo/audience/physics/RACE untouched '..path)
end
-- Run the real practice orchestrator using its existing native-instance boundary.
local prefix=fs.readFile('tests/lobby_practice_combat_validation.luau')
prefix=prefix:sub(1,assert(prefix:find('local c,p,q,r,s=fresh()',1,true))-1)
prefix=prefix:gsub("require%('%./helpers/gameplay_config'%)",'CONFIG_LOADER'):gsub("require%('%./helpers/lobby_drift_session'%)",'DRIFT')
prefix=prefix:gsub("local Combat=module", "module('HubParkRookieLoopLayout','src/shared/HubParkRookieLoopLayout.luau')\nmodule('RookieLoopDemoRoute','src/shared/RookieLoopDemoRoute.luau')\nlocal Combat=module")
prefix=prefix:gsub("zone:SetAttribute%('Center',rb.Vector3.new%(120,0,766%)%)", "zone:SetAttribute('Center',rb.Vector3.zero);zone:SetAttribute('DriveGeometry','ROOKIE_LOOP_V1')")
local scenario=[[
local c,p,q=fresh();local bot=c.bot.record.kart
check(c.route==modules.RookieLoopDemoRoute and c.normalBotSpeed==80,'PARK route and human pace selected')
tick(2);check(math.abs(c.bot.speed-80)<.001,'bot reaches 80 with humans')
for _,id in {'Thunder','Missile','Slick','Smoke'}do
 c:clearTransient(c.bot)
 local accepted,reason=c:resolve(c.bot,c.actors[p],id,now)
 check(accepted and reason=='hit','existing item resolves on PARK bot: '..id)
 if id~='Smoke'then tick(.01);check(c.bot.effect.kind==id,'physical effect state preserved: '..id)end
end
c:clearTransient(c.bot);c.bot.shieldEnd=now+5
local accepted,reason=c:resolve(c.bot,c.actors[p],'Missile',now)
check(accepted and reason=='blocked'and c.bot.shieldEnd==nil,'one-hit Shield contract preserved')
c:clearTransient(c.bot)
for i=1,80 do
 tick(.1)
 local x,z=c.route.sample(c.botElapsed,modules.KartConfig.MINI_BOOST_DURATION)
 check((c.bot.record.body.CFrame.Position-rb.Vector3.new(x,1.75,z)).Magnitude<.001,'server target proxy uses same route')
end
c:remove(p);c:remove(q);tick(10)
check(math.abs(c.bot.speed-36)<.001,'audience-only demo returns to accepted 36')
check(bot.Parent==scene.zone,'human departure retains one bot')
scene.zone.LobbyDemoState:Destroy();tick(.1)
check(c.botElapsed==nil and c.bot.speed==nil,'state removal clears motion/effects')
c:destroy();check(bot.Parent==nil,'zone teardown removes proxy')
return n
]]
local integration=luau.load(prefix..scenario,{environment={CONFIG_LOADER=require('./helpers/gameplay_config'),DRIFT=require('./helpers/lobby_drift_session')}})()
print('PASS '..n..' RookieLoop demo geometry/clock/immutability checks + '..integration..' production practice integration checks')
