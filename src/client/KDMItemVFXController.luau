-- Short observer-visible Slick tire cue and Damage Smoke plume. Server state alone starts it.
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KDMItemVFXConfig"))

local RunService = nil
pcall(function() RunService = game:GetService("RunService") end)

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local function safeNumberSequence(points)
	local ok, seq = pcall(function()
		local kps = {}
		for _, p in points do
			table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2]))
		end
		return NumberSequence.new(kps)
	end)
	return if ok then seq else nil
end

local function safeNumberRange(min, max)
	local ok, range = pcall(function() return NumberRange.new(min, max) end)
	return if ok then range else min
end

local function safeColorSequence(c1, c2)
	local ok, seq = pcall(function()
		if c2 then
			return ColorSequence.new(c1, c2)
		else
			return ColorSequence.new(c1)
		end
	end)
	return if ok then seq else nil
end

local function safeVector2(x, y)
	local ok, v = pcall(function() return Vector2.new(x, y) end)
	return if ok then v else nil
end

local function makeDamageSmoke(parent: BasePart, isThunder: boolean): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "KDMDamageSmokeAttachment"
	attachment.Position = Vector3.new(0, 1.4, 1.8)
	attachment.Parent = parent

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "DamageSmoke"
	smoke.Texture = SMOKE_TEXTURE
	smoke.Rate = 35 -- Dense billowing emission
	smoke.Lifetime = safeNumberRange(1.6, 2.4) -- Extended linger trail behind kart
	smoke.Speed = safeNumberRange(6, 12)
	smoke.EmissionDirection = Enum.NormalId.Top
	local spread = safeVector2(20, 20)
	if spread then smoke.SpreadAngle = spread end
	smoke.VelocityInheritance = 0.25
	smoke.Drag = 1.4
	smoke.Rotation = safeNumberRange(-180, 180)
	smoke.RotSpeed = safeNumberRange(-30, 30)

	local smokeColor = safeColorSequence(Color3.fromRGB(35, 36, 42), Color3.fromRGB(75, 80, 92))
	if smokeColor then smoke.Color = smokeColor end

	local smokeSize = safeNumberSequence({ {0, 1.4}, {0.35, 3.2}, {0.75, 5.0}, {1, 6.8} })
	if smokeSize then smoke.Size = smokeSize end

	local smokeTrans = safeNumberSequence({ {0, 0.05}, {0.3, 0.25}, {0.7, 0.6}, {1, 1} })
	if smokeTrans then smoke.Transparency = smokeTrans end

	smoke.Parent = attachment

	if isThunder then
		local spark = Instance.new("ParticleEmitter")
		spark.Name = "ElectricSpark"
		spark.Rate = 20
		spark.Lifetime = safeNumberRange(0.18, 0.35)
		spark.Speed = safeNumberRange(5, 10)
		local sparkSpread = safeVector2(55, 55)
		if sparkSpread then spark.SpreadAngle = sparkSpread end
		spark.LightEmission = 1.0
		local sparkColor = safeColorSequence(Color3.fromRGB(120, 240, 255))
		if sparkColor then spark.Color = sparkColor end
		local sparkSize = safeNumberSequence({ {0, 0.8}, {1, 0.15} })
		if sparkSize then spark.Size = sparkSize end
		spark.Parent = attachment
	end

	return attachment
end

local function getChildren(instance)
	if type(instance.GetChildren) == "function" then
		return instance:GetChildren()
	elseif instance.children then
		return instance.children
	end
	return {}
end

local Controller = {}
local stop

