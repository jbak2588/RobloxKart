local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local function load(path,env) return luau.load(fs.readFile(path),{environment=env or {},debugName=path})() end
local S=load('src/shared/KDMProgressionSchema.luau')
local schema=S.new(load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum}))
local Ops=load('src/server/RaceRecordOperations.luau')
local Collector=load('src/server/OfficialRaceRecords.luau')
local View=load('src/client/PersonalRecordsController.luau')
local checks=0
local function check(v,label) checks+=1;assert(v,label) end
local function guid(n) return string.format('12345678-1234-1234-1234-%012d',n) end
local function operation(n,laps,total,position,roster,at,eligible)
 local r=S.freezeRound({RoundGuid=guid(n),TrackId='Track02',GeometryId='PrototypeCircuitV2B',RulesetId='KDM_R8A3_RULES_V1',
  diagnostic=false,roster=roster or {{IsBot=false,UserId=1}}})
 local sum=0;local best=math.huge;for _,ms in laps do sum+=ms;best=math.min(best,ms) end
 local timestamp=at or 1791650000000+n
 return {kind='OFFICIAL_RECORD',round=r,userId=1,bestLapMilliseconds=best,bestRaceBoosts=n,
  achievedAt=timestamp,verification={serverAccepted=true,state='FINISHED',targetLaps=#laps,completedLaps=#laps,
   fullLapValid=true,provenance='FULL_ROUTE_V1',boostIdentity='SERVER_SERIAL_V1'},
  race={trackId=r.TrackId,geometryId=r.GeometryId,rulesetId=r.RulesetId,category=r.RaceCategory,
   recordScope=r.recordScope,targetLaps=#laps,roundGuid=r.RoundGuid,userId=1,totalMilliseconds=total or sum,
   laps=laps,finishPosition=position or 1,startingHumans=r.humanCount,startingBots=r.botCount,raceBoosts=n,
   finishedAt=timestamp,eligible=eligible~=false,reason=if eligible==false then 'INVALID_ROUTE_OR_TIMER_RESET' else 'FULL_ROUTE_V1',
   serverAccepted=true,state='FINISHED',positionFinalized=true}}
