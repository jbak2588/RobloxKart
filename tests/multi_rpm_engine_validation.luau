local fs, luau = require("@lune/fs"), require("@lune/luau")
local P = luau.load(fs.readFile("src/client/KDMEnginePowertrainPresentation.luau"))()
local M = luau.load(fs.readFile("src/client/KDMMultiRpmEngineAudio.luau"))()
local checks = 0
local function check(value, message) assert(value, message); checks += 1 end
local function step(model, kmh, n, throttle)
	local s
	for _=1,n or 1 do s=model:update(kmh/1.008, 1/60, {throttle=throttle or 1}) end
	return s
end
local p=P.new()
for gear, kmh in {0,15,30,45,60} do
	local s=step(p,kmh,30)
	check(s.gear==gear,"exact up threshold")
end
for _, pair in {{56,5},{55.9,4},{42,4},{41.9,3},{27,3},{26.9,2},{12,2},{11.9,1}} do
	check(step(p,pair[1]).gear==pair[2],"exact down hysteresis")
end
for _, pair in {{15,2},{30,3},{45,4},{60,5}} do
	local q=P.new();step(q,pair[1]-.2,180)
	local before=q.rpm;local s=step(q,pair[1])
	check(s.gear==pair[2] and s.shiftActive and s.rpm<before-1000,"same-frame upshift RPM drop")
	check(not step(q,pair[1],12).shiftActive,"140ms shift completes")
	local serial=q.shiftSerial
	for i=1,240 do step(q,pair[1]+math.sin(i)*.2) end
	check(q.shiftSerial==serial,"threshold oscillation cannot chatter")
end
for _, pair in {{60,4200},{71,6600},{101,9600}} do
	check(math.abs(P.baseRpm(5,pair[1])-pair[2])<.001,"gear5 target RPM")
end
for rpm=1000,9800,10 do
	local mix=M.calculate({rpm=rpm,load=.5,boost=false,shiftActive=false})
	local power, audible=0,0
	for i=1,5 do
		power+=mix.gains[i]^2
		if mix.gains[i]>1e-8 then audible+=1 end
		check(mix.volumes[i]>=0 and mix.volumes[i]<=.9,"volume bounds")
		check(mix.pitches[i]>=.88 and mix.pitches[i]<=1.12,"narrow pitch")
	end
	check(math.abs(power-1)<1e-12 and audible<=2,"constant power, adjacent voices only")
end
local middle=M.calculate({rpm=5800,load=.5})
check(math.abs(middle.gains[3]-math.sqrt(.5))<1e-12 and math.abs(middle.gains[4]-math.sqrt(.5))<1e-12,"midpoint gains")
-- Real transport mock: count actual assignments/calls, including pending load cancellation.
local function sound()
	local values={IsLoaded=false,TimeLength=0,Parent={},TimePosition=0}
	local s={calls={play=0,stop=0,seek=0,destroy=0}}
	setmetatable(s,{__index=values,__newindex=function(_,key,value)
		if key=="TimePosition" then s.calls.seek+=1 end
		values[key]=value
	end})
	function values.Play() s.calls.play+=1 end
	function values.Stop() s.calls.stop+=1 end
	function values.Destroy() s.calls.destroy+=1 end
	function values.Clone() return sound() end
	return s
end
local primary=sound();local mixer=M.new(primary)
for _=1,100 do mixer:tryStart() end
check(mixer.stats.play==0 and mixer.stats.initialSeek==0,"wait for known asset length")
for _,v in mixer.voices do v.IsLoaded=true;v.TimeLength=2.8894331066 end
mixer:tryStart()
for i,v in mixer.voices do
	check(v.calls.play==1 and v.calls.seek==1 and v.calls.stop==0,"one attach Play/seed")
	check(math.abs(v.TimePosition-v.TimeLength*M.PHASES[i])<1e-12,"exact seeded phase")
