-- Original temporary geometry outside Kart/Visual's production contract.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KDMItemVFXConfig"))
local Visuals = {}
local function part(parent, name, size, frame, color)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, frame, color
	p.Anchored, p.Massless = true, true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = false
	p.Parent = parent
	return p
end
local FLIGHT_TIME, REVEAL_TIME, SPLASH_TIME = 0.20, 0.16, 0.22

-- Uses the controller's existing update loop. Replicated cosmetic parts only;
-- the trigger never moves, scales or waits for this animation.
function Visuals.updateSlick(deploy, age)
	local flight = math.clamp(age / FLIGHT_TIME, 0, 1)
	if deploy.drop.Parent then
		local position = deploy.start:Lerp(deploy.frame.Position, flight)
			+ Vector3.new(0, math.sin(flight * math.pi) * 2.2, 0)
		deploy.drop.CFrame = CFrame.new(position) * CFrame.Angles(flight * 4, 0, flight * 3)
		if flight >= 1 then deploy.drop:Destroy() end
	end
	local reveal = math.clamp((age - FLIGHT_TIME) / REVEAL_TIME, 0, 1)
	local scale = 0.08 + 0.92 * (1 - (1 - reveal)^3)
	deploy.surface.Size = Vector3.new(deploy.width * scale, 0.16, deploy.length * scale)
	deploy.surface.Transparency = 1 - reveal
	for i, edge in deploy.edges do
		local side = if i % 2 == 1 then -1 else 1
		if i <= 2 then
			edge.Size = Vector3.new(0.25 * scale, 0.20, deploy.length * scale)
			edge.CFrame = deploy.frame * CFrame.new(side * (deploy.width * 0.5 - 0.125) * scale, 0.04, 0)
		else
			edge.Size = Vector3.new(deploy.width * scale, 0.20, 0.25 * scale)
			edge.CFrame = deploy.frame * CFrame.new(0, 0.04, side * (deploy.length * 0.5 - 0.125) * scale)
		end
		edge.Transparency = 1 - reveal
	end
	local splash = math.clamp((age - FLIGHT_TIME) / SPLASH_TIME, 0, 1)
	for i, droplet in deploy.droplets do
		if droplet.Parent then
			if splash >= 1 then droplet:Destroy() else
				local angle = i * math.pi * 0.5
				droplet.CFrame = deploy.frame * CFrame.new(math.cos(angle) * 3.5 * splash,
					0.12 + math.sin(splash * math.pi) * 0.65, math.sin(angle) * 2.5 * splash)
				droplet.Transparency = if age < FLIGHT_TIME then 1 else 0.1 + 0.9 * splash
			end
		end
	end
	return age >= FLIGHT_TIME + SPLASH_TIME
end

function Visuals.slick(parent, frame, config, chassisFrame)
	local model = Instance.new("Model")
	model.Name = "SlickHazard"
	local trigger = part(model, "SlickTrigger", Vector3.new(config.SLICK_WIDTH, config.SLICK_TRIGGER_HEIGHT, config.SLICK_LENGTH),
		frame + Vector3.new(0, config.SLICK_TRIGGER_HEIGHT*0.5, 0), Color3.fromRGB(35, 30, 45))
	trigger.Transparency = 1
	-- A complete rectangular patch/perimeter shows the exact swept trigger footprint.
	local surface = part(model, "SlickSurface", Vector3.new(config.SLICK_WIDTH, 0.16, config.SLICK_LENGTH), frame, Color3.fromRGB(30, 24, 43))
	local edges = {}
	for i = 1, 4 do
		local edge = part(model, "Edge"..i, Vector3.one, frame, Color3.fromRGB(180, 125, 255))
		edge.Material = Enum.Material.Neon
		table.insert(edges, edge)
	end
	local start = (chassisFrame * CFrame.new(0, 5.0, 3)).Position
	local drop = part(model, "OilDrop", Vector3.new(1.7, 2.0, 1.7), CFrame.new(start), Color3.fromRGB(115, 75, 150))
	drop.Shape = Enum.PartType.Ball
	local droplets = {}
	for i = 1, 4 do
		local droplet = part(model, "OilSplash"..i, Vector3.new(0.7, 0.15, 0.5), frame, Color3.fromRGB(70, 48, 85))
		droplet.Shape = Enum.PartType.Ball
		table.insert(droplets, droplet)
	end
	local deploy = { drop=drop, droplets=droplets, surface=surface, edges=edges,
		start=start, frame=frame, width=config.SLICK_WIDTH, length=config.SLICK_LENGTH }
	Visuals.updateSlick(deploy, 0)
	model.Parent = parent
	return model, trigger, deploy
