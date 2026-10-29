local fs,luau=require('@lune/fs'),require('@lune/luau')
local n=0;local function check(v,m)assert(v,m);n+=1 end
local source=fs.readFile('src/shared/HubLeaderboardPolicy.luau')
local policy=luau.load(source)()
check(policy.Boards.SOLO_Park.enabled and policy.Boards.SOLO_Park.ascending,'Park total finish enabled ascending')
check(policy.Boards.SOLO_Park.scope=='SOLO_Park_TOTAL_R2_L2'and policy.Boards.CASH.scope=='EARNED_R1','new total scopes cannot reuse faster one-lap scores; money scope retained')
check(policy.Boards.MULTI_Track01Race.enabled and policy.Boards.CASH.enabled,'owner-approved multi and lifetime earned policies enabled')
check(policy.Boards.SOLO_Track02==nil,'retired Track02 excluded')
check(policy.allowed({isStudio=false,universe=10768420544,place=127925465904803,role='HUB',privateId=''}),'exact production Hub')
for _,ctx in {
 {isStudio=true,universe=10768420544,place=127925465904803,role='HUB',privateId=''},
 {isStudio=false,universe=10772198697,place=106553302629620,role='HUB',privateId=''},
 {isStudio=false,universe=10768420544,place=106553302629620,role='HUB',privateId=''},
 {isStudio=false,universe=10768420544,place=127925465904803,role='HUB',privateId='paid'},
 {isStudio=false,universe=10768420544,place=127925465904803,role='RACE',privateId='paid',ownerId=123},
}do check(not policy.allowed(ctx),'no live storage in QA/Studio/mixed/paid server')end
check(policy.format(policy.Boards.SOLO_Park,79123)=='1:19.123','milliseconds format')
check(policy.format(policy.Boards.CASH,1234567)=='K$ 1,234,567','cash format')
local scores=policy.project({parkTimeTrial={bestMilliseconds=39123},parkTwoLapTrial={bestMilliseconds=80000},wallet={cash=999,lifetimeEarned=777}})
check(scores.SOLO_Park==80000 and scores.CASH==777,'Park is saved two-lap total; cash ranking is earnings, not balance')
check(policy.project({parkTimeTrial={bestMilliseconds=39123}}).SOLO_Park==nil,'never multiply a lone lap PB to fabricate a full finish')
check(next(policy.project({deleted=true,parkTimeTrial={bestMilliseconds=20000}}))==nil,'deleted profile rejected')
for _,bad in {0,-1,0/0,math.huge,10000.5,19999,'30000'}do check(policy.project({parkTwoLapTrial={bestMilliseconds=bad}}).SOLO_Park==nil,'invalid Park total rejected')end
local enabled=policy
local function evidence(category)
 local humans=if category=='HUMAN_4H_0B'then 4 elseif category=='SOLO_1H_0B'then 1 else 2
 return {trackId='Track01Race',geometryId='PracticeCircuitV1',rulesetId=enabled.Ruleset,category=category,
  userId=1,eligible=true,serverAccepted=true,state='FINISHED',positionFinalized=true,startingBots=0,startingHumans=humans,targetLaps=2,laps={50000,51000},totalMilliseconds=101000}
