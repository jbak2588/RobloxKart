local ResultView=require(script.Parent:WaitForChild('ResultPresentationView'))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
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
local RaceResultFormat = requireModule(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaceResultFormat") :: ModuleScript)
local FinishPresentation = requireModule(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KDMFinishPresentation") :: ModuleScript)
local TrackMapRenderer = require(script.Parent:WaitForChild("TrackMapRenderer"))
local PresentationState = require(script.Parent:WaitForChild("RacePresentationState"))
local RaceMinimapRivals = require(script.Parent:WaitForChild("RaceMinimapRivals"))
local GaragePresence = require(script.Parent:WaitForChild("GaragePresence"))
local RaceResultsCache = require(script.Parent:WaitForChild("RaceResultsCache"))

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
	local garageRemote = ReplicatedStorage:WaitForChild("GarageControl") :: RemoteEvent
	local playerGui = player:WaitForChild("PlayerGui")
	local previousHud = playerGui:FindFirstChild(HUD_NAME)
	if previousHud then
		previousHud:Destroy()
	end
	local previousTopHud = playerGui:FindFirstChild("RobloxKartMobileTopHud")
	if previousTopHud then previousTopHud:Destroy() end
	local previousGauge = playerGui:FindFirstChild("KDMV2GaugeHud")
	if previousGauge then previousGauge:Destroy() end
	local gaugeController = nil
	local performanceModule=script.Parent:FindFirstChild('RacePerformanceMonitor')
	local performanceMonitor=performanceModule and require(performanceModule)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = HUD_NAME
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui
	local mobileTopGui = Instance.new("ScreenGui")
	mobileTopGui.Name = "RobloxKartMobileTopHud"
	mobileTopGui.ResetOnSpawn = false
	mobileTopGui.ScreenInsets = Enum.ScreenInsets.None
	mobileTopGui.DisplayOrder = 11
	mobileTopGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Position = UDim2.fromOffset(24, 118)
	frame.Size = UDim2.fromOffset(260, 112)
	frame.BackgroundColor3 = Color3.fromRGB(16, 19, 24)
	frame.BackgroundTransparency = 1
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
	local raceEndLabel = createLabel(frame, "RaceEndWarning", 5)
	raceEndLabel.TextSize = 14
	raceEndLabel.TextColor3 = Color3.fromRGB(255, 205, 73)
	raceEndLabel.Visible = false
	for _, label in { lapLabel, checkpointLabel, bestLabel, offTrackLabel, raceEndLabel } do
		label.TextStrokeColor3 = Color3.fromRGB(16, 19, 24)
		label.TextStrokeTransparency = 0.6
	end
	local quitRow = Instance.new("Frame")
	quitRow.Name = "QuitRow"
	quitRow.LayoutOrder = 6
	quitRow.Size = UDim2.new(1, -20, 0, 24)
	quitRow.BackgroundTransparency = 1
	quitRow.Visible = false
	quitRow.Parent = frame
	local quitButton = Instance.new("TextButton")
	quitButton.Name = "QuitRace"
	quitButton.AnchorPoint = Vector2.new(1, 0)
	quitButton.Position = UDim2.new(1, 0, 0, 0)
	quitButton.Size = UDim2.fromOffset(72, 23)
	quitButton.BackgroundColor3 = Color3.fromRGB(196, 112, 120)
	quitButton.BackgroundTransparency = 1
	quitButton.TextColor3 = Color3.fromRGB(255, 230, 230)
	quitButton.Text = "QUIT"
	quitButton.TextSize = 11
	quitButton.Font = Enum.Font.GothamBold
	quitButton.Parent = quitRow
	addCorner(quitButton, 5)
	local quitOutline=Instance.new("UIStroke");quitOutline.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
	quitOutline.Color=quitButton.TextColor3;quitOutline.Thickness=1;quitOutline.Parent=quitButton
	local quitOverlay = Instance.new("Frame")
	quitOverlay.Name = "QuitConfirmation"
	quitOverlay.Size = UDim2.fromScale(1, 1)
	quitOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	quitOverlay.BackgroundTransparency = 0.35
	quitOverlay.ZIndex = 20
	quitOverlay.Visible = false
	quitOverlay.Parent = screenGui
	local routeOverlay = Instance.new("Frame")
	routeOverlay.Name = "RouteTransition"
	routeOverlay.Size = UDim2.fromScale(1, 1)
	routeOverlay.BackgroundColor3 = Color3.fromRGB(8, 14, 24)
	routeOverlay.BackgroundTransparency = 0.35
	routeOverlay.BorderSizePixel = 0
	routeOverlay.Active = true
	routeOverlay.ZIndex = 30
	routeOverlay.Visible = false
	routeOverlay.Parent = screenGui
	local routeMessage = createLabel(routeOverlay, "Message", 1)
	routeMessage.AnchorPoint = Vector2.new(0.5, 0.5)
	routeMessage.Position = UDim2.fromScale(0.5, 0.5)
	routeMessage.Size = UDim2.fromOffset(300, 72)
	routeMessage.BackgroundColor3 = Color3.fromRGB(25, 36, 52)
	routeMessage.BackgroundTransparency = 0
	routeMessage.TextColor3 = Color3.fromRGB(255, 215, 75)
	routeMessage.TextXAlignment = Enum.TextXAlignment.Center
	routeMessage.TextSize = 19
	routeMessage.Text = "RETURNING TO GARAGE..."
	routeMessage.ZIndex = 31
	addCorner(routeMessage, 9)
	local quitDialog = Instance.new("Frame")
	quitDialog.AnchorPoint = Vector2.new(0.5, 0.5)
	quitDialog.Position = UDim2.fromScale(0.5, 0.5)
	quitDialog.Size = UDim2.fromOffset(268, 132)
	quitDialog.BackgroundColor3 = Color3.fromRGB(22, 29, 40)
	quitDialog.ZIndex = 21
	quitDialog.Parent = quitOverlay
	addCorner(quitDialog, 9)
	local quitTitle = createLabel(quitDialog, "QuitTitle", 1)
	quitTitle.Position = UDim2.fromOffset(12, 11)
	quitTitle.Size = UDim2.new(1, -24, 0, 28)
	quitTitle.Text = "QUIT RACE?"
	quitTitle.TextSize = 21
	quitTitle.ZIndex = 22
	local quitDescription = createLabel(quitDialog, "QuitDescription", 2)
	quitDescription.Position = UDim2.fromOffset(12, 42)
	quitDescription.Size = UDim2.new(1, -24, 0, 22)
	quitDescription.Text = "Your current race will end."
	quitDescription.TextSize = 13
	quitDescription.ZIndex = 22
	local function dialogButton(name, label, x, color)
		local button = Instance.new("TextButton")
		button.Name = name
		button.Position = UDim2.fromOffset(x, 83)
		button.Size = UDim2.fromOffset(112, 36)
		button.BackgroundColor3 = color
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Text = label
		button.TextSize = 15
		button.Font = Enum.Font.GothamBold
		button.ZIndex = 22
		button.Parent = quitDialog
		addCorner(button, 5)
		return button
	end
	local cancelQuitButton = dialogButton("Cancel", "CANCEL", 14, Color3.fromRGB(60, 83, 105))
	local confirmQuitButton = dialogButton("ConfirmQuit", "QUIT", 142, Color3.fromRGB(155, 61, 64))
	quitButton.Activated:Connect(function()
		if player:GetAttribute("RaceState") == "RACING" then quitOverlay.Visible = true end
	end)
	cancelQuitButton.Activated:Connect(function() quitOverlay.Visible = false end)
	confirmQuitButton.Activated:Connect(function()
		if quitOverlay.Visible and player:GetAttribute("RaceState") == "RACING" then
			quitOverlay.Visible = false
			remoteEvent:FireServer("QuitRace")
		end
	end)

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
	speedUnit.Text = "km/h"
	speedUnit.TextSize = 14
	speedUnit.TextColor3 = Color3.fromRGB(180, 194, 211)
	local positionLabel = createLabel(speedPanel, "Position", 0)
	positionLabel.Position = UDim2.new(1, -76, 0, 1)
	positionLabel.Size = UDim2.fromOffset(72, 17)
	positionLabel.TextXAlignment = Enum.TextXAlignment.Right
	positionLabel.TextSize = 12
	positionLabel.TextColor3 = Color3.fromRGB(255, 225, 70)
	positionLabel.Visible = false
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
	local displayedRivalKeys = {}
	local displayedRivalPositions = {}
	local function showMapForTrack(trackEntry)
		local geometryId = trackEntry.GeometryId
		if mapGeometryId == geometryId then
			return
		end
		if mapRenderer then
			mapRenderer:destroy()
		end
		displayedRivalKeys = {}
		displayedRivalPositions = {}
		local definition = TrackGeometry.getDefinition(geometryId)
		assert(definition, "Selected race track geometry is missing")
		mapRenderer = TrackMapRenderer.create(miniMapPanel, definition, true,
			if trackEntry.Id == "Track03" then trackEntry.PreviewRotationDegrees else 0)
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
	local lobbyPanel = Instance.new("Frame")
	lobbyPanel.Name = "RaceLobbyHost"
	lobbyPanel.AnchorPoint = Vector2.new(0.5, 1)
	lobbyPanel.Position = UDim2.fromScale(0.5, 0.94)
	lobbyPanel.Size = UDim2.fromOffset(252, 88)
	lobbyPanel.BackgroundColor3 = Color3.fromRGB(16, 25, 37)
	lobbyPanel.BackgroundTransparency = 0.12
	lobbyPanel.Visible = false
	lobbyPanel.Parent = screenGui
	addCorner(lobbyPanel, 7)
	local lobbyStatus = createLabel(lobbyPanel, "Status", 1)
	lobbyStatus.Position = UDim2.fromOffset(8, 4)
	lobbyStatus.Size = UDim2.new(1, -16, 0, 30)
	lobbyStatus.Text = "RACERS  1 / 4"
	lobbyStatus.TextSize = 12
	lobbyStatus.TextColor3 = Color3.fromRGB(255, 225, 70)
	local function lobbyButton(name, label, x, color)
		local button = Instance.new("TextButton")
		button.Name = name
		button.Position = UDim2.fromOffset(x, 34)
		button.Size = UDim2.fromOffset(112, 44)
		button.BackgroundColor3 = color
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Text = label
		button.TextSize = 14
		button.Font = Enum.Font.GothamBold
		button.Parent = lobbyPanel
		addCorner(button, 5)
		return button
	end
	local autoReadySerial = player:GetAttribute("RaceItemsAutoReadySerial") or 0
	local autoReadyNoticeUntil = 0
	local autoReadyNotice = createLabel(screenGui, "ItemsAutoReadyNotice", 1)
	autoReadyNotice.Size = UDim2.fromOffset(180, 20)
	autoReadyNotice.TextSize = 12
	autoReadyNotice.TextColor3 = Color3.fromRGB(65, 225, 245)
	autoReadyNotice.Visible = false
	local lobbyStart = lobbyButton("StartRace", "START SOLO", 8, Color3.fromRGB(45, 130, 235))
	lobbyStart.Activated:Connect(function()
		if not lobbyStart.Active then return end
		remoteEvent:FireServer("StartRace")
	end)
	local lobbyLeave = lobbyButton("Cancel", "CANCEL", 132, Color3.fromRGB(80, 60, 65))
	lobbyLeave.Activated:Connect(function()
		remoteEvent:FireServer("CancelWait")
	end)
	local availabilityPanel = Instance.new("Frame")
	availabilityPanel.Name = "AvailableRacers"
	availabilityPanel.AnchorPoint = Vector2.new(0.5, 1)
	availabilityPanel.Position = UDim2.new(0.5, 0, 0.94, -96)
	availabilityPanel.Size = UDim2.fromOffset(252, 80)
	availabilityPanel.BackgroundColor3 = Color3.fromRGB(16, 25, 37)
	availabilityPanel.BackgroundTransparency = 0.12
	availabilityPanel.Visible = false
	availabilityPanel.Parent = screenGui
	addCorner(availabilityPanel, 7)
	local racingInvitesOpen = false
	local updateHud
	local racingInviteToggle = Instance.new("TextButton")
	racingInviteToggle.Name = "RacingInviteToggle"
	racingInviteToggle.AnchorPoint = Vector2.new(1, 0)
	racingInviteToggle.Position = UDim2.new(1, -12, 0, 132)
	racingInviteToggle.Size = UDim2.fromOffset(118, 32)
	racingInviteToggle.BackgroundColor3 = Color3.fromRGB(35, 95, 165)
	racingInviteToggle.BackgroundTransparency = 1
	racingInviteToggle.TextColor3 = Color3.new(1, 1, 1)
	racingInviteToggle.Font = Enum.Font.GothamBold
	racingInviteToggle.TextSize = 12
	racingInviteToggle.Text = "INVITE RACERS"
	racingInviteToggle.Visible = false
	racingInviteToggle.Parent = screenGui
	addCorner(racingInviteToggle, 5)
	local inviteOutline=Instance.new("UIStroke");inviteOutline.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
	inviteOutline.Color=Color3.new(1,1,1);inviteOutline.Thickness=1;inviteOutline.Parent=racingInviteToggle
	racingInviteToggle.Activated:Connect(function()
		racingInvitesOpen = not racingInvitesOpen
		updateHud()
	end)
	local availabilityHeading = createLabel(availabilityPanel, "WaitingTitle", 1)
	availabilityHeading.Position = UDim2.fromOffset(8, 4)
	availabilityHeading.Size = UDim2.new(1, -16, 0, 22)
	availabilityHeading.TextSize = 17
	availabilityHeading.TextColor3 = Color3.fromRGB(255, 225, 70)
	local availabilityTitle = createLabel(availabilityPanel, "AvailableTitle", 2)
	availabilityTitle.Position = UDim2.fromOffset(8, 28)
	availabilityTitle.Size = UDim2.new(1, -16, 0, 20)
	availabilityTitle.TextSize = 13
	availabilityTitle.TextColor3 = Color3.fromRGB(255, 225, 70)
	availabilityTitle.TextTruncate=Enum.TextTruncate.AtEnd
	local availabilityRows = {}
	local roomRacerRows = require(script.Parent:WaitForChild("RaceRoomRacerRows"))
	local availableHasBot = false
	local inviteStates = {}
	local inviteSerial = 0
	local function refreshInviteButtons()
		for _,row in availabilityRows do
			if row.botId then
				row.button.Text = if row.botAction == "AddBot" then "ADD BOT" else "REMOVE"
				row.button.Active = row.botAction ~= nil
				row.button.AutoButtonColor = row.button.Active
				row.button.BackgroundColor3 = Color3.fromRGB(45,130,235)
				continue
			end
			local state=inviteStates[row.userId]
			local phase=state and state.phase or "AVAILABLE"
			row.button.Text=if phase=="SENDING" then "SENDING..." elseif phase=="PENDING" then "WAITING" elseif phase=="FAILED" then "RETRY" else "INVITE"
			row.button.Active=phase=="AVAILABLE" or phase=="FAILED"
			row.button.AutoButtonColor=row.button.Active
			row.button.BackgroundColor3=if row.button.Active then Color3.fromRGB(45,130,235) else Color3.fromRGB(65,78,94)
		end
	end
	local function markInvitePending(userId, state, expiresAt)
		state.phase = "PENDING"
		state.expiresAt = expiresAt
		inviteStates[userId] = state
		task.delay(math.max(0, expiresAt-os.time()), function()
			if inviteStates[userId] == state then
				inviteStates[userId] = nil
				refreshInviteButtons()
			end
		end)
	end
	for index = 1, 4 do
		local row = createLabel(availabilityPanel, "AvailableRacer" .. index, index + 1)
		row.Position = UDim2.fromOffset(8, 52 + (index - 1) * 28)
		row.Size = UDim2.new(1, -88, 0, 25)
		row.TextSize = 13
		local invite = Instance.new("TextButton")
		invite.Name = "Invite" .. index
		invite.Position = UDim2.new(1, -76, 0, 52 + (index - 1) * 28)
		invite.Size = UDim2.fromOffset(68, 24)
		invite.BackgroundColor3 = Color3.fromRGB(45, 130, 235)
		invite.TextColor3 = Color3.new(1, 1, 1)
		invite.Font = Enum.Font.GothamBold
		invite.TextSize = 12
		invite.Text = "INVITE"
		invite.Parent = availabilityPanel
		addCorner(invite, 4)
		availabilityRows[index] = {label = row, button = invite, userId = nil}
		invite.Activated:Connect(function()
			local botRow = availabilityRows[index]
			if botRow.botId then
				if botRow.botAction then garageRemote:FireServer(botRow.botAction,botRow.botId) end
				return
			end
			local userId = availabilityRows[index].userId
			local state=inviteStates[userId]
			if not userId or (state and (state.phase=="SENDING" or state.phase=="PENDING")) then return end
			inviteSerial+=1
			local sending={phase="SENDING",requestId=inviteSerial}
			inviteStates[userId]=sending
			refreshInviteButtons()
			garageRemote:FireServer("Invite",userId,sending.requestId)
			task.delay(15,function()
				if inviteStates[userId]==sending and sending.phase=="SENDING" then sending.phase="FAILED"; refreshInviteButtons() end
			end)
		end)
	end
	local availableTotal = 0
	local roomSnapshot = nil
	local roomQueueLabel = createLabel(screenGui, "RoomQueueStatus", 30)
	roomQueueLabel.AnchorPoint = Vector2.new(0.5, 0)
	roomQueueLabel.Position = UDim2.new(0.5, 0, 0, 96)
	roomQueueLabel.Size = UDim2.fromOffset(300, 26)
	roomQueueLabel.TextXAlignment = Enum.TextXAlignment.Center
	roomQueueLabel.TextColor3 = Color3.fromRGB(255, 218, 73)
	roomQueueLabel.TextSize = 15
	roomQueueLabel.Visible = false

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
	local finishBanner,finishBannerScale,finishPlace=ResultView.banner(screenGui)
	local finishMissLabel = Instance.new("TextLabel")
	finishMissLabel.Name = "FinishMissWarning"
	finishMissLabel.AnchorPoint = Vector2.new(0.5, 0)
	finishMissLabel.Position = UDim2.new(0.5, 0, 0, 48)
	finishMissLabel.Size = UDim2.fromOffset(400, 32)
	finishMissLabel.BackgroundColor3 = Color3.fromRGB(180, 25, 25)
	finishMissLabel.BackgroundTransparency = 0.12
	finishMissLabel.BorderSizePixel = 0
	finishMissLabel.Font = Enum.Font.GothamBold
	finishMissLabel.Text = "⚠️ CHECKPOINT MISSED · TURN BACK AND CLEAR IT ⚠️"
	finishMissLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
	finishMissLabel.TextSize = 14
	finishMissLabel.Visible = false
	finishMissLabel.Parent = screenGui
	addCorner(finishMissLabel, 8)
	local finishMissStroke = Instance.new("UIStroke")
	finishMissStroke.Name = "Stroke"
	finishMissStroke.Color = Color3.fromRGB(255, 220, 60)
	finishMissStroke.Thickness = 1.5
	finishMissStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	finishMissStroke.Parent = finishMissLabel

	local resultsPanel = Instance.new("Frame")
	resultsPanel.Name = "Results"
	resultsPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	resultsPanel.Position = UDim2.fromScale(0.5, 0.5)
	resultsPanel.Size = UDim2.fromOffset(370, 340)
	resultsPanel.BackgroundColor3 = Color3.fromRGB(16, 19, 24)
	resultsPanel.BackgroundTransparency = 0.40
	resultsPanel.BorderSizePixel = 0
	resultsPanel.Visible = false
	resultsPanel.Parent = screenGui
	ResultView.panel(resultsPanel)
	local resultsScale = Instance.new("UIScale")
	resultsScale.Name = "FinishRevealScale"
	resultsScale.Scale = 1
	resultsScale.Parent = resultsPanel
	local resultRevealTween = nil
	local function stopResultReveal()
		if resultRevealTween then resultRevealTween:Cancel();resultRevealTween=nil end
		resultsScale.Scale = 1
	end
	screenGui.Destroying:Connect(stopResultReveal)

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
	local lapRows = {}
	for lap = 1, 3 do
		local row = Instance.new("Frame")
		row.Name = "Lap" .. lap .. "Row"
		row.LayoutOrder = lap + 2
		row.Size = UDim2.new(1, -20, 0, 27)
		row.BackgroundTransparency = 1
		row.Parent = resultsPanel
		local function cell(name, x, width, alignment)
			local label = createLabel(row, name, 0)
			label.Position = UDim2.new(x, 0, 0, 0)
			label.Size = UDim2.new(width, 0, 1, 0)
			label.TextSize = 17
			label.TextXAlignment = alignment
			return label
		end
		lapRows[lap] = {
			frame = row,
			name = cell("LapName", 0, 0.22, Enum.TextXAlignment.Left),
			time = cell("LapTime", 0.22, 0.40, Enum.TextXAlignment.Center),
			delta = cell("LapDelta", 0.62, 0.38, Enum.TextXAlignment.Right),
		}
	end
	local resultsBestLabel = createLabel(resultsPanel, "Best", 6)
	resultsBestLabel.TextXAlignment = Enum.TextXAlignment.Center
	local recordSaveLabel = createLabel(resultsPanel, "RecordSave", 7)
	recordSaveLabel.TextXAlignment = Enum.TextXAlignment.Center
	recordSaveLabel.Size = UDim2.new(1, -20, 0, 18)
	recordSaveLabel.TextSize = 13
	recordSaveLabel.Visible = false

	local rematchButton = Instance.new("TextButton")
	rematchButton.Name = "Rematch"
	rematchButton.LayoutOrder = 8
	rematchButton.Size = UDim2.fromOffset(180, 44)
	rematchButton.BackgroundColor3 = Color3.fromRGB(45, 130, 235)
	rematchButton.BorderSizePixel = 0
	rematchButton.Font = Enum.Font.GothamBold
	rematchButton.Text = "REMATCH"
	rematchButton.TextColor3 = Color3.new(1, 1, 1)
	rematchButton.TextSize = 20
	rematchButton.TextWrapped = true
	rematchButton.Parent = resultsPanel
	ResultView.button(rematchButton)
	rematchButton.Activated:Connect(function()
		if rematchButton.Active then remoteEvent:FireServer("Rematch") end
	end)

	local garageButton = Instance.new("TextButton")
	garageButton.Name = "ReturnGarage"
	garageButton.LayoutOrder = 9
	garageButton.Size = UDim2.fromOffset(180, 44)
	garageButton.BackgroundColor3 = Color3.fromRGB(75, 80, 90)
	garageButton.BorderSizePixel = 0
	garageButton.Font = Enum.Font.GothamBold
	garageButton.Text = "LOBBY"
	garageButton.TextColor3 = Color3.new(1, 1, 1)
	garageButton.TextSize = 20
	garageButton.Parent = resultsPanel
	ResultView.button(garageButton)
	garageButton.Activated:Connect(function()
		remoteEvent:FireServer("ReturnGarage")
	end)

	local function botSnapshots()
		local folder=ReplicatedStorage:FindFirstChild("KDMBotRacers")
		return if folder then folder:GetChildren() else {}
	end
	local resultCache = RaceResultsCache.new()
	local standingsRows = {}
	local standings = Instance.new("Frame")
	standings.Name = "Standings"
	standings.LayoutOrder = 3
	standings.BackgroundTransparency = 1
	standings.Visible = false
	standings.Parent = resultsPanel
	for index=1,4 do
		local row=Instance.new("Frame")
		row.Name="Racer"..index
		row.BorderSizePixel=0
		row.BackgroundTransparency=.35
		row.Parent=standings
		addCorner(row,4)
		local place=createLabel(row,"Place",0)
		local name=createLabel(row,"RacerName",0)
		local total=createLabel(row,"TotalTime",0)
		local laps=createLabel(row,"Laps",0)
		place.Position=UDim2.fromOffset(4,0); place.Size=UDim2.fromOffset(22,20)
		name.Position=UDim2.fromOffset(28,0); name.Size=UDim2.new(1,-112,0,20)
		name.TextTruncate=Enum.TextTruncate.AtEnd; name.TextWrapped=false
		total.Position=UDim2.new(1,-86,0,0); total.Size=UDim2.fromOffset(82,20)
		total.TextXAlignment=Enum.TextXAlignment.Right
		laps.Position=UDim2.fromOffset(28,20); laps.Size=UDim2.new(1,-32,0,18)
		standingsRows[index]={frame=row,place=place,name=name,total=total,laps=laps}
	end
	local resultStatus=createLabel(resultsPanel,"StandingsStatus",2)
	resultStatus.Size=UDim2.new(1,0,0,16)
	resultStatus.TextSize=11
	resultStatus.TextXAlignment=Enum.TextXAlignment.Center
	resultStatus.Visible=false
	local resultActions=Instance.new("Frame")
	resultActions.Name="ResultActions"
	resultActions.LayoutOrder=8
	resultActions.BackgroundTransparency=1
	resultActions.Visible=false
	resultActions.Parent=resultsPanel

	local lastRacingLayoutInputs=nil
	local function applyResponsiveLayout()
		local camera = Workspace.CurrentCamera
		local viewportSize = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		-- Touch-capable tablets still need the safe mobile LAP/item geometry
		-- after keyboard/mouse input changes the preferred input classification.
		local mobile = Input.isTouchPreferred() or UserInputService.TouchEnabled
		-- Bot polling and rank replication call updateHud frequently. During a
		-- race, unchanged geometry must not rewrite the complete responsive HUD.
		if player:GetAttribute("RaceState")=="RACING" then
			local inputs={viewportSize,screenGui.AbsoluteSize,screenGui.AbsolutePosition,
				mobileTopGui.AbsoluteSize,mobileTopGui.AbsolutePosition,GuiService.TopbarInset,
				mobile,UserInputService.TouchEnabled,offTrackLabel.Visible,raceEndLabel.Visible,
				quitRow.Visible,roomQueueLabel.Visible,availableTotal,availableHasBot,
				player:GetAttribute("RaceMatchStatus") or false,player:GetAttribute("RaceSessionComplete") or false,
				player:GetAttribute("RaceParticipantCount") or 1,player:GetAttribute("RaceHostUserId") or 0,
				player:GetAttribute("RaceEndCountdownActive") or false,player:GetAttribute("RaceTotalLaps") or 3}
			for _,row in availabilityRows do
				table.insert(inputs,row.label.Text);table.insert(inputs,row.userId or false)
				table.insert(inputs,row.botId or false);table.insert(inputs,row.botAction or false)
			end
			local same=lastRacingLayoutInputs~=nil and #inputs==#lastRacingLayoutInputs
			if same then for i,v in inputs do if lastRacingLayoutInputs[i]~=v then same=false;break end end end
			if same then return end
			lastRacingLayoutInputs=inputs
		else lastRacingLayoutInputs=nil end
		local phoneMap = mobile and screenGui.AbsoluteSize.X > screenGui.AbsoluteSize.Y
			and screenGui.AbsoluteSize.Y < 500 and player:GetAttribute("RaceState") == "RACING"
		miniMapPanel.Parent = if phoneMap then mobileTopGui else screenGui
		miniMapPanel.BackgroundTransparency = if phoneMap then .40 else .10
		roomQueueLabel.AnchorPoint = Vector2.new(0.5, 0)
		roomQueueLabel.Position = UDim2.new(0.5, 0, 0, 96)
		roomQueueLabel.Size = UDim2.fromOffset(300, 26)
		roomQueueLabel.TextXAlignment = Enum.TextXAlignment.Center
		roomQueueLabel.TextSize = 15
		local touchTarget = mobile or UserInputService.TouchEnabled
		local speedParent = if mobile then mobileTopGui else screenGui
		if speedPanel.Parent ~= speedParent then speedPanel.Parent = speedParent end
		speedPanel.BackgroundTransparency = if mobile then 0.30 else 0.15
		speedTrack.BackgroundColor3 = if mobile then Color3.fromRGB(92, 106, 124) else Color3.fromRGB(59, 68, 81)
		speedOutline.Enabled = mobile
		local compact = touchTarget or (viewportSize.Y > 0 and viewportSize.Y <= 650)
		if touchTarget then screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		else screenGui.IgnoreGuiInset = not compact end
		local quitHeight = if touchTarget then 40 else 24
		quitRow.Parent=frame
		quitRow.Position=UDim2.fromOffset(0,0)
		quitRow.Size = UDim2.new(1, -20, 0, quitHeight)
		quitButton.Size = UDim2.fromOffset(if touchTarget then 64 else 56, if touchTarget then 40 else 23)
		quitButton.TextSize = if touchTarget then 14 else 11
		miniMapPanel.Visible = player:GetAttribute("RaceState") == "COUNTDOWN" or player:GetAttribute("RaceState") == "RACING"
			or (player:GetAttribute("RaceState") == "FINISHED"
			and player:GetAttribute("RaceMatchStatus") == "RACING"
			and getNumberAttribute(player, "RaceParticipantCount", 1) >= 2
			and player:GetAttribute("RaceSessionComplete") ~= true)
		if compact then
			local lapWidth = math.min(220, math.max(175, (viewportSize.X - 160) * 0.5 - 24))
			frame.Position = UDim2.fromOffset(12, 8)
			frame.Size = UDim2.fromOffset(lapWidth, (if offTrackLabel.Visible then 116 else 96)
				+ (if raceEndLabel.Visible then 20 else 0) + (if quitRow.Visible then quitHeight else 0))
			padding.PaddingTop = UDim.new(0, 6)
			padding.PaddingBottom = UDim.new(0, 6)
			padding.PaddingLeft = UDim.new(0, 8)
			padding.PaddingRight = UDim.new(0, 8)
			lapLabel.Size = UDim2.new(1, -16, 0, 25)
			lapLabel.TextSize = 20
			for _, label in { checkpointLabel, bestLabel, offTrackLabel, raceEndLabel } do
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
			finishBanner.Size = UDim2.fromOffset(math.min(320, viewportSize.X - 32), 60)
			local resultArea = if mobile and screenGui.AbsoluteSize.Y > 0 then screenGui.AbsoluteSize else viewportSize
			local resultState = player:GetAttribute("RaceState")
			local resultLaps = getNumberAttribute(player, "RaceTotalLaps", RaceConfig.TOTAL_LAPS)
			local targetHeight = if resultState == "DNF" then 185 elseif resultLaps == 1 then 240 else 270
			if resultState == "FINISHED" and player:GetAttribute("RaceRecordSaveState") ~= nil
				and player:GetAttribute("RaceRecordSaveState") ~= "NONE" then targetHeight += 22 end
			if resultLaps == 3 then targetHeight += 22 end
			if player:GetAttribute('RaceMoneyState') and player:GetAttribute('RaceMoneyState')~='NONE' then targetHeight+=18 end
			local resultHeight = math.min(targetHeight, resultArea.Y - 16)
			local tight = resultArea.Y < 280
			local splitResult = mobile and resultState == "FINISHED" and resultArea.X >= 720
			local resultWidth = if splitResult then math.min(
				if resultLaps == 1 then 250 else 285,
				resultArea.X * (if resultLaps == 1 then 0.36 else 0.39))
				else math.min(330, resultArea.X - 24)
			resultsPanel.Size = UDim2.fromOffset(resultWidth, resultHeight)
			resultsLayout.Padding = UDim.new(0, if tight then 2 else 4)
			resultsPadding.PaddingTop = UDim.new(0, if tight then 7 else 10)
			resultsPadding.PaddingBottom = resultsPadding.PaddingTop
			resultsPadding.PaddingLeft = UDim.new(0, 12)
			resultsPadding.PaddingRight = resultsPadding.PaddingLeft
			finishLabel.Size = UDim2.new(1, 0, 0, if tight then 23 else 27)
			finishLabel.TextSize = if tight then 22 else 25
			totalLabel.Size = UDim2.new(1, -20, 0, if tight then 20 else 22)
			totalLabel.TextSize = if tight then 15 else 17
			resultsBestLabel.Size = UDim2.new(1, -20, 0, if tight then 20 else 24)
			resultsBestLabel.TextSize = if tight then 14 else 16
			for _, row in lapRows do
				row.frame.Size = UDim2.new(1, -20, 0, if tight then 18 else 22)
				for _, label in { row.name, row.time, row.delta } do label.TextSize = if tight then 13 else 15 end
			end
			rematchButton.Size = UDim2.fromOffset(160, if tight then 31 else 34)
			rematchButton.TextSize = if tight then 17 else 18
			garageButton.Size = rematchButton.Size
			garageButton.TextSize = rematchButton.TextSize
		else
			frame.Position = UDim2.fromOffset(24, 118)
			frame.Size = UDim2.fromOffset(260, (if offTrackLabel.Visible then 139 else 112)
				+ (if raceEndLabel.Visible then 23 else 0) + (if quitRow.Visible then quitHeight else 0))
			padding.PaddingTop = UDim.new(0, 8)
			padding.PaddingBottom = UDim.new(0, 8)
			padding.PaddingLeft = UDim.new(0, 10)
			padding.PaddingRight = UDim.new(0, 10)
			lapLabel.Size = UDim2.new(1, -20, 0, 30)
			lapLabel.TextSize = 23
			for _, label in { checkpointLabel, bestLabel, offTrackLabel, raceEndLabel } do
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
			finishBanner.Size = UDim2.fromOffset(400, 82)
			local resultState = player:GetAttribute("RaceState")
			local resultLaps = getNumberAttribute(player, "RaceTotalLaps", RaceConfig.TOTAL_LAPS)
			resultsPanel.Size = UDim2.fromOffset(370, if resultState == "DNF" then 220 elseif resultLaps == 1 then 280 else 340)
			if resultState == "FINISHED" and player:GetAttribute("RaceRecordSaveState") ~= nil
				and player:GetAttribute("RaceRecordSaveState") ~= "NONE" then
				resultsPanel.Size = UDim2.fromOffset(370, 356 + 27 * resultLaps)
			end
			resultsLayout.Padding = UDim.new(0, 6)
			resultsPadding.PaddingTop = UDim.new(0, 14)
			resultsPadding.PaddingBottom = UDim.new(0, 14)
			resultsPadding.PaddingLeft = UDim.new(0, 20)
			resultsPadding.PaddingRight = UDim.new(0, 20)
			finishLabel.Size = UDim2.new(1, 0, 0, 36)
			finishLabel.TextSize = 30
			totalLabel.Size = UDim2.new(1, -20, 0, 26)
			totalLabel.TextSize = 18
			resultsBestLabel.Size = UDim2.new(1, -20, 0, 26)
			resultsBestLabel.TextSize = 18
			for _, row in lapRows do
				row.frame.Size = UDim2.new(1, -20, 0, 27)
				for _, label in { row.name, row.time, row.delta } do label.TextSize = 17 end
			end
			rematchButton.Size = UDim2.fromOffset(180, 40)
			rematchButton.TextSize = 20
			garageButton.Size = rematchButton.Size
			garageButton.TextSize = 20
		end
		local compositionWidth = if mobile and screenGui.AbsoluteSize.X > 0 then screenGui.AbsoluteSize.X else viewportSize.X
		local finished = player:GetAttribute("RaceState") == "FINISHED"
		local mobileSplit = mobile and finished and compositionWidth >= 720
		resultsPanel.AnchorPoint = if mobileSplit then Vector2.new(0, 0.5) else Vector2.new(0.5, 0.5)
		resultsPanel.Position = if mobileSplit then UDim2.new(0, 14, 0.52, 0)
			elseif finished and not mobile and compositionWidth >= 720 then UDim2.fromScale(0.26, 0.52)
			else UDim2.fromScale(0.5, 0.5)
		if mobile then
			local safeSize = screenGui.AbsoluteSize
			-- GUI bounds are stable even while emulator Camera.ViewportSize is settling.
			MobileView.setViewportBottomInset(mobileTopGui.AbsoluteSize.Y,
				safeSize.Y+screenGui.AbsolutePosition.Y-mobileTopGui.AbsolutePosition.Y)
			local l = MobileView.layout(safeSize)
			-- Short notch-safe landscape needs a compact LAP lane above the left loadout.
			-- Preserve every status and the full 40px Quit target.
			local shortLap = safeSize.X >= 600 and safeSize.Y < 360
			-- Keep Quit below the statistics in the same left lane as the items.
			-- The former short-screen side position extended beyond the loadout.
			local items = MobileView.itemLayout(safeSize, 4)
			quitRow.Parent = frame
			quitRow.Size = UDim2.fromOffset(math.min(150, items.width - 16), quitHeight)
			-- Compact outlined Quit sits beside LAP rows, freeing the second item row.
			quitRow.Parent=screenGui
			quitRow.Position=frame.Position+UDim2.fromOffset(110,0)
			quitRow.Size=UDim2.fromOffset(64,40)
			local titleHeight, lineHeight = if shortLap then 16 else 25, if shortLap then 10 else 20
			padding.PaddingTop = UDim.new(0, if shortLap then 0 else 6)
			padding.PaddingBottom = UDim.new(0, if shortLap then 0 elseif quitRow.Visible then 4 else 6)
			lapLabel.Size = UDim2.new(1, -16, 0, titleHeight)
			for _, line in { checkpointLabel, bestLabel, offTrackLabel, raceEndLabel } do
				line.Size = UDim2.new(1, -16, 0, lineHeight)
			end
			local lapWidth = math.min(170, safeSize.X*0.28)
			frame.Size = UDim2.fromOffset(lapWidth,
				padding.PaddingTop.Offset + titleHeight + lineHeight*2
				+ (if offTrackLabel.Visible then lineHeight else 0)
				+ (if raceEndLabel.Visible then lineHeight else 0)
				+ padding.PaddingBottom.Offset)
			-- TopbarInset is the dynamic space clear of Roblox controls and cutouts.
			-- Keep the speed readout centered when it fits, or shift it into that space.
			local speedPosition = MobileView.speedTopbarPosition(mobileTopGui.AbsoluteSize,
				GuiService.TopbarInset, 160, l.speedHeight)
			speedPanel.Position = UDim2.fromOffset(speedPosition.X, speedPosition.Y)
			speedPanel.Size = UDim2.fromOffset(160, l.speedHeight)
			speedTrack.Position = UDim2.fromOffset(10, 44)
			-- Top HUD stays clear of both thumb zones; desktop geometry is unchanged.
			lapLabel.TextSize = if shortLap then 16 else 18
			checkpointLabel.TextSize = if shortLap then 10 else 12
			bestLabel.TextSize = if shortLap then 10 else 12
			offTrackLabel.TextSize = if shortLap then 10 else 11
			raceEndLabel.TextSize = if shortLap then 10 else 11
			miniMapPanel.AnchorPoint = Vector2.new(1, 0)
			miniMapPanel.Position = UDim2.new(1, -12, 0, 8)
			miniMapSize.MinSize = Vector2.zero
			miniMapPanel.Size = UDim2.fromOffset(100, 100)
			if roomQueueLabel.Visible and player:GetAttribute("RaceState") == "RACING" then
				-- Share the minimap's safe right edge, keeping Room status off the road.
				roomQueueLabel.AnchorPoint = Vector2.new(1, 0)
				roomQueueLabel.Position = UDim2.new(1, -12, 0, 8)
				roomQueueLabel.Size = UDim2.fromOffset(180, 22)
				roomQueueLabel.TextXAlignment = Enum.TextXAlignment.Right
				roomQueueLabel.TextSize = 13
				miniMapPanel.Position = UDim2.new(1, -12, 0, 36)
			end
			if safeSize.X < 450 then
				miniMapPanel.Visible = false
			end
			if safeSize.X > safeSize.Y and safeSize.Y < 500
				and player:GetAttribute("RaceState") == "RACING" then
				local top = speedPanel.AbsolutePosition.Y-screenGui.AbsolutePosition.Y
				local map = MobileView.minimapLayout(safeSize,top)
				local origin = screenGui.AbsolutePosition-mobileTopGui.AbsolutePosition
				miniMapPanel.Position = UDim2.fromOffset(origin.X+map.x+map.side,origin.Y+map.y)
				miniMapPanel.Size = UDim2.fromOffset(map.side,map.side)
				if roomQueueLabel.Visible and player:GetAttribute("RaceState") == "RACING" then
					roomQueueLabel.Position = UDim2.fromOffset(map.x+map.side,map.y+map.side+6)
					roomQueueLabel.Size = UDim2.fromOffset(118,22)
					roomQueueLabel.TextSize = 11
				end
			end
		end
		local waitingLobby = player:GetAttribute("RaceState") == "PRE_RACE"
			and player:GetAttribute("RaceMatchStatus") == "WAITING"
		local shortLobby = viewportSize.Y < 320
		local inviteLayout = nil
		if mobile and screenGui.AbsoluteSize.X > screenGui.AbsoluteSize.Y then
			local safeSize = screenGui.AbsoluteSize
			local mapWidth, mapHeight = miniMapPanel.Size.X.Offset, miniMapPanel.Size.Y.Offset
			local mapOrigin = miniMapPanel.AbsolutePosition-screenGui.AbsolutePosition
			inviteLayout = MobileView.inviteLayout(safeSize,mapOrigin.X,mapOrigin.Y,
				mapWidth,mapHeight,roomQueueLabel.Visible)
			racingInviteToggle.Position = UDim2.fromOffset(inviteLayout.x + inviteLayout.width, inviteLayout.y)
			racingInviteToggle.Size = UDim2.fromOffset(inviteLayout.width, inviteLayout.height)
			if player:GetAttribute("RaceState") == "RACING" then
				roomQueueLabel.AnchorPoint=Vector2.zero
				roomQueueLabel.Position=UDim2.fromOffset(inviteLayout.x,inviteLayout.statusY)
				roomQueueLabel.Size=UDim2.fromOffset(180,22)
				roomQueueLabel.TextXAlignment=Enum.TextXAlignment.Left
			end
		else
			racingInviteToggle.Position = UDim2.new(1, -12, 0, 132)
			racingInviteToggle.Size = UDim2.fromOffset(118, 32)
		end
		local racingPanel = inviteLayout and player:GetAttribute("RaceState") == "RACING"
		availabilityPanel.AnchorPoint = if racingPanel then Vector2.zero else Vector2.new(.5,1)
		availabilityPanel.Position = if racingPanel then UDim2.fromOffset(inviteLayout.panelX, inviteLayout.panelY)
			else UDim2.new(.5,0,.94,-96)
		local shownRows = math.max(1, math.min(availableTotal, if racingPanel then inviteLayout.rows elseif shortLobby then 2 else 4))
		local panelHeight = roomRacerRows.layout(1,shownRows,availableHasBot).panelHeight
		availabilityPanel.Size = UDim2.fromOffset(252,panelHeight)
		if racingPanel then availabilityPanel.Size = UDim2.fromOffset(inviteLayout.panelWidth,panelHeight) end
		for index, row in availabilityRows do
			local rowLayout = roomRacerRows.layout(index,shownRows,availableHasBot)
			row.label.Position = UDim2.fromOffset(8,rowLayout.y)
			row.label.Size = UDim2.new(1,if row.botId and not row.botAction then -16 else -88,0,rowLayout.height)
			row.button.Position = UDim2.new(1,-76,0,rowLayout.y)
			row.button.Size = UDim2.fromOffset(68,rowLayout.height)
			if index > shownRows then
				row.label.Visible = false
				row.button.Visible = false
			else
				row.label.Visible = row.label.Text ~= ""
				row.button.Visible = (row.userId ~= nil or row.botAction ~= nil)
					and player:GetAttribute("RaceHostUserId") == player.UserId
			end
		end
		countdownLabel.Position = UDim2.fromScale(0.5, if waitingLobby then (if shortLobby then 0.15 else 0.22) else 0.5)
		if waitingLobby then countdownLabel.Size = UDim2.fromOffset(math.min(320, viewportSize.X - 24), 50) end
		if player:GetAttribute("RaceEndCountdownActive") == true
			and player:GetAttribute("RaceSessionComplete") ~= true then rematchButton.TextSize = 14 end
		MobileView.layoutSteeringWheel(wheelClip, steeringDisplay, steeringRingScale,
			if mobile then screenGui.AbsoluteSize else viewportSize, mobile)
		local multiplayer = getNumberAttribute(player,"RaceParticipantCount",1)>=2
			and (player:GetAttribute("RaceState")=="FINISHED" or player:GetAttribute("RaceState")=="DNF")
		resultActions.Visible=multiplayer
		local actionParent=if multiplayer then resultActions else resultsPanel
		rematchButton.Parent=actionParent; garageButton.Parent=actionParent
		if multiplayer then
			local safe=screenGui.AbsoluteSize
			local width=if mobile then math.min(330,safe.X*.45) else 390
			local saving = player:GetAttribute("RaceState") == "FINISHED" and player:GetAttribute("RaceRecordSaveState") ~= nil
				and player:GetAttribute("RaceRecordSaveState") ~= "NONE"
			local panelHeight=(if mobile then 272 else 304)+(if saving then 22 else 0)
			if player:GetAttribute('RaceMoneyState') and player:GetAttribute('RaceMoneyState')~='NONE' then panelHeight+=18 end
			if saving then panelHeight=math.min(panelHeight,safe.Y-16) end
			local rowHeight=if mobile then 40 else 48
			if saving then rowHeight=math.min(rowHeight,math.floor((panelHeight-134)/4)) end
			resultsPanel.Size=UDim2.fromOffset(width,panelHeight)
			resultsPanel.AnchorPoint=Vector2.new(0,.5)
			resultsPanel.Position=if mobile then UDim2.new(0,14,.5,0) else UDim2.new(.08,0,.5,0)
			resultsLayout.Padding=UDim.new(0,4)
			resultsPadding.PaddingTop=UDim.new(0,8);resultsPadding.PaddingBottom=UDim.new(0,8)
			resultsPadding.PaddingLeft=UDim.new(0,10);resultsPadding.PaddingRight=UDim.new(0,10)
			finishLabel.Size=UDim2.new(1,0,0,24);finishLabel.TextSize=if mobile then 20 else 24
			standings.Size=UDim2.new(1,0,0,rowHeight*4)
			for index,row in standingsRows do
				row.frame.Position=UDim2.fromOffset(0,(index-1)*rowHeight)
				row.frame.Size=UDim2.new(1,0,0,rowHeight-2)
				for _,label in {row.place,row.name,row.total} do label.TextSize=if mobile then 12 else 15 end
				row.laps.TextSize=if mobile then 10 else 12
			end
			resultActions.Size=UDim2.new(1,0,0,44)
			rematchButton.AnchorPoint=Vector2.zero;garageButton.AnchorPoint=Vector2.zero
			rematchButton.Position=UDim2.fromOffset(0,0);garageButton.Position=UDim2.new(.5,4,0,0)
			rematchButton.Size=UDim2.new(.5,-4,0,44);garageButton.Size=rematchButton.Size
			rematchButton.TextSize=if mobile then 12 else 16;garageButton.TextSize=rematchButton.TextSize
			if mobile and roomQueueLabel.Visible then
				roomQueueLabel.AnchorPoint=Vector2.new(1,0)
				roomQueueLabel.Position=UDim2.new(1,-12,0,8)
				roomQueueLabel.Size=UDim2.fromOffset(math.min(280,safe.X-width-40),22)
				roomQueueLabel.TextSize=11
			end
		end
  local resultArea=screenGui.AbsoluteSize
  if resultArea.X>=720 and resultArea.X>resultArea.Y then
   resultsPanel.AnchorPoint=Vector2.new(0,.5)
   resultsPanel.Position=UDim2.new(0,12,.5,0)
  end

	end

	local goDisplaySerial = 0
	local finalLapSerial = 0
	local finishBannerSerial = 0
	local finalLapShown = false
	local lastNoticeCompleted = getNumberAttribute(player, "RaceCompletedLaps", 0)
	local displayedRaceState = player:GetAttribute("RaceState")
	local displayedCountdown = getNumberAttribute(player, "RaceCountdown", 0)
	local displayedLap = getNumberAttribute(player, "RaceCurrentLap", 1)
	local displayedFinishMissSerial = getNumberAttribute(player, "RaceFinishMissedSerial", 0)
	local finishMissDisplayToken = 0
	local function pulse(label: TextLabel, scale: UIScale)
		scale.Scale = 1.3
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0.3
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	updateHud = function(cause, nested)
		local eventStarted=if performanceMonitor and performanceMonitor.active() and player:GetAttribute('RaceState')=='RACING' then os.clock() else nil
		local collectStarted=eventStarted
		local resultEntries=resultCache:collect(player,Players:GetPlayers(),botSnapshots())
		if collectStarted then performanceMonitor.metric('eventCollect',(os.clock()-collectStarted)*1000) end
		local raceState = player:GetAttribute("RaceState")
		local returningToHub = player:GetAttribute("KDMRoutePending") == "HUB_RETURN"
		routeOverlay.Visible = returningToHub
		quitRow.Visible = raceState == "RACING" and not returningToHub
		if raceState ~= "RACING" or returningToHub then quitOverlay.Visible = false end
		local finishMissSerial = getNumberAttribute(player, "RaceFinishMissedSerial", 0)
		local missedCheckpoint = getNumberAttribute(player, "RaceCheckpointMissed", 0)
		local shouldWarnMissed = raceState == "RACING" and (missedCheckpoint > 0 or finishMissSerial > displayedFinishMissSerial)
		if shouldWarnMissed then
			finishMissLabel.Visible = true
			if missedCheckpoint > 0 then
				finishMissLabel.Text = string.format("⚠️ CHECKPOINT [%d] MISSED · TURN BACK AND CLEAR IT ⚠️", missedCheckpoint)
			else
				finishMissLabel.Text = "⚠️ FINISH LINE MISSED · RETURN TO FINISH GATE ⚠️"
			end
			local flashPhase = math.floor(os.clock() * 3.5) % 2
			finishMissLabel.BackgroundColor3 = if flashPhase == 0 then Color3.fromRGB(180, 25, 25) else Color3.fromRGB(48, 16, 16)
			finishMissLabel.TextColor3 = if flashPhase == 0 then Color3.fromRGB(255, 230, 80) else Color3.fromRGB(255, 120, 120)
		else
			finishMissLabel.Visible = false
		end
		displayedFinishMissSerial = finishMissSerial
		local previousRaceState = displayedRaceState
		displayedRaceState = raceState
		local currentLap = getNumberAttribute(player, "RaceCurrentLap", 1)
		local completedLaps = getNumberAttribute(player, "RaceCompletedLaps", 0)
		local totalLaps = getNumberAttribute(player, "RaceTotalLaps", RaceConfig.TOTAL_LAPS)
		local nextCheckpoint = getNumberAttribute(player, "RaceNextCheckpoint", 1)
		local checkpointCount = getNumberAttribute(player, "RaceCheckpointCount", 6)
		local bestLap = getNumberAttribute(player, "RaceBestLapTime", 0)
		local bestLapNumber = getNumberAttribute(player, "RaceBestLapNumber", 0)
		local finalTime = getNumberAttribute(player, "RaceFinalTime", 0)
		local offTrackRemaining = getNumberAttribute(player, "RaceOffTrackRemaining", 0)
		local raceEndActive = player:GetAttribute("RaceEndCountdownActive") == true
		local raceEndRemaining = getNumberAttribute(player, "RaceEndCountdownRemaining", 0)
		local participantCount = getNumberAttribute(player, "RaceParticipantCount", 1)
		local position = getNumberAttribute(player, "RacePosition", 1)
		local matchStatus = player:GetAttribute("RaceMatchStatus")
		local sessionComplete = player:GetAttribute("RaceSessionComplete") == true
		local rematchReady = player:GetAttribute("RaceRematchReady") == true
		local driver = DriverCatalog.Entries[player:GetAttribute("SelectedDriverId")]
		local kartSelection = KartCatalog.Entries[player:GetAttribute("SelectedKartId")]
		local track = TrackCatalog.Entries[player:GetAttribute("SelectedTrackId")]
		showMapForTrack(track or TrackCatalog.Entries[TrackCatalog.DefaultId])
		frame.Visible = raceState == "COUNTDOWN" or raceState == "RACING"
		speedPanel.Visible = raceState == "COUNTDOWN" or raceState == "RACING"
		steeringDisplay.Visible = speedPanel.Visible
		positionLabel.Visible = speedPanel.Visible and participantCount >= 2
		positionLabel.Text = string.format("POS %d/%d", position, participantCount)
		miniMapPanel.Visible = speedPanel.Visible or (raceState == "FINISHED" and matchStatus == "RACING"
			and participantCount >= 2 and not sessionComplete)
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
		raceEndLabel.Visible = raceState == "RACING" and raceEndActive
		raceEndLabel.Text = string.format("RACE ENDS IN %d", raceEndRemaining)
		frame.Size = UDim2.fromOffset(260, (if offTrackLabel.Visible then 139 else 112)
			+ (if raceEndLabel.Visible then 23 else 0) + (if quitRow.Visible then quitRow.Size.Y.Offset else 0))

		resultsPanel.Visible = (raceState == "FINISHED" or raceState == "DNF") and not returningToHub
		if not resultsPanel.Visible then
			stopResultReveal()
		elseif previousRaceState ~= raceState then
			stopResultReveal()
			resultsScale.Scale = FinishPresentation.REVEAL_SCALE
			resultRevealTween = TweenService:Create(resultsScale,
				TweenInfo.new(FinishPresentation.REVEAL_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale=1})
			resultRevealTween:Play()
		end
		local routeError = player:GetAttribute("RaceEntryError")
		garageButton.Text = if Workspace:GetAttribute("KDMServerRole") == "RACE"
			and type(routeError) == "string" and routeError ~= "" then "KDM LOBBY UNAVAILABLE\nRETRY" else (if raceState=='FINISHED' and getNumberAttribute(player,'RaceMoney_firstFinish',0)>0 then "PLAY TOGETHER\nVIA LOBBY" else "LOBBY")
  ResultView.button(garageButton)
		finishLabel.Text = if raceState == "DNF" then "DNF" elseif participantCount >= 2 then string.format("PLACE %d/%d", getNumberAttribute(player, "RaceFinishPosition", position), participantCount) else "FINISHED"
		finishLabel.TextColor3 = Color3.new(1,1,1)
		totalLabel.Text = if raceState == "DNF" then (if player:GetAttribute("RaceDNFReason") == "RACE_TIMEOUT"
			then "RACE TIMEOUT" elseif player:GetAttribute("RaceDNFReason") == "FORFEIT"
			then "FORFEIT" else "OFF TRACK") elseif finalTime > 0 then "TOTAL TIME  " .. RaceResultFormat.time(finalTime) else "TOTAL TIME  --"
		resultsBestLabel.Text = if bestLap > 0 then string.format("BEST LAP %d  -  %s", bestLapNumber, RaceResultFormat.time(bestLap)) else "BEST LAP  --"
		local recordState = player:GetAttribute("RaceRecordSaveState")
		if raceState == "FINISHED" and recordState == "SAVE_CONFIRMED" then
			recordSaveLabel.Text = if player:GetAttribute("RaceRecordNewBestRace") == true then "NEW BEST RACE" else "RECORD SAVED"
		elseif raceState == "FINISHED" and recordState == "SAVE_PENDING" then
			recordSaveLabel.Text = "SAVE PENDING"
		elseif raceState == "FINISHED" and (recordState == "SAVE_FAILED" or recordState == "READ_ONLY") then
			recordSaveLabel.Text = "RECORD SAVE UNCONFIRMED"
		end
		local moneyState=player:GetAttribute('RaceMoneyState')
		if raceState=='FINISHED' and moneyState and moneyState~='NONE' then
			if moneyState=='SAVE_CONFIRMED' then
				recordSaveLabel.Text ..= string.format('\nK$%d · BASE %d + RACE PB %d + LAP PB %d',
					getNumberAttribute(player,'RaceMoney_total',0),getNumberAttribute(player,'RaceMoney_base',0),
					getNumberAttribute(player,'RaceMoney_bestRace',0),getNumberAttribute(player,'RaceMoney_bestLap',0))
    if getNumberAttribute(player,'RaceMoney_firstFinish',0)>0 then
     recordSaveLabel.Text=string.format('EVENT BONUS +K$5,000 · RACE +K$%d\nTOTAL +K$%d · PLAY TOGETHER NEXT!',getNumberAttribute(player,'RaceMoney_total',0)-5000,getNumberAttribute(player,'RaceMoney_total',0))
    end
			else recordSaveLabel.Text ..= '\nK$ PAYMENT UNCONFIRMED' end
		elseif raceState == "DNF" and moneyState == "SAVE_CONFIRMED" then
			recordSaveLabel.Text = string.format("ACTIVE RACER COMPLETION · +K$%d EARNED!", getNumberAttribute(player, "RaceMoney_total", 1500))
		end
		recordSaveLabel.Size=UDim2.new(1,-20,0,if (raceState=='FINISHED' and moneyState and moneyState~='NONE') or (raceState=='DNF' and moneyState=='SAVE_CONFIRMED') then 36 else 18)
		recordSaveLabel.Visible = (raceState == "FINISHED" and (recordState == "SAVE_CONFIRMED" or recordState == "SAVE_PENDING"
			or recordState == "SAVE_FAILED" or recordState == "READ_ONLY")) or (raceState == "DNF" and moneyState == "SAVE_CONFIRMED")
		resultsBestLabel.Visible = raceState == "FINISHED"
		local canRematch = (raceState == "FINISHED" or raceState == "DNF"
			and player:GetAttribute("RaceDNFReason") ~= "FORFEIT")
			and (participantCount < 2 or sessionComplete) and not rematchReady
		rematchButton.Active = canRematch
		ResultView.button(rematchButton)
		rematchButton.Text = if raceEndActive and not sessionComplete and participantCount >= 2 then
			string.format("WAITING FOR RACERS\n0:%02d", raceEndRemaining)
			elseif rematchReady then string.format("READY %d/%d",
			getNumberAttribute(player, "RaceRematchReadyCount", 0), getNumberAttribute(player, "RaceRematchRequiredCount", participantCount))
			elseif participantCount >= 2 and not sessionComplete then "WAITING FOR RACERS" else "REMATCH"
		for lap, row in lapRows do
			local lapTime = getNumberAttribute(player, "RaceLap" .. lap .. "Time", 0)
			row.frame.Visible = raceState == "FINISHED" and lap <= totalLaps and lapTime > 0
			row.name.Text = "LAP " .. lap
			row.time.Text = if lapTime > 0 then RaceResultFormat.time(lapTime) else "--"
			row.delta.Text = if lapTime > 0 and bestLap > 0
				then RaceResultFormat.delta(lapTime, bestLap, lap == bestLapNumber) else ""
			row.delta.TextColor3 = if lap == bestLapNumber then Color3.fromRGB(255, 218, 75) else Color3.fromRGB(225, 238, 245)
		end
		local resultWriteStarted=if eventStarted then os.clock() else nil
		local multiplayerResults=participantCount>=2 and (raceState=="FINISHED" or raceState=="DNF")
		standings.Visible=multiplayerResults
		resultStatus.Visible=multiplayerResults
		resultStatus.Text=if sessionComplete then "FINAL STANDINGS" else "WAITING FOR RACERS"
		if multiplayerResults then
			finishLabel.Text="RACE RESULTS"
			totalLabel.Visible=false;resultsBestLabel.Visible=false
			for _,row in lapRows do row.frame.Visible=false end
			for index,row in standingsRows do
				local entry=resultEntries[index]
				row.frame.Visible=entry~=nil
				if entry then
					row.frame.BackgroundColor3=if entry.userId==player.UserId then Color3.fromRGB(95,165,185) else Color3.fromRGB(70,110,135)
					row.place.Text=if entry.state=="DNF" then "-" else tostring(if entry.finishPosition>0 then entry.finishPosition else entry.racePosition)
					row.place.TextColor3=if entry.finishPosition==1 and entry.state~="DNF" then Color3.fromRGB(255,218,75) else Color3.fromRGB(225,238,245)
					row.name.Text=entry.displayName
					row.total.Text=if entry.state=="DNF" then "DNF" elseif entry.finalTime>0 then RaceResultFormat.time(entry.finalTime) else "RACING"
					local parts={}
					for lap=1,math.clamp(totalLaps,1,3) do
						table.insert(parts,"L"..lap.." "..(if entry.laps[lap]>0 then RaceResultFormat.time(entry.laps[lap]) else "--"))
					end
					row.laps.Text=table.concat(parts," · ")
				end
			end
		else totalLabel.Visible=true end
		if resultWriteStarted then performanceMonitor.metric('eventResults',(os.clock()-resultWriteStarted)*1000) end

		local finishKind, placeText = FinishPresentation.resolve(raceState,
			player:GetAttribute("RaceFinishPosition"), player:GetAttribute("RaceParticipantCount"))
		finishPlace.Text = placeText
		finishPlace.TextColor3 = if finishKind=="PLACED" then Color3.fromRGB(190, 245, 255) else Color3.fromRGB(255, 218, 75)
		if raceState == "FINISHING" and previousRaceState ~= "FINISHING"
			and player:GetAttribute("RaceFinishPhase") ~= "PRESENT" then
			finishBannerSerial += 1
			local serial = finishBannerSerial
			finishBanner.Visible = true
			finishBannerScale.Scale = .88
			TweenService:Create(finishBannerScale, TweenInfo.new(.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale=1.08}):Play()
			finishPlace.TextTransparency = 1
			task.delay(.12, function()
				if serial==finishBannerSerial and finishBanner.Visible then
					TweenService:Create(finishBannerScale, TweenInfo.new(.18), {Scale=1}):Play()
					TweenService:Create(finishPlace, TweenInfo.new(.18), {TextTransparency=0}):Play()
				end
			end)
			task.delay(FinishPresentation.BANNER_SECONDS, function()
				if serial == finishBannerSerial then finishBanner.Visible = false end
			end)
		elseif raceState ~= "FINISHING" or player:GetAttribute("RaceFinishPhase") == "PRESENT" then
			finishBannerSerial += 1
			finishBanner.Visible = false
		end

		local arrivalWaiting = matchStatus == "ARRIVAL" and raceState == "PRE_RACE"
		local lobbyWaiting = matchStatus == "WAITING" and raceState == "PRE_RACE"
		local isHost = player:GetAttribute("RaceHostUserId") == player.UserId
		if not isHost or raceState == "GARAGE" then table.clear(inviteStates) end
		lobbyPanel.Visible = lobbyWaiting or arrivalWaiting
		racingInviteToggle.Visible = roomSnapshot ~= nil and isHost and raceState == "RACING"
		if not racingInviteToggle.Visible then racingInvitesOpen = false end
		availabilityPanel.Visible = (lobbyWaiting or racingInvitesOpen) and TrackCatalog.Entries[player:GetAttribute("SelectedTrackId")] ~= nil
			and TrackCatalog.Entries[player:GetAttribute("SelectedTrackId")].MatchType == "PUBLIC_RACE"
		roomQueueLabel.Visible = roomSnapshot ~= nil and (raceState == "RACING"
			or raceState == "FINISHED" or raceState == "DNF")
		roomQueueLabel.Text = if not roomSnapshot then ""
			elseif raceState == "RACING" then string.format("LOBBY %d/%d  •  NEXT %d",
				roomSnapshot.count, roomSnapshot.maxPlayers, roomSnapshot.queuedCount)
			else string.format("NEXT ROUND  •  %d READY  •  %d QUEUED",
				getNumberAttribute(player, "RaceRematchReadyCount", 0), roomSnapshot.queuedCount)
		if availabilityPanel.Visible then
			local availableCount, available
			local entries
			if roomSnapshot then
				available = roomSnapshot.available or {}
				availableCount = #available
				entries = roomRacerRows.collect(roomSnapshot,isHost,lobbyWaiting and roomSnapshot.state=="WAITING")
			else availableCount, available = GaragePresence.availableSnapshot(Players:GetPlayers(), player, #availabilityRows) end
			availableTotal = if entries then #entries else availableCount
			availableHasBot = lobbyWaiting and entries ~= nil and entries[1] ~= nil and entries[1].botId ~= nil
			availabilityHeading.AutoLocalize=not (roomSnapshot and lobbyWaiting)
			availabilityHeading.TextTruncate=Enum.TextTruncate.AtEnd
			availabilityHeading.Text = if roomSnapshot and lobbyWaiting then roomSnapshot.lobbyTitle or "RACE"
				elseif roomSnapshot then string.format("WAITING NEXT  %d", roomSnapshot.queuedCount)
				elseif isHost then "WAITING FOR RACERS" else "WAITING FOR HOST"
			local botRowCount = if entries and entries[1] and entries[1].botId then 1 else 0
			availabilityTitle.Text = if roomSnapshot then string.format("AVAILABLE RACERS  %d", availableCount+botRowCount)
				else string.format("AVAILABLE IN SERVER  %d", availableCount)
			if isHost and roomSnapshot and roomSnapshot.invitationResponses then
				local responses={}
				for _,response in roomSnapshot.invitationResponses do
					table.insert(responses,response.state..': '..response.name)
				end
				table.sort(responses)
				if #responses>0 then availabilityTitle.Text=table.concat(responses,' · ')end
			end
			for index, row in availabilityRows do
				if entries then
					local entry = entries[index]
					row.userId = entry and entry.userId
					row.botId = entry and entry.botId
					row.botAction = entry and entry.botAction
					row.label.Text = if entry then entry.name..(if entry.botId and not entry.botAction then " · "..entry.status else "")
						elseif index==1 then "No available racers." else ""
					row.label.Visible = entry ~= nil or index==1
					row.button.Visible = entry ~= nil and isHost and (row.userId ~= nil or row.botAction ~= nil)
					continue
				end
				row.botId,row.botAction = nil,nil
				local queued = roomSnapshot and roomSnapshot.queued[index]
				local entry = if queued then nil else available[index - (if roomSnapshot then math.min(#roomSnapshot.queued, #availabilityRows) else 0)]
				row.userId = if entry then entry.userId else nil
				row.label.Text = if queued then string.format("NEXT %s  %s", queued.name, queued.kind)
					elseif entry then entry.name elseif index == 1 and availableCount == 0
						then (if roomSnapshot then "No available racers." else "No available racers in this server.") else ""
				row.label.Visible = queued ~= nil or entry ~= nil or (index == 1 and availableCount == 0)
				row.button.Visible = entry ~= nil and isHost
			end
			if not isHost then table.clear(inviteStates) end
			refreshInviteButtons()
		end
		lobbyStatus.Text = string.format("RACERS  %d / %d", participantCount,
			getNumberAttribute(player, "RaceMaxPlayers", 4))
		autoReadyNotice.Visible=false
		lobbyStart.Active=lobbyWaiting and isHost
		lobbyStart.AutoButtonColor=lobbyStart.Active
		lobbyStart.BackgroundTransparency=if lobbyStart.Active then 0 else .55
		lobbyStart.Visible=lobbyWaiting and isHost
		lobbyStart.Text=if participantCount==1 then "START SOLO" else "START RACE"
		if player:GetAttribute('RaceHostStartRequired')==true then
			local pendingInvites=getNumberAttribute(player,'RaceInvitePendingCount',0)
			if pendingInvites>0 then lobbyStart.Active=false;lobbyStart.Text='WAIT REPLY'end
		elseif player:GetAttribute('RacePublicMatch')==true then
			lobbyStart.Active=false;lobbyStart.Text='AUTO START'
		end
		lobbyLeave.Visible = lobbyWaiting
		lobbyLeave.Text = if participantCount == 1 and isHost then "CANCEL" else "LEAVE"
		lobbyLeave.Position = UDim2.fromOffset(if isHost then 132 else 70, 34)
		lobbyStatus.Text = if arrivalWaiting then string.format("WAITING FOR RACERS  %d / %d",
			participantCount, getNumberAttribute(player, "RaceMaxPlayers", 4)) else lobbyStatus.Text
		if raceState == "PRE_RACE" and matchStatus == "WAITING" then
			countdownLabel.Text = if isHost then "WAITING FOR RACERS" else "WAITING FOR HOST"
			countdownLabel.TextTransparency = 0
			countdownLabel.TextStrokeTransparency = 0.3
			countdownLabel.Visible = not availabilityPanel.Visible
		elseif raceState == "COUNTDOWN" then
			local countdown = getNumberAttribute(player, "RaceCountdown", 0)
			if previousRaceState ~= "COUNTDOWN" then
				goDisplaySerial += 1
				finalLapSerial += 1
				finalLapShown = false
				lastNoticeCompleted = 0
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

		local lapNotice=PresentationState.lapNotice(totalLaps,completedLaps)
		if raceState == "RACING" and previousRaceState == "RACING"
			and completedLaps>lastNoticeCompleted and currentLap==completedLaps+1 and lapNotice then
			lastNoticeCompleted=completedLaps
			finalLapLabel.Text=lapNotice;finalLapLabel.AutoLocalize=false
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
			lastNoticeCompleted=completedLaps
			finalLapSerial += 1
			finalLapLabel.Visible = false
		end
		displayedLap = currentLap
		local layoutStarted=if eventStarted then os.clock() else nil
		applyResponsiveLayout()
		if layoutStarted then performanceMonitor.metric('eventLayout',(os.clock()-layoutStarted)*1000) end
		if eventStarted then performanceMonitor.event((os.clock()-eventStarted)*1000,if type(cause)=='string' then cause else 'OTHER',nested) end
	end
	garageRemote.OnClientEvent:Connect(function(action, data)
		if action == "RoomSnapshot" then
			if roomSnapshot and (roomSnapshot.roomId~=data.roomId or roomSnapshot.hostUserId~=data.hostUserId) then table.clear(inviteStates) end
			roomSnapshot = data
			if data.pendingInvites then
				for userId,state in inviteStates do
					if state.phase=="PENDING" and not data.pendingInvites[tostring(userId)] then inviteStates[userId]=nil end
				end
				for key, expiresAt in data.pendingInvites do
					local userId = tonumber(key)
					local state = userId and inviteStates[userId]
					if userId and type(expiresAt)=="number" and expiresAt>os.time()
						and (not state or state.phase=="FAILED") then
						markInvitePending(userId, {}, expiresAt)
					end
				end
			end
			updateHud()
		elseif (action=="InviteSent" or action=="InviteFailed" or action=="InviteDeclined") and type(data)=="table" then
			local state=inviteStates[data.targetUserId]
			if not state or (data.requestId and state.requestId~=data.requestId) then return end
			if action=="InviteSent" and type(data.expiresAt)=="number" then
				markInvitePending(data.targetUserId, state, data.expiresAt)
			elseif action=="InviteFailed" then state.phase="FAILED"
			else inviteStates[data.targetUserId]=nil end
			refreshInviteButtons()
		end
	end)

	for _, attributeName in {
		'RaceHostStartRequired','RaceInvitePendingCount',
		"RaceSessionId",
		"RaceState",
		"RaceFinishPhase",
		"RaceCountdown",
		"RaceCurrentLap",
		"RaceCompletedLaps",
		"RaceTotalLaps",
		"RaceNextCheckpoint",
		"RaceCheckpointCount",
		"RaceLastLapTime",
		"RaceBestLapTime",
		"RaceBestLapNumber",
		"RaceRecordSaveState",
		"RaceRecordNewPB",
		"RaceRecordNewBestRace",
		"RaceMoneyState",
		"RaceMoney_base",
		"RaceMoney_bestRace",
		"RaceMoney_bestLap",
		"RaceMoney_total",
  "RaceMoney_firstFinish",
		"RaceLap1Time",
		"RaceLap2Time",
		"RaceLap3Time",
		"RaceFinalTime",
		"RaceOffTrackRemaining",
		"RaceFinishMissedSerial",
		"RaceCheckpointMissed",
		"RaceParticipantCount",
		"RaceMaxPlayers",
		"RacePosition",
		"RaceFinishPosition",
		"RaceMatchStatus",
		"RaceItemsReadyCount",
		"RaceItemsRequiredCount",
		"RaceItemsAutoReadySerial",
		"RaceHostUserId",
		"RaceMatchWaitReason",
		"RaceMatchWaitRemaining",
		"RaceSessionComplete",
		"RaceEndCountdownActive",
		"RaceEndCountdownRemaining",
		"RaceDNFReason",
		"RaceRematchReady",
		"RaceRematchReadyCount",
		"RaceRematchRequiredCount",
		"SelectedDriverId",
		"SelectedKartId",
		"SelectedTrackId",
		"RaceEntryError",
		"KDMRoutePending",
	} do
		player:GetAttributeChangedSignal(attributeName):Connect(function() updateHud('LOCAL:'..attributeName,false) end)
	end
	local presenceConnections = {}
	local playerListConnections = {}
	screenGui.Destroying:Connect(function()
		if gaugeController then gaugeController:destroy();gaugeController=nil end
		for _,connections in presenceConnections do for _,binding in connections do binding:Disconnect() end end
		for _,binding in playerListConnections do binding:Disconnect() end
		table.clear(presenceConnections)
	end)
	local function bindAvailablePlayer(other)
		if other == player or presenceConnections[other] then return end
		local connections={}
		for _,attribute in RaceResultsCache.ATTRIBUTES do
			table.insert(connections,other:GetAttributeChangedSignal(attribute):Connect(function() updateHud('RIVAL:'..attribute,false) end))
		end
		presenceConnections[other]=connections
		updateHud()
	end
	for _, other in Players:GetPlayers() do bindAvailablePlayer(other) end
	table.insert(playerListConnections,Players.PlayerAdded:Connect(bindAvailablePlayer))
	table.insert(playerListConnections,Players.PlayerRemoving:Connect(function(other)
		local connection = presenceConnections[other]
		if connection then for _,binding in connection do binding:Disconnect() end; presenceConnections[other] = nil end
		task.defer(updateHud)
	end))

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
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(applyResponsiveLayout)
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyResponsiveLayout)
	bindCamera()
	updateHud()
	local displayedSpeed = 0
	local displayedSteering = 0
	local speedUpdateElapsed = 0
	local botResultElapsed = 0
	local markersActive=false
	local spareRivalKeys={}
	local lastGaugeActive=nil
	local gaugeMode=nil
	local frameStarted,sectionStarted,measuring,frameDt,displayCost=0,0,false,0,0
	local function mark(name)
		if not measuring then return end
		local now=os.clock()
		performanceMonitor.metric(name,(now-sectionStarted)*1000)
		sectionStarted=now
	end
	local function finish(chassis,speed)
		if not performanceMonitor or not performanceMonitor.active() then return end
		mark('otherHud')
		local work=(os.clock()-frameStarted)*1000
		local began=os.clock()
		if performanceMonitor then
			performanceMonitor.frame(frameDt,work)
			performanceMonitor.observe(chassis,speed,frameDt,work)
		end
		if measuring then
			performanceMonitor.metric('diagnostics',displayCost+(os.clock()-began)*1000)
			local callbackMs=(os.clock()-frameStarted)*1000
			performanceMonitor.metric('callbackTotal',callbackMs)
			performanceMonitor.completedFrame(callbackMs)
		end
	end
	RunService.RenderStepped:Connect(function(deltaTime: number)
		frameDt=deltaTime;frameStarted=os.clock();sectionStarted=frameStarted
		if performanceMonitor and performanceMonitor.beginFrame then performanceMonitor.beginFrame(deltaTime) end
		measuring=performanceMonitor and performanceMonitor.active() and player:GetAttribute('RaceState')=='RACING'
		if performanceMonitor then performanceMonitor.updateDisplay() end
		if measuring then local now=os.clock();displayCost=(now-sectionStarted)*1000;sectionStarted=now end
		if ReplicatedStorage:FindFirstChild("KDMBotRacers") then
			botResultElapsed+=deltaTime
			if botResultElapsed>=.15 then botResultElapsed=0;updateHud('BOT_POLL',true) end
		end
		if autoReadyNoticeUntil > 0 and time() >= autoReadyNoticeUntil then
			autoReadyNoticeUntil = 0; updateHud()
		end
		mark('botResults')
		if miniMapPanel.Visible and mapRenderer then
			markersActive=true
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local seat = humanoid and humanoid.SeatPart
			local kart = if seat and seat:GetAttribute("PrototypeKartSeat") == true then seat.Parent else nil
			local chassis = kart and kart:FindFirstChild("Chassis")
			mapRenderer:setRacerMarker("local:" .. tostring(player.UserId),
				if chassis and chassis:IsA("BasePart") then chassis.Position else nil, "LOCAL")
			local rivals = RaceMinimapRivals.collect(player, Players:GetPlayers(),
				getNumberAttribute(player, "RaceParticipantCount", 1),botSnapshots())
			local activeKeys = spareRivalKeys
			table.clear(activeKeys)
			for userId, position in rivals do
				local key = "rival:" .. tostring(userId)
				activeKeys[key] = true
				local previous = displayedRivalPositions[key]
				local smoothed = if previous then previous:Lerp(position, 1 - math.exp(-12 * deltaTime)) else position
				displayedRivalPositions[key] = smoothed
				mapRenderer:setRacerMarker(key, smoothed, "RIVAL")
			end
			for key in displayedRivalKeys do
				if not activeKeys[key] then
					mapRenderer:removeRacerMarker(key)
					displayedRivalPositions[key] = nil
				end
			end
			spareRivalKeys=displayedRivalKeys
			displayedRivalKeys = activeKeys
		elseif mapRenderer and markersActive then
			markersActive=false
			mapRenderer:clearRacerMarkers()
			displayedRivalKeys = {}
			displayedRivalPositions = {}
		end
		mark('minimap')
		local state = player:GetAttribute("RaceState")
		local drivingHud = state == "COUNTDOWN" or state == "RACING"
		local gaugeEnabled = Workspace:GetAttribute("KDMEnableV2Gauge") ~= false
		if not drivingHud then
			if gaugeController then gaugeController:update(nil,0,deltaTime,Input.isTouchPreferred(),false) end
			displayedSpeed = 0
			displayedSteering = 0
			steeringRing.Rotation = 0
			mark('gauge');finish(nil,0)
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
		end
		local desiredMode=if performanceMonitor then performanceMonitor.gaugeMode() else 'ANALOG'
		if gaugeController and gaugeMode~=desiredMode then gaugeController:destroy();gaugeController=nil end
		if gaugeEnabled and not gaugeController then
			gaugeMode=desiredMode
			gaugeController = require(script.Parent:WaitForChild("V2GaugeController")).new(playerGui,gaugeMode,MobileView)
		end
		local gaugeActive = gaugeController and gaugeController:update(chassis,targetSpeed,deltaTime,
			Input.isTouchPreferred(),gaugeEnabled and not quitOverlay.Visible and not routeOverlay.Visible
				and not availabilityPanel.Visible) == true
		mark('gauge')
		speedPanel.Visible = not gaugeActive
		steeringDisplay.Visible = not gaugeActive
		wheelClip.Visible = Input.isTouchPreferred() and not gaugeActive
		if lastGaugeActive~=gaugeActive then
			lastGaugeActive=gaugeActive
			positionLabel.Parent = if gaugeActive then screenGui else speedPanel
			positionLabel.AnchorPoint = if gaugeActive then Vector2.new(.5,0) else Vector2.zero
			positionLabel.Position = if gaugeActive then UDim2.new(.5,0,0,8) else UDim2.new(1,-76,0,1)
			positionLabel.Size = UDim2.fromOffset(if gaugeActive then 140 else 72,if gaugeActive then 24 else 17)
			positionLabel.TextXAlignment = if gaugeActive then Enum.TextXAlignment.Center else Enum.TextXAlignment.Right
		end
		positionLabel.Visible = getNumberAttribute(player,"RaceParticipantCount",1)>=2
		local alpha = 1 - math.exp(-10 * deltaTime)
		displayedSpeed += (targetSpeed - displayedSpeed) * alpha
		if not gaugeActive then
			local steering = kart and kart:GetAttribute("KartVisualSteering")
			local targetSteering = if kart and kart:GetAttribute("RaceControlsLocked") ~= true and type(steering) == "number"
				then math.clamp(steering, -1, 1) else 0
			if Input.isTouchPreferred() then
				targetSteering = if kart and kart:GetAttribute("RaceControlsLocked") ~= true
					and kart:GetAttribute("KartCrashActive") ~= true and kart:GetAttribute("KartSlickActive") ~= true
					then Input.getEffectiveSteering() else 0
			end
			displayedSteering += (targetSteering - displayedSteering) * alpha
			if Input.isTouchPreferred() then displayedSteering = targetSteering end
			steeringRing.Rotation = displayedSteering * 35
			speedUpdateElapsed += deltaTime
			if speedUpdateElapsed >= 0.08 then
				speedUpdateElapsed = 0
				local STUDS_PER_SECOND_TO_KMH = 1.008
				speedValue.Text = tostring(math.floor(displayedSpeed * STUDS_PER_SECOND_TO_KMH + 0.5))
				speedFill.Size = UDim2.fromScale(math.clamp(displayedSpeed / KartConfig.NITRO_MAX_SPEED, 0, 1), 1)
			end
		end
		finish(chassis,targetSpeed)
	end)
	print("[RobloxKart] Race HUD ready")
end

return RaceHudController
