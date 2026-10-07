-- Finite, non-stacking local presentation; no kart/input state references.
local Motion = {}
Motion.__index = Motion
function Motion.new(config)
	return setmetatable({ config = config }, Motion)
end
function Motion:clear() self.kind, self.born = nil, nil end
function Motion:play(kind, now)
	if kind ~= "Missile" and kind ~= "Thunder" then return false end
	self.kind, self.born = kind, now -- Replace, never sum overlapping impulses.
	return true
end
function Motion:sample(now)
	if not self.kind then return Vector3.zero, Vector3.zero, false end
	local c = self.config[self.kind].CameraShake
	local age = math.max(0, now - self.born)
	if age >= c.Duration then self:clear(); return Vector3.zero, Vector3.zero, false end
	-- One finite sequence: a short primary, then one weaker delayed aftershock.
	-- Select a pulse rather than sum them; a later hit replaces this whole sequence.
	local pulseAge = age
	local envelope = math.max(0, 1-age/c.PrimaryDuration)^2
	if age >= c.AftershockDelay then
		pulseAge = age-c.AftershockDelay
		envelope = c.AftershockScale * (1-pulseAge/(c.Duration-c.AftershockDelay))^2
	end
	local phase = pulseAge * c.Frequency * math.pi * 2
	local p = math.min(c.PositionAmplitude, self.config.Camera.MaxPositionAmplitude) * envelope
	local r = math.min(c.RotationAmplitude, self.config.Camera.MaxRotationAmplitude) * envelope
	local position = Vector3.new(math.sin(phase)*p, math.cos(phase*0.83)*p, 0)
	local rotation = Vector3.new(math.cos(phase)*r, math.sin(phase*0.71)*r*0.6, math.sin(phase*0.93)*r*0.4)
	if position.Magnitude > self.config.Camera.MaxPositionAmplitude then position = position.Unit*self.config.Camera.MaxPositionAmplitude end
	if rotation.Magnitude > self.config.Camera.MaxRotationAmplitude then rotation = rotation.Unit*self.config.Camera.MaxRotationAmplitude end
	return position, rotation, true
end
return Motion
