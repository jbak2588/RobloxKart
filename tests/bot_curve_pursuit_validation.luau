-- Native course geometry and production steering; no Studio/artifact dependency.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local harness=fs.readFile('tests/track_environment_validation.luau')
local prefix=harness:sub(1,assert(harness:find('local prototype=object("Folder")',1,true))-1)
luau.load(prefix..[====[
local serde,process=require('@lune/serde'),require('@lune/process')
local balance=luau.load(fs.readFile('src/shared/KDMGameplayBalance.luau'))()
local config=luau.load(fs.readFile('src/shared/KartConfig.luau'),{environment={script={Parent={WaitForChild=function()return {}end}},require=function()return balance end}})()
local S=luau.load(fs.readFile('src/server/RaceBotSteering.luau'),{environment=env})()
local analyses={}
local feedByRadius={}
for _,r in {180,140,120,105,100,95,85,75}do
 for _,sign in {-1,1}do
  local samples={};local n=720
  for i=1,n do local a=sign*(i-1)*math.pi*2/n; samples[i]=rb.Vector3.new(r*math.cos(a),0,r*math.sin(a))end
  local course={Samples=samples,CenterlineLength=2*math.pi*r}
  local state=S.new(course,60,config);local priorFeed=0
  for _,speed in {50,60,70,80}do
   local throttle,feed,radius,upcoming,desired,adaptive=S.corner(state,20,.5,speed)
   check(radius>r*.98 and radius<r*1.02,'geometry derived circular radius')
   check(feed==feed and math.abs(feed)<=1,'bounded finite feedforward')
   check(math.abs(feed)>=priorFeed,'speed never reduces required steering');priorFeed=math.abs(feed)
   check(adaptive==(upcoming<S.SEVERE_RADIUS),'severe threshold deterministic')
   if sign==1 and speed==60 then feedByRadius[r]=feed end
   if r>=100 then check(not adaptive and throttle==1 and feed==0,'non-severe historical input')
   elseif r<=85 then
    check(adaptive and feed*sign>0,'severe sign matches production negative yaw')
    check(desired>=50 and desired<=65,'corner pace envelope')
    if speed>=70 then check(throttle==0,'anticipatory coast')end
   end
  end
  if r<=85 then
   local _,_,_,_,desired=S.corner(state,20,.5,80)
   local throttle=S.corner(state,20,.5,desired)
   check(throttle==0,'hysteresis holds coast within band')
   throttle=S.corner(state,20,.5,desired-3);check(throttle==1,'below target accelerates')
   throttle=S.corner(state,20,.5,desired+1);check(throttle==1,'hysteresis holds acceleration')
   S.reset(state);check(not state.cornerCoastActive and state.previous==nil,'reset clears all round state')
  end
 end
end
check(feedByRadius[75]>=feedByRadius[85] and feedByRadius[85]>feedByRadius[100],'tighter radius requires stronger feedforward')
for _,id in {'PracticeCircuitV1','PracticeFigure8V1','PrototypeCircuitV2','HardCircuitV1'}do
 local course=geometry.getCourse(geometry.getDefinition(id));local state=S.new(course,60,config)
 local minRadius,active,regions=math.huge,0,{}
 for i in course.Samples do
  local throttle,feed,radius,upcoming,desired,adaptive,distance=S.corner(state,i,.5,80)
  minRadius=math.min(minRadius,radius)
  if adaptive then active+=1;table.insert(regions,{segment=i,radius=radius,upcoming=upcoming,desired=desired,coastDistance=distance})end
  check(throttle==0 or throttle==1,'nonnegative binary Bot throttle')
  if id=='PracticeCircuitV1' then check(not adaptive and throttle==1 and feed==0,'Base never adapts')end
 end
 analyses[id]={minimumRadius=minRadius,adaptiveFraction=active/#course.Samples,regions=regions}
end
for id, a in analyses do print(id,a.minimumRadius,a.adaptiveFraction) end
check(analyses.PracticeFigure8V1.minimumRadius<80,'real tight curve detected')
-- Physics proxy: speed squared drops by 2*a*d under the frozen coast model.
local practice=geometry.getCourse(geometry.getDefinition('PracticeFigure8V1'))
local state=S.new(practice,60,config)
local zones=geometry.getDefinition('PracticeFigure8V1').DriftZones
local proxy={}
for _,zone in zones do
 if zone.Radius>=95 then continue end
 local entry=math.floor(zone.StartFraction*#practice.Samples)+1
 local available=0;local index=(entry-2)%#practice.Samples+1
 for _=1,#practice.Samples do
  local throttle,_,_,_,desired,adaptive=S.corner(state,index,.5,80)
  if not adaptive then break end
  available+=state.lengths[index];index=(index-2)%#practice.Samples+1
 end
 local _,_,_,_,desired=S.corner(state,entry,.5,80)
 local needed=(80^2-desired^2)/(2*config.COAST_DECELERATION)
 table.insert(proxy,{name=zone.Name,desired=desired,available=available,required=needed,predictedEntry=math.sqrt(math.max(0,80^2-2*config.COAST_DECELERATION*available))})
 print(zone.Name,available,needed,desired)
 check(available>=needed-15,'coast horizon can reduce corner entry speed')
 local before=(entry-2)%#practice.Samples+1
 local _,earlyFeed=S.corner(state,before,.5,60)
 check(earlyFeed>0,'forward curvature anticipates real corner entry')
end
if process.args[1]=='Report' then fs.writeDir('artifacts/r7-p2a1');fs.writeFile('artifacts/r7-p2a1/curve-analysis.json',serde.encode('json',{courses=analyses,proxy=proxy}))end
print('PASS: '..count..' Bot curve geometry/feedforward/coast checks')
]====])()
