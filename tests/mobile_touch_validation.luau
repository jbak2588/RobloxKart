-- lune run tests/mobile_touch_validation.luau
-- Executes production input/model/controller with mocked Roblox signals and GUI geometry.
-- Covers transport and lifecycle, not hardware multi-touch or server physics.
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local V2, V3 = rb.Vector2, rb.Vector3
local count = 0
local function check(value, label) assert(value, label); count += 1 end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, f)
			local c = {active=true}; function c:Disconnect() self.active=false end
			table.insert(listeners,{c,f}); return c
		end,
		Fire = function(_, ...) for _, p in table.clone(listeners) do if p[1].active then p[2](...) end end end,
	}
end
local methods = {}
local safeSize = V2.new(801,334)
local function object(class, name)
	local p = {ClassName=class,Name=name or class,Enabled=true,Visible=true,Health=100,
		Size=rb.UDim2.fromScale(1,1),Position=rb.UDim2.fromScale(0,0),AnchorPoint=V2.zero}
	for _, event in {"InputBegan","InputChanged","InputEnded","Activated","Destroying","ChildAdded",
		"CharacterAdded","CharacterRemoving","WindowFocusReleased","WindowFocused","TextBoxFocused",
		"TextBoxFocusReleased","Heartbeat","MenuOpened"} do p[event]=signal() end
	return setmetatable({_p=p,_children={},_attrs={},_signals={},_properties={}}, {
		__index=function(self,k)
			if methods[k] then return methods[k] end
			if k=="AbsoluteSize" then
				if class=="ScreenGui" or not p.Parent then return safeSize end
				local size=p.Parent.AbsoluteSize
				return V2.new(size.X*p.Size.X.Scale+p.Size.X.Offset,size.Y*p.Size.Y.Scale+p.Size.Y.Offset)
			elseif k=="AbsolutePosition" then
				if class=="ScreenGui" or not p.Parent then return V2.zero end
				local size=p.Parent.AbsoluteSize
				return p.Parent.AbsolutePosition+V2.new(size.X*p.Position.X.Scale+p.Position.X.Offset,
					size.Y*p.Position.Y.Scale+p.Position.Y.Offset)-self.AbsoluteSize*p.AnchorPoint
			end
			if p[k]~=nil then return p[k] end
			return self:FindFirstChild(k)
		end,
		__newindex=function(self,k,v)
			local old=p[k]
			if k=="Parent" then
				if old then local i=table.find(old._children,self); if i then table.remove(old._children,i) end end
				if v then table.insert(v._children,self) end
			end
			p[k]=v
			if old~=v and self._properties[k] then self._properties[k]:Fire() end
		end,
	})
end
function methods:FindFirstChild(name,recursive)
	for _, c in self._children do if c.Name==name then return c end end
	if recursive then for _,c in self._children do local found=c:FindFirstChild(name,true);if found then return found end end end
end
function methods:GetChildren() return table.clone(self._children) end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
function methods:FindFirstChildOfClass(class) for _, c in self._children do if c.ClassName==class then return c end end end
function methods:GetAttribute(k) return self._attrs[k] end
function methods:SetAttribute(k,v) local old=self._attrs[k]; self._attrs[k]=v; if old~=v and self._signals[k] then self._signals[k]:Fire() end end
function methods:GetAttributeChangedSignal(k) if not self._signals[k] then self._signals[k]=signal() end; return self._signals[k] end
function methods:GetPropertyChangedSignal(k) if not self._properties[k] then self._properties[k]=signal() end; return self._properties[k] end
function methods:Destroy() self.Destroying:Fire(); self.Parent=nil end
function methods:FireServer(...) table.insert(self._p.calls,table.pack(...)) end
local function child(parent,class,name) local o=object(class,name); o.Parent=parent; return o end
local services={}
for _, name in {"Players","ReplicatedStorage","RunService","UserInputService","GuiService"} do services[name]=object(name) end
local player=child(services.Players,"Player","LocalPlayer")
local pg=child(player,"PlayerGui","PlayerGui")
local defaultGui=child(pg,"ScreenGui","TouchGui")
local character=object("Model","Character"); player.Character=character
local humanoid=child(character,"Humanoid")
local kart=object("Model","Kart"); local seat=child(kart,"Seat"); seat:SetAttribute("PrototypeKartSeat",true); humanoid.SeatPart=seat
local shared=child(services.ReplicatedStorage,"Folder","Shared"); child(shared,"ModuleScript","KartConfig")
local control=child(services.ReplicatedStorage,"RemoteEvent","KartControl"); control._p.calls={}
local item=child(services.ReplicatedStorage,"RemoteEvent","RaceItemControl"); item._p.calls={}
local modulesFolder=object("Folder")
local modules={KartConfig={REMOTE_EVENT_NAME="KartControl",INPUT_SEND_INTERVAL=0.05,DEBUG_TELEMETRY=true}}
for _, name in {"KartInputController","TouchDrivingModel","MobileControlView","MobileTutorialView","DriftChargeView","DriftChargeController","TouchDrivingController"} do child(modulesFolder,"ModuleScript",name) end
local ui=services.UserInputService
ui.TouchEnabled=true; ui.PreferredInput=rb.Enum.PreferredInput.Touch
local keys, focused = {}, nil
ui.GetFocusedTextBox=function() return focused end
ui.IsKeyDown=function(_,k) return keys[tostring(k)] or false end
services.GuiService.MenuIsOpen=false
local env={game={GetService=function(_,name) return assert(services[name],name) end},
	script={Parent=modulesFolder},require=function(m) return assert(modules[m.Name],m.Name) end,
	Instance={new=object},Vector2=V2,Vector3=V3,UDim2=rb.UDim2,UDim=rb.UDim,Color3=rb.Color3,Enum=rb.Enum}
