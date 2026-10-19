local RunService=game:GetService('RunService')
local Players=game:GetService('Players')
local HttpService=game:GetService('HttpService')
local Stats=game:GetService('Stats')
local Buffer=require(game.ReplicatedStorage.Shared.KDMPerformanceBuffer)
local Monitor={buffer=Buffer.new(60)}
local player=Players.LocalPlayer
-- Internal opt-in before controller startup; no public panels/connections or
-- profiler work by default, including the previously whitelisted accounts.
local enabled=workspace:GetAttribute('KDMPerfInternalEnabled')==true
 and Buffer.allowed(RunService:IsStudio(),player.UserId,game.GameId,game.PlaceId)
local mode='OFF'
local resetRequested=false
local pendingPair
local latest,lastSent,lastInput,zeroSince,zeroDuration=nil,nil,nil,nil,0
local metrics={}
local frames,gaps,hudSlow=0,0,0
local over33,over50=0,0
local windowMetrics,windows={},{}
local windowFrames,windowGaps,window33,window50,windowSeconds=0,0,0,0,0
local raceRound,raceNumber,raceStarted=nil,0,0
local appStarted=os.clock()
local eventRows,framePeaks={},{}
local lastRenderAt,previousCallback=nil,nil
local memoryMb,lastMemoryAt=nil,-math.huge
local function clearRace()
 metrics={};frames,gaps,hudSlow=0,0,0;over33,over50=0,0
 windowMetrics={};windows={};windowFrames,windowGaps,window33,window50,windowSeconds=0,0,0,0,0
 eventRows={};framePeaks={};lastRenderAt,previousCallback=nil,nil
end
function Monitor.configure(nextMode)
 if not enabled then return end
 assert(nextMode=='OFF' or nextMode=='LIGHT' or nextMode=='DETAIL','Unknown diagnostic mode')
 mode=nextMode; pendingPair=nil;resetRequested=true;clearRace()
end
function Monitor.active() return enabled end
function Monitor.gaugeMode()
 return if enabled and workspace:GetAttribute('KDMPerfGaugeMode')=='DIGITAL' then 'DIGITAL' else 'ANALOG'
end
local function accumulate(group,name,ms)
 local m=group[name]
 if not m then m={histogram={},count=0,total=0,max=0};group[name]=m end
 -- Fixed range: .05ms bins through 20ms, 1ms through 250ms,
 -- 25ms through 2s, then one overflow bin. Whole-race, bounded storage.
 local bin=if ms<=20 then math.ceil(math.max(0,ms)*20) elseif ms<=250 then 400+math.ceil(ms-20)
  elseif ms<=2000 then 630+math.ceil((ms-250)/25) else 701
 m.histogram[bin]=(m.histogram[bin] or 0)+1
 m.count+=1;m.total+=ms;m.max=math.max(m.max,ms)
end
function Monitor.metric(name,ms)
 if not enabled then return end
 accumulate(metrics,name,ms)
 if player:GetAttribute('RaceState')=='RACING' then accumulate(windowMetrics,name,ms) end
end
local function retain(list,row,limit)
 table.insert(list,row);if #list>limit then table.remove(list,1) end
