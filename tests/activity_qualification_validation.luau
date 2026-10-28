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
local proof={complete=true,movingMilliseconds=30001,distance=500}
check(Economy.qualifyActivity(p,'TEST_DRIVE',proof).status=='FOUND','completed drive confirmed by read-back')
local saved=a.read('u:1').value
check(saved.wallet.cash==5000 and saved.activity.starterGranted and saved.activity.kind=='TEST_DRIVE','starter money and qualification saved together')
check(saved.selection.kartId=='Kart09' and schema.validate(saved,'u:1'),'temporary kart preserved in valid first profile')
local after=writes
check(Economy.qualifyActivity(p,'TEST_DRIVE',proof).cash==5000 and writes==after,'duplicate completion has no write or extra grant')
check(p:GetAttribute('KDMStarterRewardConfirmed')==true,'only confirmed starter grant publishes success')
local old=player(2);local oldProfile=schema.default(2);oldProfile.wallet.cash=22640;oldProfile.onboarding.welcomeSeen=true
oldProfile.cosmetics.ownedPartIds.KDM_V2_WING=true
commit(a.beginUpdate('u:2',function()return oldProfile end))
check(Economy.qualifyActivity(old,'TEST_DRIVE',proof).cash==22640,'existing cash never regranted')
check(a.read('u:2').value.cosmetics.ownedPartIds.KDM_V2_WING and not a.read('u:2').value.activity.starterGranted,'existing purchase preserved and tracked as no extra grant')
local read=a.read;a.read=function()return {status='ERROR'}end
local bad=player(3)
check(Economy.getProfile(bad).status=='ERROR' and Economy.qualifyActivity(bad,'TEST_DRIVE',proof).status=='ERROR','failed reads do not become absent')
check(writes==after+1,'failed reads never write')
a.read=read
-- Use the existing real server-verified operation fixture for the direct-to-race path.
local source=fs.readFile('tests/r8_a4_economy_validation.luau')
local operation=assert(source:match('(local function guid.-)local original='))
operation=operation:gsub("check%([^\n]+\n",'')
local make=luau.load(operation..'\nreturn op',{environment={S=S}})()
local raceP=player(1);local op=make(8001,1,1,1)
-- Separate user 1 context with an empty store demonstrates the race initializer.
local Economy2=load('src/server/EconomyService.luau',env)
check(Economy2.qualifyActivity(raceP,'RACE_FINISH',op).cash==5000,'direct valid race creates starter account')
local raceBad=player(4);local invalid=S.clone(op);invalid.userId=4
check(Economy2.qualifyActivity(raceBad,'RACE_FINISH',invalid).status=='INVALID_ACTIVITY','wrong-user/invalid race rejected')
local Q=load('src/server/TestDriveQualification.luau')
for _,dt in {1/30,1/60}do
 local q=Q.new();local x=0
 for _=1,math.ceil(40/dt)do Q.step(q,dt,x,0,true);x+=20*dt end
 check(q.complete and q.seconds>=30 and q.distance>=300,'real movement qualifies at both cadences')
end
local q=Q.new();for _=1,4000 do Q.step(q,.05,0,0,true)end
check(not q.complete and q.seconds==0,'idle sitting never qualifies')
q=Q.new();for n=1,1000 do Q.step(q,.05,n*1000,0,true)end
check(not q.complete and q.distance==0,'teleport distance ignored')
q=Q.new();for n=1,1000 do Q.step(q,.05,n,0,false)end
check(not q.complete,'invalid recovery/outside samples ignored')
print('PASS '..checks..' guest, qualification, starter grant, failure and movement checks')
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
check(store.snapshot()['u:1'].wallet.cash==5000 and store.snapshot()['u:1'].activity.kind=='TEST_DRIVE','post-qualification selection preserves wallet and activity')
print('PASS '..checks..' total activity-gated account checks')
