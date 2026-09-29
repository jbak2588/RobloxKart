local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ServerRuntime = require(script:WaitForChild("ServerRuntime"))
local RaceLaunchService = require(script:WaitForChild("RaceLaunchService"))
local PrototypeWorld = require(script:WaitForChild("PrototypeWorld"))
local RaceItemController = require(script:WaitForChild("RaceItemController"))
local RaceController = require(script:WaitForChild("RaceController"))
local GarageController = require(script:WaitForChild("GarageController"))
local RaceServerBootstrap = require(script:WaitForChild("RaceServerBootstrap"))
local PlayerPreferences = require(script:WaitForChild("PlayerPreferences"))
local MatchRoomService = require(script:WaitForChild("MatchRoomService"))

local firstPlayer
local joinData
if not RunService:IsStudio() and game.PrivateServerId ~= "" then
	firstPlayer = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	local ok, result = pcall(function() return firstPlayer:GetJoinData() end)
	if ok then joinData = result end
end

local role, payload, resolveReason = ServerRuntime.resolve(if RunService:IsStudio() then "" else game.PrivateServerId,
	game.PrivateServerOwnerId, joinData, game.GameId,
	if firstPlayer then firstPlayer.UserId else 0)
ServerRuntime.setRole(role)
Workspace:SetAttribute("KDMServerRole", role)
print(string.format("[KDMRoute] resolve role=%s reason=%s private=%s owner=%s sourcePlace=%s sourceGame=%s match=%s track=%s job=%s",
	role, resolveReason, tostring(game.PrivateServerId ~= ""), tostring(game.PrivateServerOwnerId),
	tostring(if joinData then joinData.SourcePlaceId else nil),
	tostring(if joinData then joinData.SourceGameId else nil),
	tostring(if payload then payload.matchId else nil), tostring(if payload then payload.trackId else nil),
	tostring(game.JobId)))
RaceLaunchService.start()

if ServerRuntime.isRace() then
	local initialized, reason = pcall(function()
		print(string.format("[KDMRoute] race world start match=%s track=%s", payload.matchId, payload.trackId))
		PrototypeWorld.start({ trackId = payload.trackId })
		print(string.format("[KDMRoute] race world ready match=%s track=%s", payload.matchId, payload.trackId))
		-- RaceHudController waits for this RemoteEvent, while Garage admission stays HUB-only.
		local garageRemote = Instance.new("RemoteEvent")
		garageRemote.Name = "GarageControl"
		garageRemote.Parent = ReplicatedStorage
		RaceItemController.start()
		print(string.format("[KDMRoute] race controller start match=%s", payload.matchId))
		assert(RaceController.start({ trackId = payload.trackId,
			preformedMatch = payload.roomId ~= nil,
			expectedParticipantCount = #payload.participantUserIds,
			returnToHub = RaceLaunchService.returnToHub }), "Race controller startup failed")
		print(string.format("[KDMRoute] race controller ready match=%s", payload.matchId))
		PlayerPreferences.start()
		print(string.format("[KDMRoute] race bootstrap start match=%s", payload.matchId))
		assert(RaceServerBootstrap.start(payload, firstPlayer, joinData), "Race arrival startup failed")
		print(string.format("[KDMRoute] race bootstrap ready match=%s", payload.matchId))
	end)
	if not initialized then
		warn("[KDMRoute] race startup failed: " .. tostring(reason))
		RaceLaunchService.returnToHub(firstPlayer, function()
			if firstPlayer.Parent == Players then
				firstPlayer:Kick("Race launch unavailable. Please rejoin Kart Drift Masters.")
			end
		end)
	end
elseif firstPlayer and game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
	-- A malformed reserved launch never creates a default Practice race.
	warn("[KDMRoute] reserved launch rejected reason=" .. resolveReason)
	RaceLaunchService.returnToHub(firstPlayer, function()
		if firstPlayer.Parent == Players then
			firstPlayer:Kick("Race launch unavailable. Please rejoin Kart Drift Masters.")
		end
	end)
else
	PrototypeWorld.start()
	RaceItemController.start()
	RaceController.start()
	MatchRoomService.start()
	GarageController.start()
	PlayerPreferences.start()
end

print("RobloxKart SERVER sync OK")
