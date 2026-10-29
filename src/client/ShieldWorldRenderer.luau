-- Same original Shield material/orbits, rendered once per client for every kart.
local Geometry=require(game.ReplicatedStorage.Shared.KDMShieldGeometry)
local Renderer={}
local FADE_TIME=.3
local SHIELD_COLOR = Color3.fromRGB(65, 195, 255)
local SPARK_COLOR = ColorSequence.new(Color3.fromRGB(110, 220, 255))
local SPARK_TRANS = NumberSequence.new(0.25, 1)
local SPARK_SIZE = Vector3.new(0.13, 0.13, 0.13)
local ATT_POS_A = Vector3.new(0, -0.045, 0)
local ATT_POS_B = Vector3.new(0, 0.045, 0)
local TILT_EVEN = CFrame.Angles(0.48, 0, 0)
local TILT_ODD = CFrame.Angles(-0.48, 0, 0)

local function makePart(parent, name, material, size, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = size
	part.Material = material
	part.Color = SHIELD_COLOR
	part.Transparency = transparency
	part.Anchored, part.Massless = true, true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	part.Parent = parent
	return part
end

function Renderer.new(kart,chassis,character)
 local BASE_SIZE,center=Geometry.measure(kart,chassis,character)
 local centerOffset = CFrame.new(center)
 local radiusX, radiusZ = BASE_SIZE.X * 0.49, BASE_SIZE.Z * 0.49
		local model = Instance.new("Model")
		model.Name = "KDMShieldWorld"
		local globe = makePart(model, "EnergyShell", Enum.Material.ForceField, BASE_SIZE, 0.75)
		local glow = makePart(model, "SoftGlow", Enum.Material.Neon, BASE_SIZE * 1.015, 0.96)
		local sparks = {}
		for i = 1, 8 do
			local spark = makePart(model, "Orbit" .. i, Enum.Material.Neon, SPARK_SIZE, 0.2)
			local a = Instance.new("Attachment")
			a.Position = ATT_POS_A
			a.Parent = spark
			local b = Instance.new("Attachment")
			b.Position = ATT_POS_B
			b.Parent = spark
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = a, b
			trail.Lifetime = 0.24
			trail.LightEmission = 1
			trail.Color = SPARK_COLOR
			trail.Transparency = SPARK_TRANS
			trail.Enabled = false
			trail.Parent = spark
			table.insert(sparks, {part = spark, trail = trail, tilt = if i % 2 == 0 then TILT_EVEN else TILT_ODD, rate = if i % 2 == 0 then 2.2 else -1.7, phase = i * math.pi / 4})
		end
		model.Parent = kart

 local effect={model=model,globe=globe,glow=glow,sparks=sparks}
 local born,endedAt,flashUntil=time(),nil,0
 local lastSparkTrans, lastTrailEnabled = nil, nil
 function effect:update(now,active,blocked)
  if active then endedAt=nil else endedAt=endedAt or now end
  if blocked then flashUntil=now+FADE_TIME end
  local fade=if endedAt then math.clamp((now-endedAt)/FADE_TIME,0,1) else 0
		local age = now - born
		local pulse = math.sin(age * math.pi * 2 * 1.4)
		local flash = math.clamp((flashUntil - now) / FADE_TIME, 0, 1)
		local size = 1 + 0.018 * pulse + 0.08 * flash
		local frame = chassis.CFrame * centerOffset
		effect.globe.CFrame = frame -- Ellipsoid coverage stays chassis-aligned; orbits rotate.
		effect.globe.Size = BASE_SIZE * size
		effect.globe.Transparency = math.clamp(0.77 + 0.04 * pulse - 0.24 * flash + fade * 0.3, 0, 1)
		effect.glow.CFrame = frame
		effect.glow.Size = BASE_SIZE * (size * 1.015)
		effect.glow.Transparency = math.clamp(0.965 - 0.01 * pulse - 0.13 * flash + fade * 0.18, 0, 1)
		local sparkTrans = math.clamp(0.2 + fade * 0.8, 0, 1)
		local trailEnabled = not endedAt
		local writeTrans = sparkTrans ~= lastSparkTrans
		local writeTrail = trailEnabled ~= lastTrailEnabled
		lastSparkTrans, lastTrailEnabled = sparkTrans, trailEnabled
		for _, spark in effect.sparks do
			local angle = age * spark.rate + spark.phase
			local orbit = spark.tilt * Vector3.new(radiusX * math.cos(angle), 0, radiusZ * math.sin(angle))
			spark.part.CFrame = frame * CFrame.new(orbit)
			if writeTrans then spark.part.Transparency = sparkTrans end
			if writeTrail then spark.trail.Enabled = trailEnabled end
		end
  return fade<1
 end
 function effect:destroy()
  model:Destroy()
 end
 return effect
end
return Renderer
