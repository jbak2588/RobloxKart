local GaragePresence = {}

local statusLabels = {
	GARAGE = "GARAGE", PRE_RACE = "READY", COUNTDOWN = "STARTING",
	RACING = "RACING", FINISHING = "FINISHING", FINISHED = "RESULT", DNF = "DNF",
}

function GaragePresence.snapshot(players, limit)
	local entries = {}
	for _, player in players do
		table.insert(entries, {
			userId = player.UserId,
			name = if type(player.DisplayName) == "string" and player.DisplayName ~= ""
				then player.DisplayName else player.Name,
			status = statusLabels[player:GetAttribute("RaceState")] or "GARAGE",
		})
	end
	table.sort(entries, function(a, b) return a.userId < b.userId end)
	local count = #entries
	while #entries > limit do table.remove(entries) end
	return count, entries
end

function GaragePresence.availableSnapshot(players, localPlayer, limit)
	local entries = {}
	for _, player in players do
		if player ~= localPlayer and player:GetAttribute("RaceState") == "GARAGE" then
			table.insert(entries, {
				userId = player.UserId,
				name = if type(player.DisplayName) == "string" and player.DisplayName ~= ""
					then player.DisplayName else player.Name,
			})
		end
	end
	table.sort(entries, function(a, b) return a.userId < b.userId end)
	local count = #entries
	while #entries > limit do table.remove(entries) end
	return count, entries
end

return GaragePresence
