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
local now=0
local delayed = {}
local function object(class,name)
 local p={ClassName=class,Name=name or class,Size=rb.UDim2.fromScale(1,1),Position=rb.UDim2.fromScale(0,0),
  AnchorPoint=rb.Vector2.zero,Visible=true,Enabled=true,Activated=signal(),Destroying=signal()}
 return setmetatable({_p=p,_children={},_attrs={},_signals={},_properties={}}, {
  __index=function(self,key)
   if methods[key] then return methods[key] end
   if key=="AbsolutePosition" then
    if class=="ScreenGui" or not p.Parent then
     return if p.ScreenInsets==rb.Enum.ScreenInsets.CoreUISafeInsets
      then rb.Vector2.new(0,58) else rb.Vector2.zero
    end
    local parentPosition,parentSize=p.Parent.AbsolutePosition,p.Parent.AbsoluteSize
    local ownSize=self.AbsoluteSize
    return rb.Vector2.new(parentPosition.X+parentSize.X*p.Position.X.Scale+p.Position.X.Offset-p.AnchorPoint.X*ownSize.X,
     parentPosition.Y+parentSize.Y*p.Position.Y.Scale+p.Position.Y.Offset-p.AnchorPoint.Y*ownSize.Y)
   end
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
garageRemote.OnClientEvent=signal()
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
for _,name in {"KartInputController","MobileControlView","TrackMapRenderer","RaceMinimapRivals","GaragePresence","RaceResultsCache","RaceRoomRacerRows","V2GaugeController"} do child(modulesFolder,"ModuleScript",name) end
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
 RaceResultsCache=luau.load(fs.readFile("src/client/RaceResultsCache.luau"))(),
 RaceRoomRacerRows=luau.load(fs.readFile("src/client/RaceRoomRacerRows.luau"))(),
 RaceConfig={TOTAL_LAPS=3,CONTROL_REMOTE_EVENT_NAME="RaceControl"},KartConfig={MINI_BOOST_MAX_SPEED=100,NITRO_MAX_SPEED=100},
 DriverCatalog={Entries={}},KartCatalog={Entries={}},
 TrackCatalog={DefaultId="Track01",Entries={Track01={GeometryId="PracticeCircuitV1",DisplayName="Practice",MatchType="PUBLIC_RACE"}}},
 TrackGeometry={getDefinition=function() return {} end},RaceResultFormat=format,
}
local common={Instance={new=object},UDim2=rb.UDim2,UDim=rb.UDim,Vector2=rb.Vector2,Vector3=rb.Vector3,
 Color3=rb.Color3,Enum=rb.Enum,TweenInfo={new=function() return {} end},
 game={GetService=function(_,name) return assert(services[name],name) end},
 require=function(module) return assert(modules[module.Name],module.Name) end,
 task={delay=function(seconds, callback) table.insert(delayed,{seconds,callback}) end,defer=function(callback) callback() end},time=function() return now end}
common.script={Parent=modulesFolder}
modules.MobileControlView=luau.load(fs.readFile("src/client/MobileControlView.luau"),{environment=common})()
player:SetAttribute("RaceState","GARAGE")
player:SetAttribute("SelectedTrackId","Track01")
local controller=luau.load(fs.readFile("src/client/RaceHudController.luau"),{environment=common})()
workspace:SetAttribute("KDMEnableV2Gauge",false) -- legacy HUD assertions use explicit rollback
controller.start()
local hud=playerGui.RobloxKartRaceHud
local function raceMap() return playerGui.RobloxKartMobileTopHud:FindFirstChild("RaceMiniMap") or hud:FindFirstChild("RaceMiniMap") end
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
set("KDMRoutePending","HUB_RETURN")
check(hud.RouteTransition.Visible and hud.RouteTransition.Message.Text=="RETURNING TO GARAGE..."
 and not results.Visible,"HUB return shows transition instead of result choices")
set("KDMRoutePending","")
check(not hud.RouteTransition.Visible and results.Visible,"failed HUB return restores result choices")
check(not hud.Panel.Visible and results.AnchorPoint.X==0 and results.Position.X.Offset==14
 and results.Size.X.Offset<=285 and results.Size.X.Offset<=safeSize.X*0.39,
 "mobile result anchors to safe left edge with capped width")
check(results.Position.X.Offset+results.Size.X.Offset<=safeSize.X*0.44
 and results:FindFirstChild("Rematch",true).Size.X.Offset>=150 and results:FindFirstChild("ReturnGarage",true).Size.X.Offset>=150,
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
set("KDMRoutePending","HUB_RETURN")
check(hud.RouteTransition.Visible and not results.Visible,
 "Quit forfeit suppresses transient DNF choices while returning to HUB")
set("KDMRoutePending","")
check(results.Visible and not hud.RouteTransition.Visible,
 "Quit return failure restores DNF Garage retry")
set("RaceDNFReason","RACE_TIMEOUT")
check(results.Total.Text=="RACE TIMEOUT" and results.Finish.Text=="DNF",
 "race deadline DNF is distinct from off-track DNF")
set("RaceDNFReason","FORFEIT")
check(results.Total.Text=="FORFEIT" and not results:FindFirstChild("Rematch",true).Active
 and results:FindFirstChild("ReturnGarage",true).Visible,"reserved forfeit keeps Garage retry and disables Rematch")
set("RaceDNFReason","")
check(results.Position.X.Scale==0.5 and results.AnchorPoint.X==0.5,"DNF remains centered")
input.PreferredInput=rb.Enum.PreferredInput.KeyboardAndMouse
camera.ViewportSize=rb.Vector2.new(1280,720)
input:GetPropertyChangedSignal("PreferredInput"):Fire()
check(results.Size.X.Offset==370 and results.Size.Y.Offset==220,"desktop DNF layout stays compact")
set("RaceState","FINISHED")
check(math.abs(results.Position.X.Scale-0.26)<0.001 and not hud.Panel.Visible,"desktop result sits left with no lap HUD")
set("RaceParticipantCount",2);set("RacePosition",2)
set("RaceMatchStatus","RACING")
set("RaceSessionComplete",false)
set("RaceEndCountdownRemaining",45);set("RaceEndCountdownActive",true)
check(not results:FindFirstChild("Rematch",true).Active and results:FindFirstChild("Rematch",true).Text=="WAITING FOR RACERS\n0:45"
 and results:FindFirstChild("ReturnGarage",true).Visible,"finished racer sees deadline with disabled Rematch and available Garage")
set("RaceEndCountdownRemaining",44)
check(results:FindFirstChild("Rematch",true).Text=="WAITING FOR RACERS\n0:44","finished waiting time follows replicated seconds")
set("RaceSessionComplete",true);set("RaceEndCountdownActive",false)
check(results:FindFirstChild("Rematch",true).Active and results:FindFirstChild("Rematch",true).Text=="REMATCH",
 "completed race restores Rematch and hides waiting countdown")
set("RaceSessionComplete",false)
set("RaceHostUserId",player.UserId)
set("RaceItemsReadyCount",2);set("RaceItemsRequiredCount",2)
set("RaceMatchStatus","WAITING");set("RaceMatchWaitRemaining",0);set("RaceState","PRE_RACE")
local lobby=hud:FindFirstChild("RaceLobbyHost")
local availability=hud:FindFirstChild("AvailableRacers")
check(not hud.Countdown.Visible and lobby.Visible and not results.Visible
 and lobby.Status.Text=="RACERS  2 / 4\nITEMS READY  2 / 2" and lobby.StartRace.Text=="START RACE"
 and lobby.Cancel.Text=="LEAVE",
 "host lobby waits without timer or result overlay")
check(availability.Visible and availability.WaitingTitle.Text=="WAITING FOR RACERS"
 and availability.AvailableTitle.Text=="AVAILABLE IN SERVER  1"
 and availability.AvailableRacer1.Text=="Available Racer" and availability.Invite1.Visible,
 "waiting title and available racer share one panel without overlap")
availability.Invite1.Activated:Fire()
check(garageRemote.lastFire[1]=="Invite" and garageRemote.lastFire[2]==2,
 "invite control sends target user ID")
set("RaceParticipantCount",1);set("RaceItemsRequiredCount",1);set("RaceItemsReadyCount",1)
check(lobby.Status.Text=="RACERS  1 / 4\nITEMS READY  1 / 1" and lobby.StartRace.Text=="START SOLO"
 and lobby.Cancel.Text=="CANCEL","solo host sees one-of-four choice")
set("RaceParticipantCount",3);set("RaceItemsRequiredCount",3);set("RaceItemsReadyCount",3)
check(lobby.Status.Text=="RACERS  3 / 4\nITEMS READY  3 / 3" and lobby.StartRace.Text=="START RACE"
 and lobby.Cancel.Text=="LEAVE","three-racer host may start or leave")
set("RaceParticipantCount",2);set("RaceItemsRequiredCount",2);set("RaceItemsReadyCount",1)
check(not lobby.StartRace.Active and lobby.StartRace.Text=="WAIT ITEMS 1/2","host button gated on replicated readiness")
local oldAction=remote.lastFire
lobby.StartRace.Activated:Fire();check(remote.lastFire==oldAction,"disabled start sends no duplicate action")
set("RaceItemsReadyCount",2)
set("RaceItemsAutoReadyName","Available Racer");set("RaceItemsAutoReadySerial",1)
check(string.find(lobby.Status.Text,"Available Racer AUTO READY",1,true),"host sees compact authored auto-ready notice")
set("RaceState","COUNTDOWN")
check(hud.ItemsAutoReadyNotice.Visible and not lobby.Visible,"auto-ready notice survives automatic Countdown without staging panel")
now=1.5;services.RunService.RenderStepped:Fire(.1)
check(not hud.ItemsAutoReadyNotice.Visible,"Countdown notice expires after 1.4 seconds")
set("RaceState","PRE_RACE")
check(string.find(lobby.Status.Text,"ITEMS READY  2 / 2",1,true),"notice expires without new attributes")
lobby.StartRace.Activated:Fire()
check(remote.lastFire[1]=="StartRace","host START RACE sends server action")
for _,size in {rb.Vector2.new(932,430),rb.Vector2.new(844,390),rb.Vector2.new(748,303),rb.Vector2.new(724,311)} do
 safeSize=size;camera.ViewportSize=size;camera:GetPropertyChangedSignal("ViewportSize"):Fire()
 local origin=lobby.AbsolutePosition-hud.AbsolutePosition
 check(origin.X>=0 and origin.Y>=0 and origin.X+lobby.AbsoluteSize.X<=size.X
  and origin.Y+lobby.AbsoluteSize.Y<=size.Y,"waiting panel inside mobile safe bounds "..tostring(size))
 check(lobby.StartRace.AbsoluteSize.Y>=44 and lobby.Cancel.AbsoluteSize.Y>=44,"waiting start/leave 44px targets")
 check(lobby.Status.Size.Y.Offset==30 and lobby.Status.TextSize>=12,"compact two-line ready count readable")
 check(lobby.Status.Position.Y.Offset+lobby.Status.Size.Y.Offset<=lobby.StartRace.Position.Y.Offset,"ready count clears start buttons")
 check(lobby.StartRace.Position.X.Offset+lobby.StartRace.Size.X.Offset<lobby.Cancel.Position.X.Offset,"start and leave separate")
end
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
set("RaceEndCountdownRemaining",42);set("RaceEndCountdownActive",true)
check(hud.Panel.RaceEndWarning.Visible and hud.Panel.RaceEndWarning.Text=="RACE ENDS IN 42",
 "driving racer sees compact race-end warning in lap HUD")
set("RaceEndCountdownActive",false)
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
check(quitButton.Size.X.Offset>=110 and quitButton.Size.Y.Offset>=36
 and quitBottomSpace()>=4 and quitBottomSpace()<=8,
	"mobile Quit button meets touch target with 4-8px bottom space")
local function checkTouchQuitRect(label)
 local buttonPosition,buttonSize=quitButton.AbsolutePosition,quitButton.AbsoluteSize
 local panelPosition,panelSize=quitPanel.AbsolutePosition,quitPanel.AbsoluteSize
 check(hud.ScreenInsets==rb.Enum.ScreenInsets.CoreUISafeInsets
  and buttonPosition.X>=panelPosition.X and buttonPosition.X+buttonSize.X<=panelPosition.X+panelSize.X
  and buttonPosition.Y>=guiService.TopbarInset.Max.Y+8
  and buttonPosition.Y+buttonSize.Y<=panelPosition.Y+panelSize.Y,
  label.." Quit hit rectangle stays in LAP panel below Core UI")
end
checkTouchQuitRect("phone landscape 844x390")
safeSize=rb.Vector2.new(1600,680);camera.ViewportSize=rb.Vector2.new(1600,739)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
checkTouchQuitRect("phone landscape 1600x739")
safeSize=rb.Vector2.new(1920,1140);camera.ViewportSize=rb.Vector2.new(1920,1200)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
checkTouchQuitRect("tablet landscape 1920x1200")
safeSize=rb.Vector2.new(1280,740);camera.ViewportSize=rb.Vector2.new(1280,800)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
checkTouchQuitRect("narrow tablet landscape 1280x800")
input.TouchEnabled=true;input.PreferredInput=rb.Enum.PreferredInput.KeyboardAndMouse
input:GetPropertyChangedSignal("PreferredInput"):Fire()
check(quitButton.Size.X.Offset>=110 and quitButton.Size.Y.Offset>=36,
 "touch-enabled tablet keeps a large Quit target even with keyboard preferred")
checkTouchQuitRect("touch tablet with keyboard preferred")
input.TouchEnabled=false;input.PreferredInput=rb.Enum.PreferredInput.Touch
input:GetPropertyChangedSignal("PreferredInput"):Fire()
safeSize=rb.Vector2.new(844,390);camera.ViewportSize=rb.Vector2.new(844,390)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
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
check(results.Finish.Text=="RACE RESULTS" and not results:FindFirstChild("Rematch",true).Active
 and results:FindFirstChild("Rematch",true).Text=="WAITING FOR RACERS","first finisher sees fixed place and waits")
check(raceMap().Visible,"first finisher keeps multiplayer minimap while rival races")
set("RaceSessionComplete",true)
check(results:FindFirstChild("Rematch",true).Active and results:FindFirstChild("Rematch",true).Text=="REMATCH","all terminal unlocks rematch")
check(not raceMap().Visible,"completed result hides spectator minimap")
set("RaceRematchReadyCount",1);set("RaceRematchRequiredCount",2);set("RaceRematchReady",true)
check(not results:FindFirstChild("Rematch",true).Active and results:FindFirstChild("Rematch",true).Text=="READY 1/2","voter waits for opponent")
set("RaceSessionComplete",false);set("RaceMatchWaitReason","REMATCH");set("RaceMatchWaitRemaining",0)
set("RaceMatchStatus","WAITING");set("RaceState","PRE_RACE")
check(lobby.Visible and not results.Visible and hud.Countdown.Text=="WAITING FOR RACERS",
 "rematch voters return to flexible lobby without result overlap")
garageRemote.OnClientEvent:Fire("RoomSnapshot",{hostUserId=1,state="WAITING",count=1,
 maxPlayers=4,queuedCount=1,queued={{name="Friend",kind="INVITED"}},
 available={{userId=9,name="Remote Friend"}}})
check(availability.WaitingTitle.Text=="WAITING NEXT  1"
 and availability.AvailableRacer1.Text=="NEXT Friend  INVITED"
 and availability.AvailableRacer2.Text=="Remote Friend",
 "reserved Room lobby shows queued friend and cross-server availability")
availability.Invite2.Activated:Fire()
check(garageRemote.lastFire[1]=="Invite" and garageRemote.lastFire[2]==9,
 "track-side invite selects cross-server HUB user")
local requestId = garageRemote.lastFire[3]
check(availability.Invite2.Text=="SENDING..." and not availability.Invite2.Active,
 "tap immediately disables only target while waiting for storage acknowledgement")
availability.Invite2.Activated:Fire()
check(garageRemote.lastFire[3]==requestId,"repeated tap cannot send another request")
garageRemote.OnClientEvent:Fire("InviteSent",{targetUserId=9,requestId=requestId,expiresAt=os.time()+23})
check(availability.Invite2.Text=="WAITING" and not availability.Invite2.Active
 and delayed[#delayed][1]<=23 and delayed[#delayed][1]>21,
 "storage acknowledgement uses server expiry rather than a client constant")
garageRemote.OnClientEvent:Fire("RoomSnapshot",{hostUserId=1,state="WAITING",count=1,
 maxPlayers=4,queuedCount=0,queued={},pendingInvites={["9"]=os.time()+23},
 available={{userId=10,name="Second Friend"},{userId=9,name="Remote Friend"}}})
check(availability.Invite1.Text=="INVITE" and availability.Invite1.Active
 and availability.Invite2.Text=="WAITING","row reorder and other targets retain independent states")
availability.Invite1.Activated:Fire()
local secondRequest=garageRemote.lastFire[3]
garageRemote.OnClientEvent:Fire("InviteFailed",{targetUserId=10,requestId=secondRequest})
check(availability.Invite1.Text=="RETRY" and availability.Invite1.Active
 and availability.Invite2.Text=="WAITING","failure restores only failed target")
garageRemote.OnClientEvent:Fire("InviteDeclined",{targetUserId=9,requestId=requestId})
check(availability.Invite2.Text=="INVITE" and availability.Invite2.Active,"decline restores available action")
availability.Invite2.Activated:Fire()
local retryRequest=garageRemote.lastFire[3]
garageRemote.OnClientEvent:Fire("InviteSent",{targetUserId=9,requestId=requestId,expiresAt=os.time()+23})
check(availability.Invite2.Text=="SENDING...","stale acknowledgement cannot resolve newer retry")
garageRemote.OnClientEvent:Fire("InviteSent",{targetUserId=9,requestId=retryRequest,expiresAt=os.time()+9})
delayed[#delayed][2]()
check(availability.Invite2.Text=="INVITE" and availability.Invite2.Active,"expiry restores button")
availability.Invite2.Activated:Fire()
delayed[#delayed][2]()
check(availability.Invite2.Text=="RETRY" and availability.Invite2.Active,"missing acknowledgement times out to retry")
garageRemote.OnClientEvent:Fire("RoomSnapshot",{hostUserId=1,state="WAITING",count=1,
 maxPlayers=4,queuedCount=0,queued={},pendingInvites={["9"]=os.time()+20},
 available={{userId=10,name="Second Friend"},{userId=9,name="Remote Friend"}}})
check(availability.Invite2.Text=="WAITING" and not availability.Invite2.Active,
 "authoritative snapshot recovers pending state after missing acknowledgement")
garageRemote.OnClientEvent:Fire("RoomSnapshot",{hostUserId=1,state="WAITING",count=1,
 maxPlayers=4,queuedCount=0,queued={},pendingInvites={},
 available={{userId=10,name="Second Friend"},{userId=9,name="Remote Friend"}}})
check(availability.Invite2.Text=="INVITE" and availability.Invite2.Active,
 "authoritative cleared snapshot restores declined target")
set("RaceState","RACING")
check(hud.RacingInviteToggle.Visible and hud.RoomQueueStatus.Visible,
 "racing host sees queue count and invite control")
hud.RacingInviteToggle.Activated:Fire()
check(availability.Visible,"racing host can open cross-server invite list")
input.PreferredInput=rb.Enum.PreferredInput.Touch
set("RaceOffTrackRemaining",10);set("RaceEndCountdownActive",true)
set("RaceEndCountdownRemaining",42)
for _,size in {rb.Vector2.new(812,351),rb.Vector2.new(801,334),rb.Vector2.new(749,303),rb.Vector2.new(724,311)} do
 safeSize=size;camera.ViewportSize=size;camera:GetPropertyChangedSignal("ViewportSize"):Fire()
 local l=modules.MobileControlView.layout(size)
 local items=modules.MobileControlView.itemLayout(size,4)
 check(hud.Panel.Size.Y.Offset==110 and hud.Panel.Position.Y.Offset+hud.Panel.Size.Y.Offset
  <=size.Y-items.bottom-l.slot-3,"short safe LAP with both warnings clears left loadout "..tostring(size))
 check(hud.Panel.QuitRow.Size.Y.Offset==40 and hud.Panel.QuitRow.QuitRace.Size.Y.Offset==40,
  "compact LAP retains full Quit touch target")
 check(hud.Panel.OffTrack.Visible and hud.Panel.RaceEndWarning.Visible,
  "compact LAP preserves both warnings")
end
for _,size in {rb.Vector2.new(1490,620),rb.Vector2.new(844,332),rb.Vector2.new(749,303)} do
 safeSize=size;camera.ViewportSize=size;camera:GetPropertyChangedSignal("ViewportSize"):Fire()
 local status,map=hud.RoomQueueStatus,raceMap()
 local statusRight=status.AbsolutePosition.X+status.AbsoluteSize.X
 local mapRight=map.AbsolutePosition.X+map.AbsoluteSize.X
 check(status.Visible and map.Visible and math.abs(statusRight-mapRight)<1,
  "mobile Room status aligns with minimap right edge "..tostring(size))
 check(if size.Y<500 then map.AbsolutePosition.Y+map.AbsoluteSize.Y+6<=status.AbsolutePosition.Y
  else status.AbsolutePosition.Y+status.AbsoluteSize.Y+6<=map.AbsolutePosition.Y,
  "mobile Room status follows minimap hierarchy "..tostring(size))
 check(status.AbsolutePosition.X>size.X*0.5 and statusRight<=size.X
  and status.AbsolutePosition.Y>=hud.AbsolutePosition.Y,
  "mobile Room status clears central driving view inside safe area "..tostring(size))
end
for _,size in {rb.Vector2.new(749,303),rb.Vector2.new(749,361),rb.Vector2.new(724,311),
 rb.Vector2.new(844,390),rb.Vector2.new(932,430),rb.Vector2.new(640,360)} do
 safeSize=size;camera.ViewportSize=size;camera:GetPropertyChangedSignal("ViewportSize"):Fire()
 local expected=modules.MobileControlView.minimapLayout(size,playerGui.RobloxKartMobileTopHud.Speedometer.AbsolutePosition.Y-hud.AbsolutePosition.Y)
 local map=raceMap()
 check(map.Size.X.Offset==expected.side and map.Size.Y.Offset==expected.side,
  "production responsive minimap size "..tostring(size))
 check(math.abs(map.AbsolutePosition.X-hud.AbsolutePosition.X-expected.x)<1
  and math.abs(map.AbsolutePosition.Y-playerGui.RobloxKartMobileTopHud.Speedometer.AbsolutePosition.Y)<=4,
  "production minimap uses top-right speed baseline "..tostring(size))
end
set("RaceState","FINISHED")
check(hud.RoomQueueStatus.AnchorPoint.X==1 and hud.RoomQueueStatus.Position.X.Offset==-12,
 "mobile result next-round status clears standings")
set("RaceState","RACING")
input.PreferredInput=rb.Enum.PreferredInput.KeyboardAndMouse
safeSize=rb.Vector2.new(1280,720);camera.ViewportSize=safeSize
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
check(hud.RoomQueueStatus.AnchorPoint.X==0.5 and hud.RoomQueueStatus.Position.X.Scale==0.5,
 "desktop Room status retains existing layout")
check(raceMap().Position.X.Scale==1 and raceMap().Position.X.Offset==-24
 and raceMap().Position.Y.Scale==.5 and raceMap().Size.X.Offset==194,
 "desktop minimap geometry unchanged")
check(hud.RacingInviteToggle.Position.X.Offset==-12 and hud.RacingInviteToggle.Position.Y.Offset==132
 and hud.RacingInviteToggle.Size.X.Offset==118,"desktop invite geometry unchanged")
for _,state in {"COUNTDOWN","FINISHING","FINISHED","DNF","GARAGE"} do
 set("RaceState",state); check(not hud.RacingInviteToggle.Visible,"invite hidden in "..state)
end
set("RaceState","RACING"); set("RaceHostUserId",2)
check(not hud.RacingInviteToggle.Visible,"nonhost racing invite hidden")
set("RaceHostUserId",1)
check(hud.RacingInviteToggle.Visible,"host racing invite restored")
for _,entry in {{0,0},{25,25},{70,71},{100,101}} do
 raceChassis.AssemblyLinearVelocity=rb.Vector3.new(entry[1],50,0)
 for _=1,40 do services.RunService.RenderStepped:Fire(.1) end
 check(hud.Speedometer.SpeedValue.Text==tostring(entry[2]),"horizontal km/h conversion "..entry[1])
 check(hud.Speedometer.SpeedUnit.Text=="km/h","display unit km/h")
 check(math.abs(speedFill.Size.X.Scale-entry[1]/100)<.001,"speed bar retains studs/sec ratio")
end
-- Exercise the real view and current-round cache with all four racers.
local racers={player,otherPlayer}
for id=3,4 do
 local p=object("Player","Racer"..id);p.UserId=id;p.DisplayName="Racer "..id
 table.insert(racers,p)
 services.Players.PlayerAdded:Fire(p)
end
services.Players.GetPlayers=function() return racers end
player.DisplayName="Local Racer";otherPlayer.DisplayName="Winner"
set("RaceSessionId",901);set("RaceTotalLaps",3);set("RaceParticipantCount",4)
for index,p in racers do
 p:SetAttribute("RaceSessionId",901)
 p:SetAttribute("RacePosition",index);p:SetAttribute("RaceFinishPosition",if index==1 then 2 elseif index==2 then 1 else index)
 p:SetAttribute("RaceFinalTime",120+index);p:SetAttribute("RaceLap1Time",40+index)
 p:SetAttribute("RaceLap2Time",41+index);p:SetAttribute("RaceLap3Time",42+index)
 p:SetAttribute("RaceCompletedLaps",3);p:SetAttribute("RaceState","FINISHED")
end
set("RaceSessionComplete",true)
input.PreferredInput=rb.Enum.PreferredInput.Touch;safeSize=rb.Vector2.new(749,303)
camera.ViewportSize=safeSize;camera:GetPropertyChangedSignal("ViewportSize"):Fire()
local board=results.Standings
check(board.Racer1.RacerName.Text=="Winner" and board.Racer2.RacerName.Text=="Local Racer",
 "local second place still shows winner first")
check(board.Racer1.TotalTime.Text=="2:02.00" and board.Racer2.TotalTime.Text=="2:01.00",
 "totals use replicated values rather than sorting by time")
check(board.Racer1.Laps.Text=="L1 42.00 · L2 43.00 · L3 44.00","each racer three lap values")
check(board.Racer4.Visible and contentFits(),"four rows fit 749x303 result")
check(results.ResultActions.Rematch.AbsoluteSize.Y>=44 and results.ResultActions.ReturnGarage.AbsoluteSize.Y>=44,
 "multiplayer buttons retain 44px targets")
check(board.Racer2.BackgroundColor3~=board.Racer1.BackgroundColor3,"local row highlighted")
racers[3]:SetAttribute("RaceFinishPosition",0);racers[3]:SetAttribute("RaceState","DNF")
check(board.Racer3.RacerName.Text=="Racer 4" and board.Racer4.TotalTime.Text=="DNF","DNF after valid finishers")
racers[4]:SetAttribute("RaceFinishPosition",0);racers[4]:SetAttribute("RaceFinalTime",0)
racers[4]:SetAttribute("RaceState","RACING");set("RaceSessionComplete",false)
check(board.Racer3.TotalTime.Text=="RACING" and results.StandingsStatus.Text=="WAITING FOR RACERS"
 and not results.ResultActions.Rematch.Active,"live rival and Rematch wait preserved")
racers[4]:SetAttribute("RaceFinishPosition",3);racers[4]:SetAttribute("RaceFinalTime",144)
racers[4]:SetAttribute("RaceState","FINISHED");set("RaceSessionComplete",true)
check(board.Racer3.TotalTime.Text=="2:24.00" and results.StandingsStatus.Text=="FINAL STANDINGS",
 "late racer attributes update results automatically")
local leaving=table.remove(racers,2);services.Players.PlayerRemoving:Fire(leaving)
set("RaceEndCountdownRemaining",0)
check(board.Racer1.RacerName.Text=="Winner","finished departed racer remains cached")
set("RaceSessionId",902)
check(not board.Racer2.Visible,"new round drops previous result cache")
-- Production room Bot rows use distinct actions, preserve Human invites and fit short phones.
set("RaceState","PRE_RACE");set("RaceHostUserId",1);set("RaceParticipantCount",1)
set("RaceItemsRequiredCount",1);set("RaceItemsReadyCount",1)
safeSize=rb.Vector2.new(749,303);camera.ViewportSize=rb.Vector2.new(749,361)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
local botSnapshot={roomId="BotRoom",state="WAITING",hostUserId=1,count=1,maxPlayers=4,queuedCount=0,
 queued={},available={{userId=2,name="Available Racer"}},pendingInvites={},activeBots={},
 botCandidates={{botId="Bot01",name="KDM Rookie [BOT]",available=true}}}
garageRemote.OnClientEvent:Fire("RoomSnapshot",botSnapshot)
check(availability.AvailableRacer1.Text=="KDM Rookie [BOT]" and availability.Invite1.Text=="ADD BOT","Bot row clearly labeled")
check(availability.Invite1.AbsoluteSize.Y>=44 and availability.Invite1.AbsoluteSize.X>=44,"Bot 44px touch target")
check(availability.Invite1.AbsolutePosition.Y+availability.Invite1.AbsoluteSize.Y<=availability.Invite2.AbsolutePosition.Y,
 "Bot and Human invitation rows do not overlap")
availability.Invite1.Activated:Fire()
check(garageRemote.lastFire[1]=="AddBot" and garageRemote.lastFire[2]=="Bot01" and #garageRemote.lastFire==2,"Bot action sends no fake UserId or client config")
botSnapshot.activeBots={{botId="Bot01",name="KDM Rookie [BOT]"}};botSnapshot.count=2
set("RaceParticipantCount",2);set("RaceItemsRequiredCount",2);set("RaceItemsReadyCount",2)
garageRemote.OnClientEvent:Fire("RoomSnapshot",botSnapshot)
check(availability.Invite1.Text=="REMOVE" and lobby.StartRace.Text=="START RACE","Human+Bot starts multiplayer race")
availability.Invite1.Activated:Fire()
check(garageRemote.lastFire[1]=="RemoveBot" and garageRemote.lastFire[2]=="Bot01","distinct Bot removal")
set("RaceHostUserId",2)
check(not availability.Invite1.Visible and string.find(availability.AvailableRacer1.Text,"ACTIVE",1,true),"non-host has no Bot action")
set("RaceHostUserId",1);set("RaceState","RACING");botSnapshot.state="RACING"
garageRemote.OnClientEvent:Fire("RoomSnapshot",botSnapshot)
hud.RacingInviteToggle.Activated:Fire()
check(not availability.Invite1.Visible,"racing Bot removal disabled")
print("PASS: "..count.." production race result HUD checks")

-- D2 opt-in executes the real HUD, retaining speed source, POS and OFF fallback.
local gaugeInput
modules.V2GaugeController={new=function() return {destroy=function() end,
 update=function(_,chassis,speed,dt,mobile,active)
  gaugeInput={chassis=chassis,speed=speed,active=active};return active and chassis~=nil
 end} end}
local character=object('Model','Character');player.Character=character
local humanoid=child(character,'Humanoid','Humanoid')
local kart=object('Model','Kart');local chassis=child(kart,'Part','Chassis')
chassis.AssemblyLinearVelocity=rb.Vector3.new(42,9,56)
local seat=child(kart,'VehicleSeat','Seat');seat:SetAttribute('PrototypeKartSeat',true);humanoid.SeatPart=seat
set('RaceState','COUNTDOWN');set('RaceParticipantCount',2);set('RacePosition',1)
workspace:SetAttribute('KDMEnableV2Gauge',nil)
services.RunService.RenderStepped:Fire(1/60)
check(gaugeInput.speed==70 and gaugeInput.active,'absent flag defaults gauge ON with planar speed during Countdown')
check(not playerGui.RobloxKartMobileTopHud.Speedometer.Visible and hud:FindFirstChild('Position').Visible
 and hud:FindFirstChild('Position').Text=='POS 1/2','standalone POS survives hidden top speed')
check(not hud.MobileWheelIndicator.Visible,'gauge hides steering sync')
set('RaceState','RACING');camera:GetPropertyChangedSignal('ViewportSize'):Fire()
check(raceMap().Visible,'minimap resize does not depend on hidden speed panel')
services.RunService.RenderStepped:Fire(1/60)
workspace:SetAttribute('KDMEnableV2Gauge',false)
services.RunService.RenderStepped:Fire(1/60)
check(playerGui.RobloxKartMobileTopHud.Speedometer.Visible
 and playerGui.RobloxKartMobileTopHud.Speedometer:FindFirstChild('Position').Visible,'OFF restores old speed and POS')
set('RaceState','FINISHED');services.RunService.RenderStepped:Fire(1/60)
check(not gaugeInput.active,'result hides gauge')
print('PASS: D2 HUD integration including speed/POS/fallback/lifecycle')
