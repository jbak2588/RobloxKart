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
function methods:FindFirstChild(name) for _, c in self._children do if c.Name==name then return c end end end
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
local modules={KartConfig={REMOTE_EVENT_NAME="KartControl",INPUT_SEND_INTERVAL=0.05}}
for _, name in {"KartInputController","TouchDrivingModel","MobileControlView","TouchDrivingController"} do child(modulesFolder,"ModuleScript",name) end
local ui=services.UserInputService
ui.TouchEnabled=true; ui.PreferredInput=rb.Enum.PreferredInput.Touch
local keys, focused = {}, nil
ui.GetFocusedTextBox=function() return focused end
ui.IsKeyDown=function(_,k) return keys[tostring(k)] or false end
services.GuiService.MenuIsOpen=false
local env={game={GetService=function(_,name) return assert(services[name],name) end},
	script={Parent=modulesFolder},require=function(m) return assert(modules[m.Name],m.Name) end,
	Instance={new=object},Vector2=V2,Vector3=V3,UDim2=rb.UDim2,UDim=rb.UDim,Color3=rb.Color3,Enum=rb.Enum}
for _, name in {"TouchDrivingModel","MobileControlView","KartInputController","TouchDrivingController"} do
	modules[name]=luau.load(fs.readFile("src/client/"..name..".luau"),{environment=env})()
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
		f=touch(root.Forward); local steer=touch(button); local d=touch(drift)
		-- Moving far outside the button must not change a held digital target.
		for i=1,90 do
			steer.Position=V3.new(i*100,-i*70,0); ui.InputChanged:Fire(steer); tick()
			check(latest()[1]==1 and latest()[2]==direction and latest()[3],"stable forward/steering/drift across pointer movement")
		end
		other.InputBegan:Fire(steer); tick(); check(latest()[2]==direction,"one finger cannot own two buttons")
		local opposite=touch(other); check(latest()[2]==-direction,"last pressed wins")
		opposite.UserInputState=rb.Enum.UserInputState.End; tick(); check(latest()[2]==direction,"release falls back to held direction")
		for _, id in {"Nitro","Slick","Shield"} do
			input.selectRaceItem(id); use.Activated:Fire(); tick()
			check(latest()[1]==1 and latest()[2]==direction and latest()[3],"digital drift and item actions coexist")
		end
		d.UserInputState=rb.Enum.UserInputState.End; tick()
		check(latest()[1]==1 and latest()[2]==direction and not latest()[3],"drift release preserves throttle/steer for existing boost condition")
		check(input.getEffectiveSteering()==direction,"steering HUD action sync")
		steer.UserInputState=rb.Enum.UserInputState.End; f.UserInputState=rb.Enum.UserInputState.End; neutral("all buttons released")
		auto.Activated:Fire(); steer=touch(button); d=touch(drift)
		for _=1,30 do tick(); check(latest()[1]==1 and latest()[2]==direction and latest()[3],"auto stable drift") end
		b=touch(root.Brake); check(latest()[1]==-1 and latest()[2]==direction,"auto brake and reverse steer use shared actions")
		b.UserInputState=rb.Enum.UserInputState.End; tick(); check(latest()[1]==1,"auto resumes after brake")
		steer.UserInputState=rb.Enum.UserInputState.Cancel; d.UserInputState=rb.Enum.UserInputState.End; neutral("cancel disables auto")
	end
	check(#item._p.calls==12,"all digital item select/use calls delivered")
end
local function hold()
	tick(); touch(if legacy then joy else root.Forward,20,-40)
	if not legacy then touch(root.Left); touch(root.Right); touch(root.Brake) end
	touch(drift)
	if not gui:GetAttribute("AutoForwardEnabled") then auto.Activated:Fire() end
	check(latest()[1]==(if legacy then 1 else -1) and latest()[3],"hold established")
end
for _, race in {"FINISHED","DNF","GARAGE","COUNTDOWN"} do
	player:SetAttribute("RaceState","RACING"); hold(); player:SetAttribute("RaceState",race); neutral("race transition "..race)
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
for _, size in {V2.new(801,334),V2.new(473,240),V2.new(389,703),V2.new(320,568),V2.new(929,688)} do
	safeSize=size; root:GetPropertyChangedSignal("AbsoluteSize"):Fire(); tick()
	local l=modules.MobileControlView.layout(size)
	check(l.speedTop>=2 and l.speedTop<8 and l.speedTop+l.speedHeight<size.Y,"speed HUD rises without leaving safe region")
	check(l.speedHeight==56,"speed HUD keeps compact box height")
	local rects={}
	local buttons=if legacy then {joy,drift,use,auto} else {root.Forward,root.Left,root.Right,root.Brake,drift,use,auto}
	for _, button in buttons do
		local p,z=button.AbsolutePosition,button.AbsoluteSize
		table.insert(rects,{p.X,p.Y,p.X+z.X,p.Y+z.Y})
	end
	if size.X>=500 or size.Y<=size.X then
		local minimap={size.X-112,8,size.X-12,108}
		for _, r in rects do check(not overlaps(r,minimap),"driving buttons avoid minimap") end
	end
	table.insert(rects,{l.margin,size.Y-l.loadoutBottom-l.slot,l.margin+l.slot*3+l.gap*2,size.Y-l.loadoutBottom})
	table.insert(rects,{size.X/2-l.wheel/2,size.Y-l.wheel*2/3,size.X/2+l.wheel/2,size.Y})
	for i,r in rects do
		check(r[1]>=0 and r[2]>=0 and r[3]<=size.X and r[4]<=size.Y,"inside safe area")
		for j=i+1,#rects do check(not overlaps(r,rects[j]),"thumb zones / display never overlap "..tostring(size).." rects "..i.."/"..j) end
	end
end
hold(); gui:Destroy(); neutral("destroyed GUI"); check(defaultGui.Enabled,"destroy restores stock controls")
print("PASS: "..count.." mobile input, lifecycle, transport and layout checks (mocked; no hardware multi-touch)")
