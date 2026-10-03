-- lune run tests/reserved_match_validation.luau
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
track:SetAttribute("TrackId", "Track01Race")
race.start({ trackId = "Track01Race", preformedMatch = true, expectedParticipantCount = 3 })
local session = sessionType.active()
local function tick(dt) now += dt; services.RunService.Heartbeat:Fire(dt) end
local remote = services.ReplicatedStorage.RaceControl.OnServerEvent
local function ready(player) player:SetAttribute("RaceState", "PRE_RACE"); tick(0.1) end
ready(a); ready(b)
check(session.phase == "ARRIVAL" and session:count() == 2 and not race.isRosterLocked(),
 "two of three arrivals wait without a second host decision")
ready(c)
check(session.phase == "COUNTDOWN" and session.startingParticipantCount == 3 and race.isRosterLocked(),
 "third arrival starts shared countdown immediately")
check(a:GetAttribute("RaceSessionId") == b:GetAttribute("RaceSessionId")
 and b:GetAttribute("RaceSessionId") == c:GetAttribute("RaceSessionId"), "shared countdown session ID")
tick(raceConfig.COUNTDOWN_SECONDS + 0.1)
check(session.phase == "RACING" and a:GetAttribute("RaceState") == "RACING"
 and b:GetAttribute("RaceState") == "RACING" and c:GetAttribute("RaceState") == "RACING",
 "three racers start together")
ca.chassis.CFrame = CF.new(1500, 0, 1500)
cb.chassis.CFrame = CF.new(1600, 0, 1600)
cc.chassis.CFrame = CF.new(1700, 0, 1700)
tick(raceConfig.OFF_TRACK_TIMEOUT_SECONDS + 0.1)
check(session.phase == "COMPLETE" and session:count() == 3, "all terminal results complete round")
remote:Fire(a, "Rematch"); remote:Fire(b, "Rematch"); remote:Fire(c, "Rematch")
check(session.phase == "COUNTDOWN" and session.startingParticipantCount == 3,
 "all three rematch votes skip HUB waiting lobby")
tick(raceConfig.COUNTDOWN_SECONDS + 0.1)
c:SetAttribute("RaceState", "GARAGE"); tick(0.1)
check(session:count() == 2, "Garage departure leaves two racers")
ca.chassis.CFrame = CF.new(1500, 0, 1500)
cb.chassis.CFrame = CF.new(1600, 0, 1600)
tick(raceConfig.OFF_TRACK_TIMEOUT_SECONDS + 0.1)
check(session.phase == "COMPLETE", "remaining two complete round")
remote:Fire(a, "Rematch"); remote:Fire(b, "Rematch")
check(session.phase == "COUNTDOWN" and session.startingParticipantCount == 2
 and a:GetAttribute("RaceParticipantCount") == 2,
 "remaining two rematch with actual two-player denominator")
print(string.format("PASS: %d preformed reserved race checks", count))
