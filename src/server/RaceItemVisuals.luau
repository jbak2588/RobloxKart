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

local RING_SEGMENTS = Config.MissileImpact.RingSegments
local RING_TAN = 2 * math.tan(math.pi / RING_SEGMENTS)
local RING_ROTATIONS = {}
for i = 1, RING_SEGMENTS do
	RING_ROTATIONS[i] = CFrame.Angles(0, i * math.pi * 2 / RING_SEGMENTS, 0)
end

local SPARK_COUNT = Config.Missile.SparkCount
local SPARK_ROTATIONS = {}
for i = 1, SPARK_COUNT do
	SPARK_ROTATIONS[i] = CFrame.Angles(0, i * math.pi * 2 / SPARK_COUNT, 0)
end

local SPLASH_DIRS = {}
for i = 1, 4 do
	local angle = i * math.pi * 0.5
	SPLASH_DIRS[i] = { x = math.cos(angle) * 3.5, z = math.sin(angle) * 2.5 }
end

local SMOKE_UNIT_OFFSETS = {
	Vector3.new(-2, -1, -1), Vector3.new(-1, 1, 0), Vector3.new(0, -1, -1),
	Vector3.new(1, 1, 0), Vector3.new(2, -1, -1), Vector3.new(-2, 1, 1),
	Vector3.new(0, 1, 1), Vector3.new(2, 1, 1), Vector3.zero,
}

local function buildThunderPuffSpecs(c)
	return {
		{ name = "Cloud1", pos = Vector3.new(-c.Width * .16, c.OffsetY + .18, 1.1), size = Vector3.new(c.Width * .38, c.Height * .92, c.Depth * .85), color = Color3.fromRGB(78, 82, 92) },
		{ name = "Cloud2", pos = Vector3.new(0, c.OffsetY + .40, 0), size = Vector3.new(c.Width * .48, c.Height, c.Depth), color = Color3.fromRGB(68, 72, 80) },
		{ name = "Cloud3", pos = Vector3.new(c.Width * .16, c.OffsetY + .18, -1.0), size = Vector3.new(c.Width * .38, c.Height * .92, c.Depth * .85), color = Color3.fromRGB(78, 82, 92) },
		{ name = "Cloud4", pos = Vector3.new(-c.Width * .29, c.OffsetY - .12, -0.7), size = Vector3.new(c.Width * .30, c.Height * .80, c.Depth * .72), color = Color3.fromRGB(88, 93, 104) },
		{ name = "Cloud5", pos = Vector3.new(c.Width * .29, c.OffsetY - .12, 0.8), size = Vector3.new(c.Width * .30, c.Height * .80, c.Depth * .72), color = Color3.fromRGB(88, 93, 104) },
		{ name = "Cloud6", pos = Vector3.new(-c.Width * .40, c.OffsetY - .40, 0.4), size = Vector3.new(c.Width * .20, c.Height * .68, c.Depth * .60), color = Color3.fromRGB(98, 104, 116) },
		{ name = "Cloud7", pos = Vector3.new(c.Width * .40, c.OffsetY - .40, -0.4), size = Vector3.new(c.Width * .20, c.Height * .68, c.Depth * .60), color = Color3.fromRGB(98, 104, 116) },
	}
end
local THUNDER_PUFF_SPECS = buildThunderPuffSpecs(Config.ThunderWarning)
local THUNDER_GLOW_OFFSET = Vector3.new(0, Config.ThunderWarning.OffsetY - Config.ThunderWarning.Height * .5, 0)

