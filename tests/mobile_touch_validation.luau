-- lune run tests/mobile_touch_validation.luau
-- Executes production input/model/controller with mocked Roblox signals and GUI geometry.
-- Covers transport and lifecycle, not hardware multi-touch or server physics.
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local V2, V3 = rb.Vector2, rb.Vector3
local count = 0
local function check(value, label) assert(value, label); count += 1 end
local chargeSource=fs.readFile("src/client/DriftChargeView.luau")
local itemHudSource=fs.readFile("src/client/RaceItemUiController.luau")
check(string.find(chargeSource,"NitroCharge",1,true)==nil
	and string.find(chargeSource,"NITRO CHARGE",1,true)==nil
	and string.find(chargeSource,"BONUS EARNED",1,true)==nil,
	"DriftChargeView has no cumulative Nitro UI")
check(string.find(itemHudSource,"NITRO CHARGE",1,true)~=nil
	and string.find(itemHudSource,"DRIFT STREAK",1,true)==nil
	and string.find(itemHudSource,"/4",1,true)==nil,
	"RaceItemUiController owns five-count Nitro terminology")
check(require("./helpers/gameplay_config")("src/shared/RaceItemConfig.luau").DRIFT_BONUS_REQUIRED_BOOSTS==3,
	"production Bonus Nitro threshold is three")
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
	local p = {ClassName=class,Name=name or class,ZIndex=1,Enabled=true,Visible=true,Health=100,
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
child(shared,"ModuleScript","RaceItemConfig")
local control=child(services.ReplicatedStorage,"RemoteEvent","KartControl"); control._p.calls={}
local item=child(services.ReplicatedStorage,"RemoteEvent","RaceItemControl"); item._p.calls={}
local modulesFolder=object("Folder")
local modules={KartConfig={REMOTE_EVENT_NAME="KartControl",INPUT_SEND_INTERVAL=0.05,DEBUG_TELEMETRY=true,DEBUG_DRIFT_HUD=true},
	RaceItemConfig={DRIFT_BONUS_REQUIRED_BOOSTS=5,BLOCKED_FEEDBACK_DURATION=.8}}
for _, name in {"KartInputController","TouchDrivingModel","MobileControlView","MobileTutorialView","DriftChargeView","DriftChargeController","TouchDrivingController"} do child(modulesFolder,"ModuleScript",name) end
local ui=services.UserInputService
ui.TouchEnabled=true; ui.PreferredInput=rb.Enum.PreferredInput.Touch
local keys, focused = {}, nil
ui.GetFocusedTextBox=function() return focused end
ui.IsKeyDown=function(_,k) return keys[tostring(k)] or false end
services.GuiService.MenuIsOpen=false
services.ContentProvider={PreloadAsync=function() end}
local env={task={spawn=function() end,delay=function() end},game={GetService=function(_,name) return assert(services[name],name) end},
	script={Parent=modulesFolder},require=function(m) return assert(modules[m.Name],m.Name) end,
	Instance={new=object},Vector2=V2,Vector3=V3,UDim2=rb.UDim2,UDim=rb.UDim,Color3=rb.Color3,Enum=rb.Enum}
for _, name in {"RaceItemCatalog", "RaceItemSlots"} do
	local module=child(shared,"ModuleScript",name)
	local sharedEnv=table.clone(env);sharedEnv.script=module
	modules[name]=luau.load(fs.readFile("src/shared/"..name..".luau"),{environment=sharedEnv})()
end
for index,id in modules.RaceItemSlots.DEFAULT do player:SetAttribute("RaceItemSlot"..index,id) end
child(modulesFolder,"ModuleScript","KDMIconCatalog")
modules.KDMIconCatalog=luau.load(fs.readFile("src/client/KDMIconCatalog.luau"))()
child(modulesFolder,"ModuleScript","KDMControlIconView")
modules.KDMControlIconView=luau.load(fs.readFile("src/client/KDMControlIconView.luau"),{environment=env})()
child(modulesFolder,"ModuleScript","KDMItemIconView")
modules.KDMItemIconView=luau.load(fs.readFile("src/client/KDMItemIconView.luau"),{environment=env})()
child(modulesFolder,"ModuleScript","LobbyDriveLayout")
modules.LobbyDriveLayout=luau.load(fs.readFile('src/client/LobbyDriveLayout.luau'))()
for _, name in {"TouchDrivingModel","MobileControlView","MobileTutorialView","DriftChargeView","KartInputController","DriftChargeController","TouchDrivingController"} do
	modules[name]=luau.load(fs.readFile("src/client/"..name..".luau"),{environment=env})()
end
local tutorialRoot=object("Frame")
local dismissCount=0
local tutorial=modules.MobileTutorialView.create(tutorialRoot,function() dismissCount+=1 end)
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
assertTutorialIcons({"Left","Right","Drift","BrakeReverse"})
tutorialCard.Next.Activated:Fire()
check(tutorialCard.Title.Text=="DRIFT & BOOST","tutorial advances to drift")
check(string.find(tutorialCard.Description.Text,"3 boosts in one race",1,true)~=nil
	and not string.find(tutorialCard.Description.Text,"in a row",1,true),
	"tutorial explains cumulative three-Boost reward")
check(tutorialCard.Diagram.Visible,"DRIFT diagram remains visible")
assertTutorialIcons({"Drift","Left","Right"})
local examples=tutorialCard.GaugeExamples
check(examples.Visible and #examples.ChargingGauge:GetChildren()==6 and #examples.ReadyGauge:GetChildren()==6,"tutorial has two native five-segment gauges")
check(examples.ChargingGauge.Segment3.BackgroundColor3==rb.Color3.fromRGB(65,225,245)
	and examples.ChargingGauge.Segment4.BackgroundColor3==rb.Color3.fromRGB(45,60,70),"charging example has three cyan segments")
check(examples.ReadyGauge.Segment5.BackgroundColor3==rb.Color3.fromRGB(255,218,75),"ready example has five gold segments")
check(not string.find(tutorialCard.Diagram.Text,"â–°",1,true) and not string.find(tutorialCard.Diagram.Text,"â–±",1,true),"tutorial gauge uses no Unicode blocks")
tutorialCard.Next.Activated:Fire()
check(tutorialCard.Title.Text=="RACE ITEMS","tutorial advances to items")
check(tutorialCard.DontShowAgain.Visible,"final tutorial page offers persistent dismissal")
check(not tutorialCard.Diagram.Visible and tutorialCard.Diagram.Text=="","item page has no spacing-based text row")
local captions=tutorialCard.ItemCaptions
check(captions.Visible and #captions:GetChildren()==4,"item page has four independent captions")
for index,name in {"NITRO","SLICK","SHIELD","MISSILE"} do
 local caption=captions:FindFirstChild("Caption"..index)
 local slot=iconSlots:FindFirstChild("IconSlot"..index)
 check(caption.Text==name and caption.TextXAlignment==rb.Enum.TextXAlignment.Center
  and caption.Position.X.Offset+caption.Size.X.Offset/2==slot.Position.X.Offset+slot.Size.X.Offset/2,
  "item caption centers on its icon column: "..name)
end
assertTutorialIcons({"Nitro","Slick","Shield","Missile"})
for index,id in {"Nitro","Slick","Shield","Missile"} do
 local holder=iconSlots["IconSlot"..index]
 local image=holder.KDMItemImage
 check(image and image.Image==modules.KDMIconCatalog.Items[id]
  and image.ScaleType==rb.Enum.ScaleType.Fit and image.ZIndex>holder.ZIndex,
  "tutorial uses uploaded item artwork with safe layering: "..id)
end
check(not string.find(fs.readFile("src/client/GarageUiController.luau"),"CONTROLS ?",1,true),"Garage control replay label has no question mark")
tutorialCard.Back.Activated:Fire()
check(tutorialCard.Title.Text=="DRIFT & BOOST","tutorial back works")
for _,holder in iconSlots:GetChildren() do check(not holder:FindFirstChild("KDMItemImage"),"leaving items releases artwork") end
tutorialCard.Next.Activated:Fire(); tutorialCard.Next.Activated:Fire()
check(not tutorial.isOpen(),"GOT IT closes tutorial")
check(dismissCount==0,"GOT IT does not persist dismissal")
tutorial.open()
check(tutorialCard.Title.Text=="DRIVE","tutorial replay restarts at DRIVE")
tutorialCard.Next.Activated:Fire(); tutorialCard.Next.Activated:Fire()
tutorialCard.DontShowAgain.Activated:Fire()
check(not tutorial.isOpen() and dismissCount==1,"DON'T SHOW AGAIN closes and requests save")
tutorial.open()
check(tutorial.isOpen() and tutorialCard.Title.Text=="DRIVE","manual controls replay still opens")
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
local edgeCount=#control._p.calls
input.setTouchActions(1,1,true)
check(#control._p.calls==edgeCount+1 and latest()[3]==true,'mobile press sends immediately without Heartbeat')
input.setTouchActions(1,1,false)
check(#control._p.calls==edgeCount+2 and latest()[3]==false,'mobile release preserves transport edge')
input.setTouchActions(1,1,true)
check(#control._p.calls==edgeCount+3 and latest()[3]==true,'rapid release/repress survives one frame')
input.setTouchActions(0,0,false)
check(#control._p.calls==edgeCount+4 and latest()[3]==false,'rapid probe restores neutral input')
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
check(string.find(diagnostic.Text,"DT ",1,true)~=nil and string.find(diagnostic.Text,"Î”",1,true)==nil,"server delta uses ASCII DT")
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
local productionRoot=object("Frame")
local productionGauge=modules.DriftChargeView.create(productionRoot,false)
check(productionGauge.diagnostic==nil,"debug-off creates no diagnostic text")
check(productionRoot:FindFirstChild("NitroCharge",true)==nil
	and productionRoot:FindFirstChild("DriftBonusNitro",true)==nil,
	"Drift gauge creates no duplicate cumulative reward labels")
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
input.useRaceItemDirect("Shield"); tick()
check(#item._p.calls==1 and item._p.calls[1][1]=="UseItem" and item._p.calls[1][2]=="Shield","one direct use while joystick and drift are held")
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
	for _, id in {"Nitro","Slick","Shield","Missile"} do
		input.useRaceItemDirect(id); tick()
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
	check(not joy.Visible and not root.Forward.Visible and not auto.Visible and not root.AutoBackward.Visible
		and root.ForwardLeft.Visible and root.ForwardRight.Visible and root.BrakeReverse.Visible and drift.Visible
		and gui:GetAttribute("MobileDriveControlMode")=="Buttons","digital default shows Left/Right steering on left, Drift+BrakeReverse on right, and hides manual Forward/Auto buttons")
	check(root.ForwardLeft.AbsolutePosition.X < root.ForwardRight.AbsolutePosition.X
		and root.ForwardRight.AbsolutePosition.X < drift.AbsolutePosition.X
		and drift.AbsolutePosition.X + drift.AbsoluteSize.X + 8 <= root.BrakeReverse.AbsolutePosition.X
		and math.abs(drift.AbsolutePosition.Y+drift.AbsoluteSize.Y-root.BrakeReverse.AbsolutePosition.Y-root.BrakeReverse.AbsoluteSize.Y)<1,
		"Left/Right steering stays left; Drift and BrakeReverse share the bottom right row")
	check(latest()[1]==1 and latest()[2]==0 and gui:GetAttribute("AutoForwardEnabled")==true,"Auto-Forward defaults ON immediately in Buttons mode")
	local ignored=touch(joy); check(latest()[1]==1 and latest()[2]==0,"legacy stick cannot activate in Buttons mode")
	local b=touch(root.BrakeReverse); check(latest()[1]==-1,"brake/reverse overrides default Auto-Forward")
	b.UserInputState=rb.Enum.UserInputState.End; tick(); check(latest()[1]==1 and gui:GetAttribute("AutoForwardEnabled")==true,"releasing BrakeReverse immediately resumes Auto-Forward")

	for _,direction in {-1,1} do
		local steer=touch(if direction==-1 then root.ForwardLeft else root.ForwardRight)
		check(latest()[1]==1 and latest()[2]==direction,"Auto-Forward plus turn")
		local d=touch(drift);check(latest()[1]==1 and latest()[2]==direction and latest()[3],"Auto-Forward turn Drift")
		local brake=touch(root.BrakeReverse);check(latest()[1]==-1 and latest()[2]==direction and not latest()[3],"Brake overrides Auto-Forward and clears Drift while keeping steering")
		brake.UserInputState=rb.Enum.UserInputState.End;tick();check(latest()[1]==1 and latest()[2]==direction and not latest()[3] and gui:GetAttribute("AutoForwardEnabled"),"Brake release resumes Auto-Forward with cleared Drift")
		d.UserInputState=rb.Enum.UserInputState.End;steer.UserInputState=rb.Enum.UserInputState.End;tick()
		check(latest()[1]==1 and latest()[2]==0 and not latest()[3],"releasing turn resumes straight Auto-Forward")
	end

	local f=touch(root.ForwardLeft); local extra=touch(root.ForwardLeft)
	f.UserInputState=rb.Enum.UserInputState.End; tick(); check(latest()[1]==1 and latest()[2]==-1,"same-direction second owner survives first release")
	extra.UserInputState=rb.Enum.UserInputState.End; tick(); check(latest()[1]==1 and latest()[2]==0,"last same-direction owner released returns to straight Auto-Forward")
	for _, direction in {-1,1} do
		local button=if direction==-1 then root.ForwardLeft else root.ForwardRight
		local other=if direction==-1 then root.ForwardRight else root.ForwardLeft
		local steer=touch(button)
		check(latest()[1]==1 and latest()[2]==direction and not latest()[3],"normal digital steering remains full with Auto-Forward")
		local d=touch(drift)
		check(latest()[1]==1 and latest()[2]==direction and latest()[3],"drift press retains PC-equivalent full digital steering")
		check(input.getEffectiveSteering()==direction,"drift steering HUD action sync")
		for i=1,90 do
			steer.Position=V3.new(i*100,-i*70,0); ui.InputChanged:Fire(steer); tick()
			check(latest()[1]==1 and latest()[2]==direction and latest()[3],"stable forward/steering/drift across pointer movement")
		end
		other.InputBegan:Fire(steer); tick(); check(latest()[2]==direction,"one finger cannot own two buttons")
		local opposite=touch(other); check(latest()[2]==-direction,"last pressed wins")
		opposite.UserInputState=rb.Enum.UserInputState.End; tick(); check(latest()[2]==direction,"release falls back to held direction")
		for _, id in {"Nitro","Slick","Shield","Missile"} do
			input.useRaceItemDirect(id); tick()
			check(latest()[1]==1 and latest()[2]==direction and latest()[3],"digital drift and item actions coexist")
		end
		d.UserInputState=rb.Enum.UserInputState.End; tick()
		check(latest()[1]==1 and latest()[2]==direction and not latest()[3],"drift release preserves throttle/steer for existing boost condition")
		check(input.getEffectiveSteering()==direction,"steering HUD action sync")
		steer.UserInputState=rb.Enum.UserInputState.End; tick()
		check(latest()[1]==1 and latest()[2]==0 and not latest()[3],"steering release returns to straight Auto-Forward")
		steer=touch(button)
		b=touch(root.BrakeReverse);check(latest()[1]==-1 and latest()[2]==direction,"brake priority preserves independently held turn")
		d=touch(drift);check(latest()[1]==-1 and latest()[2]==direction and not latest()[3],"reverse never requests Drift")
		b.UserInputState=rb.Enum.UserInputState.End;tick();check(latest()[1]==1 and latest()[2]==direction,"brake release resumes Auto-Forward while preserving held steering")
		d.UserInputState=rb.Enum.UserInputState.End;tick();check(latest()[2]==direction and not latest()[3],"normal steering restored")
		steer.UserInputState=rb.Enum.UserInputState.Cancel;tick()
		check(latest()[1]==1 and latest()[2]==0,"cancelled steering finger keeps Auto-Forward active")
	end
	check(#item._p.calls==8,"all four digital item direct-use requests delivered once per tap")
end
local function hold()
	tick()
	if legacy then
		touch(joy,20,-40)
		touch(drift)
		if not gui:GetAttribute("AutoForwardEnabled") then auto.Activated:Fire() end
	else
		touch(root.ForwardLeft); touch(root.ForwardRight); touch(root.BrakeReverse)
		touch(drift)
	end
	check(latest()[1]==(if legacy then 1 else -1) and latest()[3]==legacy,"hold established; digital reverse suppresses Drift")
	kart:SetAttribute("KartDriftChargeProgress",1);kart:SetAttribute("KartDriftChargeReady",true);tick()
	check(gauge.Visible and gauge:GetAttribute("LitSegments")==5,"lifecycle fixture starts READY")
end
local function resumesAutoForward(label)
	tick()
	local a=latest()
	check(a[1]==(if legacy then 0 else 1) and a[2]==0 and a[3]==false,label)
end
for _, race in {"FINISHED","FINISHING","DNF","GARAGE","COUNTDOWN"} do
	player:SetAttribute("RaceState","RACING"); hold(); player:SetAttribute("RaceState",race); neutral("race transition "..race)
	check(not gauge.Visible and not diagnostic.Visible,"race transition hides READY and diagnostic")
end
player:SetAttribute("RaceState","RACING")
hold(); gui.Enabled=false; neutral("disabled GUI"); gui.Enabled=true
hold(); root.Visible=false; resumesAutoForward("hidden controls reset held ownership and restore default Auto-Forward")
hold(); humanoid.SeatPart=nil; neutral("seat loss"); humanoid.SeatPart=seat
hold(); player.CharacterRemoving:Fire(character); neutral("character removal"); player.CharacterAdded:Fire(character)
hold(); ui.WindowFocusReleased:Fire(); neutral("focus loss"); ui.WindowFocused:Fire()
hold(); focused={}; ui.TextBoxFocused:Fire(); neutral("textbox focus"); focused=nil
hold(); services.GuiService.MenuIsOpen=true; services.GuiService.MenuOpened:Fire(); neutral("menu opened"); services.GuiService.MenuIsOpen=false
hold(); kart:SetAttribute("RaceControlsLocked",true); neutral("race controls locked"); kart:SetAttribute("RaceControlsLocked",false)
hold(); kart:SetAttribute("RaceResetSerial",1); resumesAutoForward("race reset serial clears held buttons and restores default Auto-Forward")
hold(); ui.PreferredInput=rb.Enum.PreferredInput.KeyboardAndMouse; keys[tostring(rb.Enum.KeyCode.W)]=true; keys[tostring(rb.Enum.KeyCode.A)]=true; tick()
check(latest()[1]==1 and latest()[2]==-1 and not root.Visible and defaultGui.Enabled,"keyboard W/A remains unchanged; stock controls restored")
keys={}; neutral("keyboard release")
for _, case in {{rb.Enum.KeyCode.W,rb.Enum.KeyCode.D,1,1},{rb.Enum.KeyCode.S,rb.Enum.KeyCode.A,-1,-1},{rb.Enum.KeyCode.S,rb.Enum.KeyCode.D,-1,1}} do
	keys[tostring(case[1])]=true; keys[tostring(case[2])]=true; keys[tostring(rb.Enum.KeyCode.LeftShift)]=true; tick()
	check(latest()[1]==case[3] and latest()[2]==case[4] and latest()[3],"PC throttle/steering/Shift regression")
	keys={}; neutral("PC release")
end
for i,key in {rb.Enum.KeyCode.One,rb.Enum.KeyCode.Two,rb.Enum.KeyCode.Three,rb.Enum.KeyCode.Four} do
	local k=object("InputObject"); k.KeyCode=key; ui.InputBegan:Fire(k,false)
	local call=item._p.calls[#item._p.calls]
	check(call[1]=="Select" and call[2]==modules.RaceItemSlots.DEFAULT[i],"PC item selection")
end
local q=object("InputObject"); q.KeyCode=rb.Enum.KeyCode.Q; ui.InputBegan:Fire(q,false); ui.InputEnded:Fire(q)
check(item._p.calls[#item._p.calls][1]=="Use","PC Q item trigger")
ui.PreferredInput=rb.Enum.PreferredInput.Touch
-- Verify reserved thumb/display rectangles remain separate at representative safe sizes.
local function overlaps(a,b) return a[1]<b[3] and b[1]<a[3] and a[2]<b[4] and b[2]<a[4] end
local function rect(element)
	local p,s=element.AbsolutePosition,element.AbsoluteSize
	return {p.X,p.Y,p.X+s.X,p.Y+s.Y}
end
for _, size in {V2.new(1600,739),V2.new(1280,720),V2.new(844,390)} do
	safeSize=size
	productionGauge:layout(size,true)
	local l=modules.MobileControlView.layout(size)
	local items=modules.MobileControlView.itemLayout(size,4)
	local row={items.x,size.Y-items.bottom-l.slot,
		items.x+items.width,size.Y-items.bottom}
	local driftRect={l.driftX,size.Y-l.driftBottom-l.driftHitHeight,l.driftX+l.driftHitWidth,size.Y-l.driftBottom}
	local useRect={l.useX,size.Y-l.useBottom-l.action,l.useX+l.action,size.Y-l.useBottom}
	local gaugeRect=rect(productionGauge.frame)
	check(not overlaps(row,driftRect)
		and not overlaps(row,gaugeRect),"item row remains separate from driving controls")
end
for _, size in {V2.new(801,334),V2.new(749,303),V2.new(473,240),V2.new(389,703),V2.new(320,568),V2.new(929,688)} do
	safeSize=size; root:GetPropertyChangedSignal("AbsoluteSize"):Fire(); tick()
	sharedGui.SharedDriftDisplay:GetPropertyChangedSignal("AbsoluteSize"):Fire()
	drift:GetPropertyChangedSignal("AbsolutePosition"):Fire()
	local l=modules.MobileControlView.layout(size)
	check(l.speedTop>=2 and l.speedTop<8 and l.speedTop+l.speedHeight<size.Y,"speed HUD rises without leaving safe region")
	check(l.speedHeight==56,"speed HUD keeps compact box height")
	local centered=math.abs(gauge.AbsolutePosition.X+gauge.AbsoluteSize.X/2-drift.AbsolutePosition.X-drift.AbsoluteSize.X/2)<=.5
	check(centered or gauge.AbsolutePosition.X>=12+modules.MobileControlView.itemLayout(size,4).width+6,"gauge keeps centered baseline or clears crowded Nitro lane")
	local artworkTop=math.min(drift.AbsolutePosition.Y,drift.KDMControlImage.AbsolutePosition.Y)
	check(math.abs(artworkTop-gauge.AbsolutePosition.Y-gauge.AbsoluteSize.Y-(if size.X<500 and size.Y>size.X then 8 else 10))<=.5,"mobile gauge follows rendered Drift bounds with READY stroke clearance")
	local mobileClip=child(root,"Frame","ClipPreview")
	local mobileWheel=child(root,"Frame","WheelPreview")
	modules.MobileControlView.layoutSteeringWheel(mobileClip,mobileWheel,{},size,true)
	check(mobileWheel.Parent==mobileClip and mobileClip.ClipsDescendants and not mobileClip.Active,"mobile wheel uses display-only clip")
	check(math.abs(mobileClip.AbsoluteSize.Y-l.wheel*2/3)<1 and math.abs(mobileWheel.AbsoluteSize.X-l.wheel)<1,"mobile wheel geometry preserved within pixel rounding")
	check(mobileClip.AbsolutePosition.Y+mobileClip.AbsoluteSize.Y==size.Y-3,"mobile clip leaves a three-pixel bottom margin")
	mobileWheel:Destroy();mobileClip:Destroy()
	local rects={}
	local buttons=if legacy then {joy,drift,auto,gauge,diagnostic} else {root.ForwardLeft,root.ForwardRight,root.BrakeReverse,drift,gauge,diagnostic}
	for _, button in buttons do
		local p,z=button.AbsolutePosition,button.AbsoluteSize
		table.insert(rects,{p.X,p.Y,p.X+z.X,p.Y+z.Y})
	end
	if size.X>=500 or size.Y<=size.X then
		local map=modules.MobileControlView.minimapLayout(size,-58)
		local minimap={map.x,map.y,map.x+map.side,map.y+map.side}
		for i, r in rects do check(not overlaps(r,minimap),"driving buttons avoid minimap "..tostring(size).." index="..i) end
	end
	local speedX=if size.X<450 then size.X-172 else size.X/2-80
	check(not overlaps(rects[#rects],{speedX,l.speedTop,speedX+160,l.speedTop+l.speedHeight}),"debug avoids speed HUD including inset phone width")
	local items=modules.MobileControlView.itemLayout(size,4)
	table.insert(rects,{items.x,size.Y-items.bottom-l.slot,items.x+items.width,size.Y-items.bottom})
	if size.X>=600 or size.Y>size.X then table.insert(rects,{size.X/2-l.wheel/2,size.Y-3-l.wheel*2/3,size.X/2+l.wheel/2,size.Y-3}) end
	for i,r in rects do
		check(r[1]>=0 and r[2]>=0 and r[3]<=size.X and r[4]<=size.Y,"inside safe area "..tostring(size).." "..i.." "..table.concat(r,","))
		for j=i+1,#rects do check(not overlaps(r,rects[j]),"thumb zones / display never overlap "..tostring(size).." rects "..i.."/"..j) end
	end
end
-- R6-B3: actual rendered bounds across distinct safe-area / scaled containers.
for _,case in {
	{"iPhone-equivalent",V2.new(932,430),V2.new(844,352),V2.new(44,58)},
	{"Galaxy-equivalent",V2.new(960,432),V2.new(960,374),V2.new(0,58)},
	{"short viewport",V2.new(780,360),V2.new(685,280),V2.new(59,58)},
	{"normal viewport",V2.new(1920,1080),V2.new(1920,1022),V2.new(0,58)},
} do
	local label,full,controlSize,offset=case[1],case[2],case[3],case[4]
	safeSize=full
	modules.MobileControlView.setViewportBottomInset(full.Y,offset.Y+controlSize.Y)
	local host=object("ScreenGui")
	host:SetAttribute("MobileDriveControlMode",if legacy then "Joystick" else "Buttons")
	local controls=child(host,"Frame","InsetControls")
	controls.Size=rb.UDim2.fromOffset(controlSize.X,controlSize.Y)
	controls.Position=rb.UDim2.fromOffset(offset.X,offset.Y)
	local button=child(controls,"TextButton","Drift")
	local l=modules.MobileControlView.layout(controlSize)
	button.AnchorPoint=V2.new(0,1)
	button.Size=rb.UDim2.fromOffset(l.driftHitWidth,l.driftHitHeight)
	button.Position=rb.UDim2.new(0,if legacy then l.driftX else l.rightDriftX,1,-(if legacy then l.driftBottom else l.rightDriftBottom))
	local artwork=child(button,"ImageLabel","KDMControlImage")
	artwork.AnchorPoint=V2.new(.5,.5);artwork.Position=rb.UDim2.fromScale(.5,.5)
	artwork.Size=rb.UDim2.fromOffset(l.driftWidth,l.driftHeight)
	local displayRoot=child(host,"Frame","FullViewportGauge")
	local view=modules.DriftChargeView.create(displayRoot,false)
	local originalSize,originalPosition=button.Size,button.Position
	view:layout(full,true,nil,displayRoot.AbsolutePosition,button)
	local g=view.frame
	local top=math.min(button.AbsolutePosition.Y,artwork.AbsolutePosition.Y)
	local items=modules.MobileControlView.itemLayout(controlSize,if legacy then 4 else 6)
	local row={offset.X+items.x,offset.Y+(if legacy then controlSize.Y-items.bottom-l.slot else items.top),
		offset.X+items.x+items.width,offset.Y+controlSize.Y-items.bottom}
	local nitro={offset.X+items.x,offset.Y+items.progressTop,
		offset.X+items.x+items.width,offset.Y+items.progressTop+items.progressHeight}
	local states={{0,false,false,false,false},{.2,false,true,true,false},
		{.4,false,true,true,false},{.6,false,true,true,false},{.8,false,true,true,false},
		{1,true,true,true,false},{0,false,false,false,false},
		{0,false,false,false,true},{0,false,false,false,false}}
	for _,state in states do
		view:updateCharge(state[1],state[2],state[3],state[4],state[5],.12)
		local bounds=rect(g)
		local stroke=g:FindFirstChildOfClass("UIStroke").Thickness
		check(top-bounds[4]-stroke>=6,label.." full gauge / READY pulse clears artwork")
		check(bounds[1]>=0 and bounds[2]>=0 and bounds[3]<=full.X and bounds[4]<=full.Y,label.." gauge in viewport")
		check(not overlaps(bounds,row) and not overlaps({bounds[1]-stroke,bounds[2]-stroke,bounds[3]+stroke,bounds[4]+stroke},nitro),label.." items and Nitro text clear gauge")
		for index=1,5 do
			local segment=rect(g["Segment"..index])
			check(segment[1]>=bounds[1] and segment[3]<=bounds[3] and segment[2]>=bounds[2] and segment[4]<=bounds[4],label.." complete segment "..index)
		end
		check(button.Size==originalSize and button.Position==originalPosition,label.." approved Drift target preserved")
	end
	check(g.AbsoluteSize.Y==modules.MobileControlView.layout(full).gaugeHeight,label.." gauge not shrunk")
	host:Destroy()
end
modules.MobileControlView.setViewportBottomInset(0,0)
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
-- Exercise the real Lobby branch through the real digital-pad adapter, not
-- just Race KartControl: periodic sends must survive the .5s Lobby timeout.
if not legacy then
ui.TouchEnabled=true;ui.PreferredInput=rb.Enum.PreferredInput.Touch
focused=nil;services.GuiService.MenuIsOpen=false
ui.WindowFocused:Fire()
player:SetAttribute("RaceState","GARAGE")
player.UserId=123;humanoid.Health=100;humanoid.SeatPart=seat
seat:SetAttribute("PrototypeKartSeat",false);seat:SetAttribute("LobbyKartSeat",true)
kart:SetAttribute("LobbyOwnerUserId",123);kart:SetAttribute("RaceControlsLocked",false)
player:SetAttribute("LobbyDriveActive",true)
local lobbyCalls={}
input.setLobbyInputSender(function(...)table.insert(lobbyCalls,table.pack(...))end)
player.CharacterAdded:Fire(character)
tick()
local function lobbyLatest()return lobbyCalls[#lobbyCalls]end
check(lobbyLatest() and lobbyLatest()[1]==1,"Lobby digital Auto-Forward reaches Lobby transport immediately")
for i=1,24 do
 local previous=#lobbyCalls;tick()
 check(#lobbyCalls==previous+1 and lobbyLatest()[1]==1,"Lobby Auto-Forward throttle refreshed past server timeout")
end
local heldTurn=touch(root.ForwardLeft);local heldDrift=touch(drift)
check(lobbyLatest()[1]==1 and lobbyLatest()[2]==-1 and lobbyLatest()[3],"Lobby turn and Drift transported")
heldDrift.UserInputState=rb.Enum.UserInputState.End;tick()
check(not lobbyLatest()[3] and lobbyLatest()[2]==-1,"Lobby Drift release preserves steering")
heldTurn.UserInputState=rb.Enum.UserInputState.End;tick()
check(lobbyLatest()[1]==1 and lobbyLatest()[2]==0,"Lobby turn release returns to straight Auto-Forward")
local heldBrake=touch(root.BrakeReverse)
check(lobbyLatest()[1]==-1,"Lobby reverse transported")
heldBrake.UserInputState=rb.Enum.UserInputState.End;tick()
check(lobbyLatest()[1]==1,"Lobby brake release resumes Auto-Forward")
ui.WindowFocusReleased:Fire()
check(lobbyLatest()[1]==0 and lobbyLatest()[2]==0 and not lobbyLatest()[3],"Lobby focus loss forces neutral")
player:SetAttribute("LobbyDriveActive",false);input.setLobbyInputSender(nil)
seat:SetAttribute("PrototypeKartSeat",true);seat:SetAttribute("LobbyKartSeat",false)
player:SetAttribute("RaceState","RACING");ui.WindowFocused:Fire()
end
player.CharacterAdded:Fire(character)
hold(); gui:Destroy(); sharedGui:Destroy(); neutral("destroyed GUI"); check(defaultGui.Enabled,"destroy restores stock controls")
check(not gauge.Visible and not diagnostic.Visible,"GUI destruction clears charge display")
print("PASS: "..count.." mobile input, lifecycle, transport and layout checks (mocked; no hardware multi-touch)")
