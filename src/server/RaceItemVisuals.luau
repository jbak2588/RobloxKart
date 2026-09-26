-- Original temporary geometry outside Kart/Visual's production contract.
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
	deploy.surface.Size = Vector3.new(deploy.width * scale, 0.1, deploy.length * scale)
	deploy.surface.Transparency = 1 - reveal
	for i, edge in deploy.edges do
		local side = if i == 1 then -1 else 1
		edge.Size = Vector3.new(0.35, 0.12, deploy.length * 0.72 * scale)
		edge.CFrame = deploy.frame * CFrame.new(side * (deploy.width * 0.5 - 0.15) * scale, 0.03, 0)
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
	local surface = part(model, "SlickSurface", Vector3.new(config.SLICK_WIDTH, 0.10, config.SLICK_LENGTH), frame, Color3.fromRGB(30, 24, 43))
	surface.Shape = Enum.PartType.Ball
	local edges = {}
	for _, side in { -1, 1 } do
		table.insert(edges, part(model, "Edge"..side, Vector3.new(0.3, 0.12, config.SLICK_LENGTH),
			frame * CFrame.new(side*(config.SLICK_WIDTH*0.5-0.15), 0.03, 0), Color3.fromRGB(180, 115, 245)))
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
	for _, edge in edges do edge.Shape = Enum.PartType.Ball end
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
return Visuals
