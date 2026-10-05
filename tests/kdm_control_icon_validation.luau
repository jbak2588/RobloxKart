local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local checks = 0
local function check(value, message) assert(value, message); checks += 1 end
check(require("./helpers/gameplay_config")("src/shared/KartConfig.luau").DEBUG_DRIFT_HUD==false,
	"production never creates the Drift diagnostic HUD by default")
local rawCatalog = luau.load(fs.readFile("src/client/KDMIconCatalog.luau"))()
for key,id in {Forward="133764403498700",ForwardLeft="107782001043228",
	ForwardRight="118487432534938",BrakeReverse="94445847645477"} do
	check(rawCatalog.Drive[key]=="rbxassetid://"..id,"v2 direction identity "..key)
end
check(rawCatalog.Actions.AutoStart=="rbxassetid://111620163887565","v2 Auto Start")
check(rawCatalog.Actions.DriftWide=="rbxassetid://139581158872943","v2 horizontal Drift")
for key,id in {Nitro="80904195199672",Shield="133670688245113",Slick="99710951340190",
	Missile="122668047956907",Thunder="105188481205755",Smoke="117693178629090"} do
	check(rawCatalog.Items[key]=="rbxassetid://"..id,"item asset unchanged "..key)
end
local catalog = {Items={AutoStart=rawCatalog.Actions.AutoStart,Forward=rawCatalog.Drive.Forward,ForwardLeft=rawCatalog.Drive.ForwardLeft,
	ForwardRight=rawCatalog.Drive.ForwardRight,BrakeReverse=rawCatalog.Drive.BrakeReverse,
	DriftWide=rawCatalog.Actions.DriftWide,DriftSquare=rawCatalog.Actions.DriftSquare}}
local function object(class)
	return {ClassName=class, ZIndex=1, Destroy=function(self) self.destroyed=true end}
end
local enum = {AssetFetchStatus={Success="Success",Failure="Failure"},ScaleType={Fit="Fit"}}
local env={script={Parent={WaitForChild=function(_,name) return name end}},require=function() return rawCatalog end,
	Enum=enum,Instance={new=object},UDim2=rb.UDim2,Vector2=rb.Vector2,Color3=rb.Color3}
