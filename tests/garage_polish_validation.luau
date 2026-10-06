local fs = require('@lune/fs')
local luau = require('@lune/luau')
local rb = require('@lune/roblox')
local checks = 0
local function check(value, label) assert(value, label); checks += 1 end
local catalog = luau.load(fs.readFile('src/shared/KartCatalog.luau'), {environment={Enum=rb.Enum,Color3=rb.Color3}})()
local preload = luau.load(fs.readFile('src/client/GarageTexturePreload.luau'),{environment={Instance=rb.Instance}})()
local expected = {'Kart05','Kart06','Kart07','Kart08','Kart09','Kart10','Kart11','Kart01','Kart02','Kart03','Kart04'}
for index,id in expected do check(catalog.Order[index]==id,'exact Garage order '..index) end
check(catalog.DefaultId=='Kart05','accepted Cyan default independent of browsing')
local index=1
for _=1,11 do index=(index-1+1+#catalog.Order)%#catalog.Order+1 end
check(catalog.Order[index]=='Kart05','eleven right choices return Cyan')
for _,id in {'Kart04','Kart03','Kart02','Kart01','Kart11','Kart10','Kart09','Kart08','Kart07','Kart06','Kart05'} do
 index=(index-1-1+#catalog.Order)%#catalog.Order+1
 check(catalog.Order[index]==id,'left reverse cycle')
end
local assets=preload.collect(catalog)
check(#assets==7,'exact seven V2 dependencies')
for i=1,7 do check(assets[i]==catalog.Entries[expected[i]].BodyTextureId,'catalog-derived texture') end
local function harness(provider)
 local worker, timeout, cancelled, calls = nil,nil,0,0
 local scheduler={spawn=function(fn) worker=fn end,delay=function(seconds,fn)
  check(seconds==12,'bounded timeout'); timeout=fn; return fn
 end,cancel=function() cancelled+=1 end}
 local gate=preload.create(catalog,provider,scheduler,function() calls+=1 end)
 check(gate.getState()=='NOT_STARTED','initial state')
 gate.start(); gate.start()
 check(gate.getState()=='LOADING','async loading')
 check(gate.shouldWait(catalog.Entries.Kart05),'V2 preview waits')
 check(not gate.shouldWait(catalog.Entries.Kart01),'V1 remains immediate')
 return gate,function() worker() end,function() timeout() end,function() return calls,cancelled end
end
local success={PreloadAsync=function(_,ids,callback)
 check(#ids==7,'request seven texture IDs')
 for i,mesh in ids do
  check(mesh:IsA('MeshPart') and mesh.TextureID==assets[i] and mesh.Parent==nil,'unparented exact texture dependency')
  callback(mesh.TextureID,{Name='Success'})
 end
end}
local gate,run,expire,stats=harness(success)
run(); check(gate.getState()=='READY' and not gate.shouldWait(catalog.Entries.Kart05),'success releases preview')
local calls,cancelled=stats(); check(calls==1 and cancelled==1,'one refresh and timer cleanup')
expire(); check(stats()==1,'stale timeout cannot refresh')
for _,provider in {{PreloadAsync=function() error('network') end},
 {PreloadAsync=function(_,_,callback) callback(assets[1],{Name='Failure'}) end}} do
 gate,run,expire,stats=harness(provider)
 run(); check(gate.getState()=='FAILED' and not gate.shouldWait(catalog.Entries.Kart05),'error/status lazy-load fallback')
 check(stats()==1,'failure refresh once')
end
gate,run,expire,stats=harness(success)
expire(); check(gate.getState()=='FAILED','hung request expires')
run(); check(gate.getState()=='FAILED' and stats()==1,'late success ignored after timeout')
gate,run,expire,stats=harness(success)
gate.destroy(); run(); expire(); check(stats()==0,'destroy suppresses pending callbacks')
check(not gate.shouldWait(catalog.Entries.Kart05),'destroy releases gate')
local ui=fs.readFile('src/client/GarageUiController.luau')
check(ui:find('local kartIndex = 1',1,true) and ui:find('KartCatalog.Order[kartIndex]',1,true),'first Garage selection uses first ordered ID')
check(ui:find('if waiting then clearPreview() else showPreview("Kart", kartId) end',1,true),'partial preview withheld until gate releases')
local effects=fs.readFile('src/client/KartEffectsController.luau')
check(effects:find('local allowCruiseFlame = visual:GetAttribute("VisualModelName") ~= "KDMV2"',1,true)
 and effects:find('local cruising = allowCruiseFlame and',1,true),'V2 cruise-only identity gate')
check(effects:find('flame.Enabled = nitroActive or boosting',1,true),'Nitro and Mini Boost branch retained')
check(effects:find('table.insert(flames, makeFlame(point))',1,true)
 and effects:find('table.insert(cruiseFlames, makeCruiseFlame(point))',1,true),'both exhaust attachment branches retained')
print('Garage polish validation PASS: '..checks..' checks')
