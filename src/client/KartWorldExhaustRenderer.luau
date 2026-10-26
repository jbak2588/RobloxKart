local _Players = game:GetService("Players")
local _RunService = game:GetService("RunService")
local Workspace = game:GetService('Workspace')
local Envelope = require(script.Parent.BoostFlameEnvelope)

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local CRUISE_FLAME_INTERVAL = 0.45
local CRUISE_MIN_SPEED = 10

local function _getKart(seatPart: BasePart?): Model?
	if not seatPart or seatPart:GetAttribute("PrototypeKartSeat") ~= true then
		return nil
	end
	local kart = seatPart.Parent
	if kart and kart:IsA("Model") and kart:GetAttribute("PrototypeKart") == true then
		return kart
	end
	return nil
end

local function makeAttachment(parent: BasePart, name: string, position: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = parent
	return attachment
end

local function makeSmoke(attachment: Attachment, isLobby: boolean): ParticleEmitter
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "DriftSmoke"
	smoke.Texture = SMOKE_TEXTURE
	smoke.Enabled = false
	smoke.Rate = 0
	smoke.Lifetime = if isLobby then NumberRange.new(6.5, 8.0) else NumberRange.new(3.0, 4.2)
	smoke.Speed = if isLobby then NumberRange.new(4.5, 9.5) else NumberRange.new(3.5, 7.5)
	smoke.SpreadAngle = if isLobby then Vector2.new(48, 28) else Vector2.new(36, 20)
	smoke.Acceleration = if isLobby then Vector3.new(0, 0.65, 0) else Vector3.new(0, 0.45, 0)
	smoke.Drag = if isLobby then 1.65 else 1.8
	smoke.Rotation = NumberRange.new(-180, 180)
	smoke.RotSpeed = NumberRange.new(-28, 28)
	smoke.LightInfluence = 0
	smoke.VelocityInheritance = 0.15
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Color = ColorSequence.new(Color3.fromRGB(248, 250, 255))
	smoke.Size = if isLobby then NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2, 0.15),
		NumberSequenceKeypoint.new(0.18, 3.4, 0.3),
		NumberSequenceKeypoint.new(0.50, 6.8, 0.6),
		NumberSequenceKeypoint.new(0.80, 9.6, 0.8),
		NumberSequenceKeypoint.new(1, 11.5, 1.0),
	}) else NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9, 0.1),
		NumberSequenceKeypoint.new(0.20, 2.2, 0.2),
		NumberSequenceKeypoint.new(0.50, 4.2, 0.4),
		NumberSequenceKeypoint.new(1, 6.5, 0.5),
	})
	smoke.Transparency = if isLobby then NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.06),
		NumberSequenceKeypoint.new(0.18, 0.16),
		NumberSequenceKeypoint.new(0.45, 0.48),
		NumberSequenceKeypoint.new(0.75, 0.78),
		NumberSequenceKeypoint.new(0.92, 0.92),
		NumberSequenceKeypoint.new(1, 1),
	}) else NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.20, 0.58),
		NumberSequenceKeypoint.new(0.50, 0.74),
		NumberSequenceKeypoint.new(0.80, 0.88),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Parent = attachment
	return smoke
end

local function makeTrail(parent: BasePart, first: Attachment, second: Attachment, isLobby: boolean): Trail
	local trail = Instance.new("Trail")
	trail.Name = "DriftTireTrail"
	trail.Attachment0 = first
	trail.Attachment1 = second
	trail.Enabled = false
	trail.Lifetime = if isLobby then 6.0 else 2.5
	trail.MaxLength = 180
	trail.MinLength = 0.1
	trail.Color = ColorSequence.new(Color3.fromRGB(8, 9, 11))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.16),
		NumberSequenceKeypoint.new(0.65, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = parent
	return trail
end

local function makeLegacyFlame(attachment: Attachment): ParticleEmitter
	local flame = Instance.new("ParticleEmitter")
	flame.Name = "BoostFlame"
	flame.Enabled = false
	flame.Rate = 30
	flame.Lifetime = NumberRange.new(0.09, 0.19)
	flame.Speed = NumberRange.new(8, 14)
	flame.EmissionDirection = Enum.NormalId.Back
	flame.SpreadAngle = Vector2.new(9, 9)
	flame.VelocityInheritance = 0.15
	flame.LightEmission = 0.85
	flame.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 110)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 145, 35)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 75, 25)),
	})
	flame.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0.06),
	})
	flame.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	flame.Parent = attachment
	return flame
