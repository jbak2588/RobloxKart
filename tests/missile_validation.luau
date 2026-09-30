-- Production controller + projectile service, deterministic server clock/GUI geometry mocks.
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
function methods:IsA(class) return self.ClassName == class end
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
local env={Vector3=V,CFrame=CF,Color3=rb.Color3,Enum=rb.Enum,Instance={new=object},
	time=function() return now end,game={GetService=function(_,name) return assert(services[name],name) end}}
local function load(path,parent,name)
	local script=child(parent,"ModuleScript",name)
	local e=table.clone(env);e.script=script;e.require=function(m) return assert(modules[m.Name],m.Name) end
	local result=luau.load(fs.readFile(path),{environment=e,debugName=path})();modules[name]=result;return result
end
local config=load("src/shared/RaceItemConfig.luau",shared,"RaceItemConfig")
local Loadout=load("src/server/RaceLoadout.luau",server,"RaceLoadout")
local boundLoadouts={}
local originalLoadoutNew=Loadout.new
Loadout.new=function() local l=originalLoadoutNew();table.insert(boundLoadouts,l);return l end
local Visuals=load("src/server/RaceItemVisuals.luau",server,"RaceItemVisuals")
local Service=load("src/server/HomingMissileService.luau",server,"HomingMissileService")
local sessions, contexts = {}, {}
local effectCount=0
local function getKart(player)
	local c=contexts[player]
	if c and player.Parent and player:GetAttribute("RaceState")=="RACING" and c.kart.Parent and c.chassis.Parent
		and c.seat.Occupant and c.kart:GetAttribute("RaceControlsLocked")==false then return c.kart,c.chassis end
end
local world={getRaceKart=getKart,getKartContext=function(p) return contexts[p] end,
	onDriftOutcome=function() end,activateNitro=function() return true end,
	applyMissileHit=function(p) effectCount+=1;contexts[p].kart:SetAttribute("KartMissileHitActive",true);return true end,
	applySlickHit=function() effectCount+=1;return true end}
for name, result in {PrototypeWorld=world, RaceSession={forPlayer=function(p) return sessions[p] end}, RaceItemGeometry={}} do
	child(server,"ModuleScript",name);modules[name]=result
end
local players={}
services.Players.GetPlayers=function() return players end
local items=load("src/server/RaceItemController.luau",server,"RaceItemController")
local session={participants={},roundId=1}
for i=1,4 do
	local p=child(services.Players,"Player","Player"..i);p.UserId=i;p.DisplayName="Racer "..i
	p:SetAttribute("RaceState","GARAGE");p:SetAttribute("RacePosition",i)
	table.insert(players,p);sessions[p]=session;session.participants[p]={}
	local kart=child(prototype,"Model","Kart"..i)
	contexts[p]={kart=kart,chassis=child(kart,"Part","Chassis"),seat=child(kart,"Seat","Seat")}
	contexts[p].seat.Occupant={};kart:SetAttribute("RaceControlsLocked",false)
end
items.start()
local remote=services.ReplicatedStorage.RaceItemControl
local function reset()
	for i,p in players do
		sessions[p]=session;session.participants[p]={};p:SetAttribute("RacePosition",i)
		local c=contexts[p];c.kart.Parent=prototype;c.chassis.Parent=c.kart;c.seat.Occupant={}
		c.kart:SetAttribute("RaceControlsLocked",false);c.kart:SetAttribute("KartMissileHitActive",false)
		c.chassis.CFrame=CF.new(0,0,-(5-i)*50)
		p:SetAttribute("RaceState","GARAGE");p:SetAttribute("RaceState","COUNTDOWN");p:SetAttribute("RaceState","RACING")
	end
end
local function tick(dt) now+=dt;services.RunService.Heartbeat:Fire(dt) end
local function use(p,id)
	remote.OnServerEvent:Fire(p,"Select",id);now+=.16;remote.OnServerEvent:Fire(p,"Use")
