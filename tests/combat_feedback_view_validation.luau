-- Production view execution; deterministic signals/time and screen-space GUI bounds.
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local count, now = 0, 0
local function check(v,label) assert(v,label);count+=1 end
local function signal()
	local listeners={}
	return {Connect=function(_,f)
		local entry={f=f,alive=true};table.insert(listeners,entry)
		return {Disconnect=function() entry.alive=false end}
	end,Fire=function(_,...) for _,entry in listeners do if entry.alive then entry.f(...) end end end}
end
local function object(class)
	local data={ClassName=class,Position=rb.UDim2.fromOffset(0,0),Size=rb.UDim2.fromOffset(0,0),
	 AnchorPoint=rb.Vector2.zero,Visible=true,Destroying=signal(),CharacterRemoving=signal()}
	local attrs,signals,children={},{},{}
	local self
	local methods={}
	function methods:GetAttribute(k) return attrs[k] end
	function methods:SetAttribute(k,v) local old=attrs[k];attrs[k]=v;if old~=v and signals[k] then signals[k]:Fire() end end
	function methods:GetAttributeChangedSignal(k) if not signals[k] then signals[k]=signal() end;return signals[k] end
	function methods:FindFirstChildOfClass(k) for _,c in children do if c.ClassName==k then return c end end end
	function methods:FindFirstChild(k) for _,c in children do if c.Name==k then return c end end end
	function methods:Destroy() self.Destroying:Fire();self.Parent=nil end
	self=setmetatable({}, {__index=function(_,k)
		if methods[k] then return methods[k] end
		if k=="AbsoluteSize" then
			if data.bounds then return data.bounds end
			local p=data.Parent and data.Parent.AbsoluteSize or rb.Vector2.zero
			return rb.Vector2.new(p.X*data.Size.X.Scale+data.Size.X.Offset,p.Y*data.Size.Y.Scale+data.Size.Y.Offset)
		end
		if k=="AbsolutePosition" then
			if data.origin then return data.origin end
			local p=data.Parent and data.Parent.AbsolutePosition or rb.Vector2.zero
			local s=data.Parent and data.Parent.AbsoluteSize or rb.Vector2.zero
			return p+rb.Vector2.new(s.X*data.Position.X.Scale+data.Position.X.Offset-self.AbsoluteSize.X*data.AnchorPoint.X,
			 s.Y*data.Position.Y.Scale+data.Position.Y.Offset-self.AbsoluteSize.Y*data.AnchorPoint.Y)
		end
		return data[k]
	end,__newindex=function(_,k,v) data[k]=v;if k=="Parent" and v then table.insert(v.children,self) end end})
	self.children=children
	return self
end
local logs={}
local config={DEBUG_TELEMETRY=true}
local shared={WaitForChild=function() return {} end}
local heartbeat=signal()
local env={game={GetService=function(_,name)
	if name=="RunService" then return {Heartbeat=heartbeat} end
	return {WaitForChild=function() return shared end}
end},require=function() return config end,Instance={new=object},UDim=rb.UDim,UDim2=rb.UDim2,
 Vector2=rb.Vector2,Enum=rb.Enum,Color3=rb.Color3,time=function() return now end,
 print=function(message) table.insert(logs,message) end}
local View=luau.load(fs.readFile("src/client/CombatFeedbackView.luau"),{environment=env})()
local gui,player,kart,seat,character,human=object("ScreenGui"),object("Player"),object("Model"),object("Seat"),object("Model"),object("Humanoid")
gui.origin=rb.Vector2.new(44,58);gui.bounds=rb.Vector2.new(844,332)
kart.Parent=object("Workspace");seat.Parent=kart;human.Parent=character
human.Health=100;human.SeatPart=seat;player.Character=character
seat:SetAttribute("PrototypeKartSeat",true);kart:SetAttribute("PrototypeKart",true)
player:SetAttribute("RaceState","RACING");player:SetAttribute("RaceSessionId",1)
local view=View.new(gui,player)
local cue,edge=gui:FindFirstChild("CombatResult"),gui:FindFirstChild("CombatEdge1")
local function tick(dt) now+=dt or 0;heartbeat:Fire() end
local serial=0
local function result(code)
	serial+=1;player:SetAttribute("RaceCombatFeedbackCode",code)
	player:SetAttribute("RaceCombatFeedbackTargetName","RacerB");player:SetAttribute("RaceCombatFeedbackSerial",serial)
end
for _,pair in {{"MISSILE_HIT","HIT: RacerB"},{"MISSILE_BLOCKED","SHIELD BLOCKED"},
 {"SLICK_HIT","SLICK HIT: RacerB"},{"SLICK_BLOCKED","SLICK BLOCKED"}} do
	result(pair[1]);check(cue.Visible and cue.Text==pair[2],"serial received and rendered "..pair[1])
	tick(1.19);check(cue.Visible,"attacker readable for 1.2 seconds")
	tick(.02);check(not cue.Visible,"attacker expires")
end
tick()
for _,pair in {{"KartMissileHitActive","MISSILE HIT!"},{"KartSlickActive","SLICK HIT!"}} do
	kart:SetAttribute(pair[1],true)
	check(cue.Visible and cue.Text==pair[2] and edge.Visible,"victim attribute renders without waiting for Heartbeat")
	kart:SetAttribute(pair[1],false) -- Both edges may occur between sampled frames.
	tick(.59);check(cue.Visible and edge.Visible,"edge persists .60 seconds")
	tick(.02);check(cue.Visible and not edge.Visible,"badge outlives edge cue")
	tick(.40);check(not cue.Visible,"victim expires after one second")
