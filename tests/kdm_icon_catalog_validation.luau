local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local checks = 0
local function check(value, message) assert(value, message); checks += 1 end
local catalog = luau.load(fs.readFile("src/client/KDMIconCatalog.luau"))()
local expected = {
	Items={Nitro="80904195199672",Shield="133670688245113",Slick="99710951340190",Missile="122668047956907",Thunder="105188481205755",Smoke="117693178629090"},
	Actions={AutoStart="86543823779198",AutoStartOn="94676537813180",DriftWide="104706910388302",DriftSquare="124990672172496"},
	Drive={Forward="133764403498700",ForwardLeft="89268514038200",ForwardRight="130561740072224",BrakeReverse="94445847645477"},
}
for group, entries in expected do
	check(table.isfrozen(catalog[group]), "immutable catalog "..group)
	for id, asset in entries do check(catalog[group][id] == "rbxassetid://"..asset, "exact uploaded asset "..id) end
	for id in catalog[group] do check(entries[id] ~= nil, "no extra catalog key") end
end
local function object(class)
	return {ClassName=class, ZIndex=1, Destroy=function(self) self.destroyed=true end}
end
local enum = {AssetFetchStatus={Success="Success",Failure="Failure"},ScaleType={Fit="Fit"}}
local env={script={Parent={WaitForChild=function(_,name) return name end}},require=function() return catalog end,
	Enum=enum,Instance={new=object},UDim2=rb.UDim2}
local view = luau.load(fs.readFile("src/client/KDMItemIconView.luau"),{environment=env})()
local jobs, timers, callbacks, changes = {}, {}, {}, 0
local scheduler={spawn=function(cb) table.insert(jobs,cb) end,delay=function(seconds,cb)
	check(seconds==12,"bounded preload timeout");table.insert(timers,cb)
end}
local provider={PreloadAsync=function(_,assets,cb)
	check(#assets==6,"only six item images preloaded")
	for _,asset in assets do callbacks[asset.Image]=cb end
end}
local cache=view.cache(provider,scheduler)
cache:start(function() changes+=1 end)
check(#jobs==1 and changes==0,"preload is asynchronous")
cache:start(function() error("duplicate start") end)
check(#jobs==1,"preload starts once")
local mobileView={icon=function(_,id) return {root=object(id),setEnabled=function(self,on) self.enabled=on end} end}
local slot=view.new(object("TextButton"),"Nitro",cache,mobileView)
check(slot:update(true,1,false) and slot.icon.root.Visible and not slot.image.Visible,"pending uses procedural fallback")
check(not slot.image.Active and not slot.image.Selectable and slot.image.ScaleType==enum.ScaleType.Fit,"image cannot intercept input")
check(slot.image.Size==rb.UDim2.fromScale(1,1),"full cell image fill")
jobs[1]()
check(not cache:ready("Nitro"),"missing fetch callbacks fail safely")
callbacks[catalog.Items.Nitro](catalog.Items.Nitro,enum.AssetFetchStatus.Success)
check(not cache:ready("Nitro"),"late callbacks cannot reopen terminal failure")

local worker, timeout, fetch
local asyncScheduler={spawn=function(cb) worker=cb end,delay=function(_,cb) timeout=cb end}
local successProvider={PreloadAsync=function(_,assets,cb)
	for _,asset in assets do cb(asset.Image,enum.AssetFetchStatus.Success) end
end}
local ready=view.cache(successProvider,asyncScheduler)
ready:start(function() end);worker()
for id in catalog.Items do
	check(ready:ready(id),"loaded "..id)
	slot=view.new(object("TextButton"),id,ready,mobileView)
	for _,charges in {0,1,2,9} do
		check(not slot:update(true,charges,false) and slot.image.Visible and not slot.icon.root.Visible,"loaded artwork replaces fallback")
		check(slot.image.ImageTransparency==(if charges==0 then .55 else 0),"charge-dependent disabled appearance")
	end
	check(slot:update(true,1,true),"highlight retains outer stroke")
	check(not slot:update(false,1,false) and not slot.image.Visible and not slot.icon.root.Visible,"desktop retains text UI")
end
slot:setItem("Unknown")
check(slot.image.Image=="" and not slot.image.Visible,"unknown mapping clears previous image")
slot:update(true,1,false)
check(not slot.image.Visible,"unknown asset never displayed")
local hanging={PreloadAsync=function(_,_,cb) fetch=cb;coroutine.yield() end}
local timed=view.cache(hanging,asyncScheduler)
timed:start(function() changes+=1 end)
local co=coroutine.create(worker);check(coroutine.resume(co),"hung fetch yields")
fetch(catalog.Items.Shield,enum.AssetFetchStatus.Success)
timeout()
check(timed:ready("Shield") and not timed:ready("Nitro"),"timeout preserves partial success and falls back remaining assets")
fetch(catalog.Items.Nitro,enum.AssetFetchStatus.Success)
check(not timed:ready("Nitro"),"stale success after timeout ignored")
local dead=view.cache(hanging,asyncScheduler)
dead:start(function() changes+=1 end)
co=coroutine.create(worker);check(coroutine.resume(co),"second fetch yields")
dead:destroy();local before=changes
fetch(catalog.Items.Nitro,enum.AssetFetchStatus.Success);timeout();coroutine.resume(co)
check(changes==before and not dead:ready("Nitro"),"destroyed HUD ignores all late completion")
local failed=view.cache({PreloadAsync=function() error("network failure") end},asyncScheduler)
failed:start(function() end);worker()
check(not failed:ready("Nitro") and failed.states.Nitro=="Failure","preload exception preserves fallback")
print("PASS: "..checks.." KDM catalog, asynchronous preload, fallback and presentation checks")
