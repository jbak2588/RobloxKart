-- Independent approved price constants + actual reducer effects and hostile inputs.
-- Never derives expected debit from the same catalog under test.
local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local function load(p,env)return luau.load(fs.readFile(p),{environment=env or {}})()end
local S=load('src/shared/KDMProgressionSchema.luau')
local catalog=load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum})
local schema=S.new(catalog,{jsonEncode=function(v)return serde.encode('json',v)end})
local C=load('src/shared/KDMShopCatalog.luau')
local expected={Smoke=2500,Slick=2500,Shield=2500,Nitro=5000,Missile=4000,Thunder=3500}
local n=0;local function check(v,label)assert(v,label);n+=1 end
local function priceContract(c)
 if c.KartPrice~=50000 or c.PaidItemUseEnabled~=false or #c.KartOrder~=7 then return false end
 for id,value in expected do if c.Prices[id]~=value then return false end end
 return true
end
check(priceContract(C),'independent approved shop price/use contract')
for id in expected do
 local bad=table.clone(C);bad.Prices=table.clone(C.Prices);bad.Prices[id]=1
 check(not priceContract(bad),'wrong price rejected '..id)
end
local bad=table.clone(C);bad.KartPrice=25000;check(not priceContract(bad),'old kart price rejected')
bad=table.clone(C);bad.PaidItemUseEnabled=true;check(not priceContract(bad),'unapproved paid consumption rejected')
local Ops=load('src/server/ShopOperations.luau').new(S,schema,C,load('src/server/EconomyOperations.luau'))
local function op(index,id)return {kind='BUY_ITEM',id=string.format('12345678-1234-1234-1234-%012d',index),userId=1,itemId=id,price=1}end
local i=0
for id,value in expected do
 i+=1;local before=schema.default(1);before.wallet.cash=20000;before.wallet.lifetimeEarned=777
 before.purchaseHistory={old={keep=true}};before.futureInventory={keep=true}
 local frozen=S.canonical(before);local request=op(i,id)
 local after,code=Ops.reduce(request)(before)
 check(code=='APPLIED' and after.wallet.cash==20000-value,'actual server debit ignores forged price '..id)
 check(after.wallet.lifetimeEarned==777 and after.futureInventory.keep and after.purchaseHistory.old.keep,'existing account fields preserved '..id)
 check(S.canonical(before)==frozen,'reducer never mutates prior profile '..id)
 check(after.shopInventory.counts[id]==1,'exactly one stock unit '..id)
 local again,why=Ops.reduce(request)(after)
 check(why=='REPLAY' and S.canonical(again)==S.canonical(after),'same receipt cannot debit or mint stock twice '..id)
 local collision=table.clone(request);collision.itemId=if id=='Smoke'then 'Nitro'else 'Smoke'
 local denied,reason=Ops.reduce(collision)(after)
 check(not denied and reason=='IDENTITY_MISMATCH','same ID different body rejected '..id)
 local poor=schema.default(1);poor.wallet.cash=value-1
 denied,reason=Ops.reduce(op(i+10,id))(poor)
 check(not denied and reason=='INSUFFICIENT_FUNDS' and poor.wallet.cash==value-1,'insufficient funds preserve wallet '..id)
 check(Ops.confirm({status='FOUND',value=after},request),'read-back confirms exact receipt '..id)
 local corrupt=S.clone(after);corrupt.wallet.cash=-1
 check(not Ops.confirm({status='FOUND',value=corrupt},request),'corrupt read-back never confirms '..id)
end
local balance=load('src/shared/KDMGameplayBalance.luau')
check(balance.DRIFT.BonusRequiredBoosts==3,'current source Nitro requires3; historical5 prose conflict documented')
local config=require('./helpers/gameplay_config')('src/shared/KartConfig.luau')
check(config.MAX_REVERSE_SPEED==70 and config.REVERSE_ACCELERATION==22 and config.BRAKE_FORCE==70,'approved reverse cap/ramp/brake contract')
local gas=load('src/shared/GasPedalPolicy.luau')
check(gas.Speed==90 and gas.enabled(10772198697,106553302629620,true) and not gas.enabled(1,2,true),'current GAS90 scoped gate')
print('PASS '..n..' current price/stock/wallet/identity/readback contracts and mutation rejection checks')
