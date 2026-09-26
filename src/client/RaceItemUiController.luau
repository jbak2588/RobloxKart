local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Input = require(script.Parent:WaitForChild("KartInputController"))
local Config = require(Shared:WaitForChild("RaceItemConfig"))
local SlickRearPreview = require(script.Parent:WaitForChild("SlickRearPreview"))
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
	label.Name = "RaceLoadoutFeedback"
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
	local buttons = {}
	for index, id in { "Nitro", "Slick", "Shield" } do
		local button = Instance.new("TextButton")
		button.Name = id
		button.AnchorPoint = Vector2.new(0, 1)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 12
		button.BorderSizePixel = 0
		button.Parent = gui
		button.Activated:Connect(function() Input.selectRaceItem(id) end)
		buttons[index] = button
	end
	local blockedUntil = 0
	local deployedUntil = 0
	local preview
	local function refresh()
		local racing = player:GetAttribute("RaceState") == "RACING"
		if not racing then blockedUntil = 0; deployedUntil = 0 end
		if not racing and preview then preview:stop() end
		local blocked = time() < blockedUntil
		local deployed = time() < deployedUntil
		local showLoadout = (racing or player:GetAttribute("RaceState") == "COUNTDOWN")
			and not (preview and preview:isVisible())
		local selected = player:GetAttribute("SelectedRaceItemId")
		for index, button in buttons do
			local id = button.Name
			local charges = player:GetAttribute("RaceCharge" .. id) or 0
			local chosen = selected == id and charges > 0
			button.Visible = showLoadout and not blocked and not deployed
			button.BackgroundColor3 = if chosen then Color3.fromRGB(32, 102, 145) else Color3.fromRGB(16, 25, 35)
			button.TextColor3 = if charges == 0 then Color3.fromRGB(110, 118, 128) else Color3.fromRGB(220, 240, 250)
			button.Text = string.upper(id) .. " " .. charges .. (if UserInputService.KeyboardEnabled then
				"\n" .. (if chosen then "Q USE" else tostring(index)) else "")
		end
		label.Visible = racing and (blocked or deployed) and not (preview and preview:isVisible())
		label.Text = if blocked then "BLOCKED!" else "SLICK DEPLOYED"
	end
	preview = SlickRearPreview.new(gui, refresh)
	local function layout()
		local camera = Workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local compact = size.Y > 0 and size.Y <= 500
		gui.IgnoreGuiInset = not (size.Y > 0 and size.Y <= 650)
		-- Lower left keeps the road center clear. Compact layout reserves the
		-- bottom 100 px for future steering controls, within the safe GUI area.
		label.Position = UDim2.new(0, if compact then 16 else 24, 1, if compact then -100 else -30)
		label.Size = UDim2.fromOffset(if compact then 218 else 272, if compact then 40 else 48)
		local width = if compact then 70 else 88
		for index, button in buttons do
			button.Position = label.Position + UDim2.fromOffset((index-1)*(width+4), 0)
			button.Size = UDim2.fromOffset(width, if compact then 40 else 48)
		end
		label.TextSize = if compact then 14 else 18
		preview:layout(compact, label.Position)
		refresh()
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
	for _, attribute in { "RaceState", "SelectedRaceItemId", "RaceChargeNitro", "RaceChargeSlick", "RaceChargeShield" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	player:GetAttributeChangedSignal("RaceItemBlockedSerial"):Connect(function()
		if player:GetAttribute("RaceState") ~= "RACING" then return end
		blockedUntil = time() + Config.BLOCKED_FEEDBACK_DURATION
		preview:stop() -- Actual attack feedback takes priority over the deploy replay.
		refresh()
		task.delay(Config.BLOCKED_FEEDBACK_DURATION, refresh)
	end)
	player:GetAttributeChangedSignal("SlickDeployedSerial"):Connect(function()
		if player:GetAttribute("RaceState") ~= "RACING" then return end
		deployedUntil = time() + 0.75
		preview:show(player:GetAttribute("SlickDeployFrame"), player:GetAttribute("SlickEjectPosition"))
		refresh()
		task.delay(0.75, refresh)
	end)
	bindCamera()
	refresh()
end

return RaceItemUiController
