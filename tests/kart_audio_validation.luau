-- Executes production KartAudioController with mocked lifecycle/signals/audio transport.
-- Validates cue dispatch, not audible playback or Roblox asset permissions.
local fs,luau=require("@lune/fs"),require("@lune/luau")
local function signal()
	local listeners={}
	return {Connect=function(_,fn)
		local c={active=true};function c:Disconnect()self.active=false end
		table.insert(listeners,{c,fn});return c
	end,Fire=function(_,...)
		for _,p in table.clone(listeners)do if p[1].active then p[2](...)end end
	end}
end
local function node(class)
	local o={ClassName=class,attrs={},signals={},children={},Parent={},Destroying=signal()}
	function o:IsA(c)return c==self.ClassName end
	function o:GetAttribute(k)return self.attrs[k]end
	function o:GetAttributeChangedSignal(k)
		self.signals[k]=self.signals[k]or signal();return self.signals[k]
	end
	function o:SetAttribute(k,v)
		local previous=self.attrs[k];self.attrs[k]=v
		if previous~=v then self:GetAttributeChangedSignal(k):Fire()end
	end
	function o:FindFirstChild(k)return self.children[k]end
	function o:WaitForChild(k)return assert(self.children[k],k)end
	function o:FindFirstChildOfClass(c)for _,v in self.children do if v:IsA(c)then return v end end end
	function o:GetPropertyChangedSignal(k)return self:GetAttributeChangedSignal("property:"..k)end
	return o
end
local player=node("Player");player.CharacterAdded=signal();player.CharacterRemoving=signal()
player:SetAttribute("RaceState","RACING")
local kart=node("Model");kart:SetAttribute("PrototypeKart",true)
kart:SetAttribute("KartBoosting",false);kart:SetAttribute("KartNitroActive",false)
kart.children.Chassis=node("BasePart")
local seat=node("BasePart");seat.Parent=kart;seat:SetAttribute("PrototypeKartSeat",true)
local humanoid=node("Humanoid");humanoid.SeatPart=seat;humanoid.Seated=signal()
local character=node("Model");character.children.Humanoid=humanoid;player.Character=character
local clock,played,destroyed=0,0,0
local config=luau.load(fs.readFile("src/shared/AudioConfig.luau"))()
local runtime={getGroup=function()return{}end,preload=function()end,playLoop=function()end,stop=function()end}
function runtime.createSound(name,asset)
	if name~="BoostStart"then return nil end
	assert(asset==config.ASSETS.BOOST_START,"same existing launch asset")
	return {Stop=function()end,Destroy=function()destroyed+=1 end}
end
function runtime.playOnce(sound)if sound then played+=1 end end
local shared={WaitForChild=function(_,name)return name end}
local services={Players={LocalPlayer=player},ReplicatedStorage={WaitForChild=function()return shared end},RunService={Heartbeat=signal()}}
local modules={AudioRuntime=runtime,AudioConfig=config,KartConfig={}}
local controller=luau.load(fs.readFile("src/client/KartAudioController.luau"),{environment={
	game={GetService=function(_,n)return services[n]end},script={Parent=shared},require=function(n)return modules[n]end,
	time=function()return clock end,task={spawn=function(f,...)f(...)end,delay=function()error("unexpected attach retry")end},
}})()
controller.start()
assert(played==0,"attachment does not invent an activation")
kart:SetAttribute("KartNitroActive",true);assert(played==1,"approved Nitro starts exactly one launch cue")
kart:SetAttribute("KartNitroActive",true);assert(played==1,"unchanged active state does not repeat")
clock=.05;kart:SetAttribute("KartBoosting",true);assert(played==1,"near-simultaneous Mini Boost shares one onset")
clock=1;kart:SetAttribute("KartNitroActive",false);kart:SetAttribute("KartBoosting",false)
assert(played==1,"ending boost/Nitro has no launch cue")
clock=2;kart:SetAttribute("KartBoosting",true);assert(played==2,"Mini Boost cue preserved")
clock=2.04;kart:SetAttribute("KartNitroActive",true);assert(played==2,"deduplicate in the opposite order too")
clock=3;kart:SetAttribute("KartNitroActive",false)
clock=4;kart:SetAttribute("KartNitroActive",true);assert(played==3,"later independent Nitro still sounds")
player:SetAttribute("RaceState","GARAGE");assert(destroyed==1,"garage cleans up attached audio")
clock=5;kart:SetAttribute("KartNitroActive",false);kart:SetAttribute("KartNitroActive",true)
assert(played==3,"detached kart cannot trigger sound")
player:SetAttribute("RaceState","RACING");assert(played==3,"reattach while active does not replay launch")
clock=6;kart:SetAttribute("KartNitroActive",false);kart:SetAttribute("KartNitroActive",true)
assert(played==4,"new activation after rematch still works")
humanoid.SeatPart=nil;humanoid.Seated:Fire()
clock=7;kart:SetAttribute("KartNitroActive",false);kart:SetAttribute("KartNitroActive",true)
assert(played==4 and destroyed==2,"seat loss disconnects activation listeners")
print("PASS: Nitro launch cue, Mini Boost regression, both overlap orders, cleanup and reattachment")

