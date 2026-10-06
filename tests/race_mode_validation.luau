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
local catalog=load("src/shared/TrackCatalog.luau",shared,"TrackCatalog")
local mode=load("src/shared/RaceMode.luau",shared,"RaceMode")
check(#catalog.Order==4 and catalog.Order[1]=="Track01" and catalog.DefaultId=="Track01","Practice first/default")
check(catalog.Order[2]=="Track01Race" and catalog.Order[3]=="Track02" and catalog.Order[4]=="Track03","two races follow Practice")
check(catalog.Entries.Track01.GeometryId==catalog.Entries.Track01Race.GeometryId,"Practice and V1 race share geometry")
check(catalog.Entries.Track01.MaxPlayers==1 and catalog.Entries.Track01.TargetLaps==1
 and catalog.Entries.Track01.MatchType=="SOLO_PRACTICE","Practice stays solo")
check(catalog.Entries.Track01Race.DisplayName=="Base Circuit" and catalog.Entries.Track01Race.MaxPlayers==4
 and catalog.Entries.Track01Race.TargetLaps==2 and catalog.Entries.Track01Race.PreviewRotationDegrees==90,
 "Base Circuit public capability")
check(catalog.Entries.Track02.MaxPlayers==1 and catalog.Entries.Track02.TargetLaps==3
 and catalog.Entries.Track02.MatchType=="SOLO_PROTOTYPE","prototype stays solo")
check(catalog.previewKey(catalog.Entries.Track01)~=catalog.previewKey(catalog.Entries.Track01Race),
 "shared geometry uses distinct preview key")
check(string.find(catalog.capabilityLabel(catalog.Entries.Track01Race),"1–4 RACERS",1,true)~=nil,
 "public selection communicates flexible capacity")
for i,cf in catalog.Entries.Track01.GridSlots do
 check(cf==catalog.Entries.Track01Race.GridSlots[i],"identical V1 grid "..i)
end
for _, id in catalog.Order do
 local kind=mode.resolve(id)
 check(kind==(if id=="Track01" then "PRACTICE" else "RACE"),"mode "..id)
 local expected=if id=="Track01" then 1 elseif id=="Track02" then 3 else 2
 check(catalog.Entries[id].TargetLaps==expected and mode.targetLaps(kind,id)==expected,"laps "..id)
 check(mode.label(kind,id)==(if id=="Track01" then "PRACTICE / 1 LAP" else "RACE / "..expected.." LAPS"),"label "..id)
end
check(raceConfig.TOTAL_LAPS==3,"global laps unchanged")
check(not fs.isFile("src/client/DrivingLicenseUiController.luau"),"no License/tutorial controller")
local garageSource=fs.readFile("src/client/GarageUiController.luau")
check(not string.find(garageSource,"licenseButton",1,true),"no dedicated License button")
check(string.find(garageSource,'remote:FireServer("Ready", driverId, kartId, trackId)',1,true)~=nil,"client sends only selections")
local prototype=child(services.Workspace,"Folder","Prototype")
local kart=child(prototype,"Model","Kart")
local chassis=child(kart,"Part","Chassis"); kart.PrimaryPart=chassis
local seat=child(kart,"Seat","Seat")
local track=child(prototype,"Model","TestTrack")
track:SetAttribute("TrackId","Track01"); track:SetAttribute("GeometryId","PracticeCircuitV1"); track:SetAttribute("CheckpointCount",2)
local roads=child(track,"Folder","Road")
local road=child(roads,"Part","Road"); road.Size=V.new(500,1,500)
local gates=child(track,"Folder","RaceTriggers")
local finish=child(gates,"Part","Finish"); finish.Size=V.new(10,10,4)
finish:SetAttribute("RaceGate",true); finish:SetAttribute("GateType","StartFinish")
local checkpoints={}
for i=1,2 do
 local cp=child(gates,"Part","CP"..i); cp.Size=V.new(10,10,4); cp.CFrame=CF.new(0,0,-i*40)
 cp:SetAttribute("RaceGate",true); cp:SetAttribute("GateType","Checkpoint"); cp:SetAttribute("CheckpointIndex",i)
 checkpoints[i]=cp
end
child(shared,"ModuleScript","TrackCatalog")
modules.TrackCatalog={DefaultId="Track01",Entries={Track01={Id="Track01",GeometryId="PracticeCircuitV1",MatchType="SOLO_PRACTICE",MaxPlayers=1},Track02={Id="Track02",GeometryId="PracticeCircuitV1",MatchType="SOLO_PROTOTYPE",MaxPlayers=1},Track03={Id="Track03",GeometryId="PracticeCircuitV1",MatchType="SOLO_PROTOTYPE",MaxPlayers=1},Track01Race={Id="Track01Race",GeometryId="PracticeCircuitV1",MatchType="PUBLIC_RACE",MaxPlayers=4}}}
local player=child(services.Players,"Player","Driver")
player.Character=object("Model","Character")
local human=child(player.Character,"Humanoid","Humanoid"); human.Health=100; human.SeatPart=seat
player:SetAttribute("SelectedTrackId","Track01")
kart:SetAttribute("RaceStartCFrame",CF.new(0,0,20))
child(server,"ModuleScript","PrototypeWorld")
local kartContext={owner=player,kart=kart,chassis=chassis,seat=seat}
local releasedKartContexts=0
modules.PrototypeWorld={onDriftOutcome=function() end,getKartContext=function(p)
 if p==player then return kartContext end
end, getRaceKart=function(p)
 if p==player and p:GetAttribute("RaceState")=="RACING" and not kart:GetAttribute("RaceControlsLocked") then return kart,chassis end
end, activateNitro=function() return true end, applySlickHit=function() return true end,
 releaseKartContext=function() releasedKartContexts+=1 end}
load("src/server/RaceSession.luau",server,"RaceSession")
load("src/server/RaceRanking.luau",server,"RaceRanking")
load("src/server/RacerState.luau",server,"RacerState")
local race=load("src/server/RaceController.luau",server,"RaceController")
local routeOptions={}
race.start(routeOptions)
load("src/shared/RaceItemConfig.luau",shared,"RaceItemConfig")
load("src/shared/RaceItemCatalog.luau",shared,"RaceItemCatalog")
load("src/shared/RaceItemSlots.luau",shared,"RaceItemSlots")
load("src/server/RaceLoadout.luau",server,"RaceLoadout")
load("src/server/RaceItemGeometry.luau",server,"RaceItemGeometry")
load("src/server/RaceItemVisuals.luau",server,"RaceItemVisuals")
load("src/server/HomingMissileService.luau",server,"HomingMissileService")
load("src/server/ThunderStrikeService.luau",server,"ThunderStrikeService")
load("src/server/SmokeHazardService.luau",server,"SmokeHazardService")
load("src/server/TacticalLoadoutService.luau",server,"TacticalLoadoutService")
local items=load("src/server/RaceItemController.luau",server,"RaceItemController"); items.start()
local function tick(dt) now+=dt; services.RunService.Heartbeat:Fire(dt) end
local function start(trackId)
 local kind=mode.resolve(trackId)
 seat.Occupant=nil; tick(0.1)
 player:SetAttribute("SelectedTrackId",trackId); track:SetAttribute("TrackId",trackId)
 player:SetAttribute("RaceMode","UNTRUSTED"); player:SetAttribute("RaceState","PRE_RACE")
 seat.Occupant=human; tick(0.1)
 check(player:GetAttribute("RaceMode")==kind,"server derives mode "..kind)
 check(player:GetAttribute("RaceMaxPlayers")==modules.TrackCatalog.Entries[trackId].MaxPlayers,
  "server publishes selected capacity "..trackId)
 if trackId=="Track01Race" then
  check(player:GetAttribute("RaceState")=="PRE_RACE" and player:GetAttribute("RaceMatchStatus")=="WAITING",
   "circuit waits for host selection")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
  services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,"StartSolo")
 end
 check(player:GetAttribute("RaceState")=="COUNTDOWN","countdown "..kind)
 check(player:GetAttribute("RaceChargeNitro")==1 and player:GetAttribute("RaceChargeSlick")==1 and player:GetAttribute("RaceChargeShield")==1,"real loadout "..kind)
 tick(3.1)
 check(player:GetAttribute("RaceState")=="RACING","GO "..kind)
