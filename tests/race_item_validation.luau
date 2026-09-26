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
check(config.MAX_FORWARD_SPEED==70 and config.MINI_BOOST_MAX_SPEED==82 and config.MINI_BOOST_DURATION==1,"baseline speeds unchanged")
local slotType=load("src/server/RaceItemSlot.luau",server,"RaceItemSlot")
local slot=slotType.new()
check(slot:grant("Nitro"),"grant")
check(not slot:grant("Nitro") and not slot:grant("Slick"),"single slot and unimplemented items")
check(not slot:use("Use",1,function() error("must not activate") end) and slot.id=="Nitro","payload injection rejected")
check(not slot:use("Use",0,function() return false,"locked" end) and slot.id=="Nitro","rejected retains slot")
check(slot:use("Use",0,function() return true end) and slot.id=="","accepted consumes")
local Nitro=load("src/server/NitroState.luau",server,"NitroState")
local overlap=Nitro.new(config)
overlap:activate("driver",0)
check(overlap:forwardSpeed(82,true,1,1/60)>82 and overlap:forwardSpeed(82,true,1,1/60)<100,"Mini Boost to Nitro ramp")
check(overlap:forwardSpeed(100,true,1,1/60)==100,"no additive stacking")
overlap:update(3,"driver",true,false,false,true)
check(overlap:forwardSpeed(100,true,1,1/60)==99.75,"expired Nitro decays toward active Mini Boost")
check(overlap:forwardSpeed(82,true,1,1/60)==82,"live Mini Boost floor")

-- Minimal world dependencies; actual movement/controller modules run below.
for name, result in {
	KartCatalog={DefaultId="Kart01",Entries={Kart01={}}},
	TrackCatalog={DefaultId="Track01",Entries={Track01={GridSlots={CF.identity}}}},
	KartVisualFactory={createVisual=function() return object("Model","Visual") end},
} do child(shared,"ModuleScript",name); modules[name]=result end
child(server,"ModuleScript","TrackBuilder")
modules.TrackBuilder={build=function(prototype)
	local track=child(prototype,"Model","TestTrack")
	child(track,"Folder","BarrierTriggers")
end}
local player=child(services.Players,"Player","TestDriver")
player.Character=object("Model","Character")
local human=child(player.Character,"Humanoid","Humanoid"); human.Health=100
local world=load("src/server/PrototypeWorld.luau",server,"PrototypeWorld")
check(not world.activateNitro(player),"pre-start rejection")
world.start()
local items=load("src/server/RaceItemController.luau",server,"RaceItemController")
items.start()
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
check(player:GetAttribute("RaceItemId")=="Nitro","Studio RACING grants Nitro")
remote.OnServerEvent:Fire(player,"Use","Nitro")
check(not kart:GetAttribute("KartNitroActive") and player:GetAttribute("RaceItemReady"),"remote rejects extra payload")
kart:SetAttribute("RaceControlsLocked",true)
remote.OnServerEvent:Fire(player,"Use")
check(player:GetAttribute("RaceItemReady"),"locked remote keeps item")
kart:SetAttribute("RaceControlsLocked",false)
for _=1,150 do step(1) end
check(math.abs(-chassis.AssemblyLinearVelocity.Z-70)<0.001,"normal speed 70")
remote.OnServerEvent:Fire(player,"Use")
check(kart:GetAttribute("KartNitroActive") and not player:GetAttribute("RaceItemReady"),"authoritative activation and consumption")
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
	check(not kart:GetAttribute("KartNitroActive") and player:GetAttribute("RaceItemId")=="","clear "..state)
end
startRace()
check(player:GetAttribute("RaceItemReady"),"rematch receives fresh debug grant")
player:SetAttribute("RaceState","COUNTDOWN")
check(not player:GetAttribute("RaceItemReady"),"rematch countdown empty")
services.RunService.studio=false
player:SetAttribute("RaceState","RACING")
check(not player:GetAttribute("RaceItemReady"),"published server never auto-grants")
services.RunService.studio=true
startRace(); remote.OnServerEvent:Fire(player,"Use")
kart:SetAttribute("RaceResetSerial",1)
check(not kart:GetAttribute("KartNitroActive") and not player:GetAttribute("RaceItemReady"),"reset clears both")
startRace(); remote.OnServerEvent:Fire(player,"Use")
seat.Occupant=nil
check(not kart:GetAttribute("KartNitroActive"),"unseat cancels")
startRace(); remote.OnServerEvent:Fire(player,"Use")
player.CharacterRemoving:Fire()
check(not kart:GetAttribute("KartNitroActive") and not player:GetAttribute("RaceItemReady"),"character removal cleanup")
startRace(); remote.OnServerEvent:Fire(player,"Use")
now+=config.INPUT_TIMEOUT+0.1; services.RunService.Heartbeat:Fire(1/60)
check(not kart:GetAttribute("KartNitroActive"),"input timeout cancels")
startRace(); remote.OnServerEvent:Fire(player,"Use")
chassis.CFrame=CF.new(0,-50,0); step(1)
check(not kart:GetAttribute("KartNitroActive") and not player:GetAttribute("RaceItemReady"),"fall reset cleanup")
startRace(); remote.OnServerEvent:Fire(player,"Use")
for _=1,90 do step(1) end
local trigger=child(services.Workspace.Prototype.TestTrack.BarrierTriggers,"Part","TestBarrier")
trigger.Size=V.new(20,20,20)
trigger:SetAttribute("BarrierInwardNormal",V.new(0,0,1))
trigger:SetAttribute("BarrierForwardTangent",V.new(0,0,-1))
-- Refresh cached track once to register the newly supplied trigger fixture.
services.Workspace.Prototype.TestTrack.Name="HiddenTrack"; step(1)
services.Workspace.Prototype.HiddenTrack.Name="TestTrack"; step(1)
check(kart:GetAttribute("KartCrashActive") and not kart:GetAttribute("KartNitroActive"),"real barrier path cancels Nitro")
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
config.DEBUG_RACE_ITEMS=false
player:SetAttribute("RaceState","COUNTDOWN"); player:SetAttribute("RaceState","RACING")
check(not player:GetAttribute("RaceItemReady"),"debug flag disables automatic grant")
check(items.grantRaceItem(player,"Nitro"),"server-only grant remains available")
services.Players.PlayerRemoving:Fire(player)
check(not items.grantRaceItem(player,"Nitro"),"removed player has no slot")
kart:Destroy()
check(not world.activateNitro(player),"destroyed kart disables activation bridge")
print("PASS: "..count.." RaceItem/Nitro checks (production controllers under deterministic mocks)")
