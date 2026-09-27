-- Supplements physical gates with ordered progress along the rendered centerline.
-- Off-road crossings are provisional until the kart returns to the road.
local RaceRouteProgress = {}

function RaceRouteProgress.new(course, roadWidth: number)
	return { course = course, roadWidth = roadWidth, previous = nil, position = nil, pending = 1 }
end

local function project(samples, position: Vector3)
	local bestDistance, fraction = math.huge, 0
	for index, point in samples do
		local edge = samples[index % #samples + 1] - point
		local offset = position - point
		local alpha = math.clamp(offset:Dot(edge) / edge:Dot(edge), 0, 1)
		local distance = (offset - edge * alpha).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			fraction = (index - 1 + alpha) / #samples
		end
	end
	return fraction % 1, bestDistance
end

function RaceRouteProgress.step(state, worldPosition: Vector3, nextCheckpoint: number, onRoad: boolean): number
	local position = Vector3.new(worldPosition.X, 0, worldPosition.Z)
	local fraction, distance = project(state.course.Samples, position)
	local previous = state.previous
	local previousPosition = state.position
	state.previous = fraction
	state.position = position
	state.pending = math.max(state.pending, nextCheckpoint)
	if previous and previousPosition then
		local advance = (fraction - previous + 0.5) % 1 - 0.5
		local moved = (position - previousPosition).Magnitude
		-- Reject teleports and projection jumps onto a different leg of the course.
		if moved <= 60 and advance > 0
			and advance * state.course.CenterlineLength <= math.min(80, moved * 3 + 2)
			and distance <= state.roadWidth * 2 then
			local checkpoint = state.course.CheckpointSamples[state.pending]
			while checkpoint do
				local toCheckpoint = (checkpoint.Fraction - previous) % 1
				if toCheckpoint > advance then break end
				state.pending += 1
				checkpoint = state.course.CheckpointSamples[state.pending]
			end
		end
	end
	return if onRoad then state.pending else nextCheckpoint
end

return RaceRouteProgress
