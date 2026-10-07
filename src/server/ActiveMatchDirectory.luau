-- Ephemeral, server-only room authority shared by HUB and reserved RACE jobs.
local Titles=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LobbyTitleCatalog"))
local ActiveMatchDirectory = {}
ActiveMatchDirectory.__index = ActiveMatchDirectory
ActiveMatchDirectory.MAP_NAME = "KDM_ActiveBaseRooms_v1"
ActiveMatchDirectory.TTL_SECONDS = 45
ActiveMatchDirectory.MAX_QUEUED = 32
ActiveMatchDirectory.ADMISSION_SECONDS = 60

function ActiveMatchDirectory.new(map, now)
	return setmetatable({ map = map, now = now or os.time }, ActiveMatchDirectory)
end

local function stamp(self, record)
	record.lobbyTitle,record.lobbyTitleKind=Titles.publicTitle(record)
	record.updatedAt = self.now()
	return record
end

function ActiveMatchDirectory:create(room)
	local record = stamp(self, {
		roomId = room.id, trackId = room.trackId, state = "WAITING",
		hostUserId = room.hostUserId, hostName = room.hostName,
		lobbyTitleKind=room.lobbyTitleKind, lobbyTitle=room.lobbyTitle,
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
		for _, field in { "queued", "waitingMembers", "currentUserIds", "launchRoster", "stagedMembers", "currentRoundMembers", "rivalUserIds", "leftUserIds" } do
			if type(old[field]) == "table" then draft[field] = table.clone(old[field]) end
		end
		for _, field in { "stagedBots", "currentRoundBots" } do
			draft[field] = {}
			for _, bot in old[field] or {} do table.insert(draft[field], table.clone(bot)) end
		end
		local changed = mutate(draft)
		if not changed then return nil end
		return stamp(self, changed), self.now()
	end, self.TTL_SECONDS)
	return result
end

-- R2 rooms keep staging, the locked round, and the next-round queue separate.
function ActiveMatchDirectory:createPersistent(room, accessCode, privateServerId)
	local record = stamp(self, {
		roomId = room.id, trackId = room.trackId, state = "WAITING",
		hostUserId = room.hostUserId, hostName = room.hostName,
		lobbyTitleKind=room.lobbyTitleKind, lobbyTitle=room.lobbyTitle,
		maxPlayers = room.maxPlayers, currentRacers = 0,
		stagedMembers = {}, currentRoundMembers = {}, rivalUserIds = {}, leftUserIds = {}, queued = {},
		stagedBots = {}, currentRoundBots = {},
		roundId = 0, matchId = room.matchId, raceJobId = "",
		privateServerId = privateServerId, reservedServerAccessCode = accessCode,
	})
	self.map:SetAsync(room.id, record, self.TTL_SECONDS, record.updatedAt)
	return record
end

local function contains(members, userId)
	for _, member in members or {} do if member.userId == userId then return true end end
	return false
end

local function waitingCapacity(record)
	return #(record.stagedMembers or {}) + #(record.stagedBots or {})
end
local function waitingCount(record)
	local count = #(record.stagedBots or {})
	for _, member in record.stagedMembers or {} do if member.arrived then count += 1 end end
	return count
end

-- Server descriptor only; Bots never enter any UserId roster or admission token.
function ActiveMatchDirectory:addBot(roomId, descriptor)
	if type(descriptor) ~= "table" or descriptor.botId ~= "Bot01"
		or descriptor.name ~= "KDM Rookie [BOT]" or descriptor.kartId ~= "Kart01" then return nil end
	return self:update(roomId, function(record)
		if record.state ~= "WAITING" or record.trackId ~= "Track01Race" or not record.stagedMembers
			or type(record.raceJobId) ~= "string" or record.raceJobId == "" or #record.stagedBots >= 1
			or waitingCapacity(record) >= record.maxPlayers or descriptor.gridSlot ~= record.maxPlayers then return nil end
		local hostPresent = false
		for _, member in record.stagedMembers do
			if member.userId == record.hostUserId and member.arrived then hostPresent = true end
		end
		if not hostPresent then return nil end
		table.insert(record.stagedBots, {botId="Bot01", name="KDM Rookie [BOT]", kartId="Kart01", gridSlot=record.maxPlayers})
		record.currentRacers = waitingCount(record)
		return record
	end)
end

function ActiveMatchDirectory:removeBot(roomId, botId)
	return self:update(roomId, function(record)
		if record.state ~= "WAITING" then return nil end
		for index, bot in record.stagedBots do
			if bot.botId == botId then
				table.remove(record.stagedBots, index)
				record.currentRacers = waitingCount(record)
				return record
			end
		end
		return nil
	end)
end

-- Lifecycle cleanup, never a client remove action during a locked round.
function ActiveMatchDirectory:clearBots(roomId, raceJobId)
	return self:update(roomId, function(record)
		if record.raceJobId ~= raceJobId then return nil end
		record.stagedBots, record.currentRoundBots = {}, {}
		if record.state == "WAITING" then record.currentRacers = waitingCount(record)
		else
			record.currentRacers = 0
			for _, member in record.currentRoundMembers or {} do
				if not table.find(record.leftUserIds or {}, member.userId) then record.currentRacers += 1 end
			end
		end
		return record
	end)
end

function ActiveMatchDirectory:stage(roomId, member, token, expectedTrackId)
	return self:update(roomId, function(record)
		if expectedTrackId and record.trackId ~= expectedTrackId then return nil end
		if record.state ~= "WAITING" or waitingCapacity(record) >= record.maxPlayers
			or contains(record.stagedMembers, member.userId)
			or contains(record.queued, member.userId) then return nil end
		member.admissionToken = token
		member.admissionExpiresAt = self.now() + self.ADMISSION_SECONDS
		member.arrived = false
		table.insert(record.stagedMembers, member)
		return record
	end)
end

function ActiveMatchDirectory:confirmArrival(roomId, userId, token, raceJobId)
	return self:update(roomId, function(record)
		if record.state ~= "WAITING" then return nil end
		if record.raceJobId ~= "" and record.raceJobId ~= raceJobId then
			if record.currentRacers > 0 then return nil end
			for _, staged in record.stagedMembers do if staged.arrived then return nil end end
		end
		for _, member in record.stagedMembers do
			if member.userId == userId and member.admissionToken == token
				and type(member.admissionExpiresAt) == "number"
				and member.admissionExpiresAt > self.now() then
				member.arrived = true
				member.admissionToken = nil
				record.raceJobId = raceJobId
				record.currentRacers = #record.stagedBots
				for _, staged in record.stagedMembers do
					if staged.arrived then record.currentRacers += 1 end
				end
				return record
			end
		end
		return nil
	end)
end

function ActiveMatchDirectory:renewAdmission(roomId, userId, oldToken, newToken)
	return self:update(roomId, function(record)
		if record.state ~= "WAITING" then return nil end
		for _, member in record.stagedMembers do
			if member.userId == userId and not member.arrived
				and member.admissionToken == oldToken then
				member.admissionToken = newToken
				member.admissionExpiresAt = self.now() + self.ADMISSION_SECONDS
				return record
			end
		end
		return nil
	end)
end

function ActiveMatchDirectory:removeStaged(roomId, userId)
	local hadBot = false
	local result = self:update(roomId, function(record)
		if record.state ~= "WAITING" then return nil end
		hadBot = #record.stagedBots > 0
		for index, member in record.stagedMembers do
			if member.userId == userId then table.remove(record.stagedMembers, index); break end
		end
		if waitingCapacity(record) < record.maxPlayers and #record.queued > 0 then
			table.sort(record.queued, function(a, b)
				if (a.priority or 3) ~= (b.priority or 3) then return (a.priority or 3) < (b.priority or 3) end
				if a.queuedAt ~= b.queuedAt then return a.queuedAt < b.queuedAt end
				return a.userId < b.userId
			end)
			local promoted = table.remove(record.queued, 1)
			promoted.arrived = false
			table.insert(record.stagedMembers, promoted)
		end
		record.currentRacers = 0
		for _, member in record.stagedMembers do if member.arrived then record.currentRacers += 1 end end
		if record.currentRacers == 0 then record.stagedBots = {}; record.currentRoundBots = {} end
		record.currentRacers += #record.stagedBots
		if record.hostUserId == userId and record.stagedMembers[1] then
			record.hostUserId = record.stagedMembers[1].userId
			record.hostName = record.stagedMembers[1].name
		end
		return record
	end)
	if result and #result.stagedMembers == 0 and #result.queued == 0 then
		self:remove(roomId)
	elseif result and hadBot then
		local humans = 0
		for _, member in result.stagedMembers do if member.arrived then humans += 1 end end
		if humans == 0 then self:remove(roomId) end
	end
	return result
end

function ActiveMatchDirectory:leaveMember(roomId, userId)
	local record = self:get(roomId)
	if not record then return nil end
	if record.state == "WAITING" then return self:removeStaged(roomId, userId) end
	local result = self:update(roomId, function(draft)
		if not draft.currentRoundMembers then return nil end
		if not contains(draft.currentRoundMembers, userId) then return nil end
		if not table.find(draft.leftUserIds, userId) then table.insert(draft.leftUserIds, userId) end
		if draft.hostUserId == userId then
			for _, member in draft.currentRoundMembers do
				if not table.find(draft.leftUserIds, member.userId) then
					draft.hostUserId = member.userId
					draft.hostName = member.name
					break
				end
			end
		end
		return draft
	end)
	if result then
		local humans = 0
		for _, member in result.currentRoundMembers do
			if not table.find(result.leftUserIds, member.userId) then humans += 1 end
		end
		if humans == 0 and #(result.currentRoundBots or {}) > 0 then self:remove(roomId) end
	end
	return result
end

function ActiveMatchDirectory:startRound(roomId, hostUserId, expectedCount)
	return self:update(roomId, function(record)
		if record.state ~= "WAITING" or record.hostUserId ~= hostUserId
			or record.currentRacers < 1
			or waitingCapacity(record) ~= record.currentRacers
			or (expectedCount and expectedCount ~= record.currentRacers) then return nil end
		local roster = {}
		for _, member in record.stagedMembers do
			if member.arrived then table.insert(roster, member) end
		end
		if #roster + #record.stagedBots ~= record.currentRacers or #roster == 0 then return nil end
		record.currentRoundMembers = roster
		record.currentRoundBots = record.stagedBots
		record.stagedBots = {}
		record.leftUserIds = {}
		record.stagedMembers = {}
		record.state = "STARTING"
		record.roundId += 1
		record.currentRacers = #roster + #record.currentRoundBots
		return record
	end)
end

function ActiveMatchDirectory:nextStaging(roomId, rematchMembers)
	return self:update(roomId, function(record)
		if record.state ~= "ROUND_COMPLETE" then return nil end
		local bots = if #rematchMembers > 0 then record.currentRoundBots else {}
		local humanLimit = record.maxPlayers - #bots
		local staged, seen = {}, {}
		for _, member in rematchMembers do
			if #staged < humanLimit and not seen[member.userId] then
				member.arrived = true
				seen[member.userId] = true
				table.insert(staged, member)
			end
		end
		table.sort(record.queued, function(a, b)
			local pa, pb = a.priority or 3, b.priority or 3
			if pa ~= pb then return pa < pb end
			if a.queuedAt ~= b.queuedAt then return a.queuedAt < b.queuedAt end
			return a.userId < b.userId
		end)
		local remaining = {}
		for _, member in record.queued do
			if #staged < humanLimit and not seen[member.userId] then
				seen[member.userId] = true
				member.arrived = false
				member.admissionToken = member.admissionToken or member.token
				member.admissionExpiresAt = self.now() + self.ADMISSION_SECONDS
				table.insert(staged, member)
			else table.insert(remaining, member) end
		end
		if #staged == 0 and #remaining == 0 then return nil end
		record.stagedMembers = staged
		record.stagedBots = bots
		record.currentRoundBots = {}
		record.rivalUserIds = {}
		for _, member in record.currentRoundMembers do
			table.insert(record.rivalUserIds, member.userId)
		end
		record.currentRoundMembers = {}
		record.queued = remaining
		record.state = "WAITING"
		record.currentRacers = waitingCount(record)
		if not contains(staged, record.hostUserId) then
			record.hostUserId = staged[1].userId
			record.hostName = staged[1].name
		end
		return record
	end)
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
		if record.stagedMembers then
			if state == "WAITING" then
				if record.state ~= "WAITING" then return nil end
			else
				local order = { STARTING = 1, RACING = 2, FINISHING = 3, ROUND_COMPLETE = 4 }
				if not order[state] or not order[record.state]
					or order[state] < order[record.state] then return nil end
			end
			record.state = state
			if state == "WAITING" then
				record.currentRacers = #record.stagedBots
				for _, staged in record.stagedMembers do
					if staged.arrived then record.currentRacers += 1 end
				end
			else record.currentRacers = racerCount end
			if privateServerId then record.privateServerId = privateServerId end
			if raceJobId then record.raceJobId = raceJobId end
			return record
		end
		local order = { STARTING = 1, RACING = 2, FINISHING = 3, ROUND_COMPLETE = 4 }
		if (order[state] or 0) < (order[record.state] or 0) then return record end
		record.state = state
		record.currentRacers = racerCount
		if privateServerId then record.privateServerId = privateServerId end
		if raceJobId then record.raceJobId = raceJobId end
		return record
	end)
end

function ActiveMatchDirectory:queue(roomId, member, expectedTrackId)
	return self:update(roomId, function(record)
		if expectedTrackId and record.trackId ~= expectedTrackId then return nil end
		if (record.state == "WAITING" and (not record.stagedMembers
			or waitingCapacity(record) < record.maxPlayers)) or record.state == "CLOSING"
			or #record.queued >= self.MAX_QUEUED then return nil end
		if record.stagedMembers and contains(record.stagedMembers, member.userId) then return nil end
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
	local lobbyTitle,lobbyTitleKind=Titles.publicTitle(record)
	return { id = record.roomId, trackId = record.trackId, state = record.state,
		lobbyTitle=lobbyTitle, lobbyTitleKind=lobbyTitleKind,
		hostUserId = record.hostUserId, hostName = record.hostName,
		count = if record.state == "WAITING" and record.stagedMembers
			then waitingCapacity(record) else record.currentRacers,
		maxPlayers = record.maxPlayers,
		queuedCount = #record.queued, roundId = record.roundId }
end

function ActiveMatchDirectory:remove(roomId)
	self.map:RemoveAsync(roomId)
end

return ActiveMatchDirectory