end
local function cross(gate, reverse, duration)
 chassis.CFrame=CF.new(100,0,100); tick(0.1)
 chassis.CFrame=gate.CFrame; chassis.AssemblyLinearVelocity=V.new(0,0,if reverse then 70 else -70); tick(duration or 3)
end
local function crossFinishPlaneOutside(x, reverse)
 local before=if reverse then -6 else 6
 local after=if reverse then 6 else -6
 chassis.CFrame=finish.CFrame*CF.new(x,0,before); tick(0.1)
 chassis.AssemblyLinearVelocity=V.new(0,0,if reverse then 70 else -70)
 chassis.CFrame=finish.CFrame*CF.new(x,0,after); tick(0.1)
end
start("Track01")
check(player:GetAttribute("RaceTotalLaps")==1,"practice published target")
crossFinishPlaneOutside(7,false)
check(player:GetAttribute("RaceFinishMissedSerial")==0,"missing checkpoint does not show finish miss")
cross(checkpoints[2]); cross(finish)
check(player:GetAttribute("RaceCompletedLaps")==0,"skipped checkpoints cannot pass")
cross(checkpoints[1],true)
check(player:GetAttribute("RaceNextCheckpoint")==1,"wrong direction cannot pass")
cross(checkpoints[1]); cross(checkpoints[2])
crossFinishPlaneOutside(100,false)
check(player:GetAttribute("RaceFinishMissedSerial")==0,"distant finish plane is silent")
crossFinishPlaneOutside(7,true)
check(player:GetAttribute("RaceFinishMissedSerial")==0,"reverse finish plane is silent")
crossFinishPlaneOutside(7,false)
check(player:GetAttribute("RaceFinishMissedSerial")==1 and player:GetAttribute("RaceCompletedLaps")==0,"outside forward crossing warns without lap")
cross(finish)
check(player:GetAttribute("RaceState")=="FINISHING" and kart:GetAttribute("KartFinishRollActive")==true
 and kart:GetAttribute("RaceControlsLocked")==true and player:GetAttribute("RaceFinishPhase")=="ROLL","practice enters locked moving finish sequence")
