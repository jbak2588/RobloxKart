local fs,luau=require("@lune/fs"),require("@lune/luau")
local P=luau.load(fs.readFile("src/client/KartPowertrainPresentation.luau"))()
local checks=0
local function check(ok,message) assert(ok,message);checks+=1 end
local function settle(p,speed,options)
	local s
	for _=1,60 do s=p:update(speed,1/60,options) end
	return s
end
local p=P.new()
for _,pair in {{0,1},{10,1},{20,1},{27,1},{29,2},{35,2},{49,2},{51,3},{60,3},{70,3},{85,3},{100,3},
	{100,3},{70,3},{48,3},{40,2},{25,2},{20,1},{0,1}} do
	local s=settle(p,pair[1]);check(s.gear==pair[2],"gear at "..pair[1])
	check(s.rpm>=899.9 and s.rpm<=10000,"bounded RPM")
	check(s.speedKmh==pair[1]*1.008,"existing km/h rule")
end
local s=settle(p,0);check(math.abs(s.rpm-900)<.01,"idle")
p=P.new();local shifts={}
local previous=1
for i=0,700 do
	s=p:update(i/10,1/60)
	if s.gear~=previous then table.insert(shifts,{previous,s.gear});previous=s.gear end
end
check(#shifts==2 and shifts[1][1]==1 and shifts[1][2]==2 and shifts[2][1]==2 and shifts[2][2]==3,"two exact upshifts")
p=P.new();settle(p,27)
for _,v in {27,28,27,28,29,27,28,29} do settle(p,v) end
check(p.shiftSerial==1,"1/2 boundary noise no chatter")
for _,v in {49,50,49,50,51,48,49,50} do settle(p,v) end
check(p.shiftSerial==2,"2/3 boundary noise no chatter")
p=P.new();local before=settle(p,27.99);s=p:update(28,1/60)
check(s.shiftActive and s.rpm<before.rpm and s.playbackSpeed<before.playbackSpeed and s.volume<before.volume,"first shift RPM/pitch/volume drop")
settle(p,49.99);before=settle(p,49.99);s=p:update(50,1/60)
check(s.rpm<before.rpm and s.playbackSpeed<before.playbackSpeed,"second shift drop")
local cruise=settle(p,70);local nitro=settle(p,100,{nitro=true})
check(nitro.gear==3 and nitro.redline and nitro.rpm>9900,"Nitro third gear redline")
check(nitro.playbackSpeed>cruise.playbackSpeed,"RPM audio rises")
s=settle(p,70);check(not s.redline and math.abs(s.rpm-8500)<.01,"natural presentation recovery")
check(math.floor(s.speedKmh+.5)==71 and math.floor(nitro.speedKmh+.5)==101,"same rounded top speed")
check(settle(p,20,{reverse=true}).gear=="R","reverse display only")
for _,v in {0/0,math.huge,-math.huge,-10} do
	s=p:update(v,v);for _,key in {"rpm","speedStuds","speedKmh","playbackSpeed","volume","load"} do
		check(s[key]==s[key] and math.abs(s[key])<math.huge,"finite "..key)
	end
end
local donor=P.new()
local accelerating=settle(donor,70,{throttle=1})
check(math.abs(accelerating.playbackSpeed-1.02)<.001,"original donor RPM pitch at cruise")
check(math.abs(accelerating.volume-1)<.001,"full throttle original volume")
local coasting=settle(donor,70,{throttle=0})
check(math.abs(coasting.playbackSpeed-accelerating.playbackSpeed)<.001,"throttle release never changes RPM pitch independently")
check(math.abs(coasting.volume-.3)<.001,"coast returns to original idle volume")
local boosted=settle(donor,100,{throttle=1})
check(math.abs(boosted.playbackSpeed-1.2)<.001 and math.abs(boosted.volume-.5)<.001,"original redline pitch and volume")
local runtimeSource=fs.readFile("src/client/KartPowertrainPrototype.luau")
check(not runtimeSource:find(":Play%(") and not runtimeSource:find("TimePosition"),"modulation never replays or seeks engine")
local Gauge=luau.load(fs.readFile("src/client/KartPowertrainGauge.luau"))()
for _,size in {{749,302},{749,361},{844,332},{932,372},{1920,1080},{1366,768}} do
	local mobile=size[1]<1000;local l=Gauge.layout(size[1],size[2],mobile)
	check(l.visible and l.x>=0 and l.x+l.width<=size[1] and l.y>=0,"gauge safe bounds")
	local wheel=if mobile then math.min(112,size[1]*.18) else (if size[2]<=650 then 84 else 112)
	check(l.y+l.height<size[2]-3-wheel*2/3,"above Steering Sync")
	if mobile then
		check(l.x>=240,"outside item/drift lane")
		check(l.x+l.width<size[1]-20-(math.clamp(size[2]*.15,44,56)*3+24),"outside Digital Pad")
	end
end
check(not Gauge.layout(390,749,true).visible,"portrait safely suppresses prototype")
check(not Gauge.layout(750,361,false).visible,"narrow desktop suppresses gauge instead of overlapping legacy PC items")
-- Real orchestration with passive rendering mock: one state drives Sound and gauge.
local player={attrs={KDMEnablePowertrainPrototype=true,KDMPowertrainAudioMode="VIRTUAL_POWERTRAIN"}}
function player:GetAttribute(k) return self.attrs[k] end
local engine={Parent={},SoundId="current",PlaybackSpeed=1,Volume=1}
local currentState
local mockGauge={new=function()
	return {update=function(_,state) currentState=state end,destroy=function() currentState=nil end}
end}
local modules={KartPowertrainPresentation=P,KartPowertrainGauge=mockGauge,
	V2DonorExperiment={enabled=function() return false end,reset=function() end}}
local studio=true
local acceptance=false
local workspace={GetAttribute=function(_,name) return if name=="KDMPowertrainPublishedAcceptance" then acceptance else nil end}
local Runtime=luau.load(fs.readFile("src/client/KartPowertrainPrototype.luau"),{environment={
	game={GetService=function(_,name) return if name=="RunService" then {IsStudio=function() return studio end} elseif name=="Workspace" then workspace else {LocalPlayer=player} end},
	script={Parent={WaitForChild=function(_,n)return n end}},require=function(n)return modules[n]end,
}})()
local chassis={AssemblyLinearVelocity={Dot=function()return 70 end},CFrame={LookVector={}}}
function chassis:FindFirstChild() return engine end
local kart={};local parent={AbsoluteSize={X=749,Y=302}}
s=Runtime.update(parent,kart,chassis,1/60,70,70,"71",true,false)
check(currentState==s and Runtime.getState()==s,"Audio/Gauge exact same state table")
check(engine.PlaybackSpeed==s.playbackSpeed and engine.Volume==s.volume,"Audio consumes that state")
check(Runtime.ownsEngine(engine),"existing audio modulation bypassed only during prototype")
player.attrs.KDMPowertrainAudioMode="CURRENT"
engine.PlaybackSpeed=1.23
Runtime.update(parent,kart,chassis,1/60,70,70,"71",true,false)
check(engine.PlaybackSpeed==1.23 and not Runtime.ownsEngine(engine),"CURRENT existing modulation retained")
player.attrs.KDMPowertrainAudioMode="V2_ORIGINAL_AUDIO"
Runtime.update(parent,kart,chassis,1/60,70,70,"71",true,false)
check(engine.SoundId=="rbxassetid://290290922","audited candidate ID only")
engine.IsLoaded=false
for _=1,500 do Runtime.update(parent,kart,chassis,1/60,70,70,"71",true,false) end
check(engine.SoundId=="current" and Runtime.getState().originalAudioFailed,"unloadable donor falls back without stopping virtual RPM")
player.attrs.KDMEnablePowertrainPrototype=false
Runtime.update(parent,kart,chassis,1/60,70,70,"71",true,false)
check(engine.SoundId=="current" and Runtime.getState()==nil and currentState==nil,"gate OFF restores original Sound and removes gauge")
studio=false;player.attrs.KDMEnablePowertrainPrototype=true
check(not Runtime.enabled(),"published flag cannot enable prototype")
engine.PlaybackSpeed=1.23
Runtime.update(parent,kart,chassis,1/60,70,70,"71",true,false)
check(currentState==nil and engine.PlaybackSpeed==1.23,"normal published source has no gauge or virtual modulation")
acceptance=true;player.attrs.KDMEnablePowertrainPrototype=nil
for _,requested in {"CURRENT","V2_ORIGINAL_AUDIO","VIRTUAL_POWERTRAIN"} do
	player.attrs.KDMPowertrainAudioMode=requested
	s=Runtime.update(parent,kart,chassis,1/60,70,70,"71",true,false)
	check(Runtime.enabled() and currentState==s,"acceptance automatically enables shared gauge state")
	check(engine.SoundId=="rbxassetid://290290922" and engine.PlaybackSpeed==s.playbackSpeed and Runtime.ownsEngine(engine),"published acceptance forces user-approved V2 audio regardless of local mode")
end
engine.IsLoaded=false
for _=1,500 do Runtime.update(parent,kart,chassis,1/60,70,70,"71",true,false) end
check(engine.SoundId=="rbxassetid://290290922" and engine.Volume==0 and Runtime.getState().originalAudioFailed,"published load failure never restores rejected loop")
acceptance=false
Runtime.update(parent,kart,chassis,1/60,70,70,"71",true,false)
check(not Runtime.enabled() and currentState==nil and not Runtime.ownsEngine(engine),"acceptance removal restores production ownership and removes gauge")
print("PASS: "..checks.." virtual gears/RPM/audio/shared state/speed/layout/production gate checks")
