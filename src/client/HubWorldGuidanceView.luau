-- Client-only pit-lane signs, positioned from the existing spawn/prompt anchors.
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
    outline.Color, outline.Thickness, outline.Parent = theme.Selection, 3, stroke
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
    entries[definition[1]] = {plate=plate, surface=surface, text=text, arrow=arrow}
   end
  end
 end
 local view = {}
 function view.update(visible, active)
  for destination, entry in entries do
   entry.plate.Transparency = if visible then .12 else 1
   entry.surface.Enabled = visible
   entry.text.TextColor3 = if destination == active then theme.PrimaryAction else theme.TextPrimary
   entry.arrow.TextColor3 = entry.text.TextColor3
  end
 end
 function view.destroy() folder:Destroy() end
 return view
end
return View
