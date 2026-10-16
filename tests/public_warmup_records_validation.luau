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
local scenario=[=[
services.Workspace:SetAttribute('KDMServerRole','RACE')
race.start({trackId='Track01Race',persistentRoom=true,isQuickMatch=function()return true end,
 onRoundStart=function()return true end,onRoundReady=function()return true end})
local session=sessionType.active()
local function tick(dt)now+=dt;services.RunService.Heartbeat:Fire(dt)end
a:SetAttribute('RaceState','PRE_RACE');tick(.1)
local bot=addPlayer('Bot',-10,4);bot:SetAttribute('IsBot',true);bot:SetAttribute('BotId','Bot01')
bot.Parent=object('Folder','Bots')
check(session:addServerBot(bot,contexts[bot],'PRODUCTION_ROOM'),'warm-up bot staged')
tick(raceConfig.ITEM_PREP_SECONDS+1);tick(raceConfig.COUNTDOWN_SECONDS+.1)
check(a:GetAttribute('RacePublicWarmup')and observed.begin==1 and observed.start>=1,'warm-up starts official observation')
local function cross(gate)
 ca.chassis.CFrame=CF.new(100,0,100);tick(.1)
 ca.chassis.CFrame=gate.CFrame;ca.chassis.AssemblyLinearVelocity=V.new(0,0,-70);tick(8)
end
for lap=1,2 do for _,gate in {checkpoints[1],checkpoints[2],finish}do cross(gate)end end
check(a:GetAttribute('RaceState')=='FINISHING'and observed.finish==0,'no reward before final presentation completes')
tick(raceConfig.FINISH_SEQUENCE_SECONDS+.1)
check(a:GetAttribute('RaceState')=='FINISHED'and observed.finish==1,'full warm-up reaches existing finish/reward observer')
check(observed.progress>0 and observed.lap==2,'full target-lap observation retained')
tick(.1);check(observed.finish==1,'finish observer not repeated')
contexts[bot].chassis.CFrame=CF.new(1500,0,1500);tick(raceConfig.OFF_TRACK_TIMEOUT_SECONDS+1)
check(session.phase=='COMPLETE','completed human and bot terminal round settles')
tick(1.1);check(session.phase=='COMPLETE','completed warm-up retains result/reward window')
tick(7.1);check(session.phase=='WAITING','completed warm-up returns after normal results window')
print('PASS '..count..' public warm-up completed-race observer checks')
]=]
luau.load(prefix..scenario,{environment={CONFIG_LOADER=require('./helpers/gameplay_config')}})()
