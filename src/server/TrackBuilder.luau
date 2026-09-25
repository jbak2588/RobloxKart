local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TrackGeometry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrackGeometry"))

local TrackBuilder = {}

local function createPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function TrackBuilder.build(prototype: Folder, track, groundTop: number): Model
	local definition = TrackGeometry.getDefinition(track.GeometryId)
	assert(definition, "Track geometry is missing: " .. tostring(track.GeometryId))
	local previousTrack = prototype:FindFirstChild("TestTrack")
	if previousTrack and previousTrack:IsA("Model")
		and previousTrack:GetAttribute("GeometryId") == track.GeometryId
		and previousTrack:GetAttribute("TrackId") == track.Id
		and previousTrack:FindFirstChild("Road")
		and previousTrack:FindFirstChild("RaceTriggers")
	then
		return previousTrack
	end
	local course = TrackGeometry.getCourse(definition)
	local samples = course.Samples
	local checkpointSamples = course.CheckpointSamples
	local roadWidth = definition.RoadWidth
	local roadY = groundTop + 0.04

	local testTrack = Instance.new("Model")
	testTrack.Name = "TestTrack"
	local roadFolder = Instance.new("Folder")
	roadFolder.Name = "Road"
	roadFolder.Parent = testTrack
	local markingFolder = Instance.new("Folder")
	markingFolder.Name = "Markings"
	markingFolder.Parent = testTrack
	local markerFolder = Instance.new("Folder")
	markerFolder.Name = "Markers"
	markerFolder.Parent = testTrack
	local raceTriggerFolder = Instance.new("Folder")
	raceTriggerFolder.Name = "RaceTriggers"
	raceTriggerFolder.Parent = testTrack

	local partCount = 0
	local roadColor = Color3.fromRGB(48, 51, 56)
	local white = Color3.fromRGB(245, 245, 235)

	local function roadPoint(point: Vector3, height: number): Vector3
		return Vector3.new(point.X, roadY + point.Y + height, point.Z)
	end

	local function createVisualPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
		local part = createPart(parent, name, size, cframe, color)
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = material or Enum.Material.SmoothPlastic
		partCount += 1
		return part
	end

	local function createSegment(parent: Instance, name: string, first: Vector3, second: Vector3, width: number, thickness: number, overhang: number, color: Color3, material: Enum.Material?)
		local delta = second - first
		local midpoint = (first + second) * 0.5
		createVisualPart(
			parent,
			name,
			Vector3.new(width, thickness, delta.Magnitude + overhang),
			CFrame.lookAt(midpoint, midpoint + delta.Unit),
			color,
			material
		)
	end

	local function directionAt(index: number): Vector3
		local previous = samples[(index - 2) % #samples + 1]
		local following = samples[index % #samples + 1]
		local delta = following - previous
		return Vector3.new(delta.X, 0, delta.Z).Unit
	end
	local function turnAt(index: number): number
		local previous = samples[(index - 2) % #samples + 1]
		local current = samples[index]
		local following = samples[index % #samples + 1]
		local arriving = (current - previous).Unit
		local leaving = (following - current).Unit
		return math.acos(math.clamp(arriving:Dot(leaving), -1, 1))
	end

	for index = 1, #samples do
		local nextIndex = index % #samples + 1
		local first = samples[index]
		local second = samples[nextIndex]
		local bend = math.max(turnAt(index), turnAt(nextIndex))
		local overhang = math.max(1.5, roadWidth * math.tan(bend * 0.5) + 1)
		createSegment(
			roadFolder, "Road" .. index, roadPoint(first, 0), roadPoint(second, 0),
			roadWidth, 0.05, overhang, roadColor, Enum.Material.Asphalt
		)

		local firstDirection = directionAt(index)
		local secondDirection = directionAt(nextIndex)
		local firstRight = Vector3.new(-firstDirection.Z, 0, firstDirection.X)
		local secondRight = Vector3.new(-secondDirection.Z, 0, secondDirection.X)
		for _, side in { -1, 1 } do
			local firstEdge = first + firstRight * (roadWidth * 0.5 * side)
			local secondEdge = second + secondRight * (roadWidth * 0.5 * side)
			createSegment(
				markingFolder, (if side < 0 then "LeftEdge" else "RightEdge") .. index,
				roadPoint(firstEdge, 0.04), roadPoint(secondEdge, 0.04),
				1, 0.035, 0.6, white, nil
			)
		end

		if index % 3 == 1 then
			createSegment(
				markingFolder, "CenterDash" .. index,
				roadPoint(first:Lerp(second, 0.22), 0.04),
				roadPoint(first:Lerp(second, 0.78), 0.04),
				0.8, 0.03, 0, white, nil
			)
		end
	end

	local function createRaceGate(name: string, point: Vector3, direction: Vector3, gateType: string, checkpointIndex: number?)
		local gatePosition = Vector3.new(point.X, groundTop + 8, point.Z)
		local planarDirection = Vector3.new(direction.X, 0, direction.Z).Unit
		local gate = createPart(
			raceTriggerFolder, name, Vector3.new(roadWidth + 20, 20, 20),
			CFrame.lookAt(gatePosition, gatePosition + planarDirection), Color3.new(1, 1, 1)
		)
		gate.Anchored = true
		gate.CanCollide = false
		gate.CanTouch = false
		gate.CanQuery = false
		gate.Transparency = 1
		gate:SetAttribute("RaceGate", true)
		gate:SetAttribute("GateType", gateType)
		if checkpointIndex then
			gate:SetAttribute("CheckpointIndex", checkpointIndex)
		end
	end

	local startPoint = course.StartPosition
	local startDirection = course.StartTangent
	createVisualPart(
		markingFolder, "StartLine", Vector3.new(roadWidth, 0.03, 3),
		CFrame.lookAt(roadPoint(startPoint, 0.04), roadPoint(startPoint + startDirection, 0.04)),
		white, nil
	)
	createRaceGate("StartFinish", startPoint, startDirection, "StartFinish", nil)
	for index, checkpoint in checkpointSamples do
		createRaceGate(
			"Checkpoint" .. index,
			checkpoint.Position,
			checkpoint.Tangent,
			"Checkpoint", index
		)
	end

	testTrack:SetAttribute("GeometryId", track.GeometryId)
	testTrack:SetAttribute("TrackId", track.Id)
	testTrack:SetAttribute("VisualPartCount", partCount)
	testTrack:SetAttribute("CheckpointCount", #checkpointSamples)
	testTrack:SetAttribute("CenterlineLength", course.CenterlineLength)
	testTrack:SetAttribute("CenterlineSampleCount", #samples)
	testTrack:SetAttribute("RoadSegmentCount", #samples)
	testTrack:SetAttribute("RoadWidth", roadWidth)
	if previousTrack then
		previousTrack:Destroy()
	end
	testTrack.Parent = prototype
	return testTrack
end

return TrackBuilder
