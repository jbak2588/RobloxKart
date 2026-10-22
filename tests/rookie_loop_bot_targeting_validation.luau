-- Real practice selection -> charge -> warning -> projectile/strike -> hit.
local fs,luau,process=require('@lune/fs'),require('@lune/luau'),require('@lune/process')
local prefix=fs.readFile('tests/lobby_practice_combat_validation.luau')
prefix=prefix:sub(1,assert(prefix:find('local c,p,q,r,s=fresh()',1,true))-1)
prefix=prefix:gsub("require%('%./helpers/gameplay_config'%)",'CONFIG_LOADER'):gsub("require%('%./helpers/lobby_drift_session'%)",'DRIFT')
prefix=prefix:gsub('local Combat=module',"module('HubParkRookieLoopLayout','src/shared/HubParkRookieLoopLayout.luau')\nmodule('RookieLoopDemoRoute','src/shared/RookieLoopDemoRoute.luau')\nlocal Combat=module")
prefix=prefix:gsub("zone:SetAttribute%('Center',rb.Vector3.new%(120,0,766%)%)","zone:SetAttribute('Center',rb.Vector3.zero);zone:SetAttribute('DriveGeometry','ROOKIE_LOOP_V1')")
local scenario=[[
local function behind(c,r,distance,reverse)
 local target=c.bot.record.body.Position
 local position=target-rb.Vector3.new(distance,0,0)
 r.body.CFrame=rb.CFrame.lookAt(position,position+(if reverse then -rb.Vector3.xAxis else rb.Vector3.xAxis))
 r.body.Position=position
end
for _,id in {'Missile','Thunder'}do
 local c,p,q,r=fresh();c:remove(q);tick(.01)
 behind(c,r,480.1)
 check(not c:use(p,1,id)and p:GetAttribute('LobbyCharge'..id)==1,'out-of-range bot rejects without consumption '..id)
 tick(.3);behind(c,r,400,true)
 check(not c:use(p,1,id)and p:GetAttribute('LobbyCharge'..id)==1,'behind bot rejects without consumption '..id)
 tick(.3);behind(c,r,400)
 check(c:targets(c.actors[p])[1].actor==c.bot,'server acquires distant PARK bot '..id)
 check(not c:use(p,0,id)and not c:use(p,1,id,{})and p:GetAttribute('LobbyCharge'..id)==1,'stale generation and client-supplied target rejected '..id)
 check(c:use(p,1,id),'real use accepted at 400, beyond old 180 '..id)
 check(p:GetAttribute('LobbyCharge'..id)==0,'accepted use consumes once '..id)
 if id=='Missile'then check(#c.missiles.projectiles==1,'real homing warning queued')
 else check(#c.thunder.events==1,'real Thunder warning queued')end
 tick(7)
 check(p:GetAttribute('LobbyCombatHitItem')==id and p:GetAttribute('LobbyCombatHitSerial')==(if id=='Missile'then 2 else 1),'actual moving-bot hit result, not launch-only acknowledgement '..id)
 check(p:GetAttribute('LobbyCharge'..id)==1,'six-second practice refill preserved '..id)
 c:destroy();scene.root:Destroy();scene=nil
end
local c,p,q,r,s=fresh();tick(.01)
-- Bot extension never changes player-vs-player targeting.
local point=r.body.Position+rb.Vector3.new(0,0,-250);s.body.CFrame=rb.CFrame.new(point);s.body.Position=point
c.botElapsed=nil
check(#c:targets(c.actors[p])==0,'human at 250 excluded')
point=r.body.Position+rb.Vector3.new(0,0,-150);s.body.CFrame=rb.CFrame.new(point);s.body.Position=point
check(c:targets(c.actors[p])[1].actor==c.actors[q],'human at 150 included')
c.route=modules.LobbyDemoRoute;c.botElapsed=0
local position=r.body.Position+rb.Vector3.new(0,0,-400)
c.bot.record.body.CFrame=rb.CFrame.new(position);c.bot.record.body.Position=position
c:remove(q)
check(#c:targets(c.actors[p])==0,'legacy bot at 400 remains excluded')
c:destroy();scene.root:Destroy()
local c,p,q,r=fresh();c:remove(q);tick(.01);behind(c,r,400)
check(c:use(p,1,'Missile')and #c.missiles.projectiles==1,'bot departure warning fixture')
scene.zone.LobbyDemoState:Destroy();tick(.01)
check(#c.missiles.projectiles==0 and not c:valid(c.bot),'disappearing bot cancels pending attack')
c:destroy();scene.root:Destroy()
return n
]]
local count=luau.load(prefix..scenario,{environment={CONFIG_LOADER=require('./helpers/gameplay_config'),DRIFT=require('./helpers/lobby_drift_session')}})()
for _,path in {'src/server/HomingMissileService.luau','src/server/ThunderStrikeService.luau','src/shared/RaceItemConfig.luau'}do
 assert(fs.readFile(path):gsub('\r\n','\n')==process.exec('git',{'show','c0f776e:'..path}).stdout:gsub('\r\n','\n'),'weapon tuning/audio/renderer unchanged '..path)
end
print('PASS '..count..' real PARK bot acquisition/launch/hit/refill and PvP/legacy boundary checks')