end
local original=schema.default(1);original.selection.kartId='Kart07';original.wallet.cash=321
original.cosmetics.ownedPartIds.wheel=true;original.receipts.old={signature='preserved'};original.future={preserved=true}
local legacy=operation(1,{53000,55000});local oldOp=S.clone(legacy);oldOp.race=nil
local old=Ops.reduce(S,schema,oldOp)(original)
check(old.records.races==nil,'PV565 full race history never inferred')
local first=operation(2,{54000,56000});local p=Ops.reduce(S,schema,first)(old)
local scope=S.raceScope(first.round.recordScope,2)
check(schema.validate(p,'u:1'),'optional snapshots valid in schema v1')
check(p.records.races[scope].bestRace.totalMilliseconds==110000 and #p.records.races[scope].bestRace.laps==2,'2lap coherent snapshot')
local slow=operation(3,{51000,65000});p=Ops.reduce(S,schema,slow)(p)
check(p.records.races[scope].bestRace.roundGuid==first.round.RoundGuid,'fast lap cannot replace slower total')
check(p.records.scoped[first.round.recordScope].bestLapMilliseconds==51000,'single lap PB independently improves')
check(p.records.races[scope].lastRace.totalMilliseconds==116000,'slower new last race recorded')
local newer=S.clone(p)
local stale=operation(4,{55000,58000},nil,nil,nil,1791650000001)
p=Ops.reduce(S,schema,stale)(p)
check(p.records.races[scope].lastRace.roundGuid==slow.round.RoundGuid,'late older server cannot reverse last race')
local replay,status=Ops.reduce(S,schema,slow)(p)
check(status=='REPLAY' and S.canonical(replay)==S.canonical(p),'lost ACK retry no duplicate Boost or result')
local callback=Ops.reduce(S,schema,slow)(old)
check(S.canonical(callback)==S.canonical(Ops.reduce(S,schema,slow)(old)),'UpdateAsync callback replay deterministic')
local three=operation(5,{55000,56000,57000});p=Ops.reduce(S,schema,three)(p)
check(p.records.races[S.raceScope(first.round.recordScope,3)].bestRace.totalMilliseconds==168000,'3laps isolated from 2lap')
local roster={};for id=1,4 do table.insert(roster,{IsBot=false,UserId=id}) end
local fourth=operation(6,{49000,50000},nil,4,roster);p=Ops.reduce(S,schema,fourth)(p)
check(p.records.races[S.raceScope(fourth.round.recordScope,2)].bestRace.finishPosition==4,'4th personal PB is not victory')
for humans=1,4 do
 local members={};for id=1,humans do table.insert(members,{IsBot=false,UserId=id}) end
 local op=operation(10+humans,{60000,60000},nil,humans,members)
 check(Ops.valid(S,op),'human category accepted '..humans)
 check(op.race.category==(if humans==1 then 'SOLO_1H_0B' else 'HUMAN_'..humans..'H_0B'),'frozen category '..humans)
end
for _,members in {{{IsBot=false,UserId=1},{IsBot=true,BotId='bot'}},{{IsBot=false,UserId=1},{IsBot=false,UserId=2},{IsBot=true,BotId='bot'}}} do
 local op=operation(20,{50000,51000},nil,1,members);local bot=Ops.reduce(S,schema,op)(original)
 check(next(bot.pendingIndex)==nil and bot.pendingRaceIndex==nil,'Bot never enters human index')
 check(bot.records.races[S.raceScope(op.round.recordScope,2)].bestRace~=nil,'Bot personal snapshot retained')
end
local invalid=operation(30,{20000,20000},60000,nil,nil,nil,false);p=Ops.reduce(S,schema,invalid)(p)
check(p.records.races[scope].bestRace.totalMilliseconds==110000 and p.records.races[scope].lastRace.totalMilliseconds==60000,'reset mismatch retained honestly but never best race')
for _,state in {'DNF','FORFEIT','FINISHING'} do local bad=S.clone(first);bad.verification.state=state;check(not Ops.valid(S,bad),'no official result '..state) end
local bad=S.clone(first);bad.race.totalMilliseconds=1000;check(not Ops.valid(S,bad),'eligible fabricated total rejected')
bad=S.clone(first);bad.race.positionFinalized=false;check(not Ops.valid(S,bad),'temporary position rejected')
bad=S.clone(first);bad.race.laps[3]=100;check(not Ops.valid(S,bad),'wrong lap count rejected')
bad=S.clone(first);bad.race.userId=2;check(not Ops.valid(S,bad),'different profile user rejected')
for _,field in {'selection','wallet','cosmetics','future'} do check(S.canonical(p[field])==S.canonical(original[field]),'legacy field preservation '..field) end
check(p.receipts.old.signature=='preserved' and old.records.scoped[first.round.recordScope].bestLapMilliseconds==53000,'legacy receipt and old numeric record preserved')
local dirty=newer.pendingRaceIndex[scope];local repaired=Ops.clearIndex(S,schema,1,scope,dirty)(newer)
check(repaired.pendingRaceIndex[scope]==nil,'race index acknowledged snapshot cleared')
local fast=operation(31,{48000,49000});local advanced=Ops.reduce(S,schema,fast)(newer)
check(select(2,Ops.clearIndex(S,schema,1,scope,dirty)(advanced))=='INDEX_ADVANCED','stale index repair cannot clear new PB')
local corrupt=S.clone(p);corrupt.records.races[scope].bestRace.eligible=false
check(not schema.validate(corrupt,'u:1'),'corrupt ineligible PB quarantined')
local text=table.concat(View.lines({status='FOUND',records=p.records}),'\n')
for _,word in {'BEST RACE','LAST RACE','Total Time 1:50.000','Lap 1','Lap 2','Finish Position 4 / 4','BEST LAP','DRIFT RECORDS','4 drivers'} do check(text:find(word,1,true)~=nil,'mobile detail '..word) end
check(not text:find('record:v1|',1,true) and not text:find('SOLO_1H_0B',1,true),'human-readable categories and track names')

-- Exercise actual observer with approved lap clock, reset mismatch and route discontinuity.
local u={UserId=1,attrs={RaceState='RACING'}};function u:GetAttribute(k)return self.attrs[k] end
local function fixture(n,laps)
 u.attrs.RaceState='RACING';local c=Collector.new(S,{utcMs=function() return 1791650000000+n end})
 c.begin(S.clone(operation(n,{20000,20000}).round),{u},6,laps,1000);c.start(u,0);return c
end
local function lap(c,start,reset,shortcut)
 for i=0,100 do
  local f=(i/100)%1;local pos=rb.Vector3.new(math.cos(f*math.pi*2)*1000/(2*math.pi),0,math.sin(f*math.pi*2)*1000/(2*math.pi))
  if not shortcut or i<30 or i>70 then c.sample(u,start+i*.2,pos,f) end
  if reset and i==50 then c.invalidate(u) end
  c.checkpoints(u,math.min(7,math.floor(i/14)+1))
 end
 return c.lap(u,start+20,if reset then 10 else 20)
end
for laps=2,3 do
 local c=fixture(100+laps,laps);for n=1,laps do check(lap(c,(n-1)*20,false,false),'valid collected lap') end
 u.attrs.RaceState='FINISHED';local op=c.finish(u,{totalTime=laps*20,position=1,positionFinalized=true})
 check(op.race.totalMilliseconds==laps*20000 and #op.race.laps==laps and Ops.valid(S,op),'official timer collected '..laps)
 check(c.finish(u,{totalTime=laps*20,position=1,positionFinalized=true})==nil,'collector finish dedup')
end
for _,fault in {'reset','shortcut'} do
 local c=fixture(110,2);check(not lap(c,0,fault=='reset',fault=='shortcut'),'invalid provenance')
 check(lap(c,20,false,false),'following full lap PB allowed');u.attrs.RaceState='FINISHED'
 local op=c.finish(u,{totalTime=40,position=1,positionFinalized=true})
 check(not op.race.eligible and op.bestLapMilliseconds==20000,'whole race invalid but independent valid lap preserved')
 check(op.race.laps[1]==(if fault=='reset' then 10000 else 20000),'no fabricated repaired lap')
end
print('PASS: '..checks..' full race snapshots, fairness, concurrency, preservation and UI checks')