end

local function makeCruiseFlame(attachment: Attachment): ParticleEmitter
	local flame = Instance.new("ParticleEmitter")
	flame.Name = "CruiseFlame"
	flame.Enabled = false
	flame.Rate = 0
	flame.Lifetime = NumberRange.new(0.1, 0.18)
	flame.Speed = NumberRange.new(5, 8)
	flame.EmissionDirection = Enum.NormalId.Back
	flame.SpreadAngle = Vector2.new(8, 8)
	flame.VelocityInheritance = 0.15
	flame.LightEmission = 0.6
	flame.Color = ColorSequence.new(Color3.fromRGB(255, 205, 80), Color3.fromRGB(255, 110, 35))
	flame.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.32),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	flame.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	flame.Parent = attachment
	return flame
end

-- Clone actual template ParticleEmitter/PointLight children, not a reconstruction.
local function makeFlames(point,legacy)
 if legacy then return {makeLegacyFlame(point)},{} end
 local role=point:GetAttribute('EffectRole')
 local template=game:GetService('ReplicatedStorage'):WaitForChild('KDMTemplateResources'):WaitForChild(if role=='ExhaustLeft' then 'LeftNitroEmitterAttachment' else 'RightNitroEmitterAttachment')
 local attachment=template:Clone();attachment.Name='TemplateNitro';attachment.CFrame=CFrame.identity;attachment.Parent=point
 local flames,lights={},{}
 for _,o in attachment:GetChildren() do
  if o:IsA('ParticleEmitter') then o:SetAttribute('TemplateRate',o.Rate);o.Enabled=false;table.insert(flames,o) end
  if o:IsA('PointLight') then o.Enabled=false;table.insert(lights,o) end
 end
 return flames,lights,attachment
end

local Renderer = {}
-- Shared by the ambient Lobby demo and human karts: one smoke profile/rate owner.
Renderer.createDriftSmoke = makeSmoke
-- Kinematic showcase adapter; clones the exact human exhaust templates and
-- applies the same active Mini Boost density/LOD without requiring a human seat.
function Renderer.createBoostVisuals(visual)
 local flames,lights,attachments={},{},{}
 for _,point in visual:GetDescendants() do
  local role=point:GetAttribute("EffectRole")
  if point:IsA("Attachment") and (role=="ExhaustLeft" or role=="ExhaustRight") then
   local fs,ls,a=makeFlames(point,false)
   for _,f in fs do table.insert(flames,f) end
   for _,l in ls do table.insert(lights,l) end
   table.insert(attachments,a)
  end
 end
 local previous=false
 local record={}
 function record:update(active,lod)
  for _,f in flames do
   f.Rate=(f:GetAttribute("TemplateRate") or 30)*.7*lod
   f.Enabled=active and lod>0
   if previous and not active then f:Clear() end
  end
  for _,l in lights do l.Enabled=active and lod>0 end
  previous=active
 end
 function record:destroy()for _,a in attachments do a:Destroy() end end
 return record
end
function Renderer.driftSmokeRate(slip,isLobby,lod,drift)
 return if drift then (if isLobby then math.clamp(32+(slip-6)*2.0,0,68) else math.clamp(16+(slip-6)*1.0,0,34))*lod else 0
