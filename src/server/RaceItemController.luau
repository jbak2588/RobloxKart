local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("RaceItemConfig"))
local KartConfig = require(Shared:WaitForChild("KartConfig"))
local Catalog = require(Shared:WaitForChild("RaceItemCatalog"))
local Slots = require(Shared:WaitForChild("RaceItemSlots"))
local PrototypeWorld = require(script.Parent:WaitForChild("PrototypeWorld"))
local RaceSession = require(script.Parent:WaitForChild("RaceSession"))
local RaceLoadout = require(script.Parent:WaitForChild("RaceLoadout"))
local Geometry = require(script.Parent:WaitForChild("RaceItemGeometry"))
local Visuals = require(script.Parent:WaitForChild("RaceItemVisuals"))
local HomingMissileService = require(script.Parent:WaitForChild("HomingMissileService"))
local ThunderStrikeService = require(script.Parent:WaitForChild("ThunderStrikeService"))
local SmokeHazardService = require(script.Parent:WaitForChild("SmokeHazardService"))
local TacticalLoadoutService = require(script.Parent:WaitForChild("TacticalLoadoutService"))

local RaceItemController = {}
local started = false
local loadouts, connections, lastUse = {}, {}, {}
local kartConnections = {}
local lapRefillProgress = {}
local lapRefillPolicy = table.freeze({
	Enabled = Config.LAP_REFILL_ENABLED,
	RefillTo = Config.LAP_REFILL_TO,
	Eligible = Config.LAP_REFILL_ELIGIBLE,
})
local shields, immunity, previousPositions = {}, {}, {}
local hazards = {}
local prototype, hazardFolder
local missiles
local smoke
local thunder
local tactical = TacticalLoadoutService.new(RaceSession.forPlayer)
local shieldPulses = {}
local function clearPulses(player)
	for i = #shieldPulses, 1, -1 do
		if shieldPulses[i].player == player then shieldPulses[i].visual:Destroy(); table.remove(shieldPulses, i) end
	end
end
local function pulseShield(player, kart)
	local _, chassis = PrototypeWorld.getRaceKart(player)
	if not chassis then return end
	if #shieldPulses >= 32 then shieldPulses[1].visual:Destroy(); table.remove(shieldPulses, 1) end
	table.insert(shieldPulses, {player=player, kart=kart, session=RaceSession.forPlayer(player), born=time(),
		visual=Visuals.shieldPulse(kart, chassis)})
end
local function combatFeedback(source, target, item, result)
	if source == target or not loadouts[source] or source:GetAttribute("RaceState") ~= "RACING" then return end
	source:SetAttribute("RaceCombatFeedbackTargetName", (if target:GetAttribute("IsBot")==true then target:GetAttribute("DisplayName") else target.DisplayName or target.Name))
	source:SetAttribute("RaceCombatFeedbackCode", string.upper(item) .. "_" .. string.upper(result))
	source:SetAttribute("RaceCombatFeedbackSerial", (source:GetAttribute("RaceCombatFeedbackSerial") or 0) + 1)
	if KartConfig.DEBUG_TELEMETRY then
		print(string.format("[CombatFeedback] source=%s target=%s code=%s serial=%d", source.Name, target.Name,
			source:GetAttribute("RaceCombatFeedbackCode"), source:GetAttribute("RaceCombatFeedbackSerial")))
	end
end

local function publish(player)
	local loadout = loadouts[player]
	player:SetAttribute("DriftBonusProgress", if loadout then loadout.bonusProgress else 0)
	player:SetAttribute("DriftBonusPending", loadout ~= nil and loadout.bonusPending)
	player:SetAttribute("DriftBonusAwardCount", if loadout then loadout.bonusAwardCount else 0)
	player:SetAttribute("DriftBonusNitroAwarded", loadout ~= nil and loadout.bonusEverAwarded)
	for id in Catalog do
		player:SetAttribute("RaceCharge" .. id, if loadout then loadout.counts[id] else 0)
	end
	for index = 1, Slots.RACE_ITEM_SLOT_COUNT do
		player:SetAttribute("RaceItemSlot" .. index, if loadout then loadout.slots[index] or "" else "")
	end
	player:SetAttribute("SelectedRaceItemId", if loadout then loadout.selected else "")
	local choice = tactical:get(player)
	for index=1,3 do player:SetAttribute("RaceTacticalItem"..index, choice[index+1]) end
