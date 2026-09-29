local Players = game:GetService("Players")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ActiveMatchDirectory = require(script.Parent:WaitForChild("ActiveMatchDirectory"))
local RaceLaunchPayload = require(script.Parent:WaitForChild("RaceLaunchPayload"))
local RaceLaunchService = require(script.Parent:WaitForChild("RaceLaunchService"))

local RaceRoomCoordinator = {}

function RaceRoomCoordinator.start(payload)
	local directory = ActiveMatchDirectory.new(
		MemoryStoreService:GetSortedMap(ActiveMatchDirectory.MAP_NAME))
	local roomId, matchId = payload.roomId, payload.matchId
	local phase = "STARTING"
	local racerCount = 0
	local active = true
	local function publish(newPhase, count)
		phase, racerCount = newPhase, count
		local ok, result = pcall(function()
			return directory:raceState(roomId, matchId, newPhase, count,
				game.PrivateServerId, game.JobId)
		end)
		if not ok then warn("[KDMRoom] race directory publish failed: " .. tostring(result)) end
	end

	task.spawn(function()
		while active do
			task.wait(8)
			local ok, record = pcall(function() return directory:get(roomId) end)
			if ok and record and record.matchId ~= matchId then
				active = false
			elseif ok and record then
				publish(phase, racerCount)
			end
		end
	end)

	local function nextRound(players)
		publish("ROUND_COMPLETE", #players)
		local members = {}
		for _, player in players do
			if player.Parent == Players then
				table.insert(members, { userId = player.UserId,
					name = player.DisplayName,
					driverId = player:GetAttribute("SelectedDriverId"),
					kartId = player:GetAttribute("SelectedKartId") })
			end
		end
		local ok, record = pcall(function() return directory:get(roomId) end)
		if not ok or not record or record.matchId ~= matchId then return false end
		if #members == 0 and #record.queued == 0 then
			pcall(function() directory:closeIfIdle(roomId, matchId) end)
			active = false
			return true
		end
		local reserved, accessCode, privateServerId = pcall(function()
			return TeleportService:ReserveServerAsync(game.PlaceId)
		end)
		if not reserved or type(accessCode) ~= "string" or accessCode == "" then
			warn("[KDMRoom] next round reservation failed: " .. tostring(accessCode))
			return false
		end
		local nextMatchId = HttpService:GenerateGUID(false)
		local claimed, nextRecord = pcall(function()
			return directory:claimNext(roomId, matchId, nextMatchId,
				accessCode, privateServerId, members)
		end)
		if not claimed or not nextRecord then return false end
		local nextPayload = RaceLaunchPayload.buildMatch(nextMatchId, roomId,
			nextRecord.launchRoster, payload.trackId)
		if not nextPayload then return false end
		active = false
		if #members > 0 then
			local traveling = {}
			for _, member in members do
				local player = Players:GetPlayerByUserId(member.userId)
				if player then table.insert(traveling, player) end
			end
			if #traveling > 0 then
				local launched = RaceLaunchService.launchMatch(traveling, nextPayload,
					function(player)
						warn(string.format("[KDMRoom] rematch teleport failed user=%d room=%s", player.UserId, roomId))
					end, accessCode, true)
				if not launched then warn("[KDMRoom] rematch group request failed room=" .. roomId) end
			end
		end
		return true
	end

	return { onRoomPhase = publish, onRoundReady = nextRound }
end

return RaceRoomCoordinator
