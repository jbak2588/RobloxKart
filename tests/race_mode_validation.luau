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
local mode=load("src/shared/RaceMode.luau",shared,"RaceMode")
local catalog=load("src/shared/TrackCatalog.luau",shared,"TrackCatalog")
check(#catalog.Order==3 and catalog.Order[1]=="Track01" and catalog.DefaultId=="Track01","Practice first/default")
check(catalog.Order[2]=="Track01Race" and catalog.Order[3]=="Track02","two races follow Practice")
check(catalog.Entries.Track01.GeometryId==catalog.Entries.Track01Race.GeometryId,"Practice and V1 race share geometry")
for i,cf in catalog.Entries.Track01.GridSlots do
 check(cf==catalog.Entries.Track01Race.GridSlots[i],"identical V1 grid "..i)
end
for _, id in catalog.Order do
 local kind=mode.resolve(id)
 check(kind==(if id=="Track01" then "PRACTICE" else "RACE"),"mode "..id)
 check(mode.targetLaps(kind)==(if id=="Track01" then 1 else 3),"laps "..id)
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
modules.TrackCatalog={DefaultId="Track01",Entries={Track01={Id="Track01",GeometryId="PracticeCircuitV1"},Track02={Id="Track02",GeometryId="PracticeCircuitV1"},Track01Race={Id="Track01Race",GeometryId="PracticeCircuitV1"}}}
local player=child(services.Players,"Player","Driver")
player.Character=object("Model","Character")
local human=child(player.Character,"Humanoid","Humanoid"); human.Health=100; human.SeatPart=seat
player:SetAttribute("SelectedTrackId","Track01")
kart:SetAttribute("RaceStartCFrame",CF.new(0,0,20))
local race=load("src/server/RaceController.luau",server,"RaceController")
race.start()
child(server,"ModuleScript","PrototypeWorld")
modules.PrototypeWorld={getRaceKart=function(p)
 if p==player and p:GetAttribute("RaceState")=="RACING" and not kart:GetAttribute("RaceControlsLocked") then return kart,chassis end
end, activateNitro=function() return true end, applySlickHit=function() return true end}
load("src/shared/RaceItemConfig.luau",shared,"RaceItemConfig")
load("src/server/RaceLoadout.luau",server,"RaceLoadout")
load("src/server/RaceItemGeometry.luau",server,"RaceItemGeometry")
load("src/server/RaceItemVisuals.luau",server,"RaceItemVisuals")
local items=load("src/server/RaceItemController.luau",server,"RaceItemController"); items.start()
local function tick(dt) now+=dt; services.RunService.Heartbeat:Fire(dt) end
local function start(trackId)
 local kind=mode.resolve(trackId)
 seat.Occupant=nil; tick(0.1)
 player:SetAttribute("SelectedTrackId",trackId); track:SetAttribute("TrackId",trackId)
 player:SetAttribute("RaceMode","UNTRUSTED"); player:SetAttribute("RaceState","PRE_RACE")
 seat.Occupant=human; tick(0.1)
 check(player:GetAttribute("RaceMode")==kind,"server derives mode "..kind)
 check(player:GetAttribute("RaceState")=="COUNTDOWN","countdown "..kind)
 check(player:GetAttribute("RaceChargeNitro")==1 and player:GetAttribute("RaceChargeSlick")==1 and player:GetAttribute("RaceChargeShield")==1,"real loadout "..kind)
 tick(3.1)
 check(player:GetAttribute("RaceState")=="RACING","GO "..kind)
end
local function cross(gate, reverse)
 chassis.CFrame=CF.new(100,0,100); tick(0.1)
 chassis.CFrame=gate.CFrame; chassis.AssemblyLinearVelocity=V.new(0,0,if reverse then 70 else -70); tick(3)
end
start("Track01")
check(player:GetAttribute("RaceTotalLaps")==1,"practice published target")
cross(checkpoints[2]); cross(finish)
check(player:GetAttribute("RaceCompletedLaps")==0,"skipped checkpoints cannot pass")
cross(checkpoints[1],true)
check(player:GetAttribute("RaceNextCheckpoint")==1,"wrong direction cannot pass")
cross(checkpoints[1]); cross(checkpoints[2]); cross(finish)
check(player:GetAttribute("RaceState")=="FINISHED","practice normal finish without tutorial/items")
check(player:GetAttribute("RaceCompletedLaps")==1,"one lap only")
check(player:GetAttribute("LicenseCompletedThisSession")==nil,"no license state created")
services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,"Rematch")
check(player:GetAttribute("RaceTotalLaps")==1 and player:GetAttribute("RaceMode")=="PRACTICE","practice rematch stays practice")
for _, id in {"Track01","Track01Race","Track02"} do
 start(id)
 local laps=if id=="Track01" then 1 else 3
 check(player:GetAttribute("RaceTotalLaps")==laps,"published target "..id)
 for lap=1,laps do
  cross(checkpoints[1]); cross(checkpoints[2]); cross(finish)
  check(player:GetAttribute("RaceState")== (if lap==laps then "FINISHED" else "RACING"),id.." lap "..lap)
 end
 check(player:GetAttribute("LicenseCompletedThisSession")==nil,"no completion gate "..id)
 services.ReplicatedStorage.RaceControl.OnServerEvent:Fire(player,"Rematch")
 check(player:GetAttribute("RaceState")=="COUNTDOWN" and player:GetAttribute("RaceTotalLaps")==laps,"rematch target "..id)
 check(player:GetAttribute("RaceChargeNitro")==1 and player:GetAttribute("RaceChargeShield")==1,"rematch replenishes "..id)
