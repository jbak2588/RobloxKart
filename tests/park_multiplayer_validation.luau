local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local function load(path,env)return luau.load(fs.readFile(path),{environment=env or {},debugName=path})()end
local L=load('src/shared/HubParkRookieLoopLayout.luau')
local T=require('./helpers/rookie_park_trial')(L)
local refs={RookieParkTrial=T,HubParkRookieLoopLayout=L}
local parent=setmetatable({},{__index=function(_,k)return k end})
local sharedEnv={script={Parent=parent},require=function(k)return assert(refs[k],k)end}
refs.ParkOvertakePolicy=load('src/shared/ParkOvertakePolicy.luau',sharedEnv)
local P=load('src/shared/ParkMultiplayerPolicy.luau',sharedEnv);refs.ParkMultiplayerPolicy=P
local n=0;local function check(v,m)assert(v,m);n+=1 end
local seed=0
local function rng()
 return {NextNumber=function()seed=(seed*1103515245+12345)%2147483647;return seed/2147483647 end,
 NextInteger=function(_,a,b)seed=(seed*16807+13)%2147483647;return a+seed%(b-a+1)end}
end
for round=1,40 do
 local speeds=P.speeds(rng());local seen={}
 for _,v in speeds do check(v>=85 and v<=91 and not seen[v],'seven bounded distinct random paces');seen[v]=true end
end
for slot=0,7 do
 local x,z=P.sample(P.startProgress(slot),slot)
 check(math.abs(x-L.Slots[slot+1].x)<.01 and math.abs(z-L.Slots[slot+1].z)<.01,'bots start in actual eight grid brackets')
end
local now=0;local guid=0
local env={game={GetService=function(_,name)
 if name=='ReplicatedStorage'then return {Shared=parent}end
 return {GenerateGUID=function()guid+=1;return string.format('12345678-1234-1234-1234-%012d',guid)end}
 end},require=function(k)return refs[k]end,workspace={GetServerTimeNow=function()return now end},Instance=rb.Instance,Random={new=rng},Vector3=rb.Vector3}
local Sessions=load('src/server/ParkMultiplayerSession.luau',env)
local root=rb.Instance.new('Folder')
local zone=rb.Instance.new('Model');zone:SetAttribute('Center',rb.Vector3.zero);zone.Parent=root
local folder=rb.Instance.new('Folder');folder.Parent=zone
local removed=0
local practice={folder=folder,addParkRaceBot=function(_,room,slot,index,speed)
 return {slot=slot,baseSpeed=speed,distance=P.startProgress(slot)}
 end,removeParkRaceBot=function()removed+=1 end}
local function player(id)
 local a={};return {UserId=id,DisplayName='Human '..id,GetAttribute=function(_,k)return a[k]end,SetAttribute=function(_,k,v)a[k]=v end}
end
local function record(slot)
 return {slot=slot,kart=rb.Instance.new('Model'),body={Position=rb.Vector3.new(L.Slots[slot+1].x,1.75,L.Slots[slot+1].z)},
 trial={goAt=10,phase='COUNTDOWN',completedLaps=0}}
