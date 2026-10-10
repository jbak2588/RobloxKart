local fs,luau,serde,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/serde'),require('@lune/roblox')
local function load(path,env) return luau.load(fs.readFile(path),{debugName=path,environment=env or {}})() end
local S=load('src/shared/KDMProgressionSchema.luau')
local Ops=load('src/server/ProgressionOperations.luau')
local Store=load('src/server/ProgressionMockStore.luau')
local Service=load('src/server/PlayerProgressionService.luau')
local catalog=load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum})
local schema=S.new(catalog)
local checks,rows,serial=0,{},0
local function check(v,label) checks+=1;assert(v,label) end
local function player(id)
 local p={UserId=id,attrs={RaceState='GARAGE'}}
 function p:SetAttribute(k,v) self.attrs[k]=v end
 function p:GetAttribute(k) return self.attrs[k] end
 return p
end
local function profile(id,kart,revision)
 local p=schema.default(id);p.selection.kartId=kart;p.selection.revision=revision or 0;return p
end
local function fixture(initial,queue)
 local store=Store.new(S,schema,initial)
 local service=Service.new({mode='MOCK',tools=S,schema=schema,operations=Ops,store=store,
  schedule=if queue then function(f) table.insert(queue,f) end else nil,
  newOperationId=function() serial+=1;return 'a2-operation-'..serial end})
 return service,store
end
local function case(id,label,fn)
 local before=checks;local ok,err=pcall(fn)
 table.insert(rows,{id=id,label=label,status=if ok then 'PASS' else 'FAIL',checks=checks-before,error=if ok then nil else tostring(err)})
 print(id..' '..(if ok then 'PASS ' else 'FAIL ')..label)
