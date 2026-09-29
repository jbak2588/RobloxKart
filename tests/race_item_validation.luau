-- lune run tests/race_item_validation.luau
-- Deterministic server integration with signals/time/physics transport mocked.
-- Executes production PrototypeWorld and RaceItemController, NOT Studio physics.
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
	Instance={new=object}, Vector3=V, CFrame=CF, Color3=rb.Color3, Enum=rb.Enum,
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
config=table.clone(config); config.DEBUG_TELEMETRY=false; modules.KartConfig=config
local catalog=load("src/shared/RaceItemCatalog.luau",shared,"RaceItemCatalog")
for _, id in {"Nitro","Slick","Shield","Smoke"} do check(catalog[id].Id==id,"stable ID "..id) end
check(config.NITRO_MAX_SPEED==100 and config.NITRO_DURATION==3 and config.NITRO_ACCELERATION==75 and config.NITRO_EXIT_DECELERATION==15,"Nitro configuration")
check(config.MAX_FORWARD_SPEED==70 and config.MINI_BOOST_MAX_SPEED==100
	and config.MINI_BOOST_DURATION==2.0 and config.MINI_BOOST_ACCELERATION==65,
	"approved Mini Boost Beta 2 tuning preserves normal speed and acceleration")
check(config.NITRO_MAX_SPEED==100 and config.NITRO_DURATION==3 and config.OFF_TRACK_MAX_SPEED==50,
	"Nitro identity and off-track safety remain unchanged")
local loadoutType=load("src/server/RaceLoadout.luau",server,"RaceLoadout")
local loadout=loadoutType.new()
loadout:prepare()
check(loadout.counts.Nitro==1 and loadout.counts.Slick==1 and loadout.counts.Shield==1 and loadout.counts.Smoke==0,"equal base resources")
check(not loadout:select("Smoke") and not loadout:select({}) and not loadout:select(2),"selection rejects unsupported IDs/types")
check(not loadout:use("Use",1,function() error("must not activate") end) and loadout.counts.Nitro==1,"payload injection rejected")
check(not loadout:use("Use",0,function() return false,"locked" end) and loadout.counts.Nitro==1,"rejected retains charge")
check(loadout:use("Use",0,function() return true end) and loadout.counts.Nitro==0 and loadout.counts.Slick==1 and loadout.selected=="Slick","accepted consumes only selected and auto-selects")
check(not loadout:select("Nitro"),"empty selection cannot grant")
check(loadout:grantBonusNitro() and loadout.counts.Nitro==1 and not loadout:grantBonusNitro(),"bonus after use once per race")
loadout:prepare()
check(loadout:grantBonusNitro() and loadout.counts.Nitro==2 and not loadout:grantBonusNitro(),"Nitro maximum two")
loadout:clear()
check(loadout.selected=="" and loadout.counts.Nitro==0 and loadout.counts.Slick==0 and loadout.counts.Shield==0,"clear temporary resources")
-- Capture server state for legacy scenario fixture setup only; no production grant API.
local instances={}
local originalNew=loadoutType.new
loadoutType.new=function() local result=originalNew(); table.insert(instances,result); return result end
local Nitro=load("src/server/NitroState.luau",server,"NitroState")
load("src/server/DriftTelemetry.luau",server,"DriftTelemetry")
load("src/server/KartContext.luau",server,"KartContext")
local raceConfig=load("src/shared/RaceConfig.luau",shared,"RaceConfig")
child(shared,"ModuleScript","TrackCatalog")
modules.TrackCatalog={DefaultId="Track01",Entries={Track01={GridSlots={CF.identity},MaxPlayers=1},
 Track01Race={MaxPlayers=4}}}
local sessionType=load("src/server/RaceSession.luau",server,"RaceSession")
local itemConfig=load("src/shared/RaceItemConfig.luau",shared,"RaceItemConfig")
check(itemConfig.DRIFT_BONUS_REQUIRED_BOOSTS==5,"cumulative reward requires five actual Boosts")
local geometry=load("src/server/RaceItemGeometry.luau",server,"RaceItemGeometry")
local slickMotion=load("src/server/SlickMotion.luau",server,"SlickMotion")
load("src/server/RaceItemVisuals.luau",server,"RaceItemVisuals")
local overlap=Nitro.new(config)
overlap:activate("driver",0)
check(overlap:forwardSpeed(95,true,1,1/60)>95 and overlap:forwardSpeed(95,true,1,1/60)<100,"Mini Boost to Nitro ramp")
check(overlap:forwardSpeed(100,true,1,1/60)==100,"no additive stacking")
overlap:update(3,"driver",true,false,false,true)
check(overlap:forwardSpeed(100,true,1,1/60)==100,"expired Nitro keeps equal-speed active Mini Boost")
check(overlap:forwardSpeed(95,true,1,1/60)>95,"active Mini Boost accelerates toward 100")

-- Minimal world dependencies; actual movement/controller modules run below.
for name, result in {
	KartCatalog={DefaultId="Kart01",Entries={Kart01={}}},
	KartVisualFactory={createVisual=function() return object("Model","Visual") end},
} do child(shared,"ModuleScript",name); modules[name]=result end
child(server,"ModuleScript","TrackBuilder")
modules.TrackBuilder={build=function(prototype)
	local track=child(prototype,"Model","TestTrack")
	child(track,"Folder","BarrierTriggers")
	local roads=child(track,"Folder","Road")
	local road=child(roads,"Part","Road1")
	road.Size=V.new(60,0.05,2000)
end}
local player=child(services.Players,"Player","TestDriver")
player.UserId=1
player.Character=object("Model","Character")
local human=child(player.Character,"Humanoid","Humanoid"); human.Health=100
load("src/server/RacerCollisionIsolation.luau",server,"RacerCollisionIsolation")
load("src/server/KartUprightRecovery.luau",server,"KartUprightRecovery")
local world=load("src/server/PrototypeWorld.luau",server,"PrototypeWorld")
check(not world.activateNitro(player),"pre-start rejection")
world.start()
check(world.assignDefaultKart(player) ~= nil,"default kart assigned to driver")
local items=load("src/server/RaceItemController.luau",server,"RaceItemController")
items.start()
local initialSession=sessionType.new("Track01","PRACTICE",1)
initialSession:add(player,{})
local state=instances[1]
local function fixtureItem(_,id)
	state.counts[id]=1
	state.selected=id
	player:SetAttribute("SelectedRaceItemId",id)
	player:SetAttribute("RaceCharge"..id,1)
	return true
