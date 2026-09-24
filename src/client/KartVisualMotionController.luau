local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local KartVisualMotionController = {}
local started = false
local STEER_MAX = math.rad(25)
local STEER_RESPONSE = 10

local function getKart(seatPart: BasePart?): Model?
	if not seatPart or seatPart:GetAttribute("PrototypeKartSeat") ~= true then
		return nil
	end
	local kart = seatPart.Parent
	if kart and kart:IsA("Model") and kart:GetAttribute("PrototypeKart") == true then
		return kart
	end
	return nil
end

function KartVisualMotionController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local activeKart: Model? = nil
	local activeSeat: BasePart? = nil
	local activeChassis: BasePart? = nil
	local wheels = {}
	local currentSteer = 0
	local seatedConnection: RBXScriptConnection? = nil
	local simulationConnection: RBXScriptConnection? = nil
	local destroyingConnection: RBXScriptConnection? = nil

	local function detach()
		if simulationConnection then
			simulationConnection:Disconnect()
			simulationConnection = nil
		end
		if destroyingConnection then
			destroyingConnection:Disconnect()
			destroyingConnection = nil
		end
		for _, wheel in wheels do
			if wheel.motor.Parent then
				wheel.motor.Transform = CFrame.identity
			end
		end
		table.clear(wheels)
		activeKart = nil
		activeSeat = nil
		activeChassis = nil
		currentSteer = 0
	end

	local function attach(seatPart: BasePart?, attempt: number?)
		local kart = getKart(seatPart)
		if kart == activeKart and seatPart == activeSeat then
			return
		end
		detach()
		if not kart then
			return
		end
		local function retryWhenReplicated()
			if (attempt or 0) >= 10 then
				warn("[KartVisual] Wheel joints did not replicate")
				return
			end
			task.delay(0.2, function()
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.SeatPart == seatPart then
					attach(seatPart, (attempt or 0) + 1)
				end
			end)
		end
		local chassis = kart:FindFirstChild("Chassis")
		local visual = kart:FindFirstChild("Visual")
		if not chassis or not chassis:IsA("BasePart") or not visual or not visual:IsA("Model") then
			retryWhenReplicated()
			return
		end
		for _, part in visual:GetChildren() do
			if part:IsA("BasePart") then
				local role = part:GetAttribute("VisualMotionRole")
				local motor = part:FindFirstChild("VisualMotor")
				if (role == "FrontWheel" or role == "RearWheel") and motor and motor:IsA("Motor6D") then
					table.insert(wheels, {
						motor = motor,
						front = role == "FrontWheel",
						radius = part.Size.Y / 2,
						angle = 0,
					})
				end
			end
		end
		if #wheels ~= 4 then
			table.clear(wheels)
			retryWhenReplicated()
			return
		end

		activeKart = kart
		activeSeat = seatPart
		activeChassis = chassis
		destroyingConnection = kart.Destroying:Connect(detach)
		simulationConnection = RunService.PreSimulation:Connect(function(deltaTime: number)
			if not activeChassis or not activeChassis.Parent then
				detach()
				return
			end
			local velocity = activeChassis.AssemblyLinearVelocity
			local forwardSpeed = velocity:Dot(activeChassis.CFrame.LookVector)
			local steering = kart:GetAttribute("KartVisualSteering")
			local targetSteer = if kart:GetAttribute("RaceControlsLocked") == true then 0
				elseif type(steering) == "number" then math.clamp(steering, -1, 1) * STEER_MAX
				else 0
			currentSteer += (targetSteer - currentSteer) * (1 - math.exp(-STEER_RESPONSE * deltaTime))
			for _, wheel in wheels do
				if math.abs(forwardSpeed) > 0.05 then
					wheel.angle = (wheel.angle + forwardSpeed / wheel.radius * deltaTime) % (2 * math.pi)
				end
				local yaw = if wheel.front then currentSteer else 0
				wheel.motor.Transform = CFrame.Angles(0, yaw, 0) * CFrame.Angles(wheel.angle, 0, 0)
			end
		end)
	end

	local function bindCharacter(character: Model)
		detach()
		if seatedConnection then
			seatedConnection:Disconnect()
			seatedConnection = nil
		end
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		if player.Character ~= character then
			return
		end
		seatedConnection = humanoid.Seated:Connect(function(active: boolean, seatPart: BasePart?)
			attach(if active then seatPart else nil)
		end)
		attach(humanoid.SeatPart)
	end

	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function()
		detach()
		if seatedConnection then
			seatedConnection:Disconnect()
			seatedConnection = nil
		end
	end)
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
end

return KartVisualMotionController
