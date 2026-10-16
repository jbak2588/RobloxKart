local fs,luau=require('@lune/fs'),require('@lune/luau')
local fixture=fs.readFile('tests/persistent_room_race_validation.luau')
local prefix=fixture:sub(1,assert(fixture:find('local readyRoster',1,true))-1)
prefix=prefix:gsub('require%("%./helpers/gameplay_config"%)','CONFIG_LOADER')
local scenario=[=[
local starts=0
local pending=true
services.Workspace:SetAttribute('KDMServerRole','RACE')
race.start({trackId='Track01Race',persistentRoom=true,isQuickMatch=function()return true end,
 requiresHostStart=function()return true end,getRoomHostUserId=function()return 1 end,
 onRoundStart=function()if pending then return false end;starts+=1;return true end})
local session=sessionType.active()
local function tick(dt)now+=dt;services.RunService.Heartbeat:Fire(dt)end
local function ready(p)p:SetAttribute('RaceState','PRE_RACE');tick(.1)end
ready(a);ready(b);tick(raceConfig.ITEM_PREP_SECONDS+1)
check(session.phase=='WAITING'and starts==0,'invited second human never auto-starts after item prep')
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,'StartRace')
check(session.phase=='WAITING'and starts==0,'pending invitation independently blocks host start')
pending=false;tick(2)
check(session.phase=='WAITING','accept/decline response does not auto-start')
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,'StartRace')
check(session.phase=='WAITING','guest cannot start invited room')
ready(c);ready(d);tick(raceConfig.ITEM_PREP_SECONDS+1)
check(session.phase=='WAITING'and session:count()==session.maxPlayers,'full invited room still waits for host decision')
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,'StartRace')
check(session.phase=='COUNTDOWN'and starts==1,'host starts full invited room after responses and prep')
tick(.1);check(starts==1,'shared countdown only once')
print('PASS '..count..' invited public host-start controller checks')
]=]
luau.load(prefix..scenario,{environment={CONFIG_LOADER=require('./helpers/gameplay_config')}})()
