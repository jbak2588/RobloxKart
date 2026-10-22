local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local function load(path,env) return luau.load(fs.readFile(path),{environment=env or {}})() end
local Config=load('src/server/ProgressionCanaryConfig.luau')
local Policy=load('src/server/ProgressionCanaryPolicy.luau')
local Guidance=load('src/client/HubGuidanceState.luau')
local S=load('src/shared/KDMProgressionSchema.luau')
local catalog=load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum})
local schema=S.new(catalog)
local Store=load('src/server/ProgressionMockStore.luau')
local Ops=load('src/server/ProgressionOperations.luau')
local Service=load('src/server/PlayerProgressionService.luau')
local checks,rows,serial=0,{},0
local function check(v,message) checks+=1;assert(v,message) end
local function player()
 local p={UserId=11700555357,attrs={RaceState='GARAGE'}}
 function p:SetAttribute(k,v) self.attrs[k]=v end
 function p:GetAttribute(k) return self.attrs[k] end
 return p
end
local function fixture(found,queued)
 local p=player();local initial={}
 if found then local record=schema.default(p.UserId);record.selection.kartId='Kart07';initial[S.userKey(p.UserId)]=record end
 local store=Store.new(S,schema,initial);local queue,events={},{}
 local service=Service.new({mode='MOCK',tools=S,schema=schema,operations=Ops,store=store,
  newOperationId=function() serial+=1;return 'l1-'..serial end,
  loadSchedule=if queued then function(fn) table.insert(queue,fn) end else nil,
  diagnostic=function(_,event,value) table.insert(events,{event=event,value=value}) end})
 return p,service,store,queue,events
end
local function guidance(p,state)
 return Guidance.profileRestored(state,{completed=p.attrs.KartProfileLoadCompleted,result=p.attrs.KartProfileLoadResult,
  restored=p.attrs.KartRestorationConfirmed,restoredKartId=p.attrs.KartRestoredKartId,kartId=p.attrs.SelectedKartId,
  validKart=catalog.Entries[p.attrs.SelectedKartId]~=nil,saveState=p.attrs.KartSaveState})
end
local function has(events,name) for _,e in events do if e.event==name then return true end end;return false end
local function case(id,label,fn)
 local before=checks;local ok,err=pcall(fn);table.insert(rows,{id=id,label=label,status=if ok then 'PASS' else 'FAIL',checks=checks-before,error=if ok then nil else tostring(err)})
 print(id..' '..(if ok then 'PASS ' else 'FAIL ')..label)
