local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local function load(path,env) return luau.load(fs.readFile(path),{environment=env or {},debugName=path})() end
local S=load('src/shared/KDMProgressionSchema.luau')
local schema=S.new(load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum}))
local Ops=load('src/server/ProgressionOperations.luau')
local Adapter=load('src/server/ProgressionDataStoreAdapter.luau')
local Service=load('src/server/PlayerProgressionService.luau')
local Runtime=load('src/server/ProgressionLiveRuntime.luau')
local Policy=load('src/server/ProgressionCanaryPolicy.luau')
local Config=load('src/server/ProgressionCanaryConfig.luau')
local checks,rows,serial=0,{},0
local function check(ok,label) checks+=1;assert(ok,label) end
local function player(id)
 local p={UserId=id,attrs={RaceState='GARAGE'},writes=0}
 function p:SetAttribute(k,v) self.attrs[k]=v;self.writes+=1 end
 function p:GetAttribute(k) return self.attrs[k] end
 return p
end
local function profile(kart,revision)
 local p=schema.default(1);p.selection.kartId=kart or 'Kart07';p.selection.revision=revision or 2;return p
end
local function fixture(initial)
 local backend={value=S.clone(initial),reads=0,writes=0,lookups=0,authorized=true,budget=true,queue={},delays={}}
 function backend:GetAsync(key,options)
  check(key=='u:1' and options.UseCache==false,'uncached correct-key read');self.reads+=1
  if self.readFail then error('read failure') end
  return S.clone(self.value)
 end
 function backend:UpdateAsync(key,callback)
  self.writes+=1
  if self.writeFail then error('write failure') end
  local info={GetUserIds=function() return {1} end,GetMetadata=function() return {owner='preserved'} end}
  local nextValue,ids,meta=callback(S.clone(self.value),info)
  if self.replay then
   local again,ids2,meta2=callback(S.clone(self.value),info)
   check(S.canonical(nextValue)==S.canonical(again),'callback replay stable')
   nextValue,ids,meta=again,ids2,meta2
  end
  if nextValue then
   check(ids[1]==1 and meta.owner=='preserved','userIds and metadata retained');self.value=S.clone(nextValue)
  end
  if self.ackLost then error('response lost after commit') end
  return nextValue
 end
 local adapter=Adapter.new({schema=schema,key='u:1',authorize=function() return backend.authorized end,
  budget=function() return backend.budget end,getOptions=function() return {UseCache=false} end,
  getStore=function() backend.lookups+=1;return backend end})
 local dependencies={tools=S,schema=schema,operations=Ops,store=adapter,
  newOperationId=function() serial+=1;return 'a2l-'..serial end}
 local core=Service.new(setmetatable({mode='LIVE_CANARY',liveAuthorized=true},{__index=dependencies}))
 local p=player(1)
 return backend,adapter,core,p,dependencies
end
local function case(id,label,fn)
 local before=checks;local ok,err=pcall(fn)
 table.insert(rows,{id=id,label=label,status=if ok then 'PASS' else 'FAIL',checks=checks-before,error=if ok then nil else tostring(err)})
 print(id..' '..(if ok then 'PASS ' else 'FAIL ')..label)
