-- Short-lived, server-only HUB availability and Room invitations.
local Titles=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LobbyTitleCatalog"))
local RoomSocialDirectory = {}
RoomSocialDirectory.__index = RoomSocialDirectory
RoomSocialDirectory.PRESENCE_MAP = "KDM_HubPresence_v1"
RoomSocialDirectory.INVITE_MAP = "KDM_RoomInvites_v1"
RoomSocialDirectory.PRESENCE_TTL = 25
RoomSocialDirectory.INVITE_TTL = 45

function RoomSocialDirectory.new(presenceMap, inviteMap, now)
	return setmetatable({ presence = presenceMap, invites = inviteMap,
		now = now or os.time }, RoomSocialDirectory)
end

function RoomSocialDirectory:publish(player, hubJobId)
	local entry = { userId = player.UserId, name = if player.DisplayName and player.DisplayName~="" then player.DisplayName else player.Name,
		hubJobId = hubJobId, state = "HUB_AVAILABLE", updatedAt = self.now() }
	self.presence:SetAsync(tostring(player.UserId), entry, self.PRESENCE_TTL, entry.updatedAt)
end

function RoomSocialDirectory:remove(userId)
	self.presence:RemoveAsync(tostring(userId))
end

function RoomSocialDirectory:list(excludeUserId)
	local available, bound = {}, nil
	while true do
		local rows = self.presence:GetRangeAsync(Enum.SortDirection.Descending, 100, bound)
		for _, row in rows do
			local entry = row.value
			if type(entry) == "table" and entry.userId ~= excludeUserId
				and entry.state == "HUB_AVAILABLE"
				and self.now() - entry.updatedAt <= self.PRESENCE_TTL then
				table.insert(available, { userId = entry.userId, name = entry.name })
			end
		end
		if #rows < 100 then break end
		local last = rows[#rows]
		bound = { key = last.key, sortKey = last.sortKey }
	end
	return available
end

function RoomSocialDirectory:sendInvite(targetUserId, room)
	local title,kind=Titles.publicTitle(room)
	local invite = { roomId = room.roomId, hostUserId = room.hostUserId,
		hostName = room.hostName, trackId = room.trackId,
		lobbyTitle=title,lobbyTitleKind=kind,
		expiresAt = self.now() + self.INVITE_TTL }
	self.invites:SetAsync(tostring(targetUserId), invite, self.INVITE_TTL)
	return invite
end

function RoomSocialDirectory:getInvite(userId)
	local invite = self.invites:GetAsync(tostring(userId))
	if type(invite) ~= "table" or type(invite.expiresAt) ~= "number"
		or invite.expiresAt <= self.now() then return nil end
	return invite
end

function RoomSocialDirectory:clearInvite(userId)
	self.invites:RemoveAsync(tostring(userId))
end

return RoomSocialDirectory
