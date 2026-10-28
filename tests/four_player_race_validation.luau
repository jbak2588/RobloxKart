-- lune run tests/four_player_race_validation.luau
-- Deterministic RaceController integration with mocked signals, time and transport.
-- Studio physics and device rendering require separate runtime validation.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local V, CF = rb.Vector3, rb.CFrame
local count = 0
local function check(value, label)
	assert(value, label)
	count += 1
end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			local connection = { connected = true }
			function connection:Disconnect() self.connected = false end
			table.insert(listeners, { connection, callback })
			return connection
		end,
		Fire = function(_, ...)
			for _, pair in table.clone(listeners) do if pair[1].connected then pair[2](...) end end
		end,
	}
end
local methods = {}
local function object(class, name)
	local props = { ClassName=class, Name=name or class, CFrame=CF.identity, Size=V.one,
		AssemblyLinearVelocity=V.zero, AssemblyAngularVelocity=V.zero,
		PlayerAdded=signal(), PlayerRemoving=signal(), CharacterRemoving=signal(),
		Heartbeat=signal(), OnServerEvent=signal(), Destroying=signal() }
	return setmetatable({ _p=props, _children={}, _attrs={}, _signals={}, _properties={} }, {
		__index=function(self, key)
			if methods[key] then return methods[key] end
			if key == "Position" then return props.CFrame.Position end
			if props[key] ~= nil then return props[key] end
			for _, child in self._children do if child.Name==key then return child end end
		end,
		__newindex=function(self, key, value)
			local old=props[key]
			if key=="Parent" then
				if old then local index=table.find(old._children,self); if index then table.remove(old._children,index) end end
				if value then table.insert(value._children,self) end
			end
			props[key]=value
			if old~=value and self._properties[key] then self._properties[key]:Fire() end
		end,
	})
end
function methods:IsA(class)
	return self.ClassName==class or (class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="Seat" or self.ClassName=="SpawnLocation"))
end
function methods:GetChildren() return table.clone(self._children) end
function methods:FindFirstChild(name) for _, child in self._children do if child.Name==name then return child end end end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name), "Missing "..name) end
function methods:FindFirstChildOfClass(class) for _, child in self._children do if child:IsA(class) then return child end end end
function methods:SetAttribute(name,value)
	local old=self._attrs[name]; self._attrs[name]=value
	if old~=value and self._signals[name] then self._signals[name]:Fire() end
end
function methods:GetAttribute(name) return self._attrs[name] end
function methods:GetAttributeChangedSignal(name)
	if not self._signals[name] then self._signals[name]=signal() end
	return self._signals[name]
end
function methods:GetPropertyChangedSignal(name)
	if not self._properties[name] then self._properties[name]=signal() end
	return self._properties[name]
end
function methods:Destroy() self.Destroying:Fire(); self.Parent=nil end
function methods:SetNetworkOwner() end
function methods:PivotTo(cf) if self.PrimaryPart then self.PrimaryPart.CFrame=cf end end
function methods:GetPivot() return if self.PrimaryPart then self.PrimaryPart.CFrame else rb.CFrame.identity end
function methods:GetPlayers() return self._children end
function methods:GetPlayerFromCharacter(character)
	for _, player in self._children do if player.Character==character then return player end end
end
function methods:IsStudio() return self._p.studio end
local function child(parent,class,name) local result=object(class,name); result.Parent=parent; return result end
local services={ Players=object("Players"), ReplicatedStorage=object("ReplicatedStorage"),
	RunService=object("RunService"), Workspace=object("Workspace") }
