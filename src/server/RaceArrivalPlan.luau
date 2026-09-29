local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RaceMode = require(Shared:WaitForChild("RaceMode"))
local RaceLaunchPayload = require(script.Parent:WaitForChild("RaceLaunchPayload"))

local RaceArrivalPlan = {}

function RaceArrivalPlan.forPlayer(payload, userId)
	local valid, track = RaceLaunchPayload.validate(payload, true)
	if not valid or payload.participantUserIds[1] ~= userId then return nil end
	local selection = payload.selections[tostring(userId)]
	return {
		trackId = track.Id,
		maxPlayers = track.MaxPlayers,
		mode = RaceMode.resolve(track.Id),
		gridSlot = 1,
		driverId = selection.driverId,
		kartId = selection.kartId,
	}
end

return RaceArrivalPlan
