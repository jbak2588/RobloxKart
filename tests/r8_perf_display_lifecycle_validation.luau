local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local Buffer=luau.load(fs.readFile('src/shared/KDMPerformanceBuffer.luau'))()
local now,labels,events,requests=0,{},{},{}
local attrs={RaceState='RACING',OfficialRoundGuid='r1'}
local player={UserId=11700555357,GetAttribute=function(_,k)return attrs[k]end,
 PlayerGui={FindFirstChild=function()return {GetAttribute=function()return true end}end}}
local remote={Name='KDMPerfSnapshot',OnClientEvent={Connect=function()return {Connected=true}end},
 FireServer=function(_,v)table.insert(requests,v)end}
local storage={Shared={KDMPerformanceBuffer='BUFFER'},FindFirstChild=function()return remote end}
local services={Players={LocalPlayer=player},RunService={IsStudio=function()return false end},ReplicatedStorage=storage,
 Stats={GetTotalMemoryUsageMb=function()return 100 end},HttpService={JSONEncode=function(_,v)table.insert(events,v);return 'test' end}}
local env={game={GameId=10768420544,PlaceId=127925465904803,ReplicatedStorage=storage,GetService=function(_,k)return services[k]end},
 require=function()return Buffer end,os={clock=function()return now end},workspace={GetServerTimeNow=function()return now end},
 warn=function()end,Instance={new=function(kind)local v={};if kind=='TextLabel' then table.insert(labels,v)end;return v end},
 UDim2=rb.UDim2,Enum=rb.Enum,Color3=rb.Color3}
local client=luau.load(fs.readFile('src/client/RacePerformanceMonitor.luau'),{environment=env})()
client.configure('DETAIL')
local kart={GetAttribute=function()return 0 end,FindFirstChild=function()return {Occupant=nil}end}
local chassis={Parent=kart,Position=rb.Vector3.zero}
local n=0
local function check(v,label)assert(v,label);n+=1 end
local function anomaly(dt,work)
 now+=11;client.observe(chassis,70,dt,work)
end
client.observe(chassis,70,.016,.1)
anomaly(.017,9)
check(events[#events].event=='HUD_WORK','normal render dt plus expensive HUD is not mislabeled render gap')
check(labels[1].Text:find('HUD 9.0ms',1,true)~=nil,'measured trigger work cost visible')
check(labels[1].Visible and #requests==1,'HUD work still captures and requests real evidence')
now+=6.1;client.updateDisplay()
check(not labels[1].Visible,'expiry independent of physics observer')
anomaly(.2,.1)
check(events[#events].event=='RENDER_GAP' and labels[1].Visible,'actual long frame classified separately')
attrs.RaceState='FINISHED';client.updateDisplay()
check(not labels[1].Visible,'finish hides banner without another observe call')
client.receive({kind='PAIR',user=player.UserId,round='r1',client={t=now},history={}})
client.observe(chassis,0,.016,.1)
check(not labels[1].Visible,'late pair cannot resurrect banner on results')
attrs.RaceState='RACING';attrs.OfficialRoundGuid='r2';client.observe(chassis,70,.016,.1)
anomaly(.2,.1);attrs.OfficialRoundGuid='r3';client.updateDisplay()
check(not labels[1].Visible,'new round rejects old banner')
client.observe(chassis,70,.016,.1);anomaly(.016,.1)
client.observe(chassis,0,.016,.1)
check(events[#events].event=='ZERO_SPEED','actual velocity collapse remains visible and unmasked')
check(#labels==1,'rematches reuse one label')
local hud=fs.readFile('src/client/RaceHudController.luau')
local updateAt=hud:find('performanceMonitor.updateDisplay()',1,true)
local earlyReturn=hud:find('if not drivingHud then',updateAt,true)
check(updateAt~=nil and earlyReturn~=nil and updateAt<earlyReturn,'HUD owns cleanup before non-driving return')
print('PASS: '..n..' production diagnostic display lifecycle and cause classification checks')
