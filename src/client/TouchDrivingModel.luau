-- Pure input math and finger ownership. No Roblox services or physics rules.
local Model = {}
Model.__index = Model
Model.DEAD_ZONE = 0.10
-- Same full digital steering as PC; server drift controls slip and speed limits.
Model.DIGITAL_DRIFT_STEERING = 1.0
-- Development-only rollback switch; no player-facing settings menu.
Model.MobileDriveControlMode = "Buttons"

function Model.sample(dx: number, dy: number, radius: number, deadZone: number?)
	if radius <= 0 or dx ~= dx or dy ~= dy or math.abs(dx) == math.huge or math.abs(dy) == math.huge then return 0, 0, 0, 0 end
	local x, y = dx / radius, -dy / radius -- screen up means positive throttle
	local length = math.sqrt(x*x + y*y)
	if length > 1 then x /= length; y /= length end
	local zone = math.clamp(deadZone or Model.DEAD_ZONE, 0, 0.3)
	local function axis(value)
		return math.sign(value) * math.clamp((math.abs(value)-zone)/(1-zone), 0, 1)
	end
	-- Contact at center/sideways means forward. Only deliberate downward travel
	-- overrides forward with the existing negative brake/reverse action.
	return if y < -zone then axis(y) else 1, axis(x), x, -y
end

function Model.new(mode: string?)
	return setmetatable({ mode = mode or Model.MobileDriveControlMode, buttons = {}, pressSerial = 0,
		owner = nil, throttle = 0, steering = 0, knobX = 0, knobY = 0, driftOwners = {}, autoForward = false }, Model)
end

function Model:pressButton(id, action: string)
	if self.mode ~= "Buttons" or self.owner == id or self.driftOwners[id] or self.buttons[id] then return false end
	if action ~= "Forward" and action ~= "ForwardLeft" and action ~= "ForwardRight" and action ~= "BrakeReverse" then return false end
	self.pressSerial += 1
	self.buttons[id] = { action = action, serial = self.pressSerial }
	return true
end

function Model:isPressed(action: string): boolean
	for _, held in self.buttons do if held.action == action then return true end end
	return false
end

function Model:toggleAutoForward()
	self.autoForward = not self.autoForward
end

function Model:move(id, dx: number, dy: number, radius: number, deadZone: number?)
	if self.owner ~= id then return false end
	self.throttle, self.steering, self.knobX, self.knobY = Model.sample(dx, dy, radius, deadZone)
	return true
end

function Model:begin(id, dx: number, dy: number, radius: number, deadZone: number?)
	if self.mode ~= "Joystick" or self.owner or self.driftOwners[id] or self.buttons[id] then return false end
	self.owner = id
	return self:move(id, dx, dy, radius, deadZone)
end

function Model:pressDrift(id)
	if self.owner == id or self.buttons[id] then return false end
	self.driftOwners[id] = true
	return true
end

function Model:release(id)
	self.buttons[id] = nil
	self.driftOwners[id] = nil
	if self.owner == id then
		self.owner = nil
		self.throttle, self.steering, self.knobX, self.knobY = 0, 0, 0, 0
	end
end

function Model:reset()
	self.autoForward = false
	self.owner = nil
	self.throttle, self.steering, self.knobX, self.knobY = 0, 0, 0, 0
	table.clear(self.driftOwners)
	table.clear(self.buttons)
	self.pressSerial = 0
end

function Model:actions(): (number, number, boolean)
	if self.mode == "Buttons" then
		local steering, last = 0, 0
		for _, held in self.buttons do
			if (held.action == "ForwardLeft" or held.action == "ForwardRight") and held.serial > last then
				last = held.serial
				steering = if held.action == "ForwardLeft" then -1 else 1
			end
		end
		-- Negative throttle is the existing shared brake/reverse action.
		local drifting = next(self.driftOwners) ~= nil
		if drifting then steering *= Model.DIGITAL_DRIFT_STEERING end
		local throttle = if self:isPressed("BrakeReverse") then -1
			elseif self.autoForward or self:isPressed("Forward") then 1 else 0
		return throttle, steering, drifting
	end
	local throttle = if self.owner then self.throttle elseif self.autoForward then 1 else 0
	return throttle, self.steering, next(self.driftOwners) ~= nil
end

return Model
