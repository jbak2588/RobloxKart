-- A per-kart fail-safe that removes abnormal roll/pitch without granting speed.
local KartUprightRecovery = {}

function KartUprightRecovery.advance(upDot: number, elapsed: number, deltaTime: number, config)
	if upDot >= config.KART_UPRIGHT_MIN_DOT then return 0, false end
	local nextElapsed = elapsed + deltaTime
	local delay = if upDot <= 0 then config.KART_INVERTED_RECOVERY_DELAY
		else config.KART_UPRIGHT_RECOVERY_DELAY
	return nextElapsed, nextElapsed >= delay
end

function KartUprightRecovery.flatHeading(cframe: CFrame, fallback: Vector3): Vector3
	local look = cframe.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.001 then return flat.Unit end
	local safeFallback = Vector3.new(fallback.X, 0, fallback.Z)
	return if safeFallback.Magnitude > 0.001 then safeFallback.Unit else Vector3.new(0, 0, -1)
end

function KartUprightRecovery.apply(kart: Model, chassis: BasePart, fallback: Vector3): Vector3
	local heading = KartUprightRecovery.flatHeading(chassis.CFrame, fallback)
	local velocity = chassis.AssemblyLinearVelocity
	local angular = chassis.AssemblyAngularVelocity
	kart:PivotTo(CFrame.lookAt(chassis.Position, chassis.Position + heading, Vector3.yAxis))
	chassis.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	chassis.AssemblyAngularVelocity = Vector3.new(0, angular.Y, 0)
	return heading
end

return KartUprightRecovery
