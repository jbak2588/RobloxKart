-- Production Smoke/controller/selection integration under deterministic server mocks.
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local V, CF = rb.Vector3, rb.CFrame
local checks = 0
local function check(value, label) assert(value, label); checks += 1 end
local function signal()
	local callbacks = {}
	return { Connect = function(_, f)
		local c = { active = true }; function c:Disconnect() self.active = false end
		table.insert(callbacks, {c, f}); return c
	end, Fire = function(_, ...)
		for _, pair in table.clone(callbacks) do if pair[1].active then pair[2](...) end end
	end }
end
local methods = {}
local function object(class, name)
	local p = {ClassName = class, Name = name or class, CFrame = CF.identity, Size = V.one,
		PlayerAdded=signal(), PlayerRemoving=signal(), CharacterRemoving=signal(),
		Heartbeat=signal(), OnServerEvent=signal(), Destroying=signal()}
	return setmetatable({_p=p, children={}, attrs={}, signals={}, properties={}}, {
		__index = function(self, k)
			if methods[k] then return methods[k] end
			if k == "Position" then return p.CFrame.Position end
			if p[k] ~= nil then return p[k] end
			return self:FindFirstChild(k)
		end,
		__newindex = function(self, k, v)
			local old = p[k]
			if k == "Parent" then
				if old then local i=table.find(old.children,self); if i then table.remove(old.children,i) end end
				if v then table.insert(v.children,self) end
			end
			p[k]=v
			if old~=v and self.properties[k] then self.properties[k]:Fire() end
		end,
	})
end
function methods:FindFirstChild(name) for _, c in self.children do if c.Name==name then return c end end end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
function methods:GetChildren() return table.clone(self.children) end
function methods:IsA(class) return self.ClassName == class or (class=="BasePart" and self.ClassName=="Part") end
function methods:Destroy() self.Destroying:Fire(); self.Parent=nil end
function methods:PivotTo(frame) self.PrimaryPart.CFrame=frame end
function methods:GetAttribute(k) return self.attrs[k] end
function methods:SetAttribute(k,v) local old=self.attrs[k]; self.attrs[k]=v; if old~=v and self.signals[k] then self.signals[k]:Fire() end end
function methods:GetAttributeChangedSignal(k) if not self.signals[k] then self.signals[k]=signal() end; return self.signals[k] end
function methods:GetPropertyChangedSignal(k) if not self.properties[k] then self.properties[k]=signal() end; return self.properties[k] end
local function child(parent,class,name) local o=object(class,name); o.Parent=parent; return o end
local services={}
for _, name in {"Players","ReplicatedStorage","RunService","Workspace"} do services[name]=object(name) end
local shared=child(services.ReplicatedStorage,"Folder","Shared")
local server=object("Folder","Server")
local prototype=child(services.Workspace,"Folder","Prototype")
local now=0
local modules={}
local env={Vector3=V,CFrame=CF,Color3=rb.Color3,ColorSequence=rb.ColorSequence,NumberSequence=rb.NumberSequence,Enum=rb.Enum,Instance={new=object},
	time=function() return now end,game={GetService=function(_,name) return assert(services[name],name) end}}
local function load(path,parent,name)
	local script=child(parent,"ModuleScript",name)
	local e=table.clone(env);e.script=script;e.require=function(m) return assert(modules[m.Name],m.Name) end
	local result=if path == "src/shared/KartConfig.luau" or path == "src/shared/RaceItemConfig.luau" then require("./helpers/gameplay_config")(path) else luau.load(fs.readFile(path),{environment=e,debugName=path})();modules[name]=result;return result
end

