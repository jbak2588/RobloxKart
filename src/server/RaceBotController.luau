-- Explicit server NPC identity. Production rooms and the Studio harness share creation only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World = require(script.Parent:WaitForChild("PrototypeWorld"))
local Session = require(script.Parent:WaitForChild("RaceSession"))
local Steering = require(script.Parent:WaitForChild("RaceBotSteering"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackCatalog = require(Shared:WaitForChild("TrackCatalog"))
local TrackGeometry = require(Shared:WaitForChild("TrackGeometry"))
local RaceConfig = require(Shared:WaitForChild("RaceConfig"))
local KartConfig = require(Shared:WaitForChild("KartConfig"))
local Controller = {}
local testRecord
local productionRecord
local productionPending = false

-- Seating joins the initially manual Kart to an automatic NPC assembly.
-- Finalize the joined assembly at seating boundaries, never in the driving loop.
local function finalizeBotServerOwnership(context)
	local root = context.chassis.AssemblyRootPart
	if not root or context.seat.AssemblyRootPart ~= root then
		return false, "Bot seating assembly is not connected"
	end
	local canSet, reason = root:CanSetNetworkOwnership()
	if not canSet then return false, "Bot ownership unavailable: " .. tostring(reason) end
	local ok, err = pcall(function()
		if root:GetNetworkOwner() ~= nil or root:GetNetworkOwnershipAuto() then
			root:SetNetworkOwner(nil)
		end
		assert(root:GetNetworkOwner() == nil and not root:GetNetworkOwnershipAuto(),
			"Bot final assembly requires manual server ownership")
	end)
	return ok, err
end

function Controller.enabled()
	return RunService:IsStudio() and Workspace:GetAttribute("KDMEnableRaceBot") == true
end

local function destroy(record)
	if not record or record.destroyed then return end
	record.destroyed = true
	for _, connection in record.connections do connection:Disconnect() end
	local session = Session.active()
	if session and session:contains(record.state) then session:removeServerBot(record.state) end
	if record.state then World.releaseBotKartContext(record.state) end
	if record.npc then record.npc:Destroy() end
	if record.state then record.state:Destroy() end
	if record.folder and #record.folder:GetChildren() == 0 then record.folder:Destroy() end
end

local function create(source, options)
	local record = {connections={}, source=source}
	local ok, err = pcall(function()
		local track = TrackCatalog.Entries[options.trackId]
		assert(track and TrackCatalog.botAllowed(options.trackId), "Bot course unavailable")
		local course = TrackGeometry.getCourse(TrackGeometry.getDefinition(track.GeometryId))
		record.steeringState = Steering.new(course, TrackGeometry.getDefinition(track.GeometryId).RoadWidth, KartConfig)
		record.folder = ReplicatedStorage:FindFirstChild("KDMBotRacers")
		if not record.folder then
			record.folder = Instance.new("Folder")
			record.folder.Name = "KDMBotRacers"
			record.folder.Parent = ReplicatedStorage
		end
		assert(not record.folder:FindFirstChild("Bot01"), "Duplicate Bot01")
		local state = Instance.new("Folder")
		record.state = state
		state.Name = "Bot01"
		state:SetAttribute("IsBot", true)
		state:SetAttribute("BotId", "Bot01")
		state:SetAttribute("DisplayName", "KDM Rookie [BOT]")
		state:SetAttribute("ReadyOrder", options.gridSlot)
		state:SetAttribute("GridSlot", options.gridSlot)
		state:SetAttribute("SelectedTrackId", track.Id)
		state:SetAttribute("SelectedKartId", "Kart01")
		state.Parent = record.folder
		local description = Instance.new("HumanoidDescription")
		-- Bot-only color identity; the R15 rig, seating and Kart01 stay unchanged.
		description.TorsoColor = Color3.fromRGB(45, 115, 230)
		description.LeftArmColor = Color3.fromRGB(45, 115, 230)
		description.RightArmColor = Color3.fromRGB(45, 115, 230)
		description.LeftLegColor = Color3.fromRGB(25, 50, 95)
		description.RightLegColor = Color3.fromRGB(25, 50, 95)
		description.HeadColor = Color3.fromRGB(235, 220, 195)
		local modelOk, npc = pcall(function()
			return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		end)
		description:Destroy()
		assert(modelOk, tostring(npc))
		record.npc = npc
		npc.Name = "KDM Rookie [BOT]"
		npc.Parent = Workspace.Prototype
		local humanoid = npc:FindFirstChildOfClass("Humanoid")
		humanoid.DisplayName = npc.Name
		record.humanoid = humanoid
		local context = World.createBotKartContext(state, npc, options.spawnCFrame, source, options.roomId)
		record.context = context
		context.botControl = function()
			local look = context.chassis.CFrame.LookVector
			local forward = Vector3.new(look.X, 0, look.Z)
			local speed = if forward.Magnitude > 0.001 then context.chassis.AssemblyLinearVelocity:Dot(forward.Unit) else 0
			local command = Steering.command(record.steeringState, context.chassis.CFrame, nil, nil, speed)
			-- PrototypeWorld polls even while staging/countdown controls are locked.
			-- Those poses must not seed stale pursuit before the round's grid teleport.
			if state:GetAttribute("RaceState") ~= "RACING" then Steering.reset(record.steeringState) end
			state:SetAttribute("BotTargetSpeed", command.targetSpeed)
			return command
		end
		npc:PivotTo(context.seat.CFrame * CFrame.new(0, 2, 0))
		humanoid.Sit = false
		table.insert(record.connections, context.seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if context.seat.Occupant ~= humanoid then return end
			-- Defer until SeatWeld creation has completed; a repeated notification
			-- verifies the contract without another write when already manual.
			task.defer(function()
				if record.destroyed or context.seat.Occupant ~= humanoid then return end
				local finalized, reason = finalizeBotServerOwnership(context)
				if not finalized then warn("KDM Bot ownership finalization failed: " .. tostring(reason)) end
			end)
		end))
		context.seat:Sit(humanoid)
		if context.seat.Occupant == humanoid then
			local finalized, reason = finalizeBotServerOwnership(context)
			assert(finalized, tostring(reason))
		end
	end)
	if not ok then destroy(record); return nil, tostring(err) end
	return record
end

local function lost(record)
	local session = Session.active()
	return not record.npc.Parent or not record.context.kart.Parent or record.humanoid.Health <= 0
		or record.context.seat.Occupant ~= record.humanoid or not session or session:humanCount() == 0
end

function Controller.getProductionBot(botId)
	return if botId == "Bot01" then productionRecord else nil
end
function Controller.hasProductionBot(botId)
	return Controller.getProductionBot(botId) ~= nil or (botId == "Bot01" and productionPending)
end
function Controller.removeProductionBot(botId)
	if botId ~= "Bot01" or not productionRecord then return false end
	local record = productionRecord
	productionRecord = nil
	destroy(record)
	return true
end

function Controller.addProductionBot(options)
	local session = Session.active()
	local track = TrackCatalog.Entries[options.trackId]
	if not RaceConfig.INVITEABLE_BOT_ENABLED or Workspace:GetAttribute("KDMServerRole") ~= "RACE"
		or type(options.roomId) ~= "string" or options.roomId == "" or productionPending
		or productionRecord or testRecord or not session or session.phase ~= "WAITING"
		or session:humanCount() == 0 or not TrackCatalog.botAllowed(options.trackId)
		or not track or track.MaxPlayers < 2 or options.gridSlot ~= track.MaxPlayers then return false end
	productionPending = true
	local record, reason = create("PRODUCTION_ROOM", options)
	local admitted = false
	if record then
		local ok, result = pcall(function()
			if options.canAdmit and not options.canAdmit() then return false end
			return session:addServerBot(record.state, record.context, "PRODUCTION_ROOM")
		end)
		admitted = ok and result == true
		if not admitted then destroy(record) end
	end
	productionPending = false
	if not admitted then return false, reason or "admission_rejected" end
	productionRecord = record
	table.insert(record.connections, RunService.Heartbeat:Connect(function()
		if lost(record) then
			Controller.removeProductionBot("Bot01")
			if options.onLost then options.onLost() end
		end
	end))
	return true
end

function Controller.setProductionSpawn(frame)
	if not productionRecord then return end
	productionRecord.context:setSpawnCFrame(frame)
	Steering.reset(productionRecord.steeringState)
	productionRecord.context.kart:SetAttribute("RaceStartCFrame", frame)
	productionRecord.state:SetAttribute("GridSlot", TrackCatalog.Entries[productionRecord.state:GetAttribute("SelectedTrackId")].MaxPlayers)
end

function Controller.startTestHarness()
	if testRecord or productionRecord or productionPending or not Controller.enabled() then return false end
	local track = TrackCatalog.Entries.Track01Race
	local lift = CFrame.new(0, Workspace.Prototype.Kart:GetAttribute("RaceStartCFrame").Position.Y, 0)
	local record = create("STUDIO_TEST", {trackId=track.Id, gridSlot=2, spawnCFrame=lift * track.GridSlots[2]})
	if not record then return false end
	testRecord = record
	local function enter(player)
		if testRecord ~= record or record.human then return end
		record.human = player
		task.spawn(function()
			local character = player.Character or player.CharacterAdded:Wait()
			local humanoid = character:WaitForChild("Humanoid")
			if testRecord ~= record or not Controller.enabled() then return end
			player:SetAttribute("SelectedTrackId", track.Id)
			player:SetAttribute("SelectedKartId", "Kart01")
			player:SetAttribute("ReadyOrder", 1)
			local human = World.acquireKartContext(player, lift * track.GridSlots[1], "Kart01")
			character:PivotTo(human.seat.CFrame * CFrame.new(0, 3, 0))
			humanoid.Sit = false
			task.wait(.25)
			if testRecord ~= record or not Controller.enabled() then return end
			human.seat:Sit(humanoid)
			player:SetAttribute("RaceState", "PRE_RACE")
		end)
	end
	table.insert(record.connections, Players.PlayerAdded:Connect(enter))
	for _, player in Players:GetPlayers() do enter(player) end
	table.insert(record.connections, RunService.Heartbeat:Connect(function()
		if not Controller.enabled() or record.human and record.human.Parent ~= Players
			or record.added and lost(record) then Controller.stop(); return end
		local session = Session.active()
		if session and record.human and session:contains(record.human) then
			if not record.added then record.added = session:addTestBot(record.state, record.context) end
			if record.added and session.phase == "WAITING" and record.human:GetAttribute("RaceItemsReady") == true then
				session:startBotTest()
			end
		end
	end))
	table.insert(record.connections, Workspace:GetAttributeChangedSignal("KDMEnableRaceBot"):Connect(function()
		if not Controller.enabled() then Controller.stop() end
	end))
	return true
end
Controller.start = Controller.startTestHarness
function Controller.stop()
	local record = testRecord
	testRecord = nil
	destroy(record)
end
return Controller
