-- Mock backend only: public-player persistence without real DataStore access.
local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local function load(p,env)return luau.load(fs.readFile('src/'..p..'.luau'),{environment=env or {}})()end
local S=load('shared/KDMProgressionSchema')
local schema=S.new(load('shared/KartCatalog',{Color3=rb.Color3,Enum=rb.Enum}))
local Store=load('server/ProgressionMockStore');local Ops=load('server/ProgressionOperations');local Core=load('server/PlayerProgressionService')
local store=Store.new(S,schema,{})
local serial,n=0,0;local function check(v,m)assert(v,m);n+=1 end
local function player(id)
 local p={UserId=id,attrs={RaceState='GARAGE'}}
 function p:GetAttribute(k)return self.attrs[k]end
 function p:SetAttribute(k,v)self.attrs[k]=v end
 return p
end
local function service()
 return Core.new({mode='MOCK',initializeAbsent=true,tools=S,schema=schema,operations=Ops,store=store,
  newOperationId=function()serial+=1;return 'public-select-'..serial end})
end
local a=service();local p,q=player(12001),player(12002)
a.bind(p);a.bind(q)
check(store.stats().commits==0,'arrival never creates a profile or writes defaults')
a.select(p,'Kart07');a.select(q,'Kart09')
check(p.attrs.KartSaveState=='SAVE_CONFIRMED'and q.attrs.KartSaveState=='SAVE_CONFIRMED','explicit ordinary-user selection saves without activity qualification')
local snap=store.snapshot()
check(snap['u:12001'].selection.kartId=='Kart07'and snap['u:12002'].selection.kartId=='Kart09','separate per-user keys')
a.remove(p);a.remove(q)
local b=service();local rejoin=player(12001);b.bind(rejoin)
check(rejoin.attrs.SelectedKartId=='Kart07','fresh service/rejoin restores selected kart')
rejoin.attrs.RaceState='RACING'
check(not b.select(rejoin,'Kart10')and rejoin.attrs.SelectedKartId=='Kart07','race cannot change pinned kart')
rejoin.attrs.RaceState='GARAGE';b.select(rejoin,'Kart10');b.remove(rejoin)
local c=service();local again=player(12001);c.bind(again)
check(again.attrs.SelectedKartId=='Kart10','only explicit next choice replaces saved kart')
check(store.snapshot()['u:12002'].selection.kartId=='Kart09','other player unchanged')
local source=fs.readFile('src/server/ProgressionLiveCoordinator.luau')
check(source:find('initializeAbsent=true',1,true)~=nil,'production coordinator uses tested explicit-save contract')
print('PASS '..n..' public selection lifecycle checks; real DataStore calls ZERO')
