-- Existing account adapter + separate temporary RaceLoadout. No live Studio writes.
local Service={}
local RS=game:GetService('ReplicatedStorage')
local S=require(RS.Shared.KDMProgressionSchema)
local C=require(RS.Shared.KDMShopCatalog)
local Config=require(script.Parent.EconomyConfig)
local Economy=require(script.Parent.EconomyService)
local schema=S.new(require(RS.Shared.KartCatalog),{utcMs=function()return DateTime.now().UnixTimestampMillis end,jsonEncode=function(v)return game.HttpService:JSONEncode(v)end})
local Ops=require(script.Parent.ShopOperations).new(S,schema,C,require(script.Parent.EconomyOperations))
local tickets=S.newTicketBook(function()return DateTime.now().UnixTimestampMillis end,function()return game:GetService('HttpService'):GenerateGUID(false)end)
local busy,last,refillAttempted={},{},{}
local queued,pumping={},{}
-- Injected coordinator is used by mock-account tests and the live authorized adapter.
function Service.transaction(a,op,publish,wait)
 local key=S.userKey(op.userId)
 for attempt=1,Config.RetryAttempts do
  local r=a.read(key)
  if r.status=='ERROR' then wait(.5*2^(attempt-1));continue end
  if Ops.confirm(r,op) then publish(r.value);local view=Ops.view(r.value);view.purchaseState='SAVE_CONFIRMED';return view end
  if r.status~='FOUND' or r.value.deleted then return {status='READ_ONLY'} end
  local result=a.commit(a.beginUpdate(key,Ops.reduce(op)))
  r=a.read(key)
  if Ops.confirm(r,op) then publish(r.value);local view=Ops.view(r.value);view.purchaseState='SAVE_CONFIRMED';return view end
  if result.status~='PENDING' and result.status~='SAVED' then return {status=result.reason or result.status} end
  wait(.5*2^(attempt-1))
 end
 return {status='SAVE_UNCONFIRMED'}
end
local function publish(player,p)
 local revision=player:GetAttribute('KDMWalletRevision')
 if revision and revision>p.wallet.ledgerRevision then return end
 Economy.publishProfile(player,p)
 local view=Ops.view(p)
 player:SetAttribute('KDMInventoryAutoRefill',view.autoRefill)
 for id,count in view.counts do player:SetAttribute('KDMStock'..id,count) end
end
local function transact(player,kind,op)
 return Service.transaction(Economy.accountAdapter(player,kind),op,function(p)publish(player,p)end,task.wait)
end
function Service.deliverReserved(op,save,eligible,apply)
 if not eligible() then op.kind='REFUND_REFILL';save(op);return false end
 op.kind='FINALIZE_REFILL'
 if save(op).purchaseState~='SAVE_CONFIRMED' then return false end
 -- No yielding between the final eligibility check and the charge mutation.
 if apply() then return true end
 op.kind='REFUND_UNUSED_REFILL';save(op);return false
end
local function profile(player)
 local r=Economy.accountAdapter(player,'read').read(S.userKey(player.UserId))
 if r.status=='ABSENT' then return {status='GUEST',cash=0,counts={},canPurchase=false,wingOwned=false,wingEquipped=false,autoRefill=false,passAvailable=false}end
 if r.status~='FOUND' or r.value.deleted then return {status=if r.status=='FOUND' then 'READ_ONLY' else r.status} end
 -- A previous server can leave a confirmed debit without a confirmed delivery.
 -- Only expired reservations from a different job are compensated in the Hub;
 -- delivered vouchers are never refunded and no race charges are replayed here.
 if player:GetAttribute('RaceState')=='GARAGE' and Economy.allowed(player,'shop') then
  local changed=false
  for _,receipt in r.value.receipts do
   local f=receipt.refill
   if f and f.state=='RESERVED' and not receipt.refunded and f.jobId~=game.JobId and os.time()-f.reservedAt>=60 then
    local op={kind='REFUND_REFILL',id=f.roundGuid,userId=player.UserId,itemId=f.itemId,roundGuid=f.roundGuid}
    local result=transact(player,'shop',op);changed=changed or result.purchaseState=='SAVE_CONFIRMED'
   end
  end
  if changed then r=Economy.accountAdapter(player,'read').read(S.userKey(player.UserId));if r.status~='FOUND' then return {status='SAVE_UNCONFIRMED'}end end
 end
 publish(player,r.value)
 local view=Ops.view(r.value)
 view.canPurchase=Economy.allowed(player,'shop')
 view.passAvailable=Economy.passAvailable();view.passId=Config.GamePassId
 return view
end
local function tryRefill(player,id)
 if busy[player] or player:GetAttribute('KDMInventoryAutoRefill')~=true or not Economy.allowed(player,'voucher') then return end
 local Items=require(script.Parent.RaceItemController)
 local guid=Items.voucherTarget(player,id)
 if not S.guid(guid) then return end
 local key=guid..':'..id
 if refillAttempted[player] and refillAttempted[player][key] then return end
 busy[player]=true
 local ok=pcall(function()
  local r=Economy.accountAdapter(player,'read').read(S.userKey(player.UserId))
  if r.status~='FOUND' or not Ops.view(r.value).autoRefill or (Ops.view(r.value).counts[id] or 0)<1 then return end
  -- Durable identity comes from the server's globally unique official round,
  -- never a local session counter or a client-supplied identity.
  local op={kind='REFILL',id=guid,userId=player.UserId,itemId=id,roundGuid=guid,jobId=game.JobId,reservedAt=os.time(),transaction={version=1,issuedAt=player:GetAttribute('OfficialRoundIssuedAt')}}
  local result=transact(player,'voucher',op)
  if result.purchaseState~='SAVE_CONFIRMED' then return end
  refillAttempted[player]=refillAttempted[player] or {};refillAttempted[player][key]=true
  -- Never grant a charge before the durable consume has been read back.
  if Service.deliverReserved(op,function(v)return transact(player,'voucher',v)end,
   function()return Items.voucherTarget(player,id)==guid end,
   function()return Items.applyVoucher(player,id,guid)end) then
   player:SetAttribute('KDMVoucherRefillSerial',(player:GetAttribute('KDMVoucherRefillSerial') or 0)+1)
  end
 end)
 busy[player]=nil
 if not ok then player:SetAttribute('KDMShopState','SAVE_UNCONFIRMED') end
