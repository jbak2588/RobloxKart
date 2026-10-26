local fs,luau=require('@lune/fs'),require('@lune/luau')
local state=luau.load(fs.readFile('src/client/RacePresentationState.luau'),{environment={}})()
local C=luau.load(fs.readFile('src/client/CheckpointGuidanceController.luau'),{environment={
 game={GetService=function()return {}end},script={Parent={RacePresentationState='state'}},require=function()return state end,
}})()
local n=0;local function check(v,label)assert(v,label);n+=1 end
for _,height in {390,430,600,900,1080}do
 for _,fov in {60,75,85,95}do
  local far=C.markerMetrics(320,height,fov,300)
  local middle=C.markerMetrics(120,height,fov,100)
  local close=C.markerMetrics(70,height,fov,52)
  check(far<middle and middle<=close,'perspective shrinks distant sign')
  check(close<=200 and close<=height*.36,'bounded marker on short landscape and PC')
  for distance=0,26 do local _,_,alpha=C.markerMetrics(distance+18,height,fov,distance);check(alpha==0,'near kart never obscured')end
  local prior=0
  for distance=27,50 do local _,_,alpha=C.markerMetrics(distance+18,height,fov,distance);check(alpha>=prior and alpha<=1,'smooth proximity fade');prior=alpha end
  local _,_,alpha=C.markerMetrics(-1,height,fov,100);check(alpha==0,'behind camera hidden')
  _,_,alpha=C.markerMetrics(400,height,fov,351);check(alpha==0,'distant marker hidden')
  prior=1
  for distance=250,350,5 do
   local _,_,farAlpha=C.markerMetrics(distance+18,height,fov,distance)
   check(farAlpha<=prior and farAlpha>=0,'distant approach fades in without a pop')
   prior=farAlpha
  end
  check(prior==0,'visibility boundary fully transparent')
  for _,x in {200,500,850}do
   local w,h=C.markerMetrics(70,height,fov,52)
   local tipY=height*.5
   check(C.markerOverlaps(x,tipY,w,h,{x-10,tipY-20,x+10,tipY+20}),'driver/head overlap hides sign')
   check(not C.markerOverlaps(x,tipY,w,h,{x-10,tipY+7,x+10,tipY+40}),'sign above kart stays visible')
   check(not C.markerOverlaps(x,tipY,w,h,{x+w,tipY-h,x+w+20,tipY}),'lateral drift does not hide safe sign')
  end
 end
end
check(not C.markerOverlaps(0,0,100,50,nil),'missing driver remains safe')


for _,d in {351,600,1200,1899}do
 local w,h,a=C.markerMetrics(d,430,75,d,true)
 check(w>=56 and a>0,'missed checkpoint remains discoverable outside ordinary approach range')
 local _,_,ordinary=C.markerMetrics(d,430,75,d,false);check(ordinary==0,'normal approach keeps its range')
end
local _,_,behind=C.markerMetrics(-10,430,75,600,true);check(behind==0,'missed pin still respects camera direction')

for _,id in {'Track01','Track01Desert','Track01Race','Track01Metro','Track03','Track02'}do
 local track={GetAttribute=function(_,key)return if key=='TrackId'then id else nil end}
 check(C.checkerLift(track)==(if id=='Track01'then .265 else .065),'checker lift scoped to Green; other/retired identity unchanged')
end
local park={GetAttribute=function(_,key)return if key=='DriveGeometry'then 'ROOKIE_LOOP_V1'else nil end}
check(C.checkerLift(park)==.265,'Park checker clear of matte road at a distance')
print('PASS: '..n..' production marker perspective/proximity/missed-checkpoint checks')
