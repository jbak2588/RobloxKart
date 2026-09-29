local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackCatalog = require(Shared:WaitForChild("TrackCatalog"))
local DriverCatalog = require(Shared:WaitForChild("DriverCatalog"))
local KartCatalog = require(Shared:WaitForChild("KartCatalog"))
local Registry = require(script.Parent:WaitForChild("MatchRoomRegistry"))
local RaceLaunchPayload = require(script.Parent:WaitForChild("RaceLaunchPayload"))
local RaceLaunchService = require(script.Parent:WaitForChild("RaceLaunchService"))

local MatchRoomService = {}
local TRACK_ID = "Track01Race"
local registry = Registry.new(TRACK_ID, TrackCatalog.Entries[TRACK_ID].MaxPlayers)
local browsing = {}
local selections = {}
local invitations = {}
local remote
local started = false

local function eligible(player)
	return player and player.Parent == Players and player:GetAttribute("RaceState") == "GARAGE"
		and player:GetAttribute("KDMRoutePending") ~= "RACE_LAUNCH"
end

local function validSelection(driverId, kartId)
	return type(driverId) == "string" and type(kartId) == "string"
		and DriverCatalog.Entries[driverId] ~= nil and KartCatalog.Entries[kartId] ~= nil
end

local function choose(player, driverId, kartId)
	if not validSelection(driverId, kartId) then return false end
	selections[player.UserId] = { driverId = driverId, kartId = kartId }
	return true
end

local function snapshotFor(player)
	local room = registry:roomFor(player.UserId)
	local visibleRooms = registry:snapshot()
	for _, visibleRoom in visibleRooms do
		local host = Players:GetPlayerByUserId(visibleRoom.hostUserId)
		visibleRoom.hostName = if host then host.DisplayName else tostring(visibleRoom.hostUserId)
	end
	local ownRoom
	if room then
		local host = Players:GetPlayerByUserId(room.hostUserId)
		ownRoom = { id = room.id, state = room.state, hostUserId = room.hostUserId,
			hostName = if host then host.DisplayName else tostring(room.hostUserId),
			maxPlayers = registry.maxPlayers, members = {}, available = {} }
		for _, member in room.members do
			local memberPlayer = Players:GetPlayerByUserId(member.userId)
			table.insert(ownRoom.members, { userId = member.userId,
				name = if memberPlayer then memberPlayer.DisplayName else tostring(member.userId) })
		end
		if room.hostUserId == player.UserId and room.state == "WAITING" then
			for _, other in Players:GetPlayers() do
				if other ~= player and eligible(other) and not registry:roomFor(other.UserId) then
					table.insert(ownRoom.available, { userId = other.UserId, name = other.DisplayName })
				end
			end
		end
	end
	return { visible = browsing[player.UserId] == true or ownRoom ~= nil,
		rooms = visibleRooms, room = ownRoom }
end

local function broadcast()
	for _, player in Players:GetPlayers() do
		remote:FireClient(player, "Snapshot", snapshotFor(player))
	end
end

local function errorTo(player, message)
	remote:FireClient(player, "Error", message)
end

function MatchRoomService.openBrowser(player, driverId, kartId)
	if not eligible(player) or not choose(player, driverId, kartId) then return false end
	browsing[player.UserId] = true
	remote:FireClient(player, "Snapshot", snapshotFor(player))
	return true
end

local function leave(player)
	local room = registry:roomFor(player.UserId)
	if not room or room.state ~= "WAITING" then return end
	registry:leave(player.UserId)
	browsing[player.UserId] = true
	broadcast()
end

local function startRoom(player)
	local room = registry:roomFor(player.UserId)
	if not room or room.hostUserId ~= player.UserId or room.state ~= "WAITING" then return end
	local players = {}
	for _, member in room.members do
		local participant = Players:GetPlayerByUserId(member.userId)
		if not eligible(participant) then
			registry:leave(member.userId)
			broadcast()
			errorTo(player, "RACER LEFT - PLEASE TRY AGAIN")
			return
		end
		table.insert(players, participant)
	end
	local payload = RaceLaunchPayload.buildMatch(HttpService:GenerateGUID(false), room.id,
		room.members, TRACK_ID)
	if not payload then errorTo(player, "ROOM UNAVAILABLE"); return end
	registry:launch(room.id, player.UserId)
	broadcast()
	local requestInFlight = true
	local failedDuringRequest = {}
	local function memberFailed(failedPlayer)
		if requestInFlight then failedDuringRequest[failedPlayer] = true; return end
		if registry:roomFor(failedPlayer.UserId) == room then
			registry:leave(failedPlayer.UserId)
			browsing[failedPlayer.UserId] = true
			broadcast()
		end
	end
	local ok = RaceLaunchService.launchMatch(players, payload, memberFailed)
	requestInFlight = false
	if not ok then
		if registry.rooms[room.id] then room.state = "WAITING" end
		for _, participant in players do
			if participant.Parent == Players then errorTo(participant, "RACE SERVER UNAVAILABLE - PLEASE TRY AGAIN") end
		end
		broadcast()
	else
		for failedPlayer in failedDuringRequest do memberFailed(failedPlayer) end
	end
