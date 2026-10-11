local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local B=luau.load(fs.readFile('src/shared/KDMPerformanceBuffer.luau'))()
local now,logs,encoded,memoryCalls=0,{},nil,0
local attrs={RaceState='RACING',RaceSessionId=1}
local player={UserId=11700555357,GetAttribute=function(_,k)return attrs[k] end}
local gui={FindFirstChild=function()return {GetAttribute=function()return true end}end}
player.PlayerGui=gui
local services={Players={LocalPlayer=player,GetPlayers=function()return {player}end},RunService={IsStudio=function()return false end},
 HttpService={JSONEncode=function(_,row)encoded=row;return 'bounded report' end},
 Stats={GetTotalMemoryUsageMb=function()memoryCalls+=1;return 123 end}}
local workspace={GetServerTimeNow=function()return now end}
local env={game={GameId=10768420544,PlaceId=127925465904803,ReplicatedStorage={Shared={KDMPerformanceBuffer={}}},GetService=function(_,k)return services[k]end},
 require=function()return B end,workspace=workspace,os={clock=function()return now end},time=function()return now end,
 warn=function(t)table.insert(logs,t)end,Instance={new=function()return {}end},UDim2=rb.UDim2,Enum=rb.Enum,Color3=rb.Color3}
local server=luau.load(fs.readFile('src/server/RacePerformanceMonitor.luau'),{environment=env})()
local n=0
local function check(v,label)assert(v,label);n+=1 end
check(server.active(),'single approved account activates diagnostic observation')
local kartAttrs={RaceResetSerial=0}
local kart={GetAttribute=function(_,k)return kartAttrs[k]end,SetAttribute=function(_,k,v)kartAttrs[k]=v end}
local c={owner=player,chassis={AssemblyLinearVelocity=rb.Vector3.new(70,0,0),Position=rb.Vector3.zero,GetNetworkOwner=function()return nil end},seat={Occupant={}},kart=kart,
 commandedSpeed=70,control={lastUpdate=0,throttle=1,steering=0},slick={active=false}}
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
local client=luau.load(fs.readFile('src/client/RacePerformanceMonitor.luau'),{environment=env})()
client.observe(c.chassis,70,.016,.1);client.observe(c.chassis,70,.016,.1)
now=6;client.observe(c.chassis,0,4,.1)
check(encoded.event=='ZERO_SPEED' and encoded.sample.auto==true,'client AUTO and zero observation')
check(encoded.sample.serverDt==4 and encoded.sample.serverEventAge==2,'stale server event distinguished by age')
check(#logs==2,'one server and one client event, no per-frame logging')
attrs.RaceState='FINISHED';client.observe(c.chassis,0,.016,.1)
player.UserId=1;now=20;check(not server.active(),'nonapproved live users leave diagnostics disabled')
print('PASS: '..n..' actual server/client monitor gate, Bot, ZERO/AUTO, timestamp and cleanup checks')
