local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DriverCatalog = require(Shared:WaitForChild("DriverCatalog"))
local KartCatalog = require(Shared:WaitForChild("KartCatalog"))
local TrackCatalog = require(Shared:WaitForChild("TrackCatalog"))
local RaceConfig = require(Shared:WaitForChild("RaceConfig"))
local DriverAppearance = require(Shared:WaitForChild("DriverAppearance"))
local KartVisualFactory = require(Shared:WaitForChild("KartVisualFactory"))
local TrackBuilder = require(script.Parent:WaitForChild("TrackBuilder"))
local PrototypeWorld = require(script.Parent:WaitForChild("PrototypeWorld"))
local RaceSession = require(script.Parent:WaitForChild("RaceSession"))
local requireModule = require :: (ModuleScript) -> any
local RaceMode = requireModule(Shared:WaitForChild("RaceMode") :: ModuleScript)

local GarageController = {}
local REMOTE_NAME = "GarageControl"
local started = false

local function stageCharacter(player: Player, spawnLocation: SpawnLocation)
	local character = player.Character
	if not character or player:GetAttribute("RaceState") ~= "GARAGE" then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	humanoid.Sit = false
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	for _ = 1, 10 do
		if humanoid.SeatPart == nil then
			break
		end
		task.wait(0.1)
	end
	if player.Character ~= character or player:GetAttribute("RaceState") ~= "GARAGE" then
		return
	end
	if humanoid.SeatPart ~= nil then
		warn("[Garage] Driver could not leave seat")
		return
	end
	root.Anchored = true
	character:PivotTo(spawnLocation.CFrame * CFrame.new(0, 3, 0))
end

