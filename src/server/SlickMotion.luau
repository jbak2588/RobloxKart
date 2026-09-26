-- Short yaw disruption, then continuous alignment to legal course direction.
-- PrototypeWorld alone applies the returned planar movement.
local SlickMotion = {}
SlickMotion.__index = SlickMotion
local function angle(from, to) return math.atan2(from:Cross(to).Y, from:Dot(to)) end

function SlickMotion.new(config)
	return setmetatable({ config = config, active = false }, SlickMotion)
end
function SlickMotion:stop() self.active = false; self.driver = nil end
function SlickMotion:start(driver, now, forward, legalForward, speed)
	self.active, self.driver, self.started = true, driver, now
	self.legal = legalForward
	self.initialAngle = angle(legalForward, forward)
	self.speed = math.max(0, speed) * self.config.SLICK_SPEED_RETAIN
end
function SlickMotion:sample(now, forward)
	local c = self.config
	local t = math.clamp((now-self.started)/c.SLICK_EFFECT_DURATION, 0, 1)
	local smooth = t*t*(3-2*t)
	local desiredAngle = self.initialAngle*(1-smooth) + c.SLICK_YAW_AMPLITUDE*math.sin(math.pi*t)^2
	local derivative = (-self.initialAngle*6*t*(1-t) + c.SLICK_YAW_AMPLITUDE*math.pi*math.sin(2*math.pi*t))/c.SLICK_EFFECT_DURATION
	local current = angle(self.legal, forward)
	local errorAngle = math.atan2(math.sin(desiredAngle-current), math.cos(desiredAngle-current))
	local yaw = math.clamp(derivative + errorAngle*c.SLICK_ALIGNMENT_GAIN, -c.SLICK_MAX_YAW_RATE, c.SLICK_MAX_YAW_RATE)
	return self.legal*self.speed, yaw, t >= 1
end
return SlickMotion
