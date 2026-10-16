-- All monetary/purchase reducers below are test fixtures, never runtime implementation.
local fs, luau, serde, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/serde"), require("@lune/roblox")
local paths = {"src/shared/KDMProgressionSchema.luau","src/server/ProgressionMockStore.luau",
 "src/server/ProgressionOperations.luau","src/server/ProgressionMockJournal.luau"}
local serviceCalls = 0
local trap = setmetatable({}, {__index=function() serviceCalls += 1; error("service access forbidden") end})
local modules = {}
for _, path in paths do
 modules[path] = luau.load(fs.readFile(path),{environment={game=trap,Instance=trap,task=trap,require=function() error("runtime dependency forbidden") end}})()
end
local S, Store, Ops, Journal = modules[paths[1]],modules[paths[2]],modules[paths[3]],modules[paths[4]]
local catalog = luau.load(fs.readFile("src/shared/KartCatalog.luau"),{environment={Color3=rb.Color3,Enum=rb.Enum}})()
local schema = S.new(catalog)
local key, userId = S.userKey(47), 47
local checks, rows = 0, {}
local function check(value,label) checks += 1; assert(value,label) end
local function same(a,b,label) check(S.canonical(a)==S.canonical(b),label) end
local function case(id,label,fn)
 local before = checks
 local ok, err = pcall(fn)
 table.insert(rows,{id=id,label=label,status=if ok then "PASS" else "FAIL",checks=checks-before,error=if ok then nil else tostring(err)})
 print(id .. " " .. (if ok then "PASS " else "FAIL ") .. label)
 if not ok then print(err) end
end
local function fixture(initial, contract)
 return Store.new(S,contract or schema,{[key]=initial or schema.default(userId)})
end
local function selectOp(id,revision,kart)
 return {kind="SELECT_KART",operationId=id,expectedSelectionRevision=revision,kartId=kart}
end
local function selectReducer(op,contract) return Ops.selection(S,contract or schema,userId,op) end
local guid1, guid2 = "10000000-0000-4000-8000-000000000001","10000000-0000-4000-8000-000000000002"
local function event(guid,time,kind)
 return {RoundGuid=guid,UserId=userId,rewardKind=kind or "MOCK_FINISH",confirmedAtUtcMs=time,amount=40}
end
-- Model atomic mock-only credit/receipt and fixed UTC claim using trusted fixture envelopes.
local function creditConsumer(store,contract,firstDaily)
 return function(e,id,signature)
  return store.update(key,function(previous)
   local valid = contract.validate(previous,key)
   if not valid or previous.deleted then return nil,"READ_ONLY" end
   local receipt = previous.receipts[id]
   if receipt then
    if receipt.signature ~= signature then return nil,"IDENTITY_MISMATCH" end
    return S.clone(previous),"REPLAY"
   end
   if S.count(previous.receipts) >= contract.maxReceipts then return nil,"RECEIPT_CAPACITY" end
   if not S.integer(e.amount,contract.maxCash) then return nil,"INVALID_AMOUNT" end
   local p = S.clone(previous)
   local amount = e.amount
   if firstDaily then
    local day = S.utcDay(e.confirmedAtUtcMs)
    if not p.daily.claimBuckets[day] then
     if S.count(p.daily.claimBuckets) >= 8 then return nil,"DAILY_CAPACITY" end
     p.daily.claimBuckets[day] = {}
    end
    if p.daily.claimBuckets[day].first then amount=0 else p.daily.claimBuckets[day].first=true end
   end
   if p.wallet.cash+amount > contract.maxCash then return nil,"WALLET_CAPACITY" end
   p.wallet.cash += amount; p.wallet.ledgerRevision += 1
   p.receipts[id]={signature=signature}
   return p,"APPLIED"
  end)
 end
end

