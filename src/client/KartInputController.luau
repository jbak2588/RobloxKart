local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local requireModule = require :: (ModuleScript) -> any
local kartConfigModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartConfig") :: ModuleScript
local KartConfig = requireModule(kartConfigModule)
local Slots = requireModule(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaceItemSlots"))

local KartInputController = {}
local perfModule = script.Parent:FindFirstChild("RacePerformanceMonitor")
local PerformanceMonitor = perfModule and requireModule(perfModule)
local raceItemRemote: RemoteEvent? = nil
local touchActions = { throttle = 0, steering = 0, drift = false }
local touchEnabled = false
local gasHeld=false
local desktopFocused=true
local function gasEnabled()
 return ((game.GameId==10772198697 and game.PlaceId==106553302629620)
  or (game.GameId==10768420544 and game.PlaceId==127925465904803))
  and game:GetService('Workspace'):GetAttribute('KDMGasPedalEnabled')==true
end
-- Touch-capable devices retain their existing adapter and GAS ownership.
function KartInputController.desktopAutoEnabled()
 return not UserInputService.TouchEnabled
  and UserInputService.PreferredInput==Enum.PreferredInput.KeyboardAndMouse and gasEnabled()
end
local function requestedGas()
 if KartInputController.desktopAutoEnabled() then
  return desktopFocused and not GuiService.MenuIsOpen and UserInputService:GetFocusedTextBox()==nil
   and UserInputService:IsKeyDown(Enum.KeyCode.W) and not UserInputService:IsKeyDown(Enum.KeyCode.S)
 end
 return touchEnabled and gasHeld
end
local touchUpdate: ((number) -> ())? = nil
local touchEdgeSender: (() -> ())? = nil
local lobbySender = nil
local lobbyTouchReset = nil
function KartInputController.setLobbyInputSender(sender) lobbySender = sender end
function KartInputController.setLobbyTouchReset(reset) lobbyTouchReset = reset end
function KartInputController.resetLobbyTouchState() if lobbyTouchReset then lobbyTouchReset() end end
function KartInputController.isLobbyDriving()
 local player=Players.LocalPlayer
 local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 local seat=h and h.SeatPart
 return player:GetAttribute("LobbyDriveActive")==true and h and h.Health>0 and seat
  and seat:GetAttribute("LobbyKartSeat")==true and seat.Parent:GetAttribute("LobbyOwnerUserId")==player.UserId
end

function KartInputController.isTouchPreferred(): boolean
	return UserInputService.TouchEnabled and UserInputService.PreferredInput == Enum.PreferredInput.Touch
end

function KartInputController.resetTouchActions()
	touchActions.throttle, touchActions.steering, touchActions.drift = 0, 0, false
 gasHeld=false
end

function KartInputController.setGasHeld(held)
 local nextHeld=held==true and gasEnabled()
 if gasHeld==nextHeld then return end
 gasHeld=nextHeld
 if touchEnabled and touchEdgeSender then touchEdgeSender() end
end

function KartInputController.isTouchDriftHeld(): boolean
	return touchEnabled and touchActions.drift
end

-- Adapters supply gameplay actions; only this controller sends KartControl.
-- Steering is independent of the vertical axis so a future adapter can replace it.
function KartInputController.setTouchActions(throttle: number, steering: number, drift: boolean)
	local driftChanged=touchActions.drift~=(drift==true)
	touchActions.throttle = if throttle == throttle then math.clamp(throttle, -1, 1) else 0
	touchActions.steering = if steering == steering then math.clamp(steering, -1, 1) else 0
	touchActions.drift = drift == true
	-- Preserve a release/press pair even when both occur between Heartbeats.
	-- Uses the same validated KartControl transport as PC key edges.
	if driftChanged and touchEnabled and touchEdgeSender then touchEdgeSender() end
end

function KartInputController.setTouchEnabled(enabled: boolean)
	touchEnabled = enabled
	if not enabled then KartInputController.resetTouchActions() end
end

function KartInputController.setTouchUpdater(update: ((number) -> ())?) touchUpdate = update end

local controlKeys = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.LeftShift] = true,
}

