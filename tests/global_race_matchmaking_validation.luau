-- Two independent HUB services, one shared MemoryStore, controllable yielding
-- transport. Exercises the production allocation/room/launch path, not a model.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local titles=require('./helpers/lobby_title_modules')
local checks=0
local function check(v,s)assert(v,s);checks+=1 end
local function signal()
 local callbacks={}
 return {Connect=function(_,f)table.insert(callbacks,f)end,Fire=function(_,...)for _,f in callbacks do f(...)end end}
end
local function map()
 local m={values={}}
 function m:GetAsync(k)return self.values[k]end
 function m:SetAsync(k,v)self.values[k]=v end
 function m:RemoveAsync(k)self.values[k]=nil end
 function m:UpdateAsync(k,f)local v=f(self.values[k]);if v~=nil then self.values[k]=v end;return v end
 function m:GetRangeAsync()local r={};for k,v in self.values do table.insert(r,{key=k,value=v})end;return r end
 return m
end
local now=1000
local rooms,allocation,presence,invites=map(),map(),map(),map()
local enum={SortDirection={Ascending='Ascending'}}
local Directory=luau.load(fs.readFile('src/server/ActiveMatchDirectory.luau'),{environment=titles.environment(enum)})()
local Discovery=luau.load(fs.readFile('src/shared/RaceDiscovery.luau'))()
local Allocator=luau.load(fs.readFile('src/server/GlobalRaceAllocator.luau'))()
local Social=luau.load(fs.readFile('src/server/RoomSocialDirectory.luau'),{environment=titles.environment(enum)})()
local serial,reserves,holdReserve=0,0,false
local launches={}
local function node(name)return {Name=name,WaitForChild=function(_,n)return node(n)end}end
local function guid()serial+=1;return 'request-aaaaaaaa-'..serial end
local directory=Directory.new(rooms,function()return now end)
local function hub(id,userId,noBrowser)
 local p={UserId=userId,Name='P'..userId,DisplayName='P'..userId,attrs={RaceState='GARAGE',SelectedDriverId='Driver01',SelectedKartId='Kart01'}}
 function p:GetAttribute(n)return self.attrs[n]end
 function p:SetAttribute(n,v)self.attrs[n]=v end
 local players={PlayerRemoving=signal(),PlayerAdded=signal()};p.Parent=players
 function players:GetPlayers()return if p.Parent==self then {p}else {}end
 function players:GetPlayerByUserId(n)return if n==p.UserId then p else nil end
 local remote={OnServerEvent=signal(),messages={}}
 function remote:FireClient(_,action,data)table.insert(self.messages,{action=action,data=data})end
 local services={Players=players,ReplicatedStorage=node('ReplicatedStorage'),
  MemoryStoreService={GetSortedMap=function(_,n)return if n==Directory.MAP_NAME then rooms else presence end,
   GetHashMap=function(_,n)return if n==Allocator.MAP_NAME then allocation else invites end},
  HttpService={GenerateGUID=guid},TeleportService={ReserveServerAsync=function()
   reserves+=1;local n=reserves;if holdReserve then coroutine.yield('RESERVING')end
   return 'secret-code-'..n,'private-'..n
  end}}
 local modules={RaceDiscovery=Discovery,LobbyTitleService=titles.service,
  TrackCatalog={Entries={Track01={MatchType='PUBLIC_RACE',MaxPlayers=4},Track01Race={MatchType='PUBLIC_RACE',MaxPlayers=4},Track03={MatchType='PUBLIC_RACE',MaxPlayers=4}}},
  DriverCatalog={DefaultId='Driver01',Entries={Driver01={}}},KartCatalog={DefaultId='Kart01',Entries={Kart01={}}},
  ActiveMatchDirectory=setmetatable({new=function()return directory end},{__index=Directory}),
  GlobalRaceAllocator=setmetatable({new=function()return Allocator.new(allocation,function()return now end)end},{__index=Allocator}),
  RoomSocialDirectory=setmetatable({new=function()return Social.new(presence,invites,function()return now end)end},{__index=Social}),
  RaceLaunchPayload={buildMatch=function(matchId,roomId,members,trackId)
   return {matchId=matchId,roomId=roomId,trackId=trackId,participantUserIds={members[1].userId}}
  end},RaceLaunchService={launchMatch=function(group,payload,failed,code)
   table.insert(launches,{player=group[1],payload=payload,code=code,failed=failed})
   group[1]:SetAttribute('KDMRoutePending','RACE_LAUNCH');return true
  end}}
 local env={game={JobId=id,PlaceId=123,GetService=function(_,n)return assert(services[n],n)end},
  script={Parent=node('Server')},require=function(m)return assert(modules[m.Name],m.Name)end,
  Instance={new=function()return remote end},DateTime={now=function()return {UnixTimestampMillis=now*1000+serial}end},
  task={spawn=function()end,wait=function()coroutine.yield('LEASE_WAIT')end},warn=function()end}
 local service=luau.load(fs.readFile('src/server/MatchRoomService.luau'),{environment=env})();service.start()
 local function action(name,...)remote.OnServerEvent:Fire(p,name,...)end
 if not noBrowser then action('BrowseAll','Driver01','Kart01')end
 return {p=p,remote=remote,action=action,service=service}
