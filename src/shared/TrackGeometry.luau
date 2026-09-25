local TrackGeometry = {}

TrackGeometry.Definitions = {
	-- Exact straight/arc path from 88de2b3:src/server/PrototypeWorld.luau.
	-- Sample zero is ten studs into the old Main road, at the finish line.
	PracticeCircuitV1 = {
		Segments = {
			{ "Straight", -350, 440, -350, -300 },
			{ "Arc", -170, -300, 180, math.pi, math.pi },
			{ "Straight", 10, -300, 10, 200 },
			{ "Arc", 110, 200, 100, math.pi, -math.pi },
			{ "Straight", 210, 200, 210, -260 },
			{ "Straight", 210, -260, 210, -560 },
			{ "Arc", 70, -560, 140, 0, -math.pi / 2 },
			{ "Straight", 70, -700, -550, -700 },
			{ "Arc", -550, -560, 140, -math.pi / 2, -math.pi / 2 },
			{ "Straight", -690, -560, -690, 450 },
			{ "Arc", -550, 450, 140, math.pi, -math.pi / 2 },
			{ "Straight", -550, 590, -490, 590 },
			{ "Arc", -490, 450, 140, math.pi / 2, -math.pi / 2 },
			{ "Straight", -350, 450, -350, 440 },
		},
		RoadWidth = 60,
		SampleSpacing = 14,
		CheckpointPositions = {
			Vector3.new(-350, 0, 100), Vector3.new(10, 0, 0),
			Vector3.new(210, 0, 0), Vector3.new(-250, 0, -700),
			Vector3.new(-690, 0, 0), Vector3.new(-520, 0, 590),
		},
		CheckpointDirections = {
			Vector3.new(0, 0, -1), Vector3.new(0, 0, 1),
			Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0),
			Vector3.new(0, 0, 1), Vector3.new(1, 0, 0),
		},
	},
	PrototypeCircuitV2 = {
		ControlPoints = {
			Vector3.new(-360, 0, 430),
			Vector3.new(-360, 0, 180),
			Vector3.new(-300, 0, 70),
			Vector3.new(-120, 0, 30),
			Vector3.new(60, 0, 80),
			Vector3.new(180, 0, -20),
			Vector3.new(190, 0, -180),
			Vector3.new(80, 0, -330),
			Vector3.new(-140, 0, -330),
			Vector3.new(-360, 0, -330),
			Vector3.new(-500, 0, -400),
			Vector3.new(-620, 0, -380),
			Vector3.new(-620, 0, -40),
			Vector3.new(-560, 0, 80),
			Vector3.new(-430, 0, 160),
			Vector3.new(-520, 0, 280),
			Vector3.new(-630, 0, 370),
			Vector3.new(-600, 0, 500),
			Vector3.new(-470, 0, 600),
			Vector3.new(-360, 0, 640),
		},
		RoadWidth = 48,
		SampleSpacing = 14,
		CheckpointFractions = { 0.14, 0.29, 0.43, 0.58, 0.77, 0.87 },
	},
}

function TrackGeometry.getDefinition(id: string)
	return TrackGeometry.Definitions[id]
end

local function catmullRom(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: number): Vector3
	local t2 = t * t
	local t3 = t2 * t
	return (
		b * 2 + (c - a) * t + (a * 2 - b * 5 + c * 4 - d) * t2
			+ (b * 3 - a - c * 3 + d) * t3
	) * 0.5
end

local function denseLegacyPath(segments): { Vector3 }
	local dense: { Vector3 } = {}
	for _, segment in segments do
		local kind = segment[1]
		local distance = if kind == "Straight"
			then (Vector2.new(segment[4], segment[5]) - Vector2.new(segment[2], segment[3])).Magnitude
			else segment[4] * math.abs(segment[6])
		local subdivisions = math.max(2, math.ceil(distance / 4))
		for step = 0, subdivisions - 1 do
			local alpha = step / subdivisions
			local x: number
			local z: number
			if kind == "Straight" then
				x = segment[2] + (segment[4] - segment[2]) * alpha
				z = segment[3] + (segment[5] - segment[3]) * alpha
			else
				local angle = segment[5] + segment[6] * alpha
				x = segment[2] + math.cos(angle) * segment[4]
				z = segment[3] + math.sin(angle) * segment[4]
			end
			table.insert(dense, Vector3.new(x, 0, z))
		end
	end
	return dense
end

