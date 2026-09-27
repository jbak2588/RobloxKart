local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local Input = require(script.Parent:WaitForChild("KartInputController"))
local MobileView = require(script.Parent:WaitForChild("MobileControlView"))

local requireModule = require :: (ModuleScript) -> any
local raceConfigModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaceConfig") :: ModuleScript
local RaceConfig = requireModule(raceConfigModule)
local KartConfig = requireModule(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartConfig") :: ModuleScript)
local DriverCatalog = requireModule(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DriverCatalog") :: ModuleScript)
local KartCatalog = requireModule(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartCatalog") :: ModuleScript)
local TrackCatalog = requireModule(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrackCatalog") :: ModuleScript)
local TrackGeometry = requireModule(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrackGeometry") :: ModuleScript)
local TrackMapRenderer = require(script.Parent:WaitForChild("TrackMapRenderer"))

local RaceHudController = {}

local HUD_NAME = "RobloxKartRaceHud"
local DEBUG_UI = false
local started = false

local function getNumberAttribute(player: Player, name: string, fallback: number): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else fallback
end

local function createLabel(parent: Instance, name: string, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.Size = UDim2.new(1, -20, 0, 23)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextSize = 18
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function RaceHudController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local remoteEvent = ReplicatedStorage:WaitForChild(RaceConfig.CONTROL_REMOTE_EVENT_NAME) :: RemoteEvent
	local playerGui = player:WaitForChild("PlayerGui")
	local previousHud = playerGui:FindFirstChild(HUD_NAME)
	if previousHud then
		previousHud:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = HUD_NAME
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Position = UDim2.fromOffset(24, 118)
	frame.Size = UDim2.fromOffset(260, 112)
	frame.BackgroundColor3 = Color3.fromRGB(16, 19, 24)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = screenGui
	addCorner(frame, 6)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local lapLabel = createLabel(frame, "Lap", 1)
	lapLabel.Size = UDim2.new(1, -20, 0, 30)
	lapLabel.TextSize = 23
	lapLabel.TextColor3 = Color3.fromRGB(255, 225, 70)
	local checkpointLabel = createLabel(frame, "Checkpoint", 2)
	checkpointLabel.TextSize = 16
	local bestLabel = createLabel(frame, "Best", 3)
	bestLabel.TextSize = 16
	local offTrackLabel = createLabel(frame, "OffTrack", 4)
	offTrackLabel.TextSize = 16
	offTrackLabel.TextColor3 = Color3.fromRGB(255, 175, 80)

	local speedPanel = Instance.new("Frame")
	speedPanel.Name = "Speedometer"
	speedPanel.AnchorPoint = Vector2.new(0.5, 0)
	speedPanel.Position = UDim2.new(0.5, 0, 0, 18)
	speedPanel.Size = UDim2.fromOffset(210, 86)
	speedPanel.BackgroundColor3 = Color3.fromRGB(16, 19, 24)
	speedPanel.BackgroundTransparency = 0.15
	speedPanel.BorderSizePixel = 0
	speedPanel.Visible = false
	speedPanel.Parent = screenGui
	addCorner(speedPanel, 10)
	local speedOutline = Instance.new("UIStroke")
	speedOutline.Thickness = 1
	speedOutline.Color = Color3.fromRGB(170, 195, 210)
	speedOutline.Transparency = 0.85
	speedOutline.Enabled = false
	speedOutline.Parent = speedPanel
	local speedValue = createLabel(speedPanel, "SpeedValue", 1)
	speedValue.Position = UDim2.fromOffset(12, 5)
	speedValue.Size = UDim2.fromOffset(130, 46)
	speedValue.Font = Enum.Font.GothamBlack
	speedValue.TextSize = 40
	speedValue.Text = "0"
	local speedUnit = createLabel(speedPanel, "SpeedUnit", 2)
	speedUnit.Position = UDim2.fromOffset(130, 24)
	speedUnit.Size = UDim2.fromOffset(72, 20)
	speedUnit.Text = "stud/s"
	speedUnit.TextSize = 14
	speedUnit.TextColor3 = Color3.fromRGB(180, 194, 211)
	local speedTrack = Instance.new("Frame")
	speedTrack.Position = UDim2.fromOffset(12, 62)
	speedTrack.Size = UDim2.fromOffset(186, 8)
	speedTrack.BackgroundColor3 = Color3.fromRGB(59, 68, 81)
	speedTrack.BorderSizePixel = 0
	speedTrack.Parent = speedPanel
	addCorner(speedTrack, 4)
	local speedFill = Instance.new("Frame")
	speedFill.Size = UDim2.fromScale(0, 1)
	speedFill.BackgroundColor3 = Color3.fromRGB(255, 215, 75)
	speedFill.BorderSizePixel = 0
	speedFill.Parent = speedTrack
	addCorner(speedFill, 4)

	local steeringDisplay = Instance.new("Frame")
	steeringDisplay.Name = "SteeringDisplay"
	steeringDisplay.AnchorPoint = Vector2.new(0.5, 1)
	steeringDisplay.Position = UDim2.new(0.5, 0, 1, -18)
	steeringDisplay.Size = UDim2.fromOffset(112, 112)
	steeringDisplay.BackgroundColor3 = Color3.fromRGB(13, 31, 43)
	steeringDisplay.BackgroundTransparency = 0.12
	steeringDisplay.Visible = false
	steeringDisplay.Parent = screenGui
	addCorner(steeringDisplay, 56)
	steeringDisplay:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	local steeringRing = Instance.new("Frame")
	steeringRing.AnchorPoint = Vector2.new(0.5, 0.5)
	steeringRing.Position = UDim2.fromScale(0.5, 0.5)
	steeringRing.Size = UDim2.fromOffset(86, 86)
	steeringRing.BackgroundTransparency = 1
	steeringRing.Parent = steeringDisplay
	local steeringRingScale = Instance.new("UIScale")
	steeringRingScale.Parent = steeringRing
	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(1, 0)
	ringCorner.Parent = steeringRing
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = Color3.fromRGB(65, 225, 245)
	ringStroke.Thickness = 7
	ringStroke.Parent = steeringRing
	for _, position in { UDim2.fromOffset(1, 37), UDim2.fromOffset(43, 37) } do
		local spoke = Instance.new("Frame")
		spoke.Position = position
		spoke.Size = UDim2.fromOffset(42, 8)
		spoke.BackgroundColor3 = Color3.fromRGB(65, 225, 245)
		spoke.BorderSizePixel = 0
		spoke.Parent = steeringRing
	end
	local lowerSpoke = Instance.new("Frame")
	lowerSpoke.Position = UDim2.fromOffset(39, 42)
	lowerSpoke.Size = UDim2.fromOffset(8, 36)
	lowerSpoke.BackgroundColor3 = Color3.fromRGB(65, 225, 245)
	lowerSpoke.BorderSizePixel = 0
	lowerSpoke.Parent = steeringRing
	local steeringHub = Instance.new("Frame")
	steeringHub.Position = UDim2.fromOffset(33, 33)
	steeringHub.Size = UDim2.fromOffset(20, 20)
	steeringHub.BackgroundColor3 = Color3.fromRGB(255, 215, 75)
	steeringHub.BorderSizePixel = 0
	steeringHub.Parent = steeringRing
	addCorner(steeringHub, 10)
	-- Indicator only: no button, Active flag or touch/input connections here.
	local wheelClip = Instance.new("Frame")
	wheelClip.Name = "MobileWheelIndicator"
	wheelClip.AnchorPoint = Vector2.new(0.5, 1)
	wheelClip.Position = UDim2.fromScale(0.5, 1)
	wheelClip.BackgroundTransparency = 1
	wheelClip.ClipsDescendants = true
	wheelClip.Active = false
	wheelClip.Visible = false
	wheelClip.Parent = screenGui

	local miniMapPanel = Instance.new("Frame")
	miniMapPanel.Name = "RaceMiniMap"
	miniMapPanel.AnchorPoint = Vector2.new(1, 0.5)
	miniMapPanel.Position = UDim2.new(1, -24, 0.5, 0)
	miniMapPanel.Size = UDim2.fromOffset(194, 194)
	miniMapPanel.BackgroundColor3 = Color3.fromRGB(16, 25, 37)
	miniMapPanel.BackgroundTransparency = 0.1
	miniMapPanel.BorderSizePixel = 0
	miniMapPanel.Visible = false
	miniMapPanel.Parent = screenGui
	addCorner(miniMapPanel, 10)
	local miniMapSize = Instance.new("UISizeConstraint")
	miniMapSize.MinSize = Vector2.new(170, 170)
	miniMapSize.MaxSize = Vector2.new(200, 200)
	miniMapSize.Parent = miniMapPanel
	local mapRenderer = nil
	local mapGeometryId: string? = nil
	local function showMapForTrack(trackEntry)
		local geometryId = trackEntry.GeometryId
		if mapGeometryId == geometryId then
			return
		end
		if mapRenderer then
			mapRenderer:destroy()
		end
		local definition = TrackGeometry.getDefinition(geometryId)
		assert(definition, "Selected race track geometry is missing")
		mapRenderer = TrackMapRenderer.create(miniMapPanel, definition, true)
		mapGeometryId = geometryId
	end

	local selectionPanel = Instance.new("Frame")
	selectionPanel.Name = "RaceReady"
	selectionPanel.AnchorPoint = Vector2.new(1, 0)
	selectionPanel.Position = UDim2.new(1, -16, 0, 16)
	selectionPanel.Size = UDim2.fromOffset(270, 100)
	selectionPanel.BackgroundColor3 = Color3.fromRGB(16, 19, 24)
	selectionPanel.BackgroundTransparency = 0.2
	selectionPanel.BorderSizePixel = 0
	selectionPanel.Parent = screenGui
	addCorner(selectionPanel, 6)
	local selectionLayout = Instance.new("UIListLayout")
	selectionLayout.Padding = UDim.new(0, 4)
	selectionLayout.Parent = selectionPanel
	local driverLabel = createLabel(selectionPanel, "Driver", 1)
	local kartLabel = createLabel(selectionPanel, "Kart", 2)
	local trackLabel = createLabel(selectionPanel, "Track", 3)

	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "Countdown"
	countdownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	countdownLabel.Position = UDim2.fromScale(0.5, 0.5)
	countdownLabel.Size = UDim2.fromOffset(260, 140)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Font = Enum.Font.GothamBlack
	countdownLabel.TextColor3 = Color3.fromRGB(255, 225, 70)
	countdownLabel.TextStrokeTransparency = 0.25
	countdownLabel.TextScaled = true
	countdownLabel.Visible = false
	countdownLabel.Parent = screenGui
	local countdownScale = Instance.new("UIScale")
	countdownScale.Scale = 1
	countdownScale.Parent = countdownLabel

	local finalLapLabel = Instance.new("TextLabel")
	finalLapLabel.Name = "FinalLapNotice"
	finalLapLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	finalLapLabel.Position = UDim2.fromScale(0.5, 0.42)
	finalLapLabel.Size = UDim2.fromOffset(440, 80)
	finalLapLabel.BackgroundTransparency = 1
	finalLapLabel.Font = Enum.Font.GothamBlack
	finalLapLabel.Text = "FINAL LAP"
	finalLapLabel.TextColor3 = Color3.fromRGB(255, 225, 70)
	finalLapLabel.TextStrokeTransparency = 0.3
	finalLapLabel.TextScaled = true
	finalLapLabel.Visible = false
	finalLapLabel.Parent = screenGui
	local finalLapScale = Instance.new("UIScale")
	finalLapScale.Scale = 1
	finalLapScale.Parent = finalLapLabel

	local resultsPanel = Instance.new("Frame")
	resultsPanel.Name = "Results"
	resultsPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	resultsPanel.Position = UDim2.fromScale(0.5, 0.5)
	resultsPanel.Size = UDim2.fromOffset(340, 275)
	resultsPanel.BackgroundColor3 = Color3.fromRGB(16, 19, 24)
	resultsPanel.BackgroundTransparency = 0.08
	resultsPanel.BorderSizePixel = 0
	resultsPanel.Visible = false
	resultsPanel.Parent = screenGui
	addCorner(resultsPanel, 10)

	local resultsLayout = Instance.new("UIListLayout")
	resultsLayout.Padding = UDim.new(0, 8)
	resultsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	resultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	resultsLayout.Parent = resultsPanel

	local resultsPadding = Instance.new("UIPadding")
	resultsPadding.PaddingTop = UDim.new(0, 18)
	resultsPadding.PaddingBottom = UDim.new(0, 18)
	resultsPadding.PaddingLeft = UDim.new(0, 20)
	resultsPadding.PaddingRight = UDim.new(0, 20)
	resultsPadding.Parent = resultsPanel

	local finishLabel = createLabel(resultsPanel, "Finish", 1)
	finishLabel.Size = UDim2.new(1, 0, 0, 36)
	finishLabel.Text = "FINISHED"
	finishLabel.TextSize = 30
	finishLabel.TextXAlignment = Enum.TextXAlignment.Center

	local totalLabel = createLabel(resultsPanel, "Total", 2)
	totalLabel.TextXAlignment = Enum.TextXAlignment.Center
	local resultsBestLabel = createLabel(resultsPanel, "Best", 3)
	resultsBestLabel.TextXAlignment = Enum.TextXAlignment.Center

	local rematchButton = Instance.new("TextButton")
	rematchButton.Name = "Rematch"
	rematchButton.LayoutOrder = 4
	rematchButton.Size = UDim2.fromOffset(180, 44)
	rematchButton.BackgroundColor3 = Color3.fromRGB(45, 130, 235)
	rematchButton.BorderSizePixel = 0
	rematchButton.Font = Enum.Font.GothamBold
	rematchButton.Text = "REMATCH"
	rematchButton.TextColor3 = Color3.new(1, 1, 1)
	rematchButton.TextSize = 20
	rematchButton.Parent = resultsPanel
	addCorner(rematchButton, 6)
	rematchButton.Activated:Connect(function()
		remoteEvent:FireServer("Rematch")
	end)

	local garageButton = Instance.new("TextButton")
	garageButton.Name = "ReturnGarage"
	garageButton.LayoutOrder = 5
	garageButton.Size = UDim2.fromOffset(180, 44)
	garageButton.BackgroundColor3 = Color3.fromRGB(75, 80, 90)
	garageButton.BorderSizePixel = 0
	garageButton.Font = Enum.Font.GothamBold
	garageButton.Text = "GARAGE"
	garageButton.TextColor3 = Color3.new(1, 1, 1)
	garageButton.TextSize = 20
	garageButton.Parent = resultsPanel
	addCorner(garageButton, 6)
	garageButton.Activated:Connect(function()
		remoteEvent:FireServer("ReturnGarage")
	end)

	local function applyResponsiveLayout()
		local camera = Workspace.CurrentCamera
		local viewportSize = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local mobile = Input.isTouchPreferred()
		speedPanel.BackgroundTransparency = if mobile then 0.30 else 0.15
		speedTrack.BackgroundColor3 = if mobile then Color3.fromRGB(92, 106, 124) else Color3.fromRGB(59, 68, 81)
		speedOutline.Enabled = mobile
		local compact = mobile or (viewportSize.Y > 0 and viewportSize.Y <= 650)
		if mobile then screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		else screenGui.IgnoreGuiInset = not compact end
		miniMapPanel.Visible = speedPanel.Visible
		if compact then
			local lapWidth = math.min(220, math.max(175, (viewportSize.X - 160) * 0.5 - 24))
			frame.Position = UDim2.fromOffset(12, 8)
			frame.Size = UDim2.fromOffset(lapWidth, if offTrackLabel.Visible then 116 else 96)
			padding.PaddingTop = UDim.new(0, 6)
			padding.PaddingBottom = UDim.new(0, 6)
			padding.PaddingLeft = UDim.new(0, 8)
			padding.PaddingRight = UDim.new(0, 8)
			lapLabel.Size = UDim2.new(1, -16, 0, 25)
			lapLabel.TextSize = 20
			for _, label in { checkpointLabel, bestLabel, offTrackLabel } do
				label.Size = UDim2.new(1, -16, 0, 20)
				label.TextSize = 14
			end
			speedPanel.Position = UDim2.new(0.5, 0, 0, 8)
			speedPanel.Size = UDim2.fromOffset(160, 64)
			speedValue.Position = UDim2.fromOffset(10, 2)
			speedValue.Size = UDim2.fromOffset(96, 36)
			speedValue.TextSize = 31
			speedUnit.Position = UDim2.fromOffset(101, 17)
			speedUnit.Size = UDim2.fromOffset(53, 18)
			speedUnit.TextSize = 11
			speedTrack.Position = UDim2.fromOffset(10, 48)
			speedTrack.Size = UDim2.fromOffset(140, 6)
			miniMapPanel.Position = UDim2.new(1, -12, 0.5, 0)
			miniMapSize.MinSize = Vector2.zero
			miniMapPanel.Size = UDim2.fromOffset(140, 140)
			miniMapPanel.AnchorPoint = Vector2.new(1, 0.5)
			if viewportSize.X > viewportSize.Y and viewportSize.Y <= 500 then
				-- Phone landscape: leave the right capture rail and both bottom
				-- corners free. The ScreenGui already respects the top safe inset.
				miniMapPanel.AnchorPoint = Vector2.new(1, 0)
				miniMapPanel.Position = UDim2.new(1, -128, 0, 8)
				miniMapPanel.Size = UDim2.fromOffset(112, 112)
			end
			countdownLabel.Size = UDim2.fromOffset(math.min(220, viewportSize.X - 32), 100)
			finalLapLabel.Size = UDim2.fromOffset(math.min(360, viewportSize.X - 32), 64)
			resultsPanel.Size = UDim2.fromOffset(math.min(320, viewportSize.X - 32), math.min(255, viewportSize.Y - 32))
			resultsLayout.Padding = UDim.new(0, 5)
			resultsPadding.PaddingTop = UDim.new(0, 12)
			resultsPadding.PaddingBottom = UDim.new(0, 12)
			finishLabel.Size = UDim2.new(1, 0, 0, 32)
			finishLabel.TextSize = 26
			rematchButton.Size = UDim2.fromOffset(160, 38)
			garageButton.Size = rematchButton.Size
		else
			frame.Position = UDim2.fromOffset(24, 118)
			frame.Size = UDim2.fromOffset(260, if offTrackLabel.Visible then 139 else 112)
			padding.PaddingTop = UDim.new(0, 8)
			padding.PaddingBottom = UDim.new(0, 8)
			padding.PaddingLeft = UDim.new(0, 10)
			padding.PaddingRight = UDim.new(0, 10)
			lapLabel.Size = UDim2.new(1, -20, 0, 30)
			lapLabel.TextSize = 23
			for _, label in { checkpointLabel, bestLabel, offTrackLabel } do
				label.Size = UDim2.new(1, -20, 0, 23)
				label.TextSize = 16
			end
			speedPanel.Position = UDim2.new(0.5, 0, 0, 18)
			speedPanel.Size = UDim2.fromOffset(210, 86)
			speedValue.Position = UDim2.fromOffset(12, 5)
			speedValue.Size = UDim2.fromOffset(130, 46)
			speedValue.TextSize = 40
			speedUnit.Position = UDim2.fromOffset(130, 24)
			speedUnit.Size = UDim2.fromOffset(72, 20)
			speedUnit.TextSize = 14
			speedTrack.Position = UDim2.fromOffset(12, 62)
			speedTrack.Size = UDim2.fromOffset(186, 8)
			miniMapPanel.Position = UDim2.new(1, -24, 0.5, 0)
			miniMapPanel.AnchorPoint = Vector2.new(1, 0.5)
			miniMapSize.MinSize = Vector2.new(170, 170)
			miniMapPanel.Size = UDim2.fromOffset(194, 194)
			countdownLabel.Size = UDim2.fromOffset(260, 140)
			finalLapLabel.Size = UDim2.fromOffset(440, 80)
			resultsPanel.Size = UDim2.fromOffset(340, 275)
			resultsLayout.Padding = UDim.new(0, 8)
			resultsPadding.PaddingTop = UDim.new(0, 18)
			resultsPadding.PaddingBottom = UDim.new(0, 18)
			finishLabel.Size = UDim2.new(1, 0, 0, 36)
			finishLabel.TextSize = 30
			rematchButton.Size = UDim2.fromOffset(180, 44)
			garageButton.Size = rematchButton.Size
		end
		if mobile then
			local safeSize = screenGui.AbsoluteSize
			local l = MobileView.layout(safeSize)
			-- The old safe-area offset was only 8px. Clamp upward movement to
			-- the available inset instead of moving into Roblox's system controls.
			speedPanel.Position = UDim2.new(0.5, 0, 0, l.speedTop)
			speedPanel.Size = UDim2.fromOffset(160, l.speedHeight)
			speedTrack.Position = UDim2.fromOffset(10, 44)
			-- Top HUD stays clear of both thumb zones; desktop geometry is unchanged.
			local lapWidth = math.min(170, safeSize.X*0.28)
			frame.Size = UDim2.fromOffset(lapWidth, if offTrackLabel.Visible then 116 else 96)
			lapLabel.TextSize = 18
			checkpointLabel.TextSize = 12
			bestLabel.TextSize = 12
			offTrackLabel.TextSize = 11
			miniMapPanel.AnchorPoint = Vector2.new(1, 0)
			miniMapPanel.Position = UDim2.new(1, -12, 0, 8)
			miniMapSize.MinSize = Vector2.zero
			miniMapPanel.Size = UDim2.fromOffset(100, 100)
			if safeSize.X < 450 then
				miniMapPanel.Visible = false
				speedPanel.Position = UDim2.new(1, -92, 0, l.speedTop)
			end
		end
		MobileView.layoutSteeringWheel(wheelClip, steeringDisplay, steeringRingScale,
			if mobile then screenGui.AbsoluteSize else viewportSize, mobile)
	end

	local goDisplaySerial = 0
	local finalLapSerial = 0
	local finalLapShown = false
	local displayedRaceState = player:GetAttribute("RaceState")
	local displayedCountdown = getNumberAttribute(player, "RaceCountdown", 0)
	local displayedLap = getNumberAttribute(player, "RaceCurrentLap", 1)
	local function pulse(label: TextLabel, scale: UIScale)
		scale.Scale = 1.3
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0.3
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	local function updateHud()
		local raceState = player:GetAttribute("RaceState")
		local previousRaceState = displayedRaceState
		displayedRaceState = raceState
		local currentLap = getNumberAttribute(player, "RaceCurrentLap", 1)
		local completedLaps = getNumberAttribute(player, "RaceCompletedLaps", 0)
		local totalLaps = getNumberAttribute(player, "RaceTotalLaps", RaceConfig.TOTAL_LAPS)
		local nextCheckpoint = getNumberAttribute(player, "RaceNextCheckpoint", 1)
		local checkpointCount = getNumberAttribute(player, "RaceCheckpointCount", 6)
		local bestLap = getNumberAttribute(player, "RaceBestLapTime", 0)
		local finalTime = getNumberAttribute(player, "RaceFinalTime", 0)
		local offTrackRemaining = getNumberAttribute(player, "RaceOffTrackRemaining", 0)
		local driver = DriverCatalog.Entries[player:GetAttribute("SelectedDriverId")]
		local kartSelection = KartCatalog.Entries[player:GetAttribute("SelectedKartId")]
		local track = TrackCatalog.Entries[player:GetAttribute("SelectedTrackId")]
		showMapForTrack(track or TrackCatalog.Entries[TrackCatalog.DefaultId])
		frame.Visible = raceState == "COUNTDOWN" or raceState == "RACING" or raceState == "FINISHED" or raceState == "DNF"
		speedPanel.Visible = raceState == "COUNTDOWN" or raceState == "RACING"
		steeringDisplay.Visible = speedPanel.Visible
		miniMapPanel.Visible = speedPanel.Visible
		selectionPanel.Visible = DEBUG_UI and (raceState == "PRE_RACE" or raceState == "COUNTDOWN")
		driverLabel.Text = "DRIVER  " .. (if driver then driver.DisplayName else "--")
		kartLabel.Text = "KART  " .. (if kartSelection then kartSelection.DisplayName else "--")
		trackLabel.Text = "TRACK  " .. (if track then track.DisplayName else "--")

		lapLabel.Text = string.format("LAP %d / %d", currentLap, totalLaps)
		if nextCheckpoint > checkpointCount then
			checkpointLabel.Text = "CHECKPOINT FINISH"
		else
			checkpointLabel.Text = string.format("CHECKPOINT %d / %d", nextCheckpoint, checkpointCount)
		end
		bestLabel.Text = if bestLap > 0 then string.format("BEST LAP  %.2fs", bestLap) else "BEST LAP  --"
		offTrackLabel.Text = if raceState == "RACING" and offTrackRemaining > 0 then string.format("RETURN TO TRACK  %ds", offTrackRemaining) else ""
		offTrackLabel.Visible = raceState == "RACING" and offTrackRemaining > 0
		frame.Size = UDim2.fromOffset(260, if offTrackLabel.Visible then 139 else 112)

		resultsPanel.Visible = raceState == "FINISHED" or raceState == "DNF"
		finishLabel.Text = if raceState == "DNF" then "DNF" else "FINISHED"
		finishLabel.TextColor3 = if raceState == "DNF" then Color3.fromRGB(255, 175, 80) else Color3.fromRGB(255, 225, 70)
		totalLabel.Text = if raceState == "DNF" then "OFF TRACK" elseif finalTime > 0 then string.format("TOTAL TIME  %.2fs", finalTime) else "TOTAL TIME  --"
		resultsBestLabel.Text = if bestLap > 0 then string.format("BEST LAP  %.2fs", bestLap) else "BEST LAP  --"
		resultsBestLabel.Visible = raceState == "FINISHED"

		if raceState == "COUNTDOWN" then
			local countdown = getNumberAttribute(player, "RaceCountdown", 0)
			if previousRaceState ~= "COUNTDOWN" then
				goDisplaySerial += 1
				finalLapSerial += 1
				finalLapShown = false
				finalLapLabel.Visible = false
			end
			if countdown > 0 then
				if previousRaceState ~= "COUNTDOWN" or displayedCountdown ~= countdown then
					countdownLabel.Text = tostring(countdown)
					countdownLabel.Visible = true
					pulse(countdownLabel, countdownScale)
				end
			else
				countdownLabel.Visible = false
			end
			displayedCountdown = countdown
		elseif raceState == "RACING" and previousRaceState == "COUNTDOWN" then
			goDisplaySerial += 1
			local currentSerial = goDisplaySerial
			countdownLabel.Text = "GO!"
			countdownLabel.Visible = true
			pulse(countdownLabel, countdownScale)
			task.delay(0.75, function()
				if currentSerial == goDisplaySerial and player:GetAttribute("RaceState") == "RACING" then
					TweenService:Create(countdownLabel, TweenInfo.new(0.18), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
					task.delay(0.18, function()
						if currentSerial == goDisplaySerial then
							countdownLabel.Visible = false
						end
					end)
				end
			end)
		elseif raceState ~= "RACING" then
			goDisplaySerial += 1
			countdownLabel.Visible = false
		end

		if raceState == "RACING" and previousRaceState == "RACING"
			and not finalLapShown and totalLaps > 1 and displayedLap < totalLaps
			and currentLap == totalLaps and completedLaps == totalLaps - 1 then
			finalLapShown = true
			finalLapSerial += 1
			local currentSerial = finalLapSerial
			finalLapLabel.Visible = true
			pulse(finalLapLabel, finalLapScale)
			task.delay(1.45, function()
				if currentSerial == finalLapSerial and player:GetAttribute("RaceState") == "RACING" then
					TweenService:Create(finalLapLabel, TweenInfo.new(0.2), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
					task.delay(0.2, function()
						if currentSerial == finalLapSerial then
							finalLapLabel.Visible = false
						end
					end)
				end
			end)
		elseif raceState ~= "RACING" then
			finalLapSerial += 1
			finalLapLabel.Visible = false
		end
		displayedLap = currentLap
		applyResponsiveLayout()
	end

	for _, attributeName in {
		"RaceState",
		"RaceCountdown",
		"RaceCurrentLap",
		"RaceCompletedLaps",
		"RaceTotalLaps",
		"RaceNextCheckpoint",
		"RaceCheckpointCount",
		"RaceLastLapTime",
		"RaceBestLapTime",
		"RaceFinalTime",
		"RaceOffTrackRemaining",
		"SelectedDriverId",
		"SelectedKartId",
		"SelectedTrackId",
	} do
		player:GetAttributeChangedSignal(attributeName):Connect(updateHud)
	end

	local viewportConnection: RBXScriptConnection? = nil
	local function bindCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
		end
		applyResponsiveLayout()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(applyResponsiveLayout)
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyResponsiveLayout)
	bindCamera()
	updateHud()
	local displayedSpeed = 0
	local displayedSteering = 0
	local speedUpdateElapsed = 0
	RunService.RenderStepped:Connect(function(deltaTime: number)
		if not speedPanel.Visible then
			displayedSpeed = 0
			displayedSteering = 0
			steeringRing.Rotation = 0
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local kart = if seat and seat:GetAttribute("PrototypeKartSeat") == true then seat.Parent else nil
		local chassis = kart and kart:FindFirstChild("Chassis")
		local targetSpeed = 0
		if chassis and chassis:IsA("BasePart") then
			local velocity = chassis.AssemblyLinearVelocity
			targetSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			mapRenderer:setMarkerWorldPosition(chassis.Position)
		else
			mapRenderer:setMarkerWorldPosition(nil)
		end
		local steering = kart and kart:GetAttribute("KartVisualSteering")
		local targetSteering = if kart and kart:GetAttribute("RaceControlsLocked") ~= true and type(steering) == "number"
			then math.clamp(steering, -1, 1) else 0
		if Input.isTouchPreferred() then
			targetSteering = if kart and kart:GetAttribute("RaceControlsLocked") ~= true
				and kart:GetAttribute("KartCrashActive") ~= true and kart:GetAttribute("KartSlickActive") ~= true
				then Input.getEffectiveSteering() else 0
		end
		local alpha = 1 - math.exp(-10 * deltaTime)
		displayedSpeed += (targetSpeed - displayedSpeed) * alpha
		displayedSteering += (targetSteering - displayedSteering) * alpha
		if Input.isTouchPreferred() then displayedSteering = targetSteering end
		steeringRing.Rotation = displayedSteering * 35
		speedUpdateElapsed += deltaTime
		if speedUpdateElapsed >= 0.08 then
			speedUpdateElapsed = 0
			speedValue.Text = tostring(math.floor(displayedSpeed + 0.5))
			speedFill.Size = UDim2.fromScale(math.clamp(displayedSpeed / KartConfig.MINI_BOOST_MAX_SPEED, 0, 1), 1)
		end
	end)
	print("[RobloxKart] Race HUD ready")
end

return RaceHudController
