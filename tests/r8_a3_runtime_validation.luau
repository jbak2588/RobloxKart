local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local function load(p,env) return luau.load(fs.readFile(p),{environment=env or {},debugName=p})() end
local S=load('src/shared/KDMProgressionSchema.luau');local catalog=load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum})
local schema=S.new(catalog);local Ops=load('src/server/RaceRecordOperations.luau')
local Adapter=load('src/server/ProgressionDataStoreAdapter.luau');local Runtime=load('src/server/RaceRecordRuntime.luau')
local count=0
local function check(value,label) count+=1;assert(value,label) end
local guid='12345678-1234-1234-1234-123456789012'
local function operation(id)
 return {kind='OFFICIAL_RECORD',userId=1,round=S.freezeRound({RoundGuid=id or guid,TrackId='Track02',GeometryId='PrototypeCircuitV2B',
  RulesetId='KDM_R8A3_RULES_V1',diagnostic=false,roster={{IsBot=false,UserId=1}}}),bestLapMilliseconds=45000,bestRaceBoosts=9,
  achievedAt=1791650000000,verification={state='FINISHED',serverAccepted=true,targetLaps=2,completedLaps=2,
   fullLapValid=true,provenance='FULL_ROUTE_V1',boostIdentity='SERVER_SERIAL_V1'}}
end
local function fixture()
 local p={UserId=1,attrs={OfficialRoundGuid=guid}}
 function p:GetAttribute(k) return self.attrs[k] end
 function p:SetAttribute(k,v) self.attrs[k]=v end
 local backend={value=schema.default(1),reads=0,writes=0,lookups=0,indexCalls=0,allow=true,spawn={},delay={},indices={}}
 backend.value.selection.kartId='Kart07'
 function backend:GetAsync(key,opts)
  check(key=='u:1' and opts.UseCache==false,'uncached receipt verification')
  self.reads+=1;if self.readFail then error('read offline') end
  if self.failReadAfterWrite and self.writes>0 then error('confirmation unavailable') end
  return S.clone(self.value)
 end
 function backend:UpdateAsync(key,cb)
  self.writes+=1;if self.writeFail then error('write offline') end
  if self.racingSelection then self.value.selection={kartId='Kart09',revision=12,lastOpId='other-server'} end
  local info={GetUserIds=function() return {1} end,GetMetadata=function() return {preserved=true} end}
  local nextValue,ids,meta=cb(S.clone(self.value),info)
  if self.callbackReplay then local again=cb(S.clone(self.value),info);check(S.canonical(again)==S.canonical(nextValue),'replayed callback stable') end
  if nextValue then check(ids[1]==1 and meta.preserved,'platform metadata retained');self.value=S.clone(nextValue) end
  if self.ackLost then error('ACK lost after write') end
  return nextValue
 end
 local deps={allowed=function() return backend.allow end,retryAttempts=3,shutdownSeconds=1,
  clock=function() return 0 end,wait=function() error('unexpected wait') end,
  spawn=function(f) table.insert(backend.spawn,f) end,delay=function(_,f) table.insert(backend.delay,f) end,
  diagnostic=function() end,
  adapter=function()
   return Adapter.new({schema=schema,key='u:1',authorize=function() return backend.allow end,budget=function() return not backend.noBudget end,
    getOptions=function() return {UseCache=false} end,getStore=function() backend.lookups+=1;return backend end})
  end,
  index=function(_,entry)
   backend.indexCalls+=1
   if backend.indexFail then return false end
   local k=entry.geometryId..entry.category;local old=backend.indices[k] or {}
   backend.indices[k]={lap=if old.lap then math.min(old.lap,entry.lap) else entry.lap,
    boost=math.max(old.boost or 0,entry.boost)}
   return true
  end}
 local runtime=Runtime.new(S,schema,Ops,deps)
 local function drain()
  while #backend.spawn>0 do table.remove(backend.spawn,1)() end
  while #backend.delay>0 do table.remove(backend.delay,1)() end
 end
 return backend,p,runtime,drain
