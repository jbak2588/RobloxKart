local RaceLaunchPayload = require(script.Parent:WaitForChild("RaceLaunchPayload"))

local ServerRuntime = {}
ServerRuntime.HUB = "HUB"
ServerRuntime.RACE = "RACE"
local currentRole = ServerRuntime.HUB

function ServerRuntime.resolve(privateServerId, privateServerOwnerId, joinData, gameId, userId)
	if type(privateServerId) ~= "string" or privateServerId == "" then
		return ServerRuntime.HUB, nil, "PUBLIC_SERVER"
	end
	if privateServerOwnerId ~= 0 then
		return ServerRuntime.HUB, nil, "PLAYER_OWNED_PRIVATE_SERVER"
	end
	if type(joinData) ~= "table" then return ServerRuntime.HUB, nil, "NO_JOIN_DATA" end
	if joinData.SourceGameId ~= gameId then return ServerRuntime.HUB, nil, "WRONG_SOURCE_GAME" end
	local payload = joinData.TeleportData
	if payload == nil then return ServerRuntime.HUB, nil, "MISSING_TELEPORT_DATA" end
	local valid = RaceLaunchPayload.validate(payload, true)
	if not valid then return ServerRuntime.HUB, nil, "INVALID_PAYLOAD" end
	local participating = false
	for _, participantUserId in payload.participantUserIds do
		if participantUserId == userId then participating = true; break end
	end
	if not participating then return ServerRuntime.HUB, nil, "USER_NOT_PARTICIPANT" end
	return ServerRuntime.RACE, payload, "VALID_KDM_RACE"
end

function ServerRuntime.setRole(role)
	assert(role == ServerRuntime.HUB or role == ServerRuntime.RACE, "Invalid server role")
	currentRole = role
end

function ServerRuntime.getRole() return currentRole end
function ServerRuntime.isHub() return currentRole == ServerRuntime.HUB end
function ServerRuntime.isRace() return currentRole == ServerRuntime.RACE end

return ServerRuntime
