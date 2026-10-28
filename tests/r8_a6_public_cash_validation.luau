-- Actual production facades + adapter + official collector with isolated fake Roblox I/O.
-- Never connects to Roblox/DataStore; public config is injected, production flags stay OFF.
local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local function load(path,env)return luau.load(fs.readFile(path),{environment=env or {},debugName=path})()end
local S=load('src/shared/KDMProgressionSchema.luau')
local catalog=load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum})
local schema=S.new(catalog,{jsonEncode=function(v)return serde.encode('json',v)end})
local Config=load('src/server/EconomyConfig.luau');local Policy=load('src/server/EconomyPolicy.luau')
local checks=0;local function check(v,label)checks+=1;assert(v,label)end
local function guid(n)return string.format('12345678-1234-1234-1234-%012d',n)end
local public=S.clone(Config);public.StoragePublicEnabled=true;public.RewardsPublicEnabled=true;public.ShopTransactionsPublicEnabled=false
local ctx={isStudio=false,role='HUB',experienceId=Config.ExperienceId,placeId=Config.PlaceId,privateServerId='',privateServerOwnerId=0}
for _,role in {'HUB','RACE'} do
 ctx.role=role;ctx.privateServerId=if role=='HUB' then '' else 'reserved'
 for _,storage in {false,true} do for _,rewards in {false,true} do for _,shop in {false,true} do
  local c=S.clone(Config);c.StoragePublicEnabled=storage;c.RewardsPublicEnabled=rewards;c.ShopTransactionsPublicEnabled=shop
  for _,id in {2,11700555357} do
   local canary=id==11700555357;local access=storage or canary
   check(Policy.allowed(c,ctx,id,'read')==access,'storage matrix read')
   check(Policy.allowed(c,ctx,id,'initialize')==access,'storage matrix initialization')
   check(Policy.allowed(c,ctx,id,'reward')==(role=='RACE' and access and (rewards or canary)),'reward matrix')
   check(Policy.allowed(c,ctx,id,'shop')==(role=='HUB' and access and (shop or canary)),'shop matrix')
   check(Policy.allowed(c,ctx,id,'voucher')==(role=='RACE' and access and (shop or canary)),'voucher matrix')
   check(not Policy.allowed(c,ctx,id,'arbitrary-cash-grant'),'unknown capability denied')
  end
 end end end
end
for field,value in {experienceId=0,placeId=0,privateServerOwnerId=2,privateServerId=false} do
 local c=S.clone(ctx);c[field]=value;check(not Policy.allowed(public,c,2,'reward'),'wrong context blocked '..field)
end
local function node(name)local n={Name=name,children={}}
 function n:WaitForChild(k)return assert(self.children[k],k)end
 function n:FindFirstChild(k)return self.children[k]end
 return n
