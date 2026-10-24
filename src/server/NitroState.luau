-- Pure state/speed policy owned exclusively by PrototypeWorld. No velocity writes.
local NitroState = {}
NitroState.__index = NitroState

local function approach(value, target, delta)
	return if value < target then math.min(value + delta, target) else math.max(value - delta, target)
end

function NitroState.new(config)
	return setmetatable({ config = config, active = false, endTime = 0, driver = nil, exiting = false }, NitroState)
end

function NitroState:activate(driver, now): (boolean, string?)
	if self.active then return false, "already_active" end
	self.active = true
	self.exiting = false
	self.driver = driver
	self.endTime = now + self.config.NITRO_DURATION
	return true
end

function NitroState:stop(reason: string)
	-- Only natural expiry keeps overspeed. Safety transitions clear everything.
	self.exiting = reason == "duration_complete" and self.active
	self.active = false
	self.endTime = 0
	if not self.exiting then self.driver = nil end
end

function NitroState:update(now, driver, driveEnabled, offTrack, crash, validInput)
	if not driveEnabled or crash or not validInput
		or ((self.active or self.exiting) and self.driver ~= driver) then
		self:stop("safety")
	elseif self.active and now >= self.endTime then
		self:stop("duration_complete")
	end
end

function NitroState:forwardSpeed(speed, miniBoost, throttle, dt, normalCap, offTrack)
	local c = self.config
	local rawTarget = if self.active then c.NITRO_MAX_SPEED
		elseif miniBoost then c.MINI_BOOST_MAX_SPEED else (normalCap or c.MAX_FORWARD_SPEED)
	local target = if offTrack and (self.active or miniBoost) then rawTarget * c.OFF_TRACK_BOOST_SPEED_MULTIPLIER
		elseif offTrack then (c.OFF_TRACK_MAX_SPEED or 60)
		else rawTarget
	local rate = if self.active then (if speed > target then c.BRAKE_FORCE else c.NITRO_ACCELERATION)
		elseif speed > target then (if offTrack then c.BRAKE_FORCE else c.NITRO_EXIT_DECELERATION)
		elseif miniBoost then c.MINI_BOOST_ACCELERATION else c.ACCELERATION
	return approach(speed, target, rate * (if speed > target then 1 else throttle) * dt)
end

function NitroState:finishStep(speed, normalCap)
	if not self.active and speed <= (normalCap or self.config.MAX_FORWARD_SPEED) then
		self.exiting = false
		self.driver = nil
	end
end

return NitroState
