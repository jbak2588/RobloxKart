-- Developer listening harness. NORMAL is the unchanged production contract.
local Diagnostic = {}

local validModes = {
	NORMAL = true, FIXED_FULL = true, FIXED_A = true, FIXED_B = true,
	DYNAMIC_A = true, DYNAMIC_B = true,
}

local function regionFor(mode: string, length: number): (number?, number?)
	local trim = if mode == "FIXED_A" or mode == "DYNAMIC_A" then 0.05
		elseif mode == "FIXED_B" or mode == "DYNAMIC_B" then 0.10 else nil
	if not trim or length <= 0 then return nil, nil end
	local finish = length - trim
	if finish <= trim then return nil, nil end
	return trim, finish
end

function Diagnostic.new(sound: Sound, allowed: boolean)
	local currentMode: string? = nil
	local serial = 0
	local loadedConnection: RBXScriptConnection? = nil
	local destroyed = false
	local controller = {}

	local function disconnectLoaded()
		if loadedConnection then loadedConnection:Disconnect(); loadedConnection = nil end
	end

	local function apply(mode: string, loaded: boolean)
		sound:Stop()
		sound.PlaybackRegionsEnabled = false
		local start, finish = nil, nil
		if loaded then start, finish = regionFor(mode, sound.TimeLength) end
		if start and finish then
			local range = NumberRange.new(start, finish)
			sound.PlaybackRegion = range
			sound.LoopRegion = range
			sound.PlaybackRegionsEnabled = true
		elseif loaded and (mode == "FIXED_A" or mode == "FIXED_B" or mode == "DYNAMIC_A" or mode == "DYNAMIC_B") then
			warn("[KartEngineDiag] invalid loop region; using full asset")
		end
		sound.TimePosition = start or 0
		if mode == "FIXED_FULL" or mode == "FIXED_A" or mode == "FIXED_B" then
			sound.PlaybackSpeed = 1
		end
		sound:Play()
		if mode ~= "NORMAL" and loaded then
			local span = if start and finish then finish - start else sound.TimeLength
			print(string.format("[KartEngineDiag] mode=%s soundId=%s timeLength=%.3f playbackSpeed=%.3f effectiveLoop=%.3f region=%.3f..%.3f",
				mode, sound.SoundId, sound.TimeLength, sound.PlaybackSpeed,
				span / math.max(sound.PlaybackSpeed, 0.01), start or 0, finish or sound.TimeLength))
		end
	end

	function controller:setMode(requested: unknown)
		if destroyed then return end
		local mode = if allowed and type(requested) == "string" and validModes[requested] then requested else "NORMAL"
		if mode == currentMode then return end
		currentMode = mode
		serial += 1
		local thisSerial = serial
		disconnectLoaded()
		local loaded = sound.IsLoaded and sound.TimeLength > 0
		apply(mode, loaded)
		if mode == "NORMAL" or loaded then return end
		local function onLoaded()
			if destroyed or serial ~= thisSerial then return end
			disconnectLoaded()
			if sound.IsLoaded and sound.TimeLength > 0 then apply(mode, true)
			else warn("[KartEngineDiag] sound length unavailable; using full asset") end
		end
		loadedConnection = sound.Loaded:Connect(onLoaded)
		if sound.IsLoaded and sound.TimeLength > 0 then onLoaded(); return end
		task.delay(5, function()
			if destroyed or serial ~= thisSerial or not loadedConnection then return end
			disconnectLoaded()
			warn("[KartEngineDiag] sound load timed out; using full asset")
		end)
	end

	function controller:isFixed(): boolean
		return currentMode == "FIXED_FULL" or currentMode == "FIXED_A" or currentMode == "FIXED_B"
	end

	function controller:destroy()
		destroyed = true
		serial += 1
		disconnectLoaded()
	end

	return controller
end

return Diagnostic
