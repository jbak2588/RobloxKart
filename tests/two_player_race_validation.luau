-- lune run tests/race_mode_validation.luau
-- Deterministic server integration with signals/time/physics transport mocked.
-- Executes RaceController and RaceItemController with a movement bridge stub, NOT Studio physics.
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
 contexts[player]=context
 player:SetAttribute("SelectedTrackId","Track01Race")
 player:SetAttribute("ReadyOrder",slot)
 player:SetAttribute("GridSlot",slot)
 return player,context
end
local a,ca=addPlayer("A",1,1)
local b,cb=addPlayer("B",2,2)
local tie=sessionType.new("Track01Race","RACE",2)
tie:add(a,{});tie:add(b,{})
tie:recordFinish(b,5);tie:recordFinish(a,5)
check(a:GetAttribute("RaceFinishPosition")==1 and b:GetAttribute("RaceFinishPosition")==2,"same-time finish uses ready order")
check(tie:recordFinish(a,5)==1 and #tie.finishOrder==2,"finish recording is idempotent")
child(server,"ModuleScript","PrototypeWorld")
local released={}
modules.PrototypeWorld={
 getKartContext=function(p) return contexts[p] end,
 releaseKartContext=function(p) released[p]=(released[p] or 0)+1 end,
}
local race=load("src/server/RaceController.luau",server,"RaceController")
race.start({trackId="Track01Race"})
check(a:GetAttribute("RaceMapActive")==false and b:GetAttribute("RaceMapActive")==false
 and a:GetAttribute("RaceMapPosition")==V.zero,"map publication initializes inactive")
local session=sessionType.active()
local function tick(dt) now+=dt;services.RunService.Heartbeat:Fire(dt) end
track:SetAttribute("TrackId","Track01Race")
a:SetAttribute("RaceState","PRE_RACE")
tick(0.1)
check(session.phase=="WAITING" and a:GetAttribute("RaceMatchStatus")=="WAITING","first racer waits with two connected players")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"QuitRace")
check(session.phase=="WAITING" and a:GetAttribute("RaceState")=="PRE_RACE"
 and session.terminal[a]==nil,"QuitRace before racing is rejected")
check(a:GetAttribute("RaceMatchWaitRemaining")==0 and a:GetAttribute("RaceHostUserId")==a.UserId
 and ca.kart:GetAttribute("RaceControlsLocked"),"first ready is host and waits without timer")
for _,elapsed in {8,12,40} do
 tick(elapsed)
 check(session.phase=="WAITING" and a:GetAttribute("RaceState")=="PRE_RACE","waiting stays open through 8/20/60 seconds")
end
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"StartSolo")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"CancelWait")
check(session.phase=="WAITING","non-host lobby actions rejected")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"CancelWait")
check(session.phase=="EMPTY" and session:count()==0 and a:GetAttribute("RaceState")=="GARAGE"
 and not a:GetAttribute("RaceMapActive") and released[a]>=1,"host cancel returns to Garage and releases kart")
a:SetAttribute("RaceState","PRE_RACE");tick(0.1)
check(session.phase=="WAITING","host can ready again")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"StartSolo")
check(session.phase=="COUNTDOWN" and a:GetAttribute("RaceState")=="COUNTDOWN","host starts solo countdown")
a:SetAttribute("RaceState","GARAGE");tick(0.1)
check(session.phase=="EMPTY" and session:count()==0,"solo withdrawal clears session")

a:SetAttribute("RaceState","PRE_RACE");tick(0.1)
check(session.phase=="WAITING","new two-player wait")
b:SetAttribute("RaceState","PRE_RACE");tick(0.1)
check(session.phase=="WAITING" and session:count()==2
 and a:GetAttribute("RaceParticipantCount")==2 and a:GetAttribute("RaceMaxPlayers")==4,
 "second ready remains in flexible two-of-four lobby")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"StartRace")
