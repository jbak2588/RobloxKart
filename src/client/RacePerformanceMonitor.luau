local RunService=game:GetService('RunService')
local Players=game:GetService('Players')
local HttpService=game:GetService('HttpService')
local Stats=game:GetService('Stats')
local Buffer=require(game.ReplicatedStorage.Shared.KDMPerformanceBuffer)
local Monitor={buffer=Buffer.new(60)}
local player=Players.LocalPlayer
local enabled=Buffer.allowed(RunService:IsStudio(),player.UserId,game.GameId,game.PlaceId)
local latest,lastSent,lastInput,zeroSince,zeroDuration=nil,nil,nil,nil,0
local reportedZero=false
local pendingPair
Monitor.pairs=Buffer.new(6)
local snapshotConnection,discoveryConnection,snapshotRemote
function Monitor.inputSent(throttle,steering,drift)
 if not enabled then return end
 lastSent=workspace:GetServerTimeNow();lastInput={throttle=throttle,steering=steering,drift=drift}
end
function Monitor.receive(row)
 if enabled and type(row)=='table' and row.user==player.UserId then
  if row.kind=='PAIR' then
   Monitor.pairs:push(row);pendingPair=row
   warn('[KDMPerfPairClient] '..HttpService:JSONEncode(row))
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
	if display and (os.clock()>shownUntil or player:GetAttribute('RaceState')~='RACING' or displayRound~=round) then
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
	if not enabled then return end
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
	if player:GetAttribute('RaceState')~='RACING' or round~=previousRound then
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
	if now-lastSample<.1 and not zero and not recovered and dt<.15 and workMs<8 then return end
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
	if (zero or dt>=.15 or workMs>=8) and Monitor.buffer:report(now) then
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
return Monitor
