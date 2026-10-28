local fs,luau=require('@lune/fs'),require('@lune/luau')
local layout=luau.load(fs.readFile('src/shared/HubParkRookieLoopLayout.luau'))()
local policy=luau.load(fs.readFile('src/shared/LobbyDrivePolicy.luau'))()
local function check(v,label)assert(v,label)end
local m=layout.measure()
check(layout.RoadWidth==68 and layout.Shoulder==0,'approved shoulder removal transfers 18 studs to road')
check(layout.RoadWidth/2+layout.KerbWidth+layout.Shoulder==36,'guardrail envelope and driving containment unchanged')
check(m.bounds.minZ<=-1100,'uses former Figure-8 region beyond lobby apron')
check(m.bounds.maxZ<=layout.StartStraightZ+1e-6 and m.bounds.maxZ<-85,'entire main loop in front of lobby, no rear road')
check(m.length>4000 and m.length<6500,'compact pen-sketch circuit, bounded scale')
local s=layout.Segments[1]
local a,b=layout.evaluate(s,0),layout.evaluate(s,1)
local straight=math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)
check(math.abs(straight-layout.MainStraightLength)<.001,'870-stud main straight')
check(a.fx>.999 and math.abs(a.fz)<.001,'start direction left to right from lobby')
local ordered={'EntryCurve','OuterEast','UpperRight','RightInset','InnerRight','LowerBowlEast','LowerBowlWest','HairpinEntry','HairpinApex','HairpinExit','S1','S2','UpperLeftEntry','UpperLeftApex','OuterWest','ReturnChicaneEntry','ReturnChicaneExit','PitApproach'}
for i,name in ordered do check(layout.Segments[i*2].name==name,'sketch route order '..name)end
local right=layout.Segments[3];local ra,rb=layout.evaluate(right,0),layout.evaluate(right,1)
local rightLength=math.sqrt((ra.x-rb.x)^2+(ra.z-rb.z)^2)
check(math.abs(rightLength-(120*3+layout.PitShift))<.001 and rightLength==layout.NitroStraightLength,'right outer straight extended exactly by approved pit shift')
check(ra.fz<-.999 and math.abs(ra.fx)<.001,'right outer straight points away from lobby')
-- Conservative distance budget: full speed for whole effect + comfortable
-- acceleration/braking allowance. This is geometry sizing, not physics tuning.
check(straight>=120*3+180,'Nitro effect plus 180-stud runway allowance')
check(straight>=100*2+180,'Mini Boost effect plus runway allowance')
check(not layout.pitOpening({section='StartStraight',x=300}),'extended straight keeps safety edge beyond pit exit')
check(layout.pitOpening({section='StartStraight',x=140}),'existing pit exit remains open')
check(layout.DefaultEnabled==false,'remains opt-in')
for i=1,#layout.Slots,2 do
 check(layout.Slots[i].x==layout.Slots[i+1].x and layout.Slots[i].z~=layout.Slots[i+1].z,'paired row has distinct lane centers')
 if i>1 then check(layout.Slots[i-2].x>layout.Slots[i].x,'rows progress front to rear')end
end
check(policy.forwardSpeed('ROOKIE_LOOP_V1',{MAX_FORWARD_SPEED=70})==80,'RookieLoop owner-approved 80 stud normal speed')
check(policy.forwardSpeed('ROOKIE_LOOP_V1',{MAX_FORWARD_SPEED=73})==80,'PARK cap independent of official race configuration')
check(policy.forwardSpeed(nil,{MAX_FORWARD_SPEED=70})==60,'legacy HUB cap preserved')
local drift=require('./helpers/lobby_drift_session')
local config=require('./helpers/gameplay_config')('src/shared/KartConfig.luau')
for _,geometryId in {'ROOKIE_LOOP_V1','LEGACY'} do
 local cap=policy.forwardSpeed(geometryId,config)
 local state=drift.new();local speed=0
 for frame=1,600 do
  local _,_,_,budget=drift.step(state,frame/60,1/60,speed,0,speed,1,0,true,0,0,cap,false)
  speed=budget;check(speed<=cap+.001,'native production solver normal cap')
 end
 check(math.abs(speed-cap)<.001,'production solver reaches zone cap')
end
check(config.MINI_BOOST_MAX_SPEED==100 and config.NITRO_MAX_SPEED==120,'boost tuning preserved')
print(string.format('PASS reference course: %.1f studs, straight %.0f, radius %.2f, %d strips; constant-80 estimate %.1fs (not measured lap time)',m.length,straight,m.minRadius,m.roadStrips,m.length/80))
