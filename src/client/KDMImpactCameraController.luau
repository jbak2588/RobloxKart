-- Own human target only, using existing server-authored hit edges. No new remotes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
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
	end
	local function activeKart()
		if player:GetAttribute("IsBot") == true or player:GetAttribute("RaceState") ~= "RACING" then return nil end
		local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local seat = human and human.SeatPart
		local candidate = seat and seat.Parent
		if not human or human.Health <= 0 or not seat or seat:GetAttribute("PrototypeKartSeat") ~= true
			or not candidate or not candidate.Parent or candidate:GetAttribute("PrototypeKart") ~= true
			or candidate:GetAttribute("RaceControlsLocked") == true then return nil end
		return candidate
	end
	local function valid()
		return kart and activeKart() == kart and player:GetAttribute("RaceSessionId") == session
			and kart:GetAttribute("RaceResetSerial") == reset
	end
	local function play(kind)
		if not valid() then clear(); return end
		motion:play(kind, time())
		if bound then return end
		bound = true
		-- Undo before Roblox/chase smoothing reads last frame's CFrame; then add
		-- after Camera+1 (existing KartCameraController). No feedback accumulation.
		RunService:BindToRenderStep(PRE, Enum.RenderPriority.Camera.Value-1, restore)
		RunService:BindToRenderStep(POST, Enum.RenderPriority.Camera.Value+2, function()
			if not valid() then clear(); return end
			local position, rotation, active = motion:sample(time())
			if not active then clear(); return end
			camera = Workspace.CurrentCamera
			if not camera then clear(); return end
			base = camera.CFrame
			applied = base * CFrame.new(position) * CFrame.Angles(rotation.X, rotation.Y, rotation.Z)
			camera.CFrame = applied
		end)
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
		for _, attribute in {"RaceResetSerial", "RaceControlsLocked"} do
			table.insert(kartConnections, current:GetAttributeChangedSignal(attribute):Connect(sync))
		end
		table.insert(kartConnections, current.Destroying:Connect(clear))
	end
	for _, attribute in {"RaceState", "RaceSessionId"} do
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
