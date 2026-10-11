-- Diagnostics only: never writes control, velocity, ownership or race state.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local HttpService=game:GetService('HttpService')
local Stats=game:GetService('Stats')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local Shared=game.ReplicatedStorage.Shared
local Buffer=require(Shared.KDMPerformanceBuffer)
local Config=require(Shared.KartConfig)
local Monitor={buffer=Buffer.new(60),lastPoll=-math.huge,enabled=false,previous={},lastSample={},states={}}
local remote
local lastClientReport={}
local function recipients()
 local out={}
 for _,p in Players:GetPlayers() do
  if Buffer.allowed(RunService:IsStudio(),p.UserId,game.GameId,game.PlaceId) then table.insert(out,p) end
 end
 return out
end
function Monitor.active()
 local now=os.clock()
 if now-Monitor.lastPoll>=1 then
  Monitor.lastPoll=now;Monitor.enabled=RunService:IsStudio() or #recipients()>0
 end
 return Monitor.enabled
end
local function send(row)
 local targets=recipients();if #targets==0 then return end
 if not remote then
  remote=ReplicatedStorage:FindFirstChild('KDMPerfSnapshot')
  if not remote then remote=Instance.new('RemoteEvent');remote.Name='KDMPerfSnapshot';remote.Parent=ReplicatedStorage end
  remote.OnServerEvent:Connect(function(p,client)
   if not Buffer.allowed(RunService:IsStudio(),p.UserId,game.GameId,game.PlaceId) or type(client)~='table' then return end
   local now=os.clock();if now-(lastClientReport[p] or -math.huge)<10 then return end
   local at=client.t
   if type(at)~='number' or at~=at or math.abs(workspace:GetServerTimeNow()-at)>15 then return end
   for c,state in Monitor.states do
    if c.owner==p and client.round==state.round then
     lastClientReport[p]=now
     -- Fixed numeric schema; never trust client diagnostic data for gameplay.
     local safe={t=at,round=state.round}
     for _,key in {'speed','dt','moved','inputSentAge','zeroDuration'} do
      local v=client[key];if type(v)=='number' and v==v and math.abs(v)<1e7 then safe[key]=v end
     end
     warn('[KDMPerfPair] '..HttpService:JSONEncode({event='CLIENT_ANOMALY',client=safe,serverAt=workspace:GetServerTimeNow(),history=state.history:snapshot()}))
     return
    end
   end
  end)
  Players.PlayerRemoving:Connect(function(p)lastClientReport[p]=nil end)
 end
 for _,p in targets do remote:FireClient(p,row) end
end
function Monitor.lifecycle(contexts)
 local now=os.clock();if now-(Monitor.lastLifecycle or -math.huge)<.5 then return end
 Monitor.lastLifecycle=now
 local count,bots,owners=0,0,0
 for c in contexts do
  if c.kart.Parent then
   count+=1;if c.botControl then bots+=1 end
   for _,connection in c.ownerConnections or {} do if connection.Connected then owners+=1 end end
  end
 end
 Monitor.counts={contexts=count,botControls=bots,ownerConnections=owners,physicsLoops=1}
