local RoomDisplay = {}
local labels = { WAITING = "WAITING", STARTING = "STARTING", COUNTDOWN = "STARTING",
	RACING = "RACING", FINISHING = "FINISHING", ROUND_COMPLETE = "RESULTS" }

function RoomDisplay.state(state)
	return labels[state] or "UPDATING"
end

function RoomDisplay.canJoin(room)
	return room.state == "WAITING" and room.count < room.maxPlayers
end

return RoomDisplay