end
local profile={userId=1,wallet={cash=10,lifetimeEarned=9000},records={races={a={lastRace=evidence('HUMAN_2H_0B')},b={lastRace=evidence('HUMAN_4H_0B')}}}}
profile.records.races.b.lastRace.laps={48000,55000};profile.records.races.b.lastRace.totalMilliseconds=103000
check(enabled.project(profile).MULTI_Track01Race==101000 and enabled.project(profile).CASH==9000,'best whole finish wins despite another race having a faster individual lap')
profile.records.races.b.lastRace.category='BOT_1H_1B'
check(enabled.project(profile).MULTI_Track01Race==101000,'bot-assisted finish excluded')
profile.records.races.a.lastRace.eligible=false
check(enabled.project(profile).MULTI_Track01Race==nil,'invalid evidence excluded')
profile.records.races.a.lastRace=evidence('SOLO_1H_0B');profile.records.races.a.lastRace.targetLaps=3
check(enabled.project(profile).SOLO_Track01Race==nil,'old lap-count rules excluded')
profile.records.races.a.lastRace=evidence('SOLO_1H_0B');profile.records.races.a.lastRace.userId=2
check(enabled.project(profile).SOLO_Track01Race==nil,'another account cannot supply a record')
profile.records.races.a.lastRace=evidence('SOLO_1H_0B');profile.records.races.a.lastRace.totalMilliseconds=1
check(enabled.project(profile).SOLO_Track01Race==nil,'inconsistent full-race timer rejected')
profile.records.races.a.lastRace=evidence('SOLO_1H_0B')
check(enabled.project(profile).SOLO_Track01Race==101000 and enabled.project(profile).MULTI_Track01Race==nil,'solo and multiplayer total indices remain separate')
for _,track in enabled.Tracks do if track.id~='Park'then
 local race=evidence('SOLO_1H_0B');race.trackId=track.id;race.geometryId=track.geometry;race.targetLaps=track.laps
 race.laps=table.create(track.laps,50000);race.totalMilliseconds=track.laps*50000
 check(enabled.project({userId=1,records={races={a={bestRace=race}}}})['SOLO_'..track.id]==race.totalMilliseconds,'complete '..track.laps..'-lap finish '..track.id)
