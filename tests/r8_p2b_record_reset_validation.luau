local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local S=luau.load(fs.readFile('src/shared/KDMProgressionSchema.luau'))()
local C=luau.load(fs.readFile('src/shared/KartCatalog.luau'),{environment={Color3=rb.Color3,Enum=rb.Enum}})()
local schema=S.new(C)
local Reset=luau.load(fs.readFile('src/server/RaceRecordReset.luau'))()
local n=0
local function check(v,label)n+=1;assert(v,label)end
local function fixture()
 local store={value=schema.default(11700555357),writes=0,backups=0}
 store.value.selection.kartId='Kart07';store.value.wallet.cash=123
 store.value.cosmetics.ownedPartIds.wheel=true
 store.value.receipts['race-record:old']={signature='race'}
 store.value.receipts['kart-selection']={signature='kart'}
 store.value.records.scoped['record:v1|old']={bestRaceBoosts=11,officialBoostLifetime=84}
 local deps={userId=11700555357,id='approved-reset',backupRef='private-ref',utcMs=function()return 1000 end,
  read=function()return S.clone(store.value)end,
  backup=function(value)store.backups+=1;store.backup=S.clone(value)end,
  readBackup=function()return if store.backupFail then nil else S.clone(store.backup)end,
  update=function(callback)
   if store.concurrent then store.value.selection.kartId='Kart09' end
   local nextValue=callback(S.clone(store.value))
   if nextValue then store.writes+=1;store.value=nextValue end
  end}
 return store,deps
end
local b,d=fixture();local old=S.clone(b.value)
check(Reset.run(S,schema,d)=='RESET_CONFIRMED','backup-verified reset confirmed by uncached read')
check(S.canonical(b.backup.profile)==S.canonical(old),'full prior snapshot retained privately')
check(next(b.value.records.scoped)==nil and b.value.receipts['race-record:old']==nil,'only personal records and record receipts removed')
check(b.value.selection.kartId=='Kart07' and b.value.wallet.cash==123 and b.value.cosmetics.ownedPartIds.wheel,'selection, cash and inventory preserved')
check(b.value.receipts['kart-selection'].signature=='kart','non-race receipts retained')
b.value.records.scoped['record:v1|new']={bestRaceBoosts=1}
check(Reset.run(S,schema,d)=='ALREADY_RESET' and b.value.records.scoped['record:v1|new']~=nil and b.writes==1,'future new races are never wiped again')
b,d=fixture();b.backupFail=true;old=S.canonical(b.value)
check(Reset.run(S,schema,d)=='BACKUP_UNCONFIRMED' and b.writes==0 and S.canonical(b.value)==old,'failed archive read-back cannot clear records')
b,d=fixture();b.concurrent=true
check(Reset.run(S,schema,d)=='RESET_CONFLICT' and b.writes==0 and b.value.selection.kartId=='Kart09','compare-and-swap protects concurrent selection')
b,d=fixture();b.value.schemaVersion=2
check(Reset.run(S,schema,d)=='PROFILE_PROTECTED' and b.backups==0 and b.writes==0,'future schema cannot be reset')
b,d=fixture();b.value.deleted=true
check(Reset.run(S,schema,d)=='PROFILE_PROTECTED' and b.writes==0,'deletion state protected')
b,d=fixture();b.value.wallet.cash=-1
check(Reset.run(S,schema,d)=='PROFILE_PROTECTED' and b.writes==0,'non-record corruption cannot trigger profile initialization')
b,d=fixture();b.value=nil
check(Reset.run(S,schema,d)=='ABSENT' and b.writes==0,'missing profile never recreated')
local service=fs.readFile('src/server/RaceRecordService.luau')
check(service:find("ctx.role=='HUB'",1,true) and service:find("ctx.isStudio==false",1,true) and service:find("player.UserId==Config.ResetUserId",1,true),'exact live public HUB account gate')
print('PASS: '..n..' one-shot backed-up record reset and profile preservation checks')
