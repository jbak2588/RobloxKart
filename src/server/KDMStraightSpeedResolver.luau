-- Server-only, immutable course analysis. No Instances, remotes or motion writes.
local Resolver = {}
local CELL_SIZE = 128
local cache = {}

local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function key(x, z) return x .. ":" .. z end

function Resolver.precompute(samples, config, roadWidth)
	local n = #samples
	local lengths, tangents, turns, metrics, cells = {}, {}, {}, {}, {}
	for i = 1, n do
		local delta = flat(samples[i % n + 1] - samples[i])
		lengths[i] = delta.Magnitude
		assert(lengths[i] > 0, "Degenerate centerline segment")
		tangents[i] = delta.Unit
	end
	for i = 1, n do
		turns[i] = math.deg(math.acos(math.clamp(tangents[(i - 2) % n + 1]:Dot(tangents[i]), -1, 1)))
	end
	for i = 1, n do
		-- Include the start vertex and whole intersecting horizon segments: conservative
		-- at sample boundaries, including lap wrap and equal-ended S bends.
		local distance, turn, j = 0, turns[i], i
		for _ = 1, n do
			distance += lengths[j]
			j = j % n + 1
			turn += turns[j]
			if distance >= config.STRAIGHT_LOOK_AHEAD then break end
		end
		metrics[i] = turn
		local a, b = samples[i], samples[i % n + 1]
		local padding = roadWidth * 0.5
		for x = math.floor((math.min(a.X,b.X)-padding)/CELL_SIZE), math.floor((math.max(a.X,b.X)+padding)/CELL_SIZE) do
			for z = math.floor((math.min(a.Z,b.Z)-padding)/CELL_SIZE), math.floor((math.max(a.Z,b.Z)+padding)/CELL_SIZE) do
				local k = key(x,z)
				cells[k] = cells[k] or {}
				table.insert(cells[k],i)
			end
		end
	end
	return { samples=samples, lengths=lengths, turns=turns, metrics=metrics, cells=cells, config=config, roadWidth=roadWidth }
end

function Resolver.get(geometryId, geometry, config)
	if not geometryId then return nil end
	if not cache[geometryId] then
		local definition = geometry.getDefinition(geometryId)
		if not definition then return nil end
		cache[geometryId] = Resolver.precompute(geometry.getCourse(definition).Samples, config, definition.RoadWidth)
	end
	return cache[geometryId]
end

function Resolver.evaluate(course, position, active)
	local p = flat(position)
	local candidates = course.cells[key(math.floor(p.X/CELL_SIZE),math.floor(p.Z/CELL_SIZE))] or {}
	local nearest, distance = nil, math.huge
	for _, i in candidates do
		local a = flat(course.samples[i])
		local d = flat(course.samples[i % #course.samples + 1]) - a
		local alpha = math.clamp((p-a):Dot(d)/d:Dot(d),0,1)
		local separation = (p-a-d*alpha).Magnitude
		if separation < distance then nearest, distance = i, separation end
	end
	local turn = if nearest then course.metrics[nearest] else math.huge
	local threshold = if active then course.config.STRAIGHT_EXIT_MAX_TURN else course.config.STRAIGHT_ENTER_MAX_TURN
	return distance <= course.roadWidth * 0.5 and turn <= threshold, nearest, turn, distance, #candidates
end

function Resolver.update(state, course, position, now, allowed)
	if not allowed or not course then
		state.straightEligible, state.straightExitActive, state.straightLastEvaluation = false, false, nil
		return
	end
	if state.straightLastEvaluation and now-state.straightLastEvaluation < course.config.STRAIGHT_EVALUATION_INTERVAL then return end
	local previous = state.straightEligible == true
	local eligible, index, turn, distance = Resolver.evaluate(course,position,previous)
	state.straightEligible, state.straightNearestSample = eligible, index
	state.straightTurnDegrees, state.straightDistance = turn, distance
	state.straightLastEvaluation = now
	if previous and not eligible then state.straightExitActive = true end
	if eligible then state.straightExitActive = false end
end

return table.freeze(Resolver)