check(session.phase=="WAITING","non-host cannot start two-racer lobby")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"StartRace")
check(session.phase=="COUNTDOWN" and session:count()==2,"host starts two-racer shared countdown")
check(a:GetAttribute("RaceState")=="COUNTDOWN" and b:GetAttribute("RaceState")=="COUNTDOWN","both enter countdown")
check(a:GetAttribute("RaceTotalLaps")==2 and b:GetAttribute("RaceTotalLaps")==2,"Practice Circuit Race is two laps")
check(a:GetAttribute("RaceSessionId")==b:GetAttribute("RaceSessionId"),"shared round id")
check(a:GetAttribute("RaceCountdown")==b:GetAttribute("RaceCountdown"),"shared countdown display")
check(a:GetAttribute("RaceMapActive") and b:GetAttribute("RaceMapActive")
 and a:GetAttribute("RaceMapPosition")==ca.chassis.Position
 and b:GetAttribute("RaceMapPosition")==cb.chassis.Position,"both server map positions publish at countdown")
local deadline=session.countdownEndTime
tick(1.1)
check(a:GetAttribute("RaceCountdown")==b:GetAttribute("RaceCountdown"),"countdown remains synchronized")
tick(2)
check(session.phase=="RACING" and a:GetAttribute("RaceState")=="RACING" and b:GetAttribute("RaceState")=="RACING","same heartbeat race transition")
check(session.startTime==deadline and session.participants[a].raceStartTime==deadline
 and session.participants[b].raceStartTime==deadline and session.participants[a].lapStartTime==deadline
 and session.participants[b].lapStartTime==deadline,"one official start clock")
check(not ca.kart:GetAttribute("RaceControlsLocked") and not cb.kart:GetAttribute("RaceControlsLocked"),"both karts unlock")
check(a:GetAttribute("RacePosition")==1 and b:GetAttribute("RacePosition")==2,"ready order breaks exact tie")
local function cross(context,gate)
 context.chassis.CFrame=CF.new(100,0,100);tick(0.1)
 context.chassis.CFrame=gate.CFrame
 context.chassis.AssemblyLinearVelocity=V.new(0,0,-70)
 tick(3)
end
cross(cb,checkpoints[1])
check(b:GetAttribute("RaceMapPosition")==cb.chassis.Position
 and a:GetAttribute("RaceMapPosition")==ca.chassis.Position,"bounded race loop republishes both racer positions")
check(b:GetAttribute("RaceNextCheckpoint")==2 and a:GetAttribute("RaceNextCheckpoint")==1,"checkpoint progress isolated")
check(b:GetAttribute("RacePosition")==1 and a:GetAttribute("RacePosition")==2,"live position follows checkpoint")
cross(cb,checkpoints[2]);cross(cb,finish)
check(b:GetAttribute("RaceCompletedLaps")==1 and a:GetAttribute("RaceCompletedLaps")==0,"lap progress isolated")
for _,gate in {checkpoints[1],checkpoints[2],finish} do cross(cb,gate) end
check(b:GetAttribute("RaceState")=="FINISHING" and b:GetAttribute("RaceFinishPosition")==1,"official final gate records first place")
check(a:GetAttribute("RaceState")=="RACING" and not ca.kart:GetAttribute("RaceControlsLocked"),"first finish does not stop other racer")
tick(raceConfig.FINISH_SEQUENCE_SECONDS+0.1)
check(b:GetAttribute("RaceState")=="FINISHED" and session.phase=="RACING" and not b:GetAttribute("RaceSessionComplete"),"first result waits for other racer")
ca.chassis.CFrame=CF.new(22,0,18);tick(0.1)
check(b:GetAttribute("RaceMapActive") and a:GetAttribute("RaceMapActive")
 and a:GetAttribute("RaceMapPosition")==ca.chassis.Position,
 "first finisher still receives active opponent map position")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"QuitRace")
check(b:GetAttribute("RaceState")=="FINISHED" and session:count()==2,"finished racer cannot use QuitRace")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"Rematch")
check(session.phase=="RACING" and not b:GetAttribute("RaceRematchReady"),"early rematch blocked")
ca.chassis.CFrame=CF.new(1500,0,1500);tick(14.9)
check(a:GetAttribute("RaceState")=="RACING" and a:GetAttribute("RaceOffTrackRemaining")>=1,
 "off-track racer remains active at 14.9 seconds")
