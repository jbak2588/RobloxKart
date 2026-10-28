local fs,luau,serde,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/serde'),require('@lune/roblox')
local function load(p,e)return luau.load(fs.readFile(p),{environment=e or {},debugName=p})()end
local S=load('src/shared/KDMProgressionSchema.luau')
local catalog=load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum})
local schema=S.new(catalog,{jsonEncode=function(p)return serde.encode('json',p)end})
local Ops=load('src/server/RaceRecordOperations.luau');local Adapter=load('src/server/ProgressionDataStoreAdapter.luau');local Runtime=load('src/server/RaceRecordRuntime.luau')
local n=0;local function check(v,s)n+=1;assert(v,s)end
local argument=require('@lune/process').args[1]
local original=if argument then serde.decode('json',fs.readFile(argument)) else schema.default(11700555357)
if not argument then original.selection.kartId='Kart08';original.wallet.cash=321;original.receipts.legacy={signature=string.rep('a',50000)} end
local id=original.userId;local before=S.canonical(original)
check(schema.validate(original,S.userKey(id)),'existing profile valid')
local backend={value=S.clone(original),writes=0}
function backend:GetAsync(_,opts)check(opts.UseCache==false,'uncached confirm');return S.clone(self.value)end
function backend:UpdateAsync(_,cb)
 local info={GetUserIds=function()return {id}end,GetMetadata=function()return {keep=true}end}
 local result,ids,meta=cb(S.clone(self.value),info)
 local replay=cb(S.clone(self.value),info);check(S.canonical(result)==S.canonical(replay),'UpdateAsync callback deterministic')
 check(ids[1]==id and meta.keep,'backend metadata preservation')
 self.writes+=1;if result then self.value=S.clone(result)end;return result
end
local p={UserId=id,attrs={}};function p:GetAttribute(k)return self.attrs[k]end;function p:SetAttribute(k,v)self.attrs[k]=v end
local runtime=Runtime.new(S,schema,Ops,{allowed=function(_,kind)return kind~='repair'end,spawn=function(f)f()end,delay=function(_,f)f()end,retryAttempts=3,
 adapter=function()return Adapter.new({schema=schema,key=S.userKey(id),authorize=function()return true end,budget=function()return true end,
 getOptions=function()return {UseCache=false}end,getStore=function()return backend end})end})
