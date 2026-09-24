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

return AudioRuntime
