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
function methods:IsA(class) return self.ClassName==class or (class=="BasePart" and self.ClassName=="Part") end
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
function methods:FireServer(...) self.lastFire={...} end
local function child(parent,class,name) local result=object(class,name); result.Parent=parent; return result end
local player=object("Player","LocalPlayer")
player.UserId=1
local playerGui=child(player,"PlayerGui","PlayerGui")
local shared=object("Folder","Shared")
local replicated=object("ReplicatedStorage")
shared.Parent=replicated
local remote=child(replicated,"RemoteEvent","RaceControl")
local garageRemote=child(replicated,"RemoteEvent","GarageControl")
local camera=object("Camera","Camera"); camera.ViewportSize=rb.Vector2.new(800,320)
local workspace=object("Workspace"); workspace.CurrentCamera=camera
local input=object("UserInputService"); input.PreferredInput=rb.Enum.PreferredInput.Touch
local guiService=object("GuiService"); guiService.TopbarInset={Min=rb.Vector2.new(165,0),Max=rb.Vector2.new(780,58),Width=615}
local otherPlayer=object("Player","AvailableRacer");otherPlayer.UserId=2;otherPlayer.DisplayName="Available Racer"
otherPlayer:SetAttribute("RaceState","GARAGE")
local services={Players={LocalPlayer=player,GetPlayers=function() return {player,otherPlayer} end,PlayerAdded=signal(),PlayerRemoving=signal()},ReplicatedStorage=replicated,Workspace=workspace,
 RunService={RenderStepped=signal()},TweenService={Create=function() return {Play=function() end} end},
 UserInputService=input,GuiService=guiService}
local modulesFolder=object("Folder","Client")
for _,name in {"KartInputController","MobileControlView","TrackMapRenderer","RaceMinimapRivals","GaragePresence"} do child(modulesFolder,"ModuleScript",name) end
for _,name in {"RaceConfig","KartConfig","DriverCatalog","KartCatalog","TrackCatalog","TrackGeometry","RaceResultFormat"} do
 child(shared,"ModuleScript",name)