local function isDrivingPrototypeKart(): boolean
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seatPart = humanoid and humanoid.SeatPart

	return seatPart ~= nil and seatPart:GetAttribute("PrototypeKartSeat") == true
end

local function getInputAxes(): (number, number, boolean)
	if UserInputService:GetFocusedTextBox() ~= nil then
		return 0, 0, false
	end
	if KartInputController.isTouchPreferred() then
		if not touchEnabled then return 0, 0, false end
		return touchActions.throttle, touchActions.steering, touchActions.drift
	end
	if KartInputController.desktopAutoEnabled() and (not desktopFocused or GuiService.MenuIsOpen) then return 0,0,false end

	local throttle = (if KartInputController.desktopAutoEnabled() then 1 else (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0))
		- (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
	if KartInputController.desktopAutoEnabled() and UserInputService:IsKeyDown(Enum.KeyCode.S) then throttle=-1 end
	local steering = (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
		- (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)

	return throttle, steering, UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
end

function KartInputController.getEffectiveSteering(): number
	local _, steering = getInputAxes()
	return if isDrivingPrototypeKart() or KartInputController.isLobbyDriving() then steering else 0
end

-- Desktop selected-item use; mobile slots use the atomic direct-item path below.
function KartInputController.useRaceItem()
	if not raceItemRemote or UserInputService:GetFocusedTextBox() or not isDrivingPrototypeKart() then return end
	if Players.LocalPlayer:GetAttribute("RaceState") ~= "RACING" then return end
	raceItemRemote:FireServer("Use")
end

function KartInputController.selectRaceItem(id: string)
	if not raceItemRemote or UserInputService:GetFocusedTextBox() then return end
	local state = Players.LocalPlayer:GetAttribute("RaceState")
	if state ~= "RACING" and state ~= "COUNTDOWN" then return end
	if not Slots.contains(Players.LocalPlayer, id) then return end
	raceItemRemote:FireServer("Select", id)
end

function KartInputController.useRaceItemDirect(id: string)
	if not raceItemRemote or UserInputService:GetFocusedTextBox() or not KartInputController.isTouchPreferred()
		or Players.LocalPlayer:GetAttribute("RaceState") ~= "RACING" then return end
	if not Slots.contains(Players.LocalPlayer, id) then return end
	raceItemRemote:FireServer("UseItem", id)
end

function KartInputController.start()
	local remoteEvent = ReplicatedStorage:WaitForChild(KartConfig.REMOTE_EVENT_NAME) :: RemoteEvent
	raceItemRemote = ReplicatedStorage:WaitForChild("RaceItemControl") :: RemoteEvent
	local itemKeyDown = false
	local lastThrottle = 0
	local lastSteering = 0
	local lastDriftRequested = false
 local lastGasHeld=false
	local timeSinceSend = KartConfig.INPUT_SEND_INTERVAL
	local wasDriving = false

	local MIN_SEND_INTERVAL = 0.05
	local KEEP_ALIVE_INTERVAL = 0.25

	local function sendInput(force: boolean, neutral: boolean?)
		if lobbySender and KartInputController.isLobbyDriving() then
			-- Lobby has its own timeout-based transport. Heartbeat calls are not
			-- forced: still send held touch/keyboard axes before the server timeout.
			local throttle, steering, drift = getInputAxes()
   if gasEnabled() then lobbySender(if neutral then 0 else throttle,if neutral then 0 else steering,not neutral and drift,not neutral and requestedGas())
   else lobbySender(if neutral then 0 else throttle, if neutral then 0 else steering, not neutral and drift) end
			timeSinceSend = 0
			return
		end
		local driving = isDrivingPrototypeKart()
		local throttle, steering, driftRequested = getInputAxes()

		if not driving or neutral then
			throttle = 0
			steering = 0
			driftRequested = false
		end

		local changed = throttle ~= lastThrottle
			or steering ~= lastSteering
			or driftRequested ~= lastDriftRequested
			or driving ~= wasDriving
   or (gasEnabled() and (if KartInputController.desktopAutoEnabled() then requestedGas() else gasHeld)~=lastGasHeld)

		local sendInterval = math.max(KartConfig.INPUT_SEND_INTERVAL or MIN_SEND_INTERVAL, MIN_SEND_INTERVAL)
		local keepAlive = driving and timeSinceSend >= KEEP_ALIVE_INTERVAL

		local shouldSend = false
		if neutral then
			shouldSend = true
		elseif changed then
			shouldSend = force or timeSinceSend >= sendInterval
		elseif keepAlive then
			shouldSend = true
		end

		if shouldSend then
   local gas=not neutral and driving and requestedGas()
   if gasEnabled() then remoteEvent:FireServer(throttle,steering,driftRequested,gas)
   else remoteEvent:FireServer(throttle, steering, driftRequested) end
			if PerformanceMonitor then PerformanceMonitor.inputSent(throttle, steering, driftRequested) end
			lastThrottle = throttle
			lastSteering = steering
			lastDriftRequested = driftRequested
   lastGasHeld=gas
			wasDriving = driving
			timeSinceSend = 0
		end
	end

	touchEdgeSender=function() sendInput(true) end
	GuiService.MenuOpened:Connect(function()
		if KartInputController.desktopAutoEnabled() then sendInput(true,true) end
	end)
	GuiService.MenuClosed:Connect(function()
		if KartInputController.desktopAutoEnabled() then sendInput(true) end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		local slot = if input.KeyCode == Enum.KeyCode.One then 1
			elseif input.KeyCode == Enum.KeyCode.Two then 2
			elseif input.KeyCode == Enum.KeyCode.Three then 3
			elseif input.KeyCode == Enum.KeyCode.Four then 4 else nil
		if input.KeyCode == Enum.KeyCode.Five then slot = 5
		elseif input.KeyCode == Enum.KeyCode.Six then slot = 6 end
		if slot then
			local selection = Slots.get(Players.LocalPlayer, slot)
			if selection and not gameProcessed then KartInputController.selectRaceItem(selection) end
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			if not itemKeyDown and not gameProcessed then KartInputController.useRaceItem() end
			itemKeyDown = true
			return
		end
		if not controlKeys[input.KeyCode] then
			return
		end
		if gameProcessed and not isDrivingPrototypeKart() then
			return
		end

		sendInput(true)
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Q then itemKeyDown = false; return end
		if not controlKeys[input.KeyCode] then
			return
		end

		sendInput(true)
	end)

	UserInputService.WindowFocusReleased:Connect(function()
		desktopFocused=false
		itemKeyDown = false
		KartInputController.resetTouchActions()
		sendInput(true, true)
		if KartConfig.DEBUG_TELEMETRY then
			print("[KartInput] window focus released")
		end
	end)

	UserInputService.WindowFocused:Connect(function()
		desktopFocused=true
		sendInput(true)
		if KartConfig.DEBUG_TELEMETRY then
			print("[KartInput] window focused")
		end
	end)

	UserInputService.TextBoxFocused:Connect(function()
		sendInput(true)
		if KartConfig.DEBUG_TELEMETRY then
			print("[KartInput] text box focused")
		end
	end)

	UserInputService.TextBoxFocusReleased:Connect(function()
		sendInput(true)
		if KartConfig.DEBUG_TELEMETRY then
			print("[KartInput] text box focus released")
		end
	end)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		if touchUpdate then touchUpdate(deltaTime) end
		timeSinceSend += deltaTime
		local sendInterval = math.max(KartConfig.INPUT_SEND_INTERVAL or MIN_SEND_INTERVAL, MIN_SEND_INTERVAL)
		if timeSinceSend >= sendInterval then
			sendInput(false)
		end
	end)

	print("[RobloxKart] Kart controller ready")
end

return KartInputController