end
-- RaceController alone advances this attribute after validated checkpoints/time.
function RaceItemController.voucherTarget(player,id)
	local session=RaceSession.forPlayer(player)
	local loadout=loadouts[player]
	local guid=player:GetAttribute('OfficialRoundGuid')
	local kart=PrototypeWorld.getRaceKart(player)
	if player:GetAttribute('IsBot')==true or player:GetAttribute('RaceState')~='RACING'
		or not session or not session:contains(player) or not loadout or not loadout:contains(id)
		or loadout.counts[id]~=0 or type(guid)~='string' or not kart
		or kart:GetAttribute('RaceControlsLocked')==true then return nil end
	if loadout.voucherApplied[guid..':'..id] then return nil end
	return guid
end
function RaceItemController.applyVoucher(player,id,guid)
	if RaceItemController.voucherTarget(player,id)~=guid then return false end
	local accepted=loadouts[player]:creditVoucher(id,guid)
	if accepted then publish(player) end
	return accepted
end
-- Keep a high-water mark even when no charge changed or same-round recovery clears effects.
local function refillCompletedLap(player)
	local progress = lapRefillProgress[player]
	local completed = player:GetAttribute("RaceCompletedLaps")
	local total = player:GetAttribute("RaceTotalLaps")
	local session = RaceSession.forPlayer(player)
	if not progress or player:GetAttribute("IsBot") == true or not session
		or player:GetAttribute("RaceState") ~= "RACING"
		or type(completed) ~= "number" or completed % 1 ~= 0 or completed <= progress.completed
		or type(total) ~= "number" or completed <= 0 then return end
	progress.completed = completed
	if completed >= total or not Config.LAP_REFILL_ENABLED then return end
	local ids, count = loadouts[player]:refillLapItems(lapRefillPolicy)
	if count == 0 then return end
	publish(player)
	player:SetAttribute("RaceItemRefillLap", completed)
	player:SetAttribute("RaceItemRefillCount", count)
	player:SetAttribute("RaceItemRefillItems", table.concat(ids, ","))
	player:SetAttribute("RaceItemRefillSerial", (player:GetAttribute("RaceItemRefillSerial") or 0) + 1)
end
local function removeShield(player)
	local state = shields[player]
	if state then
		state.visual:Destroy()
		state.kart:SetAttribute("KartShieldActive", false)
		shields[player] = nil
	end
end
local function removeHazard(index, reason)
	local hazard = hazards[index]
	if reason then
		print(string.format("[Slick] EXPIRE owner=%d session=%s age=%.2f reason=%s",
			hazard.owner.UserId, tostring(hazard.model:GetAttribute("RaceSessionId")), time()-hazard.born, reason))
	end
	hazard.model:Destroy()
	table.remove(hazards, index)
end
-- Same-round recovery clears effects/hazards without changing temporary inventory or bonus state.
local function clearTransientCombatState(player)
	clearPulses(player)
	player:SetAttribute("RaceCombatFeedbackCode", "")
	player:SetAttribute("RaceCombatFeedbackTargetName", "")
	if missiles then missiles:clearPlayer(player) end
	if thunder then thunder:clearPlayer(player) end
	player:SetAttribute("RaceThunderIncomingCount", 0)
	player:SetAttribute("RaceThunderHitCount", 0)
	player:SetAttribute("RaceThunderBlockedCount", 0)
	if smoke then smoke:clearPlayer(player) end
	player:SetAttribute("RaceMissileIncomingCount", 0)
	player:SetAttribute("RaceMissileTargetName", "")
	player:SetAttribute("RaceItemFeedbackCode", "")
	removeShield(player)
	local state = immunity[player]
	if state then state.kart:SetAttribute("RaceItemHitImmunity", false) end
	immunity[player], previousPositions[player], lastUse[player] = nil, nil, nil
	for index = #hazards, 1, -1 do
		if hazards[index].owner == player then removeHazard(index, "owner_cleanup") end
	end
end
local function clearPlayer(player)
	clearTransientCombatState(player)
	if loadouts[player] then loadouts[player]:clear() end
	publish(player)
