local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local function load(path,env)return luau.load(fs.readFile(path),{environment=env or {},debugName=path})()end
local L=load('src/shared/HubParkRookieLoopLayout.luau')
local T=require('./helpers/rookie_park_trial')(L)
local P=load('src/shared/ParkOvertakePolicy.luau',{script={Parent={RookieParkTrial='T',HubParkRookieLoopLayout='L'}},require=function(k)return ({T=T,L=L})[k]end})
local n=0;local function check(v,m)assert(v,m);n+=1 end
check(P.Laps==3 and P.Bots==7 and P.BotSpeed==70,'approved three-lap seven-bot contract')
check(P.PreviewImageAssetId=='rbxassetid://94896526779384','approved first-card preview')
for slot=0,7 do
 local start=P.startArc(slot);check(type(start)=='number'and P.finishDistance(slot)>3*T.Length,'all eight real grid slots have complete three-lap distance')
 local distance=P.finishDistance(slot);local average=P.BotSpeed*distance/(distance-T.Length*7/8)
 check(average>=95 and average<=100,'all seven require requested 95-100 average pace for every starting slot')
 for i=1,7 do
  check(math.abs(P.botDistance(i,0)-T.Length*i/8)<1e-7,'seven evenly spaced starts')
  check(math.abs(P.botDistance(i,10)-P.botDistance(i,0)-700)<1e-7,'constant authoritative bot speed')
  local x,z,dx,dz=P.sample(start+P.botDistance(i,12))
  local _,distance=T.project(x,z);check(distance<.01 and dx*dx+dz*dz>0,'rendered rival remains on actual Park route')
 end
end
local distance=P.finishDistance(0)
check(P.countAhead(distance,distance/100)==7 and P.reward(7)==50000,'fast full finish earns 35000 plus base5000 and perfect10000')
check(P.countAhead(distance,distance/70)==0 and P.reward(0)==5000,'no overtakes still earns valid finish base only')
local partial=P.countAhead(distance,distance/90);check(partial>0 and partial<7,'normal pace earns partial catch result')
for count=0,6 do check(P.reward(count)==5000+5000*count,'no perfect bonus on partial catches')end
local tieTime=(distance-T.Length*4/8)/P.BotSpeed
check(P.countAhead(distance,tieTime)==3,'exact tie is not ahead')
check(P.countAhead(distance,tieTime-.1)==4,'earlier finish is one more rival ahead')
check(P.countAhead(distance,tieTime+.1)<P.countAhead(distance,tieTime-.1),'final-time order can fall again; never accumulates historical passes')
-- Execute the real three-lap gate tracker over the complete sampled road.
local s=T.new(0,45,L.StartStraightZ,{laps=3,countdown=8})
check(T.step(s,7.99,45,1.75,L.StartStraightZ)=='LOCKED','instructions precede GO')
check(T.step(s,8,45,1.75,L.StartStraightZ)=='GO','common launch timeline')
local x,z,now=45,L.StartStraightZ,8
local function move(p)
 local d=math.sqrt((p.x-x)^2+(p.z-z)^2);now+=d/100;x,z=p.x,p.z
 T.step(s,now,x,1.75,z)
end
for lap=1,3 do
 for _,p in L.sample(L.Segments)do if p.section~='StartStraight'or p.x>x then move(p)end end
 for _,p in L.sample(L.Segments)do if p.section~='StartStraight'or p.x>85 then break end;move(p)end
 check(s.completedLaps==lap,'one ordered circuit per completed lap')
 check((s.phase=='FINISHED')==(lap==3),'no early completion or reward at lap one/two')
end
check(#s.lapTimes==3 and s.next==7,'all eighteen checkpoints and three lap times')
local S=load('src/shared/KDMProgressionSchema.luau')
local catalog=load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum})
local schema=S.new(catalog,{utcMs=function()return 1792800000000 end,jsonEncode=function(v)return serde.encode('json',v)end})
local reward=load('src/server/ParkOvertakeReward.luau',{game={GetService=function()return {Shared={ParkOvertakePolicy='P'}}end},require=function()return P end})
local proof={id='12345678-1234-1234-1234-000000000001',userId=123,slot=0,milliseconds=s.milliseconds,completedLaps=3,completedCheckpoints=18,valid=true,transaction=schema.issueTransaction()}
proof.ahead=P.countAhead(distance,proof.milliseconds/1000)
local original=schema.default(123);original.wallet.cash=24000;original.wallet.lifetimeEarned=19000
original.selection.kartId='Kart09';original.parkTwoLapTrial={version=1,bestMilliseconds=150000,lastMilliseconds=150000,completedRuns=2}
local paid,why=reward.reduce(S,schema,proof)(original)
check(why=='PARK_OVERTAKE_CREDITED'and schema.validate(paid,S.userKey(123)),'persistent transaction validates with existing account')
check(paid.wallet.cash==74000 and paid.wallet.lifetimeEarned==69000 and paid.wallet.ledgerRevision==original.wallet.ledgerRevision+1,'perfect reward exact wallet and earnings increments')
check(paid.parkTwoLapTrial.bestMilliseconds==150000 and paid.parkTimeTrial==original.parkTimeTrial and paid.selection.kartId=='Kart09','separate from time attack, selection and existing purchases')
local again,status=reward.reduce(S,schema,proof)(paid)
check(status=='REPLAY'and S.canonical(again)==S.canonical(paid),'lost ACK / duplicate callback cannot double-credit')
for _,mutate in {
 function(v)v.valid=false end,function(v)v.completedLaps=2 end,function(v)v.completedCheckpoints=17 end,
 function(v)v.slot=8 end,function(v)v.milliseconds=100 end,function(v)v.ahead=8 end,function(v)v.id='bad'end,
}do local bad=S.clone(proof);mutate(bad);check(reward.reduce(S,schema,bad)(paid)==nil,'forged or incomplete evidence rejected')end
local mismatch=S.clone(proof);mismatch.milliseconds+=1
check(reward.reduce(S,schema,mismatch)(paid)==nil,'same receipt id with different result rejected')
local full=S.clone(original);full.wallet.cash=schema.maxCash
check(reward.reduce(S,schema,proof)(full)==nil,'wallet capacity cannot overflow')
local deleted=S.clone(original);deleted.deleted=true
check(reward.reduce(S,schema,proof)(deleted)==nil,'deleted account never resurrected')
for _,path in {'src/client/ParkOvertakeBotsView.luau','src/client/GarageUiController.luau','src/client/LobbyTestDriveController.luau','src/client/RookieParkTrialView.luau','src/client/LobbyDemoController.luau','src/server/LobbyTestDriveService.luau','src/server/RookieParkTrialSession.luau','src/server/LobbyPracticeCombat.luau','src/server/EconomyService.luau'}do
 local ok,err=pcall(luau.load,fs.readFile(path));check(ok,'compile '..path..': '..tostring(err))
