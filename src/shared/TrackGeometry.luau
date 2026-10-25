local TrackGeometry = {}

TrackGeometry.Definitions = {
	-- Dedicated planar drift practice: tangent circular corners, unequal loops,
	-- unchanged drift radii, longer exits and a 190-stud standing-start approach.
	PracticeFigure8V1 = {
		Segments = {
			{ "Straight", -119.959242415067, 140.697810235772, -230.591866666511, 295.166002515392 },
			{ "Arc", -133.033008335511, 365.039238887392, 120.000000000000, -2.520066029000, -2.192322951000 },
			{ "Straight", -133.033008335511, 485.039238887392, 162.226651990511, 485.039238887392 },
			{ "Arc", 162.226651990511, 380.039238887392, 105.000000000000, 1.570796327000, -2.192322951000 },
			{ "Straight", 247.590653030511, 318.900157061392, -125.006068178000, -201.329227267000 },
			{ "Arc", -64.031781721000, -245.000000000000, 75.000000000000, 2.520066029000, 2.192322951000 },
			{ "Straight", -64.031781721000, -320.000000000000, 44.569352617000, -320.000000000000 },
			{ "Arc", 44.569352617000, -235.000000000000, 85.000000000000, -1.570796327000, 2.192322951000 },
			{ "Straight", 113.673543935000, -185.506457570000, -119.959242415067, 140.697810235772 },
		},
		RoadWidth = 60,
		SampleSpacing = 10,
		CheckpointFractions = { 0.127914464202, 0.318134532852, 0.461116957585, 0.615042495526, 0.754450233071, 0.912660768901 },
		Crossover = {
			Position = Vector3.new(0, 0, -26.792452830),
			VisualHalfLength = 110, KerbClearRadius = 52,
			BranchTangents = { Vector3.new(-0.582276969769, 0, -0.812990486092), Vector3.new(-0.582276969769, 0, 0.812990486092) },
		},
		DriftZones = {
			{ Name = "A EASY LOWER ENTRY", Radius = 120, StartFraction = 0.076642536737, EndFraction = 0.182763710866, HeadingDegrees = -125.610852421966 },
			{ Name = "B LOWER LOOP EXIT", Radius = 105, StartFraction = 0.301866075978, EndFraction = 0.394722103340, HeadingDegrees = -125.610852421966 },
			{ Name = "C TIGHT UPPER ENTRY", Radius = 75, StartFraction = 0.652844498025, EndFraction = 0.719170231856, HeadingDegrees = 125.610852421966 },
			{ Name = "D UPPER LOOP EXIT", Radius = 85, StartFraction = 0.762977949914, EndFraction = 0.838147114922, HeadingDegrees = 125.610852421966 },
		},
	},
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
		CheckpointFractions = { 0.14, 0.38, 0.43, 0.58, 0.77, 0.87 },
	},
	HardCircuitV1 = {
		ControlPoints = {
			Vector3.new(-360.000000, 0, 430.000000),
			Vector3.new(-360.000000, 0, 316.553183),
			Vector3.new(-360.108712, 0, 202.537444),
			Vector3.new(-359.232307, 0, 90.733691),
			Vector3.new(-354.820983, 0, -14.245498),
			Vector3.new(-342.095467, 0, -102.222457),
			Vector3.new(-302.986008, 0, -161.596027),
			Vector3.new(-252.229927, 0, -182.957362),
			Vector3.new(-196.367448, 0, -165.491345),
			Vector3.new(-164.243028, 0, -114.378041),
			Vector3.new(-161.903553, 0, -32.926903),
			Vector3.new(-177.514671, 0, 29.912276),
			Vector3.new(-189.570311, 0, 118.689039),
			Vector3.new(-161.428920, 0, 179.329763),
			Vector3.new(-110.846899, 0, 204.294328),
			Vector3.new(-58.477205, 0, 192.217082),
			Vector3.new(-22.776558, 0, 147.881267),
			Vector3.new(-18.275759, 0, 80.243247),
			Vector3.new(-35.571127, 0, -20.443455),
			Vector3.new(-31.444263, 0, -98.309679),
			Vector3.new(3.364486, 0, -142.622822),
			Vector3.new(53.836424, 0, -154.934458),
			Vector3.new(107.036394, 0, -133.075250),
			Vector3.new(167.480046, 0, -81.700770),
			Vector3.new(220.258522, 0, -75.977963),
			Vector3.new(262.830101, 0, -107.078913),
			Vector3.new(289.356311, 0, -178.109281),
			Vector3.new(326.214220, 0, -239.183873),
			Vector3.new(389.997249, 0, -273.022627),
			Vector3.new(468.247409, 0, -281.420311),
			Vector3.new(554.037899, 0, -258.886556),
			Vector3.new(611.749779, 0, -223.319713),
			Vector3.new(632.921610, 0, -166.735656),
			Vector3.new(614.577510, 0, -114.699715),
			Vector3.new(561.618461, 0, -76.889398),
			Vector3.new(504.681295, 0, -36.396842),
			Vector3.new(469.425529, 0, 23.381679),
			Vector3.new(455.431175, 0, 124.005328),
			Vector3.new(420.832521, 0, 189.603984),
			Vector3.new(358.835124, 0, 224.359980),
			Vector3.new(297.882060, 0, 219.175051),
			Vector3.new(241.186889, 0, 178.779628),
			Vector3.new(185.300753, 0, 138.007442),
			Vector3.new(131.105948, 0, 133.352534),
			Vector3.new(84.101371, 0, 164.677351),
			Vector3.new(61.873672, 0, 230.628482),
			Vector3.new(81.548103, 0, 320.387094),
			Vector3.new(112.312072, 0, 387.364617),
			Vector3.new(161.881103, 0, 415.179865),
			Vector3.new(218.927196, 0, 405.573215),
			Vector3.new(282.427314, 0, 360.023340),
			Vector3.new(352.533764, 0, 334.540589),
			Vector3.new(433.759422, 0, 338.471120),
			Vector3.new(509.094285, 0, 367.790282),
			Vector3.new(587.276658, 0, 402.839897),
			Vector3.new(641.593418, 0, 451.635438),
			Vector3.new(670.963391, 0, 530.802714),
			Vector3.new(655.034906, 0, 594.928716),
			Vector3.new(605.661806, 0, 637.661982),
			Vector3.new(544.789307, 0, 645.757123),
			Vector3.new(462.141957, 0, 628.819815),
			Vector3.new(386.773540, 0, 623.230621),
			Vector3.new(311.405123, 0, 617.641428),
			Vector3.new(236.036705, 0, 612.052235),
			Vector3.new(160.668288, 0, 606.463042),
			Vector3.new(85.299871, 0, 600.873848),
			Vector3.new(9.931454, 0, 595.284655),
			Vector3.new(-66.255610, 0, 592.215551),
			Vector3.new(-113.191545, 0, 612.467157),
			Vector3.new(-139.724141, 0, 660.487785),
			Vector3.new(-149.627047, 0, 763.023261),
			Vector3.new(-156.092535, 0, 859.228078),
			Vector3.new(-180.347680, 0, 929.990145),
			Vector3.new(-233.094589, 0, 969.362672),
			Vector3.new(-285.730435, 0, 970.595335),
			Vector3.new(-331.421236, 0, 937.682147),
			Vector3.new(-353.267343, 0, 881.104429),
			Vector3.new(-360.815177, 0, 778.915115),
			Vector3.new(-359.298064, 0, 657.690734),
			Vector3.new(-360.000000, 0, 543.446139),
		},
		RoadWidth = 48,
		SampleSpacing = 14,
		CheckpointFractions = { 0.153, 0.318, 0.417, 0.600, 0.775, 0.948 },
		MajorDriftFractions = { 0.473, 0.190, 0.683 },
		NitroStraights = {
			{ StartFraction = 2 / 429, EndFraction = 30 / 429 },
			{ StartFraction = 317 / 429, EndFraction = 345 / 429 },
		},
	},
}