end
local function clearHazardsForSession(session)
	for index = #hazards, 1, -1 do
		if hazards[index].session == session then removeHazard(index, "session_cleanup") end
	end
end
-- Reserved for an explicit shared-session reset; individual lifecycle events use clearPlayer.
local function clearSession(session)
	if missiles then missiles:clearSession(session) end
	if thunder then thunder:clearSession(session) end
	if smoke then smoke:clearSession(session) end
	for player in session.participants do clearPlayer(player) end
	clearHazardsForSession(session)
end

-- Only server systems call this; RaceLoadout settles only a completed pending cycle.
function RaceItemController.grantBonusNitro(player: Player): boolean
	local loadout = loadouts[player]
	if not loadout or player:GetAttribute("RaceState") ~= "RACING" then return false end
	local accepted = loadout:grantBonusNitro()
	if accepted then publish(player) end
	return accepted
end

-- One offensive-item resolution path; source identity comes only from server hazards/projectiles.
function RaceItemController.tryApplyOffensiveItem(targetPlayer: Player, sourcePlayer: Player, itemId: string): (boolean, string)
	if itemId ~= "Slick" and itemId ~= "Missile" and itemId ~= "Smoke" and itemId ~= "Thunder" then return false, "unsupported_item" end
	local sourceSession = RaceSession.forPlayer(sourcePlayer)
	local targetSession = RaceSession.forPlayer(targetPlayer)
	if not sourceSession or sourceSession ~= targetSession then return false, "cross_session" end
	if targetPlayer:GetAttribute("RaceState") ~= "RACING" then return false, "invalid_target" end
	if (itemId == "Missile" or itemId == "Thunder") and (targetPlayer == sourcePlayer or sourcePlayer:GetAttribute("RaceState") ~= "RACING") then
		return false, "invalid_source"
	end
	local kart = PrototypeWorld.getRaceKart(targetPlayer)
	if not kart or kart:GetAttribute("KartOffTrack") == true then return false, "invalid_target" end
	local now = time()
	local protected = immunity[targetPlayer]
	if protected and now < protected.untilTime then return false, "immune" end
	local shield = shields[targetPlayer]
	if shield and now >= shield.untilTime then removeShield(targetPlayer); shield = nil end
	if shield then
		pulseShield(targetPlayer, kart)
		removeShield(targetPlayer)
		local serial = targetPlayer:GetAttribute("RaceItemBlockedSerial") or 0
		targetPlayer:SetAttribute("RaceItemBlockedSerial", serial + 1)
		if itemId ~= "Thunder" then combatFeedback(sourcePlayer, targetPlayer, itemId, "blocked") end
		return true, "blocked"
	end
	local applied = if itemId == "Missile" then PrototypeWorld.applyMissileHit(targetPlayer)
		elseif itemId == "Thunder" then PrototypeWorld.applyThunderHit(targetPlayer)
		elseif itemId == "Smoke" then smoke:apply(targetPlayer, now)
		else PrototypeWorld.applySlickHit(targetPlayer)
	if not applied then return false, "effect_rejected" end
	immunity[targetPlayer] = { untilTime = now + Config.RACE_ITEM_HIT_IMMUNITY, kart = kart }
	kart:SetAttribute("RaceItemHitImmunity", true)
	if itemId ~= "Thunder" then combatFeedback(sourcePlayer, targetPlayer, itemId, "hit") end
	return true, "hit"
end

-- RacePosition is authored by RaceController. Never skip an invalid immediate rival.
function RaceItemController.missileTarget(player)
	local session = RaceSession.forPlayer(player)
	local position = player:GetAttribute("RacePosition")
	if not session or player:GetAttribute("RaceState") ~= "RACING" or not PrototypeWorld.getRaceKart(player)
		or type(position) ~= "number" or position <= 1 or position % 1 ~= 0 then return nil end
	for target in session.participants do
		if target ~= player and RaceSession.forPlayer(target) == session
			and target:GetAttribute("RaceState") == "RACING"
			and target:GetAttribute("RacePosition") == position - 1 and PrototypeWorld.getRaceKart(target) then
			return target
		end
	end
	return nil
end

