local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("AudioConfig"))
local RaceConfig = require(Shared:WaitForChild("RaceConfig"))
local AudioRuntime = require(script.Parent:WaitForChild("AudioRuntime"))

local RaceAudioController = {}
local started = false

function RaceAudioController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local group = AudioRuntime.getGroup("RobloxKartSFX")
	local sounds: { [string]: Sound? } = {
		Countdown = AudioRuntime.createSound("CountdownBeep", AudioConfig.ASSETS.COUNTDOWN, SoundService, group, false, AudioConfig.RACE.COUNTDOWN_VOLUME, false),
		Go = AudioRuntime.createSound("RaceGoFirst", AudioConfig.ASSETS.COUNTDOWN, SoundService, group, false, AudioConfig.RACE.GO_VOLUME, false),
		Lap = AudioRuntime.createSound("LapComplete", AudioConfig.ASSETS.LAP_COMPLETE, SoundService, group, false, AudioConfig.RACE.LAP_VOLUME, false),
		FinalLap = AudioRuntime.createSound("FinalLapFirst", AudioConfig.ASSETS.FINAL_LAP, SoundService, group, false, AudioConfig.RACE.LAP_VOLUME, false),
		FinalLapRepeat = AudioRuntime.createSound("FinalLapSecond", AudioConfig.ASSETS.FINAL_LAP, SoundService, group, false, AudioConfig.RACE.LAP_VOLUME, false),
		FinalLapThird = AudioRuntime.createSound("FinalLapThird", AudioConfig.ASSETS.FINAL_LAP, SoundService, group, false, AudioConfig.RACE.LAP_VOLUME, false),
		Finish = AudioRuntime.createSound("RaceFinish", AudioConfig.ASSETS.FINISH, SoundService, group, false, AudioConfig.RACE.FINISH_VOLUME, false),
		Dnf = AudioRuntime.createSound("RaceDNF", AudioConfig.ASSETS.DNF, SoundService, group, false, AudioConfig.RACE.DNF_VOLUME, false),
	}
	if sounds.Go then
		-- Slow the single existing beep to twice its duration. Compensate the
		-- lowered pitch, then raise it independently; never loop/repeat GO.
		sounds.Go.PlaybackSpeed = 1 / AudioConfig.RACE.GO_DURATION_MULTIPLIER
		local compensate = Instance.new("PitchShiftSoundEffect")
		compensate.Name = "GoDurationPitchCompensation"
		compensate.Octave = AudioConfig.RACE.GO_DURATION_MULTIPLIER
		compensate.Priority = 2
		compensate.Parent = sounds.Go
		local higher = Instance.new("PitchShiftSoundEffect")
		higher.Name = "GoHigherPitch"
		higher.Octave = AudioConfig.RACE.GO_PITCH_RATIO
		higher.Priority = 1
		higher.Parent = sounds.Go
	end
	AudioRuntime.preload(sounds)
	for _, sound in { sounds.FinalLap, sounds.FinalLapRepeat, sounds.FinalLapThird } do
		if sound then sound.PlaybackSpeed = AudioConfig.RACE.FINAL_LAP_PLAYBACK_SPEED end
	end

	local previousState = player:GetAttribute("RaceState")
	local previousCountdown = player:GetAttribute("RaceCountdown")
	local previousCompletedLaps = player:GetAttribute("RaceCompletedLaps")
	local lastBeep: number? = nil
	local goSerial = 0
	local finalLapPlayed = false

	local function stopAll()
		for _, sound in sounds do
			AudioRuntime.stop(sound)
		end
	end

	local function playCountdown(value: unknown)
		if type(value) == "number" and value >= 1 and value <= 3 and value ~= lastBeep then
			lastBeep = value
			AudioRuntime.playOnce(sounds.Countdown)
		end
	end

	local function playFinalLapPattern()
		local first = sounds.FinalLap
		local second = sounds.FinalLapRepeat
		local third = sounds.FinalLapThird
		if not first or not second or not third then
			return
		end
		goSerial += 1
		local thisGo = goSerial
		AudioRuntime.playOnce(first)
		local beepLength = if first.TimeLength > 0 then first.TimeLength / first.PlaybackSpeed else 0.32
		-- Three higher beeps, with the same short gap between each.
		for index, sound in { second, third } do
			task.delay(beepLength * 1.16 * index, function()
				if goSerial == thisGo and player:GetAttribute("RaceState") == "RACING" then
					AudioRuntime.playOnce(sound)
				end
			end)
		end
	end

	local function checkFinalLap()
		local total = player:GetAttribute("RaceTotalLaps")
		if type(total) ~= "number" then total = RaceConfig.TOTAL_LAPS end
		-- Match the notice's lap conditions, regardless of attribute arrival order.
		if not finalLapPlayed and player:GetAttribute("RaceState") == "RACING" and total > 1
			and player:GetAttribute("RaceCompletedLaps") == total - 1
			and player:GetAttribute("RaceCurrentLap") == total then
			finalLapPlayed = true
			playFinalLapPattern()
		end
	end
	player:GetAttributeChangedSignal("RaceCurrentLap"):Connect(checkFinalLap)

	player:GetAttributeChangedSignal("RaceCountdown"):Connect(function()
		local current = player:GetAttribute("RaceCountdown")
		if player:GetAttribute("RaceState") == "COUNTDOWN" and current ~= previousCountdown then
			playCountdown(current)
		end
		previousCountdown = current
	end)

	player:GetAttributeChangedSignal("RaceCompletedLaps"):Connect(function()
		local completed = player:GetAttribute("RaceCompletedLaps")
		local previous = previousCompletedLaps
		previousCompletedLaps = completed
		if type(completed) ~= "number" or type(previous) ~= "number" or completed <= previous then
			return
		end
		if player:GetAttribute("RaceState") ~= "RACING" then
			return
		end
		local total = player:GetAttribute("RaceTotalLaps")
		if type(total) ~= "number" then
			total = RaceConfig.TOTAL_LAPS
		end
		if completed >= total then
			return
		elseif completed == total - 1 then
			checkFinalLap()
		else
			AudioRuntime.playOnce(sounds.Lap)
		end
	end)

	player:GetAttributeChangedSignal("RaceState"):Connect(function()
		local state = player:GetAttribute("RaceState")
		local prior = previousState
		previousState = state
		if state ~= "RACING" then
			goSerial += 1
			AudioRuntime.stop(sounds.Go)
			AudioRuntime.stop(sounds.FinalLap)
			AudioRuntime.stop(sounds.FinalLapRepeat)
			AudioRuntime.stop(sounds.FinalLapThird)
		end
		if state == "GARAGE" then
			finalLapPlayed = false
			stopAll()
			lastBeep = nil
		elseif state == "COUNTDOWN" and prior ~= "COUNTDOWN" then
			finalLapPlayed = false
			stopAll()
			lastBeep = nil
			playCountdown(player:GetAttribute("RaceCountdown"))
		elseif state == "RACING" and prior == "COUNTDOWN" then
			AudioRuntime.stop(sounds.Countdown)
			AudioRuntime.playOnce(sounds.Go)
		elseif state == "FINISHING" and prior == "RACING" then
			AudioRuntime.playOnce(sounds.Finish)
		elseif state == "DNF" and prior == "RACING" then
			AudioRuntime.playOnce(sounds.Dnf)
		end
	end)
	-- Park uses a personal server deadline rather than the official race attributes.
	-- Reuse these exact sound instances, including GO duration/pitch/volume.
	local parkPhase,parkGoAt,parkBeep
	local parkConnection=RunService.Heartbeat:Connect(function()
		local phase=player:GetAttribute("ParkTrialPhase")
		local deadline=player:GetAttribute("ParkTrialGoAt")
		if player:GetAttribute("LobbyDriveActive")~=true or player:GetAttribute("RaceState")~="GARAGE"
			or (phase~="COUNTDOWN" and phase~="RUNNING") or type(deadline)~="number" then
			if parkPhase then AudioRuntime.stop(sounds.Countdown);AudioRuntime.stop(sounds.Go)end
			parkPhase,parkGoAt,parkBeep=nil,nil,nil;return
		end
		if phase=="COUNTDOWN" then
			if deadline~=parkGoAt then
				parkGoAt,parkBeep=deadline,nil
				AudioRuntime.stop(sounds.Go)
			end
			local value=math.clamp(math.ceil(deadline-Workspace:GetServerTimeNow()),1,3)
			if value~=parkBeep then parkBeep=value;AudioRuntime.playOnce(sounds.Countdown)end
		elseif parkPhase=="COUNTDOWN" and deadline==parkGoAt then
			AudioRuntime.stop(sounds.Countdown);AudioRuntime.playOnce(sounds.Go)
		end
		parkPhase=phase
	end)
	player.AncestryChanged:Connect(function(_,parent)
		if not parent then parkConnection:Disconnect();goSerial+=1;stopAll() end
	end)
end

return RaceAudioController
