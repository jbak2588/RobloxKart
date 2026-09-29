local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackCatalog = require(Shared:WaitForChild("TrackCatalog"))
local DriverCatalog = require(Shared:WaitForChild("DriverCatalog"))
local KartCatalog = require(Shared:WaitForChild("KartCatalog"))
local DriverAppearance = require(Shared:WaitForChild("DriverAppearance"))
local KartVisualFactory = require(Shared:WaitForChild("KartVisualFactory"))
local RaceLaunchPayload = require(script.Parent:WaitForChild("RaceLaunchPayload"))
local RaceArrivalPlan = require(script.Parent:WaitForChild("RaceArrivalPlan"))
local RaceLaunchService = require(script.Parent:WaitForChild("RaceLaunchService"))
local PrototypeWorld = require(script.Parent:WaitForChild("PrototypeWorld"))

local RaceServerBootstrap = {}
local started = false
local activeMatchId = nil

function RaceServerBootstrap.plan(payload, userId)
	return RaceArrivalPlan.forPlayer(payload, userId)
end

function RaceServerBootstrap.start(payload)
	if started then return type(payload) == "table" and payload.matchId == activeMatchId end
	if not RaceLaunchPayload.validate(payload, true) then return false end
	started = true
	activeMatchId = payload.matchId
	local processed = {}
	local track = TrackCatalog.Entries[payload.trackId]
	local prototype = Workspace:WaitForChild("Prototype")
	local ground = Workspace:FindFirstChild("Baseplate") or prototype:FindFirstChild("Ground")
	local groundTop = if ground and ground:IsA("BasePart") then ground.Position.Y + ground.Size.Y * 0.5 else 0

	local function reject(player)
		player:SetAttribute("RaceEntryError", "RACE SERVER UNAVAILABLE - RETURNING TO HUB")
		if not RaceLaunchService.returnToHub(player, function()
			if player.Parent == Players then
				player:Kick("Race launch unavailable. Please rejoin Kart Drift Masters.")
			end
		end) then return end
	end

	local function arrive(player)
		if processed[player] then return end
		processed[player] = true
		local ok, joinData = pcall(function() return player:GetJoinData() end)
		local plan = if player.UserId == payload.participantUserIds[1]
			and ok and type(joinData) == "table" and joinData.SourcePlaceId == game.PlaceId
			and type(joinData.TeleportData) == "table"
			and joinData.TeleportData.matchId == payload.matchId
			then RaceServerBootstrap.plan(joinData.TeleportData, player.UserId) else nil
		local originalSelection = payload.selections[tostring(player.UserId)]
		if not plan or plan.trackId ~= payload.trackId
			or plan.driverId ~= originalSelection.driverId or plan.kartId ~= originalSelection.kartId then
			reject(player)
			return
		end
		print(string.format("[KDMRoute] arrival user=%d", player.UserId))
		local character = player.Character or player.CharacterAdded:Wait()
		if not player.Parent then return end
		local humanoid = character:WaitForChild("Humanoid", 10)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not humanoid or not root or humanoid.Health <= 0 then reject(player); return end
		local spawnCFrame = CFrame.new(0, groundTop + 1.75, 0) * track.GridSlots[1]
		local context = PrototypeWorld.acquireKartContext(player, spawnCFrame)
		if not context then reject(player); return end
		local seat, kart = context.seat, context.kart
		if seat.Occupant then reject(player); return end
		player:SetAttribute("SelectedDriverId", plan.driverId)
		player:SetAttribute("SelectedKartId", plan.kartId)
		player:SetAttribute("SelectedTrackId", plan.trackId)
		player:SetAttribute("RaceMaxPlayers", plan.maxPlayers)
		player:SetAttribute("RaceMode", plan.mode)
		player:SetAttribute("GridSlot", 1)
		player:SetAttribute("ReadyOrder", 1)
		player:SetAttribute("RaceEntryError", "")
		player:SetAttribute("RaceState", "PRE_RACE")
		DriverAppearance.applyToCharacter(character, DriverCatalog.Entries[plan.driverId])
		local visual = kart:FindFirstChild("Visual")
		if visual and visual:IsA("Model") then
			KartVisualFactory.applyColors(visual, KartCatalog.Entries[plan.kartId])
		end
		context:setSpawnCFrame(spawnCFrame)
		kart:PivotTo(spawnCFrame)
		root.Anchored = false
		character:PivotTo(seat.CFrame * CFrame.new(0, 2.5, 0))
		seat:Sit(humanoid)
		task.delay(1, function()
			if player.Parent and player:GetAttribute("RaceState") == "PRE_RACE"
				and seat.Occupant ~= humanoid then
				PrototypeWorld.releaseKartContext(player)
				reject(player)
			end
		end)
	end
	local function safeArrive(player)
		local ok, reason = pcall(arrive, player)
		if not ok then
			warn("[KDMRoute] arrival setup failed: " .. tostring(reason))
			reject(player)
		end
	end

	for _, player in Players:GetPlayers() do task.spawn(safeArrive, player) end
	Players.PlayerAdded:Connect(function(player) task.spawn(safeArrive, player) end)
	Players.PlayerRemoving:Connect(function(player) processed[player] = nil end)
	return true
end

return RaceServerBootstrap