check(player:GetAttribute("RaceCompletedLaps")==1,"one lap only")
check(player:GetAttribute("RaceLap1Time")>0 and player:GetAttribute("RaceBestLapNumber")==1,"practice lap history includes standing start")
local officialTime=player:GetAttribute("RaceFinalTime")
local presentationPosition=chassis.Position
chassis.CFrame=chassis.CFrame*rb.CFrame.Angles(.12,.30,-.08)
chassis.AssemblyLinearVelocity=rb.Vector3.new(3,1,2)
chassis.AssemblyAngularVelocity=rb.Vector3.new(1,2,3)
tick(raceConfig.FINISH_ROLL_SECONDS+0.01)
check((chassis.Position-presentationPosition).Magnitude<=.001,"PRESENT alignment retains chassis center")
check(chassis.CFrame.LookVector:Dot(finish.CFrame.LookVector)>=.999
 and chassis.CFrame.UpVector:Dot(finish.CFrame.UpVector)>=.999,"PRESENT aligns both gate axes")
check(chassis.AssemblyLinearVelocity.Magnitude==0 and chassis.AssemblyAngularVelocity.Magnitude==0,
 "PRESENT stops linear/angular motion")
check(player:GetAttribute("RaceState")=="FINISHING" and player:GetAttribute("RaceFinishPhase")=="PRESENT"
 and not kart:GetAttribute("KartFinishRollActive") and player:GetAttribute("RaceFinalTime")==officialTime,"presentation follows roll without changing official time")
tick(raceConfig.FINISH_CAMERA_TRANSITION_SECONDS)
check(player:GetAttribute("RaceState")=="FINISHED" and kart:GetAttribute("KartFinishRollActive")==false
 and player:GetAttribute("RaceFinishPhase")=="PRESENT" and player:GetAttribute("RaceFinalTime")==officialTime,"practice result follows presentation without added time")
check(player:GetAttribute("RaceFinishMissedSerial")==1,"valid finish gives no additional miss warning")
check(player:GetAttribute("LicenseCompletedThisSession")==nil,"no license state created")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,"Rematch")
check(player:GetAttribute("RaceTotalLaps")==1 and player:GetAttribute("RaceMode")=="PRACTICE","practice rematch stays practice")
for _, id in {"Track01","Track01Race","Track02","Track03"} do
 start(id)
 local laps=catalog.Entries[id].TargetLaps
 check(player:GetAttribute("RaceTotalLaps")==laps,"published target "..id)
 for lap=1,laps do
  local duration=if lap==2 then 2 else (if lap==3 then 2.5 else 3)
  cross(checkpoints[1],nil,duration); cross(checkpoints[2],nil,duration); cross(finish,nil,duration)
  check(player:GetAttribute("RaceState")== (if lap==laps then "FINISHING" else "RACING"),id.." lap "..lap)
  check(player:GetAttribute("RaceLap"..lap.."Time")>0,id.." lap history "..lap)
 end
 if laps==3 then check(player:GetAttribute("RaceBestLapNumber")==2,"middle lap is fastest") end
 local recorded=player:GetAttribute("RaceFinalTime")
 tick(raceConfig.FINISH_SEQUENCE_SECONDS+0.01)
 check(player:GetAttribute("RaceState")=="FINISHED" and player:GetAttribute("RaceFinishPhase")=="PRESENT"
  and player:GetAttribute("RaceFinalTime")==recorded,id.." delayed result preserves official time")
 check(player:GetAttribute("LicenseCompletedThisSession")==nil,"no completion gate "..id)
 services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,"Rematch")
 if id=="Track01Race" then
  check(player:GetAttribute("RaceState")=="PRE_RACE" and player:GetAttribute("RaceMatchStatus")=="WAITING"
   and player:GetAttribute("RaceMatchWaitReason")=="REMATCH", "solo circuit rematch returns to lobby")
