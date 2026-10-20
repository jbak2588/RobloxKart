-- Client-only pit-lane signs, positioned from the existing spawn/prompt anchors.
local Players = game:GetService("Players")
local View = {}
function View.create(hub, theme)
 local anchors, spawn = hub:FindFirstChild("Anchors") or hub:FindFirstChild("Stations"), hub:FindFirstChild("HubSpawn")
 local entries = {}
 if not anchors or not spawn then return {update=function() end, destroy=function() end} end
 local folder = Instance.new("Folder")
 folder.Name, folder.Parent = "KDMClientWorldGuidance", hub
 if anchors and spawn then
  for index, definition in {{"GARAGE", "GaragePromptAnchor", "GarageStation"}, {"RACE", "RacePromptAnchor", "RaceStation"}, {"TRACKS", "TracksPromptAnchor", "TrackStation"}} do
   local target = anchors:FindFirstChild(definition[2]) or anchors:FindFirstChild(definition[3])
   if target then
    local center = spawn.CFrame * Vector3.new((index-2)*10, -.46, if index==2 then 1 else -7)
    local toward = Vector3.new(target.CFrame.Position.X, center.Y, target.CFrame.Position.Z)
    local plate = Instance.new("Part")
    plate.Name, plate.Size = definition[1], Vector3.new(5, .04, 8)
    -- Top-face canvas axes differ from a front sign. Keep nouns readable from
    -- the arrival camera; rotate only the direction arrow toward its anchor.
    plate.CFrame = CFrame.new(center) * spawn.CFrame.Rotation * CFrame.Angles(0,-math.pi/2,0)
    plate.Anchored, plate.CanCollide, plate.CanTouch, plate.CanQuery = true, false, false, false
    plate.CastShadow, plate.Material, plate.Color = false, Enum.Material.SmoothPlastic, theme.Panel
    plate.Parent = folder
    local surface = Instance.new("SurfaceGui")
    surface.Name, surface.Face, surface.CanvasSize = "Direction", Enum.NormalId.Top, Vector2.new(480,300)
    surface.LightInfluence, surface.AlwaysOnTop, surface.Parent = 0, false, plate
    local stroke = Instance.new("Frame")
    stroke.Size, stroke.BackgroundTransparency = UDim2.fromScale(1,1), 1
    stroke.Parent = surface
    local outline = Instance.new("UIStroke")
    outline.Color, outline.Thickness, outline.Parent = theme.TextSecondary, 3, stroke
    local text = Instance.new("TextLabel")
    text.Size, text.Position, text.BackgroundTransparency, text.AutoLocalize = UDim2.fromScale(1,.45), UDim2.fromScale(0,.55), 1, true
    text.Text, text.Font, text.TextSize = definition[1], Enum.Font.GothamBold, 68
    text.TextColor3, text.Parent = theme.TextPrimary, stroke
    local arrow = text:Clone()
    arrow.Name, arrow.Text, arrow.Size, arrow.Position = "Arrow", "↑", UDim2.fromScale(.4,.5), UDim2.fromScale(.3,.03)
    arrow.TextSize=130
    local localDirection=spawn.CFrame:VectorToObjectSpace(toward-center)
    arrow.Rotation=math.deg(math.atan2(localDirection.X,-localDirection.Z))
    arrow.Parent=stroke
    entries[definition[1]] = {plate=plate, surface=surface, text=text, arrow=arrow, outline=outline}
   end
  end
 end

 local function isAnyModalOpen()
  local player = Players.LocalPlayer
  if not player then return false end
  if player:GetAttribute("HubOverlayOpen") == true or player:GetAttribute("KDMProfileOpen") == true or player:GetAttribute("KDMShopOpen") == true then
   return true
  end
  local pgui = player:FindFirstChild("PlayerGui")
  if not pgui then return false end
  local econ = pgui:FindFirstChild("KDMEconomyUi") or pgui:FindFirstChild("KDMGarageShop")
  if econ and econ.Enabled then
   local shopModal = econ:FindFirstChild("ShopModal", true) or econ:FindFirstChild("Shop", true)
   if shopModal and shopModal.Visible then return true end
  end
  local rooms = pgui:FindFirstChild("RobloxKartMatchRooms") or pgui:FindFirstChild("KDMMatchRooms")
  if rooms and rooms.Enabled then
   local overlay = rooms:FindFirstChild("Overlay", true) or rooms:FindFirstChild("Backdrop", true)
   if overlay and overlay.Visible then return true end
  end
  local create = pgui:FindFirstChild("KDMLobbyCreate")
  if create and create.Enabled then
   local overlay = create:FindFirstChild("Overlay", true) or create:FindFirstChild("CreateLobbyModal", true)
   if overlay and overlay.Visible then return true end
  end
  local records = pgui:FindFirstChild("KDMPersonalRecords") or pgui:FindFirstChild("KDMCanaryPersonalRecords")
  if records and records.Enabled then
   local overlay = records:FindFirstChild("Overlay", true) or records:FindFirstChild("SavedRecords", true)
   if overlay and overlay.Visible then return true end
  end
  return false
 end

 local function setKioskMarkersVisible(show)
  for _, desc in hub:GetDescendants() do
   if desc:IsA("BillboardGui") or (desc:IsA("SurfaceGui") and desc.Name ~= "Direction") then
    local owner=desc.Parent
    local navigationMarker=false
    while owner and owner~=hub do
     if owner.Name=='GarageStationKiosk' or owner.Name=='RaceStationKiosk' or owner.Name=='TrackStationKiosk' then
      navigationMarker=desc:IsA('BillboardGui');break
     end
     owner=owner.Parent
    end
    -- Floating navigation titles duplicate the edge buttons. Native nearby
    -- prompts and their contextual explanation now own kiosk guidance.
    desc.Enabled = show and not navigationMarker
   end
  end
 end

 local view = {}
 function view.update(visible, active)
  local modalOpen = isAnyModalOpen()
  local effectiveVisible = visible and not modalOpen
  setKioskMarkersVisible(effectiveVisible)
  for destination, entry in entries do
   entry.plate.Transparency = if effectiveVisible then .12 else 1
   entry.surface.Enabled = effectiveVisible
   entry.outline.Color = if destination == active then theme.Selection else theme.TextSecondary
   entry.text.TextColor3 = if destination == active then theme.PrimaryAction else theme.TextPrimary
   entry.arrow.TextColor3 = entry.text.TextColor3
  end
 end
 function view.destroy() folder:Destroy() end
 return view
end
return View
