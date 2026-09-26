local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RaceItemUiController = {}
local started = false

function RaceItemUiController.start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "RobloxKartRaceItemHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Name = "RaceItemSlot"
	label.AnchorPoint = Vector2.new(0, 1)
	label.BackgroundColor3 = Color3.fromRGB(16, 25, 35)
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.TextColor3 = Color3.fromRGB(65, 225, 245)
	label.Font = Enum.Font.GothamBold
	label.Text = "NITRO  [Q]"
	label.Visible = false
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	local function layout()
		local camera = Workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local compact = size.Y > 0 and size.Y <= 500
		gui.IgnoreGuiInset = not (size.Y > 0 and size.Y <= 650)
		-- Lower left keeps the road center clear. Compact layout reserves the
		-- bottom 100 px for future steering controls, within the safe GUI area.
		label.Position = UDim2.new(0, if compact then 16 else 24, 1, if compact then -100 else -30)
		label.Size = UDim2.fromOffset(if compact then 110 else 128, if compact then 40 else 48)
		label.TextSize = if compact then 14 else 18
		label.Text = if UserInputService.KeyboardEnabled then "NITRO\nQ" else "NITRO"
	end
	local function refresh()
		label.Visible = player:GetAttribute("RaceState") == "RACING"
			and player:GetAttribute("RaceItemId") == "Nitro"
			and player:GetAttribute("RaceItemReady") == true
	end
	local viewportConnection = nil
	local function bindCamera()
		if viewportConnection then viewportConnection:Disconnect() end
		if Workspace.CurrentCamera then
			viewportConnection = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
		end
		layout()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(layout)
	for _, attribute in { "RaceState", "RaceItemId", "RaceItemReady" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	bindCamera()
	refresh()
end

return RaceItemUiController