end
case('P01','public rollout admits ordinary users in exact public HUB',function()
 local context={isStudio=false,role='HUB',experienceId=10768420544,placeId=127925465904803,privateServerId=''}
 check(Config.Enabled==true and Config.AllowAllUsers==true,'owner-approved public rollout')
 check(Policy.allowed(Config,context,11700555357),'approved identity')
 check(Policy.allowed(Config,context,11700555358),'ordinary users persist')
 local canary=table.clone(Config);canary.AllowAllUsers=false
 check(not Policy.allowed(canary,context,11700555358)and Policy.allowed(canary,context,11700555357),'canary-only rollback retained')
 for _,id in {0,-1,1.5,'11700555358'}do check(not Policy.allowed(Config,context,id),'invalid user rejected')end
 for key,value in {isStudio=true,role='RACE',experienceId=1,placeId=1,privateServerId='reserved'} do
  local wrong=table.clone(context);wrong[key]=value;check(not Policy.allowed(Config,wrong,11700555357),'denied '..key)
 end
end)
case('P02','FOUND Kart07 goes directly to Tracks without CHOOSE KART',function()
 local p,c=fixture(true);c.bind(p);local state=Guidance.new()
 check(p.attrs.SelectedKartId=='Kart07' and p.attrs.KartProfileLoadCompleted and p.attrs.KartProfileLoadResult=='FOUND','load evidence')
 check(guidance(p,state),'restore accepted')
 local view=Guidance.presentation(state,rb.Vector2.new(932,342),'GARAGE',false,'',false)
 check(view.action=='TRACKS' and view.button=='SELECT TRACK','returning guidance')
 check(p.attrs.KartRestoredKartId=='Kart07' and p.attrs.KartHubGuidanceAction=='TRACKS','server restore proof')
end)
case('P03','ABSENT preserves first-visit Garage guide and no default write',function()
 local p,c,store=fixture(false);c.bind(p);local state=Guidance.new()
 check(p.attrs.KartProfileLoadResult=='ABSENT' and not guidance(p,state),'no restore')
 check(Guidance.nextAction(state)=='GARAGE' and p.attrs.SelectedKartId=='Kart05','first visit')
 check(store.stats().commits==0,'no implicit default save')
end)
case('P04','ERROR never masquerades as returning saved user',function()
 local p,c,store=fixture(true);store.inject({readFail=true});c.bind(p);local state=Guidance.new()
 check(p.attrs.KartProfileLoadResult=='ERROR' and p.attrs.KartSaveState=='SAVE_FAILED','load error')
 check(not guidance(p,state) and Guidance.nextAction(state)=='GARAGE','error guide remains')
 c.select(p,'Kart09');check(store.stats().commits==0,'error no overwrite')
end)
case('P05','read-only corrupt/future blocks restore guidance',function()
 for _,record in {{schemaVersion=2},{schemaVersion=1}} do
  local p=player();local store=Store.new(S,schema,{[S.userKey(p.UserId)]=record})
  local c=Service.new({mode='MOCK',tools=S,schema=schema,operations=Ops,store=store,newOperationId=function() return 'blocked' end})
  c.bind(p);check(p.attrs.KartSaveState=='READ_ONLY' and not guidance(p,Guidance.new()),'quarantined')
 end
end)
case('P06','late load cannot skip Garage through an overwritten newer selection',function()
 local p,c,store,q=fixture(true,true);c.bind(p);c.select(p,'Kart09');q[1]()
 check(p.attrs.SelectedKartId=='Kart09' and not p.attrs.KartRestorationConfirmed,'latest choice remains')
 check(not guidance(p,Guidance.new()),'not a restore event')
 check(store.snapshot()[S.userKey(p.UserId)].selection.kartId=='Kart09','new choice saved')
end)
case('P07','fast Race entry pins session kart and does not invent restoration',function()
 local p,c,store,q=fixture(true,true);c.bind(p);p.attrs.KDMRoutePending='RACE_LAUNCH';q[1]()
 check(p.attrs.SelectedKartId=='Kart05' and not p.attrs.KartRestorationConfirmed,'launch cart pinned')
 check(not guidance(p,Guidance.new()) and p.attrs.KartSaveState~='SAVE_CONFIRMED','no false confirmation')
 check(store.stats().commits==0,'race fallback never overwrites profile')
end)
case('P08','Kart07 to09 keeps completed navigation and confirmed write',function()
 local p,c,store=fixture(true);c.bind(p);local state=Guidance.new();guidance(p,state);c.select(p,'Kart09')
 check(p.attrs.KartSaveState=='SAVE_CONFIRMED' and p.attrs.SelectedKartId=='Kart09','latest saved')
 check(not p.attrs.KartRestorationConfirmed and Guidance.nextAction(state)=='TRACKS','completed guidance stays completed')
 check(store.snapshot()[S.userKey(p.UserId)].selection.kartId=='Kart09','durable latest')
end)
case('P09','pending ACK and transport failure retain honest states/logs',function()
 local p,c,store,q,events=fixture(true);c.bind(p);store.inject({writeFail=true});c.select(p,'Kart09')
 check(p.attrs.KartSaveState~='SAVE_CONFIRMED' and has(events,'SAVE_FAILED') and has(events,'SAVE_PENDING'),'failure distinct')
 check(has(events,'PROFILE_FOUND') and has(events,'RESTORED_KART_ID') and has(events,'SESSION_APPLIED') and has(events,'HUB_GUIDANCE_ACTION'),'bounded diagnostics')
 for _,event in events do check(type(event.event)=='string' and (event.value==nil or type(event.value)=='string'),'no profile body') end
end)
case('P10','replication order requires full evidence, preserves room precedence/layout',function()
 local p,c=fixture(true);c.bind(p)
 for _,attribute in {'KartProfileLoadCompleted','KartProfileLoadResult','KartRestorationConfirmed','KartRestoredKartId','KartSaveState','SelectedKartId'} do
  local value=p.attrs[attribute];p.attrs[attribute]=nil;check(not guidance(p,Guidance.new()),'incomplete '..attribute);p.attrs[attribute]=value
 end
 local state=Guidance.new();Guidance.confirmed(state,'Track02');guidance(p,state);check(Guidance.nextAction(state)=='ROOMS','room priority')
 local before=Guidance.presentation(Guidance.new(),rb.Vector2.new(932,342),'GARAGE',false,'',false)
 local afterState=Guidance.new();guidance(p,afterState);local after=Guidance.presentation(afterState,rb.Vector2.new(932,342),'GARAGE',false,'',false)
 check(before.width==after.width and before.height==after.height and before.bottom==after.bottom,'layout unchanged')
end)
case('P11','actual Binding ON config still blocks Studio before Coordinator/service lookup',function()
 local lookups=0;local parent={ProgressionCanaryConfig='config',FindFirstChild=function() return true end}
 local binding=load('src/server/ProgressionRuntimeBinding.luau',{script={Parent=parent},game={GetService=function(_,name)
  check(name=='RunService','only Studio role service');return {IsStudio=function() return true end}
 end},require=function(module) check(module=='config','no coordinator/store lookup');lookups+=1;return Config end})
 check(not binding.enabled() and lookups==1,'Studio disabled with ON config')
end)
local failed=0;for _,row in rows do if row.status=='FAIL' then failed+=1 end end
print('RESULT_JSON '..serde.encode('json',{scenarios=#rows,checks=checks,failed=failed,rows=rows,liveDataStoreCalls=0}))
assert(failed==0,'L1 direct validation failed')
