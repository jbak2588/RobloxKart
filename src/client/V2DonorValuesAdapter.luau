-- Presentation only. AC6 Drive RPM()/Engine() equations; no chassis writes.
local Adapter = {}
Adapter.__index = Adapter
Adapter.WHEEL_DIAMETER = 1.51524 -- largest original driven wheel Size.X (RL)
Adapter.FINAL_DRIVE = 5 * 1.5
Adapter.RATIOS = {[-1]=3.70, [0]=0, [1]=2.39, [2]=1.18}
local fFDr = Adapter.FINAL_DRIVE * 30 / math.pi
local wDRatio = Adapter.WHEEL_DIAMETER * math.pi / 60
function Adapter.new()
	return setmetatable({RPM=700,Gear=1,Throttle=.03,TransmissionMode="Auto",Redline=10000,
		rpmElapsed=0,shiftElapsed=0,shiftSerial=0},Adapter)
end
function Adapter:update(speed,dt,options)
	options=options or {}
	self.Throttle=math.max(.03,math.clamp(options.throttle or 0,0,1))
	self.Velocity=options.velocity
	local desired=if options.neutral then 0 elseif options.reverse then -1 elseif self.Gear<=0 then 1 else self.Gear
	if desired<0 or desired==0 or self.Gear<=0 then self.Gear=desired; if desired>0 then self.Gear=1 end end
	self.rpmElapsed+=dt;self.shiftElapsed+=dt
	-- Legacy Stepped RPM cadence ~60 Hz and Engine/automatic cadence .0667 sec.
	while self.rpmElapsed>=1/60 do
		self.rpmElapsed-=1/60
		if self.Gear==0 then
			self.RPM=if self.Throttle>.03 then math.min(self.RPM+150*self.Throttle,10100) else math.max(self.RPM-75,700)
		else
			local maxSpin=speed/(Adapter.WHEEL_DIAMETER/2)
			local aRPM=math.max(math.min(maxSpin*Adapter.RATIOS[self.Gear]*fFDr,10100),700)
			local clutchP=math.min(math.abs(aRPM-self.RPM)/500,.9)
			self.RPM=self.RPM*clutchP+aRPM*(1-clutchP)
		end
		if self.RPM>10000 then self.RPM-=if self.Gear<2 then 500 else 250 end
	end
	while self.shiftElapsed>=.0667 do
		self.shiftElapsed-=.0667
		local previous=self.Gear
		if self.Gear>=1 and not options.reverse and not options.neutral then
			if speed>math.ceil(wDRatio*8800/Adapter.RATIOS[self.Gear]/Adapter.FINAL_DRIVE) then self.Gear=math.min(self.Gear+1,2)
			elseif self.Gear>1 and speed<math.ceil(wDRatio*7600/Adapter.RATIOS[self.Gear-1]/Adapter.FINAL_DRIVE) then self.Gear=math.max(self.Gear-1,1) end
		end
		if previous~=self.Gear then self.shiftSerial+=1 end
	end
	return {RPM=self.RPM,Gear=self.Gear,Throttle=self.Throttle,Velocity=self.Velocity,
		TransmissionMode=self.TransmissionMode,Redline=self.Redline,IsOn=options.isOn~=false,
		speedKmh=speed*1.008,shiftSerial=self.shiftSerial}
end
return Adapter
