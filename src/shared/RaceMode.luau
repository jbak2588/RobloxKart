-- Selected catalog entry determines the server-authoritative lap policy.
local requireModule = require :: (ModuleScript) -> any
local RaceConfig = requireModule(script.Parent:WaitForChild("RaceConfig") :: ModuleScript)
local Mode = { RACE = "RACE", PRACTICE = "PRACTICE" }
function Mode.resolve(trackId)
	return if trackId == "Track01" then Mode.PRACTICE else Mode.RACE
end
function Mode.targetLaps(mode)
	return if mode == Mode.PRACTICE then 1 else RaceConfig.TOTAL_LAPS
end
function Mode.label(mode)
	return if mode == Mode.PRACTICE then "PRACTICE / 1 LAP" else "RACE / 3 LAPS"
end
return table.freeze(Mode)