end
local function signal()return {Connect=function()return {Disconnect=function()end}end}end
local function fixture(userId,backend)
 local f={now=0,queue={},serial=0,role='HUB',remotes={},close={},studio=false,lookups=0,stores=0,market=0,indexCalls=0}
 backend=backend or {values={},reads=0,writes=0,budget=100};f.backend=backend
 local p={UserId=userId or 2,attrs={RaceState='GARAGE'},Parent=true};f.player=p
 function p:GetAttribute(k)return self.attrs[k]end
 function p:SetAttribute(k,v)self.attrs[k]=v end
 function p:GetAttributeChangedSignal()return signal()end
 local shared,server=node('Shared'),node('Server');local nodes,cache={},{}
 for _,path in {'src/shared/KDMProgressionSchema.luau','src/shared/KDMPerformanceBuffer.luau','src/shared/KartCatalog.luau','src/shared/TrackCatalog.luau','src/shared/KDMShopCatalog.luau',
  'src/server/EconomyService.luau','src/server/EconomyConfig.luau','src/server/EconomyPolicy.luau','src/server/EconomyOperations.luau','src/server/ProgressionDataStoreAdapter.luau',
  'src/server/ProgressionMockStore.luau',
  'src/server/ShopOperations.luau','src/server/ShopService.luau','src/server/RaceRecordService.luau','src/server/RaceRecordConfig.luau','src/server/RaceRecordPolicy.luau',
  'src/server/RaceRecordOperations.luau','src/server/RaceRecordRuntime.luau','src/server/RaceRecordReset.luau','src/server/OfficialRaceRecords.luau'} do
  local name=path:match('/([^/]+)%.luau$');local parent=if path:find('/shared/',1,true)then shared else server
  local n=node(name);n.Parent=parent;n.path=path;parent.children[name]=n;parent[name]=n;nodes[name]=n
 end
 local RS={Shared=shared,WaitForChild=function()return shared end,FindFirstChild=function(_,n)return f.remotes[n]end}
 local players={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function()return {p}end}
 local ds={GetRequestBudgetForRequestType=function()return backend.budget end}
 function ds:GetDataStore(name)
  f.stores+=1
  check(name=='KDM_PlayerProgress_v1','unchanged store')
  return {GetAsync=function(_,key,options)
   check(key==S.userKey(p.UserId) and options.UseCache==false,'uncached existing key')
   backend.reads+=1
   if backend.readFail or backend.failReadAfterWrite and backend.writes>0 then error('mock read outage')end
   return S.clone(backend.values[key])
  end,UpdateAsync=function(_,key,cb)
   backend.writes+=1
   if backend.writeFail then error('mock write outage')end
   if backend.concurrent then local update=backend.concurrent;backend.concurrent=nil;update(backend,key)end
   local info={GetUserIds=function()return {p.UserId}end,GetMetadata=function()return {kept=true}end}
   local nextValue,ids,meta=cb(S.clone(backend.values[key]),info)
   if nextValue then
    local again=cb(S.clone(backend.values[key]),info)
    check(S.canonical(nextValue)==S.canonical(again),'platform callback retries deterministic')
    check(ids[1]==p.UserId and meta.kept,'key metadata retained')
    backend.values[key]=S.clone(nextValue)
   end
   if backend.ackLost then error('mock lost ACK')end
   return nextValue
  end}
 end
 function ds:GetOrderedDataStore()f.indexCalls+=1;return {UpdateAsync=function(_,_,cb)return cb(nil)end}end
 local services={ReplicatedStorage=RS,Players=players,DataStoreService=ds,RunService={IsStudio=function()return f.studio end},
  HttpService={JSONEncode=function(_,v)return serde.encode('json',v)end,GenerateGUID=function()f.serial+=1;return guid(f.serial)end},
  MarketplaceService={PromptGamePassPurchaseFinished=signal(),GetProductInfoAsync=function()f.market+=1;error('payment disabled')end,
   UserOwnsGamePassAsync=function()f.market+=1;error('payment disabled')end,PromptGamePassPurchase=function()f.market+=1;error('payment disabled')end}}
 local game={GameId=Config.ExperienceId,PlaceId=Config.PlaceId,PrivateServerId='',PrivateServerOwnerId=0,JobId='mock-job',PlaceVersion=681,HttpService=services.HttpService,
  GetService=function(_,name)if name=='DataStoreService'then f.lookups+=1 end;return assert(services[name],name)end,
  BindToClose=function(_,cb)table.insert(f.close,cb)end}
 local function enqueue(delay,fn)table.insert(f.queue,{at=f.now+delay,fn=fn})end
 function f.step(maxTime)
  table.sort(f.queue,function(a,b)return a.at<b.at end)
  local nextJob=f.queue[1];if not nextJob or nextJob.at>(maxTime or f.now+10)then return false end
  table.remove(f.queue,1);f.now=math.max(f.now,nextJob.at);nextJob.fn();return true
 end
 function f.drain()local endTime=f.now+10;local count=0;while f.step(endTime)do count+=1;assert(count<200,'bounded jobs')end end
 function f.race()f.role='RACE';game.PrivateServerId='reserved';p.attrs.RaceState='RACING'end
 function f.hub()f.role='HUB';game.PrivateServerId='';p.attrs.RaceState='GARAGE'end
 local env={game=game,workspace={GetAttribute=function(_,k)return if k=='KDMServerRole'then f.role else nil end},
  Enum=setmetatable({DataStoreRequestType={StandardRead=1,StandardWrite=2,OrderedRead=3,OrderedWrite=4}},{__index=rb.Enum}),Color3=rb.Color3,Vector3=rb.Vector3,CFrame=rb.CFrame,
  DateTime={now=function()return {UnixTimestampMillis=1791650000000}end},print=function()end,
  os={clock=function()return f.now end,time=function()return 1791650000 end},
  Instance={new=function(class)
   if class~='RemoteFunction'then return {}end
   return setmetatable({},{__newindex=function(t,k,v)rawset(t,k,v);if k=='Parent'then f.remotes[t.Name]=t end end})
  end},task={spawn=function(fn)enqueue(0,fn)end,defer=function(fn)enqueue(0,fn)end,delay=enqueue,wait=function(seconds)
   f.now+=seconds or .1;f.step(f.now);return seconds or .1
  end}}
 local function requireNode(n)
  if not cache[n]then
   if n.Name=='EconomyConfig'then cache[n]=S.clone(public)
   else local e=table.clone(env);e.script=n;e.require=requireNode;cache[n]=load(n.path,e)end
  end
  return cache[n]
 end
 f.Economy=requireNode(nodes.EconomyService);f.Records=requireNode(nodes.RaceRecordService);f.Shop=requireNode(nodes.ShopService)
 f.Ops=requireNode(nodes.RaceRecordOperations);f.Runtime=requireNode(nodes.RaceRecordRuntime)
 check(f.lookups==0,'production module loading has zero store calls')
 function f.qualify()local result=f.Economy.qualifyActivity(p,"TEST_DRIVE",{complete=true,movingMilliseconds=30000,distance=300});check(result.status=="FOUND","activity qualification confirmed");return result end
 function f.start()f.Economy.start();f.Shop.start();f.Records.startQuery();f.drain()end
 function f.invoke(name,action,...)f.now+=2;return f.remotes[name].OnServerInvoke(p,action,...)end
 function f.runRound(finish)
  f.race();local session={trackId='Track02',targetLaps=2,orderedParticipants=function()return {p}end}
  local identity={RoundGuid=guid(1000+f.serial),IssuedAt=1791650000000};f.serial+=1;p:SetAttribute('OfficialRoundGuid',identity.RoundGuid);p:SetAttribute('OfficialRoundIssuedAt',identity.IssuedAt)
  f.Records.begin(session,{CenterlineLength=1000},6,identity);f.Records.start(p,0)
  for lap=1,2 do
   for i=0,100 do
    local fraction=(i/100)%1;local pos=rb.Vector3.new(math.cos(fraction*2*math.pi)*1000/(2*math.pi),0,math.sin(fraction*2*math.pi)*1000/(2*math.pi))
    f.Records.progress(p,(lap-1)*20+i*.2,pos,fraction,math.min(7,math.floor(i/14)+1))
   end
   f.Records.lap(p,lap*20,20)
  end
  if finish~=false then
   p.attrs.RaceState='FINISHED';f.Records.finish(p,{totalTime=40,position=1,humanPosition=1,positionFinalized=true})
  end
 end
 function f.account()return backend.values[S.userKey(p.UserId)]end
 return f