-- Developer engine loop A/B harness: run the production diagnostic against a
-- loaded Sound mock, then exercise delayed load and production guard paths.
local delayed,diagnosticLogs,diagnosticWarnings,diagnosticMessages={},0,0,{}
local diagnostic=luau.load(fs.readFile("src/client/EngineLoopDiagnostic.luau"),{environment={
 NumberRange={new=function(a,b)return {Min=a,Max=b}end},
 task={delay=function(_,fn)table.insert(delayed,fn)end},
 print=function(message)diagnosticLogs+=1;table.insert(diagnosticMessages,message)end,
 warn=function()diagnosticWarnings+=1 end,
}})()
local function sound(length,loaded)
 local s={SoundId=config.ASSETS.ENGINE_LOOP,TimeLength=length,IsLoaded=loaded,
  PlaybackSpeed=1.292,PlaybackRegionsEnabled=false,TimePosition=0,Loaded=signal(),plays=0,stops=0}
 function s:Play()self.plays+=1;self.IsPlaying=true end
 function s:Stop()self.stops+=1;self.IsPlaying=false end
 return s
end
local engineSound=sound(1.927,true)
local mode=diagnostic.new(engineSound,true)
mode:setMode(nil)
assert(not engineSound.PlaybackRegionsEnabled and not mode:isFixed() and engineSound.PlaybackSpeed==1.292,"NORMAL keeps full dynamic pitch")
mode:setMode("FIXED_FULL")
assert(not engineSound.PlaybackRegionsEnabled and mode:isFixed() and engineSound.PlaybackSpeed==1
 and engineSound.TimePosition==0,"FIXED_FULL uses original asset at 1x")
assert(string.find(diagnosticMessages[1],"timeLength=1.927",1,true)
 and string.find(diagnosticMessages[1],"effectiveLoop=1.927",1,true),"fixed-full diagnostic reports runtime duration")
mode:setMode("FIXED_A")
assert(engineSound.PlaybackRegionsEnabled and engineSound.PlaybackRegion.Min==0.05
 and math.abs(engineSound.LoopRegion.Max-1.877)<0.0001 and engineSound.PlaybackSpeed==1,"FIXED_A trims 0.05 seconds")
mode:setMode("FIXED_B")
assert(engineSound.PlaybackRegionsEnabled and engineSound.PlaybackRegion.Min==0.10
 and math.abs(engineSound.LoopRegion.Max-1.827)<0.0001 and engineSound.PlaybackSpeed==1,"FIXED_B trims 0.10 seconds")
mode:setMode("DYNAMIC_A")
assert(engineSound.PlaybackRegionsEnabled and not mode:isFixed(),"DYNAMIC_A allows existing pitch smoothing")
mode:setMode("DYNAMIC_B")
assert(engineSound.PlaybackRegionsEnabled and engineSound.PlaybackRegion.Min==0.10
 and not mode:isFixed(),"DYNAMIC_B uses trimmed region with dynamic pitch")
mode:setMode("bad mode")
assert(not engineSound.PlaybackRegionsEnabled and not mode:isFixed(),"invalid mode returns to NORMAL")
assert(diagnosticLogs==5,"non-NORMAL mode changes print one summary each")
local guarded=sound(1.927,true)
local production=diagnostic.new(guarded,false)
production:setMode("FIXED_B")
assert(not guarded.PlaybackRegionsEnabled and not production:isFixed(),"production guard forces NORMAL")
local short=sound(0.15,true)
local shortMode=diagnostic.new(short,true)
shortMode:setMode("FIXED_B")
assert(not short.PlaybackRegionsEnabled and diagnosticWarnings==1,"invalid region falls back to full asset")
local loading=sound(0,false)
local loadingMode=diagnostic.new(loading,true)
loadingMode:setMode("FIXED_A")
assert(not loading.PlaybackRegionsEnabled and loading.TimePosition==0,"unloaded asset starts in full fallback")
loading.TimeLength=1.927;loading.IsLoaded=true;loading.Loaded:Fire()
assert(loading.PlaybackRegionsEnabled and loading.LoopRegion.Min==0.05,"Loaded event applies region")
for _,fn in delayed do fn() end
assert(diagnosticWarnings==1,"completed load cancels timeout warning")
local timed=sound(0,false)
local timedMode=diagnostic.new(timed,true)
timedMode:setMode("FIXED_A")
for _,fn in delayed do fn() end
assert(not timed.PlaybackRegionsEnabled and diagnosticWarnings==2,"load timeout remains full and warns once")
mode:destroy();production:destroy();shortMode:destroy();loadingMode:destroy();timedMode:destroy()
print("PASS: engine loop NORMAL/FIXED/DYNAMIC modes, runtime regions, delayed load, timeout and production guard")

