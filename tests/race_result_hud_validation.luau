-- lune run tests/race_result_hud_validation.luau
-- Runs the production HUD with mocked Roblox GUI objects at phone and desktop sizes.
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local count = 0
local function check(value, label) assert(value, label); count += 1 end
local function signal()
 local listeners={}
 return {Connect=function(_,f) table.insert(listeners,f); return {Disconnect=function() end} end,
  Fire=function(_,...) for _,f in listeners do f(...) end end}
end
local methods={}
local safeSize=rb.Vector2.new(800,260)
local function object(class,name)
 local p={ClassName=class,Name=name or class,Size=rb.UDim2.fromScale(1,1),Position=rb.UDim2.fromScale(0,0),
  AnchorPoint=rb.Vector2.zero,Visible=true,Enabled=true,Activated=signal(),Destroying=signal()}
 return setmetatable({_p=p,_children={},_attrs={},_signals={},_properties={}}, {
  __index=function(self,key)
   if methods[key] then return methods[key] end
   if key=="AbsoluteSize" then
    if class=="ScreenGui" or not p.Parent then return safeSize end
    local parent=p.Parent.AbsoluteSize
    return rb.Vector2.new(parent.X*p.Size.X.Scale+p.Size.X.Offset,parent.Y*p.Size.Y.Scale+p.Size.Y.Offset)
   end
   if p[key]~=nil then return p[key] end
   return self:FindFirstChild(key)
  end,
  __newindex=function(self,key,value)
   local old=p[key]
   if key=="Parent" then
    if old then local i=table.find(old._children,self); if i then table.remove(old._children,i) end end
    if value then table.insert(value._children,self) end
   end
   p[key]=value
   if old~=value and self._properties[key] then self._properties[key]:Fire() end
  end,
 })
end
function methods:FindFirstChild(name,recursive)
 for _,child in self._children do if child.Name==name then return child end end
 if recursive then for _,child in self._children do local found=child:FindFirstChild(name,true); if found then return found end end end
end
function methods:FindFirstChildOfClass(class)
 for _,child in self._children do if child.ClassName==class then return child end end
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
function methods:GetAttribute(name) return self._attrs[name] end
function methods:SetAttribute(name,value)
 local old=self._attrs[name]; self._attrs[name]=value
 if old~=value and self._signals[name] then self._signals[name]:Fire() end
end
function methods:GetAttributeChangedSignal(name)
 if not self._signals[name] then self._signals[name]=signal() end
 return self._signals[name]
end
function methods:GetPropertyChangedSignal(name)
 if not self._properties[name] then self._properties[name]=signal() end
 return self._properties[name]
end
function methods:Destroy() self.Destroying:Fire(); self.Parent=nil end
function methods:FireServer() end
local function child(parent,class,name) local result=object(class,name); result.Parent=parent; return result end
local player=object("Player","LocalPlayer")
local playerGui=child(player,"PlayerGui","PlayerGui")
local shared=object("Folder","Shared")
local replicated=object("ReplicatedStorage")
shared.Parent=replicated
local remote=child(replicated,"RemoteEvent","RaceControl")
local camera=object("Camera","Camera"); camera.ViewportSize=rb.Vector2.new(800,320)
local workspace=object("Workspace"); workspace.CurrentCamera=camera
local input=object("UserInputService"); input.PreferredInput=rb.Enum.PreferredInput.Touch
local guiService=object("GuiService"); guiService.TopbarInset={Min=rb.Vector2.new(165,0),Max=rb.Vector2.new(780,58),Width=615}
local services={Players={LocalPlayer=player},ReplicatedStorage=replicated,Workspace=workspace,
 RunService={RenderStepped=signal()},TweenService={Create=function() return {Play=function() end} end},
 UserInputService=input,GuiService=guiService}
local modulesFolder=object("Folder","Client")
for _,name in {"KartInputController","MobileControlView","TrackMapRenderer"} do child(modulesFolder,"ModuleScript",name) end
for _,name in {"RaceConfig","KartConfig","DriverCatalog","KartCatalog","TrackCatalog","TrackGeometry","RaceResultFormat"} do
 child(shared,"ModuleScript",name)
