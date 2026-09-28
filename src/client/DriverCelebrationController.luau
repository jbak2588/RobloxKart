local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DriverCelebrationController = {}
local started = false

function DriverCelebrationController.start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local active = false
	local joint: Motor6D? = nil
	local originalTransform = CFrame.identity
	local elapsed = 0

	local function restore()
		if joint and joint.Parent then joint.Transform = originalTransform end
		joint = nil
		elapsed = 0
	end

	local function findShoulder(): Motor6D?
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		if not character or not seat or seat:GetAttribute("PrototypeKartSeat") ~= true then return nil end
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		local candidate = torso and (torso:FindFirstChild("RightShoulder") or torso:FindFirstChild("Right Shoulder"))
		return if candidate and candidate:IsA("Motor6D") then candidate else nil
	end

	local function onRaceState()
		active = player:GetAttribute("RaceState") == "FINISHING"
		if not active then restore() end
	end

	player:GetAttributeChangedSignal("RaceState"):Connect(onRaceState)
	player.CharacterRemoving:Connect(function() restore() end)
	player.CharacterAdded:Connect(function() restore() end)
	RunService.PreSimulation:Connect(function(deltaTime: number)
		if not active then return end
		local character = player.Character
		if not joint then
			joint = findShoulder()
			if not joint then return end
			originalTransform = joint.Transform
			elapsed = 0
		elseif not character or not joint:IsDescendantOf(character) then
			restore()
			return
		end
		elapsed = math.min(0.25, elapsed + deltaTime)
		local alpha = elapsed / 0.25
		joint.Transform = originalTransform * CFrame.Angles(math.rad(-65) * alpha, 0, math.rad(55) * alpha)
	end)
	onRaceState()
end

return DriverCelebrationController
