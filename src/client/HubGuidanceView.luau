local HubGuidanceView = {}

function HubGuidanceView.create(parent, theme, onRaceNow, onTestDrive)
 local card = Instance.new("Frame")
 card.Name = "NextAction"
 card.BackgroundColor3 = Color3.fromRGB(14, 22, 35)
 card.BackgroundTransparency = 1
 card.BorderSizePixel = 0
 card.Active, card.AnchorPoint = false, Vector2.new(1, 1)
 card.Parent = parent

 local corner = Instance.new("UICorner")
 corner.CornerRadius, corner.Parent = UDim.new(0, 10), card

 local function label(name, y, height, size, color, font)
  local text = Instance.new("TextLabel")
  text.Name, text.BackgroundTransparency, text.AutoLocalize = name, 1, true
  text.Position, text.Size = UDim2.fromOffset(12, y), UDim2.new(1, -24, 0, height)
  text.TextSize, text.Font, text.TextColor3 = size, font or Enum.Font.GothamMedium, color
  text.TextWrapped, text.TextXAlignment = true, Enum.TextXAlignment.Left
  text.TextStrokeTransparency = 1
  text.Parent = card
  return text
 end

 local brand = label("Brand", 6, 14, 11, Color3.fromRGB(255, 215, 50), Enum.Font.GothamBold)
 brand.Text = "KART DRIFT MASTERS"

 local title = label("Heading", 20, 22, 16, Color3.fromRGB(240, 245, 252), Enum.Font.GothamBold)
 local message = label("Message", 44, 18, 12, Color3.fromRGB(160, 185, 210), Enum.Font.GothamMedium)
 local helper = label("Helper", 162, 14, 11, Color3.fromRGB(140, 165, 190), Enum.Font.Gotham)
 helper.Text = "You can use the default kart"
 helper.Visible = false

 -- Primary CTA: RACE NOW (SelectTrack name preserved for test compatibility)
 local button = Instance.new("TextButton")
 button.Name, button.Text, button.AutoLocalize = "SelectTrack", "RACE NOW", true
 button.Size = UDim2.new(1, -24, 0, 44)
 button.BackgroundColor3 = Color3.fromRGB(28, 40, 58)
 button.BackgroundTransparency = .58
 button.TextColor3, button.TextSize, button.Font = Color3.fromRGB(255, 215, 50), 15, Enum.Font.GothamBold
 button.BorderSizePixel, button.Parent = 0, card
 button.TextStrokeTransparency = 1
 local buttonCorner = Instance.new("UICorner"); buttonCorner.CornerRadius = UDim.new(0, 8); buttonCorner.Parent = button
 local raceNowHelper = label("RaceNowHelper", 108, 14, 11, Color3.fromRGB(150, 175, 200), Enum.Font.Gotham)
 raceNowHelper.Text = "Join a race or start one automatically"

 -- Secondary CTA: TEST DRIVE
 local testDriveBtn = Instance.new("TextButton")
 testDriveBtn.Name, testDriveBtn.Text, testDriveBtn.AutoLocalize = "FreeTestDrive", "TEST DRIVE", true
 testDriveBtn.Size = UDim2.new(1, -24, 0, 40)
 testDriveBtn.BackgroundColor3 = Color3.fromRGB(20, 32, 48)
 testDriveBtn.BackgroundTransparency = .58
 testDriveBtn.TextColor3, testDriveBtn.TextSize, testDriveBtn.Font = Color3.fromRGB(111, 211, 245), 14, Enum.Font.GothamBold
 testDriveBtn.BorderSizePixel, testDriveBtn.Parent = 0, card
 testDriveBtn.TextStrokeTransparency = 1
 local testCorner = Instance.new("UICorner"); testCorner.CornerRadius = UDim.new(0, 8); testCorner.Parent = testDriveBtn
 local testDriveHelper = label("TestDriveHelper", 164, 14, 11, Color3.fromRGB(150, 175, 200), Enum.Font.Gotham)
 testDriveHelper.Text = "Learn drifting and try race items"

 local connection = button.Activated:Connect(function()
  if onRaceNow then onRaceNow() end
 end)
 local driveConnection = testDriveBtn.Activated:Connect(function()
  if onTestDrive then onTestDrive() end
 end)

 local view = { card = card, button = button, testDriveButton = testDriveBtn }
 function view.update(presentation)
  card.Visible = presentation.visible
  card.Position = UDim2.new(1, -12, 1, -presentation.bottom)
  card.Size = UDim2.fromOffset(presentation.width, presentation.height)
  title.Text = presentation.heading or "YOUR KART IS READY!"
  message.Text = presentation.message or "Race against real players or a rookie bot."
  button.Text = presentation.button or "RACE NOW"
  testDriveBtn.Text = presentation.secondaryButton or "TEST DRIVE"
  button.TextStrokeTransparency = 1
  testDriveBtn.TextStrokeTransparency = 1

  -- Two quiet text actions at every viewport size; no arrival heading/card.
  for _, text in {brand, title, message, helper, raceNowHelper, testDriveHelper} do
   text.Visible = false
  end
  button.Position = UDim2.fromOffset(12, 4)
  button.Size = UDim2.new(1, -24, 0, 44)
  button.TextSize = if presentation.desktop then 20 else 16
  testDriveBtn.Position = UDim2.fromOffset(12, 60)
  testDriveBtn.Size = UDim2.new(1, -24, 0, 44)
  testDriveBtn.TextSize = if presentation.desktop then 18 else 16
  testDriveBtn.Visible = true
 end
 function view.destroy()
  connection:Disconnect()
  driveConnection:Disconnect()
  card:Destroy()
 end
 return view
end

return HubGuidanceView
