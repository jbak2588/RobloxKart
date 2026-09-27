-- Observes existing simulation values. Never changes charge or boost decisions.
local Telemetry = {}
Telemetry.__index = Telemetry

function Telemetry.progress(duration, qualified, config)
	return math.min(math.clamp(duration/config.DRIFT_CHARGE_MIN_DURATION,0,1),
		math.clamp(qualified/config.DRIFT_CHARGE_REQUIRED_TIME,0,1)),
		duration >= config.DRIFT_CHARGE_MIN_DURATION and qualified >= config.DRIFT_CHARGE_REQUIRED_TIME
end

function Telemetry.new(kart, config, logger)
	local self=setmetatable({kart=kart,config=config,logger=logger or print,elapsed=0,
		active=false,maxAge=0,maxDelta=0,endSerial=0,session=0,retain=0,
		frame={age=0,delta=0,speed=0,slip=0,steer=0,raw=0,throttle=0,valid=false}},Telemetry)
	self:clear()
	return self
end

function Telemetry:set(name,value)
	if self.kart:GetAttribute(name)~=value then self.kart:SetAttribute(name,value) end
end

function Telemetry:clearCharge()
	self:set("KartDriftChargeProgress",0)
	self:set("KartDriftChargeReady",false)
end

function Telemetry:clear()
	self:clearCharge()
	self.retain=0
	if not self.config.DEBUG_TELEMETRY then return end
	for _,key in {"Duration","Qualified","SlipDegrees","InputAge","MaxInputAge","ServerDelta","MaxServerDelta","Speed","Steering","RawSteering","Throttle"} do
		self:set("KartDriftDiag"..key,0)
	end
	self:set("KartDriftDiagEndReason","")
	self:set("KartDriftDiagBoostEligible",false)
	self:set("KartDriftDiagInputValid",false)
	self:set("KartDriftDiagEndSerial",self.endSerial)
	self:set("KartDriftDiagSession",self.session)
end

function Telemetry:observe(age,delta,speed,slip,raw,steer,throttle,valid)
	self.elapsed+=delta
	self.frame={age=age or 0,delta=delta,speed=speed,slip=slip,raw=raw,steer=steer,throttle=throttle,valid=valid}
	if self.active then
		self.maxAge=math.max(self.maxAge,age or 0)
		self.maxDelta=math.max(self.maxDelta,delta)
	elseif self.retain>0 then
		self.retain-=delta
		if self.retain<=0 then self:clear() end
	end
end

function Telemetry:begin()
	self:clear()
	self.active=true
	self.session+=1
	self.maxAge,self.maxDelta=self.frame.age,self.frame.delta
	self.elapsed=0.1
end

function Telemetry:diagnostic(duration,qualified,reason,eligible)
	if not self.config.DEBUG_TELEMETRY then return end
	local f=self.frame
	local values={Duration=duration,Qualified=qualified,SlipDegrees=f.slip,InputAge=f.age,
		MaxInputAge=self.maxAge,ServerDelta=f.delta,MaxServerDelta=self.maxDelta,
		Speed=f.speed,Steering=f.steer,RawSteering=f.raw,Throttle=f.throttle,InputValid=f.valid,
		EndReason=reason or "",BoostEligible=eligible==true,Session=self.session}
	for key,value in values do self:set("KartDriftDiag"..key,value) end
end

function Telemetry:update(duration,qualified)
	-- Before entry, expose current speed/slip/input validity too, so a held
	-- button with no accepted drift does not misleadingly show all zeros.
	if self.elapsed<0.1 or (not self.active and self.retain>0) then return end
	self.elapsed=0
	if not self.active then
		self:diagnostic(0,0)
		return
	end
	local progress,ready=Telemetry.progress(duration,qualified,self.config)
	self:set("KartDriftChargeProgress",progress)
	self:set("KartDriftChargeReady",ready)
	self:diagnostic(duration,qualified)
end

function Telemetry:finish(reason,duration,qualified,eligible)
	if not self.active then return end
	self.active=false
	self:clearCharge()
	self:diagnostic(duration,qualified,reason,eligible)
	self.retain=2
	if not self.config.DEBUG_TELEMETRY then return end
	self.endSerial+=1
	self:set("KartDriftDiagEndSerial",self.endSerial)
	local f,c=self.frame,self.config
	self.logger(string.format("[KartDriftDiag] session=%d end=%s boostEligible=%s duration=%.2f/%.2f qualified=%.2f/%.2f slip=%.1f/%.1f speed=%.1f rawSteer=%.2f steer=%.2f throttle=%.2f inputValid=%s inputAge=%.3f maxInputAge=%.3f serverDelta=%.3f maxServerDelta=%.3f",
		self.session,reason,tostring(eligible==true),duration,c.DRIFT_CHARGE_MIN_DURATION,qualified,c.DRIFT_CHARGE_REQUIRED_TIME,
		f.slip,c.DRIFT_CHARGE_MIN_SLIP_DEGREES,f.speed,f.raw,f.steer,f.throttle,tostring(f.valid),f.age,self.maxAge,f.delta,self.maxDelta))
end

return Telemetry