services.RunService.studio=true
local shared=child(services.ReplicatedStorage,"Folder","Shared")
local server=object("Folder","Server")
local modules={}
local now=0
local identitySerial=0
services.HttpService={GenerateGUID=function()
 identitySerial+=1;return string.format("12345678-1234-1234-1234-%012d",identitySerial)
end}
local environment={
	task={defer=function(callback, ...) callback(...) end},
	Instance={new=object}, Vector2=rb.Vector2, Vector3=V, CFrame=CF, Color3=rb.Color3, Enum=rb.Enum,
	PhysicalProperties={new=function() return {} end},
	game={GetService=function(_,name) return assert(services[name]) end},
	time=function() return now end,
	DateTime={now=function()return {UnixTimestampMillis=1792471213000+math.floor(now*1000)}end},
	print=function() end,
}
local function load(path, parent, name)
	local scriptObject=child(parent,"ModuleScript",name)
	local env=table.clone(environment)
	env.script=scriptObject
	env.require=function(module) return assert(modules[module.Name],module.Name) end
	local result=if path == "src/shared/KartConfig.luau" or path == "src/shared/RaceItemConfig.luau" then require("./helpers/gameplay_config")(path) else luau.load(fs.readFile(path),{debugName=path,environment=env})()
	modules[name]=result
	return result
end

local config=load("src/shared/KartConfig.luau",shared,"KartConfig")
load("src/shared/TrackGeometry.luau",shared,"TrackGeometry")
load("src/shared/RaceRouteProgress.luau",shared,"RaceRouteProgress")
local raceConfig=load("src/shared/RaceConfig.luau",shared,"RaceConfig")
check(raceConfig.OFF_TRACK_TIMEOUT_SECONDS==15,"off-track DNF remains 15 seconds")
local catalog=load("src/shared/TrackCatalog.luau",shared,"TrackCatalog")
local mode=load("src/shared/RaceMode.luau",shared,"RaceMode")
local ranking=load("src/server/RaceRanking.luau",server,"RaceRanking")
local sessionType=load("src/server/RaceSession.luau",server,"RaceSession")
load("src/server/RacerState.luau",server,"RacerState")
local sorted=ranking.sort({
 {state="RACING",finishPosition=0,completedLaps=0,nextCheckpoint=2,routeFraction=0.2,readyOrder=2,userId=2},
 {state="RACING",finishPosition=0,completedLaps=1,nextCheckpoint=1,routeFraction=0.1,readyOrder=1,userId=1},
})
check(sorted[1].completedLaps==1,"completed lap outranks checkpoint")
sorted=ranking.sort({
 {state="RACING",finishPosition=0,completedLaps=0,nextCheckpoint=2,routeFraction=0.2,readyOrder=1,userId=1},
 {state="RACING",finishPosition=0,completedLaps=0,nextCheckpoint=2,routeFraction=0.3,readyOrder=2,userId=2},
})
check(sorted[1].routeFraction==0.3,"route fraction breaks checkpoint tie")
sorted=ranking.sort({
 {state="DNF",finishPosition=0,completedLaps=1,nextCheckpoint=3,routeFraction=0.8,readyOrder=1,userId=1},
 {state="RACING",finishPosition=0,completedLaps=0,nextCheckpoint=1,routeFraction=0.1,readyOrder=2,userId=2},
})
check(sorted[1].state=="RACING","active racer outranks DNF")

catalog.Entries.Track01Race.GridSlots={CF.new(-5,0,30),CF.new(5,0,30),CF.new(-5,0,20),CF.new(5,0,20)} -- matches this fixture's synthetic gates
local prototype=child(services.Workspace,"Folder","Prototype")
local track=child(prototype,"Model","TestTrack")
track:SetAttribute("TrackId","Track01Race")
track:SetAttribute("GeometryId","PracticeCircuitV1")
track:SetAttribute("CheckpointCount",2)
local roads=child(track,"Folder","Road")
local road=child(roads,"Part","Road1");road.Size=V.new(500,1,500)
local gates=child(track,"Folder","RaceTriggers")
local finish=child(gates,"Part","Finish");finish.Size=V.new(10,10,4)
finish:SetAttribute("RaceGate",true);finish:SetAttribute("GateType","StartFinish")
local checkpoints={}
for i=1,2 do
 local gate=child(gates,"Part","CP"..i)
 gate.Size=V.new(10,10,4);gate.CFrame=CF.new(0,0,-i*40)
 gate:SetAttribute("RaceGate",true);gate:SetAttribute("GateType","Checkpoint");gate:SetAttribute("CheckpointIndex",i)
 checkpoints[i]=gate
