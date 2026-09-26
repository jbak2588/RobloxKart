local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("RaceItemConfig"))
local PrototypeWorld = require(script.Parent:WaitForChild("PrototypeWorld"))
local RaceLoadout = require(script.Parent:WaitForChild("RaceLoadout"))
local Geometry = require(script.Parent:WaitForChild("RaceItemGeometry"))
local Visuals = require(script.Parent:WaitForChild("RaceItemVisuals"))

local RaceItemController = {}
local started = false
local loadouts, connections, lastUse = {}, {}, {}
local shields, immunity, previousPositions = {}, {}, {}
local hazards = {}
local prototype, hazardFolder

local function publish(player)
	local loadout = loadouts[player]
	for _, id in { "Nitro", "Slick", "Shield", "Smoke" } do
		player:SetAttribute("RaceCharge" .. id, if loadout then loadout.counts[id] else 0)
	end
	player:SetAttribute("SelectedRaceItemId", if loadout then loadout.selected else "")
end
local function removeShield(player)
	local state = shields[player]
	if state then
		state.visual:Destroy()
		state.kart:SetAttribute("KartShieldActive", false)
		shields[player] = nil
	end
end
local function removeHazard(index)
	hazards[index].model:Destroy()
	table.remove(hazards, index)
end
local function clearPlayer(player)
	if loadouts[player] then loadouts[player]:clear() end
	removeShield(player)
	local state = immunity[player]
	if state then state.kart:SetAttribute("RaceItemHitImmunity", false) end
	immunity[player], previousPositions[player], lastUse[player] = nil, nil, nil
	publish(player)
end
local function clearSession()
	for player in loadouts do clearPlayer(player) end
	for index = #hazards, 1, -1 do removeHazard(index) end
end

-- Future player-specific reward gate calls this once; no client grant action.
function RaceItemController.grantBonusNitro(player: Player): boolean
	local loadout = loadouts[player]
	if not loadout or player:GetAttribute("RaceState") ~= "RACING" then return false end
	local accepted = loadout:grantBonusNitro()
	if accepted then publish(player) end
	return accepted
end

-- One offensive-item resolution path; source identity comes only from server hazards.
function RaceItemController.tryApplyOffensiveItem(targetPlayer: Player, sourcePlayer: Player, itemId: string): (boolean, string)
	if itemId ~= "Slick" then return false, "unsupported_item" end
	local kart = PrototypeWorld.getRaceKart(targetPlayer)
	if not kart or kart:GetAttribute("KartOffTrack") == true then return false, "invalid_target" end
	local now = time()
	local protected = immunity[targetPlayer]
	if protected and now < protected.untilTime then return false, "immune" end
	local shield = shields[targetPlayer]
	if shield and now >= shield.untilTime then removeShield(targetPlayer); shield = nil end
	if shield then
		removeShield(targetPlayer)
		local serial = targetPlayer:GetAttribute("RaceItemBlockedSerial") or 0
		targetPlayer:SetAttribute("RaceItemBlockedSerial", serial + 1)
		return true, "blocked"
	end
	if not PrototypeWorld.applySlickHit(targetPlayer) then return false, "effect_rejected" end
	immunity[targetPlayer] = { untilTime = now + Config.RACE_ITEM_HIT_IMMUNITY, kart = kart }
	kart:SetAttribute("RaceItemHitImmunity", true)
	return true, "hit"
end