end
local f=fixture();f.start()
check(f.account()==nil and f.player.attrs.KDMWalletCash==0 and f.player.attrs.KDMEconomyState=='GUEST','join/read alone cannot mint starter cash')
local qualification=f.Economy.qualifyActivity(f.player,'TEST_DRIVE',{complete=true,movingMilliseconds=30000,distance=300})
check(qualification.status=='FOUND','server activity creates qualified account')
print('R3_TRACE fresh',f.account()~=nil,f.player.attrs.KDMEconomyState,f.player.attrs.KDMWalletCash)
check(f.account().wallet.cash==5000 and f.player.attrs.KDMWalletCash==5000,'new general account confirmed starter cash')
check(f.indexCalls==0 and f.market==0,'no public index or payment lookup')
local old=schema.default(2);old.wallet.cash=805;old.wallet.lifetimeEarned=900;old.wallet.ledgerRevision=9;old.selection.kartId='Kart09'
old.cosmetics.ownedPartIds.KDM_V2_WING=true;old.cosmetics.equippedPartIdsBySlot.Wing='KDM_V2_WING'
old.shopInventory={revision=1,counts={Nitro=2,Smoke=1},autoRefill=true};old.purchaseHistory={legacy={kept=true}}
check(schema.validate(old,S.userKey(2)),select(2,schema.validate(old,S.userKey(2))))
local original=S.canonical(old)
f=fixture(2,{values={['u:2']=S.clone(old)},reads=0,writes=0,budget=100});f.start()
check(S.canonical(f.account())==original and f.backend.writes==0,'mock existing K$805 and all ownership preserved without writes')
check(f.player.attrs.KDMWalletCash==805 and f.player.attrs.KDMOwnedKart05 and f.player.attrs.KDMOwnedKart11,'server-confirmed Garage attrs')
for _,action in {'BUY_WING','PASS'}do local before=f.backend.writes;check(f.invoke('KDMEconomy',action).status=='UNAVAILABLE' and f.backend.writes==before,'legacy public purchase blocked '..action)end
for _,action in {'BUY_WING','BUY_ITEM','SET_AUTO_REFILL','EQUIP_WING'}do
 local before=f.backend.writes;check(f.invoke('KDMShop',action,'Nitro',guid(88),true).status=='ACCESS_BLOCKED' and f.backend.writes==before,'shop mutation blocked '..action)
