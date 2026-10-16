-- Exercise actual Directory, Coordinator and BotController with the existing transport/physics fixture.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local fixture=fs.readFile('tests/production_bot_validation.luau')
local prefix=fixture:sub(1,assert(fixture:find('room("production",1)\r\nlocal coordinator=',1,true) or fixture:find('room("production",1)\nlocal coordinator=',1,true))-1)
prefix=prefix:gsub('local selectedTrack=require%("@lune/process"%).args%[1%] or "Track01Race"',"local selectedTrack='Track01'",1)
prefix=prefix:gsub('local environment={Vector3=', 'local background={}\nlocal environment={Vector3=',1)
prefix=prefix:gsub('task={spawn=function%(%) end,defer=', 'task={spawn=function(fn)table.insert(background,fn)end,wait=function()coroutine.yield()end,defer=',1)
local scenario=[=[
room("production",1)
local eventRecord=directory:get('production');eventRecord.practiceOnly=true;eventRecord.firstRaceOnly=true;eventRecord.quickMatch=true
check(not directory:startRound('production',1,1),'directory refuses solo event countdown')
local coordinator=Coordinator.start({roomId='production',matchId='production-match',trackId=selectedTrack,participantUserIds={1}})
check(coordinator.isFirstRace() and coordinator.isPractice(),'private event flags preserved')
check(not Bot.hasProductionBot('Bot01'),'Bot not created before heartbeat')
local heartbeat=coroutine.create(background[#background])
check(coroutine.resume(heartbeat),'heartbeat waits normally')
check(coroutine.resume(heartbeat),'heartbeat performs automatic Bot admission')
check(Bot.hasProductionBot('Bot01') and session:count()==2,'event automatically admits one real production Bot')
check(session:humanCount()==1 and #directory:get('production').stagedBots==1,'one human plus one Bot authoritative roster')
check(coroutine.resume(heartbeat),'second heartbeat runs')
check(session:count()==2 and #directory:get('production').stagedBots==1,'automatic Bot is not duplicated')
local bot=Bot.getProductionBot('Bot01')
check(bot.state:GetAttribute('RaceItemsReady')==true,'Bot is automatically item ready')
check(directory:startRound('production',1,2)~=nil,'admitted event Bot permits two-racer countdown')
check(not directory:stage('production',{userId=77},'outside','Track01'),'event still excludes other humans')
coordinator.stop()
room('production',1)
local ordinary=directory:get('production');ordinary.practiceOnly=true
check(not directory:addBot('production',descriptor),'ordinary private solo practice remains solo')
print('PASS '..checks..' event automatic production Bot checks')
]=]
local deps={['@lune/fs']=fs,['@lune/luau']=luau,['@lune/roblox']=require('@lune/roblox'),
 ['./helpers/lobby_title_modules']=require('./helpers/lobby_title_modules'),['./helpers/gameplay_config']=require('./helpers/gameplay_config')}
luau.load(prefix..scenario,{environment={require=function(id)return assert(deps[id],id)end}})()
