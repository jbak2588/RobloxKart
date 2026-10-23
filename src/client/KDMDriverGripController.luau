local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Hands-only steering grip for the KDM V2 seated driver. Each arm is a native
-- shoulder -> wrist IKControl chain driving a runtime Attachment parented to the
-- kart's SteeringPivot, so the hands follow wheel rotation. The Seat, torso, legs,
-- kart geometry and physics are never touched. IK is local presentation only:
-- every client applies it to every seated KDM V2 driver instead of replicating it.
local KDMDriverGripController = {}

KDMDriverGripController.CONFIG = table.freeze({
	VisualModelName = "KDMV2",
	PivotName = "SteeringPivot",
	ActiveRaceStates = table.freeze({ PRE_RACE = true, COUNTDOWN = true, RACING = true }),
	IkWeight = 1,
	IkSmoothTime = 0.08,
	PollSeconds = 0.25,
	-- SteeringPivot-local grip frames. Hand centers sit just behind the rim on the driver
	-- side. Position-only IK left the physical hand ~0.25 stud off its target (the solver and
	-- the constraint-driven hand disagree on hand orientation), so Transform IK pins the
	-- native seated hand pitch, which also stays inside the R15 wrist/elbow limits.
	HandOrientation = CFrame.Angles(math.rad(36), 0, 0),
	-- Fraction of wheel roll the hand targets follow. The R15 arm cannot track a full 37.5
	-- degree lock (one hand drifts ~0.3 stud off its target); half follow keeps both under 0.15.
	RollFollow = 0.5,
	Arms = table.freeze({
		table.freeze({
			Side = "Left",
			UpperArm = "LeftUpperArm",
			Hand = "LeftHand",
			Target = "KDMGripLeft",
			Offset = Vector3.new(-0.70, 0.05, 0.15),
		}),
		table.freeze({
			Side = "Right",
			UpperArm = "RightUpperArm",
			Hand = "RightHand",
			Target = "KDMGripRight",
			Offset = Vector3.new(0.70, 0.05, 0.15),
		}),
	}),
})

local CONFIG = KDMDriverGripController.CONFIG
local IK_PREFIX = "KDMGripIK_"
local started = false

type GripTarget = { attachment: Attachment, offset: Vector3 }
type Grip = {
	seat: BasePart,
	pivot: BasePart,
	humanoid: Humanoid,
	targets: { GripTarget },
	objects: { Instance },
	destroying: RBXScriptConnection,
}

-- Attachment frame in the (rolled) SteeringPivot space. The hand pitch stays fixed relative
-- to the kart and the position follows only part of the roll.
function KDMDriverGripController.targetLocalCFrame(offset: Vector3, roll: number): CFrame
	local follow = CFrame.Angles(0, 0, roll * CONFIG.RollFollow)
	return CFrame.Angles(0, 0, -roll) * CFrame.new(follow * offset) * CONFIG.HandOrientation
end

local function readRoll(pivot: BasePart): number
	local motor = pivot:FindFirstChild("VisualMotor")
	if motor and motor:IsA("Motor6D") then
		local _, _, roll = motor.Transform:ToEulerAnglesXYZ()
		return roll
	end
	return 0
end

local function findGripContext(player: Player, humanoid: Humanoid): (BasePart?, BasePart?)
	local state = player:GetAttribute("RaceState")
	local racing = CONFIG.ActiveRaceStates[state] == true
	local driving = state == "GARAGE" and player:GetAttribute("LobbyDriveActive") == true
	local seat = humanoid.SeatPart
	if not seat or not (racing and seat:GetAttribute("PrototypeKartSeat") == true
		or driving and seat:GetAttribute("LobbyKartSeat") == true) then
		return nil, nil
	end
	local kart = seat.Parent
	if not kart or not kart:IsA("Model") or not (racing and kart:GetAttribute("PrototypeKart") == true
		or driving and kart:GetAttribute("LobbyKart") == true
			and kart:GetAttribute("LobbyOwnerUserId") == player.UserId) then
		return nil, nil
	end
	local visual = kart:FindFirstChild("Visual")
	if not visual or visual:GetAttribute("VisualModelName") ~= CONFIG.VisualModelName then
		return nil, nil
	end
	local pivot = visual:FindFirstChild(CONFIG.PivotName, true)
	if not pivot or not pivot:IsA("BasePart") then
		return nil, nil
	end
	return seat, pivot
end

local function destroyObjects(objects: { Instance })
	for _, object in objects do
		object:Destroy()
	end
	table.clear(objects)
end

