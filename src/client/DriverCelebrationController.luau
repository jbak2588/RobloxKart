local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Finish = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KDMFinishPresentation"))

local DriverCelebrationController = {}
local started = false

function DriverCelebrationController.start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local active = false
	local joint: (Motor6D | AnimationConstraint)? = nil
	local originalTransform = CFrame.identity
	local elapsed = 0
	local profile = nil
	local sessionId = player:GetAttribute("RaceSessionId")

	local function restore()
		if joint and joint.Parent then joint.Transform = originalTransform end
		joint = nil
		elapsed = 0
	end

	local function findShoulder(): (Motor6D | AnimationConstraint)?
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		if not character or not seat or seat:GetAttribute("PrototypeKartSeat") ~= true then return nil end
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		local upperArm = character:FindFirstChild("RightUpperArm")
		local candidate = upperArm and upperArm:FindFirstChild("RightShoulder")
			or torso and (torso:FindFirstChild("RightShoulder") or torso:FindFirstChild("Right Shoulder"))
		return if candidate and (candidate:IsA("Motor6D") or candidate:IsA("AnimationConstraint")) then candidate else nil
	end

	local function onPresentationState()
		local currentSession = player:GetAttribute("RaceSessionId")
		if currentSession ~= sessionId then restore(); active=false; sessionId=currentSession end
		local state = player:GetAttribute("RaceState")
		local _, _, resolved = Finish.resolve(state, player:GetAttribute("RaceFinishPosition"), player:GetAttribute("RaceParticipantCount"))
		local eligible = resolved ~= nil and player:GetAttribute("RaceFinishPhase") == "PRESENT"
			and (state == "FINISHING" or state == "FINISHED")
		if eligible and not active then profile=resolved end
		active=eligible
		if not active then restore() end
	end

	player:GetAttributeChangedSignal("RaceState"):Connect(onPresentationState)
	player:GetAttributeChangedSignal("RaceFinishPhase"):Connect(onPresentationState)
	player:GetAttributeChangedSignal("RaceSessionId"):Connect(onPresentationState)
	player:GetAttributeChangedSignal("RaceFinishPosition"):Connect(onPresentationState)
	player:GetAttributeChangedSignal("RaceParticipantCount"):Connect(onPresentationState)
	player.CharacterRemoving:Connect(function() active = false; restore() end)
	player.CharacterAdded:Connect(function() active = false; restore() end)
	RunService.PreSimulation:Connect(function(deltaTime: number)
		if not active then return end
		local character = player.Character
		if not findShoulder() then
			active = false
			restore()
			return
		end
		if not joint then
			joint = findShoulder()
			if not joint then return end
			originalTransform = joint.Transform
			elapsed = 0
		elseif not character or not joint:IsDescendantOf(character) then
			restore()
			return
		end
		elapsed += deltaTime
		local alpha = math.clamp(elapsed / 0.25, 0, 1)
		local waitingForRunnerUp = profile == Finish.Profiles.WINNER
			and player:GetAttribute("RaceWinnerAwaitingRunnerUp") == true
		local wave = if elapsed >= 0.25 and (elapsed <= profile.WaveSeconds or waitingForRunnerUp) then
			math.sin((elapsed - 0.25) * math.pi * 4) * math.rad(profile.WaveDegrees) else 0
		joint.Transform = originalTransform * CFrame.Angles(math.rad(profile.RaiseX) * alpha, wave, math.rad(profile.RaiseZ) * alpha)
	end)
	onPresentationState()
end

return DriverCelebrationController
