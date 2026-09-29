local RaceLaunchPayload = require(script.Parent:WaitForChild("RaceLaunchPayload"))

local ServerRuntime = {}
ServerRuntime.HUB = "HUB"
ServerRuntime.RACE = "RACE"
local currentRole = ServerRuntime.HUB

function ServerRuntime.resolve(privateServerId, joinData, placeId, userId, privateServerOwnerId)
	if type(privateServerId) ~= "string" or privateServerId == "" then return ServerRuntime.HUB end
	if type(privateServerOwnerId) == "number" and privateServerOwnerId ~= 0 then return ServerRuntime.HUB end
	if type(joinData) ~= "table" or joinData.SourcePlaceId ~= placeId then return ServerRuntime.HUB end
	local payload = joinData.TeleportData
	local valid = RaceLaunchPayload.validate(payload, true)
	if not valid or payload.participantUserIds[1] ~= userId then return ServerRuntime.HUB end
	return ServerRuntime.RACE, payload
end

function ServerRuntime.setRole(role)
	assert(role == ServerRuntime.HUB or role == ServerRuntime.RACE, "Invalid server role")
	currentRole = role
end

function ServerRuntime.getRole() return currentRole end
function ServerRuntime.isHub() return currentRole == ServerRuntime.HUB end
function ServerRuntime.isRace() return currentRole == ServerRuntime.RACE end

return ServerRuntime