end
function Monitor.beginFrame(dt)
 if not enabled or player:GetAttribute('RaceState')~='RACING' then return end
 local round=player:GetAttribute('OfficialRoundGuid') or player:GetAttribute('RaceSessionId')
 if round~=raceRound then clearRace();raceRound=round;raceNumber+=1;raceStarted=os.clock() end
 if windowSeconds>=30-1e-6 then
  retain(windows,{metrics=windowMetrics,frames=windowFrames,gaps=windowGaps,over33=window33,over50=window50,
   seconds=windowSeconds,at=os.clock()-raceStarted,memoryMb=memoryMb,
   serverCounts=latest and latest.round==raceRound and latest.counts or nil},12)
  windowMetrics={};windowFrames,windowGaps,window33,window50,windowSeconds=0,0,0,0,0
 end
 local now=os.clock()
 if dt>1/30 and (#framePeaks<8 or dt*1000>framePeaks[#framePeaks].intervalMs) then
  local events={}
  for _,row in eventRows do if lastRenderAt and row.at>=lastRenderAt and row.at<=now then table.insert(events,row) end end
  local row={t=workspace:GetServerTimeNow(),raceSeconds=now-raceStarted,intervalMs=dt*1000,
   previousCallbackMs=previousCallback,events=events}
  table.insert(framePeaks,row);table.sort(framePeaks,function(a,b)return a.intervalMs>b.intervalMs end)
  if #framePeaks>8 then table.remove(framePeaks) end
 end
 lastRenderAt=now
end
function Monitor.event(ms,cause,nested)
 if not enabled then return end
 Monitor.metric('hudEvent',ms)
 if ms>=8 then retain(eventRows,{at=os.clock(),t=workspace:GetServerTimeNow(),ms=ms,
  cause=cause or 'OTHER',nestedInBotResults=nested==true,round=player:GetAttribute('OfficialRoundGuid')},8) end
end
function Monitor.completedFrame(ms) if enabled then previousCallback=ms end end
function Monitor.frame(dt,workMs)
 if not enabled or player:GetAttribute('RaceState')~='RACING' then return end
 frames+=1;if dt>=.15 then gaps+=1 end;if workMs>=8 then hudSlow+=1 end
 if dt>1/30 then over33+=1 end;if dt>.05 then over50+=1 end
 windowFrames+=1;windowSeconds+=dt
 if dt>=.15 then windowGaps+=1 end
 if dt>1/30 then window33+=1 end;if dt>.05 then window50+=1 end
 Monitor.metric('frameInterval',dt*1000);Monitor.metric('hudCallback',workMs)
end
-- Quantiles are calculated only on explicit requests, never inside RenderStepped.
local function quantiles(group)
 local sections={}
 for name,m in group do
  local total,p50,p95=0,nil,nil
  for bin=0,701 do
   total+=m.histogram[bin] or 0
   local upper=if bin<=400 then bin/20 elseif bin<=630 then 20+bin-400 elseif bin<=700 then 250+(bin-630)*25 else m.max
   upper=math.min(upper,m.max)
   if not p50 and total>=math.ceil(m.count*.5) then p50=upper end
   if total>=math.ceil(m.count*.95) then p95=upper;break end
  end
  sections[name]={count=m.count,p50=p50,p95=p95,max=m.max,mean=m.total/m.count,quantiles='histogram upper bounds'}
 end
 return sections
end
function Monitor.trend()
 local out={}
 local function add(w)
  table.insert(out,{frames=w.frames,seconds=w.seconds,endingAt=w.at,gaps=w.gaps,over33=w.over33,over50=w.over50,
   memoryMb=w.memoryMb,serverCounts=w.serverCounts,
   rate33=if w.frames>0 then w.over33/w.frames else 0,rate50=if w.frames>0 then w.over50/w.frames else 0,
   sections=quantiles(w.metrics)})
 end
 for _,w in windows do add(w) end
 if windowFrames>0 then add({metrics=windowMetrics,frames=windowFrames,seconds=windowSeconds,at=os.clock()-raceStarted,
  gaps=windowGaps,over33=window33,over50=window50,memoryMb=memoryMb,
  serverCounts=latest and latest.round==raceRound and latest.counts or nil}) end
 return out
end
function Monitor.summary()
 local result={mode=mode,gauge=Monitor.gaugeMode(),frames=frames,frameGaps=gaps,frameOver33ms=over33,frameOver50ms=over50,
  hudSlow=hudSlow,sections=quantiles(metrics),windows=Monitor.trend(),framePeaks=framePeaks,eventPeaks=eventRows,
  raceNumber=raceNumber,rematch=math.max(0,raceNumber-1),raceSeconds=os.clock()-raceStarted,appSeconds=os.clock()-appStarted,
  temperature='N/A',recording='N/A',charging='N/A',powerSaving='N/A'}
 if Stats.GetTotalMemoryUsageMb then local ok,v=pcall(function() return Stats:GetTotalMemoryUsageMb() end);if ok then result.memoryMb=v end end
 if latest then result.serverLifecycle=latest.lifecycle;result.serverCounts=latest.counts end
 local settings=UserSettings and UserSettings()
 if settings then local ok,v=pcall(function()return tostring(settings:GetService('UserGameSettings').SavedQualityLevel) end)
  if ok then result.graphics=v end end
 return result
end
if enabled and workspace.GetAttributeChangedSignal then
 local function refreshMode()
  local requested=workspace:GetAttribute('KDMPerfDiagnosticsMode')
  Monitor.configure(if requested=='OFF' or requested=='DETAIL' then requested else 'LIGHT')
 end
 workspace:GetAttributeChangedSignal('KDMPerfDiagnosticsMode'):Connect(refreshMode)
 refreshMode()
end
local reportedZero=false
Monitor.pairs=Buffer.new(6)
local snapshotConnection,discoveryConnection,snapshotRemote
function Monitor.inputSent(throttle,steering,drift)
 if not Monitor.active() or mode=='OFF' then return end
 lastSent=workspace:GetServerTimeNow();lastInput={throttle=throttle,steering=steering,drift=drift}
end
function Monitor.receive(row)
 if Monitor.active() and mode~='OFF' and type(row)=='table' and row.user==player.UserId then
  if row.kind=='PAIR' then
   Monitor.pairs:push(row);pendingPair=row
   local began=os.clock()
   if mode=='DETAIL' then warn('[KDMPerfPairClient] '..HttpService:JSONEncode(row)) end
   Monitor.metric('pairCallback',(os.clock()-began)*1000)
  else
   latest=row
   if player:GetAttribute('RaceState')=='RACING' and row.round==(player:GetAttribute('OfficialRoundGuid') or player:GetAttribute('RaceSessionId')) then
    if type(row.dt)=='number' then Monitor.metric('serverFrame',row.dt*1000) end
    if type(row.ms)=='number' then Monitor.metric('serverKartStep',row.ms) end
    if type(row.raceLoopMs)=='number' then Monitor.metric('serverRaceLoop',row.raceLoopMs) end
    if type(row.inputAge)=='number' then Monitor.metric('serverInputAge',row.inputAge*1000) end
    if type(row.t)=='number' then Monitor.metric('snapshotAge',math.max(0,workspace:GetServerTimeNow()-row.t)*1000) end
   end
  end
 end
end
if enabled then
 local storage=game:GetService('ReplicatedStorage')
 local function bind(child)
  if child.Name~='KDMPerfSnapshot' or snapshotConnection then return end
  snapshotRemote=child
  snapshotConnection=child.OnClientEvent:Connect(Monitor.receive)
  if discoveryConnection then discoveryConnection:Disconnect();discoveryConnection=nil end
 end
 bind(storage:FindFirstChild('KDMPerfSnapshot') or {Name=''})
 if not snapshotConnection then discoveryConnection=storage.ChildAdded:Connect(bind) end
end
local function value(n,multiplier)
 return if type(n)=='number' then string.format('%.2f',n*(multiplier or 1)) else 'N/A'
end
local previousSpeed,previousPosition,previousRound,lastSample=0,nil,nil,-math.huge
local display,shownUntil,displayRound=nil,0,nil
-- Called by the HUD before its non-driving early return. Expiry must not
-- depend on a seated kart or on the next race starting.
function Monitor.updateDisplay()
	if not enabled then return end
	local round=player:GetAttribute('OfficialRoundGuid') or player:GetAttribute('RaceSessionId')
	if player:GetAttribute('RaceState')~='RACING' then pendingPair=nil end
	if display and (mode=='OFF' or os.clock()>shownUntil or player:GetAttribute('RaceState')~='RACING' or displayRound~=round) then
		display.Visible=false
	end
end
local function show(text)
	if not display then
		local gui=Instance.new('ScreenGui');gui.Name='KDMPerfCanary';gui.ResetOnSpawn=false
		gui.DisplayOrder=11;gui.Parent=player.PlayerGui
		display=Instance.new('TextLabel');display.Size=UDim2.new(.6,0,0,32)
		display.Position=UDim2.new(.2,0,.24,0);display.BackgroundTransparency=.25
		display.BackgroundColor3=Color3.fromRGB(15,20,30);display.TextColor3=Color3.new(1,1,1)
		display.Font=Enum.Font.Code;display.TextSize=12;display.TextWrapped=true
		display.Active=false;display.Parent=gui
	end
	displayRound=player:GetAttribute('OfficialRoundGuid') or player:GetAttribute('RaceSessionId')
	display.Text=text;display.Visible=true;shownUntil=os.clock()+6
end
function Monitor.observe(chassis,speed,dt,workMs)
	if not Monitor.active() or mode=='OFF' then return end
	Monitor.updateDisplay()
	local round=player:GetAttribute('OfficialRoundGuid') or player:GetAttribute('RaceSessionId')
	if pendingPair then
		local pair=pendingPair;pendingPair=nil
		if pair.round==round and player:GetAttribute('RaceState')=='RACING' then
			local nearest,gap=nil,math.huge
			for _,sample in pair.history do
				local d=math.abs(sample.t-pair.client.t)
				if d<gap then nearest,gap=sample,d end
			end
			-- A sparse/old history is reported unavailable, not simultaneous evidence.
			if gap>.25 then nearest=nil end
			show(string.format('PAIR delta %ss pre/post %s/%s dt %sms timeout %s lock %s reset %s',
				value(if gap<math.huge then gap else nil),value(nearest and nearest.preSpeed),value(nearest and nearest.speed),
				value(nearest and nearest.dt,1000),if nearest then tostring(nearest.inputTimeout) else 'N/A',
				if nearest then tostring(nearest.locked) else 'N/A',if nearest then tostring(nearest.reset) else 'N/A'))
		end
	end
	if resetRequested or player:GetAttribute('RaceState')~='RACING' or round~=previousRound then
		resetRequested=false
		previousSpeed,previousPosition,previousRound=0,nil,round
		zeroSince,zeroDuration=nil,0
		reportedZero=false
		return
	end
	local now=os.clock()
	local position=chassis and chassis.Position
	local moved=position and previousPosition and (position-previousPosition).Magnitude or 0
	local zero=previousSpeed>20 and speed<1
	local recovered=zeroSince~=nil and speed>=1
	if zero then zeroSince=workspace:GetServerTimeNow() end
	if zeroSince then
		zeroDuration=workspace:GetServerTimeNow()-zeroSince
		if speed>=1 then zeroSince=nil end
	end
	previousSpeed,previousPosition=speed,position
	if now-lastSample<.1 and not zero and not recovered and dt<.15 and (mode~='DETAIL' or workMs<8) then return end
	lastSample=now
	local row={t=now,dt=dt,ms=workMs,speed=speed,moved=moved,seat=chassis~=nil,
		reset=chassis and chassis.Parent:GetAttribute('RaceResetSerial'),
		memoryMb=nil}
	row.t=workspace:GetServerTimeNow();row.round=round;row.zeroDuration=zeroDuration
	row.inputSentAt=lastSent;row.inputSentAge=lastSent and row.t-lastSent;row.input=lastInput
	local kart=chassis and chassis.Parent
	local seat=kart and kart:FindFirstChild('Seat')
	if not seat and kart then seat=kart:FindFirstChildWhichIsA('Seat',true) end
	row.chassisExists=chassis~=nil and chassis.Parent~=nil
	row.seatExists=seat~=nil
	row.seated=seat~=nil and seat.Occupant~=nil and player.Character~=nil and seat.Occupant.Parent==player.Character
	row.clientConnections={snapshot=snapshotConnection and snapshotConnection.Connected==true,discovery=discoveryConnection and discoveryConnection.Connected==true}
	if latest and latest.round==round then
		row.server=latest;row.serverAge=row.t-latest.t
		row.serverDt=latest.dt;row.serverInputAge=latest.inputAge
	end
	local controls=player.PlayerGui:FindFirstChild('RobloxKartTouchDriving')
	row.auto=controls and controls:GetAttribute('AutoForwardEnabled')
	if chassis then
		row.serverEvent=chassis.Parent:GetAttribute('KDMPerfServerEvent')
		local at=chassis.Parent:GetAttribute('KDMPerfServerAt')
		row.serverEventAge=at and workspace:GetServerTimeNow()-at
	end
	Monitor.buffer:push(row)
	if recovered and reportedZero then
		reportedZero=false
		warn('[KDMPerfClient] '..HttpService:JSONEncode({event='ZERO_RECOVERED',sample=row,history=Monitor.buffer:snapshot()}))
	end
	if (zero or dt>=.15 or (mode=='DETAIL' and workMs>=8)) and Monitor.buffer:report(now) then
		if zero then reportedZero=true end
		row.memoryMb=Stats:GetTotalMemoryUsageMb()
		if snapshotRemote then
			snapshotRemote:FireServer({t=row.t,round=row.round,speed=speed,dt=dt,moved=moved,inputSentAge=row.inputSentAge,zeroDuration=zeroDuration})
		end
		local reason=if zero then 'ZERO' elseif dt>=.15 then 'FRAME GAP' else 'HUD WORK'
		show(string.format('PERF %s R %.0fms HUD %.1fms S %sms age %ss pre/post %s/%s input %ss AUTO %s',
			reason,dt*1000,workMs,value(row.serverDt,1000),value(row.serverAge),
			value(row.server and row.server.preSpeed),value(row.server and row.server.speed),value(row.serverInputAge),tostring(row.auto)))
		warn('[KDMPerfClient] '..HttpService:JSONEncode({event=if zero then 'ZERO_SPEED' elseif dt>=.15 then 'RENDER_GAP' else 'HUD_WORK',sample=row,history=Monitor.buffer:snapshot()}))
	end
end
-- Canary controls are confined to staging/results. No polling, quantile sorting
-- or summary serialization runs inside the driving HUD callback.
if enabled and workspace:GetAttribute('KDMPerfCanaryUI')==true and RunService.Heartbeat then
 local controls,panel,summaryLabel,summaryScroll,elapsed,lastState=nil,nil,nil,nil,0,nil
 local summaryText,lastRecord='',nil
 RunService.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<1 then return end;elapsed=0
  if os.clock()-lastMemoryAt>=30 then
   lastMemoryAt=os.clock()
   local ok,v=pcall(function() return Stats:GetTotalMemoryUsageMb() end);if ok then memoryMb=v end
  end
  local state=player:GetAttribute('RaceState')
  if not controls then
   controls=Instance.new('ScreenGui');controls.Name='KDMPerfAB';controls.ResetOnSpawn=false
   controls.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;controls.DisplayOrder=25;controls.Parent=player.PlayerGui
   panel=Instance.new('Frame');panel.Name='Panel';panel.AnchorPoint=Vector2.new(.5,0)
   panel.Position=UDim2.new(.5,0,0,0);panel.Size=UDim2.fromOffset(320,36)
   panel.BackgroundColor3=Color3.fromRGB(15,20,30);panel.Parent=controls
   local function button(x,clicked)
    local b=Instance.new('TextButton');b.Position=UDim2.fromOffset(x,0);b.Size=UDim2.fromOffset(160,36)
    b.TextSize=14;b.Parent=panel;b.Activated:Connect(clicked);return b
   end
   local diagnosticButton,gaugeButton
   local function canChoose()
    local phase=player:GetAttribute('RaceState')
    return phase=='WAITING' or phase=='PRE_RACE' or phase=='FINISHED'
   end
   diagnosticButton=button(0,function()
    if not canChoose() then return end
    local nextMode=if mode=='LIGHT' then 'DETAIL' elseif mode=='DETAIL' then 'OFF' else 'LIGHT'
    workspace:SetAttribute('KDMPerfDiagnosticsMode',nextMode);diagnosticButton.Text='PERF '..nextMode
   end)
   gaugeButton=button(160,function()
    if not canChoose() then return end
    local nextMode=if Monitor.gaugeMode()=='ANALOG' then 'DIGITAL' else 'ANALOG'
    workspace:SetAttribute('KDMPerfGaugeMode',nextMode);gaugeButton.Text=nextMode
   end)
   diagnosticButton.Text='PERF '..mode;gaugeButton.Text=Monitor.gaugeMode()
   summaryScroll=Instance.new('ScrollingFrame');summaryScroll.Name='SummaryScroll'
   summaryScroll.Position=UDim2.fromOffset(0,38);summaryScroll.Size=UDim2.new(1,0,1,-38)
   summaryScroll.BackgroundTransparency=1;summaryScroll.ScrollBarThickness=6
   summaryScroll.ScrollingDirection=Enum.ScrollingDirection.Y;summaryScroll.Active=true;summaryScroll.Parent=panel
   summaryLabel=Instance.new('TextLabel');summaryLabel.Position=UDim2.fromOffset(4,0)
   summaryLabel.Size=UDim2.new(1,-12,0,700);summaryLabel.BackgroundTransparency=1
   summaryLabel.TextYAlignment=Enum.TextYAlignment.Top
   summaryLabel.TextColor3=Color3.new(1,1,1);summaryLabel.TextSize=12;summaryLabel.TextWrapped=true
   summaryLabel.Text='Canary A/B: choose a mode before each race.';summaryLabel.Parent=summaryScroll
  end
  controls.Enabled=state=='WAITING' or state=='FINISHED' or state=='DNF' or state=='PRE_RACE'
  -- Staging needs only the mode buttons; keep invite/Bot/item controls clear.
  -- The full measured summary remains available on the result screen.
  local showSummary=state=='FINISHED' or state=='DNF'
  summaryScroll.Visible=showSummary
  local panelHeight=if showSummary then math.min(230,math.max(90,controls.AbsoluteSize.Y-42)) else 36
  if panel.Size.Y.Offset~=panelHeight then panel.Size=UDim2.fromOffset(320,panelHeight) end
  if lastState=='RACING' and state~='RACING' and frames>0 then
   local result=Monitor.summary();result.round=player:GetAttribute('OfficialRoundGuid')
   local lines={'KDM PERF | '..player.Name..' | v'..tostring(game.PlaceVersion),mode..' / '..Monitor.gaugeMode()..' | >33ms '..over33..' >50ms '..over50..' gaps '..gaps..' / '..frames}
   for _,name in {'frameInterval','serverFrame','serverKartStep','serverRaceLoop','serverInputAge','snapshotAge','callbackTotal','hudEvent','eventCollect','eventResults','eventLayout','botResults','minimap','gauge','otherHud','diagnostics'} do
    local m=result.sections[name]
    if m then table.insert(lines,string.format('%s p50/p95/max %.2f/%.2f/%.2fms',name,m.p50,m.p95,m.max)) end
   end
   table.insert(lines,string.format('Race %d | app %.0fs | memory %sMB',result.raceNumber,result.appSeconds,value(result.memoryMb)))
   table.insert(lines,'Round '..tostring(result.round or 'N/A'))
   table.insert(lines,'Temp/recording/charging/power: N/A; record manually.')
   table.insert(lines,'hudEvent overlaps botResults; do not add them.')
   for i,w in result.windows do
    local m=w.sections.frameInterval
    if m then table.insert(lines,string.format('W%d %.0fs: frame %.2f/%.2f/%.2fms >33 %.2f%% >50 %.2f%% gaps %d',
     i,w.endingAt,m.p50,m.p95,m.max,w.rate33*100,w.rate50*100,w.gaps)) end
   end
   summaryLabel.Size=UDim2.new(1,-12,0,#lines*32+96)
   summaryScroll.CanvasSize=UDim2.fromOffset(0,#lines*32+96);summaryScroll.CanvasPosition=Vector2.zero
   summaryText=table.concat(lines,'\n');summaryLabel.Text=summaryText;lastRecord=nil
   warn('[KDMPerfSummary] '..HttpService:JSONEncode(result))
   clearRace()
  end
  local record=player:GetAttribute('RaceRecordDiagnostic')
  if showSummary and record~=lastRecord then
   lastRecord=record
   summaryLabel.Text=summaryText..'\nSAVE '..(if type(record)=='string' then record else 'N/A')
    ..'\nReceipt '..tostring(player:GetAttribute('RaceRecordReceiptConfirmed')==true)
  end
  lastState=state
 end)
end
return Monitor