end
case('L01','constructor and blocked user perform zero lookups',function()
 local b,a=fixture(nil);check(b.lookups==0,'lazy lookup');b.authorized=false
 check(a.read('u:1').status=='ERROR','unauthorized read blocked')
 check(a.commit(a.beginUpdate('u:1',function() return profile() end)).status=='PENDING','unauthorized write blocked')
 check(b.lookups==0 and b.reads==0 and b.writes==0,'zero access')
end)
case('L02','Canary OFF / Studio / Race / target / whitelist isolation',function()
 local ctx={isStudio=false,role='HUB',experienceId=10768420544,placeId=127925465904803,privateServerId=''}
 check(not Policy.allowed(Config,ctx,11700555357),'default OFF')
 local cfg=table.clone(Config);cfg.Enabled=true
 check(Policy.allowed(cfg,ctx,11700555357),'approved user only')
 for _,id in {1,11700555358,-1,'mozzy_hni'} do check(not Policy.allowed(cfg,ctx,id),'reject non-approved identity') end
 for key,value in {isStudio=true,role='RACE',experienceId=1,placeId=1,privateServerId='reserved'} do
  local wrong=table.clone(ctx);wrong[key]=value;check(not Policy.allowed(cfg,wrong,11700555357),'context blocked '..key)
 end
end)
case('L03','ABSENT defaults without creating record',function()
 local b,a,c,p=fixture(nil);c.bind(p)
 check(a.read('u:1').status=='ABSENT' and p.attrs.SelectedKartId=='Kart05','new account default')
 check(b.writes==0 and b.value==nil and p.attrs.KartSaveState~='SAVE_CONFIRMED','no implicit save')
 c.select(p,'Kart07');check(b.value.selection.kartId=='Kart07' and p.attrs.KartSaveState=='SAVE_CONFIRMED','explicit first selection durable')
end)
case('L04','FOUND restore then latest Kart09 persists',function()
 local b,a,c,p=fixture(profile());c.bind(p)
 check(p.attrs.SelectedKartId=='Kart07' and c.selection(p,'Kart05')=='Kart07','restored direct race selection')
 c.select(p,'Kart09');check(b.value.selection.kartId=='Kart09' and b.value.selection.revision==3,'latest choice')
 local q=player(1);c.remove(p);c.bind(q);check(q.attrs.SelectedKartId=='Kart09','reconnect same backend')
end)
case('L05','ERROR never becomes ABSENT or overwrites default',function()
 local b,a,c,p=fixture(profile());b.readFail=true;c.bind(p);c.select(p,'Kart09')
 check(a.read('u:1').status=='ERROR' and b.writes==0 and b.value.selection.kartId=='Kart07','read failure safe')
 check(p.attrs.KartSaveState~='SAVE_CONFIRMED','session ACK not save ACK')
end)
case('L06','FUTURE and CORRUPT block writes',function()
 for _,value in {{schemaVersion=2},{schemaVersion=0},{schemaVersion=1},'bad'} do
  local b,a,c,p=fixture(value);local expected=if type(value)=='table' and value.schemaVersion==2 then 'FUTURE' else 'CORRUPT'
  check(a.read('u:1').status==expected,'classification '..expected);c.bind(p);c.select(p,'Kart09')
  check(b.writes==0 and p.attrs.KartSaveState=='READ_ONLY','protected payload')
 end
end)
case('L07','two servers CAS and older late request cannot overwrite',function()
 local b,a,c,p,d=fixture(profile());c.bind(p)
 local other=Service.new(setmetatable({mode='LIVE_CANARY',liveAuthorized=true},{__index=d}));local q=player(1);other.bind(q)
 other.select(q,'Kart09');c.select(p,'Kart05')
 check(b.value.selection.kartId=='Kart09' and b.value.selection.revision==3,'winner preserved')
 check(p.attrs.KartSaveState~='SAVE_CONFIRMED' and c.inspect(p).reason=='CONFLICT','stale request not acknowledged')
end)
case('L08','callback replay increments revision once and preserves other fields',function()
 local initial=profile();initial.wallet.cash=57
 local b,a,c,p=fixture(initial);b.replay=true;c.bind(p);c.select(p,'Kart09')
 check(b.value.selection.revision==3 and b.value.wallet.cash==57,'field reducer preserves wallet')
 for _,key in {'records','cosmetics'} do check(S.canonical(b.value[key])==S.canonical(initial[key]),'preserves '..key) end
 check(S.count(b.value.receipts)==S.count(initial.receipts)+1,'one receipt')
end)
case('L09','lost successful write response confirmed by uncached receipt',function()
 local b,a,c,p=fixture(profile());c.bind(p);b.ackLost=true;c.select(p,'Kart09')
 check(b.value.selection.kartId=='Kart09' and p.attrs.KartSaveState=='SAVE_CONFIRMED','unknown response resolved by receipt')
 check(b.reads==2,'read-back after response loss')
end)
case('L10','write success but unavailable read remains pending',function()
 local b,a,c,p=fixture(profile());c.bind(p);b.readFail=true;c.select(p,'Kart09')
 check(b.value.selection.kartId=='Kart09' and p.attrs.KartSaveState~='SAVE_CONFIRMED','no false ACK')
 local op=c.inspect(p).operation.operationId;b.readFail=false;c.flush(p)
 check(p.attrs.KartSaveState=='SAVE_CONFIRMED' and b.value.selection.revision==3,'idempotent retry')
 check(b.value.selection.lastOpId==op,'same identity retry')
end)
case('L11','budget unavailable and write failure preserve durable selection',function()
 local b,a,c,p=fixture(profile());c.bind(p);b.budget=false;c.select(p,'Kart09')
 check(b.writes==0 and b.value.selection.kartId=='Kart07','budget gate')
 b.budget=true;b.writeFail=true;c.flush(p)
 check(b.value.selection.kartId=='Kart07' and p.attrs.KartSaveState~='SAVE_CONFIRMED','failure safe')
end)
case('L12','slow load cannot overwrite explicit selection or Race entry',function()
 local b,a,c,p,d=fixture(profile());local queue={}
 local asynchronous=Service.new(setmetatable({mode='LIVE_CANARY',liveAuthorized=true,loadSchedule=function(f) table.insert(queue,f) end},{__index=d}))
 asynchronous.bind(p);asynchronous.select(p,'Kart09');asynchronous.loadTimeout(p)
 check(p.attrs.SelectedKartId=='Kart09' and b.writes==0,'session fallback')
 p.attrs.RaceState='RACING';queue[1]()
 check(p.attrs.SelectedKartId=='Kart09' and b.value.selection.kartId=='Kart09','accepted prior intent saved without race mutation')
 check(not asynchronous.select(p,'Kart05'),'rematch/race selection locked')
end)
case('L13','late restore never changes launched Kart',function()
 local b,a,c,p,d=fixture(profile('Kart07'));local queue={}
 local asynchronous=Service.new(setmetatable({mode='LIVE_CANARY',liveAuthorized=true,loadSchedule=function(f) table.insert(queue,f) end},{__index=d}))
 asynchronous.bind(p);p.attrs.KDMRoutePending='RACE_LAUNCH';queue[1]()
 check(p.attrs.SelectedKartId=='Kart05' and p.attrs.KartSaveState~='SAVE_CONFIRMED','late load remains session-only')
 check(b.writes==0,'no default write on launch')
end)
case('L14','departing session drains accepted write without attribute writes',function()
 local b,a,c,p,d=fixture(profile());local queue={}
 local asynchronous=Service.new(setmetatable({mode='LIVE_CANARY',liveAuthorized=true,schedule=function(f) table.insert(queue,f) end},{__index=d}))
 asynchronous.bind(p);asynchronous.select(p,'Kart09');asynchronous.detach(p);local writes=p.writes;queue[1]()
 check(b.value.selection.kartId=='Kart09' and p.writes==writes,'save finishes during drain silently')
 asynchronous.remove(p);check(asynchronous.inspect(p)==nil,'session released')
end)
case('L15','bounded retries retain operation identity',function()
 local b,a,c,p,d=fixture(profile());local jobs,delays={},{}
 local cfg=table.clone(Config);cfg.RetryAttempts=3
 local r=Runtime.new({Service=Service,config=cfg,authorize=function() return true end,coreDependencies=d,
  spawn=function(f) table.insert(jobs,f) end,delay=function(seconds,f) table.insert(delays,{seconds=seconds,fn=f}) end,
  clock=os.clock,wait=function() end})
 r.bind(p);table.remove(jobs,1)();b.writeFail=true;r.select(p,'Kart09');table.remove(jobs,1)()
 local id=r.inspect(p).operation.operationId
 -- First delay is load timeout; remaining two are the bounded retry chain.
 table.remove(delays,1).fn();table.remove(delays,1).fn();table.remove(jobs,1)();table.remove(delays,1).fn();table.remove(jobs,1)()
 check(b.writes==3 and #delays==0 and r.inspect(p).operation.operationId==id,'three attempts same ID')
end)
case('L16','authorization revoked during callback cancels write',function()
 local b,a,c,p=fixture(profile());c.bind(p)
 local original=b.UpdateAsync
 function b:UpdateAsync(key,callback) self.authorized=false;return original(self,key,callback) end
 c.select(p,'Kart09');check(b.value.selection.kartId=='Kart07' and p.attrs.KartSaveState~='SAVE_CONFIRMED','revocation safe')
end)
case('L17','wrong user key and deleted profile protected',function()
 local initial=profile();initial.deleted=true
 local b,a,c,p=fixture(initial);check(a.read('u:2').status=='ERROR' and b.lookups==0,'wrong key blocked')
 c.bind(p);c.select(p,'Kart09');check(b.writes==0 and b.value.deleted,'deleted profile retained')
end)
case('L18','live integration stays server-only and preserves legacy preferences',function()
 local coordinator=fs.readFile('src/server/ProgressionLiveCoordinator.luau')
 check(coordinator:find('assert(authorize()',1,true) and coordinator:find('UseCache=false',1,true),'guard and uncached API')
 check(not coordinator:find('KDM_PlayerPrefs_v1',1,true),'legacy preference store untouched')
 local binding=load('src/server/ProgressionRuntimeBinding.luau')
 check(not binding.enabled(),'Studio API OFF / local default OFF')
 check(Config.StoreName=='KDM_PlayerProgress_v1' and Config.AllowedUserIds[11700555357],'confirmed identity/config')
end)
case('L19','actual Coordinator hierarchy / user isolation / runtime restore',function()
 local b,a,c,p=fixture(profile())
 local approved=11700555357;p.UserId=approved
 local cfg=table.clone(Config);cfg.Enabled=true
 local actualSchema={default=function(_) return schema.default(1) end,validate=function(value,_) return schema.validate(value,'u:1') end,
  supportsKart=schema.supportsKart,maxReceipts=schema.maxReceipts}
 local tools=table.clone(S);tools.userKey=function(_) return 'u:1' end
 local modules={ProgressionCanaryConfig=cfg,ProgressionCanaryPolicy=Policy,KDMProgressionSchema=tools,KartCatalog={},
  ProgressionOperations=Ops,ProgressionDataStoreAdapter=Adapter,PlayerProgressionService=Service,ProgressionLiveRuntime=Runtime}
 tools.new=function() return actualSchema end
 local parent=setmetatable({},{__index=function(_,key) return key end})
 local shared={WaitForChild=function(_,name) return name end}
 local jobs,delays,lookups={}, {},0
 local gameMock={GameId=cfg.ExperienceId,PlaceId=cfg.PlaceId,PrivateServerId=''}
 function gameMock:GetService(name)
  if name=='RunService' then return {IsStudio=function() return false end} end
  if name=='ReplicatedStorage' then return {WaitForChild=function(_,child) check(child=='Shared','real Rojo shared path');return shared end} end
  if name=='HttpService' then return {GenerateGUID=function() serial+=1;return 'coordinator-'..serial end} end
  if name=='DataStoreService' then
   lookups+=1
   return {GetRequestBudgetForRequestType=function() return 100 end,GetDataStore=function(_,name) check(name=='KDM_PlayerProgress_v1','correct store');return b end}
  end
  error('unexpected service '..name)
 end
 local coordinator=load('src/server/ProgressionLiveCoordinator.luau',{script={Parent=parent},game=gameMock,
  workspace={GetAttribute=function(_,name) check(name=='KDMServerRole','server role');return 'HUB' end},
  require=function(name) assert(modules[name],'unmapped module '..tostring(name));return modules[name] end,
  Instance={new=function(name) check(name=='DataStoreGetOptions','real uncached options');return {} end},
  Enum={DataStoreRequestType={StandardRead=9,StandardWrite=10}},
  task={spawn=function(f) table.insert(jobs,f) end,delay=function(_,f) table.insert(delays,f) end,wait=function() end}})
 local excluded=player(2);check(not coordinator.bind(excluded) and lookups==0,'excluded zero lookup')
 check(coordinator.select(excluded,'Kart09') and excluded.attrs.SelectedKartId=='Kart09' and lookups==0,'legacy excluded selection')
 check(coordinator.bind(p) and lookups==0,'asynchronous authorized bind');table.remove(jobs,1)()
 check(p.attrs.SelectedKartId=='Kart07','actual Coordinator restores')
 coordinator.select(p,'Kart09');table.remove(jobs,1)()
 check(p.attrs.KartSaveState=='SAVE_CONFIRMED' and coordinator.selection(p,'Kart05')=='Kart09','actual Coordinator ACK and race payload')
 local writes=b.writes;coordinator.remove(p);check(b.writes==writes,'departure does not create redundant save')
end)
case('L20','late load after departure emits no attributes or default write',function()
 local b,a,c,p,d=fixture(profile());local jobs,delays={},{}
 local r=Runtime.new({Service=Service,config=Config,authorize=function() return true end,coreDependencies=d,
  spawn=function(f) table.insert(jobs,f) end,delay=function(_,f) table.insert(delays,f) end,clock=os.clock,wait=function() end})
 r.bind(p);r.remove(p);local count=p.writes;table.remove(jobs,1)()
 check(p.writes==count and b.writes==0,'late restore ignores departing player')
end)
local failed=0;for _,row in rows do if row.status~='PASS' then failed+=1 end end
print('RESULT_JSON '..serde.encode('json',{scenarios=#rows,checks=checks,failed=failed,rows=rows,liveDataStoreCalls=0}))
assert(failed==0,'A2L validation failed')