end
function Service.start()
 if RS:FindFirstChild('KDMShop') then return end
 local remote=Instance.new('RemoteFunction');remote.Name='KDMShop';remote.Parent=RS
 remote.OnServerInvoke=function(player,action,itemId,requestId,value)
  if not Economy.allowed(player,if action=='PROFILE' then 'read' else 'shop') then return {status='ACCESS_BLOCKED'} end
  if busy[player] or last[player] and os.clock()-last[player]<.75 then return {status='RATE_LIMITED'} end
  if action~='PROFILE' and (player:GetAttribute('RaceState')~='GARAGE' or player:GetAttribute('LobbyDriveActive')==true
   or player:GetAttribute('KDMRoutePending')=='RACE_LAUNCH') then return {status='HUB_REQUIRED'} end
  if action=='PREPARE' then
   local body=itemId
   if type(body)~='table' or (body.action~='BUY_WING' and body.action~='BUY_ITEM' and body.action~='EQUIP_WING' and body.action~='SET_AUTO_REFILL') then return {status='INVALID_OPERATION'} end
   if body.action=='BUY_ITEM' and (type(body.itemId)~='string' or not C.Prices[body.itemId]) then return {status='INVALID_OPERATION'} end
   if (body.action=='EQUIP_WING' or body.action=='SET_AUTO_REFILL') and type(body.value)~='boolean' then return {status='INVALID_OPERATION'} end
   local op={kind=body.action,userId=player.UserId,itemId=if body.action=='BUY_WING' or body.action=='EQUIP_WING' then C.WingId else body.itemId}
   if body.action=='EQUIP_WING' then op.equipped=body.value end
   if body.action=='SET_AUTO_REFILL' then op.itemId=nil;op.enabled=body.value end
   return {status='PREPARED',id=tickets.issue(player,op)}
  end
  if action~='PROFILE' and (not S.guid(requestId) or (action~='BUY_WING' and action~='BUY_ITEM' and action~='EQUIP_WING' and action~='SET_AUTO_REFILL')) then return {status='INVALID_OPERATION'} end
  busy[player]=true;last[player]=os.clock()
  local ok,r=pcall(function()
   if action=='PROFILE' then return profile(player) end
   local op={kind=action,id=requestId,userId=player.UserId,itemId=if action=='BUY_WING' or action=='EQUIP_WING' then C.WingId else itemId}
   if action=='EQUIP_WING' then op.equipped=value end
   if action=='SET_AUTO_REFILL' then op.itemId=nil;op.enabled=value end
   local authorized,reason=tickets.resolve(player,op)
   if not authorized then
    -- A restart/evicted ticket may still confirm an existing receipt, but
    -- absence must NEVER mint fresh authority or run a debit reducer.
    local read=Economy.accountAdapter(player,'read').read(S.userKey(player.UserId))
    if Ops.confirm(read,op) then
     publish(player,read.value);local view=Ops.view(read.value);view.purchaseState='SAVE_CONFIRMED';return view
    end
    return {status=reason}
   end
   return transact(player,'shop',authorized)
  end)
  busy[player]=nil;return if ok then r else {status='SAVE_UNCONFIRMED'}
 end
 local function joined(player)
  refillAttempted[player]={}
  local function schedule()
   if player:GetAttribute('RaceState')~='RACING' or player:GetAttribute('KDMInventoryAutoRefill')~=true then return end
   queued[player]=true
   if pumping[player] then return end
   pumping[player]=true
   task.spawn(function()
    while queued[player] and player.Parent do
     queued[player]=nil
     for _,id in C.Order do if player:GetAttribute('RaceCharge'..id)==0 then tryRefill(player,id)end end
    end
    pumping[player]=nil
   end)
  end
  player:GetAttributeChangedSignal('OfficialRoundGuid'):Connect(function()refillAttempted[player]={}end)
  player:GetAttributeChangedSignal('RaceState'):Connect(schedule)
  player:GetAttributeChangedSignal('KDMInventoryAutoRefill'):Connect(schedule)
  for _,id in C.Order do
   player:GetAttributeChangedSignal('RaceCharge'..id):Connect(function()
    if player:GetAttribute('RaceCharge'..id)==0 then task.defer(schedule) end
   end)
  end
  task.spawn(function()if Economy.allowed(player,'read') then pcall(profile,player) end end)
  task.delay(65,function()if player.Parent and player:GetAttribute('RaceState')=='GARAGE' and Economy.allowed(player,'read') then pcall(profile,player)end end)
 end
 local players=game:GetService('Players')
 players.PlayerAdded:Connect(joined);for _,p in players:GetPlayers()do joined(p)end
 players.PlayerRemoving:Connect(function(p)last[p]=nil;tickets.remove(p);refillAttempted[p]=nil;queued[p]=nil end)
end
return Service