end
local kart=services.Workspace.Prototype.Kart
local seat=kart.Seat
local chassis=kart.Chassis
local control=services.ReplicatedStorage.KartControl
local remote=services.ReplicatedStorage.RaceItemControl
local function step(throttle,dt)
	dt=dt or 1/60
	now+=dt
	control.OnServerEvent:Fire(player,throttle,0,false)
	services.RunService.Heartbeat:Fire(dt)
	return -chassis.AssemblyLinearVelocity.Z
end
local function startRace()
	player:SetAttribute("RaceState","COUNTDOWN")
	kart:SetAttribute("RaceControlsLocked",true)
	step(0)
	seat.Occupant=human; human.SeatPart=seat
	kart:SetAttribute("KartOffTrack",false)
	player:SetAttribute("RaceState","RACING")
	kart:SetAttribute("RaceControlsLocked",false)
	step(1)
end
startRace()
check(player:GetAttribute("SelectedRaceItemId")=="Nitro","Studio RACING grants Nitro")
remote.OnServerEvent:Fire(player,"Use","Nitro")
check(not kart:GetAttribute("KartNitroActive") and (player:GetAttribute("SelectedRaceItemId")~=""),"remote rejects extra payload")
kart:SetAttribute("RaceControlsLocked",true)
remote.OnServerEvent:Fire(player,"Use")
check((player:GetAttribute("SelectedRaceItemId")~=""),"locked remote keeps item")
kart:SetAttribute("RaceControlsLocked",false)
for _=1,150 do step(1) end
check(math.abs(-chassis.AssemblyLinearVelocity.Z-70)<0.001,"normal speed 70")
remote.OnServerEvent:Fire(player,"Use")
check(kart:GetAttribute("KartNitroActive") and player:GetAttribute("RaceChargeNitro")==0,"authoritative activation and consumption")
local speed=step(1)
check(speed>70 and speed<72,"real movement branch ramps first frame")
for _=1,30 do speed=step(1) end
check(math.abs(speed-100)<0.001,"100 reached")
check(not world.activateNitro(player),"duplicate rejected")
local activationEnd=now+(3-31/60)
while now+1/60 < activationEnd-0.00001 do step(1) end
check(kart:GetAttribute("KartNitroActive"),"active before 3 seconds")
step(1); speed=step(1)
check(not kart:GetAttribute("KartNitroActive") and speed>99 and speed<100,"expires and decays without snap")
for _=1,120 do speed=step(1) end
check(math.abs(speed-70)<0.001,"smooth exit reaches 70 in about 2 seconds")
check(world.activateNitro(player),"server bridge accepts valid driver")
for _=1,30 do step(1) end
local before=-chassis.AssemblyLinearVelocity.Z
local braking=step(-1)
check(math.abs(braking-(before-config.BRAKE_FORCE/60))<0.001,"S uses existing brake force during Nitro")
local coast=step(0)
check(coast<braking and math.abs(coast-(braking-config.COAST_DECELERATION/60))<0.001,"release uses coast, no forced acceleration")
kart:SetAttribute("KartOffTrack",true)
speed=step(1)
check(not kart:GetAttribute("KartNitroActive") and speed<=50,"off-track cancels and caps Nitro")
check(not world.activateNitro(player),"off-track activation rejected")
kart:SetAttribute("KartOffTrack",false)
for _, state in {"FINISHED","DNF","GARAGE","COUNTDOWN"} do
	startRace(); remote.OnServerEvent:Fire(player,"Use")
	check(kart:GetAttribute("KartNitroActive"),"activate before "..state)
	player:SetAttribute("RaceState",state)
	check(not kart:GetAttribute("KartNitroActive") and (player:GetAttribute("SelectedRaceItemId")=="" or state=="COUNTDOWN"),"clear effects "..state)
end
startRace()
check((player:GetAttribute("SelectedRaceItemId")~=""),"rematch receives fresh base loadout")
player:SetAttribute("RaceState","COUNTDOWN")
check(player:GetAttribute("RaceChargeNitro")==1 and player:GetAttribute("RaceChargeSlick")==1 and player:GetAttribute("RaceChargeShield")==1,"rematch countdown refills")
services.RunService.studio=false
player:SetAttribute("RaceState","RACING")
check(player:GetAttribute("RaceChargeNitro")==1,"published server equal loadout")
services.RunService.studio=true
startRace(); remote.OnServerEvent:Fire(player,"Use")
kart:SetAttribute("RaceResetSerial",1)
check(not kart:GetAttribute("KartNitroActive") and not (player:GetAttribute("SelectedRaceItemId")~=""),"reset clears both")
startRace(); remote.OnServerEvent:Fire(player,"Use")
seat.Occupant=nil
check(not kart:GetAttribute("KartNitroActive"),"unseat cancels")
startRace(); remote.OnServerEvent:Fire(player,"Use")
player.CharacterRemoving:Fire()
check(not kart:GetAttribute("KartNitroActive") and not (player:GetAttribute("SelectedRaceItemId")~=""),"character removal cleanup")
startRace(); remote.OnServerEvent:Fire(player,"Use")
now+=config.INPUT_TIMEOUT+0.1; services.RunService.Heartbeat:Fire(1/60)
check(not kart:GetAttribute("KartNitroActive"),"input timeout cancels")
startRace(); remote.OnServerEvent:Fire(player,"Use")
chassis.CFrame=CF.new(0,-50,0); step(1)
check(not kart:GetAttribute("KartNitroActive") and not (player:GetAttribute("SelectedRaceItemId")~=""),"fall reset cleanup")
startRace(); remote.OnServerEvent:Fire(player,"Use")
for _=1,90 do step(1) end
for _=1,100 do
	now+=1/60
	chassis.AssemblyLinearVelocity=V.new(math.tan(math.rad(15))*60,0,-60)
	control.OnServerEvent:Fire(player,1,.6,true)
	services.RunService.Heartbeat:Fire(1/60)
end
now+=1/60
chassis.AssemblyLinearVelocity=V.new(math.tan(math.rad(15))*60,0,-60)
control.OnServerEvent:Fire(player,1,.6,false)
services.RunService.Heartbeat:Fire(1/60)
check(player:GetAttribute("DriftBonusProgress")==1,"barrier fixture starts with a successful drift")
for expected=2,3 do
	for _=1,130 do step(1) end
	for _=1,100 do
		now+=1/60
		chassis.AssemblyLinearVelocity=V.new(math.tan(math.rad(15))*60,0,-60)
		control.OnServerEvent:Fire(player,1,.6,true)
		services.RunService.Heartbeat:Fire(1/60)
	end
	now+=1/60
	chassis.AssemblyLinearVelocity=V.new(math.tan(math.rad(15))*60,0,-60)
	control.OnServerEvent:Fire(player,1,.6,false)
	services.RunService.Heartbeat:Fire(1/60)
	check(player:GetAttribute("DriftBonusProgress")==expected,"barrier fixture earns "..expected.."/5")
