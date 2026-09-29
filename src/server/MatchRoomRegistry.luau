local MatchRoomRegistry = {}
MatchRoomRegistry.__index = MatchRoomRegistry

function MatchRoomRegistry.new(trackId, maxPlayers, idFactory)
	idFactory = idFactory or function() return game:GetService("HttpService"):GenerateGUID(false) end
	return setmetatable({ trackId = trackId, maxPlayers = maxPlayers,
		rooms = {}, membership = {}, nextId = 0, nextOrder = 0, idFactory = idFactory }, MatchRoomRegistry)
end

function MatchRoomRegistry:roomFor(userId)
	return self.rooms[self.membership[userId]]
end

function MatchRoomRegistry:create(userId, driverId, kartId)
	if self:roomFor(userId) then return nil, "ALREADY_IN_ROOM" end
	self.nextId += 1
	local roomId = self.idFactory()
	local room = { id = roomId, trackId = self.trackId,
		maxPlayers = self.maxPlayers, createdOrder = self.nextId, state = "WAITING",
		members = {}, hostUserId = userId }
	self.rooms[room.id] = room
	self:join(room.id, userId, driverId, kartId)
	return room
end

function MatchRoomRegistry:join(roomId, userId, driverId, kartId)
	local room = self.rooms[roomId]
	if self:roomFor(userId) then return nil, "ALREADY_IN_ROOM" end
	if not room or room.state ~= "WAITING" then return nil, "ROOM_UNAVAILABLE" end
	if #room.members >= self.maxPlayers then return nil, "ROOM_FULL" end
	self.nextOrder += 1
	table.insert(room.members, { userId = userId, driverId = driverId, kartId = kartId, joinOrder = self.nextOrder })
	self.membership[userId] = roomId
	return room
end

function MatchRoomRegistry:leave(userId)
	local room = self:roomFor(userId)
	if not room then return nil end
	self.membership[userId] = nil
	for index, member in room.members do
		if member.userId == userId then table.remove(room.members, index); break end
	end
	if #room.members == 0 then
		self.rooms[room.id] = nil
	else
		room.hostUserId = room.members[1].userId
	end
	return room
end

function MatchRoomRegistry:launch(roomId, hostUserId)
	local room = self.rooms[roomId]
	if not room or room.state ~= "WAITING" or room.hostUserId ~= hostUserId then return nil, "NOT_HOST" end
	room.state = "LAUNCHING"
	return room
end

function MatchRoomRegistry:snapshot()
	local rooms = {}
	for _, room in self.rooms do
		if room.state == "WAITING" then
			table.insert(rooms, { id = room.id, count = #room.members, maxPlayers = self.maxPlayers,
				hostUserId = room.hostUserId })
		end
	end
	table.sort(rooms, function(a, b) return a.id < b.id end)
	return rooms
end

return MatchRoomRegistry