-- Fixture below executes the real server controller, geometry, visuals and Smoke service.
function methods:FireClient(_,action,accepted,message) self.reply={action,accepted,message} end
function methods:FindFirstChildOfClass(class) for _,c in self.children do if c.ClassName==class then return c end end end
local config=load("src/shared/RaceItemConfig.luau",shared,"RaceItemConfig")
load("src/shared/KartConfig.luau",shared,"KartConfig")
load("src/shared/RaceItemCatalog.luau",shared,"RaceItemCatalog")
local Slots=load("src/shared/RaceItemSlots.luau",shared,"RaceItemSlots")
local Loadout=load("src/server/RaceLoadout.luau",server,"RaceLoadout")
local Geometry=load("src/server/RaceItemGeometry.luau",server,"RaceItemGeometry")
load("src/shared/KDMItemVFXConfig.luau",shared,"KDMItemVFXConfig")
local Visuals=load("src/server/RaceItemVisuals.luau",server,"RaceItemVisuals")
load("src/server/HomingMissileService.luau",server,"HomingMissileService")
load("src/server/ThunderStrikeService.luau",server,"ThunderStrikeService")
local Smoke=load("src/server/SmokeHazardService.luau",server,"SmokeHazardService")
load("src/server/TacticalLoadoutService.luau",server,"TacticalLoadoutService")
local contexts,sessions,players={},{},{}
local session={participants={},phase="WAITING",roundId=1,itemsReady={},itemPrepareDeadlines={}}
session.confirmItems=function(p,t)
 if session.itemsReady[p] or t>=session.itemPrepareDeadlines[p] then return false end
 session.itemsReady[p]=true;p:SetAttribute("RaceItemsReady",true);return true
end
services.Workspace:SetAttribute("KDMServerRole","RACE")
local road=child(child(child(prototype,"Model","TestTrack"),"Folder","Road"),"Part","Road")
road.Size=V.new(60,1,1000);road.CFrame=CF.new(0,-.5,0)
local function getKart(p)
	local c=contexts[p]
	if c and p.Parent and p:GetAttribute("RaceState")=="RACING" and c.kart.Parent and c.chassis.Parent
		and c.seat.Occupant and c.kart:GetAttribute("RaceControlsLocked")~=true then return c.kart,c.chassis end
end
local boostOutcome
for name,result in {PrototypeWorld={getRaceKart=getKart,getKartContext=function(p) return contexts[p] end,
	onDriftOutcome=function(f) boostOutcome=f end,activateNitro=function(p) contexts[p].kart:SetAttribute("KartNitroActive",true);return true end,
	applySlickHit=function() error("Smoke must never call Slick physics") end,
	applyMissileHit=function() error("Smoke must never call Missile physics") end},
	RaceSession={forPlayer=function(p) return sessions[p] end}} do child(server,"ModuleScript",name);modules[name]=result end
for index=1,4 do
	local p=child(services.Players,"Player","Racer"..index);p.UserId=index;p.DisplayName=p.Name
	p.Character=object("Model");local human=child(p.Character,"Humanoid","Humanoid");human.Health=100
	local kart=child(prototype,"Model","Kart"..index);kart:SetAttribute("PrototypeKart",true)
	local chassis=child(kart,"Part","Chassis");chassis.Size=V.new(4,2,6);chassis.CFrame=CF.new(index*20,1,0)
	chassis.AssemblyLinearVelocity=V.new(0,0,-70)
	local seat=child(kart,"Seat","Seat");seat.Occupant=human;human.SeatPart=seat
	contexts[p]={kart=kart,chassis=chassis,seat=seat};sessions[p]=session;session.participants[p]={};session.itemPrepareDeadlines[p]=now+10
	p:SetAttribute("RaceState","PRE_RACE");p:SetAttribute("RaceMatchStatus","WAITING");p:SetAttribute("RaceSessionId",1)
	table.insert(players,p)
end
services.Players.GetPlayers=function() return players end
local Items=load("src/server/RaceItemController.luau",server,"RaceItemController");Items.start()
local remote=services.ReplicatedStorage.RaceItemControl
local owner,b,c,d=table.unpack(players)
local function tick(dt) now+=dt or 0;services.RunService.Heartbeat:Fire() end
local function choose(p,ids)
	remote.OnServerEvent:Fire(p,"SetTacticalLoadout",ids)
	return remote.reply[2]
end
check(choose(owner,{"Shield","Missile","Smoke"}),"valid server-local Smoke swap")
check(owner:GetAttribute("RaceTacticalItem3")=="Smoke","approved choice published for modal")
session.itemsReady[owner]=nil
for _,ids in {{"Smoke","Smoke","Shield"},{"Nitro","Shield","Smoke"},{"Unknown","Shield","Smoke"},
	{"Shield","Smoke"},{"Slick","Shield","Missile","Smoke"},{"Shield","Smoke","Missile",extra="Nitro"}} do
	tick(.21);check(not choose(owner,ids),"reject invalid tactical membership/count/duplicate/payload")
