local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local HttpService=game:GetService('HttpService')
local Stats=game:GetService('Stats')
local Buffer=require(game.ReplicatedStorage.Shared.KDMPerformanceBuffer)
local Monitor={buffer=Buffer.new(60),lastPoll=-math.huge,enabled=false,previous={},lastSample={}}
function Monitor.active()
	local now=os.clock()
	if now-Monitor.lastPoll>=1 then
		Monitor.lastPoll=now
		Monitor.enabled=RunService:IsStudio()
		if not Monitor.enabled then
			for _,p in Players:GetPlayers() do
				if Buffer.allowed(false,p.UserId,game.GameId,game.PlaceId) then Monitor.enabled=true;break end
			end
		end
	end
	return Monitor.enabled
end
function Monitor.observe(context,dt,stepMs)
	local owner=context.owner
	local phase=owner and owner:GetAttribute('RaceState')
	if phase~='RACING' then Monitor.previous[context]=nil;return end
	local now=os.clock()
	local speed=context.chassis.AssemblyLinearVelocity.Magnitude
	local previous=Monitor.previous[context]
	Monitor.previous[context]=speed
	local zero=previous and previous>20 and speed<1
	if now-(Monitor.lastSample[context] or -math.huge)<.1 and not zero and dt<.15 and stepMs<8 then return end
	Monitor.lastSample[context]=now
	local control=context.control
	local row={t=now,kind='PHYSICS',user=if context.botParticipant then 'BOT' else owner.UserId,bot=context.botParticipant~=nil,dt=dt,ms=stepMs,
		botSteeringMs=context.perfBotSteeringMs,round=owner:GetAttribute('RaceSessionId'),
		speed=speed,command=context.commandedSpeed,inputAge=control and time()-control.lastUpdate or -1,
		throttle=control and control.throttle or 0,steering=control and control.steering or 0,
		seat=context.seat.Occupant~=nil,reset=context.kart:GetAttribute('RaceResetSerial'),
		locked=context.kart:GetAttribute('RaceControlsLocked')==true,
		crash=context.crashActive==true,slick=context.slick.active==true,
		missile=context.missileHitActive==true,thunder=context.thunderHitActive==true,
		x=context.chassis.Position.X,y=context.chassis.Position.Y,z=context.chassis.Position.Z}
	Monitor.buffer:push(row)
	if (zero or dt>=.15 or stepMs>=8) and Monitor.buffer:report(now) then
		row.networkOwner=tostring(context.chassis:GetNetworkOwner())
		row.memoryMb=Stats:GetTotalMemoryUsageMb()
		context.kart:SetAttribute('KDMPerfServerEvent',if zero then 'ZERO_SPEED' else 'FRAME_GAP')
		context.kart:SetAttribute('KDMPerfServerDt',dt)
		context.kart:SetAttribute('KDMPerfInputAge',row.inputAge)
		context.kart:SetAttribute('KDMPerfStepMs',stepMs)
		context.kart:SetAttribute('KDMPerfServerAt',workspace:GetServerTimeNow())
		warn('[KDMPerfServer] '..HttpService:JSONEncode({event=if zero then 'ZERO_SPEED' else 'FRAME_GAP',sample=row,history=Monitor.buffer:snapshot()}))
	end
end
function Monitor.route(dt,ms,count)
	local now=os.clock()
	if ms>=8 or now-(Monitor.lastRoute or -math.huge)>=.1 then
		Monitor.lastRoute=now
		Monitor.buffer:push({t=os.clock(),kind='RACE_LOOP',dt=dt,ms=ms,racers=count})
	end
end
function Monitor.remove(context)
	Monitor.previous[context]=nil;Monitor.lastSample[context]=nil
end
return Monitor
