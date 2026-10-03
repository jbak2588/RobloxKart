-- AC6_Sound_Mod numeric transplant. Remote transport replaced by local Sound writes.
local Audio = {}
Audio.__index = Audio
function Audio.new()
	return setmetatable({mult=0,trmmult=0,throt=0,shift=0,on=0,elapsed=0,previousGear=nil},Audio)
end
function Audio:update(state,dt,clock)
	if self.previousGear~=nil and self.previousGear~=state.Gear then
		self.mult=1
		if state.RPM>5000 then self.shift=.2 end
	end
	self.previousGear=state.Gear
	self.elapsed+=dt
	-- Original wait() envelope, approximately 30 Hz; deterministic accumulator.
	while self.elapsed>=1/30 do
		self.elapsed-=1/30
		self.mult=math.max(0,self.mult-.1)
		local trmon
		if state.Throttle<=.03 then
			self.throt=math.max(.3,self.throt-.2);self.trmmult=math.max(0,self.trmmult-.05);trmon=1
		else self.throt=math.min(1,self.throt+.1);self.trmmult=1;trmon=0 end
		self.shift=math.min(1,self.shift+.2)
		local redline=if state.RPM>10000-500/4 and state.Throttle>.03 then .5 else 1
		self.on=if state.IsOn then 1 else math.max(self.on-.015,0)
		self.volume=self.throt*self.shift*redline+.4*trmon*self.trmmult*(1-self.throt)*math.sin(clock*50)
		self.pitch=math.max((0+1.2*state.RPM/10000)*self.on+.13*self.mult*math.sin(80*clock),0)
	end
	return self.pitch or 0,self.volume or 0
end
return Audio
