local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("RaceItemConfig"))
local PrototypeWorld = require(script.Parent:WaitForChild("PrototypeWorld"))
local RaceSession = require(script.Parent:WaitForChild("RaceSession"))
local RaceLoadout = require(script.Parent:WaitForChild("RaceLoadout"))
local Geometry = require(script.Parent:WaitForChild("RaceItemGeometry"))
local Visuals = require(script.Parent:WaitForChild("RaceItemVisuals"))

local RaceItemController = {}
local started = false
local loadouts, connections, lastUse = {}, {}, {}
local driftStreaks, driftBonusAwarded = {}, {}
local kartConnections = {}
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
	driftStreaks[player] = 0
	player:SetAttribute("DriftStreakCount", 0)
	removeShield(player)
	local state = immunity[player]
	if state then state.kart:SetAttribute("RaceItemHitImmunity", false) end
	immunity[player], previousPositions[player], lastUse[player] = nil, nil, nil
	for index = #hazards, 1, -1 do
		if hazards[index].owner == player then removeHazard(index) end
	end
	publish(player)
end
local function clearHazardsForSession(session)
	for index = #hazards, 1, -1 do
		if hazards[index].session == session then removeHazard(index) end
	end
end
-- Reserved for an explicit shared-session reset; individual lifecycle events use clearPlayer.
local function clearSession(session)
	for player in session.participants do clearPlayer(player) end
	clearHazardsForSession(session)
end

-- Only server systems call this; RaceLoadout enforces the one-bonus limit.
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
	local sourceSession = RaceSession.forPlayer(sourcePlayer)
	local targetSession = RaceSession.forPlayer(targetPlayer)
	if not sourceSession or sourceSession ~= targetSession then return false, "cross_session" end
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
		table.insert(hazards, { model=model, trigger=trigger, deploy=deploy, owner=player,
			session=RaceSession.forPlayer(player), born=time() })
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
	hazardFolder = Instance.new("Folder")
	hazardFolder.Name = "RaceItemHazards"
	hazardFolder.Parent = prototype
	local function unbindKart(player)
		for _, connection in kartConnections[player] or {} do connection:Disconnect() end
		kartConnections[player] = nil
	end
	local function bindKart(player)
		unbindKart(player)
		local context = PrototypeWorld.getKartContext(player)
		if not context then return end
		local kart, seat = context.kart, context.seat
		kartConnections[player] = {
			kart:GetAttributeChangedSignal("RaceResetSerial"):Connect(function() clearPlayer(player) end),
			seat:GetPropertyChangedSignal("Occupant"):Connect(function()
				-- Grid seating during COUNTDOWN keeps the prepared loadout.
				if player:GetAttribute("RaceState") ~= "COUNTDOWN" then
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if not humanoid or seat.Occupant ~= humanoid then clearPlayer(player) end
				end
			end),
			kart.Destroying:Connect(function() clearPlayer(player); unbindKart(player) end),
		}
	end
	local function bind(player)
		if loadouts[player] then return end
		loadouts[player] = RaceLoadout.new()
		driftStreaks[player], driftBonusAwarded[player] = 0, false
		player:SetAttribute("DriftStreakCount", 0)
		player:SetAttribute("DriftBonusNitroAwarded", false)
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
					driftBonusAwarded[player] = false
					player:SetAttribute("DriftBonusNitroAwarded", false)
					clearPlayer(player)
					bindKart(player)
					loadouts[player]:prepare()
					publish(player)
				elseif state ~= "RACING" or oldState ~= "COUNTDOWN" then
					clearPlayer(player)
					if state == "GARAGE" then
						driftBonusAwarded[player] = false
						player:SetAttribute("DriftBonusNitroAwarded", false)
					end
				end
			end),
			player.CharacterRemoving:Connect(function() clearPlayer(player) end),
		}
	end
	Players.PlayerAdded:Connect(bind)
	Players.PlayerRemoving:Connect(function(player)
		clearPlayer(player)
		unbindKart(player)
		for _, connection in connections[player] or {} do connection:Disconnect() end
		connections[player], loadouts[player] = nil, nil
		driftStreaks[player], driftBonusAwarded[player] = nil, nil
	end)
	for _, player in Players:GetPlayers() do bind(player) end
	PrototypeWorld.onDriftOutcome(function(player, outcome)
		if not loadouts[player] then return end
		if outcome == "RESET" then
			driftStreaks[player] = 0
			player:SetAttribute("DriftStreakCount", 0)
			return
		end
		if outcome ~= "BOOST" or player:GetAttribute("RaceState") ~= "RACING" or driftBonusAwarded[player] then return end
		local streak = (driftStreaks[player] or 0) + 1
		if streak >= 4 then
			local accepted = RaceItemController.grantBonusNitro(player)
			driftBonusAwarded[player] = accepted or loadouts[player].bonusClaimed == true
			player:SetAttribute("DriftBonusNitroAwarded", driftBonusAwarded[player])
			streak = 0
		end
		driftStreaks[player] = streak
		player:SetAttribute("DriftStreakCount", streak)
	end)
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
					if hazard.session ~= nil and hazard.session == RaceSession.forPlayer(target.player)
						and (target.player ~= hazard.owner or now-hazard.born >= Config.SLICK_OWNER_GRACE)
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
