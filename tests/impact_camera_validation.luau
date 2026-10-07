local fs,luau,rb=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local n=0
local function check(v,l)assert(v,l);n+=1 end
local function signal()
 local list={};return {Connect=function(_,f)local c={active=true};function c:Disconnect()self.active=false end;table.insert(list,{c,f});return c end,
 Fire=function(_,...)for _,p in table.clone(list) do if p[1].active then p[2](...) end end end,
 Count=function()local count=0;for _,p in list do if p[1].active then count+=1 end end;return count end}
end
local function object()
 local o={attrs={},signals={},Parent=true,Destroying=signal()}
 function o:GetAttribute(k)return self.attrs[k] end
 function o:GetAttributeChangedSignal(k)if not self.signals[k] then self.signals[k]=signal() end;return self.signals[k] end
 function o:GetPropertyChangedSignal(k)return self:GetAttributeChangedSignal(k) end
 function o:SetAttribute(k,v)local old=self.attrs[k];self.attrs[k]=v;if old~=v then self:GetAttributeChangedSignal(k):Fire() end end
 return o
end
local player=object();player.CharacterRemoving=signal();player.AncestryChanged=signal();player.OnTeleport=signal()
local kart=object();kart:SetAttribute("PrototypeKart",true);kart:SetAttribute("RaceResetSerial",0)
local seat=object();seat.Parent=kart;seat:SetAttribute("PrototypeKartSeat",true)
local human={SeatPart=seat,Health=100}
player.Character={FindFirstChildOfClass=function()return human end}
player:SetAttribute("RaceState","RACING");player:SetAttribute("RaceSessionId",1)
local camera={CFrame=rb.CFrame.identity,CameraSubject=human,CameraType="Custom",FieldOfView=70}
local workspace=object();workspace.CurrentCamera=camera
local run={Heartbeat=signal(),bindings={}}
function run:BindToRenderStep(name,priority,f)self.bindings[name]={priority,f} end
function run:UnbindFromRenderStep(name)self.bindings[name]=nil end
local now=0
local config=luau.load(fs.readFile("src/shared/KDMItemVFXConfig.luau"))()
local motion=luau.load(fs.readFile("src/shared/KDMImpactCameraMotion.luau"),{environment={Vector3=rb.Vector3}})()
local node={WaitForChild=function(self,name)if name=="KDMItemVFXConfig" or name=="KDMImpactCameraMotion" then return name end;return self end}
local services={Players={LocalPlayer=player},Workspace=workspace,RunService=run,ReplicatedStorage=node}
local controller=luau.load(fs.readFile("src/client/KDMImpactCameraController.luau"),{environment={
 game={GetService=function(_,name)return services[name] end},require=function(name)return if name=="KDMItemVFXConfig" then config else motion end,
 Vector3=rb.Vector3,CFrame=rb.CFrame,Enum={RenderPriority={Camera={Value=200}}},time=function()return now end}})()
local function count()local c=0;for _ in run.bindings do c+=1 end;return c end
local function frame(t,base)
 now=t
 local pre=run.bindings.KDMImpactCameraRestore;if pre then pre[2]() end
 check(camera.CFrame==base,"last additive write restored before camera smoothing")
 -- Existing camera owner writes a fresh base at Camera+1.
 camera.CFrame=base
 local post=run.bindings.KDMImpactCameraOffset;if post then post[2]() end
end
controller.start();controller.start()
check(run.Heartbeat.Count()==1 and count()==0,"start idempotent, idle zero render bindings")
local other=object();other:SetAttribute("KartMissileHitActive",true);check(count()==0,"another kart/shooter/observer cannot shake own camera")
player:SetAttribute("RaceItemBlockedSerial",1);check(count()==0,"Shield block no full shake")
for _,kind in {"Missile","Thunder"} do
 kart:SetAttribute("Kart"..kind.."HitActive",false)
 now=0;kart:SetAttribute("Kart"..kind.."HitActive",true)
 check(count()==2,"target real edge creates only pre/post bindings")
 for i=0,math.ceil(config[kind].CameraShake.Duration*100)+2 do frame(i/100,rb.CFrame.identity) end
 check(count()==0 and camera.CFrame==rb.CFrame.identity,"expired exact zero residual and next frame zero drift")
 check(camera.CameraType=="Custom" and camera.CameraSubject==human and camera.FieldOfView==70,"camera ownership preserved")
end
for _,reason in {"RaceResetSerial","RaceState","RaceSessionId","SeatLoss","CharacterRemoving","CurrentCamera","Teleport","Leave"} do
 player:SetAttribute("RaceState","RACING");human.SeatPart=seat;run.Heartbeat:Fire()
 kart:SetAttribute("KartMissileHitActive",false);now=0;kart:SetAttribute("KartMissileHitActive",true)
 frame(.02,rb.CFrame.identity);check(count()==2,"active before cleanup "..reason)
 if reason=="RaceResetSerial" then kart:SetAttribute(reason,1)
 elseif reason=="RaceState" then player:SetAttribute(reason,"FINISHING")
 elseif reason=="RaceSessionId" then player:SetAttribute(reason,2)
 elseif reason=="SeatLoss" then human.SeatPart=nil;run.Heartbeat:Fire()
 elseif reason=="CharacterRemoving" then player.CharacterRemoving:Fire()
 elseif reason=="CurrentCamera" then workspace:GetPropertyChangedSignal(reason):Fire()
 elseif reason=="Teleport" then player.OnTeleport:Fire()
 else player.AncestryChanged:Fire(player,nil) end
 check(count()==0 and camera.CFrame==rb.CFrame.identity,"cleanup restores and unbinds "..reason)
end
check(run.Heartbeat.Count()==0,"leave removes controller observer")
controller.start();player:SetAttribute("IsBot",true);run.Heartbeat:Fire()
kart:SetAttribute("KartThunderHitActive",false);kart:SetAttribute("KartThunderHitActive",true)
check(count()==0,"bot has no camera dependency/event")
controller.destroy();check(run.Heartbeat.Count()==0 and count()==0,"explicit destroy removes all connections")
print("PASS: "..n.." actual impact camera controller target isolation, owner ordering, residual and lifecycle checks")