-- Execute the actual engine heartbeat with stale velocity in stopped PRESENT.
local rb=require("@lune/roblox")
local engineHeartbeat=signal()
services.RunService={Heartbeat=engineHeartbeat,IsStudio=function()return false end}
modules.KartConfig={MAX_FORWARD_SPEED=70,MINI_BOOST_MAX_SPEED=100}
local idleEngine
runtime.createSound=function(name)
 if name~="EngineLoop" then return nil end
 idleEngine={Volume=config.ENGINE.IDLE_VOLUME,PlaybackSpeed=0,Stop=function()end,Destroy=function()end}
 return idleEngine
end
modules.EngineLoopDiagnostic={new=function()return {setMode=function()end,isFixed=function()return false end,destroy=function()end}end}
player.signals={};humanoid.SeatPart=seat;player:SetAttribute("RaceState","RACING")
kart:SetAttribute("KartBoosting",false)
kart.children.Chassis.CFrame=rb.CFrame.identity
kart.children.Chassis.AssemblyLinearVelocity=rb.Vector3.new(0,0,-70)
local engineController=luau.load(fs.readFile("src/client/KartAudioController.luau"),{environment={
 game={GetService=function(_,n)return services[n]end},script={Parent=shared},require=function(n)return modules[n]end,
 time=function()return clock end,task={spawn=function(f,...)f(...)end,delay=function()error("unexpected retry")end},
}})()
engineController.start()
for _=1,120 do engineHeartbeat:Fire(1/60) end
assert(math.abs(idleEngine.PlaybackSpeed-1.30)<1e-6 and math.abs(idleEngine.Volume-.60)<1e-6,"normal 70 high-rev target")
kart.children.Chassis.AssemblyLinearVelocity=rb.Vector3.new(0,0,-100)
for _=1,240 do engineHeartbeat:Fire(1/60) end
assert(math.abs(idleEngine.PlaybackSpeed-1.38)<1e-6 and math.abs(idleEngine.Volume-.62)<1e-6,"Nitro 100 target preserved above normal")
kart:SetAttribute("KartBoosting",true)
for _=1,240 do engineHeartbeat:Fire(1/60) end
assert(math.abs(idleEngine.PlaybackSpeed-1.48)<1e-6,"Mini Boost pitch emphasis preserved")
kart:SetAttribute("KartBoosting",false)
kart.children.Chassis.AssemblyLinearVelocity=rb.Vector3.new(0,0,-70)
for _=1,240 do engineHeartbeat:Fire(1/60) end
player:SetAttribute("RaceState","FINISHING");player:SetAttribute("RaceFinishPhase","ROLL")
for _=1,120 do engineHeartbeat:Fire(1/60) end
assert(idleEngine.PlaybackSpeed>config.ENGINE.IDLE_PLAYBACK_SPEED,"ROLL still uses real movement")
for _,state in {"FINISHING","FINISHED"} do
 player:SetAttribute("RaceState",state);player:SetAttribute("RaceFinishPhase","PRESENT")
 kart:SetAttribute("KartBoosting",true)
 for _=1,240 do engineHeartbeat:Fire(1/60) end
 assert(math.abs(idleEngine.PlaybackSpeed-config.ENGINE.IDLE_PLAYBACK_SPEED)<1e-6,"stopped finish idle pitch")
 assert(math.abs(idleEngine.Volume-config.ENGINE.IDLE_VOLUME)<1e-6,"stopped finish idle volume")
end
player:SetAttribute("RaceState","RACING");player:SetAttribute("RaceFinishPhase",nil);kart:SetAttribute("KartBoosting",false)
for _=1,240 do engineHeartbeat:Fire(1/60) end
assert(idleEngine.PlaybackSpeed>config.ENGINE.IDLE_PLAYBACK_SPEED+.1,"rematch returns to normal dynamic V1 audio")
print("PASS: stopped PRESENT idle pitch/volume, stale velocity, ROLL and Rematch audio")
