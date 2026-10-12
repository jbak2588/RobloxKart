-- Server account facade. No DataStore call at module load, no Studio live writes.
local Service={}
local Shared=game:GetService('ReplicatedStorage'):WaitForChild('Shared')
local S=require(Shared.KDMProgressionSchema)
local schema=S.new(require(Shared.KartCatalog),{jsonEncode=function(v)return game:GetService('HttpService'):JSONEncode(v)end})
local Config=require(script.Parent.EconomyConfig)
local Policy=require(script.Parent.EconomyPolicy)
local Ops=require(script.Parent.EconomyOperations)
local Adapter=require(script.Parent.ProgressionDataStoreAdapter)
local busy,last={},{}
local function context()
 return {isStudio=game:GetService('RunService'):IsStudio(),role=workspace:GetAttribute('KDMServerRole'),
  experienceId=game.GameId,placeId=game.PlaceId,privateServerId=game.PrivateServerId,privateServerOwnerId=game.PrivateServerOwnerId}
end
function Service.allowed(player,kind) return Policy.allowed(Config,context(),player.UserId,kind) end
local function adapter(player,kind)
 return Adapter.new({schema=schema,key=S.userKey(player.UserId),authorize=function()return Service.allowed(player,kind)end,
  getStore=function()return game:GetService('DataStoreService'):GetDataStore(Config.StoreName)end,
  getOptions=function()local o=Instance.new('DataStoreGetOptions');o.UseCache=false;return o end,
  budget=function(kind)
   local ds=game:GetService('DataStoreService')
   return ds:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardRead)>0
    and (kind=='read' or ds:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardWrite)>0)
  end})
end
function Service.publishProfile(player,p)
 if not p or not schema.validate(p,S.userKey(player.UserId)) or p.deleted then return end
 local revision=player:GetAttribute('KDMWalletRevision')
 if revision and revision>p.wallet.ledgerRevision then return end
 player:SetAttribute('KDMWalletRevision',p.wallet.ledgerRevision)
 player:SetAttribute('KDMWalletCash',p.wallet.cash)
 player:SetAttribute('KDMLifetimeEarned',p.wallet.lifetimeEarned or 0)
 player:SetAttribute('KDMWingOwned',p.cosmetics.ownedPartIds[Config.WingId]==true)
 player:SetAttribute('KDMWingEquipped',p.cosmetics.equippedPartIdsBySlot.Wing==Config.WingId)
 player:SetAttribute('KDMEconomyState','FOUND')
end
local function publicProfile(p)
 return {status='FOUND',cash=p.wallet.cash,lifetimeEarned=p.wallet.lifetimeEarned or 0,kartId=p.selection.kartId,
  wingOwned=p.cosmetics.ownedPartIds[Config.WingId]==true,wingEquipped=p.cosmetics.equippedPartIdsBySlot.Wing==Config.WingId}
end
local function read(player)
 if not Service.allowed(player,'read') then return {status='ACCESS_BLOCKED'} end
 local a=adapter(player,'read');local key=S.userKey(player.UserId);local r=a.read(key)
 if r.status=='ABSENT' and Service.allowed(player,'purchase') then
  -- Create only on a confirmed absent read. UpdateAsync preserves a concurrently created profile.
  a=adapter(player,'purchase')
  a.commit(a.beginUpdate(key,function(previous)return previous or schema.default(player.UserId),'INITIALIZED'end))
  r=a.read(key)
 end
 if r.status=='FOUND' and not r.value.deleted then Service.publishProfile(player,r.value);return publicProfile(r.value) end
 return {status=if r.status=='FOUND' then 'READ_ONLY' else r.status}
end
local function transact(player,op)
 local a=adapter(player,'purchase');local key=S.userKey(player.UserId)
 for attempt=1,Config.RetryAttempts do
  local r=a.read(key)
  if Ops.confirm(S,schema,r,op) then Service.publishProfile(player,r.value);local view=publicProfile(r.value);view.purchaseState='SAVE_CONFIRMED';return view end
  if r.status~='FOUND' or r.value.deleted then return {status='READ_ONLY'} end
  local result=a.commit(a.beginUpdate(key,Ops.reduce(S,schema,op)))
  -- Always read back after an unknown ACK; never display success from UpdateAsync alone.
  r=a.read(key)
  if Ops.confirm(S,schema,r,op) then Service.publishProfile(player,r.value);local view=publicProfile(r.value);view.purchaseState='SAVE_CONFIRMED';return view end
  if result.status~='PENDING' and result.status~='SAVED' then
   if r.status=='FOUND' then Service.publishProfile(player,r.value) end
   return {status=result.reason or result.status}
  end
  task.wait(.5*2^(attempt-1))
 end
 return {status='SAVE_UNCONFIRMED'}
