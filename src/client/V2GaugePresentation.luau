-- Donor two-ratio tachometer reference, visual only. No input or audio ownership.
local Presentation = {}
local diameter = 1.51524
local ratios = {2.39, 1.18}
local finalDrive = 7.5
function Presentation.new()
	local self = {rpm=700, ratio=1, rpmElapsed=0, shiftElapsed=0}
	function self:update(speed, dt)
		dt = math.clamp(dt, 0, .1)
		speed = math.abs(speed)
		self.rpmElapsed += dt
		self.shiftElapsed += dt
		while self.rpmElapsed >= 1/60 do
			self.rpmElapsed -= 1/60
			local target = math.clamp(speed/(diameter/2)*ratios[self.ratio]*finalDrive*30/math.pi, 700, 10100)
			local clutch = math.min(math.abs(target-self.rpm)/500, .9)
			self.rpm = self.rpm*clutch+target*(1-clutch)
			if self.rpm > 10000 then self.rpm -= if self.ratio < 2 then 500 else 250 end
		end
		while self.shiftElapsed >= .0667 do
			self.shiftElapsed -= .0667
			local wheelRatio = diameter*math.pi/60
			if speed > math.ceil(wheelRatio*8800/ratios[self.ratio]/finalDrive) then
				self.ratio = math.min(2, self.ratio+1)
			elseif self.ratio > 1 and speed < math.ceil(wheelRatio*7600/ratios[self.ratio-1]/finalDrive) then
				self.ratio -= 1
			end
		end
		return {rpm=self.rpm, speedKmh=speed*1.008}
	end
	return self
end
return Presentation
