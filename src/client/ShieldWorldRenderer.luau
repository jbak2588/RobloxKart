-- Same original Shield material/orbits, rendered once per client for every kart.
local Geometry=require(game.ReplicatedStorage.Shared.KDMShieldGeometry)
local Renderer={}
local FADE_TIME=.3
local function makePart(parent, name, material, size, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = size
	part.Material = material
	part.Color = Color3.fromRGB(65, 195, 255)
	part.Transparency = transparency
	part.Anchored, part.Massless = true, true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	part.Parent = parent
	return part
end

function Renderer.new(kart,chassis,character)
 local BASE_SIZE,center=Geometry.measure(kart,chassis,character)
		local model = Instance.new("Model")
		model.Name = "KDMShieldWorld"
		local globe = makePart(model, "EnergyShell", Enum.Material.ForceField, BASE_SIZE, 0.75)
		local glow = makePart(model, "SoftGlow", Enum.Material.Neon, BASE_SIZE * 1.015, 0.96)
		local sparks = {}
		for i = 1, 8 do
			local spark = makePart(model, "Orbit" .. i, Enum.Material.Neon, Vector3.new(0.13, 0.13, 0.13), 0.2)
			local a = Instance.new("Attachment")
			a.Position = Vector3.new(0, -0.045, 0)
			a.Parent = spark
			local b = Instance.new("Attachment")
			b.Position = Vector3.new(0, 0.045, 0)
			b.Parent = spark
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = a, b
			trail.Lifetime = 0.24
			trail.LightEmission = 1
			trail.Color = ColorSequence.new(Color3.fromRGB(110, 220, 255))
			trail.Transparency = NumberSequence.new(0.25, 1)
			trail.Enabled = false
			trail.Parent = spark
			table.insert(sparks, {part = spark, trail = trail})
		end
		model.Parent = kart

 local effect={model=model,globe=globe,glow=glow,sparks=sparks}
 local born,endedAt,flashUntil=time(),nil,0
 function effect:update(now,active,blocked)
  if active then endedAt=nil else endedAt=endedAt or now end
  if blocked then flashUntil=now+FADE_TIME end
  local fade=if endedAt then math.clamp((now-endedAt)/FADE_TIME,0,1) else 0
		local age = now - born
		local pulse = math.sin(age * math.pi * 2 * 1.4)
		local flash = math.clamp((flashUntil - now) / FADE_TIME, 0, 1)
		local size = 1 + 0.018 * pulse + 0.08 * flash
		local frame = chassis.CFrame * CFrame.new(center)
		effect.globe.CFrame = frame -- Ellipsoid coverage stays chassis-aligned; orbits rotate.
		effect.globe.Size = BASE_SIZE * size
		effect.globe.Transparency = math.clamp(0.77 + 0.04 * pulse - 0.24 * flash + fade * 0.3, 0, 1)
		effect.glow.CFrame = frame
		effect.glow.Size = BASE_SIZE * (size * 1.015)
		effect.glow.Transparency = math.clamp(0.965 - 0.01 * pulse - 0.13 * flash + fade * 0.18, 0, 1)
		for i, spark in effect.sparks do
			local angle = age * (if i % 2 == 0 then 2.2 else -1.7) + i * math.pi / 4
			local tilt = if i % 2 == 0 then 0.48 else -0.48
			local orbit = CFrame.Angles(tilt, 0, 0) * Vector3.new(BASE_SIZE.X*.49 * math.cos(angle), 0, BASE_SIZE.Z*.49 * math.sin(angle))
			spark.part.CFrame = frame * CFrame.new(orbit)
			spark.part.Transparency = math.clamp(0.2 + fade * 0.8, 0, 1)
			spark.trail.Enabled = not endedAt
		end
  return fade<1
 end
 function effect:destroy()
  model:Destroy()
 end
 return effect
end
return Renderer