local view = luau.load(fs.readFile("src/client/KDMControlIconView.luau"),{environment=env})()
local jobs, timers, callbacks, changes = {}, {}, {}, 0
local scheduler={spawn=function(cb) table.insert(jobs,cb) end,delay=function(seconds,cb)
	check(seconds==12,"bounded preload timeout");table.insert(timers,cb)
end}
local provider={PreloadAsync=function(_,assets,cb)
	check(#assets==7,"only six item images preloaded")
	for _,asset in assets do callbacks[asset.Image]=cb end
end}
local cache=view.cache(provider,scheduler)
cache:start(function() changes+=1 end)
check(#jobs==1 and changes==0,"preload is asynchronous")
cache:start(function() error("duplicate start") end)
check(#jobs==1,"preload starts once")
local mobileView={round=function()end,stroke=function() return object("UIStroke") end,icon=function(_,id) return {root=object(id),setEnabled=function(self,on) self.enabled=on end,setLatched=function(self,on) self.latched=on end} end}
local slot=view.new(object("TextButton"),"Forward",cache,mobileView)
check(not slot:update(true,false) and slot.fallback.root.Visible and not slot.image.Visible,"pending uses procedural fallback")
check(not slot.image.Active and not slot.image.Selectable and slot.image.ScaleType==enum.ScaleType.Fit,"image cannot intercept input")
check(slot.image.Size==rb.UDim2.fromScale(1,1),"full cell image fill")
jobs[1]()
check(not cache:ready("Forward"),"missing fetch callbacks fail safely")
callbacks[catalog.Items.Forward](catalog.Items.Forward,enum.AssetFetchStatus.Success)
check(not cache:ready("Forward"),"late callbacks cannot reopen terminal failure")

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
	slot:layout(52,52)
	check(slot:update(true,false) and slot.image.Visible and not slot.fallback.root.Visible,"loaded control artwork replaces fallback")
	check(slot:update(true,true) and slot.scale.Scale==1 and slot.image.ImageColor3==rb.Color3.fromRGB(255,255,255),"pressed feedback")
	if id=="AutoStart" then check(slot.indicator.Visible,"Auto ON state light")end
	slot:update(true,false);check(slot.indicator.Visible==(id=="AutoStart") and slot.scale.Scale==1,"release retains one Auto state lamp")
	if id=="AutoStart" then
		check(slot.indicator.BackgroundColor3==rb.Color3.fromRGB(35,50,60),"Auto OFF covers baked green dot")
		slot:update(true,true)
		check(slot.indicator.BackgroundColor3==rb.Color3.fromRGB(70,255,170),"Auto ON lamp follows state")
	end
	slot:update(false,false);check(slot.image.ImageTransparency==.55,"disabled image")
end
slot=view.new(object("TextButton"),"Unknown",ready,mobileView)
check(slot.image.Image=="" and not slot.image.Visible,"unknown mapping clears previous image")
slot:update(true,false)
check(not slot.image.Visible,"unknown asset never displayed")
local hanging={PreloadAsync=function(_,_,cb) fetch=cb;coroutine.yield() end}
local timed=view.cache(hanging,asyncScheduler)
timed:start(function() changes+=1 end)
local co=coroutine.create(worker);check(coroutine.resume(co),"hung fetch yields")
fetch(catalog.Items.DriftWide,enum.AssetFetchStatus.Success)
timeout()
check(timed:ready("DriftWide") and not timed:ready("Forward"),"timeout preserves partial success and falls back remaining assets")
fetch(catalog.Items.Forward,enum.AssetFetchStatus.Success)
check(not timed:ready("Forward"),"stale success after timeout ignored")
local dead=view.cache(hanging,asyncScheduler)
dead:start(function() changes+=1 end)
co=coroutine.create(worker);check(coroutine.resume(co),"second fetch yields")
dead:destroy();local before=changes
fetch(catalog.Items.Forward,enum.AssetFetchStatus.Success);timeout();coroutine.resume(co)
check(changes==before and not dead:ready("Forward"),"destroyed HUD ignores all late completion")
local failed=view.cache({PreloadAsync=function() error("network failure") end},asyncScheduler)
failed:start(function() end);worker()
check(not failed:ready("Forward") and failed.states.Forward=="Failure","preload exception preserves fallback")


local model=luau.load(fs.readFile("src/client/TouchDrivingModel.luau"))()
local state=model.new("Buttons")
state:toggleAutoForward();state.autoForward=true
local t,steer=state:actions();check(t==1 and steer==0,"Buttons Auto accelerates without a held finger")
state:toggleAutoForward();t,steer=state:actions();check(t==0 and steer==0,"Auto toggles OFF")
check(not state:pressButton("x","Left") and not state:pressButton("x","Brake"),"old directional actions rejected")
state:pressButton("a","ForwardLeft");state:pressButton("b","ForwardRight")
t,steer=state:actions();check(t==1 and steer==1,"last turn press wins")
state:release("b");t,steer=state:actions();check(t==1 and steer==-1,"last turn release restores earlier owner")
state:pressButton("c","BrakeReverse");state:pressDrift("d")
t,steer=state:actions();check(t==-1 and steer==-.60,"brake and Drift preserve other directional owner")
state:reset();t,steer=state:actions();check(t==0 and steer==0,"reset clears every owner")
local layout=luau.load(fs.readFile("src/client/MobileControlView.luau"),{environment={Color3=rb.Color3}})()
local gauge=luau.load(fs.readFile("src/client/V2DonorGauge.luau"),{environment={script={Parent={WaitForChild=function()end}},require=function()return layout end}})()
local function overlaps(a,b) return a[1]<b[3] and b[1]<a[3] and a[2]<b[4] and b[2]<a[4] end
for _,pair in {{750,283},{750,341},{750,361},{844,390},{932,430},{749,303},{640,360},{473,240},{320,568},{389,703},{1600,739}} do
	local w,h=pair[1],pair[2];local l=layout.layout({X=w,Y=h})
	local left=w-l.margin-l.padWidth-l.padInset;local top=h-l.padBottom-l.padHeight
	local turnTop=h-l.padBottom-(l.padHeight+l.direction)/2
	local fx=left+(l.padWidth-l.forward)/2
	local ax=left+(l.padWidth-l.autoHitSize)/2;local ay=h-l.padBottom-(l.padHeight+l.autoHitSize)/2
	local targets={{ax,ay,ax+l.autoHitSize,ay+l.autoHitSize},{fx,top,fx+l.forward,top+l.forward},
	{left,turnTop,left+l.direction,turnTop+l.direction},
	{left+l.padWidth-l.direction,turnTop,left+l.padWidth,turnTop+l.direction},
	{fx,h-l.padBottom-l.brake,fx+l.brake,h-l.padBottom}}
	check(l.direction>=l.driveVisualSize*layout.artwork.driveWidth+4,"visible artwork retains touch tolerance")
	check(l.driftHitWidth>=l.driftWidth*1.10 and l.driftHitHeight>=l.driftHeight*layout.artwork.driftHeight+6,"Drift target encloses the opaque artwork")
	check(math.abs(l.driftWidth/l.driftHeight-2.4)<.001,"wide art aspect")
	local g=gauge.layout(w,h,true)
	local passive={g.x-g.width/2,g.y-g.height,g.x+g.width/2,g.y}
	for i,r in targets do
		check(r[1]>=0 and r[2]>=0 and r[3]<=w and r[4]<=h,"hitbox inside safe region")
		check(r[3]-r[1]>=(if i==1 then l.autoVisualSize*layout.artwork.autoWidth else l.driveVisualSize*layout.artwork.driveWidth),"opaque artwork inside hitbox")
		for j=i+1,#targets do check(not overlaps(r,targets[j]),"drive hitboxes never overlap") end
		if g.visible then check(not overlaps(r,passive),"drive avoids RPM/Speed gauge "..w.."x"..h.." target "..i) end
	end
	check(l.driveVisualSize>=(if w<500 and h<260 then 58 else 62),"enlarged drive art minimum")
	check(l.driftWidth==layout.itemLayout({X=w,Y=h},4).width,"Drift matches four item group width")
	if w>=600 and w>h then
		check(math.abs(l.padBottom+(l.brake-l.driveVisualSize)/2+l.driveVisualSize*layout.artwork.driveBottom-10)<.001,"visible Brake bottom is 10px")
		check(math.abs(l.driftBottom+(l.driftHitHeight-l.driftHeight)/2+l.driftHeight*layout.artwork.driftBottom-10)<.001,"visible Drift bottom is 10px")
		check(math.abs(l.padVerticalSpacing-(l.driveVisualSize*layout.artwork.driveWidth+l.autoVisualSize*layout.artwork.autoWidth)/2-10)<.001,"visible Auto artwork gap is 10px")
		check(math.abs(l.margin+l.padInset+(l.direction-l.driveVisualSize)/2+l.driveVisualSize*layout.artwork.driveRight-12)<.001,"Pad shares minimap's right edge")
	end
	local d={l.driftX,h-l.driftBottom-l.driftHitHeight,l.driftX+l.driftHitWidth,h-l.driftBottom}
	if g.visible then check(not overlaps(d,passive),"wide Drift avoids RPM/Speed gauge") end
	for _,r in targets do check(not overlaps(d,r),"wide Drift avoids drive hitboxes") end
end
layout.setViewportBottomInset(360,338)
local insetLayout=layout.layout({X=685,Y=280})
local insetItems=layout.itemLayout({X=685,Y=280},4)
check(insetLayout.direction==59 and insetLayout.autoHitSize==50 and insetLayout.driftHitWidth==221
	and insetLayout.driftHitHeight==63,"R6-B1 short touch dimensions remain exact")
check(280-insetItems.bottom-insetLayout.slot>=120,"device bottom compensation leaves room for LAP, Quit and both warnings")
check(math.abs(insetLayout.padBottom+(insetLayout.brake-insetLayout.driveVisualSize)/2
	+insetLayout.driveVisualSize*layout.artwork.driveBottom+22-10)<.001,"device inset compensated Brake shares physical gauge bottom")
layout.setViewportBottomInset(338,338)
print("PASS: "..checks.." four-button ownership, asset lifecycle, feedback and hitbox geometry checks")
