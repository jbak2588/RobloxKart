-- Production RaceItemController fall-reset inventory integration, with mocked kart transport.
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
	local result=luau.load(fs.readFile(path),{environment=e,debugName=path})();modules[name]=result;return result
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
local Visuals=load("src/server/RaceItemVisuals.luau",server,"RaceItemVisuals")
load("src/server/HomingMissileService.luau",server,"HomingMissileService")
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
local function prepare(p,ids)
 contexts[p].kart.Parent=prototype;p.Parent=services.Players;contexts[p].seat.Occupant={}
 p:SetAttribute("RaceState","GARAGE");session.phase="WAITING"
 p:SetAttribute("RaceState","PRE_RACE");session.itemsReady[p]=nil;session.itemPrepareDeadlines[p]=now+10
 if ids then tick(.21);assert(choose(p,ids)) end
 p:SetAttribute("RaceState","COUNTDOWN");p:SetAttribute("RaceState","RACING")
end
local function snapshot(p)
 local result={}
 for _,id in {"Nitro","Slick","Shield","Missile","Smoke"} do result["RaceCharge"..id]=p:GetAttribute("RaceCharge"..id) end
 for index=1,4 do result["RaceItemSlot"..index]=p:GetAttribute("RaceItemSlot"..index) end
 result.SelectedRaceItemId=p:GetAttribute("SelectedRaceItemId")
 result.DriftBonusProgress=p:GetAttribute("DriftBonusProgress")
 result.DriftBonusNitroAwarded=p:GetAttribute("DriftBonusNitroAwarded")
 for index=1,3 do result["RaceTacticalItem"..index]=p:GetAttribute("RaceTacticalItem"..index) end
 return result
end
local function same(p,before,label)
 for name,value in before do check(p:GetAttribute(name)==value,label.." preserves "..name) end
 check(p:GetAttribute("RaceState")=="RACING",label.." remains RACING")
end
local function fall(p)
 local kart=contexts[p].kart;kart:SetAttribute("RaceResetSerial",(kart:GetAttribute("RaceResetSerial") or 0)+1)
end
local function use(p,id) tick(.21);remote.OnServerEvent:Fire(p,"UseItem",id) end
for _,p in players do prepare(p) end
-- A: untouched production defaults.
local before=snapshot(owner);fall(owner);same(owner,before,"untouched fall")
check(owner:GetAttribute("RaceChargeNitro")==1 and owner:GetAttribute("RaceChargeMissile")==1,"default charges never erased")
-- B: consumed Nitro/Shield, custom Smoke in place of Missile; no refill exploit.
prepare(owner,{"Slick","Shield","Smoke"});use(owner,"Nitro");use(owner,"Shield")
check(owner:GetAttribute("RaceChargeNitro")==0 and owner:GetAttribute("RaceChargeShield")==0
 and owner:GetAttribute("RaceChargeSlick")==1 and owner:GetAttribute("RaceChargeSmoke")==1,"partially consumed fixture 0/1/0/1")
