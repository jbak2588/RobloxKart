-- Ephemeral, server-only room authority shared by HUB and reserved RACE jobs.
local ActiveMatchDirectory = {}
ActiveMatchDirectory.__index = ActiveMatchDirectory
ActiveMatchDirectory.MAP_NAME = "KDM_ActiveBaseRooms_v1"
ActiveMatchDirectory.TTL_SECONDS = 45
ActiveMatchDirectory.MAX_QUEUED = 32

function ActiveMatchDirectory.new(map, now)
	return setmetatable({ map = map, now = now or os.time }, ActiveMatchDirectory)
end

local function stamp(self, record)
	record.updatedAt = self.now()
	return record
end

function ActiveMatchDirectory:create(room)
	local record = stamp(self, {
		roomId = room.id, trackId = room.trackId, state = "WAITING",
		hostUserId = room.hostUserId, hostName = room.hostName,
		currentRacers = #room.members, maxPlayers = room.maxPlayers,
		queued = {}, roundId = 0, matchId = "", ownerJobId = room.ownerJobId,
		waitingMembers = room.members,
		currentUserIds = {}, privateServerId = "", reservedServerAccessCode = "", raceJobId = "",
	})
	self.map:SetAsync(room.id, record, self.TTL_SECONDS, record.updatedAt)
	return record
end

function ActiveMatchDirectory:get(roomId)
	local value = self.map:GetAsync(roomId)
	return value
end

function ActiveMatchDirectory:update(roomId, mutate)
	local result = self.map:UpdateAsync(roomId, function(old)
		if type(old) ~= "table" or old.roomId ~= roomId then return nil end
		local draft = table.clone(old)
		for _, field in { "queued", "waitingMembers", "currentUserIds", "launchRoster" } do
			if type(old[field]) == "table" then draft[field] = table.clone(old[field]) end
		end
		local changed = mutate(draft)
		if not changed then return nil end
		return stamp(self, changed), self.now()
	end, self.TTL_SECONDS)
	return result
end

function ActiveMatchDirectory:waiting(room)
	return self:update(room.id, function(record)
		if record.state ~= "WAITING" or record.ownerJobId ~= room.ownerJobId then return nil end
		record.hostUserId = room.hostUserId
		record.hostName = room.hostName
		record.currentRacers = #room.members
		record.waitingMembers = room.members
		return record
	end)
end

function ActiveMatchDirectory:heartbeatWaiting(roomId, ownerJobId)
	return self:update(roomId, function(record)
		if record.state ~= "WAITING" or record.ownerJobId ~= ownerJobId then return nil end
		return record
	end)
end

function ActiveMatchDirectory:joinWaiting(roomId, member)
	return self:update(roomId, function(record)
		if record.state ~= "WAITING" or #record.waitingMembers >= record.maxPlayers then return nil end
		for _, existing in record.waitingMembers do
			if existing.userId == member.userId then return nil end
		end
		table.insert(record.waitingMembers, member)
		record.currentRacers = #record.waitingMembers
		return record
	end)
end

function ActiveMatchDirectory:leaveWaiting(roomId, userId)
	local result = self:update(roomId, function(record)
		if record.state ~= "WAITING" then return nil end
		for index, member in record.waitingMembers do
			if member.userId == userId then table.remove(record.waitingMembers, index); break end
		end
		if #record.waitingMembers == 0 then
			record.currentRacers = 0
		else
			local host = record.waitingMembers[1]
			record.hostUserId = host.userId
			record.hostName = host.name
			record.ownerJobId = host.hubJobId
			record.currentRacers = #record.waitingMembers
		end
		return record
	end)
	if result and result.currentRacers == 0 then self:remove(roomId) end
	return result
end

function ActiveMatchDirectory:initialLaunch(roomId, hostUserId, matchId, accessCode, privateServerId)
	return self:update(roomId, function(record)
		if record.state ~= "WAITING" or record.hostUserId ~= hostUserId then return nil end
		local userIds = {}
		for _, member in record.waitingMembers do table.insert(userIds, member.userId) end
		record.state = "STARTING"
		record.roundId = 1
		record.matchId = matchId
		record.currentUserIds = userIds
		record.currentRacers = #userIds
		record.launchRoster = record.waitingMembers
		record.waitingMembers = {}
		record.privateServerId = privateServerId
		record.reservedServerAccessCode = accessCode
		return record
	end)
end

function ActiveMatchDirectory:launchAccepted(roomId, matchId, privateServerId, accessCode)
	return self:update(roomId, function(record)
		if record.matchId ~= matchId then return nil end
		record.privateServerId = privateServerId or ""
		record.reservedServerAccessCode = accessCode or ""
		return record
	end)
end