end
local function projectileCount() return #prototype.RaceMissiles:GetChildren() end
reset()
for n=2,4 do
	for i,p in players do sessions[p]=if i<=n then session else nil end
	for i=1,n do check(items.missileTarget(players[i])==(if i==1 then nil else players[i-1]),n.." racer immediate target "..i) end
end
reset()
use(players[1],"Missile")
check(players[1]:GetAttribute("RaceChargeMissile")==1 and players[1]:GetAttribute("RaceItemFeedbackCode")=="NO_TARGET_AHEAD"
	and projectileCount()==0,"leader retains charge with feedback")
sessions[players[4]]={participants={[players[4]]={}},roundId=1}
use(players[4],"Missile")
check(players[4]:GetAttribute("RaceChargeMissile")==1 and players[4]:GetAttribute("RaceItemFeedbackCode")=="NO_TARGET_AHEAD","solo retains Missile")
reset()
local source,target=players[4],players[3]
for _, state in {"GARAGE","PRE_RACE","COUNTDOWN","FINISHING","FINISHED","DNF"} do
	target:SetAttribute("RaceState",state)
	check(items.missileTarget(source)==nil,"target state excluded "..state)
	target:SetAttribute("RaceState","RACING")
end
sessions[target]={participants={[target]={}},roundId=1}
check(items.missileTarget(source)==nil,"different session/Room excluded even if ranking matches")
local crossHit,crossReason=items.tryApplyOffensiveItem(target,source,"Missile")
check(not crossHit and crossReason=="cross_session","offensive resolution independently rejects cross-session Missile")
sessions[target]=session
contexts[target].seat.Occupant=nil
check(items.missileTarget(source)==nil,"invalid KartContext excluded without skipping to leader")
contexts[target].seat.Occupant={}
reset()
remote.OnServerEvent:Fire(source,"Select","Missile")
for _, injected in {target,target.UserId,contexts[target].kart,V.new(0,0,0)} do remote.OnServerEvent:Fire(source,"Use",injected) end
check(source:GetAttribute("RaceChargeMissile")==1 and (target:GetAttribute("RaceMissileIncomingCount") or 0)==0,"all client target injection rejected")
use(source,"Missile")
local warningStart=now
check(config.MISSILE_WARNING_SECONDS==1.50,"R2 mobile reaction window is 1.50 seconds")
check(source:GetAttribute("RaceChargeMissile")==0 and source:GetAttribute("RaceMissileTargetName")==target.DisplayName
	and source:GetAttribute("RaceMissileLaunchSerial")==1 and target:GetAttribute("RaceMissileIncomingCount")==1,"acceptance consumes only Missile and publishes lock/incoming")
tick(1.0)
check(projectileCount()==0 and effectCount==0 and target:GetAttribute("RaceMissileIncomingCount")==1,
	"immediate incoming warning remains active beyond old .75 launch time")
use(target,"Shield")
tick(warningStart+1.499-now)
check(projectileCount()==0 and contexts[target].kart:GetAttribute("KartShieldActive"),"Shield selected/used before full 1.50 warning ends")
tick(.0011)
check(projectileCount()==1 and contexts[target].kart:GetAttribute("KartShieldActive"),"target can Shield during warning")
for _, part in prototype.RaceMissiles:GetChildren()[1]:GetChildren() do
	check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,"native projectile has no physics/touch authority")
end
source:SetAttribute("RacePosition",2);target:SetAttribute("RacePosition",4)
for _=1,30 do tick(1/60) end
check(effectCount==0 and not contexts[target].kart:GetAttribute("KartShieldActive")
	and target:GetAttribute("RaceItemBlockedSerial")==1 and target:GetAttribute("RaceMissileIncomingCount")==0,
	"fixed target blocks after positions change, no effect")
