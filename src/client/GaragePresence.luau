local GaragePresence = {}

local statusLabels = {
	GARAGE = "GARAGE", PRE_RACE = "READY", COUNTDOWN = "STARTING",
	RACING = "RACING", FINISHING = "FINISHING", FINISHED = "RESULT", DNF = "DNF",
}

function GaragePresence.snapshot(players, localPlayer)
	local entries = {}
	for _, player in players do
		table.insert(entries, {
			userId = player.UserId,
			isLocal = player == localPlayer,
			readyOrder = player:GetAttribute("ReadyOrder") or 0,
			name = if type(player.DisplayName) == "string" and player.DisplayName ~= ""
				then player.DisplayName else player.Name,
			status = statusLabels[player:GetAttribute("RaceState")] or "GARAGE",
		})
	end
	table.sort(entries, function(a, b)
		if a.isLocal ~= b.isLocal then return a.isLocal end
		if (a.readyOrder > 0) ~= (b.readyOrder > 0) then return a.readyOrder > 0 end
		if a.readyOrder > 0 and b.readyOrder > 0 and a.readyOrder ~= b.readyOrder then
			return a.readyOrder < b.readyOrder
		end
		local aName, bName = string.lower(a.name), string.lower(b.name)
		if aName ~= bName then return aName < bName end
		return a.userId < b.userId
	end)
	return #entries, entries
end

function GaragePresence.canvasHeight(count, rowHeight, spacing)
	return math.max(0, count * rowHeight + math.max(0, count - 1) * spacing)
end

-- width/height are already CoreUISafeInsets content bounds. Do not inset again.
function GaragePresence.mobileLayout(count, width, height, previewWidth, presenceWidth, twoLines)
	local top = if twoLines then height * 0.13 + 64 else height * 0.155
	local availableHeight = height * 0.38 - top - 8
	local panelWidth = presenceWidth
	if width > height then
		-- A narrow notch-safe gutter is still landscape, not the portrait lane.
		panelWidth = math.min(presenceWidth, math.floor((width - previewWidth) * 0.5 - 62),
			math.floor(width * 0.1 - 16))
		top = math.max(56, height * 0.12 + 6)
		availableHeight = height - top - 8
	end
	local capacity = math.clamp(math.floor((availableHeight - 30) / 18), 0, 4)
	local visibleRows = math.min(count, capacity)
	local listHeight = GaragePresence.canvasHeight(visibleRows, 16, 2)
	return { width = math.max(0, panelWidth), top = top, visibleRows = visibleRows,
		listHeight = listHeight, panelHeight = 32 + listHeight }
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