local impactCache = setmetatable({}, { __mode = "k" })
local warningCache = setmetatable({}, { __mode = "k" })
local strikeCache = setmetatable({}, { __mode = "k" })

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
	local edgeTrans = 1 - reveal
	deploy.surface.Size = Vector3.new(deploy.width * scale, 0.16, deploy.length * scale)
	deploy.surface.Transparency = edgeTrans
	local sideSize = Vector3.new(0.25 * scale, 0.20, deploy.length * scale)
	local frontSize = Vector3.new(deploy.width * scale, 0.20, 0.25 * scale)
	local halfW = (deploy.width * 0.5 - 0.125) * scale
	local halfL = (deploy.length * 0.5 - 0.125) * scale
	for i, edge in deploy.edges do
		local side = if i % 2 == 1 then -1 else 1
		if i <= 2 then
			edge.Size = sideSize
			edge.CFrame = deploy.frame * CFrame.new(side * halfW, 0.04, 0)
		else
			edge.Size = frontSize
			edge.CFrame = deploy.frame * CFrame.new(0, 0.04, side * halfL)
		end
		edge.Transparency = edgeTrans
	end
	local splash = math.clamp((age - FLIGHT_TIME) / SPLASH_TIME, 0, 1)
	local splashY = 0.12 + math.sin(splash * math.pi) * 0.65
	local splashTrans = if age < FLIGHT_TIME then 1 else 0.1 + 0.9 * splash
	for i, droplet in deploy.droplets do
		if droplet.Parent then
			if splash >= 1 then droplet:Destroy() else
				local dir = SPLASH_DIRS[i]
				droplet.CFrame = deploy.frame * CFrame.new(dir.x * splash, splashY, dir.z * splash)
				droplet.Transparency = splashTrans
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
	local list = {}
	local raySize = Vector3.new(.13, .13, radius * .55)
	local offset = CFrame.new(0, 0, -radius * .65)
	for i = 1, count do
		local angle = i * math.pi * 2 / count
		local ray = part(root, prefix..i, raySize,
			root.CFrame * CFrame.Angles(0, angle, 0) * offset, color)
		ray.Material, ray.Transparency = Enum.Material.Neon, .15
		list[i] = ray
	end
	return list
end
function Visuals.missileImpact(parent, position, blocked)
	local flash = part(parent, if blocked then "MissileShieldImpact" else "MissileImpact", Vector3.one, CFrame.new(position),
		if blocked then Color3.fromRGB(65, 210, 255) else Color3.fromRGB(255, 200, 75))
	flash.Shape, flash.Material, flash.Transparency = Enum.PartType.Ball, Enum.Material.Neon, .3
	if not blocked then
		local bursts = rays(flash, SPARK_COUNT, Config.Missile.BurstRadius, Color3.fromRGB(255, 225, 140), "Burst")
		-- A real horizontal ring, visible to every racer through replication.
		-- Reuse the service-owned flash lifetime; no particles, lights or UI washout.
		local shockwaves = {}
		local ringColor = Color3.fromRGB(255, 160, 45)
		for i = 1, RING_SEGMENTS do
			local segment = part(flash, "Shockwave"..i, Vector3.one, flash.CFrame, ringColor)
			segment.Material = Enum.Material.Neon
			shockwaves[i] = segment
		end
		local puff = part(flash, "ImpactPuff", Vector3.one*2*Config.Missile.PuffScale, flash.CFrame, Color3.fromRGB(100, 105, 115))
		puff.Shape, puff.Transparency = Enum.PartType.Ball, Config.Missile.PuffTransparency
		local residual = part(flash, "Aftershock", Vector3.one, flash.CFrame, Color3.fromRGB(255, 205, 100))
		residual.Shape, residual.Material, residual.Transparency = Enum.PartType.Ball, Enum.Material.Neon, 1
		impactCache[flash] = { bursts = bursts, shockwaves = shockwaves, puff = puff, residual = residual }
	else
		impactCache[flash] = { blocked = true }
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
	local cached = impactCache[flash]
	if cached then
		if not cached.blocked then
			local delay = Config.Missile.AftershockDelay
			local after = math.clamp((age-delay)/(Config.Missile.ImpactLifetime-delay),0,1)
			local primary = math.max(0,1-age/delay)
			local intensity = if age >= delay then Config.Missile.AftershockScale*(1-after) else primary
			local flashCF = flash.CFrame
			local radius = 2 + (Config.MissileImpact.ShockwaveSize/2-2)*t
			local ringSize = Vector3.new(.55, .4, radius * RING_TAN)
			local ringOffset = CFrame.new(radius, .35, 0)
			local ringTrans = .15 + .85 * t
			for i, seg in cached.shockwaves do
				seg.Size = ringSize
				seg.CFrame = flashCF * RING_ROTATIONS[i] * ringOffset
				seg.Transparency = ringTrans
			end
			local burstTrans = 1 - .85 * intensity
			local burstOffset = CFrame.new(0, 0, -Config.Missile.BurstRadius * (.3 + .7 * t))
			for i, b in cached.bursts do
				b.Transparency = burstTrans
				b.CFrame = flashCF * SPARK_ROTATIONS[i] * burstOffset
			end
			local puff = cached.puff
			if puff then
				puff.Size = Vector3.one * (2 + 2 * t) * Config.Missile.PuffScale
				puff.Transparency = Config.Missile.PuffTransparency + (1 - Config.Missile.PuffTransparency) * t
			end
			local residual = cached.residual
			if residual then
				residual.Size = Vector3.one * (3 + 9 * after)
				residual.Transparency = if age < delay then 1 else 1 - Config.Missile.AftershockScale * (1 - after)
			end
		end
		return t >= 1
	end
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
	local puffColor = Color3.fromRGB(55, 58, 63)
	local scaleX, scaleY, scaleZ = config.SMOKE_WIDTH/6, config.SMOKE_HEIGHT/10, config.SMOKE_LENGTH/6
	for index, unitOffset in SMOKE_UNIT_OFFSETS do
		local offset = Vector3.new(unitOffset.X*scaleX, unitOffset.Y*scaleY, unitOffset.Z*scaleZ)
		local puff = part(model, "Cloud"..index, puffSize, center * CFrame.new(offset), puffColor)
		puff.Shape, puff.Transparency = Enum.PartType.Ball, 0.48
	end
	model.Parent = parent
	return model, trigger
