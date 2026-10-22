local fs = require('@lune/fs')
local luau = require('@lune/luau')
local rb = require('@lune/roblox')

local checks = 0
local function check(value, label)
	assert(value, label)
	checks += 1
end

local V, CF = rb.Vector3, rb.CFrame
local source = fs.readFile('src/client/KDMDriverGripController.luau')
local env = {
	Vector3 = V, CFrame = CF, Instance = rb.Instance, Enum = rb.Enum,
	game = { GetService = function() return {} end },
}
local grip = luau.load(source, { environment = env })()
local config = grip.CONFIG

-- Activation contract
check(config.VisualModelName == 'KDMV2', 'helper is gated to the KDM V2 visual model')
check(config.PivotName == 'SteeringPivot', 'targets live on SteeringPivot')
check(config.ActiveRaceStates.PRE_RACE and config.ActiveRaceStates.COUNTDOWN and config.ActiveRaceStates.RACING,
	'active from staging through racing')
check(not config.ActiveRaceStates.FINISHING and not config.ActiveRaceStates.FINISHED
	and not config.ActiveRaceStates.GARAGE and not config.ActiveRaceStates.DNF,
	'finish presentation, results and Garage release the hands')
check(not source:find('SprintV1', 1, true), 'Sprint is excluded by model gate, never named or special-cased')
check(not source:find('Kart0', 1, true) and not source:find('Cyan', 1, true) and not source:find('Red', 1, true)
	and not source:find('TextureID', 1, true), 'Cyan/Red share one config; no texture or Kart-id branching')
check(source:find('visual:GetAttribute("VisualModelName") ~= CONFIG.VisualModelName', 1, true) ~= nil,
	'model gate reads the Visual attribute')

-- Both arms defined, mirrored, same settings
check(#config.Arms == 2, 'left and right arms defined')
local left, right = config.Arms[1], config.Arms[2]
check(left.Side == 'Left' and right.Side == 'Right', 'arm sides')
check(left.UpperArm == 'LeftUpperArm' and left.Hand == 'LeftHand'
	and right.UpperArm == 'RightUpperArm' and right.Hand == 'RightHand', 'chains are shoulder to hand only')
check(left.Offset.X == -right.Offset.X and left.Offset.Y == right.Offset.Y and left.Offset.Z == right.Offset.Z,
	'grip offsets mirror across the wheel')
check(math.abs(left.Offset.X) > 0.5 and math.abs(left.Offset.X) < 0.8, 'grip offsets sit near the rim width')
check(left.Target ~= right.Target, 'distinct runtime attachments')

-- Pose function: position follows part of the roll, hand pitch stays kart-relative
local function rollCF(angle) return CF.Angles(0, 0, angle) end
for _, roll in { -0.6545, -0.3, 0, 0.3, 0.6545 } do
	for _, arm in config.Arms do
		local localCF = grip.targetLocalCFrame(arm.Offset, roll)
		local world = rollCF(roll) * localCF
		local expected = rollCF(roll * config.RollFollow) * arm.Offset
		check((world.Position - expected).Magnitude < 1e-5, 'target position follows RollFollow of the wheel roll')
		check(world.Rotation:FuzzyEq(config.HandOrientation, 1e-5), 'hand orientation does not roll with the wheel')
	end
end
check(grip.targetLocalCFrame(left.Offset, 0):FuzzyEq(CF.new(left.Offset) * config.HandOrientation, 1e-6),
	'straight wheel keeps the configured grip frame')
check(config.RollFollow > 0 and config.RollFollow <= 1, 'roll follow fraction is bounded')

-- Body, seat, geometry and physics are never written
local forbidden = {
	'BodyVelocity', 'VectorForce', 'AlignPosition', 'AlignOrientation', 'LinearVelocity', 'BodyPosition',
	'WeldConstraint', 'AssemblyLinearVelocity', 'PivotTo', 'ApplyImpulse', 'SetNetworkOwner',
	'UpperTorso', 'LowerTorso', 'HumanoidRootPart', 'LeftFoot', 'RightFoot', 'Head', 'Seat:Sit',
}
for _, token in forbidden do
	check(not source:find(token, 1, true), 'helper never references ' .. token)
end
check(not source:find('%.Transform%s*=[^=]'), 'helper only reads the steering motor, never writes Transform')
check(not source:find('seat%.%w+%s*=[^=]') and not source:find('pivot%.%w+%s*=[^=]')
	and not source:find('humanoid%.%w+%s*=[^=]'), 'helper never assigns Seat, SteeringPivot or Humanoid properties')
check(source:find('ik.ChainRoot = upperArm', 1, true) ~= nil and source:find('ik.EndEffector = hand', 1, true) ~= nil,
	'IK chain is UpperArm to Hand')
check(source:find('ik.Parent = humanoid', 1, true) ~= nil and source:find('target.Parent = pivot', 1, true) ~= nil,
	'only runtime IK and attachments are created')
check(not source:find('Enum.IKControlType.Position', 1, true) and source:find('Enum.IKControlType.Transform', 1, true) ~= nil,
	'Transform IK pins hand pitch (Position-only IK left the hand ~0.25 stud off target)')

-- Cleanup paths
for _, token in {
	'SeatPart', 'GetAttributeChangedSignal("RaceState")', 'CharacterRemoving', 'CharacterAdded',
	'PlayerRemoving', 'pivot.Destroying', 'humanoid.Died', 'Health <= 0', 'destroyObjects(grip.objects)',
} do
	check(source:find(token, 1, true) ~= nil, 'cleanup/lifecycle path: ' .. token)
end
check(source:find('stale:Destroy()', 1, true) ~= nil and source:find('staleIk:Destroy()', 1, true) ~= nil,
	're-seat removes stale helpers before creating new ones')

-- Wiring
local client = fs.readFile('src/client/init.client.luau')
check(client:find('KDMDriverGripController.start()', 1, true) ~= nil, 'client starts the grip controller')

-- Locked contracts stay untouched
local definition = fs.readFile('src/shared/KDMV2VisualDefinition.luau')
check(definition:find('CFrame.new(0, -0.79, 0.5)', 1, true) ~= nil, 'KDMV2 lowered Seat contract verified')
local factory = fs.readFile('src/shared/KartVisualFactory.luau')
check(factory:find('CFrame.new(0, 0.06, 0.5)', 1, true) ~= nil, 'Sprint lowered Seat contract verified')
check(not definition:find('Grip', 1, true) and not factory:find('KDMGrip', 1, true),
	'visual definition and factory carry no grip geometry')

print('PASS: ' .. checks .. ' KDM driver grip contract checks (runtime hand contact is verified in Studio, not here)')
