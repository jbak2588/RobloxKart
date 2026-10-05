local fs,luau=require("@lune/fs"),require("@lune/luau")
local T=luau.load(fs.readFile("src/server/DriftTelemetry.luau"))()
local config=require("./helpers/gameplay_config")("src/shared/KartConfig.luau")
local function kart()
	return {attrs={},writes=0,GetAttribute=function(self,k)return self.attrs[k]end,
		SetAttribute=function(self,k,v)self.attrs[k]=v;self.writes+=1 end}
end
for _,c in {{0,0,0,false},{.5,.75,.5,false},{1,.375,.5,false},{1,.75,1,true}} do
	local progress,ready=T.progress(c[1],c[2],config)
	assert(progress==c[3] and ready==c[4],"progress uses both independent requirements")
end
local k,logs=kart(),{}
local t=T.new(k,config,function(line)table.insert(logs,line)end)
assert(k.attrs.KartDriftChargeProgress==0 and not k.attrs.KartDriftChargeReady,"initial clear")
t:observe(.1,.017,62,8,.6,.6,1,true);t:begin();t:update(1,.3)
assert(math.abs(k.attrs.KartDriftChargeProgress-.4)<1e-9,"qualified limit")
local writes=k.writes
for _=1,5 do t:observe(.1,.016,62,8,.6,.6,1,true);t:update(1,.4) end
assert(k.writes==writes,"replication is throttled below 100ms")
t:observe(.63,.11,61,8,.6,.6,0,false)
t:finish("input_timeout",1,.4,false);t:finish("input_timeout",1,.4,false)
assert(#logs==1 and string.find(logs[1],"end=input_timeout",1,true),"one end log")
assert(k.attrs.KartDriftDiagMaxInputAge==.63 and k.attrs.KartDriftDiagMaxServerDelta==.11,"includes final timeout/hitch frame")
assert(not k.attrs.KartDriftDiagBoostEligible and not k.attrs.KartDriftChargeReady and k.attrs.KartDriftChargeProgress==0,"end clears ready/progress")
t:observe(.08,.017,62,15,.6,.6,1,true);t:begin();t:update(1,.75)
assert(k.attrs.KartDriftDiagMaxInputAge==.08 and k.attrs.KartDriftDiagMaxServerDelta==.017,"new session resets maxima")
assert(k.attrs.KartDriftChargeReady and k.attrs.KartDriftChargeProgress==1,"full ready")
t:finish("shift_release",1,.75,true)
assert(#logs==2 and k.attrs.KartDriftDiagBoostEligible,"actual eligible passed by gameplay")
assert(k.attrs.KartDriftDiagEndSerial==2,"distinct completion notification")
t:observe(0,2.01,0,0,0,0,0,false)
assert(k.attrs.KartDriftDiagEndReason=="" and k.attrs.KartDriftDiagDuration==0,"result retention expires")
for _,reason in {"slick","barrier","fall","no_occupant","race_controls_locked","driver_changed","steer_below_exit","speed_below_exit","reverse"} do
	t:begin();t:update(1,.75);t:finish(reason,1,.75,false)
	assert(k.attrs.KartDriftDiagEndReason==reason and not k.attrs.KartDriftChargeReady,"cancel reason and ready cleanup")
end
t:clear();assert(k.attrs.KartDriftDiagEndReason=="" and k.attrs.KartDriftChargeProgress==0,"lifecycle clear")
local quietConfig=table.clone(config);quietConfig.DEBUG_TELEMETRY=false
local q=kart();local quiet=T.new(q,quietConfig,function()error("debug-off log")end)
quiet:begin();quiet:update(1,.75);assert(q.attrs.KartDriftChargeReady,"production gauge independent of debug")
quiet:finish("shift_release",1,.75,true)
for key in q.attrs do assert(not string.find(key,"Diag",1,true),"debug-off has no diagnostic attributes") end
print("PASS: authoritative progress, 10Hz publication, per-session maxima, timeout/hitch final sample, end logs, reset and DEBUG gating")
