local fs,luau,rb,process=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/process')
local B=luau.load(fs.readFile('src/shared/KDMPerformanceBuffer.luau'))()
local now,n=0,0
local function check(v,label)assert(v,label);n+=1 end
local attrs={RaceState='RACING',RaceSessionId=1,OfficialRoundGuid='round1'}
local player={UserId=11700555357,Character={},GetAttribute=function(_,k)return attrs[k]end}
local sent,logs={},{}
local function signal() local s={} function s:Connect(fn) self.fn=fn;return {Connected=true,Disconnect=function(self)self.Connected=false end} end return s end
local uploaded={}
local remote={Name='KDMPerfSnapshot',OnClientEvent=signal(),OnServerEvent=signal(),FireClient=function(_,p,row)table.insert(sent,{p=p,row=row})end,
 FireServer=function(_,r)table.insert(uploaded,r)end}
local storage={Shared={KDMPerformanceBuffer='BUFFER',KartConfig='CONFIG'},ChildAdded=signal(),FindFirstChild=function()return remote end}
local services={Players={LocalPlayer=player,PlayerRemoving=signal(),GetPlayers=function()return {player,{UserId=99}}end},ReplicatedStorage=storage,
 RunService={IsStudio=function()return false end},Stats={GetTotalMemoryUsageMb=function()return 123 end},
 HttpService={JSONEncode=function(_,r)table.insert(logs,r);return 'bounded' end}}
local env={game={GameId=10768420544,PlaceId=127925465904803,ReplicatedStorage=storage,GetService=function(_,k)return services[k]end},
 require=function(m)return if m=='CONFIG' then {INPUT_TIMEOUT=.5} else B end,Vector3=rb.Vector3,
 workspace={GetServerTimeNow=function()return now end,GetDescendants=function()return {1,2,3}end},
 os={clock=function()return now end},time=function()return now end,warn=function()end,
 Instance={new=function()return {}end},UDim2=rb.UDim2,Enum=rb.Enum,Color3=rb.Color3}
local server=luau.load(fs.readFile('src/server/RacePerformanceMonitor.luau'),{environment=env})()
local ka={RaceControlsLocked=false,RaceResetSerial=1}
local seat={Occupant={Parent=player.Character}}
local kart={Parent={},GetAttribute=function(_,k)return ka[k]end,SetAttribute=function(_,k,v)ka[k]=v end,
 FindFirstChild=function()return seat end}
