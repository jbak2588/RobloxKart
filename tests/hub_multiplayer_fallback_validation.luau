local fs,luau=require('@lune/fs'),require('@lune/luau')
local P=luau.load(fs.readFile('src/shared/HubLeaderboardPolicy.luau'))()
local n=0;local function check(v,m)assert(v,m);n+=1 end
local function race()
 return {userId=7,trackId='Track01',geometryId='PracticeFigure8V1',targetLaps=3,
  rulesetId=P.Ruleset,eligible=true,serverAccepted=true,state='FINISHED',positionFinalized=true,
  startingHumans=1,startingBots=1,category='BOT_1H_1B',laps={30000,31000,32000},totalMilliseconds=93000}
end
local function project(r)return P.project({userId=7,records={races={one={bestRace=r}}}})end
local scores=project(race())
check(scores.BOT_Track01==93000 and scores.MULTI_Track01==nil and scores.SOLO_Track01==nil,'exact1H1B uses separate full-total index')
check(P.Boards.MULTI_Track01.scope=='MULTI_Track01_TOTAL_R2_L3' and P.Boards.BOT_Track01.scope=='BOT_Track01_TOTAL_R2_L3','human scope preserved; bot scope separate')
for _,patch in {{startingBots=2},{startingHumans=2},{category='BOT_ASSISTED_2H_1B'},
 {eligible=false},{serverAccepted=false},{positionFinalized=false},{state='DNF'},
 {userId=8},{targetLaps=2},{geometryId='Other'},{totalMilliseconds=90000},{rulesetId='Other'}}do
 local r=race();for k,v in patch do r[k]=v end
 check(next(project(r))==nil,'reject invalid/incomplete/mixed bot evidence')
end
local function rows(ids)
 local out={};for i,id in ids do table.insert(out,{userId=id,score=100000+i*1000})end;return out
end
local human=rows({1,2,3,4});local bots=rows({2,5,6,7})
bots[2].score=80000
local mixed=P.multiplayerRows(human,bots)
check(#mixed==5 and mixed[1].userId==1 and mixed[4].userId==4 and mixed[5].userId==5,'four humans first; duplicate human excluded from fallback')
check(mixed[5].score==80000 and mixed[4].score>mixed[5].score,'source priority is explicit even when bot finish is faster')
check(mixed[5].source=='BOT_1H_1B' and mixed[1].source=='HUMAN','each row exposes provenance')
check(human[1].source==nil and bots[2].source==nil,'composition never mutates source caches')
check(#P.multiplayerRows(rows({1,2,3,4,5,6}),bots)==6,'five-plus humans keep full human Top50 without bots')
check(#P.multiplayerRows({},rows({1,2,3,4,5,6}))==5,'no-human board fills at most5 bot users')
check(#P.multiplayerRows(rows({1,2}),rows({2,3,4}))==4,'does not fabricate a fifth distinct user')
local cache={}
for _,t in P.Tracks do if t.id~='Park'then
 cache['MULTI_'..t.id]={status='READY',rows={}}
 cache['BOT_'..t.id]={status='READY',rows={}}
end end
cache.MULTI_Track01.rows=human;cache.BOT_Track01.rows=rows({2,5,6,7,8,9})
cache.MULTI_Track01Desert.rows=rows({1,2});cache.BOT_Track01Desert.rows=rows({1,3,4})
cache.MULTI_Track01Race.rows=human;cache.BOT_Track01Race.rows=rows({1,2,5})
check(P.featuredMulti(cache,'MULTI_Track01Desert')=='MULTI_Track01','Green4H plus bot coverage beats Desert4 combined and Base5 combined')
cache.MULTI_Track01Race.rows=rows({1,2,3,4,5})
check(P.featuredMulti(cache,'MULTI_Track01')=='MULTI_Track01Race','full human Top5 takes priority over bot-filled Top5')
cache.BOT_Track01Race.status='STALE'
check(P.featuredMulti(cache,'MULTI_Track01Desert')=='MULTI_Track01Desert','stale source preserves current featured track')
cache.BOT_Track01Race=nil
check(P.featuredMulti(cache,nil)==P.DefaultMulti,'incomplete caches use inspected Green default')
local service=fs.readFile('src/server/HubLeaderboardService.luau')
check(service:find("model.MultiBoardOpen:SetAttribute('LeaderboardId',featured)",1,true)~=nil,'physical board and kiosk switch together')
check(service:find("WS:SetAttribute('KDMFeaturedMultiBoardId',featured)",1,true)~=nil,'initial detail tab receives server selection')
check(service:find("sourceRows=if c.status=='READY'or c.status=='STALE'",1,true)~=nil,'never show fallback before human index loads')
print('PASS '..n..' human-first Top5 fallback, separate evidence, unique users and featured-track checks')