tick(raceConfig.ITEM_PREP_SECONDS) -- Complete the server-owned item prep before this start action.
  services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,"StartSolo")
 end
 check(player:GetAttribute("RaceState")=="COUNTDOWN" and player:GetAttribute("RaceTotalLaps")==laps,"rematch target "..id)
 check(player:GetAttribute("RaceChargeNitro")==1 and player:GetAttribute("RaceChargeShield")==1,"rematch replenishes "..id)
 check(player:GetAttribute("RaceLap1Time")==0 and player:GetAttribute("RaceLap2Time")==0 and player:GetAttribute("RaceLap3Time")==0
  and player:GetAttribute("RaceBestLapNumber")==0 and player:GetAttribute("RaceFinishPhase")=="NONE"
  and not kart:GetAttribute("KartFinishRollActive"),"rematch clears lap and finish state "..id)
end
start("Track01")
cross(checkpoints[1]); cross(checkpoints[2]); cross(finish)
tick(raceConfig.FINISH_SEQUENCE_SECONDS+0.01)
local hubReturns=0
local releaseCountBeforeReserved= releasedKartContexts
routeOptions.returnToHub=function() hubReturns+=1; return true end
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,"ReturnGarage")
check(hubReturns==1 and player:GetAttribute("RaceState")=="FINISHED"
 and releasedKartContexts==releaseCountBeforeReserved,"reserved Finish Garage requests HUB without premature kart cleanup")
routeOptions.returnToHub=nil
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,"ReturnGarage")
check(player:GetAttribute("RaceState")=="GARAGE" and player:GetAttribute("RaceFinishPhase")=="NONE"
 and not kart:GetAttribute("KartFinishRollActive"),"Garage clears finish presentation")
print("PASS: "..count.." Practice/race mode/checkpoint/loadout integration checks")

-- Drive the real Hard geometry through the production controller, including
-- excursions around CP4/CP5 (the two checkpoints left pending in the report).
-- Explicit basis avoids this Lune version's lookAt Z-axis reflection.
local function lookAt(position, target)
 local forward=(target-position).Unit
 return CF.fromMatrix(position,forward:Cross(V.yAxis),V.yAxis,-forward)
end
local geometry=modules.TrackGeometry
local definition=geometry.getDefinition("HardCircuitV1")
local course=geometry.getCourse(definition)
modules.TrackCatalog.Entries.Track03.GeometryId="HardCircuitV1"
local builderEnv=table.clone(environment)
builderEnv.CFrame=table.clone(CF);builderEnv.CFrame.lookAt=lookAt
builderEnv.UDim2=rb.UDim2;builderEnv.UDim=rb.UDim
builderEnv.require=function(module)return assert(modules[module.Name],module.Name)end
local realBuilder=luau.load(fs.readFile("src/server/TrackBuilder.luau"),{environment=builderEnv})()
track=realBuilder.build(prototype,catalog.Entries.Track03,0)
roads=track:FindFirstChild("Road")
gates=track:FindFirstChild("RaceTriggers")
finish=gates:FindFirstChild("StartFinish")
checkpoints={}
for i=1,#course.CheckpointSamples do checkpoints[i]=gates:FindFirstChild("Checkpoint"..i) end
local support=track:FindFirstChild("SafetyGround")
local outer=course.Samples[1]
for _,point in course.Samples do if point.X>outer.X then outer=point end end
local function supported(position)
 return support.Anchored and support.CanCollide and math.abs(position.X-support.Position.X)<support.Size.X/2
  and math.abs(position.Z-support.Position.Z)<support.Size.Z/2 and support.Parent~=roads
