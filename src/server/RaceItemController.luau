local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local KartConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartConfig"))
local Catalog = require(ReplicatedStorage.Shared:WaitForChild("RaceItemCatalog"))
local PrototypeWorld = require(script.Parent:WaitForChild("PrototypeWorld"))
local RaceItemSlot = require(script.Parent:WaitForChild("RaceItemSlot"))

local RaceItemController = {}
local started = false
local slots = {}
local connections = {}
local lastUse = {}

local function publish(player)
	local slot = slots[player]
	player:SetAttribute("RaceItemId", if slot then slot.id else "")
	player:SetAttribute("RaceItemReady", slot ~= nil and slot.id ~= "")
end

local function clear(player)
	if slots[player] then slots[player]:clear() end
	publish(player)
end

function RaceItemController.grantRaceItem(player: Player, id: string): boolean
	local slot = slots[player]
	if not slot or player:GetAttribute("RaceState") ~= "RACING" or not Catalog[id] then return false end
	local accepted = slot:grant(id)
	if accepted then publish(player) end
	return accepted
end

function RaceItemController.start()
	if started then return end
	started = true
	local remote = ReplicatedStorage:FindFirstChild("RaceItemControl")
	if remote then
		assert(remote:IsA("RemoteEvent"), "RaceItemControl must be a RemoteEvent")
	else
		remote = Instance.new("RemoteEvent")
		remote.Name = "RaceItemControl"
		remote.Parent = ReplicatedStorage
	end
	local kart = Workspace:WaitForChild("Prototype"):WaitForChild("Kart")
	local function bind(player)
		if slots[player] then return end
		slots[player] = RaceItemSlot.new()
		publish(player)
		local previousState = player:GetAttribute("RaceState")
		connections[player] = {
			player:GetAttributeChangedSignal("RaceState"):Connect(function()
				local state = player:GetAttribute("RaceState")
				if state == previousState then return end
				previousState = state
				clear(player)
				lastUse[player] = nil
				-- Isolated development grant: never runs on a published server.
				if state == "RACING" and RunService:IsStudio() and KartConfig.DEBUG_RACE_ITEMS then
					RaceItemController.grantRaceItem(player, "Nitro")
				end
			end),
			player.CharacterRemoving:Connect(function() clear(player) end),
		}
	end
	Players.PlayerAdded:Connect(bind)
	Players.PlayerRemoving:Connect(function(player)
		for _, connection in connections[player] or {} do connection:Disconnect() end
		connections[player], slots[player], lastUse[player] = nil, nil, nil
	end)
	for _, player in Players:GetPlayers() do bind(player) end
	kart:GetAttributeChangedSignal("RaceResetSerial"):Connect(function()
		for player in slots do clear(player) end
	end)
	remote.OnServerEvent:Connect(function(player, action, ...)
		local slot = slots[player]
		if not slot or action ~= "Use" or select("#", ...) ~= 0 then return end
		local now = time()
		if lastUse[player] and now - lastUse[player] < 0.15 then return end
		lastUse[player] = now
		if player:GetAttribute("RaceState") ~= "RACING" then return end
		local accepted = slot:use(action, 0, function() return PrototypeWorld.activateNitro(player) end)
		if accepted then publish(player) end
	end)
end

return RaceItemController
