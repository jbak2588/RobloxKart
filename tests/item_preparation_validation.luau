-- Production RaceController with deterministic admission/transport fixture.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local fixture=fs.readFile('tests/persistent_room_race_validation.luau')
local prefix=fixture:sub(1,assert(fixture:find('local readyRoster',1,true))-1)
local scenario=[=[
local quick=QUICK;local hostGate=false;local directoryReady=true;local starts=0
race.start({trackId='Track01Race',persistentRoom=true,isQuickMatch=function()return quick end,
 requiresHostStart=function()return hostGate end,
 onRoundStart=function()if not directoryReady then return false end;starts+=1;return true end})
local session=sessionType.active();local remote=services.ReplicatedStorage.RaceControl.OnServerEvent
local function tick(dt)now+=dt;services.RunService.Heartbeat:Fire(dt)end
a:SetAttribute('RaceState','PRE_RACE');tick(.1)
check(session.phase=='WAITING' and a:GetAttribute('RaceItemsPrepareRemaining')==0,'no item-prep deadline')
check(not session.confirmItems(a,now),'retired confirmation cannot gate start')
if quick then
 tick(raceConfig.QUICK_RACE_ARRIVAL_WAIT_SECONDS-1)
 check(session.phase=='WAITING','quick match protects initial teleport arrival window')
 directoryReady=false;tick(2)
 check(session.phase=='WAITING'and starts==0,'pending cross-server reservation blocks start')
 directoryReady=true;hostGate=true;tick(2)
 check(session.phase=='WAITING','explicit host invite preserves host decision')
 hostGate=false;tick(1.1)
 check(session.phase=='COUNTDOWN'and starts==1,'one human auto-starts without item prep or another human')
else
 remote:Fire(b,'StartRace')
 check(session.phase=='WAITING','nonmember cannot start')
 remote:Fire(a,'StartSolo')
 check(session.phase=='COUNTDOWN'and starts==1,'host immediately starts without item selection')
end
remote:Fire(a,'StartRace');tick(.1)
check(starts==1,'countdown starts once')
tick(raceConfig.COUNTDOWN_SECONDS+.1)
check(session.phase=='RACING','immediate countdown reaches race')
print('PASS '..count..' no-prep '..tostring(quick)..' start checks')
]=]
local loader=require('./helpers/gameplay_config')
for _,quick in {false,true}do
 luau.load(prefix..scenario,{environment={QUICK=quick,require=function(path)
  if path=='./helpers/gameplay_config'then return loader end;return require(path)
 end}})()
end
