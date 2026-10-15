-- Test only: no real account access, fixed canary operation is outside production source.
local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local function load(p,e)return luau.load(fs.readFile(p),{environment=e or {},debugName=p})()end
local S=load('src/shared/KDMProgressionSchema.luau')
local schema=S.new(load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum}),{jsonEncode=function(v)return serde.encode('json',v)end})
local G=load('artifacts/r8-a6-b-release-readiness/canary_grant_operation.luau')
local grant=G.new(S,schema);local Adapter=load('src/server/ProgressionDataStoreAdapter.luau')
local Economy=load('src/server/EconomyOperations.luau')
local n=0;local function check(v,label)n+=1;assert(v,label)end
local p=schema.default(G.UserId);p.wallet.cash=22925;p.wallet.ledgerRevision=17;p.wallet.lifetimeEarned=925
p.selection.kartId='Kart09';p.shopInventory={counts={Nitro=4,Thunder=2},autoRefill=false,revision=8}
p.inventory={retained=true};p.purchaseHistory={old={preserved=true}};p.receipts.old={signature='unchanged'}
local old=S.clone(p);local read={status='FOUND',value=p}
local preflight,reason=grant.preflight(read);check(preflight and reason=='READY' and preflight.cash==22925,'latest confirmed preflight, no assumed live balance')
local value,status=grant.reduce(preflight)(p)
check(status=='APPLIED' and value.wallet.cash==25925 and value.wallet.ledgerRevision==18,'exact +3000 and one revision')
check(value.wallet.lifetimeEarned==925,'test grant excluded from play earnings')
local remainder=S.clone(value);remainder.wallet.cash=22925;remainder.wallet.ledgerRevision=17;remainder.receipts[G.OperationId]=nil
check(S.canonical(remainder)==S.canonical(old) and S.canonical(p)==S.canonical(old),'all other fields and input preserved')
check(grant.confirm({status='FOUND',value=value}).afterCash==25925,'schema-compatible durable grant receipt')
local again,why=grant.reduce(preflight)(value);check(why=='REPLAY' and S.canonical(again)==S.canonical(value),'identical operation cannot grant twice')
check(select(2,grant.preflight({status='FOUND',value=value}))=='ALREADY_GRANTED','preflight stops repeat operation')
for _,kind in {'ABSENT','ERROR','FUTURE','CORRUPT','ACCESS_BLOCKED'} do check(not grant.preflight({status=kind}),'no write from '..kind)end
local other=schema.default(2);check(not grant.preflight({status='FOUND',value=other}),'wrong account denied')
local owned=S.clone(p);owned.cosmetics.ownedPartIds.KDM_V2_WING=true
check(select(2,grant.preflight({status='FOUND',value=owned}))=='ALREADY_OWNED','never revoke Wing to manufacture a purchase test')
local deleted=S.clone(p);deleted.deleted=true;check(not grant.preflight({status='FOUND',value=deleted}),'deleted denied')
local collision=S.clone(p);collision.receipts[G.OperationId]={signature='other'}
check(select(2,grant.preflight({status='FOUND',value=collision}))=='RECEIPT_COLLISION','existing receipt cannot be replaced')
check(select(2,grant.reduce(preflight)(collision))=='RECEIPT_COLLISION','callback independently blocks collision')
local changed=S.clone(p);changed.wallet.cash+=10
check(select(2,grant.reduce(preflight)(changed))=='ACCOUNT_CHANGED','concurrent race or purchase requires fresh inspection')
changed=S.clone(p);changed.selection.kartId='Kart07'
check(select(2,grant.reduce(preflight)(changed))=='ACCOUNT_CHANGED','even non-wallet concurrent field is preserved')
local small=S.new(load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum}),{maxReceipts=1})
check(select(2,G.new(S,small).preflight(read))=='RECEIPT_CAPACITY','full receipt store stops grant')
changed=S.clone(p);changed.wallet.cash=schema.maxCash-2999
check(select(2,grant.preflight({status='FOUND',value=changed}))=='WALLET_CAPACITY','overflow denied')
local b={value=S.clone(p),writeFail=false,readFail=false,ackLost=true,writes=0}
local store={GetAsync=function(_,key,options)check(key==S.userKey(G.UserId) and options.UseCache==false,'uncached exact-account read');if b.readFail then error('outage')end;return S.clone(b.value)end,
 UpdateAsync=function(_,_,cb)
  if b.writeFail then error('write outage')end
  local info={GetUserIds=function()return {G.UserId,42}end,GetMetadata=function()return {preserved=true}end}
  local nextValue,ids,metadata=cb(S.clone(b.value),info)
  if nextValue then check(ids[2]==42 and metadata.preserved,'DataStore UserIds/metadata preserved');b.value=nextValue;b.writes+=1 end
  if b.ackLost then error('ACK lost')end;return nextValue
 end}
local a=Adapter.new({schema=schema,key=S.userKey(G.UserId),authorize=function()return true end,getStore=function()return store end,budget=function()return true end,getOptions=function()return {UseCache=false}end})
local result=a.commit(a.beginUpdate(S.userKey(G.UserId),grant.reduce(preflight)))
check(result.status=='PENDING' and grant.confirm(a.read(S.userKey(G.UserId))),'lost ACK must reread existing receipt before retry')
b.readFail=true;check(not grant.confirm(a.read(S.userKey(G.UserId))),'read failure is not grant success')
b.readFail=false;b.ackLost=false
result=a.commit(a.beginUpdate(S.userKey(G.UserId),grant.reduce(preflight)))
check(b.value.wallet.cash==25925 and result.outcome=='REPLAY','reexecution has zero extra credit')
-- Purchase uses the real existing economy reducer, not an ownership shortcut.
local buy={kind='BUY_WING',id='12345678-1234-1234-1234-123456789099',userId=G.UserId,itemId='KDM_V2_WING'}
local bought=Economy.reduce(S,schema,buy)(b.value)
check(bought.wallet.cash==925 and bought.wallet.ledgerRevision==19 and bought.cosmetics.ownedPartIds.KDM_V2_WING,'mock grant then normal Wing purchase returns original B')
check(bought.cosmetics.equippedPartIdsBySlot.Wing=='KDM_V2_WING','normal Wing equip preserved')
check(Economy.confirm(S,schema,{status='FOUND',value=bought},buy) and bought.purchaseHistory['wing:'..buy.id],'purchase history and receipt')
local retryBuy=S.clone(buy);retryBuy.id='12345678-1234-1234-1234-123456789100'
check(select(2,Economy.reduce(S,schema,retryBuy)(bought))=='ALREADY_OWNED','distinct request duplicate buy never debits again')
check(grant.confirm({status='FOUND',value=bought}) and select(2,grant.reduce(preflight)(bought))=='REPLAY','grant receipt survives purchase; replay cannot replenish spent grant')
local reconnect=serde.decode('json',serde.encode('json',bought));check(schema.validate(reconnect,S.userKey(G.UserId)) and reconnect.wallet.cash==925,'JSON reconnect preserves final balance and entitlement')
print('PASS: '..n..' one-off canary grant / normal Wing operation mock checks; live reads/writes ZERO')
