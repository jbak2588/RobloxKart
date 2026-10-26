-- Server account facade. No DataStore call at module load, no Studio live writes.
local Service={}
local Shared=game:GetService('ReplicatedStorage'):WaitForChild('Shared')
local S=require(Shared.KDMProgressionSchema)
local schema=S.new(require(Shared.KartCatalog),{utcMs=function()return DateTime.now().UnixTimestampMillis end,jsonEncode=function(v)return game:GetService('HttpService'):JSONEncode(v)end})
local ShopCatalog=require(Shared.KDMShopCatalog)
local Config=require(script.Parent.EconomyConfig)
local Policy=require(script.Parent.EconomyPolicy)
local Ops=require(script.Parent.EconomyOperations)
local Adapter=require(script.Parent.ProgressionDataStoreAdapter)
local busy,last={},{}
local accountReads,joining,closing=0,0,false
local parkSaves=0
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
 for _,id in ShopCatalog.KartOrder do player:SetAttribute('KDMOwned'..id,ShopCatalog.ownsKart(p.cosmetics.ownedPartIds,id)) end
 local owned=ShopCatalog.playerOwnsKart(player,player:GetAttribute('SelectedKartId'))
 player:SetAttribute('KDMWingOwned',owned);player:SetAttribute('KDMWingEquipped',owned)
 local event=S.finishEvent(p)
 player:SetAttribute('KDMWelcomeSeen',event.seen)
 player:SetAttribute('KDMFirstFinishClaimed',event.claimed)
 player:SetAttribute('KDMRookieParkBestMilliseconds',p.parkTimeTrial and p.parkTimeTrial.bestMilliseconds)
 player:SetAttribute('KDMRookieParkTwoLapBestMilliseconds',p.parkTwoLapTrial and p.parkTwoLapTrial.bestMilliseconds)
 player:SetAttribute('KDMRookieParkCompletedLaps',p.parkTimeTrial and p.parkTimeTrial.completedLaps or 0)
 player:SetAttribute('KDMAccountQualified',true)
 player:SetAttribute('KDMEconomyState','FOUND')
end
local function publicProfile(p)
 return {status='FOUND',cash=p.wallet.cash,lifetimeEarned=p.wallet.lifetimeEarned or 0,kartId=p.selection.kartId,
  wingOwned=ShopCatalog.ownsKart(p.cosmetics.ownedPartIds,p.selection.kartId),wingEquipped=ShopCatalog.ownsKart(p.cosmetics.ownedPartIds,p.selection.kartId)}