end
case('T01','ABSENT displays Kart05 without implicit write',function()
 local a,store=fixture({});local p=player(1);a.bind(p)
 check(p.attrs.SelectedKartId=='Kart05' and a.inspect(p).state=='READY','new default not saved')
 check(store.stats().commits==0 and store.snapshot()['u:1']==nil,'no default overwrite')
 a.select(p,'Kart07');check(store.snapshot()['u:1'].selection.kartId=='Kart07','explicit first save')
end)
case('T02','FOUND restores and service recreation reuses Mock backend',function()
 local a,store=fixture({['u:1']=profile(1,'Kart07',4)});local p=player(1);a.bind(p)
 check(p.attrs.SelectedKartId=='Kart07' and a.inspect(p).state=='SAVED','restore persisted selection')
 a.remove(p);local b=Service.new({mode='MOCK',tools=S,schema=schema,operations=Ops,store=store,newOperationId=function() return 'restart' end})
 local rejoin=player(1);b.bind(rejoin);check(rejoin.attrs.SelectedKartId=='Kart07','recreated service restore')
end)
case('T03','Tracks/Race uses restored selection with no Garage selection',function()
 local a=fixture({['u:1']=profile(1,'Kart07')});local p=player(1);a.bind(p)
 check(a.selection(p,'Kart05')=='Kart07' and a.inspect(p).generation==0,'no select call required')
 local ui=fs.readFile('src/client/GarageUiController.luau')
 check(ui:find('else committedKartId()',1,true) and ui:find('step = if action == "TRACK"',1,true),'existing direct Tracks uses committed attribute')
end)
case('T04','session ACK precedes delayed save confirmation',function()
 local queue={};local a,store=fixture({['u:1']=profile(1,'Kart07')},queue);local p=player(1);a.bind(p);a.select(p,'Kart09')
 check(p.attrs.SelectedKartId=='Kart09' and p.attrs.KartSaveState=='SAVE_PENDING','applied not saved')
 check(store.snapshot()['u:1'].selection.kartId=='Kart07','old durable choice before callback')
 queue[1]();check(p.attrs.KartSaveState=='SAVE_CONFIRMED' and store.snapshot()['u:1'].selection.kartId=='Kart09','read-back receipt confirmed')
end)
case('T05','delayed load cannot overwrite newer explicit choice',function()
 local a,store=fixture({['u:1']=profile(1,'Kart05',8)});store.inject({delayRead=true});local p=player(1);a.bind(p);a.select(p,'Kart07');a.loadTimeout(p)
 check(p.attrs.SelectedKartId=='Kart07' and p.attrs.KartSaveState=='SAVE_PENDING','fallback never claims saved')
 store.inject({});a.completeLoad(p)
 check(p.attrs.SelectedKartId=='Kart07' and store.snapshot()['u:1'].selection.revision==9,'CAS after late load retains intent')
end)
case('T06','write/read failures preserve original profile',function()
 local a,store=fixture({['u:1']=profile(1,'Kart07')});local p=player(1);a.bind(p);store.inject({writeFail=true});a.select(p,'Kart09')
 check(p.attrs.KartSaveState~='SAVE_CONFIRMED' and store.snapshot()['u:1'].selection.kartId=='Kart07','failure preserves old record')
 local b,other=fixture({['u:2']=profile(2,'Kart09')});other.inject({readFail=true});local q=player(2);b.bind(q);b.select(q,'Kart07')
 check(q.attrs.SelectedKartId=='Kart07' and other.stats().commits==0,'session-only selection with unreadable profile')
 check(other.snapshot()['u:2'].selection.kartId=='Kart09' and q.attrs.KartSaveState=='READ_ONLY','no default overwrite or saved claim')
end)
case('T07','two servers reversed commit order protects newest CAS',function()
 local queue={};local a,store=fixture({['u:1']=profile(1,'Kart05')},queue)
 local b=Service.new({mode='MOCK',tools=S,schema=schema,operations=Ops,store=store,newOperationId=function() return 'server-b-09' end})
 local p,q=player(1),player(1);a.bind(p);b.bind(q);a.select(p,'Kart07');b.select(q,'Kart09');queue[1]()
 check(store.snapshot()['u:1'].selection.kartId=='Kart09','older callback cannot undo revision')
 check(a.inspect(p).state=='PENDING' and b.inspect(q).state=='SAVED','conflict pending not auto rebased')
 local operation=a.inspect(p).operation;a.flush(p)
 check(S.canonical(operation)==S.canonical(a.inspect(p).operation) and store.stats().commits==1,'retry same id preserves newer selection')
end)
case('T08','validated payload pins Reserved race while Hub restore remains separate',function()
 local shared={WaitForChild=function(_,name) return {Name=name} end}
 local modules={KartCatalog=catalog,DriverCatalog=load('src/shared/DriverCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum}),TrackCatalog=load('src/shared/TrackCatalog.luau',{CFrame=rb.CFrame})}
 local env={game={GetService=function(_,name) assert(name=='ReplicatedStorage');return {WaitForChild=function() return shared end} end},require=function(m) return modules[m.Name] end}
 local Payload=load('src/server/RaceLaunchPayload.luau',env);modules.RaceLaunchPayload=Payload
 env.script={Parent={WaitForChild=function(_,name) return {Name=name} end}}
 modules.RaceMode=load('src/shared/RaceMode.luau',{game=env.game,require=env.require,script={Parent=shared}})
 local Arrival=load('src/server/RaceArrivalPlan.luau',env)
 local a=fixture({['u:1']=profile(1,'Kart07')});local p=player(1);a.bind(p)
 local payload=Payload.buildMatch('a2-race-12345678','a2-room-12345678',{{userId=p.UserId,driverId=modules.DriverCatalog.DefaultId,kartId=a.selection(p,'Kart05')}},'Track02')
 check(Payload.validate(payload,false),'actual payload valid');a.select(p,'Kart09')
 local plan=Arrival.forPlayer(payload,1);check(plan.kartId=='Kart07','arrival pinned to departure not later profile')
 local race,store=fixture({['u:1']=profile(1,'Kart09')});local arrival=player(1);arrival.attrs.SelectedKartId=plan.kartId
 race.bind(arrival,{locked=true,kartId=plan.kartId});check(arrival.attrs.SelectedKartId=='Kart07' and not race.select(arrival,'Kart05'),'race profile cannot replace Kart')
 check(arrival.attrs.KartSaveState~='SAVE_CONFIRMED','different saved profile cannot confirm payload selection')
 race.remove(arrival);local hub=player(1);race.bind(hub);check(hub.attrs.SelectedKartId=='Kart09','Hub restores latest saved profile')
 check(store.stats().commits==0,'race arrival is not selection save')
end)
case('T09','ACK loss resolves by receipt; disconnected pending callback fenced',function()
 local a,store=fixture({['u:1']=profile(1,'Kart07')});local p=player(1);a.bind(p);store.inject({ackLoss=true});a.select(p,'Kart09')
 check(a.inspect(p).state=='SAVED' and store.stats().commits==1,'lost ACK read-back confirms one commit')
 a.remove(p);local q=player(1);a.bind(q);check(q.attrs.SelectedKartId=='Kart09','rejoin sees committed selection')
 local queue={};local b,other=fixture({['u:2']=profile(2,'Kart07')},queue);local r=player(2);b.bind(r);b.select(r,'Kart09');b.remove(r);queue[1]()
 check(other.snapshot()['u:2'].selection.kartId=='Kart07' and not b.inspect(r),'late callback cannot act after removal')
end)
case('A10','Test Drive Exit respawn uses same authoritative selection',function()
 local a=fixture({['u:1']=profile(1,'Kart07')});local p=player(1);a.bind(p)
 p.attrs.LobbyDriveActive=true;check(a.selection(p,'Kart05')=='Kart07','drive choice');p.attrs.LobbyDriveActive=false
 check(p.attrs.SelectedKartId=='Kart07','exit/respawn do not clear profile')
 local drive=fs.readFile('src/server/LobbyTestDriveService.luau');local hub=fs.readFile('src/client/HubUiController.luau')
 check(drive:find('Catalog.Entries[player:GetAttribute("SelectedKartId")',1,true),'real service reads selected attribute')
 check(hub:find('GetAttributeChangedSignal("SelectedKartId"):Connect(refreshDisplay)',1,true),'existing display auto refresh')
end)
case('A11','rapid changes cancel queued obsolete intent and deduplicate same request',function()
 local queue={};local a,store=fixture({['u:1']=profile(1,'Kart05')},queue);local p=player(1);a.bind(p);a.select(p,'Kart07');a.select(p,'Kart09');a.select(p,'Kart09')
 check(#queue==2 and a.inspect(p).generation==2,'same choice not new operation')
 queue[1]();queue[2]();check(store.snapshot()['u:1'].selection.kartId=='Kart09' and store.stats().commits==1,'latest queued intent only')
end)
case('A12','future corrupt deleted profiles quarantined',function()
 for _,kind in {'future','corrupt','deleted'} do
  local data=profile(1,'Kart07');if kind=='future' then data.schemaVersion=999 elseif kind=='corrupt' then data.selection.kartId='FakeKart' else data.deleted=true end
  local a,store=fixture({['u:1']=data});local p=player(1);a.bind(p);a.select(p,'Kart09')
  check(a.inspect(p).state=='READ_ONLY' and store.stats().commits==0,'quarantine '..kind)
  check(S.canonical(store.snapshot()['u:1'])==S.canonical(data),'raw preserved '..kind)
 end
end)
case('A13','shutdown fences callbacks and invalid selection rejected',function()
 local queue={};local a,store=fixture({['u:1']=profile(1,'Kart07')},queue);local p=player(1);a.bind(p)
 for _,id in {'FakeKart',false,17,{}} do check(not a.select(p,id),'invalid selection') end
 a.select(p,'Kart09');a.shutdown();queue[1]();check(store.stats().commits==0 and not a.inspect(p),'shutdown cleanup')
end)
case('A14','two three four human selection isolation and rematch',function()
 for count=2,4 do
  local a=fixture({});local group={}
  for id=1,count do local p=player(id);a.bind(p);a.select(p,if id%2==0 then 'Kart09' else 'Kart07');table.insert(group,p) end
  for id,p in group do check(a.selection(p,'Kart05')==(if id%2==0 then 'Kart09' else 'Kart07'),'individual racer choice');p.attrs.RaceState='PRE_RACE';p.attrs.RaceState='RACING';p.attrs.RaceState='FINISHED';p.attrs.RaceState='PRE_RACE';check(a.inspect(p).generation==1,'rematch no selection rewrite') end
 end
end)
case('A15','feature OFF and public Studio switch prohibition',function()
 local studio=false
 local binding=load('src/server/ProgressionRuntimeBinding.luau',{game={GetService=function(_,name) assert(name=='RunService');return {IsStudio=function() return studio end} end},task={delay=function() end}})
 check(binding.KDM_PROGRESS_KART_PERSISTENCE_ENABLED==false and not binding.enabled(),'default off')
 local p=player(1);check(not binding.bind(p) and binding.selection(p,'Kart07')=='Kart07' and not p.attrs.KartSaveState,'OFF no profile or UI work')
 local a=fixture({});check(not pcall(binding.installStudioMock,a),'live install rejected')
 studio=true;binding.installStudioMock(a);check(binding.enabled(),'trusted Studio injection only');binding.bind(p);binding.select(p,'Kart09');check(p.attrs.SelectedKartId=='Kart09','actual facade routes to mock');binding.shutdown();check(not binding.enabled(),'cleanup disables facade')
end)
case('A16','late load after race departure cannot replace pinned kart',function()
 for _,state in {'PRE_RACE','RACING','FINISHED','RACE_LAUNCH'} do
  local a,store=fixture({['u:1']=profile(1,'Kart07')});store.inject({delayRead=true});local p=player(1);a.bind(p)
  if state=='RACE_LAUNCH' then p.attrs.KDMRoutePending=state else p.attrs.RaceState=state end
  store.inject({});a.completeLoad(p)
  check(p.attrs.SelectedKartId=='Kart05' and a.selection(p,'Kart09')=='Kart05','departure choice preserved '..state)
  check(p.attrs.KartSaveState~='SAVE_CONFIRMED' and not a.select(p,'Kart09'),'no false confirmed selection or mid-race change '..state)
 end
end)
local passed=0;for _,row in rows do if row.status=='PASS' then passed+=1 end end
print('RESULT_JSON '..serde.encode('json',{rows=rows,passed=passed,total=#rows,checks=checks,liveDataStoreCalls=0,actualRejoin=false,serviceRecreation=true}))
assert(passed==#rows,'runtime validation failed')
