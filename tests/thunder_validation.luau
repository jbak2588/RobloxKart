-- Actual Thunder service/controller/loadout/visual integration, mocked kart transport.
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
	applyThunderHit=function(p)
  local kart=contexts[p].kart
  if kart:GetAttribute("KartThunderHitActive") or kart:GetAttribute("KartMissileHitActive") or kart:GetAttribute("KartSlickActive") then return false end
  kart:SetAttribute("KartThunderHitActive",true);return true
 end,
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
 p:SetAttribute("RaceState","GARAGE");contexts[p].kart:SetAttribute("KartThunderHitActive",false);contexts[p].kart:SetAttribute("KartOffTrack",false);session.phase="WAITING"
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

local function reset()
 for i,p in players do
  sessions[p]=session;session.participants[p]={};p:SetAttribute("RacePosition",i)
  contexts[p].kart.Parent=prototype;contexts[p].chassis.Parent=contexts[p].kart
  contexts[p].kart:SetAttribute("KartMissileHitActive",false);contexts[p].kart:SetAttribute("KartSlickActive",false)
  prepare(p,{"Shield","Missile","Thunder"})
 end
end
local function warnings() local n=0;for _,m in prototype.RaceMissiles:GetChildren() do if m.Name=="ThunderWarning" then n+=1 end end;return n end
check(config.THUNDER_EFFECT_DURATION==2.00 and config.THUNDER_SPEED_CAP==60 and config.THUNDER_WARNING_SECONDS==1.00,"R1 duration 2.00; warning/cap frozen")
check(modules.RaceItemCatalog.Thunder.TargetMode=="AllAhead" and modules.RaceItemCatalog.Thunder.MaxCharges==1,"implemented AllAhead catalog")
check(#Slots.TACTICAL==5 and Slots.tactical({"Shield","Smoke","Thunder"})[4]=="Thunder","five candidates / exactly three tactical")
local l=Loadout.new();l:prepare();check(l.counts.Thunder==0 and #l.slots==4,"default stays Nitro Slick Shield Missile")
for n=2,4 do
 reset()
 for i,p in players do sessions[p]=if i<=n then session else nil end
 for i=1,n do
  local targets=Items.thunderTargets(players[i]);check(#targets==i-1,n.." racers target count "..i)
  for j,t in targets do check(t==players[j],"exact ahead target "..j) end
 end
end
reset();use(owner,"Thunder")
check(owner:GetAttribute("RaceChargeThunder")==1 and owner:GetAttribute("RaceItemFeedbackCode")=="NO_TARGET_AHEAD" and warnings()==0,"leader no target retains charge")
sessions[d]={participants={[d]={}},roundId=1};use(d,"Thunder")
check(d:GetAttribute("RaceChargeThunder")==1,"solo no target retains charge")
reset()
for _,state in {"GARAGE","FINISHED","DNF","FINISHING"} do
 owner:SetAttribute("RaceState",state);check(#Items.thunderTargets(b)==0,"exclude target "..state);owner:SetAttribute("RaceState","RACING")
end
contexts[owner].chassis.Parent=nil;check(#Items.thunderTargets(b)==0,"destroyed chassis excluded");contexts[owner].chassis.Parent=contexts[owner].kart
sessions[owner]={participants={},roundId=1};check(#Items.thunderTargets(b)==0,"cross-session excluded");sessions[owner]=session
remote.OnServerEvent:Fire(d,"UseItem","Thunder",owner)
check(d:GetAttribute("RaceChargeThunder")==1 and warnings()==0,"client target injection rejected")
reset();use(owner,"Shield");use(d,"Thunder")
local began=now
check(d:GetAttribute("RaceChargeThunder")==0 and warnings()==3,"one charge for three warnings")
remote.OnServerEvent:Fire(d,"UseItem","Thunder")
check(warnings()==3 and d:GetAttribute("RaceChargeThunder")==0,"duplicate cannot create another admission/event")
check(session.itemsReady[d] and d:GetAttribute("RaceTacticalItem3")=="Thunder","Thunder confirmed through existing ready gate")
for _,model in prototype.RaceMissiles:GetChildren() do
 for _,part in model:GetChildren() do check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,"warning parts are visual only") end
end
for i=1,3 do check(players[i]:GetAttribute("RaceThunderIncomingCount")==1,"immediate incoming "..i) end
-- Swap rankings and move B behind source: original fixed A/B/C set remains.
b:SetAttribute("RacePosition",5);owner:SetAttribute("RacePosition",2)
contexts[b].chassis.CFrame=CF.new(80,1,0)
tick(.99)
local foundFollowing=false
for _,model in prototype.RaceMissiles:GetChildren() do
 if model.Name=="ThunderWarning" and model.Cloud2.Position.X==80 then foundFollowing=true end
end
check(foundFollowing,"fixed warning cloud follows target movement")
check(not contexts[b].kart:GetAttribute("KartThunderHitActive") and warnings()==3,"no strike before 1.00")
tick(.01)
check(not contexts[owner].kart:GetAttribute("KartThunderHitActive") and not contexts[owner].kart:GetAttribute("KartShieldActive"),"Shield consumed with no effect")
check(contexts[b].kart:GetAttribute("KartThunderHitActive") and contexts[c].kart:GetAttribute("KartThunderHitActive"),"fixed targets independently hit despite position change")
check(d:GetAttribute("RaceThunderHitCount")==2 and d:GetAttribute("RaceThunderBlockedCount")==1 and d:GetAttribute("RaceThunderResultSerial")==1,"one aggregate mixed result 2 hit 1 block")
check(owner:GetAttribute("RaceItemBlockedSerial")==1 and not d:GetAttribute("RaceCombatFeedbackSerial"),"victim block serial; no per-target owner overwrite")
for i=1,3 do check(players[i]:GetAttribute("RaceThunderIncomingCount")==0,"resolved warning zero "..i) end
check(warnings()==0,"warning visuals removed at strike");tick(.26);check(#prototype.RaceMissiles:GetChildren()==0,"short strike flash expires")
reset();use(owner,"Shield");use(d,"Thunder");tick(.95)
check(Items.tryApplyOffensiveItem(c,d,"Smoke"),"shared immunity fixture just before strike")
tick(.05)
check(d:GetAttribute("RaceThunderHitCount")==1 and d:GetAttribute("RaceThunderBlockedCount")==1
 and not contexts[c].kart:GetAttribute("KartThunderHitActive"),"mixed independent Shield / hit / immune outcomes")
-- Concurrent events: independently balanced incoming counts, no stacked effects.
reset();use(d,"Thunder");use(c,"Thunder")
check(owner:GetAttribute("RaceThunderIncomingCount")==2,"two concurrent incoming")
fall(d);check(owner:GetAttribute("RaceThunderIncomingCount")==1 and warnings()==2,"source reset cancels only its event")
tick(1);check(owner:GetAttribute("RaceThunderIncomingCount")==0,"remaining event resolves 1 to zero")
reset();use(d,"Thunder");tick(.3);use(c,"Thunder");tick(.7)
check(owner:GetAttribute("RaceThunderIncomingCount")==1,"first event resolves independently")
tick(.3);check(owner:GetAttribute("RaceThunderIncomingCount")==0 and c:GetAttribute("RaceThunderHitCount")==0,"second event respects shared immunity")
-- Invalidating one target retains all other fixed targets.
for _,boundary in {"FINISHED","DNF","GARAGE","reset","session","kart","seat"} do
 reset();use(d,"Thunder")
 if boundary=="reset" then fall(owner)
 elseif boundary=="session" then sessions[owner]={participants={},roundId=1}
 elseif boundary=="kart" then contexts[owner].kart.Parent=nil
 elseif boundary=="seat" then contexts[owner].seat.Occupant=nil
 else owner:SetAttribute("RaceState",boundary) end
 tick(1)
 check(owner:GetAttribute("RaceThunderIncomingCount")==0 and d:GetAttribute("RaceThunderHitCount")==2,"one invalid target preserves others "..boundary)
end
reset();use(d,"Thunder");contexts[owner].kart:SetAttribute("KartOffTrack",true);tick(1)
check(d:GetAttribute("RaceThunderHitCount")==2 and not contexts[owner].kart:GetAttribute("KartThunderHitActive"),"off-track rejected at actual strike")
for _,active in {"KartMissileHitActive","KartSlickActive","KartThunderHitActive"} do
 reset();contexts[owner].kart:SetAttribute(active,true)
 local ok,reason=Items.tryApplyOffensiveItem(owner,d,"Thunder")
 check(not ok and reason=="effect_rejected","physical effect rejects stacking "..active)
end
for _,boundary in {"FINISHED","DNF","GARAGE","reset","session","round","kart","locked","leave"} do
 reset();use(d,"Thunder")
 if boundary=="reset" then fall(d)
 elseif boundary=="session" then sessions[d]={participants={},roundId=1}
 elseif boundary=="round" then session.roundId+=1
 elseif boundary=="kart" then contexts[d].kart.Parent=nil
 elseif boundary=="locked" then contexts[d].kart:SetAttribute("RaceControlsLocked",true)
 elseif boundary=="leave" then services.Players.PlayerRemoving:Fire(d)
 else d:SetAttribute("RaceState",boundary) end
 tick(0)
 check(warnings()==0 and owner:GetAttribute("RaceThunderIncomingCount")==0,"source lifecycle cleanup "..boundary)
 if boundary=="leave" then services.Players.PlayerAdded:Fire(d) end
 contexts[d].kart:SetAttribute("RaceControlsLocked",false)
end
reset();use(owner,"Shield");use(d,"Thunder")
local before=snapshot(d);local thunderBefore=d:GetAttribute("RaceChargeThunder")
fall(d);same(d,before,"Thunder fall")
check(d:GetAttribute("RaceChargeThunder")==thunderBefore and thunderBefore==0 and d:GetAttribute("RaceItemSlot4")=="Thunder","spent Thunder stays spent with identity intact")
d:SetAttribute("RaceState","PRE_RACE")
check(d:GetAttribute("RaceTacticalItem3")=="Thunder","Rematch staging retains confirmed Thunder choice")
d:SetAttribute("RaceState","COUNTDOWN");d:SetAttribute("RaceState","RACING")
check(d:GetAttribute("RaceChargeThunder")==1 and d:GetAttribute("RaceThunderIncomingCount")==0,"new round refills Thunder and clears transients")
-- Real service cap independent of charge availability, bounded visuals.
reset()
local svc=modules.ThunderStrikeService.new(config,{getKart=getKart,getSession=function(p) return sessions[p] end,
 visuals=Visuals,parent=prototype.RaceMissiles,resolve=function() return false,"immune" end,result=function() end})
for i=1,8 do check(svc:launch(d,{owner,b,c},session,now),"bounded event accepted "..i) end
check(not svc:launch(d,{owner},session,now) and #svc.events==8,"ninth event rejected")
check(owner:GetAttribute("RaceThunderIncomingCount")==8,"count tracks all bounded events")
svc:clearPlayer(owner);check(owner:GetAttribute("RaceThunderIncomingCount")==0 and #svc.events==8,"one target cancellation preserves events")
svc:clearSession(session);check(#svc.events==0 and b:GetAttribute("RaceThunderIncomingCount")==0,"session cleanup balances all warnings")
svc:clearSession(session);svc:clearPlayer(owner)
check(owner:GetAttribute("RaceThunderIncomingCount")==0 and b:GetAttribute("RaceThunderIncomingCount")==0,"repeated cleanup never negative")
print("PASS: "..checks.." Thunder service/controller/targeting checks (mocked; published runtime required)")