end

-- Bounded native cosmetics; every Part is anchored and noninteractive.
function Visuals.thunderWarning(parent, chassis)
	local model = Instance.new("Model"); model.Name = "ThunderWarning"; model.Parent = parent
	local puffs = {}
	for i, spec in THUNDER_PUFF_SPECS do
		local puff = part(model, spec.name, spec.size, CFrame.new(), spec.color)
		puff.Shape, puff.Transparency = Enum.PartType.Ball, .12
		puffs[i] = { part = puff, pos = spec.pos }
	end
	local glow = part(model, "ElectricGlow", Vector3.new(.25, 1.4, .25), CFrame.new(), Color3.fromRGB(90, 230, 255))
	glow.Material = Enum.Material.Neon
	warningCache[model] = { puffs = puffs, glow = glow }
	Visuals.updateThunderWarning(model, chassis)
	return model
end
function Visuals.updateThunderWarning(model, chassis)
	local pos = chassis.Position
	local cached = warningCache[model]
	if cached then
		for _, entry in cached.puffs do
			entry.part.CFrame = CFrame.new(pos + entry.pos)
		end
		cached.glow.CFrame = CFrame.new(pos + THUNDER_GLOW_OFFSET)
		return
	end
	for _, spec in THUNDER_PUFF_SPECS do
		local puff = model:FindFirstChild(spec.name)
		if puff then puff.CFrame = CFrame.new(pos + spec.pos) end
	end
	model.ElectricGlow.CFrame = CFrame.new(pos + THUNDER_GLOW_OFFSET)