end
function Renderer.new(kart)
 local chassis, visual = kart:FindFirstChild("Chassis"), kart:FindFirstChild("Visual")
 if not chassis or not visual then return nil end
 local wheels,anchors={},{}
 for _,o in visual:GetDescendants() do
  if o:IsA("BasePart") and o:GetAttribute("VisualMotionRole")=="RearWheel" and o:FindFirstChild("VisualMotor") and type(o:GetAttribute("WheelRadius"))=="number" and type(o:GetAttribute("WheelWidth"))=="number" then wheels[o:GetAttribute("WheelSide")]=o end
  if o:IsA("Attachment") then local role=o:GetAttribute("EffectRole");if role=="ExhaustLeft" or role=="ExhaustRight" then anchors[role]=o end end
 end
 if not wheels.Left or not wheels.Right or not anchors.ExhaustLeft or not anchors.ExhaustRight then return nil end
 local isLobby = kart:GetAttribute("LobbyKart") == true
  or (kart.Parent ~= nil and kart.Parent.Name == "LobbyFrontTestDriveZone")
  or (kart.Name:find("LobbyKart") ~= nil)
 local attachments, smokes, trails, flames, cruiseFlames = {}, {}, {}, {}, {}
 local lights={}
 local contacts={}
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
 local surfaceRoot=nil
 local visualRoads=nil;local roadHint=1;local ribbonStart=1
 local tireSurfaceLift=0
 local function updateSurfaceFilter()
  if surfaceRoot and surfaceRoot.Parent then return true end
  local parent=kart.Parent
  if isLobby then
   surfaceRoot=parent and parent:FindFirstChild("LobbyFrontSmoothFloor")
   tireSurfaceLift=0
   if parent and parent:GetAttribute('DriveGeometry')=='ROOKIE_LOOP_V1' then
    surfaceRoot=parent:FindFirstChild('G2SafetyGround')
    -- Park road slices deliberately cannot be queried. Raycast the existing
    -- flat support, then draw on the visual road top (.35 high + .02 offset).
    tireSurfaceLift=.37
   end
  else
   local track=parent and parent:FindFirstChild("TestTrack")
   surfaceRoot=track and track:FindFirstChild("Road")
   local geometry=track and track:GetAttribute('GeometryId')
   local metro=track and track:GetAttribute('TrackId')=='Track01Metro' and geometry=='PracticeCircuitV1'
   if surfaceRoot and (geometry=='PracticeFigure8V1' or metro) then
    -- Figure-8 and Metro Road slices are intentionally non-queryable. Keep that contract;
    -- contact is the top plane of the bounded visual slices, not the grass support.
    visualRoads={}
    for _,p in surfaceRoot:GetChildren()do if p:IsA('BasePart')then table.insert(visualRoads,p)end end
    ribbonStart=#visualRoads+1
    local environment=track:FindFirstChild('Environment')
    if environment then for _,p in environment:GetChildren()do
     if p:IsA('BasePart')and p.Name:match('^CrossoverRibbon')then table.insert(visualRoads,p)end
    end end
    if #visualRoads==0 then visualRoads=nil end
   end
  end
  params.FilterDescendantsInstances=if surfaceRoot then {surfaceRoot} else {}
  return surfaceRoot~=nil
 end
 for _, wheel in visual:GetDescendants() do
  if wheel:IsA("BasePart") and wheel:GetAttribute("VisualMotionRole") == "RearWheel" then
   local motor, radius, width = wheel:FindFirstChild("VisualMotor"), wheel:GetAttribute("WheelRadius"), wheel:GetAttribute("WheelWidth")
   if motor and type(radius)=="number" and type(width)=="number" then
    local side=wheel:GetAttribute("WheelSide")
    local contact=motor.C0.Position-Vector3.yAxis*(radius-.01)
    local point=makeAttachment(chassis,"DriftSmokePoint"..side,contact+Vector3.yAxis*.12)
    local edge=Vector3.xAxis*(width*.45)
    local a=makeAttachment(chassis,"TireEdgeA"..side,contact-edge)
    local b=makeAttachment(chassis,"TireEdgeB"..side,contact+edge)
    table.insert(attachments,point);table.insert(attachments,a);table.insert(attachments,b)
    table.insert(smokes,makeSmoke(point,isLobby));table.insert(trails,makeTrail(chassis,a,b,isLobby))
    table.insert(contacts,{position=contact,a=a,b=b,width=width*.45})
   end
  end
 end
 for _, point in visual:GetDescendants() do
  local role=point:GetAttribute("EffectRole")
  if point:IsA("Attachment") and (role=="ExhaustLeft" or role=="ExhaustRight") then
   local fs,ls,a=makeFlames(point,kart:GetAttribute("KDMUseLegacyExhaust")==true)
   for _,f in fs do table.insert(flames,f) end
   for _,l in ls do table.insert(lights,l) end
   if a then table.insert(attachments,a) end
   table.insert(cruiseFlames,makeCruiseFlame(point))
  end
 end
 local record={flames=flames,smokes=smokes,trails=trails,attachments=attachments,cruise=cruiseFlames}
 function record:destroy()
  for _, list in {flames,smokes,trails,cruiseFlames,attachments} do for _,o in list do o:Destroy() end end
 end
 if #smokes~=2 or #trails~=2 or #flames~= (if kart:GetAttribute("KDMUseLegacyExhaust")==true then 2 else 6) then record:destroy();return nil end
 local previousNitro, previousBoost, previousDrift = nil,nil,nil
 local envelope=Envelope.new()
 local flameStyles={}
 for _,f in flames do
  local sizes={}
  for level=0,12 do
   local points={}
   for _,kp in f.Size.Keypoints do table.insert(points,NumberSequenceKeypoint.new(kp.Time,kp.Value*level/12,kp.Envelope*level/12)) end
   sizes[level]=NumberSequence.new(points)
  end
  flameStyles[f]={sizes=sizes,brightness=f.Brightness or 1,emission=f.LightEmission}
 end
 local lightStyles={};for _,l in lights do lightStyles[l]={brightness=l.Brightness,range=l.Range}end
 local cruiseElapsed=0
 local groundElapsed=0
 local farElapsed=0
 local wasCulled=false
 local grounded={false,false}

 local function checkIsLocalKart(): boolean
  local lp = _Players.LocalPlayer
  if not lp then return false end
  if kart:GetAttribute("LocalKart") == true then return true end
  if (kart:GetAttribute("KartOwnerUserId") or kart:GetAttribute("LobbyOwnerUserId")) == lp.UserId then return true end
  local char = lp.Character
  if char then
   local hum = if typeof(char.FindFirstChildOfClass) == "function" then char:FindFirstChildOfClass("Humanoid") else char:FindFirstChild("Humanoid")
   local seatPart = hum and hum.SeatPart
   if seatPart and seatPart.Parent == kart then return true end
  end
  return false
 end

 function record:update(dt,enabled)
  local camera=Workspace.CurrentCamera
  local distance=if camera then (camera.CFrame.Position-chassis.Position).Magnitude else 0
  local isLocal=checkIsLocalKart()
  if not isLocal and distance>160 then
   if not wasCulled then
    for _,list in {flames,smokes,cruiseFlames} do for _,effect in list do effect.Enabled=false;effect:Clear() end end
    for _,trail in trails do trail.Enabled=false;trail:Clear() end
    for _,light in lights do light.Enabled=false end
    grounded={false,false};groundElapsed=0;wasCulled=true
   end
   return
  end
  if wasCulled then wasCulled=false;previousNitro,previousBoost,previousDrift=nil,nil,nil end
  if not isLocal and distance>90 then
   farElapsed+=dt;if farElapsed<.12 then return end
   dt=farElapsed;farElapsed=0
  else farElapsed=0 end
  local off=kart:GetAttribute("KartOffTrack")==true
  local nitro=enabled and kart:GetAttribute("KartNitroActive")==true
  local boost=enabled and kart:GetAttribute("KartBoosting")==true

  local velocity=chassis.AssemblyLinearVelocity
  local planarSpeed=Vector3.new(velocity.X,0,velocity.Z).Magnitude
  local forward=velocity:Dot(chassis.CFrame.LookVector)
  local lateral=velocity:Dot(chassis.CFrame.RightVector)
  local slip=if math.abs(forward)<5 then 0 else math.abs(math.deg(math.atan2(lateral,math.max(math.abs(forward),.01))))
  local isDrifting=kart:GetAttribute("KartDrifting")==true or kart:GetAttribute("LobbyDrifting")==true
  local isSlipping=slip>=5 and planarSpeed>=10
  local drift=enabled and not off and isDrifting and isSlipping

  local naturalEnd=(previousNitro and not nitro and kart:GetAttribute('KartNitroEndReason')=='duration_complete')
   or (previousBoost and not boost and kart:GetAttribute('KartBoostEndReason')=='duration_complete')
  local unsafe=not enabled or (off and not nitro and not boost) or isDrifting or drift or kart:GetAttribute('KartCrashActive')==true
   or kart:GetAttribute('KartSlickActive')==true or kart:GetAttribute('KartMissileHitActive')==true
   or kart:GetAttribute('KartThunderHitActive')==true
  local oldWeight=envelope.weight
  local flameWeight=Envelope.step(envelope,dt,planarSpeed,nitro,boost,naturalEnd,unsafe)
  if oldWeight>0 and flameWeight==0 then for _,f in flames do f:Clear() end end
  if not enabled then
   if previousNitro or previousBoost or previousDrift then
    for _,list in {flames,smokes,trails,cruiseFlames} do for _,o in list do o.Enabled=false;o:Clear() end end
   end
  end
  previousNitro,previousBoost,previousDrift=nitro,boost,drift
  local cruising=visual:GetAttribute("VisualModelName")~="KDMV2" and enabled and not off and not drift and not boost and not nitro and forward>=CRUISE_MIN_SPEED
  if cruising then
   cruiseElapsed+=dt
   if cruiseElapsed>=CRUISE_FLAME_INTERVAL then cruiseElapsed%=CRUISE_FLAME_INTERVAL;for _,f in cruiseFlames do f:Emit(5) end end
  else cruiseElapsed=0 end
  local lod=if distance>160 then 0 elseif distance>80 or dt>.035 then .5 else 1
  for _,f in flames do
   -- Full original template profile for Nitro; Mini Boost uses 70% density.
   local style=flameStyles[f]
   local alpha=if nitro or boost then 1 else flameWeight/math.max(envelope.mode,.01)
   f.Size=style.sizes[math.clamp(math.ceil(alpha*12),0,12)]
   f.Brightness=style.brightness*alpha;f.LightEmission=style.emission*alpha
   f.Rate=(f:GetAttribute('TemplateRate') or 30)*flameWeight*lod
   f.Enabled=flameWeight>0 and lod>0
  end
  for _,l in lights do
   local alpha=if nitro or boost then 1 else flameWeight/math.max(envelope.mode,.01)
   l.Brightness=lightStyles[l].brightness*alpha;l.Range=lightStyles[l].range*alpha
   l.Enabled=flameWeight>0 and lod>0
  end
  local rate = Renderer.driftSmokeRate(slip,isLobby,lod,drift)
  for _,s in smokes do s.Rate=rate;s.Enabled=rate>0 end
  groundElapsed+=dt
  local raycastInterval = if (not isLocal and distance > 90) then 0.12 else 0.04
  if drift and slip>=5 and groundElapsed>=raycastInterval then
   groundElapsed=0
   for i,contact in contacts do
    local origin=chassis.CFrame:PointToWorldSpace(contact.position)+Vector3.yAxis*2
    local hit=nil
    if updateSurfaceFilter() then
     if visualRoads then
      local function sample(index)
       local p=visualRoads[index];if not p or not p.Parent then return nil end
       local normal=p.CFrame.UpVector;if normal.Y<=.55 then return nil end
       local top=p.Position+normal*(p.Size.Y/2)
       local down=(origin-top):Dot(normal)/normal.Y
       if down<0 or down>6 then return nil end
       local point=origin-Vector3.yAxis*down;local q=p.CFrame:PointToObjectSpace(point)
       if math.abs(q.X)>p.Size.X/2 or math.abs(q.Z)>p.Size.Z/2 then return nil end
       return {Position=point,Normal=normal}
      end
      -- Usually the same slice or its immediate neighbors; full search only on entry.
      for delta=-3,3 do local index=(roadHint+delta-1)%#visualRoads+1
       hit=sample(index);if hit then roadHint=index;break end
      end
      if not hit then for index=1,#visualRoads do hit=sample(index);if hit then roadHint=index;break end end end
      -- The crossing's raised visual ribbons must not bury a road-slice mark.
      for index=ribbonStart,#visualRoads do local ribbon=sample(index)
       if ribbon and (not hit or ribbon.Position.Y>hit.Position.Y)then hit=ribbon end
      end
     else hit=Workspace:Raycast(origin,-Vector3.yAxis*6,params)end
    end
    grounded[i]=hit~=nil and hit.Normal.Y>.55
    if grounded[i] then
     local surface=hit.Position+hit.Normal*(.04+tireSurfaceLift)
     local right=chassis.CFrame.RightVector
     local tangent=(right-hit.Normal*right:Dot(hit.Normal)).Unit*contact.width
     contact.a.WorldPosition=surface-tangent
     contact.b.WorldPosition=surface+tangent
    end
   end
  end
  for i,t in trails do
   local active=drift and slip>=5 and grounded[i]
   if active and not t.Enabled then t:Clear() end -- no bridge across jumps/re-entry
   t.Enabled=active
  end
 end
 return record
end
return Renderer
