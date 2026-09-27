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
