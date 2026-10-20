local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Garage = require(script.Parent:WaitForChild("GarageUiController"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KDMUiTheme"))
local GuidanceState = require(script.Parent:WaitForChild("HubGuidanceState"))
local GuidanceView = require(script.Parent:WaitForChild("HubGuidanceView"))
local WorldGuidance = require(script.Parent:WaitForChild("HubWorldGuidanceView"))
local LobbyLayout=require(script.Parent:WaitForChild("LobbyDriveLayout"))
local MobileView=require(script.Parent:WaitForChild("MobileControlView"))
local StyleHelper = require(script.Parent:WaitForChild("KDMUiStyleHelper"))
local HubUiController = {}
local started = false
local SHOWROOM_VISUAL_SCALE = 1.2

-- Reuse the yellow stand between the exterior bollards; keep the entry prompt.
function HubUiController.createTestDriveKiosk(hub)
 local zone=hub:FindFirstChild('LobbyFrontTestDriveZone')
 local entry=zone and zone:FindFirstChild('LobbyFrontDriveEntry')
 local source=hub:FindFirstChild('RaceStationKiosk',true)
 if not entry or not source then return nil end
 local kiosk=source:Clone();kiosk.Name='TestDriveEntryKiosk'
 for _,d in kiosk:GetDescendants() do
  if d:IsA('BillboardGui') or d:IsA('ProximityPrompt') or d:IsA('LuaSourceContainer') then d:Destroy()
  elseif d:IsA('BasePart') then
   d.Anchored=true;d.CanCollide=false;d.CanTouch=false;d.CanQuery=false;d.CastShadow=false
  end
 end
 local old=kiosk:GetPivot()
 -- The source stand's visible screen faces the exterior track (-Z);
 -- its rear edge stays just outside the wall, between the two bollards.
 kiosk:PivotTo(CFrame.new(entry.Position.X+4.65,old.Position.Y,entry.Position.Z+9.4)*old.Rotation)
 local box,size=kiosk:GetBoundingBox()
 local top=entry.Position.Y+entry.Size.Y/2
 kiosk:PivotTo(kiosk:GetPivot()+Vector3.new(0,top-(box.Position.Y-size.Y/2),0))
 kiosk.Parent=hub
 return kiosk
end

-- Visual-only client ownership. Each client calls this with its own selection/parent.
function HubUiController.createDisplay(parent, anchor, definition, factory,wingEquipped)
 local visual = factory.createVisual(definition,wingEquipped)
 visual.Name = "KDMClientMyKartDisplay"
 visual:SetAttribute("SelectedKartId", definition.Id)
 local bottom = math.huge
 for _,node in visual:GetDescendants() do
  if node:IsA("LuaSourceContainer") or node:IsA("Seat") or node:IsA("VehicleSeat") or node:IsA("Constraint") or node:IsA("WeldConstraint") or node:IsA("JointInstance")
   or node:IsA("Sound") or node:IsA("BodyMover") or node:IsA("ProximityPrompt")
   or node:IsA("ParticleEmitter") or node:IsA("Trail") or node:IsA("Beam") then node:Destroy() end
 end
 -- Enlarge only the static exhibit; ground the scaled tires below. Live karts
 -- continue to use the original factory dimensions and driver seat contract.
 visual:ScaleTo(visual:GetScale() * SHOWROOM_VISUAL_SCALE)
 for _,node in visual:GetDescendants() do
  if node:IsA("BasePart") then
   node.Anchored,node.CanCollide,node.CanTouch,node.CanQuery=true,false,false,false
   for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
    local corner=node.CFrame*Vector3.new(x*node.Size.X/2,y*node.Size.Y/2,z*node.Size.Z/2)
    bottom=math.min(bottom,corner.Y)
   end end end
  end
 end
 assert(bottom < math.huge,"Empty Kart visual")
 for _,node in visual:GetDescendants() do
  if node:IsA("BasePart") then node.CFrame=anchor.CFrame*CFrame.new(0,-bottom,0)*node.CFrame end
 end
 local previous=parent:FindFirstChild("KDMClientMyKartDisplay")
 if previous then previous:Destroy() end
 visual.Parent=parent
 return visual
end

function HubUiController.start()
 if started or Workspace:GetAttribute("KDMServerRole") ~= "HUB" then return end
 started = true
 local player = Players.LocalPlayer
 local hub = Workspace:WaitForChild("KDMHub")
 local gui = Instance.new("ScreenGui")
 gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "KDMHubNavigation", false, 18
 gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
 gui.Parent = player:WaitForChild("PlayerGui")
 local connections = {}
 local state = GuidanceState.new()
 local roomOwned = false
 local previousRaceState = player:GetAttribute("RaceState")
 local function open(action)
  local rooms = gui.Parent:FindFirstChild("KDMMatchRooms")
  if roomOwned or player:GetAttribute("HubOverlayOpen") == true or (player:GetAttribute('KDMProfileOpen')==true or player:GetAttribute('KDMShopOpen')==true) or (rooms and rooms.Enabled) then return end
  if action=='SHOP' then
   if player:GetAttribute('LobbyDriveActive')==true or player:GetAttribute('LobbyDrivePending')==true or (player:GetAttribute('KDMRoutePending')~=nil and player:GetAttribute('KDMRoutePending')~='') then return end
   require(script.Parent.GarageShopController).open('WINGS');return
  end
  Garage.open(action, if action == "ROOMS" then state.trackId else nil)
 end
 local function onRaceNow()
  print("[F60:Client] event=F60_RACE_NOW_CLICKED")
  local rooms = gui.Parent:FindFirstChild("KDMMatchRooms")
  if roomOwned or player:GetAttribute("HubOverlayOpen") == true or (player:GetAttribute('KDMProfileOpen')==true or player:GetAttribute('KDMShopOpen')==true) or (rooms and rooms.Enabled) then return end
  if player:GetAttribute('LobbyDriveActive')==true or player:GetAttribute('LobbyDrivePending')==true or (player:GetAttribute('KDMRoutePending')~=nil and player:GetAttribute('KDMRoutePending')~='') then return end
  local MatchRoomUi = require(script.Parent:WaitForChild("MatchRoomUiController"))
  MatchRoomUi.quickStart()
 end
 local function onTestDrive()
  print("[F60:Client] event=F60_TEST_DRIVE_CLICKED")
  local rooms = gui.Parent:FindFirstChild("KDMMatchRooms")
  if roomOwned or player:GetAttribute("HubOverlayOpen") == true or (player:GetAttribute('KDMProfileOpen')==true or player:GetAttribute('KDMShopOpen')==true) or (rooms and rooms.Enabled) then return end
  if player:GetAttribute('LobbyDriveActive')==true or player:GetAttribute('LobbyDrivePending')==true or (player:GetAttribute('KDMRoutePending')~=nil and player:GetAttribute('KDMRoutePending')~='') then return end
  local TestDrive = require(script.Parent:WaitForChild("LobbyTestDriveController"))
  TestDrive.requestDrive()
 end
 local canvas = Instance.new("Frame")
 canvas.Name, canvas.Size, canvas.BackgroundTransparency = "SafeCanvas", UDim2.fromScale(1,1), 1
 canvas.Active, canvas.Parent = false, gui
 local guidance = GuidanceView.create(canvas, Theme, onRaceNow, onTestDrive)
 print("[F60:Client] event=F60_HUB_READY")
 local worldGuidance = WorldGuidance.create(hub, Theme)
 local raceBoard=require(script.Parent:WaitForChild('HubRaceBoardView')).create(hub)
 local panel = Instance.new("Frame")
 panel.Name = "Shortcuts"
 panel.AnchorPoint, panel.Position = Vector2.new(1,1), UDim2.new(1,-12,1,-12)
 panel.Size, panel.BackgroundColor3, panel.BorderSizePixel = UDim2.fromOffset(150,152), Color3.fromRGB(14, 22, 35), 0
 panel.BackgroundTransparency = 1
 panel.Parent = gui

 local panelCorner = Instance.new("UICorner")
 panelCorner.CornerRadius = UDim.new(0, 10)
 panelCorner.Parent = panel

 for index, action in {"GARAGE", "TRACKS", "SHOP"} do
  local button = Instance.new("TextButton")
  button.Name, button.Text = action, ""
  button.Size, button.Position = UDim2.new(1,-12,0,44), UDim2.fromOffset(6,6+(index-1)*48)
  button.BackgroundColor3 = Color3.fromRGB(24, 36, 52)
  button.BackgroundTransparency = .58
  button.TextColor3 = Color3.fromRGB(225, 235, 245)
  button.Font, button.TextSize, button.BorderSizePixel = Enum.Font.GothamBold, 13, 0
  button.Parent = panel
  local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,6);corner.Parent=button

  local caption=Instance.new('TextLabel');caption.Name='NavigationLabel';caption.Text=action;caption.BackgroundTransparency=1
  caption.Position=UDim2.fromOffset(22,0);caption.Size=UDim2.new(1,-26,1,0)
  caption.Font=Enum.Font.GothamBold;caption.TextSize=13
  caption.TextXAlignment=Enum.TextXAlignment.Left
  caption.TextColor3=Color3.fromRGB(225, 235, 245)
  caption.TextStrokeTransparency = 1
  caption.Parent=button

  local mark=Instance.new('Frame');mark.Name='NavigationIcon';mark.Size=UDim2.fromOffset(12,14)
  mark.Position=UDim2.new(0,5,.5,-7);mark.BackgroundTransparency=1;mark.Parent=button
  local function piece(x,y,w,h,color)
   local f=Instance.new('Frame');f.Size=UDim2.fromOffset(w,h);f.Position=UDim2.fromOffset(x,y);f.BackgroundColor3=color;f.BorderSizePixel=0;f.Parent=mark
  end
  local ink=if action=='GARAGE' then Color3.fromRGB(135,205,255) elseif action=='TRACKS' then Color3.fromRGB(255,170,125) else Color3.fromRGB(140,230,165)
  if action=='GARAGE' then
   piece(3,2,6,10,ink);for _,x in {0,10}do piece(x,2,2,4,ink);piece(x,9,2,4,ink)end
  elseif action=='TRACKS' then
   piece(0,1,2,13,ink);for x=0,2 do for y=0,1 do if (x+y)%2==0 then piece(3+x*3,1+y*4,3,4,ink)end end end
  else
   piece(1,5,11,9,ink);piece(3,1,2,5,ink);piece(8,1,2,5,ink);piece(3,0,7,2,ink)
  end

  table.insert(connections, button.Activated:Connect(function() open(action) end))
 end

 local walletCapsule = Instance.new("Frame")
 walletCapsule.Name = "WalletCapsule"
 walletCapsule.Position = UDim2.fromOffset(16, 16)
 walletCapsule.Size = UDim2.fromOffset(180, 42)
 walletCapsule.BackgroundColor3 = Color3.fromRGB(15, 25, 45)
 walletCapsule.BorderSizePixel = 0
 walletCapsule.Parent = gui

 local capsuleCorner = Instance.new("UICorner")
 capsuleCorner.CornerRadius = UDim.new(0, 21)
 capsuleCorner.Parent = walletCapsule

 local capsuleStroke = Instance.new("UIStroke")
 capsuleStroke.Thickness = 2.5
 capsuleStroke.Color = Color3.fromRGB(35, 60, 100)
 capsuleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
 capsuleStroke.Parent = walletCapsule

 StyleHelper.applyGradient(walletCapsule, Color3.fromRGB(28, 48, 85), nil, Color3.fromRGB(15, 25, 45), 45)

 local cashLabel = Instance.new("TextLabel")
 cashLabel.Name = "CashLabel"
 cashLabel.Text = "K$ 0"
 cashLabel.Position = UDim2.fromOffset(14, 0)
 cashLabel.Size = UDim2.new(1, -54, 1, 0)
 cashLabel.BackgroundTransparency = 1
 cashLabel.TextColor3 = Color3.fromRGB(85, 255, 100)
 cashLabel.Font = Enum.Font.GothamBlack
 cashLabel.TextSize = 16
 cashLabel.TextStrokeTransparency = 0.15
 cashLabel.TextStrokeColor3 = Color3.fromRGB(10, 40, 15)
 cashLabel.TextXAlignment = Enum.TextXAlignment.Left
 cashLabel.Parent = walletCapsule

 local plusButton = Instance.new("TextButton")
 plusButton.Name = "OpenShopBadge"
 plusButton.Text = "+"
 plusButton.Position = UDim2.new(1, -36, 0.5, -15)
 plusButton.Size = UDim2.fromOffset(30, 30)
 plusButton.TextColor3 = Color3.fromRGB(255, 255, 255)
 plusButton.Font = Enum.Font.GothamBlack
 plusButton.TextSize = 18
 plusButton.Parent = walletCapsule

 StyleHelper.apply3DButton(
  plusButton,
  Color3.fromRGB(255, 215, 40),
  Color3.fromRGB(255, 175, 20),
  Color3.fromRGB(220, 130, 0),
  15,
  2
 )

 table.insert(connections, plusButton.Activated:Connect(function() open("SHOP") end))

 local function updateWallet()
  local cash = player:GetAttribute("KDMWalletCash") or 0
  cashLabel.Text = "K$ " .. StyleHelper.formatCash(cash)
 end
 table.insert(connections, player:GetAttributeChangedSignal("KDMWalletCash"):Connect(updateWallet))
 updateWallet()
 local promptEnabled = {}
 for _, prompt in hub.Stations:GetDescendants() do
  if prompt:IsA("ProximityPrompt") then promptEnabled[prompt] = prompt.Enabled end
 end
 local function update()
  local overlay = player:GetAttribute("HubOverlayOpen") == true or (player:GetAttribute('KDMProfileOpen')==true or player:GetAttribute('KDMShopOpen')==true)
  local raceState = player:GetAttribute("RaceState")
  local selectedId=player:GetAttribute("SelectedKartId")
  local kartCatalog=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartCatalog"))
  GuidanceState.profileRestored(state,{
   completed=player:GetAttribute("KartProfileLoadCompleted"),result=player:GetAttribute("KartProfileLoadResult"),
   restored=player:GetAttribute("KartRestorationConfirmed"),restoredKartId=player:GetAttribute("KartRestoredKartId"),
   kartId=selectedId,validKart=kartCatalog.Entries[selectedId]~=nil,saveState=player:GetAttribute("KartSaveState"),
  })
  if previousRaceState ~= "GARAGE" and raceState == "GARAGE" then GuidanceState.returned(state, "RACE_RETURN") end
  previousRaceState = raceState
  gui.Enabled = player:GetAttribute("RaceState") == "GARAGE"
   and player:GetAttribute("HubOverlayOpen") ~= true and (player:GetAttribute('KDMProfileOpen')~=true and player:GetAttribute('KDMShopOpen')~=true)
   and player:GetAttribute("KDMRoutePending") ~= "RACE_LAUNCH"
  local rooms = gui.Parent:FindFirstChild("KDMMatchRooms")
  local modal = overlay or roomOwned or (rooms ~= nil and rooms.Enabled)
  for prompt, enabled in promptEnabled do
   prompt.Enabled = enabled and raceState == "GARAGE" and not modal
  end
  local presentation = GuidanceState.presentation(state, canvas.AbsoluteSize, raceState, overlay,
   player:GetAttribute("KDMRoutePending"), roomOwned or (rooms ~= nil and rooms.Enabled))
  local driving = player:GetAttribute("LobbyDriveActive") == true
  panel.Visible = not driving
  if driving then presentation.visible = false end
  local driveLayout=LobbyLayout.shortcuts(canvas.AbsoluteSize,MobileView)
  panel.AnchorPoint = if driving then Vector2.zero else Vector2.new(1,1)
  panel.Position = if driving then UDim2.fromOffset(driveLayout.x,driveLayout.y) else UDim2.new(1,-12,1,-12)
  panel.Size = if driving then UDim2.fromOffset(driveLayout.width,driveLayout.height) else UDim2.fromOffset(150,152)
  for index, name in {"GARAGE","TRACKS","SHOP"} do
   local button = panel[name]
   button.NavigationLabel.TextSize=if canvas.AbsoluteSize.X>=1200 then 15 else 13
   button.Visible=name~='SHOP' or not driving
   button.Size = if driving then UDim2.new(1,-12,0,34) else UDim2.new(1,-12,0,44)
   button.Position = if driving then UDim2.fromOffset(6,4+(index-1)*38) else UDim2.fromOffset(6,6+(index-1)*48)
  end
  if not driving then
   -- Wallet ends at y=58. Keep 12px clearance and three 44px rows,
   -- leaving the native joystick's lower-left corner available.
   panel.AnchorPoint = Vector2.zero
   panel.Position = UDim2.fromOffset(16,70)
   panel.Size = UDim2.fromOffset(if canvas.AbsoluteSize.X>=1200 then 150 else 132,144)
   for index,name in {'GARAGE','TRACKS','SHOP'} do
    panel[name].Size=UDim2.new(1,0,0,44)
    panel[name].Position=UDim2.fromOffset(0,(index-1)*50)
   end
  end
  guidance.update(presentation)
  worldGuidance.update(raceState == "GARAGE", if presentation.visible then presentation.destination else nil)
 end
 local disconnectNavigation = Garage.observeNavigation(function(event, action)
  if event == "Returned" then GuidanceState.returned(state, action)
  elseif event == "TrackConfirmed" then GuidanceState.confirmed(state, action) end
  update()
 end)
 table.insert(connections, canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
 local roomRemote = ReplicatedStorage:WaitForChild("MatchRoomControl")
 table.insert(connections, roomRemote.OnClientEvent:Connect(function(action, snapshot)
  if action == "Snapshot" then
   raceBoard.update(snapshot)
   roomOwned = snapshot.room ~= nil
   if snapshot.visible and snapshot.trackId then GuidanceState.confirmed(state, snapshot.trackId) end
  end
  update()
 end))
 local function watchRooms(child)
  if child.Name == "KDMMatchRooms" then
   table.insert(connections, child:GetPropertyChangedSignal("Enabled"):Connect(update))
   update()
  end
 end
 for _, child in gui.Parent:GetChildren() do watchRooms(child) end
 table.insert(connections, gui.Parent.ChildAdded:Connect(watchRooms))
 local display = nil
 local catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartCatalog"))
 local factory = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartVisualFactory"))
 local function refreshDisplay()
  if display then display:Destroy();display=nil end
  local anchors=hub:FindFirstChild("Anchors")
  local anchor=anchors and anchors:FindFirstChild("MyKartDisplayAnchor")
  if not anchor or player:GetAttribute("RaceState") ~= "GARAGE" or player:GetAttribute("LobbyDriveActive") == true then return end
  local id=player:GetAttribute("SelectedKartId") or catalog.DefaultId
  local definition=catalog.Entries[id] or catalog.Entries[catalog.DefaultId]
  -- Seven local static visuals reuse the approved catalog/factory. A selected
  -- V2 occupies the hero bay; Sprint selection is preserved with Cyan as exhibit.
  local showroom=Instance.new("Model");showroom.Name="KDMClientShowroom"
  local heroId=if definition.VisualModelName=="KDMV2" then definition.Id else "Kart05"
  local ids={heroId}
  for _,candidate in catalog.Order do
   if candidate~=heroId and catalog.Entries[candidate].VisualModelName=="KDMV2" then table.insert(ids,candidate) end
  end
  local bays={{0,904},{-30,885},{30,885},{-30,901},{30,901},{-30,917},{30,917}}
  local ok,result=pcall(function()
   for index,kartId in ids do
    local bay=Instance.new("Model");bay.Name="ShowroomBay"..index;bay.Parent=showroom
    local location=bays[index]
    local offset=CFrame.new(location[1],0,location[2]-904)
    -- Spawn camera faces +Z: positive X bays are screen-left.
    -- Factory front wheels/nose face +X here; only these three face out.
    local frame=offset*anchor.CFrame*(if location[1]>0 then CFrame.Angles(0,math.pi,0) else CFrame.identity)
    local kart=HubUiController.createDisplay(bay,{CFrame=frame},catalog.Entries[kartId],factory,player:GetAttribute('KDMWingEquipped')==true)
    kart:SetAttribute("ShowroomStatic",true)
    do
     local drive=Instance.new("Part");drive.Name="LobbyDisplayDrivePoint";drive.Size=Vector3.one;drive.Transparency=1;drive.Anchored=true;drive.CanCollide=false;drive.CanTouch=false;drive.CanQuery=false
     drive.CFrame=frame*CFrame.new(0,2,0);drive:SetAttribute("ShowroomKartId",kartId);drive.Parent=kart
     local prompt=Instance.new("ProximityPrompt");prompt.Name="LobbyDisplayTestDrive";prompt.ActionText="TEST DRIVE";prompt.ObjectText=catalog.Entries[kartId].DisplayName;prompt.RequiresLineOfSight=false;prompt.MaxActivationDistance=8;prompt.Parent=drive
    end
   end
   return showroom
  end)
  if ok then showroom.Parent=hub;display=result
  else showroom:Destroy();warn("[Hub] Showroom unavailable: "..tostring(result)) end
 end
 table.insert(connections,player:GetAttributeChangedSignal("SelectedKartId"):Connect(refreshDisplay))
 table.insert(connections,player:GetAttributeChangedSignal('KDMWingEquipped'):Connect(refreshDisplay))
 table.insert(connections,player:GetAttributeChangedSignal("RaceState"):Connect(refreshDisplay))
 table.insert(connections,player.CharacterAdded:Connect(refreshDisplay))
 table.insert(connections,player:GetAttributeChangedSignal("LobbyDriveActive"):Connect(refreshDisplay))
 refreshDisplay()
 local entryKiosk=HubUiController.createTestDriveKiosk(hub)
 for _, attribute in {"RaceState", "HubOverlayOpen", "KDMProfileOpen", "KDMShopOpen", "KDMRoutePending", "LobbyDriveActive",
  "KartProfileLoadCompleted","KartProfileLoadResult","KartRestorationConfirmed","KartRestoredKartId","KartSaveState","SelectedKartId"} do
  table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(update))
 end
 table.insert(connections, ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
  if triggeringPlayer ~= player or player:GetAttribute("RaceState") ~= "GARAGE" then return end
  if not prompt:IsDescendantOf(hub.Stations) then return end
  local station = prompt.Parent
  local action = station:GetAttribute("HubAction")
  if action == "GARAGE" or action == "TRACKS" or action == "RACE" then open(action) end
 end))
 gui.Destroying:Connect(function()
  for _, connection in connections do connection:Disconnect() end
  guidance.destroy()
  worldGuidance.destroy()
  if entryKiosk then entryKiosk:Destroy() end
  disconnectNavigation()
  if display then display:Destroy();display=nil end
  started = false
  for prompt, enabled in promptEnabled do if prompt.Parent then prompt.Enabled = enabled end end
 end)
 update()
end

return HubUiController