end
local contexts={}
local function addPlayer(name,id,slot)
 local player=child(services.Players,"Player",name);player.UserId=id
 player.Character=object("Model",name.."Character")
 local human=child(player.Character,"Humanoid","Humanoid");human.Health=100
 local kart=child(prototype,"Model","Kart_"..name)
 local chassis=child(kart,"Part","Chassis");kart.PrimaryPart=chassis
 chassis.CFrame=CF.new(slot*10,0,20)
 local seat=child(kart,"Seat","Seat")
 seat.Occupant=human;human.SeatPart=seat
 kart:SetAttribute("RaceStartCFrame",chassis.CFrame)
 local context={owner=player,kart=kart,chassis=chassis,seat=seat}
 function context:setSpawnCFrame(frame) self.spawnCFrame=frame;self.kart:SetAttribute("RaceStartCFrame",frame)end
 contexts[player]=context
 player:SetAttribute("SelectedTrackId","Track01Race")
 player:SetAttribute("ReadyOrder",slot)
 player:SetAttribute("GridSlot",slot)
 return player,context
end
local a,ca=addPlayer("A",1,1)
local b,cb=addPlayer("B",2,2)
local c,cc=addPlayer("C",3,3)
local d,cd=addPlayer("D",4,4)
local e,ce=addPlayer("E",5,5)
child(server,"ModuleScript","PrototypeWorld")
local released={}
modules.PrototypeWorld={
 reassertServerAuthority=function(p) assert(contexts[p],"live mocked player");return true end,
 getKartContext=function(p) return contexts[p] end,
 releaseKartContext=function(p) released[p]=(released[p] or 0)+1 end,
}
local race=load("src/server/RaceController.luau",server,"RaceController")
race.start({trackId="Track01Race"})
local session=sessionType.active()
local function tick(dt) now+=dt;services.RunService.Heartbeat:Fire(dt) end
local remote=services.ReplicatedStorage.RaceControl.OnServerEvent
track:SetAttribute("TrackId","Track01Race")
local function ready(player) player:SetAttribute("RaceState","PRE_RACE");tick(0.1) end
ready(a);ready(b);ready(c)
check(session.phase=="WAITING" and session:count()==3 and session.hostUserId==a.UserId
 and a:GetAttribute("RaceParticipantCount")==3 and c:GetAttribute("RaceMaxPlayers")==4,
 "one to three racers wait indefinitely with four-racer capacity")
tick(60)
check(session.phase=="WAITING" and session.countdownEndTime==0,"three-racer lobby has no timer")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
remote:Fire(b,"StartRace")
check(session.phase=="WAITING","non-host cannot start lobby")
remote:Fire(b,"CancelWait")
check(session.phase=="WAITING" and session:count()==2 and session.hostUserId==a.UserId
 and b:GetAttribute("RaceState")=="GARAGE" and (released[b] or 0)==1,
 "non-host LEAVE removes only that racer")
ready(b)
remote:Fire(a,"CancelWait")
check(session.phase=="WAITING" and session:count()==2 and session.hostUserId==b.UserId
 and b:GetAttribute("RaceHostUserId")==b.UserId and c:GetAttribute("RaceHostUserId")==b.UserId,
 "host LEAVE transfers authority to earliest remaining ReadyOrder")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
remote:Fire(b,"StartRace")
check(session.phase=="COUNTDOWN" and session.startingParticipantCount==2,
 "transferred host starts two-racer shared countdown")
b:SetAttribute("RaceState","GARAGE");c:SetAttribute("RaceState","GARAGE");tick(0.1)
check(session.phase=="EMPTY" and session:count()==0,"withdrawal clears first round")