end
check(f.invoke('KDMShop','PROFILE').canPurchase==false and f.market==0,'public exhibition read cannot enable sale')
f.runRound();f.drain()
check(f.account().wallet.cash==8305 and f.player.attrs.KDMWalletCash==8305 and f.player.attrs.RaceMoneyState=='SAVE_CONFIRMED','actual official normal finish earns existing solo+PB 2500')
local writes=f.backend.writes;f.Records.finish(f.player,{totalTime=40,position=1,humanPosition=1,positionFinalized=true});f.drain()
check(f.account().wallet.cash==8305 and f.backend.writes==writes,'collector duplicate finish rejected')
check(f.account().selection.kartId=='Kart09' and f.account().shopInventory.counts.Nitro==2 and f.account().cosmetics.ownedPartIds.KDM_V2_WING,'reward preserves kart Wing stock')
check(f.indexCalls==0 and f.market==0,'general rewards do not enable index/payment')
local rejoined=fixture(2,f.backend);rejoined.start();check(rejoined.player.attrs.KDMWalletCash==8305,'new server reconnect reads accumulated balance')
f=fixture();f.start();f.qualify();f.runRound(false);f.player.attrs.RaceState='DNF';f.Records.finish(f.player);f.drain()
print('R3_TRACE fresh',f.account()~=nil,f.player.attrs.KDMEconomyState,f.player.attrs.KDMWalletCash)
check(f.account().wallet.cash==5000 and f.player.attrs.RaceMoneyState=='NONE','DNF/leave earns no reward')
f=fixture();f.race();f.runRound();f.drain()
check(f.account().wallet.cash==12500 and f.player.attrs.RaceMoneyState=='SAVE_CONFIRMED','first finish initializes absent reserved account safely')
f=fixture();f.race();f.backend.concurrent=function(b,key)b.values[key]=S.clone(old)end
f.runRound();f.drain();check(f.account().wallet.cash==8305 and f.account().shopInventory.counts.Nitro==2,'concurrent initialization never overwrites existing K$805')
f=fixture();f.backend.readFail=true;f.start()
check(not f.account() and f.backend.writes==0 and f.player.attrs.KDMWalletCash==nil,'failed initial read never fabricates zero or overwrites')
f.runRound();f.drain();check(f.backend.writes==0 and f.player.attrs.RaceMoneyState=='SAVE_PENDING','failed reward read no false credit')
f=fixture();f.start();f.qualify();f.backend.writeFail=true;f.runRound();f.drain()
print('R3_TRACE fresh',f.account()~=nil,f.player.attrs.KDMEconomyState,f.player.attrs.KDMWalletCash)
check(f.account().wallet.cash==5000 and f.player.attrs.RaceMoneyState=='SAVE_PENDING' and f.player.attrs.KDMWalletCash==5000,'all write attempts fail closed')
f=fixture();f.race();f.backend.writeFail=true;f.runRound();f.step();check(f.player.attrs.RaceMoneyState=='SAVE_PENDING','unknown absent initialization retries')
f.backend.writeFail=false;f.drain();check(f.account().wallet.cash==12500,'initialization write retry recovers')
f=fixture();f.start();f.qualify();f.backend.ackLost=true;f.runRound();f.drain()
check(f.account().wallet.cash==12500 and f.player.attrs.RaceMoneyState=='SAVE_CONFIRMED','ACK loss reconciles by durable receipt')
f=fixture();f.start();f.qualify();f.backend.writes=0;f.backend.failReadAfterWrite=true;f.runRound();f.step()
check(f.account().wallet.cash==12500 and f.player.attrs.KDMWalletCash==5000 and f.player.attrs.RaceMoneyState=='SAVE_PENDING','unconfirmed write stays hidden')
f.backend.failReadAfterWrite=false;f.drain();check(f.account().wallet.cash==12500 and f.player.attrs.KDMWalletCash==12500,'read retry confirms exactly once')
for _,bad in {'future','corrupt','deleted'}do
 local profile=S.clone(old);if bad=='future'then profile.schemaVersion=999 elseif bad=='corrupt'then profile.wallet.cash=-1 else profile.deleted=true end
 f=fixture(2,{values={['u:2']=profile},reads=0,writes=0,budget=100});local before=S.canonical(profile);f.start();f.runRound();f.drain()
 check(f.backend.writes==0 and S.canonical(f.account())==before and f.player.attrs.KDMWalletCash==nil,'readonly profile never overwritten '..bad)