case("S01","ABSENT creates only an unsaved new profile",function()
 local store=Store.new(S,schema)
 local loaded=Ops.load(S,schema,store.read(key),userId)
 check(loaded.state=="NEW" and not loaded.saved,"absent only")
 check(loaded.profile.selection.kartId=="Kart05" and loaded.profile.wallet.cash==5000,"catalog default")
 check(store.stats().commits==0 and serviceCalls==0,"no default write or service calls")
end)
case("S02","ERROR never becomes ABSENT/default save",function()
 local store=Store.new(S,schema); store.inject({readFail=true})
 local loaded=Ops.load(S,schema,store.read(key),userId)
 check(loaded.state=="UNAVAILABLE" and loaded.profile==nil,"unavailable")
 check(store.stats().commits==0 and next(store.snapshot())==nil,"unchanged")
end)
case("S03","Existing wallet and selection faithfully decoded",function()
 local p=schema.default(userId); p.wallet.cash=137; p.selection.kartId="Kart11"
 local store=fixture(p); local loaded=Ops.load(S,schema,store.read(key),userId)
 check(loaded.state=="READY" and loaded.saved,"loaded")
 same(p,loaded.profile,"no reset")
 loaded.profile.wallet.cash=0; check(store.read(key).value.wallet.cash==137,"copy isolation")
end)
case("S04","Future schema quarantined unchanged",function()
 local p=schema.default(userId); p.schemaVersion=99
 local store=fixture(p); local before=store.snapshot()
 check(Ops.load(S,schema,store.read(key),userId).state=="READ_ONLY","future readonly")
 check(store.update(key,selectReducer(selectOp("future",0,"Kart01"))).status=="READ_ONLY","no reducer migration")
 same(before,store.snapshot(),"future preserved")
end)
case("S05","Corrupt profile, wrong key, invalid kart fail closed",function()
 for _, variant in {"key","kart","wallet","type"} do
  local p=schema.default(userId)
  if variant=="key" then p.userId=48 elseif variant=="kart" then p.selection.kartId="Unknown"
  elseif variant=="wallet" then p.wallet.cash="bad" else p="broken" end
  local store=fixture(p); local before=store.snapshot()
  check(Ops.load(S,schema,store.read(key),userId).state=="READ_ONLY","corruption readonly "..variant)
  check(store.update(key,selectReducer(selectOp("bad",0,"Kart01"))).status=="READ_ONLY","rejected "..variant)
  same(before,store.snapshot(),"no rewrite "..variant)
 end
 local cyc={};cyc.self=cyc
 check(not schema.validate(cyc,key),"cycle rejected before clone")
 check(not schema.validate({schemaVersion=1/0},key),"nonfinite rejected")
end)
case("S06","SELECT_KART CAS and immutable operation",function()
 local store=fixture(); local op=selectOp("cas",0,"Kart02"); local reducer=selectReducer(op)
 op.kartId="Kart03"
 local result=store.update(key,reducer)
 check(result.status=="SAVED" and result.value.selection.kartId=="Kart02","copied authorized op")
 check(result.value.selection.revision==1 and result.value.selection.lastOpId=="cas","revision")
 check(store.update(key,selectReducer(selectOp("stale",0,"Kart01"))).status=="CONFLICT","CAS reject")
end)
case("S07","Stale session cannot revert newer explicit selection",function()
 local p=schema.default(userId); p.wallet.cash=91
 local store=fixture(p); local stale=selectReducer(selectOp("old",0,"Kart01"))
 check(store.update(key,selectReducer(selectOp("new1",0,"Kart02"))).status=="SAVED","first choice")
 check(store.update(key,selectReducer(selectOp("new2",1,"Kart03"))).status=="SAVED","later choice")
 check(store.update(key,stale).status=="CONFLICT","stale rejected")
 check(store.read(key).value.selection.kartId=="Kart03" and store.read(key).value.wallet.cash==91,"new choice/wallet preserved")
end)
case("S08","Reexecution is pure; mutation/yield/nondeterminism rejected",function()
 local store=fixture(); store.inject({callbackReplay=true})
 check(store.update(key,selectReducer(selectOp("reexec",0,"Kart04"))).status=="SAVED","replay commits")
 check(store.stats().callbacks==2 and store.stats().commits==1,"two evaluations one effect")
 store.inject({})
 check(store.update(key,function(p) p.wallet.cash=999; return p end).status=="CALLBACK_ERROR","frozen old input")
 check(store.update(key,function() coroutine.yield(); return schema.default(userId) end).status=="CALLBACK_YIELDED","yield rejected")
 store.inject({callbackReplay=true}); local counter=0
 check(store.update(key,function(p) counter+=1; local n=S.clone(p);n.wallet.cash=counter;return n,"APPLIED" end).status=="NONDETERMINISTIC_CALLBACK","nondeterminism rejected")
 check(store.stats().commits==1,"unsafe callbacks no commits")
end)
case("S09","Same operation receipt replay and changed payload rejection",function()
 local smallSchema=S.new(catalog,{maxReceipts=999})
 local store=fixture(nil,smallSchema); local op=selectOp("once",0,"Kart01")
 store.update(key,selectReducer(op,smallSchema));store.update(key,selectReducer(selectOp("next",1,"Kart02"),smallSchema))
 local result=store.update(key,selectReducer(op,smallSchema))
 check(result.status=="SAVED" and result.outcome=="REPLAY","replay receipt")
 check(result.value.selection.kartId=="Kart02" and store.stats().commits==2,"old replay no revert")
 check(store.update(key,selectReducer(selectOp("once",0,"Kart03"),smallSchema)).status=="IDENTITY_MISMATCH","different payload denied")
end)
case("S10","ACK loss read-back resolves same operation without blind new ID",function()
 local store=fixture();local op=selectOp("ack",0,"Kart11");store.inject({ackLoss=true})
 check(store.update(key,selectReducer(op)).status=="PENDING","ACK ambiguous")
 check(store.stats().commits==1,"commit actually happened")
 store.inject({readFail=true})
 check(Ops.resolveSelection(S,schema,store.read(key),userId,op).state=="PENDING","failed read no saved claim")
 store.inject({})
 check(Ops.resolveSelection(S,schema,store.read(key),userId,op).state=="SAVED","receipt verified")
 store.update(key,selectReducer(op));check(store.stats().commits==1,"no second effect")
end)
case("S11","Two writers preserve distinct fields under optimistic conflict",function()
 local store=fixture()
 local selection=store.beginUpdate(key,selectReducer(selectOp("serverA",0,"Kart02")))
 local credit=store.beginUpdate(key,function(p) local n=S.clone(p); n.wallet.cash+=7;n.wallet.ledgerRevision+=1;return n,"APPLIED" end)
 check(store.commit(selection).status=="SAVED" and store.commit(credit).status=="SAVED","both writes")
 local p=store.read(key).value
 check(p.selection.kartId=="Kart02" and p.wallet.cash==5007,"fresh rerun merges fields")
 check(store.stats().conflicts==1,"real conflict injected")
 check(store.update(key,selectReducer({kind="CREDIT_FINISH"})).status=="FUTURE_OPERATION_DISABLED","runtime economy handler absent")
end)
case("S12","Competing selection CAS rejects stale writer",function()
 local store=fixture()
 local a=store.beginUpdate(key,selectReducer(selectOp("A",0,"Kart01")))
 local b=store.beginUpdate(key,selectReducer(selectOp("B",0,"Kart02")))
 check(store.commit(b).status=="SAVED","authorized commit B")
 check(store.commit(a).status=="CONFLICT","A stale")
 check(store.read(key).value.selection.kartId=="Kart02" and store.stats().commits==1,"one authorized CAS")
end)
case("S13","Failures, capacity, delayed reads/ACKs stay pending",function()
 for _,fault in {{writeFail=true},{noResponse=true},{capacityFull=true}} do
  local store=fixture(); local before=store.snapshot();store.inject(fault)
  local result=store.update(key,selectReducer(selectOp("fail",0,"Kart01")))
  check(result.status=="PENDING" or result.status=="READ_ONLY","never saved")
  same(before,store.snapshot(),"no commit")
 end
 local store=fixture();store.inject({delayRead=true});local slow=store.read(key)
 check(slow.status=="PENDING","read actually deferred")
 store.inject({delayAck=true});local op=selectOp("delay",0,"Kart02")
 local result=store.update(key,selectReducer(op));check(result.status=="PENDING","ACK deferred")
 local old=store.finishRead(slow.ticket)
 check(Ops.resolveSelection(S,schema,old,userId,op).state=="PENDING","old response not proof of saved choice")
 check(store.finishRead(result.ticket).status=="SAVED","release actual ACK")
 store.inject({});check(store.read(key).value.selection.kartId=="Kart02","late old snapshot not committed")
end)
case("S14","Crash before append unguaranteed; after append image replayable",function()
 local journal=Journal.new(S);journal.inject({beforeAppend=true})
 check(journal.append(event(guid1,1)).status=="UNGUARANTEED","explicit loss before append")
 check(next(journal.snapshot().events)==nil,"no fabricated recovery")
 journal.inject({afterAppend=true});local result=journal.append(event(guid1,1))
 check(result.status=="PENDING" and result.id~=nil,"appended without ACK")
 local restarted=Journal.new(S,journal.snapshot());local store=fixture()
 check(restarted.deliver(result.id,2,creditConsumer(store,schema)).status=="DELIVERED","retained image replays")
 check(store.read(key).value.wallet.cash==5040,"one simulated credit")
end)
case("S15","Duplicate reward receipt, delivery ACK loss, overflow fail closed",function()
 local small=S.new(catalog,{maxReceipts=1});local store=fixture(nil,small)
 local journal=Journal.new(S);local result=journal.append(event(guid1,1));journal.inject({deliveryAckLoss=true})
 check(journal.deliver(result.id,2,creditConsumer(store,small)).status=="PENDING","journal ACK lost after profile commit")
 check(store.read(key).value.wallet.cash==5040,"first credit")
 journal.inject({});check(journal.deliver(result.id,3,creditConsumer(store,small)).status=="DELIVERED","same receipt replay")
 check(store.read(key).value.wallet.cash==5040 and store.stats().commits==1,"no duplicate")
 local second=journal.append(event(guid2,3));check(journal.deliver(second.id,4,creditConsumer(store,small)).status=="RECEIPT_CAPACITY","overflow blocked")
 check(store.read(key).value.wallet.cash==5040,"overflow neither credited nor evicted")
 local changed=event(guid1,1);changed.amount=999
 check(journal.append(changed).status=="IDENTITY_MISMATCH","altered event denied")
end)
case("S16","UTC fixed event day, eight out-of-order buckets, no double daily claim",function()
 local journal=Journal.new(S);local store=fixture();local lastDay=20000*86400000
 for offset=0,7 do
  local withinDay=if offset==0 then 1 else 86400000-100
  local e=event(string.format("20000000-0000-4000-8000-%012d",offset+1),lastDay-offset*86400000+withinDay)
  local result=journal.append(e)
  check(journal.deliver(result.id,lastDay+100,creditConsumer(store,schema,true)).status=="DELIVERED","old day still recognized")
 end
 check(S.count(store.read(key).value.daily.claimBuckets)==8 and store.read(key).value.wallet.cash==5320,"8 dates retained")
 local midnight=event(guid1,lastDay-1);local r=journal.append(midnight)
 check(journal.deliver(r.id,lastDay+101,creditConsumer(store,schema,true)).status=="DELIVERED","midnight retry original date")
 check(store.read(key).value.wallet.cash==5320,"same day claimed only once")
 local ninth=event(guid2,lastDay-8*86400000+1);r=journal.append(ninth)
 check(journal.deliver(r.id,lastDay+102,creditConsumer(store,schema,true)).status=="BLOCKED","outside replay window no prune/credit")
end)
case("S17","Expired/evicted receipt replay never silently credits",function()
 local journal=Journal.new(S);local store=fixture();local r=journal.append(event(guid1,1))
 journal.deliver(r.id,2,creditConsumer(store,schema))
 local image=store.snapshot();image[key].receipts={};local evicted=Store.new(S,schema,image)
 check(journal.deliver(r.id,3,creditConsumer(evicted,schema)).status=="DELIVERED","canonical delivered suppression")
 check(evicted.read(key).value.wallet.cash==5040 and evicted.stats().commits==0,"no duplicate after receipt eviction")
 local pending=Journal.new(S);r=pending.append(event(guid2,1))
 check(pending.deliver(r.id,8*86400000,creditConsumer(evicted,schema)).status=="BLOCKED","expiration not reissued")
 check(Journal.new(S).deliver(r.id,2,creditConsumer(evicted,schema)).status=="BLOCKED","missing canonical history blocked")
 -- If BOTH canonical history and receipts are erased then provenance is gone: no supported prune API.
 local lost=Journal.new(S,nil,{recovery=true})
 check(lost.append(event(guid1,1)).status=="BLOCKED","missing history cannot re-register old entitlement")
 check(lost.deliver(r.id,2,creditConsumer(evicted,schema)).status=="BLOCKED","joint erasure recovery blocked")
 check(evicted.read(key).value.wallet.cash==5040,"no silent credit through unknown history")
end)
case("S18","Deletion tombstone denies pending replay after restart",function()
 local journal=Journal.new(S);local r=journal.append(event(guid1,1));journal.deleteUser(userId)
 local restored=Journal.new(S,journal.snapshot());local store=fixture()
 check(restored.deliver(r.id,2,creditConsumer(store,schema)).status=="DELETED","pending denied")
 check(restored.append(event(guid2,1)).status=="DELETED","reappend denied")
 check(store.read(key).value.wallet.cash==5000,"no credit")
 local p=schema.default(userId);p.deleted=true;store=fixture(p)
 check(store.update(key,selectReducer(selectOp("deleted",0,"Kart02"))).status=="DELETED","profile tombstone readonly")
 check(Ops.load(S,schema,store.read(key),userId).state=="DELETED","not new user")
end)
case("S19","Bounds and corrupt/unowned inventory rejected without rewrite",function()
 for _,amount in {-1,0/0,1/0,2147483648} do
  local p=schema.default(userId);p.wallet.cash=amount
  check(not schema.validate(p,key),"invalid cash bound")
 end
 local p=schema.default(userId);p.cosmetics.equippedPartIdsBySlot.wheel="unowned"
 check(not schema.validate(p,key),"unowned equip rejected")
 p.cosmetics.ownedPartIds.unowned=true;check(schema.validate(p,key),"owned structural entitlement")
 p.cosmetics.ownedPartIds.unowned="client_claim";check(not schema.validate(p,key),"non-authoritative shape rejected")
 local store=fixture();local before=store.snapshot()
 check(store.update(key,function(old)local n=S.clone(old);n.wallet.cash=-1;return n,"APPLIED" end).status=="READ_ONLY","invalid write")
 same(before,store.snapshot(),"rejected next value unchanged")
 local tiny=Store.new(S,schema,{[key]=schema.default(userId)},{maxBytes=10})
 check(tiny.update(key,selectReducer(selectOp("bytes",0,"Kart02"))).status=="READ_ONLY","actual byte budget exhausted")
 check(tiny.stats().commits==0,"capacity never partially commits")
 local oversized=schema.default(userId);oversized.unknown=string.rep("\0",math.floor(schema.maxBytes/6)+1)
 check(not schema.validate(oversized,key),"JSON escaping reserve bounded")
end)
case("S20","Hypothetical purchase atomic race; fixture only",function()
 local p=schema.default(userId);p.wallet.cash=50;local store=fixture(p)
 local fixtureCatalog={a={slot="wheel",price=40,revision=1,family="KDMV2"},b={slot="wheel",price=40,revision=1,family="KDMV2"}}
 local function purchase(part,id,claimedRevision)
  return function(old)
   local item=fixtureCatalog[part]
   if not item or item.revision~=claimedRevision then return nil,"PRICE_VERSION_MISMATCH" end
   local sig=S.canonical({part=part,id=id,revision=claimedRevision})
   if old.receipts[id] then return if old.receipts[id].signature==sig then S.clone(old) else nil,"REPLAY" end
   if old.cosmetics.ownedPartIds[part] then return nil,"ALREADY_OWNED" end
   if old.wallet.cash<item.price then return nil,"INSUFFICIENT" end
   local n=S.clone(old);n.wallet.cash-=item.price;n.wallet.ledgerRevision+=1
   n.cosmetics.ownedPartIds[part]=true;n.receipts[id]={signature=sig};return n,"APPLIED"
  end
 end
 local a=store.beginUpdate(key,purchase("a","buyA",1));local b=store.beginUpdate(key,purchase("b","buyB",1))
 check(store.commit(a).status=="SAVED" and store.commit(b).status=="INSUFFICIENT","one affordable debit/grant")
 check(store.read(key).value.wallet.cash==10 and store.read(key).value.cosmetics.ownedPartIds.a==true
  and store.read(key).value.cosmetics.ownedPartIds.b==nil,"atomic ownership")
 store.update(key,purchase("a","buyA",1));check(store.stats().commits==1,"purchase receipt no second debit")
 check(store.update(key,purchase("b","price",2)).status=="PRICE_VERSION_MISMATCH","server price revision")
 local fail=fixture(p);fail.inject({writeFail=true});check(fail.update(key,purchase("a","fail",1)).status=="PENDING","fault path")
 same(fail.read(key).value,p,"failure neither charged nor granted")
 check(Ops.FutureContracts.PURCHASE_COSMETIC~=nil,"future spec only")
end)
local function round(roster,geometry,diagnostic)
 return S.freezeRound({RoundGuid=guid1,TrackId="Track02",GeometryId=geometry or "PrototypeCircuitV2B",
  RulesetId="RACE_RULESET_V1_ITEMS_ON",roster=roster,diagnostic=diagnostic or false})