function ActiveMatchDirectory:launchFailed(roomId, matchId)
	return self:update(roomId, function(record)
		if record.matchId ~= matchId or record.state ~= "STARTING" or record.roundId ~= 1
			or record.raceJobId ~= "" then return nil end
		record.state = "WAITING"
		record.roundId = 0
		record.matchId = ""
		record.currentUserIds = {}
		record.waitingMembers = record.launchRoster or {}
		record.currentRacers = #record.waitingMembers
		local waiting = {}
		for _, member in record.waitingMembers do waiting[member.userId] = true end
		local retainedQueue = {}
		for _, member in record.queued do
			if not waiting[member.userId] then table.insert(retainedQueue, member) end
		end
		record.queued = retainedQueue
		record.launchRoster = nil
		record.privateServerId = ""
		record.reservedServerAccessCode = ""
		record.raceJobId = ""
		return record
	end)
end

function ActiveMatchDirectory:raceState(roomId, matchId, state, racerCount, privateServerId, raceJobId)
	return self:update(roomId, function(record)
		if record.matchId ~= matchId then return nil end
		local order = { STARTING = 1, RACING = 2, FINISHING = 3, ROUND_COMPLETE = 4 }
		if (order[state] or 0) < (order[record.state] or 0) then return record end
		record.state = state
		record.currentRacers = racerCount
		if privateServerId then record.privateServerId = privateServerId end
		if raceJobId then record.raceJobId = raceJobId end
		return record
	end)
end

function ActiveMatchDirectory:queue(roomId, member)
	return self:update(roomId, function(record)
		if record.state == "WAITING" or record.state == "CLOSING"
			or #record.queued >= self.MAX_QUEUED then return nil end
		for _, queued in record.queued do
			if queued.userId == member.userId then return nil end
		end
		table.insert(record.queued, member)
		return record
	end)
end

function ActiveMatchDirectory:closeIfIdle(roomId, matchId)
	local record = self:update(roomId, function(current)
		if current.matchId ~= matchId or current.state ~= "ROUND_COMPLETE"
			or current.currentRacers ~= 0 or #current.queued > 0 then return nil end
		current.state = "CLOSING"
		return current
	end)
	if record then self:remove(roomId) end
	return record ~= nil
end

function ActiveMatchDirectory:cancelQueue(roomId, userId)
	return self:update(roomId, function(record)
		for index, member in record.queued do
			if member.userId == userId then table.remove(record.queued, index); return record end
		end
		return nil
	end)
end

function ActiveMatchDirectory:claimNext(roomId, matchId, nextMatchId, accessCode, privateServerId, rematchMembers)
	return self:update(roomId, function(record)
		if record.matchId ~= matchId or record.state ~= "ROUND_COMPLETE" then return nil end
		local roster = {}
		local seen = {}
		for _, member in rematchMembers do
			if #roster >= record.maxPlayers then break end
			if not seen[member.userId] then
				seen[member.userId] = true
				table.insert(roster, member)
			end
		end
		local remaining = {}
		for _, member in record.queued do
			if not seen[member.userId] and #roster < record.maxPlayers then
				seen[member.userId] = true
				table.insert(roster, member)
			else
				table.insert(remaining, member)
			end
		end
		if #roster == 0 then return nil end
		local hostPresent = false
		for _, member in roster do
			if member.userId == record.hostUserId then hostPresent = true; break end
		end
		if not hostPresent then
			record.hostUserId = roster[1].userId
			record.hostName = roster[1].name or tostring(roster[1].userId)
		end
		record.queued = remaining
		record.state = "STARTING"
		record.roundId += 1
		record.matchId = nextMatchId
		record.reservedServerAccessCode = accessCode
		record.privateServerId = privateServerId
		record.raceJobId = ""
		record.currentUserIds = {}
		for _, member in roster do table.insert(record.currentUserIds, member.userId) end
		record.currentRacers = #roster
		record.launchRoster = roster
		return record
	end)
end

function ActiveMatchDirectory:list()
	local records = {}
	local bound = nil
	while true do
		local rows = self.map:GetRangeAsync(Enum.SortDirection.Ascending, 100, bound)
		for _, row in rows do
			if type(row.value) == "table" and row.value.state ~= "CLOSING" then
				table.insert(records, row.value)
			end
		end
		if #rows < 100 then break end
		local last = rows[#rows]
		bound = { key = last.key, sortKey = last.sortKey }
	end
	return records
end

function ActiveMatchDirectory:display(record)
	return { id = record.roomId, trackId = record.trackId, state = record.state,
		hostUserId = record.hostUserId, hostName = record.hostName,
		count = record.currentRacers, maxPlayers = record.maxPlayers,
		queuedCount = #record.queued, roundId = record.roundId }
end

function ActiveMatchDirectory:remove(roomId)
	self.map:RemoveAsync(roomId)
end

return ActiveMatchDirectory