end
for _,state in {"COUNTDOWN","RACING"} do owner:SetAttribute("RaceState",state);tick(.21);check(not choose(owner,{"Slick","Shield","Missile"}),"round locks choices "..state) end
owner:SetAttribute("RaceState","PRE_RACE");session.phase="RACING"
check(not choose(owner,{"Slick","Shield","Missile"}),"stale PRE_RACE client cannot change started session")
session.phase="WAITING"
for _,p in players do p:SetAttribute("RaceState","COUNTDOWN");p:SetAttribute("RaceState","RACING") end
check(owner:GetAttribute("RaceItemSlot1")=="Nitro" and owner:GetAttribute("RaceItemSlot2")=="Shield"
	and owner:GetAttribute("RaceItemSlot4")=="Smoke" and owner:GetAttribute("RaceChargeSmoke")==1,"Nitro core plus chosen three refills")
local function cloud() return services.Workspace.Prototype.RaceItemHazards:FindFirstChild("SmokeHazard") end
contexts[owner].chassis.CFrame=CF.new(0,1,0)
remote.OnServerEvent:Fire(owner,"UseItem","Smoke")
check(owner:GetAttribute("RaceChargeSmoke")==0 and cloud()~=nil,"accepted deploy consumes charge and creates server cloud")
local model=cloud();local trigger=model.SmokeTrigger
check(model:GetAttribute("SmokeOwnerUserId")==owner.UserId and model:GetAttribute("RaceSessionId")==1,"server owner/session attributes")
check(trigger.Size==V.new(36,10,18) and #model:GetChildren()==10,"volume tuning and bounded nine-puff native visual")
for _,part in model:GetChildren() do
	check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,"cloud never blocks physics/query/touch")
	if part.Name~="SmokeTrigger" then
		local center=trigger.CFrame:PointToObjectSpace(part.Position)
		check(math.abs(center.X)+part.Size.X/2<=18 and math.abs(center.Y)+part.Size.Y/2<=5
			and math.abs(center.Z)+part.Size.Z/2<=9,"visible puff fits hazard bounds")
	end
end
check(config.SMOKE_WIDTH==36 and config.SMOKE_LENGTH==18 and config.SMOKE_HEIGHT==10 and config.SMOKE_EFFECT_DURATION==3,"R2 provisional tuning")
check(config.SMOKE_DROP_DISTANCE==10 and config.SMOKE_LIFETIME==6 and config.SMOKE_OWNER_GRACE==.75 and config.SMOKE_MAX_HAZARDS==12,"unchanged duration/grace/cap/drop contracts")
for _,puff in model:GetChildren() do
 if puff.Name~="SmokeTrigger" then check(puff.Transparency>=.45 and puff.Transparency<=.50,"denser world puffs remain translucent") end
end
local before=contexts[b].chassis.AssemblyLinearVelocity
local control={steering=.6,throttle=1,driftRequested=true}
contexts[b].control=control
contexts[b].kart:SetAttribute("KartVisualSteering",.6)
contexts[b].kart:SetAttribute("KartNitroActive",true);contexts[b].kart:SetAttribute("KartDrifting",true);contexts[b].kart:SetAttribute("KartBoosting",true)
contexts[owner].chassis.CFrame=trigger.CFrame;tick()
check(not contexts[owner].kart:GetAttribute("KartSmokeObscuredActive"),"owner grace protects deployer")
contexts[b].chassis.CFrame=trigger.CFrame;tick()
check(contexts[b].kart:GetAttribute("KartSmokeObscuredActive") and cloud()==model,"first racer obscured but cloud survives")
check(contexts[b].chassis.AssemblyLinearVelocity==before and contexts[b].kart:GetAttribute("KartNitroActive")
	and contexts[b].kart:GetAttribute("KartDrifting") and contexts[b].kart:GetAttribute("KartBoosting"),"Smoke never changes speed/Nitro/Drift/Boost")
check(before.Magnitude==70 and contexts[b].control==control and control.steering==.6 and control.throttle==1
 and control.driftRequested and contexts[b].kart:GetAttribute("KartVisualSteering")==.6,"normal-speed kart keeps steering/throttle command intact")
check(owner:GetAttribute("RaceCombatFeedbackCode")=="SMOKE_HIT","deployer receives authoritative Smoke hit result")
-- Shield consumes only this target's defense; the third target can still use the cloud.
tick(.21);remote.OnServerEvent:Fire(c,"UseItem","Shield")
contexts[c].chassis.CFrame=trigger.CFrame;tick()
check(not contexts[c].kart:GetAttribute("KartSmokeObscuredActive") and not contexts[c].kart:GetAttribute("KartShieldActive")
	and c:GetAttribute("RaceItemBlockedSerial")==1 and cloud()==model,"Shield blocks one target; cloud remains")
