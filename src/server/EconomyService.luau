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
local accountReads,joining,closing=0,0,false
local studioData={}
local studioAdapter={
 read=function(key)
  local val=studioData[key]
  if val==nil then return {status='ABSENT',key=key} end
  return {status='FOUND',key=key,value=S.clone(val)}
 end,
 beginUpdate=function(key,callback)
  return {key=key,callback=callback,consumed=false}
 end,
 commit=function(tx)
  tx.consumed=true
  local nextVal,outcome=tx.callback(studioData[tx.key])
  if nextVal~=nil then studioData[tx.key]=S.clone(nextVal) end
  return {status='SAVED',value=studioData[tx.key],outcome=outcome}
 end,
}
local function context()
 return {isStudio=game:GetService('RunService'):IsStudio(),role=workspace:GetAttribute('KDMServerRole'),
  experienceId=game.GameId,placeId=game.PlaceId,privateServerId=game.PrivateServerId,privateServerOwnerId=game.PrivateServerOwnerId}
end
function Service.allowed(player,kind) return Policy.allowed(Config,context(),player.UserId,kind) end
local function adapter(player,kind)
 if game:GetService('RunService'):IsStudio() then
  return studioAdapter
 end
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
local function readAccount(player)
 if not Service.allowed(player,'read') then return {status='ACCESS_BLOCKED'} end
 local a=adapter(player,'read');local key=S.userKey(player.UserId);local r=a.read(key)
 if r.status=='ABSENT' and Service.allowed(player,'initialize') then
  -- Create only on a confirmed absent read. UpdateAsync preserves a concurrently created profile.
  a=adapter(player,'initialize')
  local result=a.commit(a.beginUpdate(key,function(previous)return previous or schema.default(player.UserId),'INITIALIZED'end))
  r=a.read(key)
  if r.status=='ABSENT' and (result.status=='PENDING' or result.status=='SAVED') then return {status='PENDING'} end
 end
 if r.status=='FOUND' and not r.value.deleted then
  local p=r.value
  local emptyHistory=(not p.purchaseHistory or next(p.purchaseHistory)==nil)
   and (not p.receipts or next(p.receipts)==nil)
   and (p.wallet.lifetimeEarned==nil or p.wallet.lifetimeEarned==0)
  
  if p.receipts and S.count(p.receipts) >= 3 then
   local pa = adapter(player, 'purchase')
   pa.commit(pa.beginUpdate(key, function(curr)
    if not curr then return nil end
    local cloned = S.clone(curr)
    if cloned.receipts and S.count(cloned.receipts) >= 3 then
     local candidates = {}
     for id in cloned.receipts do table.insert(candidates, id) end
     table.sort(candidates)
     for i = 1, #candidates - 1 do cloned.receipts[candidates[i]] = nil end
     return cloned, 'PRUNED_RECEIPTS'
    end
    return nil, 'NO_CHANGE'
   end))
   r = a.read(key)
   p = r.value
  end

  if p.wallet.cash==0 and p.wallet.ledgerRevision==0 and emptyHistory then
   a=adapter(player,'initialize')
   a.commit(a.beginUpdate(key,function(curr)
    if not curr then return nil end
    local cloned=S.clone(curr)
    if cloned.wallet.cash==0 and cloned.wallet.ledgerRevision==0 then cloned.wallet.cash=5000 end
    return cloned,'STARTER_CASH_GRANTED'
   end))
   r=a.read(key)
  end
  Service.publishProfile(player,r.value);return publicProfile(r.value)
 end
 return {status=if r.status=='FOUND' then 'READ_ONLY' else r.status}
end
local function read(player)
 accountReads+=1
 local ok,value=pcall(readAccount,player)
 accountReads-=1
 return if ok then value else {status='ERROR'}
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
 return ok and info.IsForSale==true and type(info.PriceInRobux)=='number' and info.PriceInRobux>0
