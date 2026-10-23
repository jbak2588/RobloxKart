-- Camera-only horizontal composition. The kart's world position and velocity
-- remain untouched. Translation carries most of the shift; yaw stays modest.
local Composition = {}
local WORLD_UP = Vector3.yAxis

function Composition.offset(
	position: Vector3,
	baseTarget: Vector3,
	subject: Vector3,
	viewport: Vector2,
	verticalFovDegrees: number,
	targetScreenX: number
): (Vector3, Vector3)
	if viewport.X <= 0 or viewport.Y <= 0 or targetScreenX == 0.5 then
		return position, baseTarget
	end
	local forward = baseTarget - position
	local planar = Vector3.new(forward.X, 0, forward.Z)
	if planar.Magnitude < 0.001 then return position, baseTarget end
	local direction = planar.Unit
	local right = direction:Cross(WORLD_UP).Unit
	local depth = (subject - position):Dot(direction)
	if depth <= 0.001 then return position, baseTarget end
	local aspect = viewport.X / viewport.Y
	local horizontalTangent = math.tan(math.rad(verticalFovDegrees) * 0.5) * aspect
	local angle = math.atan((targetScreenX * 2 - 1) * horizontalTangent)
	local translation = depth * math.tan(angle * 0.6)
	local yaw = angle * 0.4
	local shiftedPosition = position - right * translation
	local aimedForward = direction * math.cos(yaw) - right * math.sin(yaw)
	local shiftedTarget = shiftedPosition + aimedForward * planar.Magnitude
		+ WORLD_UP * (baseTarget.Y - position.Y)
	return shiftedPosition, shiftedTarget
end

-- Shared by official RACE and Rookie Park; same front distance and subject height.
function Composition.front(position,forward,viewport,fov,side,height,screenX)
 local right=forward:Cross(WORLD_UP).Unit
 local target=position+WORLD_UP*2.25
 local front=position+forward*11+right*side+WORLD_UP*height
 if screenX~=.5 then front,target=Composition.offset(front,target,target,viewport,fov,screenX)end
 return front,target
end

return Composition
