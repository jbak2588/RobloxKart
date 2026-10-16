local fs,luau=require('@lune/fs'),require('@lune/luau')
local fixture=fs.readFile('tests/persistent_room_race_validation.luau')
local prefix=fixture:sub(1,assert(fixture:find('local readyRoster',1,true))-1)
prefix=prefix:gsub('require%("%./helpers/gameplay_config"%)','CONFIG_LOADER')
local observer=[[
local observed={begin=0,start=0,progress=0,lap=0,finish=0}
child(server,'ModuleScript','RaceRecordService')
modules.RaceRecordService={}
for _,method in {'begin','start','invalidate','progress','lap','checkpoints','boost','finish'}do
 modules.RaceRecordService[method]=function(...)observed[method]=(observed[method]or 0)+1 end
end
modules.PrototypeWorld.onDriftOutcome=function()end
]]
prefix=prefix:gsub('local race=load',observer..'local race=load',1)
assert(fs.readFile('src/server/init.server.luau'):find('isFirstRace=if roomCoordinator then roomCoordinator.isFirstRace else nil',1,true),'server bootstrap must forward first-race observer gate')
local scenario=[=[
services.Workspace:SetAttribute('KDMServerRole','RACE')
track:SetAttribute('TrackId','Track01');track:SetAttribute('GeometryId',catalog.Entries.Track01.GeometryId)
a:SetAttribute('SelectedTrackId','Track01')
race.start({trackId='Track01',persistentRoom=true,isQuickMatch=function()return true end,
 isPractice=function()return true end,isFirstRace=function()return true end,
 onRoundStart=function()return true end,onRoundReady=function()return true end})
local session=sessionType.active()
local function tick(dt)now+=dt;services.RunService.Heartbeat:Fire(dt)end
a:SetAttribute('RaceState','PRE_RACE');tick(.1)
tick(raceConfig.ITEM_PREP_SECONDS+1);tick(raceConfig.COUNTDOWN_SECONDS+.1)
check(a:GetAttribute('RaceState')=='RACING' and observed.begin==1,'first Practice auto starts and records')
local function cross(gate)
 ca.chassis.CFrame=CF.new(100,0,100);tick(.1)
 ca.chassis.CFrame=gate.CFrame;ca.chassis.AssemblyLinearVelocity=V.new(0,0,-70);tick(8)
end
for lap=1,3 do for _,gate in {checkpoints[1],checkpoints[2],finish}do cross(gate)end end
check(a:GetAttribute('RaceState')=='FINISHING' and observed.finish==0,'no first bonus before presentation')
tick(raceConfig.FINISH_SEQUENCE_SECONDS+.1)
check(a:GetAttribute('RaceState')=='FINISHED' and observed.finish==1 and observed.lap==3,'first full three-lap finish observed once')
tick(.1);check(observed.finish==1,'repeat heartbeat cannot duplicate finish')
tick(20);check(a:GetAttribute('RaceState')=='FINISHED','first results remain until player chooses next action')
print('PASS '..count..' first Practice controller checks')
]=]
luau.load(prefix..scenario,{environment={CONFIG_LOADER=require('./helpers/gameplay_config')}})()
