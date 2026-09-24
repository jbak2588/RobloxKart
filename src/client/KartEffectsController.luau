local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local KartEffectsController = {}
local started = false
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local CRUISE_FLAME_INTERVAL = 0.45
local CRUISE_MIN_SPEED = 10

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

local function makeAttachment(parent: BasePart, name: string, position: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = parent
	return attachment
end

local function makeSmoke(attachment: Attachment): ParticleEmitter
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "DriftSmoke"
	smoke.Texture = SMOKE_TEXTURE
	smoke.Enabled = false
	smoke.Rate = 0
	smoke.Lifetime = NumberRange.new(0.35, 0.7)
	smoke.Speed = NumberRange.new(1, 3)
	smoke.Acceleration = Vector3.new(0, 3, 0)
	smoke.Drag = 1
	smoke.VelocityInheritance = 0.15
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.SpreadAngle = Vector2.new(24, 24)
	smoke.Color = ColorSequence.new(Color3.fromRGB(125, 125, 130), Color3.fromRGB(170, 170, 175))
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.28),
		NumberSequenceKeypoint.new(1, 1.1),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Parent = attachment
	return smoke
end

local function makeTrail(parent: BasePart, first: Attachment, second: Attachment): Trail
	local trail = Instance.new("Trail")
	trail.Name = "DriftTireTrail"
	trail.Attachment0 = first
	trail.Attachment1 = second
	trail.Enabled = false
	trail.Lifetime = 0.35
	trail.MaxLength = 14
	trail.MinLength = 0.1
	trail.Color = ColorSequence.new(Color3.fromRGB(35, 37, 40))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = parent
	return trail
end

local function makeFlame(attachment: Attachment): ParticleEmitter
	local flame = Instance.new("ParticleEmitter")
	flame.Name = "BoostFlame"
	flame.Enabled = false
	flame.Rate = 30
	flame.Lifetime = NumberRange.new(0.09, 0.19)
	flame.Speed = NumberRange.new(8, 14)
	flame.EmissionDirection = Enum.NormalId.Back
	flame.SpreadAngle = Vector2.new(9, 9)
	flame.VelocityInheritance = 0.15
	flame.LightEmission = 0.85
	flame.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 110)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 145, 35)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 75, 25)),
	})
	flame.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0.06),
	})
	flame.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	flame.Parent = attachment
	return flame
end

local function makeCruiseFlame(attachment: Attachment): ParticleEmitter
	local flame = Instance.new("ParticleEmitter")
	flame.Name = "CruiseFlame"
	flame.Enabled = false
	flame.Rate = 0
	flame.Lifetime = NumberRange.new(0.1, 0.18)
	flame.Speed = NumberRange.new(5, 8)
	flame.EmissionDirection = Enum.NormalId.Back
	flame.SpreadAngle = Vector2.new(8, 8)
	flame.VelocityInheritance = 0.15
	flame.LightEmission = 0.6
	flame.Color = ColorSequence.new(Color3.fromRGB(255, 205, 80), Color3.fromRGB(255, 110, 35))
	flame.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.32),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	flame.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	flame.Parent = attachment
	return flame
end

