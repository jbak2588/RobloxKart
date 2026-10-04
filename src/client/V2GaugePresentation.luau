-- Speed-synchronized tachometer presentation only; never controls engine audio.
local Presentation = {}
function Presentation.new()
	local self={rpm=700,peak=5000}
	function self:update(speed,dt,boosting,nitro)
		speed=math.abs(speed)
		if nitro then self.peak=7000
		elseif boosting then self.peak=5000
		elseif speed<=70 then self.peak=5000 end
		local normal=700+1800*math.clamp(speed/70,0,1)
		local target=normal+(self.peak-2500)*math.clamp((speed-70)/30,0,1)
		self.rpm+=(target-self.rpm)*(1-math.exp(-math.clamp(dt,0,.1)/.12))
		return {rpm=self.rpm,speedKmh=speed*1.008}
	end
	return self
end
return Presentation