end
local function grantPass(player)
 if not Service.allowed(player,'purchase') or not Config.GamePassEnabled or Config.GamePassId<=0 then return {status='PASS_UNAVAILABLE'} end
 local ok,owned=pcall(function()return game:GetService('MarketplaceService'):UserOwnsGamePassAsync(player.UserId,Config.GamePassId)end)
 if not ok or not owned then return {status='PASS_NOT_OWNED'} end
 return transact(player,{kind='GRANT_PASS',userId=player.UserId,id=game:GetService('HttpService'):GenerateGUID(false),itemId=Config.WingId,passId=Config.GamePassId})
end
-- Internal server APIs; callers still pass through adapter authorization.
function Service.accountAdapter(player,kind) return adapter(player,kind) end
function Service.getProfile(player) return read(player) end
function Service.passAvailable() return passVerified() end
function Service.start()
 local storage=game:GetService('ReplicatedStorage')
 if storage:FindFirstChild('KDMEconomy') then return end
 local remote=Instance.new('RemoteFunction');remote.Name='KDMEconomy';remote.Parent=storage
 remote.OnServerInvoke=function(player,action,equipped)
  if closing then return {status='CLOSING'} end
  if not Service.allowed(player,if action=='PROFILE' then 'read' elseif action=='BUY_WING' or action=='PASS' then 'shop' else 'purchase') then return {status='ACCESS_BLOCKED'} end
  if busy[player] or last[player] and os.clock()-last[player]<1 then return {status='RATE_LIMITED'} end
  if action~='PROFILE' and (player:GetAttribute('RaceState')~='GARAGE' or player:GetAttribute('LobbyDriveActive')==true
   or player:GetAttribute('KDMRoutePending')=='RACE_LAUNCH') then return {status='HUB_REQUIRED'} end
  busy[player]=true;last[player]=os.clock()
  local ok,value=pcall(function()
   if action=='PROFILE' then local view=read(player);view.passAvailable=passVerified();view.passId=Config.GamePassId;return view end
   if action=='BUY_WING' or action=='EQUIP_WING' and type(equipped)=='boolean' then
    return transact(player,{kind=action,userId=player.UserId,id=game:GetService('HttpService'):GenerateGUID(false),itemId=Config.WingId,equipped=equipped})
   end
   if action=='PASS' and Config.GamePassEnabled and Config.GamePassId>0 then
    local owned=game:GetService('MarketplaceService'):UserOwnsGamePassAsync(player.UserId,Config.GamePassId)
    if owned then return grantPass(player) end
    if not passVerified() then return {status='PASS_UNAVAILABLE'} end
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
  if closing then return end
  joining+=1
  task.spawn(function()
   pcall(function()
    for i=1,Config.RetryAttempts do
     local r=read(p)
     if r.status=='FOUND' then break end
     if not Service.allowed(p,'read') then p:SetAttribute('KDMEconomyState','ACCESS_BLOCKED');return end
     if i<Config.RetryAttempts then task.wait(i) end
    end
    if Config.GamePassEnabled and Service.allowed(p,'purchase') and p:GetAttribute('KDMWingOwned')~=true then pcall(grantPass,p) end
   end)
   joining-=1
  end)
 end
 players.PlayerAdded:Connect(joined);for _,p in players:GetPlayers() do joined(p) end
 players.PlayerRemoving:Connect(function(p)last[p]=nil end)
 game:BindToClose(function()
  closing=true
  local deadline=os.clock()+20
  while (next(busy) or accountReads>0 or joining>0) and os.clock()<deadline do task.wait(.1) end
 end)
 game:GetService('MarketplaceService').PromptGamePassPurchaseFinished:Connect(function(p,id,purchased)
  if purchased and id==Config.GamePassId and not busy[p] then
   busy[p]=true;pcall(grantPass,p);busy[p]=nil
  end
 end)
end
return table.freeze(Service)
