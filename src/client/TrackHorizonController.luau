-- Client-only low-poly horizon mountains and rolling hills surrounding race tracks.
-- Zero server CPU/memory/network overhead; completely non-interactive visual scenery.
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Controller = {}
local stop = nil

local NEAR_COLORS = {
	Color3.fromRGB(54, 78, 56),
	Color3.fromRGB(64, 88, 66),
	Color3.fromRGB(58, 82, 60),
	Color3.fromRGB(70, 94, 72),
}

local FAR_COLORS = {
	Color3.fromRGB(68, 84, 98),
	Color3.fromRGB(76, 92, 106),
	Color3.fromRGB(84, 100, 114),
	Color3.fromRGB(92, 108, 122),
}

local function createVisualWedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = name
	wedge.Size = size
	wedge.CFrame = cf
	wedge.Color = color
	wedge.Material = Enum.Material.SmoothPlastic
	wedge.Anchored = true
	wedge.CanCollide = false
	wedge.CanTouch = false
	wedge.CanQuery = false
	wedge.CastShadow = false
	wedge.Parent = parent
	return wedge
end

local function createVisualBlock(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function getTrackBounds(testTrack: Model): (Vector3, number, number)
	local road = testTrack:FindFirstChild("Road")
	if not road then return Vector3.zero, 480, 0 end
	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge
	local groundY = 0
	for _, part in road:GetChildren() do
		if part:IsA("BasePart") then
			minX = math.min(minX, part.Position.X - part.Size.X * 0.5)
			maxX = math.max(maxX, part.Position.X + part.Size.X * 0.5)
			minZ = math.min(minZ, part.Position.Z - part.Size.Z * 0.5)
			maxZ = math.max(maxZ, part.Position.Z + part.Size.Z * 0.5)
			groundY = part.Position.Y
		end
	end
	local center = Vector3.new((minX + maxX) * 0.5, groundY, (minZ + maxZ) * 0.5)
	local radius = math.max((maxX - minX) * 0.5, (maxZ - minZ) * 0.5)
	return center, math.max(460, radius + 140), groundY
end

local function buildHorizon(testTrack: Model, parentFolder: Instance): Model
	local model = Instance.new("Model")
	model.Name = "ClientHorizonEnvironment"
	model.Parent = parentFolder

	local center, baseRadius, groundY = getTrackBounds(testTrack)
	local sectorCount = 18 -- 18 sectors surrounding the circuit (20 degrees each)

	-- 1. Outer Majestic Mountain Peaks (Far horizon layer)
	local outerRadius = baseRadius + 130
	for i = 1, sectorCount do
		local angle = (i - 1) * (math.pi * 2 / sectorCount)
		local peakHeight = 75 + ((i * 37) % 35) -- Varied heights: 75 to 110 studs
		local peakWidth = 130 + ((i * 23) % 40)
		local peakDepth = 90 + ((i * 19) % 30)

		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local peakPos = center + dir * outerRadius
		local lookAway = CFrame.lookAt(peakPos, peakPos + dir)

		local color = FAR_COLORS[(i % #FAR_COLORS) + 1]

		-- Front slope
		local frontCf = lookAway * CFrame.new(0, groundY + peakHeight * 0.5 - 2, -peakDepth * 0.25)
		createVisualWedge(model, "MountainFront" .. i, Vector3.new(peakWidth, peakHeight, peakDepth * 0.5), frontCf, color)

		-- Back slope
		local backCf = lookAway * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, groundY + peakHeight * 0.5 - 2, -peakDepth * 0.25)
		createVisualWedge(model, "MountainBack" .. i, Vector3.new(peakWidth, peakHeight, peakDepth * 0.5), backCf, color)
	end

	-- 2. Inner Rolling Forest Hills (Mid-ground layer)
	local innerRadius = baseRadius + 40
	for i = 1, sectorCount do
		local offsetAngle = (i - 0.5) * (math.pi * 2 / sectorCount)
		local hillHeight = 35 + ((i * 29) % 25) -- Heights: 35 to 60 studs
		local hillWidth = 110 + ((i * 31) % 35)
		local hillDepth = 80 + ((i * 17) % 25)

		local dir = Vector3.new(math.cos(offsetAngle), 0, math.sin(offsetAngle))
		local hillPos = center + dir * innerRadius
		local lookAway = CFrame.lookAt(hillPos, hillPos + dir)

		local color = NEAR_COLORS[(i % #NEAR_COLORS) + 1]

		-- Front hill slope
		local frontCf = lookAway * CFrame.new(0, groundY + hillHeight * 0.5 - 2, -hillDepth * 0.25)
		createVisualWedge(model, "HillFront" .. i, Vector3.new(hillWidth, hillHeight, hillDepth * 0.5), frontCf, color)

		-- Back hill slope
		local backCf = lookAway * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, groundY + hillHeight * 0.5 - 2, -hillDepth * 0.25)
		createVisualWedge(model, "HillBack" .. i, Vector3.new(hillWidth, hillHeight, hillDepth * 0.5), backCf, color)
	end

	-- 3. Perimeter Horizon Base Skirt (Eliminates any bottom gap or void horizon)
	local skirtColor = Color3.fromRGB(48, 70, 50)
	for i = 1, sectorCount do
		local angle = (i - 1) * (math.pi * 2 / sectorCount)
		local nextAngle = i * (math.pi * 2 / sectorCount)
		local p1 = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (baseRadius + 20)
		local p2 = center + Vector3.new(math.cos(nextAngle), 0, math.sin(nextAngle)) * (baseRadius + 20)
		local mid = (p1 + p2) * 0.5
		local segLength = (p2 - p1).Magnitude
		local segLook = CFrame.lookAt(mid + Vector3.new(0, groundY - 2, 0), p2 + Vector3.new(0, groundY - 2, 0))
		createVisualBlock(model, "Skirt" .. i, Vector3.new(60, 6, segLength + 2), segLook, skirtColor)
	end

	return model
end

function Controller.start()
	if stop then return end
	local connections = {}
	local activeHorizonModel = nil

	local function clearHorizon()
		if activeHorizonModel then
			activeHorizonModel:Destroy()
			activeHorizonModel = nil
		end
	end

	local function onTrackChanged(testTrack: Instance?)
		clearHorizon()
		if testTrack and testTrack:IsA("Model") and testTrack:FindFirstChild("Road") then
			activeHorizonModel = buildHorizon(testTrack, testTrack)
		end
	end

	local prototype = if Workspace.WaitForChild then Workspace:WaitForChild("Prototype") else nil
	if prototype then
		local initialTrack = if prototype.FindFirstChild then prototype:FindFirstChild("TestTrack") else nil
		if initialTrack then onTrackChanged(initialTrack) end

		if prototype.ChildAdded then
			table.insert(connections, prototype.ChildAdded:Connect(function(child)
				if child.Name == "TestTrack" then onTrackChanged(child) end
			end))
		end

		if prototype.ChildRemoved then
			table.insert(connections, prototype.ChildRemoved:Connect(function(child)
				if child.Name == "TestTrack" then clearHorizon() end
			end))
		end
	end

	stop = function()
		clearHorizon()
		for _, conn in connections do conn:Disconnect() end
		stop = nil
	end

	if prototype and prototype.Destroying then
		table.insert(connections, prototype.Destroying:Connect(function() Controller.destroy() end))
	end
	if Players.LocalPlayer and Players.LocalPlayer.AncestryChanged then
		table.insert(connections, Players.LocalPlayer.AncestryChanged:Connect(function(_, parent)
			if not parent then Controller.destroy() end
		end))
	end
end

function Controller.destroy()
	if stop then stop() end
end

return Controller