end
local trigger=child(services.Workspace.Prototype.TestTrack.BarrierTriggers,"Part","TestBarrier")
trigger.Size=V.new(20,20,20)
trigger:SetAttribute("BarrierInwardNormal",V.new(0,0,1))
trigger:SetAttribute("BarrierForwardTangent",V.new(0,0,-1))
-- Refresh cached track once to register the newly supplied trigger fixture.
services.Workspace.Prototype.TestTrack.Name="HiddenTrack"; step(1)
services.Workspace.Prototype.HiddenTrack.Name="TestTrack"; step(1)
check(kart:GetAttribute("KartCrashActive") and not kart:GetAttribute("KartNitroActive"),"real barrier path cancels Nitro")
check(player:GetAttribute("DriftBonusProgress")==3,"barrier crash preserves 3/5 progress")
check(not world.activateNitro(player),"crash activation rejected")
check(chassis.AssemblyLinearVelocity.Y==0,"barrier introduces no vertical impulse")
local input=fs.readFile("src/client/KartInputController.luau")
check(string.find(input,'remoteEvent:FireServer(throttle, steering, driftRequested)',1,true)~=nil,"KartControl payload unchanged")
check(string.find(input,'raceItemRemote:FireServer("Use")',1,true)~=nil,"client only sends Use")

-- Exercise actual client input gating, including repeated InputBegan and focus.
local uis=object("UserInputService")
services.UserInputService=uis
for _, name in {"InputBegan","InputEnded","WindowFocusReleased","WindowFocused","TextBoxFocused","TextBoxFocusReleased"} do
	uis[name]=signal()
end
function methods:GetFocusedTextBox() return self._p.focusedBox end
function methods:IsKeyDown() return false end
local requests=0
function methods:FireServer(...)
	if self==remote then requests+=1 end
	self.OnServerEvent:Fire(player,...)
end
services.Players.LocalPlayer=player
local inputController=load("src/client/KartInputController.luau",object("Folder"),"KartInputController")
inputController.start()
local q={KeyCode=rb.Enum.KeyCode.Q}
uis.InputBegan:Fire(q,false); uis.InputBegan:Fire(q,false)
check(requests==1,"held Q produces only one request")
uis.InputEnded:Fire(q)
uis.focusedBox={}; uis.InputBegan:Fire(q,false); uis.InputEnded:Fire(q)
check(requests==1,"focused TextBox ignores Q")
uis.focusedBox=nil
uis.InputBegan:Fire(q,true); uis.InputEnded:Fire(q)
check(requests==1,"processed Q ignored")
human.SeatPart=nil; inputController.useRaceItem()
check(requests==1,"unseated client does not send Use")
check(not world.activateNitro(player),"server rejects unseated driver independently")
human.SeatPart=seat
player:SetAttribute("RaceState","GARAGE"); inputController.useRaceItem()
check(requests==1,"Garage client ignores use")
player:SetAttribute("RaceState","RACING")
inputController.useRaceItem()
check(requests==2,"shared future touch action sends same request")
player:SetAttribute("RaceState","COUNTDOWN"); player:SetAttribute("RaceState","RACING")
check(player:GetAttribute("RaceChargeNitro")==1,"base loadout available outside Studio")
check(fixtureItem(player,"Nitro"),"test fixture selects Nitro")
local nitroChecks=count
local function fresh(itemId)
	player:SetAttribute("RaceState","GARAGE")
	trigger.CFrame=CF.new(10000,0,10000)
	player:SetAttribute("RaceState","COUNTDOWN")
	kart:SetAttribute("RaceControlsLocked",true)
	step(0)
	chassis.CFrame=CF.new(0,1.75,0)
	seat.Occupant=human; human.SeatPart=seat
	kart:SetAttribute("KartOffTrack",false)
	player:SetAttribute("RaceState","RACING")
	kart:SetAttribute("RaceControlsLocked",false)
	step(0)
	if itemId then assert(fixtureItem(player,itemId)) end
end
local function use()
	step(0,0.2)
	remote.OnServerEvent:Fire(player,"Use")
