local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService('Workspace')

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local CRUISE_FLAME_INTERVAL = 0.45
local CRUISE_MIN_SPEED = 10

local function getKart(seatPart: BasePart?): Model?
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

local function makeSmoke(attachment: Attachment): ParticleEmitter
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "DriftSmoke"
	smoke.Texture = SMOKE_TEXTURE
	smoke.Enabled = false
	smoke.Rate = 0
	smoke.Lifetime = NumberRange.new(.65, 1.1)
	smoke.Speed = NumberRange.new(1, 3)
	smoke.Acceleration = Vector3.new(0, 1, 0)
	smoke.Drag = 1
 smoke.RotSpeed=NumberRange.new(20,100)
 smoke.LightInfluence=0
	smoke.VelocityInheritance = 0.15
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.SpreadAngle = Vector2.new(24, 24)
	smoke.Color = ColorSequence.new(Color3.fromRGB(211, 211, 211), Color3.fromRGB(255, 255, 255))
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, .55),
		NumberSequenceKeypoint.new(.20, 1.8),
		NumberSequenceKeypoint.new(1, 2.6),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, .38),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Parent = attachment
	return smoke
end

local function makeTrail(parent: BasePart, first: Attachment, second: Attachment): Trail
	local trail = Instance.new("Trail")
	trail.Name = "DriftTireTrail"
	trail.Attachment0 = first
	trail.Attachment1 = second
	trail.Enabled = false
	trail.Lifetime = 2.5
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

-- Audited buggy Rear/Spark/Glow settings scaled to kart exhaust anchors.
-- Only Roblox built-in textures; no template scripts or external flame assets.
local function makeFlames(point,legacy)
 if legacy then return {makeLegacyFlame(point)} end
 local result={}
 for i,layer in {'Rear','Spark','Glow'} do
  local f=Instance.new('ParticleEmitter');f.Name=if i==1 then 'BoostFlame' else 'Boost'..layer
  f.Enabled=false;f.Rate=0;f.LightEmission=1;f.LightInfluence=0
  f.Texture=if i==1 then SMOKE_TEXTURE else 'rbxasset://textures/particles/sparkles_main.dds'
  f.Lifetime=NumberRange.new(.10,.15);f.Speed=if i==3 then NumberRange.new(0) else NumberRange.new(22)
  f.LockedToPart=true;f.EmissionDirection=Enum.NormalId.Back;f.SpreadAngle=Vector2.new(if i==1 then 15 elseif i==2 then 10 else 0,10)
  f.Orientation=if i==3 then Enum.ParticleOrientation.FacingCamera else Enum.ParticleOrientation.VelocityParallel
  f.Rotation=NumberRange.new(90);f.Color=ColorSequence.new(Color3.fromRGB(202,244,255),Color3.fromRGB(28,107,255))
  f.Size=NumberSequence.new(if i==3 then 1.0 else .55)
  f.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.14,0),NumberSequenceKeypoint.new(.70,.12),NumberSequenceKeypoint.new(1,1)})
  f:SetAttribute('FlameLayer',i);f.Parent=point;table.insert(result,f)
 end
 return result
end

