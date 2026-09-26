local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DriverCatalog = require(Shared:WaitForChild("DriverCatalog"))
local KartCatalog = require(Shared:WaitForChild("KartCatalog"))
local TrackCatalog = require(Shared:WaitForChild("TrackCatalog"))
local TrackGeometry = require(Shared:WaitForChild("TrackGeometry"))
local KartVisualFactory = require(Shared:WaitForChild("KartVisualFactory"))
local KartPreviewFraming = require(Shared:WaitForChild("KartPreviewFraming"))
local DriverAppearance = require(Shared:WaitForChild("DriverAppearance"))
local TrackMapRenderer = require(script.Parent:WaitForChild("TrackMapRenderer"))

local requireModule = require :: (ModuleScript) -> any
local RaceMode = requireModule(Shared:WaitForChild("RaceMode") :: ModuleScript)

local GarageUiController = {}
local started = false

local function makeText(parent: Instance, size: UDim2, position: UDim2, text: string, fontSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
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
	button.BackgroundColor3 = Color3.fromRGB(45, 130, 235)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 19
	button.Text = text
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

local function makeFallbackDriver(driver: { [string]: any }): Model
	local model = Instance.new("Model")
	model.Name = "PreviewDriver"
	local function piece(name: string, size: Vector3, position: Vector3, color: Color3, shape: Enum.PartType?)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Position = position
		part.Shape = shape or Enum.PartType.Block
		part.Color = color
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Parent = model
	end
	local dark = Color3.fromRGB(38, 43, 51)
	piece("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0.25, 0), driver.Theme)
	piece("Head", Vector3.new(1.1, 1.1, 1.1), Vector3.new(0, 1.8, 0), Color3.fromRGB(225, 185, 145), Enum.PartType.Ball)
	piece("LeftArm", Vector3.new(0.65, 1.8, 0.8), Vector3.new(-1.4, 0.3, 0), driver.Theme)
	piece("RightArm", Vector3.new(0.65, 1.8, 0.8), Vector3.new(1.4, 0.3, 0), driver.Theme)
	piece("LeftLeg", Vector3.new(0.8, 2, 0.85), Vector3.new(-0.55, -1.75, 0), dark)
	piece("RightLeg", Vector3.new(0.8, 2, 0.85), Vector3.new(0.55, -1.75, 0), dark)
	DriverAppearance.applyHairStyle(model)
	return model
end

local function cloneDriver(character: Model?, driver: { [string]: any }): Model
	if not character then
		return makeFallbackDriver(driver)
	end
	local wasArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = wasArchivable
	if not clone or not clone:FindFirstChild("Head") then
		if clone then
			clone:Destroy()
		end
		return makeFallbackDriver(driver)
	end
	clone.Name = "PreviewDriver"
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	clone:PivotTo(CFrame.new(0, 0, 0))
	DriverAppearance.applyToCharacter(clone, driver)
	return clone
end

function GarageUiController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local remote = ReplicatedStorage:WaitForChild("GarageControl") :: RemoteEvent
	local gui = Instance.new("ScreenGui")
	gui.Name = "RobloxKartGarage"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(12, 19, 31)
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local title = makeText(backdrop, UDim2.fromScale(0.8, 0.09), UDim2.fromScale(0.1, 0.055), "ROBLOX KART", 40)
	title.TextColor3 = Color3.fromRGB(255, 215, 75)
	title.TextScaled = true
	local titleSize = Instance.new("UITextSizeConstraint")
	titleSize.MaxTextSize = 40
	titleSize.MinTextSize = 28
	titleSize.Parent = title
	local stepLabel = makeText(backdrop, UDim2.fromScale(0.8, 0.07), UDim2.fromScale(0.1, 0.17), "", 24)
	local choiceLabel = makeText(backdrop, UDim2.fromScale(0.8, 0.08), UDim2.fromScale(0.1, 0.61), "", 34)
	local detailLabel = makeText(backdrop, UDim2.fromScale(0.8, 0.12), UDim2.fromScale(0.1, 0.70), "", 19)
	detailLabel.TextWrapped = true
	local errorLabel = makeText(backdrop, UDim2.fromScale(0.8, 0.05), UDim2.fromScale(0.1, 0.77), "", 18)
	errorLabel.TextColor3 = Color3.fromRGB(255, 110, 110)

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "SelectionPreview"
	viewport.AnchorPoint = Vector2.new(0.5, 0)
	viewport.Position = UDim2.fromScale(0.5, 0.265)
	viewport.Size = UDim2.fromScale(0.52, 0.32)
	viewport.BackgroundColor3 = Color3.fromRGB(22, 32, 48)
	viewport.BackgroundTransparency = 0.1
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(145, 152, 165)
	viewport.LightColor = Color3.fromRGB(235, 230, 220)
	viewport.LightDirection = Vector3.new(-1, -1, -0.6)
	viewport.Parent = backdrop
	local viewportSize = Instance.new("UISizeConstraint")
	viewportSize.MinSize = Vector2.new(360, 200)
	viewportSize.MaxSize = Vector2.new(680, 340)
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
	mapPanel.BackgroundColor3 = Color3.fromRGB(22, 32, 48)
	mapPanel.BorderSizePixel = 0
	mapPanel.Visible = false
	mapPanel.Parent = backdrop
	local mapSize = Instance.new("UISizeConstraint")
	mapSize.MinSize = viewportSize.MinSize
	mapSize.MaxSize = viewportSize.MaxSize
	mapSize.Parent = mapPanel
	local mapCorner = Instance.new("UICorner")
	mapCorner.CornerRadius = UDim.new(0, 12)
	mapCorner.Parent = mapPanel
	local startLegend = makeText(mapPanel, UDim2.fromOffset(155, 22), UDim2.new(0, 14, 1, -32), "● START / FINISH", 13)
	startLegend.TextColor3 = Color3.fromRGB(255, 205, 55)
	startLegend.TextXAlignment = Enum.TextXAlignment.Left
	local function makeArrow(text: string, xOffset: number): TextButton
		local arrow = makeButton(backdrop, text, UDim2.new(0.5, xOffset, 0.43, 0))
		arrow.Name = if xOffset < 0 then "PreviousChoice" else "NextChoice"
		arrow.Size = UDim2.fromOffset(52, 64)
		arrow.BackgroundColor3 = Color3.fromRGB(36, 51, 73)
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
	controlsCard.Size = UDim2.fromOffset(292, 124)
	controlsCard.BackgroundColor3 = Color3.fromRGB(22, 32, 48)
	controlsCard.BackgroundTransparency = 0.08
	controlsCard.BorderSizePixel = 0
	controlsCard.Parent = backdrop
	local controlsCorner = Instance.new("UICorner")
	controlsCorner.CornerRadius = UDim.new(0, 10)
	controlsCorner.Parent = controlsCard
	local controlsTitle = makeText(controlsCard, UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 8), "CONTROLS", 17)
	controlsTitle.TextColor3 = Color3.fromRGB(255, 215, 75)
	controlsTitle.TextXAlignment = Enum.TextXAlignment.Left
	for index, hint in {
		"W / S   Accelerate / Brake & Reverse",
		"A / D   Steer",
		"SHIFT   Drift",
	} do
		local line = makeText(controlsCard, UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 34 + (index - 1) * 26), hint, 14)
		line.Font = Enum.Font.Gotham
		line.TextXAlignment = Enum.TextXAlignment.Left
	end

	local previousButton = makeButton(backdrop, "BACK", UDim2.new(0.5, -270, 0.84, 0))
	local cycleButton = makeButton(backdrop, "SELECT", UDim2.new(0.5, -85, 0.84, 0))
	local nextButton = makeButton(backdrop, "READY", UDim2.new(0.5, 100, 0.84, 0))

	local step = 1
	local driverIndex = 1
	local kartIndex = 1
	local trackIndex = 1
	local catalogs = { DriverCatalog, KartCatalog, TrackCatalog }
	local headings = { "1 / 4   DRIVER SELECT", "2 / 4   KART SELECT", "3 / 4   TRACK SELECT", "4 / 4   READY" }
	local previewKey: string? = nil
	local previewWorld: WorldModel? = nil
	local previewCamera: Camera? = nil
	local trackMap = nil
	local trackMapGeometryId: string? = nil
	local mobileCompact = false
	local previewKart: Model? = nil
	local function fitKartPreview()
		if previewKart and previewCamera and viewport.AbsoluteSize.Y > 0 then
			local fitted = KartPreviewFraming.fit(previewKart, viewport.AbsoluteSize.X / viewport.AbsoluteSize.Y, previewCamera.FieldOfView)
			if fitted then previewCamera.CFrame = fitted end
		end
	end
	viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitKartPreview)

	local function applyResponsiveLayout()
		local camera = Workspace.CurrentCamera
		local viewportSizePixels = if camera then camera.ViewportSize else backdrop.AbsoluteSize
		mobileCompact = viewportSizePixels.Y > 0 and viewportSizePixels.Y <= 650
		gui.IgnoreGuiInset = not mobileCompact
		controlsCard.Visible = not mobileCompact
		if mobileCompact then
			local safeSize = backdrop.AbsoluteSize
			local layoutWidth = if safeSize.X > 0 then safeSize.X else viewportSizePixels.X - 32
			local layoutHeight = if safeSize.Y > 0 then safeSize.Y else viewportSizePixels.Y - 40
			-- Reserve the same right-side capture rail as the race HUD. Move the
			-- entire preview and its arrows together, keeping arrows beside models.
			local captureReserve = if viewportSizePixels.X > viewportSizePixels.Y and viewportSizePixels.Y <= 500 then 128 else 0
			local selectionWidth = layoutWidth - captureReserve
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
			title.Size = UDim2.fromScale(0.8, 0.10)
			titleSize.MinTextSize = 20
			stepLabel.Position = UDim2.fromScale(0.1, 0.16)
			stepLabel.TextSize = 19
			choiceLabel.Position = UDim2.fromScale(0.1, if step <= 3 then 0.59 else 0.39)
			choiceLabel.TextSize = 25
			detailLabel.Position = UDim2.fromScale(0.1, if step <= 3 then 0.68 else 0.55)
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
			previousButton.Position = UDim2.new(0.5, -buttonWidth - 8, 0.85, 0)
			cycleButton.Position = UDim2.new(0.5, if previousButton.Visible then 8 else -buttonWidth * 0.5, 0.85, 0)
			nextButton.Position = UDim2.new(0.5, 8, 0.85, 0)
		else
			viewportSize.MinSize = Vector2.new(360, 200)
			loadingSize.MinSize = viewportSize.MinSize
			mapSize.MinSize = viewportSize.MinSize
			viewport.Size = UDim2.fromScale(0.52, 0.32)
			viewport.Position = UDim2.fromScale(0.5, 0.265)
			previewLoading.Size = viewport.Size
			previewLoading.Position = viewport.Position
			mapPanel.Size = viewport.Size
			mapPanel.Position = viewport.Position
			title.Position = UDim2.fromScale(0.1, 0.055)
			title.Size = UDim2.fromScale(0.8, 0.09)
			titleSize.MinTextSize = 28
			stepLabel.Position = UDim2.fromScale(0.1, 0.17)
			stepLabel.TextSize = 24
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
	end
	local function showTrackPreview(trackId: string)
		local geometryId = TrackCatalog.Entries[trackId].GeometryId
		if geometryId == trackMapGeometryId then
			return
		end
		if trackMap then
			trackMap:destroy()
		end
		local definition = TrackGeometry.getDefinition(geometryId)
		assert(definition, "Selected track geometry is missing")
		trackMap = TrackMapRenderer.create(mapPanel, definition, false)
		trackMapGeometryId = geometryId
	end

	local function clearPreview()
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
		local key = kind .. ":" .. selectedId
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
			local visual = KartVisualFactory.createVisual(KartCatalog.Entries[selectedId])
			visual.Name = "PreviewKart"
			for _, part in visual:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = true
				end
			end
			visual.Parent = world
			previewKart = visual
		else
			local driver = cloneDriver(player.Character, DriverCatalog.Entries[selectedId])
			driver.Parent = world
			camera.CFrame = CFrame.new(Vector3.new(-5, 2.3, -9), Vector3.new(0, 0, 0))
		end
		viewport.CurrentCamera = camera
		previewWorld = world
		previewCamera = camera
		previewKey = key
		fitKartPreview()
	end

	local function selectedIds(): (string, string, string)
		return DriverCatalog.Order[driverIndex], KartCatalog.Order[kartIndex], TrackCatalog.Order[trackIndex]
	end

	local function update()
		local raceState = player:GetAttribute("RaceState")
		gui.Enabled = raceState == "GARAGE" or raceState == "PRE_RACE"
		if not gui.Enabled then
			mapPanel.Visible = false
			previewLoading.Visible = false
			clearPreview()
			return
		end
		if raceState == "PRE_RACE" then
			mapPanel.Visible = false
			leftArrow.Visible = false
			rightArrow.Visible = false
			viewport.Visible = false
			previewLoading.Visible = false
			clearPreview()
			choiceLabel.Position = UDim2.fromScale(0.1, 0.40)
			detailLabel.Position = UDim2.fromScale(0.1, 0.54)
			stepLabel.Text = "PREPARING GRID"
			choiceLabel.Text = "GET READY"
			detailLabel.Text = "Placing your driver in the kart"
			errorLabel.Text = ""
			previousButton.Visible = false
			cycleButton.Visible = false
			nextButton.Visible = false
			applyResponsiveLayout()
			return
		end
		local driverId, kartId, trackId = selectedIds()
		local mode = RaceMode.resolve(trackId)
		stepLabel.Text = headings[step]
		viewport.Visible = step <= 2
		mapPanel.Visible = step == 3
		choiceLabel.Position = UDim2.fromScale(0.1, if step <= 3 then 0.61 else 0.40)
		detailLabel.Position = UDim2.fromScale(0.1, if step <= 3 then 0.70 else 0.54)
		if step == 1 then
			local character = player.Character
			local appearanceReady = character ~= nil and character:FindFirstChild("Head") ~= nil and player:HasAppearanceLoaded()
			previewLoading.Visible = not appearanceReady
			if appearanceReady then
				showPreview("Driver", driverId)
			else
				clearPreview()
			end
		elseif step == 2 then
			previewLoading.Visible = false
			showPreview("Kart", kartId)
		else
			previewLoading.Visible = false
			clearPreview()
			if step == 3 then
				showTrackPreview(trackId)
			end
		end
		if step <= 3 then
			local catalog = catalogs[step]
			local selectedId = if step == 1 then driverId elseif step == 2 then kartId else trackId
			choiceLabel.Text = catalog.Entries[selectedId].DisplayName
			detailLabel.Text = if step == 1 then (DriverCatalog.Entries[driverId].Description or "Choose your racing driver")
				elseif step == 2 then "All MVP karts use the same physics"
				else RaceMode.label(mode) .. "\n" .. (if mode == RaceMode.PRACTICE then "Practice driving and item timing" else "Complete three laps")
		else
			choiceLabel.Text = RaceMode.label(mode)
			detailLabel.Text = string.format("%s  /  %s  /  %s", DriverCatalog.Entries[driverId].DisplayName, KartCatalog.Entries[kartId].DisplayName, TrackCatalog.Entries[trackId].DisplayName)
		end
		previousButton.Visible = step > 1
		cycleButton.Visible = step <= 3
		nextButton.Visible = step == 4
		leftArrow.Visible = step <= 3 and #catalogs[step].Order > 1
		rightArrow.Visible = leftArrow.Visible
		previousButton.Position = UDim2.new(0.5, -180, 0.84, 0)
		cycleButton.Position = UDim2.new(0.5, if previousButton.Visible then 10 else -85, 0.84, 0)
		nextButton.Position = UDim2.new(0.5, 10, 0.84, 0)
		errorLabel.Text = tostring(player:GetAttribute("RaceEntryError") or "")
		applyResponsiveLayout()
	end

	local function changeChoice(direction: number)
		if step == 1 then
			driverIndex = (driverIndex - 1 + direction + #DriverCatalog.Order) % #DriverCatalog.Order + 1
		elseif step == 2 then
			kartIndex = (kartIndex - 1 + direction + #KartCatalog.Order) % #KartCatalog.Order + 1
		elseif step == 3 then
			trackIndex = (trackIndex - 1 + direction + #TrackCatalog.Order) % #TrackCatalog.Order + 1
		end
		update()
	end
	leftArrow.Activated:Connect(function()
		changeChoice(-1)
	end)
	rightArrow.Activated:Connect(function()
		changeChoice(1)
	end)

	previousButton.Activated:Connect(function()
		step = math.max(1, step - 1)
		update()
	end)
	cycleButton.Activated:Connect(function()
		step = math.min(4, step + 1)
		update()
	end)
	nextButton.Activated:Connect(function()
		if step == 4 then
			local driverId, kartId, trackId = selectedIds()
			remote:FireServer("Ready", driverId, kartId, trackId)
		end
	end)
	player:GetAttributeChangedSignal("RaceState"):Connect(function()
		if player:GetAttribute("RaceState") == "GARAGE" then
			step = 1
		end
		update()
	end)
	player:GetAttributeChangedSignal("RaceEntryError"):Connect(update)
	local viewportConnection: RBXScriptConnection? = nil
	local function bindCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	bindCamera()
	local characterChildConnection: RBXScriptConnection? = nil
	local function bindCharacter(character: Model)
		if characterChildConnection then
			characterChildConnection:Disconnect()
		end
		-- Appearance parts can reach the client after HasAppearanceLoaded becomes true.
		characterChildConnection = character.ChildAdded:Connect(function()
			if player.Character == character and player:GetAttribute("RaceState") == "GARAGE" and step == 1 then
				clearPreview()
				update()
			end
		end)
		clearPreview()
		update()
		task.spawn(function()
			while player.Character == character and (not character:FindFirstChild("Head") or not player:HasAppearanceLoaded()) do
				task.wait(0.1)
			end
			if player.Character == character then
				clearPreview()
				update()
			end
		end)
	end
	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		bindCharacter(player.Character)
	end
	update()
	print("[RobloxKart] Garage UI ready")
end

return GarageUiController