check(owner:GetAttribute("RaceCombatFeedbackCode")=="SMOKE_BLOCKED","deployer receives Smoke blocked result")
local accepted,reason=Items.tryApplyOffensiveItem(d,owner,"Smoke")
check(accepted and reason=="hit","fourth racer smoke resolution shares immunity")
contexts[d].chassis.CFrame=trigger.CFrame;tick()
tick(2.7)
check(contexts[b].kart:GetAttribute("KartSmokeObscuredActive"),"server effect remains active past old 1.75-second duration")
tick(.31)
check(not contexts[b].kart:GetAttribute("KartSmokeObscuredActive") and not contexts[d].kart:GetAttribute("KartSmokeObscuredActive"),"effect expires near 3.00 seconds")
tick(.1);check(not contexts[b].kart:GetAttribute("KartSmokeObscuredActive") and not contexts[c].kart:GetAttribute("KartSmokeObscuredActive")
	and not contexts[d].kart:GetAttribute("KartSmokeObscuredActive"),"hit/blocked/immune targets never retrigger from the same stationary cloud")
owner:SetAttribute("RaceState","FINISHED")
check(not cloud(),"owner finish removes own cloud")
owner:SetAttribute("RaceState","PRE_RACE");session.phase="WAITING"
check(owner:GetAttribute("RaceTacticalItem3")=="Smoke","Rematch staging retains chosen tactical IDs")
owner:SetAttribute("RaceState","COUNTDOWN");owner:SetAttribute("RaceState","RACING")
check(owner:GetAttribute("RaceChargeSmoke")==1 and owner:GetAttribute("RaceChargeNitro")==1,"Rematch refills chosen loadout")
contexts[owner].chassis.CFrame=CF.new(100,1,0);tick(.21);remote.OnServerEvent:Fire(owner,"UseItem","Smoke")
check(owner:GetAttribute("RaceChargeSmoke")==1 and not cloud(),"off-road deployment rejection retains charge")
contexts[owner].chassis.CFrame=CF.new(0,1,0)
sessions[d]={roundId=1,participants={[d]={}}};contexts[d].chassis.CFrame=CF.new(0,4,10)
tick(.21);remote.OnServerEvent:Fire(owner,"UseItem","Smoke")
local nextCloud=cloud()
contexts[b].chassis.CFrame=nextCloud.SmokeTrigger.CFrame
tick()
check(contexts[b].kart:GetAttribute("KartSmokeObscuredActive") and cloud()==nextCloud,"cloud survives first racer for a later independent contact")
contexts[c].chassis.CFrame=nextCloud.SmokeTrigger.CFrame
tick(.2)
check(contexts[b].kart:GetAttribute("KartSmokeObscuredActive") and contexts[c].kart:GetAttribute("KartSmokeObscuredActive")
	and cloud()==nextCloud,"two independent racers enter one persistent cloud")
check(not contexts[d].kart:GetAttribute("KartSmokeObscuredActive"),"another RaceSession never receives cloud effect")
contexts[owner].seat.Occupant=nil;tick()
check(not cloud(),"owner seat loss removes world cloud")
contexts[owner].seat.Occupant={};sessions[d]=session
owner:SetAttribute("RaceState","GARAGE");owner:SetAttribute("RaceState","COUNTDOWN");owner:SetAttribute("RaceState","RACING")
check(owner:GetAttribute("RaceItemSlot4")=="Missile" and owner:GetAttribute("RaceChargeSmoke")==0,"leaving to Garage restores safe production default")
-- Execute swept math at realistic speeds, including entire-volume fast crossings.
for _,speed in {55,70,100} do
	local ch=object("Part");ch.Size=V.new(4,2,6);ch.CFrame=CF.new(0,0,-speed*.25)
	check(Geometry.crosses(CF.identity,V.new(36,10,18),V.new(0,0,speed*.25),ch),"swept crossing "..speed)
	ch.CFrame=CF.new(25,0,-speed*.25)
	check(not Geometry.crosses(CF.identity,V.new(36,10,18),V.new(25,0,speed*.25),ch),"clear swept miss "..speed)
