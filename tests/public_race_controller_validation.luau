local fs,luau=require('@lune/fs'),require('@lune/luau')
local fixture=fs.readFile('tests/persistent_room_race_validation.luau')
local prefix=fixture:sub(1,assert(fixture:find('local readyRoster',1,true))-1)
local configLoader=require('./helpers/gameplay_config')
prefix=prefix:gsub('require%("%./helpers/gameplay_config"%)','CONFIG_LOADER')
local scenario=[=[
local starts,nextRounds,session,bot=0,0,nil,nil
local practiceMode=false
local rejectNext=false
environment.warn=function()end
services.Workspace:SetAttribute('KDMServerRole','RACE')
race.start({trackId='Track01Race',persistentRoom=true,isQuickMatch=function()return true end,
 isPractice=function()return practiceMode end,
 onRoundStart=function()starts+=1;return true end,
 onRoundReady=function()nextRounds+=1;return not rejectNext end,
 onWarmupArrival=function(player,token)
  if token~='verified-arrival'or player~=b then return false end
  session:removeServerBot(bot);return true
 end})
session=sessionType.active()
local function tick(dt)now+=dt;services.RunService.Heartbeat:Fire(dt)end
local function ready(p)p:SetAttribute('RaceState','PRE_RACE');tick(.1)end
ready(a);ready(b)
check(session.phase=='WAITING'and starts==0,'two public humans still receive item prep')
tick(raceConfig.ITEM_PREP_SECONDS)
check(session.phase=='COUNTDOWN'and starts==1,'two humans auto-start with no host button')
check(a:GetAttribute('RacePublicWarmup')==false,'two-human race is competitive, not warm-up')
tick(raceConfig.COUNTDOWN_SECONDS+.1)
check(not race.prepareQuickArrival(c,'verified-arrival')and session.phase=='RACING','running human race cannot be interrupted')
ca.chassis.CFrame=CF.new(1500,0,1500);cb.chassis.CFrame=CF.new(1600,0,1600)
tick(raceConfig.OFF_TRACK_TIMEOUT_SECONDS+.1)
check(session.phase=='COMPLETE','human round completes normally')
tick(8.1)
check(session.phase=='WAITING'and nextRounds==1,'public room returns to staging without unanimous rematch votes')
b:SetAttribute('RaceState','GARAGE');tick(.1)
bot=addPlayer('Bot',-10,4);bot:SetAttribute('IsBot',true);bot:SetAttribute('BotId','Bot01')
bot.Parent=object('Folder','Bots')
check(session:addServerBot(bot,contexts[bot],'PRODUCTION_ROOM'),'existing server bot enters one-human public staging')
tick(raceConfig.ITEM_PREP_SECONDS+1)
check(session.phase=='COUNTDOWN'and a:GetAttribute('RacePublicWarmup')==true,'one-human bot round becomes explicitly labeled warm-up')
tick(raceConfig.COUNTDOWN_SECONDS+.1)
check(session.phase=='RACING','bot warm-up runs normally')
check(not race.prepareQuickArrival(b,'forged')and session.phase=='RACING','failed arrival authorization leaves host driving')
check(race.prepareQuickArrival(b,'verified-arrival'),'verified arriving human can transition bot warm-up')
check(session.phase=='WAITING'and not race.isRosterLocked()and session:count()==1,'bot removed and human admission unlocked')
check(a:GetAttribute('RaceState')=='PRE_RACE'and a:GetAttribute('RaceDNFReason')~='FORFEIT','host returns to grid without forfeit')
ready(b)
tick(raceConfig.ITEM_PREP_SECONDS+1)
check(session.phase=='COUNTDOWN'and session:humanCount()==2 and not a:GetAttribute('RacePublicWarmup'),'arriving pair starts together with fresh item prep')
tick(raceConfig.COUNTDOWN_SECONDS+.1)
ca.chassis.CFrame=CF.new(1500,0,1500);cb.chassis.CFrame=CF.new(1600,0,1600)
tick(raceConfig.OFF_TRACK_TIMEOUT_SECONDS+.1);tick(8.1)
practiceMode=true;b:SetAttribute('RaceState','GARAGE');tick(.1)
tick(raceConfig.ITEM_PREP_SECONDS+1)
check(session.phase=='COUNTDOWN'and session:count()==1,'private practice auto-starts one human without a bot')
check(a:GetAttribute('RacePrivatePractice')and not a:GetAttribute('RacePublicWarmup'),'practice is explicitly private rather than recruitment warm-up')
tick(raceConfig.COUNTDOWN_SECONDS+.1);ca.chassis.CFrame=CF.new(1500,0,1500)
tick(raceConfig.OFF_TRACK_TIMEOUT_SECONDS+.1)
rejectNext=true;tick(8.1);local before=nextRounds
tick(.1);tick(.1)
check(nextRounds==before,'failed next-round storage is not retried every heartbeat')
tick(5.1);check(nextRounds==before+1,'failed next-round transition retries after bounded backoff')
print('PASS '..count..' production public controller auto-start, warm-up handoff and rematch checks')
]=]
luau.load(prefix..scenario,{environment={CONFIG_LOADER=configLoader}})()