function Controller.start()
	if stop then return end
	local records, connections = {}, {}

	local function clearEffect(record)
		if record.effect then record.effect:Destroy(); record.effect = nil end
	end

	local function clearDamageSmoke(record, fade: boolean)
		if record.damageAttachment then
			if fade then
				for _, emitter in getChildren(record.damageAttachment) do
					if emitter:IsA("ParticleEmitter") then
						emitter.Enabled = false
					end
				end
				Debris:AddItem(record.damageAttachment, 2.5)
			else
				record.damageAttachment:Destroy()
			end
			record.damageAttachment = nil
		end
	end

	local function remove(kart)
		local record = records[kart]
		if not record then return end
		clearEffect(record)
		clearDamageSmoke(record, false)
		for _, connection in record.connections do connection:Disconnect() end
		records[kart] = nil
	end

	local function bind(kart)
		if records[kart] or not kart:IsA("Model") then return end
		local isKart = kart:GetAttribute("PrototypeKart") == true
			or kart:GetAttribute("LobbyKart") == true
			or kart:GetAttribute("LobbyPracticeBot") == true
			or kart:GetAttribute("LobbyDemoBot") == true
			or (kart.Name and (kart.Name:find("LobbyKart") ~= nil or kart.Name:find("LobbyPracticeBot") ~= nil or kart.Name:find("KDMClientDemoBot") ~= nil))
		if not isKart then return end

		local record = {
			connections = {},
			previousSlick = kart:GetAttribute("KartSlickActive") == true,
			damageAttachment = nil,
		}
		records[kart] = record

		local function updateDamage()
			local missile = kart:GetAttribute("KartMissileHitActive") == true
			local thunder = kart:GetAttribute("KartThunderHitActive") == true
			local locked = kart:GetAttribute("RaceControlsLocked") == true
			local isDamaged = (missile or thunder) and not locked
			local chassis = kart.PrimaryPart or (if type(kart.FindFirstChild) == "function" then kart:FindFirstChild("Chassis") else nil)

			if isDamaged and chassis then
				if not record.damageAttachment then
					record.damageAttachment = makeDamageSmoke(chassis, thunder)
				end
			else
				clearDamageSmoke(record, true)
			end
		end

		table.insert(record.connections, kart:GetAttributeChangedSignal("KartSlickActive"):Connect(function()
			local active = kart:GetAttribute("KartSlickActive") == true
			clearEffect(record)
			local chassis = kart.PrimaryPart or (if type(kart.FindFirstChild) == "function" then kart:FindFirstChild("Chassis") else nil)
			if active and not record.previousSlick and chassis and kart:GetAttribute("RaceControlsLocked") ~= true then
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
			record.previousSlick = active
		end))

		table.insert(record.connections, kart:GetAttributeChangedSignal("KartMissileHitActive"):Connect(updateDamage))
		table.insert(record.connections, kart:GetAttributeChangedSignal("KartThunderHitActive"):Connect(updateDamage))

		for _, attribute in {"RaceResetSerial", "RaceControlsLocked"} do
			table.insert(record.connections, kart:GetAttributeChangedSignal(attribute):Connect(function()
				clearEffect(record)
				clearDamageSmoke(record, false)
			end))
		end

		table.insert(record.connections, kart.Destroying:Connect(function() remove(kart) end))
		updateDamage()
	end

	local function watchContainer(container)
		if not container then return end
		if container.GetDescendants then
			for _, instance in container:GetDescendants() do bind(instance) end
		end
		if container.DescendantAdded then
			table.insert(connections, container.DescendantAdded:Connect(bind))
		end
		if container.DescendantRemoving then
			table.insert(connections, container.DescendantRemoving:Connect(remove))
		end
	end

	local prototype = if Workspace.WaitForChild then Workspace:WaitForChild("Prototype") else nil
	if prototype then watchContainer(prototype) end

	local hub = if type(Workspace.FindFirstChild) == "function" then Workspace:FindFirstChild("KDMHub") else nil
	if hub then
		watchContainer(hub)
	elseif Workspace.ChildAdded then
		table.insert(connections, Workspace.ChildAdded:Connect(function(child)
			if child.Name == "KDMHub" then watchContainer(child) end
		end))
	end

	local scan = 0
	if RunService and RunService.Heartbeat then
		table.insert(connections, RunService.Heartbeat:Connect(function(dt)
			scan += dt
			if scan >= 0.25 then
				scan = 0
				if prototype and prototype.GetChildren then
					for _, o in prototype:GetChildren() do bind(o) end
				end
				local h = if type(Workspace.FindFirstChild) == "function" then Workspace:FindFirstChild("KDMHub") else nil
				if h then
					local zone = if type(h.FindFirstChild) == "function" then h:FindFirstChild("LobbyFrontTestDriveZone", true) else nil
					if not zone and type(h.FindFirstChild)=='function'then zone=h:FindFirstChild('HubParkRookieLoopG2',true)end
					if zone and zone.GetChildren then
						for _, o in zone:GetChildren() do bind(o) end
					end
				end
			end
		end))
	end

	stop = function()
		for kart in records do remove(kart) end
		for _, connection in connections do connection:Disconnect() end
		stop = nil
	end

	table.insert(connections, prototype.Destroying:Connect(function() Controller.destroy() end))
	table.insert(connections, Players.LocalPlayer.AncestryChanged:Connect(function(_, parent) if not parent then Controller.destroy() end end))
end

function Controller.destroy()
	if stop then stop() end
end

return Controller
