local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local requireModule = require :: (ModuleScript) -> any
local kartConfigModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartConfig") :: ModuleScript
local KartConfig = requireModule(kartConfigModule)

local KartInputController = {}

local controlKeys = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.LeftShift] = true,
}

local function isDrivingPrototypeKart(): boolean
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seatPart = humanoid and humanoid.SeatPart

	return seatPart ~= nil and seatPart:GetAttribute("PrototypeKartSeat") == true
end

local function getInputAxes(): (number, number, boolean)
	if UserInputService:GetFocusedTextBox() ~= nil then
		return 0, 0, false
	end

	local throttle = (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
		- (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
	local steering = (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
		- (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)

	return throttle, steering, UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
end

function KartInputController.start()
	local remoteEvent = ReplicatedStorage:WaitForChild(KartConfig.REMOTE_EVENT_NAME) :: RemoteEvent
	local lastThrottle = 0
	local lastSteering = 0
	local lastDriftRequested = false
	local timeSinceSend = KartConfig.INPUT_SEND_INTERVAL
	local wasDriving = false

	local function sendInput(force: boolean, neutral: boolean?)
		local driving = isDrivingPrototypeKart()
		local throttle, steering, driftRequested = getInputAxes()

		if not driving or neutral then
			throttle = 0
			steering = 0
			driftRequested = false
		end

		local changed = throttle ~= lastThrottle
			or steering ~= lastSteering
			or driftRequested ~= lastDriftRequested
			or driving ~= wasDriving
		if changed or (force and driving) then
			remoteEvent:FireServer(throttle, steering, driftRequested)
			lastThrottle = throttle
			lastSteering = steering
			lastDriftRequested = driftRequested
			wasDriving = driving
			timeSinceSend = 0
		end
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if not controlKeys[input.KeyCode] then
			return
		end
		if gameProcessed and not isDrivingPrototypeKart() then
			return
		end

		sendInput(true)
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if not controlKeys[input.KeyCode] then
			return
		end

		sendInput(true)
	end)

	UserInputService.WindowFocusReleased:Connect(function()
		sendInput(true, true)
		if KartConfig.DEBUG_TELEMETRY then
			print("[KartInput] window focus released")
		end
	end)

	UserInputService.WindowFocused:Connect(function()
		sendInput(true)
		if KartConfig.DEBUG_TELEMETRY then
			print("[KartInput] window focused")
		end
	end)

	UserInputService.TextBoxFocused:Connect(function()
		sendInput(true)
		if KartConfig.DEBUG_TELEMETRY then
			print("[KartInput] text box focused")
		end
	end)

	UserInputService.TextBoxFocusReleased:Connect(function()
		sendInput(true)
		if KartConfig.DEBUG_TELEMETRY then
			print("[KartInput] text box focus released")
		end
	end)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		timeSinceSend += deltaTime
		if timeSinceSend >= KartConfig.INPUT_SEND_INTERVAL then
			sendInput(true)
		else
			sendInput(false)
		end
	end)

	print("[RobloxKart] Kart controller ready")
end

return KartInputController
