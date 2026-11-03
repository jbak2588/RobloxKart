-- Hub-local eight-slot roster. Deadlines, bot fill, finish order and receipts are server-owned.
local RS=game:GetService('ReplicatedStorage')
local P=require(RS.Shared.ParkMultiplayerPolicy)
local Http=game:GetService('HttpService')
local Session={}
function Session.new(zone,practice)
 local rooms,members={},{}
 local waiting
 local api={}
 local function now()return workspace:GetServerTimeNow()end
 local function publish(room)
  local humans=0;for _,m in room.members do if not m.left then humans+=1 end end
  room.humans=humans
  room.folder:SetAttribute('Phase',room.phase);room.folder:SetAttribute('GoAt',room.goAt)
  for p,m in room.members do if not m.left then
   p:SetAttribute('ParkRaceId',room.id);p:SetAttribute('ParkRacePhase',room.phase)
   p:SetAttribute('ParkRaceHumans',humans);p:SetAttribute('ParkRaceBots',#room.bots)
   p:SetAttribute('ParkRaceJoinUntil',room.closesAt)
   if m.record then m.record.trial.goAt=room.goAt or room.closesAt end
  end end
 end
 local function destroy(room)
  for _,b in room.bots do practice:removeParkRaceBot(b)end
  room.folder:Destroy();rooms[room]=nil;if waiting==room then waiting=nil end
 end
 function api:reserve(player)
  if members[player]then return nil end
  local t=now();local room=waiting
  if not room or room.phase~='WAITING'or t>=room.closesAt then
   local count=0;for _ in rooms do count+=1 end;if count>=6 then return nil end
   local folder=Instance.new('Folder');folder.Name='ParkRace_'..Http:GenerateGUID(false);folder.Parent=practice.folder
   room={id=folder.Name,folder=folder,phase='WAITING',closesAt=t+P.JoinSeconds,members={},bots={},speeds=P.speeds(Random.new())}
   rooms[room]=true;waiting=room
  end
  local used={};for _,m in room.members do if not m.left then used[m.slot]=true end end
  local slot;for i=0,7 do if not used[i]then slot=i;break end end
  if slot==nil then return nil end
  local m={room=room,slot=slot,player=player};members[player]=m;room.members[player]=m
  if slot==7 then waiting=nil end
  publish(room);return slot
 end
 function api:attach(player,r)
  local m=members[player]
  if not m or (m.room.phase~='WAITING'and m.room.phase~='SEATING')or now()>m.room.closesAt+1.5 then return false end
  m.record=r;r.parkRaceRoom=m.room;r.kart:SetAttribute('ParkRaceId',m.room.id)
  publish(m.room);return true
 end
 function api:remove(player)
  local m=members[player];if not m then return end
  m.left=true;members[player]=nil
  if m.record then m.record.parkRaceRoom=nil end
  local alive=false;for _,v in m.room.members do if not v.left then alive=true;break end end
  local pending=false;for _,v in m.room.members do if v.finishedAt and not v.rank then pending=true end end
  if not alive and not pending then destroy(m.room)else
   if not waiting and m.room.phase=='WAITING'and now()<m.room.closesAt then waiting=m.room end
   publish(m.room)
  end
  for _,k in {'Id','Phase','Humans','Bots','JoinUntil','Position','FinishPosition','Results'}do player:SetAttribute('ParkRace'..k,nil)end
 end
 function api:room(player)return members[player]and members[player].room end
 function api:finished(player,r,onFinalized)
  local m=members[player];if not m or m.record~=r or m.finishedAt then return end
  m.finishedAt=r.trial.startedAt+r.trial.milliseconds/1000
  m.readyAt=now()+.25;m.onFinalized=onFinalized
 end
 function api:update()
  local t=now()
  for room in rooms do
   if room.phase=='WAITING'and t>=room.closesAt then
    if waiting==room then waiting=nil end
    room.phase='SEATING';publish(room)
   end
   if room.phase=='SEATING'then
    local pending=false;for _,m in room.members do if not m.left and not m.record then pending=true end end
    if pending and t<room.closesAt+1.5 then continue end
    local used={}
    for p,m in room.members do
     if not m.left and m.record then used[m.slot]=true
     elseif not m.left then
      m.left=true;members[p]=nil
      for _,k in {'Id','Phase','Humans','Bots','JoinUntil'}do p:SetAttribute('ParkRace'..k,nil)end
     end
    end
    local humans=0;for _ in used do humans+=1 end
    if humans==0 then destroy(room);continue end
    room.startHumans=humans
    room.slots={};for i=0,7 do if not used[i]then table.insert(room.slots,i)end end
    room.phase='FILLING';room.nextFill=t;publish(room)
   end
   if room.phase=='FILLING'and t>=room.nextFill then
    local slot=table.remove(room.slots,1)
    if slot~=nil then
     table.insert(room.bots,practice:addParkRaceBot(room,slot,#room.bots+1,room.speeds[#room.bots+1]))
     room.nextFill=t+P.FillSeconds;publish(room)
    else
     room.phase='COUNTDOWN';room.goAt=t+P.Countdown;publish(room)
    end
   end
   if room.phase=='COUNTDOWN'and t>=room.goAt then room.phase='RUNNING';publish(room)end
   if room.phase=='RUNNING'then
    local live=false
    for _,b in room.bots do if not b.finishedAt and t-room.goAt<=P.Timeout then live=true end end
    -- Finalize completed runs even if a player leaves during the short tie window.
    for p,m in room.members do
     if m.finishedAt and not m.rank and t>=m.readyAt then
      local rank,humanRank=1,1
      for _,b in room.bots do if b.finishedAt and b.finishedAt<=m.finishedAt then rank+=1 end end
      for _,other in room.members do
       if other~=m and other.finishedAt and (other.finishedAt<m.finishedAt or(other.finishedAt==m.finishedAt and other.slot<m.slot))then rank+=1;humanRank+=1 end
      end
      local s=m.record.trial
      m.rank=rank;s.raceRank=rank;s.humanRank=humanRank;s.humanCount=room.startHumans
      if not m.left then p:SetAttribute('ParkRaceFinishPosition',rank)end
      if m.onFinalized then m.onFinalized();m.onFinalized=nil end
     end
    end
    local alive=false;local pending=false
    for _,m in room.members do if not m.left then alive=true end;if m.finishedAt and not m.rank then pending=true end end
    if not alive and not pending then destroy(room);continue end
    for p,m in room.members do if not m.left and m.record then
     local r=m.record;local s=r.trial
     if not m.finishedAt and t-room.goAt>P.Timeout then s.phase='INVALID';s.invalid=true end
     if not m.finishedAt and s.phase~='INVALID'then live=true end
     local pos=1;local center=zone:GetAttribute('Center');local here=r.body.Position-center
     local progress=if m.finishedAt then P.finishProgress()else P.humanProgress(s,here.X,here.Z)
     for _,b in room.bots do if b.distance>progress then pos+=1 end end
     for _,other in room.members do if other~=m and not other.left and other.record then
      local op=other.record.body.Position-center
      if other.finishedAt or P.humanProgress(other.record.trial,op.X,op.Z)>progress then pos+=1 end
     end end
     if p:GetAttribute('ParkRacePosition')~=(m.rank or pos)then p:SetAttribute('ParkRacePosition',m.rank or pos)end
    end end
    if not live then
     local pending=false;for _,m in room.members do if not m.left and m.finishedAt and not m.rank then pending=true end end
     if not pending then room.phase='RESULTS';publish(room)end
    end
   end
  end
 end
 return api
end
return Session
