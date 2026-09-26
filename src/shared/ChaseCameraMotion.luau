-- Carry target translation immediately; smooth only the relative chase framing.
-- Smoothing world-space translation makes frame/network cadence look like surging.
local Motion = {}
function Motion.step(previousCamera, previousTarget, target, desired, response, dt)
	if not previousTarget or (target - previousTarget).Magnitude > 100 then return desired end
	local carried = previousCamera + (target - previousTarget)
	return carried:Lerp(desired, 1 - math.exp(-response * math.max(dt, 0)))
end
return Motion