-- Local B-only candidate; Legacy definitions remain byte-identical.
TrackGeometry.Definitions.PrototypeCircuitV2B = (function()
-- KDM R7-N3 candidate B: Track02 prototype only. Not an approved/played production track.
-- Add as TrackGeometry.Definitions.PrototypeCircuitV2B after careful review; do NOT replace legacy.
-- 24 signed Catmull-Rom control points; original P1-P16 unchanged.
local definition = {
    ControlPoints = {
        Vector3.new(-360.000, 0, 430.000), -- P1
        Vector3.new(-360.000, 0, 180.000), -- P2
        Vector3.new(-300.000, 0, 70.000), -- P3
        Vector3.new(-120.000, 0, 30.000), -- P4
        Vector3.new(60.000, 0, 80.000), -- P5
        Vector3.new(180.000, 0, -20.000), -- P6
        Vector3.new(190.000, 0, -180.000), -- P7
        Vector3.new(80.000, 0, -330.000), -- P8
        Vector3.new(-140.000, 0, -330.000), -- P9
        Vector3.new(-360.000, 0, -330.000), -- P10
        Vector3.new(-500.000, 0, -400.000), -- P11
        Vector3.new(-620.000, 0, -380.000), -- P12
        Vector3.new(-620.000, 0, -40.000), -- P13
        Vector3.new(-560.000, 0, 80.000), -- P14
        Vector3.new(-430.000, 0, 160.000), -- P15
        Vector3.new(-520.000, 0, 280.000), -- P16
        Vector3.new(-680.000, 0, 365.000), -- P17
        Vector3.new(-740.000, 0, 560.000), -- P18
        Vector3.new(-700.000, 0, 745.000), -- P19
        Vector3.new(-581.791, 0, 866.756), -- P20
        Vector3.new(-452.744, 0, 895.306), -- P21
        Vector3.new(-328.511, 0, 822.636), -- P22
        Vector3.new(-305.730, 0, 705.840), -- P23
        Vector3.new(-360.000, 0, 540.450), -- P24
    },
    RoadWidth = 48,
    SampleSpacing = 14,
    -- Fractions are new route-station proposals; retain exactly six ordered checkpoints.
    CheckpointFractions = { 0.118282592, 0.321054611, 0.363298781, 0.490031293, 0.650784732, 0.737278028 },
    -- Candidate focus for exit-clearance study; calibrate using actual Builder corner zones.
    MajorDriftFractions = { 0.710, 0.835 },
}
return definition

end)()

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

-- Park-style road grid, left/right then the next row, measured back from GO.
function TrackGeometry.getStartGridFrames(course)
	local frames = {}
	local samples = course.Samples
	for row = 0, 3 do
		local remaining = 30 + row * 30
		local point, tangent = course.StartPosition, course.StartTangent
		for index = #samples, 1, -1 do
			local behind, ahead = samples[index], samples[index % #samples + 1]
			local length = (ahead - behind).Magnitude
			if length > 0 and remaining <= length then
				point = ahead:Lerp(behind, remaining / length)
				tangent = (ahead - behind).Unit
				break
			end
			remaining -= length
		end
		local frame = CFrame.lookAt(point, point + tangent)
		for _, side in {-1, 1} do table.insert(frames, frame * CFrame.new(side * 14, 0, 0)) end
	end
	return frames
end

return table.freeze(TrackGeometry)
