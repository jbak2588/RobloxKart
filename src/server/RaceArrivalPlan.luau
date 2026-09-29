local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RaceMode = require(Shared:WaitForChild("RaceMode"))
local RaceLaunchPayload = require(script.Parent:WaitForChild("RaceLaunchPayload"))

local RaceArrivalPlan = {}

function RaceArrivalPlan.forPlayer(payload, userId)
	local valid, track = RaceLaunchPayload.validate(payload, false)
	if not valid then return nil end
	local slot
	for index, participantUserId in payload.participantUserIds do
		if participantUserId == userId then slot = index; break end
	end
	if not slot then return nil end
	local selection = payload.selections[tostring(userId)]
	return {
		trackId = track.Id,
		maxPlayers = track.MaxPlayers,
		mode = RaceMode.resolve(track.Id),
		gridSlot = slot,
		readyOrder = slot,
		driverId = selection.driverId,
		kartId = selection.kartId,
	}
end

return RaceArrivalPlan
