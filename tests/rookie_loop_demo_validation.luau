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
 if boost then boosts+=1;check(math.abs(z-L.StartStraightZ)<.001 and math.abs(drift)<.01 and x>=route.StartX-4 and x<=route.StartX+141,'boost begins at the starting line on the clear straight')end
 local ax,az,adx,adz=route.sample(t+1/120,2)
 check(math.sqrt((ax-x)^2+(az-z)^2)<=route.Speed/120+.001,'no position jump at joins or lap seam')
 check(dx*adx+dz*adz>.999,'smooth tangent at joins')
end
check(turns>100 and boosts>100,'both drift and boost demonstrations present')
for _,path in {'src/shared/LobbyDemoRoute.luau','src/server/RaceBotController.luau','src/shared/KartConfig.luau'}do
 check(fs.readFile(path):gsub('\r\n','\n')==process.exec('git',{'show','eceaec9:'..path}).stdout:gsub('\r\n','\n'),'legacy demo/audience/physics/RACE untouched '..path)
end
-- Run the real practice orchestrator using its existing native-instance boundary.
local prefix=fs.readFile('tests/lobby_practice_combat_validation.luau')
prefix=prefix:sub(1,assert(prefix:find('local c,p,q,r,s=fresh()',1,true))-1)
prefix=prefix:gsub("require%('%./helpers/gameplay_config'%)",'CONFIG_LOADER'):gsub("require%('%./helpers/lobby_drift_session'%)",'DRIFT')
prefix=prefix:gsub("local Combat=module", "module('HubParkRookieLoopLayout','src/shared/HubParkRookieLoopLayout.luau')\nmodule('RookieLoopDemoRoute','src/shared/RookieLoopDemoRoute.luau')\nlocal Combat=module")
prefix=prefix:gsub("zone:SetAttribute%('Center',rb.Vector3.new%(120,0,766%)%)", "zone:SetAttribute('Center',rb.Vector3.zero);zone:SetAttribute('DriveGeometry','ROOKIE_LOOP_V1')")
local scenario=[[
local c,p,q=fresh();local bot=c.bot.record.kart
check(c.route==modules.RookieLoopDemoRoute and c.normalBotSpeed==70,'PARK bots use race-normal 70')
tick(6);check(math.abs(c.bot.speed-70)<.001,'bot returns to 70 after boosted launch with humans')
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
check(math.abs(c.bot.speed-70)<.001,'audience-only Park also runs at 70')
check(bot.Parent==scene.zone,'human departure retains one bot')
scene.zone.LobbyDemoState:Destroy();tick(.1)
check(c.botElapsed==nil and c.bot.speed==nil,'state removal clears motion/effects')
c:destroy();check(bot.Parent==nil,'zone teardown removes proxy')
local c,p,q=fresh();c:remove(p);c:remove(q)
check(#c.bots==7,'seven shared Park bot proxies')
local colors={}
for i,b in c.bots do
 local id=b.record.kart:GetAttribute('KartId');check(not colors[id],'all seven kart colors unique');colors[id]=true
 check(b.botDelay==(i-1)*30,'one new bot per 30 seconds')
end
tick(.01)
check(c.bots[1].speed<1 and c.bots[1].record.kart:GetAttribute('KartBoosting'),'first bot ramps from rest with visible boost state')
local startX=c.bots[1].record.body.Position.X
check(math.abs(startX-modules.RookieLoopDemoRoute.StartX)<4,'natural spawn just ahead of personal grid')
for i=2,7 do
 tick((i-1)*30-now+.01)
 local active=0;for _,b in c.bots do if b.active then active+=1 end end
 check(active==i,'only scheduled bots activate through 180 seconds')
 check(c.bots[i].speed<2 and c.bots[i].record.kart:GetAttribute('KartBoosting'),'each new color starts from rest in Mini Boost')
end
tick(7)
for _,b in c.bots do check(b.speed>=70 and b.speed<=100,'idle audience traffic retains 70 base and bounded boosts')end
scene.zone.LobbyDemoState:Destroy();tick(.01)
for _,b in c.bots do check(not b.active and b.botElapsed==nil and b.launchUntil==nil and not b.record.kart:GetAttribute('KartBoosting'),'last audience exit clears every launch')end
c:destroy()
return n
]]
local integration=luau.load(prefix..scenario,{environment={CONFIG_LOADER=require('./helpers/gameplay_config'),DRIFT=require('./helpers/lobby_drift_session')}})()
print('PASS '..n..' RookieLoop demo geometry/clock/immutability checks + '..integration..' production practice integration checks')