local Renderer = {}
function Renderer.new(kart)
 local chassis, visual = kart:FindFirstChild("Chassis"), kart:FindFirstChild("Visual")
 if not chassis or not visual then return nil end
 local wheels,anchors={},{}
 for _,o in visual:GetDescendants() do
  if o:IsA("BasePart") and o:GetAttribute("VisualMotionRole")=="RearWheel" and o:FindFirstChild("VisualMotor") and type(o:GetAttribute("WheelRadius"))=="number" and type(o:GetAttribute("WheelWidth"))=="number" then wheels[o:GetAttribute("WheelSide")]=o end
  if o:IsA("Attachment") then local role=o:GetAttribute("EffectRole");if role=="ExhaustLeft" or role=="ExhaustRight" then anchors[role]=o end end
 end
 if not wheels.Left or not wheels.Right or not anchors.ExhaustLeft or not anchors.ExhaustRight then return nil end
 local attachments, smokes, trails, flames, cruiseFlames = {}, {}, {}, {}, {}
 local contacts={}
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={kart}
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
    table.insert(smokes,makeSmoke(point));table.insert(trails,makeTrail(chassis,a,b))
    table.insert(contacts,{position=contact,a=a,b=b,width=width*.45})
   end
  end
 end
 for _, point in visual:GetDescendants() do
  local role=point:GetAttribute("EffectRole")
  if point:IsA("Attachment") and (role=="ExhaustLeft" or role=="ExhaustRight") then
   for _,f in makeFlames(point,kart:GetAttribute("KDMUseLegacyExhaust")==true) do table.insert(flames,f) end;table.insert(cruiseFlames,makeCruiseFlame(point))
  end
 end
 local record={flames=flames,smokes=smokes,trails=trails,attachments=attachments,cruise=cruiseFlames}
 function record:destroy()
  for _, list in {flames,smokes,trails,cruiseFlames,attachments} do for _,o in list do o:Destroy() end end
 end
 if #smokes~=2 or #trails~=2 or #flames~= (if kart:GetAttribute("KDMUseLegacyExhaust")==true then 2 else 6) then record:destroy();return nil end
 local previousNitro, previousBoost, previousDrift = nil,nil,nil
 local cruiseElapsed=0
 local groundElapsed=0
 local grounded={false,false}
 local roadFolder=nil
 local roadBoxes={}
 local lastRoad={}
 local function roadSurface(point,index)
  if kart:GetAttribute('LobbyKart')==true then
   local floor=kart.Parent and kart.Parent:FindFirstChild('LobbyFrontSmoothFloor')
   if floor then local p=floor.CFrame:PointToObjectSpace(point);if math.abs(p.X)<=floor.Size.X/2 and math.abs(p.Z)<=floor.Size.Z/2 then return floor.CFrame:PointToWorldSpace(Vector3.new(p.X,floor.Size.Y/2,p.Z))+Vector3.yAxis*.04 end end
   return nil
  end
  local track=kart.Parent and kart.Parent:FindFirstChild('TestTrack')
  local folder=track and track:FindFirstChild('Road')
  if folder~=roadFolder then
   roadFolder=folder;table.clear(roadBoxes);table.clear(lastRoad)
   if folder then for _,part in folder:GetChildren() do if part:IsA('BasePart') then
    table.insert(roadBoxes,{frame=part.CFrame,half=part.Size*.5})
   end end end
  end
  local function project(box)
   local p=box.frame:PointToObjectSpace(point)
   if math.abs(p.X)<=box.half.X and math.abs(p.Z)<=box.half.Z then
    return box.frame:PointToWorldSpace(Vector3.new(p.X,box.half.Y,p.Z))+box.frame.UpVector*.04
   end
  end
  local previous=lastRoad[index]
  if previous then local surface=project(previous);if surface then return surface end end
  for _,box in roadBoxes do local surface=project(box);if surface then lastRoad[index]=box;return surface end end
  lastRoad[index]=nil;return nil
 end
 function record:update(dt,enabled)
  local off=kart:GetAttribute("KartOffTrack")==true
  local nitro=enabled and not off and kart:GetAttribute("KartNitroActive")==true
  local boost=enabled and kart:GetAttribute("KartBoosting")==true
  local drift=enabled and not off and kart:GetAttribute("KartDrifting")==true
  if boost and not previousBoost then for _,f in flames do f:Emit(12) end end
  if nitro~=previousNitro or boost~=previousBoost then
   for _,f in flames do
    local layer=f:GetAttribute("FlameLayer") or 1
    f.Rate=if layer==3 then (if nitro then 18 else 10) else (if nitro then 40 else 22)
    f.LightEmission=if nitro then 1 else .85
    f.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,if layer==3 then (if nitro then 1.3 else .85) else (if nitro then .75 else .5)),NumberSequenceKeypoint.new(1,.06)})
    f.Enabled=nitro or boost
    if not f.Enabled then f:Clear() end
   end
  end
  if not enabled then
   if previousNitro or previousBoost or previousDrift then
    for _,list in {flames,smokes,trails,cruiseFlames} do for _,o in list do o.Enabled=false;o:Clear() end end
   end
  end
  previousNitro,previousBoost,previousDrift=nitro,boost,drift
  local velocity=chassis.AssemblyLinearVelocity
  local forward=velocity:Dot(chassis.CFrame.LookVector)
  local cruising=visual:GetAttribute("VisualModelName")~="KDMV2" and enabled and not off and not drift and not boost and not nitro and forward>=CRUISE_MIN_SPEED
  if cruising then
   cruiseElapsed+=dt
   if cruiseElapsed>=CRUISE_FLAME_INTERVAL then cruiseElapsed%=CRUISE_FLAME_INTERVAL;for _,f in cruiseFlames do f:Emit(5) end end
  else cruiseElapsed=0 end
  local lateral=velocity:Dot(chassis.CFrame.RightVector)
  local slip=if math.abs(forward)<5 then 0 else math.abs(math.deg(math.atan2(lateral,math.max(math.abs(forward),.01))))
  local camera=Workspace.CurrentCamera
  local distance=if camera then (camera.CFrame.Position-chassis.Position).Magnitude else 0
  local lod=if distance>160 then 0 elseif distance>80 or dt>.035 then .5 else 1
  for _,f in flames do
   local layer=f:GetAttribute('FlameLayer') or 1
   f.Rate=(if layer==3 then (if nitro then 18 else 10) else (if nitro then 40 else 22))*lod
   f.Enabled=(nitro or boost) and lod>0
  end
  local rate=if drift then math.clamp((slip-8)*.8,0,28)*lod else 0
  for _,s in smokes do s.Rate=rate;s.Enabled=rate>0 end
  groundElapsed+=dt
  if drift and slip>=5 and groundElapsed>=.04 then
   groundElapsed=0
   for i,contact in contacts do
    local origin=chassis.CFrame:PointToWorldSpace(contact.position)+Vector3.yAxis*2
    local hit=Workspace:Raycast(origin,-Vector3.yAxis*6,params)
    local surface=roadSurface(origin,i)
    grounded[i]=hit~=nil and hit.Normal.Y>.55 and surface~=nil and math.abs(hit.Position.Y-surface.Y)<.6
    if grounded[i] then
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