tick(.21);check(projectileCount()==0,"blocked flash/projectile cleaned")
reset();effectCount=0
use(source,"Missile");tick(config.MISSILE_WARNING_SECONDS)
for _=1,30 do tick(1/60) end
check(effectCount==1 and contexts[target].kart:GetAttribute("KartMissileHitActive") and target:GetAttribute("RaceMissileIncomingCount")==0,"unshielded impact resolves effect once")
local hit,reason=items.tryApplyOffensiveItem(target,source,"Missile")
check(not hit and reason=="immune" and effectCount==1,"second Missile inside immunity cannot stack")
hit,reason=items.tryApplyOffensiveItem(target,source,"Slick")
check(not hit and reason=="immune" and effectCount==1,"shared offensive immunity blocks Slick too")
tick(.21);check(projectileCount()==0,"hit flash cleanup")

-- Direct Shield uses the normal defense against a real service-owned Missile.
reset();use(source,"Missile")
local blockedBeforeDirect=target:GetAttribute("RaceItemBlockedSerial") or 0
for _,injected in {"Shield",target,2,{incoming=1}} do
	remote.OnServerEvent:Fire(target,"UseItem","Shield",injected)
end
check(target:GetAttribute("RaceChargeShield")==1 and not contexts[target].kart:GetAttribute("KartShieldActive"),
	"direct Shield use rejects all client-supplied payloads without spending")
remote.OnServerEvent:Fire(target,"UseItem","Shield")
check(contexts[target].kart:GetAttribute("KartShieldActive") and target:GetAttribute("RaceChargeShield")==0
	and target:GetAttribute("RaceChargeNitro")==1 and target:GetAttribute("SelectedRaceItemId")=="Nitro",
	"one direct Shield use request activates and consumes only Shield while preserving selection")
local directShell=contexts[target].kart:FindFirstChild("RaceItemShield")
for _=1,10 do remote.OnServerEvent:Fire(target,"UseItem","Shield") end
check(target:GetAttribute("RaceChargeShield")==0 and contexts[target].kart:FindFirstChild("RaceItemShield")==directShell,
	"duplicate direct taps cannot consume again or create another Shield")
-- Supply a charge behind an already-active Shield to isolate that validation.
boundLoadouts[3].counts.Shield=1;remote.OnServerEvent:Fire(target,"Select","Nitro");now+=.16
remote.OnServerEvent:Fire(target,"UseItem","Shield")
check(target:GetAttribute("RaceChargeShield")==1 and contexts[target].kart:FindFirstChild("RaceItemShield")==directShell,
	"already-active Shield rejects direct activation even with a charge")
tick(config.MISSILE_WARNING_SECONDS)
for _=1,30 do tick(1/60) end
check(not contexts[target].kart:GetAttribute("KartShieldActive") and not contexts[target].kart:GetAttribute("KartMissileHitActive")
	and target:GetAttribute("RaceItemBlockedSerial")==blockedBeforeDirect+1,"direct Shield is the ordinary one-hit defense with no slowdown")
reset();use(source,"Missile")
boundLoadouts[3].counts.Shield=0;remote.OnServerEvent:Fire(target,"Select","Nitro")
remote.OnServerEvent:Fire(target,"UseItem","Shield")
check(target:GetAttribute("RaceChargeShield")==0 and not contexts[target].kart:GetAttribute("KartShieldActive"),
	"incoming with zero Shield rejects without negative charge")
reset()
remote.OnServerEvent:Fire(target,"UseItem","Shield")
check(target:GetAttribute("RaceMissileIncomingCount")==0 and target:GetAttribute("RaceChargeShield")==0
 and contexts[target].kart:GetAttribute("KartShieldActive"),"direct Shield requires no incoming warning")
reset();use(source,"Missile");source:SetAttribute("RaceState","GARAGE")
remote.OnServerEvent:Fire(target,"UseItem","Shield")
check(target:GetAttribute("RaceMissileIncomingCount")==0 and target:GetAttribute("RaceChargeShield")==0
 and contexts[target].kart:GetAttribute("KartShieldActive"),"expired incoming does not change direct Shield semantics")
reset();use(target,"Shield")
check(contexts[target].kart:GetAttribute("KartShieldActive") and target:GetAttribute("RaceChargeShield")==0,
 "desktop Select/Use still works without incoming")
reset();remote.OnServerEvent:Fire(target,"EmergencyShield")
check(target:GetAttribute("RaceChargeShield")==1 and not contexts[target].kart:GetAttribute("KartShieldActive"),
 "removed special action cannot spend a charge")
