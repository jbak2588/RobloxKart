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

local function lookAt(position,target)
 local forward=(target-position).Unit
 local right=forward:Cross(V.yAxis).Unit
 return CF.fromMatrix(position,right,right:Cross(forward),-forward)
end
local geometry=modules.TrackGeometry
local definition=geometry.getDefinition("HardCircuitV1")
local course=geometry.getCourse(definition)
check(catalog.Entries.Track03.MatchType=="PUBLIC_RACE" and catalog.Entries.Track03.MaxPlayers==4
 and catalog.Entries.Track03.TargetLaps==2,"Track03 public contract")
local prototype=child(services.Workspace,"Folder","Prototype")
local track=child(prototype,"Model","TestTrack")
track:SetAttribute("TrackId","Track03");track:SetAttribute("GeometryId","HardCircuitV1")
track:SetAttribute("CheckpointCount",#course.CheckpointSamples)
local roads=child(track,"Folder","Road")
for index,point in course.Samples do
 local nextPoint=course.Samples[index % #course.Samples+1]
 local part=child(roads,"Part","Road"..index)
 part.Size=V.new(definition.RoadWidth,1,(nextPoint-point).Magnitude+2)
 part.CFrame=lookAt((point+nextPoint)*.5,nextPoint)
end
local gates=child(track,"Folder","RaceTriggers")
local function gate(name,point,tangent,kind,index)
 local p=child(gates,"Part",name);p.Size=V.new(definition.RoadWidth+20,20,20);p.CFrame=lookAt(point,point+tangent)
 p:SetAttribute("RaceGate",true);p:SetAttribute("GateType",kind)
 if index then p:SetAttribute("CheckpointIndex",index) end
 return p
end
gate("Finish",course.StartPosition,course.StartTangent,"StartFinish")
for index,cp in course.CheckpointSamples do gate("CP"..index,cp.Position,cp.Tangent,"Checkpoint",index) end
local contexts,players={},{}
for index=1,catalog.Entries.Track03.MaxPlayers do
 local player=child(services.Players,"Player","P"..index);player.UserId=index;player.DisplayName=player.Name
 player.Character=object("Model");local human=child(player.Character,"Humanoid","Humanoid");human.Health=100
 local kart=child(prototype,"Model","KartP"..index);local chassis=child(kart,"Part","Chassis");kart.PrimaryPart=chassis
 chassis.Size=V.new(6,2,10);chassis.CFrame=catalog.Entries.Track03.GridSlots[index]
 local seat=child(kart,"Seat","Seat");seat.Occupant=human;human.SeatPart=seat
 kart:SetAttribute("RaceStartCFrame",chassis.CFrame)
 contexts[player]={owner=player,kart=kart,chassis=chassis,seat=seat}
 player:SetAttribute("SelectedTrackId","Track03");player:SetAttribute("ReadyOrder",index);player:SetAttribute("GridSlot",index)
 table.insert(players,player)
end
child(server,"ModuleScript","PrototypeWorld")
modules.PrototypeWorld={getKartContext=function(p) return contexts[p] end,releaseKartContext=function() end}
local race=load("src/server/RaceController.luau",server,"RaceController")
check(race.start({trackId="Track03"})~=false,"controller binds actual Hard course")
local session=sessionType.active()
local remote=services.ReplicatedStorage.RaceControl.OnServerEvent
local function tick(dt) now+=dt;services.RunService.Heartbeat:Fire(dt) end
for _,p in players do p:SetAttribute("RaceState","PRE_RACE");tick(.1) end
check(session:count()==4 and session.phase=="WAITING","four players share Hard waiting session")
tick(raceConfig.ITEM_PREP_SECONDS)
check(session.phase=="COUNTDOWN" and session.startingParticipantCount==4,"full ready room begins one countdown")
tick(raceConfig.COUNTDOWN_SECONDS+.1)
for index,p in players do check(p:GetAttribute("RaceState")=="RACING" and p:GetAttribute("RacePosition")==index,"GO and POS "..index) end
local function driveRound(dnfFourth)
 local completed={}
 for step=0,1000 do
  for index,p in players do
   if p:GetAttribute("RaceState")=="RACING" then
    if dnfFourth and index==4 then contexts[p].chassis.CFrame=CF.new(20000,0,20000)
    else
     local fraction=(step/(#course.Samples) * (1-(index-1)*.015))
     local point=geometry.getSampleAtFraction(course.Samples,fraction)
     local tangent=geometry.getTangentAtFraction(course.Samples,fraction)
     local right=V.new(-tangent.Z,0,tangent.X)
     point+=right*(if index%2==0 then 8 else -8)
     contexts[p].chassis.CFrame=lookAt(point,point+tangent)
     contexts[p].chassis.AssemblyLinearVelocity=tangent*70
    end
   end
  end
  tick(.22)
  for _,p in players do
   if p:GetAttribute("RaceCurrentLap")==2 then completed[p]=true end
  end
  if session.phase=="COMPLETE" then
   for index,p in players do
    if not (dnfFourth and index==4) then check(completed[p]==true,"Lap1 and Lap2 tracked independently "..index) end
   end
   return
  end
 end
 error("Hard 4P race did not complete")
end
driveRound(false)
tick(raceConfig.FINISH_SEQUENCE_SECONDS+.1)
for index,p in players do
 check(p:GetAttribute("RaceState")=="FINISHED" and p:GetAttribute("RaceFinishPosition")==index
  and p:GetAttribute("RaceFinalTime")>0,"Hard ordered official finish P"..index)
 remote:Fire(p,"Rematch")
end
check(session.phase=="WAITING","four-voter rematch returns to item prep")
tick(raceConfig.ITEM_PREP_SECONDS)
check(session.phase=="COUNTDOWN","rematch full ready room countdown")
tick(raceConfig.COUNTDOWN_SECONDS+.1)
driveRound(true)
tick(raceConfig.FINISH_SEQUENCE_SECONDS+.1)
check(players[4]:GetAttribute("RaceState")=="DNF" and players[4]:GetAttribute("RaceDNFReason")=="OFF_TRACK","fourth player's DNF isolated from finishing rivals")
for index=1,3 do check(players[index]:GetAttribute("RaceState")=="FINISHED","mixed results preserve survivor P"..index) end
print("PASS: "..count.." actual Hard course four-player controller checks (mock transport/physics)")