end
local positions=table.clone(M.PHASES)
local lastWrap={-100,-100,-100,-100,-100}
local coincidences=0
local model=P.new()
local minRpm,maxRpm,lastRpm,minPitch,maxPitch,minVolume,maxVolume=math.huge,0,nil,math.huge,0,math.huge,0
for frame=1,7320 do
	local state=model:update(70,1/60,{throttle=1})
	mixer:tryStart();mixer:update(state)
	check(mixer.state==state and state.speedStuds==70 and state.speedKmh==70*1.008,"unchanged speed/shared state")
	check(state.gear==5 and state.rpm==state.rpm and state.load>=0 and state.load<=1,"gear/state finite")
	if frame>120 then
		minRpm=math.min(minRpm,state.rpm);maxRpm=math.max(maxRpm,state.rpm)
		check(math.abs(state.variation)<=.03 and math.abs(state.rpm-(P.baseRpm(5,state.speedKmh)))<=P.baseRpm(5,state.speedKmh)*.035,"bounded cruise variation")
		if lastRpm then check(math.abs(state.rpm-lastRpm)<12,"no needle jitter") end
		lastRpm=state.rpm
		for i,v in mixer.voices do
			minPitch=math.min(minPitch,v.PlaybackSpeed);maxPitch=math.max(maxPitch,v.PlaybackSpeed)
			minVolume=math.min(minVolume,v.Volume);maxVolume=math.max(maxVolume,v.Volume)
			local previous=positions[i]
			local delta=v.PlaybackSpeed/60/v.TimeLength
			positions[i]=(previous+delta)%1
			if previous+delta>=1 and v.Volume>.01 then
				local now=frame/60-(previous+delta-1)*v.TimeLength/v.PlaybackSpeed
				for j=1,5 do if j~=i and mixer.voices[j].Volume>.01 and math.abs(now-lastWrap[j])<=.03 then coincidences+=1 end end
				lastWrap[i]=now
			end
		end
	end
end
check(maxRpm-minRpm>50,"steady cruise breathes")
check(mixer.stats.play==5 and mixer.stats.initialSeek==5,"no restart/seek after load")
for _,v in mixer.voices do check(v.calls.play==1 and v.calls.seek==1 and v.calls.stop==0,"actual transport runtime contract") end
check(mixer:update(nil)==nil,"comparison mode mutes extras without playback churn")
for i=2,5 do check(mixer.voices[i].Volume==0,"silent comparison layers") end
mixer:destroy();mixer:destroy();mixer:tryStart()
for i=2,5 do check(mixer.voices[i].calls.stop==1 and mixer.voices[i].calls.destroy==1,"idempotent detach") end
check(primary.calls.stop==0,"controller retains primary teardown ownership")
local cancelled=M.new(sound());cancelled:destroy()
for _,v in cancelled.voices do v.IsLoaded=true;v.TimeLength=2.9 end
cancelled:tryStart();check(cancelled.stats.play==0,"late load cannot revive destroyed owner")
local nitro=step(model,100*1.008,180)
check(nitro.gear==5 and nitro.rpm>=9000 and nitro.rpm<=9800,"Nitro redline presentation")
-- Execute the real experiment coordinator: gauge and mixer receive the exact same object.
local attributes={KDMV2DonorExperiment=true,KDMEngineExperimentMode="MULTI_RPM"}
local studio=true
local workspace={GetAttribute=function(_,key) return attributes[key] end}
local gaugeState
local modules={KDMEnginePowertrainPresentation=P,
	V2DonorValuesAdapter=luau.load(fs.readFile("src/client/V2DonorValuesAdapter.luau"))(),
	V2DonorAudio=luau.load(fs.readFile("src/client/V2DonorAudio.luau"))(),
	KartPowertrainPresentation=luau.load(fs.readFile("src/client/KartPowertrainPresentation.luau"))(),
	V2DonorGauge={new=function() return {destroy=function() end,update=function(_,s) gaugeState=s end} end}}
local env={game={GetService=function(_,name)
	return if name=="Workspace" then workspace else {IsStudio=function() return studio end}
end},script={Parent={WaitForChild=function(_,name) return name end}},
	require=function(name) return assert(modules[name],name) end,tick=function() return 5 end}
local E=luau.load(fs.readFile("src/client/V2DonorExperiment.luau"),{environment=env})()
local observed
E.bindMixer({update=function(_,s) observed=s end})
local chassis={AssemblyLinearVelocity={Dot=function() return 70 end},CFrame={LookVector={}},
	FindFirstChild=function() return primary end}
local kart={GetAttribute=function() return false end}
local parent={AbsoluteSize={X=750,Y=361}}
for _=1,180 do E.update(parent,kart,chassis,1/60,70,true,false,1) end
check(observed==gaugeState and gaugeState==E.getState() and observed.gear==5,"audio/gauge same state reference")
attributes.KDMEngineExperimentMode="DONOR_EXACT"
for _=1,180 do E.update(parent,kart,chassis,1/60,70,true,false,1) end
check(observed==nil and E.getState().Gear==2,"donor exact 2-speed comparison restored")
studio=false
E.update(parent,kart,chassis,1/60,70,true,false,1)
check(E.getState().gear==5,"published D1 always MULTI_RPM")
attributes.KDMV2DonorExperiment=false
E.update(parent,kart,chassis,1/60,70,true,false,1)
check(E.getState()==nil and observed==nil,"experiment OFF cleans presentation")
print(string.format("120s controlled 70 stud/s: RPM %.3f..%.3f, pitch %.6f..%.6f, volume %.6f..%.6f, audible wrap coincidence=%d",minRpm,maxRpm,minPitch,maxPitch,minVolume,maxVolume,coincidences))
print("PASS: "..checks.." multi-RPM state/mixer/lifecycle checks")