end
local a,b=hub('HUB-A',101),hub('HUB-B',102)
holdReserve=true
local ca=coroutine.create(function()a.action('QuickPlay')end)
local cb=coroutine.create(function()b.action('QuickPlay')end)
local ok,why=coroutine.resume(ca);check(ok and why=='RESERVING','A holds shared allocation during server reservation')
ok,why=coroutine.resume(cb);check(ok and why=='LEASE_WAIT','simultaneous B waits instead of creating a second room')
check(reserves==1,'one reserved server for simultaneous independent HUBs')
holdReserve=false
check(coroutine.resume(ca),'A commits and releases allocation before transport')
check(coroutine.resume(cb),'B resumes and joins canonical room')
check(#launches==2 and launches[1].code==launches[2].code,'both HUBs launch to same reserved server')
local roomId=launches[1].payload.roomId
local r=directory:get(roomId)
check(r and #r.stagedMembers==2 and not r.initializing,'two atomic reservations in one visible room')
check(launches[2].payload.trackId==launches[1].payload.trackId,'no manual track agreement required')
check(not directory:startRound(roomId,r.hostUserId,2),'cannot start until reservations actually arrive')
for _,m in r.stagedMembers do check(directory:confirmArrival(roomId,m.userId,m.admissionToken,'RACE-JOB'),'arrival validates private room token')end
check(directory:startRound(roomId,r.hostUserId,2),'two humans can start together after arrival')
directory:raceState(roomId,r.matchId,'RACING',2,r.privateServerId,'RACE-JOB')
local c=hub('HUB-C',103);c.action('QuickPlay')
r=directory:get(roomId)
check(#launches==2 and #r.queued==1 and r.state=='RACING','two-human race preserved; third person queues')
check(reserves==1,'active human race concentrates next entrant without duplicate room')
local display=directory:display(r)
check(display.humanCount==2 and display.botCount==0 and display.queuedCount==1,'accurate public counts')
check(display.reservedServerAccessCode==nil and display.currentRoundMembers==nil,'public snapshot never leaks access codes or tokens')

-- A broken transfer releases only its own reservation.
rooms.values={};allocation.values={};launches={}
local d,e=hub('HUB-D',104),hub('HUB-E',105)
d.action('QuickPlay');e.action('QuickPlay')
roomId=launches[1].payload.roomId
launches[2].failed();r=directory:get(roomId)
check(r and #r.stagedMembers==1 and r.stagedMembers[1].userId==104,'teleport failure preserves the other player and room')
now+=61
local f=hub('HUB-F',106);f.action('QuickPlay');r=directory:get(roomId)
check(r and #r.stagedMembers==1 and r.stagedMembers[1].userId==106,'expired unarrived seats are reclaimed')
check(r.hostUserId==106,'expired creator reservation transfers host to the arriving replacement')

-- Fencing prevents a paused owner from publishing after its lease was stolen.
local lease=Allocator.new(map(),function()return now end)
check(lease:acquire('old'),'lease acquired');now+=31
check(lease:acquire('new'),'expired lease recovers after owner crash')
check(not lease:finish('old','orphan'),'stale allocator cannot publish or release new owner')
check(lease:finish('new','canonical').roomId=='canonical','new owner publishes canonical room')

rooms.values={};allocation.values={};launches={};holdReserve=true
local slow,fast=hub('HUB-SLOW',107),hub('HUB-FAST',108)
local paused=coroutine.create(function()slow.action('QuickPlay')end)
check(coroutine.resume(paused),'slow allocator starts')
now+=31;holdReserve=false;fast.action('QuickPlay')
check(coroutine.resume(paused),'expired allocator resumes safely')
check(#directory:list()==1 and #launches==1 and launches[1].player==fast.p,'stale creator cannot publish a competing room or teleport its player')
slow.action('QuickPlay')
check(#launches==2 and launches[2].code==launches[1].code,'failed stale creator retries into the canonical room')

-- Real directory warm-up admission: a request must not interrupt the host.
rooms.values={}
r=directory:createPersistent({id='warmup-room',matchId='warmup-match',hostUserId=201,hostName='Host',trackId='Track01Race',maxPlayers=4,quickMatch=true},'secret','private')
local host={userId=201,name='Host',kartId='Kart01',driverId='Driver01'}
directory:stage(r.roomId,host,'host-token','Track01Race')
directory:confirmArrival(r.roomId,201,'host-token','race-job')
check(directory:addBot(r.roomId,{botId='Bot01',name='KDM Rookie [BOT]',kartId='Kart01',gridSlot=4}),'warm-up supports existing bot')
directory:startRound(r.roomId,201,2);directory:raceState(r.roomId,r.matchId,'RACING',2,'private','race-job')
check(directory:get(r.roomId).quickWarmup,'one-human public bot round marked warm-up')
directory:stage(r.roomId,{userId=202,name='Guest',driverId='Driver01',kartId='Kart01'},'guest-token','Track01Race')
check(directory:get(r.roomId).state=='RACING','seat reservation alone does not interrupt')
check(not directory:interruptWarmup(r.roomId,202,'forged','race-job'),'forged arrival token rejected')
check(not directory:interruptWarmup(r.roomId,202,'guest-token','wrong-job'),'wrong destination rejected')
local joined=directory:interruptWarmup(r.roomId,202,'guest-token','race-job')
check(joined and joined.state=='WAITING'and #joined.stagedBots==0 and #joined.currentRoundBots==0,'verified arrival transitions to human staging')
check(#joined.stagedMembers==2 and joined.stagedMembers[1].arrived and not joined.stagedMembers[2].arrived,'host preserved, guest must still finish seat confirmation')
check(directory:confirmArrival(r.roomId,202,'guest-token','race-job'),'guest confirms fresh human round')
check(directory:startRound(r.roomId,201,2)and not directory:get(r.roomId).quickWarmup,'human-vs-human round replaces warm-up')

local savedRange=rooms.GetRangeAsync
rooms.GetRangeAsync=function()error('network unavailable')end
local beforeReserves=reserves
local offline=hub('HUB-OFFLINE',109);offline.action('QuickPlay')
check(reserves==beforeReserves,'directory failure never creates an isolated fallback race')
check(offline.remote.messages[#offline.remote.messages].action=='Error','directory failure produces recoverable feedback')
rooms.GetRangeAsync=savedRange

rooms.values={};allocation.values={};launches={}
local practice=hub('HUB-PRACTICE',301)
practice.action('Browse','Driver01','Kart01','Track03');practice.action('Practice')
local training=directory:get(launches[1].payload.roomId)
check(training and training.practiceOnly and training.trackId=='Track03','selected track opens private solo practice')
check(#directory:list()==0 and Discovery.rank(training)==nil,'private practice is absent from public discovery')
check(not directory:stage(training.roomId,{userId=302},'outsider-token','Track03'),'private practice rejects another human even with room id')
check(not directory:queue(training.roomId,{userId=302},'Track03'),'private practice rejects public queue')
local public=hub('HUB-PUBLIC',302);public.action('QuickPlay')
check(launches[2].payload.roomId~=training.roomId and launches[2].payload.trackId=='Track01Race','public matching does not interrupt or recruit private practice')

-- Welcome CTA needs no prior browser selection and always chooses Practice.
rooms.values={};allocation.values={};launches={};holdReserve=false
local newbie=hub('HUB-FIRST',401,true)
newbie.action('FirstRace')
local firstRoom=launches[1] and directory:get(launches[1].payload.roomId)
check(firstRoom and firstRoom.trackId=='Track01' and firstRoom.practiceOnly and firstRoom.firstRaceOnly,'first CTA directly routes to isolated Practice')
check(firstRoom.quickMatch and #firstRoom.stagedMembers==1,'first solo auto-start room contract')
check(#directory:list()==0 and not directory:queue(firstRoom.roomId,{userId=402},'Track01'),'first race protected from discovery and mid-race arrivals')
newbie.action('FirstRace')
check(#launches==1,'double CTA creates no second room')

local Layout=luau.load(fs.readFile('src/client/RaceBrowserLayout.luau'))()
for _,size in {{375,700},{640,300},{749,302},{844,390},{932,430},{1366,768},{1920,1080}}do
 local m=Layout.measure(size[1],size[2])
 check(m.width<=size[1]-16 and m.height<=size[2],'safe browser bounds')
 check(m.detail>=14 and m.body>=16 and m.button>=16,'reference-sized readable type')
 check(m.height-m.listTop-m.listBottom>0 and m.row>=m.thumb+20,'scroll viewport and thumbnail clearance')
end
print('PASS '..checks..' cross-HUB matchmaking, fencing, arrival, human priority and layout checks')
