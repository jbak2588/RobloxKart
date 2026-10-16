local RoomDisplay = {}
local labels = { WAITING = "WAITING", STARTING = "STARTING", COUNTDOWN = "STARTING",
	RACING = "RACING", FINISHING = "FINISHING", ROUND_COMPLETE = "RESULTS" }

function RoomDisplay.state(state)
	return labels[state] or "UPDATING"
end

function RoomDisplay.canJoin(room)
	return (room.state == "WAITING"or room.quickWarmup==true) and (room.humanCount or room.count)+(room.reservedCount or 0)<room.maxPlayers
end

return RoomDisplay