ca.chassis.CFrame=CF.new(0,0,0);tick(0.1)
check(a:GetAttribute("RaceState")=="RACING" and a:GetAttribute("RaceOffTrackRemaining")==0,
 "returning to road resets off-track countdown")
ca.chassis.CFrame=CF.new(1500,0,1500);tick(raceConfig.OFF_TRACK_TIMEOUT_SECONDS+0.1)
check(a:GetAttribute("RaceState")=="DNF" and b:GetAttribute("RaceState")=="FINISHED","DNF isolated")
check(session.phase=="COMPLETE" and a:GetAttribute("RaceSessionComplete") and b:GetAttribute("RaceSessionComplete"),"all terminal completes session")
check(b:GetAttribute("RacePosition")==1 and a:GetAttribute("RacePosition")==2,"finished place stable ahead of DNF")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"Rematch")
check(b:GetAttribute("RaceRematchReady") and b:GetAttribute("RaceRematchReadyCount")==1 and session.phase=="COMPLETE","first vote waits")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"Rematch")
check(session.phase=="WAITING" and a:GetAttribute("RaceState")=="PRE_RACE"
 and b:GetAttribute("RaceState")=="PRE_RACE","two votes return to flexible lobby")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"StartRace")
check(session.phase=="COUNTDOWN","host starts two-racer rematch")
check(a:GetAttribute("RaceFinishPosition")==0 and b:GetAttribute("RaceFinishPosition")==0 and #session.finishOrder==0,"finish order reset")
check(a:GetAttribute("RaceCompletedLaps")==0 and b:GetAttribute("RaceCompletedLaps")==0,"both lap histories reset")
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
for _=1,2 do for _,gate in {checkpoints[1],checkpoints[2],finish} do cross(ca,gate) end end
check(a:GetAttribute("RaceFinishPosition")==1 and b:GetAttribute("RaceState")=="RACING","first final gate fixes place while opponent drives")
tick(raceConfig.FINISH_SEQUENCE_SECONDS+0.1)
for _=1,2 do for _,gate in {checkpoints[1],checkpoints[2],finish} do cross(cb,gate) end end
check(b:GetAttribute("RaceFinishPosition")==2 and a:GetAttribute("RaceFinishPosition")==1,"second official finisher gets second place")
tick(raceConfig.FINISH_SEQUENCE_SECONDS+0.1)
check(session.phase=="COMPLETE" and a:GetAttribute("RaceState")=="FINISHED" and b:GetAttribute("RaceState")=="FINISHED","both results complete session")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"Rematch")
local finishedTime=a:GetAttribute("RaceFinalTime")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"ReturnGarage")
check(session:count()==1 and session.phase=="WAITING" and session.waitingReason=="REMATCH",
 "rematch voter waits after opponent returns to Garage")
check(a:GetAttribute("RaceState")=="PRE_RACE" and a:GetAttribute("RaceFinalTime")==finishedTime
 and a:GetAttribute("RaceRematchReadyCount")==0 and a:GetAttribute("RaceRematchRequiredCount")==1,
 "voter returns to start-grid lobby after opponent leaves")
check(a:GetAttribute("RaceMatchWaitRemaining")==0 and a:GetAttribute("RaceHostUserId")==a.UserId,
 "rematch rejoin has no timer and waiting racer is host")
tick(60)
check(session.phase=="WAITING","rematch rejoin remains waiting")
b:SetAttribute("RaceState","PRE_RACE");tick(0.1)
check(session:count()==2 and session.phase=="WAITING" and a:GetAttribute("RaceState")=="PRE_RACE"
 and b:GetAttribute("RaceState")=="PRE_RACE", "Garage racer rejoins flexible lobby")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"StartRace")
check(session.phase=="COUNTDOWN", "host starts after Garage rejoin")
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
ca.chassis.CFrame=CF.new(1500,0,1500);cb.chassis.CFrame=CF.new(1600,0,1600)
tick(raceConfig.OFF_TRACK_TIMEOUT_SECONDS+0.1)
check(session.phase=="COMPLETE", "both racers can finish after rejoin")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"ReturnGarage")
check(session.phase=="COMPLETE" and session:count()==1 and a:GetAttribute("RaceState")=="DNF",
 "opponent Garage first leaves remaining result complete")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"Rematch")
