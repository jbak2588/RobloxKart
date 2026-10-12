local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local Buffer=luau.load(fs.readFile('src/shared/KDMPerformanceBuffer.luau'))()
local now=0
local attrs={RaceState='RACING',OfficialRoundGuid='round1'}
local services={Players={LocalPlayer={UserId=11700555357,GetAttribute=function(_,k)return attrs[k]end}},
 RunService={IsStudio=function()return false end},Stats={GetTotalMemoryUsageMb=function()return 100 end},HttpService={}}
local env={game={GameId=10768420544,PlaceId=127925465904803,ReplicatedStorage={Shared={KDMPerformanceBuffer={}}},
 GetService=function(_,k)return services[k] end},require=function()return Buffer end,os={clock=function()return now end},
 workspace={GetAttribute=function()end,GetServerTimeNow=function()return now end},warn=function()error('unexpected per-frame logging')end}
-- No remote is available; instrumentation must not discover/create one in these mocks.
services.ReplicatedStorage={FindFirstChild=function()end,ChildAdded={Connect=function()return {} end}}
local client=luau.load(fs.readFile('src/client/RacePerformanceMonitor.luau'),{environment=env})()
local n=0
local function check(v,label)n+=1;assert(v,label)end
local function frame(dt,cpu)
 now+=dt;client.beginFrame(dt);client.metric('gauge',cpu);client.frame(dt,cpu);client.completedFrame(cpu)
end
for i=1,1500 do frame(.02,.2) end
for i=1,500 do frame(.06,.3) end
local result=client.summary()
check(#result.windows==2,'separate thirty-second windows')
check(result.windows[1].frames==1500 and result.windows[1].rate33==0,'early window remains smooth')
check(result.windows[2].frames==500 and result.windows[2].rate33==1 and result.windows[2].rate50==1,'late frame trend quantified')
check(result.windows[1].sections.frameInterval.p95==20 and result.windows[2].sections.frameInterval.p95==60,'render quantiles separate from callback CPU')
check(result.windows[2].sections.gauge.max==.3 and result.frameGaps==0,'slow render does not imply long gap or slow gauge')
check(result.raceNumber==1 and result.appSeconds>=60,'app/race chronology')
check(result.temperature=='N/A' and result.recording=='N/A','unobservable device state not invented')
attrs.OfficialRoundGuid='round2';frame(.016,.1)
check(client.summary().frames==1 and client.summary().rematch==1,'rematch clears stats and increments logical race')
now+=.005;client.event(24,'LOCAL:RacePosition',false);client.completedFrame(1)
frame(.04,.2)
result=client.summary()
check(result.framePeaks[1].events[1].cause=='LOCAL:RacePosition','timestamped event falls within preceding render interval')
check(result.framePeaks[1].previousCallbackMs==1,'previous callback correlated, not current CPU mislabeled')
check(not result.framePeaks[1].events[1].nestedInBotResults,'attribute event distinguished from nested Bot poll')
client.event(20,'BOT_POLL',true)
check(client.summary().eventPeaks[2].nestedInBotResults,'nested timing explicitly flagged, never summed')
for i=1,14000 do frame(.04,.2) end
result=client.summary()
check(#result.windows<=13 and #result.framePeaks<=8 and #result.eventPeaks<=8,'long session memory bounded')
client.configure('OFF');frame(.2,.1)
check(client.summary().frames==1 and client.summary().frameGaps==1,'OFF uses same minimal profiler')
client.configure('LIGHT');frame(.016,.1)
check(client.summary().frames==1 and client.summary().frameGaps==0,'mode reset does not contaminate A/B')
-- HUD integration: event causes are passed by actual signal bindings; measured
-- callback begins before the trend bookkeeping and layout is not changed here.
local hud=fs.readFile('src/client/RaceHudController.luau')
check(hud:find("updateHud('BOT_POLL',true)",1,true) and hud:find("updateHud('LOCAL:'..attributeName,false)",1,true),'actual event source tags')
local source=fs.readFile('src/client/RacePerformanceMonitor.luau')
check(source:find("summaryScroll.CanvasSize",1,true) and source:find("{'frameInterval','callbackTotal'",1,true),'render evidence first and full summary scrollable')
check(source:find("if not canChoose() then return end",1,true),'GO transition cannot change modes through stale visible button')
-- Execute the actual staging/result view, including a delayed save response.
local heartbeat,objects=nil,{}
services.RunService.Heartbeat={Connect=function(_,f)heartbeat=f;return {} end}
env.Instance={new=function(kind)
 local object={Name=kind,AbsoluteSize=rb.Vector2.new(844,320),Activated={Connect=function(self,f)self.callback=f end}}
 table.insert(objects,object);return object
end}
env.UDim2,env.Vector2,env.Color3,env.Enum=rb.UDim2,rb.Vector2,rb.Color3,rb.Enum
services.Players.LocalPlayer.PlayerGui={}
services.HttpService.JSONEncode=function(_,v)return serde.encode('json',v)end
env.warn=function()end
attrs.RaceState='WAITING';attrs.OfficialRoundGuid='view-round'
local view=luau.load(source,{environment=env})()
heartbeat(1)
local panel,scroll,label,modeButton
for _,o in objects do
 if o.Name=='Panel' then panel=o elseif o.Name=='SummaryScroll' then scroll=o
 elseif o.Name=='TextLabel' then label=o elseif o.Name=='TextButton' and not modeButton then modeButton=o end
end
check(panel.Size.Y.Offset==36 and not scroll.Visible,'compact waiting controls preserved')
attrs.RaceState='RACING';view.beginFrame(.016);view.frame(.016,.1);view.metric('callbackTotal',.2);heartbeat(1)
check(not objects[1].Enabled,'controls hidden during racing')
modeButton.Activated.callback() -- no workspace setter in mock; would throw if allowed
attrs.RaceState='FINISHED';heartbeat(1)
check(scroll.Visible and scroll.CanvasSize.Y.Offset>scroll.Size.Y.Offset,'complete results scroll range')
check(label.Text:find('frameInterval',1,true) and label.Text:find('callbackTotal',1,true),'actual render and callback numbers visible')
attrs.RaceRecordDiagnostic='FINAL / READ_ONLY / ABSENT';attrs.RaceRecordReceiptConfirmed=false;heartbeat(1)
check(label.Text:find('FINAL / READ_ONLY / ABSENT',1,true),'late server diagnostic updates existing result')
attrs.RaceState='WAITING';heartbeat(1)
check(panel.Size.Y.Offset==36 and not scroll.Visible,'Rematch collapses result without covering invite/Bot buttons')
print('PASS: '..n..' P2B window statistics, bounded correlation, round and diagnostic-mode checks')
