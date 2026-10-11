local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local B=luau.load(fs.readFile('src/shared/KDMPerformanceBuffer.luau'))()
local n=0
local function check(v,label)assert(v,label);n+=1 end
for _,id in {11700555357,11736539305} do
 check(B.allowed(false,id,10768420544,127925465904803),'approved diagnostic account')
 check(not B.allowed(false,id,1,127925465904803),'wrong experience blocked')
 check(not B.allowed(false,id,10768420544,1),'wrong place blocked')
end
check(not B.allowed(false,11736656701,10768420544,127925465904803),'stain2588 not enabled')
check(not B.allowed(false,99,10768420544,127925465904803),'general users blocked')
check(B.allowed(true,99,0,0),'existing Studio diagnostic behavior preserved')
local function signal()return {Connect=function(self,fn)self.fn=fn;return {Connected=true}end}end
local attrs={RaceState='RACING',OfficialRoundGuid='round1',RaceSessionId=1}
local function player(id)return {UserId=id,Character={},GetAttribute=function(_,k)return attrs[k]end,
 PlayerGui={FindFirstChild=function()return {GetAttribute=function()return true end}end}} end
local primary,partner,other=player(11700555357),player(11736539305),player(99)
local sent={}
local remote={Name='KDMPerfSnapshot',OnClientEvent=signal(),OnServerEvent=signal(),FireClient=function(_,p,r)table.insert(sent,{p=p,row=r})end}
local storage={Shared={KDMPerformanceBuffer='BUFFER',KartConfig='CONFIG'},FindFirstChild=function()return remote end}
local services={Players={LocalPlayer=partner,PlayerRemoving=signal(),GetPlayers=function()return {primary,partner,other}end},
 ReplicatedStorage=storage,RunService={IsStudio=function()return false end},Stats={GetTotalMemoryUsageMb=function()return 100 end},
 HttpService={JSONEncode=function()return 'test' end}}
local now=0
local env={game={GameId=10768420544,PlaceId=127925465904803,ReplicatedStorage=storage,GetService=function(_,k)return services[k]end},
 require=function(m)return if m=='CONFIG' then {INPUT_TIMEOUT=.5} else B end,Vector3=rb.Vector3,
 workspace={GetServerTimeNow=function()return now end,GetDescendants=function()return {}end},os={clock=function()return now end},
 time=function()return now end,warn=function()end,Instance={new=function()return {}end},UDim2=rb.UDim2,Enum=rb.Enum,Color3=rb.Color3}
local server=luau.load(fs.readFile('src/server/RacePerformanceMonitor.luau'),{environment=env})()
local function context(p)
 local seat={Occupant={Parent=p.Character}}
 local kart={GetAttribute=function(_,k)return if k=='RaceResetSerial' then 0 else false end,SetAttribute=function()end,FindFirstChild=function()return seat end}
 local chassis={Parent=kart,Position=rb.Vector3.zero,AssemblyLinearVelocity=rb.Vector3.new(70,0,0),GetNetworkOwner=function()return nil end}
 return {owner=p,kart=kart,chassis=chassis,seat=seat,commandedSpeed=70,control={lastUpdate=0,throttle=1,steering=0},slick={active=false},ownerConnections={}}
end
local a,b=context(primary),context(partner)
server.lifecycle({[a]=true,[b]=true});server.observe(a,.016,.1,a.chassis.AssemblyLinearVelocity);server.observe(b,.016,.1,b.chassis.AssemblyLinearVelocity)
check(#sent==4,'normal snapshots delivered to both approved accounts')
for _,r in sent do check(r.p~=other,'no diagnostics delivered to ordinary user')end
remote.OnServerEvent.fn(partner,{t=now,round='round1',speed=0,dt=.016})
check(sent[#sent].p==partner and sent[#sent].row.kind=='PAIR' and sent[#sent].row.user==partner.UserId,'partner receives its own paired context history')
local client=luau.load(fs.readFile('src/client/RacePerformanceMonitor.luau'),{environment=env})()
client.receive(sent[1].row);client.observe(b.chassis,70,.016,.1);now=.11;client.observe(b.chassis,70,.016,.1)
check(client.buffer:snapshot()[client.buffer.count].server==nil,'partner ignores primary player snapshot')
client.receive(sent[3].row);now=.22;client.observe(b.chassis,70,.016,.1)
check(client.buffer:snapshot()[client.buffer.count].server.user==partner.UserId,'partner observes own server snapshot')
print('PASS: '..n..' approved partner, exact target gating and per-player transport checks')
