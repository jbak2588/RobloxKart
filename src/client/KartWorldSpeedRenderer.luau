-- Fixed native air streaks and rearward vortex, rendered locally.
-- Clean arcade airflow: Demoted Subordinate Trail (<= 6 studs) + Pure White Micro Vortex.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Speed = require(game.ReplicatedStorage.Shared.KDMSpeedSensation)
local Renderer = {}
local baseAirColor = Color3.fromRGB(222, 243, 255)
local defaultAirColor = ColorSequence.new(baseAirColor)

-- Bounded immutable value cache: no sequences/tables/instances allocated on update.
local primaryVisuals = {}
local secondaryVisuals = {}

for bucket = 0, 20 do
	-- Trail (V3.0 보조 격하):
	-- Primary Trail: 세계 길이 6stud 이하 고정 (Lifetime = 6 / speed, 속도에 반비례)
	-- 70 studs/s = 0.086s, 80 studs/s = 0.075s, 90 studs/s = 0.067s
	local life1 = if bucket <= 10 then
		0.095 - 0.009 * (bucket / 10)
	elseif bucket <= 17 then
		0.0857 - (0.0857 - 0.075) * ((bucket - 10) / 7)
	else
		0.075 - (0.075 - 0.0667) * ((bucket - 17) / 3)

	-- Transparency: 시작 0.75, 끝 1.0 (완전 페이드)
	-- Width: 시작 0.12 / 0.16 / 0.20 stud, 끝 0 (테이퍼)
	local width1 = if bucket <= 10 then
		0.08 + 0.04 * (bucket / 10)
	elseif bucket <= 17 then
		0.12 + (0.16 - 0.12) * ((bucket - 10) / 7)
	else
		0.16 + (0.20 - 0.16) * ((bucket - 17) / 3)

	primaryVisuals[bucket] = table.freeze({
		Lifetime = life1,
		Width = NumberSequence.new({
			NumberSequenceKeypoint.new(0, math.max(0.01, width1)),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Color = defaultAirColor,
	})

	-- Secondary Trail: Primary의 60% 길이, 90stud에서만 완전 점등
	local life2 = life1 * 0.60
	local width2 = 0.15
	secondaryVisuals[bucket] = table.freeze({
		Lifetime = life2,
		Width = NumberSequence.new({
			NumberSequenceKeypoint.new(0, width2),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.80),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Color = defaultAirColor,
	})
end
table.freeze(primaryVisuals)
table.freeze(secondaryVisuals)

-- Immutable rearward particle profiles. Shared tier/camera rules remain unchanged.
local function sequence(a, b, c)
	return NumberSequence.new({NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.45, b), NumberSequenceKeypoint.new(1, c)})
end
local jetColor = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 250, 255)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(80, 210, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 120, 255)),
})

-- Orange Cruise Flame: 1~91 studs/s 상시 로켓 화염 (고열 노란빛 코어 -> 진한 오렌지/레드 화염)
local orangeFlameCoreColor = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 220)),
	ColorSequenceKeypoint.new(0.30, Color3.fromRGB(255, 175, 30)),
	ColorSequenceKeypoint.new(0.70, Color3.fromRGB(255, 95, 12)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 45, 10)),
})

local orangeFlamePlumeColor = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 210, 60)),
	ColorSequenceKeypoint.new(0.40, Color3.fromRGB(255, 130, 20)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 35, 10)),
})

local flameCoreTrans = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.25),
	NumberSequenceKeypoint.new(0.15, 0.00),
	NumberSequenceKeypoint.new(0.70, 0.10),
	NumberSequenceKeypoint.new(1, 1.00),
})

local flamePlumeTrans = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.40),
	NumberSequenceKeypoint.new(0.20, 0.15),
	NumberSequenceKeypoint.new(0.65, 0.35),
	NumberSequenceKeypoint.new(1, 1.00),
})

