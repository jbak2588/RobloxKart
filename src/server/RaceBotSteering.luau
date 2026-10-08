-- Bot pursuit owns accepted branch identity, independently of player checkpoints.
local Steering = {}
Steering.TARGET_SPEED = 70
Steering.LOOK_AHEAD = 18
Steering.GAIN = 2.0

-- Curvature uses route distance, never spatial proximity across an intersection.
Steering.CURVATURE_WINDOW = 36
Steering.UPCOMING_DISTANCE = 100
Steering.SEVERE_RADIUS = 95
Steering.FEEDFORWARD_GAIN = 0.8
Steering.FEEDFORWARD_DISTANCE = 30
Steering.SPEED_HYSTERESIS = 2

local function routePoint(samples, lengths, index, alpha, distance)
 local point = samples[index]:Lerp(samples[index % #samples + 1], alpha)
 if distance < 0 then
  for _ = 1, #samples do
   local available = lengths[index] * alpha
   if -distance <= available then return point:Lerp(samples[index], -distance / math.max(available, 0.001)) end
   distance += available; point = samples[index]; index = (index - 2) % #samples + 1; alpha = 1
  end
 else
  for _ = 1, #samples do
   local available = lengths[index] * (1 - alpha)
   local nextPoint = samples[index % #samples + 1]
   if distance <= available then return point:Lerp(nextPoint, distance / math.max(available, 0.001)) end
   distance -= available; point = nextPoint; index = index % #samples + 1; alpha = 0
  end
 end
 return point
end

function Steering.new(course, roadWidth, physics)
 assert(#course.Samples >= 2 and course.CenterlineLength > 0, "Bot course unavailable")
 local lengths, curvature = {}, {}
 for i, p in course.Samples do lengths[i] = (course.Samples[i % #course.Samples + 1] - p).Magnitude end
 for i in course.Samples do
  local half = Steering.CURVATURE_WINDOW * 0.5
  local p = routePoint(course.Samples, lengths, i, 0.5, 0)
  local before = p - routePoint(course.Samples, lengths, i, 0.5, -half)
  local after = routePoint(course.Samples, lengths, i, 0.5, half) - p
  curvature[i] = if before.Magnitude > 0.001 and after.Magnitude > 0.001
   then -math.atan2(before.Unit:Cross(after.Unit).Y, before.Unit:Dot(after.Unit)) / half else 0
 end
 return {course=course, roadWidth=roadWidth or 60, previous=nil, position=nil,
  segmentIndex=nil, alpha=nil, lengths=table.freeze(lengths), curvature=table.freeze(curvature),
  physics=physics, cornerCoastActive=false}
end

function Steering.reset(state)
 state.previous, state.position, state.segmentIndex, state.alpha = nil, nil, nil, nil
 state.cornerCoastActive = false
end

function Steering.corner(state, index, alpha, physicalSpeed)
 local localCurve = state.curvature[index]
 local radius = if math.abs(localCurve) > 1e-6 then 1 / math.abs(localCurve) else math.huge
 local upcomingRadius, upcomingDistance = radius, 0
 local distance, scan = state.lengths[index] * (1 - alpha), index % #state.lengths + 1
 for _ = 1, #state.lengths do
  if distance > Steering.UPCOMING_DISTANCE then break end
  local curve = math.abs(state.curvature[scan])
  if curve > 1e-6 and 1 / curve < upcomingRadius then upcomingRadius, upcomingDistance = 1 / curve, distance end
  distance += state.lengths[scan]; scan = scan % #state.lengths + 1
 end
 local speed = if type(physicalSpeed)=="number" and physicalSpeed==physicalSpeed and math.abs(physicalSpeed)<math.huge
  then math.max(physicalSpeed, 0) else 0
 local adaptive = state.physics ~= nil and upcomingRadius < Steering.SEVERE_RADIUS
 local desired, feedforward = Steering.TARGET_SPEED, 0
 if adaptive then
  desired = math.clamp(65 * math.sqrt(upcomingRadius / Steering.SEVERE_RADIUS), 50, 65)
  if speed > desired + Steering.SPEED_HYSTERESIS then state.cornerCoastActive = true
  elseif speed < desired - Steering.SPEED_HYSTERESIS then state.cornerCoastActive = false end
 else state.cornerCoastActive = false end
 local feedIndex, feedDistance = index, state.lengths[index] * (1 - alpha)
 for _ = 1, #state.lengths do
  if feedDistance >= Steering.FEEDFORWARD_DISTANCE then break end
  feedIndex = feedIndex % #state.lengths + 1; feedDistance += state.lengths[feedIndex]
 end
 local feedCurve = state.curvature[feedIndex]
 if state.physics and math.abs(feedCurve) > 1 / Steering.SEVERE_RADIUS then
  local config = state.physics
  local turnRadius = config.TURN_RADIUS_LOW_SPEED + (config.TURN_RADIUS_HIGH_SPEED - config.TURN_RADIUS_LOW_SPEED)
   * math.clamp(speed / config.MAX_FORWARD_SPEED, 0, 1)
  feedforward = math.clamp(turnRadius * feedCurve * Steering.FEEDFORWARD_GAIN, -1, 1)
 end
 return if state.cornerCoastActive then 0 else 1, feedforward, radius, upcomingRadius, desired, adaptive, upcomingDistance
end

function Steering.command(state, frame, lookAhead, gain, physicalSpeed)
	local samples = state.course.Samples
	local position = Vector3.new(frame.Position.X, 0, frame.Position.Z)
	local previous = state.previous
	local moved = if state.position then (position - state.position).Magnitude else 0
	local limit = math.min(80, moved * 3 + 2)
	local bestDistance, bestDelta = math.huge, math.huge
	local bestIndex, bestAlpha, fraction
	-- A rejected teleport retains BOTH accepted anchors. No global reacquisition
	-- until the lifecycle owner explicitly resets this tracker.
	if previous == nil or moved <= 60 then
		for index, point in samples do
			local edge = samples[index % #samples + 1] - point
			local squared = edge:Dot(edge)
			if squared <= 0 then continue end
			local alpha = math.clamp((position - point):Dot(edge) / squared, 0, 1)
			local candidate = ((index - 1 + alpha) / #samples) % 1
			local delta = if previous then math.abs((candidate - previous + 0.5) % 1 - 0.5) else 0
			if previous ~= nil and delta * state.course.CenterlineLength > limit then continue end
			local distance = (position - point - edge * alpha).Magnitude
			if previous ~= nil and distance > state.roadWidth * 2 then continue end
			if (previous == nil and distance < bestDistance)
				or (previous ~= nil and (distance < bestDistance - 1e-6
					or (math.abs(distance - bestDistance) <= 1e-6 and delta < bestDelta))) then
				bestDistance, bestDelta = distance, delta
				bestIndex, bestAlpha, fraction = index, alpha, candidate
			end
		end
	end
	local heldPrevious = fraction == nil
	if fraction ~= nil then
		-- At inside corners projection can remain at a segment endpoint while
		-- physical travel continues. Accumulate movement until route advance.
		if fraction ~= previous then state.previous, state.position = fraction, position end
		state.segmentIndex, state.alpha = bestIndex, bestAlpha
	else
		bestIndex, bestAlpha = state.segmentIndex, state.alpha
	end
	assert(bestIndex ~= nil, "Bot course has no usable centerline segment")
	local target = samples[bestIndex]:Lerp(samples[bestIndex % #samples + 1], bestAlpha)
	if heldPrevious then bestDistance = (position - target).Magnitude end
	-- Pursuit always starts at the accepted branch, including rejected frames.
	local remaining, index = lookAhead or Steering.LOOK_AHEAD, bestIndex
	for _ = 1, #samples do
		local nextPoint = samples[index % #samples + 1]
		local distance = (nextPoint - target).Magnitude
		if distance >= remaining then
			target = target:Lerp(nextPoint, remaining / math.max(distance, 0.001)); break
		end
		remaining -= distance; target = nextPoint; index = index % #samples + 1
	end
	local forward = Vector3.new(frame.LookVector.X, 0, frame.LookVector.Z)
	if forward.Magnitude <= 0.001 then
		forward = samples[bestIndex % #samples + 1] - samples[bestIndex]
	end
	forward = forward.Unit
	local offset = target - position
	local direction = if offset.Magnitude > 0.001 then offset.Unit else forward
	local angle = math.atan2(forward:Cross(direction).Y, forward:Dot(direction))
	local pursuit = -angle * (gain or Steering.GAIN)
	local throttle, feedforward, radius, upcoming, desired, adaptive, upcomingDistance = Steering.corner(state, bestIndex, bestAlpha, physicalSpeed)
	return {throttle=throttle, steering=math.clamp(pursuit + feedforward, -1, 1),
		rawPursuit= pursuit, feedforward=feedforward, curveRadius=radius, upcomingRadius=upcoming,
		desiredCornerSpeed=desired, adaptiveCorner=adaptive, upcomingDistance=upcomingDistance, effectiveLookAhead=lookAhead or Steering.LOOK_AHEAD,
		driftRequested=false, targetSpeed=Steering.TARGET_SPEED, distance=bestDistance, target=target,
		routeFraction=state.previous, segmentIndex=bestIndex, heldPrevious=heldPrevious}
end
return Steering