end
local b,p,r,drain=fixture();b.allow=false
check(not r.submit(p,operation()) and r.read(p).status=='ACCESS_BLOCKED' and b.lookups==0,'non-allowed zero API calls')
b,p,r,drain=fixture();b.callbackReplay=true;b.ackLost=true
check(r.submit(p,operation()) and p.attrs.RaceRecordSaveState=='SAVE_PENDING','session submit not save ACK')
drain();check(p.attrs.RaceRecordSaveState=='SAVE_CONFIRMED' and p.attrs.RaceRecordNewPB,'lost ACK confirmed uncached receipt')
local scope=operation().round.recordScope
check(b.value.records.scoped[scope].officialBoostLifetime==9 and next(b.value.pendingIndex)==nil,'idempotent record and repaired index')
check(r.submit(p,operation()),'duplicate accepted idempotently');drain()
check(b.value.records.scoped[scope].officialBoostLifetime==9,'duplicate finish does not increment twice')
b,p,r,drain=fixture();b.ackLost=true;b.failReadAfterWrite=true
r.submit(p,operation());table.remove(b.spawn,1)()
check(p.attrs.RaceRecordSaveState=='SAVE_PENDING' and not p.attrs.RaceRecordNewPB,'unconfirmed write never success')
b.failReadAfterWrite=false;drain();check(p.attrs.RaceRecordSaveState=='SAVE_CONFIRMED' and b.value.records.scoped[scope].officialBoostLifetime==9,'retry same op confirms exactly once')
b,p,r,drain=fixture();b.writeFail=true;r.submit(p,operation());drain()
check(p.attrs.RaceRecordSaveState=='SAVE_PENDING' and next(b.value.records.scoped)==nil and b.value.selection.kartId=='Kart07','write outage protects gameplay/profile')
b,p,r,drain=fixture();b.readFail=true;r.submit(p,operation());drain()
check(b.writes==0 and p.attrs.RaceRecordSaveState=='SAVE_PENDING','read outage cannot create default profile')
b,p,r,drain=fixture();b.value=nil;r.submit(p,operation());drain()
check(b.writes==0 and p.attrs.RaceRecordSaveState=='READ_ONLY','absent reserved profile stays absent')
b,p,r,drain=fixture();b.value.schemaVersion=2;r.submit(p,operation());drain()
check(b.writes==0 and p.attrs.RaceRecordSaveState=='READ_ONLY','future Profile no overwrite')
b,p,r,drain=fixture();b.noBudget=true;r.submit(p,operation());drain()
check(b.lookups==0 and p.attrs.RaceRecordSaveState=='SAVE_PENDING','budget starvation bounded zero lookup')
b,p,r,drain=fixture();b.racingSelection=true;r.submit(p,operation());drain()
check(b.value.selection.kartId=='Kart09' and b.value.selection.revision==12,'concurrent HUB selection latest retained')
b,p,r,drain=fixture();b.indexFail=true;r.submit(p,operation());drain()
check(p.attrs.RaceRecordSaveState=='SAVE_CONFIRMED' and b.value.pendingIndex[scope]~=nil,'index failure never rolls back confirmed Profile')
b.indexFail=false;local read=r.read(p)
check(read.status=='FOUND' and read.records.scoped[scope].bestLapMilliseconds==45000 and next(b.value.pendingIndex)==nil,'returning query repairs pending index')
b,p,r,drain=fixture();r.submit(p,operation());p.attrs.OfficialRoundGuid='12345678-1234-1234-1234-123456789013';drain()
check(p.attrs.RaceRecordSaveState=='SAVE_PENDING','old Round response cannot label new Round saved')
check(b.value.records.scoped[scope].officialBoostLifetime==9,'old Round still safely persists after departure/rematch')
local selectionOps=load('src/server/ProgressionOperations.luau')
local selected=selectionOps.selection(S,schema,1,{kind='SELECT_KART',kartId='Kart09',operationId='A2-followup',expectedSelectionRevision=b.value.selection.revision})(b.value)
check(selected and selected.records.scoped[scope].bestLapMilliseconds==45000 and selected.records.metadata[scope].lap.roundGuid==guid,'A2 subsequent select preserves A3 metadata')
print('PASS: '..count..' API-shape records runtime outage, replay, concurrent selection and index-repair checks')
