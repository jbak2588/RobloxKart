local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DriverCatalog = require(Shared:WaitForChild("DriverCatalog"))
local KartCatalog = require(Shared:WaitForChild("KartCatalog"))
local TrackCatalog = require(Shared:WaitForChild("TrackCatalog"))
local KartVisualFactory = require(Shared:WaitForChild("KartVisualFactory"))
local DriverAppearance = require(Shared:WaitForChild("DriverAppearance"))

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
	piece("Helmet", Vector3.new(1.35, 0.7, 1.35), Vector3.new(0, 2.25, 0), driver.Theme, Enum.PartType.Ball)
	piece("LeftArm", Vector3.new(0.65, 1.8, 0.8), Vector3.new(-1.4, 0.3, 0), driver.Theme)
	piece("RightArm", Vector3.new(0.65, 1.8, 0.8), Vector3.new(1.4, 0.3, 0), driver.Theme)
	piece("LeftLeg", Vector3.new(0.8, 2, 0.85), Vector3.new(-0.55, -1.75, 0), dark)
	piece("RightLeg", Vector3.new(0.8, 2, 0.85), Vector3.new(0.55, -1.75, 0), dark)
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
	local stepLabel = makeText(backdrop, UDim2.fromScale(0.8, 0.07), UDim2.fromScale(0.1, 0.17), "", 24)
	local choiceLabel = makeText(backdrop, UDim2.fromScale(0.8, 0.08), UDim2.fromScale(0.1, 0.61), "", 34)
	local detailLabel = makeText(backdrop, UDim2.fromScale(0.8, 0.07), UDim2.fromScale(0.1, 0.70), "", 19)
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
	viewport.Ambient = Color3.fromRGB(190, 195, 205)
	viewport.LightColor = Color3.fromRGB(255, 247, 227)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = backdrop
	local viewportSize = Instance.new("UISizeConstraint")
	viewportSize.MinSize = Vector2.new(360, 200)
	viewportSize.MaxSize = Vector2.new(680, 340)
	viewportSize.Parent = viewport
	local viewportCorner = Instance.new("UICorner")
	viewportCorner.CornerRadius = UDim.new(0, 12)
	viewportCorner.Parent = viewport

	local previousButton = makeButton(backdrop, "BACK", UDim2.new(0.5, -270, 0.84, 0))
	local cycleButton = makeButton(backdrop, "CHANGE", UDim2.new(0.5, -85, 0.84, 0))
	local nextButton = makeButton(backdrop, "NEXT", UDim2.new(0.5, 100, 0.84, 0))

	local step = 1
	local driverIndex = 1
	local kartIndex = 1
	local trackIndex = 1
	local catalogs = { DriverCatalog, KartCatalog, TrackCatalog }
	local headings = { "1 / 4   DRIVER SELECT", "2 / 4   KART SELECT", "3 / 4   TRACK SELECT", "4 / 4   READY" }
	local previewKey: string? = nil
	local previewWorld: WorldModel? = nil
	local previewCamera: Camera? = nil

	local function clearPreview()
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
			for _, part in visual:GetChildren() do
				if part:IsA("BasePart") then
					part.Anchored = true
				end
			end
			visual.Parent = world
			camera.CFrame = CFrame.new(Vector3.new(-10, 7, -10), Vector3.new(0, 0.3, 0))
		else
			local driver = cloneDriver(player.Character, DriverCatalog.Entries[selectedId])
			driver.Parent = world
			camera.CFrame = CFrame.new(Vector3.new(-5, 2.3, -9), Vector3.new(0, 0, 0))
		end
		viewport.CurrentCamera = camera
		previewWorld = world
		previewCamera = camera
		previewKey = key
	end

	local function selectedIds(): (string, string, string)
		return DriverCatalog.Order[driverIndex], KartCatalog.Order[kartIndex], TrackCatalog.Order[trackIndex]
	end

	local function update()
		local raceState = player:GetAttribute("RaceState")
		gui.Enabled = raceState == "GARAGE" or raceState == "PRE_RACE"
		if not gui.Enabled then
			clearPreview()
			return
		end
		if raceState == "PRE_RACE" then
			viewport.Visible = false
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
			return
		end
		nextButton.Visible = true
		local driverId, kartId, trackId = selectedIds()
		stepLabel.Text = headings[step]
		viewport.Visible = step <= 2
		choiceLabel.Position = UDim2.fromScale(0.1, if viewport.Visible then 0.61 else 0.40)
		detailLabel.Position = UDim2.fromScale(0.1, if viewport.Visible then 0.70 else 0.54)
		if step == 1 then
			showPreview("Driver", driverId)
		elseif step == 2 then
			showPreview("Kart", kartId)
		else
			clearPreview()
		end
		if step <= 3 then
			local catalog = catalogs[step]
			local selectedId = if step == 1 then driverId elseif step == 2 then kartId else trackId
			choiceLabel.Text = catalog.Entries[selectedId].DisplayName
			detailLabel.Text = if step == 1 then "Choose your racing driver"
				elseif step == 2 then "All MVP karts use the same physics"
				else "Choose the circuit for this race"
		else
			choiceLabel.Text = "START RACE"
			detailLabel.Text = string.format("%s  /  %s  /  %s", DriverCatalog.Entries[driverId].DisplayName, KartCatalog.Entries[kartId].DisplayName, TrackCatalog.Entries[trackId].DisplayName)
		end
		previousButton.Visible = step > 1
		cycleButton.Visible = step <= 3 and #catalogs[step].Order > 1
		nextButton.Text = if step == 4 then "READY" else "NEXT"
		errorLabel.Text = tostring(player:GetAttribute("RaceEntryError") or "")
	end

	previousButton.Activated:Connect(function()
		step = math.max(1, step - 1)
		update()
	end)
	cycleButton.Activated:Connect(function()
		if step == 1 then
			driverIndex = driverIndex % #DriverCatalog.Order + 1
		elseif step == 2 then
			kartIndex = kartIndex % #KartCatalog.Order + 1
		elseif step == 3 then
			trackIndex = trackIndex % #TrackCatalog.Order + 1
		end
		update()
	end)
	nextButton.Activated:Connect(function()
		if step < 4 then
			step += 1
			update()
		else
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
	player.CharacterAppearanceLoaded:Connect(function()
		if player:GetAttribute("RaceState") == "GARAGE" and step == 1 then
			clearPreview()
			update()
		end
	end)
	update()
	print("[RobloxKart] Garage UI ready")
end

return GarageUiController