-- Snapshot all valid ahead racers once. RacePosition is server-authored.
function RaceItemController.thunderTargets(player)
	local session = RaceSession.forPlayer(player)
	local position = player:GetAttribute("RacePosition")
	local targets = {}
	if not session or player:GetAttribute("RaceState") ~= "RACING" or not PrototypeWorld.getRaceKart(player)
		or type(position) ~= "number" or position < 1 or position % 1 ~= 0 then return targets end
	for target in session.participants do
		local ahead = target:GetAttribute("RacePosition")
		if target ~= player and RaceSession.forPlayer(target) == session and target:GetAttribute("RaceState") == "RACING"
			and type(ahead) == "number" and ahead >= 1 and ahead % 1 == 0 and ahead < position
			and PrototypeWorld.getRaceKart(target) then table.insert(targets, target) end
	end
	table.sort(targets, function(a,b) return a:GetAttribute("RacePosition") < b:GetAttribute("RacePosition") end)
	return targets
end

local function feedback(player, code)
	player:SetAttribute("RaceItemFeedbackCode", code)
	player:SetAttribute("RaceItemFeedbackSerial", (player:GetAttribute("RaceItemFeedbackSerial") or 0) + 1)
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
		pulseShield(player, kart)
		return true
	elseif id == "Missile" then
		local target = RaceItemController.missileTarget(player)
		if not target then feedback(player, "NO_TARGET_AHEAD"); return false, "no_target_ahead" end
		local accepted, reason = missiles:launch(player, target, RaceSession.forPlayer(player), time())
		if accepted then
			player:SetAttribute("RaceMissileTargetName", (if target:GetAttribute("IsBot")==true then target:GetAttribute("DisplayName") else target.DisplayName or target.Name))
			player:SetAttribute("RaceMissileLaunchSerial", (player:GetAttribute("RaceMissileLaunchSerial") or 0) + 1)
			feedback(player, "MISSILE_LOCKED")
		end
		return accepted, reason
	elseif id == "Thunder" then
		if kart:GetAttribute("KartOffTrack") == true then return false,"off_track" end
		local targets=RaceItemController.thunderTargets(player)
		if #targets == 0 then feedback(player,"NO_TARGET_AHEAD");return false,"no_target_ahead" end
		return thunder:launch(player,targets,RaceSession.forPlayer(player),time())
	elseif id == "Smoke" then
		return smoke:deploy(player, prototype, time())
	elseif id == "Slick" then
		if kart:GetAttribute("KartOffTrack") == true then return false, "off_track" end
		local frame = Geometry.dropFrame(prototype, chassis, Config.SLICK_DROP_DISTANCE)
		if not frame then return false, "no_road_behind" end
		if #hazards >= Config.SLICK_MAX_HAZARDS then return false, "hazard_limit" end
		local model, trigger, deploy = Visuals.slick(hazardFolder, frame, Config, chassis.CFrame)
		model:SetAttribute("SlickOwnerUserId", player.UserId)
		model:SetAttribute("RaceSessionId", player:GetAttribute("RaceSessionId"))
		table.insert(hazards, { model=model, trigger=trigger, deploy=deploy, owner=player,
			session=RaceSession.forPlayer(player), born=time(), blocked={} })
		print(string.format("[Slick] DEPLOY owner=%d session=%s size=%dx%d lifetime=%.1f position=%s",
			player.UserId, tostring(model:GetAttribute("RaceSessionId")), Config.SLICK_WIDTH,
			Config.SLICK_LENGTH, Config.SLICK_LIFETIME, tostring(frame.Position)))
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
	local missileFolder = Instance.new("Folder")
	missileFolder.Name = "RaceMissiles"
	missileFolder.Parent = prototype
	missiles = HomingMissileService.new(Config, { getKart = PrototypeWorld.getRaceKart,
		getSession = RaceSession.forPlayer, resolve = RaceItemController.tryApplyOffensiveItem,
		visuals = Visuals, parent = missileFolder })
	smoke = SmokeHazardService.new(Config, {getKart=PrototypeWorld.getRaceKart, getSession=RaceSession.forPlayer,
		resolve=RaceItemController.tryApplyOffensiveItem, geometry=Geometry, visuals=Visuals, parent=hazardFolder})
	thunder = ThunderStrikeService.new(Config,{getKart=PrototypeWorld.getRaceKart,getSession=RaceSession.forPlayer,
		resolve=RaceItemController.tryApplyOffensiveItem,visuals=Visuals,parent=missileFolder,
		result=function(owner,hits,blocks)
			owner:SetAttribute("RaceThunderHitCount",hits)
			owner:SetAttribute("RaceThunderBlockedCount",blocks)
			owner:SetAttribute("RaceThunderResultSerial",(owner:GetAttribute("RaceThunderResultSerial") or 0)+1)
		end})
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
			kart:GetAttributeChangedSignal("RaceControlsLocked"):Connect(function()
				if kart:GetAttribute("RaceControlsLocked") == true then missiles:clearPlayer(player); thunder:clearPlayer(player) end
			end),
			kart:GetAttributeChangedSignal("RaceResetSerial"):Connect(function()
				if player:GetAttribute("RaceState") == "RACING" then
					clearTransientCombatState(player)
					publish(player) -- No clear/prepare/refill: consumed charges and bonus state stay intact.
				else clearPlayer(player) end
			end),
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
		if player:GetAttribute("IsBot") == true then return end
		loadouts[player] = RaceLoadout.new()
		lapRefillProgress[player] = { completed = player:GetAttribute("RaceCompletedLaps") or 0 }
		publish(player)
		player:SetAttribute("RaceItemBlockedSerial", 0)
		player:SetAttribute("RaceMissileIncomingCount", 0)
		player:SetAttribute("RaceMissileLaunchSerial", 0)
		player:SetAttribute("RaceThunderIncomingCount",0)
		player:SetAttribute("RaceThunderResultSerial",0)
		player:SetAttribute("RaceThunderHitCount",0)
		player:SetAttribute("RaceThunderBlockedCount",0)
		player:SetAttribute("RaceMissileTargetName", "")
		player:SetAttribute("RaceItemFeedbackSerial", 0)
		player:SetAttribute("RaceItemFeedbackCode", "")
		local previousState = player:GetAttribute("RaceState")
		connections[player] = {
			player:GetAttributeChangedSignal("RaceCompletedLaps"):Connect(function() refillCompletedLap(player) end),
			player:GetAttributeChangedSignal("RaceSessionId"):Connect(function()
				lapRefillProgress[player] = { completed = player:GetAttribute("RaceCompletedLaps") or 0 }
				clearPlayer(player)
				if player:GetAttribute("RaceState") == "COUNTDOWN" then
					loadouts[player]:prepare(tactical:get(player))
					publish(player)
				end
			end),
			player:GetAttributeChangedSignal("RaceState"):Connect(function()
				local state = player:GetAttribute("RaceState")
				if state == previousState then return end
				local oldState = previousState
				previousState = state
				if state == "COUNTDOWN" then
					lapRefillProgress[player] = { completed = 0 }
					clearPlayer(player)
					bindKart(player)
					loadouts[player]:prepare(tactical:get(player))
					publish(player)
				elseif state == "RACING" and oldState == "COUNTDOWN" then
					-- Grid/seat reset events can clear the countdown loadout after prepare.
					-- No item can be used in COUNTDOWN, so refill at the authoritative start.
					local active = loadouts[player].slots
					loadouts[player]:prepare(if #active == Slots.RACE_ITEM_SLOT_COUNT then active else tactical:get(player), true)
					publish(player)
				elseif state ~= "RACING" or oldState ~= "COUNTDOWN" then
					clearPlayer(player)
					if state == "GARAGE" then
						tactical:clear(player)
						publish(player)
					elseif state == "PRE_RACE" then
						publish(player)
					end
				end
			end),
			player.CharacterRemoving:Connect(function() clearPlayer(player) end),
		}
	end
	Players.PlayerAdded:Connect(bind)
	Players.PlayerRemoving:Connect(function(player)
		clearPlayer(player)
		tactical:clear(player)
		unbindKart(player)
		for _, connection in connections[player] or {} do connection:Disconnect() end
		connections[player], loadouts[player] = nil, nil
		lapRefillProgress[player] = nil
	end)
	for _, player in Players:GetPlayers() do bind(player) end
	PrototypeWorld.onDriftOutcome(function(player, outcome)
		local loadout = loadouts[player]
		if not loadout or outcome ~= "BOOST" or player:GetAttribute("RaceState") ~= "RACING" then return end
		if loadout:recordBoost(Config.DRIFT_BONUS_REQUIRED_BOOSTS) then publish(player) end
	end)
	remote.OnServerEvent:Connect(function(player, action, ...)
		local loadout = loadouts[player]
		if not loadout then return end
		local state = player:GetAttribute("RaceState")
		if action == "SetTacticalLoadout" then
			local accepted, message = false, "ITEMS UNAVAILABLE"
			if select("#", ...) == 1 and Workspace:GetAttribute("KDMServerRole") == "RACE" then
				accepted, message = tactical:set(player, ..., time())
			end
			if accepted then publish(player) end
			remote:FireClient(player, "TacticalLoadoutResult", accepted, message)
			return
		end
		if action == "Select" then
			if select("#", ...) ~= 1 or (state ~= "COUNTDOWN" and state ~= "RACING") then return end
			if loadout:select(...) then publish(player) end
			return
		end
		if state ~= "RACING" then return end
		local id = ...
		if action == "UseItem" then
			if select("#", ...) ~= 1 or not loadout:contains(id) then return end
		elseif action ~= "Use" or select("#", ...) ~= 0 then return end
		local now = time()
		if lastUse[player] and now-lastUse[player] < 0.15 then return end
		lastUse[player] = now
		local accepted = if action == "UseItem"
			then loadout:useItem(id, function(itemId) return activate(player, itemId) end)
			else loadout:use("Use", 0, function(itemId) return activate(player, itemId) end)
		if accepted then publish(player) end
	end)
	-- One loop for every hazard's lifetime/contact and every defense's expiry.
	RunService.Heartbeat:Connect(function()
		local now = time()
		for i = #shieldPulses, 1, -1 do
			local p = shieldPulses[i]
			local age = now - p.born
			if age >= 0.3 or not p.visual.Parent or PrototypeWorld.getRaceKart(p.player) ~= p.kart
				or RaceSession.forPlayer(p.player) ~= p.session then
				p.visual:Destroy(); table.remove(shieldPulses, i)
			else
				p.visual.Size = Vector3.new(9, 6.5, 11) * (0.9 + age * 1.5)
				p.visual.Transparency = 0.45 + age / 0.3 * 0.55
			end
		end
		missiles:update(now)
		thunder:update(now)
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
		local botSession=RaceSession.active and RaceSession.active()
		if botSession then
			for participant in botSession.participants do
				if participant:GetAttribute("IsBot")==true then
					local activeKart,chassis=PrototypeWorld.getRaceKart(participant)
					if activeKart then
						table.insert(targets,{player=participant,chassis=chassis,previous=previousPositions[participant] or chassis.Position})
						previousPositions[participant]=chassis.Position
					else previousPositions[participant]=nil end
				end
			end
		end
		smoke:update(now, targets)
		for index = #hazards, 1, -1 do
			local hazard = hazards[index]
			local remove = now-hazard.born >= Config.SLICK_LIFETIME or not hazard.model.Parent
			local removalReason = if now-hazard.born >= Config.SLICK_LIFETIME then "lifetime"
				elseif not hazard.model.Parent then "model_removed" else nil
			if not remove then
				if hazard.deploy and Visuals.updateSlick(hazard.deploy, now-hazard.born) then hazard.deploy = nil end
				for _, target in targets do
					if hazard.session ~= nil and hazard.session == RaceSession.forPlayer(target.player)
						and (target.player ~= hazard.owner or now-hazard.born >= Config.SLICK_OWNER_GRACE)
						and Geometry.crosses(hazard.trigger.CFrame, hazard.trigger.Size, target.previous, target.chassis) then
						local accepted, reason = RaceItemController.tryApplyOffensiveItem(target.player, hazard.owner, "Slick")
						if reason == "hit" or reason == "blocked" or reason == "immune" and not hazard.blocked[target.player] then
							print(string.format("[Slick] %s owner=%d target=%s reason=%s",
								if reason == "hit" then "HIT" else "BLOCKED", hazard.owner.UserId, if target.player:GetAttribute("IsBot")==true then target.player:GetAttribute("BotId") else tostring(target.player.UserId), reason))
							if reason == "immune" then hazard.blocked[target.player] = true end
						end
						if accepted then remove = true; break end
					end
				end
			end
			if remove then removeHazard(index, removalReason) end
		end
	end)
end

return RaceItemController
