-- Robux payment authority is server-only; Studio previews NEVER credit live data.
local Service={}
local RS=game:GetService('ReplicatedStorage')
local S=require(RS.Shared.KDMProgressionSchema)
local Catalog=require(RS.Shared.KDMRobuxTopUpCatalog)
local Economy=require(script.Parent.EconomyService)
local Ops=require(script.Parent.RobuxTopUpOperations)
local Processor=require(script.Parent.RobuxTopUpReceiptProcessor)
local schema=S.new(require(RS.Shared.KartCatalog),{utcMs=function()return DateTime.now().UnixTimestampMillis end,jsonEncode=function(v)return game:GetService('HttpService'):JSONEncode(v)end})
local started,closing,inflight=false,false,0
local function live()
 return not closing and not game:GetService('RunService'):IsStudio()
  and game.GameId==Catalog.ExperienceId and game.PlaceId==Catalog.PlaceId
end
local function canPrompt(p)
 return live() and p.Parent==game:GetService('Players') and Economy.allowed(p,'shop')
  and p:GetAttribute('RaceState')=='GARAGE' and p:GetAttribute('LobbyDriveActive')~=true
  and p:GetAttribute('LobbyDrivePending')~=true and (p:GetAttribute('KDMRoutePending')or '')==''
end
function Service.start()
 if started then return end;started=true
 local players=game:GetService('Players');local market=game:GetService('MarketplaceService')
 local function publish(p,profile)
  if p.Parent~=players then return end
  Economy.publishProfile(p,profile)
  p:SetAttribute('KDMTopUpState','SAVED')
  p:SetAttribute('KDMTopUpSerial',(p:GetAttribute('KDMTopUpSerial')or 0)+1)
 end
 local process=Processor.new({S=S,schema=schema,catalog=Catalog,ops=Ops,
  pending=Enum.ProductPurchaseDecision.NotProcessedYet,granted=Enum.ProductPurchaseDecision.PurchaseGranted,
  allowed=live,player=function(id)return players:GetPlayerByUserId(id)end,
  adapter=function(p)return Economy.accountAdapter(p,'initialize')end,publish=publish})
 market.ProcessReceipt=function(receipt)
  inflight+=1
  local ok,result=pcall(process,receipt)
  inflight-=1
  return if ok then result else Enum.ProductPurchaseDecision.NotProcessedYet
 end
 local remote=Instance.new('RemoteFunction');remote.Name='KDMRobuxTopUp';remote.Parent=RS
 local busy,last={},{}
 remote.OnServerInvoke=function(p,action,sku,...)
  if select('#',...)>0 or (action~='LIST' and action~='PROMPT') then return {status='UNAVAILABLE'} end
  if action=='LIST' then
   local offers={}
   for _,id in Catalog.Order do local e=Catalog.Entries[id];table.insert(offers,{sku=id,productId=e.ProductId,amount=e.Amount,baseRobux=e.BaseRobux})end
   return {status=if game:GetService('RunService'):IsStudio()then 'PREVIEW' else 'READY',offers=offers,canPurchase=canPrompt(p)}
  end
  local entry=type(sku)=='string' and Catalog.Entries[sku]
  if not entry or entry.ProductId<=0 or not canPrompt(p) then return {status='UNAVAILABLE'} end
  if busy[p] or os.clock()-(last[p]or -math.huge)<2 then return {status='PLEASE_WAIT'} end
  busy[p]=true;last[p]=os.clock()
  local ok,result=pcall(function()
   local profile=Economy.getProfile(p)
   if profile.status~='FOUND' and profile.status~='GUEST' then return {status='ACCOUNT_UNAVAILABLE'} end
   if (profile.cash or schema.maxCash)+entry.Amount>schema.maxCash then return {status='WALLET_FULL'} end
   local a=Economy.accountAdapter(p,'initialize');local key=S.userKey(p.UserId);local raw=a.read(key)
   if raw.status~='FOUND' and raw.status~='ABSENT' then return {status='ACCOUNT_UNAVAILABLE'} end
   local candidate=Ops.reduce(S,schema,Catalog,{PlayerId=p.UserId,ProductId=entry.ProductId,PurchaseId='preflight:'..game:GetService('HttpService'):GenerateGUID(false)})(raw.value)
   if not candidate then return {status='WALLET_FULL'} end
   local info=market:GetProductInfoAsync(entry.ProductId,Enum.InfoType.Product)
   if type(info)~='table' or info.IsForSale==false or type(info.PriceInRobux)~='number' or info.PriceInRobux<=0 then return {status='UNAVAILABLE'} end
   if not canPrompt(p) then return {status='UNAVAILABLE'} end
   p:SetAttribute('KDMTopUpState','PROMPTED')
   market:PromptProductPurchase(p,entry.ProductId)
   return {status='PROMPTED'}
  end)
  busy[p]=nil
  return if ok then result else {status='UNAVAILABLE'}
 end
 players.PlayerRemoving:Connect(function(p)busy[p]=nil;last[p]=nil end)
 game:BindToClose(function()
  closing=true;local deadline=os.clock()+20
  while inflight>0 and os.clock()<deadline do task.wait(.1)end
 end)
end
return table.freeze(Service)