end
function Visuals.shield(kart, chassis)
	local shell = part(kart, "RaceItemShield", Vector3.new(9, 6.5, 11),
		chassis.CFrame * CFrame.new(0, 1.3, 0), Color3.fromRGB(65, 210, 255))
	shell.Shape = Enum.PartType.Ball
	shell.Material = Enum.Material.ForceField
	shell.Transparency = 0.76
	shell.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = chassis, shell
	weld.Parent = shell
	return shell
end
function Visuals.missile(parent, frame)
	local model = Instance.new("Model")
	model.Name = "HomingMissile"
	local body = part(model, "Body", Vector3.new(0.8, 0.8, 2.8), frame, Color3.fromRGB(230, 240, 250))
	body.Shape = Enum.PartType.Ball
	model.PrimaryPart = body
	local nose = part(model, "Nose", Vector3.one * 0.85, frame * CFrame.new(0, 0, -1.2), Color3.fromRGB(255, 95, 60))
	nose.Shape = Enum.PartType.Ball
	part(model, "FinLeft", Vector3.new(1.4, 0.15, 0.8), frame * CFrame.new(-0.45, 0, 0.9), Color3.fromRGB(255, 180, 65))
	part(model, "FinRight", Vector3.new(1.4, 0.15, 0.8), frame * CFrame.new(0.45, 0, 0.9), Color3.fromRGB(255, 180, 65))
	local exhaust = part(model, "Exhaust", Vector3.new(0.45, 0.45, 1.2), frame * CFrame.new(0, 0, 1.7), Color3.fromRGB(255, 225, 75))
	exhaust.Material = Enum.Material.Neon
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(-0.25, 0, 1.7); a.Parent = body
	local b = Instance.new("Attachment")
	b.Position = Vector3.new(0.25, 0, 1.7); b.Parent = body
	local trail = Instance.new("Trail")
	trail.Name = "ExhaustTrail"
	trail.Attachment0, trail.Attachment1 = a, b
	trail.Lifetime, trail.LightEmission = Config.Missile.TrailLifetime, 1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 190, 65))
	trail.Transparency = NumberSequence.new(0.25, 1)
	trail.Parent = body
	local smoke = Instance.new("Trail")
	smoke.Name = "SmokeTrail"
	smoke.Attachment0, smoke.Attachment1 = a, b
	smoke.Lifetime, smoke.LightEmission = Config.Missile.SmokeLifetime, 0
	smoke.Color = ColorSequence.new(Color3.fromRGB(145, 155, 165))
	smoke.Transparency = NumberSequence.new(0.65, 1)
	smoke.Parent = body
	local launch = part(model, "LaunchFlash", Vector3.one * 1.2, frame, Color3.fromRGB(255, 205, 65))
	launch.Shape, launch.Material, launch.Transparency = Enum.PartType.Ball, Enum.Material.Neon, 0.25
	model.Parent = parent
	return model
end

function Visuals.updateMissile(model, age)
	local launch = model:FindFirstChild("LaunchFlash")
	if launch then
		if age >= Config.Missile.LaunchFlashLifetime then launch:Destroy() else
			launch.Size = Vector3.one * (1.2 + age * 10)
			launch.Transparency = 0.25 + age / Config.Missile.LaunchFlashLifetime * 0.75
		end
	end
end

-- A short cosmetic shell follows the Kart, separate from the defense shell.
function Visuals.shieldPulse(kart, chassis)
	local pulse = part(kart, "ShieldPulse", Vector3.new(9, 6.5, 11) * 0.9,
		chassis.CFrame * CFrame.new(0, 1.3, 0), Color3.fromRGB(65, 225, 255))
	pulse.Shape, pulse.Material, pulse.Transparency = Enum.PartType.Ball, Enum.Material.Neon, 0.45
	pulse.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = chassis, pulse, pulse
	local ripple = Instance.new("Highlight")
	ripple.Name, ripple.Adornee = "BlockRipple", pulse
	ripple.FillTransparency, ripple.OutlineTransparency = 1, 0.15
	ripple.OutlineColor = Color3.fromRGB(120, 245, 255)
	ripple.DepthMode = Enum.HighlightDepthMode.Occluded
	ripple.Parent = pulse -- Expands with the existing pulse; inherits its cleanup.
	return pulse
