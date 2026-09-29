-- lune run tests/kart_contact_validation.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local V, CF = rb.Vector3, rb.CFrame
local count = 0
local function check(value, label)
	assert(value, label)
	count += 1
end
local function load(path)
	return luau.load(fs.readFile(path), { environment = { Vector3 = V, CFrame = CF } })()
end
local config = load("src/shared/KartConfig.luau")
local Isolation = load("src/server/RacerCollisionIsolation.luau")
local Recovery = load("src/server/KartUprightRecovery.luau")
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			local connection = { active = true }
			function connection:Disconnect() self.active = false end
			table.insert(listeners, { connection, callback })
			return connection
		end,
		Fire = function(_, value)
			for _, listener in listeners do
				if listener[1].active then listener[2](value) end
			end
		end,
	}
end
local function node(class, name, group)
	local result = { ClassName = class, Name = name, CollisionGroup = group or "Default",
		children = {}, DescendantAdded = signal(), Destroying = signal() }
	function result:IsA(target) return self.ClassName == target or (target == "BasePart" and self.ClassName == "Part") end
	function result:GetDescendants()
		local descendants = {}
		local function visit(parent)
			for _, child in parent.children do
				table.insert(descendants, child)
				visit(child)
			end
		end
		visit(self)
		return descendants
	end
	function result:add(child)
		table.insert(self.children, child)
		local ancestor = self
		while ancestor do
			ancestor.DescendantAdded:Fire(child)
			ancestor = ancestor.parent
		end
		child.parent = self
	end
	return result
end
local physics = { registered = {}, pairs = {} }
function physics:IsCollisionGroupRegistered(name) return self.registered[name] == true end
function physics:RegisterCollisionGroup(name) self.registered[name] = true end
function physics:CollisionGroupSetCollidable(a, b, enabled)
	self.pairs[a .. ":" .. b] = enabled
end
local isolation = Isolation.new(physics)
isolation:configure()
check(physics.registered.RacerKart and physics.registered.RacerDriver, "both groups registered")
for _, pair in { "RacerKart:RacerKart", "RacerKart:RacerDriver", "RacerDriver:RacerDriver" } do
	check(physics.pairs[pair] == false, pair .. " non-collidable")
end
local kart = node("Model", "Kart")
local chassis = node("Part", "Chassis")
local seat = node("Part", "Seat")
local visual = node("Model", "Visual")
local wheel = node("Part", "WheelPivot")
visual:add(wheel)
kart:add(chassis)
kart:add(seat)
kart:add(visual)
isolation:bindKart(kart)
check(chassis.CollisionGroup == "RacerKart" and seat.CollisionGroup == "RacerKart"
	and wheel.CollisionGroup == "RacerKart", "kart chassis, seat, and visual parts isolated")
local lateKartPart = node("Part", "LateEffect")
visual:add(lateKartPart)
check(lateKartPart.CollisionGroup == "RacerKart", "late kart part isolated")

local character = node("Model", "Character")
local head = node("Part", "Head", "Default")
local root = node("Part", "HumanoidRootPart", "CustomAvatar")
local accessory = node("Accessory", "Hat")
local handle = node("Part", "Handle", "AccessoryCollision")
accessory:add(handle)
character:add(head)
character:add(root)
character:add(accessory)
local binding = isolation:bindDriver(character)
check(head.CollisionGroup == "RacerDriver" and root.CollisionGroup == "RacerDriver"
	and handle.CollisionGroup == "RacerDriver", "body, root, and accessory isolated")
local lateAccessory = node("Accessory", "LateHat")
character:add(lateAccessory)
local lateHandle = node("Part", "Handle", "LateOriginal")
lateAccessory:add(lateHandle)
check(lateHandle.CollisionGroup == "RacerDriver", "late accessory handle isolated")
local kartCount, driverCount, mismatches = isolation:audit(kart, character)
check(kartCount == 4 and driverCount == 4 and mismatches == 0, "collision audit clean")
binding:restore()
check(head.CollisionGroup == "Default" and root.CollisionGroup == "CustomAvatar"
	and handle.CollisionGroup == "AccessoryCollision" and lateHandle.CollisionGroup == "LateOriginal",
	"Garage/owner release restores each previous collision group")
local afterRestore = node("Part", "AfterRestore")
character:add(afterRestore)
check(afterRestore.CollisionGroup == "Default", "restored binding no longer intercepts descendants")
binding:restore()

local elapsed, recover = Recovery.advance(1, 0.1, 0.1, config)
check(elapsed == 0 and not recover, "upright never recovers")
elapsed, recover = Recovery.advance(0.3, 0, 0.05, config)
check(not recover, "short tilt does not recover")
elapsed, recover = Recovery.advance(0.3, elapsed, 0.05, config)
check(not recover, "tilt below sustained threshold does not recover")
elapsed, recover = Recovery.advance(0.3, elapsed, 0.03, config)
check(recover, "sustained tilt recovers")
elapsed, recover = Recovery.advance(0.7, elapsed, 0.01, config)
check(elapsed == 0 and not recover, "upright frame clears accumulated tilt")
elapsed, recover = Recovery.advance(-0.8, 0, 0.02, config)
check(not recover, "single inverted impulse not enough")
elapsed, recover = Recovery.advance(-0.8, elapsed, 0.02, config)
check(recover, "inverted kart recovers promptly")

local function fixture(speed)
	local position = V.new(14, 5, 9)
	local tilted = CF.new(position) * CF.Angles(0.2, 0.6, 1.2)
	local part = { CFrame = tilted, Position = position,
		AssemblyLinearVelocity = V.new(speed, 12, 0),
		AssemblyAngularVelocity = V.new(3, 1.5, -4) }
	local model = { CFrame = tilted }
	function model:PivotTo(cf) self.CFrame = cf; part.CFrame = cf end
	return model, part
end
for _, speed in { 70, 100 } do
	local model, part = fixture(speed)
	local headingBefore = Recovery.flatHeading(part.CFrame, V.new(0, 0, -1))
	local heading = Recovery.apply(model, part, V.new(0, 0, -1))
	check(part.CFrame.UpVector:Dot(V.yAxis) > 0.999, "recovered upright at " .. speed)
	check((part.CFrame.Position - V.new(14, 5, 9)).Magnitude < 0.001, "position preserved")
	check((heading - headingBefore).Magnitude < 0.001, "planar heading preserved")
	check(part.AssemblyLinearVelocity.Magnitude <= speed and part.AssemblyLinearVelocity.Y == 0,
		"no speed gain at " .. speed)
	check(part.AssemblyAngularVelocity.X == 0 and part.AssemblyAngularVelocity.Y == 1.5
		and part.AssemblyAngularVelocity.Z == 0, "roll/pitch removed and yaw retained")
end
local kartA, partA = fixture(70)
local kartB, partB = fixture(100)
local beforeB = partB.CFrame
local velocityB = partB.AssemblyLinearVelocity
local stateA, stateB = { tiltUnsafeElapsed = 0.13 }, { tiltUnsafeElapsed = 0 }
Recovery.apply(kartA, partA, V.new(0, 0, -1))
stateA.tiltUnsafeElapsed = 0
check(partB.CFrame == beforeB and partB.AssemblyLinearVelocity == velocityB
	and stateB.tiltUnsafeElapsed == 0, "other racer context and physics unaffected")
print(string.format("PASS kart contact: %d checks", count))
