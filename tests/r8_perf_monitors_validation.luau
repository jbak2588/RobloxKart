local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local B=luau.load(fs.readFile('src/shared/KDMPerformanceBuffer.luau'))()
local now,logs,encoded,memoryCalls=0,{},nil,0
local attrs={RaceState='RACING',RaceSessionId=1}
local player={UserId=11700555357,GetAttribute=function(_,k)return attrs[k] end}
local gui={FindFirstChild=function()return {GetAttribute=function()return true end}end}
player.PlayerGui=gui
function player:FindFirstChild(name)return if name=='PlayerGui' then gui else nil end
local latestServerSnapshot
local snapshot={OnServerEvent={Connect=function()end},OnClientEvent={Connect=function()end},FireClient=function(_,_,row)
 if row.user==player.UserId then latestServerSnapshot=row end
end}
local storage={FindFirstChild=function()return snapshot end,ChildAdded={Connect=function()end}}
local services={Players={LocalPlayer=player,GetPlayers=function()return {player}end,PlayerRemoving={Connect=function()end}},RunService={IsStudio=function()return false end},
 ReplicatedStorage=storage,
 HttpService={JSONEncode=function(_,row)encoded=row;return 'bounded report' end},
 Stats={GetTotalMemoryUsageMb=function()memoryCalls+=1;return 123 end}}
local workspace={GetAttribute=function(_,k)return k=="KDMPerfInternalEnabled" or k=="KDMPerfCanaryUI" end,GetServerTimeNow=function()return now end}
local config=require('./helpers/gameplay_config')('src/shared/KartConfig.luau')
local env={game={GameId=10768420544,PlaceId=127925465904803,ReplicatedStorage={Shared={KDMPerformanceBuffer='BUFFER',KartConfig='CONFIG'}},GetService=function(_,k)return services[k]end},
 require=function(m)return if m=='CONFIG' then config else B end,workspace=workspace,os={clock=function()return now end},time=function()return now end,
 warn=function(t)table.insert(logs,t)end,Instance={new=function()return {}end},UDim2=rb.UDim2,Enum=rb.Enum,Color3=rb.Color3,Vector3=rb.Vector3}
local server=luau.load(fs.readFile('src/server/RacePerformanceMonitor.luau'),{environment=env})()
local n=0
local function check(v,label)assert(v,label);n+=1 end
check(server.active(),'single approved account activates diagnostic observation')
local kartAttrs={RaceResetSerial=0}
local kart={GetAttribute=function(_,k)return kartAttrs[k]end,SetAttribute=function(_,k,v)kartAttrs[k]=v end}
function kart:FindFirstChild(name)return if name=='Seat' then {Occupant={}} else nil end
function kart:FindFirstChildWhichIsA()return nil end
local c={owner=player,chassis={AssemblyLinearVelocity=rb.Vector3.new(70,0,0),Position=rb.Vector3.zero,GetNetworkOwner=function()return nil end},seat={Occupant={}},kart=kart,
 commandedSpeed=70,control={lastUpdate=0,throttle=1,steering=0},slick={active=false}}
server.route(.016,.3,1)
server.observe(c,.016,.2);check(memoryCalls==0 and #logs==0,'normal frames avoid memory probes and logs')
now=4;c.chassis.AssemblyLinearVelocity=rb.Vector3.zero
server.observe(c,4,.2)
check(#logs==1 and encoded.event=='ZERO_SPEED','actual velocity collapse detected without altering physics')
check(encoded.sample.inputAge==4 and encoded.sample.dt==4 and encoded.sample.command==70,'input/dt/command evidence retained')
check(kartAttrs.KDMPerfServerAt==4 and kartAttrs.KDMPerfServerDt==4,'shared event timestamp retained')
local oldOwner=c.owner;c.owner={GetAttribute=function()return 'RACING' end};c.botParticipant={}
now=5;server.observe(c,.016,.2);check(server.buffer:snapshot()[server.buffer.count].user=='BOT','Bot Folder needs no Player UserId member')
server.remove(c);check(server.previous[c]==nil and server.lastSample[c]==nil,'destroyed context anchors released')
c.owner=oldOwner;c.botParticipant=nil;c.chassis.Parent=kart
local client=luau.load(fs.readFile('src/client/RacePerformanceMonitor.luau'),{environment=env})();client.configure('LIGHT')
-- Production now receives server measurements through the snapshot transport.
client.receive(latestServerSnapshot)
local sections=client.summary().sections
check(sections.serverFrame and sections.serverKartStep and sections.serverRaceLoop and sections.serverInputAge and sections.snapshotAge,'published summary includes correlated server measurements')
client.observe(c.chassis,70,.016,.1);client.observe(c.chassis,70,.016,.1)
now=6;client.observe(c.chassis,0,4,.1)
check(encoded.event=='ZERO_SPEED' and encoded.sample.auto==true,'client AUTO and zero observation')
check(encoded.sample.serverDt==4 and encoded.sample.serverEventAge==2,'stale server event distinguished by age')
check(#logs==2,'one server and one client event, no per-frame logging')
attrs.RaceState='FINISHED';client.observe(c.chassis,0,.016,.1)
player.UserId=1;now=20;check(not server.active(),'nonapproved live users leave diagnostics disabled')
print('PASS: '..n..' actual server/client monitor gate, Bot, ZERO/AUTO, timestamp and cleanup checks')