end
-- Smoke centers on Road-local X regardless of owner lane and follows rotated segments.
for _,angle in {0,math.rad(45),math.rad(90),math.rad(-35)} do
 road.CFrame=CF.new(40,-.5,80)*CF.Angles(0,angle,0)
 for _,lane in {-22,0,22} do
  local ch=object("Part");ch.Size=V.new(4,2,6);ch.CFrame=road.CFrame*CF.new(lane,1,-100)
  local smokeFrame=Geometry.smokeDropFrame(prototype,ch,10)
  local slickFrame=Geometry.dropFrame(prototype,ch,10)
  local point=road.CFrame:PointToObjectSpace(smokeFrame.Position)
  local slickPoint=road.CFrame:PointToObjectSpace(slickFrame.Position)
  check(math.abs(point.X)<.0001 and math.abs(point.Z+90)<.0001,"all owner lanes share road center; longitudinal drop preserved")
  check((smokeFrame.RightVector-road.CFrame.RightVector).Magnitude<.0001
   and (smokeFrame.LookVector-road.CFrame.LookVector).Magnitude<.0001,"road-local frame follows rotated segment")
  check(math.abs(slickPoint.X-lane)<.0001,"Slick retains precise owner lane")
 end
 local frame=road.CFrame*CF.new(0,5.58,10)
 for _,case in {{0,true},{19,true},{25,false},{-25,false}} do
  local ch=object("Part");ch.Size=V.new(4,2,6);ch.CFrame=frame*CF.new(case[1],0,-30)
  check(Geometry.crosses(frame,V.new(36,10,18),(frame*CF.new(case[1],0,30)).Position,ch)==case[2],
   "center and overlapping edge hit; deliberate outer line avoids Smoke")
 end
end
road.CFrame=CF.new(0,-.5,0)
local farKart=object("Part");farKart.CFrame=CF.new(100,1,0)
check(not Geometry.smokeDropFrame(prototype,farKart,10),"Smoke cannot project an off-road drop into a valid free admission")
-- A skewed owner heading still uses the Road's heading and its own drop's longitudinal point.
local skewed=object("Part");skewed.CFrame=CF.new(22,1,-100)*CF.Angles(0,math.rad(20),0)
local projected=Geometry.smokeDropFrame(prototype,skewed,10)
local actualDrop=skewed.Position-skewed.CFrame.LookVector*10
check(math.abs(projected.Position.Z-actualDrop.Z)<.0001 and math.abs(projected.Position.X)<.0001
 and (projected.LookVector-road.CFrame.LookVector).Magnitude<.0001,"skewed heading preserves drop Z while aligning across Road")
-- Isolated service lifecycle/cap test executes production apply/update, not string assertions.
local service=Smoke.new(config,{getKart=getKart,getSession=modules.RaceSession.forPlayer,geometry=Geometry,visuals=Visuals,
	parent=services.Workspace.Prototype.RaceItemHazards,resolve=Items.tryApplyOffensiveItem})
contexts[owner].chassis.CFrame=CF.new(0,1,0)
for index=1,12 do check(service:deploy(owner,prototype,now),"bounded cloud deploy "..index) end
check(not service:deploy(owner,prototype,now),"hazard cap rejects thirteenth")
service:update(now+6.01,{});check(#service.hazards==0,"six-second cloud TTL")
for _,boundary in {"FINISHED","DNF","GARAGE","COUNTDOWN","seat","destroy","reset","session","round","leave"} do
	b.Parent=services.Players;b:SetAttribute("RaceState","RACING");contexts[b].kart.Parent=prototype
	contexts[b].seat.Occupant={};sessions[b]=session
	check(service:apply(b,now),"active effect lifecycle fixture "..boundary)
	if boundary=="seat" then contexts[b].seat.Occupant=nil
	elseif boundary=="destroy" then contexts[b].kart.Parent=nil
	elseif boundary=="reset" then contexts[b].kart:SetAttribute("RaceResetSerial",1)
	elseif boundary=="session" then sessions[b]={roundId=5}
	elseif boundary=="round" then session.roundId+=1
	elseif boundary=="leave" then b.Parent=nil
	else b:SetAttribute("RaceState",boundary) end
	service:update(now,{})
	check(not contexts[b].kart:GetAttribute("KartSmokeObscuredActive"),"effect lifecycle cleanup "..boundary)
end
print("PASS: "..checks.." production Smoke/tactical loadout checks")