ready(a);ready(b);ready(c)
check(session.phase=="WAITING" and session:count()==3,"third ready stays in lobby")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
remote:Fire(a,"StartRace")
check(session.phase=="COUNTDOWN" and session.startingParticipantCount==3
 and a:GetAttribute("RaceSessionId")==b:GetAttribute("RaceSessionId")
 and b:GetAttribute("RaceSessionId")==c:GetAttribute("RaceSessionId"),
 "host starts synchronized three-racer countdown")
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
check(session.phase=="RACING" and a:GetAttribute("RaceState")=="RACING"
 and b:GetAttribute("RaceState")=="RACING" and c:GetAttribute("RaceState")=="RACING"
 and not ca.kart:GetAttribute("RaceControlsLocked")
 and not cb.kart:GetAttribute("RaceControlsLocked")
 and not cc.kart:GetAttribute("RaceControlsLocked"),
 "three independent racer states and karts unlock together")
cb.chassis.CFrame=CF.new(1500,0,1500);cc.chassis.CFrame=CF.new(1600,0,1600)
ca.chassis.CFrame=CF.new(1700,0,1700);tick(raceConfig.OFF_TRACK_TIMEOUT_SECONDS+0.1)
check(session.phase=="COMPLETE" and a:GetAttribute("RaceState")=="DNF"
 and b:GetAttribute("RaceState")=="DNF" and c:GetAttribute("RaceState")=="DNF",
 "three-racer terminal state completes independently")
remote:Fire(a,"Rematch");remote:Fire(b,"Rematch");remote:Fire(c,"Rematch")
check(session.phase=="WAITING" and session:count()==3 and session.hostUserId==a.UserId
 and a:GetAttribute("RaceParticipantCount")==3 and c:GetAttribute("RaceState")=="PRE_RACE",
 "three-of-four rematch returns all voters to flexible lobby")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
remote:Fire(a,"StartRace")
check(session.phase=="COUNTDOWN" and session.startingParticipantCount==3,
 "three-of-four rematch starts on host action")
a:SetAttribute("RaceState","GARAGE");b:SetAttribute("RaceState","GARAGE")
c:SetAttribute("RaceState","GARAGE");tick(0.1)
check(session.phase=="EMPTY","three-racer cleanup leaves no session")

ready(a);ready(b);ready(c)
check(session.phase=="WAITING" and session:count()==3,"fourth racer has not joined yet")
ready(d)
check(session.phase=="COUNTDOWN" and d:GetAttribute("RaceItemsReady"),"fourth admission starts without item preparation")
tick(.1)
check(session.phase=="COUNTDOWN" and session:count()==4 and session.startingParticipantCount==4,
 "fourth READY alone triggers full-lobby countdown")
check(a:GetAttribute("RaceSessionId")==d:GetAttribute("RaceSessionId")
 and a:GetAttribute("RaceParticipantCount")==4 and d:GetAttribute("RaceParticipantCount")==4
 and ca.kart~=cb.kart and cb.kart~=cc.kart and cc.kart~=cd.kart
 and a:GetAttribute("GridSlot")==1 and b:GetAttribute("GridSlot")==2
 and c:GetAttribute("GridSlot")==3 and d:GetAttribute("GridSlot")==4
 and session.participants[a]~=session.participants[b]
 and session.participants[b]~=session.participants[c]
 and session.participants[c]~=session.participants[d],
 "four racers share session with distinct contexts and grid slots")
for _,entry in {{a,ca},{b,cb},{c,cc},{d,cd}} do
 check(entry[1]:GetAttribute("RaceMapActive")
  and entry[1]:GetAttribute("RaceMapPosition")==entry[2].chassis.Position,
  "each of four racers publishes its own map position")
end
ready(e)
check(session:count()==4 and e:GetAttribute("RaceState")=="GARAGE"
 and e:GetAttribute("RaceEntryError")=="Race in progress",
 "fifth racer is rejected after roster lock")
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
check(session.phase=="RACING" and a:GetAttribute("RacePosition")==1
 and b:GetAttribute("RacePosition")==2 and c:GetAttribute("RacePosition")==3
 and d:GetAttribute("RacePosition")==4,
 "four-racer ranking begins with deterministic ready order")
