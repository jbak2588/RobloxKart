local fs,luau=require('@lune/fs'),require('@lune/luau')
local p=luau.load(fs.readFile('src/shared/LobbyDrivePolicy.luau'))()
local n=0;local function check(v,label)assert(v,label);n+=1 end
check(p.isGlobalHub('HUB','',false),'public Lobby accepted')
for _,v in {{'RACE','',false},{'HUB','reserved',false},{'HUB','private',false},{'HUB','',true}} do check(not p.isGlobalHub(unpack(v)),'reserved/private/bot excluded') end
for _,v in {{0,0},{1,-1},{.5,.75}} do check(p.validAxes(unpack(v)),'finite axes') end
for _,v in {{0/0,0},{0,math.huge},{-math.huge,0},{'1',0},{0,{}}} do check(not p.validAxes(unpack(v)),'malformed input rejected') end
-- Simulate a real start, brake/reverse and release at two mobile/server cadences.
check(p.Reverse==30,'Lobby reverse maximum is 30 studs/s')
for _,dt in {1/30,1/60} do
 local speed,distance=0,0
 for _=1,math.floor(3/dt) do speed=p.advance(speed,1,dt);distance+=speed*dt;check(speed<=60 and speed>=0,'forward capped each step') end
 check(math.abs(speed-60)<.001 and distance<240,'60 reachable on straight')
 for _=1,math.floor(2/dt) do speed=p.advance(speed,-1,dt);check(speed>=-30 and speed<=60,'brake/reverse cap every step') end
 check(math.abs(speed+30)<.001,'reverse reached')
 for _=1,math.floor(2/dt) do speed=p.advance(speed,0,dt) end
 check(math.abs(speed)<.001,'release coasts to stop')
end
local points=p.route(p.Radius)
for i,a in points do
 local b=points[i%#points+1];local length=math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)
 check(length>0 and length<=8,'continuous dense closed route including seam')
 check(p.inside(a.x,a.z,p.FootprintMargin+4),'all centerline points have safe footprint clearance')
 for _,offset in {-p.RoadWidth/2,p.RoadWidth/2} do
  local dx,dz=(b.x-a.x)/length,(b.z-a.z)/length
  check(p.inside(a.x-dz*offset,a.z+dx*offset,p.FootprintMargin),'road edges have kart safety shoulder')
 end
end
check(not p.inside(0,p.OuterRadius+1,0),'outer edge rejected')
check(not p.inside(p.HalfStraight+p.OuterRadius+1,0,0),'outer curve rejected')
check(p.inside(0,0,p.FootprintMargin),'infield remains safe ground')
check(p.OuterRadius-p.Radius-p.RoadWidth/2-2>=16,'guardrail shoulder respects major drift clearance despite no Lobby drift')
check(p.TurnRadius==p.Radius,'full-steer circle fits the loop at 60')
print('PASS: '..n..' Lobby policy / speed / closed-loop footprint cases')