end
for humans=1,8 do
 now=0;local api=Sessions.new(zone,practice);local people,records={},{}
 for i=1,humans do local p=player(i);people[i]=p;local slot=api:reserve(p);check(slot==i-1,'unique human slot');records[i]=record(slot);check(api:attach(p,records[i]),'human attaches before deadline')end
 local room=api:room(people[1])
 now=9.999;api:update();check(room.phase=='WAITING'and #room.bots==0,'full ten-second human window, no early fill')
 now=10;api:update();local last=#room.bots
 check(last==(if humans==8 then 0 else 1),'first bot fills only at deadline')
 for i=1,9 do now+=.31;api:update();check(#room.bots-last<=1,'at most one sequential fill per tick');last=#room.bots end
 check(#room.bots==8-humans and room.phase=='COUNTDOWN','exact 8-H bot complement')
 local used={};for _,r in records do used[r.slot]=true;check(r.trial.goAt==room.goAt,'shared GO time')end
 for _,b in room.bots do check(not used[b.slot],'bot cannot occupy human grid');used[b.slot]=true end
 now=room.goAt;api:update();check(room.phase=='RUNNING','synchronous three-lap start')
 -- Two humans finish within one sample; exact crossing times own order, not iteration.
 for i,p in people do records[i].trial.startedAt=room.goAt;records[i].trial.milliseconds=300000-i;records[i].trial.phase='FINISHING';api:finished(p,records[i])end
 for i,b in room.bots do b.finishedAt=room.goAt+299-i end
 now=room.goAt+301;api:update()
 for i,r in records do check(r.trial.raceRank==8-humans+humans-i+1,'bots plus humans share final 8-racer order');check(r.trial.humanRank==humans-i+1 and r.trial.humanCount==humans,'separate human prize ordering')end
 for _,p in people do api:remove(p)end
 check(#folder:GetChildren()==0,'last departure destroys room and bots')
end
now=0;local api=Sessions.new(zone,practice);local a,b,c=player(1),player(2),player(3)
api:reserve(a);api:attach(a,record(0));now=9.9;check(api:reserve(b)==1,'human accepted before deadline');api:attach(b,record(1))
local old=api:room(a);now=10;check(api:reserve(c)==0 and api:room(c)~=old,'deadline arrival starts new room');api:attach(c,record(0));api:update()
check(old.startHumans==2,'late arrival cannot alter locked roster')
api:remove(a);api:remove(b);api:remove(c)
now=0;api=Sessions.new(zone,practice);a=player(1);api:reserve(a);now=10;api:update()
check(api:room(a).phase=='SEATING'and api:attach(a,record(0)),'pre-deadline reservation gets bounded seating grace')
api:update();api:remove(a)
now=0;api=Sessions.new(zone,practice);a=player(1);api:reserve(a);now=11.6;check(not api:attach(a,record(0)),'slow seat cannot attach beyond grace');api:update();check(api:room(a)==nil,'unseated reservation is discarded')
now=0;api=Sessions.new(zone,practice);a=player(1);api:reserve(a)
local departedRecord=record(0);api:attach(a,departedRecord)
local departingRoom=api:room(a);departingRoom.phase='RUNNING';departingRoom.goAt=0;departingRoom.startHumans=1
departedRecord.trial.startedAt=0;departedRecord.trial.milliseconds=1000
local finalized=0;api:finished(a,departedRecord,function()finalized+=1 end);api:remove(a)
check(finalized==0 and #folder:GetChildren()==1,'valid finish survives departure during tie-resolution window')
now=.3;api:update();api:update()
check(finalized==1 and #folder:GetChildren()==0 and a:GetAttribute('ParkRaceId')==nil,'departed finish finalizes once without resurrecting room or HUD')
local S=load('src/shared/KDMProgressionSchema.luau')
local catalog=load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum})
local schema=S.new(catalog,{utcMs=function()return 1792800000000 end,jsonEncode=function(v)return serde.encode('json',v)end})
local Reward=load('src/server/ParkMultiplayerReward.luau',{game={GetService=function()return {Shared=parent}end},require=function()return P end})
local proof={id='12345678-1234-1234-1234-000000000001',userId=123,slot=0,milliseconds=300000,position=3,humans=2,humanPosition=1,completedLaps=3,completedCheckpoints=18,valid=true,transaction=schema.issueTransaction()}
local original=schema.default(123);original.wallet.cash=24000;original.wallet.lifetimeEarned=19000
local paid,status=Reward.reduce(S,schema,proof)(original)
check(status=='PARK_RACE_CREDITED'and paid.wallet.cash==27500 and paid.wallet.lifetimeEarned==22500,'existing public human-place base reward')
check(schema.validate(paid,S.userKey(123)),'profile remains valid')
local again,why=Reward.reduce(S,schema,proof)(paid);check(why=='REPLAY'and S.canonical(again)==S.canonical(paid),'duplicate ACK cannot grant twice')
check(paid.parkTwoLapTrial==original.parkTwoLapTrial and paid.parkTimeTrial==original.parkTimeTrial,'no time-attack record contamination')
for _,mutate in {function(p)p.valid=false end,function(p)p.completedLaps=2 end,function(p)p.position=9 end,function(p)p.humans=9 end,function(p)p.humanPosition=3 end,function(p)p.milliseconds=1 end}do
 local bad=S.clone(proof);mutate(bad);check(Reward.reduce(S,schema,bad)(paid)==nil,'invalid or forged finish rejected')
end
local altered=S.clone(proof);altered.position=4;check(Reward.reduce(S,schema,altered)(paid)==nil,'immutable result identity')
check(P.reward(1,1)==1500 and P.reward(8,8)==1500 and P.reward(8,2)==2500,'existing public base payout schedule')
root:Destroy()
local manifest=serde.decode('json',fs.readFile('tests/fixtures/source_freeze_release_f5ebec8.json'))
local freeze=require('./helpers/release_source_freeze')
for path in manifest.parkMultiplayerPatches do
 local source=fs.readFile(path)
 check(freeze.accepts(manifest,path,source),'exact feature source pin '..path)
 check(not freeze.accepts(manifest,path,source..'\n-- unexpected mutation'),'unapproved source mutation rejected '..path)
end
print('PASS: '..n..' Park multiplayer roster, clocks, grid, random pace, finish order and receipt checks')
