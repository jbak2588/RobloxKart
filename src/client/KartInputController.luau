local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local requireModule = require :: (ModuleScript) -> any
local kartConfigModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartConfig") :: ModuleScript
local KartConfig = requireModule(kartConfigModule)

local KartInputController = {}

local keyDown = {
	[Enum.KeyCode.W] = false,
	[Enum.KeyCode.S] = false,
	[Enum.KeyCode.A] = false,
	[Enum.KeyCode.D] = false,
	[Enum.KeyCode.LeftShift] = false,
}

local function isDrivingPrototypeKart(): boolean
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seatPart = humanoid and humanoid.SeatPart

	return seatPart ~= nil and seatPart:GetAttribute("PrototypeKartSeat") == true
end

local function getInputAxes(): (number, number)
	local throttle = (keyDown[Enum.KeyCode.W] and 1 or 0) - (keyDown[Enum.KeyCode.S] and 1 or 0)
	local steering = (keyDown[Enum.KeyCode.D] and 1 or 0) - (keyDown[Enum.KeyCode.A] and 1 or 0)

	return throttle, steering
end

function KartInputController.start()
	local remoteEvent = ReplicatedStorage:WaitForChild(KartConfig.REMOTE_EVENT_NAME) :: RemoteEvent
	local lastThrottle = 0
	local lastSteering = 0
	local lastDriftRequested = false
	local timeSinceSend = KartConfig.INPUT_SEND_INTERVAL
	local wasDriving = false

	local function sendInput(force: boolean)
		local driving = isDrivingPrototypeKart()
		local throttle, steering = getInputAxes()
		local driftRequested = keyDown[Enum.KeyCode.LeftShift] == true

		if not driving then
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
		if keyDown[input.KeyCode] == nil then
			return
		end
		if UserInputService:GetFocusedTextBox() ~= nil then
			return
		end
		if gameProcessed and not isDrivingPrototypeKart() then
			return
		end

		keyDown[input.KeyCode] = true
		sendInput(true)
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if keyDown[input.KeyCode] == nil then
			return
		end

		keyDown[input.KeyCode] = false
		sendInput(true)
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