before=snapshot(owner);fall(owner);same(owner,before,"partial fall")
check(not contexts[owner].kart:GetAttribute("KartShieldActive"),"active Shield removed while consumed charge stays zero")
for _=1,3 do fall(owner);same(owner,before,"repeated partial fall") end
use(owner,"Shield");check(owner:GetAttribute("RaceChargeShield")==0 and not contexts[owner].kart:GetAttribute("KartShieldActive"),"empty Shield remains unusable after resets")
use(owner,"Smoke");check(owner:GetAttribute("RaceChargeSmoke")==0,"remaining charge usable through normal direct UseItem after fall")
-- C: custom order/selection survives, including a consumed Missile.
prepare(owner,{"Shield","Missile","Smoke"})
owner:SetAttribute("RacePosition",2);b:SetAttribute("RacePosition",1)
use(owner,"Missile");remote.OnServerEvent:Fire(owner,"Select","Smoke")
check(owner:GetAttribute("RaceChargeMissile")==0 and owner:GetAttribute("SelectedRaceItemId")=="Smoke","custom 1/1/0/1 and selected Smoke fixture")
before=snapshot(owner);fall(owner);same(owner,before,"custom order fall")
check(owner:GetAttribute("RaceItemSlot2")=="Shield" and owner:GetAttribute("RaceItemSlot4")=="Smoke","tactical order intact")
-- D/E: earned progress and both award guards survive without granting another reward.
prepare(owner)
for _=1,3 do boostOutcome(owner,"BOOST") end
before=snapshot(owner);fall(owner);same(owner,before,"3-of-5 fall")
check(owner:GetAttribute("DriftBonusProgress")==3,"3/5 still 3/5")
for _=1,2 do boostOutcome(owner,"BOOST") end
check(owner:GetAttribute("RaceChargeNitro")==2 and owner:GetAttribute("DriftBonusNitroAwarded"),"fifth boost grants exactly one bonus")
use(owner,"Nitro");use(owner,"Nitro")
before=snapshot(owner);fall(owner);same(owner,before,"earned bonus fall")
check(not Items.grantBonusNitro(owner),"bonusClaimed remains locked even with empty Nitro after fall")
for _=1,5 do boostOutcome(owner,"BOOST") end
check(owner:GetAttribute("RaceChargeNitro")==0 and owner:GetAttribute("DriftBonusProgress")==5
 and owner:GetAttribute("DriftBonusNitroAwarded"),"earned race reward cannot repeat after reset")
-- F: both owned/targeted warnings, Shield, Smoke victim/hazard, immunity and feedback clear.
prepare(owner,{"Shield","Missile","Smoke"});prepare(b);prepare(c)
contexts[owner].chassis.CFrame=CF.new(0,1,0)
owner:SetAttribute("RacePosition",2);b:SetAttribute("RacePosition",3);c:SetAttribute("RacePosition",1)
check(Items.tryApplyOffensiveItem(owner,b,"Smoke"),"Smoke victim fixture")
use(owner,"Smoke");use(owner,"Shield");use(owner,"Missile");use(b,"Missile")
check(contexts[owner].kart:GetAttribute("KartShieldActive") and contexts[owner].kart:GetAttribute("KartSmokeObscuredActive")
 and owner:GetAttribute("RaceMissileIncomingCount")==1 and c:GetAttribute("RaceMissileIncomingCount")==1,"transient combat fixture active")
before=snapshot(owner);fall(owner);same(owner,before,"combat fall")
check(not contexts[owner].kart:GetAttribute("KartShieldActive") and not contexts[owner].kart:GetAttribute("KartSmokeObscuredActive")
 and not contexts[owner].kart:GetAttribute("RaceItemHitImmunity"),"Shield/Smoke/immunity cleared immediately")
check(owner:GetAttribute("RaceMissileIncomingCount")==0 and c:GetAttribute("RaceMissileIncomingCount")==0
 and owner:GetAttribute("RaceCombatFeedbackCode")=="" and owner:GetAttribute("RaceItemFeedbackCode")=="","incoming and outgoing warnings/feedback clear")
check(#services.Workspace.Prototype.RaceItemHazards:GetChildren()==0,"owned temporary hazards removed")
-- G: inventory still fully clears at actual lifecycle boundaries.
for _,boundary in {"GARAGE","session","destroy","leave"} do
 prepare(owner,{"Shield","Missile","Smoke"})
 if boundary=="session" then owner:SetAttribute("RaceSessionId",(owner:GetAttribute("RaceSessionId") or 0)+1)
 elseif boundary=="destroy" then contexts[owner].kart:Destroy()
 elseif boundary=="leave" then services.Players.PlayerRemoving:Fire(owner)
 else owner:SetAttribute("RaceState",boundary) end
 for _,id in {"Nitro","Slick","Shield","Missile","Smoke"} do check(owner:GetAttribute("RaceCharge"..id)==0,"full teardown zero "..boundary.." "..id) end
 for i=1,4 do check(owner:GetAttribute("RaceItemSlot"..i)=="","full teardown clears slot "..boundary.." "..i) end
end
print("PASS: "..checks.." production fall-reset inventory/lifecycle checks (mocked; published fall retest required)")