function GarageController.start()
	if started then
		return
	end
	started = true

	local prototype = Workspace:WaitForChild("Prototype")
	local spawnLocation = prototype:WaitForChild("PlayerSpawn") :: SpawnLocation
	prototype:WaitForChild("TestTrack")
	local ground = Workspace:FindFirstChild("Baseplate") or prototype:FindFirstChild("Ground")
	local groundTop = if ground and ground:IsA("BasePart") then ground.Position.Y + ground.Size.Y * 0.5 else 0

	local remote = Instance.new("RemoteEvent")
	remote.Name = REMOTE_NAME
	remote.Parent = ReplicatedStorage
	local readyPending: { [Player]: boolean } = {}
	local reservedSlots: { [Player]: number } = {}
	local readyOrder = 0

	local function releaseSlot(player: Player)
		reservedSlots[player] = nil
		player:SetAttribute("ReadyOrder", 0)
		player:SetAttribute("GridSlot", 0)
		if next(reservedSlots) == nil then
			readyOrder = 0
		end
	end

	local function nextGridSlot(gridSlots: { CFrame }, maxSlots: number): number?
		for slotIndex = 1, math.min(#gridSlots, maxSlots) do
			local occupied = false
			for _, reservedIndex in reservedSlots do
				if reservedIndex == slotIndex then
					occupied = true
					break
				end
			end
			if not occupied then
				return slotIndex
			end
		end
		return nil
	end

	local function bindPlayer(player: Player)
		player:SetAttribute("RaceMode", RaceMode.RACE)
		player:SetAttribute("SelectedDriverId", DriverCatalog.DefaultId)
		player:SetAttribute("SelectedKartId", KartCatalog.DefaultId)
		player:SetAttribute("SelectedTrackId", TrackCatalog.DefaultId)
		player:SetAttribute("RaceEntryError", "")
		player:SetAttribute("ReadyOrder", 0)
		player:SetAttribute("GridSlot", 0)
		player:GetAttributeChangedSignal("RaceState"):Connect(function()
			if player:GetAttribute("RaceState") == "GARAGE" then
				releaseSlot(player)
				task.spawn(stageCharacter, player, spawnLocation)
			end
		end)
		player.CharacterAdded:Connect(function()
			task.delay(0.25, function()
				stageCharacter(player, spawnLocation)
			end)
		end)
		if player.Character then
			task.spawn(stageCharacter, player, spawnLocation)
		end
	end

	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player)
		readyPending[player] = nil
		releaseSlot(player)
	end)

	remote.OnServerEvent:Connect(function(player: Player, action: unknown, driverId: unknown, kartId: unknown, trackId: unknown)
		if action ~= "Ready" or readyPending[player] or player:GetAttribute("RaceState") ~= "GARAGE" then
			return
		end
		if type(driverId) ~= "string" or type(kartId) ~= "string" or type(trackId) ~= "string" then
			return
		end
		local mode = RaceMode.resolve(trackId)
		local driver = DriverCatalog.Entries[driverId]
		local kartSelection = KartCatalog.Entries[kartId]
		local track = TrackCatalog.Entries[trackId]
		if not driver or not kartSelection or not track or track.ModelName ~= "TestTrack" then
			return
		end
		local session = RaceSession.active()
		if session and session:count() > 0 then
			if session:count() >= session.maxPlayers then
				player:SetAttribute("RaceEntryError", "Race full")
				return
			end
			if session.phase ~= "WAITING" or trackId ~= "Track01Race" or session.trackId ~= trackId then
				player:SetAttribute("RaceEntryError", if session.phase == "COUNTDOWN" or session.phase == "RACING" then "Race in progress" else "Racer not ready")
				return
			end
		end
		local slotIndex = nextGridSlot(track.GridSlots,
			if trackId == "Track01Race" then RaceConfig.PUBLIC_RACE_MAX_PLAYERS else 1)
		if not slotIndex then
			player:SetAttribute("RaceEntryError", "Grid full")
			return
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
			player:SetAttribute("RaceEntryError", "Driver not ready")
			return
		end
		local gridCFrame = CFrame.new(0, groundTop + 1.75, 0) * track.GridSlots[slotIndex]
		readyPending[player] = true
		reservedSlots[player] = slotIndex
		local built, buildError = pcall(TrackBuilder.build, prototype, track, groundTop)
		if not built then
			readyPending[player] = nil
			releaseSlot(player)
			player:SetAttribute("RaceEntryError", "Track unavailable")
			warn("[Garage] Track build failed: " .. tostring(buildError))
			return
		end
		local context = PrototypeWorld.acquireKartContext(player, gridCFrame)
		if not context then
			readyPending[player] = nil
			releaseSlot(player)
			player:SetAttribute("RaceEntryError", "Kart unavailable")
			return
		end
		local kart, seat = context.kart, context.seat
		if seat.Occupant then
			readyPending[player] = nil
			releaseSlot(player)
			player:SetAttribute("RaceEntryError", "Kart in use")
			return
		end

		player:SetAttribute("RaceEntryError", "")
		player:SetAttribute("SelectedDriverId", driverId)
		player:SetAttribute("SelectedKartId", kartId)
		player:SetAttribute("SelectedTrackId", trackId)
		player:SetAttribute("RaceMode", mode)
		readyOrder += 1
		player:SetAttribute("ReadyOrder", readyOrder)
		player:SetAttribute("GridSlot", slotIndex)
		player:SetAttribute("RaceState", "PRE_RACE")
		DriverAppearance.applyToCharacter(character, driver)
		local visual = kart:FindFirstChild("Visual")
		if visual and visual:IsA("Model") then
			KartVisualFactory.applyColors(visual, kartSelection)
		end
		context:setSpawnCFrame(gridCFrame)
		kart:PivotTo(gridCFrame)
		root.Anchored = false
		character:PivotTo(seat.CFrame * CFrame.new(0, 2.5, 0))
		seat:Sit(humanoid)
		print(string.format("[Garage] ready driver=%s kart=%s track=%s order=%d slot=%d", driverId, kartId, trackId, readyOrder, slotIndex))
		task.delay(1, function()
			readyPending[player] = nil
			if not player.Parent then
				return
			end
			if seat.Occupant == humanoid then
				print(string.format("[Garage] driver seated at grid slot=%d", slotIndex))
			elseif player:GetAttribute("RaceState") == "PRE_RACE" then
				player:SetAttribute("RaceEntryError", "Seat failed; try Ready again")
				player:SetAttribute("RaceState", "GARAGE")
				PrototypeWorld.releaseKartContext(player)
			end
		end)
	end)

	print("[RobloxKart] Garage controller ready")
end

return GarageController
