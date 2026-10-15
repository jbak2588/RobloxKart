local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("KDMUiTheme"))
local DriverCatalog = require(Shared:WaitForChild("DriverCatalog"))
local KartCatalog = require(Shared:WaitForChild("KartCatalog"))
local TrackCatalog = require(Shared:WaitForChild("TrackCatalog"))
local TrackGeometry = require(Shared:WaitForChild("TrackGeometry"))
local KartVisualFactory = require(Shared:WaitForChild("KartVisualFactory"))
local KartPreviewFraming = require(Shared:WaitForChild("KartPreviewFraming"))
local TrackMapRenderer = require(script.Parent:WaitForChild("TrackMapRenderer"))
local GaragePresence = require(script.Parent:WaitForChild("GaragePresence"))
local GarageTexturePreload = require(script.Parent:WaitForChild("GarageTexturePreload"))

local GarageUiController = {}
local Input = require(script.Parent:WaitForChild("KartInputController"))
local MobileTutorialView = require(script.Parent:WaitForChild("MobileTutorialView"))
local started = false
local STEP_KART, STEP_TRACK, STEP_READY = 1, 2, 3
local openOverlay, closeOverlay
local shopContext
function GarageUiController.shopContext() return if shopContext then shopContext() else nil end
local openGate = nil
function GarageUiController.setOpenGate(gate) openGate = gate end
local navigationObservers = {}
local function notifyNavigation(event, action)
 for callback in navigationObservers do callback(event, action) end
end
function GarageUiController.observeNavigation(callback)
 navigationObservers[callback] = true
 return function() navigationObservers[callback] = nil end
end

function GarageUiController.open(action: string, confirmedTrackId: string?)
 if openOverlay then openOverlay(action, confirmedTrackId) end
end

function GarageUiController.resumeAfterShop()
 if openOverlay then openOverlay("SHOP_RETURN") end
end

function GarageUiController.close()
 if closeOverlay then closeOverlay() end
end
local GARAGE_LAYOUT_DEBUG = false
local GARAGE_LAYOUT_REVISION = "GARAGE R2"
local GARAGE_COLORS = {
	BackgroundTop = Theme.Background,
	BackgroundBottom = Theme.Background,
	Stage = Theme.Panel,
	StageDeep = Color3.fromRGB(10, 20, 34), -- Frozen 3D podium material, not UI palette.
	Cyan = Theme.Selection,
	CyanSoft = Color3.fromRGB(65, 165, 220),
	Primary = Theme.PrimaryAction,
	Gold = Theme.PrimaryAction,
	White = Theme.TextPrimary,
	Muted = Theme.TextSecondary,
}

