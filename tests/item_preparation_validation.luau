-- lune run tests/item_preparation_validation.luau
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
local environment={
	Instance={new=object}, Vector2=rb.Vector2, Vector3=V, CFrame=CF, Color3=rb.Color3, Enum=rb.Enum,
	PhysicalProperties={new=function() return {} end},
	game={GetService=function(_,name) return assert(services[name]) end},
	time=function() return now end,
	print=function() end,
}
local function load(path, parent, name)
	local scriptObject=child(parent,"ModuleScript",name)
	local env=table.clone(environment)
	env.script=scriptObject
	env.require=function(module) return assert(modules[module.Name],module.Name) end
	local result=luau.load(fs.readFile(path),{debugName=path,environment=env})()
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
track:SetAttribute("TrackId","Track01")
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
local c,cc=addPlayer("C",3,3)
local d,cd=addPlayer("D",4,4)
local e,ce=addPlayer("E",5,5)
child(server,"ModuleScript","PrototypeWorld")
local released={}
modules.PrototypeWorld={
 getKartContext=function(p) return contexts[p] end,
 releaseKartContext=function(p) released[p]=(released[p] or 0)+1 end,
}
local race=load("src/server/RaceController.luau",server,"RaceController")
load("src/shared/RaceItemCatalog.luau",shared,"RaceItemCatalog")
load("src/shared/RaceItemSlots.luau",shared,"RaceItemSlots")
local tactical=load("src/server/TacticalLoadoutService.luau",server,"TacticalLoadoutService").new(sessionType.forPlayer)
race.start()
local session=sessionType.active()
local function tick(dt) now+=dt;services.RunService.Heartbeat:Fire(dt) end
local remote=services.ReplicatedStorage.RaceControl.OnServerEvent
track:SetAttribute("TrackId","Track01Race")
local function join(p) p:SetAttribute("RaceState","PRE_RACE");tick(.1) end
local default={"Slick","Shield","Missile"}
local chosen={"Shield","Missile","Smoke"}
local function confirm(p,ids) return tactical:set(p,ids or default,now) end
check(raceConfig.ITEM_PREP_SECONDS==10,"named ten-second deadline")
check(a:GetAttribute("RaceItemsReady")==false and a:GetAttribute("RaceItemsPrepareRemaining")==0,"initial defaults")
join(a)
check(not a:GetAttribute("RaceItemsReady") and a:GetAttribute("RaceItemsPrepareRemaining")==10,"A receives own prep window")
check(confirm(a,chosen),"validated confirmation stores choice and readies A")
check(a:GetAttribute("RaceItemsReadyCount")==1 and not a:GetAttribute("RaceItemsAutoReady"),"A confirmed 1/1")
check(not confirm(a,default) and tactical:get(a)[4]=="Smoke","confirmed loadout locks without overwrite")
join(b)
local bDeadline=session.itemPrepareDeadlines[b]
check(a:GetAttribute("RaceItemsReady") and b:GetAttribute("RaceItemsPrepareRemaining")==10
 and a:GetAttribute("RaceItemsReadyCount")==1 and a:GetAttribute("RaceItemsRequiredCount")==2,"B joins 1/2, A unchanged")
remote:Fire(a,"StartRace")
check(session.phase=="WAITING" and session.roundId==0,"host early start rejected")
b:SetAttribute("RaceItemsReady",true);remote:Fire(a,"StartRace")
check(session.phase=="WAITING","internal state rejects forged attribute readiness")
b:SetAttribute("RaceItemsReady",false)
check(not confirm(b,{"Smoke","Smoke","Shield"}) and not b:GetAttribute("RaceItemsReady"),"invalid confirmation never readies racer")
check(confirm(b),"B valid confirm")
check(a:GetAttribute("RaceItemsReadyCount")==2,"immediate 2/2 publication")
remote:Fire(a,"StartRace");remote:Fire(a,"StartRace")
check(session.phase=="COUNTDOWN" and session.roundId==1,"all-ready host starts exactly once")
check(not confirm(b,chosen),"Countdown cannot change choices")
tick(raceConfig.COUNTDOWN_SECONDS+.1)
a:SetAttribute("RaceState","DNF");b:SetAttribute("RaceState","DNF");tick(.1)
remote:Fire(a,"Rematch");remote:Fire(b,"Rematch")
check(session.phase=="WAITING" and not a:GetAttribute("RaceItemsReady")
 and a:GetAttribute("RaceItemsPrepareRemaining")==10 and tactical:get(a)[4]=="Smoke","Rematch preserves choice and resets prep")
