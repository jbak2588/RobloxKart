local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("AudioConfig"))
local KartConfig = require(Shared:WaitForChild("KartConfig"))
local AudioRuntime = require(script.Parent:WaitForChild("AudioRuntime"))
local EngineLoopDiagnostic = require(script.Parent:WaitForChild("EngineLoopDiagnostic"))

local KartAudioController = {}
local started = false

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

function KartAudioController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local engineGroup = AudioRuntime.getGroup("RobloxKartEngine")
	local sfxGroup = AudioRuntime.getGroup("RobloxKartSFX")
	local activeKart: Model? = nil
	local activeSeat: BasePart? = nil
	local activeChassis: BasePart? = nil
	local currentHumanoid: Humanoid? = nil
	local seatedConnection: RBXScriptConnection? = nil
	local seatPartConnection: RBXScriptConnection? = nil
	local heartbeatConnection: RBXScriptConnection? = nil
	local seatCheckElapsed = 0
	local kartConnections: { RBXScriptConnection } = {}
	local sounds: { Sound } = {}
	local engine: Sound? = nil
	local engineDiagnostic = nil
	local drift: Sound? = nil
	local boostStart: Sound? = nil
	local boostLoop: Sound? = nil

	local function detach()
		if engineDiagnostic then engineDiagnostic:destroy(); engineDiagnostic = nil end
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
			heartbeatConnection = nil
		end
		for _, connection in kartConnections do
			connection:Disconnect()
		end
		table.clear(kartConnections)
		for _, sound in sounds do
			sound:Stop()
			sound:Destroy()
		end
		table.clear(sounds)
		engine = nil
		drift = nil
		boostStart = nil
		boostLoop = nil
		activeKart = nil
		activeSeat = nil
		activeChassis = nil
	end

	local function attach(seatPart: BasePart?, attempt: number?)
		local kart = getKart(seatPart)
		if kart == activeKart and seatPart == activeSeat then
			return
		end
		detach()
		if not kart or player:GetAttribute("RaceState") == "GARAGE" then
			return
		end
		local chassis = kart:FindFirstChild("Chassis")
		if not chassis or not chassis:IsA("BasePart") then
			if (attempt or 0) < 10 then
				task.delay(0.2, function()
					local character = player.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.SeatPart == seatPart then
						attach(seatPart, (attempt or 0) + 1)
					end
				end)
			end
			return
		end

		activeKart = kart
		activeSeat = seatPart
		activeChassis = chassis
		local function addSound(name: string, asset: string, group: SoundGroup, looped: boolean, volume: number): Sound?
			local sound = AudioRuntime.createSound(name, asset, chassis, group, looped, volume, true)
			if sound then
				table.insert(sounds, sound)
			end
			return sound
		end
		engine = addSound("EngineLoop", AudioConfig.ASSETS.ENGINE_LOOP, engineGroup, true, AudioConfig.ENGINE.IDLE_VOLUME)
		if engine then
			engine.PlaybackSpeed = AudioConfig.ENGINE.IDLE_PLAYBACK_SPEED
		end
		drift = addSound("DriftLoop", AudioConfig.ASSETS.DRIFT_LOOP, sfxGroup, true, 0)
		if drift then
			drift.PlaybackRegionsEnabled = true
			drift.PlaybackRegion = NumberRange.new(5.0, 8.0)
			drift.LoopRegion = NumberRange.new(5.0, 8.0)
		end
		boostStart = addSound("BoostStart", AudioConfig.ASSETS.BOOST_START, sfxGroup, false, AudioConfig.BOOST.START_VOLUME)
		boostLoop = addSound("BoostLoop", AudioConfig.ASSETS.BOOST_LOOP, sfxGroup, true, AudioConfig.BOOST.LOOP_VOLUME)
		AudioRuntime.preload({ Engine = engine, Drift = drift, BoostStart = boostStart, BoostLoop = boostLoop })
		if engine then
			engineDiagnostic = EngineLoopDiagnostic.new(engine,
				RunService:IsStudio() or KartConfig.DEBUG_TELEMETRY == true)
			engineDiagnostic:setMode(player:GetAttribute("KartEngineLoopTestMode"))
			table.insert(kartConnections, player:GetAttributeChangedSignal("KartEngineLoopTestMode"):Connect(function()
				if engineDiagnostic then engineDiagnostic:setMode(player:GetAttribute("KartEngineLoopTestMode")) end
			end))
		end

		local wasBoosting = kart:GetAttribute("KartBoosting") == true
		local wasNitroActive = kart:GetAttribute("KartNitroActive") == true
		local lastBoostStartAt = -math.huge
		local function playBoostStart()
			local now = time()
			-- Shared onset sound: near-simultaneous Mini Boost/Nitro must not
			-- restart the same launch sound twice as attributes replicate.
			if now - lastBoostStartAt >= 0.12 then
				lastBoostStartAt = now
				AudioRuntime.playOnce(boostStart)
			end
		end
		if wasBoosting then
			AudioRuntime.playLoop(boostLoop)
		end
		table.insert(kartConnections, kart:GetAttributeChangedSignal("KartBoosting"):Connect(function()
			local boosting = kart:GetAttribute("KartBoosting") == true
			if boosting and not wasBoosting then
				playBoostStart()
				AudioRuntime.playLoop(boostLoop)
			elseif not boosting and wasBoosting then
				AudioRuntime.stop(boostLoop)
			end
			wasBoosting = boosting
		end))
		table.insert(kartConnections, kart:GetAttributeChangedSignal("KartNitroActive"):Connect(function()
			local active = kart:GetAttribute("KartNitroActive") == true
			if active and not wasNitroActive and player:GetAttribute("RaceState") == "RACING" then
				playBoostStart()
			end
			wasNitroActive = active
		end))
		table.insert(kartConnections, kart.Destroying:Connect(detach))

		if engine or drift then
			heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
				if not activeChassis or not activeChassis.Parent then
					detach()
					return
				end
				local velocity = activeChassis.AssemblyLinearVelocity
				local forwardSpeed = velocity:Dot(activeChassis.CFrame.LookVector)
				if engine then
					local normalized = math.clamp(math.abs(forwardSpeed) / KartConfig.MINI_BOOST_MAX_SPEED, 0, 1)
					local targetPitch = AudioConfig.ENGINE.IDLE_PLAYBACK_SPEED
						+ (AudioConfig.ENGINE.MAX_PLAYBACK_SPEED - AudioConfig.ENGINE.IDLE_PLAYBACK_SPEED) * normalized
					if kart:GetAttribute("KartBoosting") == true then
						targetPitch += AudioConfig.ENGINE.BOOST_PLAYBACK_BONUS
					end
					targetPitch = math.clamp(targetPitch, 0.7, 1.55)
					local targetVolume = AudioConfig.ENGINE.IDLE_VOLUME
						+ (AudioConfig.ENGINE.MAX_VOLUME - AudioConfig.ENGINE.IDLE_VOLUME) * normalized
					local alpha = 1 - math.exp(-AudioConfig.ENGINE.RESPONSE * deltaTime)
					if not engineDiagnostic or not engineDiagnostic:isFixed() then
						engine.PlaybackSpeed += (targetPitch - engine.PlaybackSpeed) * alpha
					end
					engine.Volume += (targetVolume - engine.Volume) * alpha
				end
				if drift then
					local validDrift = kart:GetAttribute("KartDrifting") == true
						and kart:GetAttribute("KartOffTrack") ~= true
						and kart:GetAttribute("RaceControlsLocked") ~= true
						and math.abs(forwardSpeed) >= AudioConfig.DRIFT.MIN_SPEED
					local slipFactor = 0
					if validDrift then
						local lateralSpeed = velocity:Dot(activeChassis.CFrame.RightVector)
						local slip = math.abs(math.deg(math.atan2(lateralSpeed, math.max(math.abs(forwardSpeed), 0.01))))
						slipFactor = math.clamp(
							(slip - AudioConfig.DRIFT.MIN_SLIP_DEGREES)
								/ (AudioConfig.DRIFT.FULL_SLIP_DEGREES - AudioConfig.DRIFT.MIN_SLIP_DEGREES),
							0,
							1
						)
					end
					local targetVolume = slipFactor * AudioConfig.DRIFT.MAX_VOLUME
					local targetPitch = AudioConfig.DRIFT.MIN_PLAYBACK_SPEED
						+ (AudioConfig.DRIFT.MAX_PLAYBACK_SPEED - AudioConfig.DRIFT.MIN_PLAYBACK_SPEED) * slipFactor
					local alpha = 1 - math.exp(-AudioConfig.DRIFT.RESPONSE * deltaTime)
					drift.Volume += (targetVolume - drift.Volume) * alpha
					drift.PlaybackSpeed += (targetPitch - drift.PlaybackSpeed) * alpha
					if targetVolume > 0.01 then
						AudioRuntime.playLoop(drift)
					elseif drift.Volume < 0.01 then
						AudioRuntime.stop(drift)
					end
				end
			end)
		end
	end

	local function bindCharacter(character: Model)
		detach()
		if seatedConnection then
			seatedConnection:Disconnect()
			seatedConnection = nil
		end
		if seatPartConnection then
			seatPartConnection:Disconnect()
			seatPartConnection = nil
		end
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		if player.Character ~= character then
			return
		end
		currentHumanoid = humanoid
		seatedConnection = humanoid.Seated:Connect(function()
			attach(humanoid.SeatPart)
		end)
		seatPartConnection = humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
			attach(humanoid.SeatPart)
		end)
		attach(humanoid.SeatPart)
	end

	RunService.Heartbeat:Connect(function(deltaTime: number)
		seatCheckElapsed += deltaTime
		if seatCheckElapsed < 0.25 then
			return
		end
		seatCheckElapsed = 0
		local humanoid = currentHumanoid
		local seatPart = humanoid and humanoid.SeatPart
		if player:GetAttribute("RaceState") ~= "GARAGE" and seatPart ~= activeSeat then
			attach(seatPart)
		end
	end)

	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function()
		detach()
		if seatedConnection then
			seatedConnection:Disconnect()
			seatedConnection = nil
		end
		if seatPartConnection then
			seatPartConnection:Disconnect()
			seatPartConnection = nil
		end
		currentHumanoid = nil
	end)
	player:GetAttributeChangedSignal("RaceState"):Connect(function()
		if player:GetAttribute("RaceState") == "GARAGE" then
			detach()
		elseif currentHumanoid then
			attach(currentHumanoid.SeatPart)
		end
	end)
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
end

return KartAudioController
