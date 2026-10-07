local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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
	smoke.Lifetime = NumberRange.new(0.35, 0.7)
	smoke.Speed = NumberRange.new(1, 3)
	smoke.Acceleration = Vector3.new(0, 3, 0)
	smoke.Drag = 1
	smoke.VelocityInheritance = 0.15
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.SpreadAngle = Vector2.new(24, 24)
	smoke.Color = ColorSequence.new(Color3.fromRGB(125, 125, 130), Color3.fromRGB(170, 170, 175))
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.28),
		NumberSequenceKeypoint.new(1, 1.1),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
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
	trail.Lifetime = 0.35
	trail.MaxLength = 14
	trail.MinLength = 0.1
	trail.Color = ColorSequence.new(Color3.fromRGB(35, 37, 40))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = parent
	return trail
end

local function makeFlame(attachment: Attachment): ParticleEmitter
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
   end
  end
 end
 for _, point in visual:GetDescendants() do
  local role=point:GetAttribute("EffectRole")
  if point:IsA("Attachment") and (role=="ExhaustLeft" or role=="ExhaustRight") then
   table.insert(flames,makeFlame(point));table.insert(cruiseFlames,makeCruiseFlame(point))
  end
 end
 local record={flames=flames,smokes=smokes,trails=trails,attachments=attachments,cruise=cruiseFlames}
 function record:destroy()
  for _, list in {flames,smokes,trails,cruiseFlames,attachments} do for _,o in list do o:Destroy() end end
 end
 if #smokes~=2 or #trails~=2 or #flames~=2 then record:destroy();return nil end
 local previousNitro, previousBoost, previousDrift = nil,nil,nil
 local cruiseElapsed=0
 function record:update(dt,enabled)
  local off=kart:GetAttribute("KartOffTrack")==true
  local nitro=enabled and not off and kart:GetAttribute("KartNitroActive")==true
  local boost=enabled and kart:GetAttribute("KartBoosting")==true
  local drift=enabled and not off and kart:GetAttribute("KartDrifting")==true
  if boost and not previousBoost then for _,f in flames do f:Emit(12) end end
  if nitro~=previousNitro or boost~=previousBoost then
   for _,f in flames do
    f.Rate=if nitro then 65 else 30
    f.LightEmission=if nitro then 1 else .85
    f.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,if nitro then .7 else .45),NumberSequenceKeypoint.new(1,.06)})
    f.Enabled=nitro or boost
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
  local rate=if drift then math.clamp((slip-8)*2,0,35) else 0
  for _,s in smokes do s.Rate=rate;s.Enabled=rate>0 end
  for _,t in trails do t.Enabled=drift and slip>=10 end
 end
 return record
end
return Renderer
