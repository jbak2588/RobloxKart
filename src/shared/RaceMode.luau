-- Selected catalog entry determines the server-authoritative lap policy.
local requireModule = require :: (ModuleScript) -> any
local RaceConfig = requireModule(script.Parent:WaitForChild("RaceConfig") :: ModuleScript)
local TrackCatalog = requireModule(script.Parent:WaitForChild("TrackCatalog") :: ModuleScript)
local Mode = { RACE = "RACE", PRACTICE = "PRACTICE" }
function Mode.resolve(trackId)
	return if trackId == "Track01" then Mode.PRACTICE else Mode.RACE
end
function Mode.targetLaps(mode, trackId)
	local track = TrackCatalog.Entries[trackId]
	return if track then track.TargetLaps else (if mode == Mode.PRACTICE then 1 else RaceConfig.TOTAL_LAPS)
end
function Mode.label(mode, trackId)
	local laps = Mode.targetLaps(mode, trackId)
	return string.format("%s / %d %s", mode, laps, if laps == 1 then "LAP" else "LAPS")
end
return table.freeze(Mode)