reset();remote.OnServerEvent:Fire(source,"UseItem","Missile")
local directSerial=source:GetAttribute("RaceMissileLaunchSerial")
for _=1,10 do remote.OnServerEvent:Fire(source,"UseItem","Missile") end
check(source:GetAttribute("RaceChargeMissile")==0 and source:GetAttribute("RaceMissileLaunchSerial")==directSerial
 and target:GetAttribute("RaceMissileIncomingCount")==1,"direct Missile launches once despite rapid duplicate requests")
reset();remote.OnServerEvent:Fire(players[1],"UseItem","Missile")
check(players[1]:GetAttribute("RaceChargeMissile")==1 and players[1]:GetAttribute("RaceItemFeedbackCode")=="NO_TARGET_AHEAD",
 "direct Missile with no target retains its charge and publishes feedback")
reset();use(source,"Missile")
contexts[target].seat._p.Occupant=nil
remote.OnServerEvent:Fire(target,"UseItem","Shield")
check(target:GetAttribute("RaceChargeShield")==1 and not contexts[target].kart:GetAttribute("KartShieldActive"),
	"invalid active Kart rejects atomic direct without consuming")
reset();use(players[4],"Missile");players[2]:SetAttribute("RacePosition",4);use(players[2],"Missile")
check(target:GetAttribute("RaceMissileIncomingCount")==2,"two actual incoming records before direct")
remote.OnServerEvent:Fire(target,"UseItem","Shield")
check(target:GetAttribute("RaceChargeShield")==0 and contexts[target].kart:GetAttribute("KartShieldActive"),
	"multiple incoming still create just one ordinary Shield")
local firstBlocked,firstReason=items.tryApplyOffensiveItem(target,source,"Missile")
local secondHit,secondReason=items.tryApplyOffensiveItem(target,players[2],"Missile")
check(firstBlocked and firstReason=="blocked" and secondHit and secondReason=="hit",
	"one direct Shield blocks one attack; the next attack can hit")
for _,state in {"GARAGE","COUNTDOWN","FINISHED","DNF"} do
	reset();use(source,"Missile");target:SetAttribute("RaceState",state)
	local before=target:GetAttribute("RaceChargeShield")
	remote.OnServerEvent:Fire(target,"UseItem","Shield")
	check(target:GetAttribute("RaceChargeShield")==before and not contexts[target].kart:GetAttribute("KartShieldActive"),
		"direct is RACING-only "..state)
end

for _, phase in {"WARNING","FLYING"} do
for _, boundary in {"FINISHING","FINISHED","DNF","GARAGE","COUNTDOWN","reset","occupant","lock","destroy","session","round","leave","owner_leave"} do
	reset();use(source,"Missile");if phase=="FLYING" then tick(config.MISSILE_WARNING_SECONDS) end
	if boundary=="reset" then contexts[target].kart:SetAttribute("RaceResetSerial",(contexts[target].kart:GetAttribute("RaceResetSerial") or 0)+1)
	elseif boundary=="occupant" then contexts[target].seat.Occupant=nil
	elseif boundary=="lock" then contexts[target].kart:SetAttribute("RaceControlsLocked",true)
	elseif boundary=="destroy" then contexts[target].kart:Destroy()
	elseif boundary=="session" then sessions[target]={participants={[target]={}},roundId=1}
	elseif boundary=="round" then session.roundId+=1
	elseif boundary=="leave" then services.Players.PlayerRemoving:Fire(target)
	elseif boundary=="owner_leave" then services.Players.PlayerRemoving:Fire(source)
	else target:SetAttribute("RaceState",boundary) end
	tick(.01)
	check(projectileCount()==0 and target:GetAttribute("RaceMissileIncomingCount")==0,"projectile/incoming cleanup "..phase.." "..boundary)
	-- Rebind removed fixtures; a real departed player never rejoins this controller instance.
	if boundary=="leave" then services.Players.PlayerAdded:Fire(target) end
	if boundary=="owner_leave" then services.Players.PlayerAdded:Fire(source) end
