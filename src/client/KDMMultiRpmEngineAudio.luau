-- Same-source architecture prototype. These are NOT five distinct recorded RPM samples.
local Mixer = {}
Mixer.ASSET = "rbxassetid://290290922"
Mixer.BANDS = {1000,2800,4800,6800,9000}
Mixer.PHASES = {0,.17,.39,.63,.81}
Mixer.DETUNES = {.994,.998,1,1.004,1.008}
function Mixer.calculate(state)
	local rpm = math.clamp(state.rpm, 1000, 9800)
	local lo = 1
	while lo < 4 and rpm >= Mixer.BANDS[lo+1] do lo += 1 end
	local t = math.clamp((rpm-Mixer.BANDS[lo])/(Mixer.BANDS[lo+1]-Mixer.BANDS[lo]),0,1)
	local gains = {0,0,0,0,0}
	if t <= 0 then gains[lo]=1 elseif t >= 1 then gains[lo+1]=1
	else gains[lo]=math.cos(t*math.pi/2);gains[lo+1]=math.sin(t*math.pi/2) end
	local volume = math.clamp(.3+.6*state.load, .25, if state.boost then .95 else .9)
	local pitches, volumes = {}, {}
	for i, band in Mixer.BANDS do
		-- Narrow transformations of one sample; broad pitch synthesis would misrepresent the source.
		local pitch = 1 + math.clamp((rpm-band)/band,-1,1)*.1
		if state.shiftActive then pitch *= .98 end
		pitches[i] = math.clamp(pitch*Mixer.DETUNES[i], .88, 1.12)
		volumes[i] = volume*gains[i]
	end
	return {gains=gains,pitches=pitches,volumes=volumes,volume=volume,low=lo,high=lo+1}
end
function Mixer.new(primary)
	local self = {voices={primary}, ready=false, destroyed=false, state=nil,
		stats={play=0, initialSeek=0, stop=0, runtimePlay=0, runtimeSeek=0}}
	primary.Volume=0
	for i=2,5 do
		local voice=primary:Clone()
		voice.Name="KDMEngineLayer"..i
		voice.Volume=0;voice.Parent=primary.Parent
		table.insert(self.voices,voice)
	end
	function self:tryStart()
		if self.ready or self.destroyed then return end
		for _, voice in self.voices do
			if not voice.IsLoaded or voice.TimeLength <= 0 then return end
		end
		-- Initial loading/phase setup only. No seeks or restarts exist in update().
		for i, voice in self.voices do
			voice.Looped=true;voice.PlaybackRegionsEnabled=false
			voice.PlaybackSpeed=Mixer.DETUNES[i]
			voice.TimePosition=voice.TimeLength*Mixer.PHASES[i]
			self.stats.initialSeek+=1
			voice:Play();self.stats.play+=1
		end
		self.ready=true
	end
	function self:update(state)
		if self.destroyed then return end
		self.state=state
		if not state then
			for i=2,5 do self.voices[i].Volume=0 end
			return
		end
		local mix=Mixer.calculate(state)
		for i, voice in self.voices do voice.Volume=mix.volumes[i];voice.PlaybackSpeed=mix.pitches[i] end
		self.mix=mix
	end
	function self:destroy()
		if self.destroyed then return end
		self.destroyed=true
		-- The audio controller owns primary's detach Stop/Destroy; avoid double teardown.
		for i=2,5 do self.voices[i]:Stop();self.stats.stop+=1;self.voices[i]:Destroy() end
	end
	return self
end
return Mixer
