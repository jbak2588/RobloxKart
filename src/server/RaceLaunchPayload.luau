local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackCatalog = require(Shared:WaitForChild("TrackCatalog"))
local DriverCatalog = require(Shared:WaitForChild("DriverCatalog"))
local KartCatalog = require(Shared:WaitForChild("KartCatalog"))

local RaceLaunchPayload = {}
RaceLaunchPayload.SCHEMA = "KDM_RACE_V1"

local function validUserId(value)
	return type(value) == "number" and value > 0 and value % 1 == 0
end

function RaceLaunchPayload.validate(payload, soloOnly)
	if type(payload) ~= "table" or payload.schema ~= RaceLaunchPayload.SCHEMA
		or payload.role ~= "RACE" or payload.source ~= "HUB"
		or type(payload.matchId) ~= "string" or #payload.matchId < 8 or #payload.matchId > 64 then
		return false, "invalid_header"
	end
	if type(payload.trackId) ~= "string" then return false, "invalid_track" end
	local track = TrackCatalog.Entries[payload.trackId]
	if not track then return false, "invalid_track" end
	if track.MatchType == "PUBLIC_RACE" then
		if type(payload.roomId) ~= "string" or #payload.roomId < 8 or #payload.roomId > 64 then
			return false, "invalid_room"
		end
	elseif payload.roomId ~= nil then
		return false, "unexpected_room"
	end
	if soloOnly and track.MatchType ~= "SOLO_PRACTICE" and track.MatchType ~= "SOLO_PROTOTYPE" then
		return false, "unsupported_track"
	end
	local participants = payload.participantUserIds
	if type(participants) ~= "table" or #participants < track.MinPlayers
		or #participants > track.MaxPlayers or (soloOnly and #participants ~= 1) then
		return false, "invalid_count"
	end
	local total = 0
	for index in participants do
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #participants then
			return false, "invalid_participants"
		end
		total += 1
	end
	if total ~= #participants then return false, "invalid_participants" end
	if type(payload.selections) ~= "table" then return false, "missing_selections" end
	local seen = {}
	for _, userId in participants do
		if not validUserId(userId) or seen[userId] then return false, "invalid_participant" end
		seen[userId] = true
		local selection = payload.selections[tostring(userId)]
		if type(selection) ~= "table" or not DriverCatalog.Entries[selection.driverId]
			or not KartCatalog.Entries[selection.kartId] then
			return false, "invalid_selection"
		end
	end
	return true, track
end

function RaceLaunchPayload.buildMatch(matchId, roomId, members, trackId)
	local track = TrackCatalog.Entries[trackId]
	if not track or track.MatchType ~= "PUBLIC_RACE" or type(members) ~= "table" then
		return nil, "unsupported_track"
	end
	local payload = {
		schema = RaceLaunchPayload.SCHEMA, role = "RACE", source = "HUB",
		matchId = matchId, roomId = roomId, trackId = trackId,
		participantUserIds = {}, selections = {},
	}
	for _, member in members do
		table.insert(payload.participantUserIds, member.userId)
		payload.selections[tostring(member.userId)] = {
			driverId = member.driverId, kartId = member.kartId,
		}
	end
	local valid, reason = RaceLaunchPayload.validate(payload, false)
	if not valid then return nil, reason end
	return payload
end

function RaceLaunchPayload.buildSolo(matchId, player, trackId, driverId, kartId)
	local payload = {
		schema = RaceLaunchPayload.SCHEMA,
		role = "RACE",
		matchId = matchId,
		trackId = trackId,
		source = "HUB",
		participantUserIds = { player.UserId },
		selections = { [tostring(player.UserId)] = { driverId = driverId, kartId = kartId } },
	}
	local valid, reason = RaceLaunchPayload.validate(payload, true)
	if not valid then return nil, reason end
	return payload
end

return RaceLaunchPayload
