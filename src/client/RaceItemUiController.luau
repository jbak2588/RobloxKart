local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Input = require(script.Parent:WaitForChild("KartInputController"))
local Config = require(Shared:WaitForChild("RaceItemConfig"))
local SlickRearPreview = require(script.Parent:WaitForChild("SlickRearPreview"))
local MobileView = require(script.Parent:WaitForChild("MobileControlView"))
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
	local mobileIcons = {}
	for index, id in { "Nitro", "Slick", "Shield", "Missile" } do
		local button = Instance.new("TextButton")
		button.Name = id
		button.AnchorPoint = Vector2.new(0, 1)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 12
		button.BorderSizePixel = 0
		button.Parent = gui
		button.Activated:Connect(function() Input.selectRaceItem(id) end)
		buttons[index] = button
		local icon = MobileView.icon(button, id)
		local scale = Instance.new("UIScale")
		scale.Scale = 0.8
		scale.Parent = icon.root
		icon.root.Position = UDim2.fromScale(0.45, 0.43)
		local border = MobileView.stroke(button, 1)
		local count = Instance.new("TextLabel")
		count.Name = "Charges"
		count.AnchorPoint = Vector2.new(1, 1)
		count.Position = UDim2.new(1, -2, 1, -2)
		count.Size = UDim2.fromOffset(18, 18)
		count.BackgroundColor3 = Color3.fromRGB(9, 20, 30)
		count.TextColor3 = Color3.new(1, 1, 1)
		count.Font = Enum.Font.GothamBold
		count.TextSize = 14
		count.BorderSizePixel = 0
		count.Parent = button
		MobileView.round(count)
		local chosenMark = Instance.new("TextLabel")
		chosenMark.Name = "SelectedMark"
		chosenMark.Size = UDim2.fromOffset(14, 14)
		chosenMark.Position = UDim2.new(1, -15, 0, 1)
		chosenMark.BackgroundTransparency = 1
		chosenMark.Text = "✓"
		chosenMark.TextColor3 = Color3.new(1, 1, 1)
		chosenMark.TextSize = 14
		chosenMark.Parent = button
		mobileIcons[index] = {icon=icon, border=border, count=count, mark=chosenMark}
	end
	local nitroProgress = Instance.new("Frame")
	nitroProgress.Name = "NitroProgress"
	nitroProgress.BackgroundTransparency = 1
	nitroProgress.BorderSizePixel = 0
	nitroProgress.Active = false
	nitroProgress.Selectable = false
	nitroProgress.Parent = gui
	local progressLabel = Instance.new("TextLabel")
	progressLabel.Name = "NitroCharge"
	progressLabel.Size = UDim2.fromScale(1, 1)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Font = Enum.Font.GothamBold
	progressLabel.TextColor3 = Color3.fromRGB(65, 225, 245)
	progressLabel.TextSize = 13
	progressLabel.TextXAlignment = Enum.TextXAlignment.Center
	progressLabel.TextYAlignment = Enum.TextYAlignment.Center
	progressLabel.Parent = nitroProgress
	local bonusLabel = Instance.new("TextLabel")
	bonusLabel.Name = "DriftBonusNitro"
	bonusLabel.Size = UDim2.fromScale(1, 1)
	bonusLabel.BackgroundTransparency = 1
	bonusLabel.Font = Enum.Font.GothamBlack
	bonusLabel.TextColor3 = Color3.fromRGB(255, 218, 75)
	bonusLabel.TextSize = 17
	bonusLabel.TextXAlignment = Enum.TextXAlignment.Center
	bonusLabel.TextYAlignment = Enum.TextYAlignment.Center
	bonusLabel.Text = "NITRO +1"
	bonusLabel.Visible = false
	bonusLabel.Parent = nitroProgress
	local blockedUntil = 0
	local combat = Instance.new("TextLabel")
	combat.Name = "MissileFeedback"
	combat.AnchorPoint = Vector2.new(0.5, 0)
	combat.BackgroundColor3 = Color3.fromRGB(16, 25, 35)
	combat.BackgroundTransparency = 0.12
	combat.BorderSizePixel = 0
	combat.Font = Enum.Font.GothamBold
	combat.TextSize = 14
	combat.TextColor3 = Color3.fromRGB(255, 215, 75)
	combat.TextTruncate = Enum.TextTruncate.AtEnd
	combat.Active = false
	combat.Visible = false
	combat.Parent = gui
	MobileView.round(combat, UDim.new(0, 8))
	local feedbackUntil = 0
	local feedbackText = ""
	local deployedUntil = 0
	local lastAwarded = player:GetAttribute("DriftBonusNitroAwarded") == true
	local bonusFlashSerial = 0
	local bonusFlashVisible = false
	local preview
	local function refresh()
		local racing = player:GetAttribute("RaceState") == "RACING"
		if not racing and bonusFlashVisible then
			bonusFlashVisible = false
			bonusFlashSerial += 1
		end
		if not racing then blockedUntil = 0; deployedUntil = 0; feedbackUntil = 0 end
		local incoming = (player:GetAttribute("RaceMissileIncomingCount") or 0) > 0
		combat.Visible = racing and (incoming or time() < feedbackUntil)
		combat.Text = if incoming then "MISSILE INCOMING\nSHIELD CAN BLOCK" else feedbackText
		if not racing and preview then preview:stop() end
		local blocked = time() < blockedUntil
		local deployed = time() < deployedUntil
		local showLoadout = (racing or player:GetAttribute("RaceState") == "COUNTDOWN")
			and not (preview and preview:isVisible())
		local selected = player:GetAttribute("SelectedRaceItemId")
		local mobile = Input.isTouchPreferred()
		for index, button in buttons do
			local id = button.Name
			local charges = player:GetAttribute("RaceCharge" .. id) or 0
			local chosen = selected == id and charges > 0
			button.Visible = showLoadout and not blocked and not deployed
			button.BackgroundColor3 = if chosen then Color3.fromRGB(32, 102, 145) else Color3.fromRGB(16, 25, 35)
			button.TextColor3 = if charges == 0 then Color3.fromRGB(110, 118, 128) else Color3.fromRGB(220, 240, 250)
			button.Text = if mobile then "" else string.upper(id) .. " " .. charges .. (if UserInputService.KeyboardEnabled then
				"\n" .. (if chosen then "Q USE" else tostring(index)) else "")
			local symbols = mobileIcons[index]
			symbols.icon.root.Visible = mobile
			symbols.icon:setEnabled(charges > 0)
			symbols.count.Visible = mobile
			symbols.count.Text = tostring(charges)
			symbols.mark.Visible = mobile and chosen
			symbols.border.Enabled = mobile
			symbols.border.Thickness = if chosen then 3 else 1
			symbols.border.Transparency = if charges == 0 then 0.7 elseif chosen then 0 else 0.5
		end
		label.Visible = racing and (blocked or deployed) and not (preview and preview:isVisible())
		label.Text = if blocked then "BLOCKED!" else "SLICK DEPLOYED"
		local awarded = player:GetAttribute("DriftBonusNitroAwarded") == true
		local progress = player:GetAttribute("DriftBonusProgress")
		local threshold = Config.DRIFT_BONUS_REQUIRED_BOOSTS
		local count = if awarded then threshold elseif type(progress) == "number"
			then math.clamp(progress, 0, threshold) else 0
		nitroProgress.Visible = racing or player:GetAttribute("RaceState") == "COUNTDOWN"
		progressLabel.Visible = not bonusFlashVisible
		progressLabel.Text = if awarded then string.format("NITRO CHARGE  %d/%d\nBONUS EARNED", threshold, threshold)
			else string.format("NITRO CHARGE  %d/%d", count, threshold)
		bonusLabel.Visible = bonusFlashVisible
	end
	preview = SlickRearPreview.new(gui, refresh)
	local function layout()
		local camera = Workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local compact = size.Y > 0 and size.Y <= 500
		local mobile = Input.isTouchPreferred()
		if mobile then gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		else gui.IgnoreGuiInset = not (size.Y > 0 and size.Y <= 650) end
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
		combat.Position = UDim2.new(0.5, 0, 0, 64)
		combat.Size = UDim2.fromOffset(math.max(160, math.min(320, gui.AbsoluteSize.X - 384)), 40)
		if mobile then
			local l = MobileView.layout(gui.AbsoluteSize)
			local items = MobileView.itemLayout(gui.AbsoluteSize, #buttons)
			local groupWidth = items.width
			local progressHeight = items.progressHeight
			for index, button in buttons do
				button.Position = UDim2.new(0, items.x+(index-1)*(l.slot+l.gap), 1, -items.bottom)
				button.Size = UDim2.fromOffset(l.slot, l.slot)
			end
			label.Position = UDim2.new(0, items.x, 1, -items.bottom)
			label.Size = UDim2.fromOffset(groupWidth, l.slot)
			nitroProgress.Position = UDim2.fromOffset(items.x, items.progressTop)
			nitroProgress.Size = UDim2.fromOffset(groupWidth, progressHeight)
			progressLabel.TextSize = if progressHeight < 30 then 10 else 13
			preview:layout(true, label.Position)
			local panel = gui:FindFirstChild("SlickRearPreview")
			if panel then panel.Size = UDim2.fromOffset(groupWidth, math.clamp(gui.AbsoluteSize.Y-items.bottom-116,44,112)) end
			if gui.AbsoluteSize.X < 600 then
				combat.Position = UDim2.new(0.5, 0, 0, 180)
				combat.Size = UDim2.fromOffset(math.min(300, gui.AbsoluteSize.X-24), 40)
			end
		else
			nitroProgress.Position = UDim2.new(label.Position.X.Scale, label.Position.X.Offset,
				label.Position.Y.Scale, label.Position.Y.Offset - (if compact then 40 else 48) - 38)
			nitroProgress.Size = UDim2.fromOffset(width * #buttons + 4 * (#buttons-1), 32)
			progressLabel.TextSize = 13
		end
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
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(layout)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	for _, attribute in { "RaceState", "SelectedRaceItemId", "RaceChargeNitro", "RaceChargeSlick", "RaceChargeShield", "RaceChargeMissile", "DriftBonusProgress", "RaceMissileIncomingCount" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	player:GetAttributeChangedSignal("RaceItemFeedbackSerial"):Connect(function()
		if player:GetAttribute("RaceState") ~= "RACING" then return end
		local code = player:GetAttribute("RaceItemFeedbackCode")
		feedbackText = if code == "NO_TARGET_AHEAD" then "NO TARGET AHEAD"
			elseif code == "MISSILE_LOCKED" then "MISSILE LOCKED: " .. (player:GetAttribute("RaceMissileTargetName") or "") else ""
		feedbackUntil = time() + 1.75
		refresh()
		task.delay(1.75, refresh)
	end)
	player:GetAttributeChangedSignal("DriftBonusNitroAwarded"):Connect(function()
		local awarded = player:GetAttribute("DriftBonusNitroAwarded") == true
		bonusFlashSerial += 1
		local serial = bonusFlashSerial
		bonusFlashVisible = awarded and not lastAwarded and player:GetAttribute("RaceState") == "RACING"
		lastAwarded = awarded
		refresh()
		if bonusFlashVisible then
			task.delay(1, function()
				if bonusFlashSerial ~= serial then return end
				bonusFlashVisible = false
				refresh()
			end)
		end
	end)
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
