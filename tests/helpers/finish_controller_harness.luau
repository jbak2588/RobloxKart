local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local function signal()
 local listeners={}
 return {Connect=function(_,fn)
  local binding={fn=fn,active=true};table.insert(listeners,binding)
  return {Disconnect=function()binding.active=false end}
 end,Fire=function(_,...) for _,binding in table.clone(listeners) do if binding.active then binding.fn(...) end end end,
 Count=function()local n=0;for _,b in listeners do if b.active then n+=1 end end;return n end}
end
local methods={}
local allocated=0
local function object(class,name)
 allocated+=1
 local values={ClassName=class,Name=name or class,Enabled=true,Transform=rb.CFrame.identity}
 local o=setmetatable({children={},attrs={},props={},signals={},ChildAdded=signal(),ChildRemoved=signal(),
  CharacterAdded=signal(),CharacterRemoving=signal(),OnTeleport=signal()},
  {__index=function(self,key)return methods[key] or values[key]end,
   __newindex=function(self,key,value)
    local old=values[key]
    if key=='Parent' and old~=value then
     values[key]=value
     if old then local i=table.find(old.children,self);if i then table.remove(old.children,i)end;old.ChildRemoved:Fire(self)end
     if value then table.insert(value.children,self);value.ChildAdded:Fire(self)end
    else values[key]=value end
    if old~=value and self.props[key] then self.props[key]:Fire()end
   end})
 return o
end
function methods:IsA(class)return self.ClassName==class or (class=='BasePart' and self.ClassName=='Part')end
function methods:GetChildren()return table.clone(self.children)end
function methods:GetDescendants()local result={};for _,c in self.children do table.insert(result,c);for _,v in c:GetDescendants()do table.insert(result,v)end end;return result end
function methods:FindFirstChild(name)for _,c in self.children do if c.Name==name then return c end end end
function methods:FindFirstChildOfClass(class)for _,c in self.children do if c:IsA(class)then return c end end end
function methods:WaitForChild(name)return assert(self:FindFirstChild(name),name)end
function methods:IsDescendantOf(parent)local p=self.Parent;while p do if p==parent then return true end;p=p.Parent end;return false end
function methods:GetAttribute(name)return self.attrs[name]end
function methods:SetAttribute(name,value)local old=self.attrs[name];self.attrs[name]=value;if old~=value and self.signals[name]then self.signals[name]:Fire()end end
function methods:GetAttributeChangedSignal(name)if not self.signals[name]then self.signals[name]=signal()end;return self.signals[name]end
function methods:GetPropertyChangedSignal(name)if not self.props[name]then self.props[name]=signal()end;return self.props[name]end
function methods:Emit(n)self.emitted=(self.emitted or 0)+n;self.emitCalls=(self.emitCalls or 0)+1 end
function methods:Destroy()for _,c in self:GetChildren()do c:Destroy()end;self.Parent=nil;self.destroyed=true end
local function child(parent,class,name)local o=object(class,name);o.Parent=parent;return o end
return function()
 local player=object('Player','LocalPlayer');local gui=child(player,'PlayerGui','PlayerGui')
 local kart=object('Model','Kart');kart.Parent=object('Folder','World')
 local chassis=child(kart,'Part','Chassis');kart.PrimaryPart=chassis
 local seat=child(kart,'VehicleSeat','Seat');seat:SetAttribute('PrototypeKartSeat',true)
 local pre=signal();local timers={}
 local finish=luau.load(fs.readFile('src/shared/KDMFinishPresentation.luau'))()
 local shared={WaitForChild=function(_,name)return name end}
 local services={Players={LocalPlayer=player},RunService={PreSimulation=pre},ReplicatedStorage={WaitForChild=function()return shared end}}
 local env={game={GetService=function(_,name)return assert(services[name],name)end},require=function()return finish end,
  Instance={new=object},Vector3=rb.Vector3,Vector2=rb.Vector2,CFrame=rb.CFrame,Enum=rb.Enum,
  Color3=rb.Color3,ColorSequence=rb.ColorSequence,NumberSequence=rb.NumberSequence,NumberSequenceKeypoint=rb.NumberSequenceKeypoint,NumberRange=rb.NumberRange,
  task={delay=function(seconds,fn)table.insert(timers,{seconds=seconds,fn=fn})end}}
 local function character(rig,shoulder,jointClass,armParent)
  local model=object('Model','Character')
  local humanoid=child(model,'Humanoid','Humanoid');humanoid.SeatPart=seat
  local torso=child(model,'Part',rig)
  local parent=if armParent then child(model,'Part','RightUpperArm') else torso
  local joint=child(parent,jointClass or 'Motor6D',shoulder);joint.Transform=rb.CFrame.Angles(.03,.04,.05)
  player.Character=model
  return model,joint,humanoid
 end
 player:SetAttribute('RaceSessionId',901);player:SetAttribute('RaceState','RACING')
 player:SetAttribute('RaceFinishPhase','NONE');player:SetAttribute('RaceFinishPosition',1);player:SetAttribute('RaceParticipantCount',2)
 local model,joint,humanoid=character('UpperTorso','RightShoulder')
 return {player=player,gui=gui,kart=kart,chassis=chassis,seat=seat,pre=pre,timers=timers,object=object,child=child,
  character=character,joint=joint,humanoid=humanoid,finish=finish,rb=rb,
  allocated=function()return allocated end,load=function(path)return luau.load(fs.readFile(path),{environment=env})()end}
end
