local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local UIS=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local PromptService=game:GetService("ProximityPromptService")
local Shared=RS:WaitForChild("Shared")
local Policy=require(Shared:WaitForChild("LobbyDrivePolicy"))
local KartConfig=require(Shared:WaitForChild('KartConfig'))
local RaceConfig=require(Shared:WaitForChild('RaceConfig'))
local FinishComposition=require(script.Parent:WaitForChild('FinishCameraComposition'))
local Motion=require(Shared:WaitForChild("ChaseCameraMotion"))
local AudioConfig=require(Shared:WaitForChild("AudioConfig"))
local Audio=require(script.Parent:WaitForChild("AudioRuntime"))
local EngineDiagnostic=require(script.Parent:WaitForChild("EngineLoopDiagnostic"))
local Input=require(script.Parent:WaitForChild("KartInputController"))
local Garage=require(script.Parent:WaitForChild("GarageUiController"))
local LobbyLayout=require(script.Parent:WaitForChild("LobbyDriveLayout"))
local MobileView=require(script.Parent:WaitForChild("MobileControlView"))
local DriftFeedback=require(script.Parent:WaitForChild("LobbyDriftFeedback"))
local Exhaust=require(script.Parent:WaitForChild('KartWorldExhaustRenderer'))
local EngineAB=require(script.Parent:WaitForChild('LobbyEngineAB'))
local StyleHelper=require(script.Parent:WaitForChild('KDMUiStyleHelper'))
local PracticeView=require(script.Parent:WaitForChild('LobbyPracticeView'))
local SmokeView=require(script.Parent:WaitForChild('SmokeEffectView'))
local PostDriveView=require(script.Parent:WaitForChild('LobbyPostDriveView'))
local CombatFeedbackView=require(script.Parent:WaitForChild('CombatFeedbackView'))
local Controller={}
local requestDrive
function Controller.requestDrive(mode)return if requestDrive then requestDrive(mode)else false end
local started=false
function Controller.start()
 if started or Workspace:GetAttribute("KDMServerRole")~="HUB"
  or Workspace:GetAttribute("KDMEnableRaceBot")==true then return end
 local remote=RS:WaitForChild("LobbyDriveControl",10);if not remote then return end
 started=true
 local player=Players.LocalPlayer;local token=0;local pending=nil;local suspended=false;local handoffComplete=false
 local finishCameraStart,finishCameraElapsed
 local feedback=nil
 local exhaust=nil
 local speedGauge=nil
 local engineAB=nil
 local finishEngine=Audio.newFinishEngineEnvelope()
 local focused=true;local cameraBody=nil;local previousTarget=nil;local savedFov=nil;local engine,engineSecondary,engineLooper,diagnostic=nil,nil,nil,nil
 local boostAudio=nil
 local missileHitCue=nil;local previousMissileHit=false
 local thunderHitCue=nil;local previousThunderHit=false
 local driveZone=Workspace:WaitForChild("KDMHub"):WaitForChild(Workspace:GetAttribute('LobbyDriveZoneName')or "LobbyFrontTestDriveZone")
 local hub=driveZone.Parent
 local displayPrompts={}
 local function cacheDisplayPrompts(model)
  if model.Name~="KDMClientShowroom" then return end
  table.clear(displayPrompts)
  for _,node in model:GetDescendants()do if node:IsA("ProximityPrompt")and node.Name=="LobbyDisplayTestDrive"then table.insert(displayPrompts,node)end end
 end
 for _,model in hub:GetChildren()do cacheDisplayPrompts(model)end
 hub.ChildAdded:Connect(cacheDisplayPrompts)
 hub.ChildRemoved:Connect(function(model)if model.Name=="KDMClientShowroom"then table.clear(displayPrompts)end end)
 local entryPrompt=driveZone:WaitForChild("LobbyFrontDriveEntry"):FindFirstChildOfClass("ProximityPrompt")
 local gui=Instance.new("ScreenGui");gui.Name="KDMLobbyTestDrive";gui.ResetOnSpawn=false
 gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.DisplayOrder=21;gui.Parent=player:WaitForChild("PlayerGui")
 local canvas=Instance.new("Frame");canvas.Name="SafeCanvas";canvas.Size=UDim2.fromScale(1,1);canvas.BackgroundTransparency=1;canvas.Parent=gui
 local combatView=CombatFeedbackView.new(canvas,player,nil,true)
 local button=Instance.new("TextButton");button.Name="Drive";button.AnchorPoint=Vector2.new(0,1)
 button.Position=UDim2.new(0,12,1,-12);button.Size=UDim2.fromOffset(156,44)
 button.BackgroundColor3=Color3.fromRGB(111,211,245);button.TextColor3=Color3.fromRGB(12,27,42)
 button.Font=Enum.Font.GothamBold;button.TextSize=17;button.BorderSizePixel=0;button.Text="DRIVE";button.Parent=canvas
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,8);corner.Parent=button
 if driveZone:GetAttribute('DriveGeometry')~='ROOKIE_LOOP_V1'then StyleHelper.apply3DButton(button,Color3.fromRGB(80,190,255),Color3.fromRGB(0,140,240),Color3.fromRGB(0,95,200),12,2.5)else
  button.BackgroundTransparency=1;button.TextColor3=Color3.new(1,1,1)
  local outline=Instance.new('UIStroke');outline.Color=Color3.new(1,1,1);outline.Thickness=1;outline.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;outline.Parent=button
 end
 button.Text=''
 local returnLabel=Instance.new('TextLabel');returnLabel.Name='NavigationLabel'
 returnLabel.Size=UDim2.fromScale(1,1);returnLabel.BackgroundTransparency=1
 returnLabel.TextColor3=Color3.fromRGB(255,255,255);returnLabel.Font=Enum.Font.GothamBold
 returnLabel.TextSize=16;returnLabel.Parent=button
 local charge=Instance.new('TextLabel');charge.Name='DriftCharge';charge.BackgroundTransparency=1
 charge.Position=UDim2.fromOffset(12,12);charge.Size=UDim2.fromOffset(260,28)
 charge.Font=Enum.Font.GothamBold;charge.TextSize=16;charge.TextColor3=Color3.fromRGB(235,246,250);charge.TextStrokeTransparency=.35;charge.Parent=canvas
 charge.TextXAlignment=Enum.TextXAlignment.Left
 local gauge=Instance.new('Frame');gauge.Name='TrainingChargeGauge';gauge.BackgroundTransparency=1;gauge.Position=UDim2.fromOffset(12,44);gauge.Size=UDim2.fromOffset(230,9);gauge.Parent=canvas
 local segments={}
 for i=1,5 do local segment=Instance.new('Frame');segment.BorderSizePixel=0;segment.Size=UDim2.fromOffset(42,9);segment.Position=UDim2.fromOffset((i-1)*46,0);segment.Parent=gauge;segments[i]=segment end
 local status=Instance.new("TextLabel");status.Name="Status";status.AnchorPoint=Vector2.new(0,1)
 status.Position=UDim2.new(0,12,1,-60);status.Size=UDim2.fromOffset(240,24)
 status.BackgroundColor3=Color3.fromRGB(19,39,54);status.BackgroundTransparency=.15
 status.TextColor3=Color3.fromRGB(224,245,249);status.Font=Enum.Font.GothamBold;status.TextSize=12;status.Text="";status.Parent=canvas
 local function seatKart()
  local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  local seat=h and h.SeatPart;local kart=seat and seat.Parent
  if h and h.Health>0 and seat and seat:GetAttribute("LobbyKartSeat")==true and kart and kart:GetAttribute("LobbyOwnerUserId")==player.UserId then return kart,h end
  return nil,nil
 end
 local practiceView=PracticeView.new(canvas,player,remote,function()
  return player:GetAttribute('LobbyDriveActive')==true and seatKart()~=nil and not suspended and focused and not pending
 end)
 local trialView
 local overtakeBots=require(script.Parent:WaitForChild('ParkOvertakeBotsView')).new(player,driveZone)
 local parkMap,parkDot,parkMapPoint,parkMapGui,parkMarker
 if MobileView.controlsV1Enabled() then
  local layout=require(RS.Shared.HubParkRookieLoopLayout)
  local points=layout.sample(layout.Segments)
  local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
  for _,p in points do minX=math.min(minX,p.x);maxX=math.max(maxX,p.x);minZ=math.min(minZ,p.z);maxZ=math.max(maxZ,p.z)end
  local extent=math.max(maxX-minX,maxZ-minZ)*1.14
  parkMapPoint=function(x,z)return Vector2.new(.5+(x-(minX+maxX)/2)/extent,.5-(z-(minZ+maxZ)/2)/extent)end
  parkMapGui=Instance.new('ScreenGui');parkMapGui.Name='KDMParkMinimap';parkMapGui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets
  parkMapGui.ResetOnSpawn=false;parkMapGui.DisplayOrder=21;parkMapGui.Parent=gui.Parent
  gui.Destroying:Connect(function()parkMapGui:Destroy()end)
  parkMap=Instance.new('Frame');parkMap.Name='ParkMinimap';parkMap.BackgroundTransparency=1;parkMap.Parent=parkMapGui
  for i=1,#points-1 do
   local a,b=parkMapPoint(points[i].x,points[i].z),parkMapPoint(points[i+1].x,points[i+1].z)
   local delta=b-a;local line=Instance.new('Frame');line.AnchorPoint=Vector2.new(.5,.5);line.Position=UDim2.fromScale((a.X+b.X)/2,(a.Y+b.Y)/2)
   line.Size=UDim2.new(delta.Magnitude,1,0,2);line.Rotation=math.deg(math.atan2(delta.Y,delta.X));line.BorderSizePixel=0;line.BackgroundColor3=Color3.fromRGB(230,238,245);line.Parent=parkMap
  end
  parkMarker=require(script.Parent.MinimapDriverMarker)
  parkDot=parkMarker.new(parkMap,'Driver',4)
 end
 local smokeView=SmokeView.new(player:WaitForChild('PlayerGui'),player,true)
 local postDrive=PostDriveView.new(gui.Parent,function()
  local rooms=gui.Parent:FindFirstChild('KDMMatchRooms')
  local h=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
  return h~=nil and h.Health>0 and not h.SeatPart and player:GetAttribute('RaceState')=='GARAGE'
   and player:GetAttribute('LobbyDriveActive')~=true and player:GetAttribute('LobbyDrivePending')~=true
   and player:GetAttribute('KDMRoutePending')~='RACE_LAUNCH' and player:GetAttribute('HubOverlayOpen')~=true
   and player:GetAttribute('KDMShopOpen')~=true and player:GetAttribute('KDMProfileOpen')~=true and not (rooms and rooms.Enabled)
 end,function()
  local MatchRoomUi=require(script.Parent:WaitForChild('MatchRoomUiController'))
  MatchRoomUi.quickStart()
 end)
 gui.Destroying:Connect(function()
  smokeView:destroy();postDrive:destroy();overtakeBots:destroy();if trialView then trialView:destroy()end
  if speedGauge then speedGauge:destroy();speedGauge=nil end
 end)
 local function neutral()
  if boostAudio then boostAudio:step(0,false,false,nil,false) end
  if speedGauge then speedGauge:update(nil,0,0,Input.isTouchPreferred(),false) end
  if exhaust then exhaust:update(0,false) end
  if feedback then feedback:update(0,false) end
  suspended=true;Input.resetTouchActions();Input.resetLobbyTouchState()
  remote:FireServer("Input",player:GetAttribute("LobbyDriveGeneration"),0,0)
 end
 local function detach()
  if speedGauge then speedGauge:destroy();speedGauge=nil end
  if engineAB then engineAB:destroy();engineAB=nil end
  if boostAudio then boostAudio:destroy();boostAudio=nil end
  if missileHitCue then Audio.stop(missileHitCue);missileHitCue:Destroy();missileHitCue=nil end;previousMissileHit=false
  if thunderHitCue then Audio.stop(thunderHitCue);thunderHitCue:Destroy();thunderHitCue=nil end;previousThunderHit=false
  if exhaust then exhaust:destroy();exhaust=nil end
  if feedback then feedback:destroy();feedback=nil end
  if engine then engine:Stop();engine:Destroy();engine=nil end
  if engineSecondary then engineSecondary:Stop();engineSecondary:Destroy();engineSecondary=nil end
  engineLooper=nil
  finishEngine=Audio.newFinishEngineEnvelope()
  if diagnostic then diagnostic:destroy();diagnostic=nil end
  if cameraBody then
   local camera=Workspace.CurrentCamera;local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
   if camera then camera.CameraType=Enum.CameraType.Custom;if h then camera.CameraSubject=h end;if savedFov then camera.FieldOfView=savedFov end end
  end
  cameraBody,previousTarget,savedFov=nil,nil,nil
  finishCameraStart,finishCameraElapsed=nil,nil
 end
 local function request(action,callback,previewKartId,mode)
  if pending then return false end
  postDrive:hide()
  token+=1;local id=token;pending={id=id,callback=callback,action=action}
  if action=="Stop" then neutral();detach() else suspended=false end
  button.Active=false
  if mode then remote:FireServer(action,id,previewKartId,mode)elseif previewKartId then remote:FireServer(action,id,previewKartId) else remote:FireServer(action,id) end
  task.delay(5,function()
   if pending and pending.id==id then
    local stale=pending;pending=nil;neutral();detach();status.Text="PLEASE TRY AGAIN";button.Active=true
    if stale.action=="Drive" then token+=1;remote:FireServer("Stop",token) end
    if stale.callback then stale.callback(false) end
   end
  end)
  return true
 end
 requestDrive=function(mode)return request('Drive',nil,nil,mode)end
 if driveZone:GetAttribute('DriveGeometry')=='ROOKIE_LOOP_V1'then
  trialView=require(script.Parent:WaitForChild('RookieParkTrialView')).new(gui.Parent,player,
   function()request('Replay')end,function()request('Stop')end)
 end
 Garage.setOpenGate(function(resume)
  if handoffComplete then handoffComplete=false;return false end
  if player:GetAttribute("LobbyDriveActive")~=true and player:GetAttribute("LobbyDrivePending")~=true and not pending then return false end
  if pending then return true end
  request("Stop",function(ok) if ok then handoffComplete=true;resume() end end)
  return true
 end)
 Input.setLobbyInputSender(function(throttle,steering,drift,gas)
  local kart=seatKart();if not kart or player:GetAttribute("LobbyDriveActive")~=true then return end
  if suspended or not focused or GuiService.MenuIsOpen or UIS:GetFocusedTextBox() then throttle,steering,drift,gas=0,0,false,false end
  if MobileView.controlsV1Enabled() and Workspace:GetAttribute('KDMGasPedalEnabled')==true then
   remote:FireServer('Input',player:GetAttribute('LobbyDriveGeneration'),throttle,steering,drift==true,gas==true)
  else remote:FireServer("Input",player:GetAttribute("LobbyDriveGeneration"),throttle,steering,drift==true) end
 end)
 remote.OnClientEvent:Connect(function(action,id,gen,ok,message,returned)
  if action~="Reply" or not pending or id~=pending.id then return end
  local current=player:GetAttribute("LobbyDriveGeneration") or 0
  if type(gen)~="number" or gen<current then return end
  local done=pending;pending=nil;button.Active=true
  status.Text=if ok then "" else (message or "DRIVE UNAVAILABLE")
  if not ok then neutral();detach() end
  if done.callback then done.callback(ok,returned) end
 end)
 button.Activated:Connect(function()
  if pending then return end
  if player:GetAttribute('LobbyDriveActive')==true then
   local parkTrial=player:GetAttribute('ParkTrialPhase')~=nil
   local character=player.Character;local requestToken=token+1
   request('Stop',function(ok,returned)
    if not ok or not returned or parkTrial then return end
    -- The reply can arrive before replicated seat/attribute changes settle.
    task.spawn(function()
     local deadline=os.clock()+2
     while token==requestToken and player.Character==character and os.clock()<deadline do
      local h=character and character:FindFirstChildOfClass('Humanoid')
      if not h or h.Health<=0 then return end
      if not h.SeatPart and player:GetAttribute('LobbyDriveActive')~=true and player:GetAttribute('LobbyDrivePending')~=true then
       postDrive:show();return
      end
      Run.RenderStepped:Wait()
     end
    end)
   end)
  else request('Drive') end
 end)
 PromptService.PromptTriggered:Connect(function(prompt,who)
  if who~=player or not prompt.Parent or pending or not gui.Enabled or player:GetAttribute("LobbyDriveActive")==true then return end
  if prompt==entryPrompt then request("Drive");return end
  local showroom=hub:FindFirstChild("KDMClientShowroom")
  if prompt.Name~="LobbyDisplayTestDrive"or not showroom or not prompt:IsDescendantOf(showroom)then return end
  local previewKartId=prompt.Parent:GetAttribute("ShowroomKartId")
  local entry=require(Shared:WaitForChild("KartCatalog")).Entries[previewKartId]
  if entry and entry.VisualModelName=="KDMV2"then request("Drive",nil,previewKartId)end
 end)
 player.CharacterRemoving:Connect(function() postDrive:hide();neutral();detach();if pending and pending.callback then pending.callback(false) end;pending=nil;token+=1 end)
 player:GetAttributeChangedSignal("LobbyDriveActive"):Connect(function()
  if player:GetAttribute("LobbyDriveActive")~=true then neutral();detach() else suspended=false end
 end)
 player:GetAttributeChangedSignal("LobbyDriveResetSerial"):Connect(function() neutral();previousTarget=nil;suspended=false end)
 UIS.WindowFocusReleased:Connect(function() focused=false;neutral() end)
 UIS.WindowFocused:Connect(function() focused=true;suspended=false end)
 GuiService.MenuOpened:Connect(neutral)
 GuiService.MenuClosed:Connect(function() suspended=false end)
 Run.RenderStepped:Connect(function(dt)
  postDrive:update()
  local active=player:GetAttribute("LobbyDriveActive")==true
  if trialView then trialView:update(active,Workspace.CurrentCamera)end
  overtakeBots:update(active)
  local phase=player:GetAttribute("ParkTrialPhase")
  local driving=active and (phase==nil or phase=="RUNNING")
  local rooms=gui.Parent:FindFirstChild("KDMMatchRooms")
  gui.Enabled=player:GetAttribute("LobbyDriveAvailable")==true and player:GetAttribute("RaceState")=="GARAGE"
   and player:GetAttribute("KDMRoutePending")~="RACE_LAUNCH" and player:GetAttribute("HubOverlayOpen")~=true and not (rooms and rooms.Enabled) and player:GetAttribute("KDMShopOpen")~=true and player:GetAttribute("KDMProfileOpen")~=true
  button.Visible=active and phase~="FINISHING" and phase~="FINISHED" and phase~="INVALID"
  returnLabel.Text=if pending then "PLEASE WAIT" else "RETURN LOBBY"
  charge.Visible=active
  gauge.Visible=active
  local touch=gui.Parent:FindFirstChild("RobloxKartTouchDriving")
  local controls=touch and touch:FindFirstChild("Controls")
  local size=if controls then controls.AbsoluteSize else Workspace.CurrentCamera.ViewportSize
  local l=MobileView.layout(size);if not l.controlsV1 then l=LobbyLayout.apply(l,size) end
  if parkMap then
   parkMap.Visible=l.controlsV1~=nil and active and gui.Enabled
   if l.controlsV1 then
    local r=MobileView.controlsV1Layout(parkMapGui.AbsoluteSize).map
    parkMap.Position=UDim2.fromOffset(r.x,r.y);parkMap.Size=UDim2.fromOffset(r.width,r.height)
    local kart=seatKart();local body=kart and kart:FindFirstChild('Chassis');local center=driveZone:GetAttribute('Center')
    if body and center then
     local p=parkMapPoint(body.Position.X-center.X,body.Position.Z-center.Z);parkDot.Position=UDim2.fromScale(p.X,p.Y)
     parkMarker.update(parkDot,body.CFrame.LookVector)
    end
   end
  end
  local navigation=gui.Parent:FindFirstChild("KDMHubNavigation")
  local wallet=navigation and navigation:FindFirstChild("WalletCapsule")
  local walletBottom=if wallet then wallet.AbsolutePosition.Y+wallet.AbsoluteSize.Y-canvas.AbsolutePosition.Y else nil
  local practiceLayout=practiceView:update(driving and gui.Enabled,l,walletBottom,seatKart())
  local rewardHud=gui.Parent:FindFirstChild('KDMActivityReward')
  if l.controlsV1 and rewardHud then
   local progress=rewardHud:FindFirstChild('Progress')
   if progress then
    local r=l.controlsV1.clock
    progress.AnchorPoint=Vector2.zero
    progress.Position=UDim2.fromOffset(r.x,r.y)
    progress.Size=UDim2.fromOffset(r.width,r.height)
    progress.TextSize=10
    progress.TextWrapped=true
   end
  end
  combatView:layout(UDim2.new(.5,0,0,6),nil,
   rewardHud and rewardHud.Enabled and rewardHud:FindFirstChild('Progress'))
  charge.Visible=driving;gauge.Visible=driving
  charge.TextSize=if practiceLayout.compact then 12 else 16
  charge.Position=UDim2.fromOffset(practiceLayout.x,practiceLayout.boostY);charge.Size=UDim2.fromOffset(practiceLayout.width,practiceLayout.boostTextHeight)
  gauge.Position=UDim2.fromOffset(practiceLayout.x,practiceLayout.gaugeY);gauge.Size=UDim2.fromOffset(practiceLayout.width,practiceLayout.gaugeHeight)
  local segmentWidth=(practiceLayout.width-16)/5
  for i,segment in segments do segment.Size=UDim2.fromOffset(segmentWidth,practiceLayout.gaugeHeight);segment.Position=UDim2.fromOffset((i-1)*(segmentWidth+4),0) end
  if l.controlsV1 then
   local r=l.controlsV1.gauge;local controlsOrigin=if controls then controls.AbsolutePosition-canvas.AbsolutePosition else Vector2.zero
   charge.Visible=false
   gauge.Position=UDim2.fromOffset(controlsOrigin.X+r.x,controlsOrigin.Y+r.y);gauge.Size=UDim2.fromOffset(r.width,r.height)
   local segmentWidth=(r.width-16)/5
   for i,segment in segments do segment.Size=UDim2.fromOffset(segmentWidth,r.height);segment.Position=UDim2.fromOffset((i-1)*(segmentWidth+4),0) end
  end
  local exit=LobbyLayout.shortcuts(canvas.AbsoluteSize,MobileView)
  button.AnchorPoint=Vector2.zero
  button.Position=UDim2.fromOffset(exit.x+6,exit.y+4)
  button.Size=UDim2.fromOffset(exit.width-12,44)
  if trialView and wallet then
   local position=wallet.AbsolutePosition-canvas.AbsolutePosition
   button.Position=UDim2.fromOffset(position.X,position.Y+wallet.AbsoluteSize.Y+8)
   button.Size=UDim2.fromOffset(wallet.AbsoluteSize.X,44)
  end
  local promptsEnabled=gui.Enabled and not active and not pending
  for _,prompt in displayPrompts do
   if prompt.Parent and prompt.Enabled~=promptsEnabled then prompt.Enabled=promptsEnabled end
  end
  if entryPrompt then entryPrompt.Enabled=promptsEnabled end
  status.Visible=status.Text~=""
  local kart,h=seatKart();local body=kart and kart:FindFirstChild("Chassis")
  if not active or not body or suspended then if feedback then feedback:update(dt,false) end;if not active then detach() end;return end
  local camera=Workspace.CurrentCamera;if not camera then return end
  if body~=cameraBody then
   detach();cameraBody=body;savedFov=camera.FieldOfView;previousTarget=nil
   feedback=DriftFeedback.new(body,kart,driveZone)
   exhaust=Exhaust.new(kart)
   engine=Audio.createSound("LobbyEngineLoop",AudioConfig.ASSETS.ENGINE_LOOP,body,Audio.getGroup("RobloxKartEngine"),true,AudioConfig.ENGINE.IDLE_VOLUME,true)
   if Audio.createEngineLooper then
    engineSecondary=Audio.createSound("LobbyEngineLoopB",AudioConfig.ASSETS.ENGINE_LOOP,body,Audio.getGroup("RobloxKartEngine"),true,0,true)
    if engineSecondary then engineSecondary.PlaybackSpeed=AudioConfig.ENGINE.IDLE_PLAYBACK_SPEED*AudioConfig.ENGINE.SECONDARY_DETUNE end
    engineLooper=Audio.createEngineLooper(engine,engineSecondary)
   end
   boostAudio=Audio.createBoostAudio(body,'Lobby')
   missileHitCue=Audio.createSound('LobbyMissileHit',AudioConfig.COMBAT.Missile.Asset,body,Audio.getGroup('RobloxKartSFX'),false,AudioConfig.COMBAT.Missile.Volume,true)
   if missileHitCue then missileHitCue.PlaybackSpeed=AudioConfig.COMBAT.Missile.Pitch end
   thunderHitCue=Audio.createSound('LobbyThunderHit',AudioConfig.COMBAT.Thunder.Asset,body,Audio.getGroup('RobloxKartSFX'),false,AudioConfig.COMBAT.Thunder.Volume,true)
   if thunderHitCue then thunderHitCue.PlaybackSpeed=AudioConfig.COMBAT.Thunder.Pitch end
   engineAB=EngineAB.new(body,canvas)
   if engine then diagnostic=EngineDiagnostic.new(engine,Run:IsStudio());diagnostic:setMode(player:GetAttribute("KartEngineLoopTestMode"));engine:Play() end
  end
  -- Reuse the accepted race analog dials + digital readout. This is local
  -- presentation only: no speed attributes, remotes or driving writes.
  if driveZone:GetAttribute('DriveGeometry')=='ROOKIE_LOOP_V1' or (Input.isTouchPreferred() and MobileView.controlsV1Enabled()) then
   if not speedGauge then
    speedGauge=require(script.Parent:WaitForChild('V2GaugeController')).new(gui.Parent,if Input.isTouchPreferred() and MobileView.controlsV1Enabled() then 'DIGITAL' else 'ANALOG',MobileView)
    speedGauge.gui.Name='KDMLobbySpeedHud'
   end
   speedGauge.gui.Enabled=gui.Enabled and phase~="FINISHING" and phase~="FINISHED" and phase~="INVALID"
   local velocity=body.AssemblyLinearVelocity
   local measuredSpeed=if driving then Vector3.new(velocity.X,0,velocity.Z).Magnitude else 0
   speedGauge:update(body,measuredSpeed,dt,Input.isTouchPreferred(),gui.Enabled and focused and not GuiService.MenuIsOpen)
  end
  local speed=math.abs(body.AssemblyLinearVelocity:Dot(body.CFrame.LookVector))
  if feedback then feedback:update(dt,(kart:GetAttribute("LobbyDrifting")==true or kart:GetAttribute("KartSlickActive")==true) and not suspended and focused and not GuiService.MenuIsOpen, kart:GetAttribute("KartOffTrack")==true, speed) end
  if exhaust then exhaust:update(dt,not suspended and focused and not GuiService.MenuIsOpen) end
  local miniBoost=kart:GetAttribute('KartBoosting')==true
  local nitro=kart:GetAttribute('KartNitroActive')==true
  local boosting=miniBoost or nitro
  if boostAudio then boostAudio:step(dt,miniBoost,nitro,kart:GetAttribute('KartNitroEndReason'),driving and not suspended and focused and not GuiService.MenuIsOpen) end
  local missileHit=kart:GetAttribute('KartMissileHitActive')==true
  if missileHit and not previousMissileHit then Audio.playOnce(missileHitCue) end
  previousMissileHit=missileHit
  local thunderHit=kart:GetAttribute('KartThunderHitActive')==true
  if thunderHit and not previousThunderHit then Audio.playOnce(thunderHitCue) end
  previousThunderHit=thunderHit
  charge.Text=if kart:GetAttribute('KartBoosting') then 'MINI BOOST' elseif kart:GetAttribute('LobbyDriftReady') then 'BOOST READY • RELEASE' else string.format('BOOST CHARGE %d%%',math.floor((kart:GetAttribute('LobbyDriftCharge') or 0)*100))
  if l.controlsV1 then
   charge.Text=if kart:GetAttribute('KartBoosting') then 'BOOST' elseif kart:GetAttribute('LobbyDriftReady') then 'READY' else string.format('%d%%',math.floor((kart:GetAttribute('LobbyDriftCharge') or 0)*100))
  end
  for i,segment in segments do segment.BackgroundColor3=if kart:GetAttribute('LobbyDriftReady') then Color3.fromRGB(255,218,67) elseif (kart:GetAttribute('LobbyDriftCharge') or 0)*5>=i then Color3.fromRGB(111,211,245) else Color3.fromRGB(26,40,56) end
  local f=body.CFrame.LookVector;f=Vector3.new(f.X,0,f.Z).Unit
  local target=body.Position
  local desired=CFrame.lookAt(target-f*18+Vector3.new(0,8,0),target+f*12+Vector3.new(0,2,0))
  camera.CameraType=Enum.CameraType.Scriptable;camera.FieldOfView=75
  if player:GetAttribute('ParkTrialFinishPhase')=='ROLL'and Input.isTouchPreferred()and canvas.AbsoluteSize.X>=720 then
   local progress=math.clamp((Workspace:GetServerTimeNow()-(player:GetAttribute('ParkTrialFinishedAt')or Workspace:GetServerTimeNow()))/RaceConfig.FINISH_ROLL_SECONDS,0,1)
   local drift=math.clamp((progress-RaceConfig.FINISH_DRIFT_START_RATIO)/(1-RaceConfig.FINISH_DRIFT_START_RATIO),0,1)
   drift=drift*drift*(3-2*drift)
   local position=target-f*KartConfig.CAMERA_DISTANCE+Vector3.yAxis*KartConfig.CAMERA_HEIGHT
   local look=target+f*KartConfig.CAMERA_LOOK_AHEAD+Vector3.yAxis*2
   position,look=FinishComposition.offset(position,look,target+Vector3.yAxis*2.25,camera.ViewportSize,KartConfig.CAMERA_FOV,.5+(RaceConfig.TARGET_FINISH_SCREEN_X-.5)*drift)
   desired=CFrame.lookAt(position,look)
  end
  local present=player:GetAttribute('ParkTrialFinishPhase')=='PRESENT'
  if present then
   if not finishCameraStart then finishCameraStart=camera.CFrame;finishCameraElapsed=0 end
   finishCameraElapsed+=dt
   local visual=kart:FindFirstChild('Visual');local v2=visual and visual:GetAttribute('VisualModelName')=='KDMV2'
   local mobile=Input.isTouchPreferred()and camera.ViewportSize.X>camera.ViewportSize.Y and canvas.AbsoluteSize.X>=720
   local position,look=FinishComposition.front(target,f,camera.ViewportSize,KartConfig.CAMERA_FOV,
    if v2 then KartConfig.V2_FINISH_CAMERA_SIDE else 2.5,if v2 then KartConfig.V2_FINISH_CAMERA_HEIGHT else 4.5,
    if mobile then RaceConfig.MOBILE_FINISH_PRESENT_SCREEN_X else .5)
   local alpha=math.clamp(finishCameraElapsed/RaceConfig.FINISH_CAMERA_TRANSITION_SECONDS,0,1)
   camera.CFrame=finishCameraStart:Lerp(CFrame.lookAt(position,look),alpha*alpha*(3-2*alpha))
   camera.FieldOfView=KartConfig.CAMERA_FOV;camera.Focus=CFrame.new(look)
  else
   finishCameraStart,finishCameraElapsed=nil,nil
   camera.CFrame=Motion.step(camera.CFrame,previousTarget,target,desired,6,dt);camera.Focus=CFrame.new(target);previousTarget=target
  end
  if engine then
   if not engine.IsPlaying then engine:Play()end
   local speed=math.abs(body.AssemblyLinearVelocity:Dot(body.CFrame.LookVector))
   local ratio=math.clamp(speed/KartConfig.MAX_FORWARD_SPEED,0,1)
   local bonus=math.clamp((speed-KartConfig.MAX_FORWARD_SPEED)/(KartConfig.MINI_BOOST_MAX_SPEED-KartConfig.MAX_FORWARD_SPEED),0,1)
   local pitch=AudioConfig.ENGINE.IDLE_PLAYBACK_SPEED+(AudioConfig.ENGINE.NORMAL_PLAYBACK_SPEED-AudioConfig.ENGINE.IDLE_PLAYBACK_SPEED)*ratio+(AudioConfig.ENGINE.MAX_PLAYBACK_SPEED-AudioConfig.ENGINE.NORMAL_PLAYBACK_SPEED)*bonus+(if boosting then AudioConfig.ENGINE.BOOST_PLAYBACK_BONUS else 0)
   local volume=AudioConfig.ENGINE.IDLE_VOLUME+(AudioConfig.ENGINE.NORMAL_VOLUME-AudioConfig.ENGINE.IDLE_VOLUME)*ratio+(AudioConfig.ENGINE.MAX_VOLUME-AudioConfig.ENGINE.NORMAL_VOLUME)*bonus
   if Audio.gasEngineTargets then pitch,volume=Audio.gasEngineTargets(pitch,volume,speed,kart:GetAttribute('KartGasPedalActive')==true,boosting,nitro,Workspace:GetServerTimeNow())end
   local finishing=player:GetAttribute('ParkTrialFinishPhase')=='ROLL' or present
   pitch,volume=finishEngine:step(finishing,pitch,volume,dt)
   local alpha=if finishing then 1 else 1-math.exp(-AudioConfig.ENGINE.RESPONSE*dt)
   local fixedPitch=diagnostic~=nil and diagnostic:isFixed()
   local diagActive=player:GetAttribute("KartEngineLoopTestMode")~=nil and player:GetAttribute("KartEngineLoopTestMode")~="NORMAL"
   if fixedPitch then engine.PlaybackSpeed=1 end
   if engineLooper then
    engineLooper:step(dt,if fixedPitch then 1 else math.clamp(pitch,.7,1.55),volume,alpha,diagActive or fixedPitch)
   elseif not diagnostic or not diagnostic:isFixed() then
    engine.PlaybackSpeed+=(math.clamp(pitch,.7,1.55)-engine.PlaybackSpeed)*alpha
    engine.Volume+=(volume-engine.Volume)*alpha
   end
   if engineAB then engineAB:update(engine,engine.PlaybackSpeed,engine.Volume) end
  end
 end)
end
return Controller
