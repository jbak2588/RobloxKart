local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Input = require(script.Parent:WaitForChild("KartInputController"))
local Model = require(script.Parent:WaitForChild("TouchDrivingModel"))
local View = require(script.Parent:WaitForChild("MobileControlView"))
local Controller = {}
local started = false

function Controller.start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "RobloxKartTouchDriving"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 20
	-- Input tuning, not physics. Safe to adjust locally during M1-C.
	gui:SetAttribute("JoystickDeadZone", Model.DEAD_ZONE)
	gui.Parent = player:WaitForChild("PlayerGui")
	local root = Instance.new("Frame")
	root.Name = "Controls"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = gui
	local function button(name)
		local b = Instance.new("TextButton")
		b.Name = name
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundColor3 = Color3.fromRGB(19, 39, 54)
		b.BackgroundTransparency = 0.18
		b.BorderSizePixel = 0
		b.Parent = root
		View.round(b)
		return b, View.stroke(b, 2)
	end
	local joystick, joystickStroke = button("RightJoystick")
	joystick.AnchorPoint = Vector2.new(1, 1)
	joystick.BackgroundTransparency = 0.4
	joystickStroke.Transparency = 0.35
	local thumb = Instance.new("Frame")
	thumb.Name = "Thumb"
	thumb.AnchorPoint = Vector2.new(0.5, 0.5)
	thumb.Position = UDim2.fromScale(0.5, 0.5)
	thumb.Size = UDim2.fromOffset(40, 40)
	thumb.BackgroundColor3 = Color3.fromRGB(65, 225, 245)
	thumb.BorderSizePixel = 0
	thumb.Active = false
	thumb.Parent = joystick
	View.round(thumb)
	View.stroke(thumb, 2)
	-- Four small guide marks communicate a two-axis stick without text labels.
	for _, pos in {Vector2.new(0.5,0.08),Vector2.new(0.5,0.92),Vector2.new(0.08,0.5),Vector2.new(0.92,0.5)} do
		local mark = Instance.new("Frame")
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(pos.X, pos.Y)
		mark.Size = UDim2.fromOffset(5, 5)
		mark.BackgroundColor3 = Color3.fromRGB(220, 240, 250)
		mark.BorderSizePixel = 0
		mark.Active = false
		mark.Parent = joystick
		View.round(mark)
	end
	local drift, driftStroke = button("Drift")
	drift.AnchorPoint = Vector2.new(0, 1)
	local driftIcon = View.icon(drift, "Drift")
	local use = button("UseItem")
	use.AnchorPoint = Vector2.new(0, 1)
	local useIcon = View.icon(use, "Use")
	local auto, autoStroke = button("AutoForward")
	auto.AnchorPoint = Vector2.new(1, 1)
	local autoIcon = View.icon(auto, "AutoForward")
	autoIcon.root.Position = UDim2.fromScale(0.5, 0.5)
	local autoScale = Instance.new("UIScale")
	autoScale.Scale = 0.85
	autoScale.Parent = autoIcon.root
	local state = Model.new()
	gui:SetAttribute("MobileDriveControlMode", state.mode)
	joystick.Visible = state.mode == "Joystick"
	local drivingButtons = {}
	for _, action in {"Forward", "Left", "Right", "Brake"} do
		local b, outline = button(action)
		b.AnchorPoint = Vector2.new(0, 1)
		b.Visible = state.mode == "Buttons"
		drivingButtons[action] = {button = b, outline = outline, icon = View.icon(b, action)}
	end
	local touches, connections, kartConnections = {}, {}, {}
	local focused, removing = true, false
	local currentKart, humanoidConnection, characterConnection = nil, nil, nil
	local function connect(event, callback)
		local c = event:Connect(callback)
		table.insert(connections, c)
		return c
	end
	local function publish()
		Input.setTouchActions(state:actions())
		for action, control in drivingButtons do
			local held = state:isPressed(action)
			control.outline.Thickness = if held then 4 else 2
			control.button.BackgroundColor3 = if held then Color3.fromRGB(36, 107, 137) else Color3.fromRGB(19, 39, 54)
		end
		autoIcon:setLatched(state.autoForward)
		auto.BackgroundTransparency = if state.autoForward then 0.08 else 0.65
		autoStroke.Thickness = if state.autoForward then 4 else 1
		auto.BackgroundColor3 = if state.autoForward then Color3.fromRGB(32, 102, 145) else Color3.fromRGB(19, 39, 54)
		gui:SetAttribute("AutoForwardEnabled", state.autoForward)
		-- The visual thumb follows the clamped raw displacement; actions have a dead band.
		local travel = math.max(1, (joystick.AbsoluteSize.X-thumb.AbsoluteSize.X)/2-4)
		thumb.Position = UDim2.new(0.5, state.knobX*travel, 0.5, state.knobY*travel)
		joystickStroke.Transparency = if state.owner then 0 else 0.35
		driftStroke.Thickness = if next(state.driftOwners) then 4 else 2
		drift.BackgroundColor3 = if next(state.driftOwners) then Color3.fromRGB(36, 107, 137) else Color3.fromRGB(19, 39, 54)
	end
	local function reset()
		for _, c in touches do c:Disconnect() end
		table.clear(touches)
		state:reset()
		Input.setTouchEnabled(false)
		publish()
	end
	local function kart()
		local character = if not removing then player.Character else nil
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		return if humanoid and humanoid.Health > 0 and seat and seat:GetAttribute("PrototypeKartSeat") == true
			then seat.Parent else nil
	end
	local function canShow()
		local race = player:GetAttribute("RaceState")
		return gui.Enabled and Input.isTouchPreferred() and focused and not GuiService.MenuIsOpen
			and UserInputService:GetFocusedTextBox() == nil and kart() ~= nil
			and (race == "COUNTDOWN" or race == "RACING")
	end
	local function canDrive()
		local activeKart = kart()
		return canShow() and root.Visible and player:GetAttribute("RaceState") == "RACING"
			and activeKart ~= nil and activeKart:GetAttribute("RaceControlsLocked") ~= true
	end
	local function release(input)
		-- A cancelled joystick is not an intentional release of cruise control.
		if (input == state.owner or state.buttons[input]) and input.UserInputState == Enum.UserInputState.Cancel then state.autoForward = false end
		if touches[input] then touches[input]:Disconnect(); touches[input] = nil end
		state:release(input)
		publish()
	end
	local function watch(input)
		touches[input] = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then release(input) end
		end)
	end
	for action, control in drivingButtons do
		connect(control.button.InputBegan, function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch or not canDrive() or touches[input] then return end
			if state:pressButton(input, action) then watch(input); publish() end
		end)
		-- Release follows the owning InputObject globally, even outside the button.
		connect(control.button.InputEnded, release)
	end
	local function displacement(input)
		local center = joystick.AbsolutePosition + joystick.AbsoluteSize/2
		local radius = math.max(1, (joystick.AbsoluteSize.X-thumb.AbsoluteSize.X)/2-4)
		local zone = gui:GetAttribute("JoystickDeadZone")
		return input.Position.X-center.X, input.Position.Y-center.Y, radius,
			if type(zone) == "number" and zone == zone then zone else Model.DEAD_ZONE
	end
	connect(joystick.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch or not canDrive() then return end
		if state:begin(input, displacement(input)) then watch(input); publish() end
	end)
	connect(drift.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch or not canDrive() or touches[input] then return end
		if state:pressDrift(input) then watch(input); publish() end
	end)
	connect(joystick.InputEnded, release)
	connect(drift.InputEnded, release)
	connect(UserInputService.InputEnded, release)
	connect(UserInputService.InputChanged, function(input)
		if input == state.owner and canDrive() then state:move(input, displacement(input)); publish() end
	end)
	connect(use.Activated, function() if canDrive() then Input.useRaceItem() end end)
	connect(auto.Activated, function()
		if canDrive() then state:toggleAutoForward(); publish() end
	end)
	local function layout()
		reset()
		local l = View.layout(root.AbsoluteSize)
		joystick.Size = UDim2.fromOffset(l.joystick, l.joystick)
		joystick.Position = UDim2.new(1, -l.margin, 1, -l.margin)
		auto.Size = UDim2.fromOffset(48, 48)
		auto.Position = UDim2.new(1, -l.margin-l.joystick-8, 1, -math.max(l.margin+(l.joystick-48)/2,l.wheel*2/3+8))
		if state.mode == "Buttons" then
			local left = root.AbsoluteSize.X - l.margin - l.padWidth
			local top = l.padBottom + l.padHeight
			local function place(action, x, bottom, size)
				local b = drivingButtons[action].button
				b.Size = UDim2.fromOffset(size, size)
				b.Position = UDim2.new(0, left+x, 1, -bottom)
			end
			place("Forward", (l.padWidth-l.forward)/2, top-l.forward, l.forward)
			local directionBottom = l.padBottom + (if l.padCompact then (l.padHeight-l.direction)/2 else l.brake+6)
			place("Left", 0, directionBottom, l.direction)
			place("Right", l.padWidth-l.direction, directionBottom, l.direction)
			place("Brake", (l.padWidth-l.brake)/2, l.padBottom, l.brake)
			auto.Size = UDim2.fromOffset(44,44)
			auto.Position = UDim2.new(0,left+(if l.padAutoRight then l.padWidth else 44),1,-(if l.padCompact then top+6 else top-44))
		end
		drift.Size, use.Size = UDim2.fromOffset(l.action,l.action), UDim2.fromOffset(l.action,l.action)
		drift.Position = UDim2.new(0,l.driftX,1,-l.driftBottom)
		use.Position = UDim2.new(0,l.useX,1,-l.useBottom)
	end
	local function bindKart(value)
		for _, c in kartConnections do c:Disconnect() end
		table.clear(kartConnections)
		currentKart = value
		reset()
		if value then
			for _, key in {"RaceControlsLocked", "RaceResetSerial"} do
				table.insert(kartConnections, value:GetAttributeChangedSignal(key):Connect(reset))
			end
		end
	end
	local function bindCharacter(character)
		removing = false
		reset()
		if humanoidConnection then humanoidConnection:Disconnect(); humanoidConnection = nil end
		if characterConnection then characterConnection:Disconnect() end
		local function bindHumanoid()
			local h = character:FindFirstChildOfClass("Humanoid")
			if h and not humanoidConnection then
				humanoidConnection = h:GetPropertyChangedSignal("SeatPart"):Connect(function() bindKart(kart()) end)
				bindKart(kart())
			end
		end
		characterConnection = character.ChildAdded:Connect(bindHumanoid)
		bindHumanoid()
	end
	connect(player.CharacterAdded, bindCharacter)
	connect(player.CharacterRemoving, function() removing = true; bindKart(nil) end)
	if player.Character then bindCharacter(player.Character) end
	connect(player:GetAttributeChangedSignal("RaceState"), reset)
	connect(UserInputService.WindowFocusReleased, function() focused = false; reset() end)
	connect(UserInputService.WindowFocused, function() focused = true end)
	connect(UserInputService.TextBoxFocused, reset)
	connect(GuiService.MenuOpened, reset)
	connect(UserInputService:GetPropertyChangedSignal("PreferredInput"), reset)
	connect(gui:GetPropertyChangedSignal("Enabled"), reset)
	connect(root:GetPropertyChangedSignal("Visible"), function() if not root.Visible then reset() end end)
	connect(root:GetPropertyChangedSignal("AbsoluteSize"), layout)
	layout()
	local hiddenTouchGui, previousEnabled = nil, nil
	local function defaultControls(hidden)
		local defaultGui = player.PlayerGui:FindFirstChild("TouchGui")
		if hidden and defaultGui and not hiddenTouchGui then
			hiddenTouchGui, previousEnabled = defaultGui, defaultGui.Enabled
			defaultGui.Enabled = false
		elseif not hidden and hiddenTouchGui then
			hiddenTouchGui.Enabled = previousEnabled
			hiddenTouchGui = nil
		end
	end
	Input.setTouchUpdater(function()
		local activeKart = kart()
		if activeKart ~= currentKart then bindKart(activeKart) end
		local show = canShow()
		root.Visible = show
		defaultControls(show)
		local enabled = canDrive()
		if not enabled then reset() end
		Input.setTouchEnabled(enabled)
		local selected = player:GetAttribute("SelectedRaceItemId")
		local charges = if type(selected) == "string" then player:GetAttribute("RaceCharge"..selected) else 0
		useIcon:setEnabled(enabled and type(charges) == "number" and charges > 0)
		driftIcon:setEnabled(enabled)
		autoIcon:setEnabled(enabled)
		for _, control in drivingButtons do control.icon:setEnabled(enabled) end
		thumb.BackgroundTransparency = if enabled then 0 else 0.6
	end)
	connect(gui.Destroying, function()
		reset()
		Input.setTouchUpdater(nil)
		defaultControls(false)
		for _, c in connections do c:Disconnect() end
		for _, c in kartConnections do c:Disconnect() end
		if humanoidConnection then humanoidConnection:Disconnect() end
		if characterConnection then characterConnection:Disconnect() end
		started = false
	end)
end

return Controller
