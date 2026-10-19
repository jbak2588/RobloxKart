-- Supplements physical gates with ordered progress along the rendered centerline.
-- Off-road crossings are provisional until the kart returns to the road.
local RaceRouteProgress = {}

function RaceRouteProgress.new(course, roadWidth: number)
	return { course = course, roadWidth = roadWidth, previous = nil, position = nil, pending = 1 }
end

local function project(samples, position: Vector3, previous, length, limit, corridor)
	local bestDistance, fraction, bestDelta, bestIndex = math.huge, nil, math.huge, math.huge
	local count=#samples
	local radius=if previous then math.ceil(limit*count/length)+2 else count
	local bounded=previous~=nil and radius*2+1<count
	local first,last=if bounded then -radius else 0,if bounded then radius else count-1
	local center=if bounded then math.floor(previous*count) else 0
	for offset=first,last do
		local index=(center+offset)%count+1
		local point=samples[index]
		local edge = samples[index % #samples + 1] - point
		local edgeLengthSquared = edge:Dot(edge)
		if edgeLengthSquared > 0 then
			local offset = position - point
			local alpha = math.clamp(offset:Dot(edge) / edgeLengthSquared, 0, 1)
			local candidate = ((index - 1 + alpha) / #samples) % 1
			local delta = if previous then math.abs((candidate - previous + 0.5) % 1 - 0.5) else 0
			-- Filter BOTH forward and reverse motion before nearest-distance selection.
			if previous == nil or delta * length <= limit then
				local distance = (offset - edge * alpha).Magnitude
				if (previous == nil or distance <= corridor)
					and (distance < bestDistance or (distance == bestDistance and (delta < bestDelta or (delta == bestDelta and index < bestIndex)))) then
					bestDistance, fraction, bestDelta, bestIndex = distance, candidate, delta, index
				end
			end
		end
	end
	return fraction
end

function RaceRouteProgress.step(state, worldPosition: Vector3, nextCheckpoint: number, onRoad: boolean): number
	local position = Vector3.new(worldPosition.X, 0, worldPosition.Z)
	local previous = state.previous
	local previousPosition = state.position
	state.pending = math.max(state.pending, nextCheckpoint)
	-- previous AND position are last ACCEPTED route/world samples. Rejected hitches,
	-- teleports and distant excursions retain both anchors until a compatible return
	-- or RaceController's existing clearGateState() creates fresh route state.
	local moved = if previousPosition then (position - previousPosition).Magnitude else 0
	if previous ~= nil and moved > 60 then return nextCheckpoint end
	local fraction = project(state.course.Samples, position, previous,
		state.course.CenterlineLength, math.min(80, moved * 3 + 2), state.roadWidth * 2)
	if fraction == nil then return nextCheckpoint end
	-- A segment-end projection can stay fixed while the chassis rounds an inside
	-- corner. Keep its movement anchor until route position changes, so legitimate
	-- travel accumulates instead of repeatedly losing the ability to leave that end.
	if fraction ~= previous then state.previous, state.position = fraction, position end
	if previous and previousPosition then
		local advance = (fraction - previous + 0.5) % 1 - 0.5
		-- Route position may move backward; only forward motion recovers checkpoints.
		if advance > 0 then
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
