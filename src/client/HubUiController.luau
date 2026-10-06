local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Garage = require(script.Parent:WaitForChild("GarageUiController"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KDMUiTheme"))
local HubUiController = {}
local started = false

-- Visual-only client ownership. Each client calls this with its own selection/parent.
function HubUiController.createDisplay(parent, anchor, definition, factory)
 local visual = factory.createVisual(definition)
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
 local panel = Instance.new("Frame")
 panel.Name = "Shortcuts"
 panel.AnchorPoint, panel.Position = Vector2.new(1,1), UDim2.new(1,-12,1,-12)
 panel.Size, panel.BackgroundColor3, panel.BorderSizePixel = UDim2.fromOffset(150,104), Theme.Panel, 0
 panel.Parent = gui
 for index, action in {"GARAGE", "TRACKS"} do
  local button = Instance.new("TextButton")
  button.Name, button.Text = action, action
  button.Size, button.Position = UDim2.new(1,-12,0,44), UDim2.fromOffset(6,6+(index-1)*48)
  button.BackgroundColor3 = if action == "TRACKS" then Theme.PrimaryAction else Theme.Background
  button.TextColor3 = if action == "TRACKS" then Theme.Background else Theme.TextPrimary
  button.Font, button.TextSize, button.BorderSizePixel = Enum.Font.GothamBold, 16, 0
  button.Parent = panel
  local stroke = Instance.new("UIStroke")
  stroke.Color, stroke.ApplyStrokeMode, stroke.Parent = Theme.Selection, Enum.ApplyStrokeMode.Border, button
  button.Activated:Connect(function() Garage.open(action) end)
 end
 local function update()
  gui.Enabled = player:GetAttribute("RaceState") == "GARAGE"
   and player:GetAttribute("HubOverlayOpen") ~= true
   and player:GetAttribute("KDMRoutePending") ~= "RACE_LAUNCH"
 end
 local connections = {}
 local display = nil
 local catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartCatalog"))
 local factory = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartVisualFactory"))
 local function refreshDisplay()
  if display then display:Destroy();display=nil end
  local anchors=hub:FindFirstChild("Anchors")
  local anchor=anchors and anchors:FindFirstChild("MyKartDisplayAnchor")
  if not anchor or player:GetAttribute("RaceState") ~= "GARAGE" then return end
  local id=player:GetAttribute("SelectedKartId") or catalog.DefaultId
  local definition=catalog.Entries[id] or catalog.Entries[catalog.DefaultId]
  local ok,result=pcall(HubUiController.createDisplay,hub,anchor,definition,factory)
  if ok then display=result else warn("[Hub] My Kart display unavailable: "..tostring(result)) end
 end
 table.insert(connections,player:GetAttributeChangedSignal("SelectedKartId"):Connect(refreshDisplay))
 table.insert(connections,player:GetAttributeChangedSignal("RaceState"):Connect(refreshDisplay))
 table.insert(connections,player.CharacterAdded:Connect(refreshDisplay))
 refreshDisplay()
 for _, attribute in {"RaceState", "HubOverlayOpen", "KDMRoutePending"} do
  table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(update))
 end
 table.insert(connections, ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
  if triggeringPlayer ~= player or player:GetAttribute("RaceState") ~= "GARAGE" then return end
  if not prompt:IsDescendantOf(hub.Stations) then return end
  local station = prompt.Parent
  local action = station:GetAttribute("HubAction")
  if action == "GARAGE" or action == "TRACKS" or action == "RACE" then Garage.open(action) end
 end))
 gui.Destroying:Connect(function() for _, connection in connections do connection:Disconnect() end; if display then display:Destroy();display=nil end end)
 update()
end

return HubUiController