end
player:SetAttribute("RaceItemBlockedSerial",1)
check(cue.Visible and cue.Text=="BLOCKED!" and cue.TextColor3==rb.Color3.fromRGB(65,225,255),"block victim receives cyan badge")
result("SLICK_HIT");check(cue.Text=="SLICK HIT: RacerB","latest result replaces block immediately")
check(cue.TextSize==17 and cue.BackgroundTransparency==.25 and cue.AbsoluteSize.Y==34 and edge.AbsoluteSize.X==6,
	"readable badge and bounded peripheral width")
local speedGui,speed,warning=object("ScreenGui"),object("Frame"),object("TextLabel")
speed.Parent=speedGui;warning.Parent=gui
speedGui.origin=rb.Vector2.zero;speedGui.bounds=rb.Vector2.new(932,430)
speed.AnchorPoint=rb.Vector2.new(.5,0);speed.Position=rb.UDim2.new(.5,0,0,2);speed.Size=rb.UDim2.fromOffset(160,56)
warning.Position=rb.UDim2.new(.5,0,0,64);warning.AnchorPoint=rb.Vector2.new(.5,0);warning.Size=rb.UDim2.fromOffset(240,40)
local function rect(o) local p,s=o.AbsolutePosition,o.AbsoluteSize;return {p.X,p.Y,p.X+s.X,p.Y+s.Y} end
local function overlaps(a,b) return a[1]<b[3] and b[1]<a[3] and a[2]<b[4] and b[2]<a[4] end
for _,case in {{932,430,44,58,844,332},{844,390,48,58,748,303},{852,393,64,58,724,311}} do
	speedGui.bounds=rb.Vector2.new(case[1],case[2]);gui.origin=rb.Vector2.new(case[3],case[4]);gui.bounds=rb.Vector2.new(case[5],case[6])
	for _,incoming in {false,true} do
		warning.Visible=incoming;view:layout(rb.UDim2.new(.5,0,0,64),warning.Size,warning,speed)
		local badge,safe,speedRect=rect(cue),rect(gui),rect(speed)
		check(badge[1]>=safe[1] and badge[2]>=safe[2] and badge[3]<=safe[3] and badge[4]<=safe[4],"badge within notch-safe screen")
		check(badge[2]>=speedRect[4]+6,"badge below actual speed panel across different GUI insets")
		if incoming then check(badge[2]>=rect(warning)[4]+6,"incoming gets priority above result") end
		local lap={safe[1]+12,safe[2]+8,safe[1]+182,safe[2]+163}
		local map={safe[3]-112,safe[2]+36,safe[3]-12,safe[2]+136}
		local room={safe[3]-192,safe[2]+8,safe[3]-12,safe[2]+30}
		local items={safe[1]+12,safe[4]-160,safe[1]+228,safe[4]-112}
		local road={safe[1]+case[5]*.4,safe[2]+case[6]*.5,safe[1]+case[5]*.6,safe[4]}
		for _,r in {lap,map,room,items,road,speedRect} do check(not overlaps(badge,r),"badge clears driving HUD/road") end
	end
end
local before=#logs;tick();tick();check(#logs==before,"no Heartbeat diagnostic spam")
player:SetAttribute("RaceState","GARAGE");result("MISSILE_HIT")
check(#logs==before+2 and not cue.Visible and string.find(logs[#logs],"suppressed=INACTIVE_KART",1,true),
	"received serial is logged even when lifecycle suppresses presentation")
player:SetAttribute("RaceState","RACING");before=#logs
config.DEBUG_TELEMETRY=false;result("MISSILE_HIT");check(#logs==before,"diagnostics obey telemetry flag")
for _,boundary in {"FINISHED","DNF","GARAGE","COUNTDOWN","PRE_RACE","session","seat","reset","destroy","character"} do
	player.Character=character;human.SeatPart=seat;kart.Parent=object("Workspace")
	player:SetAttribute("RaceState","RACING");tick();result("MISSILE_HIT")
	if boundary=="session" then player:SetAttribute("RaceSessionId",2)
	elseif boundary=="seat" then human.SeatPart=nil
	elseif boundary=="reset" then kart:SetAttribute("RaceResetSerial",1)
	elseif boundary=="destroy" then kart.Parent=nil
	elseif boundary=="character" then player.CharacterRemoving:Fire();player.Character=nil
	else player:SetAttribute("RaceState",boundary) end
	tick();check(not cue.Visible and not edge.Visible,"cleanup "..boundary)
end
view:destroy();check(not cue.Parent and not edge.Parent,"destruction disconnects and removes view")
-- Regression: the initial Kart binding must not swallow an already-replicated hit.
player.Character=character;human.SeatPart=seat;kart.Parent=object("Workspace");player:SetAttribute("RaceState","RACING")
kart:SetAttribute("KartMissileHitActive",true)
local firstGui=object("ScreenGui");firstGui.bounds=rb.Vector2.new(844,332);firstGui.origin=rb.Vector2.zero
local first=View.new(firstGui,player);tick()
check(firstGui:FindFirstChild("CombatResult").Text=="MISSILE HIT!" and firstGui:FindFirstChild("CombatResult").Visible,
	"first binding displays already-replicated active hit")
first:destroy()
print("PASS: "..count.." production combat feedback view checks")
