local RunService=game:GetService('RunService')
local Players=game:GetService('Players')
local HttpService=game:GetService('HttpService')
local Stats=game:GetService('Stats')
local Buffer=require(game.ReplicatedStorage.Shared.KDMPerformanceBuffer)
local Monitor={buffer=Buffer.new(60)}
local player=Players.LocalPlayer
local enabled=Buffer.allowed(RunService:IsStudio(),player.UserId,game.GameId,game.PlaceId)
local previousSpeed,previousPosition,previousRound,lastSample=0,nil,nil,-math.huge
local display,shownUntil=nil,0
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
	display.Text=text;display.Visible=true;shownUntil=os.clock()+6
end
function Monitor.observe(chassis,speed,dt,workMs)
	if not enabled then return end
	if display and (os.clock()>shownUntil or player:GetAttribute('RaceState')~='RACING') then display.Visible=false end
	local round=player:GetAttribute('RaceSessionId')
	if player:GetAttribute('RaceState')~='RACING' or round~=previousRound then
		previousSpeed,previousPosition,previousRound=0,nil,round
		return
	end
	local now=os.clock()
	local position=chassis and chassis.Position
	local moved=position and previousPosition and (position-previousPosition).Magnitude or 0
	local zero=previousSpeed>20 and speed<1
	previousSpeed,previousPosition=speed,position
	if now-lastSample<.1 and not zero and dt<.15 and workMs<8 then return end
	lastSample=now
	local row={t=now,dt=dt,ms=workMs,speed=speed,moved=moved,seat=chassis~=nil,
		reset=chassis and chassis.Parent:GetAttribute('RaceResetSerial'),
		memoryMb=nil}
	local controls=player.PlayerGui:FindFirstChild('RobloxKartTouchDriving')
	row.auto=controls and controls:GetAttribute('AutoForwardEnabled')
	if chassis then
		row.serverEvent=chassis.Parent:GetAttribute('KDMPerfServerEvent')
		row.serverDt=chassis.Parent:GetAttribute('KDMPerfServerDt')
		row.serverInputAge=chassis.Parent:GetAttribute('KDMPerfInputAge')
		local at=chassis.Parent:GetAttribute('KDMPerfServerAt')
		row.serverEventAge=at and workspace:GetServerTimeNow()-at
	end
	Monitor.buffer:push(row)
	if (zero or dt>=.15 or workMs>=8) and Monitor.buffer:report(now) then
		row.memoryMb=Stats:GetTotalMemoryUsageMb()
		show(string.format('PERF %s render %.0fms server %.0fms input %.2fs AUTO %s',
			if zero then 'ZERO' else 'GAP',dt*1000,(row.serverDt or 0)*1000,row.serverInputAge or -1,tostring(row.auto)))
		warn('[KDMPerfClient] '..HttpService:JSONEncode({event=if zero then 'ZERO_SPEED' else 'RENDER_GAP',sample=row,history=Monitor.buffer:snapshot()}))
	end
end
return Monitor