end
local function readAccount(player)
 if not Service.allowed(player,'read') then return {status='ACCESS_BLOCKED'} end
 local a=adapter(player,'read');local key=S.userKey(player.UserId);local r=a.read(key)
 if r.status=='ABSENT' and player:GetAttribute('KDMAccountQualified')==true then return {status='PENDING'} end
 if r.status=='ABSENT' then
  -- Confirmed absence is a guest, never permission to create an account on read.
  player:SetAttribute('KDMWalletCash',0);player:SetAttribute('KDMWalletRevision',0)
  player:SetAttribute('KDMLifetimeEarned',0);player:SetAttribute('KDMWingOwned',false);player:SetAttribute('KDMWingEquipped',false)
  player:SetAttribute('KDMAccountQualified',false);player:SetAttribute('KDMFirstFinishClaimed',false)
  if player:GetAttribute('KDMWelcomeSeen')==nil then player:SetAttribute('KDMWelcomeSeen',false)end
  player:SetAttribute('KDMEconomyState','GUEST')
  return {status='GUEST',cash=0,wingOwned=false,wingEquipped=false}
 end
 if r.status=='FOUND' and not r.value.deleted then
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
 op=S.clone(op);op.transaction=op.transaction or schema.issueTransaction()
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
-- Called only by server-owned driving/official-finish observers. Never exposed as a remote action.
local qualifying={}
function Service.qualifyActivity(player,kind,proof)
 if kind~='TEST_DRIVE' and kind~='RACE_FINISH' then return {status='INVALID_ACTIVITY'} end
 if kind=='TEST_DRIVE' and (type(proof)~='table' or proof.complete~=true or not S.integer(proof.movingMilliseconds)
  or proof.movingMilliseconds<30000 or type(proof.distance)~='number' or proof.distance<300 or proof.distance~=proof.distance or proof.distance==math.huge) then return {status='INVALID_ACTIVITY'} end
 if kind=='RACE_FINISH' then
  local records=require(script.Parent.RaceRecordOperations)
  if not records.valid(S,proof) or proof.userId~=player.UserId or not proof.race or not proof.race.eligible then return {status='INVALID_ACTIVITY'} end
 end
 if not Service.allowed(player,'initialize') or qualifying[player] then return {status='PENDING'} end
 qualifying[player]=true
 local ok,result=pcall(function()
  local a=adapter(player,'initialize');local key=S.userKey(player.UserId)
  local before=a.read(key)
  if before.status~='FOUND' and before.status~='ABSENT' then return {status=before.status} end
  if before.status=='FOUND' and schema.validate(before.value,key) and not before.value.deleted and before.value.activity then
   Service.publishProfile(player,before.value);return publicProfile(before.value)
  end
  local qualifiedAt=DateTime.now().UnixTimestampMillis
  local selected=player:GetAttribute('SelectedKartId')
  a.commit(a.beginUpdate(key,function(previous)
   if previous and (not schema.validate(previous,key) or previous.deleted) then return nil,'READ_ONLY' end
   local nextValue=if previous then S.clone(previous) else schema.default(player.UserId)
   -- Existing users keep their existing starter cash; no second grant.
   if not previous and schema.supportsKart(selected) then nextValue.selection.kartId=selected end
   if not nextValue.activity then
    nextValue.activity={version=1,kind=kind,qualifiedAt=qualifiedAt,starterGranted=previous==nil,
     movingMilliseconds=if kind=='TEST_DRIVE' then proof.movingMilliseconds else 0,
     distance=if kind=='TEST_DRIVE' then math.floor(proof.distance) else 0}
   end
   return nextValue,'ACTIVITY_QUALIFIED'
  end))
  local saved=a.read(key)
  if saved.status~='FOUND' or not schema.validate(saved.value,key) or saved.value.deleted or not saved.value.activity then return {status='SAVE_UNCONFIRMED'} end
  Service.publishProfile(player,saved.value)
  if before.status=='ABSENT' then player:SetAttribute('KDMStarterRewardConfirmed',true)end
  return publicProfile(saved.value)
 end)
 qualifying[player]=nil
 return if ok then result else {status='SAVE_UNCONFIRMED'}
end
-- Internal observer only: no remote accepts a lap proof or reward amount.
function Service.saveParkLap(player,proof)
 if not Service.allowed(player,'parkReward')then return {status='ACCESS_BLOCKED'}end
 local op=S.clone(proof);op.userId=player.UserId
 local reducer=Ops.parkLap(S,schema,op)
 parkSaves+=1
 local ok,result=pcall(function()
  local a=adapter(player,'parkReward');local key=S.userKey(player.UserId)
  local sig=S.transactionCanonical(op)
  for attempt=1,Config.RetryAttempts do
   local result=a.commit(a.beginUpdate(key,reducer))
   local read=a.read(key)
   local receipt=read.status=='FOUND'and schema.validate(read.value,key)and not read.value.deleted and read.value.receipts['park-lap:'..tostring(op.id)]
   if receipt and S.signatureMatches(receipt,sig)then
    Service.publishProfile(player,read.value);return {status='SAVE_CONFIRMED'}
   end
   if result.status~='PENDING'and result.status~='SAVED'then return {status='SAVE_UNCONFIRMED'}end
   if attempt<Config.RetryAttempts then task.wait(.5*2^(attempt-1))end
  end
  return {status='SAVE_UNCONFIRMED'}
 end)
 parkSaves-=1
 return if ok then result else {status='SAVE_UNCONFIRMED'}
