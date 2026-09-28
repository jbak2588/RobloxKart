-- Select replicated karts belonging to racers in the local active round.
local RaceMinimapRivals = {}

function RaceMinimapRivals.collect(localPlayer, players, prototype, participantCount)
	local rivals = {}
	local sessionId = localPlayer:GetAttribute("RaceSessionId")
	if participantCount < 2 or type(sessionId) ~= "number" or sessionId <= 0 or not prototype then
		return rivals
	end
	local kartsByOwner = {}
	for _, kart in prototype:GetChildren() do
		local ownerId = kart:GetAttribute("KartOwnerUserId")
		if type(ownerId) == "number" and ownerId > 0 then
			local chassis = kart:FindFirstChild("Chassis")
			if chassis and chassis:IsA("BasePart") then kartsByOwner[ownerId] = chassis end
		end
	end
	for _, other in players do
		if other ~= localPlayer and other:GetAttribute("RaceSessionId") == sessionId
			and other:GetAttribute("RaceState") ~= "GARAGE" then
			local chassis = kartsByOwner[other.UserId]
			if chassis then rivals[other.UserId] = chassis.Position end
		end
	end
	return rivals
end

return RaceMinimapRivals
