-- Executes the current production bind/Remote/Room hooks with the real Mock adapter.
local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local function load(p,e) return luau.load(fs.readFile(p),{debugName=p,environment=e or {}})() end
local S=load('src/shared/KDMProgressionSchema.luau');local Ops=load('src/server/ProgressionOperations.luau')
local Store=load('src/server/ProgressionMockStore.luau');local Service=load('src/server/PlayerProgressionService.luau')
local catalog=load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum});local schema=S.new(catalog)
local checks=0;local function check(v,s) checks+=1;assert(v,s) end
local queue={};local sequence=0;local profile=schema.default(1);profile.selection.kartId='Kart07'
local store=Store.new(S,schema,{['u:1']=profile})
local runtime=Service.new({mode='MOCK',tools=S,schema=schema,operations=Ops,store=store,schedule=function(f) table.insert(queue,f) end,
 newOperationId=function() sequence+=1;return 'garage-mock-'..sequence end})
local Binding=load('src/server/ProgressionRuntimeBinding.luau',{game={GetService=function() return {IsStudio=function() return true end} end},task={delay=function() end}})
Binding.installStudioMock(runtime)
local function signal() return {Connect=function() return {Disconnect=function() end} end} end
local players={};local p={UserId=1,Parent=players,attrs={RaceState='GARAGE'},CharacterAdded=signal()}
function p:SetAttribute(k,v) self.attrs[k]=v end
function p:GetAttribute(k) return self.attrs[k] end
function p:GetAttributeChangedSignal() return signal() end
local source=fs.readFile('src/server/GarageController.luau')
local bindBody=assert(source:match('local function bindPlayer%(player: Player%)(.-)\n\tend'))
local bind=luau.load('return function(player)'..bindBody..'\nend',{environment={RaceMode={RACE='RACE'},DriverCatalog={DefaultId='Driver01'},KartCatalog=catalog,
 TrackCatalog={DefaultId='Track01'},spawnLocation={},progressionBinding=function() return Binding end,task={spawn=function() end,delay=function() end}}})()
bind(p);check(p.attrs.SelectedKartId=='Kart07' and p.attrs.KartSaveState=='SAVE_CONFIRMED','actual bind restores after default initialization')
local replies,launches,pending={},{},{}
local handler=assert(source:match('remote.OnServerEvent:Connect%((function%(player: Player, action: unknown, first: unknown, second: unknown, third: unknown%).-)\n\tend%)'))..'\nend'
local stopCount=0
local route=luau.load('return '..handler,{environment={Workspace={GetAttribute=function() return 'HUB' end},Players=players,KartCatalog=catalog,readyPending=pending,
 script={Parent={FindFirstChild=function(_,name) return if name=='ProgressionRuntimeBinding' then {Name=name} else nil end}},require=function() return Binding end,
 remote={FireClient=function(_,player,action,id) table.insert(replies,{action=action,id=id}) end},
 stopLobbyDrive=function(player) player.attrs.LobbyDriveActive=false;stopCount+=1 end,
 ready=function(player,driver,kart,track) table.insert(launches,{kartId=kart,trackId=track}) end}})()
p.attrs.LobbyDriveActive=true;route(p,'SelectKart','Kart09')
check(stopCount==1 and p.attrs.SelectedKartId=='Kart09','real handler stops drive and applies choice')
check(replies[#replies].action=='KartSelected' and p.attrs.KartSaveState=='SAVE_PENDING','session reply separated from pending persistence')
route(p,'Ready','Driver01','Kart05','Track02');check(launches[1].kartId=='Kart09','fast Ready ignores stale client kart before save ACK')
queue[1]();check(p.attrs.KartSaveState=='SAVE_CONFIRMED','later read-back confirms saved choice')
local generation=p.attrs.KartSelectionGeneration;route(p,'SelectKart','Kart09')
check(p.attrs.KartSelectionGeneration==generation and #queue==1,'same selection does not duplicate operation')
for _,state in {'RACING','PRE_RACE','FINISHED'} do p.attrs.RaceState=state;route(p,'SelectKart','Kart07');check(replies[#replies].action=='KartSelectionRejected','existing state gate '..state) end
p.attrs.RaceState='GARAGE';p.attrs.KDMRoutePending='RACE_LAUNCH';route(p,'SelectKart','Kart07');check(p.attrs.SelectedKartId=='Kart09','route lock retained');p.attrs.KDMRoutePending=nil
store.inject({writeFail=true});route(p,'SelectKart','Kart07');queue[2]()
check(replies[#replies].action=='KartSelected' and p.attrs.KartSaveState~='SAVE_CONFIRMED','failure retains applied session ACK')
check(store.snapshot()['u:1'].selection.kartId=='Kart09','previous saved record untouched')
local selected={};local room=fs.readFile('src/server/MatchRoomService.luau')
local choose=assert(room:match('local function choose%(player, driverId, kartId, trackId%)(.-)\nend'))
local env={script={Parent={FindFirstChild=function() return {} end}},require=function() return Binding end,publicTrack=function() return true end,
 DriverCatalog={Entries={Driver01={}}},KartCatalog=catalog,selections=selected}
local chooser=luau.load('return function(player,driverId,kartId,trackId)'..choose..'\nend',{environment=env})()
check(chooser(p,'Driver01','Kart05','Track02') and selected[1].kartId=='Kart07','actual Browse selects server session choice')
local memberBody=assert(room:match('local function memberFor%(player, priority%)(.-)\nend'))
env.game={JobId='a2-hub'};env.DateTime={now=function() return {UnixTimestampMillis=1} end};env.HttpService={GenerateGUID=function() return 'admission-test' end}
local memberFor=luau.load('return function(player,priority)'..memberBody..'\nend',{environment=env})()
route(p,'SelectKart','Kart08');local member=memberFor(p,3)
check(member.kartId=='Kart08','Create/Join refresh selection even after Browse snapshot')
Binding.remove(p);queue[3]();check(not runtime.inspect(p) and store.snapshot()['u:1'].selection.kartId=='Kart09','PlayerRemoving fences pending save')
Binding.shutdown();check(not Binding.enabled(),'shutdown resets test runtime')
print('PASS: '..checks..' actual current Garage / Room hook integration checks')
