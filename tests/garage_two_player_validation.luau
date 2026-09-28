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

environment.task={spawn=function() end,delay=function() end}
function methods:Sit(humanoid) self.Occupant=humanoid;humanoid.SeatPart=self end
load("src/shared/RaceConfig.luau",shared,"RaceConfig")
local catalog=load("src/shared/TrackCatalog.luau",shared,"TrackCatalog")
load("src/shared/RaceMode.luau",shared,"RaceMode")
local sessionType=load("src/server/RaceSession.luau",server,"RaceSession")
local function sharedStub(name,value)
 child(shared,"ModuleScript",name);modules[name]=value
end
sharedStub("DriverCatalog",{DefaultId="Driver01",Entries={Driver01={DisplayName="A"},Driver02={DisplayName="B"}}})
sharedStub("KartCatalog",{DefaultId="Kart01",Entries={Kart01={Color="Red"},Kart02={Color="Blue"}}})
sharedStub("DriverAppearance",{applyToCharacter=function(character,driver) character:SetAttribute("Driver",driver.DisplayName) end})
sharedStub("KartVisualFactory",{applyColors=function(visual,kartSelection) visual:SetAttribute("Color",kartSelection.Color) end})
local prototype=child(services.Workspace,"Folder","Prototype")
local ground=child(prototype,"Part","Ground");ground.CFrame=CF.new(0,-0.5,0);ground.Size=V.new(2048,1,2048)
child(prototype,"SpawnLocation","PlayerSpawn")
local track=child(prototype,"Model","TestTrack")
track:SetAttribute("TrackId","Track01")
local builds=0
child(server,"ModuleScript","TrackBuilder")
modules.TrackBuilder={build=function(_,selection)
 if track:GetAttribute("TrackId")~=selection.Id then builds+=1;track:SetAttribute("TrackId",selection.Id) end
 return track
end}
local contexts={}
local function makeKart(name)
 local kart=child(prototype,"Model",name)
 local chassis=child(kart,"Part","Chassis");kart.PrimaryPart=chassis
 local seat=child(kart,"Seat","Seat")
 local visual=child(kart,"Model","Visual")
 return {kart=kart,chassis=chassis,seat=seat,visual=visual,
  setSpawnCFrame=function(self,frame) self.spawnCFrame=frame;self.kart:SetAttribute("RaceStartCFrame",frame) end}
end
local defaultContext=makeKart("Kart")
local created=0
child(server,"ModuleScript","PrototypeWorld")
modules.PrototypeWorld={acquireKartContext=function(player,frame)
 if contexts[player] then return contexts[player] end
 local context=if not defaultContext.owner then defaultContext else makeKart("Kart_"..player.UserId)
 if context~=defaultContext then created+=1 end
 context.owner=player;contexts[player]=context;context:setSpawnCFrame(frame)
 return context
end}
local function makePlayer(name,id)
 local player=child(services.Players,"Player",name);player.UserId=id
 player.CharacterAdded=signal()
 player.Character=object("Model",name.."Character")
 local root=child(player.Character,"Part","HumanoidRootPart");player.Character.PrimaryPart=root
 local humanoid=child(player.Character,"Humanoid","Humanoid");humanoid.Health=100
 player:SetAttribute("RaceState","GARAGE")
 return player
end
local a,b,c=makePlayer("A",1),makePlayer("B",2),makePlayer("C",3)
local garage=load("src/server/GarageController.luau",server,"GarageController")
garage.start()
local remote=services.ReplicatedStorage.GarageControl
local function ready(player,kartId,trackId)
 remote.OnServerEvent:Fire(player,"Ready","Driver01",kartId,trackId)
end
ready(a,"Kart01","Track01Race")
check(contexts[a]==defaultContext and a:GetAttribute("GridSlot")==1,"first ready owns default kart in slot one")
check(a:GetAttribute("RaceState")=="PRE_RACE" and defaultContext.seat.Occupant~=nil,"first driver seated")
check(defaultContext.spawnCFrame==CF.new(0,1.75,0)*catalog.Entries.Track01Race.GridSlots[1],"first reset point is slot one")
check(defaultContext.visual:GetAttribute("Color")=="Red","first kart color applied")
local session=sessionType.new("Track01Race","RACE",2)
session.phase="WAITING";session:add(a,{})
ready(c,"Kart01","Track02")
check(c:GetAttribute("RaceEntryError")=="Race in progress" and contexts[c]==nil,"other track cannot rebuild waiting race")
ready(b,"Kart02","Track01Race")
check(contexts[b] and contexts[b]~=contexts[a] and contexts[b].kart~=contexts[a].kart,"second ready creates distinct kart")
check(a:GetAttribute("GridSlot")==1 and b:GetAttribute("GridSlot")==2 and created==1,"only two grid slots allocated")
check(contexts[b].spawnCFrame==CF.new(0,1.75,0)*catalog.Entries.Track01Race.GridSlots[2],"second reset point is slot two")
check(contexts[b].visual:GetAttribute("Color")=="Blue" and defaultContext.visual:GetAttribute("Color")=="Red","kart colors isolated")
check(a.Character:GetAttribute("Driver")=="A" and b.Character:GetAttribute("Driver")=="A","driver appearance applied separately")
check(builds==1 and track:GetAttribute("TrackId")=="Track01Race","joining racer keeps shared track")
session:add(b,{})
session.phase="COUNTDOWN"
ready(c,"Kart01","Track01Race")
check(c:GetAttribute("RaceEntryError")=="Race full" and contexts[c]==nil,"third racer refused")
print("PASS: "..count.." Garage two-player allocation checks")