local chassis={Parent=kart,AssemblyLinearVelocity=rb.Vector3.new(70,3,0),Position=rb.Vector3.zero,GetNetworkOwner=function()return nil end}
local c={owner=player,kart=kart,chassis=chassis,seat=seat,commandedSpeed=70,control={lastUpdate=0,throttle=1,steering=0},slick={active=false},ownerConnections={{Connected=true}}}
check(server.active(),'exact canary activates')
server.lifecycle({[c]=true});server.observe(c,.016,.2,chassis.AssemblyLinearVelocity)
check(#sent==1 and sent[1].p==player,'normal snapshot is canary-only')
check(sent[1].row.preVertical==3 and sent[1].row.speed==70,'separate planar/vertical observations')
check(sent[1].row.ownerSeated and not sent[1].row.inputTimeout,'seating and fresh input')
check(sent[1].row.counts.contexts==1 and sent[1].row.counts.ownerConnections==1,'owned lifecycle counts')
check(sent[1].row.lifecycle.objects==3,'round boundary object snapshot')
remote.OnServerEvent.fn({UserId=99},{t=now,round='round1'})
check(#logs==0,'unauthorized client cannot request server history')
remote.OnServerEvent.fn(player,{t=now,round='wrong'})
check(#logs==0,'stale round request rejected')
remote.OnServerEvent.fn(player,{t=now,round='round1',speed=0,dt=.016,extra='untrusted'})
check(#logs==1 and logs[1].client.extra==nil and logs[1].history[1].t==0,'paired history fixed schema and server clock')
check(sent[#sent].row.kind=='PAIR' and sent[#sent].p==player,'bounded paired history returned only to authorized client')
remote.OnServerEvent.fn(player,{t=now,round='round1'})
check(#logs==1,'client report spam bounded')
table.clear(logs)
now=.02;server.observe(c,.016,.2,chassis.AssemblyLinearVelocity)
check(#sent==2,'normal snapshot plus one authorized event reply; no per-frame replication')
now=.2;server.observe(c,.016,.2,rb.Vector3.new(0,-4,0))
check(logs[#logs].event=='ZERO_SPEED' and logs[#logs].sample.preSpeed==0 and logs[#logs].sample.speed==70,'pre-step collapse survives post-step restoration')
local c2=table.clone(c);c2.chassis=table.clone(chassis)
now=.3;server.observe(c2,.016,.2,c2.chassis.AssemblyLinearVelocity)
now=.4;c2.chassis.AssemblyLinearVelocity=rb.Vector3.zero;server.observe(c2,.016,.2,rb.Vector3.zero)
check(logs[#logs].sample.speed==0 and #logs==2,'other racer independent anomaly limiter')
now=.6;server.observe(c,.016,.2,chassis.AssemblyLinearVelocity)
check(sent[#sent].row.inputTimeout,'expired input observed without modifying timeout')
local previousCount=#logs;attrs.OfficialRoundGuid='round2';attrs.RaceSessionId=2
now=1;server.lifecycle({[c]=true});server.observe(c,.016,.2,chassis.AssemblyLinearVelocity)
check(sent[#sent].row.rematch==1 and sent[#sent].row.round=='round2','new round correlation')
check(#logs==previousCount,'round transition has no synthetic ZERO')
for i=1,100 do now=1+i*.1;server.observe(c,.016,.2,chassis.AssemblyLinearVelocity) end
check(server.states[c].history.count==60,'per-context history bounded')
server.remove(c2);check(server.states[c2]==nil,'context cleanup releases history')
player.PlayerGui={FindFirstChild=function()return {GetAttribute=function()return true end}end}
local client=luau.load(fs.readFile('src/client/RacePerformanceMonitor.luau'),{environment=env})()
client.receive(sent[#sent].row);client.inputSent(1,0,false)
client.observe(chassis,70,.016,.1);now+=.11;client.observe(chassis,70,.016,.1)
local row=client.buffer:snapshot()[client.buffer.count]
check(row.server and row.server.round=='round2' and row.serverAge>=0,'shared clock and round matched')
check(row.input.throttle==1 and row.inputSentAge>.1,'actual input send age')
check(row.seated and row.chassisExists and row.seatExists,'actual Seat and Humanoid identity')
now+=.02;client.observe(chassis,0,.016,.1)
check(#uploaded==1 and uploaded[1].round=='round2','client zero submits matching round to server history')
client.receive({kind='PAIR',user=player.UserId,round='round2',client=uploaded[1],history=server.states[c].history:snapshot()})
check(client.pairs.count==1,'client retains bounded matching server/client history')
now+=.3;client.observe(chassis,70,.016,.1)
check(logs[#logs].event=='ZERO_RECOVERED' and logs[#logs].sample.zeroDuration>.29,'zero recovery duration retained')
attrs.OfficialRoundGuid='round3';now+=.2;client.observe(chassis,70,.016,.1);now+=.2;client.observe(chassis,70,.016,.1)
check(client.buffer:snapshot()[client.buffer.count].server==nil,'old round snapshot rejected')
check(client.buffer:snapshot()[client.buffer.count].serverDt==nil,'stale event attributes never substitute for current snapshot')
local source=fs.readFile('src/client/RacePerformanceMonitor.luau')
check(source:find("else 'N/A'",1,true)~=nil,'missing numeric values rendered N/A')
player.UserId=99;now+=2;check(not server.active(),'noncanary cannot activate live diagnostics')
local root=process.args[1] or '.'
local baseline=process.exec('git',{'-C',root,'show','e095cfda25405fcf25fe1ca11ba8183ace05fc89:src/server/PrototypeWorld.luau'})
source=fs.readFile('src/server/PrototypeWorld.luau'):gsub('\r\n','\n')
source=source:gsub('\t\tif diagnostic then PerformanceMonitor.lifecycle%(contexts%) end\n','')
source=source:gsub('\t\t\t\tlocal before=if diagnostic then context.chassis.AssemblyLinearVelocity else nil\n','')
source=source:gsub('PerformanceMonitor.observe%(context,deltaTime,%(os.clock%(%)%-began%)%*1000,before%)','PerformanceMonitor.observe(context,deltaTime,(os.clock()-began)*1000)')
check(baseline.ok and source==baseline.stdout:gsub('\r\n','\n'),'exact full simulation preservation')
baseline=process.exec('git',{'-C',root,'show','e095cfda25405fcf25fe1ca11ba8183ace05fc89:src/client/KartInputController.luau'})
source=fs.readFile('src/client/KartInputController.luau'):gsub('\r\n','\n')
source=source:gsub('local perfModule = script.Parent:FindFirstChild%("RacePerformanceMonitor"%)\nlocal PerformanceMonitor = perfModule and requireModule%(perfModule%)\n','')
source=source:gsub('\t\t\tif PerformanceMonitor then PerformanceMonitor.inputSent%(throttle, steering, driftRequested%) end\n','')
check(baseline.ok and source==baseline.stdout:gsub('\r\n','\n'),'exact input sending behavior preservation')
print('PASS: '..n..' P1 current monitor paired clocks, pre/post, isolation, rounds, counts and unchanged driving assertions')