-- 120stud (니트로 화염 max length = 30 speed * 0.15 life = 4.5 studs) 기준 70/120, 80/120, 90/120 화염 길이 비례 구현
local cruiseFlameVisuals = {}
for spd = 0, 91 do
	local ratio = math.clamp(spd / 120, 0, 91 / 120)
	local s = math.clamp((spd - 2) / (91 - 2), 0, 1)

	local coreRate = if spd <= 1 then 0 else math.floor(8 + 30 * s + 0.5)
	local plumeRate = if s > 0.10 then math.floor(4 + 24 * ((s - 0.10) / 0.90) + 0.5) else 0

	local coreSpeedMax = 30 * ratio
	local coreSpeedMin = coreSpeedMax * 0.72

	local plumeSpeedMax = coreSpeedMax * 0.85
	local plumeSpeedMin = plumeSpeedMax * 0.72

	local coreSizeMin = 0.20 + 0.40 * s
	local coreSizeMid = 0.25 + 0.50 * s
	local coreSizeEnd = 0.05 + 0.13 * s

	local plumeSizeMin = 0.28 + 0.47 * s
	local plumeSizeMid = 0.35 + 0.60 * s
	local plumeSizeEnd = 0.08 + 0.17 * s

	cruiseFlameVisuals[spd] = table.freeze({
		table.freeze({ -- Layer 1: Core
			Rate = coreRate,
			Lifetime = NumberRange.new(0.11, 0.15),
			Speed = NumberRange.new(coreSpeedMin, coreSpeedMax),
			SpreadAngle = Vector2.new(4, 4),
			LightEmission = 1.0,
			VelocityInheritance = 0.0,
			Size = sequence(coreSizeMin, coreSizeMid, coreSizeEnd),
			Transparency = flameCoreTrans,
			Color = orangeFlameCoreColor,
		}),
		table.freeze({ -- Layer 2: Plume
			Rate = plumeRate,
			Lifetime = NumberRange.new(0.12, 0.16),
			Speed = NumberRange.new(plumeSpeedMin, plumeSpeedMax),
			SpreadAngle = Vector2.new(8, 8),
			LightEmission = 1.0,
			VelocityInheritance = 0.0,
			Size = sequence(plumeSizeMin, plumeSizeMid, plumeSizeEnd),
			Transparency = flamePlumeTrans,
			Color = orangeFlamePlumeColor,
		}),
	})
end
table.freeze(cruiseFlameVisuals)

local particleProfiles = {
	MINI_BOOST = {
		{Rate = 45, Lifetime = NumberRange.new(0.12, 0.16), Speed = NumberRange.new(22, 30), SpreadAngle = Vector2.new(6, 6), LightEmission = 1.0, VelocityInheritance = 0.0, Size = sequence(0.75, 0.90, 0.20), Transparency = flameCoreTrans, Color = jetColor},
		{Rate = 25, Lifetime = NumberRange.new(0.14, 0.20), Speed = NumberRange.new(16, 22), SpreadAngle = Vector2.new(10, 10), LightEmission = 1.0, VelocityInheritance = 0.0, Size = sequence(1.10, 1.30, 0.30), Transparency = flamePlumeTrans, Color = jetColor},
	},
	NITRO = {
		{Rate = 65, Lifetime = NumberRange.new(0.14, 0.20), Speed = NumberRange.new(30, 42), SpreadAngle = Vector2.new(8, 8), LightEmission = 1.0, VelocityInheritance = 0.0, Size = sequence(1.00, 1.25, 0.25), Transparency = flameCoreTrans, Color = jetColor},
		{Rate = 35, Lifetime = NumberRange.new(0.16, 0.24), Speed = NumberRange.new(20, 28), SpreadAngle = Vector2.new(13, 13), LightEmission = 1.0, VelocityInheritance = 0.0, Size = sequence(1.40, 1.70, 0.40), Transparency = flamePlumeTrans, Color = jetColor},
		{Rate = 18, Lifetime = NumberRange.new(0.08, 0.14), Speed = NumberRange.new(24, 36), SpreadAngle = Vector2.new(12, 12), LightEmission = 1.0, VelocityInheritance = 0.0, Size = sequence(0.18, 0.12, 0.04), Transparency = sequence(0.0, 0.20, 1.0), Color = jetColor},
	},
}