end
f=fixture();f.backend.budget=0;f.start();f.runRound();f.drain()
check(f.stores==0 and f.backend.writes==0 and not f.account(),'zero budget no store lookup/default')
f=fixture(11700555357);f.start();f.qualify();check(f.Economy.allowed(f.player,'shop') and f.invoke('KDMShop','PROFILE').canPurchase,'existing canary policy retained')
f.race();check(f.Economy.allowed(f.player,'voucher'),'canary voucher unchanged')
f=fixture();f.studio=true;f.start();f.runRound();f.drain()
check(f.lookups==0 and f.backend.writes==0,'real Studio policy always denies live datastore, even public candidate')
-- Two independent server runtimes share the same fake atomic backend and immutable round receipt.
f=fixture();f.start();f.qualify();local other=fixture(2,f.backend);other.start();f.race();other.race()
local round=S.freezeRound({RoundGuid=guid(99),TrackId='Track02',GeometryId='PrototypeCircuitV2B',RulesetId='KDM_R8A3_RULES_V1',diagnostic=false,roster={{IsBot=false,UserId=2}}})
local op={kind='OFFICIAL_RECORD',userId=2,round=round,bestLapMilliseconds=20000,bestRaceBoosts=0,achievedAt=1791650000000,
 verification={state='FINISHED',serverAccepted=true,targetLaps=2,completedLaps=2,fullLapValid=true,provenance='FULL_ROUTE_V1',boostIdentity='SERVER_SERIAL_V1'},economy={version=1,humanPosition=1},
 race={trackId=round.TrackId,geometryId=round.GeometryId,rulesetId=round.RulesetId,category=round.RaceCategory,recordScope=round.recordScope,
 targetLaps=2,roundGuid=round.RoundGuid,userId=2,totalMilliseconds=40000,laps={20000,20000},finishPosition=1,startingHumans=1,startingBots=0,
 raceBoosts=0,finishedAt=1791650000000,eligible=true,reason='FULL_ROUTE_V1',serverAccepted=true,state='FINISHED',positionFinalized=true}}
local function runtime(server)
 local deps={allowed=function(_,kind)return kind~='repair' and server.Economy.allowed(server.player,if kind=='write'then 'reward'else 'read')end,
  adapter=function()return server.Economy.accountAdapter(server.player,'reward')end,profileConfirmed=server.Economy.publishProfile,
  ensureProfile=server.Economy.getProfile,retryAttempts=3,shutdownSeconds=20,clock=function()return server.now end,
  spawn=function(fn)table.insert(server.queue,{at=server.now,fn=fn})end,delay=function(t,fn)table.insert(server.queue,{at=server.now+t,fn=fn})end,
  wait=function(t)server.now+=t;server.step(server.now)end,index=function()error('no public index')end}
 return server.Runtime.new(S,schema,server.Ops,deps)
end
local a,b=runtime(f),runtime(other);f.player.attrs.OfficialRoundGuid=guid(99);other.player.attrs.OfficialRoundGuid=guid(99)
check(a.submit(f.player,op) and b.submit(other.player,op),'independent servers accept same immutable envelope')
f.drain();other.drain();check(f.account().wallet.cash==12500 and f.backend.writes==2,'cross-server replay reads receipt, one reward plus one init')
local different=S.clone(op);different.bestRaceBoosts=1;check(not b.submit(other.player,different),'same round changed payload rejected')
local stale=S.clone(f.account());stale.wallet.cash=0;stale.wallet.ledgerRevision=0;f.Economy.publishProfile(f.player,stale)
check(f.player.attrs.KDMWalletCash==12500,'stale result cannot regress confirmed wallet')
local op2=S.clone(op);op2.round.RoundGuid=guid(100);op2.race.roundGuid=guid(100);op2.achievedAt+=1;op2.race.finishedAt+=1
f.player.attrs.OfficialRoundGuid=guid(100);f.backend.writeFail=true;a.submit(f.player,op2);f.step();f.backend.writeFail=false
a.shutdown();check(f.account().wallet.cash==13500 and f.player.attrs.RaceMoneyState=='SAVE_CONFIRMED','graceful shutdown drains accepted retry')
check(not a.submit(f.player,op),'shutdown refuses new submissions')
local disconnected=fixture(2,f.backend);disconnected.start();check(disconnected.player.attrs.KDMWalletCash==13500,'shutdown then reconnect preserved')
local closeJoin=fixture();closeJoin.Economy.start();closeJoin.close[1]()
check(closeJoin.account()==nil and closeJoin.invoke('KDMEconomy','PROFILE').status=='CLOSING','graceful close drains scheduled new account and refuses new remote')
print('PASS: '..checks..' R8-A6 public policy, actual account/official race/Shop facades, outages, reconnect and independent-server atomic mock checks; live DataStore calls ZERO')
