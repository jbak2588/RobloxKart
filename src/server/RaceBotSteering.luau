-- Input-only centerline pursuit. No movement, braking or competitor-dependent speed.
local Steering = {}
Steering.TARGET_SPEED = 70
Steering.LOOK_AHEAD = 18
Steering.GAIN = 2.0
function Steering.command(samples, frame, lookAhead, gain)
	local position = Vector3.new(frame.Position.X,0,frame.Position.Z)
	local bestDistance, bestIndex, bestAlpha = math.huge,1,0
	for index,point in samples do
		local edge=samples[index % #samples+1]-point
		local alpha=if edge:Dot(edge)>0 then math.clamp((position-point):Dot(edge)/edge:Dot(edge),0,1) else 0
		local distance=(position-point-edge*alpha).Magnitude
		if distance<bestDistance then bestDistance,bestIndex,bestAlpha=distance,index,alpha end
	end
	local target=samples[bestIndex]:Lerp(samples[bestIndex % #samples+1],bestAlpha)
	local remaining=lookAhead or Steering.LOOK_AHEAD
	local index=bestIndex
	for _=1,#samples do
		local nextPoint=samples[index % #samples+1]
		local distance=(nextPoint-target).Magnitude
		if distance>=remaining then target=target:Lerp(nextPoint,remaining/math.max(distance,.001)); break end
		remaining-=distance;target=nextPoint;index=index % #samples+1
	end
	local forward=Vector3.new(frame.LookVector.X,0,frame.LookVector.Z).Unit
	local offset=target-position
	local direction=if offset.Magnitude>.001 then offset.Unit else forward
	local angle=math.atan2(forward:Cross(direction).Y,forward:Dot(direction))
	-- Production positive steering turns right (negative world yaw).
	return {throttle=1,steering=math.clamp(-angle*(gain or Steering.GAIN),-1,1),driftRequested=false,
		targetSpeed=Steering.TARGET_SPEED,distance=bestDistance,target=target}
end
return Steering