local function activate(player, id)
	if id == "Nitro" then return PrototypeWorld.activateNitro(player) end
	local kart, chassis = PrototypeWorld.getRaceKart(player)
	if not kart or kart:GetAttribute("KartSlickActive") == true then return false, "invalid_driver" end
	if id == "Shield" then
		local old = shields[player]
		if old and time() < old.untilTime then return false, "shield_active" end
		removeShield(player)
		shields[player] = { untilTime = time() + Config.SHIELD_DURATION, kart = kart, visual = Visuals.shield(kart, chassis) }
		kart:SetAttribute("KartShieldActive", true)
		return true
	elseif id == "Slick" then
		if kart:GetAttribute("KartOffTrack") == true then return false, "off_track" end
		local frame = Geometry.dropFrame(prototype, chassis, Config.SLICK_DROP_DISTANCE)
		if not frame then return false, "no_road_behind" end
		if #hazards >= Config.SLICK_MAX_HAZARDS then return false, "hazard_limit" end
		local model, trigger, deploy = Visuals.slick(hazardFolder, frame, Config, chassis.CFrame)
		table.insert(hazards, { model=model, trigger=trigger, deploy=deploy, owner=player, born=time() })
		player:SetAttribute("SlickDeployFrame", frame)
		player:SetAttribute("SlickEjectPosition", (chassis.CFrame * CFrame.new(0, 5, 3)).Position)
		player:SetAttribute("SlickDeployedSerial", (player:GetAttribute("SlickDeployedSerial") or 0) + 1)
		return true
	end
	return false, "unsupported_item"
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
	prototype = Workspace:WaitForChild("Prototype")
	local kart = prototype:WaitForChild("Kart")
	hazardFolder = Instance.new("Folder")
	hazardFolder.Name = "RaceItemHazards"
	hazardFolder.Parent = prototype
	local function bind(player)
		if loadouts[player] then return end
		loadouts[player] = RaceLoadout.new()
		publish(player)
		player:SetAttribute("RaceItemBlockedSerial", 0)
		local previousState = player:GetAttribute("RaceState")
		connections[player] = {
			player:GetAttributeChangedSignal("RaceState"):Connect(function()
				local state = player:GetAttribute("RaceState")
				if state == previousState then return end
				local oldState = previousState
				previousState = state
				if state == "COUNTDOWN" then
					clearSession()
					loadouts[player]:prepare()
					publish(player)
				elseif state ~= "RACING" or oldState ~= "COUNTDOWN" then
					clearSession()
				end
			end),
			player.CharacterRemoving:Connect(clearSession),
		}
	end
	Players.PlayerAdded:Connect(bind)
	Players.PlayerRemoving:Connect(function(player)
		clearSession()
		for _, connection in connections[player] or {} do connection:Disconnect() end
		connections[player], loadouts[player] = nil, nil
	end)
	for _, player in Players:GetPlayers() do bind(player) end
	kart:GetAttributeChangedSignal("RaceResetSerial"):Connect(clearSession)
	kart:WaitForChild("Seat"):GetPropertyChangedSignal("Occupant"):Connect(function()
		-- Grid seating happens during COUNTDOWN; it must not erase prepared charges.
		for player in loadouts do
			if player:GetAttribute("RaceState") ~= "COUNTDOWN" then clearSession(); break end
		end
	end)
	kart.Destroying:Connect(clearSession)
	remote.OnServerEvent:Connect(function(player, action, ...)
		local loadout = loadouts[player]
		if not loadout then return end
		local state = player:GetAttribute("RaceState")
		if action == "Select" then
			if select("#", ...) ~= 1 or (state ~= "COUNTDOWN" and state ~= "RACING") then return end
			if loadout:select(...) then publish(player) end
			return
		end
		if action ~= "Use" or select("#", ...) ~= 0 or state ~= "RACING" then return end
		local now = time()
		if lastUse[player] and now-lastUse[player] < 0.15 then return end
		lastUse[player] = now
		local accepted = loadout:use(action, 0, function(id) return activate(player, id) end)
		if accepted then publish(player) end
	end)
	-- One loop for every hazard's lifetime/contact and every defense's expiry.
	RunService.Heartbeat:Connect(function()
		local now = time()
		for player, shield in shields do
			if now >= shield.untilTime or not PrototypeWorld.getRaceKart(player) then removeShield(player) end
		end
		for player, state in immunity do
			if now >= state.untilTime then state.kart:SetAttribute("RaceItemHitImmunity", false); immunity[player] = nil end
		end
		local targets = {}
		for player in loadouts do
			local activeKart, chassis = PrototypeWorld.getRaceKart(player)
			if activeKart then
				table.insert(targets, { player=player, chassis=chassis, previous=previousPositions[player] or chassis.Position })
				previousPositions[player] = chassis.Position
			else previousPositions[player] = nil end
		end
		for index = #hazards, 1, -1 do
			local hazard = hazards[index]
			local remove = now-hazard.born >= Config.SLICK_LIFETIME or not hazard.model.Parent
			if not remove then
				if hazard.deploy and Visuals.updateSlick(hazard.deploy, now-hazard.born) then hazard.deploy = nil end
				for _, target in targets do
					if (target.player ~= hazard.owner or now-hazard.born >= Config.SLICK_OWNER_GRACE)
						and Geometry.crosses(hazard.trigger.CFrame, hazard.trigger.Size, target.previous, target.chassis) then
						local accepted = RaceItemController.tryApplyOffensiveItem(target.player, hazard.owner, "Slick")
						if accepted then remove = true; break end
					end
				end
			end
			if remove then removeHazard(index) end
		end
	end)
end

return RaceItemController
