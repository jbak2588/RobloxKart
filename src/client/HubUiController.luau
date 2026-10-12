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
   or node:IsA("Sound") or node:IsA("BodyMover") or node:IsA("ProximityPrompt") then node:Destroy() end
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
  if roomOwned or player:GetAttribute("HubOverlayOpen") == true or player:GetAttribute('KDMProfileOpen')==true or (rooms and rooms.Enabled) then return end
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
 panel.Size, panel.BackgroundColor3, panel.BorderSizePixel = UDim2.fromOffset(150,104), Theme.Panel, 0
 panel.Parent = gui
 for index, action in {"GARAGE", "TRACKS"} do
  local button = Instance.new("TextButton")
  button.Name, button.Text = action, action
  button.Size, button.Position = UDim2.new(1,-12,0,44), UDim2.fromOffset(6,6+(index-1)*48)
  button.BackgroundColor3 = Theme.Panel
  button.TextColor3 = Theme.TextPrimary
  button.Font, button.TextSize, button.BorderSizePixel = Enum.Font.GothamBold, 16, 0
  button.Parent = panel
  local stroke = Instance.new("UIStroke")
  stroke.Color, stroke.ApplyStrokeMode, stroke.Parent = Theme.TextSecondary, Enum.ApplyStrokeMode.Border, button
  table.insert(connections, button.Activated:Connect(function() open(action) end))
 end
 local promptEnabled = {}
 for _, prompt in hub.Stations:GetDescendants() do
  if prompt:IsA("ProximityPrompt") then promptEnabled[prompt] = prompt.Enabled end
 end
 local function update()
  local overlay = player:GetAttribute("HubOverlayOpen") == true or player:GetAttribute('KDMProfileOpen')==true
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
   and player:GetAttribute("HubOverlayOpen") ~= true and player:GetAttribute('KDMProfileOpen')~=true
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
  panel.Size = if driving then UDim2.fromOffset(driveLayout.width,driveLayout.height) else UDim2.fromOffset(150,104)
  for index, name in {"GARAGE","TRACKS"} do
   local button = panel[name]
   button.Size = if driving then UDim2.new(1,-12,0,34) else UDim2.new(1,-12,0,44)
   button.Position = if driving then UDim2.fromOffset(6,4+(index-1)*38) else UDim2.fromOffset(6,6+(index-1)*48)
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
  local ok,result=pcall(HubUiController.createDisplay,hub,anchor,definition,factory,player:GetAttribute('KDMWingEquipped')==true)
  if ok then
   display=result
   local point=Instance.new("Part");point.Name="LobbyDisplayDrivePoint";point.Size=Vector3.one;point.Transparency=1;point.Anchored=true;point.CanCollide=false;point.CanTouch=false;point.CanQuery=false
   point.CFrame=anchor.CFrame*CFrame.new(0,2,0);point.Parent=display
   local prompt=Instance.new("ProximityPrompt");prompt.Name="LobbyDisplayTestDrive";prompt.ActionText="TEST DRIVE";prompt.ObjectText="";prompt.RequiresLineOfSight=false;prompt.MaxActivationDistance=8;prompt.Parent=point
  else warn("[Hub] My Kart display unavailable: "..tostring(result)) end
 end
 table.insert(connections,player:GetAttributeChangedSignal("SelectedKartId"):Connect(refreshDisplay))
 table.insert(connections,player:GetAttributeChangedSignal('KDMWingEquipped'):Connect(refreshDisplay))
 table.insert(connections,player:GetAttributeChangedSignal("RaceState"):Connect(refreshDisplay))
 table.insert(connections,player.CharacterAdded:Connect(refreshDisplay))
 table.insert(connections,player:GetAttributeChangedSignal("LobbyDriveActive"):Connect(refreshDisplay))
 refreshDisplay()
 for _, attribute in {"RaceState", "HubOverlayOpen", "KDMProfileOpen", "KDMRoutePending", "LobbyDriveActive",
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
