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

local firstPlayer
local joinData
if not RunService:IsStudio() and game.PrivateServerId ~= "" then
	firstPlayer = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	local ok, result = pcall(function() return firstPlayer:GetJoinData() end)
	if ok then joinData = result end
end

local role, payload = ServerRuntime.resolve(if RunService:IsStudio() then "" else game.PrivateServerId,
	joinData, game.PlaceId,
	if firstPlayer then firstPlayer.UserId else 0, game.PrivateServerOwnerId)
ServerRuntime.setRole(role)
Workspace:SetAttribute("KDMServerRole", role)
print(string.format("[KDMRoute] role=%s job=%s", role, game.JobId))
RaceLaunchService.start()

if ServerRuntime.isRace() then
	print(string.format("[KDMRoute] role=RACE match=%s track=%s expected=1", payload.matchId, payload.trackId))
	local initialized, reason = pcall(function()
		PrototypeWorld.start({ trackId = payload.trackId })
		-- RaceHudController waits for this RemoteEvent, while Garage admission stays HUB-only.
		local garageRemote = Instance.new("RemoteEvent")
		garageRemote.Name = "GarageControl"
		garageRemote.Parent = ReplicatedStorage
		RaceItemController.start()
		assert(RaceController.start({ trackId = payload.trackId,
			returnToHub = RaceLaunchService.returnToHub }), "Race controller startup failed")
		PlayerPreferences.start()
		assert(RaceServerBootstrap.start(payload), "Race arrival startup failed")
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
	RaceLaunchService.returnToHub(firstPlayer, function()
		firstPlayer:Kick("Race launch unavailable. Please rejoin Kart Drift Masters.")
	end)
else
	PrototypeWorld.start()
	RaceItemController.start()
	RaceController.start()
	GarageController.start()
	PlayerPreferences.start()
end

print("RobloxKart SERVER sync OK")
