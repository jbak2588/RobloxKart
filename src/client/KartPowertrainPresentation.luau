-- Virtual transmission only: numeric inputs, no Instances, remotes or physics writes.
local Powertrain = {}
Powertrain.__index = Powertrain
Powertrain.SPEED_TO_KMH = 1.008
Powertrain.IDLE_RPM = 900
Powertrain.REDLINE_RPM = 9000
Powertrain.MAX_RPM = 10000
Powertrain.SHIFT_SECONDS = .18
local function finite(value, fallback)
	return if type(value)=="number" and value==value and math.abs(value)<math.huge then value else fallback
end
function Powertrain.new()
	return setmetatable({gear=1,rpm=900,shiftRemaining=0,shiftSerial=0,previousSpeed=0,load=.3,coast=0,audioTime=0},Powertrain)
end
function Powertrain:update(speed, dt, options)
	options=options or {}
	speed=math.max(0,finite(speed,0));dt=math.clamp(finite(dt,0),0,.25)
	self.shiftRemaining=math.max(0,self.shiftRemaining-dt)
	local previous=self.gear
	if options.reverse and speed>1 then self.gear="R"
	else
		if self.gear=="R" then self.gear=1 end
		if self.shiftRemaining==0 then
			if self.gear==1 and speed>=28 then self.gear=2
			elseif self.gear==2 and speed>=50 then self.gear=3
			elseif self.gear==3 and speed<=45 then self.gear=2
			elseif self.gear==2 and speed<=24 then self.gear=1 end
		end
	end
	if previous~=self.gear then self.shiftSerial+=1;self.shiftRemaining=Powertrain.SHIFT_SECONDS end
	local target
	if self.gear=="R" then target=900+math.clamp(speed/24,0,1)*4100
	elseif self.gear==1 then target=900+math.clamp(speed/28,0,1)*7400
	elseif self.gear==2 then target=4300+math.clamp((speed-24)/26,0,1)*4000
	else target=4700+math.clamp((speed-45)/25,0,1)*3800+math.clamp((speed-70)/30,0,1)*1500 end
	local response=if self.shiftRemaining>0 then 20 else 12
	self.rpm+=(target-self.rpm)*(1-math.exp(-response*dt))
	local acceleration=if dt>0 then (speed-self.previousSpeed)/dt else 0
	local load=finite(options.throttle,math.clamp(.45+acceleration/45+speed/200,.3,1))
	-- Original AC6 donor: idle throttle threshold 3%, .3..1 volume envelope.
	local accelerating=math.abs(load)>.03
	self.load=if accelerating then math.min(1,self.load+3*dt) else math.max(.3,self.load-6*dt)
	self.coast=if accelerating then 1 else math.max(0,self.coast-1.5*dt)
	self.audioTime+=dt
	self.previousSpeed=speed
	local normalized=math.clamp((self.rpm-900)/9100,0,1)
	local shift= self.shiftRemaining/Powertrain.SHIFT_SECONDS
	return {speedStuds=speed,speedKmh=speed*Powertrain.SPEED_TO_KMH,gear=self.gear,rpm=self.rpm,
		normalizedRpm=normalized,load=self.load,throttle=self.load,shiftActive=shift>0,
		shiftSerial=self.shiftSerial,redline=self.rpm>=9000,
		-- Donor SetPitch=0, SetRev=1.2, Redline=10000. Never restart the Sound.
		playbackSpeed=1.2*self.rpm/10000,
		volume=self.load*(1-shift*.8)*(if self.rpm>9875 and accelerating then .5 else 1)
			+(if accelerating then 0 else .4*self.coast*(1-self.load)*math.sin(self.audioTime*50))}
end
return Powertrain