local ranked=ranking.sort({
 {userId=1,state="RACING",finishPosition=0,completedLaps=1,nextCheckpoint=3,routeFraction=0,readyOrder=1},
 {userId=2,state="RACING",finishPosition=0,completedLaps=1,nextCheckpoint=5,routeFraction=0,readyOrder=2},
 {userId=3,state="RACING",finishPosition=0,completedLaps=0,nextCheckpoint=6,routeFraction=0,readyOrder=3},
 {userId=4,state="RACING",finishPosition=0,completedLaps=0,nextCheckpoint=2,routeFraction=0,readyOrder=4},
})
check(ranked[1].userId==2 and ranked[2].userId==1
 and ranked[3].userId==3 and ranked[4].userId==4,
 "four-racer ranking orders laps before checkpoints")
local function cross(context,gate)
 context.chassis.CFrame=CF.new(100,0,100);tick(0.1)
 context.chassis.CFrame=gate.CFrame
 context.chassis.AssemblyLinearVelocity=V.new(0,0,-70)
 tick(3)
end
for _,context in {ca,cb,cc,cd} do
 for _,gate in {checkpoints[1],checkpoints[2],finish} do cross(context,gate) end
end
local function finishRacer(context,laps)
 for _=1,(laps or 1) do for _,gate in {checkpoints[1],checkpoints[2],finish} do cross(context,gate) end end
 tick(raceConfig.FINISH_SEQUENCE_SECONDS+0.1)
end
finishRacer(cb)
check(b:GetAttribute("RaceFinishPosition")==1 and b:GetAttribute("RaceState")=="FINISHED"
 and a:GetAttribute("RaceState")=="RACING" and c:GetAttribute("RaceState")=="RACING"
 and d:GetAttribute("RaceState")=="RACING" and session.phase=="RACING",
 "first finisher leaves three rivals driving")
check(b:GetAttribute("RaceWinnerAwaitingRunnerUp")==true
 and a:GetAttribute("RaceWinnerAwaitingRunnerUp")==false
 and c:GetAttribute("RaceWinnerAwaitingRunnerUp")==false,
 "only the first finisher extends celebration while waiting for runner-up")
finishRacer(ca)
check(not b:GetAttribute("RaceWinnerAwaitingRunnerUp") and session.phase=="RACING"
 and c:GetAttribute("RaceState")=="RACING" and d:GetAttribute("RaceState")=="RACING",
 "runner-up crossing stops winner extension without ending remaining racers")
finishRacer(cd);finishRacer(cc)
check(session.phase=="COMPLETE" and b:GetAttribute("RaceFinishPosition")==1
 and a:GetAttribute("RaceFinishPosition")==2 and d:GetAttribute("RaceFinishPosition")==3
 and c:GetAttribute("RaceFinishPosition")==4,
 "official final gates assign deterministic places one through four")
remote:Fire(a,"Rematch");remote:Fire(b,"Rematch");remote:Fire(c,"Rematch")
check(session.phase=="COMPLETE","three votes do not start a full four-racer rematch")
remote:Fire(d,"Rematch")
check(session.phase=="WAITING" and d:GetAttribute("RaceItemsReady"),"full Rematch has no item-preparation gate")
tick(.1)
check(session.phase=="COUNTDOWN" and session.startingParticipantCount==4,
 "four-of-four rematch automatically starts shared countdown")
for _,p in {a,b,c,d} do check(p:GetAttribute("RaceWinnerAwaitingRunnerUp")==false,"Rematch clears waiting celebration") end
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
finishRacer(cb,2)
local mixedDeadline=session.raceEndDeadline
remote:Fire(a,"QuitRace")
check(a:GetAttribute("RaceState")=="GARAGE" and session.terminal[a]=="FORFEIT"
 and session:count()==3 and b:GetAttribute("RaceParticipantCount")==4
 and c:GetAttribute("RaceParticipantCount")==4 and d:GetAttribute("RaceParticipantCount")==4,
 "forfeit preserves four-racer round denominator and other participants")
