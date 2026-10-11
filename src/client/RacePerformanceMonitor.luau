local RunService=game:GetService('RunService')
local Players=game:GetService('Players')
local HttpService=game:GetService('HttpService')
local Stats=game:GetService('Stats')
local Buffer=require(game.ReplicatedStorage.Shared.KDMPerformanceBuffer)
local Monitor={buffer=Buffer.new(60)}
local player=Players.LocalPlayer
local enabled=Buffer.allowed(RunService:IsStudio(),player.UserId,game.GameId,game.PlaceId)
-- LIGHT is the shipping default. Canary-only attributes support controlled A/B.
local mode='LIGHT'
local resetRequested=false
local pendingPair
local metrics={}
local frames,gaps,hudSlow=0,0,0
local over33,over50=0,0
function Monitor.configure(nextMode)
 if not enabled then return end
 assert(nextMode=='OFF' or nextMode=='LIGHT' or nextMode=='DETAIL','Unknown diagnostic mode')
 mode=nextMode; pendingPair=nil;resetRequested=true;metrics={};frames,gaps,hudSlow=0,0,0
 over33,over50=0,0
end
function Monitor.active() return enabled end
function Monitor.gaugeMode()
 return if enabled and workspace:GetAttribute('KDMPerfGaugeMode')=='DIGITAL' then 'DIGITAL' else 'ANALOG'
end
function Monitor.metric(name,ms)
 if not Monitor.active() then return end
 local m=metrics[name]
 if not m then m={histogram={},count=0,total=0,max=0};metrics[name]=m end
 -- Fixed range: .05ms bins through 20ms, 1ms through 250ms,
 -- 25ms through 2s, then one overflow bin. Whole-race, bounded storage.
 local bin=if ms<=20 then math.ceil(math.max(0,ms)*20) elseif ms<=250 then 400+math.ceil(ms-20)
  elseif ms<=2000 then 630+math.ceil((ms-250)/25) else 701
 m.histogram[bin]=(m.histogram[bin] or 0)+1
 m.count+=1;m.total+=ms;m.max=math.max(m.max,ms)
end
function Monitor.frame(dt,workMs)
 if not enabled or player:GetAttribute('RaceState')~='RACING' then return end
 frames+=1;if dt>=.15 then gaps+=1 end;if workMs>=8 then hudSlow+=1 end
 if dt>1/30 then over33+=1 end;if dt>.05 then over50+=1 end
 Monitor.metric('frameInterval',dt*1000);Monitor.metric('hudCallback',workMs)
end
-- Quantiles are calculated only on explicit requests, never inside RenderStepped.
function Monitor.summary()
 local result={mode=mode,gauge=Monitor.gaugeMode(),frames=frames,frameGaps=gaps,frameOver33ms=over33,frameOver50ms=over50,hudSlow=hudSlow,sections={}}
 for name,m in metrics do
  local total,p50,p95=0,nil,nil
  for bin=0,701 do
   total+=m.histogram[bin] or 0
   local upper=if bin<=400 then bin/20 elseif bin<=630 then 20+bin-400 elseif bin<=700 then 250+(bin-630)*25 else m.max
   upper=math.min(upper,m.max)
   if not p50 and total>=math.ceil(m.count*.5) then p50=upper end
   if total>=math.ceil(m.count*.95) then p95=upper;break end
  end
  result.sections[name]={count=m.count,p50=p50,p95=p95,max=m.max,mean=m.total/m.count,quantiles='whole-race histogram upper bounds'}
 end
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
local latest,lastSent,lastInput,zeroSince,zeroDuration=nil,nil,nil,nil,0
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
  else latest=row end
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
if enabled and RunService.Heartbeat then
 local controls,summaryLabel,elapsed,lastState=nil,nil,0,nil
 RunService.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<1 then return end;elapsed=0
  local state=player:GetAttribute('RaceState')
  if not controls then
   controls=Instance.new('ScreenGui');controls.Name='KDMPerfAB';controls.ResetOnSpawn=false
   controls.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;controls.DisplayOrder=25;controls.Parent=player.PlayerGui
   local panel=Instance.new('Frame');panel.Name='Panel';panel.AnchorPoint=Vector2.new(.5,0)
   panel.Position=UDim2.new(.5,0,0,40);panel.Size=UDim2.fromOffset(320,172)
   panel.BackgroundColor3=Color3.fromRGB(15,20,30);panel.Parent=controls
   local function button(x,clicked)
    local b=Instance.new('TextButton');b.Position=UDim2.fromOffset(x,0);b.Size=UDim2.fromOffset(160,36)
    b.TextSize=14;b.Parent=panel;b.Activated:Connect(clicked);return b
   end
   local diagnosticButton,gaugeButton
   diagnosticButton=button(0,function()
    local nextMode=if mode=='LIGHT' then 'DETAIL' elseif mode=='DETAIL' then 'OFF' else 'LIGHT'
    workspace:SetAttribute('KDMPerfDiagnosticsMode',nextMode);diagnosticButton.Text='PERF '..nextMode
   end)
   gaugeButton=button(160,function()
    local nextMode=if Monitor.gaugeMode()=='ANALOG' then 'DIGITAL' else 'ANALOG'
    workspace:SetAttribute('KDMPerfGaugeMode',nextMode);gaugeButton.Text=nextMode
   end)
   diagnosticButton.Text='PERF '..mode;gaugeButton.Text=Monitor.gaugeMode()
   summaryLabel=Instance.new('TextLabel');summaryLabel.Position=UDim2.fromOffset(0,38)
   summaryLabel.Size=UDim2.fromOffset(320,132);summaryLabel.BackgroundTransparency=1
   summaryLabel.TextColor3=Color3.new(1,1,1);summaryLabel.TextSize=12;summaryLabel.TextWrapped=true
   summaryLabel.Text='Canary A/B: choose a mode before each race.';summaryLabel.Parent=panel
  end
  controls.Enabled=state=='WAITING' or state=='FINISHED' or state=='PRE_RACE'
  if lastState=='RACING' and state~='RACING' and frames>0 then
   local result=Monitor.summary();result.round=player:GetAttribute('OfficialRoundGuid')
   local lines={mode..' / '..Monitor.gaugeMode()..' | >33ms '..over33..' >50ms '..over50..' gaps '..gaps..' / '..frames}
   for _,name in {'botResults','hudEvent','minimap','gauge','otherHud','diagnostics','callbackTotal','frameInterval'} do
    local m=result.sections[name]
    if m then table.insert(lines,string.format('%s p50/p95/max %.2f/%.2f/%.2fms',name,m.p50,m.p95,m.max)) end
   end
   summaryLabel.Text=table.concat(lines,'\n')
   warn('[KDMPerfSummary] '..HttpService:JSONEncode(result))
   metrics={};frames,gaps,hudSlow=0,0,0
   over33,over50=0,0
  end
  lastState=state
 end)
end
return Monitor