end
local function passVerified()
 if not Config.GamePassEnabled or Config.GamePassId<=0 then return false end
 local ok,info=pcall(function()return game:GetService('MarketplaceService'):GetProductInfoAsync(Config.GamePassId,Enum.InfoType.GamePass)end)
 return ok and info.IsForSale==true and info.PriceInRobux==Config.GamePassPrice
end
local function grantPass(player)
 if not Service.allowed(player,'purchase') or not passVerified() then return {status='PASS_UNAVAILABLE'} end
 local ok,owned=pcall(function()return game:GetService('MarketplaceService'):UserOwnsGamePassAsync(player.UserId,Config.GamePassId)end)
 if not ok or not owned then return {status='PASS_NOT_OWNED'} end
 return transact(player,{kind='GRANT_PASS',userId=player.UserId,id=game:GetService('HttpService'):GenerateGUID(false),itemId=Config.WingId,passId=Config.GamePassId})
end
function Service.start()
 local storage=game:GetService('ReplicatedStorage')
 if storage:FindFirstChild('KDMEconomy') then return end
 local remote=Instance.new('RemoteFunction');remote.Name='KDMEconomy';remote.Parent=storage
 remote.OnServerInvoke=function(player,action,equipped)
  if not Service.allowed(player,if action=='PROFILE' then 'read' else 'purchase') then return {status='ACCESS_BLOCKED'} end
  if busy[player] or last[player] and os.clock()-last[player]<1 then return {status='RATE_LIMITED'} end
  if action~='PROFILE' and (player:GetAttribute('RaceState')~='GARAGE' or player:GetAttribute('LobbyDriveActive')==true
   or player:GetAttribute('KDMRoutePending')=='RACE_LAUNCH') then return {status='HUB_REQUIRED'} end
  busy[player]=true;last[player]=os.clock()
  local ok,value=pcall(function()
   if action=='PROFILE' then local view=read(player);view.passAvailable=passVerified();return view end
   if action=='BUY_WING' or action=='EQUIP_WING' and type(equipped)=='boolean' then
    return transact(player,{kind=action,userId=player.UserId,id=game:GetService('HttpService'):GenerateGUID(false),itemId=Config.WingId,equipped=equipped})
   end
   if action=='PASS' and passVerified() then
    local owned=game:GetService('MarketplaceService'):UserOwnsGamePassAsync(player.UserId,Config.GamePassId)
    if owned then return grantPass(player) end
    local view=read(player)
    if view.status~='FOUND' or view.wingOwned then return {status=if view.wingOwned then 'ALREADY_OWNED' else view.status} end
    game:GetService('MarketplaceService'):PromptGamePassPurchase(player,Config.GamePassId)
    return {status='PASS_PROMPTED'}
   end
   return {status='UNAVAILABLE'}
  end)
  busy[player]=nil
  return if ok then value else {status='SAVE_UNCONFIRMED'}
 end
 local players=game:GetService('Players')
 local function joined(p)
  task.spawn(function()
   for i=1,Config.RetryAttempts do
    local ok,r=pcall(read,p)
    if ok and r.status=='FOUND' then break end
    if not Service.allowed(p,'read') then p:SetAttribute('KDMEconomyState','ACCESS_BLOCKED');return end
    task.wait(i)
   end
   if Config.GamePassEnabled and Service.allowed(p,'purchase') and p:GetAttribute('KDMWingOwned')~=true then pcall(grantPass,p) end
  end)
 end
 players.PlayerAdded:Connect(joined);for _,p in players:GetPlayers() do joined(p) end
 players.PlayerRemoving:Connect(function(p)last[p]=nil end)
 game:BindToClose(function()
  local deadline=os.clock()+20
  while next(busy) and os.clock()<deadline do task.wait(.1) end
 end)
 game:GetService('MarketplaceService').PromptGamePassPurchaseFinished:Connect(function(p,id,purchased)
  if purchased and id==Config.GamePassId and not busy[p] then
   busy[p]=true;pcall(grantPass,p);busy[p]=nil
  end
 end)
end
return table.freeze(Service)