cc.chassis.CFrame=CF.new(1600,0,1600);tick(raceConfig.OFF_TRACK_TIMEOUT_SECONDS+0.1)
check(c:GetAttribute("RaceState")=="DNF" and not c:GetAttribute("RaceMapActive")
 and d:GetAttribute("RaceState")=="RACING" and session.phase=="RACING",
 "DNF removes inactive marker without ending last driver's race")
finishRacer(cd,2)
check(session.phase=="COMPLETE" and b:GetAttribute("RaceFinalTime")>0
 and d:GetAttribute("RaceFinalTime")>0 and c:GetAttribute("RaceState")=="DNF"
 and b:GetAttribute("RaceParticipantCount")==4 and now<mixedDeadline
 and session.raceEndDeadline==mixedDeadline,
 "mixed finish, forfeit and DNF complete without corrupting surviving results")
remote:Fire(b,"Rematch");remote:Fire(c,"Rematch");remote:Fire(d,"Rematch")
check(session.phase=="WAITING" and session:count()==3 and session.hostUserId==b.UserId,
 "remaining three voters return to sub-full lobby with earliest host")
remote:Fire(c,"CancelWait")
check(session.phase=="WAITING" and session:count()==2
 and b:GetAttribute("RaceParticipantCount")==2 and d:GetAttribute("RaceState")=="PRE_RACE",
 "mixed four-racer results may continue as a two-of-four rematch lobby")
ready(a)
check(session.phase=="WAITING" and session:count()==3,
 "Garage racer rejoins sub-full rematch without auto-start")
ready(c)
check(session.phase=="COUNTDOWN" and c:GetAttribute("RaceItemsReady")==true,"rejoining fourth racer starts without item prep")
tick(0.1)
check(session.phase=="COUNTDOWN" and session:count()==4
 and session.startingParticipantCount==4,
 "fourth ready racer fills rematch lobby and auto-starts")
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
for _,context in {ca,cb,cc,cd} do
 for _,gate in {checkpoints[1],checkpoints[2],finish} do cross(context,gate) end
end
finishRacer(cb)
local firstDeadline=session.raceEndDeadline
check(firstDeadline>now and b:GetAttribute("RaceFinishPosition")==1,
 "first of four finishers starts race-end grace")
finishRacer(ca)
check(session.raceEndDeadline==firstDeadline and a:GetAttribute("RaceFinishPosition")==2,
 "second finisher does not restart deadline")
finishRacer(cc)
check(session.raceEndDeadline==firstDeadline and c:GetAttribute("RaceFinishPosition")==3
 and d:GetAttribute("RaceState")=="RACING","third finisher leaves last on-road racer active")
tick(firstDeadline-now-0.1)
check(d:GetAttribute("RaceState")=="RACING","fourth racer remains active before first deadline")
tick(0.1)
check(d:GetAttribute("RaceState")=="DNF" and d:GetAttribute("RaceDNFReason")=="RACE_TIMEOUT"
 and d:GetAttribute("RaceFinishPosition")==0 and d:GetAttribute("RaceFinalTime")==0
 and b:GetAttribute("RaceParticipantCount")==4 and session.phase=="COMPLETE",
 "first finisher deadline times out only unfinished fourth racer")
-- A runner-up may never arrive; existing terminal completion must end the hold.
for _,p in {a,b,c,d} do remote:Fire(p,"Rematch") end
tick(raceConfig.COUNTDOWN_SECONDS+.1)
finishRacer(cb,2)
check(b:GetAttribute("RaceWinnerAwaitingRunnerUp")==true,"new round winner waits for a possible second finish")
for _,ctx in {ca,cc,cd} do ctx.chassis.CFrame=CF.new(1700,0,1700) end
tick(raceConfig.OFF_TRACK_TIMEOUT_SECONDS+.1)
check(session.phase=="COMPLETE" and #session.finishOrder==1
 and b:GetAttribute("RaceWinnerAwaitingRunnerUp")==false,
 "all rivals DNF clears wait without fabricating a runner-up or extending grace")
print("PASS: "..count.." flexible four-player race checks")