end end
local Runtime=luau.load(fs.readFile('src/server/HubLeaderboardRuntime.luau'))()
local storage={};local failWrite,failRead=false,false;local writes=0
local runtime=Runtime.new(policy,{
 remove=function(_,uid)storage[uid]=nil;return true end,
 upsert=function(b,uid,score)writes+=1;if failWrite then return false end;storage[uid]=math.min(storage[uid]or math.huge,score);return true end,
 read=function()if failRead then error('network')end;return {{key='2',value=40000},{key='1',value=30000},{key='bad',value=1},{key='3',value=-1}}end,
})
runtime:offer(1,{SOLO_Park=40000});runtime:offer(1,{SOLO_Park=50000});runtime:write(0)
check(storage[1]==40000,'worse/out-of-order profile never overwrites faster lap; no wallet write')
runtime:offer(1,{SOLO_Park=39000});failWrite=true;runtime:write(1);local previous=writes;runtime:write(1.5)
check(writes==previous and runtime.pending[1]~=nil,'failed index retained with bounded backoff')
failWrite=false;runtime:write(4);check(storage[1]==39000 and runtime.pending[1]==nil,'retry settles once without adding score')
check(runtime:request('SOLO_Park',0).status=='LOADING','empty cache is loading, not fake data')
runtime:read(0);local data=runtime:request('SOLO_Park',1)
check(data.status=='READY'and #data.rows==2 and data.rows[1].userId==1,'sorted/filter-valid top page')
runtime:request('SOLO_Park',61);failRead=true;runtime:read(61)
check(runtime.cache.SOLO_Park.status=='STALE'and #runtime.cache.SOLO_Park.rows==2,'read failure preserves last good ranking')
check(runtime:request('not-a-board',0)==nil,'invalid query cannot access storage')
local disabled=luau.load((source:gsub('CashEnabled=true','CashEnabled=false'):gsub('MultiEnabled=true','MultiEnabled=false')))()
check(Runtime.new(disabled,{}):request('CASH',0).status=='POLICY_PENDING','disabled policy cannot access storage')
runtime:offer(7,{});check(runtime.pending[7]==nil,'empty profiles cannot leave an undrainable queue')
runtime:remove(1);for i=1,#policy.Order do runtime:write(100+i)end
check(storage[1]==nil and runtime.own[1]==nil and runtime.pending[1]==nil,'deleted profile removes derived scores without editing account')
local cashStore={};local descending=Runtime.new(policy,{
 upsert=function(_,uid,value)cashStore[uid]=math.max(cashStore[uid]or 0,value);return true end,
 read=function()local r={};for i=1,60 do table.insert(r,{key=tostring(i),value=i*100})end;return r end,
})
descending:offer(1,{CASH=9000});descending:offer(1,{CASH=8000});descending:write(0)
check(cashStore[1]==9000,'stale earnings snapshot cannot decrease ranking')
descending:request('CASH',0);descending:read(0)
check(#descending.cache.CASH.rows==50 and descending.cache.CASH.rows[1].userId==60,'descending top50 selected after sorting')
local order={};local fair=Runtime.new(policy,{read=function(b)table.insert(order,b.id);return {}end})
fair:request('SOLO_Park',0);fair:request('CASH',1);fair:request('MULTI_Track01Race',2)
fair:request('SOLO_Park',10);fair:read(12);fair:read(24);fair:read(36)
check(table.concat(order,',')=='SOLO_Park,CASH,MULTI_Track01Race','repeated world/detail requests cannot starve an older requested board')
local persisted={};local adapters={
 upsert=function(_,uid,score)persisted[uid]=math.min(persisted[uid]or math.huge,score);return true end,
 read=function()local rows={};for uid,score in persisted do table.insert(rows,{key=tostring(uid),value=score})end;return rows end,
}
local writer=Runtime.new(policy,adapters);writer:offer(11,{SOLO_Park=120000});writer:offer(22,{SOLO_Park=110000});writer:write(0);writer:write(1)
local reopened=Runtime.new(policy,adapters);reopened:request('SOLO_Park',0);reopened:read(0)
check(#reopened.cache.SOLO_Park.rows==2 and reopened.cache.SOLO_Park.rows[1].userId==22,'two distinct users survive cache/server recreation and occupy separate rows')
local pages,consumed={},{};local retry=true;local capacity=true
local scan=Runtime.newBackfill({canStep=function()return capacity end,
 page=function(cursor)table.insert(pages,cursor);if cursor==''then return {keys={'u:11','u:22'},cursor='page2',finished=false}end;return {keys={'u:33'},cursor='',finished=true}end,
 consume=function(key)if key=='u:22'and retry then retry=false;error('temporary read failure')end;table.insert(consumed,key);return true end,
})
scan:step(0);scan:step(2);scan:step(4)
check(scan.visited==1 and scan.index==2,'offline backfill retains failed key rather than skipping it')
capacity=false;scan:step(6);check(#consumed==1,'backfill respects live traffic / queue backpressure')
capacity=true;for now=8,24,2 do scan:step(now)end
check(scan.done and scan.visited==3 and table.concat(consumed,',')=='u:11,u:22,u:33'and table.concat(pages,',')==',page2','paged offline profiles indexed once per successful read, including departed users')
local pageAttempts=0;local retryPage=Runtime.newBackfill({canStep=function()return true end,consume=function()return true end,
 page=function(cursor)pageAttempts+=1;assert(cursor=='');if pageAttempts==1 then error('list unavailable')end;return {keys={},cursor='',finished=true}end})
retryPage:step(0);check(retryPage.cursor==''and not retryPage.done,'failed listing preserves first cursor')
retryPage:step(2);retryPage:step(4);check(retryPage.done and pageAttempts==2,'empty successful final page terminates sweep')
local server=fs.readFile('src/server/HubLeaderboardService.luau')
check(not server:find('SetAsync',1,true)and not server:find('IncrementAsync',1,true),'no blind overwrite/increment API')
check(server:find("GetDataStore('KDM_PlayerProgress_v1'):GetAsync",1,true)~=nil,'profile store read only')
check(server:find('options.UseCache=false',1,true)~=nil,'confirmed profile refresh cannot reuse a stale account cache')
check(server:find("if not live then",1,true)~=nil,'Studio memory adapter')
for _,path in {'src/shared/HubLeaderboardPolicy.luau','src/server/HubLeaderboardRuntime.luau','src/server/HubLeaderboardBoardBuilder.luau','src/server/HubLeaderboardService.luau','src/server/HubLeaderboardBootstrap.server.luau','src/client/HubLeaderboardController.luau','src/client/HubLeaderboardBootstrap.client.luau'}do
 local ok,err=pcall(luau.load,fs.readFile(path));check(ok,'compile '..path..': '..tostring(err))
end
print('PASS: '..n..' Hub leaderboard policy, exact environment, profile projection, retry/cache and compile checks')

local board=fs.readFile('src/server/HubLeaderboardBoardBuilder.luau')
check(board:find("d.name..'KioskScreen'",1,true)and board:find("d.name..'KioskStand'",1,true),'each ranking board has a visible terminal and pedestal')
check(board:find('USE THE KIOSK BELOW',1,true)and board:find('APPROACH & INTERACT',1,true),'world board and kiosk explain approach interaction')
check(board:find('prompt.MaxActivationDistance=8',1,true),'detail prompt is close-range at kiosk')