function TrackGeometry.sampleClosedCenterline(definition)
	local dense: { Vector3 }
	if definition.Segments then
		dense = denseLegacyPath(definition.Segments)
	else
		local controlPoints = definition.ControlPoints
		local count = #controlPoints
		assert(count >= 4, "Track geometry needs at least four control points")
		dense = {}
		for index = 1, count do
			local a = controlPoints[(index - 2) % count + 1]
			local b = controlPoints[index]
			local c = controlPoints[index % count + 1]
			local d = controlPoints[(index + 1) % count + 1]
			local subdivisions = math.max(12, math.ceil((c - b).Magnitude / 5))
			for step = 0, subdivisions - 1 do
				table.insert(dense, catmullRom(a, b, c, d, step / subdivisions))
			end
		end
	end

	local cumulative = { 0 }
	for index = 1, #dense do
		local nextPoint = dense[index % #dense + 1]
		table.insert(cumulative, cumulative[index] + (nextPoint - dense[index]).Magnitude)
	end
	local denseLength = cumulative[#cumulative]
	local sampleCount = math.max(3, math.round(denseLength / definition.SampleSpacing))
	local samples: { Vector3 } = {}
	local denseIndex = 1
	for index = 0, sampleCount - 1 do
		local distance = denseLength * index / sampleCount
		while denseIndex < #dense and cumulative[denseIndex + 1] < distance do
			denseIndex += 1
		end
		local segmentLength = cumulative[denseIndex + 1] - cumulative[denseIndex]
		local alpha = if segmentLength > 0 then (distance - cumulative[denseIndex]) / segmentLength else 0
		table.insert(samples, dense[denseIndex]:Lerp(dense[denseIndex % #dense + 1], alpha))
	end
	local length = 0
	for index = 1, #samples do
		length += (samples[index % #samples + 1] - samples[index]).Magnitude
	end
	return samples, length
end

function TrackGeometry.getBounds(samples: { Vector3 })
	local bounds = { MinX = math.huge, MaxX = -math.huge, MinZ = math.huge, MaxZ = -math.huge }
	for _, point in samples do
		bounds.MinX = math.min(bounds.MinX, point.X)
		bounds.MaxX = math.max(bounds.MaxX, point.X)
		bounds.MinZ = math.min(bounds.MinZ, point.Z)
		bounds.MaxZ = math.max(bounds.MaxZ, point.Z)
	end
	return bounds
end

function TrackGeometry.getSampleAtFraction(samples: { Vector3 }, fraction: number): Vector3
	local position = (fraction % 1) * #samples
	local index = math.floor(position) + 1
	return samples[index]:Lerp(samples[index % #samples + 1], position % 1)
end

function TrackGeometry.getTangentAtFraction(samples: { Vector3 }, fraction: number): Vector3
	local halfStep = 0.5 / #samples
	local tangent = TrackGeometry.getSampleAtFraction(samples, fraction + halfStep)
		- TrackGeometry.getSampleAtFraction(samples, fraction - halfStep)
	return tangent.Unit
end

function TrackGeometry.getCheckpointSamples(definition, samples: { Vector3 })
	local checkpoints = {}
	if definition.CheckpointPositions then
		for index, position in definition.CheckpointPositions do
			local nearestIndex = 1
			local nearestDistance = math.huge
			for sampleIndex, sample in samples do
				local distance = (sample - position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestIndex = sampleIndex
				end
			end
			table.insert(checkpoints, {
				Position = position,
				Tangent = definition.CheckpointDirections[index],
				Fraction = (nearestIndex - 1) / #samples,
			})
		end
	else
		for _, fraction in definition.CheckpointFractions do
			table.insert(checkpoints, {
				Position = TrackGeometry.getSampleAtFraction(samples, fraction),
				Tangent = TrackGeometry.getTangentAtFraction(samples, fraction),
				Fraction = fraction,
			})
		end
	end
	return checkpoints
end

function TrackGeometry.getCourse(definition)
	local samples, length = TrackGeometry.sampleClosedCenterline(definition)
	return {
		Samples = samples,
		Bounds = TrackGeometry.getBounds(samples),
		CenterlineLength = length,
		StartPosition = TrackGeometry.getSampleAtFraction(samples, 0),
		StartTangent = TrackGeometry.getTangentAtFraction(samples, 0),
		CheckpointSamples = TrackGeometry.getCheckpointSamples(definition, samples),
	}
end

return table.freeze(TrackGeometry)