check(session.phase=="WAITING" and session.waitingReason=="REMATCH"
 and a:GetAttribute("RaceRematchRequiredCount")==1,"Garage then Rematch also waits for rejoin")
b:SetAttribute("RaceState","PRE_RACE");tick(0.1)
check(session:count()==2 and session.phase=="WAITING" and a:GetAttribute("RaceState")=="PRE_RACE"
 and b:GetAttribute("RaceState")=="PRE_RACE","Garage-first order rejoins flexible lobby")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"StartRace")
check(session.phase=="COUNTDOWN","host starts after Garage-first rejoin")
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
check(session.phase=="RACING" and not ca.kart:GetAttribute("RaceControlsLocked")
 and not cb.kart:GetAttribute("RaceControlsLocked"),"both racers drive after Garage-first rejoin")
ca.owner=nil
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"QuitRace")
check(a:GetAttribute("RaceState")=="RACING" and session.terminal[a]==nil,
 "QuitRace without caller-owned KartContext is rejected")
ca.owner=a
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"QuitRace")
check(a:GetAttribute("RaceState")=="GARAGE" and session.terminal[a]=="FORFEIT"
 and not a:GetAttribute("RaceMapActive") and released[a]>=1
 and a:GetAttribute("RaceFinalTime")==0,"valid QuitRace forfeits without finish time and releases caller")
check(b:GetAttribute("RaceState")=="RACING" and not cb.kart:GetAttribute("RaceControlsLocked")
 and session:count()==1,"opponent continues unaffected after QuitRace")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"QuitRace")
check(session:count()==1 and session.terminal[a]=="FORFEIT","non-participant QuitRace ignored")
cb.chassis.CFrame=CF.new(1600,0,1600);tick(raceConfig.OFF_TRACK_TIMEOUT_SECONDS+0.1)
check(session.phase=="COMPLETE" and b:GetAttribute("RaceState")=="DNF","remaining racer can finish round after forfeit")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"Rematch")
check(session.phase=="WAITING" and session.waitingReason=="REMATCH", "forfeit round rematch waits")
tick(60)
check(session.phase=="WAITING", "solo rematch does not start automatically")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"StartSolo")
check(session.phase=="COUNTDOWN" and session.startingParticipantCount==1
 and b:GetAttribute("RaceRematchRequiredCount")==1, "host starts solo rematch")
services.Players.PlayerRemoving:Fire(a);a.Parent=nil
check(session:count()==1 and session.phase=="COUNTDOWN" and cb.kart.Parent~=nil,"Garage player's disconnect preserves remaining kart and clock")
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
check(b:GetAttribute("RaceState")=="RACING" and session.phase=="RACING","remaining racer starts on original countdown")
for _=1,2 do for _,gate in {checkpoints[1],checkpoints[2],finish} do cross(cb,gate) end end
check(session.raceEndDeadline==0 and session.firstFinishAt==0
 and not b:GetAttribute("RaceEndCountdownActive"),"solo official finish never starts grace timer")
tick(raceConfig.FINISH_SEQUENCE_SECONDS+0.1)
check(session.phase=="COMPLETE" and b:GetAttribute("RaceState")=="FINISHED"
 and session.startingParticipantCount==1,"solo circuit round reaches result")
local soloKart=cb.kart
local soloRound=session.roundId
local soloTime=b:GetAttribute("RaceFinalTime")
cb.chassis.AssemblyLinearVelocity=V.new(0,0,-70)
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"Rematch")
check(session.phase=="WAITING" and session.waitingReason=="REMATCH" and session:count()==1
 and session.hostUserId==b.UserId and b:GetAttribute("RaceMatchStatus")=="WAITING"
 and b:GetAttribute("RaceState")=="PRE_RACE" and b:GetAttribute("RaceHostUserId")==b.UserId,
 "solo finish rematch returns same host to waiting lobby")
check(session.roundId==soloRound and session.startTime==0 and session.countdownEndTime==0
 and b:GetAttribute("RaceCountdown")==0 and b:GetAttribute("RaceFinalTime")==soloTime,
 "waiting does not start new race accounting")