local scope,first,afterFirst
for i=1,6 do
 local guid=string.format('c12572a0-5ec0-403a-b5ef-%012d',i)
 local r=S.freezeRound({RoundGuid=guid,TrackId='Track01Race',GeometryId='PracticeCircuitV1',RulesetId='KDM_R8A3_RULES_V1',diagnostic=false,
 roster={{IsBot=false,UserId=id},{IsBot=false,UserId=11736539305},{IsBot=true,BotId='Bot01'}}})
 local total=120000+i*1000
 local op={kind='OFFICIAL_RECORD',round=r,userId=id,bestLapMilliseconds=60000,bestRaceBoosts=9,achievedAt=1791795600000+i,
 verification={serverAccepted=true,state='FINISHED',targetLaps=2,completedLaps=2,fullLapValid=true,provenance='FULL_ROUTE_V1',boostIdentity='SERVER_SERIAL_V1'},
 race={trackId=r.TrackId,geometryId=r.GeometryId,rulesetId=r.RulesetId,category=r.RaceCategory,recordScope=r.recordScope,targetLaps=2,roundGuid=guid,userId=id,
 totalMilliseconds=total,laps={60000,total-60000},finishPosition=2,startingHumans=2,startingBots=1,raceBoosts=9,finishedAt=1791795600000+i,
 eligible=true,reason='FULL_ROUTE_V1',serverAccepted=true,state='FINISHED',positionFinalized=true}}
 if i==1 then
  first=op;local nextValue=Ops.reduce(S,schema,op)(original)
  print('R3_TRACE capacity',#S.canonical(nextValue),#serde.encode('json',nextValue),schema.maxBytes)
  check(#S.canonical(original)*6>262144 and #S.canonical(nextValue)<#S.canonical(original),'large legacy profile compressed without the historical false capacity refusal')
  check(#serde.encode('json',nextValue)<schema.maxBytes,'actual JSON below unchanged limit')
 end
 p.attrs.OfficialRoundGuid=guid;check(runtime.submit(p,op),'official submit')
 check(p.attrs.RaceRecordSaveState=='SAVE_CONFIRMED','real receipt confirmation')
 scope=S.raceScope(r.recordScope,2);local entry=backend.value.records.races[scope]
 check(entry.bestRace.totalMilliseconds==121000,'slower Rematch retains BEST')
 check(entry.lastRace.totalMilliseconds==total,'new LAST advances')
 check(Ops.confirm(S,schema,{status='FOUND',value=backend.value},op)~=nil,'matching canonical receipt')
 local snapshot=S.canonical(backend.value);runtime.submit(p,op);check(S.canonical(backend.value)==snapshot,'duplicate finish idempotent')
 if i==1 then afterFirst=#serde.encode('json',backend.value)end
end
for k,v in original.receipts do check(S.signatureMatches(backend.value.receipts[k],v.signature),'old receipt replay identity preserved through signature compression')end
for k,v in original do if k~='records' and k~='receipts' and k~='pendingIndex' and k~='pendingRaceIndex' then check(S.canonical(backend.value[k])==S.canonical(v),'non-record fields '..k)end end
local corrupt=S.clone(original);corrupt.bad=0/0;local valid,reason=schema.validate(corrupt,S.userKey(id));check(not valid and reason=='NONFINITE_NUMBER','structural reason separate')
corrupt=S.clone(original);corrupt.bad=string.rep('a',schema.maxBytes+1);valid,reason=schema.validate(corrupt,S.userKey(id));check(not valid and reason=='PROFILE_CAPACITY','true byte limit enforced')
corrupt=S.clone(original);corrupt.bad=corrupt;valid,reason=schema.validate(corrupt,S.userKey(id));check(not valid and reason=='UNSAFE_STRUCTURE','cycle rejected')
local escaped=schema.default(id);escaped.extra=string.rep('\0"\\',1000);check(S.jsonByteBound(escaped)>=#serde.encode('json',escaped),'escaping bound conservative')
-- Public defaults must not create diagnostic GUI, subscribe, log or sample memory.
local connections=0
local services={Players={LocalPlayer={UserId=id}},RunService={IsStudio=function()return false end,Heartbeat={Connect=function()connections+=1 end}},
 Stats={},HttpService={},ReplicatedStorage={Shared={KDMPerformanceBuffer='buffer'}}}
local Buffer=load('src/shared/KDMPerformanceBuffer.luau')
local monitor=load('src/client/RacePerformanceMonitor.luau',{game={GameId=10768420544,PlaceId=127925465904803,ReplicatedStorage=services.ReplicatedStorage,GetService=function(_,k)return services[k]end},
 require=function()return Buffer end,workspace={GetAttribute=function()return nil end},warn=function()error('public logging')end,Instance={new=function()error('public debug UI')end}})
check(not monitor.active() and monitor.gaugeMode()=='ANALOG' and connections==0,'public monitor fully OFF and ANALOG')
monitor.metric('x',100);monitor.beginFrame(.2);monitor.updateDisplay();monitor.observe(nil,0,.2,100);check(monitor.summary().frames==0,'no public profiler work')
print('PASS: '..n..' P2C save/receipt/nonrecord preservation, byte-limit and public-OFF assertions')
if argument then fs.writeFile('artifacts/r8-perf-p2c/actual-profile-validation.json',serde.encode('json',{status='PASS',checks=n,beforeJsonBytes=#serde.encode('json',original),firstJsonBytes=afterFirst,finalJsonBytes=#serde.encode('json',backend.value),receiptsBefore=S.count(original.receipts),receiptsAfter=S.count(backend.value.receipts),additionalReset=false},true))end