end
local format=luau.load(fs.readFile("src/shared/RaceResultFormat.luau"))()
local modules={
 KartInputController={isTouchPreferred=function() return input.PreferredInput==rb.Enum.PreferredInput.Touch end,getEffectiveSteering=function() return 0 end},
 TrackMapRenderer={create=function() return {destroy=function() end,setRacerMarker=function() end,
  removeRacerMarker=function() end,clearRacerMarkers=function() end} end},
 RaceMinimapRivals={collect=function() return {} end},
 GaragePresence=luau.load(fs.readFile("src/client/GaragePresence.luau"))(),
 RaceConfig={TOTAL_LAPS=3,CONTROL_REMOTE_EVENT_NAME="RaceControl"},KartConfig={MINI_BOOST_MAX_SPEED=100,NITRO_MAX_SPEED=100},
 DriverCatalog={Entries={}},KartCatalog={Entries={}},
 TrackCatalog={DefaultId="Track01",Entries={Track01={GeometryId="PracticeCircuitV1",DisplayName="Practice",MatchType="PUBLIC_RACE"}}},
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
check(not hud.Panel.Visible and results.AnchorPoint.X==0 and results.Position.X.Offset==14
 and results.Size.X.Offset<=285 and results.Size.X.Offset<=safeSize.X*0.39,
 "mobile result anchors to safe left edge with capped width")
check(results.Position.X.Offset+results.Size.X.Offset<=safeSize.X*0.44
 and results.Rematch.Size.X.Offset>=150 and results.ReturnGarage.Size.X.Offset>=150,
 "mobile result leaves scene clearance with tappable buttons")
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
check(results.AnchorPoint.X==0 and results.Position.X.Offset+results.Size.X.Offset<=safeSize.X*0.44,
 "phone panel reserves the right side for kart")
safeSize=rb.Vector2.new(640,300)
camera.ViewportSize=rb.Vector2.new(640,360)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
check(results.AnchorPoint.X==0.5 and results.Position.X.Scale==0.5 and contentFits(),"narrow phone falls back to centered result")
set("RaceState","COUNTDOWN")
set("RaceTotalLaps",2);set("RaceLap1Time",83.2);set("RaceLap2Time",78.9);set("RaceLap3Time",0)
set("RaceCompletedLaps",2)
set("RaceState","FINISHED")
check(results.Lap1Row.Visible and results.Lap2Row.Visible and not results.Lap3Row.Visible,"Practice Circuit Race shows two laps")
set("RaceState","COUNTDOWN")
safeSize=rb.Vector2.new(800,260)
camera.ViewportSize=rb.Vector2.new(800,320)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
set("RaceTotalLaps",1);set("RaceLap1Time",58.42);set("RaceLap2Time",0);set("RaceLap3Time",0)
set("RaceBestLapTime",58.42);set("RaceBestLapNumber",1)
set("RaceState","FINISHED")
check(results.Lap1Row.Visible and not results.Lap2Row.Visible and not results.Lap3Row.Visible,"Practice shows one lap")
check(results.Size.X.Offset<=250 and results.Size.X.Offset<=safeSize.X*0.36
 and results.AnchorPoint.X==0,"one-lap phone result uses smaller left panel")
set("RaceState","DNF")
check(results.Visible and results.Total.Text=="OFF TRACK" and not results.Lap1Row.Visible and not results.Best.Visible,"DNF keeps simple result")
check(results.Position.X.Scale==0.5 and results.AnchorPoint.X==0.5,"DNF remains centered")
input.PreferredInput=rb.Enum.PreferredInput.KeyboardAndMouse
camera.ViewportSize=rb.Vector2.new(1280,720)
input:GetPropertyChangedSignal("PreferredInput"):Fire()
check(results.Size.X.Offset==370 and results.Size.Y.Offset==220,"desktop DNF layout stays compact")
set("RaceState","FINISHED")
check(math.abs(results.Position.X.Scale-0.26)<0.001 and not hud.Panel.Visible,"desktop result sits left with no lap HUD")
set("RaceParticipantCount",2);set("RacePosition",2)
set("RaceHostUserId",player.UserId)
set("RaceMatchStatus","WAITING");set("RaceMatchWaitRemaining",0);set("RaceState","PRE_RACE")
local lobby=hud:FindFirstChild("RaceLobbyHost")
local availability=hud:FindFirstChild("AvailableRacers")
check(not hud.Countdown.Visible and lobby.Visible and not results.Visible
 and lobby.Status.Text=="RACERS  2 / 4" and lobby.StartRace.Text=="START RACE"
 and lobby.Cancel.Text=="LEAVE",
 "host lobby waits without timer or result overlay")
check(availability.Visible and availability.WaitingTitle.Text=="WAITING FOR RACERS"
 and availability.AvailableTitle.Text=="AVAILABLE IN SERVER  1"
 and availability.AvailableRacer1.Text=="Available Racer" and availability.Invite1.Visible,
 "waiting title and available racer share one panel without overlap")
availability.Invite1.Activated:Fire()
check(garageRemote.lastFire[1]=="Invite" and garageRemote.lastFire[2]==2,
 "invite control sends target user ID")
set("RaceParticipantCount",1)
check(lobby.Status.Text=="RACERS  1 / 4" and lobby.StartRace.Text=="START SOLO"
 and lobby.Cancel.Text=="CANCEL","solo host sees one-of-four choice")
set("RaceParticipantCount",3)
check(lobby.Status.Text=="RACERS  3 / 4" and lobby.StartRace.Text=="START RACE"
 and lobby.Cancel.Text=="LEAVE","three-racer host may start or leave")
set("RaceParticipantCount",2)
lobby.StartRace.Activated:Fire()
check(remote.lastFire[1]=="StartRace","host START RACE sends server action")
lobby.Cancel.Activated:Fire()
check(remote.lastFire[1]=="CancelWait","host LEAVE sends server action")
set("RaceHostUserId",999)
check(lobby.Visible and not lobby.StartRace.Visible and lobby.Cancel.Visible
 and availability.WaitingTitle.Text=="WAITING FOR HOST","non-host sees waiting and LEAVE only")
check(availability.Visible and not availability.Invite1.Visible,
 "non-host sees availability without invite control")
otherPlayer:SetAttribute("RaceState","RACING")
check(availability.AvailableTitle.Text=="AVAILABLE IN SERVER  0"
 and availability.AvailableRacer1.Text=="No available racers in this server.",
 "racing player disappears from available list")
set("RaceHostUserId",player.UserId)
remote.lastFire=nil
set("RaceState","COUNTDOWN");set("RaceState","RACING")
check(not lobby.Visible,"host lobby hides at countdown")
set("RaceMatchStatus","RACING")
local raceKart=object("Model","Kart")
local raceSeat=child(raceKart,"Seat","Seat")
raceSeat:SetAttribute("PrototypeKartSeat",true)
local raceChassis=child(raceKart,"Part","Chassis")
local character=object("Model","Character")
local humanoid=child(character,"Humanoid","Humanoid");humanoid.SeatPart=raceSeat
player.Character=character
local speedTrack=hud.Speedometer:FindFirstChildOfClass("Frame")
local speedFill=speedTrack:FindFirstChildOfClass("Frame")
raceChassis.AssemblyLinearVelocity=rb.Vector3.new(100,0,0)
for _=1,12 do services.RunService.RenderStepped:Fire(0.1) end
check(speedFill.Size.X.Scale>0.99 and speedFill.Size.X.Scale<=1,
 "100 Mini Boost fills Nitro-scaled speed bar")
raceChassis.AssemblyLinearVelocity=rb.Vector3.new(100,0,0)
for _=1,12 do services.RunService.RenderStepped:Fire(0.1) end
check(speedFill.Size.X.Scale>0.99 and speedFill.Size.X.Scale<=1,
 "100 Nitro fills the speed bar")
check(hud.Panel.QuitRow.Visible and not hud.QuitConfirmation.Visible,"Quit Race appears only while racing")
input.PreferredInput=rb.Enum.PreferredInput.Touch
safeSize=rb.Vector2.new(844,390)
camera.ViewportSize=rb.Vector2.new(844,390)
input:GetPropertyChangedSignal("PreferredInput"):Fire()
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
local quitPanel=hud.Panel
local quitButton=quitPanel.QuitRow.QuitRace
local panelPadding=quitPanel:FindFirstChildOfClass("UIPadding")
local function quitBottomSpace()
	return quitPanel.Size.Y.Offset-panelPadding.PaddingTop.Offset-quitPanel.Lap.Size.Y.Offset
		-quitPanel.Checkpoint.Size.Y.Offset-quitPanel.Best.Size.Y.Offset
		-(if quitPanel.OffTrack.Visible then quitPanel.OffTrack.Size.Y.Offset else 0)
		-quitButton.Size.Y.Offset
end
check(quitButton.Size.Y.Offset>=23 and quitBottomSpace()>=4 and quitBottomSpace()<=8,
	"mobile Quit button retains touch height and 4-8px bottom space")
set("RaceOffTrackRemaining",10)
check(quitPanel.OffTrack.Visible and quitBottomSpace()>=4 and quitBottomSpace()<=8,
	"off-track warning and Quit button fit in panel")
set("RaceOffTrackRemaining",0)
input.PreferredInput=rb.Enum.PreferredInput.KeyboardAndMouse
camera.ViewportSize=rb.Vector2.new(1280,720)
input:GetPropertyChangedSignal("PreferredInput"):Fire()
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
hud.Panel.QuitRow.QuitRace.Activated:Fire()
check(hud.QuitConfirmation.Visible and remote.lastFire==nil,"first Quit click opens confirmation without server action")
hud.QuitConfirmation.Frame.Cancel.Activated:Fire()
check(not hud.QuitConfirmation.Visible and remote.lastFire==nil,"Cancel closes Quit confirmation")
hud.Panel.QuitRow.QuitRace.Activated:Fire()
hud.QuitConfirmation.Frame.ConfirmQuit.Activated:Fire()
check(not hud.QuitConfirmation.Visible and remote.lastFire[1]=="QuitRace","confirmed Quit sends server action")
local positionLabel=hud.Speedometer:FindFirstChild("Position")
check(positionLabel.Visible and positionLabel.Text=="POS 2/2","race position display")
set("RaceFinishPosition",1);set("RaceState","FINISHED")
check(not hud.Panel.QuitRow.Visible and not hud.QuitConfirmation.Visible,"Quit action hides after racing")
check(results.Finish.Text=="PLACE 1/2" and not results.Rematch.Active
 and results.Rematch.Text=="WAITING FOR RACERS","first finisher sees fixed place and waits")
check(hud.RaceMiniMap.Visible,"first finisher keeps multiplayer minimap while rival races")
set("RaceSessionComplete",true)
check(results.Rematch.Active and results.Rematch.Text=="REMATCH","all terminal unlocks rematch")
check(not hud.RaceMiniMap.Visible,"completed result hides spectator minimap")
set("RaceRematchReadyCount",1);set("RaceRematchRequiredCount",2);set("RaceRematchReady",true)
check(not results.Rematch.Active and results.Rematch.Text=="READY 1/2","voter waits for opponent")
set("RaceSessionComplete",false);set("RaceMatchWaitReason","REMATCH");set("RaceMatchWaitRemaining",0)
set("RaceMatchStatus","WAITING");set("RaceState","PRE_RACE")
check(lobby.Visible and not results.Visible and hud.Countdown.Text=="WAITING FOR RACERS",
 "rematch voters return to flexible lobby without result overlap")
print("PASS: "..count.." production race result HUD checks")