end
end
reset()
check(source:GetAttribute("RaceChargeMissile")==1 and target:GetAttribute("RaceMissileIncomingCount")==0,"new round refills and clears incoming")
local loadout=Loadout.new();loadout:prepare()
check(loadout.counts.Nitro==1 and loadout.counts.Slick==1 and loadout.counts.Shield==1
	and loadout.counts.Missile==1 and loadout.counts.Smoke==0,"four equal temporary base resources")
check(loadout:grantBonusNitro() and loadout.counts.Nitro==2 and not loadout:grantBonusNitro(),"bonus remains capped at two once per race")

-- Service-level simultaneous launch, capacity, turning and relative sweep probes.
local hits={}
local folder=child(prototype,"Folder","ServiceProbes")
local service=Service.new(config,{getKart=getKart,getSession=function(p) return sessions[p] end,
	resolve=function(t,s) table.insert(hits,{t,s});return true,"hit" end,visuals=Visuals,parent=folder})
check(Service.sweptHit(V.new(0,0,0),V.new(0,0,-100),V.new(0,0,-50),V.new(0,0,-50),5.5),"fast segment cannot tunnel")
check(Service.sweptHit(V.new(-10,0,0),V.new(10,0,0),V.new(0,0,-10),V.new(0,0,10),1),"relative sweep catches moving target")
check(not Service.sweptHit(V.zero,V.new(0,0,-100),V.new(20,0,-50),V.new(20,0,-50),5.5),"sweep rejects lateral miss")
assert(service:launch(players[4],players[2],session,now));assert(service:launch(players[3],players[2],session,now))
check(players[2]:GetAttribute("RaceMissileIncomingCount")==2,"multiple incoming counted independently")
service:clearPlayer(players[4]);check(players[2]:GetAttribute("RaceMissileIncomingCount")==1,"one owner cleanup preserves other incoming")
service:clearSession(session);check(players[2]:GetAttribute("RaceMissileIncomingCount")==0 and #service.projectiles==0,"session cleanup clears only its records")
for _=1,config.MISSILE_MAX_ACTIVE do assert(service:launch(source,target,session,now)) end
check(not service:launch(source,target,session,now) and target:GetAttribute("RaceMissileIncomingCount")==config.MISSILE_MAX_ACTIVE,"bounded capacity includes warning records")
service:clearSession(session)
assert(service:launch(source,target,session,now));service:update(now+config.MISSILE_WARNING_SECONDS)
local p=service.projectiles[1]
contexts[target].chassis.CFrame=CF.new(1000,0,1000)
local oldDirection=p.direction
service:update(now+config.MISSILE_WARNING_SECONDS+.01)
check(math.acos(math.clamp(oldDirection:Dot(p.direction),-1,1))<=config.MISSILE_TURN_RATE*.01+.0001,"turn rate capped in radians per second")
service:update(now+config.MISSILE_WARNING_SECONDS+6.999)
check(#service.projectiles==1,"flight lifetime remains seven seconds after the longer warning")
service:update(now+config.MISSILE_WARNING_SECONDS+7.001)
check(#service.projectiles==0 and #folder:GetChildren()==0 and target:GetAttribute("RaceMissileIncomingCount")==0,"seven-second flight expiry cleans incoming/visual")
reset();assert(service:launch(source,target,session,now));service:update(now+config.MISSILE_WARNING_SECONDS)
-- Cross the target in one large frame, rather than reporting client contact.
p=service.projectiles[1];p.position=contexts[target].chassis.Position+V.new(0,2,20);p.direction=V.new(0,0,-1)
service:update(now+config.MISSILE_WARNING_SECONDS+.3)
check(#hits==1 and hits[1][1]==target and #service.projectiles==0,"server swept impact resolves the fixed target")
service:clearSession(session)
check(#folder:GetChildren()==0,"session cleanup also removes impact flash")
print("PASS: "..checks.." Missile targeting, warning, resolution, projectile and lifecycle checks (mocked)")
