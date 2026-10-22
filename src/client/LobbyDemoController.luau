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
local ItemConfig=require(Shared:WaitForChild('RaceItemConfig'))
local VFX=require(Shared:WaitForChild('KDMItemVFXConfig'))
local Policy=require(Shared:WaitForChild('LobbyPracticePolicy'))
local Controller={}
local stopCurrent

function Controller.start()
 if stopCurrent or Workspace:GetAttribute("KDMServerRole")~="HUB" then return end
 local player=Players.LocalPlayer
 local hub=Workspace:WaitForChild("KDMHub")
 -- The server announces the active zone after building it. Initial replication
 -- may lag the HUB model, so wait briefly without binding a per-frame watcher.
 local deadline=os.clock()+15
 local name=Workspace:GetAttribute('LobbyDriveZoneName')
 while type(name)~='string'and os.clock()<deadline do
  task.wait(.1);name=Workspace:GetAttribute('LobbyDriveZoneName')
 end
 local zone=hub:FindFirstChild(if type(name)=='string'then name else 'LobbyFrontTestDriveZone')
 if not zone and type(name)=='string'then zone=hub:WaitForChild(name,15)end
 if not zone then return end
 local route=if zone:GetAttribute('DriveGeometry')=='ROOKIE_LOOP_V1'then require(Shared:WaitForChild('RookieLoopDemoRoute'))else Route
 local connections={}
 local render,state
 local botList={}
 local function clear()
  if render then render:Disconnect();render=nil end
  for _,b in botList do
   if b.audio then b.audio:destroy() end
   if b.boostVisuals then b.boostVisuals:destroy() end
   if b.model then b.model:Destroy() end
  end
  botList={}
  state=nil
 end
 local function refresh()
  local nextState=zone:FindFirstChild("LobbyDemoState")
  if nextState==state and #botList>0 then return end
  clear()
  if not nextState then return end
  local start=nextState:GetAttribute("StartedAt")
  local center=zone:GetAttribute("Center")
  if type(start)~="number" or typeof(center)~="Vector3" then return end
  state=nextState

 local isRookie=zone:GetAttribute('DriveGeometry')=='ROOKIE_LOOP_V1'
 local Layout=if isRookie then require(Shared:WaitForChild('HubParkRookieLoopLayout')) else nil
 local fleet=if isRookie then Policy.BotFleet else {Policy.BotFleet[1]}

  for index,cfg in fleet do
   local botKartId=nextState:GetAttribute("BotKartId_"..cfg.id) or cfg.kartId
   local definition=Catalog.Entries[botKartId] or Catalog.Entries[nextState:GetAttribute("KartId")]
   if not definition then continue end

   local botDelay=cfg.delay
   local model=Instance.new("Model")
   model.Name=if cfg.id==1 then "KDMClientDemoBot" else "KDMClientDemoBot_"..cfg.id
   model:SetAttribute("LobbyDemoBot",true)
   model:SetAttribute("BotIndex",cfg.id)
   local visual=Factory.createVisual(definition,false);visual.Parent=model
   local root=Instance.new("Part");root.Name="DemoRoot";root.Transparency=1;root.Size=Vector3.one;root.Parent=model;model.PrimaryPart=root
   local seat=Factory.getDriverSeatLocalCFrame(definition)
   local function driverPart(pname,size,offset,color,ball)
    local p=Instance.new("Part");p.Name=pname;p.Size=size;p.CFrame=seat*CFrame.new(offset);p.Color=color
    if ball then p.Shape=Enum.PartType.Ball end
    p.Material=Enum.Material.SmoothPlastic;p.Parent=model;return p
   end
   local driverColor=cfg.driverColor or Color3.fromRGB(35,155,240)
   local dark=Color3.fromRGB(20,29,44)
   driverPart("DriverTorso",Vector3.new(1.85,1.9,1.0),Vector3.new(0,1.67,0),driverColor)
   driverPart("DriverHelmet",Vector3.new(1.5,1.5,1.5),Vector3.new(0,3.17,-.05),driverColor,true)
   driverPart("DriverVisor",Vector3.new(1.3,.55,.25),Vector3.new(0,3.27,-.75),dark)
   for _,side in {-1,1} do
    driverPart("DriverArm",Vector3.new(.65,.65,1.6),Vector3.new(side*1.05,1.62,-.65),driverColor)
    driverPart("DriverLeg",Vector3.new(.7,.65,1.7),Vector3.new(side*.5,.67,-.9),dark)
   end
   local scale=route.VisualScale or 1.0
   if scale~=1.0 then model:ScaleTo(scale) end
   model:SetAttribute("DemoVisualScale",scale)
   local smoke={}
   for _,side in {-1,1} do
    local attachment=Instance.new("Attachment");attachment.Position=Vector3.new(side*2.1*scale,-1.0*scale,2.2*scale);attachment.Parent=root
    table.insert(smoke,Exhaust.createDriftSmoke(attachment,true))
   end
   for _,v in model:GetDescendants() do
    if v:IsA("BasePart") then v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false;v.CastShadow=false
    elseif v:IsA("LuaSourceContainer") or v:IsA("ProximityPrompt") then v:Destroy() end
   end
   local audio=Feedback.new(root)
   local badge=Instance.new('BillboardGui');badge.Name='PracticeBotFeedback';badge.Size=UDim2.fromOffset(200,32);badge.StudsOffset=Vector3.new(0,6,0);badge.AlwaysOnTop=false;badge.Parent=root
   local label=Instance.new('TextLabel');label.Size=UDim2.fromScale(1,1);label.BackgroundColor3=Color3.fromRGB(16,25,35);label.BackgroundTransparency=.15
   label.TextColor3=Color3.fromRGB(65,225,245);label.TextSize=15;label.Font=Enum.Font.GothamBold;label.BorderSizePixel=0;label.Parent=badge
   local boostVisuals=Exhaust.createBoostVisuals(visual)
   table.insert(botList,{
    id=cfg.id,delay=botDelay,model=model,visual=visual,root=root,smoke=smoke,audio=audio,
    badge=badge,label=label,boostVisuals=boostVisuals,visualDrift=0,
    proxyName=if cfg.id==1 then 'LobbyPracticeBot' else 'LobbyPracticeBot_'..cfg.id,
   })
  end

  local function step(dt)
   local now=Workspace:GetServerTimeNow()
   for _,b in botList do
    local botStart=nextState:GetAttribute("BotStartedAt_"..b.id) or (start+b.delay)
    if now<botStart then
     if b.model.Parent then b.model.Parent=nil end
     continue
    end
    if not b.model.Parent then b.model.Parent=zone end
    local proxy=zone:FindFirstChild(b.proxyName)
    local elapsed=now-botStart
    local sampled=proxy and proxy:GetAttribute('SampledAt')
    if type(sampled)=='number' and type(proxy:GetAttribute('RouteElapsed'))=='number' then
     elapsed=proxy:GetAttribute('RouteElapsed')+math.clamp(now-sampled,0,.3)*(proxy:GetAttribute('RouteRate')or 1)
    end
    local x,z,dx,dz,drift,_,pattern,boosting=route.sample(elapsed,KartConfig.MINI_BOOST_DURATION)
    b.visualDrift+=(drift-b.visualDrift)*(1-math.exp(-math.max(0,dt)*10))

    local slick=proxy and proxy:GetAttribute('KartSlickActive')==true
    local missile=proxy and proxy:GetAttribute('KartMissileHitActive')==true
    local thunder=proxy and proxy:GetAttribute('KartThunderHitActive')==true
    local hit=slick or missile or thunder

    if hit then boosting=false;b.visualDrift=0 end

    -- Sync combat hit attributes so KDMItemVFXController renders official race smoke & electrical sparks
    b.model:SetAttribute('KartMissileHitActive',missile)
    b.model:SetAttribute('KartThunderHitActive',thunder)
    b.model:SetAttribute('KartSlickActive',slick)

    -- Official race-identical hit handling: speed attenuation + smoke/sparks, no unnatural tumbling
    local spin=if slick then math.rad(VFX.Slick.SpinDegrees)*math.clamp((now-(proxy:GetAttribute('LobbySlickStartedAt')or 0))/ItemConfig.SLICK_EFFECT_DURATION,0,1)else 0

    local groundY=if Layout and Layout.height then Layout.height(x,z)else 0
    local ny,nz=1,0
    if Layout and Layout.normal then local _nx,_ny,_nz=Layout.normal(x,z);ny,nz=_ny,_nz end

    local position=center+Vector3.new(x,groundY+0.463,z)
    local basis=CFrame.lookAt(position,position+Vector3.new(dx,0,dz),Vector3.new(0,ny,nz))
    b.model:PivotTo(basis*CFrame.Angles(0,if slick then spin else math.rad(32)*b.visualDrift,0))

    -- Target practice feedback badge
    local customMsg=if missile then "MISSILE HIT!" elseif thunder then "SHOCKED!" elseif slick then "SLIPPED!" else (proxy and proxy:GetAttribute('LobbyPracticeMessage'))
    local showBadge=hit or (proxy~=nil and now-(proxy:GetAttribute('LobbyPracticeMessageAt')or -math.huge)<1.2)
    b.badge.Enabled=showBadge
    if showBadge then
     b.label.Text=customMsg or ''
     b.label.TextColor3=if thunder then Color3.fromRGB(255,235,80) elseif missile then Color3.fromRGB(255,90,80) else Color3.fromRGB(65,225,245)
    end

    -- Drift particles & audio
    local slip=if slick then 32 elseif hit then 0 else 32*math.abs(drift)
    local drifting=slip>=5 or slick==true
    local camera=Workspace.CurrentCamera
    local distance=if camera then (camera.CFrame.Position-position).Magnitude else 0
    local lod=if distance>160 then 0 elseif distance>80 or dt>.035 then .5 else 1
    local rate=Exhaust.driftSmokeRate(slip,true,lod,drifting)
    for _,emitter in b.smoke do emitter.Rate=rate;emitter.Enabled=rate>0 end
    b.boostVisuals:update(boosting,lod)
    b.audio:update(dt,drifting,boosting)
    b.model:SetAttribute("DemoDrifting",drifting)
    b.model:SetAttribute("DemoBoosting",boosting)
    b.model:SetAttribute("DemoPattern",pattern)
    b.model:SetAttribute("DemoDriftDirection",math.sign(drift))
   end
  end
  step(0)
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
