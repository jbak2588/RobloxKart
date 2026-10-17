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
local Controller={}
local started=false
function Controller.start()
 if started or Workspace:GetAttribute("KDMServerRole")~="HUB"
  or Workspace:GetAttribute("KDMEnableRaceBot")==true then return end
 local remote=RS:WaitForChild("LobbyDriveControl",10);if not remote then return end
 started=true
 local player=Players.LocalPlayer;local token=0;local pending=nil;local suspended=false;local handoffComplete=false
 local feedback=nil
 local exhaust=nil
 local engineAB=nil
 local focused=true;local cameraBody=nil;local previousTarget=nil;local savedFov=nil;local engine,engineSecondary,engineLooper,diagnostic=nil,nil,nil,nil
 local boostCue=nil;local previousBoost=false
 local driveZone=Workspace:WaitForChild("KDMHub"):WaitForChild("LobbyFrontTestDriveZone")
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
 local button=Instance.new("TextButton");button.Name="Drive";button.AnchorPoint=Vector2.new(0,1)
 button.Position=UDim2.new(0,12,1,-12);button.Size=UDim2.fromOffset(156,44)
 button.BackgroundColor3=Color3.fromRGB(111,211,245);button.TextColor3=Color3.fromRGB(12,27,42)
 button.Font=Enum.Font.GothamBold;button.TextSize=17;button.BorderSizePixel=0;button.Text="DRIVE";button.Parent=canvas
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,8);corner.Parent=button
 StyleHelper.apply3DButton(button,Color3.fromRGB(80,190,255),Color3.fromRGB(0,140,240),Color3.fromRGB(0,95,200),12,2.5)
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
 local smokeView=SmokeView.new(player:WaitForChild('PlayerGui'),player,true)
 local postDrive=PostDriveView.new(gui.Parent,function()
  local rooms=gui.Parent:FindFirstChild('KDMMatchRooms')
  local h=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
  return h~=nil and h.Health>0 and not h.SeatPart and player:GetAttribute('RaceState')=='GARAGE'
   and player:GetAttribute('LobbyDriveActive')~=true and player:GetAttribute('LobbyDrivePending')~=true
   and player:GetAttribute('KDMRoutePending')~='RACE_LAUNCH' and player:GetAttribute('HubOverlayOpen')~=true
   and player:GetAttribute('KDMShopOpen')~=true and player:GetAttribute('KDMProfileOpen')~=true and not (rooms and rooms.Enabled)
 end,function() Garage.open('RACE') end)
 gui.Destroying:Connect(function()smokeView:destroy();postDrive:destroy()end)
 local function neutral()
  if exhaust then exhaust:update(0,false) end
  if feedback then feedback:update(0,false) end
  suspended=true;Input.resetTouchActions();Input.resetLobbyTouchState()
  remote:FireServer("Input",player:GetAttribute("LobbyDriveGeneration"),0,0)
 end
 local function detach()
  if engineAB then engineAB:destroy();engineAB=nil end
  if boostCue then Audio.stop(boostCue);boostCue:Destroy();boostCue=nil end;previousBoost=false
  if exhaust then exhaust:destroy();exhaust=nil end
  if feedback then feedback:destroy();feedback=nil end
  if engine then engine:Stop();engine:Destroy();engine=nil end
  if engineSecondary then engineSecondary:Stop();engineSecondary:Destroy();engineSecondary=nil end
  engineLooper=nil
  if diagnostic then diagnostic:destroy();diagnostic=nil end
  if cameraBody then
   local camera=Workspace.CurrentCamera;local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
   if camera then camera.CameraType=Enum.CameraType.Custom;if h then camera.CameraSubject=h end;if savedFov then camera.FieldOfView=savedFov end end
  end
  cameraBody,previousTarget,savedFov=nil,nil,nil
 end
 local function request(action,callback,previewKartId)
  if pending then return false end
  postDrive:hide()
  token+=1;local id=token;pending={id=id,callback=callback,action=action}
  if action=="Stop" then neutral();detach() else suspended=false end
  button.Active=false
  if previewKartId then remote:FireServer(action,id,previewKartId) else remote:FireServer(action,id) end
  task.delay(5,function()
   if pending and pending.id==id then
    local stale=pending;pending=nil;neutral();detach();status.Text="PLEASE TRY AGAIN";button.Active=true
    if stale.action=="Drive" then token+=1;remote:FireServer("Stop",token) end
    if stale.callback then stale.callback(false) end
   end
  end)
  return true
 end
 Garage.setOpenGate(function(resume)
  if handoffComplete then handoffComplete=false;return false end
  if player:GetAttribute("LobbyDriveActive")~=true and player:GetAttribute("LobbyDrivePending")~=true and not pending then return false end
  if pending then return true end
  request("Stop",function(ok) if ok then handoffComplete=true;resume() end end)
  return true
 end)
 Input.setLobbyInputSender(function(throttle,steering,drift)
  local kart=seatKart();if not kart or player:GetAttribute("LobbyDriveActive")~=true then return end
  if suspended or not focused or GuiService.MenuIsOpen or UIS:GetFocusedTextBox() then throttle,steering,drift=0,0,false end
  remote:FireServer("Input",player:GetAttribute("LobbyDriveGeneration"),throttle,steering,drift==true)
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
   local character=player.Character;local requestToken=token+1
   request('Stop',function(ok,returned)
    if not ok or not returned then return end
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
  local rooms=gui.Parent:FindFirstChild("KDMMatchRooms")
  gui.Enabled=player:GetAttribute("LobbyDriveAvailable")==true and player:GetAttribute("RaceState")=="GARAGE"
   and player:GetAttribute("KDMRoutePending")~="RACE_LAUNCH" and player:GetAttribute("HubOverlayOpen")~=true and not (rooms and rooms.Enabled) and player:GetAttribute("KDMShopOpen")~=true and player:GetAttribute("KDMProfileOpen")~=true
  button.Visible=active
  returnLabel.Text=if pending then "PLEASE WAIT" else "RETURN LOBBY"
  charge.Visible=active
  gauge.Visible=active
  local touch=gui.Parent:FindFirstChild("RobloxKartTouchDriving")
  local controls=touch and touch:FindFirstChild("Controls")
  local driftButton=controls and controls:FindFirstChild("Drift")
  local size=if controls then controls.AbsoluteSize else Workspace.CurrentCamera.ViewportSize
  local l=LobbyLayout.apply(MobileView.layout(size),size)
  local navigation=gui.Parent:FindFirstChild("KDMHubNavigation")
  local wallet=navigation and navigation:FindFirstChild("WalletCapsule")
  local walletLeft=if wallet then wallet.AbsolutePosition.X-canvas.AbsolutePosition.X else nil
  local walletBottom=if wallet then wallet.AbsolutePosition.Y+wallet.AbsoluteSize.Y-canvas.AbsolutePosition.Y else nil
  local driftLeft=if driftButton and controls.Visible then driftButton.AbsolutePosition.X-canvas.AbsolutePosition.X else l.driftX
  local hud=LobbyLayout.trainingHud(canvas.AbsoluteSize,walletLeft,walletBottom,driftLeft,
   if driftButton and controls.Visible then driftButton.AbsoluteSize.X else l.driftHitWidth,l.driftWidth)
  local compactPractice=practiceView:update(active and gui.Enabled,l,walletBottom,seatKart())
  charge.Visible=active and not compactPractice;gauge.Visible=active and not compactPractice
  charge.Position=UDim2.fromOffset(hud.x,hud.y);charge.Size=UDim2.fromOffset(hud.width,22)
  gauge.Position=UDim2.fromOffset(hud.x,hud.y+26);gauge.Size=UDim2.fromOffset(hud.width,9)
  local segmentWidth=(hud.width-16)/5
  for i,segment in segments do segment.Size=UDim2.fromOffset(segmentWidth,9);segment.Position=UDim2.fromOffset((i-1)*(segmentWidth+4),0) end
  local exit=LobbyLayout.shortcuts(canvas.AbsoluteSize,MobileView)
  button.AnchorPoint=Vector2.zero
  button.Position=UDim2.fromOffset(exit.x+6,exit.y+4)
  button.Size=UDim2.fromOffset(exit.width-12,44)
  local promptsEnabled=gui.Enabled and not active and not pending and not postDrive.gui.Enabled
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
   boostCue=Audio.createSound('LobbyBoostStart',AudioConfig.ASSETS.BOOST_START,body,Audio.getGroup('RobloxKartSFX'),false,AudioConfig.BOOST.START_VOLUME,true)
   engineAB=EngineAB.new(body,canvas)
   if engine then diagnostic=EngineDiagnostic.new(engine,Run:IsStudio());diagnostic:setMode(player:GetAttribute("KartEngineLoopTestMode"));engine:Play() end
  end
  if feedback then feedback:update(dt,(kart:GetAttribute("LobbyDrifting")==true or kart:GetAttribute("KartSlickActive")==true) and not suspended and focused and not GuiService.MenuIsOpen) end
  if exhaust then exhaust:update(dt,not suspended and focused and not GuiService.MenuIsOpen) end
  local boosting=kart:GetAttribute('KartBoosting')==true or kart:GetAttribute('KartNitroActive')==true
  if boosting and not previousBoost then Audio.playOnce(boostCue) end
  if not boosting and previousBoost then Audio.stop(boostCue) end
  previousBoost=boosting
  charge.Text=if kart:GetAttribute('KartBoosting') then 'MINI BOOST' elseif kart:GetAttribute('LobbyDriftReady') then 'BOOST READY • RELEASE' else string.format('BOOST CHARGE %d%%',math.floor((kart:GetAttribute('LobbyDriftCharge') or 0)*100))
  for i,segment in segments do segment.BackgroundColor3=if kart:GetAttribute('LobbyDriftReady') then Color3.fromRGB(255,218,67) elseif (kart:GetAttribute('LobbyDriftCharge') or 0)*5>=i then Color3.fromRGB(111,211,245) else Color3.fromRGB(26,40,56) end
  local f=body.CFrame.LookVector;f=Vector3.new(f.X,0,f.Z).Unit
  local target=body.Position
  local desired=CFrame.lookAt(target-f*18+Vector3.new(0,8,0),target+f*12+Vector3.new(0,2,0))
  camera.CameraType=Enum.CameraType.Scriptable;camera.FieldOfView=75
  camera.CFrame=Motion.step(camera.CFrame,previousTarget,target,desired,6,dt);camera.Focus=CFrame.new(target);previousTarget=target
  if engine then
   local speed=math.abs(body.AssemblyLinearVelocity:Dot(body.CFrame.LookVector))
   local ratio=math.clamp(speed/KartConfig.MAX_FORWARD_SPEED,0,1)
   local bonus=math.clamp((speed-KartConfig.MAX_FORWARD_SPEED)/(KartConfig.MINI_BOOST_MAX_SPEED-KartConfig.MAX_FORWARD_SPEED),0,1)
   local pitch=AudioConfig.ENGINE.IDLE_PLAYBACK_SPEED+(AudioConfig.ENGINE.NORMAL_PLAYBACK_SPEED-AudioConfig.ENGINE.IDLE_PLAYBACK_SPEED)*ratio+(AudioConfig.ENGINE.MAX_PLAYBACK_SPEED-AudioConfig.ENGINE.NORMAL_PLAYBACK_SPEED)*bonus+(if boosting then AudioConfig.ENGINE.BOOST_PLAYBACK_BONUS else 0)
   local volume=AudioConfig.ENGINE.IDLE_VOLUME+(AudioConfig.ENGINE.NORMAL_VOLUME-AudioConfig.ENGINE.IDLE_VOLUME)*ratio+(AudioConfig.ENGINE.MAX_VOLUME-AudioConfig.ENGINE.NORMAL_VOLUME)*bonus
   local alpha=1-math.exp(-AudioConfig.ENGINE.RESPONSE*dt)
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