end
function Service.passAvailable() return passVerified() end
function Service.creditReward(player, amount, reason, identity)
	if not player or type(amount) ~= "number" or amount <= 0 or not Service.allowed(player, "reward") then return false end
	local a = adapter(player, "reward")
	local key = S.userKey(player.UserId)
 local op={userId=player.UserId,roundGuid=if identity then identity.RoundGuid else player:GetAttribute('OfficialRoundGuid'),amount=amount,reason=reason,
  transaction={version=1,issuedAt=if identity then identity.IssuedAt else player:GetAttribute('OfficialRoundIssuedAt')}}
 local ok,result=pcall(function()
  local result=a.commit(a.beginUpdate(key,Ops.dnf(S,schema,op)))
  local read=a.read(key);local receipt=read.status=='FOUND' and read.value.receipts['dnf:'..tostring(op.roundGuid)]
  if receipt and S.signatureMatches(receipt,S.transactionCanonical(op)) then return {status='SAVED',value=read.value} end
  return result.status=='SAVED' and {status='SAVE_UNCONFIRMED'} or result
 end)
	if ok and result and result.status == "SAVED" and result.value then
		Service.publishProfile(player, result.value)
		if player:GetAttribute("OfficialRoundGuid")==op.roundGuid then
			player:SetAttribute("RaceMoneyState", "SAVE_CONFIRMED")
			player:SetAttribute("RaceMoney_base", amount)
			player:SetAttribute("RaceMoney_total", amount)
		end
		return true
	end
	return false
end
function Service.start()
 local storage=game:GetService('ReplicatedStorage')
 if storage:FindFirstChild('KDMEconomy') then return end
 local remote=Instance.new('RemoteFunction');remote.Name='KDMEconomy';remote.Parent=storage
 remote.OnServerInvoke=function(player,action,equipped)
  if closing then return {status='CLOSING'} end
  if action=='BUY_WING' or action=='EQUIP_WING' or action=='PASS' then return {status='UNAVAILABLE'} end
  if not Service.allowed(player,if action=='PROFILE' then 'read' elseif action=='BUY_WING' or action=='PASS' then 'shop' else 'purchase') then return {status='ACCESS_BLOCKED'} end
  if busy[player] or last[player] and os.clock()-last[player]<1 then return {status='RATE_LIMITED'} end
  if action~='PROFILE' and (player:GetAttribute('RaceState')~='GARAGE' or player:GetAttribute('LobbyDriveActive')==true
   or player:GetAttribute('KDMRoutePending')=='RACE_LAUNCH') then return {status='HUB_REQUIRED'} end
  busy[player]=true;last[player]=os.clock()
  local ok,value=pcall(function()
   if action=='PROFILE' then local view=read(player);view.passAvailable=passVerified();view.passId=Config.GamePassId;return view end
   if action=='WELCOME_SEEN' then
    local a=adapter(player,'purchase');local key=S.userKey(player.UserId)
    local r=a.read(key)
    if r.status=='ABSENT' then player:SetAttribute('KDMWelcomeSeen',true);return {status='SAVE_CONFIRMED'} end
    if r.status~='FOUND' or not schema.validate(r.value,key) or r.value.deleted then return {status='READ_ONLY'} end
    a.commit(a.beginUpdate(key,function(previous)
     if not previous or not schema.validate(previous,key) or previous.deleted then return nil,'READ_ONLY' end
     local copy=S.clone(previous)
     copy.onboarding=copy.onboarding or {welcomeSeen=true,firstFinishClaimed=false}
     local event=S.finishEvent(copy);event.seen=true;copy.onboarding.finishEvent=event
     copy.onboarding.welcomeSeen=true;return copy,'WELCOME_SEEN'
    end))
    r=a.read(key)
    if r.status=='FOUND' and S.finishEvent(r.value).seen then
     Service.publishProfile(player,r.value);return {status='SAVE_CONFIRMED'}
    end
    return {status='SAVE_UNCONFIRMED'}
   end
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
  p:GetAttributeChangedSignal('SelectedKartId'):Connect(function()
   local owned=ShopCatalog.playerOwnsKart(p,p:GetAttribute('SelectedKartId'))
   p:SetAttribute('KDMWingOwned',owned);p:SetAttribute('KDMWingEquipped',owned)
  end)
  joining+=1
  task.spawn(function()
   pcall(function()
    for i=1,Config.RetryAttempts do
     local r=read(p)
     if r.status=='FOUND' or r.status=='GUEST' then break end
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
  while (next(busy) or accountReads>0 or joining>0 or parkSaves>0) and os.clock()<deadline do task.wait(.1) end
 end)
 game:GetService('MarketplaceService').PromptGamePassPurchaseFinished:Connect(function(p,id,purchased)
  if purchased and id==Config.GamePassId and not busy[p] then
   busy[p]=true;pcall(grantPass,p);busy[p]=nil
  end
 end)
end
return table.freeze(Service)
