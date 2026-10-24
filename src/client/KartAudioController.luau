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
	local engineSecondary: Sound? = nil
	local engineLooper = nil
	local engineDiagnostic = nil
	local drift: Sound? = nil
	local boostAudio = nil

	local function detach()
		if boostAudio then boostAudio:destroy(); boostAudio = nil end
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
		engineSecondary = nil
		engineLooper = nil
		drift = nil
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
		if AudioRuntime.createEngineLooper then
			engineSecondary = addSound("EngineLoopB", AudioConfig.ASSETS.ENGINE_LOOP, engineGroup, true, 0)
		end
		if engine then
			engine.PlaybackSpeed = AudioConfig.ENGINE.IDLE_PLAYBACK_SPEED
		end
		if engineSecondary then
			engineSecondary.PlaybackSpeed = AudioConfig.ENGINE.IDLE_PLAYBACK_SPEED * AudioConfig.ENGINE.SECONDARY_DETUNE
		end
		engineLooper = if AudioRuntime.createEngineLooper then AudioRuntime.createEngineLooper(engine, engineSecondary) else nil
		drift = addSound("DriftLoop", AudioConfig.ASSETS.DRIFT_LOOP, sfxGroup, true, 0)
		if drift then
			drift.PlaybackRegionsEnabled = true
			drift.PlaybackRegion = NumberRange.new(5.0, 8.0)
			drift.LoopRegion = NumberRange.new(5.0, 8.0)
		end
		boostAudio = AudioRuntime.createBoostAudio(chassis, "Race")
		local missileHit = addSound("VictimMissileHit", AudioConfig.COMBAT.Missile.Asset, sfxGroup, false, AudioConfig.COMBAT.Missile.Volume)
		if missileHit then missileHit.PlaybackSpeed = AudioConfig.COMBAT.Missile.Pitch end
		local thunderHit = addSound("VictimThunderHit", AudioConfig.COMBAT.Thunder.Asset, sfxGroup, false, AudioConfig.COMBAT.Thunder.Volume)
		if thunderHit then thunderHit.PlaybackSpeed = AudioConfig.COMBAT.Thunder.Pitch end
		AudioRuntime.preload({ Engine = engine, EngineB = engineSecondary, Drift = drift, MissileHit = missileHit, ThunderHit = thunderHit })
		if engine then
			engineDiagnostic = EngineLoopDiagnostic.new(engine,
				RunService:IsStudio() or KartConfig.DEBUG_TELEMETRY == true)
			engineDiagnostic:setMode(player:GetAttribute("KartEngineLoopTestMode"))
			table.insert(kartConnections, player:GetAttributeChangedSignal("KartEngineLoopTestMode"):Connect(function()
				if engineDiagnostic then engineDiagnostic:setMode(player:GetAttribute("KartEngineLoopTestMode")) end
			end))
		end

		local wasMissileHit = kart:GetAttribute("KartMissileHitActive") == true
		local wasThunderHit = kart:GetAttribute("KartThunderHitActive") == true
		local function updateBoostAudio(dt)
			boostAudio:step(dt, kart:GetAttribute("KartBoosting") == true,
				kart:GetAttribute("KartNitroActive") == true, kart:GetAttribute("KartNitroEndReason"),
				player:GetAttribute("RaceState") == "RACING" and kart:GetAttribute("RaceControlsLocked") ~= true)
		end
		updateBoostAudio(0)
		for _, attribute in { "KartBoosting", "KartNitroActive", "RaceControlsLocked" } do
			table.insert(kartConnections, kart:GetAttributeChangedSignal(attribute):Connect(function() updateBoostAudio(0) end))
		end
		table.insert(kartConnections, kart:GetAttributeChangedSignal("KartMissileHitActive"):Connect(function()
			local active = kart:GetAttribute("KartMissileHitActive") == true
			if active and not wasMissileHit and player:GetAttribute("RaceState") == "RACING" then
				if missileHit then AudioRuntime.playOnce(missileHit) end
			end
			wasMissileHit = active
		end))
		table.insert(kartConnections, kart:GetAttributeChangedSignal("KartThunderHitActive"):Connect(function()
			local active = kart:GetAttribute("KartThunderHitActive") == true
			if active and not wasThunderHit and player:GetAttribute("RaceState") == "RACING" then
				if thunderHit then AudioRuntime.playOnce(thunderHit) end
			end
			wasThunderHit = active
		end))
		table.insert(kartConnections, kart.Destroying:Connect(detach))

		if engine or drift or boostAudio then
			heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
				if not activeChassis or not activeChassis.Parent then
					detach()
					return
				end
				updateBoostAudio(deltaTime)
				local velocity = activeChassis.AssemblyLinearVelocity
				local forwardSpeed = velocity:Dot(activeChassis.CFrame.LookVector)
				if engine then
					-- PRESENT is a stopped, anchored kart; replicated velocity may retain
					-- its last ROLL sample. Use idle audio without changing that physics state.
					local raceState = player:GetAttribute("RaceState")
					local finishedStop = player:GetAttribute("RaceFinishPhase") == "PRESENT"
						and (raceState == "FINISHING" or raceState == "FINISHED")
					local audioSpeed = if finishedStop then 0 else forwardSpeed
					local speed = math.abs(audioSpeed)
					local normalRatio = math.clamp(speed / KartConfig.MAX_FORWARD_SPEED, 0, 1)
					local boostRatio = math.clamp((speed - KartConfig.MAX_FORWARD_SPEED)
						/ (KartConfig.MINI_BOOST_MAX_SPEED - KartConfig.MAX_FORWARD_SPEED), 0, 1)
					local targetPitch = AudioConfig.ENGINE.IDLE_PLAYBACK_SPEED
						+ (AudioConfig.ENGINE.NORMAL_PLAYBACK_SPEED - AudioConfig.ENGINE.IDLE_PLAYBACK_SPEED) * normalRatio
						+ (AudioConfig.ENGINE.MAX_PLAYBACK_SPEED - AudioConfig.ENGINE.NORMAL_PLAYBACK_SPEED) * boostRatio
					if not finishedStop and kart:GetAttribute("KartBoosting") == true then
						targetPitch += AudioConfig.ENGINE.BOOST_PLAYBACK_BONUS
					end
					targetPitch = math.clamp(targetPitch, 0.7, 1.55)
					local targetVolume = AudioConfig.ENGINE.IDLE_VOLUME
						+ (AudioConfig.ENGINE.NORMAL_VOLUME - AudioConfig.ENGINE.IDLE_VOLUME) * normalRatio
						+ (AudioConfig.ENGINE.MAX_VOLUME - AudioConfig.ENGINE.NORMAL_VOLUME) * boostRatio
					local alpha = 1 - math.exp(-AudioConfig.ENGINE.RESPONSE * deltaTime)
					local fixedPitch = engineDiagnostic ~= nil and engineDiagnostic:isFixed()
					local diagActive = player:GetAttribute("KartEngineLoopTestMode") ~= nil
						and player:GetAttribute("KartEngineLoopTestMode") ~= "NORMAL"
					if fixedPitch then
						engine.PlaybackSpeed = 1
					end
					if engineLooper then
						engineLooper:step(deltaTime, if fixedPitch then 1 else targetPitch, targetVolume, alpha, diagActive or fixedPitch)
					else
						if not fixedPitch then
							engine.PlaybackSpeed += (targetPitch - engine.PlaybackSpeed) * alpha
						end
						engine.Volume += (targetVolume - engine.Volume) * alpha
					end
				end
				if drift then
					local offTrack = kart:GetAttribute("KartOffTrack") == true
					local validDrift = kart:GetAttribute("KartDrifting") == true
						and not offTrack
						and kart:GetAttribute("RaceControlsLocked") ~= true
						and math.abs(forwardSpeed) >= AudioConfig.DRIFT.MIN_SPEED
					-- Slick cancels Drift in gameplay, so its skid must be driven by
					-- the victim's own authoritative hit state, not KartDrifting.
					local slickHit = kart:GetAttribute("KartSlickActive") == true
						and player:GetAttribute("RaceState") == "RACING"
						and kart:GetAttribute("RaceControlsLocked") ~= true
					local isOffTrackRumble = offTrack
						and math.abs(forwardSpeed) >= 6
						and kart:GetAttribute("RaceControlsLocked") ~= true

					local targetVolume = 0
					local targetPitch = AudioConfig.DRIFT.MIN_PLAYBACK_SPEED

					if isOffTrackRumble then
						-- Option A: Low-pitched, heavy tire rumble while driving on off-track grass/gravel
						local offTrackFactor = math.clamp(math.abs(forwardSpeed) / 60, 0.3, 1.0)
						targetVolume = offTrackFactor * (AudioConfig.DRIFT.MAX_VOLUME * 0.75)
						targetPitch = 0.65 + 0.12 * math.clamp(math.abs(forwardSpeed) / 100, 0, 1)
					elseif slickHit then
						targetVolume = AudioConfig.DRIFT.MAX_VOLUME
						targetPitch = AudioConfig.DRIFT.MAX_PLAYBACK_SPEED
					elseif validDrift then
						local lateralSpeed = velocity:Dot(activeChassis.CFrame.RightVector)
						local slip = math.abs(math.deg(math.atan2(lateralSpeed, math.max(math.abs(forwardSpeed), 0.01))))
						local slipFactor = math.clamp(
							(slip - AudioConfig.DRIFT.MIN_SLIP_DEGREES)
								/ (AudioConfig.DRIFT.FULL_SLIP_DEGREES - AudioConfig.DRIFT.MIN_SLIP_DEGREES),
							0,
							1
						)
						targetVolume = slipFactor * AudioConfig.DRIFT.MAX_VOLUME
						targetPitch = AudioConfig.DRIFT.MIN_PLAYBACK_SPEED
							+ (AudioConfig.DRIFT.MAX_PLAYBACK_SPEED - AudioConfig.DRIFT.MIN_PLAYBACK_SPEED) * slipFactor
					end

					local alpha = 1 - math.exp(-AudioConfig.DRIFT.RESPONSE * deltaTime)
					drift.Volume += (targetVolume - drift.Volume) * alpha
					drift.PlaybackSpeed += (targetPitch - drift.PlaybackSpeed) * alpha
					if targetVolume > 0.01 then
						if not drift.IsPlaying then drift.TimePosition = 5 end
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
