-- Camera framing only. Never writes kart pose, velocity or replicated state.
local Heading = {}
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function angle(a, b)
	return math.atan2(a:Cross(b).Y, math.clamp(a:Dot(b), -1, 1))
end
function Heading.clear(state)
	state.offset = 0
	state.velocityDirection = nil
	state.pathTurnRate = 0
end
function Heading.step(state, body, velocity, dt, active, safe, config)
	local forward = flat(body)
	if forward.Magnitude < 0.001 then Heading.clear(state); return body end
	forward = forward.Unit
	if not safe or dt <= 0 or dt > config.MaxStep then
		Heading.clear(state)
		return forward
	end
	local planar = flat(velocity)
	local target = 0
	if active and planar.Magnitude >= config.MinSpeed and planar:Dot(forward) > config.MinForwardSpeed then
		local direction = planar.Unit
		local slip = angle(forward, direction)
		local abrupt = state.velocityDirection ~= nil
			and math.abs(angle(state.velocityDirection, direction)) > math.rad(config.MaxVelocityChangeDegrees)
		if math.abs(slip) <= math.rad(config.MaxSlipDegrees) and not abrupt then
			local turn = if state.velocityDirection then angle(state.velocityDirection, direction) / dt else 0
			state.pathTurnRate = (state.pathTurnRate or 0) + (turn - (state.pathTurnRate or 0))
				* (1 - math.exp(-config.PathTurnResponse * dt))
			local lead = math.clamp(state.pathTurnRate * config.PathLeadSeconds,
				-math.rad(config.MaxPathLeadDegrees), math.rad(config.MaxPathLeadDegrees))
			local weight = math.clamp((planar.Magnitude - config.MinSpeed) / (config.FullSpeed - config.MinSpeed), 0, 1)
			-- Bounded path anticipation offsets the preserved ChaseMotion rotation lag.
			target = (slip + lead) * weight
		else
			state.pathTurnRate = 0
		end
		state.velocityDirection = direction
	else
		state.velocityDirection = nil
		state.pathTurnRate = 0
	end
	local current = state.offset or 0
	local response = if active then config.EntryResponse else config.ExitResponse
	local change = (target - current) * (1 - math.exp(-response * dt))
	local bound = math.rad(config.MaxRotationDegreesPerSecond) * dt
	state.offset = current + math.clamp(change, -bound, bound)
	return CFrame.fromAxisAngle(Vector3.yAxis, state.offset):VectorToWorldSpace(forward)
end
return table.freeze(Heading)