end
print('PASS: '..n..' Park overtake route, final order, perfect reward, receipt, isolation and compile checks')

-- Real Garage GUI wiring: the challenge card must not use official Ready routing.
local fixture=fs.readFile('tests/garage_transition_validation.luau')
local prefix=fixture:sub(1,assert(fixture:find('controller.start()',1,true))-1)
local scenario=[=[
services.Workspace:SetAttribute('KDMServerRole','HUB');services.Workspace:SetAttribute('HubParkV1Enabled',true)
child(client,'ModuleScript','LobbyTestDriveController')
local requests=0;modules.LobbyTestDriveController={requestDrive=function(mode)assert(mode=='OVERTAKE');requests+=1;return true end}
controller.start();controller.open('TRACKS')
local gui=playerGui.RobloxKartGarage;local body=gui:FindFirstChild('Frame');local image=body:FindFirstChild('ApprovedTrackImage',true)
assert(image.Image=='rbxassetid://94896526779384','challenge preview is first')
local start
for _,v in body:GetDescendants()do if v.Text=='START OVERTAKE'then start=v end end
assert(start,'dedicated challenge launch button')
local before=remote.fireCount
start.Activated:Fire()
assert(requests==1 and remote.fireCount==before and not gui.Enabled,'ordinary Hub drive launch, no official Ready packet')
print('PASS: actual Garage first-card and isolated challenge launch')
]=]
luau.load(prefix..scenario,{environment={require=function(path)return require(path)end},debugName='park_overtake_garage'})()

local sessionFixture=fs.readFile('tests/rookie_park_trial_session_validation.luau')
local sessionPrefix=sessionFixture:sub(1,assert(sessionFixture:find('local module=load(',1,true))-1)
local sessionScenario=[=[
local O=load('src/shared/ParkOvertakePolicy.luau',{script={Parent={RookieParkTrial='T',HubParkRookieLoopLayout='L'}},require=function(k)return ({T=T,L=L})[k]end})
local previousRequire=env.require;env.require=function(ref)if ref=='O'then return O elseif ref=='E'then return {
 saveParkOvertake=function(_,proof)
  saved+=1;check(proof.completedLaps==3 and proof.completedCheckpoints==18 and proof.ahead==7,'exact three-lap server final-order proof')
  return {status='SAVE_CONFIRMED'}
 end}end;return previousRequire(ref)end
local getService=env.game.GetService;env.game.GetService=function(self,name)
 if name=='ReplicatedStorage'then return {Shared={RookieParkTrial='T',KartConfig='C',RaceConfig='R',ParkOvertakePolicy='O'}}end
 return getService(self,name)
end
r.parkOvertake=true;r.slot=0;r.generation=2;attrs.LobbyDriveGeneration=2
local module=load('src/server/RookieParkTrialSession.luau',env)
local session=module.new({GetAttribute=function()return rb.Vector3.zero end},practice)
session:begin(player,r);check(attrs.ParkTrialTotalLaps==3 and attrs.ParkOvertakeActive and attrs.ParkTrialGoAt==8,'challenge countdown and mode propagated')
now=8;session:step(player,r)
local x,z=45,L.StartStraightZ-14
local function move(v)local dx,dz=v.x-x,v.z-z;now+=math.sqrt(dx*dx+dz*dz)/100;x,z=v.x,v.z;body.Position=rb.Vector3.new(x,1.75,z);session:step(player,r)end
local points=L.sample(L.Segments)
for circuit=1,3 do
 for _,v in points do if v.section~='StartStraight'or v.x>x then move(v)end end
 for _,v in points do if v.section~='StartStraight'or v.x>100 then break end;move(v)end
 check(saved==(if circuit==3 then 1 else 0),'only final lap saves')
end
check(attrs.ParkTrialRewardAmount==50000 and attrs.ParkTrialRewardState=='CONFIRMED'and attrs.ParkOvertakeAhead==7,'perfect result shown only after ACK')
now=r.trial.finishAt+3.31;session:step(player,r)
check(session:replay(player,r)and attrs.ParkTrialRewardMultiplier==1 and attrs.ParkTrialRewardAmount==5000 and attrs.ParkOvertakeAhead==0,'Replay restarts challenge without a reward multiplier')
session:remove(player);check(attrs.ParkOvertakeActive==nil and attrs.ParkOvertakeStartArc==nil,'cleanup removes challenge mode/timeline')
print('PASS: '..n..' actual Park challenge lifecycle / final proof / reward ACK / Replay checks')
]=]
luau.load(sessionPrefix..sessionScenario,{environment={require=function(path)return require(path)end},debugName='park_overtake_session'})()