function KartEffectsController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local activeKart: Model? = nil
	local activeSeat: BasePart? = nil
	local activeChassis: BasePart? = nil
	local seatedConnection: RBXScriptConnection? = nil
	local heartbeatConnection: RBXScriptConnection? = nil
	local kartConnections: { RBXScriptConnection } = {}
	local attachments: { Attachment } = {}
	local smokes: { ParticleEmitter } = {}
	local trails: { Trail } = {}
	local flames: { ParticleEmitter } = {}
	local cruiseFlames: { ParticleEmitter } = {}
	local cruiseElapsed = 0
	local drifting = false
	local boosting = false

	local function clearParticles()
		for _, smoke in smokes do
			if smoke.Parent then
				smoke.Enabled = false
				smoke:Clear()
			end
		end
		for _, trail in trails do
			if trail.Parent then
				trail.Enabled = false
				trail:Clear()
			end
		end
		for _, flame in flames do
			if flame.Parent then
				flame.Enabled = false
				flame:Clear()
			end
		end
		for _, flame in cruiseFlames do
			if flame.Parent then
				flame:Clear()
			end
		end
		cruiseElapsed = 0
	end

	local function detach()
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
			heartbeatConnection = nil
		end
		for _, connection in kartConnections do
			connection:Disconnect()
		end
		table.clear(kartConnections)
		clearParticles()
		for _, attachment in attachments do
			attachment:Destroy()
		end
		table.clear(attachments)
		table.clear(smokes)
		table.clear(trails)
		table.clear(flames)
		table.clear(cruiseFlames)
		activeKart = nil
		activeSeat = nil
		activeChassis = nil
		drifting = false
		boosting = false
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
				warn("[KartVFX] Wheel or exhaust parts did not replicate")
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
			if part:IsA("BasePart") and part:GetAttribute("VisualMotionRole") == "RearWheel" then
				local motor = part:FindFirstChild("VisualMotor")
				if motor and motor:IsA("Motor6D") then
					local side = part:GetAttribute("WheelSide")
					local center = motor.C0.Position
					local contact = center - Vector3.yAxis * (part.Size.Y / 2 - 0.08)
					local smokePoint = makeAttachment(chassis, "DriftSmokePoint" .. tostring(side), contact)
					local edgeOffset = Vector3.xAxis * (part.Size.X * 0.45)
					local edgeA = makeAttachment(chassis, "TireEdgeA" .. tostring(side), contact - edgeOffset)
					local edgeB = makeAttachment(chassis, "TireEdgeB" .. tostring(side), contact + edgeOffset)
					table.insert(attachments, smokePoint)
					table.insert(attachments, edgeA)
					table.insert(attachments, edgeB)
					table.insert(smokes, makeSmoke(smokePoint))
					table.insert(trails, makeTrail(chassis, edgeA, edgeB))
				end
			end
		end
		for _, exhaustName in { "ExhaustL", "ExhaustR" } do
			local exhaust = visual:FindFirstChild(exhaustName)
			if exhaust and exhaust:IsA("BasePart") then
				local point = makeAttachment(exhaust, "BoostFlame" .. exhaustName, Vector3.new(0, 0, exhaust.Size.Z / 2))
				table.insert(attachments, point)
				table.insert(flames, makeFlame(point))
				table.insert(cruiseFlames, makeCruiseFlame(point))
			end
		end
		if #smokes ~= 2 or #trails ~= 2 or #flames ~= 2 or #cruiseFlames ~= 2 then
			detach()
			retryWhenReplicated()
			return
		end

		activeKart = kart
		activeSeat = seatPart
		activeChassis = chassis
		local function refreshStates()
			local locked = kart:GetAttribute("RaceControlsLocked") == true
			local offTrack = kart:GetAttribute("KartOffTrack") == true
			drifting = not locked and not offTrack and kart:GetAttribute("KartDrifting") == true
			local shouldBoost = not locked and kart:GetAttribute("KartBoosting") == true
			if shouldBoost and not boosting then
				for _, flame in flames do
					flame:Emit(12)
				end
			end
			boosting = shouldBoost
			for _, flame in flames do
				flame.Enabled = boosting
			end
			if not drifting then
				for _, smoke in smokes do
					smoke.Enabled = false
				end
				for _, trail in trails do
					trail.Enabled = false
				end
			end
		end
		for _, attribute in { "KartDrifting", "KartBoosting", "KartOffTrack", "RaceControlsLocked" } do
			table.insert(kartConnections, kart:GetAttributeChangedSignal(attribute):Connect(refreshStates))
		end
		table.insert(kartConnections, kart:GetAttributeChangedSignal("RaceResetSerial"):Connect(clearParticles))
		table.insert(kartConnections, kart.Destroying:Connect(detach))
		heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
			if not activeChassis or not activeChassis.Parent then
				detach()
				return
			end
			local velocity = activeChassis.AssemblyLinearVelocity
			local forwardSpeed = velocity:Dot(activeChassis.CFrame.LookVector)
			local cruising = kart:GetAttribute("RaceControlsLocked") ~= true
				and kart:GetAttribute("KartOffTrack") ~= true
				and not drifting
				and not boosting
				and forwardSpeed >= CRUISE_MIN_SPEED
			if cruising then
				cruiseElapsed += deltaTime
				if cruiseElapsed >= CRUISE_FLAME_INTERVAL then
					cruiseElapsed %= CRUISE_FLAME_INTERVAL
					for _, flame in cruiseFlames do
						flame:Emit(5)
					end
				end
			else
				cruiseElapsed = 0
			end
			if not drifting then
				return
			end
			local lateralSpeed = velocity:Dot(activeChassis.CFrame.RightVector)
			local slip = if math.abs(forwardSpeed) < 5 then 0
				else math.abs(math.deg(math.atan2(lateralSpeed, math.max(math.abs(forwardSpeed), 0.01))))
			local rate = math.clamp((slip - 8) * 2, 0, 35)
			for _, smoke in smokes do
				smoke.Rate = rate
				smoke.Enabled = rate > 0
			end
			local showTrail = slip >= 10
			for _, trail in trails do
				trail.Enabled = showTrail
			end
		end)
		refreshStates()
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

return KartEffectsController
