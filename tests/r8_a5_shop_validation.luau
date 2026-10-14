local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local function load(path,env)return luau.load(fs.readFile(path),{environment=env or {},debugName=path})()end
local S=load('src/shared/KDMProgressionSchema.luau')
local catalog=load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum})
local schema=S.new(catalog,{jsonEncode=function(v)return serde.encode('json',v)end})
local C=load('src/shared/KDMShopCatalog.luau')
local Economy=load('src/server/EconomyOperations.luau')
local Ops=load('src/server/ShopOperations.luau').new(S,schema,C,Economy)
local checks=0;local function check(v,label)checks+=1;assert(v,label)end
local function guid(n)return string.format('12345678-1234-1234-1234-%012d',n)end
local p=schema.default(1);p.wallet.cash=805;p.wallet.lifetimeEarned=900;p.selection.kartId='Kart09'
p.futureInventory={preserved=true};p.records.scoped={};p.purchaseHistory={old={preserved=true}}
local original=S.clone(p)
local function op(kind,n,id)return {kind=kind,id=guid(n),userId=1,itemId=id}end
local function apply(profile,o)local nextValue,code=Ops.reduce(o)(profile);return nextValue,code end
local wing=op('BUY_WING',1,C.WingId)
local value,code=apply(p,wing);check(value==nil and code=='INSUFFICIENT_FUNDS','mock K$805 cannot buy Wing')
check(S.canonical(p)==S.canonical(original),'failed purchase never mutates input')
p.wallet.cash=3100;value,code=apply(p,wing)
check(code=='APPLIED' and value.wallet.cash==100 and value.cosmetics.ownedPartIds[C.WingId],'Wing atomically debits and owns')
local replay=apply(value,wing);check(replay.wallet.cash==100,'same request replay cannot charge again')
local duplicate=op('BUY_WING',2,C.WingId);local none,reason=apply(value,duplicate)
check(not none and reason=='ALREADY_OWNED','different request duplicate Wing blocked')
local pass={kind='GRANT_PASS',id=guid(3),userId=1,itemId=C.WingId,passId=123}
local already,why=Economy.reduce(S,schema,pass)(value);check(not already and why=='ALREADY_OWNED','cash and pass resolve same entitlement')
local passFirst=Economy.reduce(S,schema,pass)(p);check(passFirst.wallet.cash==p.wallet.cash and passFirst.cosmetics.ownedPartIds[C.WingId],'verified pass owns without cash debit')
none,reason=apply(passFirst,wing);check(not none and reason=='ALREADY_OWNED','pass then cash cannot buy twice')
local equip=op('EQUIP_WING',4,C.WingId);equip.equipped=false;value=apply(value,equip)
check(not value.cosmetics.equippedPartIdsBySlot.Wing and value.wallet.cash==100,'unequip preserves ownership and wallet')
equip.id=guid(5);equip.equipped=true;value=apply(value,equip)
check(value.cosmetics.equippedPartIdsBySlot.Wing==C.WingId,'re-equip uses permanent entitlement')
check(value.selection.kartId=='Kart09' and value.futureInventory.preserved and value.purchaseHistory.old.preserved and value.wallet.lifetimeEarned==900,'existing account fields preserved')
p=S.clone(original)
for i,id in C.Order do
 local buy=op('BUY_ITEM',10+i,id);local before=p.wallet.cash;p=apply(p,buy)
 check(p.wallet.cash==before-C.Prices[id] and p.shopInventory.counts[id]==1,'price and permanent stock '..id)
 local again=apply(p,buy);check(again.wallet.cash==p.wallet.cash and again.shopInventory.counts[id]==1,'purchase retry '..id)
 local mismatch=op('BUY_ITEM',10+i,C.Order[i%#C.Order+1]);none,reason=apply(p,mismatch)
 check(not none and reason=='IDENTITY_MISMATCH','request identity cannot change product')
end
check(not p.shopInventory.autoRefill,'legacy stock defaults auto OFF')
local round=guid(50)
local refill={kind='REFILL',id=round,userId=1,itemId='Nitro',roundGuid=round}
none,reason=apply(p,refill);check(not none and reason=='AUTO_REFILL_OFF','no silent purchased refill')
local enabled=op('SET_AUTO_REFILL',30,nil);enabled.enabled=true;p=apply(p,enabled)
local cash=p.wallet.cash;p=apply(p,refill)
check(p.shopInventory.counts.Nitro==0 and p.wallet.cash==cash,'voucher consumes stock, no second cash debit')
local twice=apply(p,refill);check(twice.shopInventory.counts.Nitro==0,'same round voucher debit replay once')
refill.itemId='Shield';p=apply(p,refill);refill.itemId='Thunder'
none,reason=apply(p,refill);check(not none and reason=='ROUND_REFILL_LIMIT','two total per official round')
local nextRound=S.clone(refill);nextRound.id=guid(51);nextRound.roundGuid=guid(51);p=apply(p,nextRound)
check(p.shopInventory.counts.Thunder==0,'Rematch new official GUID uses its own limit')
local refund=S.clone(nextRound);refund.kind='REFUND_REFILL';p=apply(p,refund)
local refunded=apply(p,refund);check(refunded.shopInventory.counts.Thunder==1,'invalidated delivery refunds once')
check(not Ops.confirm({status='FOUND',value=p},nextRound),'refunded receipt cannot deliver')
none,reason=apply(p,nextRound);check(not none and reason=='REFILL_CLOSED','refunded round/item remains closed')
local delivered={kind='REFILL',id=guid(52),roundGuid=guid(52),userId=1,itemId='Smoke',jobId='crashed-job',reservedAt=1}
p=apply(p,delivered)
local retry=S.clone(delivered);retry.reservedAt=2
check(Ops.confirm({status='FOUND',value=p},retry),'reservation retry is stable across server clock changes')
local done=S.clone(delivered);done.kind='FINALIZE_REFILL';p=apply(p,done)
check(Ops.confirm({status='FOUND',value=p},done),'delivery finalized durably')
local stop=S.clone(delivered);stop.kind='REFUND_REFILL';none,reason=apply(p,stop)
check(not none and reason=='ALREADY_DELIVERED','delivered voucher never refunds after reconnect')
local rejoined=serde.decode('json',serde.encode('json',p));check(schema.validate(rejoined,S.userKey(1)) and rejoined.shopInventory.counts.Thunder==1 and rejoined.shopInventory.autoRefill,'inventory survives JSON reconnect')
local corrupt=S.clone(p);corrupt.shopInventory.counts.Nitro=-1;check(not schema.validate(corrupt,S.userKey(1)),'negative inventory rejected')
corrupt=S.clone(p);corrupt.shopInventory.counts.Unknown=1;check(not schema.validate(corrupt,S.userKey(1)),'unknown purchased item rejected')
local wrong=op('BUY_ITEM',80,'Smoke');wrong.userId=2;none,reason=apply(p,wrong);check(not none and reason=='READ_ONLY','wrong account rejected')
local under=S.clone(p);under.wallet.cash=0;none,reason=apply(under,op('BUY_ITEM',81,'Smoke'));check(not none and reason=='INSUFFICIENT_FUNDS','insufficient item balance')
local capped=S.clone(p);capped.shopInventory.counts.Smoke=C.MaxStock;none,reason=apply(capped,op('BUY_ITEM',82,'Smoke'));check(not none and reason=='STOCK_FULL','stock cap enforced')

local Adapter=load('src/server/ProgressionDataStoreAdapter.luau')
local Config=load('src/server/EconomyConfig.luau');local Policy=load('src/server/EconomyPolicy.luau')
local ctx={isStudio=false,role='HUB',experienceId=Config.ExperienceId,placeId=Config.PlaceId,privateServerId='',privateServerOwnerId=0}
check(Policy.allowed(Config,ctx,11700555357,'shop') and not Policy.allowed(Config,ctx,2,'shop'),'only canary shop transactions')
local public=S.clone(Config);public.StoragePublicEnabled=true;check(not Policy.allowed(public,ctx,2,'shop'),'storage rollout alone cannot enable general shop sales')
ctx.isStudio=true;check(not Policy.allowed(Config,ctx,11700555357,'shop'),'Studio live account writes blocked');ctx.isStudio=false
ctx.role='RACE';ctx.privateServerId='reserved';check(Policy.allowed(Config,ctx,11700555357,'voucher') and not Policy.allowed(Config,ctx,11700555357,'shop'),'Race voucher does not permit shopping')
local shared={KDMProgressionSchema='S',KDMShopCatalog='C',KartCatalog='Karts'}
local server={EconomyConfig='Config',EconomyService='E',EconomyOperations='Economy',ShopOperations='Ops'}
local mods={S=S,C=C,Karts=catalog,Config=Config,E={},Economy=Economy,Ops=load('src/server/ShopOperations.luau')}
local Service=load('src/server/ShopService.luau',{game={GetService=function()return {Shared=shared}end,HttpService={JSONEncode=function(_,v)return serde.encode('json',v)end}},script={Parent=server},require=function(id)return mods[id]end})
local trace={};local granted=0
local function saveDelivery(op)table.insert(trace,op.kind);return {purchaseState='SAVE_CONFIRMED'}end
check(Service.deliverReserved(S.clone(delivered),saveDelivery,function()return true end,function()granted+=1;return true end),'confirmed consume permits one runtime grant')
check(trace[1]=='FINALIZE_REFILL' and #trace==1 and granted==1,'durable delivery marker precedes transient charge')
trace={};check(not Service.deliverReserved(S.clone(delivered),function(op)table.insert(trace,op.kind);return {status='SAVE_UNCONFIRMED'}end,function()return true end,function()granted+=1;return true end),'uncertain finalization never grants')
check(granted==1 and #trace==1,'unknown acknowledgement cannot grant or refund uncertain delivery')
trace={};check(not Service.deliverReserved(S.clone(delivered),saveDelivery,function()return false end,function()error('ineligible grant')end) and trace[1]=='REFUND_REFILL','free refill or finish before commit compensates reservation')
trace={};check(not Service.deliverReserved(S.clone(delivered),saveDelivery,function()return true end,function()return false end) and trace[2]=='REFUND_UNUSED_REFILL','known failed runtime grant compensates finalized consumption')
local unused=S.clone(delivered);unused.kind='REFUND_UNUSED_REFILL'
local refunded=apply(p,unused);check(refunded.shopInventory.counts.Smoke==p.shopInventory.counts.Smoke+1,'known unused finalized voucher restored')
local again=apply(refunded,unused);check(again.shopInventory.counts.Smoke==refunded.shopInventory.counts.Smoke,'finalized compensation replay cannot duplicate stock')
local saved=S.clone(original);local ackLoss=false;local readFailure=false;local writes=0;local publications=0
local backend={GetAsync=function(_,_,options)check(options.UseCache==false,'uncached read-back');if readFailure then error('timeout')end return S.clone(saved)end,
 UpdateAsync=function(_,_,callback)local value=callback(S.clone(saved));if value then saved=value;writes+=1 end;if ackLoss then error('lost ACK')end return value end}
local a=Adapter.new({schema=schema,key=S.userKey(1),authorize=function()return true end,getStore=function()return backend end,getOptions=function()return {UseCache=false}end,budget=function()return true end})
local buy=op('BUY_ITEM',100,'Nitro');ackLoss=true
local r=Service.transaction(a,buy,function()publications+=1 end,function()end)
check(r.purchaseState=='SAVE_CONFIRMED' and writes==1 and saved.wallet.cash==780,'unknown write ACK resolved by durable receipt read-back')
r=Service.transaction(a,buy,function()end,function()end);check(r.purchaseState=='SAVE_CONFIRMED' and writes==1,'retry after lost response never rewrites or recharges')
readFailure=true;r=Service.transaction(a,op('BUY_ITEM',101,'Smoke'),function()error('must not publish')end,function()end)
check(r.status=='SAVE_UNCONFIRMED' and saved.wallet.cash==780,'read timeout never claims success or mutates account')
readFailure=false;ackLoss=false
backend.UpdateAsync=function(_,_,callback)local value=callback(S.clone(saved));if value then saved=value;writes+=1 end;readFailure=true;error('ACK plus read outage')end
buy=op('BUY_ITEM',102,'Smoke');r=Service.transaction(a,buy,function()error('unverified success')end,function()end)
check(r.status=='SAVE_UNCONFIRMED' and saved.shopInventory.counts.Smoke==1,'committed but unreadable purchase remains unconfirmed')
readFailure=false;r=Service.transaction(a,buy,function()end,function()end)
check(r.purchaseState=='SAVE_CONFIRMED' and saved.shopInventory.counts.Smoke==1 and saved.wallet.cash==760,'same client GUID reconciles after reconnect/outage')

local raceCatalog=load('src/shared/RaceItemCatalog.luau');local slots=load('src/shared/RaceItemSlots.luau',{script={Parent={WaitForChild=function(_,n)return n end}},require=function()return raceCatalog end})
local loadout=load('src/server/RaceLoadout.luau',{game={GetService=function()return {WaitForChild=function()return {WaitForChild=function(_,n)return n end}end}end},require=function(n)return if n=='RaceItemCatalog' then raceCatalog else slots end})
local l=loadout.new();l:prepare();local free=S.clone(l.counts)
l.counts.Nitro=0;l.bonusProgress=3
check(l:creditVoucher('Nitro',guid(400)) and l.counts.Nitro==1 and l.bonusProgress==3,'voucher preserves earned Nitro progress')
check(l:creditVoucher('Nitro',guid(400)) and l.counts.Nitro==1,'runtime delivery receipt never duplicates charge')
check(not l:creditVoucher('Smoke',guid(400)),'inactive slot cannot receive paid charge')
check(not l:creditVoucher('Shield',guid(400)),'full slot rejects voucher')
l:prepare();for id,count in free do check(l.counts[id]==count,'Rematch default preserved '..id)end
l.counts.Shield=0;l:refillLapItems({Enabled=true,Eligible={Shield=true},RefillTo=1});check(l.counts.Shield==1 and not l:creditVoucher('Shield',guid(401)),'free lap refill has priority; no extra charge')

local Layout=load('src/client/ShopLayout.luau')
for _,size in {{749,323},{749,381},{932,352},{844,332},{473,240},{473,182},{320,568},{1920,1022}}do
 local v={X=size[1],Y=size[2]};local q=Layout.forSize(v)
 check(q.width<=v.X-16 and q.height<=v.Y-16,'shop outer rectangle safe')
 check(q.tabsY+44<=q.bodyY and q.bodyY+q.bodyHeight<=(if q.footerHeight==0 then q.height-8 else q.footerY-8),'tabs scroll body and status never overlap')
 check(q.bodyHeight>=44,'scroll viewport can expose a complete touch button')
 check(q.confirmHeight<=v.Y-16 and q.confirmWidth<=v.X-16,'confirmation inside safe area')
 check(8+3*q.tabWidth+8<=q.width,'three tabs stay inside modal')
end
print('PASS: '..checks..' shop transaction, inventory, voucher, preservation, timeout and safe-layout checks; mock accounts only')
