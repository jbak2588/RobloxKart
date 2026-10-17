local fs,luau,rb=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local n=0
local function check(v,l)assert(v,l);n+=1 end
local function signal()
 local list={};return {Connect=function(_,f)local c={active=true};function c:Disconnect()self.active=false end;table.insert(list,{c,f});return c end,
 Fire=function(_,...)for _,p in table.clone(list) do if p[1].active then p[2](...) end end end,
 Count=function()local count=0;for _,p in list do if p[1].active then count+=1 end end;return count end}
end
local methods={}
local function object(class)
 local props={ClassName=class,Name=class,Destroying=signal()}
 return setmetatable({props=props,children={},signals={},attrs={}}, {__index=function(self,k)return methods[k] or props[k] end,
 __newindex=function(self,k,v)if k=="Parent" then if props.Parent then local i=table.find(props.Parent.children,self);if i then table.remove(props.Parent.children,i) end end;if v then table.insert(v.children,self) end end;props[k]=v end})
end
function methods:IsA(c)return self.ClassName==c end
function methods:GetAttribute(k)return self.attrs[k] end
function methods:GetAttributeChangedSignal(k)if not self.signals[k] then self.signals[k]=signal() end;return self.signals[k] end
function methods:SetAttribute(k,v)local old=self.attrs[k];self.attrs[k]=v;if old~=v then self:GetAttributeChangedSignal(k):Fire() end end
function methods:GetDescendants()local out={};for _,c in self.children do table.insert(out,c);for _,v in c:GetDescendants() do table.insert(out,v) end end;return out end
function methods:Destroy()self.Destroying:Fire();for _,c in table.clone(self.children) do c:Destroy() end;self.Parent=nil end
function methods:WaitForChild(name)for _,c in self.children do if c.Name==name then return c end end;error(name) end
local workspace=object("Workspace")
local prototype=object("Folder");prototype.Name="Prototype";prototype.Parent=workspace;prototype.DescendantAdded=signal();prototype.DescendantRemoving=signal()
local player=object("Player");player.AncestryChanged=signal()
local function kart()
 local k=object("Model");k:SetAttribute("PrototypeKart",true);k.Parent=prototype
 local chassis=object("Part");chassis.CFrame=rb.CFrame.identity;k.PrimaryPart=chassis;chassis.Parent=k
 return k
end
local k=kart()
local queue={}
local debris={AddItem=function(_,model,lifetime)table.insert(queue,{model,lifetime}) end}
local node={WaitForChild=function(self)return self end}
local cfg=luau.load(fs.readFile("src/shared/KDMItemVFXConfig.luau"))()
local services={Workspace=workspace,Debris=debris,Players={LocalPlayer=player},ReplicatedStorage=node}
local controller=luau.load(fs.readFile("src/client/KDMItemVFXController.luau"),{environment={game={GetService=function(_,name)return services[name] end},require=function()return cfg end,
 Instance={new=object},Vector3=rb.Vector3,CFrame=rb.CFrame,Color3=rb.Color3,Enum=rb.Enum}})()
local function count()local c=0;for _,m in workspace.children do if m.Name=="KDMSlickTireCue" then c+=1 end end;return c end
controller.start();controller.start();check(prototype.DescendantAdded.Count()==1,"idempotent observer")
for i=1,20 do
 k:SetAttribute("KartSlickActive",true);check(count()==1 and #queue[#queue][1].children==2,"two bounded puffs per edge")
 check(queue[#queue][2]==.18,"finite visual lifetime")
 for _,puff in queue[#queue][1].children do check(puff.Anchored and not puff.CanCollide and not puff.CanTouch and not puff.CanQuery,"noninteractive cue") end
 queue[#queue][1]:Destroy();check(count()==0,"Debris expiry no residual")
 k:SetAttribute("KartSlickActive",false)
end
k:SetAttribute("KartSlickActive",true);k:SetAttribute("RaceResetSerial",1);check(count()==0,"recovery cancels cue")
k:SetAttribute("KartSlickActive",false);k:SetAttribute("RaceControlsLocked",true);k:SetAttribute("KartSlickActive",true);check(count()==0,"locked lifecycle suppresses cue")
local bot=kart();prototype.DescendantAdded:Fire(bot);bot:SetAttribute("KartSlickActive",true);check(count()==1,"observer sees bot cue too")
prototype.DescendantRemoving:Fire(bot);check(count()==0 and bot:GetAttributeChangedSignal("KartSlickActive").Count()==0,"removed kart disconnects")

-- Damage smoke lifecycle validation under Missile and Thunder hits
local function findDamageAttachment(target)
	for _, child in target.PrimaryPart.children do
		if child.Name == "KDMDamageSmokeAttachment" then return child end
	end
	return nil
end

-- 1. Missile hit spawns single damage smoke plume
k:SetAttribute("RaceControlsLocked", false)
k:SetAttribute("KartMissileHitActive", true)
local missileAttach = findDamageAttachment(k)
check(missileAttach ~= nil, "damage smoke attachment created on Missile hit")
local smokeEmitter = nil
for _, child in missileAttach.children do if child.Name == "DamageSmoke" then smokeEmitter = child end end
check(smokeEmitter ~= nil, "damage smoke emitter exists")
check(smokeEmitter.Enabled ~= false, "damage smoke emitter is actively enabled")

-- 2. Missile recovery fades and queues debris cleanup
k:SetAttribute("KartMissileHitActive", false)
check(smokeEmitter.Enabled == false, "damage smoke disabled upon speed recovery")
check(queue[#queue][1] == missileAttach and queue[#queue][2] == 2.5, "damage smoke queued for Debris fade cleanup")
missileAttach:Destroy()

-- 3. Thunder hit spawns damage smoke with electric spark
k:SetAttribute("KartThunderHitActive", true)
local thunderAttach = findDamageAttachment(k)
check(thunderAttach ~= nil, "damage smoke attachment created on Thunder hit")
local hasSpark = false
for _, child in thunderAttach.children do if child.Name == "ElectricSpark" then hasSpark = true end end
check(hasSpark, "thunder damage includes electric spark emitter")

-- 4. RaceReset cancels damage smoke immediately
k:SetAttribute("RaceResetSerial", 2)
check(findDamageAttachment(k) == nil, "race reset cancels damage smoke immediately")

-- 5. RaceControlsLocked suppresses damage smoke
k:SetAttribute("KartThunderHitActive", false)
k:SetAttribute("RaceControlsLocked", true)
k:SetAttribute("KartThunderHitActive", true)
check(findDamageAttachment(k) == nil, "locked controls suppress damage smoke")
k:SetAttribute("KartThunderHitActive", false)
k:SetAttribute("RaceControlsLocked", false)

controller.destroy();check(count()==0 and prototype.DescendantAdded.Count()==0 and k:GetAttributeChangedSignal("KartSlickActive").Count()==0,"controller destroy zero objects/connections")
print("PASS: "..n.." actual local Slick & Damage Smoke VFX repeated-round budget, bot visibility and lifecycle checks")