end

function MatchRoomService.start()
	if started then return end
	started = true
	remote = Instance.new("RemoteEvent")
	remote.Name = "MatchRoomControl"
	remote.Parent = ReplicatedStorage
	remote.OnServerEvent:Connect(function(player, action, first, second)
		if action == "Browse" then
			MatchRoomService.openBrowser(player, first, second)
		elseif action == "Back" then
			if not registry:roomFor(player.UserId) then browsing[player.UserId] = nil; broadcast() end
		elseif action == "Create" then
			if not eligible(player) or not selections[player.UserId] then return end
			local selected = selections[player.UserId]
			local room, reason = registry:create(player.UserId, selected.driverId, selected.kartId)
			if not room then errorTo(player, reason); return end
			broadcast()
		elseif action == "Join" and type(first) == "string" then
			if not eligible(player) or not selections[player.UserId] then return end
			local selected = selections[player.UserId]
			local room, reason = registry:join(first, player.UserId, selected.driverId, selected.kartId)
			if not room then errorTo(player, reason); return end
			invitations[player.UserId] = nil
			broadcast()
			if #room.members == registry.maxPlayers then startRoom(Players:GetPlayerByUserId(room.hostUserId)) end
		elseif action == "Leave" then
			leave(player)
		elseif action == "Start" then
			startRoom(player)
		elseif action == "Invite" and type(first) == "number" then
			local room = registry:roomFor(player.UserId)
			local target = Players:GetPlayerByUserId(first)
			if not room or room.hostUserId ~= player.UserId or room.state ~= "WAITING"
				or #room.members >= registry.maxPlayers or not eligible(target)
				or registry:roomFor(first) then return end
		invitations[first] = { roomId = room.id, hostUserId = player.UserId, sentAt = os.clock() }
		remote:FireClient(target, "Invite", { roomId = room.id, hostUserId = player.UserId,
			hostName = player.DisplayName, trackId = TRACK_ID, count = #room.members,
			maxPlayers = registry.maxPlayers })
		elseif action == "AcceptInvite" then
			local invitation = invitations[player.UserId]
			invitations[player.UserId] = nil
			if not invitation or os.clock() - invitation.sentAt > 30 then errorTo(player, "INVITE EXPIRED"); return end
			if not choose(player, first, second) then errorTo(player, "SELECT A DRIVER AND KART FIRST"); return end
			local room = registry.rooms[invitation.roomId]
			if not room or room.state ~= "WAITING" or room.hostUserId ~= invitation.hostUserId
				or not eligible(player) then errorTo(player, "INVITE EXPIRED"); return end
			local selected = selections[player.UserId]
			local joined, reason = registry:join(room.id, player.UserId, selected.driverId, selected.kartId)
			if not joined then errorTo(player, reason); return end
			browsing[player.UserId] = true
			broadcast()
			if #room.members == registry.maxPlayers then startRoom(Players:GetPlayerByUserId(room.hostUserId)) end
		elseif action == "DeclineInvite" then
			invitations[player.UserId] = nil
		end
	end)
	local function watchPlayer(player)
		player:GetAttributeChangedSignal("RaceState"):Connect(broadcast)
	end
	for _, player in Players:GetPlayers() do watchPlayer(player) end
	Players.PlayerAdded:Connect(function(player)
		watchPlayer(player)
		broadcast()
	end)
	Players.PlayerRemoving:Connect(function(player)
		browsing[player.UserId] = nil
		selections[player.UserId] = nil
		invitations[player.UserId] = nil
		registry:leave(player.UserId)
		broadcast()
	end)
end

return MatchRoomService
