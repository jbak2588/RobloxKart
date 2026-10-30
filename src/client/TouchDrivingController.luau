local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Input = require(script.Parent:WaitForChild("KartInputController"))
local Model = require(script.Parent:WaitForChild("TouchDrivingModel"))
local View = require(script.Parent:WaitForChild("MobileControlView"))
local IconView = require(script.Parent:WaitForChild("KDMControlIconView"))
local ContentProvider = game:GetService("ContentProvider")
local LobbyLayout=require(script.Parent:WaitForChild("LobbyDriveLayout"))
local Controller = {}
local started = false

function Controller.start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local state = Model.new()
	local cache = IconView.cache(ContentProvider,task)
	local controlsEnabled = false
	local gui = Instance.new("ScreenGui")
	gui.Name = "RobloxKartTouchDriving"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ClipToDeviceSafeArea=false
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
	local driftIcon = IconView.new(drift,"DriftWide",cache,View)
	local use = button("UseItem")
	use.Visible = false -- Item-only control superseded by direct item-slot actions.
	use.AnchorPoint = Vector2.new(0, 1)
	local useIcon = View.icon(use, "Use")
	local auto,autoStroke,autoIcon
	do
		auto,autoStroke=button("AutoForward")
		auto.AnchorPoint=Vector2.new(1,1)
		autoIcon=if state.mode == "Buttons" then IconView.new(auto,"AutoStart",cache,View) else View.icon(auto,"AutoForward")
		if state.mode == "Joystick" then local scale=Instance.new("UIScale");scale.Scale=.85;scale.Parent=autoIcon.root end
	end
	local autoBackward,backwardStroke,backwardIcon
	if state.mode == "Buttons" then
		autoBackward,backwardStroke=button("AutoBackward")
		autoBackward.AnchorPoint=Vector2.new(1,1)
		backwardIcon=IconView.new(autoBackward,"AutoBackward",cache,View)
	end
	gui:SetAttribute("MobileDriveControlMode", state.mode)
	joystick.Visible = state.mode == "Joystick"
	local drivingButtons = {}
	for _, action in {"Forward", "ForwardLeft", "ForwardRight", "BrakeReverse"} do
		local b, outline = button(action)
		b.AnchorPoint = Vector2.new(0, 1)
		b.Visible = state.mode == "Buttons"
		drivingButtons[action] = {button = b, outline = outline, icon = IconView.new(b,action,cache,View)}
	end
 local gas,gasStroke=button('Gas');gas.Visible=false
 local v1Labels={};local previewLayout=nil
 local function centerTriangle(t)
  if t.Text~='◀' and t.Text~='▶' then return end
  -- Unicode fallback fonts can use half-width or full-width triangle advances.
  -- Follow the rendered text metrics when fonts load or the UI scale changes.
  local bounds=t.TextBounds
  local width=if bounds and bounds.X>0 then bounds.X else t.TextSize
  local wide=width>t.TextSize*.6
  local x=if wide then (if t.Text=='◀' then 1 else -1) else 0
  t.Position=UDim2.fromOffset(x,-math.round(t.TextSize*(if wide then 1/6 else 1/12)))
 end
 local function glyph(b,text)
  local t=Instance.new('TextLabel');t.Name='ControlsV1Glyph';t.BackgroundTransparency=1;t.Size=UDim2.fromScale(1,1)
  t.Text=text;t.Font=Enum.Font.GothamBold;t.TextColor3=Color3.fromRGB(245,245,245);t.TextSize=14;t.Active=false;t.Visible=false;t.Parent=b
  if text=='◀' or text=='▶' then t:GetPropertyChangedSignal('TextBounds'):Connect(function()centerTriangle(t)end)end
  return t
 end
 v1Labels.ForwardLeft=glyph(drivingButtons.ForwardLeft.button,'◀')
 v1Labels.ForwardRight=glyph(drivingButtons.ForwardRight.button,'▶')
 v1Labels.BrakeReverse=glyph(drivingButtons.BrakeReverse.button,'BRAKE')
 v1Labels.Drift=glyph(drift,'DRIFT');v1Labels.Gas=glyph(gas,'GAS')
 local notice=Instance.new('TextLabel');notice.Name='ControlsV1PreviewNotice';notice.BackgroundTransparency=1
 notice.Text='UI PREVIEW / GAS SPEED NOT CONNECTED';notice.TextWrapped=true;notice.TextSize=10;notice.Font=Enum.Font.GothamBold
 notice.TextColor3=Color3.fromRGB(245,220,140);notice.TextStrokeTransparency=.35;notice.Active=false;notice.Visible=false;notice.Parent=root
 local function neutral(b,outline,label,held)
  b.BackgroundColor3=if held and b==gas then Color3.fromRGB(32,47,50) else Color3.fromRGB(28,30,34)
  b.BackgroundTransparency=if held then .33 else .52
  outline.Enabled=true;outline.Color=Color3.fromRGB(225,230,235);outline.Thickness=1;outline.Transparency=if held then .15 else .35
  local corner=b:FindFirstChildOfClass("UICorner");if corner then corner.CornerRadius=UDim.new(.28,0)end
  label.Visible=true;label.TextTransparency=if controlsEnabled then 0 else .4
  local steering=b==drivingButtons.ForwardLeft.button or b==drivingButtons.ForwardRight.button
  label.Font=if steering then Enum.Font.GothamBlack else Enum.Font.GothamBold
  label.TextSize=if steering then 48 elseif b==drivingButtons.BrakeReverse.button then 10 else 12
  -- Move only the non-interactive ink; preserve all accepted input bounds.
  if steering then centerTriangle(label) end
 end
	local touches, connections, kartConnections = {}, {}, {}
	local autoTouch,backwardTouch=nil,nil
	local function ownsAuto(input) return input==autoTouch or input==backwardTouch end
	local focused, removing = true, false
	local currentKart, humanoidConnection, characterConnection = nil, nil, nil
	local function connect(event, callback)
		local c = event:Connect(callback)
		table.insert(connections, c)
		return c
	end
	local function publish()
		Input.setTouchActions(state:actions())
  if Input.setGasHeld then Input.setGasHeld(controlsEnabled and state.gasOwner~=nil) end
  gui:SetAttribute('GasPreviewHeld',state.gasOwner~=nil)
		for action,control in drivingButtons do
			local held=state:isPressed(action)
			local loaded=control.icon:update(controlsEnabled,held)
			control.outline.Enabled=not loaded
			control.outline.Thickness=if held then 4 else 2
			control.outline.Color=Color3.fromRGB(225,246,255)
			control.outline.Transparency=0
			control.button.BackgroundTransparency=if loaded then 1 else .18
			control.button.BackgroundColor3=if held then Color3.fromRGB(36,107,137) else Color3.fromRGB(19,39,54)
		end
		if auto then
			if state.mode == "Buttons" then
				local loaded=autoIcon:update(controlsEnabled,state.autoForward)
				autoStroke.Enabled=not loaded
			else autoIcon:setLatched(state.autoForward) end
			auto.BackgroundTransparency=if state.mode == "Buttons" and autoIcon.image.Visible then 1 elseif state.autoForward then .08 else .65
			autoStroke.Thickness=if state.autoForward then 4 else 1
			auto.BackgroundColor3=if state.autoForward then Color3.fromRGB(32,102,145) else Color3.fromRGB(19,39,54)
			gui:SetAttribute("AutoForwardEnabled",state.autoForward)
		end
		if autoBackward then
			local loaded=backwardIcon:update(controlsEnabled,state.autoBackward)
			backwardStroke.Enabled=not loaded
			backwardStroke.Thickness=if state.autoBackward then 4 else 1
			autoBackward.BackgroundTransparency=if loaded then 1 elseif state.autoBackward then .08 else .65
			autoBackward.BackgroundColor3=if state.autoBackward then Color3.fromRGB(32,102,145) else Color3.fromRGB(19,39,54)
		end
		gui:SetAttribute("AutoBackwardEnabled",state.autoBackward)
		-- The visual thumb follows the clamped raw displacement; actions have a dead band.
		local travel = math.max(1, (joystick.AbsoluteSize.X-thumb.AbsoluteSize.X)/2-4)
		thumb.Position = UDim2.new(0.5, state.knobX*travel, 0.5, state.knobY*travel)
		joystickStroke.Transparency = if state.owner then 0 else 0.35
		local loaded=driftIcon:update(controlsEnabled,next(state.driftOwners)~=nil)
		driftStroke.Enabled=not loaded
		drift.BackgroundTransparency=if loaded then 1 else .18
		driftStroke.Thickness = if next(state.driftOwners) then 4 else 2
		drift.BackgroundColor3 = if next(state.driftOwners) then Color3.fromRGB(36, 107, 137) else Color3.fromRGB(19, 39, 54)
  gas.Visible=previewLayout~=nil and state.mode=='Buttons'
  for _,label in v1Labels do label.Visible=false end
  notice.Visible=previewLayout~=nil and player.UserId==game.CreatorId
   and workspace:GetAttribute('KDMGasPedalEnabled')~=true
  if previewLayout then
   for action,control in drivingButtons do
    if v1Labels[action] then
     control.icon.image.Visible=false;control.icon.fallback.root.Visible=false
     neutral(control.button,control.outline,v1Labels[action],state:isPressed(action))
    end
   end
   driftIcon.image.Visible=false;driftIcon.fallback.root.Visible=false
   neutral(drift,driftStroke,v1Labels.Drift,next(state.driftOwners)~=nil)
   neutral(gas,gasStroke,v1Labels.Gas,state.gasOwner~=nil)
  end
	end
	local function reset()
		autoTouch,backwardTouch=nil,nil
		for _, c in touches do c:Disconnect() end
		table.clear(touches)
		state:reset()
		Input.setTouchEnabled(false)
		publish()
	end
	Input.setLobbyTouchReset(reset)
	local function kart()
		local character = if not removing then player.Character else nil
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		return if humanoid and humanoid.Health > 0 and seat and (seat:GetAttribute("PrototypeKartSeat") == true or seat:GetAttribute("LobbyKartSeat") == true)
			then seat.Parent else nil
	end
	local function canShow()
		local race = player:GetAttribute("RaceState")
		local phase=player:GetAttribute("ParkTrialPhase")
		return gui.Enabled and Input.isTouchPreferred() and focused and not GuiService.MenuIsOpen
			and phase~="FINISHING" and phase~="FINISHED" and phase~="INVALID"
			and UserInputService:GetFocusedTextBox() == nil and kart() ~= nil
			and (race == "COUNTDOWN" or race == "RACING" or Input.isLobbyDriving())
	end
	local function canDrive()
		local activeKart = kart()
		return canShow() and root.Visible and (player:GetAttribute("RaceState") == "RACING" or Input.isLobbyDriving())
			and player:GetAttribute("ParkTrialPhase")~="COUNTDOWN"
			and activeKart ~= nil and activeKart:GetAttribute("RaceControlsLocked") ~= true
	end
	local function release(input)
		if input.UserInputState ~= Enum.UserInputState.End and input.UserInputState ~= Enum.UserInputState.Cancel then return end
		-- A cancelled joystick is not an intentional release of cruise control.
		if input.UserInputState == Enum.UserInputState.Cancel then
			if input == state.owner or ownsAuto(input) then state:clearAuto() end
			if input==autoTouch then autoTouch=nil end
			if input==backwardTouch then backwardTouch=nil end
		end
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
			if input.UserInputType ~= Enum.UserInputType.Touch or not canDrive() or touches[input] or ownsAuto(input) then return end
			if state:pressButton(input, action) then watch(input); publish() end
		end)
		-- Release follows the owning InputObject globally, even outside the button.
		connect(control.button.InputEnded, release)
	end
 connect(gas.InputBegan,function(input)
  if not previewLayout or input.UserInputType~=Enum.UserInputType.Touch or not canDrive() or touches[input] or ownsAuto(input) then return end
  if state:pressGas(input) then watch(input);publish() end
 end)
 connect(gas.InputEnded,release)
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
		if input.UserInputType ~= Enum.UserInputType.Touch or not canDrive() or touches[input] or ownsAuto(input) then return end
		if state:pressDrift(input) then watch(input); publish() end
	end)
	connect(joystick.InputEnded, release)
	connect(drift.InputEnded, release)
	connect(UserInputService.InputEnded, release)
	connect(UserInputService.InputChanged, function(input)
		if input == state.owner and canDrive() then state:move(input, displacement(input)); publish() end
  -- A held GAS finger may move to BRAKE or DRIFT without lifting.
  -- Brake takes negative-throttle ownership immediately instead of leaving GAS held.
  if previewLayout and input==state.gasOwner and canDrive() then
   local brake=drivingButtons.BrakeReverse.button
   local pos,size=brake.AbsolutePosition,brake.AbsoluteSize
   if input.Position.X>=pos.X and input.Position.X<=pos.X+size.X and input.Position.Y>=pos.Y and input.Position.Y<=pos.Y+size.Y then
    state:release(input);state:pressButton(input,'BrakeReverse');publish()
   else
    pos,size=drift.AbsolutePosition,drift.AbsoluteSize
    if input.Position.X>=pos.X and input.Position.X<=pos.X+size.X and input.Position.Y>=pos.Y and input.Position.Y<=pos.Y+size.Y then
     state:release(input);state:pressDrift(input);publish()
    end
   end
  end
	end)
	if auto then
		connect(auto.InputBegan,function(input)
			if input.UserInputType==Enum.UserInputType.Touch and canDrive() and not touches[input] and not ownsAuto(input) then autoTouch=input;watch(input) end
		end)
		connect(auto.Activated, function(input)
			-- Only a touch that began on Auto may toggle it; an existing held
			-- steering/Drift finger cannot arm Auto by slipping onto its target.
			if input and input~=autoTouch then return end
			autoTouch=nil
			if canDrive() then state:toggleAutoForward(); publish() end
		end)
	end
	if autoBackward then
		connect(autoBackward.InputBegan,function(input)
			if input.UserInputType==Enum.UserInputType.Touch and canDrive() and not touches[input] and not ownsAuto(input) then backwardTouch=input;watch(input) end
		end)
		connect(autoBackward.Activated,function(input)
			if input and input~=backwardTouch then return end
			backwardTouch=nil
			if canDrive() then state:toggleAutoBackward();publish() end
		end)
	end
	local function layout()
		reset()
		local l = View.layout(root.AbsoluteSize)
		if Input.isLobbyDriving() and not l.controlsV1 then l=LobbyLayout.apply(l,root.AbsoluteSize) end
  previewLayout=if state.mode=='Buttons' then l.controlsV1 else nil
		local backwardLayout=if autoBackward then View.autoBackwardLayout(l,root.AbsoluteSize) else nil
		joystick.Size = UDim2.fromOffset(l.joystick, l.joystick)
		joystick.Position = UDim2.new(1, -l.margin, 1, -l.margin)
		if auto then auto.Size = UDim2.fromOffset(48, 48)
		auto.Position = UDim2.new(1, -l.margin-l.joystick-8, 1, -math.max(l.margin+(l.joystick-48)/2,l.wheel*2/3+8)) end
		if state.mode == "Buttons" then
			local left = root.AbsoluteSize.X - l.margin - l.padWidth - l.padInset
			local top = l.padBottom + l.padHeight
			auto.Visible = false
			auto.Size=UDim2.fromOffset(l.autoHitSize,l.autoHitSize)
			auto.Position=UDim2.new(0,left+l.autoRight,1,-top+l.autoTop+l.autoHitSize)
			autoIcon:layout(l.autoVisualSize,l.autoVisualSize)
			if backwardLayout then
				autoBackward.Visible = false
				autoBackward.Size=UDim2.fromOffset(backwardLayout.hit,backwardLayout.hit)
				autoBackward.Position=UDim2.new(0,backwardLayout.right,1,-backwardLayout.bottom)
				backwardIcon:layout(backwardLayout.visual,backwardLayout.visual)
			end
			drivingButtons.Forward.button.Visible = false
			drivingButtons.Forward.button.Size = UDim2.fromOffset(l.forward, l.forward)
			drivingButtons.Forward.button.Position = UDim2.new(0, left+(l.padWidth-l.forward)/2, 1, -(top-l.forward))

			-- Left thumb zone: Left / Right steering buttons (where Drift used to be)
			local steerX = l.steerLeftX or 12
			local steerBottom = l.steerBottom or math.max(12, l.padBottom)
			drivingButtons.ForwardLeft.button.Visible = true
			drivingButtons.ForwardLeft.button.Size = UDim2.fromOffset(l.sideWidth, l.sideHeight)
			drivingButtons.ForwardLeft.button.Position = UDim2.new(0, steerX, 1, -steerBottom)

			drivingButtons.ForwardRight.button.Visible = true
			drivingButtons.ForwardRight.button.Size = UDim2.fromOffset(l.sideWidth, l.sideHeight)
			drivingButtons.ForwardRight.button.Position = UDim2.new(0, steerX + l.sideWidth + 8, 1, -steerBottom)

			-- Right thumb zone: Drift and BrakeReverse share the lower row.
			local rightBrakeX = l.rightBrakeX or (left + (l.padWidth - l.brake) / 2)
			local rightBrakeBottom = l.rightBrakeBottom or math.max(10, l.padBottom)
			drivingButtons.BrakeReverse.button.Visible = true
			drivingButtons.BrakeReverse.button.Size = UDim2.fromOffset(l.brake, l.brake)
			drivingButtons.BrakeReverse.button.Position = UDim2.new(0, rightBrakeX, 1, -rightBrakeBottom)

			local rightDriftX = l.rightDriftX or (left + (l.padWidth - l.driftHitWidth) / 2)
			local rightDriftBottom = l.rightDriftBottom or (rightBrakeBottom + l.brake + 6)
			drift.Size, use.Size = UDim2.fromOffset(l.driftHitWidth,l.driftHitHeight), UDim2.fromOffset(l.action,l.action)
			driftIcon:layout(l.driftWidth,l.driftHeight)
			for action,control in drivingButtons do
				local visualWidth = if action=="ForwardLeft" or action=="ForwardRight" then l.sideVisualWidth elseif action=="BrakeReverse" then (l.brakeVisualSize or l.driveVisualSize) else l.driveVisualSize
				local visualHeight = if action=="BrakeReverse" then (l.brakeVisualSize or l.driveVisualSize) else l.driveVisualSize
				control.icon:layout(visualWidth, visualHeight)
			end
			drift.Position = UDim2.new(0, rightDriftX, 1, -rightDriftBottom)
			use.Position = UDim2.new(0, l.useX, 1, -l.useBottom)
		else
			if auto then auto.Visible = true end
			drift.Size, use.Size = UDim2.fromOffset(l.driftHitWidth,l.driftHitHeight), UDim2.fromOffset(l.action,l.action)
			driftIcon:layout(l.driftWidth,l.driftHeight)
			for action,control in drivingButtons do
				control.icon:layout(if action=="ForwardLeft" or action=="ForwardRight" then l.sideVisualWidth else l.driveVisualSize,l.driveVisualSize)
			end
			drift.Position = UDim2.new(0,l.driftX,1,-l.driftBottom)
			use.Position = UDim2.new(0,l.useX,1,-l.useBottom)
		end
  if previewLayout then
   for name,r in previewLayout.buttons do
    local b=if name=='Gas' then gas elseif name=='Drift' then drift else drivingButtons[name].button
    b.AnchorPoint=Vector2.zero;b.Position=UDim2.fromOffset(r.x,r.y);b.Size=UDim2.fromOffset(r.width,r.height)
   end
   local n=previewLayout.notice;notice.Position=UDim2.fromOffset(n.x,n.y);notice.Size=UDim2.fromOffset(n.width,n.height)
  else
   drift.AnchorPoint=Vector2.new(0,1)
   for _,c in drivingButtons do c.button.AnchorPoint=Vector2.new(0,1) end
  end
  publish()
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
	connect(player:GetAttributeChangedSignal("LobbyDriveResetSerial"), reset)
	connect(player:GetAttributeChangedSignal("LobbyDriveActive"), layout)
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
 if workspace and workspace.GetAttributeChangedSignal then connect(workspace:GetAttributeChangedSignal('KDMControlsV1Preview'),layout) end
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
		controlsEnabled=enabled
		if not enabled then reset() end
		Input.setTouchEnabled(enabled)
		local lobby = Input.isLobbyDriving()
		drift.Visible = true
		use.Visible = false
		local selected = player:GetAttribute("SelectedRaceItemId")
		local charges = if type(selected) == "string" then player:GetAttribute("RaceCharge"..selected) else 0
		useIcon:setEnabled(enabled and type(charges) == "number" and charges > 0)
		if autoIcon and state.mode == "Joystick" then autoIcon:setEnabled(enabled) end
		publish()
		thumb.BackgroundTransparency = if enabled then 0 else 0.6
	end)
	connect(gui.Destroying, function()
		cache:destroy()
		reset()
		Input.setTouchUpdater(nil)
		defaultControls(false)
		for _, c in connections do c:Disconnect() end
		for _, c in kartConnections do c:Disconnect() end
		if humanoidConnection then humanoidConnection:Disconnect() end
		if characterConnection then characterConnection:Disconnect() end
		started = false
	end)
	cache:start(publish)
end

return Controller