end

-- Child parts share the parent's existing service lifetime/cleanup owner.
local function rays(root, count, radius, color, prefix)
	for i = 1, count do
		local angle = i * math.pi * 2 / count
		local ray = part(root, prefix..i, Vector3.new(.13, .13, radius*.55),
			root.CFrame * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius*.65), color)
		ray.Material, ray.Transparency = Enum.Material.Neon, .15
	end
end
function Visuals.missileImpact(parent, position, blocked)
	local flash = part(parent, if blocked then "MissileShieldImpact" else "MissileImpact", Vector3.one, CFrame.new(position),
		if blocked then Color3.fromRGB(65, 210, 255) else Color3.fromRGB(255, 200, 75))
	flash.Shape, flash.Material, flash.Transparency = Enum.PartType.Ball, Enum.Material.Neon, .3
	if not blocked then
		rays(flash, Config.Missile.SparkCount, Config.Missile.BurstRadius, Color3.fromRGB(255, 225, 140), "Burst")
		-- A real horizontal ring, visible to every racer through replication.
		-- Reuse the service-owned flash lifetime; no particles, lights or UI washout.
		for i = 1, Config.MissileImpact.RingSegments do
			local segment = part(flash, "Shockwave"..i, Vector3.one, flash.CFrame, Color3.fromRGB(255, 160, 45))
			segment.Material = Enum.Material.Neon
		end
		local puff = part(flash, "ImpactPuff", Vector3.one*2*Config.Missile.PuffScale, flash.CFrame, Color3.fromRGB(100, 105, 115))
		puff.Shape, puff.Transparency = Enum.PartType.Ball, Config.Missile.PuffTransparency
		local residual = part(flash, "Aftershock", Vector3.one, flash.CFrame, Color3.fromRGB(255, 205, 100))
		residual.Shape, residual.Material, residual.Transparency = Enum.PartType.Ball, Enum.Material.Neon, 1
	end
	Visuals.updateMissileImpact(flash, 0)
	return flash
end
function Visuals.updateMissileImpact(flash, age)
	local blocked = flash.Name == "MissileShieldImpact"
	local lifetime = if blocked then Config.Shield.MissileImpactLifetime else Config.Missile.ImpactLifetime
	local t = math.clamp(age / lifetime, 0, 1)
	flash.Size = Vector3.one * (if blocked then 1+3*t else 4+(Config.MissileImpact.Size-4)*t)
	flash.Transparency = .3+.7*t
	local delay = Config.Missile.AftershockDelay
	local after = math.clamp((age-delay)/(Config.Missile.ImpactLifetime-delay),0,1)
	local primary = math.max(0,1-age/delay)
	local intensity = if age >= delay then Config.Missile.AftershockScale*(1-after) else primary
	for _, child in flash:GetChildren() do
		if child:IsA("BasePart") then
			local index = tonumber(string.match(child.Name, "^Burst(%d+)$"))
			local ringIndex = tonumber(string.match(child.Name, "^Shockwave(%d+)$"))
			if ringIndex then
				local radius = 2 + (Config.MissileImpact.ShockwaveSize/2-2)*t
				local angle = ringIndex*math.pi*2/Config.MissileImpact.RingSegments
				child.Size = Vector3.new(.55, .4, 2*radius*math.tan(math.pi/Config.MissileImpact.RingSegments))
				child.CFrame = flash.CFrame*CFrame.Angles(0,angle,0)*CFrame.new(radius,.35,0)
				child.Transparency = .15+.85*t
			elseif index then
				child.Transparency = 1-.85*intensity
				local angle = index*math.pi*2/Config.Missile.SparkCount
				child.CFrame = flash.CFrame*CFrame.Angles(0,angle,0)*CFrame.new(0,0,-Config.Missile.BurstRadius*(.3+.7*t))
			elseif child.Name == "ImpactPuff" then
				child.Size = Vector3.one*(2+2*t)*Config.Missile.PuffScale
				child.Transparency = Config.Missile.PuffTransparency+(1-Config.Missile.PuffTransparency)*t
			elseif child.Name == "Aftershock" then
				child.Size = Vector3.one*(3+9*after)
				child.Transparency = if age < delay then 1 else 1-Config.Missile.AftershockScale*(1-after)
			end
		end
	end
	return t >= 1
