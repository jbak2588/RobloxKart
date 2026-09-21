local Players = game:GetService("Players")

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

function RaceHudController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
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
	frame.Size = UDim2.fromOffset(250, 112)
	frame.BackgroundColor3 = Color3.fromRGB(16, 19, 24)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

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

	local function updateHud()
		local currentLap = getNumberAttribute(player, "RaceCurrentLap", 1)
		local nextCheckpoint = getNumberAttribute(player, "RaceNextCheckpoint", 1)
		local checkpointCount = getNumberAttribute(player, "RaceCheckpointCount", 6)
		local lastLap = getNumberAttribute(player, "RaceLastLapTime", 0)
		local bestLap = getNumberAttribute(player, "RaceBestLapTime", 0)

		lapLabel.Text = string.format("LAP %d", currentLap)
		if nextCheckpoint > checkpointCount then
			checkpointLabel.Text = "CHECKPOINT FINISH"
		else
			checkpointLabel.Text = string.format("CHECKPOINT %d / %d", nextCheckpoint, checkpointCount)
		end
		lastLabel.Text = if lastLap > 0 then string.format("LAST %.2f", lastLap) else "LAST --"
		bestLabel.Text = if bestLap > 0 then string.format("BEST %.2f", bestLap) else "BEST --"
	end

	for _, attributeName in {
		"RaceCurrentLap",
		"RaceNextCheckpoint",
		"RaceCheckpointCount",
		"RaceLastLapTime",
		"RaceBestLapTime",
	} do
		player:GetAttributeChangedSignal(attributeName):Connect(updateHud)
	end

	updateHud()
	print("[RobloxKart] Race HUD ready")
end

return RaceHudController