end
local format=luau.load(fs.readFile("src/shared/RaceResultFormat.luau"))()
local modules={
 KartInputController={isTouchPreferred=function() return input.PreferredInput==rb.Enum.PreferredInput.Touch end,getEffectiveSteering=function() return 0 end},
 TrackMapRenderer={create=function() return {destroy=function() end,setMarkerWorldPosition=function() end} end},
 RaceConfig={TOTAL_LAPS=3,CONTROL_REMOTE_EVENT_NAME="RaceControl"},KartConfig={MINI_BOOST_MAX_SPEED=82},
 DriverCatalog={Entries={}},KartCatalog={Entries={}},
 TrackCatalog={DefaultId="Track01",Entries={Track01={GeometryId="PracticeCircuitV1",DisplayName="Practice"}}},
 TrackGeometry={getDefinition=function() return {} end},RaceResultFormat=format,
}
local common={Instance={new=object},UDim2=rb.UDim2,UDim=rb.UDim,Vector2=rb.Vector2,Vector3=rb.Vector3,
 Color3=rb.Color3,Enum=rb.Enum,TweenInfo={new=function() return {} end},
 game={GetService=function(_,name) return assert(services[name],name) end},
 require=function(module) return assert(modules[module.Name],module.Name) end,
 task={delay=function() end}}
common.script={Parent=modulesFolder}
modules.MobileControlView=luau.load(fs.readFile("src/client/MobileControlView.luau"),{environment=common})()
player:SetAttribute("RaceState","GARAGE")
player:SetAttribute("SelectedTrackId","Track01")
local controller=luau.load(fs.readFile("src/client/RaceHudController.luau"),{environment=common})()
controller.start()
local hud=playerGui.RobloxKartRaceHud
local results=hud.Results
local function contentFits()
 local content=results:FindFirstChildOfClass("UIPadding")
 local layout=results:FindFirstChildOfClass("UIListLayout")
 local height=content.PaddingTop.Offset+content.PaddingBottom.Offset
 local visible=0
 for _,item in results._children do
  if item.ClassName=="Frame" or item.ClassName=="TextLabel" or item.ClassName=="TextButton" then
   if item.Visible then height+=item.Size.Y.Offset;visible+=1 end
  end
 end
 return height+math.max(0,visible-1)*layout.Padding.Offset<=results.Size.Y.Offset
end
local function set(name,value) player:SetAttribute(name,value) end
set("RaceTotalLaps",3)
set("RaceLap1Time",83.2);set("RaceLap2Time",78.9);set("RaceLap3Time",79.03)
set("RaceBestLapTime",78.9);set("RaceBestLapNumber",2)
set("RaceFinalTime",241.13);set("RaceCompletedLaps",3)
set("RaceState","FINISHING")
check(hud.FinishBanner.Visible and not results.Visible and not playerGui.RobloxKartMobileTopHud.Speedometer.Visible,"FINISHING shows banner, hides result and speed")
set("RaceState","FINISHED")
check(results.Visible and not hud.FinishBanner.Visible,"result waits for FINISHED")
check(results.Total.Text=="TOTAL TIME  4:01.13","result shows official total time")
check(results.Lap1Row.LapTime.Text=="1:23.20" and results.Lap1Row.LapDelta.Text=="+4.30","lap one and delta")
check(results.Lap2Row.LapDelta.Text=="BEST" and results.Lap3Row.LapDelta.Text=="+0.13","best and lap three delta")
check(results.Best.Text=="BEST LAP 2  -  1:18.90","best summary names lap number")
check(results.Size.Y.Offset<=safeSize.Y-16,"phone landscape result stays inside safe height")
check(contentFits(),"all three lap rows and buttons fit 320px phone safe area")
safeSize=rb.Vector2.new(932,370)
camera.ViewportSize=rb.Vector2.new(932,430)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
check(results.Size.Y.Offset<=safeSize.Y-16 and contentFits(),"430px phone result fits safe area")
set("RaceState","COUNTDOWN")
set("RaceTotalLaps",1);set("RaceLap1Time",58.42);set("RaceLap2Time",0);set("RaceLap3Time",0)
set("RaceBestLapTime",58.42);set("RaceBestLapNumber",1)
set("RaceState","FINISHED")
check(results.Lap1Row.Visible and not results.Lap2Row.Visible and not results.Lap3Row.Visible,"Practice shows one lap")
set("RaceState","DNF")
check(results.Visible and results.Total.Text=="OFF TRACK" and not results.Lap1Row.Visible and not results.Best.Visible,"DNF keeps simple result")
input.PreferredInput=rb.Enum.PreferredInput.KeyboardAndMouse
camera.ViewportSize=rb.Vector2.new(1280,720)
input:GetPropertyChangedSignal("PreferredInput"):Fire()
check(results.Size.X.Offset==370 and results.Size.Y.Offset==220,"desktop DNF layout stays compact")
print("PASS: "..count.." production race result HUD checks")