end
function Visuals.thunderStrike(parent, chassis, blocked)
	local model = Instance.new("Model"); model.Name = if blocked then "ThunderShieldImpact" else "ThunderStrike"; model.Parent = parent
	local bolts = {}
	local boltColor = Color3.fromRGB(210, 250, 255)
	local height = Config.ThunderWarning.OffsetY / 3
	local boltSize = Vector3.new(.8, height + .5, .8)
	for i = 1, 3 do
		local bolt = part(model, "Bolt"..i, boltSize, CFrame.new(chassis.Position + Vector3.new(if i == 2 then .4 else 0, Config.ThunderWarning.OffsetY - (i - .5) * height, 0)) * CFrame.Angles(0, 0, if i == 2 then .35 else -.18), boltColor)
		bolt.Material = Enum.Material.Neon
		bolts[i] = bolt
	end
	local flash = part(model, "Impact", Vector3.new(5, .25, 5), CFrame.new(chassis.Position), Color3.fromRGB(65, 225, 255))
	flash.Material = Enum.Material.Neon; flash.Transparency = .65
	local arcs, burst, light
	if blocked then
		-- Absorbed strike ends at the shell; no full electric ground burst.
		for i = 1, 3 do bolts[i].Transparency = .75 end
	else
		arcs = rays(flash, Config.Thunder.ArcCount, 3, Color3.fromRGB(100, 235, 255), "ElectricArc")
		burst = Visuals.missileImpact(model, chassis.Position, false)
		burst.Name = "ThunderExplosion"
		light = Instance.new("PointLight"); light.Name = "ImpactLight"
		light.Range = Config.ThunderImpact.LightRange; light.Brightness = 0; light.Enabled = false
		light.Color = Color3.fromRGB(255, 225, 150); light.Shadows = false; light.Parent = burst
	end
	strikeCache[model] = { bolts = bolts, flash = flash, arcs = arcs, burst = burst, light = light, burstHidden = false }
	Visuals.updateThunderStrike(model, 0)
	return model
end

function Visuals.thunderStrikeLifetime(blocked)
	return if blocked then Config.Thunder.StrikeLifetime else math.max(Config.Thunder.StrikeLifetime, Config.ThunderImpact.Delay + Config.Missile.ImpactLifetime)
end
function Visuals.updateThunderStrike(model, age)
	local c = Config.Thunder
	local t = math.clamp(age / c.StrikeLifetime, 0, 1)
	local primary = math.max(0, 1 - age / c.PrimaryDuration)
	local after = if age < c.AfterFlashDelay then 0 else c.AfterFlashScale * (1 - math.clamp((age - c.AfterFlashDelay) / (c.StrikeLifetime - c.AfterFlashDelay), 0, 1))
	local blocked = model.Name == "ThunderShieldImpact"
	local intensity = if blocked then .20 * (1 - t) else math.max(primary, after)
	local boltTrans = 1 - intensity * .80
	local arcTrans = 1 - intensity * .65
	local cached = strikeCache[model]
	if cached then
		for _, bolt in cached.bolts do bolt.Transparency = boltTrans end
		cached.flash.Transparency = arcTrans
		if cached.arcs then
			for _, arc in cached.arcs do arc.Transparency = arcTrans end
		end
		local burst = cached.burst
		if burst then
			local burstAge = age - Config.ThunderImpact.Delay
			if burstAge < 0 then
				if not cached.burstHidden then
					burst.Transparency = 1
					for _, p in burst:GetDescendants() do if p:IsA("BasePart") then p.Transparency = 1 end end
					cached.burstHidden = true
				end
			else
				cached.burstHidden = false
				Visuals.updateMissileImpact(burst, burstAge)
			end
			local fade = math.clamp(1 - burstAge / Config.Missile.ImpactLifetime, 0, 1)
			local light = cached.light or burst.ImpactLight
			light.Enabled = burstAge >= 0 and fade > 0
			light.Brightness = if light.Enabled then Config.ThunderImpact.LightBrightness * fade * fade else 0
		end
		return
	end
	local burst = model:FindFirstChild("ThunderExplosion")
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= burst then
			-- Fade the initial vertical strike; residual arcs/ground pulse remain lighter.
			p.Transparency = if p.Name:match("^Bolt") then boltTrans else arcTrans
			for _, arc in p:GetChildren() do if arc:IsA("BasePart") then arc.Transparency = arcTrans end end
		end
	end
	if burst then
		local burstAge = age - Config.ThunderImpact.Delay
		if burstAge < 0 then
			burst.Transparency = 1
			for _, p in burst:GetDescendants() do if p:IsA("BasePart") then p.Transparency = 1 end end
		else Visuals.updateMissileImpact(burst, burstAge) end
		local fade = math.clamp(1 - burstAge / Config.Missile.ImpactLifetime, 0, 1)
		local light = burst.ImpactLight
		light.Enabled = burstAge >= 0 and fade > 0
		light.Brightness = if light.Enabled then Config.ThunderImpact.LightBrightness * fade * fade else 0
	end
end
return Visuals
