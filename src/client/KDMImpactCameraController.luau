-- Own human target only, using existing server-authored hit edges. No new remotes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HapticService = (function() local ok, s = pcall(function() return game:GetService("HapticService") end); return if ok then s else nil end)()
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("KDMItemVFXConfig"))
local Motion = require(Shared:WaitForChild("KDMImpactCameraMotion"))
local Controller = {}
local stop
function Controller.start()
	if stop then return end
	local player = Players.LocalPlayer
	local motion = Motion.new(Config)
	local connections, kartConnections = {}, {}
	local kart, session, reset, bound
	local previous = {}
	local camera, base, applied
	local PRE, POST = "KDMImpactCameraRestore", "KDMImpactCameraOffset"
	local function restore()
		-- Only undo our last write, never a newer write by another camera owner.
		if camera and applied and camera.CFrame == applied then camera.CFrame = base end
		camera, base, applied = nil, nil, nil
	end
	local function clear()
		restore(); motion:clear()
		RunService:UnbindFromRenderStep(PRE); RunService:UnbindFromRenderStep(POST)
		bound = false
		pcall(function()
			if HapticService and HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1) then
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
			end
		end)
	end
	local function activeKart()
		if player:GetAttribute("IsBot") == true then return nil end
		local state = player:GetAttribute("RaceState")
		local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local seat = human and human.SeatPart
		local candidate = seat and seat.Parent
		if not human or human.Health <= 0 or not seat or not candidate or not candidate.Parent then return nil end
		if candidate:GetAttribute("RaceControlsLocked") == true then return nil end

		local isRaceKart = (state == "RACING") and seat:GetAttribute("PrototypeKartSeat") == true and candidate:GetAttribute("PrototypeKart") == true
		local isLobbyKart = seat:GetAttribute("LobbyKartSeat") == true and candidate:GetAttribute("LobbyKart") == true
		if not isRaceKart and not isLobbyKart then return nil end
		return candidate
	end
	local function valid()
		if not kart or activeKart() ~= kart then return false end
		if kart:GetAttribute("LobbyKart") == true then return true end
		return player:GetAttribute("RaceSessionId") == session
			and kart:GetAttribute("RaceResetSerial") == reset
	end
	local function renderStep()
		if not valid() then clear(); return end
		local position, rotation, active = motion:sample(time())
		local offTrack = kart and kart:GetAttribute("KartOffTrack") == true
		local forwardSpeed = 0
		if offTrack and kart.PrimaryPart then
			forwardSpeed = math.abs(kart.PrimaryPart.AssemblyLinearVelocity:Dot(kart.PrimaryPart.CFrame.LookVector))
		end

		local shakePos = Vector3.zero
		local shakeRot = Vector3.zero
		if offTrack and forwardSpeed > 4 then
			local speedFactor = math.clamp(forwardSpeed / 60, 0.2, 1.0)
			local shakeT = time() * 30
			local sx = (math.sin(shakeT * 1.3) + math.cos(shakeT * 0.9)) * 0.05 * speedFactor
			local sy = math.sin(shakeT * 1.7) * 0.07 * speedFactor
			local sz = math.cos(shakeT * 1.5) * 0.04 * speedFactor
			local sRoll = math.rad(math.sin(shakeT * 1.1) * 0.5 * speedFactor)
			shakePos = Vector3.new(sx, sy, sz)
			shakeRot = Vector3.new(0, 0, sRoll)

			pcall(function()
				if HapticService and HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1) then
					HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0.2 * speedFactor)
				end
			end)
		else
			pcall(function()
				if HapticService and HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1) then
					HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
				end
			end)
		end

		if not active and not (offTrack and forwardSpeed > 4) then clear(); return end
		camera = Workspace.CurrentCamera
		if not camera then clear(); return end
		base = camera.CFrame
		applied = base * CFrame.new(position + shakePos) * CFrame.Angles(rotation.X + shakeRot.X, rotation.Y + shakeRot.Y, rotation.Z + shakeRot.Z)
		camera.CFrame = applied
	end
	local function bindRender()
		if bound then return end
		bound = true
		RunService:BindToRenderStep(PRE, Enum.RenderPriority.Camera.Value-1, restore)
		RunService:BindToRenderStep(POST, Enum.RenderPriority.Camera.Value+2, renderStep)
	end
	local function play(kind)
		if not valid() then clear(); return end
		motion:play(kind, time())
		bindRender()
	end
	local function sync()
		local current = activeKart()
		local s = player:GetAttribute("RaceSessionId")
		local r = current and current:GetAttribute("RaceResetSerial")
		if current == kart and s == session and r == reset then return end
		clear()
		for _, connection in kartConnections do connection:Disconnect() end
		kartConnections = {}
		kart, session, reset = current, s, r
		if not current then return end
		for kind, attribute in { Missile = "KartMissileHitActive", Thunder = "KartThunderHitActive" } do
			-- Binding/reset suppresses a stale active effect, not a new impact.
			previous[kind] = current:GetAttribute(attribute) == true
			table.insert(kartConnections, current:GetAttributeChangedSignal(attribute):Connect(function()
				local active = current:GetAttribute(attribute) == true
				if active and not previous[kind] then play(kind) end
				previous[kind] = active
			end))
		end
		table.insert(kartConnections, current:GetAttributeChangedSignal("KartOffTrack"):Connect(function()
			if current:GetAttribute("KartOffTrack") == true then
				bindRender()
			end
		end))
		for _, attribute in {"RaceResetSerial", "RaceControlsLocked"} do
			table.insert(kartConnections, current:GetAttributeChangedSignal(attribute):Connect(sync))
		end
		table.insert(kartConnections, current.Destroying:Connect(clear))
	end
	for _, attribute in {"RaceState", "RaceSessionId", "LobbyDriveActive"} do
		table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(sync))
	end
	-- Seat changes are polled by one connection, not another character-owned chain.
	table.insert(connections, RunService.Heartbeat:Connect(sync))
	table.insert(connections, player.CharacterRemoving:Connect(function() clear() end))
	table.insert(connections, player.OnTeleport:Connect(clear))
	table.insert(connections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(clear))
	stop = function()
		clear()
		for _, connection in connections do connection:Disconnect() end
		for _, connection in kartConnections do connection:Disconnect() end
		stop = nil
	end
	table.insert(connections, player.AncestryChanged:Connect(function(_, parent) if not parent then Controller.destroy() end end))
	sync()
end
function Controller.destroy() if stop then stop() end end
return Controller
