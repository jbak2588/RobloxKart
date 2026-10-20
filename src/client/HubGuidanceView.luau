local HubGuidanceView = {}

function HubGuidanceView.create(parent, theme, onRaceNow, onTestDrive)
 local card = Instance.new("Frame")
 card.Name = "NextAction"
 card.BackgroundColor3 = Color3.fromRGB(14, 22, 35)
 card.BackgroundTransparency = 0.35
 card.BorderSizePixel = 0
 card.Active, card.AnchorPoint = false, Vector2.new(1, 1)
 card.Parent = parent

 local corner = Instance.new("UICorner")
 corner.CornerRadius, corner.Parent = UDim.new(0, 10), card

 local cardStroke = Instance.new("UIStroke")
 cardStroke.Name = "CardStroke"
 cardStroke.Color = Color3.fromRGB(40, 60, 90)
 cardStroke.Thickness = 1
 cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
 cardStroke.Parent = card

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
 button.BackgroundTransparency = 0.25
 button.TextColor3, button.TextSize, button.Font = Color3.fromRGB(255, 215, 50), 15, Enum.Font.GothamBold
 button.BorderSizePixel, button.Parent = 0, card
 button.TextStrokeTransparency = 1
 local buttonCorner = Instance.new("UICorner"); buttonCorner.CornerRadius = UDim.new(0, 8); buttonCorner.Parent = button
 local buttonStroke = Instance.new("UIStroke")
 buttonStroke.Name = "ButtonStroke"; buttonStroke.Color = Color3.fromRGB(70, 95, 135); buttonStroke.Thickness = 1
 buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; buttonStroke.Parent = button

 local raceNowHelper = label("RaceNowHelper", 108, 14, 11, Color3.fromRGB(150, 175, 200), Enum.Font.Gotham)
 raceNowHelper.Text = "Join a race or start one automatically"

 -- Secondary CTA: TEST DRIVE
 local testDriveBtn = Instance.new("TextButton")
 testDriveBtn.Name, testDriveBtn.Text, testDriveBtn.AutoLocalize = "FreeTestDrive", "TEST DRIVE", true
 testDriveBtn.Size = UDim2.new(1, -24, 0, 40)
 testDriveBtn.BackgroundColor3 = Color3.fromRGB(20, 32, 48)
 testDriveBtn.BackgroundTransparency = 0.35
 testDriveBtn.TextColor3, testDriveBtn.TextSize, testDriveBtn.Font = Color3.fromRGB(111, 211, 245), 14, Enum.Font.GothamBold
 testDriveBtn.BorderSizePixel, testDriveBtn.Parent = 0, card
 testDriveBtn.TextStrokeTransparency = 1
 local testCorner = Instance.new("UICorner"); testCorner.CornerRadius = UDim.new(0, 8); testCorner.Parent = testDriveBtn
 local testStroke = Instance.new("UIStroke")
 testStroke.Name = "TestStroke"; testStroke.Color = Color3.fromRGB(45, 68, 98); testStroke.Thickness = 1
 testStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; testStroke.Parent = testDriveBtn

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

  local isCompact = presentation.compact == true or presentation.height < 150
  if isCompact then
   brand.Visible = false
   title.Position = UDim2.fromOffset(12, 4)
   title.Size = UDim2.new(1, -24, 0, 20)
   title.TextSize = 13
   message.Visible = false
   raceNowHelper.Visible = false
   testDriveHelper.Visible = false
   helper.Visible = false

   local btnWidth = math.max(60, math.floor((presentation.width - 32) * 0.5))
   button.Position = UDim2.fromOffset(12, 26)
   button.Size = UDim2.fromOffset(btnWidth, 44)
   button.TextSize = 14
   button.Font = Enum.Font.GothamBold
   button.TextColor3 = Color3.fromRGB(255, 215, 50)
   button.TextStrokeTransparency = 1

   testDriveBtn.Position = UDim2.fromOffset(12 + btnWidth + 8, 26)
   testDriveBtn.Size = UDim2.fromOffset(btnWidth, 44)
   testDriveBtn.TextSize = 13
   testDriveBtn.Font = Enum.Font.GothamBold
   testDriveBtn.TextColor3 = Color3.fromRGB(111, 211, 245)
   testDriveBtn.TextStrokeTransparency = 1
   testDriveBtn.Visible = true
  else
   brand.Visible = true
   brand.Position = UDim2.fromOffset(12, 6)
   brand.Size = UDim2.new(1, -24, 0, 14)

   title.Position = UDim2.fromOffset(12, 20)
   title.Size = UDim2.new(1, -24, 0, 22)
   title.TextSize = 16

   message.Visible = true
   message.Position = UDim2.fromOffset(12, 42)
   message.Size = UDim2.new(1, -24, 0, 18)
   message.TextSize = 12

   button.Position = UDim2.fromOffset(12, 64)
   button.Size = UDim2.new(1, -24, 0, 42)
   button.TextSize = 15
   button.Font = Enum.Font.GothamBold
   button.TextColor3 = Color3.fromRGB(255, 215, 50)
   button.TextStrokeTransparency = 1

   raceNowHelper.Visible = true
   raceNowHelper.Position = UDim2.fromOffset(12, 108)
   raceNowHelper.Size = UDim2.new(1, -24, 0, 14)

   testDriveBtn.Visible = true
   testDriveBtn.Position = UDim2.fromOffset(12, 124)
   testDriveBtn.Size = UDim2.new(1, -24, 0, 38)
   testDriveBtn.TextSize = 14
   testDriveBtn.Font = Enum.Font.GothamBold
   testDriveBtn.TextColor3 = Color3.fromRGB(111, 211, 245)
   testDriveBtn.TextStrokeTransparency = 1

   testDriveHelper.Visible = true
   testDriveHelper.Position = UDim2.fromOffset(12, 164)
   testDriveHelper.Size = UDim2.new(1, -24, 0, 14)

   helper.Visible = false
  end
 end
 function view.destroy()
  connection:Disconnect()
  driveConnection:Disconnect()
  card:Destroy()
 end
 return view
end

return HubGuidanceView
