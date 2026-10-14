-- Run only as a temporary Server Script in a local Studio Play session.
-- Replaces the Shop RemoteFunction with an injected in-memory adapter.
assert(game:GetService('RunService'):IsStudio(),'Studio mock only')
local player=game.Players:GetPlayers()[1]
local Shared=game.ReplicatedStorage.Shared
local S=require(Shared.KDMProgressionSchema)
local C=require(Shared.KDMShopCatalog)
local schema=S.new(require(Shared.KartCatalog),{jsonEncode=function(v)return game.HttpService:JSONEncode(v)end})
local Server=game.ServerScriptService.Server
local Economy=require(Server.EconomyService)
local Service=require(Server.ShopService)
local Ops=require(Server.ShopOperations).new(S,schema,C,require(Server.EconomyOperations))
local saved=schema.default(player.UserId);saved.wallet.cash=3100
local backend={}
function backend:GetAsync(_,options)
 assert(options.UseCache==false)
 if workspace:GetAttribute('ShopMockReadFailure') then error('mock read timeout')end
 return S.clone(saved)
end
function backend:UpdateAsync(_,callback)
 local value=callback(S.clone(saved))
 if value then saved=value end
 if workspace:GetAttribute('ShopMockAckLoss') then error('mock ACK loss')end
 return value
end
local adapter=require(Server.ProgressionDataStoreAdapter).new({schema=schema,key=S.userKey(player.UserId),
 authorize=function()return game:GetService('RunService'):IsStudio()end,
 getStore=function()return backend end,getOptions=function()return {UseCache=false}end,budget=function()return true end})
local function publish(p)
 Economy.publishProfile(player,p)
 player:SetAttribute('KDMInventoryAutoRefill',p.shopInventory and p.shopInventory.autoRefill or false)
 for _,id in C.Order do player:SetAttribute('KDMStock'..id,p.shopInventory and p.shopInventory.counts[id] or 0)end
 workspace:SetAttribute('ShopMockProfile',game.HttpService:JSONEncode(p))
end
game.ReplicatedStorage.KDMShop.OnServerInvoke=function(p,action,itemId,requestId,value)
 assert(p==player)
 if action=='PROFILE' then local r=Ops.view(saved);r.canPurchase=true;r.passAvailable=false;r.passId=0;return r end
 local op={kind=action,id=requestId,userId=p.UserId,itemId=itemId}
 if action=='EQUIP_WING' then op.equipped=value end
 if action=='SET_AUTO_REFILL' then op.itemId=nil;op.enabled=value end
 return Service.transaction(adapter,op,publish,task.wait)
end
publish(saved)
workspace:SetAttribute('ShopMockOnly',true)
print('SHOP MOCK ACCOUNT: K$3100, zero live DataStore calls')
