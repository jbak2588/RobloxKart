-- Reverse only exact authorized P2A/P2A1 integration edits for historical freezes.
-- Exact literal matching keeps gates, ownership and unrelated source detectable.
return function(source)
	source=require("./p2b_track_capability_freeze")(source):gsub("\r\n","\n")
	local function replace(current,prior)
		local start=source:find(current,1,true)
		if start then source=source:sub(1,start-1)..prior..source:sub(start+#current) end
	end
 replace("function context:setServerControl(steering: number, throttle: number?)","function context:setServerControl(steering: number)")
 replace("if throttle == nil then throttle = 1 end\n\t\t\tif type(throttle)~=\"number\" or throttle~=throttle or math.abs(throttle)==math.huge then return false end\n\t\t\tself.control={throttle=math.clamp(throttle,0,1),steering=","self.control={throttle=1,steering=")
 replace("if context.botControl then\n\t\t\t\tlocal command = context.botControl()\n\t\t\t\tcontext:setServerControl(command.steering, command.throttle)\n\t\t\tend","if context.botControl then context:setServerControl(context.botControl().steering) end")
 replace("local look = context.chassis.CFrame.LookVector\n\t\t\tlocal forward = Vector3.new(look.X, 0, look.Z)\n\t\t\tlocal speed = if forward.Magnitude > 0.001 then context.chassis.AssemblyLinearVelocity:Dot(forward.Unit) else 0\n\t\t\tlocal command = Steering.command(record.steeringState, context.chassis.CFrame, nil, nil, speed)","local command = Steering.command(record.steeringState, context.chassis.CFrame)")
 replace('local KartConfig = require(Shared:WaitForChild("KartConfig"))\n','')
 replace('Steering.new(course, TrackGeometry.getDefinition(track.GeometryId).RoadWidth, KartConfig)','Steering.new(course, TrackGeometry.getDefinition(track.GeometryId).RoadWidth)')
	replace('\t\trecord.steeringState = Steering.new(course, TrackGeometry.getDefinition(track.GeometryId).RoadWidth)\n','')
	replace('Steering.command(record.steeringState, context.chassis.CFrame)','Steering.command(course.Samples, context.chassis.CFrame)')
	replace('\t\t\t-- PrototypeWorld polls even while staging/countdown controls are locked.\n\t\t\t-- Those poses must not seed stale pursuit before the round\'s grid teleport.\n\t\t\tif state:GetAttribute("RaceState") ~= "RACING" then Steering.reset(record.steeringState) end\n','')
	replace('\tSteering.reset(productionRecord.steeringState)\n','')
	return source
end