end

function Visuals.smoke(parent, frame, config)
	local model = Instance.new("Model")
	model.Name = "SmokeHazard"
	local center = frame * CFrame.new(0, config.SMOKE_HEIGHT/2, 0)
	local trigger = part(model, "SmokeTrigger", Vector3.new(config.SMOKE_WIDTH, config.SMOKE_HEIGHT, config.SMOKE_LENGTH), center, Color3.fromRGB(65, 65, 70))
	trigger.Transparency = 1
	-- Nine static overlapping puffs span the screen; including trigger, 120 parts at cap.
	local puffSize = Vector3.new(config.SMOKE_WIDTH/3, config.SMOKE_HEIGHT*.8, config.SMOKE_LENGTH*2/3)
	for index, unitOffset in {Vector3.new(-2,-1,-1), Vector3.new(-1,1,0), Vector3.new(0,-1,-1),
		Vector3.new(1,1,0), Vector3.new(2,-1,-1), Vector3.new(-2,1,1), Vector3.new(0,1,1),
		Vector3.new(2,1,1), Vector3.zero} do
		local offset = Vector3.new(unitOffset.X*config.SMOKE_WIDTH/6, unitOffset.Y*config.SMOKE_HEIGHT/10,
			unitOffset.Z*config.SMOKE_LENGTH/6)
		local puff = part(model, "Cloud"..index, puffSize, center * CFrame.new(offset), Color3.fromRGB(55, 58, 63))
		puff.Shape, puff.Transparency = Enum.PartType.Ball, 0.48
	end
	model.Parent = parent
	return model, trigger
end

local function thunderPuffSpecs(c)
 return {
  { name = "Cloud1", pos = Vector3.new(-c.Width*.16, c.OffsetY+.18, 1.1), size = Vector3.new(c.Width*.38, c.Height*.92, c.Depth*.85), color = Color3.fromRGB(78, 82, 92) },
  { name = "Cloud2", pos = Vector3.new(0, c.OffsetY+.40, 0), size = Vector3.new(c.Width*.48, c.Height, c.Depth), color = Color3.fromRGB(68, 72, 80) },
  { name = "Cloud3", pos = Vector3.new(c.Width*.16, c.OffsetY+.18, -1.0), size = Vector3.new(c.Width*.38, c.Height*.92, c.Depth*.85), color = Color3.fromRGB(78, 82, 92) },
  { name = "Cloud4", pos = Vector3.new(-c.Width*.29, c.OffsetY-.12, -0.7), size = Vector3.new(c.Width*.30, c.Height*.80, c.Depth*.72), color = Color3.fromRGB(88, 93, 104) },
  { name = "Cloud5", pos = Vector3.new(c.Width*.29, c.OffsetY-.12, 0.8), size = Vector3.new(c.Width*.30, c.Height*.80, c.Depth*.72), color = Color3.fromRGB(88, 93, 104) },
  { name = "Cloud6", pos = Vector3.new(-c.Width*.40, c.OffsetY-.40, 0.4), size = Vector3.new(c.Width*.20, c.Height*.68, c.Depth*.60), color = Color3.fromRGB(98, 104, 116) },
  { name = "Cloud7", pos = Vector3.new(c.Width*.40, c.OffsetY-.40, -0.4), size = Vector3.new(c.Width*.20, c.Height*.68, c.Depth*.60), color = Color3.fromRGB(98, 104, 116) },
 }
end

-- Bounded native cosmetics; every Part is anchored and noninteractive.
function Visuals.thunderWarning(parent, chassis)
 local model=Instance.new("Model");model.Name="ThunderWarning";model.Parent=parent
 local c=Config.ThunderWarning
 for _, spec in thunderPuffSpecs(c) do
  local puff=part(model,spec.name,spec.size,CFrame.new(),spec.color)
  puff.Shape,puff.Transparency=Enum.PartType.Ball,.12
 end
 local glow=part(model,"ElectricGlow",Vector3.new(.25,1.4,.25),CFrame.new(),Color3.fromRGB(90,230,255))
 glow.Material=Enum.Material.Neon
 Visuals.updateThunderWarning(model,chassis)
 return model
