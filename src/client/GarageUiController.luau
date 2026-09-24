local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DriverCatalog = require(Shared:WaitForChild("DriverCatalog"))
local KartCatalog = require(Shared:WaitForChild("KartCatalog"))
local TrackCatalog = require(Shared:WaitForChild("TrackCatalog"))

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

	local title = makeText(backdrop, UDim2.fromScale(0.8, 0.12), UDim2.fromScale(0.1, 0.12), "ROBLOX KART", 40)
	title.TextColor3 = Color3.fromRGB(255, 215, 75)
	local stepLabel = makeText(backdrop, UDim2.fromScale(0.8, 0.08), UDim2.fromScale(0.1, 0.28), "", 24)
	local choiceLabel = makeText(backdrop, UDim2.fromScale(0.8, 0.13), UDim2.fromScale(0.1, 0.40), "", 34)
	local detailLabel = makeText(backdrop, UDim2.fromScale(0.8, 0.12), UDim2.fromScale(0.1, 0.54), "", 19)
	detailLabel.TextWrapped = true
	local errorLabel = makeText(backdrop, UDim2.fromScale(0.8, 0.07), UDim2.fromScale(0.1, 0.68), "", 18)
	errorLabel.TextColor3 = Color3.fromRGB(255, 110, 110)

	local previousButton = makeButton(backdrop, "BACK", UDim2.new(0.5, -270, 0.8, 0))
	local cycleButton = makeButton(backdrop, "CHANGE", UDim2.new(0.5, -85, 0.8, 0))
	local nextButton = makeButton(backdrop, "NEXT", UDim2.new(0.5, 100, 0.8, 0))

	local step = 1
	local driverIndex = 1
	local kartIndex = 1
	local trackIndex = 1
	local catalogs = { DriverCatalog, KartCatalog, TrackCatalog }
	local headings = { "1 / 4   DRIVER SELECT", "2 / 4   KART SELECT", "3 / 4   TRACK SELECT", "4 / 4   READY" }

	local function selectedIds(): (string, string, string)
		return DriverCatalog.Order[driverIndex], KartCatalog.Order[kartIndex], TrackCatalog.Order[trackIndex]
	end

	local function update()
		local raceState = player:GetAttribute("RaceState")
		gui.Enabled = raceState == "GARAGE" or raceState == "PRE_RACE"
		if not gui.Enabled then
			return
		end
		if raceState == "PRE_RACE" then
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
	update()
	print("[RobloxKart] Garage UI ready")
end

return GarageUiController
