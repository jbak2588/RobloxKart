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
local CompactHubBuilder = require(script:WaitForChild("CompactHubBuilder"))
local RaceServerBootstrap = require(script:WaitForChild("RaceServerBootstrap"))
local PlayerPreferences = require(script:WaitForChild("PlayerPreferences"))
local MatchRoomService = require(script:WaitForChild("MatchRoomService"))
local RaceRoomCoordinator = require(script:WaitForChild("RaceRoomCoordinator"))
local KDMServerPresence = require(script:WaitForChild("KDMServerPresence"))
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")

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
-- Both HUB query and Reserved RACE result writer share the existing Profile store.
-- The service's exact server policy blocks Studio and all non-Canary accounts.
local recordsReady = pcall(function() require(script:WaitForChild("RaceRecordService")).startQuery() end)
if not recordsReady then warn("[KDMRecords] query unavailable") end
print(string.format("[KDMRoute] resolve role=%s reason=%s private=%s owner=%s sourcePlace=%s sourceGame=%s match=%s track=%s job=%s",
	role, resolveReason, tostring(game.PrivateServerId ~= ""), tostring(game.PrivateServerOwnerId),
	tostring(if joinData then joinData.SourcePlaceId else nil),
	tostring(if joinData then joinData.SourceGameId else nil),
	tostring(if payload then payload.matchId else nil), tostring(if payload then payload.trackId else nil),
	tostring(game.JobId)))
require(script:WaitForChild('EconomyService')).start()
RaceLaunchService.start()

local presenceJobKey = KDMServerPresence.resolveJobKey(game.JobId, RunService:IsStudio(),
	function() return HttpService:GenerateGUID(false) end)
local presence = KDMServerPresence.new(MemoryStoreService:GetSortedMap(KDMServerPresence.MAP_NAME),
	presenceJobKey, role, if payload then payload.trackId else nil)
local presenceRemote = Instance.new("RemoteEvent")
presenceRemote.Name = "KDMPopulationStatus"
presenceRemote.Parent = ReplicatedStorage
task.spawn(function()
	while true do
		local published, publishError = pcall(function() presence:publish(Players:GetPlayers()) end)
		if not published then warn("[KDMPresence] publish failed: " .. tostring(publishError)) end
		if role == "HUB" then
			local snapshot = if published then presence:aggregate() else { stale = true }
			presenceRemote:FireAllClients(snapshot)
		end
		task.wait(KDMServerPresence.HEARTBEAT_SECONDS)
	end
end)
Players.PlayerRemoving:Connect(function()
	task.defer(function()
		if #Players:GetPlayers() <= 1 then
			local ok, err = pcall(function() presence:remove() end)
			if not ok then warn("[KDMPresence] remove failed: " .. tostring(err)) end
		end
	end)
end)
game:BindToClose(function() pcall(function() presence:remove() end) end)

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
		local roomCoordinator = if payload.roomId then RaceRoomCoordinator.start(payload) else nil
		assert(RaceController.start({ trackId = payload.trackId,
			preformedMatch = false,
			persistentRoom = roomCoordinator ~= nil,
			onRoomPhase = if roomCoordinator then roomCoordinator.onRoomPhase else nil,
			onRoundStart = if roomCoordinator then roomCoordinator.onRoundStart else nil,
			onRoundReady = if roomCoordinator then roomCoordinator.onRoundReady else nil,
			onRoomLeave = if roomCoordinator then roomCoordinator.onRoomLeave else nil,
			getRoomHostUserId = if roomCoordinator then roomCoordinator.getRoomHostUserId else nil,
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
	local botTest=RunService:IsStudio() and Workspace:GetAttribute("KDMEnableRaceBot")==true
	PrototypeWorld.start(if botTest then {trackId="Track01Race"} else nil)
	RaceItemController.start()
	RaceController.start(if botTest then {trackId="Track01Race"} else nil)
	MatchRoomService.start()
	CompactHubBuilder.build(Workspace, Workspace.Prototype.PlayerSpawn)
	GarageController.start()
	if game.PrivateServerId == "" and not botTest and CompactHubBuilder.buildFrontDriveZone then
		local drive = require(script:WaitForChild("LobbyTestDriveService"))
		drive.configureCollision()
		local hub = Workspace:FindFirstChild("KDMHub")
		local ground = Workspace:FindFirstChild("Baseplate") or Workspace.Prototype:FindFirstChild("Ground")
		local zone = CompactHubBuilder.buildFrontDriveZone(hub, ground)
		drive.start(zone, MatchRoomService.canTestDrive)
	end
	PlayerPreferences.start()
	if botTest then require(script:WaitForChild("RaceBotController")).start() end
end

print("RobloxKart SERVER sync OK")