end
function Visuals.updateThunderWarning(model,chassis)
 local c=Config.ThunderWarning
 for _, spec in thunderPuffSpecs(c) do
  local puff = model:FindFirstChild(spec.name)
  if puff then puff.CFrame = CFrame.new(chassis.Position + spec.pos) end
 end
 model.ElectricGlow.CFrame=CFrame.new(chassis.Position+Vector3.new(0,c.OffsetY-c.Height*.5,0))
end
function Visuals.thunderStrike(parent,chassis,blocked)
 local model=Instance.new("Model");model.Name=if blocked then "ThunderShieldImpact" else "ThunderStrike";model.Parent=parent
 for i=1,3 do
  local height=Config.ThunderWarning.OffsetY/3
  local bolt=part(model,"Bolt"..i,Vector3.new(.8,height+.5,.8),CFrame.new(chassis.Position+Vector3.new(if i==2 then .4 else 0,Config.ThunderWarning.OffsetY-(i-.5)*height,0))*CFrame.Angles(0,0,if i==2 then .35 else -.18),Color3.fromRGB(210,250,255))
  bolt.Material=Enum.Material.Neon
 end
 local flash=part(model,"Impact",Vector3.new(5,.25,5),CFrame.new(chassis.Position),Color3.fromRGB(65,225,255))
 flash.Material=Enum.Material.Neon;flash.Transparency=.65
 if blocked then
  -- Absorbed strike ends at the shell; no full electric ground burst.
  for i=1,3 do model:FindFirstChild("Bolt"..i).Transparency=.75 end
 else
  rays(flash,Config.Thunder.ArcCount,3,Color3.fromRGB(100,235,255),"ElectricArc")
  local burst=Visuals.missileImpact(model,chassis.Position,false)
  burst.Name="ThunderExplosion"
  local light=Instance.new("PointLight");light.Name="ImpactLight"
  light.Range=Config.ThunderImpact.LightRange;light.Brightness=0;light.Enabled=false
  light.Color=Color3.fromRGB(255,225,150);light.Shadows=false;light.Parent=burst
 end
 Visuals.updateThunderStrike(model,0)
 return model
end

function Visuals.thunderStrikeLifetime(blocked)
 return if blocked then Config.Thunder.StrikeLifetime else math.max(Config.Thunder.StrikeLifetime,Config.ThunderImpact.Delay+Config.Missile.ImpactLifetime)
end
function Visuals.updateThunderStrike(model, age)
	local c=Config.Thunder
	local t=math.clamp(age/c.StrikeLifetime,0,1)
	local primary=math.max(0,1-age/c.PrimaryDuration)
	local after=if age<c.AfterFlashDelay then 0 else c.AfterFlashScale*(1-math.clamp((age-c.AfterFlashDelay)/(c.StrikeLifetime-c.AfterFlashDelay),0,1))
	local blocked=model.Name=="ThunderShieldImpact"
	local intensity=if blocked then .20*(1-t) else math.max(primary,after)
	local burst=model:FindFirstChild("ThunderExplosion")
	for _,p in model:GetChildren() do
		if p:IsA("BasePart") and p~=burst then
			-- Fade the initial vertical strike; residual arcs/ground pulse remain lighter.
			p.Transparency=1-intensity*(if p.Name:match("^Bolt") then .80 else .65)
			for _,arc in p:GetChildren()do if arc:IsA("BasePart")then arc.Transparency=1-intensity*.65 end end
		end
	end
	if burst then
		local burstAge=age-Config.ThunderImpact.Delay
		if burstAge<0 then
			burst.Transparency=1
			for _,p in burst:GetDescendants()do if p:IsA("BasePart")then p.Transparency=1 end end
		else Visuals.updateMissileImpact(burst,burstAge) end
		local fade=math.clamp(1-burstAge/Config.Missile.ImpactLifetime,0,1)
		local light=burst.ImpactLight
		light.Enabled=burstAge>=0 and fade>0
		light.Brightness=if light.Enabled then Config.ThunderImpact.LightBrightness*fade*fade else 0
	end
end
return Visuals