function Renderer.new(kart)
	local chassis = kart.PrimaryPart
	if not chassis or not chassis:IsA("BasePart") then return nil end
	local visual = kart:FindFirstChild("Visual")
	if not visual then return nil end
	-- Read the fixed wheel pivots once. Wheel spin must not move the air origin.
	local wheels, exhausts = {}, {}
	for _, wheel in visual:GetDescendants() do
		if wheel:IsA("BasePart") and wheel:GetAttribute("VisualMotionRole") == "RearWheel" then
			local motor = wheel:FindFirstChild("VisualMotor")
			local width = wheel:GetAttribute("WheelWidth")
			if motor and type(width) == "number" and width > 0 then
				wheels[wheel:GetAttribute("WheelSide") or ""] = {Center = motor.C0.Position, Width = width}
			end
		end
		if wheel:IsA("Attachment") then
			local role = wheel:GetAttribute("EffectRole")
			if role == "ExhaustLeft" or role == "ExhaustRight" then exhausts[role] = wheel end
		end
	end
	if not wheels.Left or not wheels.Right or not exhausts.ExhaustLeft or not exhausts.ExhaustRight then return nil end

	local attachments, trails, particlePoints, emitters = {}, {}, {}, {}

	-- Trails: index 1 & 2 = Primary rear bumper ribbons; index 3 & 4 = Secondary upper cowl slipstream
	for index = 1, 4 do
		local isPrimary = index <= 2
		local side = if index % 2 == 1 then -1 else 1
		local wheel = if side < 0 then wheels.Left else wheels.Right
		local xPrimary = (wheel.Center.X + side * (wheel.Width * 0.5 + 0.12)) * 0.85
		local zPrimary = wheel.Center.Z + 1.40
		local x, yLow, yHigh, z
		if isPrimary then
			x = xPrimary
			yLow = wheel.Center.Y + 0.35
			yHigh = wheel.Center.Y + 0.85
			z = zPrimary
		else
			-- Secondary: elevated above rear cowl/fender, wider and forward from primary
			x = xPrimary + side * 0.70
			yLow = wheel.Center.Y + 1.05
			yHigh = wheel.Center.Y + 1.45
			z = zPrimary - 0.50
		end
		for edge = 1, 2 do
			local attachment = Instance.new("Attachment")
			attachment.Name = "KDMSpeedPoint" .. index .. "_" .. edge
			attachment.Position = Vector3.new(x, if edge == 1 then yLow else yHigh, z)
			attachment.Parent = chassis
			attachments[#attachments + 1] = attachment
		end
		local trail = Instance.new("Trail")
		trail.Name = "KDMSpeedTrail" .. index
		trail.Attachment0 = attachments[index * 2 - 1]
		trail.Attachment1 = attachments[index * 2]
		trail.Color = if isPrimary then primaryVisuals[0].Color else defaultAirColor
		trail.FaceCamera = true
		trail.Enabled = false
		trail.MinLength = 0.05
		trail.MaxLength = 40
		trail.LightInfluence = 0
		trail.Parent = chassis
		trails[index] = trail
	end

	-- Exhaust jet points and emitters (Mini Boost & Nitro)
	for _, role in {"ExhaustLeft", "ExhaustRight"} do
		local source = exhausts[role]
		local position = chassis.CFrame:ToObjectSpace(source.Parent.CFrame * source.CFrame).Position
		local point = Instance.new("Attachment")
		point.Name = "KDMSpeedJetPoint" .. role
		point.CFrame = CFrame.new(position)
		point.Parent = chassis
		particlePoints[#particlePoints + 1] = point
		local layers = {}
		for layer, name in {"Core", "Plume", "Spark"} do
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "KDMSpeedJet" .. name
			emitter.Texture = if layer == 3 then "rbxasset://textures/particles/sparkles_main.dds" else "rbxasset://textures/particles/smoke_main.dds"
			emitter.Enabled = false
			emitter.Rate = 0
			emitter.Acceleration = Vector3.zero
			emitter.Drag = 0
			emitter.EmissionDirection = Enum.NormalId.Back
			emitter.Orientation = if layer == 3 then Enum.ParticleOrientation.FacingCamera else Enum.ParticleOrientation.VelocityParallel
			emitter.LockedToPart = true
			emitter.LightInfluence = 0
			emitter.Color = jetColor
			emitter.Parent = point
			layers[layer] = emitter
		end
		emitters[#emitters + 1] = layers
	end

	local lastTier, lastBucket, lastSpeedInt, lastDrifting = nil, nil, nil, nil
	local record = {}
	function record:update(_dt, enabled)
		local look = chassis.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z)
		local speed = if forward.Magnitude > 0.001 then chassis.AssemblyLinearVelocity:Dot(forward.Unit) else 0
		local tier, alpha = Speed.resolve(speed, kart:GetAttribute("KartBoosting") == true, kart:GetAttribute("KartNitroActive") == true,
			enabled and kart:GetAttribute("RaceControlsLocked") ~= true, kart:GetAttribute("KartOffTrack") == true)
		local isDrifting = kart:GetAttribute("KartDrifting") == true or kart:GetAttribute("LobbyDrifting") == true
		local bucket = math.floor(alpha * 20 + 0.5)
		local spdInt = math.clamp(math.floor(speed + 0.5), 0, 91)
		if tier == lastTier and bucket == lastBucket and spdInt == lastSpeedInt and isDrifting == lastDrifting then return end

		-- Air trails yield to drift so they don't clash with drift skidmarks.
		local isHigh = tier == "HIGH_SPEED" and alpha > 0 and not isDrifting
		local isSecondary = isHigh and bucket >= 19 -- V2.3: 90stud에서만 완전 점등

		-- Update speed trails
		local primaryVis = primaryVisuals[bucket]
		local secondaryVis = secondaryVisuals[bucket]
		for index, trail in trails do
			local isPrimary = index <= 2
			local active = if isPrimary then isHigh else isSecondary
			if not active and trail.Enabled then trail:Clear() end
			trail.Enabled = active
			if isPrimary then
				trail.Lifetime = primaryVis.Lifetime
				trail.WidthScale = primaryVis.Width
				trail.Transparency = primaryVis.Transparency
				trail.Color = primaryVis.Color
				trail.LightEmission = 0.18
			else
				trail.Lifetime = secondaryVis.Lifetime
				trail.WidthScale = secondaryVis.Width
				trail.Transparency = secondaryVis.Transparency
				trail.Color = secondaryVis.Color
				trail.LightEmission = 0.14
			end
		end

		-- Update exhaust jet emitters (Boost/Nitro blue priority, or 1~91 studs/s Orange Cruise Flame)
		-- Cruise flame stays active during drift for continuous high-speed rocket power feel
		local boostParticles = particleProfiles[tier]
		if boostParticles then
			for _, layers in emitters do
				for layer, emitter in layers do
					local values = boostParticles[layer]
					if values then
						for property, value in values do emitter[property] = value end
					else
						emitter.Rate = 0
					end
					emitter.Enabled = values ~= nil
				end
			end
		elseif enabled and speed > 1 and kart:GetAttribute("RaceControlsLocked") ~= true and kart:GetAttribute("KartOffTrack") ~= true then
			local cruiseVis = cruiseFlameVisuals[spdInt]
			for _, layers in emitters do
				for layer, emitter in layers do
					local values = cruiseVis and cruiseVis[layer]
					if values and values.Rate > 0 then
						for property, value in values do emitter[property] = value end
						emitter.Enabled = true
					else
						emitter.Rate = 0
						emitter.Enabled = false
					end
				end
			end
		else
			for _, layers in emitters do
				for _, emitter in layers do
					emitter.Rate = 0
					emitter.Enabled = false
					if tier == "NONE" then emitter:Clear() end
				end
			end
		end

		lastTier, lastBucket, lastSpeedInt, lastDrifting = tier, bucket, spdInt, isDrifting
	end

	function record:destroy()
		for _, layers in emitters do for _, emitter in layers do emitter.Enabled = false; emitter:Clear(); emitter:Destroy() end end
		for _, point in particlePoints do point:Destroy() end
		for _, trail in trails do trail:Clear(); trail:Destroy() end
		for _, attachment in attachments do attachment:Destroy() end
	end

	return record
end

return Renderer
