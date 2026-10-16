-- Smooth local rendering of the server's shared, noncolliding showcase bot.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Route=require(Shared:WaitForChild("LobbyDemoRoute"))
local Catalog=require(Shared:WaitForChild("KartCatalog"))
local Factory=require(Shared:WaitForChild("KartVisualFactory"))
local Exhaust=require(script.Parent:WaitForChild("KartWorldExhaustRenderer"))
local Feedback=require(script.Parent:WaitForChild("LobbyDemoFeedback"))
local KartConfig=require(Shared:WaitForChild("KartConfig"))
local Controller={}
local stopCurrent

function Controller.start()
 if stopCurrent or Workspace:GetAttribute("KDMServerRole")~="HUB" then return end
 local player=Players.LocalPlayer
 local hub=Workspace:WaitForChild("KDMHub")
 local zone=hub:WaitForChild("LobbyFrontTestDriveZone",15)
 if not zone then return end
 local connections={}
 local model,render,state,audio
 local function clear()
  if render then render:Disconnect();render=nil end
  if audio then audio:destroy();audio=nil end
  if model then model:Destroy();model=nil end
  state=nil
 end
 local function refresh()
  local nextState=zone:FindFirstChild("LobbyDemoState")
  if nextState==state and model and model.Parent then return end
  clear()
  if not nextState then return end
  local start=nextState:GetAttribute("StartedAt")
  local center=zone:GetAttribute("Center")
  if type(start)~="number" or typeof(center)~="Vector3" then return end
  local definition=Catalog.Entries[nextState:GetAttribute("KartId")]
  if not definition then return end
  state=nextState
  model=Instance.new("Model");model.Name="KDMClientDemoBot"
  model:SetAttribute("LobbyDemoBot",true)
  local visual=Factory.createVisual(definition,false);visual.Parent=model
  -- Explicit origin avoids bounding-box pivot changes when the driver is added.
  local root=Instance.new("Part");root.Name="DemoRoot";root.Transparency=1;root.Size=Vector3.one;root.Parent=model;model.PrimaryPart=root
  local bottom=math.huge
  for _,v in visual:GetDescendants() do if v:IsA("BasePart") then
   for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
    bottom=math.min(bottom,(v.CFrame*Vector3.new(x*v.Size.X/2,y*v.Size.Y/2,z*v.Size.Z/2)).Y)
   end end end
  end end
  local seat=Factory.getDriverSeatLocalCFrame(definition)
  local function driverPart(name,size,offset,color,ball)
   local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=seat*CFrame.new(offset);p.Color=color
   if ball then p.Shape=Enum.PartType.Ball end
   p.Material=Enum.Material.SmoothPlastic;p.Parent=model;return p
  end
  local blue,dark=Color3.fromRGB(35,155,240),Color3.fromRGB(20,29,44)
  driverPart("DriverTorso",Vector3.new(1.7,1.5,.85),Vector3.new(0,.6,0),blue)
  driverPart("DriverHelmet",Vector3.new(1.35,1.35,1.35),Vector3.new(0,1.9,-.05),blue,true)
  driverPart("DriverVisor",Vector3.new(1.15,.5,.2),Vector3.new(0,2,-.68),dark)
  for _,side in {-1,1} do
   driverPart("DriverArm",Vector3.new(.55,.55,1.5),Vector3.new(side*.95,.55,-.65),blue)
   driverPart("DriverLeg",Vector3.new(.65,.6,1.6),Vector3.new(side*.45,-.25,-.9),dark)
  end
  local smoke={}
  for _,side in {-1,1} do
   local attachment=Instance.new("Attachment");attachment.Position=Vector3.new(side*2.1,bottom+.25,2.2);attachment.Parent=root
   table.insert(smoke,Exhaust.createDriftSmoke(attachment,true))
  end
  for _,v in model:GetDescendants() do
   if v:IsA("BasePart") then v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false;v.CastShadow=false
   elseif v:IsA("LuaSourceContainer") or v:IsA("ProximityPrompt") then v:Destroy() end
  end
  audio=Feedback.new(root)
  local function step(dt)
   local elapsed=Workspace:GetServerTimeNow()-start
   local x,z,dx,dz,drift=Route.sample(elapsed)
   local position=center+Vector3.new(x,.22-bottom,z)
   model:PivotTo(CFrame.lookAt(position,position+Vector3.new(dx,0,dz))*CFrame.Angles(0,math.rad(32)*drift,0))
   local slip=32*drift
   local drifting=slip>=5
   local camera=Workspace.CurrentCamera
   local distance=if camera then (camera.CFrame.Position-position).Magnitude else 0
   local lod=if distance>160 then 0 elseif distance>80 or dt>.035 then .5 else 1
   local rate=Exhaust.driftSmokeRate(slip,true,lod,drifting)
   for _,emitter in smoke do emitter.Rate=rate;emitter.Enabled=rate>0 end
   local phase=math.max(0,elapsed)%Route.CycleSeconds
   local boosting=phase>=Route.DonutSeconds and phase<Route.DonutSeconds+KartConfig.MINI_BOOST_DURATION
   audio:update(dt,drifting,boosting)
   model:SetAttribute("DemoDrifting",drifting)
   model:SetAttribute("DemoBoosting",boosting)
  end
  step(0);model.Parent=zone
  render=RunService.RenderStepped:Connect(step)
 end
 stopCurrent=function()
  for _,connection in connections do connection:Disconnect() end
  clear();stopCurrent=nil
 end
 table.insert(connections,zone.ChildAdded:Connect(function(v) if v.Name=="LobbyDemoState" then refresh() end end))
 table.insert(connections,zone.ChildRemoved:Connect(function(v) if v==state then refresh() end end))
 table.insert(connections,player:GetAttributeChangedSignal("RaceState"):Connect(refresh))
 table.insert(connections,player:GetAttributeChangedSignal("KDMRoutePending"):Connect(refresh))
 table.insert(connections,zone.Destroying:Connect(function() Controller.stop() end))
 refresh()
end
function Controller.stop() if stopCurrent then stopCurrent() end end
return Controller