check(confirm(a,default),"Rematch allows a different confirmed trio")
check(tactical:get(a)[4]=="Missile" and not confirm(a,chosen),"new confirmed choice freezes")
local serial=a:GetAttribute("RaceItemsAutoReadySerial")
tick(9)
check(b:GetAttribute("RaceItemsPrepareRemaining")==1 and not b:GetAttribute("RaceItemsReady"),"server remaining nine-second progress")
local expired=session.itemPrepareDeadlines[b]
-- A local draft has no server representation: never call set for B's imagined Smoke draft.
now=expired
check(not confirm(b,chosen) and tactical:get(b)[4]=="Missile","late confirmation rejected before timer heartbeat; draft ignored")
services.RunService.Heartbeat:Fire(1)
check(b:GetAttribute("RaceItemsReady") and b:GetAttribute("RaceItemsAutoReady")
 and b:GetAttribute("RaceItemsPrepareRemaining")==0,"timeout auto-readies B")
check(a:GetAttribute("RaceItemsReadyCount")==2 and session.phase=="WAITING","sub-full ready never auto-starts")
check(a:GetAttribute("RaceItemsAutoReadySerial")==serial+1 and a:GetAttribute("RaceItemsAutoReadyName")==b.Name,"host gets authored timeout notice")
check(not confirm(b,chosen),"auto-ready selection locked")
join(c)
local cDeadline=session.itemPrepareDeadlines[c]
remote:Fire(a,"StartRace")
check(session.phase=="WAITING" and a:GetAttribute("RaceItemsReadyCount")==2,"new unready C gates start")
remote:Fire(c,"CancelWait")
check(a:GetAttribute("RaceItemsRequiredCount")==2 and a:GetAttribute("RaceItemsReadyCount")==2
 and not session.itemPrepareDeadlines[c],"unready leave immediately removes required count")
join(c);local remainingDeadline=session.itemPrepareDeadlines[c]
remote:Fire(a,"CancelWait")
check(session.hostUserId==b.UserId and session.itemsReady[b] and session.itemPrepareDeadlines[c]==remainingDeadline,
 "host migration preserves remaining readiness and exact deadline")
remote:Fire(b,"StartRace");check(session.phase=="WAITING","new host still gated")
check(confirm(c),"C confirms for migrated host")
remote:Fire(b,"StartRace");check(session.phase=="COUNTDOWN" and session.roundId==2,"migrated ready host starts")
-- Reset test participants through normal departure, then verify full room admission.
for _,p in {b,c} do p:SetAttribute("RaceState","GARAGE") end;tick(.1)
join(a);check(confirm(a),"full-room A ready")
join(b);check(confirm(b),"full-room B ready")
join(c);check(confirm(c),"full-room C ready")
join(d)
check(session.phase=="WAITING" and d:GetAttribute("RaceItemsPrepareRemaining")==10
 and a:GetAttribute("RaceItemsReadyCount")==3 and a:GetAttribute("RaceItemsRequiredCount")==4,"D arrival stays WAITING at 3/4")
local round=session.roundId
tick(9);check(session.phase=="WAITING","full room waits for D")
check(confirm(d),"D confirms before deadline")
tick(.01)
check(session.phase=="COUNTDOWN" and session.roundId==round+1 and session.startingParticipantCount==4,"4/4 auto-start after final confirm")
tick(.01);remote:Fire(a,"StartRace")
check(session.roundId==round+1,"heartbeat and host cannot duplicate countdown")
-- Full-room Rematch must wait again, then final timeout triggers one countdown.
tick(raceConfig.COUNTDOWN_SECONDS+.1)
for _,p in {a,b,c,d} do p:SetAttribute("RaceState","DNF") end;tick(.1)
for _,p in {a,b,c,d} do remote:Fire(p,"Rematch") end
check(session.phase=="WAITING" and a:GetAttribute("RaceItemsReadyCount")==0,"4/4 Rematch gets fresh preparation")
for _,p in {a,b,c} do check(confirm(p),"Rematch ready "..p.Name) end
round=session.roundId;tick(10)
check(session.phase=="COUNTDOWN" and session.roundId==round+1 and d:GetAttribute("RaceItemsAutoReady"),"full-room final timeout starts once")
tick(.1);check(session.roundId==round+1,"expired timers cannot restart countdown")
print("PASS: "..count.." item preparation/controller/tactical checks (mocked; published flow required)")
