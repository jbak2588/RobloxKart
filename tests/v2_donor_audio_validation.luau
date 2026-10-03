local fs,luau=require('@lune/fs'),require('@lune/luau')
local A=luau.load(fs.readFile('src/client/V2DonorValuesAdapter.luau'))()
local S=luau.load(fs.readFile('src/client/V2DonorAudio.luau'))()
local checks=0
local function check(ok,message) assert(ok,message);checks+=1 end
local a,s=A.new(),S.new()
local state,pitch,volume
for i=1,7200 do
	state=a:update(70,1/60,{throttle=1})
	pitch,volume=s:update(state,1/60,i/60)
	check(state.Gear==1 or state.Gear==2,'never third gear')
	check(state.RPM>=700 and state.RPM<=10100,'donor RPM bounds')
	if i>180 then
		local expected=70/(A.WHEEL_DIAMETER/2)*1.18*(7.5*30/math.pi)
		check(state.Gear==2 and math.abs(state.RPM-expected)<.001,'wheel/final-drive/ratio exact cruise RPM')
		check(math.abs(pitch-1.2*expected/10000)<.001 and volume==1,'steady original pitch/volume')
	end
end
print(string.format('70 stud/s 120s state: gear=%s RPM=%.6f pitch=%.6f volume=%.6f',state.Gear,state.RPM,pitch,volume))
for i=1,120 do state=a:update(0,1/60,{throttle=0});pitch,volume=s:update(state,1/60,120+i/60) end
check(state.Gear==1 and math.abs(state.RPM-700)<.001,'downshift/idle');check(volume==.3,'coast envelope settles')
state=a:update(10,1/60,{reverse=true});check(state.Gear==-1,'reverse')
state=a:update(0,1/60,{neutral=true});check(state.Gear==0,'neutral')
state=a:update(10,1/60,{});check(state.Gear==1,'forward restores after neutral')
-- Numeric equivalence to the donor while-wait body, including gear ripple.
local audio=S.new();local throt,trmmult,mult,shift=0,0,0,0
for i=1,100 do
	local gear=if i<40 then 1 else 2
	if i==40 then mult=1;shift=.2 end
	mult=math.max(0,mult-.1)
	local throttle=if i<70 then 1 else .03
	local trmon=if throttle<=.03 then 1 else 0
	if trmon==1 then throt=math.max(.3,throt-.2);trmmult=math.max(0,trmmult-.05) else throt=math.min(1,throt+.1);trmmult=1 end
	shift=math.min(1,shift+.2)
	local rpm=if i>=50 and i<65 then 9950 else 8000
	local time=i/30
	local ep=math.max(1.2*rpm/10000+.13*mult*math.sin(80*time),0)
	local ev=throt*shift*(if rpm>9875 and throttle>.03 then .5 else 1)+.4*trmon*trmmult*(1-throt)*math.sin(time*50)
	local p,v=audio:update({RPM=rpm,Gear=gear,Throttle=throttle,IsOn=true},1/30,time)
	check(math.abs(p-ep)<1e-9 and math.abs(v-ev)<1e-9,'donor numeric frame equivalence')
end
local src=fs.readFile('src/client/V2DonorExperiment.luau')
check(not src:find(':Play%(') and not src:find(':Stop%(') and not src:find('TimePosition') and not src:find('SoundId'),'no restart/seek/asset mutation during modulation')
local controller=fs.readFile('src/client/KartAudioController.luau')
check(controller:find('engine:Play()',1,true)~=nil and controller:find('engine.PlaybackRegionsEnabled = false',1,true)~=nil,'attach-only Play/full loop')
print('PASS: '..checks..' donor state/audio checks')
