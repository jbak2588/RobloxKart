-- Short observer-visible Slick tire cue. Server state alone starts it.
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KDMItemVFXConfig"))
local Controller = {}
local stop
function Controller.start()
	if stop then return end
	local records, connections = {}, {}
	local function clearEffect(record)
		if record.effect then record.effect:Destroy(); record.effect = nil end
	end
	local function remove(kart)
		local record = records[kart]
		if not record then return end
		clearEffect(record)
		for _, connection in record.connections do connection:Disconnect() end
		records[kart] = nil
	end
	local function bind(kart)
		if records[kart] or not kart:IsA("Model") or kart:GetAttribute("PrototypeKart") ~= true then return end
		local record = { connections = {}, previous = kart:GetAttribute("KartSlickActive") == true }
		records[kart] = record
		table.insert(record.connections, kart:GetAttributeChangedSignal("KartSlickActive"):Connect(function()
			local active = kart:GetAttribute("KartSlickActive") == true
			clearEffect(record)
			local chassis = kart.PrimaryPart
			if active and not record.previous and chassis and kart:GetAttribute("RaceControlsLocked") ~= true then
				local model = Instance.new("Model")
				model.Name = "KDMSlickTireCue"
				for _, side in {-1, 1} do
					local puff = Instance.new("Part")
					puff.Name, puff.Shape = "TirePuff", Enum.PartType.Ball
					puff.Size, puff.Color = Vector3.new(1.5,.65,1.8), Color3.fromRGB(165,175,185)
					puff.CFrame = chassis.CFrame*CFrame.new(side*2.7, .15, 2.3)
					puff.Transparency, puff.CastShadow = .72, false
					puff.Anchored, puff.CanCollide, puff.CanTouch, puff.CanQuery = true, false, false, false
					puff.Parent = model
				end
				model.Parent, record.effect = Workspace, model
				Debris:AddItem(model, Config.Slick.VisualSmokeLifetime)
			end
			record.previous = active
		end))
		for _, attribute in {"RaceResetSerial", "RaceControlsLocked"} do
			table.insert(record.connections, kart:GetAttributeChangedSignal(attribute):Connect(function() clearEffect(record) end))
		end
		table.insert(record.connections, kart.Destroying:Connect(function() remove(kart) end))
	end
	local prototype = Workspace:WaitForChild("Prototype")
	for _, instance in prototype:GetDescendants() do bind(instance) end
	table.insert(connections, prototype.DescendantAdded:Connect(bind))
	table.insert(connections, prototype.DescendantRemoving:Connect(remove))
	stop = function()
		for kart in records do remove(kart) end
		for _, connection in connections do connection:Disconnect() end
		stop = nil
	end
	table.insert(connections, prototype.Destroying:Connect(function() Controller.destroy() end))
	table.insert(connections, Players.LocalPlayer.AncestryChanged:Connect(function(_, parent) if not parent then Controller.destroy() end end))
end
function Controller.spawnMissileImpact(pos, hitNormal)
	local config = Config.MissileImpact
	local root = Instance.new("Part")
	root.Name = "MissileImpactRoot"
	root.Anchored = true; root.CanCollide = false; root.Transparency = 1
	root.Position = pos; root.Parent = Workspace

	local light = Instance.new("PointLight", root)
	light.Color = Color3.fromRGB(255, 170, 40)
	light.Range = config.LightRadius
	light.Brightness = config.LightBrightness

	local ring = Instance.new("SelectionBox")
	ring.Adornee = root
	ring.Color3 = Color3.fromRGB(255, 200, 60)
	ring.LineThickness = 0.4
	ring.Parent = root
	if TweenService and TweenService.Create then
		pcall(function()
			TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				LineThickness = 0.01,
			}):Play()
		end)
	end

	local shock = Instance.new("ParticleEmitter", root)
	shock.Texture = "rbxasset://textures/particles/smoke_main.dds"
	shock.Size = NumberSequence.new(4, config.Size)
	shock.Color = ColorSequence.new(Color3.fromRGB(255, 120, 20), Color3.fromRGB(40, 40, 40))
	shock.Lifetime = NumberRange.new(0.4, config.Duration)
	shock.Speed = NumberRange.new(8, 26)
	shock.SpreadAngle = Vector2.new(180, 180)
	shock:Emit(35)

	Debris:AddItem(root, config.Duration + 0.5)
	return root
end

function Controller.attachThunderCloud(targetChassis)
	local cfg = Config.ThunderWarning
	local cloudPart = Instance.new("Part")
	cloudPart.Name = "ThunderCloud"
	cloudPart.Size = cfg.CloudSize
	cloudPart.Transparency = 0.35
	cloudPart.Material = Enum.Material.ForceField
	cloudPart.Color = Color3.fromRGB(25, 20, 45)
	cloudPart.CanCollide = false; cloudPart.Anchored = false

	local darkSmoke = Instance.new("ParticleEmitter", cloudPart)
	darkSmoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	darkSmoke.Color = ColorSequence.new(Color3.fromRGB(35, 30, 55))
	darkSmoke.Size = cfg.ParticleSize
	darkSmoke.Rate = 45
	darkSmoke.Lifetime = NumberRange.new(1.0, 1.8)
	darkSmoke.Speed = NumberRange.new(1, 3)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = targetChassis
	weld.Part1 = cloudPart
	weld.Parent = cloudPart
	cloudPart.CFrame = targetChassis.CFrame * CFrame.new(cfg.CloudOffset)
	cloudPart.Parent = targetChassis
	return cloudPart
end

function Controller.destroy() if stop then stop() end end
return Controller
