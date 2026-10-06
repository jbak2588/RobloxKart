local HubGuidanceView = {}

function HubGuidanceView.create(parent, theme, onTrack)
 local card = Instance.new("Frame")
 card.Name, card.BackgroundColor3, card.BorderSizePixel = "NextAction", theme.Panel, 0
 card.Active, card.AnchorPoint = false, Vector2.new(1, 1)
 card.Parent = parent
 local corner = Instance.new("UICorner")
 corner.CornerRadius, corner.Parent = UDim.new(0, 8), card
 local function label(name, y, height, size, color)
  local text = Instance.new("TextLabel")
  text.Name, text.BackgroundTransparency, text.AutoLocalize = name, 1, true
  text.Position, text.Size = UDim2.fromOffset(12, y), UDim2.new(1, -24, 0, height)
  text.TextSize, text.Font, text.TextColor3 = size, Enum.Font.GothamMedium, color
  text.TextWrapped, text.TextXAlignment = true, Enum.TextXAlignment.Left
  text.Parent = card
  return text
 end
 local title = label("Heading", 6, 20, 16, theme.TextPrimary)
 title.Font = Enum.Font.GothamBold
 local message = label("Message", 28, 36, 16, theme.TextPrimary)
 local helper = label("Helper", 116, 28, 14, theme.TextSecondary)
 helper.Text = "You can use the default kart"
 local button = Instance.new("TextButton")
 button.Name, button.Text, button.AutoLocalize = "SelectTrack", "SELECT TRACK", true
 button.Size, button.BackgroundColor3 = UDim2.new(1, -24, 0, 44), theme.PrimaryAction
 button.TextColor3, button.TextSize, button.Font = theme.Background, 16, Enum.Font.GothamBold
 button.BorderSizePixel, button.Parent = 0, card
 local connection = button.Activated:Connect(onTrack)
 local view = { card = card, button = button }
 function view.update(presentation)
  card.Visible = presentation.visible
  card.Position = UDim2.new(1, -12, 1, -presentation.bottom)
  card.Size = UDim2.fromOffset(presentation.width, presentation.height)
  title.Text, message.Text = presentation.heading, presentation.message
  button.Text = presentation.button
  message.Visible, helper.Visible = not presentation.compact, not presentation.compact
  button.Position = UDim2.fromOffset(12, if presentation.compact then 26 else 68)
 end
 function view.destroy() connection:Disconnect(); card:Destroy() end
 return view
end

return HubGuidanceView