end
local function hazardCount() return #services.Workspace.Prototype.RaceItemHazards:GetChildren() end
check(catalog.Slick.TargetMode=="DropBehind" and catalog.Shield.TargetMode=="Self","C1-B catalog metadata")
check(itemConfig.SLICK_LIFETIME==10 and itemConfig.SLICK_OWNER_GRACE==0.75 and itemConfig.SLICK_EFFECT_DURATION==0.7,"Slick config")
check(itemConfig.SHIELD_DURATION==5 and itemConfig.RACE_ITEM_HIT_IMMUNITY==1,"defense config")
fresh("Slick")
remote.OnServerEvent:Fire(player,"Use",V.new(99,99,99))
check(hazardCount()==0 and player:GetAttribute("SelectedRaceItemId")=="Slick","client cannot provide drop coordinates")
kart:SetAttribute("KartOffTrack",true); use()
check(hazardCount()==0 and player:GetAttribute("SelectedRaceItemId")=="Slick","rejected Slick retains loadout")
check(player:GetAttribute("SlickDeployedSerial")==nil,"rejected Slick publishes no deployment feedback")
kart:SetAttribute("KartOffTrack",false); use()
check(hazardCount()==1 and player:GetAttribute("RaceChargeSlick")==0,"accepted Slick consumes charge")
local hazard=services.Workspace.Prototype.RaceItemHazards:GetChildren()[1]
check(math.abs(hazard.SlickSurface.Position.Z-10)<0.0001,"server drops 10 studs behind chassis")
check(hazard.SlickTrigger.Size==V.new(7,4,5),"authoritative Slick dimensions unchanged during reveal")
check(hazard:FindFirstChild("OilDrop") ~= nil and hazard.SlickSurface.Transparency==1,"accepted deployment starts with projectile and hidden pad")
check(hazard.OilDrop.Position==V.new(0,6.75,3),"ejection starts above rear center for chase visibility")
check(player:GetAttribute("SlickDeployedSerial")==1,"accepted Slick publishes deployment feedback")
check(player:GetAttribute("SlickDeployFrame")==hazard.SlickSurface.CFrame,"rear preview uses authoritative landing frame")
check(player:GetAttribute("SlickEjectPosition")==hazard.OilDrop.Position,"rear preview uses authoritative ejection position")
check(hazard.SlickSurface.Shape==rb.Enum.PartType.Ball,"oil surface is rounded rather than rectangular")
step(0,0.1)
check(hazard.OilDrop.Position.Z>4 and hazard.OilDrop.Position.Z<10,"projectile travels toward server drop position")
step(0,0.11)
check(not hazard:FindFirstChild("OilDrop") and hazard.OilSplash1.Transparency<1,"impact removes projectile and reveals splash")
step(0,0.16)
check(hazard.SlickSurface.Size==V.new(7,0.1,5) and hazard.SlickSurface.Transparency==0,"pad reaches full dimensions after reveal")
step(0,0.06)
check(not hazard:FindFirstChild("OilSplash1") and #hazard:GetChildren()==4,"temporary deployment geometry cleaned")
for _, p in hazard:GetChildren() do
	check(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery,"safe hazard visual "..p.Name)
end
chassis.CFrame=CF.new(0,1.75,10); step(0,0.1)
check(not kart:GetAttribute("KartSlickActive") and hazardCount()==1,"owner grace prevents immediate hit")
step(0,0.7)
check(kart:GetAttribute("KartSlickActive") and hazardCount()==0,"owner hits after grace; single-use hazard removed")
check(kart:GetAttribute("RaceItemHitImmunity"),"offensive hit starts immunity")
local accepted, reason=items.tryApplyOffensiveItem(player,player,"Slick")
check(not accepted and reason=="immune","repeated offensive hit ignored")
check(not world.activateNitro(player),"Nitro rejected during Slick effect")
for _=1,50 do
	step(0)
	chassis.CFrame=chassis.CFrame*CF.Angles(0,chassis.AssemblyAngularVelocity.Y/60,0)
end
check(not kart:GetAttribute("KartSlickActive"),"Slick effect expires")
check(chassis.CFrame.LookVector:Dot(V.new(0,0,-1))>0.94,"Slick recovery usable forward direction")
check(chassis.AssemblyLinearVelocity.Y==0,"Slick no vertical impulse")
step(0,0.3)
check(not kart:GetAttribute("RaceItemHitImmunity"),"immunity expires")

fresh("Slick"); use()
check(fixtureItem(player,"Shield"),"one-loadout accepts Shield after Slick consumed")
use()
check(kart:GetAttribute("KartShieldActive") and player:GetAttribute("RaceChargeShield")==0,"Shield use consumes and activates")
local shell=kart:FindFirstChild("RaceItemShield")
check(shell and shell.Parent==kart and not shell.CanCollide and shell.Massless and not shell.Anchored,"shield outside Visual, welded noncolliding")
check(shell:FindFirstChildOfClass("WeldConstraint").Part0==chassis,"shield attached to chassis")
check(fixtureItem(player,"Shield"),"test fixture supplies Shield for active-rejection scenario")
use()
check(player:GetAttribute("SelectedRaceItemId")=="Shield","duplicate active Shield use rejected without consumption")
step(0,0.4)
chassis.CFrame=CF.new(0,1.75,10); step(0)
check(not kart:GetAttribute("KartShieldActive") and not kart:FindFirstChild("RaceItemShield"),"first contact consumes shield and visual")
check(not kart:GetAttribute("KartSlickActive") and hazardCount()==0,"blocked Slick has no physics and is removed")
check(player:GetAttribute("RaceItemBlockedSerial")==1,"BLOCKED feedback event")
check(not kart:GetAttribute("RaceItemHitImmunity"),"blocking does not grant extra hit immunity")
accepted,reason=items.tryApplyOffensiveItem(player,player,"Slick")
check(accepted and reason=="hit" and kart:GetAttribute("KartSlickActive"),"next attack hits after shield consumed")

fresh("Shield"); use(); step(0,4.9)
check(kart:GetAttribute("KartShieldActive"),"Shield lives before 5 seconds")
step(0,0.11)
check(not kart:GetAttribute("KartShieldActive") and not kart:FindFirstChild("RaceItemShield"),"Shield timeout removes visual")
fresh("Slick"); use(); step(0,9.9)
check(hazardCount()==1,"hazard before lifetime")
step(0,0.11)
check(hazardCount()==0,"hazard expires at 10 seconds")
fresh()
for _=1,itemConfig.SLICK_MAX_HAZARDS do assert(fixtureItem(player,"Slick")); use() end
check(hazardCount()==itemConfig.SLICK_MAX_HAZARDS,"bounded hazard capacity")
assert(fixtureItem(player,"Slick")); use()
check(hazardCount()==itemConfig.SLICK_MAX_HAZARDS and player:GetAttribute("SelectedRaceItemId")=="Slick","hazard cap rejects without consuming")
fresh("Slick"); use(); step(0,0.8)
chassis.CFrame=CF.new(0,1.75,30); step(0)
chassis.CFrame=CF.new(0,1.75,-30); step(0)
check(kart:GetAttribute("KartSlickActive"),"swept contact catches high-speed crossing")

for _, boundary in {"FINISHED","DNF","GARAGE","COUNTDOWN","reset","occupant"} do
	fresh("Slick"); use()
	assert(fixtureItem(player,"Shield")); use()
	-- First hit blocks; second starts immunity and Slick. Then clear lifecycle.
	items.tryApplyOffensiveItem(player,player,"Slick")
	items.tryApplyOffensiveItem(player,player,"Slick")
	if boundary=="reset" then kart:SetAttribute("RaceResetSerial",(kart:GetAttribute("RaceResetSerial") or 0)+1)
	elseif boundary=="occupant" then seat.Occupant=nil
	else player:SetAttribute("RaceState",boundary) end
	check(not kart:GetAttribute("KartSlickActive") and not kart:GetAttribute("RaceItemHitImmunity") and hazardCount()==0
		and (player:GetAttribute("SelectedRaceItemId")=="" or boundary=="COUNTDOWN"),"full offensive lifecycle cleanup "..boundary)
	fresh("Shield"); use()
	if boundary=="reset" then kart:SetAttribute("RaceResetSerial",(kart:GetAttribute("RaceResetSerial") or 0)+1)
	elseif boundary=="occupant" then seat.Occupant=nil
	else player:SetAttribute("RaceState",boundary) end
	check(not kart:GetAttribute("KartShieldActive") and not kart:FindFirstChild("RaceItemShield"),"Shield lifecycle cleanup "..boundary)
end

-- Test continuous recovery over different approach angles and frame rates.
for _, fps in {30,60,120} do
	for _, angle in {0,math.pi/2,math.pi,-math.pi/2} do
		local effect=slickMotion.new(itemConfig)
		local frame=CF.Angles(0,angle,0)
		effect:start(player,0,frame.LookVector,V.new(0,0,-1),70)
		for i=1,math.ceil(0.7*fps) do
			local velocity,yaw=effect:sample(i/fps,frame.LookVector)
			assert(velocity.Y==0 and velocity.Magnitude<=70)
			frame=frame*CF.Angles(0,yaw/fps,0)
		end
		check(frame.LookVector:Dot(V.new(0,0,-1))>0.94,"continuous heading recovery "..fps.."/"..angle)
	end
end

-- Production selection/actions and base refill, independent of Studio flags.
fresh()
for index,id in {"Nitro","Slick","Shield"} do
	local key=({rb.Enum.KeyCode.One,rb.Enum.KeyCode.Two,rb.Enum.KeyCode.Three})[index]
	uis.InputBegan:Fire({KeyCode=key},false)
	check(player:GetAttribute("SelectedRaceItemId")==id,"keyboard selection "..index)
end
local selected=state.selected
remote.OnServerEvent:Fire(player,"Select","Smoke")
remote.OnServerEvent:Fire(player,"Select","Nitro","extra")
remote.OnServerEvent:Fire(player,"Grant","Nitro")
check(state.selected==selected and state.counts.Nitro==1,"invalid selection/grant rejected")
remote.OnServerEvent:Fire(player,"Select","Slick")
use()
check(state.counts.Slick==0 and state.counts.Nitro==1 and state.counts.Shield==1,"only Slick depleted")
remote.OnServerEvent:Fire(player,"Select","Slick")
check(state.selected=="Shield","empty selected item rejected")
remote.OnServerEvent:Fire(player,"Select","Nitro")
use()
check(kart:GetAttribute("KartNitroActive"),"chosen Nitro active")
remote.OnServerEvent:Fire(player,"Select","Shield")
use()
check(kart:GetAttribute("KartShieldActive") and kart:GetAttribute("KartNitroActive"),"Shield and Nitro coexist")
check(items.grantBonusNitro(player) and not items.grantBonusNitro(player),"server reward once per race")
player:SetAttribute("RaceState","COUNTDOWN")
check(state.counts.Nitro==1 and state.counts.Slick==1 and state.counts.Shield==1,"new countdown resets all counts")
remote.OnServerEvent:Fire(player,"Use")
check(state.counts.Nitro==1 and not kart:GetAttribute("KartNitroActive"),"countdown use blocked")
seat.Occupant=nil; seat.Occupant=human
check(state.counts.Nitro==1,"grid seating preserves prepared loadout")
check(not items.grantBonusNitro(player),"reward forbidden outside race")
player:SetAttribute("RaceState","RACING")
check(items.grantBonusNitro(player) and state.counts.Nitro==2,"new race renews bonus eligibility")
player:SetAttribute("RaceState","GARAGE")
check(state.counts.Nitro==0 and state.counts.Slick==0 and state.counts.Shield==0,"Garage clears all")
print("PASS: "..(count-nitroChecks).." Slick/Shield/loadout integration checks")
-- Existing production Drift/Mini Boost decisions, with controlled velocity
-- samples (not a physics simulation), must agree with replicated diagnostics.
config.DEBUG_TELEMETRY=true
local function driftFrame(requested,slip,dt,send,throttle,steering)
	dt=dt or 1/60; now+=dt
	chassis.AssemblyLinearVelocity=V.new(math.tan(math.rad(slip))*60,0,-60)
	if send~=false then control.OnServerEvent:Fire(player,throttle or 1,steering or .6,requested) end
	services.RunService.Heartbeat:Fire(dt)
end
local function charge(slip)
	startRace()
	for _=1,100 do driftFrame(true,slip) end
end
charge(15)
check(kart:GetAttribute("KartDriftChargeReady")==true,"production drift publishes READY")
driftFrame(false,15)
check(kart:GetAttribute("KartBoosting")==true and kart:GetAttribute("KartDriftDiagBoostEligible")==true
	and kart:GetAttribute("KartDriftDiagEndReason")=="shift_release"
	and player:GetAttribute("DriftBonusProgress")==1,"READY Drift-button-first release starts one Boost and increments progress")
check(kart:GetAttribute("KartDriftChargeProgress")==0 and kart:GetAttribute("KartDriftChargeReady")==false,"boost clears gauge")
for _=1,110 do step(1) end
check(kart:GetAttribute("KartBoosting") and -chassis.AssemblyLinearVelocity.Z>99,
	"Beta 2 Mini Boost reaches 100 and lasts beyond 1.5 seconds")
for _=1,15 do step(1) end
check(not kart:GetAttribute("KartBoosting"),"Beta 2 Mini Boost expires after 2 seconds")
startRace()
for _=1,100 do driftFrame(true,15) end
driftFrame(false,15)
kart:SetAttribute("KartOffTrack",true)
local offTrackBoostSpeed=step(1)
check(not kart:GetAttribute("KartBoosting") and offTrackBoostSpeed<=50,
	"Beta 2 Mini Boost cancels and caps at 50 off-track")
charge(8)
check(kart:GetAttribute("KartDriftDiagDuration")==1 and kart:GetAttribute("KartDriftDiagQualified")==0,"insufficient slip distinguishes two charge axes")
driftFrame(false,8)
check(kart:GetAttribute("KartDriftDiagEndReason")=="shift_release" and not kart:GetAttribute("KartDriftDiagBoostEligible"),"unqualified release result")
charge(15)
driftFrame(false,15,1/60,true,0)
check(kart:GetAttribute("KartDriftDiagEndReason")=="shift_release" and not kart:GetAttribute("KartDriftDiagBoostEligible") and kart:GetAttribute("KartDriftDiagThrottle")==0,"READY can fail release throttle check")
charge(15)
check(kart:GetAttribute("KartDriftChargeReady"),"steering-first fixture reaches READY")
local steeringBoosts=0
local steeringObserver=world.onDriftOutcome(function(who,outcome)
	if who==player and outcome=="BOOST" then steeringBoosts+=1 end
end)
for _=1,9 do driftFrame(true,15,1/60,true,1,0) end
check(kart:GetAttribute("KartDriftDiagEndReason")=="steer_below_exit"
	and kart:GetAttribute("KartDriftDiagBoostEligible") and kart:GetAttribute("KartBoosting")
	and player:GetAttribute("DriftBonusProgress")==1,"READY steering-first exit starts Mini Boost and increments progress")
driftFrame(false,15,1/60,true,1,0)
check(steeringBoosts==1 and player:GetAttribute("DriftBonusProgress")==1,
	"later Drift-button release cannot duplicate steering-first Boost")
steeringObserver:Disconnect()
for _=1,130 do driftFrame(false,15) end
for _=1,10 do driftFrame(true,15) end
for _=1,9 do driftFrame(true,15,1/60,true,1,0) end
check(kart:GetAttribute("KartDriftDiagEndReason")=="steer_below_exit"
	and not kart:GetAttribute("KartDriftDiagBoostEligible") and not kart:GetAttribute("KartBoosting")
	and player:GetAttribute("DriftBonusProgress")==1,"non-READY steering release fails without losing progress")
charge(15)
kart:SetAttribute("KartOffTrack",true)
driftFrame(false,15)
check(not kart:GetAttribute("KartBoosting") and player:GetAttribute("DriftBonusProgress")==0,
	"READY off-track termination cannot start Boost")
driftFrame(true,15)
check(not kart:GetAttribute("KartDrifting") and not kart:GetAttribute("KartDriftChargeReady"),
	"off-track state cannot start another Drift charge")
charge(15)
driftFrame(true,15,.63,false)
check(kart:GetAttribute("KartDriftDiagEndReason")=="input_timeout" and kart:GetAttribute("KartDriftDiagMaxInputAge")>=.63-1e-8,"timeout captures final input gap")
check(kart:GetAttribute("KartDriftDiagMaxServerDelta")==.63,"hitch captured without changing cap")
charge(15)
check(world.applySlickHit(player),"slick diagnostic fixture accepted")
check(kart:GetAttribute("KartDriftDiagEndReason")=="slick" and not kart:GetAttribute("KartDriftChargeReady"),"slick cancels gauge")
startRace()
local function successfulDrift()
	for _=1,100 do driftFrame(false,15) end
	for _=1,100 do driftFrame(true,15) end
	driftFrame(false,15)
end
local function successfulSteerFirstDrift()
	for _=1,100 do driftFrame(false,15) end
	for _=1,100 do driftFrame(true,15) end
	for _=1,9 do driftFrame(true,15,1/60,true,1,0) end
	driftFrame(false,15,1/60,true,1,0)
end
successfulDrift()
check(player:GetAttribute("DriftBonusProgress")==1 and not player:GetAttribute("DriftBonusNitroAwarded"),
	"first real Mini Boost earns 1/5 progress")
for _=1,100 do driftFrame(false,15) end
check(player:GetAttribute("DriftBonusProgress")==1,"straight driving preserves progress")
remote.OnServerEvent:Fire(player,"Select","Shield");use()
check(player:GetAttribute("RaceChargeShield")==0 and player:GetAttribute("DriftBonusProgress")==1,
	"Shield use preserves progress")
for _=1,10 do driftFrame(false,15) end
remote.OnServerEvent:Fire(player,"Select","Slick");use()
check(player:GetAttribute("RaceChargeSlick")==0 and player:GetAttribute("DriftBonusProgress")==1,
	"Slick deploy preserves progress")
for _=1,100 do driftFrame(true,8) end
driftFrame(false,8)
check(player:GetAttribute("DriftBonusProgress")==1,"failed Drift preserves first success")
for expected=2,3 do
	successfulDrift()
	check(player:GetAttribute("DriftBonusProgress")==expected,"cumulative Boost success "..expected)
end
kart:SetAttribute("KartOffTrack",true)
check(player:GetAttribute("DriftBonusProgress")==3,"off-track preserves 3/5 progress")
kart:SetAttribute("KartOffTrack",false)
local finalBoosts=0
local finalObserver=world.onDriftOutcome(function(who,outcome)
	if who==player and outcome=="BOOST" then finalBoosts+=1 end
end)
successfulSteerFirstDrift()
finalObserver:Disconnect()
check(player:GetAttribute("DriftBonusProgress")==4 and not player:GetAttribute("DriftBonusNitroAwarded")
	and player:GetAttribute("RaceChargeNitro")==1 and finalBoosts==1,
	"steering-first fourth Boost advances to 4/5 without early Nitro")
for _=1,100 do driftFrame(true,8) end
driftFrame(false,8)
check(player:GetAttribute("DriftBonusProgress")==4,"failed fifth Drift preserves 4/5")
check(world.applySlickHit(player) and player:GetAttribute("DriftBonusProgress")==4,
	"Slick victim preserves 4/5 progress")
successfulDrift()
check(player:GetAttribute("DriftBonusProgress")==5 and player:GetAttribute("DriftBonusNitroAwarded")
	and player:GetAttribute("RaceChargeNitro")==2,"fifth Boost grants Nitro 1 to 2 and holds 5/5")
for _=1,5 do successfulDrift() end
check(player:GetAttribute("DriftBonusProgress")==5 and player:GetAttribute("RaceChargeNitro")==2,
	"five further Boosts cannot start a second reward cycle")
kart:SetAttribute("RaceResetSerial",(kart:GetAttribute("RaceResetSerial") or 0)+1)
check(player:GetAttribute("DriftBonusProgress")==5 and player:GetAttribute("DriftBonusNitroAwarded"),
	"fall reset cannot reopen an earned race reward")
successfulDrift()
check(player:GetAttribute("DriftBonusProgress")==5 and player:GetAttribute("RaceChargeNitro")==0,
	"post-reset Boost does not issue a second Nitro")
startRace()
check(player:GetAttribute("DriftBonusProgress")==0 and not player:GetAttribute("DriftBonusNitroAwarded")
	and player:GetAttribute("RaceChargeNitro")==1,"new Countdown resets progress and base loadout")
successfulDrift()
remote.OnServerEvent:Fire(player,"Select","Nitro");use()
check(player:GetAttribute("RaceChargeNitro")==0 and player:GetAttribute("DriftBonusProgress")==1,
	"Nitro use preserves first success")
for _=1,4 do successfulDrift() end
check(player:GetAttribute("RaceChargeNitro")==1 and player:GetAttribute("DriftBonusNitroAwarded")
	and player:GetAttribute("DriftBonusProgress")==5,"fifth Boost replenishes one spent Nitro")
startRace()
successfulDrift()
kart:SetAttribute("KartOffTrack",true)
check(player:GetAttribute("DriftBonusProgress")==1,"off-track preserves progress")
kart:SetAttribute("KartOffTrack",false)
successfulDrift()
check(world.applySlickHit(player) and player:GetAttribute("DriftBonusProgress")==2,
	"Slick hit preserves progress")
startRace()
successfulDrift()
kart:SetAttribute("RaceResetSerial",(kart:GetAttribute("RaceResetSerial") or 0)+1)
check(player:GetAttribute("DriftBonusProgress")==1,"fall/reset serial preserves progress during race")
player:SetAttribute("RaceState","GARAGE");kart:SetAttribute("RaceControlsLocked",true);step(0)
check(not kart:GetAttribute("KartDriftChargeReady") and not player:GetAttribute("DriftBonusNitroAwarded")
	and player:GetAttribute("DriftBonusProgress")==0,"Garage clears gauge and bonus progress")
startRace()
chassis.AssemblyLinearVelocity=V.new(0,0,-70)
kart:SetAttribute("KartFinishRollDirection",V.new(0,0,-1))
kart:SetAttribute("KartFinishRollActive",true)
kart:SetAttribute("RaceControlsLocked",true)
check(not kart:GetAttribute("KartNitroActive") and not kart:GetAttribute("KartBoosting")
	and not kart:GetAttribute("KartDrifting") and not kart:GetAttribute("KartSlickActive"),"finish roll clears race effects")
local rollSpeed=step(1,0.2)
check(rollSpeed>0 and rollSpeed<70 and chassis.AssemblyAngularVelocity==V.zero,"locked finish roll moves forward without yaw")
local slowerSpeed=step(1,1)
check(slowerSpeed>0 and slowerSpeed<rollSpeed,"finish roll decelerates despite throttle input")
check(step(1,raceConfig.FINISH_ROLL_SECONDS-1.2)==0,"finish roll reaches zero at configured duration")
kart:SetAttribute("KartFinishRollActive",false)
check(step(1,0)==0,"locked kart remains stopped after finish roll")
config.DEBUG_TELEMETRY=false

-- Two real production contexts and item controllers must keep ownership isolated.
local second=child(services.Players,"Player","SecondDriver"); second.UserId=2
second.Character=object("Model","SecondCharacter")
local secondHuman=child(second.Character,"Humanoid","Humanoid"); secondHuman.Health=100
local secondGrid=CF.new(20,1.75,0)
local secondContext=world.acquireKartContext(second,secondGrid)
local firstContext=world.getKartContext(player)
check(firstContext~=secondContext and world.getKartContext(second)==secondContext,"distinct registered kart contexts")
check(kart:GetAttribute("KartOwnerUserId")==player.UserId
	and secondContext.kart:GetAttribute("KartOwnerUserId")==second.UserId,"both kart ownership IDs are server-assigned")
check(secondContext.kart~=firstContext.kart and secondContext.spawnCFrame==secondGrid
	and secondContext.kart:GetAttribute("RaceStartCFrame")==secondGrid,"second racer has own kart and grid reset point")
check(world.acquireKartContext(second,secondGrid)==secondContext,"acquire reuses owned context")
services.Players.PlayerAdded:Fire(second)
local session=sessionType.new("Track01Race","RACE",2)
session:add(player,{})
session:add(second,{})
startRace()
second:SetAttribute("RaceState","COUNTDOWN")
secondContext.seat.Occupant=secondHuman; secondHuman.SeatPart=secondContext.seat
second:SetAttribute("RaceState","RACING")
secondContext.kart:SetAttribute("RaceControlsLocked",false)
control.OnServerEvent:Fire(second,1,0.7,true)
check(secondContext.control and secondContext.control.steering==0.7 and firstContext.control.steering==0,
	"throttle and steering stay on their owner context")
secondContext:receiveControl(player,-1,-1,false)
check(secondContext.control.steering==0.7,"foreign caller cannot control another kart")
check(world.getRaceKart(player)==kart and world.getRaceKart(second)==secondContext.kart,
	"player resolves to own seated race kart")
remote.OnServerEvent:Fire(second,"Select","Shield")
remote.OnServerEvent:Fire(second,"Use")
check(secondContext.kart:GetAttribute("KartShieldActive"),"second player shield active")
check(not kart:GetAttribute("KartShieldActive"),"second player Shield does not set first kart Shield")
second:SetAttribute("RaceSessionId",7)
remote.OnServerEvent:Fire(second,"Select","Slick")
now+=0.2; remote.OnServerEvent:Fire(second,"Use")
local secondHazardCount=hazardCount()
check(secondHazardCount>0,"second player owns Slick hazard")
local secondHazard=services.Workspace.Prototype.RaceItemHazards:GetChildren()[1]
check(secondHazard:GetAttribute("SlickOwnerUserId")==second.UserId
	and secondHazard:GetAttribute("RaceSessionId")==second:GetAttribute("RaceSessionId"),
	"Slick hazard keeps server-assigned owner and race-session identity")
local extraRacers={}
for id=3,4 do
	local racer=child(services.Players,"Player","Racer"..id);racer.UserId=id
	racer.Character=object("Model","RacerCharacter"..id)
	local humanoid=child(racer.Character,"Humanoid","Humanoid");humanoid.Health=100
	local context=world.acquireKartContext(racer,CF.new(id*10,1.75,0))
	services.Players.PlayerAdded:Fire(racer)
	session:add(racer,{})
	racer:SetAttribute("RaceState","COUNTDOWN")
	context.seat.Occupant=humanoid;humanoid.SeatPart=context.seat
	racer:SetAttribute("RaceState","RACING")
	context.kart:SetAttribute("RaceControlsLocked",false)
	extraRacers[id]={player=racer,context=context}
end
local thirdRacer=extraRacers[3].player
local fourthRacer=extraRacers[4].player
remote.OnServerEvent:Fire(fourthRacer,"Select","Shield")
remote.OnServerEvent:Fire(fourthRacer,"Use")
check(extraRacers[4].context.kart:GetAttribute("KartShieldActive")
	and not extraRacers[3].context.kart:GetAttribute("KartShieldActive")
	and secondContext.kart:GetAttribute("KartShieldActive"),
	"fourth racer Shield does not alter other racers' Shield")
local firstNitro=player:GetAttribute("RaceChargeNitro")
local secondNitro=second:GetAttribute("RaceChargeNitro")
local fourthNitro=fourthRacer:GetAttribute("RaceChargeNitro")
remote.OnServerEvent:Fire(thirdRacer,"Select","Nitro")
control.OnServerEvent:Fire(thirdRacer,1,0,false)
remote.OnServerEvent:Fire(thirdRacer,"Use")
check(thirdRacer:GetAttribute("RaceChargeNitro")==0
	and player:GetAttribute("RaceChargeNitro")==firstNitro
	and second:GetAttribute("RaceChargeNitro")==secondNitro
	and fourthRacer:GetAttribute("RaceChargeNitro")==fourthNitro,
	"third racer Nitro use changes only its own charge")
check(items.grantBonusNitro(fourthRacer)
	and fourthRacer:GetAttribute("RaceChargeNitro")==fourthNitro+1
	and thirdRacer:GetAttribute("RaceChargeNitro")==0
	and player:GetAttribute("RaceChargeNitro")==firstNitro
	and second:GetAttribute("RaceChargeNitro")==secondNitro,
	"fourth racer Bonus Nitro remains independent and once per round")
check(not items.grantBonusNitro(fourthRacer),"fourth racer cannot claim Bonus Nitro twice")
for id=3,4 do
	local racer=extraRacers[id].player
	session:remove(racer)
	services.Players.PlayerRemoving:Fire(racer)
	world.releaseKartContext(racer)
end
check(hazardCount()==secondHazardCount and secondContext.kart:GetAttribute("KartShieldActive"),
	"extra racer cleanup preserves second racer's Slick and Shield")
player:SetAttribute("RaceState","COUNTDOWN")
check(second:GetAttribute("RaceChargeNitro")==1 and secondContext.kart:GetAttribute("KartShieldActive")
	and hazardCount()==secondHazardCount,"first COUNTDOWN preserves second resources")
player:SetAttribute("RaceState","RACING")
player:SetAttribute("RaceState","FINISHED")
check(second:GetAttribute("RaceChargeNitro")==1 and secondContext.kart:GetAttribute("KartShieldActive")
	and hazardCount()==secondHazardCount,"first FINISH preserves second resources")
player.CharacterRemoving:Fire()
check(secondContext.kart:GetAttribute("KartShieldActive") and hazardCount()==secondHazardCount,
	"first CharacterRemoving preserves second resources")
local otherSession=sessionType.new("Other","RACE",3)
otherSession:add(second,{})
local accepted,reason=items.tryApplyOffensiveItem(second,player,"Slick")
check(not accepted and reason=="cross_session","cross-session offensive target rejected")
otherSession:remove(second); session:add(second,{})
check(sessionType.forPlayer(second)==session,"session membership restored")
local blocked,blockReason=items.tryApplyOffensiveItem(second,player,"Slick")
check(blocked and blockReason=="blocked" and not secondContext.kart:GetAttribute("KartShieldActive"),
	"second player Shield absorbs only its own attack")
local hit,hitReason=items.tryApplyOffensiveItem(second,player,"Slick")
check(hit and hitReason=="hit" and secondContext.kart:GetAttribute("RaceItemHitImmunity"),
	"second player receives independent hit immunity")
services.Players.PlayerRemoving:Fire(player)
check(second:GetAttribute("RaceChargeNitro")==1 and secondContext.kart:GetAttribute("RaceItemHitImmunity")
	and hazardCount()==secondHazardCount,"first PlayerRemoving preserves second resources")
check(world.getKartContext(player)==nil and kart.Parent==nil and kart:GetAttribute("KartOwnerUserId")==0,
	"default kart loses ownership and is destroyed after player leaves")
local third=child(services.Players,"Player","ThirdDriver");third.UserId=3
local replacement=world.acquireKartContext(third,CF.new(30,1.75,0))
check(replacement and replacement.kart.Parent and replacement.kart~=kart
	and replacement.kart:GetAttribute("KartOwnerUserId")==third.UserId,
	"next acquisition recreates an owned default kart")
world.releaseKartContext(third)
check(replacement.kart.Parent==nil,"recreated default kart also disappears on release")
check(not items.grantBonusNitro(player),"removed player has no loadout")
second:SetAttribute("RaceState","FINISHED")
local ignored,ignoredReason=items.tryApplyOffensiveItem(second,player,"Slick")
check(not ignored and ignoredReason=="invalid_target","finished racer cannot be hit by Slick")
world.releaseKartContext(second)
check(world.getKartContext(second)==nil and not secondContext.kart.Parent,"dynamic kart released on Garage")
kart:Destroy()
check(not world.activateNitro(player),"destroyed kart disables activation bridge")
print("PASS: "..count.." RaceItem/Nitro checks (production controllers under deterministic mocks)")

-- Real preview lifecycle with deterministic rendering clock, without a live world.
local previewChecks = 0
local function previewCheck(value, label)
	assert(value, label); previewChecks += 1
end
services.RunService.RenderStepped = signal()
local previewEnv = table.clone(environment)
previewEnv.Vector2, previewEnv.UDim2 = rb.Vector2, rb.UDim2
previewEnv.workspace = object("Workspace")
local previewType = luau.load(fs.readFile("src/client/SlickRearPreview.luau"), {
	debugName="SlickRearPreview", environment=previewEnv,
})()
local gui = object("ScreenGui")
local completed = 0
local preview = previewType.new(gui, function() completed += 1 end)
local panel = gui:FindFirstChild("SlickRearPreview")
local viewport = panel:FindFirstChildOfClass("ViewportFrame")
preview:layout(true, rb.UDim2.fromOffset(16, 100))
preview:show(nil, nil)
previewCheck(not preview:isVisible() and #viewport:GetChildren()==1, "invalid deploy creates no scene")
preview:show(CF.identity, V.new(0, 5, -7))
previewCheck(preview:isVisible() and #viewport:GetChildren()==2, "accepted deployment creates one temporary scene")
now += 0.89; services.RunService.RenderStepped:Fire()
previewCheck(preview:isVisible() and completed==0, "preview remains before 0.9 seconds")
now += 0.02; services.RunService.RenderStepped:Fire()
previewCheck(not preview:isVisible() and #viewport:GetChildren()==1 and completed==1, "timeout destroys scene and restores HUD")
services.RunService.RenderStepped:Fire()
previewCheck(completed==1, "timeout disconnects render callback")
preview:show(CF.identity, V.new(0, 5, -7))
preview:show(CF.identity, V.new(0, 5, -7))
previewCheck(#viewport:GetChildren()==2, "repeat preview replaces rather than duplicates scene")
preview:stop()
previewCheck(not preview:isVisible() and #viewport:GetChildren()==1, "race exit stop removes scene")
preview:show(CF.identity, V.new(0, 5, -7))
gui:Destroy()
previewCheck(not preview:isVisible() and #viewport:GetChildren()==1, "GUI destruction removes scene")
print("PASS: "..previewChecks.." rear preview lifecycle checks")
