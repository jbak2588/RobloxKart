local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local requireModule = require :: (ModuleScript) -> any
local raceConfigModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaceConfig") :: ModuleScript
local RaceConfig = requireModule(raceConfigModule)

local RaceHudController = {}

local HUD_NAME = "RobloxKartRaceHud"
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
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Position = UDim2.fromOffset(16, 16)
	frame.Size = UDim2.fromOffset(250, 135)
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
	local checkpointLabel = createLabel(frame, "Checkpoint", 2)
	local lastLabel = createLabel(frame, "Last", 3)
	local bestLabel = createLabel(frame, "Best", 4)
	local offTrackLabel = createLabel(frame, "OffTrack", 5)
	offTrackLabel.TextColor3 = Color3.fromRGB(255, 175, 80)

	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "Countdown"
	countdownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	countdownLabel.Position = UDim2.fromScale(0.5, 0.35)
	countdownLabel.Size = UDim2.fromOffset(260, 140)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Font = Enum.Font.GothamBlack
	countdownLabel.TextColor3 = Color3.fromRGB(255, 225, 70)
	countdownLabel.TextStrokeTransparency = 0.25
	countdownLabel.TextScaled = true
	countdownLabel.Visible = false
	countdownLabel.Parent = screenGui

	local resultsPanel = Instance.new("Frame")
	resultsPanel.Name = "Results"
	resultsPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	resultsPanel.Position = UDim2.fromScale(0.5, 0.5)
	resultsPanel.Size = UDim2.fromOffset(320, 220)
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
	finishLabel.Text = "FINISH"
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

	local goDisplaySerial = 0
	local displayedRaceState = player:GetAttribute("RaceState")
	local function updateHud()
		local raceState = player:GetAttribute("RaceState")
		local previousRaceState = displayedRaceState
		displayedRaceState = raceState
		local currentLap = getNumberAttribute(player, "RaceCurrentLap", 1)
		local totalLaps = getNumberAttribute(player, "RaceTotalLaps", RaceConfig.TOTAL_LAPS)
		local nextCheckpoint = getNumberAttribute(player, "RaceNextCheckpoint", 1)
		local checkpointCount = getNumberAttribute(player, "RaceCheckpointCount", 6)
		local lastLap = getNumberAttribute(player, "RaceLastLapTime", 0)
		local bestLap = getNumberAttribute(player, "RaceBestLapTime", 0)
		local finalTime = getNumberAttribute(player, "RaceFinalTime", 0)
		local offTrackRemaining = getNumberAttribute(player, "RaceOffTrackRemaining", 0)

		lapLabel.Text = string.format("LAP %d / %d", currentLap, totalLaps)
		if nextCheckpoint > checkpointCount then
			checkpointLabel.Text = "CHECKPOINT FINISH"
		else
			checkpointLabel.Text = string.format("CHECKPOINT %d / %d", nextCheckpoint, checkpointCount)
		end
		lastLabel.Text = if lastLap > 0 then string.format("LAST %.2f", lastLap) else "LAST --"
		bestLabel.Text = if bestLap > 0 then string.format("BEST %.2f", bestLap) else "BEST --"
		offTrackLabel.Text = if raceState == "RACING" and offTrackRemaining > 0 then string.format("RETURN TO TRACK  %ds", offTrackRemaining) else ""

		resultsPanel.Visible = raceState == "FINISHED" or raceState == "DNF"
		finishLabel.Text = if raceState == "DNF" then "DNF" else "FINISH"
		totalLabel.Text = if raceState == "DNF" then string.format("OFF TRACK %ds", RaceConfig.OFF_TRACK_TIMEOUT_SECONDS) elseif finalTime > 0 then string.format("TOTAL  %.2f", finalTime) else "TOTAL  --"
		resultsBestLabel.Text = if bestLap > 0 then string.format("BEST   %.2f", bestLap) else "BEST   --"

		if raceState == "COUNTDOWN" then
			goDisplaySerial += 1
			local countdown = getNumberAttribute(player, "RaceCountdown", 0)
			countdownLabel.Text = if countdown > 0 then tostring(countdown) else "GO"
			countdownLabel.Visible = true
		elseif raceState == "RACING" and previousRaceState == "COUNTDOWN" then
			goDisplaySerial += 1
			local currentSerial = goDisplaySerial
			countdownLabel.Text = "GO"
			countdownLabel.Visible = true
			task.delay(0.75, function()
				if currentSerial == goDisplaySerial and player:GetAttribute("RaceState") == "RACING" then
					countdownLabel.Visible = false
				end
			end)
		elseif raceState ~= "RACING" then
			goDisplaySerial += 1
			countdownLabel.Visible = false
		end
	end

	for _, attributeName in {
		"RaceState",
		"RaceCountdown",
		"RaceCurrentLap",
		"RaceTotalLaps",
		"RaceNextCheckpoint",
		"RaceCheckpointCount",
		"RaceLastLapTime",
		"RaceBestLapTime",
		"RaceFinalTime",
		"RaceOffTrackRemaining",
	} do
		player:GetAttributeChangedSignal(attributeName):Connect(updateHud)
	end

	updateHud()
	print("[RobloxKart] Race HUD ready")
end

return RaceHudController
