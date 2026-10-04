-- Client presentation only: no transmission, velocity or control writes.
local Powertrain = {}
local UP = {15, 30, 45, 60}
local DOWN = {12, 27, 42, 56}
local LOW = {0, 15, 30, 45}
local BASE = {1000, 3300, 3400, 3500}
local TOP = {7200, 7400, 7600, 7800}
function Powertrain.baseRpm(gear, kmh)
	if gear == 5 then
		if kmh <= 71 then return 4200 + math.clamp((kmh-60)/11, 0, 1)*2400 end
		return 6600 + math.clamp((kmh-71)/30, 0, 1)*3000
	end
	return BASE[gear] + math.clamp((kmh-LOW[gear])/15, 0, 1)*(TOP[gear]-BASE[gear])
end
function Powertrain.new()
	local self = {gear=1, elapsed=0, lastKmh=0, acceleration=0, rpm=1000,
		load=0, shiftRemaining=0, shiftSerial=0, variation=0, loadVariation=0}
	function self:update(speed, dt, input)
		input = input or {}
		dt = math.clamp(dt, 0, .1)
		local kmh = math.abs(speed)*1.008
		self.elapsed += dt
		local acceleration = if dt > 0 then (kmh-self.lastKmh)/dt else 0
		self.lastKmh = kmh
		self.acceleration += (acceleration-self.acceleration)*(1-math.exp(-8*dt))
		local oldGear = self.gear
		while self.gear < 5 and kmh >= UP[self.gear] do self.gear += 1 end
		while self.gear > 1 and kmh < DOWN[self.gear-1] do self.gear -= 1 end
		if oldGear ~= self.gear then
			self.shiftSerial += 1
			self.shiftRemaining = .14
			-- Commit the new RPM together with the new gear; never show an old-gear redline.
			self.rpm = Powertrain.baseRpm(self.gear, kmh)
		else
			self.shiftRemaining = math.max(0, self.shiftRemaining-dt)
		end
		local throttle = math.clamp(input.throttle or 0, 0, 1)
		local steady = kmh >= 55 and math.abs(self.acceleration) < 2
		local amplitude = if steady then .03 elseif self.acceleration < -2 then .015 else .004
		local noise = math.clamp(2*(.65*math.noise(self.elapsed*.43, 7.31, 0)
			+.35*math.noise(self.elapsed*.227, 19.71, 0)), -1, 1)
		local loadNoise = math.clamp(2*math.noise(self.elapsed*.317, 29.37, 0), -1, 1)
		local alpha = 1-math.exp(-5*dt)
		self.variation += (noise*amplitude-self.variation)*alpha
		self.loadVariation += (loadNoise*(if steady then .04 else .01)-self.loadVariation)*alpha
		local targetRpm = Powertrain.baseRpm(self.gear, kmh)*(1+self.variation)
		self.rpm += (targetRpm-self.rpm)*(1-math.exp(-12*dt))
		local targetLoad = if kmh < 1 then throttle*.15 elseif steady then .4*throttle else .8*throttle
		if input.boost then targetLoad = 1 end
		self.load += (targetLoad-self.load)*alpha
		local shiftActive = self.shiftRemaining > 0
		local load = math.clamp((self.load+self.loadVariation)*(if shiftActive then .72 else 1), 0, 1)
		local rpm = math.clamp(self.rpm, 900, 9800)
		return {speedStuds=speed, speedKmh=kmh, gear=self.gear, rpm=rpm,
			normalizedRpm=math.clamp((rpm-1000)/8800,0,1), load=load, throttle=throttle,
			shiftActive=shiftActive, shiftSerial=self.shiftSerial, boost=input.boost==true,
			redline=rpm>=9000, variation=self.variation, acceleration=self.acceleration}
	end
	return self
end
return Powertrain