end
print("PASS: "..count.." Practice/race mode/checkpoint/loadout integration checks")

-- Drive the real V2 geometry through the production controller, including
-- excursions around CP4/CP5 (the two checkpoints left pending in the report).
-- Explicit basis avoids this Lune version's lookAt Z-axis reflection.
local function lookAt(position, target)
 local forward=(target-position).Unit
 return CF.fromMatrix(position,forward:Cross(V.yAxis),V.yAxis,-forward)
end
local geometry=modules.TrackGeometry
local definition=geometry.getDefinition("PrototypeCircuitV2")
local course=geometry.getCourse(definition)
modules.TrackCatalog.Entries.Track02.GeometryId="PrototypeCircuitV2"
track:SetAttribute("GeometryId","PrototypeCircuitV2")
track:SetAttribute("CheckpointCount",#course.CheckpointSamples)
road:Destroy()
for i,point in course.Samples do
 local following=course.Samples[i % #course.Samples+1]
 local strip=child(roads,"Part","Road"..i)
 strip.Size=V.new(definition.RoadWidth,1,(following-point).Magnitude+2)
 strip.CFrame=lookAt((point+following)/2,following)
end
finish.CFrame=lookAt(course.StartPosition,course.StartPosition+course.StartTangent)
finish.Size=V.new(definition.RoadWidth+16,16,12)
for i,cp in course.CheckpointSamples do
 local gate=checkpoints[i] or child(gates,"Part","CP"..i)
 gate.Size=V.new(definition.RoadWidth+16,16,12)
 gate.CFrame=lookAt(cp.Position,cp.Position+cp.Tangent)
 gate:SetAttribute("RaceGate",true); gate:SetAttribute("GateType","Checkpoint"); gate:SetAttribute("CheckpointIndex",i)
 checkpoints[i]=gate
end
kart:SetAttribute("RaceStartCFrame",lookAt(course.StartPosition-course.StartTangent*25,course.StartPosition))
start("Track02")
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
 end
 check(player:GetAttribute("RaceCompletedLaps")==lap,"V2 excursion/return finish counts lap "..lap)
end
-- Provisional recovery must not bypass the existing off-road timeout.
chassis.CFrame=CF.new(1500,0,1500); tick(10.1)
check(player:GetAttribute("RaceState")=="DNF","offroad timeout still wins")
print("PASS: "..count.." total race integration checks including real V2 recovery")
