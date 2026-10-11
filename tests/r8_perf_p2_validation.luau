local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local Buffer=luau.load(fs.readFile('src/shared/KDMPerformanceBuffer.luau'))()
local now,requests,logs,labels=0,{},{},{}
local attrs={RaceState='RACING',OfficialRoundGuid='r1'}
local player={UserId=11700555357,GetAttribute=function(_,k)return attrs[k]end,
 PlayerGui={FindFirstChild=function()return {GetAttribute=function()return true end}end}}
local remote={Name='KDMPerfSnapshot',OnClientEvent={Connect=function()return {Connected=true}end},FireServer=function(_,r)table.insert(requests,r)end}
local storage={Shared={KDMPerformanceBuffer='BUFFER'},FindFirstChild=function()return remote end}
local services={Players={LocalPlayer=player},RunService={IsStudio=function()return false end},ReplicatedStorage=storage,
 Stats={GetTotalMemoryUsageMb=function()return 100 end},HttpService={JSONEncode=function(_,r)table.insert(logs,r);return serde.encode('json',r)end}}
local env={game={GameId=10768420544,PlaceId=127925465904803,ReplicatedStorage=storage,GetService=function(_,k)return services[k]end},
 require=function()return Buffer end,os={clock=function()return now end},workspace={GetServerTimeNow=function()return now end,GetAttribute=function()return nil end},
 warn=function()end,Instance={new=function(kind)local v={};if kind=='TextLabel' then table.insert(labels,v)end;return v end},UDim2=rb.UDim2,Enum=rb.Enum,Color3=rb.Color3}
local client=luau.load(fs.readFile('src/client/RacePerformanceMonitor.luau'),{environment=env})()
local chassis={Parent={GetAttribute=function()return 0 end,FindFirstChild=function()return {Occupant=nil}end},Position=rb.Vector3.zero}
local n=0
local function check(v,label)assert(v,label);n+=1 end
client.observe(chassis,70,.016,12)
for i=1,1000 do now=i*.016;client.frame(.016,12);client.observe(chassis,70,.016,12) end
check(#requests==0 and #logs==0 and #labels==0,'LIGHT HUD_WORK has zero JSON, requests or banners')
check(client.buffer.count<=60,'evidence remains bounded')
local summary=client.summary()
check(summary.frames==1000 and summary.hudSlow==1000 and summary.frameGaps==0,'CPU work distinct from frame gaps')
check(summary.sections.hudCallback.p95==12 and summary.sections.frameInterval.p95==16,'units and quantiles')
for i=1,600 do client.metric('synthetic',i) end
summary=client.summary().sections.synthetic
check(summary.p50==300 and summary.p95==575 and summary.max==600 and summary.count==600,'bounded whole-race quantile histogram')
now+=11;client.observe(chassis,0,.016,12)
check(#requests==1 and logs[#logs].event=='ZERO_SPEED','LIGHT true zero retains detailed evidence')
check(requests[1].round=='r1' and requests[1].t==now,'same server clock and round')
now+=.1;client.observe(chassis,70,.016,12)
check(logs[#logs].event=='ZERO_RECOVERED','recovery evidence retained')
now+=11;client.observe(chassis,70,.2,12)
check(logs[#logs].event=='RENDER_GAP','real frame gap retains detailed evidence')
client.configure('OFF');local count=#requests;local logCount=#logs
now+=11;client.observe(chassis,0,.3,20);client.frame(.3,20)
check(#requests==count and #logs==logCount and client.summary().frames==1,'OFF removes anomaly work but keeps shared A/B profiler')
client.configure('DETAIL');client.observe(chassis,70,.016,12);now+=11;client.observe(chassis,70,.016,12)
check(logs[#logs].event=='HUD_WORK' and #requests>count,'DETAIL restores diagnostic A/B baseline')
-- DIGITAL must not load or instantiate the analog donor/presentation at all.
local objects,requires={},0
local controller=luau.load(fs.readFile('src/client/V2GaugeController.luau'),{environment={
 Instance={new=function(kind)local obj={kind=kind,Destroy=function(self)self.destroyed=true end};table.insert(objects,obj);return obj end},
 Enum=rb.Enum,Vector2=rb.Vector2,UDim2=rb.UDim2,Color3=rb.Color3,
 require=function()requires+=1;error('analog required in digital mode')end}})()
local digital=controller.new({},'DIGITAL');digital:update(chassis,70,.08,true,true)
check(requires==0 and #objects==2,'DIGITAL creates only ScreenGui and passive label')
check(objects[2].Text=='71 KM/H','unchanged 1.008 conversion')
digital:update(chassis,0,.08,true,true);check(objects[2].Text=='0 KM/H','real zero never hidden')
digital:update(nil,0,.08,true,false);check(not objects[2].Visible,'unseated inactive HUD hidden')
check(objects[1].ScreenInsets==rb.Enum.ScreenInsets.CoreUISafeInsets and objects[1].ClipToDeviceSafeArea,'digital safe area')
digital:destroy();check(objects[1].destroyed,'mode switch owns teardown')
local view=luau.load(fs.readFile('src/client/MobileControlView.luau'),{environment={Vector2=rb.Vector2,Color3=rb.Color3}})()
for _,pair in {{832,384},{844,390},{932,430},{724,260},{640,360},{390,844}} do
 local size=rb.Vector2.new(pair[1],pair[2]);local l=view.layout(size);local d=controller.digitalLayout(size,l)
 local left,right=size.X*.5-d.width*.5,size.X*.5+d.width*.5
 local top,bottom=size.Y-d.bottom-38,size.Y-d.bottom
 check(left>=0 and right<=size.X and top>=0 and bottom<=size.Y,'digital within safe size')
 local function overlaps(x,y,w,h)return left<x+w and right>x and top<y+h and bottom>y end
 check(not overlaps(l.driftX,size.Y-l.driftBottom-l.driftHitHeight,l.driftHitWidth,l.driftHitHeight),'digital clears Drift hit area')
 check(not overlaps(size.X-l.margin-l.padWidth-l.padInset,size.Y-l.padBottom-l.padHeight,l.padWidth,l.padHeight),'digital clears driving controls')
end
-- Reproducible host-side diagnostic-path comparison, not mobile rendering timing.
local comparison={}
for _,mode in {'OFF','LIGHT','DETAIL'} do
 local c=luau.load(fs.readFile('src/client/RacePerformanceMonitor.luau'),{environment=env})()
 c.configure(mode);table.clear(requests);table.clear(logs);now=0
 local costs={};local started=os.clock()
 for i=1,12000 do
  now=i/60;local before=os.clock();c.observe(chassis,70,1/60,12);costs[i]=(os.clock()-before)*1000
 end
 local total=(os.clock()-started)*1000;table.sort(costs)
 local bytes=0;for _,row in logs do bytes+=#serde.encode('json',row) end
 comparison[mode]={frames=12000,p50=costs[6000],p95=costs[11400],max=costs[12000],totalMs=total,jsonCalls=#logs,jsonBytes=bytes,pairRequests=#requests}
end
check(comparison.LIGHT.jsonCalls==0 and comparison.DETAIL.jsonCalls>0,'measured ordinary-work serialization eliminated')
fs.writeDir('artifacts/r8-perf-p2')
fs.writeFile('artifacts/r8-perf-p2/host-diagnostic-comparison.json',serde.encode('json',comparison,true))
print('PASS: '..n..' P2 light/detail/off, timing statistics, real anomaly evidence and digital-only factory checks')
