local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local function load(path,env)return luau.load(fs.readFile(path),{environment=env or {},debugName=path})()end
local S=load('src/shared/KDMProgressionSchema.luau')
local catalog=load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum})
local schema=S.new(catalog)
local config=load('src/server/EconomyConfig.luau')
local modules={KDMShopCatalog=load("src/shared/KDMShopCatalog.luau"),KDMProgressionSchema=S,KartCatalog=catalog,EconomyConfig=config,EconomyPolicy=load('src/server/EconomyPolicy.luau'),
 EconomyOperations=load('src/server/EconomyOperations.luau'),ProgressionDataStoreAdapter={},RaceRecordOperations=load('src/server/RaceRecordOperations.luau')}
local function node(name)return setmetatable({Name=name},{__index=function(_,id)return node(id)end})end
local rs={WaitForChild=function(_,id)return node(id)end}
local env={game={GetService=function(_,name)
 if name=='ReplicatedStorage'then return rs elseif name=='RunService'then return {IsStudio=function()return true end}
 elseif name=='HttpService'then return {JSONEncode=function(_,v)return serde.encode('json',v)end}end;error(name)end},
 workspace={GetAttribute=function()return 'HUB'end},script={Parent=node('Server')},require=function(id)return assert(modules[id.Name],id.Name)end,
 DateTime={now=function()return {UnixTimestampMillis=1792380000000}end},task={wait=function()end}}
local Economy=load('src/server/EconomyService.luau',env)
local function player(id)
 local attrs={SelectedKartId='Kart09'}
 return {UserId=id,GetAttribute=function(_,key)return attrs[key]end,SetAttribute=function(_,key,v)attrs[key]=v end}
end
local checks=0;local function check(v,message)assert(v,message);checks+=1 end
local p=player(1);local a=Economy.accountAdapter(p,'read');local writes=0;local commit=a.commit
a.commit=function(tx)writes+=1;return commit(tx)end
for _=1,8 do check(Economy.getProfile(p).status=='GUEST','read-only guest')end
check(writes==0 and a.read('u:1').status=='ABSENT' and p:GetAttribute('KDMWalletCash')==0,'bounce creates no key and grants no cash')
check(Economy.qualifyActivity(p,'TEST_DRIVE',{complete=true,movingMilliseconds=29000,distance=1000}).status=='INVALID_ACTIVITY','under-time proof rejected')
check(Economy.qualifyActivity(p,'TEST_DRIVE',{complete=true,movingMilliseconds=60000,distance=200}).status=='INVALID_ACTIVITY','under-distance rejected')
check(writes==0,'invalid activity never writes')
local proof={complete=true,movingMilliseconds=60000,distance=1000}
check(Economy.qualifyActivity(p,'TEST_DRIVE',proof).status=='INVALID_ACTIVITY'and writes==0,'retired completed drive proof cannot grant or initialize')
check(schema.default(1).wallet.cash==0,'new accounts have no implicit starter cash')
local lap={id='12345678-1234-1234-1234-000000000001',userId=1,milliseconds=140000,bestLapMilliseconds=69000,proofVersion=2,completedLaps=2,completedCheckpoints=12,valid=true,rewardMultiplier=1}
local saved,status=modules.EconomyOperations.parkLap(S,schema,lap)(nil)
check(status=='PARK_LAP_CREDITED'and saved.wallet.cash==5000,'first verified two-lap finish pays total5000')
local duplicate,why=modules.EconomyOperations.parkLap(S,schema,lap)(saved)
check(why=='REPLAY'and duplicate.wallet.cash==5000,'duplicate ACK cannot mint another finish reward')
local invalid=S.clone(lap);invalid.valid=false
check(modules.EconomyOperations.parkLap(S,schema,invalid)(nil)==nil,'invalid finish does not create account')
local old=schema.default(2);old.wallet.cash=22640;old.cosmetics.ownedPartIds.KDM_V2_WING=true
lap.userId=2
local paid=modules.EconomyOperations.parkLap(S,schema,lap)(old)
check(paid.wallet.cash==27640 and paid.cosmetics.ownedPartIds.KDM_V2_WING,'old cash and purchases preserved plus exact finish reward')
local Q=load('src/server/TestDriveQualification.luau');local q=Q.new()
check(not Q.step(q,60,1000,0,true)and Q.proof(q)==nil,'legacy compatibility module cannot qualify')
local source=fs.readFile('tests/r8_a4_economy_validation.luau')
local operation=assert(source:match('(local function guid.-)local original=')):gsub("check%([^\n]+\n",'')
local make=luau.load(operation..'\nreturn op',{environment={S=S}})()
check(Economy.qualifyActivity(p,'RACE_FINISH',make(8001,1,1,1)).cash==0,'official account initialization alone grants no starter money')
check(a.read('u:1').value.activity.starterGranted==false,'official initialization records no starter grant')
print('PASS '..checks..' finish-only account and retired activity reward checks')
local Store=load('src/server/ProgressionMockStore.luau')
local Core=load('src/server/PlayerProgressionService.luau')
local Ops=load('src/server/ProgressionOperations.luau')
local store=Store.new(S,schema,{})
local selection=Core.new({mode='MOCK',initializeAbsent=false,tools=S,schema=schema,operations=Ops,store=store,newOperationId=function()return 'qualified-selection' end})
local guest=player(1);selection.bind(guest);selection.select(guest,'Kart07');selection.flush(guest)
check(store.stats().commits==0 and store.snapshot()['u:1']==nil,'guest kart selection creates no permanent profile')
store.commit(store.beginUpdate('u:1',function()return S.clone(saved),'QUALIFIED' end));guest:SetAttribute('KDMAccountQualified',true)
selection.select(guest,'Kart09');selection.flush(guest)
check(store.snapshot()['u:1'].selection.kartId=='Kart09','selection can persist after activity account exists')
check(store.snapshot()['u:1'].wallet.cash==5000 and store.snapshot()['u:1'].activity==nil,'post-qualification selection preserves wallet and activity')
print('PASS '..checks..' total activity-gated account checks')
