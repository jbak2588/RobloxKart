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
local HubUiController = {}
local started = false

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
 local canvas = Instance.new("Frame")
 canvas.Name, canvas.Size, canvas.BackgroundTransparency = "SafeCanvas", UDim2.fromScale(1,1), 1
 canvas.Active, canvas.Parent = false, gui
 local guidance = GuidanceView.create(canvas, Theme, function() open(GuidanceState.nextAction(state)) end)
 local worldGuidance = WorldGuidance.create(hub, Theme)
 local panel = Instance.new("Frame")
 panel.Name = "Shortcuts"
 panel.AnchorPoint, panel.Position = Vector2.new(1,1), UDim2.new(1,-12,1,-12)
 panel.Size, panel.BackgroundColor3, panel.BorderSizePixel = UDim2.fromOffset(150,152), Theme.Panel, 0
 panel.Parent = gui
 for index, action in {"GARAGE", "TRACKS", "SHOP"} do
  local button = Instance.new("TextButton")
  button.Name, button.Text = action, action
  button.Size, button.Position = UDim2.new(1,-12,0,44), UDim2.fromOffset(6,6+(index-1)*48)
  button.BackgroundColor3 = if action=='GARAGE' then Color3.fromRGB(36,138,242) elseif action=='TRACKS' then Color3.fromRGB(246,112,42) else Color3.fromRGB(42,198,102)
  button.TextColor3 = Color3.fromRGB(255,255,255)
  button.Font, button.TextSize, button.BorderSizePixel = Enum.Font.GothamBold, 13, 0
  button.Parent = panel
  local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,6);corner.Parent=button
  button.Text=''
  local caption=Instance.new('TextLabel');caption.Name='NavigationLabel';caption.Text=action;caption.BackgroundTransparency=1;caption.Position=UDim2.fromOffset(22,0);caption.Size=UDim2.new(1,-26,1,0);caption.Font=Enum.Font.GothamBold;caption.TextSize=13;caption.TextColor3=Color3.fromRGB(255,255,255);caption.TextStrokeTransparency=0.35;caption.Parent=button
  local mark=Instance.new('Frame');mark.Name='NavigationIcon';mark.Size=UDim2.fromOffset(12,14);mark.Position=UDim2.new(0,5,.5,-7);mark.BackgroundTransparency=1;mark.Parent=button
  local function piece(x,y,w,h,color)
   local f=Instance.new('Frame');f.Size=UDim2.fromOffset(w,h);f.Position=UDim2.fromOffset(x,y);f.BackgroundColor3=color;f.BorderSizePixel=0;f.Parent=mark
  end
  local ink=Color3.fromRGB(240,245,252)
  if action=='GARAGE' then
   piece(3,2,6,10,ink);for _,x in {0,10}do piece(x,2,2,4,ink);piece(x,9,2,4,ink)end
  elseif action=='TRACKS' then
   piece(0,1,2,13,ink);for x=0,2 do for y=0,1 do if (x+y)%2==0 then piece(3+x*3,1+y*4,3,4,ink)end end end
  else
   piece(1,5,11,9,ink);piece(3,1,2,5,ink);piece(8,1,2,5,ink);piece(3,0,7,2,ink)
  end
  local stroke = Instance.new("UIStroke")
  stroke.Color, stroke.Thickness, stroke.ApplyStrokeMode, stroke.Parent = Color3.fromRGB(0,220,255), 2, Enum.ApplyStrokeMode.Border, button
  table.insert(connections, button.Activated:Connect(function() open(action) end))
 end
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
  if driving then presentation.visible = false end
  local driveLayout=LobbyLayout.shortcuts(canvas.AbsoluteSize,MobileView)
  panel.AnchorPoint = if driving then Vector2.zero else Vector2.new(1,1)
  panel.Position = if driving then UDim2.fromOffset(driveLayout.x,driveLayout.y) else UDim2.new(1,-12,1,-12)
  panel.Size = if driving then UDim2.fromOffset(driveLayout.width,driveLayout.height) else UDim2.fromOffset(150,152)
  for index, name in {"GARAGE","TRACKS","SHOP"} do
   local button = panel[name]
   button.Visible=name~='SHOP' or not driving
   button.Size = if driving then UDim2.new(1,-12,0,34) else UDim2.new(1,-12,0,44)
   button.Position = if driving then UDim2.fromOffset(6,4+(index-1)*38) else UDim2.fromOffset(6,6+(index-1)*48)
  end
  local compactShortcuts=canvas.AbsoluteSize.Y<440
  if not driving then
   local width=math.min(300,canvas.AbsoluteSize.X-24)
   panel.Size=if compactShortcuts then UDim2.fromOffset(width,56) else UDim2.fromOffset(150,152)
   for index,name in {'GARAGE','TRACKS','SHOP'}do
    if compactShortcuts then panel[name].Size=UDim2.fromOffset((width-24)/3,44);panel[name].Position=UDim2.fromOffset(6+(index-1)*(width-6)/3,6)end
   end
   presentation.bottom=if compactShortcuts then 76 else 172
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
    local frame=offset*anchor.CFrame
    local kart=HubUiController.createDisplay(bay,{CFrame=frame},catalog.Entries[kartId],factory,player:GetAttribute('KDMWingEquipped')==true)
    kart:SetAttribute("ShowroomStatic",true)
    local point=Instance.new("Part");point.Name="ShowroomColorLabel";point.Size=Vector3.one;point.Transparency=1;point.Anchored=true;point.CanCollide=false;point.CanTouch=false;point.CanQuery=false
    point.CFrame=frame*CFrame.new(0,4,0);point.Parent=bay
    local sign=Instance.new("BillboardGui");sign.Name="ColorLabel";sign.Size=UDim2.fromOffset(140,24);sign.MaxDistance=65;sign.AlwaysOnTop=false;sign.Parent=point
    local label=Instance.new("TextLabel");label.Size=UDim2.fromScale(1,1);label.BackgroundColor3=Theme.Panel;label.BackgroundTransparency=.2;label.TextColor3=Theme.TextPrimary;label.Font=Enum.Font.GothamBold;label.TextSize=13
    label.Text=catalog.Entries[kartId].DisplayColorName..(if kartId==id then "  ✓" else "");label.Parent=sign
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
  disconnectNavigation()
  if display then display:Destroy();display=nil end
  started = false
  for prompt, enabled in promptEnabled do if prompt.Parent then prompt.Enabled = enabled end end
 end)
 update()
end

return HubUiController