end
function Monitor.observe(context,dt,stepMs,before)
 local owner=context.owner;if not owner then return end
 local now=os.clock()
 local round=owner:GetAttribute('OfficialRoundGuid') or owner:GetAttribute('RaceSessionId')
 local state=Monitor.states[context]
 if not state then state={history=Buffer.new(60),lastPublish=-math.huge,rounds=0};Monitor.states[context]=state end
 if round~=state.round then
  state.round=round;state.rounds+=1;state.lastPublish=-math.huge;state.history=Buffer.new(60);Monitor.previous[context]=nil
  if Monitor.counts then
   state.lifecycle={memoryMb=Stats:GetTotalMemoryUsageMb(),objects=#workspace:GetDescendants(),counts=Monitor.counts}
  end
 end
 local velocity=context.chassis.AssemblyLinearVelocity
 local speed=Vector3.new(velocity.X,0,velocity.Z).Magnitude
 local pre=before or velocity
 local preSpeed=Vector3.new(pre.X,0,pre.Z).Magnitude
 local previous=Monitor.previous[context];Monitor.previous[context]=speed
 local phase=owner:GetAttribute('RaceState')
 local zero=phase=='RACING' and ((previous and previous>20 and speed<1) or (previous and previous>20 and preSpeed<1))
 local anomaly=zero or dt>=.15 or stepMs>=8
 if now-(Monitor.lastSample[context] or -math.huge)<.1 and not anomaly then return end
 Monitor.lastSample[context]=now
 local control=context.control
 local age=control and time()-control.lastUpdate
 local networkOwner=context.chassis:GetNetworkOwner()
 local row={t=workspace:GetServerTimeNow(),kind='PHYSICS',user=if context.botParticipant then 'BOT' else owner.UserId,
  bot=context.botParticipant~=nil,dt=dt,ms=stepMs,botSteeringMs=context.perfBotSteeringMs,
  round=round,session=owner:GetAttribute('RaceSessionId'),rematch=if type(owner:GetAttribute('RaceSessionId'))=='number'
   then math.max(0,owner:GetAttribute('RaceSessionId')-1) else math.max(0,state.rounds-1),phase=phase,
  speed=speed,preSpeed=preSpeed,preVertical=pre.Y,vertical=velocity.Y,command=context.commandedSpeed,
  inputAge=age,inputTimeout=age==nil or age>Config.INPUT_TIMEOUT,throttle=control and control.throttle,
  steering=control and control.steering,seat=context.seat.Occupant~=nil,
  ownerSeated=context.botParticipant~=nil and context.seat.Occupant~=nil or
   (context.seat.Occupant~=nil and owner.Character~=nil and context.seat.Occupant.Parent==owner.Character),
  networkOwner=networkOwner and networkOwner.UserId or 'SERVER',reset=context.kart:GetAttribute('RaceResetSerial'),
  locked=context.kart:GetAttribute('RaceControlsLocked')==true,crash=context.crashActive==true,
  crashUntil=context.crashEndTime,crashCooldownUntil=context.crashCooldownEndTime,
  slick=context.slick.active==true,missile=context.missileHitActive==true,thunder=context.thunderHitActive==true,
  nitro=context.kart:GetAttribute('KartNitroActive'),boost=context.boostActive==true,
  offTrack=context.kart:GetAttribute('KartOffTrack'),
  x=context.chassis.Position.X,y=context.chassis.Position.Y,z=context.chassis.Position.Z,
  counts=Monitor.counts,lifecycle=state.lifecycle}
 Monitor.buffer:push(row);state.history:push(row)
 if now-state.lastPublish>=.5 then state.lastPublish=now;send(row) end
 if anomaly and state.history:report(now) then
  local event=if zero then 'ZERO_SPEED' else 'FRAME_GAP'
  context.kart:SetAttribute('KDMPerfServerEvent',event)
  context.kart:SetAttribute('KDMPerfServerDt',dt)
  context.kart:SetAttribute('KDMPerfInputAge',age)
  context.kart:SetAttribute('KDMPerfStepMs',stepMs)
  context.kart:SetAttribute('KDMPerfServerAt',row.t)
  send(row)
  warn('[KDMPerfServer] '..HttpService:JSONEncode({event=event,sample=row,history=state.history:snapshot()}))
 end
end
function Monitor.route(dt,ms,count)
 local now=os.clock()
 if ms>=8 or now-(Monitor.lastRoute or -math.huge)>=.1 then
  Monitor.lastRoute=now;Monitor.buffer:push({t=workspace:GetServerTimeNow(),kind='RACE_LOOP',dt=dt,ms=ms,racers=count})
 end
end
function Monitor.remove(context)
 Monitor.previous[context]=nil;Monitor.lastSample[context]=nil;Monitor.states[context]=nil
end
return Monitor
