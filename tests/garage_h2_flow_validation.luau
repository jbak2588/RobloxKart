local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local n=0;local function check(v,s) assert(v,s);n+=1 end
local catalog=luau.load(fs.readFile('src/shared/KartCatalog.luau'),{environment={Color3=rb.Color3,Enum=rb.Enum}})()
local source=fs.readFile('src/server/GarageController.luau')
local handler=assert(source:match('remote.OnServerEvent:Connect%((function%(player: Player, action: unknown, first: unknown, second: unknown, third: unknown%).-)\n\tend%)'))..'\nend'
local role='HUB';local players={};local replies={};local launches={};local pending={}
local remote={FireClient=function(_,p,action,id) table.insert(replies,{p,action,id}) end}
local route=luau.load('return '..handler,{environment={Workspace={GetAttribute=function() return role end},Players=players,KartCatalog=catalog,readyPending=pending,remote=remote,
 ready=function(p,driver,kart,track) table.insert(launches,{p,driver,kart,track}) end}})()
local function player(id)
 local attrs={RaceState='GARAGE',SelectedKartId=id};return {Parent=players,GetAttribute=function(_,k) return attrs[k] end,SetAttribute=function(_,k,v) attrs[k]=v end},attrs
end
local a,aa=player('Kart05');local b,ba=player('Kart06')
route(a,'SelectKart','Kart08');check(aa.SelectedKartId=='Kart08' and ba.SelectedKartId=='Kart06','independent server-owned selection')
check(replies[#replies][2]=='KartSelected' and replies[#replies][3]=='Kart08','accepted ack')
for _,bad in {'FakeKart',false,{},123} do route(a,'SelectKart',bad);check(aa.SelectedKartId=='Kart08' and replies[#replies][2]=='KartSelectionRejected','reject malformed/unknown') end
for _,state in {'RACING','PRE_RACE','FINISHED'} do aa.RaceState=state;route(a,'SelectKart','Kart06');check(aa.SelectedKartId=='Kart08','race state guarded') end
aa.RaceState='GARAGE';aa.KDMRoutePending='RACE_LAUNCH';route(a,'SelectKart','Kart06');check(aa.SelectedKartId=='Kart08','launch lock')
aa.KDMRoutePending=nil;pending[a]=true;route(a,'SelectKart','Kart06');check(aa.SelectedKartId=='Kart08','pending request lock');pending[a]=nil
role='RACE';route(a,'SelectKart','Kart06');check(aa.SelectedKartId=='Kart08','role isolation');role='HUB'
route(a,'Ready','Driver01','Kart06','Track03');check(launches[1][3]=='Kart08','race ignores uncommitted/malicious Kart argument')
route(b,'Ready','Driver01','Kart08','Track01');check(launches[2][3]=='Kart06','second player committed race choice')
local families={};local seen={}
for _,id in catalog.Order do
 local entry=catalog.Entries[id];check(entry.Id==id and not seen[id],'real catalog variant');seen[id]=true
 check(typeof(entry.DisplayColor)=='Color3' and type(entry.DisplayColorName)=='string','chip metadata only')
 families[entry.VisualModelName]=(families[entry.VisualModelName] or 0)+1
end
check(families.KDMV2==7 and families.SprintV1==4,'two actual chassis / eleven valid variants')
-- UI navigation, draft cancellation, actual confirm ack and responsive targets execute in garage_transition_validation.
check(source:find('player:SetAttribute("SelectedKartId", KartCatalog.DefaultId)',1,true),'new session uses existing default')
print('Garage H2 server flow / catalog validation PASS: '..n..' checks')
