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
	local isHardCircuit = track.GeometryId == "HardCircuitV1"
	local environmentVersion = if isHardCircuit then 6 else 1
	local previousTrack = prototype:FindFirstChild("TestTrack")
	if previousTrack and previousTrack:IsA("Model")
		and previousTrack:GetAttribute("GeometryId") == track.GeometryId
		and previousTrack:GetAttribute("TrackId") == track.Id
		and previousTrack:FindFirstChild("Road")
		and previousTrack:FindFirstChild("RaceTriggers")
		and previousTrack:FindFirstChild("BarrierTriggers")
		and previousTrack:GetAttribute("BarrierForwardTangentVersion") == 1
		and previousTrack:GetAttribute("EnvironmentCueVersion") == environmentVersion
		and not previousTrack:FindFirstChild("BarrierCollisions")
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
	local environmentFolder = Instance.new("Folder")
	environmentFolder.Name = "Environment"
	environmentFolder.Parent = testTrack
	local speedCues = Instance.new("Folder")
	speedCues.Name = "SpeedCues"
	speedCues.Parent = environmentFolder
	local markingFolder = Instance.new("Folder")
	markingFolder.Name = "Markings"
	markingFolder.Parent = testTrack
	local kerbFolder = Instance.new("Folder")
	kerbFolder.Name = "Kerbs"
	kerbFolder.Parent = testTrack
	local barrierFolder = Instance.new("Folder")
	barrierFolder.Name = "Barriers"
	barrierFolder.Parent = testTrack
	local barrierTriggerFolder = Instance.new("Folder")
	barrierTriggerFolder.Name = "BarrierTriggers"
	barrierTriggerFolder.Parent = testTrack
	local markerFolder = Instance.new("Folder")
	markerFolder.Name = "Markers"
	markerFolder.Parent = testTrack
	local raceTriggerFolder = Instance.new("Folder")
	raceTriggerFolder.Name = "RaceTriggers"
	raceTriggerFolder.Parent = testTrack

	local partCount = 0
	local roadColor = Color3.fromRGB(48, 51, 56)
	local white = Color3.fromRGB(245, 245, 235)
	local kerbRed = Color3.fromRGB(205, 48, 45)
	local kerbWhite = Color3.fromRGB(238, 236, 229)
	local isPractice = track.GeometryId == "PracticeCircuitV1"
	local kerbThreshold = math.rad(if isPractice then 5 else 3.5)
	if isHardCircuit then kerbThreshold = math.atan(definition.SampleSpacing / 350) end
	local barrierThreshold = math.rad(if isPractice then 7 else 9)
	local kerbCount = 0
	local barrierCount = 0
	local checkerCount = 0
	local barrierStride = if isPractice then 3 else 2

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

	local function createSegment(parent: Instance, name: string, first: Vector3, second: Vector3, width: number, thickness: number, overhang: number, color: Color3, material: Enum.Material?): Part
		local delta = second - first
		local midpoint = (first + second) * 0.5
		return createVisualPart(
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

	local function signedTurnAt(index: number): number
		local previous = samples[(index - 2) % #samples + 1]
		local current = samples[index]
		local following = samples[index % #samples + 1]
		local arriving = (current - previous).Unit
		local leaving = (following - current).Unit
		return arriving:Cross(leaving).Y
	end

	-- Sample zero is on the long finish straight: corner runs cannot wrap the grid.
	local cornerZones = {}
	local cornerSegments = {}
	if isHardCircuit then
		local index = 4
		while index <= #samples - 3 do
			if turnAt(index) >= kerbThreshold then
				local first = index
				local side = if signedTurnAt(index) > 0 then -1 else 1
				while index <= #samples - 3 and turnAt(index) >= kerbThreshold
					and (if signedTurnAt(index) > 0 then -1 else 1) == side do
					index += 1
				end
				-- At least one normal-speed second of connected curvature, not a spline ripple.
				if (index - first) * definition.SampleSpacing >= 70 then
					local zone = { First = first - 2, Last = index + 1, Side = side }
					table.insert(cornerZones, zone)
					for segment = zone.First, zone.Last do cornerSegments[segment] = true end
				end
			else
				index += 1
			end
		end
	end

	if isHardCircuit then
		for index = 4, #samples - 3 do
			if turnAt(index) >= kerbThreshold then cornerSegments[index] = true end
		end
	end

	local majorSegments, exitClearSegments = {}, {}
	for _, zone in cornerZones do
		for _, fraction in definition.MajorDriftFractions or {} do
			local index = fraction * #samples + 1
			if index >= zone.First and index <= zone.Last then
				for segment = zone.First, zone.Last do majorSegments[segment] = true end
				local exitFirst = math.floor(zone.First + (zone.Last - zone.First) * 0.75)
				for segment = exitFirst - 3, zone.Last + math.ceil(60 / definition.SampleSpacing) + 3 do
					exitClearSegments[segment % #samples + 1] = true
				end
			end
		end
	end

	-- Sparse, deterministic scenery gives nearby motion cues without touching
	-- the road, race triggers, barriers or kart physics.
	local speedCueObjects = 0
	local speedCueParts = 0
	local maxSpeedCueObjects = 32
	local cueStride = if isHardCircuit then 4 else math.max(7, math.ceil((#samples - 16) / maxSpeedCueObjects))
	local cueIndices = {}
	local straightCueRoles = {}
	if isHardCircuit then
		for straightIndex, straight in definition.NitroStraights or {} do
			local first = math.round(straight.StartFraction * #samples) + 1
			local last = math.round(straight.EndFraction * #samples) + 1
			for _, marker in { {first, "ENTRY"}, {first + 8, "MARKER"}, {last - 8, "MARKER"}, {last + 3, "EXIT"} } do
				table.insert(cueIndices, marker[1])
				straightCueRoles[marker[1]] = { Role = marker[2], Straight = straightIndex }
			end
		end
	end
	for index = 8, #samples - 8, cueStride do
		if not isHardCircuit or (not cornerSegments[index] and turnAt(index) < math.rad(1)) then
			if not straightCueRoles[index] and (not isHardCircuit or #cueIndices < maxSpeedCueObjects) then table.insert(cueIndices, index) end
		end
	end
	if isHardCircuit and #cueIndices > maxSpeedCueObjects then
		local distributed = {}
		for slot = 0, maxSpeedCueObjects - 1 do
			table.insert(distributed, cueIndices[1 + math.round(slot * (#cueIndices - 1) / (maxSpeedCueObjects - 1))])
		end
		cueIndices = distributed
	end
	if isHardCircuit then table.sort(cueIndices) end
	for _, index in cueIndices do
		if speedCueObjects >= maxSpeedCueObjects then break end
		local tangent = directionAt(index)
		local side = if math.floor((index - 8) / cueStride) % 2 == 0 then 1 else -1
		local normal = Vector3.new(-tangent.Z, 0, tangent.X) * side
		local offset = roadWidth * 0.5 + 24 + (index % 3) * 5
		local center = samples[index] + normal * offset
		local clearOfRoad = not isHardCircuit or (not cornerSegments[index] and turnAt(index) < math.rad(1))
		for _, roadSample in samples do
			local delta = center - roadSample
			if Vector2.new(delta.X, delta.Z).Magnitude < roadWidth * 0.5 + 12 then
				clearOfRoad = false
				break
			end
		end
		if clearOfRoad then
			speedCueObjects += 1
			local base = roadPoint(center, 0)
			local role = straightCueRoles[index]
			local kind = if role then (if role.Role == "MARKER" then 0 else 1) else speedCueObjects % 3
			local function cuePart(name: string, size: Vector3, height: number, color: Color3, material: Enum.Material?)
				createVisualPart(speedCues, string.format("Cue%02d%s", speedCueObjects, name), size,
					CFrame.new(base + Vector3.new(0, height, 0)), color, material)
				speedCueParts += 1
			end
			if isHardCircuit and kind == 1 then
				cuePart("SignPost", Vector3.new(1, 12, 1), 6, Color3.fromRGB(65, 73, 80), nil)
				local board = createVisualPart(speedCues, string.format("Cue%02dBillboard", speedCueObjects),
					Vector3.new(12, 6, 0.3), CFrame.lookAt(base + Vector3.new(0, 12, 0), base + Vector3.new(0, 12, 0) - normal),
					Color3.fromRGB(26, 40, 53), nil)
				local gui = Instance.new("SurfaceGui")
				gui.Face = Enum.NormalId.Front
				gui.CanvasSize = Vector2.new(360, 180)
				gui.Parent = board
				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.Text = if role and role.Role == "ENTRY" then "KDM / NITRO " .. (if role.Straight == 1 then "A" else "B")
					elseif role and role.Role == "EXIT" then (if role.Straight == 1 then "TURN RIGHT" else "TURN LEFT")
					elseif speedCueObjects % 2 == 0 then "BOOST" else "KDM"
				label.TextScaled = true
				label.TextColor3 = white
				label.Font = Enum.Font.GothamBold
				label.Parent = gui
				speedCueParts += 1
			elseif isHardCircuit and kind == 0 then
				cuePart("Pylon", Vector3.new(2, 13, 2), 6.5, Color3.fromRGB(179, 200, 205), nil)
			elseif kind == 1 then
				cuePart("Trunk", Vector3.new(2, 12, 2), 6, Color3.fromRGB(91, 68, 49), Enum.Material.SmoothPlastic)
				cuePart("Canopy", Vector3.new(11, 12, 11), 16, Color3.fromRGB(46, 113, 65), Enum.Material.SmoothPlastic)
			elseif kind == 2 then
				cuePart("Pole", Vector3.new(1, 18, 1), 9, Color3.fromRGB(70, 78, 83), Enum.Material.SmoothPlastic)
				cuePart("Head", Vector3.new(5, 2, 3), 18, Color3.fromRGB(255, 224, 139), Enum.Material.Neon)
			else
				cuePart("Rock", Vector3.new(7, 5, 6), 2.5, Color3.fromRGB(105, 111, 110), Enum.Material.Slate)
			end
		end
	end

	-- This plane only covers the gray physical ground; it cannot affect kart contact or road checks.
	local bounds = course.Bounds
	local grassMargin = if isHardCircuit then roadWidth * 0.5 + 200 else 180
	createVisualPart(
		environmentFolder, "Infield",
		Vector3.new(bounds.MaxX - bounds.MinX + grassMargin * 2, 0.02, bounds.MaxZ - bounds.MinZ + grassMargin * 2),
		CFrame.new((bounds.MinX + bounds.MaxX) * 0.5, groundTop + 0.02, (bounds.MinZ + bounds.MaxZ) * 0.5),
		Color3.fromRGB(84, 125, 79), Enum.Material.Grass
	)

	if isHardCircuit then
		local support = createPart(testTrack, "SafetyGround",
			Vector3.new(bounds.MaxX - bounds.MinX + grassMargin * 2, 1, bounds.MaxZ - bounds.MinZ + grassMargin * 2),
			CFrame.new((bounds.MinX + bounds.MaxX) * 0.5, groundTop - 0.5, (bounds.MinZ + bounds.MaxZ) * 0.5),
			Color3.fromRGB(84, 125, 79))
		support.Anchored = true
		support.CanCollide = true
		support.CanTouch = false
		support.CanQuery = true
		support.Material = Enum.Material.Grass
	end

	for index = 1, #samples do
		local nextIndex = index % #samples + 1
		local first = samples[index]
		local second = samples[nextIndex]
		local startBend = turnAt(index)
		local endBend = turnAt(nextIndex)
		local bend = math.max(startBend, endBend)
		local overhang = math.max(1.5, roadWidth * math.tan(bend * 0.5) + 1)
		createSegment(
			roadFolder, "Road" .. index, roadPoint(first, 0), roadPoint(second, 0),
			roadWidth, 0.05, overhang, roadColor, Enum.Material.Asphalt
		)

		local firstDirection = directionAt(index)
		local secondDirection = directionAt(nextIndex)
		local firstRight = Vector3.new(-firstDirection.Z, 0, firstDirection.X)
		local secondRight = Vector3.new(-secondDirection.Z, 0, secondDirection.X)
		local strongestTurn = if startBend >= endBend then index else nextIndex
		local innerSide = if signedTurnAt(strongestTurn) > 0 then -1 else 1
		for _, side in { -1, 1 } do
			local firstEdge = first + firstRight * (roadWidth * 0.5 * side)
			local secondEdge = second + secondRight * (roadWidth * 0.5 * side)
			createSegment(
				markingFolder, (if side < 0 then "LeftEdge" else "RightEdge") .. index,
				roadPoint(firstEdge, 0.04), roadPoint(secondEdge, 0.04),
				1, 0.035, 0.6, white, nil
			)
		end

		-- Leave the grid and finish crossing visually open. Corner strips sit beyond the road edge.
		local nearStart = index <= 3 or index >= #samples - 2
		if not isHardCircuit and not nearStart and bend >= kerbThreshold then
			local offset = roadWidth * 0.5 + 1.9
			local firstKerb = first + firstRight * (offset * innerSide)
			local secondKerb = second + secondRight * (offset * innerSide)
			createSegment(kerbFolder, "Kerb" .. index, roadPoint(firstKerb, 0.025), roadPoint(secondKerb, 0.025),
				3.5, 0.07, 0.6, if index % 2 == 0 then kerbRed else kerbWhite, nil)
			kerbCount += 1
		end

		if not nearStart and bend >= barrierThreshold and index % barrierStride == 0
			and not exitClearSegments[index] then
			local outerSide = -innerSide
			local offset = roadWidth * 0.5 + (if isHardCircuit then (if majorSegments[index] then 28 else 22) else 7)
			local firstBarrier = first + firstRight * (offset * outerSide)
			local secondBarrier = second + secondRight * (offset * outerSide)
			local barrierY = groundTop + 1.23
			local barrier = createSegment(
				barrierFolder, "Barrier" .. index,
				Vector3.new(firstBarrier.X, barrierY, firstBarrier.Z),
				Vector3.new(secondBarrier.X, barrierY, secondBarrier.Z),
				1.6, 2.4, 0.2,
				if index % (barrierStride * 2) == 0 then kerbRed else kerbWhite, nil
			)
			local roadMidpoint = (first + second) * 0.5
			local toRoad = roadMidpoint - barrier.Position
			local inwardNormal = Vector3.new(toRoad.X, 0, toRoad.Z).Unit
			local trigger = createPart(
				barrierTriggerFolder, "BarrierTrigger" .. index,
				Vector3.new(5, barrier.Size.Y, barrier.Size.Z + 2),
				barrier.CFrame + inwardNormal * 2, barrier.Color
			)
			trigger.Anchored = true
			trigger.Transparency = 1
			trigger.CanCollide = false
			trigger.CanTouch = false
			trigger.CanQuery = false
			trigger.CastShadow = false
			trigger:SetAttribute("BarrierInwardNormal", inwardNormal)
			local segmentDelta = second - first
			trigger:SetAttribute("BarrierForwardTangent", Vector3.new(segmentDelta.X, 0, segmentDelta.Z).Unit)
			trigger:SetAttribute("BarrierIndex", index)
			barrierCount += 1
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

	local singleKerbParts, doubleKerbParts, sharpGroupCount = 0, 0, 0
	local doubleSegments = {}
	if isHardCircuit then
		-- A sustained <=105-stud core enters the thick kerb band; <=140 holds it
		-- through the shoulder of the bend. Ignore isolated one/two-sample spikes.
		local sharpCore = math.atan(definition.SampleSpacing / 105)
		local sharpHold = math.atan(definition.SampleSpacing / 140)
		local index = 4
		while index <= #samples - 3 do
			if turnAt(index) >= sharpCore then
				local first = index
				while index <= #samples - 3 and turnAt(index) >= sharpCore do index += 1 end
				if index - first >= 3 then
					local last = index - 1
					while first > 4 and turnAt(first - 1) >= sharpHold do first -= 1 end
					while last < #samples - 3 and turnAt(last + 1) >= sharpHold do last += 1 end
					for segment = first - 2, last + 2 do doubleSegments[segment] = true end
				end
			else index += 1 end
		end
		for segment = 2, #samples - 1 do
			if doubleSegments[segment] and not doubleSegments[segment - 1] then sharpGroupCount += 1 end
		end
		local function edgeAt(index: number, offset: number, side: number): Vector3
			local tangent = directionAt(index)
			return samples[index] + Vector3.new(-tangent.Z, 0, tangent.X) * offset * side
		end
		local function chordError(first: number, last: number, offset: number, side: number): number
			local a, b = edgeAt(first, offset, side), edgeAt(last + 1, offset, side)
			local delta = b - a
			local error = 0
			for step = first + 1, last do
				local point = edgeAt(step, offset, side)
				local alpha = math.clamp((point - a):Dot(delta) / delta:Dot(delta), 0, 1)
				error = math.max(error, (point - a - delta * alpha).Magnitude)
			end
			return error
		end
		for row = 1, 2 do
			local offset = roadWidth * 0.5 + 2.6 + (row - 1) * 3.6
			local segment, stripe = 2, 0
			while segment <= #samples - 1 do
				if row == 2 and not doubleSegments[segment] then segment += 1; continue end
				local last = segment
				-- Merge only gentle spans within 0.25 stud of BOTH true offset edges.
				while last < math.min(segment + 3, #samples - 1)
					and (row == 1 or doubleSegments[last + 1])
					and turnAt(last + 1) < math.atan(definition.SampleSpacing / 250)
					and chordError(segment, last + 1, offset, -1) <= 0.25
					and chordError(segment, last + 1, offset, 1) <= 0.25 do last += 1 end
				stripe += 1
				for _, side in { -1, 1 } do
					local part = createSegment(kerbFolder,
						(if side < 0 then "LeftKerb" else "RightKerb") .. "Row" .. row .. "_" .. segment,
						roadPoint(edgeAt(segment, offset, side), 0.025), roadPoint(edgeAt(last + 1, offset, side), 0.025),
						3.5, 0.07, 1.6, if stripe % 2 == 0 then kerbRed else kerbWhite, nil)
					part:SetAttribute("KerbRow", row)
					part:SetAttribute("KerbSide", side)
					part:SetAttribute("FirstSegment", segment)
					part:SetAttribute("LastSegment", last)
					if row == 1 then singleKerbParts += 1 else doubleKerbParts += 1 end
					kerbCount += 1
				end
				segment = last + 1
			end
		end
	end

	local chevronParts = 0
	local chevronClusters = 0
	if isHardCircuit then
		local directions = Instance.new("Folder")
		directions.Name = "DirectionMarkers"
		directions.Parent = testTrack
		local traveled = 0
		local nextMarker = 70 -- Initial forward cue shortly after the checker/grid.
		for index = 2, #samples - 2 do
			traveled += (samples[index] - samples[index - 1]).Magnitude
			if traveled < nextMarker then continue end
			local clearOfGate = (samples[index] - course.StartPosition).Magnitude > 28
			for _, checkpoint in checkpointSamples do
				if (samples[index] - checkpoint.Position).Magnitude < 28 then clearOfGate = false end
			end
			if not clearOfGate then continue end
			local tangent = directionAt(index)
			local right = Vector3.new(-tangent.Z, 0, tangent.X)
			for _, laneSide in { -1, 1 } do
				chevronClusters += 1
				local origin = roadPoint(samples[index] + right * (roadWidth * 0.25 * laneSide), 0.12)
				local cluster = Instance.new("Folder")
				cluster.Name = "ForwardChevron" .. chevronClusters
				cluster:SetAttribute("SampleIndex", index)
				cluster:SetAttribute("LaneSide", laneSide)
				cluster.Parent = directions
				-- Same forward cue in each lane center; keep the center divider clear.
				for arrow = -1, 1 do
					for _, wing in { -1, 1 } do
						local head = origin + tangent * (arrow * 8 + 3)
						local tail = origin + tangent * (arrow * 8 - 3) + right * (wing * 3)
						createSegment(cluster, "Arrow" .. arrow .. "Wing" .. wing, tail, head, 1.1, 0.035, 0,
							Color3.fromRGB(185, 202, 204), nil)
						chevronParts += 1
					end
				end
			end

			nextMarker = traveled + (if cornerSegments[index] then 98 else 154)
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
	local startCFrame = CFrame.lookAt(roadPoint(startPoint, 0.058), roadPoint(startPoint + startDirection, 0.058))
	local checkerColumns = 10
	local checkerRows = 2
	for row = 1, checkerRows do
		for column = 1, checkerColumns do
			local offsetX = (column - 0.5 - checkerColumns * 0.5) * roadWidth / checkerColumns
			local offsetZ = (row - 0.5 - checkerRows * 0.5) * 3 / checkerRows
			createVisualPart(
				markingFolder, "StartLine" .. row .. "_" .. column,
				Vector3.new(roadWidth / checkerColumns, 0.035, 3 / checkerRows),
				startCFrame * CFrame.new(offsetX, 0, offsetZ),
				if (row + column) % 2 == 0 then Color3.fromRGB(20, 22, 24) else white, nil
			)
			checkerCount += 1
		end
	end
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
	testTrack:SetAttribute("EnvironmentPartCount", 1 + speedCueParts)
	testTrack:SetAttribute("EnvironmentCueVersion", environmentVersion)
	if isHardCircuit then
		testTrack:SetAttribute("CornerZoneCount", #cornerZones)
		testTrack:SetAttribute("SingleKerbPartCount", singleKerbParts)
		testTrack:SetAttribute("DoubleKerbPartCount", doubleKerbParts)
		testTrack:SetAttribute("SharpKerbGroupCount", sharpGroupCount)
		testTrack:SetAttribute("ChevronClusterCount", chevronClusters)
		testTrack:SetAttribute("ChevronPartCount", chevronParts)
	end
	testTrack:SetAttribute("SpeedCueObjectCount", speedCueObjects)
	testTrack:SetAttribute("SpeedCuePartCount", speedCueParts)
	testTrack:SetAttribute("KerbPartCount", kerbCount)
	testTrack:SetAttribute("BarrierPartCount", barrierCount)
	testTrack:SetAttribute("BarrierTriggerPartCount", barrierCount)
	testTrack:SetAttribute("BarrierForwardTangentVersion", 1)
	testTrack:SetAttribute("CheckerPartCount", checkerCount)
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