local function createGrip(character: Model, humanoid: Humanoid, seat: BasePart, pivot: BasePart): Grip?
	local objects: { Instance } = {}
	local targets: { GripTarget } = {}
	local roll = readRoll(pivot)
	for _, arm in CONFIG.Arms do
		local upperArm = character:FindFirstChild(arm.UpperArm)
		local hand = character:FindFirstChild(arm.Hand)
		if not upperArm or not upperArm:IsA("BasePart") or not hand or not hand:IsA("BasePart") then
			destroyObjects(objects)
			return nil
		end
		-- Never stack helpers if a previous grip was torn down by a character reset.
		local stale = pivot:FindFirstChild(arm.Target)
		if stale then
			stale:Destroy()
		end
		local staleIk = humanoid:FindFirstChild(IK_PREFIX .. arm.Side)
		if staleIk then
			staleIk:Destroy()
		end

		local target = Instance.new("Attachment")
		target.Name = arm.Target
		target.CFrame = KDMDriverGripController.targetLocalCFrame(arm.Offset, roll)
		target.Parent = pivot
		table.insert(objects, target)
		table.insert(targets, { attachment = target, offset = arm.Offset })

		local ik = Instance.new("IKControl")
		ik.Name = IK_PREFIX .. arm.Side
		ik.Type = Enum.IKControlType.Transform
		ik.ChainRoot = upperArm
		ik.EndEffector = hand
		ik.Target = target
		ik.Weight = CONFIG.IkWeight
		ik.SmoothTime = CONFIG.IkSmoothTime
		ik.Enabled = true
		ik.Parent = humanoid
		table.insert(objects, ik)
	end
	local grip: Grip
	local destroying = pivot.Destroying:Connect(function()
		destroyObjects(grip.objects)
	end)
	grip = {
		seat = seat,
		pivot = pivot,
		humanoid = humanoid,
		targets = targets,
		objects = objects,
		destroying = destroying,
	}
	return grip
end

function KDMDriverGripController.start()
	if started then
		return
	end
	started = true

	local grips: { [Player]: Grip } = {}
	local bindings: { [Player]: { RBXScriptConnection } } = {}
	local humanoidBindings: { [Player]: { RBXScriptConnection } } = {}

	local function release(player: Player)
		local grip = grips[player]
		if not grip then
			return
		end
		grips[player] = nil
		grip.destroying:Disconnect()
		destroyObjects(grip.objects)
	end

	local function evaluate(player: Player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid or humanoid.Health <= 0 then
			release(player)
			return
		end
		local seat, pivot = findGripContext(player, humanoid)
		local grip = grips[player]
		if not seat or not pivot then
			release(player)
			return
		end
		if grip and grip.seat == seat and grip.pivot == pivot and grip.humanoid == humanoid then
			return
		end
		release(player)
		local created = createGrip(character, humanoid, seat, pivot)
		if created then
			grips[player] = created
		end
	end

	local function clearHumanoidBindings(player: Player)
		local connections = humanoidBindings[player]
		if connections then
			for _, connection in connections do
				connection:Disconnect()
			end
			humanoidBindings[player] = nil
		end
	end

	local function unbind(player: Player)
		release(player)
		clearHumanoidBindings(player)
		local connections = bindings[player]
		if connections then
			for _, connection in connections do
				connection:Disconnect()
			end
			bindings[player] = nil
		end
	end

	local function bindCharacter(player: Player, character: Model)
		release(player)
		clearHumanoidBindings(player)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") or player.Character ~= character
			or not bindings[player] then
			return
		end
		humanoidBindings[player] = {
			humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
				evaluate(player)
			end),
			humanoid.Died:Connect(function()
				release(player)
			end),
		}
		evaluate(player)
	end

	local function bindPlayer(player: Player)
		if bindings[player] then
			return
		end
		bindings[player] = {
			player:GetAttributeChangedSignal("RaceState"):Connect(function()
				evaluate(player)
			end),
			player:GetAttributeChangedSignal("LobbyDriveActive"):Connect(function()
				evaluate(player)
			end),
			player.CharacterRemoving:Connect(function()
				release(player)
				clearHumanoidBindings(player)
			end),
			player.CharacterAdded:Connect(function(character)
				bindCharacter(player, character)
			end),
		}
		if player.Character then
			task.spawn(bindCharacter, player, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(unbind)

	RunService.PreRender:Connect(function()
		for _, grip in grips do
			local roll = readRoll(grip.pivot)
			for _, target in grip.targets do
				target.attachment.CFrame = KDMDriverGripController.targetLocalCFrame(target.offset, roll)
			end
		end
	end)

	-- Kart visual and Seat attributes replicate independently of SeatPart; poll cheaply.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed < CONFIG.PollSeconds then
			return
		end
		elapsed = 0
		for player in bindings do
			evaluate(player)
		end
	end)
end

return KDMDriverGripController
