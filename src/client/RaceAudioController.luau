local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

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
		GoRepeat = AudioRuntime.createSound("RaceGoSecond", AudioConfig.ASSETS.COUNTDOWN, SoundService, group, false, AudioConfig.RACE.GO_VOLUME, false),
		GoThird = AudioRuntime.createSound("RaceGoThird", AudioConfig.ASSETS.COUNTDOWN, SoundService, group, false, AudioConfig.RACE.GO_VOLUME, false),
		Lap = AudioRuntime.createSound("LapComplete", AudioConfig.ASSETS.LAP_COMPLETE, SoundService, group, false, AudioConfig.RACE.LAP_VOLUME, false),
		FinalLap = AudioRuntime.createSound("FinalLap", AudioConfig.ASSETS.FINAL_LAP, SoundService, group, false, AudioConfig.RACE.LAP_VOLUME, false),
		Finish = AudioRuntime.createSound("RaceFinish", AudioConfig.ASSETS.FINISH, SoundService, group, false, AudioConfig.RACE.FINISH_VOLUME, false),
		Dnf = AudioRuntime.createSound("RaceDNF", AudioConfig.ASSETS.DNF, SoundService, group, false, AudioConfig.RACE.DNF_VOLUME, false),
	}
	if sounds.Go then
		sounds.Go.PlaybackSpeed = 1.08
	end
	if sounds.GoRepeat then
		sounds.GoRepeat.PlaybackSpeed = 1.08
	end
	if sounds.GoThird then
		sounds.GoThird.PlaybackSpeed = 1.08
	end
	AudioRuntime.preload(sounds)

	local previousState = player:GetAttribute("RaceState")
	local previousCountdown = player:GetAttribute("RaceCountdown")
	local previousCompletedLaps = player:GetAttribute("RaceCompletedLaps")
	local lastBeep: number? = nil
	local goSerial = 0

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

	local function playGo()
		local first = sounds.Go
		local second = sounds.GoRepeat
		local third = sounds.GoThird
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
			AudioRuntime.playOnce(sounds.FinalLap)
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
		end
		if state == "GARAGE" then
			stopAll()
			lastBeep = nil
		elseif state == "COUNTDOWN" and prior ~= "COUNTDOWN" then
			stopAll()
			lastBeep = nil
			playCountdown(player:GetAttribute("RaceCountdown"))
		elseif state == "RACING" and prior == "COUNTDOWN" then
			playGo()
		elseif state == "FINISHED" and prior == "RACING" then
			AudioRuntime.playOnce(sounds.Finish)
		elseif state == "DNF" and prior == "RACING" then
			AudioRuntime.playOnce(sounds.Dnf)
		end
	end)
end

return RaceAudioController