check(cb.kart==soloKart and cb.chassis.CFrame==cb.kart:GetAttribute("RaceStartCFrame")
 and cb.chassis.AssemblyLinearVelocity==V.zero and cb.chassis.AssemblyAngularVelocity==V.zero
 and cb.kart:GetAttribute("RaceControlsLocked") and not cb.kart:GetAttribute("KartFinishRollActive")
 and b:GetAttribute("RaceFinishPhase")=="NONE" and not b:GetAttribute("RaceMapActive"),
 "solo rematch reuses stationary locked grid kart and exits finish presentation")
tick(60)
check(session.phase=="WAITING" and b:GetAttribute("RaceState")=="PRE_RACE",
 "solo rematch waiting has no timeout")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"StartSolo")
check(session.phase=="COUNTDOWN" and session.startingParticipantCount==1
 and b:GetAttribute("RaceState")=="COUNTDOWN" and session.roundId==soloRound+1,
 "solo rematch host START SOLO starts a fresh countdown")
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
cb.chassis.CFrame=CF.new(1600,0,1600);tick(raceConfig.OFF_TRACK_TIMEOUT_SECONDS+0.1)
check(session.phase=="COMPLETE" and b:GetAttribute("RaceState")=="DNF", "second solo round reaches DNF")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"Rematch")
check(session.phase=="WAITING" and b:GetAttribute("RaceState")=="PRE_RACE", "solo DNF rematch also waits")
local releasedBeforeCancel=released[b] or 0
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"CancelWait")
check(session.phase=="EMPTY" and session:count()==0 and b:GetAttribute("RaceState")=="GARAGE"
 and not b:GetAttribute("RaceMapActive") and (released[b] or 0)==releasedBeforeCancel+1,
 "solo rematch CANCEL releases participant, kart and grid reservation")
b:SetAttribute("RaceState","PRE_RACE");tick(0.1)
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"StartSolo")
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
cb.chassis.CFrame=CF.new(1600,0,1600);tick(raceConfig.OFF_TRACK_TIMEOUT_SECONDS+0.1)
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"Rematch")
check(session.phase=="WAITING" and session.waitingReason=="REMATCH", "solo host ready for second racer")
a.Parent=services.Players
a:SetAttribute("RaceState","PRE_RACE");tick(0.1)
check(session.phase=="WAITING" and session:count()==2
 and a:GetAttribute("RaceState")=="PRE_RACE" and b:GetAttribute("RaceState")=="PRE_RACE"
 and ca.kart:GetAttribute("RaceStartCFrame")~=cb.kart:GetAttribute("RaceStartCFrame"),
 "second READY joins solo rematch host in flexible lobby on separate grid slots")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"StartRace")
check(session.phase=="COUNTDOWN" and session.startingParticipantCount==2
 and a:GetAttribute("RaceSessionId")==b:GetAttribute("RaceSessionId"),
 "host starts joined rematch on shared countdown")
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
ca.chassis.CFrame=CF.new(1500,0,1500);cb.chassis.CFrame=CF.new(1600,0,1600)
tick(raceConfig.OFF_TRACK_TIMEOUT_SECONDS+0.1)
check(session.phase=="COMPLETE", "joined race completes")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"Rematch")
check(session.phase=="COMPLETE" and a:GetAttribute("RaceRematchReady"), "first two-racer rematch vote waits")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"Rematch")
check(session.phase=="WAITING" and session:count()==2,
 "both two-racer rematch votes return to flexible lobby")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(if session.hostUserId==a.UserId then a else b,"StartRace")
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
check(session.raceEndDeadline==0 and not a:GetAttribute("RaceEndCountdownActive"),
 "no race-end timer before an official finish")
for _=1,2 do for _,gate in {checkpoints[1],checkpoints[2],finish} do cross(ca,gate) end end
local firstFinishDeadline=session.raceEndDeadline
check(session.firstFinishAt==now and firstFinishDeadline==now+raceConfig.POST_FIRST_FINISH_GRACE_SECONDS
 and a:GetAttribute("RaceFinishPosition")==1 and b:GetAttribute("RaceState")=="RACING",
 "first official gate starts shared 45-second deadline")