end
check(supported(outer+V.xAxis*124),"generated support contains outer road edge plus 100 studs")
kart:SetAttribute("RaceStartCFrame",lookAt(course.StartPosition-course.StartTangent*25,course.StartPosition))
start("Track03")
for lap=1,2 do
 for step=0,2000 do
  local fraction=step/2000
  local tangent=geometry.getTangentAtFraction(course.Samples,fraction)
  local offset=0
  for _,i in {4,5,6} do
   local gap=math.abs(fraction-course.CheckpointSamples[i].Fraction)
   offset=math.max(offset,54*math.clamp((0.018-gap)/0.008,0,1))
  end
  local position=geometry.getSampleAtFraction(course.Samples,fraction)+V.new(-tangent.Z,0,tangent.X)*offset
  chassis.CFrame=lookAt(position,position+tangent)
  chassis.AssemblyLinearVelocity=tangent*70
  tick(0.05)
  if lap==1 and step==560 then
   local nextCheckpoint=player:GetAttribute("RaceNextCheckpoint")
   local reset=kart:GetAttribute("RaceResetSerial")
   for _,distance in {40,80,100} do
    local offroad=outer+V.xAxis*(definition.RoadWidth/2+distance)
    check(supported(offroad),"real SafetyGround recovery point collidable and covered")
    chassis.CFrame=lookAt(offroad,offroad+tangent);tick(1)
    check(kart:GetAttribute("KartOffTrack")==true and player:GetAttribute("RaceState")=="RACING","support does not count as road")
   end
   chassis.CFrame=lookAt(position,position+tangent);tick(.3)
   check(kart:GetAttribute("KartOffTrack")==false,"return before 15 seconds clears offtrack")
   check(player:GetAttribute("RaceNextCheckpoint")==nextCheckpoint and player:GetAttribute("RaceCompletedLaps")==0
    and kart:GetAttribute("RaceResetSerial")==reset,"recovery preserves checkpoint/lap/reset state")
  end
 end
 check(player:GetAttribute("RaceCompletedLaps")==lap,"Hard excursion/return finish counts lap "..lap)
end
check(player:GetAttribute("RaceState")=="FINISHING" or player:GetAttribute("RaceState")=="FINISHED","Hard finishes after second real geometry lap")
check(player:GetAttribute("RaceLap1Time")>0 and player:GetAttribute("RaceLap2Time")>0 and player:GetAttribute("RaceLap3Time")==0,"Hard two-lap history only")
tick(raceConfig.FINISH_SEQUENCE_SECONDS+0.01)
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,"Rematch")
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
check(player:GetAttribute("RaceState")=="RACING","Hard offroad test starts a fresh round")
-- Provisional recovery must not bypass the existing off-road timeout.
chassis.CFrame=CF.new(outer+V.xAxis*124); tick(raceConfig.OFF_TRACK_TIMEOUT_SECONDS+0.1)
check(player:GetAttribute("RaceState")=="DNF","offroad timeout still wins")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,"Rematch")
tick(raceConfig.COUNTDOWN_SECONDS+0.1)
check(player:GetAttribute("RaceState")=="RACING","reserved quit setup reaches active Hard race")
routeOptions.returnToHub=function()
 hubReturns+=1
 player:SetAttribute("RaceEntryError","RACE SERVER UNAVAILABLE - PLEASE TRY AGAIN")
 return false
end
releaseCountBeforeReserved=releasedKartContexts
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,"QuitRace")
local session=modules.RaceSession.active()
check(hubReturns==2 and session.terminal[player]=="FORFEIT"
 and player:GetAttribute("RaceState")=="DNF" and player:GetAttribute("RaceDNFReason")=="FORFEIT"
 and player:GetAttribute("RaceSessionComplete")==true,"reserved quit forfeits and requests HUB exactly once")
check(kart:GetAttribute("RaceControlsLocked")==true and kart:GetAttribute("KartFinishRollActive")==false
 and chassis.AssemblyLinearVelocity==V.zero and chassis.AssemblyAngularVelocity==V.zero
 and player:GetAttribute("RaceMapActive")==false,"failed HUB return leaves locked inert kart")
check(player:GetAttribute("RaceFinalTime")==0 and player:GetAttribute("RaceFinishPosition")==0
 and releasedKartContexts==releaseCountBeforeReserved and session:contains(player),"forfeit gives no finish result and retains kart until departure")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,"QuitRace")
check(hubReturns==2,"repeated Quit cannot duplicate HUB return")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,"Rematch")
check(player:GetAttribute("RaceState")=="DNF" and hubReturns==2,"forfeit cannot rematch while HUB return is pending")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,"ReturnGarage")
check(hubReturns==3 and session:contains(player) and releasedKartContexts==releaseCountBeforeReserved,
 "failed HUB return keeps Garage retry path and kart")
services.Players.PlayerRemoving:Fire(player)
check(releasedKartContexts==releaseCountBeforeReserved+1 and not session:contains(player),
 "successful departure releases reserved kart through PlayerRemoving")
print("PASS: "..count.." total race integration checks including real Hard recovery")
