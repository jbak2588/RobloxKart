-- Read server-published positions; client Workspace kart replication is not a map contract.
local RaceMinimapRivals = {}

function RaceMinimapRivals.collect(localPlayer, players, participantCount)
	local rivals = {}
	local sessionId = localPlayer:GetAttribute("RaceSessionId")
	if participantCount < 2 or type(sessionId) ~= "number" or sessionId <= 0 then
		return rivals
	end
	for _, other in players do
		if other ~= localPlayer and other:GetAttribute("RaceSessionId") == sessionId
			and other:GetAttribute("RaceState") ~= "GARAGE"
			and other:GetAttribute("RaceMapActive") == true then
			local position = other:GetAttribute("RaceMapPosition")
			if typeof(position) == "Vector3" then rivals[other.UserId] = position end
		end
	end
	return rivals
end

return RaceMinimapRivals
