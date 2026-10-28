local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local function load(path,env)return luau.load(fs.readFile(path),{environment=env or {},debugName=path})()end
local S=load('src/shared/KDMProgressionSchema.luau')
local catalog=load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum})
local schema=S.new(catalog,{jsonEncode=function(v)return serde.encode('json',v)end})
local Records=load('src/server/RaceRecordOperations.luau')
local Economy=load('src/server/EconomyOperations.luau')
local Policy=load('src/server/EconomyPolicy.luau')
local Config=load('src/server/EconomyConfig.luau')
local checks=0
local function check(v,label)checks+=1;assert(v,label)end
local function guid(n)return string.format('12345678-1234-1234-1234-%012d',n)end
check(S.sha256('')=='e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855','SHA256 empty')
check(S.sha256('abc')=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad','SHA256 abc')
local function op(n,humans,bots,rank,ms)
 local roster={};for i=1,humans do table.insert(roster,{IsBot=false,UserId=i})end
 for i=1,bots do table.insert(roster,{IsBot=true,BotId='bot'..i})end
 local round=S.freezeRound({RoundGuid=guid(n),TrackId='Track01Race',GeometryId='PracticeCircuitV1',RulesetId='KDM_R8A3_RULES_V1',diagnostic=false,roster=roster})
 ms=ms or 60000
 return {kind='OFFICIAL_RECORD',round=round,userId=1,bestLapMilliseconds=ms,bestRaceBoosts=2,achievedAt=1791650000000+n,
 verification={serverAccepted=true,state='FINISHED',targetLaps=2,completedLaps=2,fullLapValid=true,provenance='FULL_ROUTE_V1',boostIdentity='SERVER_SERIAL_V1'},
 economy={version=1,humanPosition=rank},race={trackId=round.TrackId,geometryId=round.GeometryId,rulesetId=round.RulesetId,category=round.RaceCategory,
 recordScope=round.recordScope,targetLaps=2,roundGuid=round.RoundGuid,userId=1,totalMilliseconds=ms*2,laps={ms,ms},finishPosition=rank+bots,
 startingHumans=humans,startingBots=bots,raceBoosts=2,finishedAt=1791650000000+n,eligible=true,reason='FULL_ROUTE_V1',serverAccepted=true,state='FINISHED',positionFinalized=true}}
end
local original=schema.default(1);original.onboarding.firstFinishClaimed=true;original.onboarding.finishEvent.claimed=true;original.selection.kartId='Kart09';original.wallet.cash=25000
original.inventory={existing='preserved'};original.purchaseHistory={old={method='LEGACY'}}
original.receipts.legacy={signature='unmodified'};original.cosmetics.ownedPartIds.Wheel=true
for rank,base in {3500,2500,2000,1500} do
 local o=op(rank,4,0,rank);local p=Records.reduce(S,schema,o)(original);local receipt=Records.confirm(S,schema,{status='FOUND',value=p},o)
 check(receipt.money.base==base and receipt.money.total==base+1500,'human rank '..rank)
 check(p.wallet.cash==25000+base+1500 and p.wallet.lifetimeEarned==base+1500,'atomic wallet '..rank)
 local replay,status=Records.reduce(S,schema,o)(p)
 check(status=='REPLAY' and S.canonical(replay)==S.canonical(p),'duplicate RoundGuid '..rank)
end
for _,test in {{1,0,1000},{1,1,1500},{1,3,1500},{2,1,3500},{3,1,3500}} do
 local o=op(10+test[1]+test[2],test[1],test[2],1);local p=Records.reduce(S,schema,o)(original)
 check(p.receipts[Records.receiptKey(o)].money.base==test[3],'roster base '..test[1]..'H '..test[2]..'B')
 check(p.wallet.cash-25000<=5000,'per race cap')
end
local first=op(100,2,1,1);local p=Records.reduce(S,schema,first)(original)
local slow=op(101,2,1,1,65000);p=Records.reduce(S,schema,slow)(p)
check(p.receipts[Records.receiptKey(slow)].money.total==3500,'slow Rematch no PB reward')
local fast=op(102,2,1,1,55000);p=Records.reduce(S,schema,fast)(p)
check(p.wallet.cash==38500 and p.wallet.lifetimeEarned==13500,'repeat credits')
for _,state in {'DNF','FORFEIT','FINISHING'} do local bad=S.clone(first);bad.verification.state=state;check(not Records.valid(S,bad),'terminal reject '..state)end
local invalid=op(103,2,1,1);invalid.race.eligible=false;invalid.race.reason='INVALID_ROUTE_OR_TIMER_RESET'
local before=p.wallet.cash;p=Records.reduce(S,schema,invalid)(p)
-- Owner confirmed2026-10-28: ineligible finish grants no base/PB/event money.
-- Owner explicitly authorized the scoped source gate; historical baseline remains intact.
check(p.wallet.cash==before and p.receipts[Records.receiptKey(invalid)].money.total==0,'owner contract: ineligible finish pays zero')
local bad=S.clone(first);bad.race.positionFinalized=false;check(not Records.valid(S,bad),'provisional forbidden')
bad=S.clone(first);bad.economy.humanPosition=3;check(not Records.valid(S,bad),'rank beyond humans')
bad=S.clone(first);bad.userId=99;check(not Records.valid(S,bad),'bot/nonmember forbidden')
local second=op(104,2,1,1,54000)
local reduced=Records.reduce(S,schema,second)
check(S.canonical(reduced(p))==S.canonical(reduced(p)),'platform callback deterministic')
local nextValue=reduced(p);check(nextValue.wallet.cash==p.wallet.cash+5000,'concurrent update latest profile')
local buy={kind='BUY_WING',id=guid(500),userId=1,itemId='KDM_V2_WING'}
local bought=Economy.reduce(S,schema,buy)(nextValue)
check(bought.wallet.cash==nextValue.wallet.cash-25000 and bought.cosmetics.ownedPartIds.KDM_V2_WING and bought.cosmetics.equippedPartIdsBySlot.Wing=='KDM_V2_WING','debit grant equip atomic')
check(Economy.confirm(S,schema,{status='FOUND',value=bought},buy),'purchase readback')
check(S.canonical(Economy.reduce(S,schema,buy)(bought))==S.canonical(bought),'lost ACK duplicate buy')
local another=S.clone(buy);another.id=guid(501)
check(select(2,Economy.reduce(S,schema,another)(bought))=='ALREADY_OWNED','competing purchase charged once')
check(select(2,Economy.reduce(S,schema,buy)(schema.default(1)))=='INSUFFICIENT_FUNDS','no overdraft')
local eq={kind='EQUIP_WING',id=guid(502),userId=1,itemId='KDM_V2_WING',equipped=false}
local off=Economy.reduce(S,schema,eq)(bought);check(off.cosmetics.equippedPartIdsBySlot.Wing==nil and off.wallet.cash==bought.wallet.cash,'free unequip')
eq.id=guid(503);eq.equipped=true;local on=Economy.reduce(S,schema,eq)(off)
local reconnect=serde.decode('json',serde.encode('json',on));check(schema.validate(reconnect,'u:1') and reconnect.cosmetics.equippedPartIdsBySlot.Wing=='KDM_V2_WING','rejoin restores inventory equip')
for _,field in {'selection','inventory'} do check(S.canonical(on[field])==S.canonical(original[field]),'preserve '..field)end
check(on.receipts.legacy ~= nil and S.signatureMatches(on.receipts.legacy,'unmodified') and on.purchaseHistory.old.method=='LEGACY' and on.cosmetics.ownedPartIds.Wheel,'legacy receipt identity and purchases/cosmetics remain')
local concurrent=Records.reduce(S,schema,op(105,2,1,1,53000))(on)
check(concurrent.cosmetics.ownedPartIds.KDM_V2_WING and concurrent.wallet.cash==on.wallet.cash+5000,'purchase/race CAS preserves both')
check(not Economy.confirm(S,schema,{status='ERROR'},buy),'failed read never success')
local ctx={isStudio=false,role='RACE',experienceId=10768420544,placeId=127925465904803,privateServerId='reserved',privateServerOwnerId=0}
check(Policy.allowed(Config,ctx,11700555357,'reward') and Policy.allowed(Config,ctx,1,'reward'),'independent reward canary')
ctx.isStudio=true;check(Policy.allowed(Config,ctx,11700555357,'reward'),'Studio allowed');ctx.isStudio=false
local public=S.clone(Config);public.RewardsPublicEnabled=true
check(Policy.allowed(public,ctx,1,'reward'),'public payout enabled')
public.StoragePublicEnabled=true;check(Policy.allowed(public,ctx,1,'reward'),'explicit public rollout')
ctx.privateServerOwnerId=123;check(not Policy.allowed(public,ctx,1,'reward'),'VIP blocked')
ctx.role='HUB';ctx.privateServerId='';check(not Policy.allowed(public,ctx,1,'reward') and Policy.allowed(public,ctx,1,'purchase'),'hub only purchase')
check(Config.GamePassId==0 and not Config.GamePassEnabled,'unverified Robux disabled')
-- Repeated real callbacks, followed by a retained-receipt capacity fixture. No receipt eviction.
local repeated=schema.default(1);repeated.onboarding.firstFinishClaimed=true;repeated.onboarding.finishEvent.claimed=true
for n=1000,1249 do repeated=Records.reduce(S,schema,op(n,1,0,1,60000))(repeated) end
check(repeated.wallet.cash==256500 and repeated.wallet.lifetimeEarned==251500,'250 repeated race credits')
local receipt=S.clone(repeated.receipts[Records.receiptKey(op(1249,1,0,1))])
for n=1, 10000 - S.count(repeated.receipts) do repeated.receipts['race-record:'..guid(20000+n)]=S.clone(receipt) end
check(S.count(repeated.receipts)==10000 and schema.validate(repeated,'u:1'),'10000 permanent receipts within capacity')
local encoded=serde.encode('json',repeated)
check(#encoded<3000000 and #encoded<=S.jsonByteBound(repeated),'P2C JSON bound retained for 10000 races')
local after=Records.reduce(S,schema,op(11000,1,0,1))(repeated)
check(after and after.wallet.cash==repeated.wallet.cash+1000,'late account remains writable')
local max=S.new(catalog,{maxReceipts=1});local full=S.clone(original)
check(select(2,Records.reduce(S,max,op(11001,1,0,1))(full))=='RECEIPT_CAPACITY','capacity fails closed without pruning')
fs.writeFile('artifacts/r8-a4/economy-validation.json',serde.encode('json',{checks=checks,retainedReceipts=10000,jsonBytes=#encoded,liveDataStore=false}))
print('PASS: '..checks..' economy checks; 10000 retained receipts '..#encoded..' JSON bytes')

local newcomer=schema.default(1)
local debut=op(900,1,0,1)
local firstPaid=Records.reduce(S,schema,debut)(newcomer)
local receipt=firstPaid.receipts[Records.receiptKey(debut)]
check(receipt.money.firstFinish==5000 and receipt.money.total==7500,'first solo normal reward plus bonus')
check(firstPaid.wallet.cash==12500 and firstPaid.onboarding.firstFinishClaimed,'first bonus durable wallet latch')
check(schema.validate(firstPaid,S.userKey(1)),'new bonus receipt schema valid')
check(S.canonical(Records.reduce(S,schema,debut)(firstPaid))==S.canonical(firstPaid),'lost ACK replay never awards twice')
local again=op(901,1,1,1,65000)
local secondPaid=Records.reduce(S,schema,again)(firstPaid)
check(secondPaid.receipts[Records.receiptKey(again)].money.firstFinish==0,'new round no second first bonus')
local botDebut=Records.reduce(S,schema,op(902,1,1,1))(newcomer)
check(botDebut.wallet.cash==13000,'bot finish earns normal and first bonus')
local badFinish=op(903,1,0,1);badFinish.race.eligible=false;badFinish.race.reason='INVALID_ROUTE_OR_TIMER_RESET'
local rejected=Records.reduce(S,schema,badFinish)(newcomer)
check(rejected.wallet.cash==5000 and not rejected.onboarding.firstFinishClaimed,'invalid finish retains eligibility without money')
local overflow=S.clone(newcomer);overflow.wallet.cash=schema.maxCash-100
check(select(2,Records.reduce(S,schema,debut)(overflow))=='WALLET_CAPACITY','bonus capacity failure awards nothing')
local legacy=S.clone(firstPaid);legacy.onboarding=nil
local legacyNext=Records.reduce(S,schema,op(904,1,1,1,65000))(legacy)
check(legacyNext.receipts[Records.receiptKey(op(904,1,1,1,65000))].money.firstFinish==5000,'legacy previous finisher receives campaign bonus')
local corrupt=S.clone(firstPaid);corrupt.receipts[Records.receiptKey(debut)].money.firstFinish=4999
check(not schema.validate(corrupt,S.userKey(1)),'tampered bonus rejected')
print('PASS first-finish bonus and economy '..checks..' checks')

local previousBonus=S.clone(firstPaid)
previousBonus.onboarding={welcomeSeen=true,firstFinishClaimed=true}
local paidAgain=Records.reduce(S,schema,op(905,1,0,1,65000))(previousBonus)
check(paidAgain.receipts[Records.receiptKey(op(905,1,0,1,65000))].money.firstFinish==5000,'old welcome bonus does not exclude campaign participation')
check(paidAgain.onboarding.finishEvent.claimed and paidAgain.onboarding.finishEvent.id==S.FinishEventId,'stable campaign identity stored')
local rejoin=S.clone(paidAgain)
local afterRejoin=Records.reduce(S,schema,op(906,1,0,1,65000))(rejoin)
check(afterRejoin.receipts[Records.receiptKey(op(906,1,0,1,65000))].money.firstFinish==0,'persisted campaign latch survives service restart/rejoin')
check(S.finishEvent(previousBonus).seen==false and S.finishEvent(legacy).claimed==false,'all old account formats eligible for new campaign')
check(S.finishEvent(paidAgain).seen and S.finishEvent(paidAgain).claimed,'claimed account suppresses campaign popup')
local seenOnly=S.clone(previousBonus);seenOnly.onboarding.finishEvent=S.finishEvent(previousBonus);seenOnly.onboarding.finishEvent.seen=true
check(not S.finishEvent(seenOnly).claimed and seenOnly.wallet.cash==previousBonus.wallet.cash,'acknowledgement neither claims nor credits')
local corrupted=S.clone(paidAgain);corrupted.onboarding.finishEvent.claimed='true'
check(not schema.validate(corrupted,S.userKey(1)),'malformed campaign state rejected')
print('PASS campaign rollout economy '..checks..' checks')

-- R3 owner exception: invalid first completion neither credits nor consumes event/PB eligibility.
local function zeroInvalid(module)
 local fresh=schema.default(1);fresh.wallet.cash=777;fresh.wallet.lifetimeEarned=555
 fresh.purchaseHistory={keep={value=42}};fresh.selection.kartId='Kart09'
 local request=op(99001,4,0,1,30000);request.race.eligible=false;request.race.reason='INVALID_ROUTE_OR_TIMER_RESET';request.bestLapMilliseconds=nil;request.verification.fullLapValid=false
 local result,status=module.reduce(S,schema,request)(fresh)
 assert(result and status=='APPLIED','invalid result still has one durable receipt')
 local money=result.receipts[module.receiptKey(request)].money
 assert(result.wallet.cash==777 and result.wallet.lifetimeEarned==555 and money.base==0 and money.bestRace==0 and money.bestLap==0 and money.firstFinish==0 and money.total==0,'ineligible means zero in every payment channel')
 assert(not S.finishEvent(result).claimed and result.selection.kartId=='Kart09' and result.purchaseHistory.keep.value==42,'invalid preserves campaign eligibility and existing data')
 local retry,why=module.reduce(S,schema,request)(result)
 assert(why=='REPLAY' and S.canonical(retry)==S.canonical(result),'invalid ACK retry is also idempotent')
 local valid=op(99002,4,0,1,30000)
 local paid=module.reduce(S,schema,valid)(result)
 assert(paid.wallet.cash==10777 and S.finishEvent(paid).claimed,'later eligible finish keeps full base/PB/event entitlement')
 return true
end
check(zeroInvalid(Records),'zero invalid / later eligible / durable replay contract')
local raw=fs.readFile('src/server/RaceRecordOperations.luau')
local before='if copy.race and copy.race.eligible then'
local start=assert(raw:find(before,1,true))
local mutant=raw:sub(1,start-1)..'if true then'..raw:sub(start+#before)
local broken=luau.load(mutant,{debugName='R3_INJECT_INVALID_BASE_BUG'})()
check(not pcall(zeroInvalid,broken),'restoring unconditional base bug is detected by real reducer test')
print('PASS owner R3 invalid eligibility, event preservation and injected-defect rejection '..checks..' checks')