local function visualStroke(parent: Instance, transparency: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "ArcadeStroke"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Theme.TextSecondary
	stroke.Thickness = 1.5
	stroke.Transparency = transparency
	stroke.Parent = parent
	return stroke
end

local function visualGradient(parent: Instance, top: Color3, bottom: Color3)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "ArcadeDepth"
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	gradient.Parent = parent
end

local function makeText(parent: Instance, size: UDim2, position: UDim2, text: string, fontSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Theme.TextPrimary
	label.TextStrokeColor3 = Theme.Background
	label.TextStrokeTransparency = .55
	label.TextScaled = false
	label.TextSize = fontSize
	label.Text = text
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, text: string, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(170, 48)
	button.Position = position
	button.BackgroundColor3 = Theme.Panel
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Theme.TextPrimary
	button.TextSize = 19
	button.Text = text
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

function GarageUiController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local remote = ReplicatedStorage:WaitForChild("GarageControl") :: RemoteEvent
	local preferenceRemote = ReplicatedStorage:WaitForChild("ControlsTutorialPreference") :: RemoteEvent
	local gui = Instance.new("ScreenGui")
	gui.Name = "RobloxKartGarage"
	gui.Enabled = false
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")
	-- Paint edge-to-edge independently of the safe-area content layout.
	local backgroundGui = Instance.new("ScreenGui")
	backgroundGui.Name = "RobloxKartGarageBackground"
	backgroundGui.Enabled = false
	backgroundGui.ResetOnSpawn = false
	backgroundGui.ScreenInsets = Enum.ScreenInsets.None
	backgroundGui.DisplayOrder = 19
	backgroundGui.Parent = player.PlayerGui
	-- Only non-interactive header text may use the topbar's vacant band.
	local headerGui = Instance.new("ScreenGui")
	headerGui.Name = "GarageTopHeader"
	headerGui.Enabled = false
	headerGui.IgnoreGuiInset = true
	headerGui.ScreenInsets = Enum.ScreenInsets.None
	headerGui.ClipToDeviceSafeArea = false
	headerGui.DisplayOrder = 20
	headerGui.ResetOnSpawn = false
	headerGui.Parent = player.PlayerGui
	gui:GetPropertyChangedSignal("Enabled"):Connect(function() headerGui.Enabled = gui.Enabled end)
	gui.Destroying:Connect(function() headerGui:Destroy() end)
	local background = Instance.new("Frame")
	background.Name = "FullScreenBackground"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Theme.Background
	background.BackgroundTransparency = .82
	background.Active = true
	background.BorderSizePixel = 0
	background.Parent = backgroundGui
	-- The live Workspace Lobby remains behind normal selections. RouteTransition
	-- keeps its independent loading shade and input ownership below.
	gui:GetPropertyChangedSignal("Enabled"):Connect(function() backgroundGui.Enabled = gui.Enabled end)
	gui.Destroying:Connect(function() backgroundGui:Destroy() end)

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Theme.Background
	backdrop.BackgroundTransparency = 1
	backdrop.Active = true
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui
	local routeOverlay = Instance.new("Frame")
	routeOverlay.Name = "RouteTransition"
	routeOverlay.Size = UDim2.fromScale(1, 1)
	routeOverlay.BackgroundColor3 = Theme.Background
	routeOverlay.BackgroundTransparency = 0.35
	routeOverlay.BorderSizePixel = 0
	routeOverlay.Active = true
	routeOverlay.ZIndex = 30
	routeOverlay.Visible = false
	routeOverlay.Parent = gui
	local routeCard = Instance.new("TextLabel")
	routeCard.Name = "Message"
	routeCard.AnchorPoint = Vector2.new(0.5, 0.5)
	routeCard.Position = UDim2.fromScale(0.5, 0.5)
	routeCard.Size = UDim2.fromOffset(280, 72)
	routeCard.BackgroundColor3 = Theme.Panel
	routeCard.BorderSizePixel = 0
	routeCard.Font = Enum.Font.GothamBold
	routeCard.TextColor3 = Theme.TextPrimary
	routeCard.TextSize = 20
	routeCard.Text = "JOINING RACE..."
	routeCard.ZIndex = 31
	routeCard.Parent = routeOverlay
	local routeCorner = Instance.new("UICorner")
	routeCorner.CornerRadius = UDim.new(0, 9)
	routeCorner.Parent = routeCard

	local title = makeText(backdrop, UDim2.fromScale(0.8, 0.09), UDim2.fromScale(0.1, 0.055), "KART DRIFT MASTERS", 40)
	title.Name = "GarageTitle"
	title.Active = false
	title.Selectable = false
	title.AnchorPoint = Vector2.new(.5, .5)
	title.TextColor3 = Theme.TextPrimary
	title.TextScaled = true
	local titleSize = Instance.new("UITextSizeConstraint")
	titleSize.MaxTextSize = 40
	titleSize.MinTextSize = 28
	titleSize.Parent = title
	local stepLabel = makeText(backdrop, UDim2.fromScale(0.8, 0.07), UDim2.fromScale(0.1, 0.17), "", 24)
	stepLabel.Name = "GarageStep"
	local choiceLabel = makeText(backdrop, UDim2.fromScale(0.8, 0.08), UDim2.fromScale(0.1, 0.61), "", 34)
	choiceLabel.Name = "GarageChoice"
	local detailLabel = makeText(backdrop, UDim2.fromScale(0.8, 0.12), UDim2.fromScale(0.1, 0.70), "", 19)
	detailLabel.Name = "GarageDetail"
	detailLabel.TextWrapped = true
	local errorLabel = makeText(backdrop, UDim2.fromScale(0.8, 0.05), UDim2.fromScale(0.1, 0.77), "", 18)
	errorLabel.TextColor3 = Theme.Danger
	local buildLabel = makeText(backdrop, UDim2.fromOffset(140, 16), UDim2.new(0, 10, 1, -20),
		"BUILD PV " .. tostring(game.PlaceVersion), 11)
	buildLabel.TextColor3 = Theme.TextSecondary
	if GARAGE_LAYOUT_DEBUG then
		buildLabel.Text ..= " \u{2022} " .. GARAGE_LAYOUT_REVISION
		buildLabel.Size = UDim2.fromOffset(260, 16)
	end
	buildLabel.TextXAlignment = Enum.TextXAlignment.Left
	local mobileCompact = false
	local presencePanel = Instance.new("Frame")
	presencePanel.Name = "ServerPresence"
	presencePanel.AnchorPoint = Vector2.new(1, 0)
	presencePanel.Position = UDim2.new(1, -16, 0.19, 0)
	presencePanel.Size = UDim2.fromOffset(205, 100)
	presencePanel.BackgroundColor3 = Theme.Panel
	presencePanel.BackgroundTransparency = 0.08
	presencePanel.BorderSizePixel = 0
	presencePanel.Parent = backdrop
	local presenceCorner = Instance.new("UICorner")
	presenceCorner.CornerRadius = UDim.new(0, 8)
	presenceCorner.Parent = presencePanel
	local presenceHeader = makeText(presencePanel, UDim2.new(1, -12, 0, 23), UDim2.fromOffset(6, 3), "", 14)
	presenceHeader.TextColor3 = Theme.TextPrimary
	presenceHeader.TextXAlignment = Enum.TextXAlignment.Left
	local populationLabel = makeText(presencePanel, UDim2.new(1, -12, 0, 42),
		UDim2.fromOffset(6, 25), "KDM STATUS UPDATING...", 12)
	populationLabel.Name = "KDMPopulation"
	populationLabel.TextXAlignment = Enum.TextXAlignment.Left
	populationLabel.TextYAlignment = Enum.TextYAlignment.Top
	populationLabel.TextWrapped = true
	local populationSnapshot = nil
	local populationTwoLines = true
	local function updatePopulationText()
		local snapshot = populationSnapshot
		if not snapshot or snapshot.stale then
			populationLabel.Text = "KDM STATUS UPDATING..."
		else
			local separator = if populationTwoLines then "\n" else " \u{2022} "
			populationLabel.Text = string.format("KDM ONLINE %d%sLOBBY %d \u{2022} IN RACE %d",
				snapshot.online, separator, snapshot.lobby, snapshot.inRace)
		end
	end
	local populationRemote = ReplicatedStorage:WaitForChild("KDMPopulationStatus")
	populationRemote.OnClientEvent:Connect(function(snapshot)
		if type(snapshot) ~= "table" then return end
		if snapshot.stale then
			populationSnapshot = { stale = true }
		elseif type(snapshot.online) == "number" and type(snapshot.lobby) == "number"
			and type(snapshot.inRace) == "number" then
			populationSnapshot = snapshot
		end
		updatePopulationText()
	end)
	local presenceList = Instance.new("ScrollingFrame")
	presenceList.Name = "OnlineList"
	presenceList.Position = UDim2.fromOffset(6, 68)
	presenceList.Size = UDim2.new(1, -12, 1, -74)
	presenceList.BackgroundTransparency = 1
	presenceList.BorderSizePixel = 0
	presenceList.ScrollBarThickness = 4
	presenceList.ScrollingDirection = Enum.ScrollingDirection.Y
	presenceList.CanvasSize = UDim2.fromOffset(0, 0)
	presenceList.AutomaticCanvasSize = Enum.AutomaticSize.None
	presenceList.ClipsDescendants = true
	presenceList.Parent = presencePanel
	local presenceLayout = Instance.new("UIListLayout")
	presenceLayout.SortOrder = Enum.SortOrder.LayoutOrder
	presenceLayout.Padding = UDim.new(0, 2)
	presenceLayout.Parent = presenceList
	local presenceRows = {}
	local presenceRowHeight = 20
	local presenceConnections = {}
	local presenceGeometry = nil
	local function updatePresence()
		local count, entries = GaragePresence.snapshot(Players:GetPlayers(), player)
		presenceHeader.Text = string.format("LOBBY %d", count)
		local contentHeight = GaragePresence.canvasHeight(count, presenceRowHeight, 2)
		local listHeight = presenceList.AbsoluteSize.Y
		if mobileCompact and presenceGeometry then
			presencePanel.AnchorPoint=Vector2.new(1,0)
			local g = presenceGeometry
			local layout = GaragePresence.mobileLayout(count, g.width, g.height, g.previewWidth, g.presenceWidth, g.twoLines, g.previewTop, g.previewHeight)
			presencePanel.Position = UDim2.new(1, -10, 0, layout.top)
			presencePanel.Size = UDim2.fromOffset(layout.width, layout.panelHeight)
			presenceList.Size = UDim2.new(1, -8, 0, layout.listHeight)
			listHeight = layout.listHeight
		end
		local scrolling = contentHeight > listHeight
		presenceList.ScrollBarThickness = if scrolling then 4 else 0
		local seen = {}
		for index, entry in entries do
			seen[entry.userId] = true
			local row = presenceRows[entry.userId]
			if not row then
				row = makeText(presenceList, UDim2.new(1, -8, 0, presenceRowHeight), UDim2.new(), "", 12)
				row.Name = "Player" .. tostring(entry.userId)
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.TextTruncate = Enum.TextTruncate.AtEnd
				presenceRows[entry.userId] = row
			end
			row.LayoutOrder = index
			row.Size = UDim2.new(1, if mobileCompact then (if scrolling then -6 else 0) else -8, 0, presenceRowHeight)
			row.TextSize = if mobileCompact and presenceGeometry and presenceGeometry.previewTop then 12 elseif mobileCompact then 10 else 12
			row.Text = if mobileCompact then entry.name else string.format("%s  %s", entry.name, entry.status)
		end
		for userId, row in presenceRows do
			if not seen[userId] then row:Destroy(); presenceRows[userId] = nil end
		end
		presenceList.CanvasSize = UDim2.fromOffset(0, contentHeight)
		local scroll = presenceList.CanvasPosition
		if scroll and scroll.Y > math.max(0, contentHeight - listHeight) then
			presenceList.CanvasPosition = Vector2.new(0, math.max(0, contentHeight - listHeight))
		end
	end
	local function bindPresence(other)
		if presenceConnections[other] then return end
		presenceConnections[other] = {
			other:GetAttributeChangedSignal("RaceState"):Connect(updatePresence),
			other:GetAttributeChangedSignal("ReadyOrder"):Connect(updatePresence),
		}
		updatePresence()
	end
	for _, other in Players:GetPlayers() do bindPresence(other) end
	Players.PlayerAdded:Connect(bindPresence)
	Players.PlayerRemoving:Connect(function(other)
		local connections = presenceConnections[other]
		if connections then
			for _, connection in connections do connection:Disconnect() end
			presenceConnections[other] = nil
		end
		task.defer(updatePresence)
	end)
	updatePresence()

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "SelectionPreview"
	viewport.AnchorPoint = Vector2.new(0.5, 0)
	viewport.Position = UDim2.fromScale(0.5, 0.265)
	viewport.Size = UDim2.fromScale(0.52, 0.32)
	viewport.BackgroundColor3 = Theme.Panel
	viewport.BackgroundTransparency = .12
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(182, 189, 200)
	viewport.LightColor = Color3.fromRGB(250, 244, 233)
	viewport.LightDirection = Vector3.new(-1, -1, -0.6)
	viewport.Parent = backdrop
	viewport.ZIndex = 2
	local viewportSize = Instance.new("UISizeConstraint")
	viewportSize.MinSize = Vector2.new(360, 200)
	viewportSize.MaxSize = Vector2.new(800, 410)
	viewportSize.Parent = viewport
	local viewportCorner = Instance.new("UICorner")
	viewportCorner.CornerRadius = UDim.new(0, 12)
	viewportCorner.Parent = viewport
	local previewLoading = makeText(backdrop, viewport.Size, viewport.Position, "Loading driver...", 20)
	previewLoading.AnchorPoint = viewport.AnchorPoint
	previewLoading.ZIndex = 2
	previewLoading.Visible = false
	local loadingSize = Instance.new("UISizeConstraint")
	loadingSize.MinSize = viewportSize.MinSize
	loadingSize.MaxSize = viewportSize.MaxSize
	loadingSize.Parent = previewLoading
	local mapPanel = Instance.new("Frame")
	mapPanel.Name = "TrackPreview"
	mapPanel.AnchorPoint = viewport.AnchorPoint
	mapPanel.Position = viewport.Position
	mapPanel.Size = viewport.Size
	mapPanel.BackgroundColor3 = Theme.Panel
	mapPanel.BorderSizePixel = 0
	mapPanel.Visible = false
	mapPanel.Parent = backdrop
	mapPanel.BackgroundTransparency = 1
	mapPanel.ZIndex = 2
	local mapSize = Instance.new("UISizeConstraint")
	mapSize.MinSize = viewportSize.MinSize
	mapSize.MaxSize = viewportSize.MaxSize
	mapSize.Parent = mapPanel
	local mapCorner = Instance.new("UICorner")
	mapCorner.CornerRadius = UDim.new(0, 12)
	mapCorner.Parent = mapPanel
	local trackImageArea = Instance.new("Frame")
	trackImageArea.Name = "ImageArea"
	trackImageArea.BackgroundTransparency = 1
	trackImageArea.BorderSizePixel = 0
	trackImageArea.Size = UDim2.new(1,0,1,-54)
	trackImageArea.ZIndex = 2
	trackImageArea.Parent = mapPanel
	local trackImage = Instance.new("ImageLabel")
	trackImage.Name = "ApprovedTrackImage"
	trackImage.Size = UDim2.fromScale(1,1)
	trackImage.BackgroundTransparency = 1
	trackImage.ScaleType = Enum.ScaleType.Fit
	trackImage.Active = false
	trackImage.ZIndex = 4
	trackImage.Visible = false
	trackImage.Parent = trackImageArea
	local trackInfo = Instance.new("Frame")
	trackInfo.Name = "TrackInformation"
	trackInfo.Position = UDim2.new(0,0,1,-54)
	trackInfo.Size = UDim2.new(1,0,0,54)
	trackInfo.BackgroundColor3 = Theme.Panel
	trackInfo.BackgroundTransparency = .08
	trackInfo.BorderSizePixel = 0
	trackInfo.ZIndex = 4
	trackInfo.Parent = mapPanel
	local trackName = makeText(trackInfo,UDim2.new(1,-16,0,28),UDim2.fromOffset(8,2),"",24)
	trackName.Name = "TrackName"
	trackName.ZIndex = 5
	trackName.TextWrapped = true
	local trackMetadata = makeText(trackInfo,UDim2.new(1,-16,0,20),UDim2.fromOffset(8,31),"",14)
	trackMetadata.Name = "TrackMetadata"
	trackMetadata.ZIndex = 5
	trackMetadata.TextWrapped = true
	local function makeArrow(text: string, xOffset: number): TextButton
		local arrow = makeButton(backdrop, text, UDim2.new(0.5, xOffset, 0.43, 0))
		arrow.Name = if xOffset < 0 then "PreviousChoice" else "NextChoice"
		arrow.Size = UDim2.fromOffset(52, 64)
		arrow.BackgroundColor3 = Theme.Panel
		arrow.BackgroundTransparency = 0.12
		arrow.TextSize = 29
		arrow.ZIndex = 3
		return arrow
	end
	local leftArrow = makeArrow(utf8.char(9664), -350)
	local rightArrow = makeArrow(utf8.char(9654), 298)

	local controlsCard = Instance.new("Frame")
	controlsCard.Name = "ControlsHint"
	controlsCard.AnchorPoint = Vector2.new(1, 0)
	controlsCard.Position = UDim2.new(1, -16, 0.28, 0)
	controlsCard.Size = UDim2.fromOffset(292, 184)
	controlsCard.BackgroundColor3 = Theme.Panel
	controlsCard.BackgroundTransparency = 0.08
	controlsCard.BorderSizePixel = 0
	controlsCard.Parent = backdrop
	local controlsCorner = Instance.new("UICorner")
	controlsCorner.CornerRadius = UDim.new(0, 10)
	controlsCorner.Parent = controlsCard
	local controlsTitle = makeText(controlsCard, UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 8), "CONTROLS", 17)
	controlsTitle.TextColor3 = Theme.TextPrimary
	controlsTitle.TextXAlignment = Enum.TextXAlignment.Left
	for index, hint in {
		"W / S   Accelerate / Brake & Reverse",
		"A / D   Steer",
		"SHIFT   Drift",
		"GOLD GAUGE + SHIFT RELEASE = BOOST",
		"1 / 2 / 3 / 4   Select item",
		"Q   Use item",
	} do
		local line = makeText(controlsCard, UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 34 + (index - 1) * 23), hint, if index == 4 then 10 else 12)
		line.Font = Enum.Font.Gotham
		line.TextXAlignment = Enum.TextXAlignment.Left
	end

	local previousButton = makeButton(backdrop, "BACK", UDim2.new(0.5, -270, 0.84, 0))
	local shopButton=makeButton(backdrop,'GO TO SHOP',UDim2.fromOffset(12,14))
	shopButton.Size=UDim2.fromOffset(104,44)
	shopButton.BackgroundColor3=Theme.Panel;shopButton.TextSize=12
	shopButton.Activated:Connect(function()require(script.Parent.GarageShopController).open('WINGS')end)
	local cycleButton = makeButton(backdrop, "SELECT", UDim2.new(0.5, -85, 0.84, 0))
	local nextButton = makeButton(backdrop, "READY", UDim2.new(0.5, 100, 0.84, 0))
	local inviteGui = Instance.new("ScreenGui")
	inviteGui.Name = "HubRaceInvite"
	inviteGui.ResetOnSpawn = false
	inviteGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	inviteGui.DisplayOrder = 40
	inviteGui.Parent = player.PlayerGui
	gui.Destroying:Connect(function() inviteGui:Destroy() end)
	local inviteModal = Instance.new("Frame")
	inviteModal.Name = "RaceInvite"
	inviteModal.AnchorPoint = Vector2.new(0.5, 0.5)
	inviteModal.Position = UDim2.fromScale(0.5, 0.5)
	inviteModal.Size = UDim2.fromOffset(290, 174)
	inviteModal.BackgroundColor3 = Theme.Panel
	inviteModal.BorderSizePixel = 0
	inviteModal.ZIndex = 10
	inviteModal.Visible = false
	inviteModal.Parent = inviteGui
	inviteModal:GetPropertyChangedSignal("Visible"):Connect(function()
		populationLabel.Visible = not (mobileCompact and inviteModal.Visible)
	end)
	local inviteCorner = Instance.new("UICorner")
	inviteCorner.CornerRadius = UDim.new(0, 10)
	inviteCorner.Parent = inviteModal
	local inviteTitle = makeText(inviteModal, UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 10), "RACE INVITE", 19)
	inviteTitle.TextColor3 = Theme.TextPrimary
	inviteTitle.ZIndex = 11
	local inviteDescription = makeText(inviteModal, UDim2.new(1, -24, 0, 70), UDim2.fromOffset(12, 40), "", 14)
	inviteDescription.TextWrapped = true
	inviteDescription.ZIndex = 11
	local declineInvite = makeButton(inviteModal, "DECLINE", UDim2.fromOffset(12, 120))
	declineInvite.Size = UDim2.fromOffset(126, 40)
	declineInvite.BackgroundColor3 = Theme.Panel
	declineInvite.ZIndex = 11
	local joinInvite = makeButton(inviteModal, "JOIN", UDim2.fromOffset(152, 120))
	joinInvite.Size = UDim2.fromOffset(126, 40)
 joinInvite.BackgroundColor3,joinInvite.TextColor3 = Theme.PrimaryAction,Theme.Background
	joinInvite.ZIndex = 11
	local tutorial = MobileTutorialView.create(backdrop, function()
		preferenceRemote:FireServer("Dismiss")
	end)
	local controlsButton = makeButton(backdrop, "CONTROLS", UDim2.new(1, -136, 0, 14))
	controlsButton.AnchorPoint = Vector2.new(0, 0)
	controlsButton.Size = UDim2.fromOffset(120, 36)
	controlsButton.TextSize = 15
	controlsButton.Visible = false
	controlsButton.Activated:Connect(function() tutorial.open() end)
	local tutorialSeenThisSession = false

	local step = STEP_KART
	local overlayOpen = false
	-- One reusable, non-interactive shell behind both existing preview targets.
	local shell = Instance.new("Frame")
	shell.Name = "PreviewVisualShell"
	shell.AnchorPoint = viewport.AnchorPoint
	shell.BackgroundColor3 = Color3.new(1, 1, 1)
	shell.BorderSizePixel = 0
	shell.Active = false
	shell.ZIndex = 0
	shell.Parent = backdrop
	local shellCorner = Instance.new("UICorner")
	shellCorner.CornerRadius = UDim.new(0, 12)
	shellCorner.Parent = shell
	visualGradient(shell, GARAGE_COLORS.Stage, Theme.Background)
	local shellStroke = visualStroke(shell, .55)
	shellStroke.Color = GARAGE_COLORS.Cyan
	local platform = Instance.new("Frame")
	platform.Name = "ShowcasePlatform"
	platform.AnchorPoint = Vector2.new(.5, .5)
	platform.Position = UDim2.fromScale(.5, .86)
	platform.Size = UDim2.fromScale(.48, .085)
	platform.BackgroundColor3 = GARAGE_COLORS.CyanSoft
	platform.BackgroundTransparency = .86
	platform.BorderSizePixel = 0
	platform.Active = false
	platform.ZIndex = 0
	platform.Parent = shell
	local platformCorner = Instance.new("UICorner")
	platformCorner.CornerRadius = UDim.new(1, 0)
	platformCorner.Parent = platform
	local halo = Instance.new("Frame")
	halo.Name = "ShowcaseHalo"
	halo.AnchorPoint = Vector2.new(.5, .5)
	halo.Position = UDim2.fromScale(.5, .57)
	halo.Size = UDim2.fromScale(.74, .68)
	halo.BackgroundColor3 = Theme.TextSecondary
	halo.BackgroundTransparency = .96
	halo.BorderSizePixel = 0
	halo.Active = false
	halo.ZIndex = 0
	halo.Parent = shell
	local haloCorner = Instance.new("UICorner")
	haloCorner.CornerRadius = UDim.new(1, 0)
	haloCorner.Parent = halo
	local haloGradient = Instance.new("UIGradient")
	haloGradient.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.5, 0), NumberSequenceKeypoint.new(1, 1)})
	haloGradient.Rotation = 90
	haloGradient.Parent = halo
	local checker = Instance.new("Frame")
	checker.Name = "CheckerAccent"
	checker.AnchorPoint = Vector2.new(1, 1)
	checker.Position = UDim2.new(1, -12, 1, -10)
	checker.Size = UDim2.fromOffset(32, 16)
	checker.BackgroundTransparency = 1
	checker.Active = false
	checker.ZIndex = 0
	checker.Parent = shell
	for row = 0, 1 do for column = 0, 3 do
		local square = Instance.new("Frame")
		square.Name = "CheckerSquare"
		square.Position = UDim2.fromOffset(column*8, row*8)
		square.Size = UDim2.fromOffset(8, 8)
		square.BackgroundColor3 = if (row+column)%2 == 0 then GARAGE_COLORS.White else Theme.TextSecondary
		square.BackgroundTransparency = if (row+column)%2 == 0 then .65 else .9
		square.BorderSizePixel = 0
		square.Active = false
		square.ZIndex = 0
		square.Parent = checker
	end end
	visualStroke(presencePanel, .7)
	visualStroke(controlsCard, .85)
	local readyCard = Instance.new("Frame")
	readyCard.Name = "ReadySummaryCard"
	readyCard.BackgroundColor3 = Color3.new(1, 1, 1)
	readyCard.BorderSizePixel = 0
	readyCard.Active = false
	readyCard.ZIndex = 0
	readyCard.Parent = backdrop
	local readyCorner = Instance.new("UICorner")
	readyCorner.CornerRadius = UDim.new(0, 12)
	readyCorner.Parent = readyCard
	visualGradient(readyCard, GARAGE_COLORS.Stage, Theme.Background)
	visualStroke(readyCard, .75)
	for _, button in {previousButton, cycleButton, nextButton, leftArrow, rightArrow} do
		local primary = button == cycleButton or button == nextButton
		button.BackgroundColor3 = if primary then GARAGE_COLORS.Primary else Theme.Panel
		button.TextColor3 = if primary then Theme.Background else Theme.TextPrimary
		button.AutoButtonColor = true -- Native hover/press feedback, without layout animation.
		visualStroke(button, if primary then .3 else .65)
	end
	local selectionTween: Tween? = nil
	local function clearSelectionPulse()
		if selectionTween then selectionTween:Cancel(); selectionTween = nil end
		shellStroke.Transparency = .55
	end
	gui.Destroying:Connect(clearSelectionPulse)
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not gui.Enabled then clearSelectionPulse() end
	end)
	local function syncVisualShell()
		local target = if step == STEP_TRACK then mapPanel else viewport
		shell.Position, shell.Size = target.Position, target.Size
		shell.Visible = step <= STEP_TRACK
		platform.Visible = false -- Replaced by the preview-only native 3D podium.
		halo.Visible = step <= STEP_KART
		readyCard.Visible = step == STEP_READY
		if step == STEP_READY then
			-- Existing text rectangles remain the source of truth; only their backdrop expands.
			local origin = backdrop.AbsolutePosition
			local first, second = choiceLabel.AbsolutePosition - origin, detailLabel.AbsolutePosition - origin
			local left, top = math.min(first.X, second.X), math.min(first.Y, second.Y)
			local right = math.max(first.X + choiceLabel.AbsoluteSize.X, second.X + detailLabel.AbsoluteSize.X)
			local bottom = math.max(first.Y + choiceLabel.AbsoluteSize.Y, second.Y + detailLabel.AbsoluteSize.Y)
			local padLeft, padTop, padRight, padBottom = 8, 8, 8, 8
			for _, item in {presencePanel, controlsCard, controlsButton, previousButton, nextButton} do
				if not item.Visible then continue end
				local position, size = item.AbsolutePosition - origin, item.AbsoluteSize
				if position.X >= right then padRight = math.max(0, math.min(padRight, position.X - right - 4)) end
				if position.X + size.X <= left then padLeft = math.max(0, math.min(padLeft, left - position.X - size.X - 4)) end
				if position.Y >= bottom then padBottom = math.max(0, math.min(padBottom, position.Y - bottom - 4)) end
				if position.Y + size.Y <= top then padTop = math.max(0, math.min(padTop, top - position.Y - size.Y - 4)) end
			end
			readyCard.Position = UDim2.fromOffset(left - padLeft, top - padTop)
			readyCard.Size = UDim2.fromOffset(right - left + padLeft + padRight, bottom - top + padTop + padBottom)
		end
		if step == STEP_READY then clearSelectionPulse() end
	end
	local selectionPending = nil
	local localRouteRequested = false
	local stopPreviewRotation: (() -> ())? = nil
	local startPreviewIdleRotation: (() -> ())? = nil
		local kartIndex = 1
	local trackIndex = 1
	local trackOrder = {}
	for _, id in TrackCatalog.Order do
		local entry = TrackCatalog.Entries[id]
		if entry and entry.Visible ~= false and entry.Selectable ~= false then table.insert(trackOrder, id) end
	end
	local catalogs = { [STEP_KART] = KartCatalog, [STEP_TRACK] = {Order=trackOrder, Entries=TrackCatalog.Entries} }
	local headings = { [STEP_KART] = "KART GARAGE", [STEP_TRACK] = "STEP 1 / 2 \u{00B7} TRACK SELECT", [STEP_READY] = "2 / 2   READY" }
	local previewKey: string? = nil
	local previewWorld: WorldModel? = nil
	local previewCamera: Camera? = nil
	local trackMap = nil
	local trackMapKey: string? = nil
	local previewKart: Model? = nil
	local function updateRouteOverlay()
		local pending = localRouteRequested or player:GetAttribute("KDMRoutePending") == "RACE_LAUNCH"
		if pending then clearSelectionPulse() end
		routeOverlay.Visible = pending and player:GetAttribute("RaceState") == "GARAGE"
		if pending and stopPreviewRotation then stopPreviewRotation()
		elseif startPreviewIdleRotation then startPreviewIdleRotation() end
		for _, button in { previousButton, cycleButton, nextButton, leftArrow, rightArrow } do
			button.Active = not pending and selectionPending == nil
		end
	end
	local previewRenderConnection: RBXScriptConnection? = nil
	local previewYaw, previewPitch, previewDistance = 0, 0, 0
	local previewCenter = Vector3.zero
	local podium: Folder? = nil
	local podiumDiameter, podiumBottom = 0, 0
	local podiumCenter = Vector3.zero
	local function updateShowcasePodium()
		if not podium or not previewCamera then return end
		-- Bound only the decoration to the existing full-yaw camera envelope.
		-- The circular podium is symmetric, so this conservative limit covers every yaw.
		local tangent = math.tan(math.rad(previewCamera.FieldOfView) / 2)
		local sine, cosine = math.sin(previewPitch), math.cos(previewPitch)
		local height = previewCenter.Y - podiumBottom + .265
		local offset = Vector3.new(podiumCenter.X - previewCenter.X, 0, podiumCenter.Z - previewCenter.Z).Magnitude
		local vertical = .99 * tangent
		local horizontal = .94 * tangent * viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y)
		local radiusY = (vertical * (previewDistance + height * sine) - height * cosine) / (math.abs(sine) + vertical * cosine)
		local radiusX = horizontal * (previewDistance + height * sine) / (1 + horizontal * cosine)
		local diameter = math.max(.1, math.min(podiumDiameter, 2 * (math.min(radiusY, radiusX) - offset)))
		podium.GlowBase.Size = Vector3.new(.12, diameter, diameter)
		podium.MainDisc.Size = Vector3.new(.12, diameter * .94, diameter * .94)
	end
	local activePreviewInput: InputObject? = nil
	local lastDragX = 0
	local idleDelay = 0
	local rotationConnections = {}
	local function updatePreviewCamera()
		if not previewCamera then return end
		local direction = Vector3.new(math.sin(previewYaw) * math.cos(previewPitch), math.sin(previewPitch), math.cos(previewYaw) * math.cos(previewPitch))
		local right = Vector3.yAxis:Cross(direction).Unit
		previewCamera.CFrame = CFrame.fromMatrix(previewCenter + direction * previewDistance, right, direction:Cross(right), direction)
	end
	stopPreviewRotation = function()
		if previewRenderConnection then previewRenderConnection:Disconnect(); previewRenderConnection = nil end
		activePreviewInput = nil
		idleDelay = 0
	end
	startPreviewIdleRotation = function()
		if previewRenderConnection or not previewCamera or routeOverlay.Visible or not gui.Enabled then return end
		previewRenderConnection = RunService.RenderStepped:Connect(function(dt)
			if activePreviewInput or inviteModal.Visible then return end
			if idleDelay > 0 then idleDelay = math.max(0, idleDelay - dt); return end
			previewYaw = (previewYaw + dt * math.pi * 2 / 7) % (math.pi * 2)
			updatePreviewCamera()
		end)
	end
	local function fitSelectionPreview()
		if not previewCamera or viewport.AbsoluteSize.Y <= 0 then return end
		local fitted, target
		local aspect = viewport.AbsoluteSize.X / viewport.AbsoluteSize.Y
		if previewKart then fitted, target = KartPreviewFraming.fit(previewKart, aspect, previewCamera.FieldOfView, true) end
		if not fitted or not target then return end
		previewCenter = target
		local offset = fitted.Position - target
		previewDistance = offset.Magnitude
		previewPitch = math.asin(offset.Y / previewDistance)
		-- Resize retains the current viewing angle; a rebuilt selection resets it below.
		updatePreviewCamera()
		updateShowcasePodium()
	end
	viewport.Active = true
	table.insert(rotationConnections, viewport.InputBegan:Connect(function(input)
		if activePreviewInput or not gui.Enabled or not viewport.Visible or routeOverlay.Visible or inviteModal.Visible or not previewCamera then return end
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		activePreviewInput = input
		lastDragX = input.Position.X
		idleDelay = 2.5
	end))
	table.insert(rotationConnections, UserInputService.InputChanged:Connect(function(input)
		if not activePreviewInput then return end
		local matching = input == activePreviewInput or (activePreviewInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
		if not matching then return end
		local delta = input.Position.X - lastDragX
		lastDragX = input.Position.X
		previewYaw = (previewYaw - math.rad(delta * 0.32)) % (math.pi * 2)
		updatePreviewCamera()
	end))
	table.insert(rotationConnections, UserInputService.InputEnded:Connect(function(input)
		if input == activePreviewInput then activePreviewInput = nil; idleDelay = 2.5 end
	end))
	table.insert(rotationConnections, UserInputService.WindowFocusReleased:Connect(function()
		activePreviewInput = nil; idleDelay = 2.5
	end))
	table.insert(rotationConnections,gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not gui.Enabled then stopPreviewRotation() else startPreviewIdleRotation() end
	end))
	table.insert(rotationConnections,inviteModal:GetPropertyChangedSignal("Visible"):Connect(function()
		activePreviewInput=nil; idleDelay=2.5
	end))
	gui.Destroying:Connect(function()
		stopPreviewRotation()
		for _, connection in rotationConnections do connection:Disconnect() end
	end)
	viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitSelectionPreview)

	local function applyVisualStage(size: Vector2, screen: Vector2)
		local width, height = size.X, size.Y
		local topbar = GuiService.TopbarInset
		-- None-inset label offsets are physical-screen coordinates. Roblox's raw
		-- AbsolutePosition is relative to the device-safe/Core UI origin; it is
		-- diagnostic data, never a vertical correction to TopbarInset.
		local deviceOrigin = Vector2.new(
			math.max(0, (headerGui.AbsoluteSize.X - screen.X) * .5),
			math.max(0, (headerGui.AbsoluteSize.Y - screen.Y) * .5))
		screen = headerGui.AbsoluteSize
		local titleWidth = math.min(screen.X * 0.36, 450)
		local titleHeight = math.clamp(screen.Y * 0.055, 24, 36)
		-- TopbarInset is in the camera's device-safe viewport. Translate it once
		-- into the physical header canvas, independently of the Garage safe root.
		local centerY = (topbar.Min.Y + topbar.Max.Y) * .5 + deviceOrigin.Y
		local topHeader = screen.X >= 700 and screen.X > screen.Y
			and topbar.Height >= titleHeight and centerY - titleHeight * .5 >= 0
			and centerY + titleHeight * .5 <= screen.Y
			and screen.X * .5 - titleWidth * .5 >= topbar.Min.X + deviceOrigin.X + 8
			and screen.X * .5 + titleWidth * .5 <= topbar.Max.X + deviceOrigin.X - 8
		local headerBottom
		if topHeader then
			title.Parent = headerGui
			stepLabel.Parent = backdrop
			title.Position = UDim2.fromOffset(screen.X*.5, centerY)
			title.Size = UDim2.fromOffset(titleWidth, titleHeight)
			titleSize.MinTextSize, titleSize.MaxTextSize = 20, 32
			-- Only the title occupies the Core UI band. Other lines stay in safe content.
			local stepTop = if mobileCompact then (if controlsButton.Visible and step ~= STEP_TRACK then 52 else 0) else topbar.Max.Y + 2
			stepLabel.Position = UDim2.new(stepLabel.Position.X.Scale,stepLabel.Position.X.Offset,0,stepTop)
			stepLabel.Size = UDim2.new(stepLabel.Size.X.Scale,stepLabel.Size.X.Offset,0,if mobileCompact then 20 else 24)
			if mobileCompact then
				populationLabel.Parent = backdrop
				populationLabel.Position = UDim2.new(.5,0,0,stepTop+22)
				headerBottom = stepTop+22+populationLabel.AbsoluteSize.Y
			else headerBottom = stepTop+24 end
		else
			title.Parent, stepLabel.Parent = backdrop, backdrop
			local safeTitleHeight = math.min(40,height*.075)
			title.Position = UDim2.new(.5,0,0,height*.02+safeTitleHeight*.5)
			title.Size = UDim2.new(.8,0,0,safeTitleHeight)
			local stepTop = height*.02 + safeTitleHeight + 2
			stepLabel.Position = UDim2.new(stepLabel.Position.X.Scale,stepLabel.Position.X.Offset,0,stepTop)
			stepLabel.Size = UDim2.new(stepLabel.Size.X.Scale,stepLabel.Size.X.Offset,0,if mobileCompact then 20 else 24)
			if mobileCompact then
				populationLabel.Parent = backdrop
				populationLabel.Position = UDim2.new(.5,0,0,stepTop+22)
				headerBottom = stepTop+22+populationLabel.AbsoluteSize.Y
			else headerBottom = stepTop+24 end
		end
		-- Keep the empty canvas enabled in SAFE_HEADER too: disabled ScreenGuis
		-- can retain their previous AbsoluteSize during a device switch, locking
		-- the fallback against a stale desktop width on the next mobile layout.
		headerGui.Enabled = gui.Enabled
		headerGui:SetAttribute("GarageHeaderMode", if topHeader then "TOPBAR" else "SAFE_HEADER")
		headerGui:SetAttribute("GarageLayoutRevision", GARAGE_LAYOUT_REVISION)
		if mobileCompact and width>height and step == STEP_KART then
			headerBottom = stepLabel.Position.Y.Offset+stepLabel.Size.Y.Offset
		end
		local top = if mobileCompact then math.max(height*.06, headerBottom+6) else math.max(height*.10,headerBottom+24)
		local buttonTop = if mobileCompact then height-48 else height*.84
		local nameHeight = if mobileCompact then 28 else 36
		local descriptionSpace = if step == STEP_TRACK then (if mobileCompact then 26 else 32) else 0
		local available = buttonTop - top - nameHeight - descriptionSpace - (if step == STEP_TRACK then 16 else 26)
		local stageHeight = math.max(1, math.min(height*.51,360,available))
		if mobileCompact and width>height and step == STEP_KART then
			-- Give the kart the full safe lane between the header, name and actions.
			stageHeight = math.max(1, available+14)
		end
		-- Retain Phase 1B widths independently from the expanded vertical budget.
		local priorHeight = math.min(height*.44,310)
		local stageWidth = math.min(width*(if width>height then .5 else .64),800,priorHeight*(if step == STEP_KART then 2.4 else 2.65),stageHeight*2.65)
		local selectionCenter=width*.5
		local desktopNameTop, desktopDetailTop
		if mobileCompact and width>height and step <= STEP_TRACK then
			if width*.5-stageWidth*.5-70<120 then stageWidth*=.94 end
			presenceGeometry.previewTop, presenceGeometry.previewHeight = top, stageHeight
			presenceGeometry.previewWidth = stageWidth
		elseif not mobileCompact then
			-- Scale only the desktop composition. Keep a bounded landscape preview
			-- on short screens, while allowing taller desktops to reach 1100x500.
			local sidebarWidth=math.clamp(width*.128,220,280)
			local sidebarGap=76 -- Clears the existing 52px arrow and its 8px margin.
			local availableTop, availableBottom=headerBottom+36,height-24
			stageHeight=math.clamp(height*.42,330,math.clamp(height*.35,440,500))
			stageHeight=math.min(stageHeight,math.max(1,availableBottom-availableTop-196))
			stageWidth=math.min(1100,stageHeight*2.2,width-sidebarWidth-sidebarGap-152)
			if stageWidth<stageHeight*2.2 then stageHeight=stageWidth/2.2 end
			local groupWidth=stageWidth+sidebarGap+sidebarWidth
			selectionCenter=(width-groupWidth)*.5+stageWidth*.5
			nameHeight=math.clamp(height*.038,36,44)
			choiceLabel.TextSize=math.clamp(height*.034,30,38)
			local buttonWidth=math.clamp(width*.12,190,240)
			local buttonHeight=math.clamp(height*.056,52,64)
			local selectionHeight=stageHeight+10+nameHeight+descriptionSpace+24+buttonHeight
			local contentHeight=math.max(selectionHeight,stageHeight+196)
			-- Aim the actual preview/name/action block at 45% of the canvas;
			-- the taller sidebar also has to fit inside the same available region.
			top=math.max(availableTop,math.min(height*.45-selectionHeight*.5,availableBottom-contentHeight))
			desktopNameTop=top+stageHeight+10
			desktopDetailTop=top+stageHeight+nameHeight+14
			if step == STEP_READY then
				local readyHeight=nameHeight+14+26+24+buttonHeight
				desktopNameTop=math.max(availableTop,math.min(height*.45-readyHeight*.5,availableBottom-readyHeight))
				desktopDetailTop=desktopNameTop+nameHeight+14
			end
			local sidebarX=selectionCenter+stageWidth*.5+sidebarGap
			presencePanel.Position=UDim2.fromOffset(sidebarX,top)
			presencePanel.Size=UDim2.fromOffset(sidebarWidth,stageHeight)
			presencePanel.AnchorPoint=Vector2.zero
			presenceList.Size=UDim2.new(1,-12,1,-74)
			controlsCard.Position=UDim2.fromOffset(sidebarX,top+stageHeight+12)
			controlsCard.AnchorPoint=Vector2.zero
			controlsCard.Size=UDim2.fromOffset(sidebarWidth,184)
			local buttonY=if step <= STEP_TRACK then desktopNameTop+nameHeight+descriptionSpace+24 else desktopDetailTop+26+24
			for _,button in {previousButton,cycleButton,nextButton} do
				button.Size=UDim2.fromOffset(buttonWidth,buttonHeight)
				button.TextSize=math.clamp(height*.021,20,24)
				button.Position=UDim2.fromOffset(selectionCenter+(if button==previousButton then -buttonWidth-10 elseif button==cycleButton and not previousButton.Visible then -buttonWidth*.5 else 10),buttonY)
			end
		end
		if step == STEP_TRACK and width<=height then stageHeight=math.min(stageHeight,stageWidth) end
		for _, constraint in {viewportSize,loadingSize,mapSize} do
			constraint.MinSize = Vector2.zero
			constraint.MaxSize = if mobileCompact then Vector2.new(800,410) else Vector2.new(1100,500)
		end
		for _, panel in {viewport,previewLoading,mapPanel} do
			panel.Position = UDim2.fromOffset(selectionCenter,top)
			panel.Size = UDim2.fromOffset(stageWidth,stageHeight)
		end
		choiceLabel.Position = UDim2.new(.1,0,0,if step <= STEP_TRACK then top+stageHeight+10 else height*.39)
		choiceLabel.Size = UDim2.new(.8,0,0,nameHeight)
		if not mobileCompact then
			choiceLabel.Position=UDim2.fromOffset(selectionCenter-stageWidth*.5,desktopNameTop)
			choiceLabel.Size=UDim2.fromOffset(stageWidth,nameHeight)
		end
		detailLabel.Visible = step >= STEP_TRACK
		detailLabel.Position = UDim2.new(.1,0,0,if step == STEP_TRACK then top+stageHeight+nameHeight+14 else height*.55)
		detailLabel.Size = UDim2.new(.8,0,0,if mobileCompact then 20 else 26)
		if not mobileCompact then detailLabel.Position=UDim2.fromOffset(selectionCenter-stageWidth*.5,desktopDetailTop); detailLabel.Size=UDim2.fromOffset(stageWidth,26) end
		local arrowWidth, arrowHeight = if mobileCompact then 44 else 52, if mobileCompact then 50 else 64
		leftArrow.Size, rightArrow.Size = UDim2.fromOffset(arrowWidth,arrowHeight), UDim2.fromOffset(arrowWidth,arrowHeight)
		local arrowTop = top+(stageHeight-arrowHeight)*.5
		if mobileCompact and width<=height and presenceGeometry then
			local g=presenceGeometry
			local lobby=GaragePresence.mobileLayout(#Players:GetPlayers(),width,height,g.previewWidth,g.presenceWidth,g.twoLines)
			arrowTop=math.max(arrowTop,lobby.top+lobby.panelHeight+8)
		end
		leftArrow.Position = UDim2.fromOffset(selectionCenter-stageWidth*.5-arrowWidth-8,arrowTop)
		rightArrow.Position = UDim2.fromOffset(selectionCenter+stageWidth*.5+8,arrowTop)
		if step == STEP_TRACK then
			-- Track-only expansion: metadata shares the card, freeing the former
			-- name/detail lanes. Fit preserves the whole approved 1672x941 image.
			if mobileCompact and width>height then
				-- Keep online/room information together in the preserved sidebar,
				-- releasing an entire header row for the full-circuit image.
				populationLabel.Parent = presencePanel
				populationLabel.AnchorPoint = Vector2.zero
				populationLabel.Position = UDim2.fromOffset(6,24)
				populationLabel.Size = UDim2.new(1,-12,0,34)
				populationLabel.TextSize = 10
				populationLabel.TextXAlignment = Enum.TextXAlignment.Left
				populationLabel.TextYAlignment = Enum.TextYAlignment.Top
				headerBottom = stepLabel.Position.Y.Offset + stepLabel.AbsoluteSize.Y
				presenceList.Position = UDim2.fromOffset(6,60)
				presenceList.Size = UDim2.new(1,-12,1,-66)
			end
			local footer = if mobileCompact and width>height then 38 elseif mobileCompact then 42 else 64
			local cardTop = math.max(headerBottom+6,if mobileCompact then 8 else 72)
			local actionTop = if mobileCompact then height-48 else height-76
			local cardHeight = math.max(80,actionTop-cardTop-10)
			local side = math.clamp(width*.14,96,if mobileCompact then 124 else 220)
			local left = arrowWidth+16
			local right = width-side-arrowWidth-28
			if width<=height then left=arrowWidth+12;right=width-arrowWidth-12 end
			local cardWidth = math.max(100,math.min(right-left,(cardHeight-footer)*1672/941,1400))
			local baselineWidth = if mobileCompact and width>height then math.max(100,math.min(right-left,(cardHeight-42)*1672/941,1400)) else cardWidth
			if mobileCompact and width>height then
				-- Grow within the actual header/CTA/sidebar budget, bounded at +10%.
				cardTop=math.max(headerBottom,8)
				actionTop=height-44
				left=arrowWidth+8;right=width-side-arrowWidth-20
				cardWidth=math.min(baselineWidth*1.10,right-left,(actionTop-cardTop-2-footer)*1672/941)
			end
			mapPanel:SetAttribute("H3BCardBaselineWidth",baselineWidth)
			cardHeight = cardWidth*941/1672+footer
			local center = (left+right)*.5
			mapSize.MaxSize = Vector2.new(1600,1200)
			mapPanel.Position = UDim2.fromOffset(center,cardTop)
			mapPanel.Size = UDim2.fromOffset(cardWidth,cardHeight)
			mapPanel.BackgroundTransparency = 0
			trackImageArea.Size = UDim2.new(1,0,1,-footer)
			trackInfo.Position = UDim2.new(0,0,1,-footer)
			trackInfo.Size = UDim2.new(1,0,0,footer)
			trackName.TextSize = if mobileCompact and width>height then 18 elseif mobileCompact then math.clamp(cardWidth*.05,18,25) else 30
			trackMetadata.TextSize = if mobileCompact then math.clamp(cardWidth*.03,12,15) else 18
			trackName.Size = UDim2.new(1,-16,0,if mobileCompact and width>height then 20 elseif mobileCompact then 22 else 34)
			trackMetadata.Position = UDim2.fromOffset(8,if mobileCompact and width>height then 21 elseif mobileCompact then 23 else 38)
			trackMetadata.Size = UDim2.new(1,-16,0,if mobileCompact and width>height then 16 elseif mobileCompact then 18 else 24)
			leftArrow.Position = UDim2.fromOffset(center-cardWidth*.5-arrowWidth-8,cardTop+(cardHeight-arrowHeight)*.5)
			rightArrow.Position = UDim2.fromOffset(center+cardWidth*.5+8,cardTop+(cardHeight-arrowHeight)*.5)
			controlsCard.Visible = false
			if width>height then
				presencePanel.AnchorPoint = Vector2.new(1,0)
				presencePanel.Position = UDim2.new(1,-10,0,cardTop)
				presencePanel.Size = UDim2.fromOffset(side,cardHeight)
				if mobileCompact then
					presenceGeometry.previewWidth=cardWidth;presenceGeometry.presenceWidth=side
					presenceGeometry.previewTop=cardTop;presenceGeometry.previewHeight=cardHeight
				end
			end
			for _,button in {previousButton,cycleButton,nextButton} do
				local ctaWidth=(cardWidth-16)*.5
				button.Size=UDim2.fromOffset(ctaWidth,if mobileCompact then 40 else 52)
				button.Position = UDim2.fromOffset(center-cardWidth*.5+(if button==previousButton then 0 else ctaWidth+16),actionTop)
			end
		end
	end

	local pendingLayoutMeasurements = true
	local function applyResponsiveLayout()
		local camera = Workspace.CurrentCamera
		local viewportSizePixels = if camera then camera.ViewportSize else backdrop.AbsoluteSize
		if viewportSizePixels.X <= 0 or viewportSizePixels.Y <= 0
			or headerGui.AbsoluteSize.X <= 0 or headerGui.AbsoluteSize.Y <= 0
			or backdrop.AbsoluteSize.X <= 0 or backdrop.AbsoluteSize.Y <= 0
			or title.AbsoluteSize.X <= 0 or title.AbsoluteSize.Y <= 0 then
			pendingLayoutMeasurements = true
			return
		end
		pendingLayoutMeasurements = false
		local portrait=viewportSizePixels.X<=viewportSizePixels.Y
		mobileCompact = portrait or (UserInputService.TouchEnabled and viewportSizePixels.X<1800)
		gui:SetAttribute("GarageLayoutClass",if portrait then "PORTRAIT" elseif mobileCompact then "TOUCH_LANDSCAPE" elseif viewportSizePixels.Y<=650 then "COMPACT_DESKTOP" else "DESKTOP")
		if mobileCompact then gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		else gui.IgnoreGuiInset = true end
		controlsCard.Visible = not mobileCompact
		populationLabel.Visible = not (mobileCompact and inviteModal.Visible)
		if mobileCompact then
			local safeSize = backdrop.AbsoluteSize
			local layoutWidth = if safeSize.X > 0 then safeSize.X else viewportSizePixels.X - 32
			local layoutHeight = if safeSize.Y > 0 then safeSize.Y else viewportSizePixels.Y - 40
			local selectionWidth = layoutWidth
			local previewCenter = selectionWidth * 0.5
			local previewWidth = math.max(180, math.min(selectionWidth * 0.64, 520, selectionWidth - 112))
			local previewHeight = math.min(layoutHeight * 0.30, 170)
			local previewSize = UDim2.fromOffset(previewWidth, previewHeight)
			viewportSize.MinSize = Vector2.zero
			loadingSize.MinSize = Vector2.zero
			mapSize.MinSize = Vector2.zero
			viewport.Size = previewSize
			viewport.Position = UDim2.new(0, previewCenter, 0.26, 0)
			previewLoading.Size = previewSize
			previewLoading.Position = viewport.Position
			mapPanel.Size = previewSize
			mapPanel.Position = viewport.Position
			title.Position = UDim2.fromScale(0.1, 0.035)
			title.Size = UDim2.fromScale(0.8, 0.085)
			titleSize.MinTextSize = 20
			-- Reserve a centered header lane, separate from the local Lobby list.
			local presenceWidth = math.min(165, math.max(54, (layoutWidth - previewWidth) * 0.5 - 16))
			local statusWidth = if layoutWidth < 500 then layoutWidth - 32
				else math.min(560, layoutWidth - 2 * (presenceWidth + 20))
			populationTwoLines = statusWidth < 400
			stepLabel.Position = UDim2.new(0.5, -statusWidth * 0.5, 0.13, 0)
			stepLabel.TextSize = 19
			stepLabel.Size = UDim2.fromOffset(statusWidth, 20)
			-- Keep the approved aggregate header width independent of the local list.
			presenceGeometry = { width = layoutWidth, height = layoutHeight, previewWidth = previewWidth,
				presenceWidth = presenceWidth, twoLines = populationTwoLines }
			presenceHeader.TextSize = 11
			presenceHeader.Size = UDim2.new(1, -12, 0, 20)
			presenceList.Position = UDim2.fromOffset(4, 26)
			populationLabel.Parent = backdrop
			populationLabel.AnchorPoint = Vector2.new(0.5, 0)
			populationLabel.Position = UDim2.new(0.5, 0, 0.13, 22)
			populationLabel.Size = UDim2.fromOffset(statusWidth, if populationTwoLines then 36 else 18)
			populationLabel.TextSize = 14
			populationLabel.TextXAlignment = Enum.TextXAlignment.Center
			populationLabel.TextYAlignment = Enum.TextYAlignment.Center
			presenceRowHeight = 16
			choiceLabel.Position = UDim2.fromScale(0.1, if step <= STEP_TRACK then 0.59 else 0.39)
			choiceLabel.TextSize = 25
			detailLabel.Position = UDim2.fromScale(0.1, if step <= STEP_TRACK then 0.68 else 0.55)
			detailLabel.TextSize = 15
			errorLabel.Position = UDim2.fromScale(0.1, 0.76)
			errorLabel.TextSize = 14
			leftArrow.Size = UDim2.fromOffset(40, 50)
			rightArrow.Size = leftArrow.Size
			leftArrow.Position = UDim2.new(0, previewCenter - previewWidth * 0.5 - 46, 0.38, 0)
			rightArrow.Position = UDim2.new(0, previewCenter + previewWidth * 0.5 + 6, 0.38, 0)
			local buttonWidth = math.min(150, (layoutWidth - 48) * 0.5)
			for _, button in { previousButton, cycleButton, nextButton } do
				button.Size = UDim2.fromOffset(buttonWidth, 40)
				button.TextSize = 17
			end
			previousButton.Position = UDim2.new(0.5, -buttonWidth - 8, 1, -48)
			cycleButton.Position = UDim2.new(0.5, if previousButton.Visible then 8 else -buttonWidth * 0.5, 1, -48)
			nextButton.Position = UDim2.new(0.5, 8, 1, -48)
		else
			viewportSize.MinSize = Vector2.new(360, 200)
			loadingSize.MinSize = viewportSize.MinSize
			mapSize.MinSize = viewportSize.MinSize
			viewport.Size = UDim2.fromScale(0.52, 0.32)
			viewport.Position = UDim2.fromScale(0.5, 0.265)
			previewLoading.Size = viewport.Size
			previewLoading.Position = viewport.Position
			mapPanel.Size = UDim2.fromScale(0.52, 0.32)
			mapPanel.Position = UDim2.fromScale(0.5, 0.265)
			title.Position = UDim2.fromScale(0.1, 0.055)
			title.Size = UDim2.fromScale(0.8, 0.09)
			titleSize.MinTextSize = 28
			stepLabel.Position = UDim2.fromScale(0.1, 0.17)
			stepLabel.TextSize = 24
			stepLabel.Size = UDim2.fromScale(0.8, 0.07)
			presencePanel.Position = UDim2.new(1, -16, 0.19, 0)
			presencePanel.Size = UDim2.fromOffset(205, 155)
			presenceHeader.TextSize = 14
			presenceHeader.Size = UDim2.new(1, -12, 0, 23)
			presenceList.Position = UDim2.fromOffset(6, 68)
			presenceList.Size = UDim2.new(1, -12, 1, -74)
			populationTwoLines = true
			populationLabel.Parent = presencePanel
			populationLabel.AnchorPoint = Vector2.zero
			populationLabel.Position = UDim2.fromOffset(6, 25)
			populationLabel.Size = UDim2.new(1, -12, 0, 42)
			populationLabel.TextSize = 12
			populationLabel.TextXAlignment = Enum.TextXAlignment.Left
			populationLabel.TextYAlignment = Enum.TextYAlignment.Top
			presenceRowHeight = 20
			choiceLabel.TextSize = 34
			detailLabel.TextSize = 19
			errorLabel.Position = UDim2.fromScale(0.1, 0.77)
			errorLabel.TextSize = 18
			leftArrow.Size = UDim2.fromOffset(52, 64)
			rightArrow.Size = leftArrow.Size
			leftArrow.Position = UDim2.new(0.5, -350, 0.43, 0)
			rightArrow.Position = UDim2.new(0.5, 298, 0.43, 0)
			for _, button in { previousButton, cycleButton, nextButton } do
				button.Size = UDim2.fromOffset(170, 48)
				button.TextSize = 19
			end
		end
		applyVisualStage(backdrop.AbsoluteSize, viewportSizePixels)
		choiceLabel.Visible = step ~= STEP_TRACK
		detailLabel.Visible = step == STEP_READY
		syncVisualShell()
		if GARAGE_LAYOUT_DEBUG then
			task.defer(function()
				if not gui.Parent then return end
				print("[GarageLayout]", GARAGE_LAYOUT_REVISION, "viewport", viewportSizePixels,
					"topbarInset", GuiService.TopbarInset, "guiInset", GuiService:GetGuiInset(),
					"headerMode", headerGui:GetAttribute("GarageHeaderMode"),
					"headerOrigin", headerGui.AbsolutePosition, "headerSize", headerGui.AbsoluteSize,
					"title.Position", title.Position, "title.AbsolutePosition", title.AbsolutePosition,
					"title.AbsoluteSize", title.AbsoluteSize, "step.AbsolutePosition", stepLabel.AbsolutePosition,
					"population.AbsolutePosition", populationLabel.AbsolutePosition,
					"preview.AbsolutePosition", viewport.AbsolutePosition, "preview.AbsoluteSize", viewport.AbsoluteSize)
			end)
		end
		updatePopulationText()
		updatePresence()
		fitSelectionPreview()
		if previewKart then startPreviewIdleRotation() end
	end
	local function clearTrackPreview()
		if trackMap then trackMap:destroy(); trackMap = nil end
		trackMapKey = nil
		trackImage.Visible = false
		trackImage.Image = ""
	end
	local trackImageRequests = {}
	local function syncTrackImage(loadedChanged: boolean?)
		if not trackMapKey then return end
		-- An unloaded image paints nothing; the silhouette stays beneath it.
		trackImage.Visible = true
		trackImage.ImageTransparency = 0
		if (loadedChanged and trackImage.IsLoaded) or trackImageRequests[trackImage.Image] == "SUCCESS" then
			if trackMap then trackMap:destroy(); trackMap = nil end
			mapPanel:SetAttribute("PreviewStatus","STATIC_IMAGE")
		end
	end
	local trackImageConnection = trackImage:GetPropertyChangedSignal("IsLoaded"):Connect(function() syncTrackImage(true) end)
	gui.Destroying:Connect(function() trackImageConnection:Disconnect(); clearTrackPreview() end)
	local function showTrackPreview(trackId: string)
		local track = TrackCatalog.Entries[trackId]
		local key = trackId .. ":" .. tostring(track.PreviewImageAssetId)
		if key == trackMapKey then return end
		clearTrackPreview()
		trackMapKey = key
		mapPanel:SetAttribute("TrackId",trackId)
		trackName.Text = track.DisplayName
  trackMetadata.TextColor3 = if track.MatchType == "PUBLIC_RACE" then Theme.PublicRace else Theme.TextSecondary
		trackMetadata.Text = if track.MatchType == "PUBLIC_RACE" then
			string.format("PUBLIC RACE \u{2022} %d\u{2013}%d PLAYERS \u{2022} %d %s",track.MinPlayers,track.MaxPlayers,track.TargetLaps,if track.TargetLaps==1 then "LAP" else "LAPS")
			else string.format("SOLO \u{2022} 1 PLAYER \u{2022} %d %s",track.TargetLaps,if track.TargetLaps==1 then "LAP" else "LAPS")
		-- A nonblocking silhouette is present until the approved image is ready.
		-- A missing/denied asset keeps this fallback; no launch/selection gate.
		local ok,fallback = pcall(function()
			local definition = TrackGeometry.getDefinition(track.GeometryId)
			assert(definition,"Track preview geometry missing")
			return TrackMapRenderer.create(trackImageArea,definition,false,track.PreviewRotationDegrees)
		end)
		if ok then
			trackMap = fallback
			for _,v in trackImageArea:GetDescendants() do
				if v:IsA("GuiObject") and v ~= trackImage then v.ZIndex = 3 end
			end
		end
		mapPanel:SetAttribute("PreviewStatus",if ok then "FALLBACK_2D" else "NEUTRAL")
		trackImage.Image = track.PreviewImageAssetId or ""
		syncTrackImage()
		-- Some cached textures become loaded without an IsLoaded notification.
		-- One delayed reconciliation per selection avoids a render/polling loop.
		task.delay(1, function()
			if gui.Parent and trackMapKey == key then syncTrackImage(true) end
		end)
		local asset = trackImage.Image
		if asset ~= "" and not trackImageRequests[asset] and ContentProvider.PreloadAsync then
			-- At most one nonblocking request per catalog image for this UI lifetime.
			trackImageRequests[asset] = "PENDING"
			task.spawn(function()
				local loaded, loadError = pcall(function()
					ContentProvider:PreloadAsync({asset}, function(_, status)
						trackImageRequests[asset] = if status == Enum.AssetFetchStatus.Success then "SUCCESS" else "FAILED"
						if gui.Parent and trackMapKey and trackImage.Image == asset then syncTrackImage() end
					end)
				end)
				if not loaded then warn("[TrackPreview] image preload failed", asset, loadError) end
			end)
		end
	end

	local function clearPreview()
		stopPreviewRotation()
		podium = nil
		previewKart = nil
		viewport.CurrentCamera = nil
		if previewWorld then
			previewWorld:Destroy()
			previewWorld = nil
		end
		if previewCamera then
			previewCamera:Destroy()
			previewCamera = nil
		end
		previewKey = nil
	end

	local function showPreview(kind: string, selectedId: string)
		local key = kind .. ":" .. selectedId .. ':' .. tostring(player:GetAttribute('KDMWingEquipped')==true)
		if previewKey == key then
			return
		end
		clearPreview()
		local world = Instance.new("WorldModel")
		world.Name = "PreviewWorld"
		world.Parent = viewport
		local camera = Instance.new("Camera")
		camera.Name = "PreviewCamera"
		camera.FieldOfView = 40
		camera.Parent = viewport
		if kind == "Kart" then
			local visual = KartVisualFactory.createVisual(KartCatalog.Entries[selectedId],player:GetAttribute('KDMWingEquipped')==true)
			visual.Name = "PreviewKart"
			for _, part in visual:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = true
				end
			end
			visual.Parent = world
			previewKart = visual
		end
		viewport.CurrentCamera = camera
		previewWorld = world
		previewCamera = camera
		previewKey = key
		previewYaw = math.rad(-135)
		fitSelectionPreview()
		-- A sibling of the fitted model: podium geometry never enters either fit helper.
		local model = previewKart
		if model then
			local box, bounds = model:GetBoundingBox()
			local bottom = math.huge
			for _, x in {-1, 1} do for _, y in {-1, 1} do for _, z in {-1, 1} do
				bottom = math.min(bottom, (box * Vector3.new(x * bounds.X / 2, y * bounds.Y / 2, z * bounds.Z / 2)).Y)
			end end end
			local diameter = math.max(bounds.X, bounds.Z) * 1.15
			podiumDiameter, podiumBottom, podiumCenter = diameter, bottom, box.Position
			podium = Instance.new("Folder")
			podium.Name = "ShowcasePodium"
			podium.Parent = world
			for _, disc in {{"GlowBase", .12, diameter, .32, GARAGE_COLORS.CyanSoft}, {"MainDisc", .12, diameter * .94, 0, GARAGE_COLORS.StageDeep}} do
				local part = Instance.new("Part")
				part.Name = disc[1]
				part.Shape = Enum.PartType.Cylinder
				part.Size = Vector3.new(disc[2], disc[3], disc[3])
				local surface = bottom - .025 - (if disc[1] == "GlowBase" then .12 else 0)
				part.CFrame = CFrame.new(box.Position.X, surface - disc[2] / 2, box.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
				part.Color = disc[5]
				part.Material = Enum.Material.SmoothPlastic
				part.Transparency = disc[4]
				part.Anchored = true
				part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = false, false, false, false
				part.Parent = podium
			end
			updateShowcasePodium()
		end
		startPreviewIdleRotation()
	end

 local update
 local colorTween = nil
 local acknowledgedKartId = nil
 local function committedKartId()
  local id=acknowledgedKartId or player:GetAttribute("SelectedKartId")
  return if KartCatalog.Entries[id] then id else KartCatalog.DefaultId
 end
 local kartControls=Instance.new("Frame")
 kartControls.Name,kartControls.BackgroundTransparency,kartControls.Parent="KartControls",1,backdrop
 local tabs, chips = {}, {}
 local families, familyOrder = {}, {}
 for _,id in KartCatalog.Order do
  local family=KartCatalog.Entries[id].VisualModelName
  if not families[family] then families[family]={};table.insert(familyOrder,family) end
  table.insert(families[family],id)
 end
 local chipRow=Instance.new("ScrollingFrame")
 chipRow.Name,chipRow.BackgroundTransparency,chipRow.BorderSizePixel="ColorChips",1,0
 chipRow.Position,chipRow.Size=UDim2.fromOffset(0,50),UDim2.new(1,0,0,48)
 chipRow.ScrollingDirection,chipRow.ScrollBarThickness=Enum.ScrollingDirection.X,3
 chipRow.Parent=kartControls
 local function chooseKart(id)
  if selectionPending or routeOverlay.Visible then return end
  kartIndex=table.find(KartCatalog.Order,id) or kartIndex
  update()
  if colorTween then colorTween:Cancel() end
  colorTween=TweenService:Create(viewport,TweenInfo.new(.2),{BackgroundColor3=Theme.Panel:Lerp(KartCatalog.Entries[id].DisplayColor or Theme.Selection,.18)})
  colorTween:Play()
 end
 for index,family in familyOrder do
  local tab=Instance.new("TextButton")
  tab.Name,tab.Text="Chassis_"..family,if family=="KDMV2" then "KDM V2" else "SPRINT V1"
  tab.Position,tab.Size=UDim2.new((index-1)/#familyOrder,2,0,0),UDim2.new(1/#familyOrder,-4,0,44)
  tab.Font,tab.TextSize,tab.BorderSizePixel=Enum.Font.GothamBold,16,0
  tab.Parent=kartControls;tabs[family]=tab
  tab.Activated:Connect(function() chooseKart(families[family][1]) end)
 end
 for _,id in KartCatalog.Order do
  local entry=KartCatalog.Entries[id]
  local chip=Instance.new("TextButton")
  chip.Name,chip.Size="Color_"..id,UDim2.fromOffset(44,44)
  chip.BackgroundColor3=entry.DisplayColor or entry.BodyColor or Theme.Panel
  chip.TextColor3=Theme.Selection;chip.Font,chip.TextSize=Enum.Font.GothamBold,22
  chip.BorderSizePixel=0;chip.Parent=chipRow
  local swatch=Instance.new("TextLabel")
  swatch.Name,swatch.Size,swatch.Position="Swatch",UDim2.fromOffset(32,32),UDim2.fromOffset(6,6)
  swatch.BackgroundColor3,swatch.BorderSizePixel=chip.BackgroundColor3,0
  swatch.Font,swatch.TextSize,swatch.TextColor3=chip.Font,18,chip.TextColor3
  swatch.Visible,swatch.Parent=false,chip
  local ring=Instance.new("UIStroke");ring.Name="SelectionRing";ring.Color,ring.Thickness,ring.Parent=Theme.Selection,2,chip
  chips[id]=chip
  chip.Activated:Connect(function() chooseKart(id) end)
 end
 local function layoutKartControls()
  shopButton.Visible=step==STEP_KART
  kartControls.Visible=step==STEP_KART
  if not kartControls.Visible then presencePanel.Visible=true; return end
  local position=viewport.Position
  local size=viewport.Size
  local canvas=backdrop.AbsoluteSize
  shopButton.AnchorPoint=Vector2.zero
  local actionY=cycleButton.AbsolutePosition.Y-backdrop.AbsolutePosition.Y
  if canvas.X<500 and canvas.Y>canvas.X then
   local width=(canvas.X-32)/3
   previousButton.Size,cycleButton.Size,shopButton.Size=UDim2.fromOffset(width,44),UDim2.fromOffset(width,44),UDim2.fromOffset(width,44)
   previousButton.Position=UDim2.fromOffset(8,actionY)
   cycleButton.Position=UDim2.fromOffset(16+width,actionY)
   shopButton.Position=UDim2.fromOffset(24+width*2,actionY)
  else
   shopButton.Size=UDim2.fromOffset(104,44)
   shopButton.Position=UDim2.fromOffset(math.min(canvas.X-116,cycleButton.AbsolutePosition.X-backdrop.AbsolutePosition.X+cycleButton.AbsoluteSize.X+12),actionY+(cycleButton.AbsoluteSize.Y-44)/2)
  end
  local sideControls=mobileCompact and canvas.X>canvas.Y
  presencePanel.Visible=not sideControls
  local reserved=102
  kartControls.AnchorPoint=viewport.AnchorPoint
  kartControls.Position=UDim2.new(position.X.Scale,position.X.Offset,position.Y.Scale,position.Y.Offset+size.Y.Offset-reserved)
  kartControls.Size=UDim2.new(size.X.Scale,size.X.Offset,0,reserved)
  viewport.Size=UDim2.new(size.X.Scale,size.X.Offset,size.Y.Scale,math.max(1,size.Y.Offset-reserved-4))
  previewLoading.Size=viewport.Size
  shell.Size=viewport.Size
  local columns=nil
  if sideControls then
   -- Compact selectors release width to the kart, with 44px touch targets.
   local controlsWidth=math.clamp(canvas.X*.23,192,208)
   local previewWidth=math.max(1,canvas.X-controlsWidth-136)
   viewport.Position=UDim2.fromOffset(64+previewWidth*.5,position.Y.Offset)
   viewport.Size=UDim2.fromOffset(previewWidth,size.Y.Offset)
   previewLoading.Position,previewLoading.Size=viewport.Position,viewport.Size
   shell.Position,shell.Size=viewport.Position,viewport.Size
   kartControls.AnchorPoint=Vector2.zero
   kartControls.Position=UDim2.fromOffset(canvas.X-controlsWidth-12,position.Y.Offset)
   kartControls.Size=UDim2.fromOffset(controlsWidth,size.Y.Offset+32)
   populationLabel.Parent,populationLabel.AnchorPoint=kartControls,Vector2.zero
   populationLabel.Position,populationLabel.Size=UDim2.fromOffset(0,0),UDim2.new(1,0,0,20)
   populationLabel.TextSize=10
   chipRow.Position,chipRow.Size=UDim2.fromOffset(0,74),UDim2.new(1,0,1,-74)
   chipRow.ScrollingDirection=Enum.ScrollingDirection.Y
   columns=math.max(1,math.floor(controlsWidth/48))
   leftArrow.Position=UDim2.fromOffset(12,position.Y.Offset+(size.Y.Offset-leftArrow.Size.Y.Offset)*.5)
   rightArrow.Position=UDim2.fromOffset(64+previewWidth+8,leftArrow.Position.Y.Offset)
  else
   chipRow.Position=UDim2.fromOffset(0,50)
   chipRow.Size=UDim2.new(1,0,0,48)
   chipRow.ScrollingDirection=Enum.ScrollingDirection.X
  end
  local id=KartCatalog.Order[kartIndex]
  local family=KartCatalog.Entries[id].VisualModelName
  local chipPitch=if sideControls then 48 else 50
  local index=0
  for _,key in KartCatalog.Order do
   local chip=chips[key];chip.Visible=KartCatalog.Entries[key].VisualModelName==family
   if chip.Visible then chip.Position=UDim2.fromOffset(if columns then index%columns*chipPitch else index*chipPitch,if columns then math.floor(index/columns)*chipPitch else 0);index+=1 end
   chip.Text=if key==id then "\u{2713}" else ""
   chip.BackgroundTransparency,chip.TextTransparency=if sideControls then 1 else 0,if sideControls then 1 else 0
   chip.Swatch.Visible,chip.Swatch.Text=sideControls,chip.Text
   chip.SelectionRing.Transparency=if key==id then 0 else 1
   chip.Active=selectionPending==nil
  end
  chipRow.CanvasSize=if columns then UDim2.fromOffset(0,math.ceil(index/columns)*chipPitch) else UDim2.fromOffset(index*chipPitch,0)
  for key,tab in tabs do
   tab.Position=UDim2.new(tab.Position.X.Scale,tab.Position.X.Offset,0,if sideControls then 24 else 0)
   tab.TextSize=if sideControls then 12 else 16
   tab.BackgroundColor3=if key==family then Theme.Selection else Theme.Panel
   tab.TextColor3=if key==family then Theme.Background else Theme.TextPrimary
  end
  fitSelectionPreview()
 end
 gui.Destroying:Connect(function() if colorTween then colorTween:Cancel() end end)
	local function selectedIds(): (string, string, string)
		return DriverCatalog.DefaultId, if step == STEP_KART then KartCatalog.Order[kartIndex] else committedKartId(), trackOrder[trackIndex]
	end
	local inviteSerial = 0
	remote.OnClientEvent:Connect(function(action, hostName, trackId, count, maxPlayers)
		if action == "KartSelected" or action == "KartSelectionRejected" then
   if not selectionPending then return end
   local accepted=action=="KartSelected" and hostName==selectionPending
   selectionPending=nil
   if accepted then acknowledgedKartId=hostName; GarageUiController.close() else update() end
   return
  end
  if action == "RouteLaunchFailed" then
			localRouteRequested = false
			updateRouteOverlay()
			return
		end
		if action == "InviteExpired" then
			inviteModal.Visible = false
			return
		end
		if action ~= "Invite" or player:GetAttribute("RaceState") ~= "GARAGE" then return end
		local track = TrackCatalog.Entries[trackId]
		if not track then return end
		inviteSerial += 1
		local serial = inviteSerial
		inviteDescription.Text = string.format("%s invited you to\n%s\nRACERS %d / %d",
			tostring(hostName), track.DisplayName, count, maxPlayers)
		inviteModal.Visible = true
		task.delay(30, function()
			if serial == inviteSerial then inviteModal.Visible = false end
		end)
	end)
	declineInvite.Activated:Connect(function()
		inviteSerial += 1
		inviteModal.Visible = false
		remote:FireServer("DeclineInvite")
	end)
	joinInvite.Activated:Connect(function()
		if not inviteModal.Visible then return end
		inviteSerial += 1
		inviteModal.Visible = false
		local driverId = DriverCatalog.DefaultId
		remote:FireServer("JoinInvite", driverId, committedKartId())
	end)

	local texturePreload = GarageTexturePreload.create(KartCatalog, ContentProvider, task, function()
		if gui.Parent and player:GetAttribute("RaceState") == "GARAGE" then update() end
	end)
	gui.Destroying:Connect(function() texturePreload.destroy() end)
	update = function()
		local raceState = player:GetAttribute("RaceState")
		if raceState ~= "GARAGE" then overlayOpen = false; player:SetAttribute("HubOverlayOpen", false) end
		gui.Enabled = raceState == "GARAGE" and overlayOpen
		inviteGui.Enabled = raceState == "GARAGE"
		if not gui.Enabled then
			if raceState ~= "GARAGE" then inviteModal.Visible = false end
			tutorial.close()
			controlsButton.Visible = false
			mapPanel.Visible = false
			previewLoading.Visible = false
			clearPreview()
			clearTrackPreview()
			return
		end
		local driverId, kartId, trackId = selectedIds()
		texturePreload.start()
		controlsButton.Visible = Input.isTouchPreferred() and step == STEP_READY
		if controlsButton.Visible and not tutorialSeenThisSession
			and player:GetAttribute("ControlsTutorialPreferenceLoaded") == true
			and player:GetAttribute("ControlsTutorialDismissed") ~= true then
			tutorialSeenThisSession = true
			tutorial.open()
		end
		stepLabel.Text = headings[step]
		viewport.Visible = step <= STEP_KART
		mapPanel.Visible = step == STEP_TRACK
		choiceLabel.Position = UDim2.fromScale(0.1, if step <= STEP_TRACK then 0.61 else 0.40)
		detailLabel.Position = UDim2.fromScale(0.1, if step <= STEP_TRACK then 0.70 else 0.54)
		if step == STEP_KART then
			clearTrackPreview()
			local waiting = texturePreload.shouldWait(KartCatalog.Entries[kartId])
			previewLoading.Text = "Loading kart..."
			previewLoading.Visible = waiting
			if waiting then clearPreview() else showPreview("Kart", kartId) end
		else
			previewLoading.Visible = false
			clearPreview()
			if step == STEP_TRACK then
				showTrackPreview(trackId)
			else clearTrackPreview() end
		end
		if step <= STEP_TRACK then
			local catalog = catalogs[step]
			local selectedId = if step == STEP_KART then kartId else trackId
			choiceLabel.Text = catalog.Entries[selectedId].DisplayName
			detailLabel.Text = if step <= STEP_KART then ""
				else (if TrackCatalog.Entries[trackId].MatchType == "PUBLIC_RACE" then TrackCatalog.capabilityLabel(TrackCatalog.Entries[trackId])
				else string.format("SOLO \u{2022} 1 PLAYER \u{2022} %d %s", TrackCatalog.Entries[trackId].TargetLaps, if TrackCatalog.Entries[trackId].TargetLaps == 1 then "LAP" else "LAPS"))
		else
			choiceLabel.Text = string.format("%s / %s", KartCatalog.Entries[kartId].DisplayName, TrackCatalog.Entries[trackId].DisplayName)
			detailLabel.Text = TrackCatalog.capabilityLabel(TrackCatalog.Entries[trackId])
		end
		previousButton.Visible = true
		cycleButton.Text = if step == STEP_KART then "USE KART" elseif step == STEP_TRACK and TrackCatalog.Entries[trackId].MatchType == "PUBLIC_RACE" then "RACE LIST" else "SELECT"
		cycleButton.Active = selectionPending == nil
		cycleButton.Visible = step <= STEP_TRACK
		nextButton.Visible = step == STEP_READY
		leftArrow.Visible = step <= STEP_TRACK and #catalogs[step].Order > 1
		rightArrow.Visible = leftArrow.Visible
		previousButton.Position = UDim2.new(0.5, -180, 0.84, 0)
		cycleButton.Position = UDim2.new(0.5, if previousButton.Visible then 10 else -85, 0.84, 0)
		nextButton.Position = UDim2.new(0.5, 10, 0.84, 0)
		errorLabel.Text = tostring(player:GetAttribute("RaceEntryError") or "")
		updateRouteOverlay()
		applyResponsiveLayout()
		choiceLabel.Visible = step ~= STEP_TRACK
		detailLabel.Visible = step == STEP_READY
  layoutKartControls()
	end


 shopContext=function()
  if localRouteRequested or selectionPending or routeOverlay.Visible then return nil end
  if not overlayOpen then return 'LOBBY' end
  return if step==STEP_KART then 'KART' else nil
 end
 openOverlay = function(action, confirmedTrackId)
  if openGate and openGate(function() openOverlay(action, confirmedTrackId) end) then return end
  if player:GetAttribute("RaceState") ~= "GARAGE" or localRouteRequested
   or player:GetAttribute("KDMRoutePending") == "RACE_LAUNCH" then return end
  -- A browser acknowledgement can come from an Invite as well as Track Select.
  local roomsTrackId = confirmedTrackId or trackOrder[trackIndex]
  local roomsTrack = TrackCatalog.Entries[roomsTrackId]
  if action == "ROOMS" and roomsTrack and roomsTrack.MatchType == "PUBLIC_RACE" then
   remote:FireServer("Ready", DriverCatalog.DefaultId, committedKartId(), roomsTrackId)
   return
  end
  step = if action == "TRACK" or action == "TRACKS" or action == "RACE" or action == "ROOMS" then STEP_TRACK else STEP_KART
  if action~="SHOP_RETURN" then kartIndex = table.find(KartCatalog.Order, committedKartId()) or 1 end
  -- Open the showroom on V2; browsing still requires USE KART to commit a choice.
  if action~="SHOP_RETURN" and step == STEP_KART and KartCatalog.Entries[KartCatalog.Order[kartIndex]].VisualModelName ~= "KDMV2" then
   for index, id in KartCatalog.Order do
    if KartCatalog.Entries[id].VisualModelName == "KDMV2" then kartIndex = index; break end
   end
  end
  selectionPending = nil
  viewport.BackgroundColor3=Theme.Panel:Lerp(KartCatalog.Entries[KartCatalog.Order[kartIndex]].DisplayColor or Theme.Selection,.18)
  if action~="SHOP_RETURN" then chipRow.CanvasPosition = Vector2.zero end
  overlayOpen = true
  player:SetAttribute("HubOverlayOpen", true)
  notifyNavigation("Opened", if step == STEP_KART then "GARAGE" else "TRACKS")
  update()
 end
 closeOverlay = function()
  if localRouteRequested or player:GetAttribute("KDMRoutePending") == "RACE_LAUNCH" then return end
  selectionPending = nil
  overlayOpen = false
  notifyNavigation("Returned", if step == STEP_KART then "GARAGE" else "TRACKS")
  player:SetAttribute("HubOverlayOpen", false)
  update()
 end

	local function changeChoice(direction: number)
		if routeOverlay.Visible or selectionPending then return end
		if step == STEP_KART then
			chooseKart(KartCatalog.Order[(kartIndex - 1 + direction + #KartCatalog.Order) % #KartCatalog.Order + 1]);return
		elseif step == STEP_TRACK then
			trackIndex = (trackIndex - 1 + direction + #trackOrder) % #trackOrder + 1
		end
		update()
		clearSelectionPulse()
		shellStroke.Transparency = .2
		selectionTween = TweenService:Create(shellStroke, TweenInfo.new(.22), {Transparency = .55})
		selectionTween:Play()
	end
	leftArrow.Activated:Connect(function()
		changeChoice(-1)
	end)
	rightArrow.Activated:Connect(function()
		changeChoice(1)
	end)

	previousButton.Activated:Connect(function()
		if routeOverlay.Visible then return end
		if step <= STEP_TRACK then GarageUiController.close(); return end
		step = STEP_TRACK
		update()
	end)
	cycleButton.Activated:Connect(function()
		if routeOverlay.Visible then return end
  if step == STEP_KART then
   if selectionPending then return end
   selectionPending=KartCatalog.Order[kartIndex]
   remote:FireServer("SelectKart",selectionPending)
  elseif TrackCatalog.Entries[trackOrder[trackIndex]].MatchType == "PUBLIC_RACE" then
   local driverId,kartId,trackId=selectedIds()
   remote:FireServer("Ready",driverId,kartId,trackId)
  else step=STEP_READY; notifyNavigation("TrackConfirmed", trackOrder[trackIndex]) end
  update()
	end)
	nextButton.Activated:Connect(function()
		if routeOverlay.Visible then return end
		if step == STEP_READY then
			local driverId, kartId, trackId = selectedIds()
			local track = TrackCatalog.Entries[trackId]
			if track and (track.MatchType == "SOLO_PRACTICE" or track.MatchType == "SOLO_PROTOTYPE") then
				localRouteRequested = true
				updateRouteOverlay()
			end
			remote:FireServer("Ready", driverId, kartId, trackId)
		end
	end)
	player:GetAttributeChangedSignal("RaceState"):Connect(function()
		if player:GetAttribute("RaceState") == "GARAGE" then
			step = STEP_KART
			overlayOpen = false
			player:SetAttribute("HubOverlayOpen", false)
		end
		update()
	end)
	player:GetAttributeChangedSignal("KDMRoutePending"):Connect(function()
		localRouteRequested = false
		updateRouteOverlay()
	end)
	player:GetAttributeChangedSignal("SelectedKartId"):Connect(function() acknowledgedKartId=nil; update() end)
 player:GetAttributeChangedSignal('KDMWingEquipped'):Connect(function() acknowledgedKartId=nil; update() end)
	player:GetAttributeChangedSignal("RaceEntryError"):Connect(update)
	player:GetAttributeChangedSignal("ControlsTutorialPreferenceLoaded"):Connect(update)
	player:GetAttributeChangedSignal("ControlsTutorialDismissed"):Connect(update)
	local viewportConnection: RBXScriptConnection? = nil
	local layoutConnections = {}
	local function bindCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
			viewportConnection = nil
		end
		local camera = Workspace.CurrentCamera
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	table.insert(layoutConnections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
	table.insert(layoutConnections, GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(update))
	table.insert(layoutConnections, backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
	table.insert(layoutConnections, headerGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
	table.insert(layoutConnections, headerGui:GetPropertyChangedSignal("AbsolutePosition"):Connect(update))
	table.insert(layoutConnections, backdrop:GetPropertyChangedSignal("AbsolutePosition"):Connect(update))
	table.insert(layoutConnections, title:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		-- Only a startup measurement may request layout. Resizing this label is
		-- layout output, so observing every change would recursively re-layout it.
		if pendingLayoutMeasurements then update() end
	end))
	gui.Destroying:Connect(function()
		if viewportConnection then viewportConnection:Disconnect(); viewportConnection = nil end
		for _, connection in layoutConnections do connection:Disconnect() end
	end)
	bindCamera()
	local characterChildConnection: RBXScriptConnection? = nil
	local function bindCharacter(character: Model)
		if characterChildConnection then
			characterChildConnection:Disconnect()
		end
		-- Appearance parts can reach the client after HasAppearanceLoaded becomes true.
		characterChildConnection = character.ChildAdded:Connect(function()
			if player.Character == character and player:GetAttribute("RaceState") == "GARAGE" and overlayOpen then
				clearPreview()
				update()
			end
		end)
		clearPreview()
		update()
	end
	player.CharacterRemoving:Connect(function() clearPreview() end)
	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		bindCharacter(player.Character)
	end
	update()
	print("[RobloxKart] Garage UI ready")
end

return GarageUiController
