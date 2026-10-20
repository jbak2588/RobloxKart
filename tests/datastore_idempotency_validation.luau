-- Production reducers; trusted-clock policy, no DataStore/network access.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local base=fs.readFile('tests/r8_a4_economy_validation.luau')
local at=assert(base:find('for rank,base in',1,true))
luau.load(base:sub(1,at-1)..[[
local now=1791650100000
schema=S.new(catalog,{utcMs=function()return now end,jsonEncode=function(v)return serde.encode('json',v)end})
local C=load('src/shared/KDMShopCatalog.luau')
local Shop=load('src/server/ShopOperations.luau').new(S,schema,C,Economy)
local Selection=load('src/server/ProgressionOperations.luau')
local Adapter=load('src/server/ProgressionDataStoreAdapter.luau')
local function stamp(o)o.transaction=schema.issueTransaction();return o end
local function race(n)
 local o=op(n,1,1,1);o.achievedAt=now;o.race.finishedAt=now
 o.race.eligible=false;o.race.reason='INVALID_ROUTE_OR_TIMER_RESET'
 return stamp(o)
end
local function account()
 local p=schema.default(1);p.wallet.cash=10000;p.onboarding.finishEvent.claimed=true
 return p
end
local p=account();local a=race(70001)
p=assert(Records.reduce(S,schema,a)(p));check(p.wallet.cash==11500,'scenario 1 exact existing 1500 base')
local repeatA,status=Records.reduce(S,schema,a)(p);check(status=='REPLAY' and repeatA.wallet.cash==11500,'scenario 1 duplicate zero')
local b=race(70002);p=assert(Records.reduce(S,schema,b)(p))
local again=assert(Records.reduce(S,schema,a)(p));check(again.wallet.cash==13000,'scenario 2 A B A')
local buy=stamp({kind='BUY_ITEM',id=guid(70003),userId=1,itemId='Smoke'})
p=assert(Shop.reduce(buy)(p));local cash=p.wallet.cash
check(Records.reduce(S,schema,a)(p).wallet.cash==cash,'scenario 3 A purchase A')
local selected=stamp({kind='SELECT_KART',operationId=guid(70004),kartId='Kart09',expectedSelectionRevision=p.selection.revision})
p=assert(Selection.selection(S,schema,1,selected)(p))
check(Records.reduce(S,schema,a)(p).wallet.cash==cash,'scenario 3 A selection A')
check(Selection.resolveSelection(S,schema,{status='FOUND',key=S.userKey(1),value=p},1,selected).state=='SAVED','selection hashed confirmation')
-- Slot identity is immutable even when a caller changes an unrelated transaction's payload.
local changed=S.clone(a);changed.bestRaceBoosts+=1;changed.race.raceBoosts+=1
local no,why=Records.reduce(S,schema,changed)(p);check(not no and why=='IDENTITY_MISMATCH','same RoundGuid different payload rejected')
-- UpdateAsync writes, loses ACK, reruns callback against latest value; uncached verify.
local saved=S.clone(p);local lose=true
local backend={GetAsync=function()return S.clone(saved)end,UpdateAsync=function(_,_,cb)
 local v=cb(S.clone(saved));if v then saved=S.clone(v)end
 if lose then lose=false;error('lost ACK')end
 return S.clone(saved)
end}
local adapter=Adapter.new({schema=schema,key=S.userKey(1),authorize=function()return true end,budget=function()return true end,getStore=function()return backend end,getOptions=function()return {UseCache=false}end})
local c=race(70005);local expected=saved.wallet.cash+1500
check(adapter.commit(adapter.beginUpdate(S.userKey(1),Records.reduce(S,schema,c))).status=='PENDING','scenario 5 lost ACK')
check(adapter.commit(adapter.beginUpdate(S.userKey(1),Records.reduce(S,schema,c))).outcome=='REPLAY','scenario 5 retry')
check(saved.wallet.cash==expected and Records.confirm(S,schema,adapter.read(S.userKey(1)),c)~=nil,'scenario 5 readback and one credit')
local server2=Records.reduce(S,schema,c);check(server2(saved).wallet.cash==expected,'two server callbacks serialize one credit')
-- Preserve an active reservation while other writes proceed; repeated close is idempotent.
p=account();p.shopInventory={counts={Smoke=3},autoRefill=true,revision=0}
local reserve=stamp({kind='REFILL',id=guid(71000),roundGuid=guid(71000),userId=1,itemId='Smoke',jobId='dead-job',reservedAt=math.floor(now/1000)})
p=assert(Shop.reduce(reserve)(p));p=assert(Records.reduce(S,schema,race(71001))(p))
local refund=S.clone(reserve);refund.kind='REFUND_REFILL'
p=assert(Shop.reduce(refund)(p));check(p.shopInventory.counts.Smoke==3,'scenario 6 refund after other write')
check(Shop.reduce(refund)(p).shopInventory.counts.Smoke==3,'scenario 6 refund replay')
local reserve2=stamp({kind='REFILL',id=guid(71002),roundGuid=guid(71002),userId=1,itemId='Smoke',jobId='job',reservedAt=math.floor(now/1000)})
p=assert(Shop.reduce(reserve2)(p));local finalize=S.clone(reserve2);finalize.kind='FINALIZE_REFILL'
p=assert(Shop.reduce(finalize)(p));check(Shop.reduce(finalize)(p).shopInventory.counts.Smoke==2,'finalize once')
local unused=S.clone(finalize);unused.kind='REFUND_UNUSED_REFILL';p=assert(Shop.reduce(unused)(p));check(Shop.reduce(unused)(p).shopInventory.counts.Smoke==3,'unused compensation once')
-- Same-round max still enforced across unrelated writes.
for i,id in {'Missile','Shield','Thunder'} do
 p.shopInventory.counts[id]=2
 local refill=stamp({kind='REFILL',id=guid(71002),roundGuid=guid(71002),userId=1,itemId=id,jobId='job',reservedAt=math.floor(now/1000)})
 local result,code=Shop.reduce(refill)(p)
 if i==1 then p=assert(result) else check(not result and code=='ROUND_REFILL_LIMIT','same round refill limit')end
end
local reservedKey='shop-refill:'..guid(71002)..':Missile'
-- GC must preserve RESERVED, with explicit recovery after restart even past TTL.
local oldReserve=S.clone(p.receipts[reservedKey]);local oldRound=reserve2.roundGuid
now+=schema.transactionLifetimeMs+1
p=assert(Records.reduce(S,schema,race(72000))(p));check(p.receipts[reservedKey]~=nil,'expired unresolved reservation retained')
local recover={kind='REFUND_REFILL',id=guid(71002),roundGuid=oldRound,userId=1,itemId='Missile'}
local stockBefore=p.shopInventory.counts.Missile;p=assert(Shop.reduce(recover)(p));check(p.shopInventory.counts.Missile==stockBefore+1,'restart compensation without fresh admission')
check(Shop.confirm({status='FOUND',value=p},recover),'late recovery remains confirmable after prior expiry floor')
local duplicate,code=Shop.reduce(recover)(p);check(code=='REPLAY' and duplicate.shopInventory.counts.Missile==p.shopInventory.counts.Missile,'late recovery cannot refund twice')
-- Original expired request must fail, a fresh race still pays.
no,why=Records.reduce(S,schema,a)(p);check(not no and why=='TRANSACTION_EXPIRED','scenario 4 expired A refused')
local before=p.wallet.cash;p=assert(Records.reduce(S,schema,race(72001))(p));check(p.wallet.cash==before+1500,'scenario 4 fresh B allowed')
local oldRefill=stamp(S.clone(reserve2));oldRefill.transaction=reserve2.transaction
no,why=Shop.reduce(oldRefill)(p);check(not no and (why=='TRANSACTION_EXPIRED' or why=='REFILL_CLOSED'),'old round cannot renew refill lifetime')
local sizes={}
local function metrics(profile)
 local function bytes(v)return #serde.encode('json',v or {})end
 local other=S.clone(profile);for _,k in {'receipts','records','pendingIndex','pendingRaceIndex','purchaseHistory'}do other[k]=nil end
 return {total=bytes(profile),receipts=bytes(profile.receipts),scoped=bytes(profile.records.scoped),races=bytes(profile.records.races),metadata=bytes(profile.records.metadata),pendingIndex=bytes(profile.pendingIndex),pendingRaceIndex=bytes(profile.pendingRaceIndex),purchaseHistory=bytes(profile.purchaseHistory),other=bytes(other),receiptCount=S.count(profile.receipts)}
end
-- Gradual migration uses test clones only; known permanent data must survive.
for _,count in {0,1,40,1100} do
 local legacy=account();legacy.purchaseHistory={old={method='LEGACY',note='preserve'}}
 for i=1,count do legacy.receipts['legacy:'..i]={signature=string.rep('x',90)..i}end
 local source=S.canonical(legacy);local nextProfile=assert(Records.reduce(S,schema,race(73000+count))(legacy))
 check(S.canonical(legacy)==source,'migration never mutates source '..count)
 check(nextProfile.wallet.cash==11500 and nextProfile.purchaseHistory.old.note=='preserve','migration preserves economic history '..count)
 check(S.count(nextProfile.receipts)==count+1,'legacy retry window retained '..count)
 if count==1100 then sizes.legacy85kbBefore=metrics(legacy);sizes.legacy85kbMigrated=metrics(nextProfile);check(sizes.legacy85kbBefore.total>85000,'synthetic 85KB legacy')end
 now+=schema.transactionLifetimeMs+1
 nextProfile=assert(Records.reduce(S,schema,race(75000+count))(nextProfile))
 check(S.count(nextProfile.receipts)==1,'legacy expires safely '..count)
 if count==1100 then sizes.legacy85kbAfterExpiry=metrics(nextProfile)end
end
-- Canonical and SHA receipts both identify the same business operation.
for _,make in {function(v)return v end,S.sha256} do
 local o=race(76000);local profile=account();profile.receipts[Records.receiptKey(o)]={signature=make(S.transactionCanonical(o))}
 local same,code=Records.reduce(S,schema,o)(profile);check(code=='REPLAY' and same.wallet.cash==10000,'legacy/hash race compatibility')
 local sel=stamp({kind='SELECT_KART',operationId=guid(76001),kartId='Kart09',expectedSelectionRevision=0})
 profile.receipts['selection:'..sel.operationId]={signature=make(S.transactionCanonical(sel))}
 check(Selection.resolveSelection(S,schema,{status='FOUND',key=S.userKey(1),value=profile},1,sel).state=='SAVED','legacy/hash selection compatibility')
 local o2=stamp({kind='BUY_ITEM',id=guid(76002),userId=1,itemId='Smoke'})
 profile.receipts[Shop.key(o2)]={signature=make(S.transactionCanonical(o2))}
 check(Shop.confirm({status='FOUND',value=profile},o2),'legacy/hash purchase compatibility')
end
-- Index recovery work and authoritative metadata survive receipt expiry.
local indexed=op(76500,2,0,1);indexed.achievedAt=now;indexed.race.finishedAt=now;stamp(indexed)
local indexedProfile=assert(Records.reduce(S,schema,indexed)(account()))
local pending=S.canonical(indexedProfile.pendingIndex);local pendingRace=S.canonical(indexedProfile.pendingRaceIndex)
local evidence=S.canonical(indexedProfile.records)
now+=schema.transactionLifetimeMs+1
local cleaned=assert(schema.prepare(indexedProfile,schema.issueTransaction()))
check(S.canonical(cleaned.pendingIndex)==pending and S.canonical(cleaned.pendingRaceIndex)==pendingRace,'pending leaderboard repair retained through GC')
check(S.canonical(cleaned.records)==evidence,'best/last/metadata/lifetime survive GC')
local staleSelection=stamp({kind='SELECT_KART',operationId=guid(76501),kartId='Kart09',expectedSelectionRevision=0})
local selectedOnce=assert(Selection.selection(S,schema,1,staleSelection)(account()))
now+=schema.transactionLifetimeMs+1
selectedOnce=assert(schema.prepare(selectedOnce,schema.issueTransaction()))
local forgedRenewal=S.clone(staleSelection);forgedRenewal.transaction=schema.issueTransaction()
local denied,reason=Selection.selection(S,schema,1,forgedRenewal)(selectedOnce)
check(not denied and reason=='CONFLICT','selection revision protects even after receipt removal')
-- Full pending reservation set is never forcibly evicted, even after days.
local bounded=S.new(catalog,{maxReceipts=3,utcMs=function()return now end})
local pendingProfile=account();pendingProfile.shopInventory={counts={Smoke=1},revision=0,autoRefill=true}
for i=1,3 do pendingProfile.receipts['shop-refill:'..guid(76600+i)..':Smoke']={signature='old',issuedAt=now-864000000,refill={roundGuid=guid(76600+i),itemId='Smoke',state='RESERVED',jobId='dead',reservedAt=1}}end
local v,code=Records.reduce(S,bounded,race(76700))(pendingProfile)
check(not v and code=='RECEIPT_CAPACITY','unrecoverable pending capacity fails closed')
local recover={kind='REFUND_REFILL',id=guid(76601),roundGuid=guid(76601),userId=1,itemId='Smoke'}
local recovered=assert(load('src/server/ShopOperations.luau').new(S,bounded,C,Economy).reduce(recover)(pendingProfile))
check(recovered.shopInventory.counts.Smoke==2,'full pending profile can still recover')
-- Production capacity and tiny mock capacity both refuse rather than drop active receipts.
for _,limit in {3,16384} do
 local bounded=S.new(catalog,{maxReceipts=limit,utcMs=function()return now end})
 local profile=account()
 for i=1,limit do profile.receipts['reserved:'..i]={signature='legacy',issuedAt=now}end
 local v,code=Records.reduce(S,bounded,race(77000))(profile);check(not v and code=='RECEIPT_CAPACITY','active receipt cap '..limit)
 now+=schema.transactionLifetimeMs+1
 profile.receiptPolicy={version=1,floor=now-schema.transactionLifetimeMs,migratedAt=now-schema.transactionLifetimeMs-1}
 check(Records.reduce(S,bounded,race(77001))(profile)~=nil,'capacity frees only expired receipts '..limit)
end
-- Unknown ticket IDs are never minted afresh, across eviction or server restart.
local serial=80000;local function newId()serial+=1;return guid(serial)end
local book=S.newTicketBook(function()return now end,newId)
local body={kind='BUY_ITEM',itemId='Smoke',userId=1};local id=book.issue('player',body);body.id=id
local ticket=assert(book.resolve('player',body));check(ticket.transaction.issuedAt==now,'server issued time')
local altered=S.clone(body);altered.itemId='Shield';check(not book.resolve('player',altered),'ticket bound to immutable payload')
local restart=S.newTicketBook(function()return now end,newId);check(not restart.resolve('player',body),'unknown ID after restart refused')
now+=600001;check(not book.resolve('player',body),'ticket expiry cannot renew UUID')
-- Exercise the actual Shop RemoteFunction admission path (not a copied reducer).
local remoteProfile=account();local remoteInstance
local facade={allowed=function()return true end,publishProfile=function()end,passAvailable=function()return false end}
local remoteAdapter={read=function(key)return {status='FOUND',key=key,value=S.clone(remoteProfile)}end,
 beginUpdate=function(key,cb)return {key=key,cb=cb}end,
 commit=function(tx)local value,code=tx.cb(remoteProfile);if value then remoteProfile=value end;return {status=if value then 'SAVED' else code}end}
facade.accountAdapter=function()return remoteAdapter end
local signal={Connect=function()end}
local rs={Shared={KDMProgressionSchema='S',KDMShopCatalog='C',KartCatalog='Catalog'},FindFirstChild=function()return nil end}
local http={GenerateGUID=function()return newId()end,JSONEncode=function(_,v)return serde.encode('json',v)end}
local players={PlayerAdded=signal,PlayerRemoving=signal,GetPlayers=function()return {}end}
local modules={S=S,C=C,Catalog=catalog,Config=Config,Facade=facade,Economy=Economy,Shop=load('src/server/ShopOperations.luau')}
local osMock=table.clone(os);osMock.clock=function()return now/1000 end
local liveShop=load('src/server/ShopService.luau',{
 game={HttpService=http,GetService=function(_,name)return ({ReplicatedStorage=rs,HttpService=http,Players=players})[name]end},
 DateTime={now=function()return {UnixTimestampMillis=now}end},os=osMock,task={wait=function()end},
 Instance={new=function()remoteInstance={};return remoteInstance end},
 script={Parent={EconomyConfig='Config',EconomyService='Facade',EconomyOperations='Economy',ShopOperations='Shop'}},
 require=function(id)return assert(modules[id],tostring(id))end})
liveShop.start()
local player={UserId=1,SetAttribute=function()end,GetAttribute=function(_,key)return if key=='RaceState' then 'GARAGE' else nil end}
local invoke=remoteInstance.OnServerInvoke
local prepared=invoke(player,'PREPARE',{action='BUY_ITEM',itemId='Smoke'})
check(prepared.status=='PREPARED','actual remote prepares server ticket')
local result=invoke(player,'BUY_ITEM','Smoke',prepared.id)
check(result.purchaseState=='SAVE_CONFIRMED' and remoteProfile.wallet.cash==9750,'actual remote debits one fixed-price purchase')
now+=1000
result=invoke(player,'BUY_ITEM','Smoke',prepared.id)
check(result.purchaseState=='SAVE_CONFIRMED' and remoteProfile.wallet.cash==9750,'actual remote same request no second debit')
now+=600001
check(invoke(player,'BUY_ITEM','Smoke',prepared.id).purchaseState=='SAVE_CONFIRMED' and remoteProfile.wallet.cash==9750,'expired ticket can confirm receipt without minting debit authority')
now+=1000
check(invoke(player,'BUY_ITEM','Smoke',guid(1)).status=='TRANSACTION_EXPIRED' and remoteProfile.wallet.cash==9750,'client UUID cannot become fresh authority')
now+=1000
check(invoke(player,'PREPARE',{action='BUY_ITEM',itemId={}}).status=='INVALID_OPERATION','malformed ticket body denied before allocation')
local refreshed=S.clone(a);refreshed.transaction=schema.issueTransaction()
local denied,code=Records.reduce(S,schema,refreshed)(account())
check(not denied and code=='TRANSACTION_TIME_MISMATCH','old race cannot refresh completion timestamp on retry')
-- Fixed-rate sustained long use: real reducers, finite window, fresh IDs, no best-record deletion.
p=account()
for i=1,10000 do
 now+=3600000
 if i%2==0 then p=assert(Records.reduce(S,schema,race(90000+i))(p))
 else p=assert(Shop.reduce(stamp({kind='SET_AUTO_REFILL',id=guid(90000+i),userId=1,enabled=i%4==1}))(p))end
 if i==1000 then sizes.after1000=metrics(p)end
 if i==5000 then sizes.after5000=metrics(p)end
end
sizes.after10000=metrics(p)
check(sizes.after10000.receiptCount<=24,'scenario 8 finite active window')
check(sizes.after10000.total<=sizes.after5000.total+256,'scenario 8 long use plateau')
check(S.count(p.records.scoped)==1 and S.count(p.records.races)==1,'permanent last/best scoped records preserved')
local fresh=race(110001);local noClock=S.clone(fresh);noClock.transaction=nil
check(not Records.reduce(S,schema,noClock)(p),'strict production rejects missing authority')
local dn=stamp({userId=1,roundGuid=guid(120000),amount=1500,reason='ACTIVE_DNF_COMPLETION'})
local cash=p.wallet.cash;p=assert(Economy.dnf(S,schema,dn)(p));check(Economy.dnf(S,schema,dn)(p).wallet.cash==cash+1500,'existing DNF reward one credit')
local corrupt=S.clone(p);corrupt.receiptPolicy.floor='bad';local snapshot=S.canonical(corrupt)
check(not Records.reduce(S,schema,fresh)(corrupt) and S.canonical(corrupt)==snapshot,'corrupt migration fails read-only without reset')
fs.writeFile('artifacts/p0-economy/profile-byte-metrics.json',serde.encode('json',sizes,true))
print('PASS: '..checks..' datastore idempotency checks; 10000 long-lived transactions; no live writes')
]])()