tick(raceConfig.FINISH_SEQUENCE_SECONDS+0.1)
check(a:GetAttribute("RaceState")=="FINISHED" and a:GetAttribute("RaceEndCountdownActive")
 and b:GetAttribute("RaceEndCountdownRemaining")>0 and session.phase=="RACING",
 "finished racer waits while stationary opponent may still drive")
tick(firstFinishDeadline-now-0.1)
check(b:GetAttribute("RaceState")=="RACING" and session.phase=="RACING",
 "stationary on-road racer remains active before deadline")
tick(0.1)
check(b:GetAttribute("RaceState")=="DNF" and b:GetAttribute("RaceDNFReason")=="RACE_TIMEOUT"
 and session.terminal[b]=="RACE_TIMEOUT" and b:GetAttribute("RaceFinalTime")==0
 and b:GetAttribute("RaceFinishPosition")==0 and not b:GetAttribute("RaceMapActive")
 and cb.kart:GetAttribute("RaceControlsLocked") and session.phase=="COMPLETE"
 and a:GetAttribute("RaceParticipantCount")==2 and not a:GetAttribute("RaceEndCountdownActive"),
 "45-second expiry ends stationary rival without fake finish or denominator change")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"Rematch")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"Rematch")
check(session.phase=="WAITING" and session.raceEndDeadline==0,
 "timeout result permits normal rematch and clears deadline")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(if session.hostUserId==a.UserId then a else b,"StartRace")
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
for _=1,2 do for _,gate in {checkpoints[1],checkpoints[2],finish} do cross(ca,gate) end end
local leaveDeadline=session.raceEndDeadline
tick(raceConfig.FINISH_SEQUENCE_SECONDS+0.1)
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"ReturnGarage")
check(session:count()==1 and session.raceEndDeadline==leaveDeadline
 and b:GetAttribute("RaceState")=="RACING", "first finisher leaving preserves shared deadline")
tick(leaveDeadline-now)
check(b:GetAttribute("RaceState")=="DNF" and session.phase=="COMPLETE",
 "remaining racer times out after first finisher returned to Garage")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"Rematch")
check(session.phase=="WAITING" and session:count()==1,"timeout DNF can enter flexible rematch lobby")
a:SetAttribute("RaceState","PRE_RACE");tick(0.1)
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(if session.hostUserId==a.UserId then a else b,"StartRace")
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
for _,gate in {checkpoints[1],checkpoints[2],finish} do cross(cb,gate) end
for _=1,2 do for _,gate in {checkpoints[1],checkpoints[2],finish} do cross(ca,gate) end end
local finishInTimeDeadline=session.raceEndDeadline
tick(20)
for _,gate in {checkpoints[1],checkpoints[2],finish} do cross(cb,gate) end
check(b:GetAttribute("RaceState")=="FINISHING" and b:GetAttribute("RaceFinishPosition")==2
 and b:GetAttribute("RaceDNFReason")=="" and session.phase=="COMPLETE"
 and now<finishInTimeDeadline and session.raceEndDeadline==finishInTimeDeadline,
 "second racer finishing within grace completes immediately with official place")
tick(raceConfig.FINISH_SEQUENCE_SECONDS+0.1)
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(a,"Rematch")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(b,"Rematch")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(if session.hostUserId==a.UserId then a else b,"StartRace")
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
for _=1,2 do for _,gate in {checkpoints[1],checkpoints[2],finish} do cross(ca,gate) end end
local disconnectDeadline=session.raceEndDeadline
tick(raceConfig.FINISH_SEQUENCE_SECONDS+0.1)
a.Parent=nil;services.Players.PlayerRemoving:Fire(a)
check(session:count()==1 and session.raceEndDeadline==disconnectDeadline,
 "first finisher disconnect preserves session deadline")
tick(disconnectDeadline-now)
check(b:GetAttribute("RaceState")=="DNF" and session.phase=="COMPLETE",
 "stationary racer still times out after first finisher disconnects")
print("PASS: "..count.." synchronized two-player race checks")
