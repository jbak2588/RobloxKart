-- Actual RaceController + records/economy/shop services; only platform I/O and item delivery are mocked.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local source=fs.readFile('tests/four_player_race_validation.luau')
local anchor='local race=load("src/server/RaceController.luau",server,"RaceController")'
local prefix=source:sub(1,assert(source:find(anchor,1,true))-1)
prefix=prefix:gsub('require%("%./helpers/gameplay_config"%)','CONFIG_LOADER')
if CONTROLLER_OVERRIDE then
 prefix=prefix:gsub('fs.readFile%(path%)','(if path=="src/server/RaceController.luau" then fs.readFile(CONTROLLER_OVERRIDE) else fs.readFile(path))')
end
local setup=[[
local serde=require('@lune/serde')
local S=load('src/shared/KDMProgressionSchema.luau',shared,'KDMProgressionSchema')
local karts=load('src/shared/KartCatalog.luau',shared,'KartCatalog')
local shopCatalog=load('src/shared/KDMShopCatalog.luau',shared,'KDMShopCatalog')
check(shopCatalog.PaidItemUseEnabled==false,'current public policy pauses paid consumption')
if MODE=='LEGACY_OPT_IN'then
 -- Test-only opt-in exercises retained transaction defenses; never enables runtime policy.
 local enabled=table.clone(shopCatalog);enabled.PaidItemUseEnabled=true;modules.KDMShopCatalog=enabled
end
load('src/shared/KDMPerformanceBuffer.luau',shared,'KDMPerformanceBuffer')
load('src/server/EconomyConfig.luau',server,'EconomyConfig')
load('src/server/EconomyPolicy.luau',server,'EconomyPolicy')
load('src/server/EconomyOperations.luau',server,'EconomyOperations')
load('src/server/ProgressionDataStoreAdapter.luau',server,'ProgressionDataStoreAdapter')
load('src/server/ShopOperations.luau',server,'ShopOperations')
local schema=S.new(karts,{utcMs=function()return environment.DateTime.now().UnixTimestampMillis end,jsonEncode=function(v)return serde.encode('json',v)end})
local profiles={};local lostAck=false;local reservationHook
local backend={GetAsync=function(_,key,options)check(options.UseCache==false,'service uncached read');return S.clone(profiles[key])end,
 UpdateAsync=function(_,key,callback)
  local value=callback(S.clone(profiles[key]));if value then profiles[key]=S.clone(value)end
  if reservationHook then local f=reservationHook;reservationHook=nil;f()end
  if lostAck then lostAck=false;error('stored but ACK lost')end
  return S.clone(profiles[key])
 end}
for _,p in services.Players:GetPlayers()do
 local profile=schema.default(p.UserId);profile.wallet.cash=10000;profile.onboarding.finishEvent.claimed=true
 profile.shopInventory={counts={Smoke=3,Missile=2,Shield=2},autoRefill=true,revision=0}
 profiles[S.userKey(p.UserId)]=profile
end
services.RunService.studio=false
services.Workspace:SetAttribute('KDMServerRole','RACE')
services.DataStoreService={GetRequestBudgetForRequestType=function()return 100 end,GetDataStore=function(_,name)check(name=='KDM_PlayerProgress_v1','mock live-shape store');return backend end}
services.HttpService.JSONEncode=function(_,v)return serde.encode('json',v)end
local originalGuid=services.HttpService.GenerateGUID;local guidCalls=0
services.HttpService.GenerateGUID=function(...)guidCalls+=1;return originalGuid(...)end
local jobs={};local delayed={}
environment.task={spawn=function(fn,...)local args={...};table.insert(jobs,function()fn(table.unpack(args))end)end,
 defer=function(fn)table.insert(jobs,fn)end,delay=function(_,fn)table.insert(delayed,fn)end,wait=function()end}
environment.workspace=services.Workspace
environment.os={clock=function()return now end,time=function()return math.floor(environment.DateTime.now().UnixTimestampMillis/1000)end}
environment.game.HttpService=services.HttpService
environment.game.GameId=10768420544;environment.game.PlaceId=127925465904803
environment.game.PrivateServerId='reserved';environment.game.PrivateServerOwnerId=0;environment.game.JobId='current-job'
local economy=load('src/server/EconomyService.luau',server,'EconomyService')
modules.PrototypeWorld.onDriftOutcome=function()end
if MODE=='LOAD_FAILURE' then
 child(server,'ModuleScript','RaceRecordService') -- require cannot resolve -> actual pcall failure
elseif MODE=='BEGIN_FAILURE' then
 child(server,'ModuleScript','RaceRecordService');modules.RaceRecordService={begin=function()error('injected observer begin failure')end}
elseif MODE=='NORMAL' or MODE=='LEGACY_OPT_IN' then
 load('src/server/RaceRecordConfig.luau',server,'RaceRecordConfig')
 load('src/server/RaceRecordPolicy.luau',server,'RaceRecordPolicy')
 load('src/server/RaceRecordOperations.luau',server,'RaceRecordOperations')
 load('src/server/RaceRecordRuntime.luau',server,'RaceRecordRuntime')
 load('src/server/OfficialRaceRecords.luau',server,'OfficialRaceRecords')
 load('src/server/RaceRecordReset.luau',server,'RaceRecordReset')
 load('src/server/RaceRecordService.luau',server,'RaceRecordService')
end
local eligible=true;local applyOk=true;local delivered=0;local expectedGuid
child(server,'ModuleScript','RaceItemController')
modules.RaceItemController={voucherTarget=function(p,id)
 if eligible and p:GetAttribute('RaceState')=='RACING' and p:GetAttribute('RaceCharge'..id)==0 then return p:GetAttribute('OfficialRoundGuid')end
end,applyVoucher=function(p,id,guid)
 check(guid==p:GetAttribute('OfficialRoundGuid') and guid==expectedGuid,'delivery bound to controller round')
 if not applyOk then return false end
 delivered+=1;p:SetAttribute('RaceCharge'..id,1);return true
end}
local shop=load('src/server/ShopService.luau',server,'ShopService');shop.start()
local function drain()local n=0;while #jobs>0 do n+=1;assert(n<100,'bounded queued work');table.remove(jobs,1)()end end
drain()
local race=load('src/server/RaceController.luau',server,'RaceController')
race.start({trackId='Track01Race'})
local session=sessionType.active()
local function tick(dt)now+=dt;services.RunService.Heartbeat:Fire(dt)end
local remote=services.ReplicatedStorage.RaceControl.OnServerEvent
a:SetAttribute('RaceState','PRE_RACE');tick(.1);b:SetAttribute('RaceState','PRE_RACE');tick(.1)
remote:Fire(a,'StartRace');tick(raceConfig.COUNTDOWN_SECONDS+.1)
check(session.phase=='RACING','actual controller GO despite '..MODE)
local guid=a:GetAttribute('OfficialRoundGuid');local issued=a:GetAttribute('OfficialRoundIssuedAt')
check(S.guid(guid) and S.integer(issued) and b:GetAttribute('OfficialRoundGuid')==guid and b:GetAttribute('OfficialRoundIssuedAt')==issued,'shared identity/time independent of observer '..MODE)
check(guidCalls==1,'one GUID at GO; records observer reuses it '..MODE)
expectedGuid=guid;drain()
if MODE=='NORMAL'then
 local before=S.canonical(profiles[S.userKey(a.UserId)]);a:SetAttribute('RaceChargeSmoke',0);drain()
 check(S.canonical(profiles[S.userKey(a.UserId)])==before and delivered==0,'current policy consumes no paid stock or receipt even with stored autoRefill=true')
end
if MODE=='LEGACY_OPT_IN' then
 local profile=profiles[S.userKey(a.UserId)]
 check(profile.shopInventory.counts.Smoke==3,'initial stock before service refill')
 lostAck=true -- actual ShopService transaction resolves committed RESERVED ACK loss
 a:SetAttribute('RaceChargeSmoke',0);drain()
 profile=profiles[S.userKey(a.UserId)]
 local key='shop-refill:'..guid..':Smoke';local receipt=profile.receipts[key]
 check(receipt and receipt.issuedAt==issued and receipt.refill.state=='DELIVERED' and not receipt.refunded,'normal service reserve/finalize has controller time')
 check(profile.shopInventory.counts.Smoke==2 and delivered==1 and a:GetAttribute('RaceChargeSmoke')==1,'normal service one stock debit and one delivery')
 a:SetAttribute('RaceChargeSmoke',0);drain()
 check(profiles[S.userKey(a.UserId)].shopInventory.counts.Smoke==2 and delivered==1,'same-round automatic refill cannot repeat')
 -- Become ineligible after the durable reserve; actual service compensates once.
 reservationHook=function()eligible=false end
 a:SetAttribute('RaceChargeMissile',0);drain();eligible=true
 profile=profiles[S.userKey(a.UserId)];receipt=profile.receipts['shop-refill:'..guid..':Missile']
 check(receipt and receipt.refunded and profile.shopInventory.counts.Missile==2,'service reservation eligibility loss refunds stock')
 a:SetAttribute('RaceChargeMissile',1);a:SetAttribute('RaceChargeMissile',0);drain()
 check(profiles[S.userKey(a.UserId)].shopInventory.counts.Missile==2,'service refund cannot be repeated')
 -- In another user's round slot, failed transient grant compensates finalized stock.
 applyOk=false;b:SetAttribute('RaceChargeShield',0);drain();applyOk=true
 profile=profiles[S.userKey(b.UserId)];receipt=profile.receipts['shop-refill:'..guid..':Shield']
 check(receipt and receipt.refunded and receipt.refill.state=='DELIVERED' and profile.shopInventory.counts.Shield==2,'service finalized-but-unused compensation')
end
-- Real controller eligibility and EconomyService, not a copied criteria function.
ca.chassis.AssemblyLinearVelocity=V.new(0,0,20);a:SetAttribute('RaceCompletedLaps',1)
ca.kart:SetAttribute('KartOffTrack',false);session.participants[a].offTrackElapsed=0
session.participants[a]:timeoutRace()
check(a:GetAttribute('RaceState')=='DNF' and #jobs==1,'active DNF queues existing reward '..MODE)
local rewardJob=table.remove(jobs,1)
-- Simulate a newer round arriving before the accepted asynchronous write runs.
a:SetAttribute('OfficialRoundGuid','12345678-1234-1234-1234-999999999999')
a:SetAttribute('OfficialRoundIssuedAt',issued+1000);a:SetAttribute('RaceMoneyState','NEW_ROUND_SENTINEL')
lostAck=true;rewardJob()
local profile=profiles[S.userKey(a.UserId)]
check(profile.wallet.cash==11500 and profile.wallet.lifetimeEarned==1500,'existing active DNF 1500 survives '..MODE)
check(profile.receipts['dnf:'..guid] and profile.receipts['dnf:'..guid].issuedAt==issued,'queued credit retained original identity '..MODE)
check(a:GetAttribute('RaceMoneyState')=='NEW_ROUND_SENTINEL','old credit does not overwrite new-round HUD '..MODE)
check(economy.creditReward(a,1500,'ACTIVE_DNF_COMPLETION',{RoundGuid=guid,IssuedAt=issued}) and profiles[S.userKey(a.UserId)].wallet.cash==11500,'service lost ACK/replay no double reward '..MODE)
cb.chassis.AssemblyLinearVelocity=V.zero;b:SetAttribute('RaceCompletedLaps',1);session.participants[b]:timeoutRace();drain()
check(profiles[S.userKey(b.UserId)].wallet.cash==10000,'inactive timeout still no reward '..MODE)
-- Actual rematch GO generates a new independent ID, preserving refill authority.
tick(.1);remote:Fire(a,'Rematch');remote:Fire(b,'Rematch');tick(.1)
if session.phase=='WAITING'then remote:Fire(a,'StartRace')end
tick(raceConfig.COUNTDOWN_SECONDS+.1)
check(session.phase=='RACING' and a:GetAttribute('OfficialRoundGuid')~=guid and guidCalls==2,'rematch rotates server identity '..MODE)
check(a:GetAttribute('OfficialRoundIssuedAt')>issued,'rematch time newly issued '..MODE)
print('PASS '..count..' actual controller/economy/shop integration checks '..MODE)
]]
for _,mode in (ONLY_MODE and {ONLY_MODE} or {'MISSING','LOAD_FAILURE','BEGIN_FAILURE','NORMAL','LEGACY_OPT_IN'}) do
 luau.load(prefix..setup,{debugName='P0-exception-'..mode,environment={MODE=mode,CONFIG_LOADER=require('./helpers/gameplay_config'),CONTROLLER_OVERRIDE=CONTROLLER_OVERRIDE}})()
end