end
local function humans(n)
 local roster={};for i=1,n do table.insert(roster,{UserId=i,IsBot=false}) end;return roster
end
case("S21","Frozen SOLO/BOT/HUMAN_2/3/4 categories distinct",function()
 local categories={}
 for n=1,4 do
  local r=round(humans(n));categories[r.RaceCategory]=true
  check(r.RaceCategory==(if n==1 then "SOLO_1H_0B" else "HUMAN_"..n.."H_0B"),"actual starter cardinality")
 end
 local r=round({{UserId=1,IsBot=false},{IsBot=true,BotId="bot1"}})
 check(r.RaceCategory=="BOT_1H_1B" and r.humanCount==1 and r.botCount==1,"special bot category")
 r=round({{UserId=1,IsBot=false},{UserId=2,IsBot=false},{IsBot=true,BotId="bot1"}})
 check(r.RaceCategory=="BOT_ASSISTED_2H_1B","human count preserved")
 check(S.count(categories)==4,"no merged categories")
 check(S.classify({{UserId=1}})=="UNCLASSIFIED","missing server bot identity")
 check(S.classify({{UserId=1,IsBot=false},{UserId=1,IsBot=false}})=="UNCLASSIFIED","duplicate human rejected")
 local fields={}; fields[2]={UserId=1,IsBot=false};check(S.classify(fields)=="UNCLASSIFIED","sparse roster rejected")
 local malformed={RoundGuid=guid1,diagnostic=false,roster=humans(2)};malformed.self=malformed
 check(not pcall(S.freezeRound,malformed),"cyclic round fails closed")
end)
case("S22","4H category immutable after departures",function()
 local input=humans(4);local r=round(input)
 table.remove(input,4);same(#input,3,"live input changed")
 check(r.humanCount==4 and #r.roster==4 and r.RaceCategory=="HUMAN_4H_0B","snapshot independent")
 check(not pcall(function()r.roster[4]=nil end),"nested roster frozen")
 check(not pcall(function()r.RaceCategory="HUMAN_3H_0B" end),"category frozen")
end)
case("S23","V2 vs V2B separate canonical scopes and global round IDs",function()
 local legacy=round(humans(2),"PrototypeCircuitV2");local beta=round(humans(2),"PrototypeCircuitV2B")
 check(legacy.recordScope~=beta.recordScope,"geometry independent")
 check(S.recordScope("a|b","c","d","e")~=S.recordScope("a","b|c","d","e"),"length framing unambiguous")
 check(S.eventId(guid1,userId,"FINISH")~=S.eventId(guid2,userId,"FINISH"),"new round distinct")
 check(S.eventId(guid1:upper(),userId,"FINISH")==S.eventId(guid1,userId,"FINISH"),"guid casing canonical")
 for _,bad in {"1","JobId:1","RaceSession:1"} do check(not pcall(S.eventId,bad,userId,"FINISH"),"no local-only ID") end
end)
case("S24","Diagnostic, Bot and invalid results no official global rank",function()
 local finish={serverAccepted=true,state="FINISHED",fullLapValid=true}
 check(not S.globalCandidate(round(humans(2),nil,true),1,finish),"diagnostic excluded")
 local botRound=round({{UserId=1,IsBot=false},{IsBot=true,BotId="bot1"}})
 check(not S.globalCandidate(botRound,1,finish) and not S.officialCandidate(botRound,-1,finish),"bot category separated and bot excluded")
 local humanRound=round(humans(2));check(S.globalCandidate(humanRound,1,finish),"human candidate only")
 for _,bad in {{serverAccepted=true,state="DNF",fullLapValid=true},{serverAccepted=true,state="FINISHING",fullLapValid=true},
  {serverAccepted=true,state="FINISHED",fullLapValid=false},{serverAccepted=false,state="FINISHED",fullLapValid=true}} do
  check(not S.globalCandidate(humanRound,1,bad),"unofficial result excluded")
 end
 check(not S.globalCandidate(humanRound,99,finish),"nonstarter excluded")
 check(not S.globalCandidate(S.clone(humanRound),1,finish),"unfrozen round excluded")
 check(not S.globalCandidate(nil,1,finish),"unknown round safely excluded")
end)
case("S25","Mock runtime has zero service/network and no production mock imports",function()
 for _,path in paths do
  local source=fs.readFile(path)
  for _,forbidden in {"DataStoreService","GetDataStore","GetAsync","UpdateAsync","OrderedDataStore","RequestAsync","GetService","Instance.new","task.spawn"} do
   check(not source:find(forbidden,1,true),path.." excludes "..forbidden)
  end
 end
 local function scan(folder)
  for _,entry in fs.readDir(folder) do
   local p=folder.."/"..entry
   if fs.isDir(p) then scan(p) elseif p:sub(-5)==".luau" and not modules[p] then
    local source=fs.readFile(p)
    for _,newPath in paths do
     local name=newPath:match("([^/]+)%.luau$")
     -- A2/A3/A4 now legitimately reuse the pure schema and operation contracts.
     if name=='ProgressionMockStore' or name=='ProgressionMockJournal' then
      check(not source:find(name,1,true),p.." does not require mock-only module")
     end
    end
   end
  end
 end
 scan("src")
 check(serviceCalls==0,"trap count zero across all executed mock paths")
end)

local passed=0
for _,row in rows do if row.status=="PASS" then passed+=1 end end
fs.writeFile("artifacts/r8-a1/mock-test-results.json",serde.encode("json",{
 rows=rows,passed=passed,total=#rows,checks=checks,serviceCalls=serviceCalls,
 scope="in-memory only; no live progression/purchase/score writes; crash image is simulated",
 blockers={"no real durability adapter","joint receipt and journal erasure cannot recover provenance",
 "privacy pair lookup deferred A6","actual full-lap and boost hooks deferred A3","runtime integration deferred A2"}
},true))
assert(passed==25,"mandatory mock scenarios failed")
print("PASS: "..passed.."/25 mandatory scenarios; "..checks.." checks; service calls "..serviceCalls)
