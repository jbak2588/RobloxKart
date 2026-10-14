local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AudioConfig"))

local AudioRuntime = {}

function AudioRuntime.isConfigured(soundId: unknown): boolean
	return type(soundId) == "string" and soundId:match("%S") ~= nil
end

function AudioRuntime.getGroup(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Volume = 1
	group.Parent = SoundService
	return group
end

function AudioRuntime.createSound(
	name: string,
	soundId: unknown,
	parent: Instance,
	group: SoundGroup,
	looped: boolean,
	volume: number,
	spatial: boolean
): Sound?
	if not AudioRuntime.isConfigured(soundId) then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId :: string
	sound.Looped = looped
	sound.Volume = volume
	sound.SoundGroup = group
	if spatial then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = AudioConfig.SPATIAL.MIN_DISTANCE
		sound.RollOffMaxDistance = AudioConfig.SPATIAL.MAX_DISTANCE
	end
	sound.Parent = parent
	return sound
end

function AudioRuntime.playOnce(sound: Sound?)
	if sound then
		sound:Stop()
		sound:Play()
	end
end

function AudioRuntime.playLoop(sound: Sound?)
	if sound and not sound.IsPlaying then
		sound:Play()
	end
end

function AudioRuntime.stop(sound: Sound?)
	if sound and sound.IsPlaying then
		sound:Stop()
	end
end

function AudioRuntime.preload(sounds: { [string]: Sound? })
	local configured: { Sound } = {}
	for _, sound in sounds do
		if sound then
			table.insert(configured, sound)
		end
	end
	if #configured == 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(configured)
		end)
	end)
end

-- Shared dual-voice equal-power crossfade looper for both Race and Lobby karts.
-- Eliminates the encoder-padding pop at the 1.96s loop boundary of asset 6667206432.
function AudioRuntime.createEngineLooper(primary: Sound?, secondary: Sound?)
	local activeVoice = 1
	local crossfadeElapsed: number? = nil
	local masterVol = AudioConfig.ENGINE.IDLE_VOLUME
	local currentPitch = AudioConfig.ENGINE.IDLE_PLAYBACK_SPEED
	local rng = Random.new()
	local activeFadeDuration = AudioConfig.ENGINE.CROSSFADE_DURATION
	local flutterClock = rng:NextNumber(0, 10)
	local looper = {}

	function looper:step(deltaTime: number, targetPitch: number, targetVolume: number, alpha: number, bypassCrossfade: boolean?)
		if not primary then return end
		currentPitch = if bypassCrossfade then primary.PlaybackSpeed else currentPitch + (targetPitch - currentPitch) * alpha
		masterVol += (targetVolume - masterVol) * alpha

		if not secondary or bypassCrossfade or not primary.IsLoaded or primary.TimeLength <= 0.8 then
			primary.PlaybackSpeed = currentPitch
			if secondary and secondary.IsPlaying then
				secondary:Stop()
				secondary.Volume = 0
			end
			primary.Volume = masterVol
			return
		end

		-- Non-repeating dual-sine RPM micro-flutter breaks steady-state periodicity at constant speed
		flutterClock += deltaTime
		local cruisingWeight = math.clamp((currentPitch - AudioConfig.ENGINE.IDLE_PLAYBACK_SPEED) / 0.35, 0.25, 1)
		local waveA = math.sin(flutterClock * 1.73 * math.pi * 2) * 0.65
		local waveB = math.sin(flutterClock * 4.19 * math.pi * 2) * 0.35
		local flutterDepth = AudioConfig.ENGINE.RPM_FLUTTER_DEPTH or 0.012
		local leadFlutter = 1 + (waveA + waveB) * flutterDepth * cruisingWeight
		local followFlutter = 1 + (waveB - waveA) * flutterDepth * cruisingWeight

		local lead = if activeVoice == 1 then primary else secondary
		local follow = if activeVoice == 1 then secondary else primary
		lead.PlaybackSpeed = currentPitch * leadFlutter
		follow.PlaybackSpeed = currentPitch * AudioConfig.ENGINE.SECONDARY_DETUNE * followFlutter

		if not lead.IsPlaying then
			lead.TimePosition = AudioConfig.ENGINE.LOOP_TRIM_START
			lead:Play()
		end
		local switchPoint = math.max(
			AudioConfig.ENGINE.LOOP_TRIM_START + 0.25,
			primary.TimeLength - AudioConfig.ENGINE.LOOP_TRIM_END - (activeFadeDuration * currentPitch)
		)
		if crossfadeElapsed == nil and lead.TimePosition >= switchPoint then
			crossfadeElapsed = 0
			local maxJitter = math.min(
				AudioConfig.ENGINE.ENTRY_JITTER_MAX or 0.35,
				math.max(0, primary.TimeLength * 0.35 - AudioConfig.ENGINE.LOOP_TRIM_START)
			)
			follow.TimePosition = AudioConfig.ENGINE.LOOP_TRIM_START + rng:NextNumber(0, maxJitter)
			local fadeJitter = AudioConfig.ENGINE.CROSSFADE_JITTER or 0.08
			activeFadeDuration = math.max(0.22, AudioConfig.ENGINE.CROSSFADE_DURATION + rng:NextNumber(-fadeJitter, fadeJitter))
			if not follow.IsPlaying then follow:Play() end
		end
		if crossfadeElapsed ~= nil then
			crossfadeElapsed += deltaTime
			local t = math.clamp(crossfadeElapsed / activeFadeDuration, 0, 1)
			lead.Volume = masterVol * math.cos(t * math.pi * 0.5)
			follow.Volume = masterVol * math.sin(t * math.pi * 0.5)
			if t >= 1 then
				lead:Stop()
				lead.Volume = 0
				follow.Volume = masterVol
				activeVoice = if activeVoice == 1 then 2 else 1
				crossfadeElapsed = nil
			end
		else
			lead.Volume = masterVol
			follow.Volume = 0
		end
	end

	return looper
end

return AudioRuntime
