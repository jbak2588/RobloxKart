local fs,luau=require('@lune/fs'),require('@lune/luau')
local prefix=fs.readFile('tests/lobby_practice_combat_validation.luau')
prefix=prefix:sub(1,assert(prefix:find('local c,p,q,r,s=fresh()',1,true))-1)
prefix=prefix:gsub("require%('%./helpers/gameplay_config'%)",'CONFIG_LOADER'):gsub("require%('%./helpers/lobby_drift_session'%)",'DRIFT')
local scenario=[[
module('HubParkRookieLoopLayout','src/shared/HubParkRookieLoopLayout.luau')
module('RaceRouteProgress','src/shared/RaceRouteProgress.luau');module('RaceConfig','src/shared/RaceConfig.luau')
module('RookieParkTrial','src/shared/RookieParkTrial.luau');module('ParkOvertakePolicy','src/shared/ParkOvertakePolicy.luau')
local P=module('ParkMultiplayerPolicy','src/shared/ParkMultiplayerPolicy.luau')
local c,p,q,r,s=fresh();local folder=rb.Instance.new('Folder');folder.Parent=c.folder
local room={id='test-room',folder=folder,phase='COUNTDOWN',goAt=1003}
r.parkRaceRoom=room;r.trial={phase='RUNNING'};s.trial={phase='RUNNING'}
local b=c:addParkRaceBot(room,1,1,83)
check(b.record.body.Parent==nil and b.record.kart.Parent==folder,'inert private bot pose, replicated sampled metadata only')
check(not c:valid(b),'no target before GO')
local before=b.distance;now=2;c:updateParkRaceBot(b,1002,now)
check(b.distance==before and b.speed==0,'grid bot remains stationary through countdown')
room.phase='RUNNING';now=4;c:updateParkRaceBot(b,1004,now)
check(math.abs(b.distance-before-83)<1e-6,'server integrates from common GO time')
local source=c.actors[p];local outsider=c.actors[q]
check(c:resolve(b,outsider,'Missile',now)==false,'time-attack driver cannot damage race bot')
check(c:resolve(outsider,source,'Thunder',now)==false,'race player cannot damage outside driver')
local ok,why=c:resolve(b,source,'Missile',now)
check(ok and why=='hit','participant items affect shared race opponents')
local hitUntil=b.effect.untilTime;local distance=b.distance
now=hitUntil+1;c:updateParkRaceBot(b,1000+now,now)
local expected=cfg.MISSILE_SPEED_CAP*(hitUntil-4)+83
check(math.abs(b.distance-distance-expected)<1e-5,'hit expiry integrates affected and normal time separately')
check(b.speed==83,'normal pace resumes after damage')
b.effect=nil;before=b.distance;now+=.5
check(c:resolve(b,source,'Smoke',now),'smoke applies inside room')
c:updateParkRaceBot(b,1000+now,now)
check(math.abs(b.distance-before-83*.5)<1e-5,'Smoke stays vision-only')
local otherRoom={id='other',folder=folder,phase='RUNNING',goAt=1003}
s.parkRaceRoom=otherRoom
check(c:resolve(outsider,source,'Missile',now)==false,'different Park race rooms cannot attack one another')
local final=P.finishProgress();b.effect=nil;b.distance=final-41.5;b.sampleTime=1000+now
now+=1;c:updateParkRaceBot(b,1000+now,now)
check(b.distance==final and b.finishedAt==1000+now-.5 and b.speed==0,'bot stops exactly at three-lap finish with subframe time')
check(not c:valid(b),'finished bot no longer combat eligible')
c:removeParkRaceBot(b);check(b.record.body.Parent==nil and b.record.kart.Parent==nil and not c.raceBots[b],'explicit private pose and metadata cleanup')
c:destroy();scene.root:Destroy()
print('PASS '..n..' production Park multiplayer bot motion, damage, isolation and cleanup checks')
]]
luau.load(prefix..scenario,{environment={CONFIG_LOADER=require('./helpers/gameplay_config'),DRIFT=require('./helpers/lobby_drift_session')}})()
