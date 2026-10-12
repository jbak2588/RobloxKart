local fs,luau,rb=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local n=0;local function check(v,l)assert(v,l);n+=1 end
local function signal()
 local list={};return {Connect=function(_,f)local c={active=true};function c:Disconnect()self.active=false end;table.insert(list,{c,f});return c end,
 Fire=function(_,...)for _,p in table.clone(list) do if p[1].active then p[2](...) end end end,
 Count=function()local count=0;for _,p in list do if p[1].active then count+=1 end end;return count end}
end
local methods={}
local function object(class)
 local props={ClassName=class,Name=class,Destroying=signal(),DescendantAdded=signal(),DescendantRemoving=signal()}
 return setmetatable({props=props,children={},signals={},attrs={}}, {__index=function(self,k)return methods[k] or props[k] end,
 __newindex=function(self,k,v)if k=="Parent" then if props.Parent then local i=table.find(props.Parent.children,self);if i then table.remove(props.Parent.children,i) end end;if v then table.insert(v.children,self) end end;props[k]=v end})
end
function methods:IsA(c)return self.ClassName==c or c=="BasePart" and self.ClassName=="Part" end
function methods:GetAttribute(k)return self.attrs[k] end
function methods:GetAttributeChangedSignal(k)if not self.signals[k] then self.signals[k]=signal() end;return self.signals[k] end
function methods:SetAttribute(k,v)local old=self.attrs[k];self.attrs[k]=v;if old~=v then self:GetAttributeChangedSignal(k):Fire() end end
function methods:FindFirstChild(name)for _,c in self.children do if c.Name==name then return c end end end
function methods:GetChildren()return table.clone(self.children) end
function methods:WaitForChild(name)return assert(self:FindFirstChild(name),name) end
function methods:Emit(n)self.emitted=(self.emitted or 0)+n end
function methods:Clear()self.cleared=true end
function methods:GetDescendants()local out={};for _,c in self.children do table.insert(out,c);for _,v in c:GetDescendants() do table.insert(out,v) end end;return out end
function methods:Destroy()self.Destroying:Fire();for _,c in table.clone(self.children) do c:Destroy() end;self.Parent=nil end
return function(racers,rounds,exercise)
 local workspace=object("Workspace")
 function workspace:Raycast(origin,_direction,_params)
  if self.noGround then return nil end
  return {Position=rb.Vector3.new(origin.X,0,origin.Z),Normal=rb.Vector3.yAxis,
   Instance={FindFirstAncestor=function(_,name)return if name=='Road' then {} else nil end}}
 end
 local prototype=object("Folder");prototype.Name="Prototype";prototype.Parent=workspace
 local track=object('Folder');track.Name='TestTrack';track.Parent=prototype
 local road=object('Folder');road.Name='Road';road.Parent=track
 local surface=object('Part');surface.Name='Road1';surface.Size=rb.Vector3.new(200,1,20000)
 surface.CFrame=rb.CFrame.new(0,-.5,0);surface.Parent=road
 local players={};for i=1,racers do local p=object("Player");p.UserId=i;p.AncestryChanged=signal();p.OnTeleport=signal();p:SetAttribute("RaceState","RACING");p:SetAttribute("RaceSessionId",1);players[i]=p end
 local run={Heartbeat=signal(),RenderStepped=signal()}
 local now=0
 local services={Workspace=workspace,Players={LocalPlayer=players[1],GetPlayerByUserId=function(_,id)return players[id] end},RunService=run}
 local modules={}
 local parent={ShieldWorldRenderer="shield",KartWorldExhaustRenderer="exhaust",KartWorldSpeedRenderer="speed",KartWorldVFXController="observer"}
 local allocated=0
 local env={game={GetService=function(_,name)return services[name] end,ReplicatedStorage={Shared={KDMShieldGeometry="geometry",KDMSpeedSensation="speedProfile"}}},script={Parent=parent},require=function(k)return assert(modules[k],tostring(k)) end,
 Instance={new=function(class)allocated+=1;return object(class)end},RaycastParams={new=function()return {}end},Vector2=rb.Vector2,Vector3=rb.Vector3,CFrame=rb.CFrame,Color3=rb.Color3,ColorSequence=rb.ColorSequence,ColorSequenceKeypoint=rb.ColorSequenceKeypoint,NumberSequence=rb.NumberSequence,NumberSequenceKeypoint=rb.NumberSequenceKeypoint,NumberRange=rb.NumberRange,Enum=rb.Enum,time=function()return now end}
 local function load(path)return luau.load(fs.readFile(path),{environment=env})() end
 modules.geometry=load("src/shared/KDMShieldGeometry.luau")
 modules.shield=load("src/client/ShieldWorldRenderer.luau")
 modules.exhaust=load("src/client/KartWorldExhaustRenderer.luau")
 modules.speedProfile=load("src/shared/KDMSpeedSensation.luau")
 modules.speed=load("src/client/KartWorldSpeedRenderer.luau")
 modules.observer=load("src/client/KartWorldVFXController.luau")
 local function kart(id)
  local k=object("Model");k.Name="Kart_"..id;k:SetAttribute("PrototypeKart",true);k:SetAttribute("KartOwnerUserId",id);k.Parent=prototype
  local c=object("Part");c.Name="Chassis";c.CFrame=rb.CFrame.identity;c.Size=rb.Vector3.new(8,1,10);c.AssemblyLinearVelocity=rb.Vector3.zero;c.Parent=k;k.PrimaryPart=c
  local char=object("Model");char.Parent=workspace
  local head=object("Part");head.Size=rb.Vector3.new(2,2,2);head.CFrame=rb.CFrame.new(0,6,0);head.Parent=char
  local h=object("Humanoid");h.Health=100;h.Parent=char;players[id].Character=char
  local seat=object("Seat");seat.Name="Seat";seat.Occupant=h;seat.Parent=k
  local v=object("Model");v.Name="Visual";v.Parent=k;v:SetAttribute("VisualModelName","KDMV2")
  for _,side in {"Left","Right"} do
   local w=object("Part");w.Size=rb.Vector3.new(1,2,2);w.CFrame=rb.CFrame.new(if side=="Left" then -4 else 4,0,3);w:SetAttribute("VisualMotionRole","RearWheel");w:SetAttribute("WheelSide",side);w:SetAttribute("WheelRadius",1);w:SetAttribute("WheelWidth",1);w.Parent=v
   local m=object("Motor6D");m.Name="VisualMotor";m.C0=w.CFrame;m.Parent=w
   local a=object("Attachment");a.CFrame=rb.CFrame.identity;a:SetAttribute("EffectRole","Exhaust"..side);a.Parent=w
  end
  return k
 end
 local karts={};for i=1,racers do karts[i]=kart(i) end
 local controller=load("src/client/ShieldEffectsController.luau")
 controller.start();load("src/client/KartEffectsController.luau").start()
 check(run.Heartbeat.Count()==1 and run.RenderStepped.Count()==0,"self/remote wrappers share exactly one observer")
 local function tick(dt)now+=dt;run.Heartbeat:Fire(dt) end
 local function count(k,class,name)
  local n=0;for _,o in k:GetDescendants() do if o:IsA(class) and (not name or o.Name:find(name,1,true)) then n+=1 end end;return n
 end
 tick(.3)
 if exercise then exercise({karts=karts,players=players,tick=tick,count=count,object=object,run=run,
  prototype=prototype,workspace=workspace,allocated=function()return allocated end,modules=modules}) end
 for round=1,rounds do
  for id,k in karts do
   local shell=object("Part");shell.Name="RaceItemShield";shell.Parent=k;k:SetAttribute("KartShieldActive",true)
   k:SetAttribute("KartNitroActive",true);k:SetAttribute("KartBoosting",true)
  end
  tick(.01)
  for id,k in karts do
   local model=k:FindFirstChild("KDMShieldWorld");check(model~=nil and count(k,"Model","KDMShieldWorld")==1 and count(model,"Part","EnergyShell")==1,"self and remote Shield visible without duplicate shell")
   check(count(model,"Trail")==8 and count(model,"Part","Orbit")==8,"exactly eight original orbit trails")
   check(count(k,"Trail","ShieldRear")==0 and count(k,"Attachment","ShieldRear")==0,"cancelled rear feature remains absent")
   check(count(k,"ParticleEmitter","BoostFlame")==2,"one exhaust pair per racer")
   local shell=model:FindFirstChild("EnergyShell");check(shell.Size.X>=14 and shell.Size.Y>=11 and shell.Size.Z>=16,"larger Shield envelope")
   for _,p in k:GetDescendants() do if p.Name=="BoostFlame" then check(p.Enabled and p.Rate==65,"replicated Nitro active drives remote emitter") end end
   local before=model:FindFirstChild("Orbit1").CFrame;tick(.1);check(model:FindFirstChild("Orbit1").CFrame~=before,"preserved counterrotating orbit motion")
   local alpha=shell.Transparency;players[id]:SetAttribute("RaceItemBlockedSerial",round);tick(.001);check(shell.Transparency<alpha,"remote authoritative block brightens without camera feedback")
  end
  local total=#prototype:GetDescendants();for i=1,30 do tick(.01) end;check(#prototype:GetDescendants()==total,"unchanged states allocate no instances")
  for id,k in karts do
   k:SetAttribute("KartNitroActive",false);tick(.01)
   for _,p in k:GetDescendants() do if p.Name=="BoostFlame" then check(p.Enabled and p.Rate==30,"Mini Boost remains visible after Nitro ends") end end
   k:SetAttribute("KartBoosting",false);k:SetAttribute("KartShieldActive",false);k:FindFirstChild("RaceItemShield"):Destroy()
  end
  tick(.01);tick(.31)
  for _,k in karts do
   check(not k:FindFirstChild("KDMShieldWorld"),"expiry removes Shield model")
   check(count(k,"Attachment","ShieldRear")==0 and count(k,"Trail")==4,"expiry leaves Drift pair plus two disabled persistent speed trails")
   for _,p in k:GetDescendants() do if p.Name:find("KDMSpeedTrail",1,true) then check(not p.Enabled,"idle speed trails disabled independently of Shield") end end
   for _,p in k:GetDescendants() do if p.Name=="BoostFlame" then check(not p.Enabled,"expired boosts stop remote emission") end end
  end
 end
 for id,k in karts do
  local shell=object("Part");shell.Name="RaceItemShield";shell.Parent=k;k:SetAttribute("KartShieldActive",true)
 end
 tick(.01)
 for id,k in karts do players[id]:SetAttribute("RaceState","FINISHING") end
 tick(.01);for _,k in karts do check(not k:FindFirstChild("KDMShieldWorld") and count(k,"ParticleEmitter")==0 and count(k,"Trail","KDMSpeed")==0 and count(k,"Attachment","KDMSpeed")==0,"finish clears world effects including speed") end
 for id,k in karts do
  players[id]:SetAttribute("RaceState","RACING");players[id]:SetAttribute("RaceSessionId",2);k:SetAttribute("RaceResetSerial",1)
 end
 tick(.01);for _,k in karts do check(k:FindFirstChild("KDMShieldWorld")~=nil,"Rematch active-state recovery") end
 for id,k in karts do k:FindFirstChild("Seat").Occupant=nil end
 tick(.01);for _,k in karts do check(not k:FindFirstChild("KDMShieldWorld") and count(k,"Trail")==0,"seat/respawn loss clears local trails") end
 for id,k in karts do k:Destroy();karts[id]=kart(id) end
 tick(.3)
 for _,k in karts do check(count(k,"ParticleEmitter","BoostFlame")==2,"replacement kart rebinds exactly one pair") end
 controller.destroy();controller.destroy()
 check(run.Heartbeat.Count()==0 and prototype.DescendantAdded.Count()==0 and prototype.DescendantRemoving.Count()==0,"destroy disconnects shared observer")
 for _,k in karts do check(count(k,"ParticleEmitter")==0 and count(k,"Trail","KDMSpeed")==0 and count(k,"Attachment","KDMSpeed")==0,"destroy leaves zero emitters and speed instances") end
 print("PASS: "..n.." production world-VFX checks ("..racers.." racers, "..rounds.." repeated cycles)")
end