for _, name in {"TouchDrivingModel","MobileControlView","MobileTutorialView","DriftChargeView","KartInputController","DriftChargeController","TouchDrivingController"} do
	modules[name]=luau.load(fs.readFile("src/client/"..name..".luau"),{environment=env})()
end
local tutorialRoot=object("Frame")
local tutorial=modules.MobileTutorialView.create(tutorialRoot)
local tutorialOverlay=tutorialRoot.MobileControlsTutorial
local tutorialCard=tutorialOverlay.TutorialCard
local iconSlots=tutorialCard.ActualControlIcons
local function assertTutorialIcons(kinds)
	for index,kind in kinds do
		local holder=iconSlots["IconSlot"..index]
		local icon=holder[kind.."Icon"]
		check(holder.Visible and icon~=nil and icon.ZIndex>holder.ZIndex and icon.ZIndex>tutorialCard.ZIndex,"tutorial actual icon above card: "..kind)
		local shapes=0
		for _, child in icon:GetChildren() do
			if child.ClassName=="Frame" then
				shapes+=1
				check(child.ZIndex>icon.ZIndex,"tutorial icon shape is visible above root: "..kind)
			end
		end
		check(shapes>0,"tutorial icon has visible shapes: "..kind)
	end
end
check(not tutorial.isOpen(),"tutorial starts closed")
tutorial.open()
check(tutorial.isOpen() and tutorialCard.Title.Text=="DRIVE","tutorial opens on DRIVE")
check(not tutorialCard.Diagram.Visible and tutorialCard.Diagram.Text=="","DRIVE has no duplicate arrow row")
assertTutorialIcons({"Forward","Left","Right","Brake"})
tutorialCard.Next.Activated:Fire()
check(tutorialCard.Title.Text=="DRIFT & BOOST","tutorial advances to drift")
check(tutorialCard.Diagram.Visible,"DRIFT diagram remains visible")
assertTutorialIcons({"Drift","Left","Right"})
local examples=tutorialCard.GaugeExamples
check(examples.Visible and #examples.ChargingGauge:GetChildren()==6 and #examples.ReadyGauge:GetChildren()==6,"tutorial has two native five-segment gauges")
check(examples.ChargingGauge.Segment3.BackgroundColor3==rb.Color3.fromRGB(65,225,245)
	and examples.ChargingGauge.Segment4.BackgroundColor3==rb.Color3.fromRGB(45,60,70),"charging example has three cyan segments")
check(examples.ReadyGauge.Segment5.BackgroundColor3==rb.Color3.fromRGB(255,218,75),"ready example has five gold segments")
check(not string.find(tutorialCard.Diagram.Text,"▰",1,true) and not string.find(tutorialCard.Diagram.Text,"▱",1,true),"tutorial gauge uses no Unicode blocks")
tutorialCard.Next.Activated:Fire()
check(tutorialCard.Title.Text=="RACE ITEMS","tutorial advances to items")
check(not tutorialCard.Diagram.Visible and tutorialCard.Diagram.Text=="","item page has no spacing-based text row")
local captions=tutorialCard.ItemCaptions
check(captions.Visible and #captions:GetChildren()==4,"item page has four independent captions")
for index,name in {"NITRO","SLICK","SHIELD","USE"} do
 local caption=captions:FindFirstChild("Caption"..index)
 local slot=iconSlots:FindFirstChild("IconSlot"..index)
 check(caption.Text==name and caption.TextXAlignment==rb.Enum.TextXAlignment.Center
  and caption.Position.X.Offset+caption.Size.X.Offset/2==slot.Position.X.Offset+slot.Size.X.Offset/2,
  "item caption centers on its icon column: "..name)
end
assertTutorialIcons({"Nitro","Slick","Shield","Use"})
check(not string.find(fs.readFile("src/client/GarageUiController.luau"),"CONTROLS ?",1,true),"Garage control replay label has no question mark")
tutorialCard.Back.Activated:Fire()
check(tutorialCard.Title.Text=="DRIFT & BOOST","tutorial back works")
tutorialCard.Next.Activated:Fire(); tutorialCard.Next.Activated:Fire()
check(not tutorial.isOpen(),"GOT IT closes tutorial")
tutorial.open()
check(tutorialCard.Title.Text=="DRIVE","tutorial replay restarts at DRIVE")
tutorial.close()
for _, case in {
	{V2.new(852,393),V2.new(176,0),V2.new(830,58)},
	{V2.new(640,320),V2.new(146,0),V2.new(622,48)},
	{V2.new(1024,768),V2.new(190,0),V2.new(1000,64)},
} do
	local area={Min=case[2],Max=case[3],Width=case[3].X-case[2].X}
	local position=modules.MobileControlView.speedTopbarPosition(case[1],area,160,56)
	check(position.X-80>=area.Min.X+8 and position.X+80<=area.Max.X-8,"speed panel avoids topbar controls and cutout")
	check(position.Y>=area.Min.Y and position.Y<=area.Max.Y,"speed panel aligns to top control band")
end
local model=modules.TouchDrivingModel
local legacy = require("@lune/process").args[1] == "Joystick"
if legacy then model.MobileDriveControlMode = "Joystick" end
for _, case in {{0,0,1,0},{0,-100,1,0},{0,100,-1,0},{-100,0,1,-1},{100,0,1,1},{5,-5,1,0},{0,5,1,0}} do
	local t,s=model.sample(case[1],case[2],100); check(t==case[3] and s==case[4],"cardinal / neutral")
end
local t,s=model.sample(50,-50,100); check(t==1 and s>0 and s<1,"forward with analog steering")
for _, xy in {{100,-100},{-100,-100},{100,100},{-100,100}} do
	local throttle,steer,x,y=model.sample(xy[1],xy[2],50)
	check(math.sign(throttle)==-math.sign(xy[2]) and math.sign(steer)==math.sign(xy[1]) and x*x+y*y<1.001,"saturation and quadrants")
end
check(model.sample(math.huge,0,100)==0,"non-finite input")
local input=modules.KartInputController; input.start()
player:SetAttribute("RaceState","RACING"); player:SetAttribute("SelectedRaceItemId","Nitro"); player:SetAttribute("RaceChargeNitro",1)
modules.TouchDrivingController.start()
modules.DriftChargeController.start()
local gui=pg.RobloxKartTouchDriving; local root=gui.Controls
local joy,drift,use=root.RightJoystick,root.Drift,root.UseItem
local function tick() services.RunService.Heartbeat:Fire(0.05) end
local function latest() return control._p.calls[#control._p.calls] end
local function neutral(label) tick(); local a=latest(); check(a[1]==0 and a[2]==0 and a[3]==false,label) end
local function touch(target,dx,dy)
	local f=object("InputObject"); f.UserInputType=rb.Enum.UserInputType.Touch; f.KeyCode=rb.Enum.KeyCode.Unknown; f.UserInputState=rb.Enum.UserInputState.Begin
	local c=joy.AbsolutePosition+joy.AbsoluteSize/2
	f.Position=V3.new(c.X+(dx or 0),c.Y+(dy or 0),0); target.InputBegan:Fire(f); tick(); return f
end
tick(); check(root.Visible and not defaultGui.Enabled,"race controls own mobile area")
local sharedGui=pg.RobloxKartDriftCharge
local gauge=sharedGui.SharedDriftDisplay.DriftChargeGauge
local diagnostic=sharedGui.SharedDriftDisplay.DriftDiagnostic
check(gauge.Active==false and gauge.Selectable==false and diagnostic.Active==false and diagnostic.Selectable==false,"gauge/diagnostics never intercept input")
for _,case in {{0,0},{.19,0},{.20,1},{.40,2},{.60,3},{.80,4},{1,5}} do
	kart:SetAttribute("KartDrifting",true)
	kart:SetAttribute("KartDriftChargeProgress",case[1]);kart:SetAttribute("KartDriftChargeReady",case[1]==1);tick()
	check(gauge.Visible and gauge:GetAttribute("LitSegments")==case[2],"server progress battery threshold")
	if case[1]==.19 then check(math.abs(gauge.Segment1.Fill.Size.X.Scale-.95)<1e-6,"partial first cell reacts below 20 percent") end
end
check(gauge:FindFirstChildOfClass("UIStroke").Thickness==3,"ready pulses once")
check(string.find(diagnostic.Text,"DT ",1,true)~=nil and string.find(diagnostic.Text,"Δ",1,true)==nil,"server delta uses ASCII DT")
for _=1,8 do tick() end
check(gauge:FindFirstChildOfClass("UIStroke").Thickness==1,"ready pulse expires without repeating")
kart:SetAttribute("KartDriftDiagEndSerial",0);tick()
kart:SetAttribute("KartDriftChargeProgress",0);kart:SetAttribute("KartDriftChargeReady",false);kart:SetAttribute("KartDrifting",false)
kart:SetAttribute("KartDriftDiagEndReason","input_timeout");kart:SetAttribute("KartDriftDiagBoostEligible",false)
kart:SetAttribute("KartDriftDiagEndSerial",1);tick()
check(diagnostic.Visible and string.find(diagnostic.Text,"input_timeout",1,true)~=nil,"end result shows timeout")
for _=1,8 do tick() end
check(not gauge.Visible and diagnostic.Visible,"short gauge feedback, longer diagnostic retention")
for _=1,40 do tick() end
check(not diagnostic.Visible,"diagnostic hides after two seconds")
local heldProbe=touch(drift);for _=1,40 do tick() end
check(gauge.Visible and gauge:GetAttribute("LitSegments")==0,"held button never invents charge")
heldProbe.UserInputState=rb.Enum.UserInputState.End;tick()
local productionGauge=modules.DriftChargeView.create(object("Frame"),false)
check(productionGauge.diagnostic==nil,"debug-off creates no diagnostic text")
kart:SetAttribute("KartDriftChargeProgress",.6)
productionGauge:update(true,kart,false,.12)
check(productionGauge.frame.Visible and productionGauge.frame:GetAttribute("LitSegments")==3,"debug-off player gauge remains functional")
tick();check(gauge:GetAttribute("LitSegments")==3,"mobile server progress .60")
ui.PreferredInput=rb.Enum.PreferredInput.KeyboardAndMouse;tick()
check(gauge.Visible and gauge:GetAttribute("LitSegments")==3,"PC uses same server progress without duplicate gauge")
check(gauge.Position.X.Scale==.5,"PC gauge bottom center")
ui.PreferredInput=rb.Enum.PreferredInput.Touch;tick()
check(sharedGui.SharedDriftDisplay.DriftChargeGauge==gauge and gauge:GetAttribute("LitSegments")==3,"input mode switch reuses same gauge")
kart:SetAttribute("KartDriftChargeProgress",0);kart:SetAttribute("KartBoosting",true);tick()
check(gauge:GetAttribute("LitSegments")==5 and gauge:FindFirstChildOfClass("UIStroke").Thickness==3,"boost success fills and flashes even without diagnostic result")
local startTransparency=gauge.BackgroundTransparency
tick();check(gauge.BackgroundTransparency>startTransparency,"success fades smoothly")
for _=1,8 do tick() end
check(not gauge.Visible and gauge:GetAttribute("LitSegments")==0,"success resets after fade")
kart:SetAttribute("KartBoosting",false)
ui.PreferredInput=rb.Enum.PreferredInput.KeyboardAndMouse
keys[tostring(rb.Enum.KeyCode.W)]=true;keys[tostring(rb.Enum.KeyCode.A)]=true;keys[tostring(rb.Enum.KeyCode.LeftShift)]=true
for _=1,12 do tick() end
check(not gauge.Visible and gauge:GetAttribute("LitSegments")==0,"PC Shift without server charge does not invent progress")
keys={};ui.PreferredInput=rb.Enum.PreferredInput.Touch;tick()
local auto=root.AutoForward
if legacy then
local finger=touch(joy,15,-30); local a=latest()
check(a.n==3 and a[1]==1 and a[2]>0,"unchanged KartControl protocol / forward diagonal")
local heldT,heldS=a[1],a[2]
local second=touch(joy,-50,50); check(latest()[1]==heldT and latest()[2]==heldS,"second finger cannot steal joystick")
local d=touch(drift); check(latest()[3] and latest()[1]==heldT,"joystick plus drift")
input.selectRaceItem("Shield"); use.Activated:Fire(); tick()
check(item._p.calls[1][1]=="Select" and item._p.calls[1][2]=="Shield" and item._p.calls[2][1]=="Use","selection/use existing actions")
check(latest()[1]==heldT and latest()[2]==heldS and latest()[3],"item actions preserve simultaneous driving/drift")
second.UserInputState=rb.Enum.UserInputState.End; ui.InputEnded:Fire(second); tick()
check(latest()[1]==heldT,"unowned release cannot cancel joystick")
d.UserInputState=rb.Enum.UserInputState.Cancel; tick(); check(not latest()[3] and latest()[1]==heldT,"drift cancellation independent")
finger.Position=V3.new(joy.AbsolutePosition.X+joy.AbsoluteSize.X/2,joy.AbsolutePosition.Y+joy.AbsoluteSize.Y,0)
ui.InputChanged:Fire(finger); tick(); check(latest()[1]==-1 and latest()[2]==0,"down delegates brake/reverse")
finger.UserInputState=rb.Enum.UserInputState.Cancel; neutral("cancel clears all axes")
for _, direction in {-1,1} do
	local f=touch(joy,direction*25,-30); local driftFinger=touch(drift)
	check(latest()[1]>0 and math.sign(latest()[2])==direction and latest()[3],"both diagonal drift combinations")
	for _, id in {"Nitro","Slick","Shield"} do
		input.selectRaceItem(id); use.Activated:Fire(); tick()
		check(latest()[1]>0 and math.sign(latest()[2])==direction and latest()[3],"selection/use does not cancel held axes")
	end
	f.UserInputState=rb.Enum.UserInputState.End; tick()
	check(latest()[1]==0 and latest()[2]==0 and latest()[3],"joystick End preserves independently held drift")
	driftFinger.UserInputState=rb.Enum.UserInputState.End; neutral("all owners ended")
end
local auto=root.AutoForward
check(auto:FindFirstChild("Status")==nil,"auto mode has no ON/OFF text label")
local shackle=auto.AutoForwardIcon.LockShackle
local openRotation=shackle.Rotation
local offTransparency=auto.BackgroundTransparency
local centered=touch(joy,0,0); check(latest()[1]==1 and latest()[2]==0,"center contact drives forward")
centered.UserInputState=rb.Enum.UserInputState.End; neutral("default release coasts")
auto.Activated:Fire(); tick(); check(latest()[1]==1 and gui:GetAttribute("AutoForwardEnabled"),"auto drives without a finger")
check(shackle.Rotation~=openRotation and auto.BackgroundTransparency<offTransparency,"auto state differs by lock shape and fill, not only color")
local reverse=touch(joy,0,50); check(latest()[1]==-1,"brake/reverse overrides auto")
reverse.UserInputState=rb.Enum.UserInputState.End; tick(); check(latest()[1]==1,"release resumes auto")
auto.Activated:Fire(); neutral("auto OFF coasts")
check(shackle.Rotation==openRotation and auto.BackgroundTransparency==offTransparency,"auto OFF visual restored")
auto.Activated:Fire(); local cancelled=touch(joy,10,0); cancelled.UserInputState=rb.Enum.UserInputState.Cancel
neutral("cancelled joystick disables auto")
else
	check(not joy.Visible and root.Forward.Visible and gui:GetAttribute("MobileDriveControlMode")=="Buttons","digital default hides legacy joystick")
	local ignored=touch(joy); neutral("legacy stick cannot activate in Buttons mode")
	local f=touch(root.Forward); check(latest()[1]==1,"forward press")
	local b=touch(root.Brake); check(latest()[1]==-1,"brake overrides held forward")
	b.UserInputState=rb.Enum.UserInputState.End; tick(); check(latest()[1]==1,"forward resumes after brake")
	f.UserInputState=rb.Enum.UserInputState.End; neutral("forward release auto OFF")
	auto.Activated:Fire(); f=touch(root.Forward)
	f.UserInputState=rb.Enum.UserInputState.End; tick(); check(latest()[1]==1,"forward release keeps auto ON")
	auto.Activated:Fire(); neutral("digital auto OFF coasts")
	f=touch(root.Left); local extra=touch(root.Left)
	f.UserInputState=rb.Enum.UserInputState.End; tick(); check(latest()[2]==-1,"same-direction second owner survives first release")
	extra.UserInputState=rb.Enum.UserInputState.End; neutral("last same-direction owner released")
	for _, direction in {-1,1} do
		local button=if direction==-1 then root.Left else root.Right
		local other=if direction==-1 then root.Right else root.Left
		f=touch(root.Forward); local steer=touch(button)
		check(latest()[2]==direction and not latest()[3],"normal digital steering remains full")
		local d=touch(drift)
		check(latest()[2]==direction*0.60 and latest()[3],"drift press immediately reduces digital steering")
		check(input.getEffectiveSteering()==direction*0.60,"drift steering HUD action sync")
		-- Moving far outside the button must not change a held digital target.
		for i=1,90 do
			steer.Position=V3.new(i*100,-i*70,0); ui.InputChanged:Fire(steer); tick()
			check(latest()[1]==1 and latest()[2]==direction*0.60 and latest()[3],"stable forward/steering/drift across pointer movement")
		end
		other.InputBegan:Fire(steer); tick(); check(latest()[2]==direction*0.60,"one finger cannot own two buttons")
		local opposite=touch(other); check(latest()[2]==-direction*0.60,"last pressed wins")
		opposite.UserInputState=rb.Enum.UserInputState.End; tick(); check(latest()[2]==direction*0.60,"release falls back to held direction")
		for _, id in {"Nitro","Slick","Shield"} do
			input.selectRaceItem(id); use.Activated:Fire(); tick()
			check(latest()[1]==1 and latest()[2]==direction*0.60 and latest()[3],"digital drift and item actions coexist")
		end
		d.UserInputState=rb.Enum.UserInputState.End; tick()
		check(latest()[1]==1 and latest()[2]==direction and not latest()[3],"drift release preserves throttle/steer for existing boost condition")
		check(input.getEffectiveSteering()==direction,"steering HUD action sync")
		steer.UserInputState=rb.Enum.UserInputState.End; f.UserInputState=rb.Enum.UserInputState.End; neutral("all buttons released")
		auto.Activated:Fire(); steer=touch(button); d=touch(drift)
		for _=1,30 do tick(); check(latest()[1]==1 and latest()[2]==direction*0.60 and latest()[3],"auto stable drift") end
		b=touch(root.Brake); check(latest()[1]==-1 and latest()[2]==direction*0.60,"auto brake and reverse steer use shared actions")
		b.UserInputState=rb.Enum.UserInputState.End; tick(); check(latest()[1]==1,"auto resumes after brake")
		d.UserInputState=rb.Enum.UserInputState.End; tick()
		check(latest()[1]==1 and latest()[2]==direction and not latest()[3],"auto drift release restores full steering")
		steer.UserInputState=rb.Enum.UserInputState.Cancel; neutral("cancel disables auto")
	end
	check(#item._p.calls==12,"all digital item select/use calls delivered")
end
local function hold()
	tick(); touch(if legacy then joy else root.Forward,20,-40)
	if not legacy then touch(root.Left); touch(root.Right); touch(root.Brake) end
	touch(drift)
	if not gui:GetAttribute("AutoForwardEnabled") then auto.Activated:Fire() end
	check(latest()[1]==(if legacy then 1 else -1) and latest()[3],"hold established")
	kart:SetAttribute("KartDriftChargeProgress",1);kart:SetAttribute("KartDriftChargeReady",true);tick()
	check(gauge.Visible and gauge:GetAttribute("LitSegments")==5,"lifecycle fixture starts READY")
end
for _, race in {"FINISHED","FINISHING","DNF","GARAGE","COUNTDOWN"} do
	player:SetAttribute("RaceState","RACING"); hold(); player:SetAttribute("RaceState",race); neutral("race transition "..race)
	check(not gauge.Visible and not diagnostic.Visible,"race transition hides READY and diagnostic")
end
player:SetAttribute("RaceState","RACING")
hold(); gui.Enabled=false; neutral("disabled GUI"); gui.Enabled=true
hold(); root.Visible=false; neutral("hidden controls reset ownership")
hold(); humanoid.SeatPart=nil; neutral("seat loss"); humanoid.SeatPart=seat
hold(); player.CharacterRemoving:Fire(character); neutral("character removal"); player.CharacterAdded:Fire(character)
hold(); ui.WindowFocusReleased:Fire(); neutral("focus loss"); ui.WindowFocused:Fire()
hold(); focused={}; ui.TextBoxFocused:Fire(); neutral("textbox focus"); focused=nil
hold(); services.GuiService.MenuIsOpen=true; services.GuiService.MenuOpened:Fire(); neutral("menu opened"); services.GuiService.MenuIsOpen=false
hold(); kart:SetAttribute("RaceControlsLocked",true); neutral("race controls locked"); kart:SetAttribute("RaceControlsLocked",false)
hold(); kart:SetAttribute("RaceResetSerial",1); neutral("race reset serial")
hold(); ui.PreferredInput=rb.Enum.PreferredInput.KeyboardAndMouse; keys[tostring(rb.Enum.KeyCode.W)]=true; keys[tostring(rb.Enum.KeyCode.A)]=true; tick()
check(latest()[1]==1 and latest()[2]==-1 and not root.Visible and defaultGui.Enabled,"keyboard W/A remains unchanged; stock controls restored")
keys={}; neutral("keyboard release")
for _, case in {{rb.Enum.KeyCode.W,rb.Enum.KeyCode.D,1,1},{rb.Enum.KeyCode.S,rb.Enum.KeyCode.A,-1,-1},{rb.Enum.KeyCode.S,rb.Enum.KeyCode.D,-1,1}} do
	keys[tostring(case[1])]=true; keys[tostring(case[2])]=true; keys[tostring(rb.Enum.KeyCode.LeftShift)]=true; tick()
	check(latest()[1]==case[3] and latest()[2]==case[4] and latest()[3],"PC throttle/steering/Shift regression")
	keys={}; neutral("PC release")
end
for i,key in {rb.Enum.KeyCode.One,rb.Enum.KeyCode.Two,rb.Enum.KeyCode.Three} do
	local k=object("InputObject"); k.KeyCode=key; ui.InputBegan:Fire(k,false)
	local call=item._p.calls[#item._p.calls]
	check(call[1]=="Select" and call[2]==({"Nitro","Slick","Shield"})[i],"PC item selection")
end
local q=object("InputObject"); q.KeyCode=rb.Enum.KeyCode.Q; ui.InputBegan:Fire(q,false); ui.InputEnded:Fire(q)
check(item._p.calls[#item._p.calls][1]=="Use","PC Q item trigger")
ui.PreferredInput=rb.Enum.PreferredInput.Touch
-- Verify reserved thumb/display rectangles remain separate at representative safe sizes.
local function overlaps(a,b) return a[1]<b[3] and b[1]<a[3] and a[2]<b[4] and b[2]<a[4] end
for _, size in {V2.new(801,334),V2.new(749,303),V2.new(473,240),V2.new(389,703),V2.new(320,568),V2.new(929,688)} do
	safeSize=size; root:GetPropertyChangedSignal("AbsoluteSize"):Fire(); tick()
	local l=modules.MobileControlView.layout(size)
	check(l.speedTop>=2 and l.speedTop<8 and l.speedTop+l.speedHeight<size.Y,"speed HUD rises without leaving safe region")
	check(l.speedHeight==56,"speed HUD keeps compact box height")
	check(math.abs(gauge.AbsolutePosition.X+gauge.AbsoluteSize.X/2-drift.AbsolutePosition.X-drift.AbsoluteSize.X/2)<=.5,"gauge centered on DRIFT")
	check(math.abs(drift.AbsolutePosition.Y-gauge.AbsolutePosition.Y-gauge.AbsoluteSize.Y-l.driftGaugeGap)<=.5,"mobile gauge keeps an eight-pixel pulse-safe gap")
	local mobileClip=child(root,"Frame","ClipPreview")
	local mobileWheel=child(root,"Frame","WheelPreview")
	modules.MobileControlView.layoutSteeringWheel(mobileClip,mobileWheel,{},size,true)
	check(mobileWheel.Parent==mobileClip and mobileClip.ClipsDescendants and not mobileClip.Active,"mobile wheel uses display-only clip")
	check(math.abs(mobileClip.AbsoluteSize.Y-l.wheel*2/3)<1 and math.abs(mobileWheel.AbsoluteSize.X-l.wheel)<1,"mobile wheel geometry preserved within pixel rounding")
	check(mobileClip.AbsolutePosition.Y+mobileClip.AbsoluteSize.Y==size.Y-3,"mobile clip leaves a three-pixel bottom margin")
	mobileWheel:Destroy();mobileClip:Destroy()
	local rects={}
	local buttons=if legacy then {joy,drift,use,auto,gauge,diagnostic} else {root.Forward,root.Left,root.Right,root.Brake,drift,use,auto,gauge,diagnostic}
	for _, button in buttons do
		local p,z=button.AbsolutePosition,button.AbsoluteSize
		table.insert(rects,{p.X,p.Y,p.X+z.X,p.Y+z.Y})
	end
	if size.X>=500 or size.Y<=size.X then
		local minimap={size.X-112,8,size.X-12,108}
		for _, r in rects do check(not overlaps(r,minimap),"driving buttons avoid minimap") end
	end
	local speedX=if size.X<450 then size.X-172 else size.X/2-80
	check(not overlaps(rects[#rects],{speedX,l.speedTop,speedX+160,l.speedTop+l.speedHeight}),"debug avoids speed HUD including inset phone width")
	table.insert(rects,{l.margin,size.Y-l.loadoutBottom-l.slot,l.margin+l.slot*3+l.gap*2,size.Y-l.loadoutBottom})
	table.insert(rects,{size.X/2-l.wheel/2,size.Y-3-l.wheel*2/3,size.X/2+l.wheel/2,size.Y-3})
	for i,r in rects do
		check(r[1]>=0 and r[2]>=0 and r[3]<=size.X and r[4]<=size.Y,"inside safe area")
		for j=i+1,#rects do check(not overlaps(r,rects[j]),"thumb zones / display never overlap "..tostring(size).." rects "..i.."/"..j) end
	end
end
-- Desktop and compact PC placement uses the actual steering display geometry.
for _,size in {V2.new(1920,1080),V2.new(1280,720),V2.new(801,334)} do
	safeSize=size
	local previewRoot=object("Frame")
	local clip=child(previewRoot,"Frame","Clip")
	local wheel=child(previewRoot,"Frame","SteeringDisplay")
	local diameter=if size.Y<=650 then 84 else 112
	modules.MobileControlView.layoutSteeringWheel(clip,wheel,{},size,false)
	check(wheel.Parent==clip and clip.ClipsDescendants and not clip.Active,"desktop wheel uses display-only clip")
	check(math.abs(clip.AbsoluteSize.Y/diameter-2/3)<.01 and wheel.AbsoluteSize.Y==diameter,"desktop upper two-thirds visible")
	check(clip.AbsolutePosition.Y+clip.AbsoluteSize.Y==size.Y-3,"desktop clip leaves a three-pixel bottom margin")
	check(previewRoot:FindFirstChild("SteeringDisplay",true)==wheel,"nested wheel can be found by gauge controller")
	local preview=modules.DriftChargeView.create(previewRoot,true)
	preview:layout(size,false,wheel,V2.zero)
	local g=preview.frame
	check(math.abs(g.AbsolutePosition.X+g.AbsoluteSize.X/2-size.X/2)<=.5,"desktop gauge centered "..tostring(size).." p="..tostring(g.AbsolutePosition).." sz="..tostring(g.AbsoluteSize).." wheel="..tostring(wheel.AbsolutePosition))
	check(math.abs(g.AbsolutePosition.Y+g.AbsoluteSize.Y-wheel.AbsolutePosition.Y+10)<=.5,"desktop gauge has ten-pixel wheel gap")
	check(g.AbsoluteSize.X>=140 and g.AbsoluteSize.X<=160 and g.AbsoluteSize.Y==(if size.Y<=650 then 18 else 20),"desktop compact gauge dimensions")
	local d=preview.diagnostic
	check(d.AbsolutePosition.X>size.X/2 and d.AbsolutePosition.Y>size.Y/2,"desktop debug uses bottom-right corner")
end
hold(); gui:Destroy(); sharedGui:Destroy(); neutral("destroyed GUI"); check(defaultGui.Enabled,"destroy restores stock controls")
check(not gauge.Visible and not diagnostic.Visible,"GUI destruction clears charge display")
print("PASS: "..count.." mobile input, lifecycle, transport and layout checks (mocked; no hardware multi-touch)")
