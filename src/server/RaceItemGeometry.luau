-- Server placement and swept contact math; no client position/hit reports.
local Geometry = {}
local eliphantRoad
local superZRoad

function Geometry.roadAt(prototype, position)
	local track = prototype:FindFirstChild("TestTrack")
	local road = track and track:FindFirstChild("Road")
	if not road then return nil end
	local nearest, distance = nil, math.huge
	for _, part in road:GetChildren() do
		if part:IsA("BasePart") then
			local p = part.CFrame:PointToObjectSpace(position)
			local dx = math.max(0, math.abs(p.X) - part.Size.X * 0.5)
			local dz = math.max(0, math.abs(p.Z) - part.Size.Z * 0.5)
			local d = dx * dx + dz * dz
			if d < distance then nearest, distance = part, d end
		end
	end
	if not nearest then return nil end
	return nearest, math.sqrt(distance)
end

function Geometry.roadFrameAt(prototype, position, maxGap, keepLane)
	local track = prototype:FindFirstChild("TestTrack")
	local geometryId = track and track.GetAttribute and track:GetAttribute("GeometryId")
	local roadPolicy
	if geometryId == "EliphantNoseR2" then
		eliphantRoad = eliphantRoad or require(script.Parent:WaitForChild("EliphantTrackBuilder"))
		roadPolicy = eliphantRoad
	elseif geometryId == "SuperZV1" then
		if not superZRoad then
			local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
			superZRoad = require(shared:WaitForChild("SuperZRoadPolicy"))
		end
		roadPolicy = superZRoad
	end
	if roadPolicy then
		if maxGap and not roadPolicy.contains(position, maxGap) then return nil end
		local top = track:GetAttribute("GroundTop") + roadPolicy.AsphaltTopOffset
		if keepLane then return CFrame.new(position.X, top + 0.08, position.Z) end
		local center, direction = roadPolicy.centerlineAt(position)
		local location = Vector3.new(center.X, top + 0.08, center.Z)
		return CFrame.fromMatrix(location, direction:Cross(Vector3.yAxis), Vector3.yAxis, -direction)
	end
	local road, gap = Geometry.roadAt(prototype, position)
	if not road or (maxGap and gap > maxGap) then return nil end
	if keepLane then return CFrame.new(position.X, road.Position.Y + road.Size.Y * 0.5 + 0.08, position.Z) end
	local localPoint = road.CFrame:PointToObjectSpace(position)
	-- Road X is lateral width; preserve longitudinal Z and the segment's rotation.
	return road.CFrame * CFrame.new(0, road.Size.Y * 0.5 + 0.08, localPoint.Z)
end

local function dropPoint(chassis, distance)
	local look = chassis.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.001 then return nil end
	local forward = flat.Unit
	return chassis.Position - forward * distance, forward
end

function Geometry.dropFrame(prototype, chassis, distance)
	local position, forward = dropPoint(chassis, distance)
	if not position then return nil end
	local road = Geometry.roadFrameAt(prototype, position, 0.5, true)
	if not road then return nil end
	local right = forward:Cross(Vector3.yAxis)
	return CFrame.fromMatrix(road.Position, right, Vector3.yAxis, -forward)
end

-- Smoke screens span the road, while Slick keeps dropFrame's exact owner lane.
function Geometry.smokeDropFrame(prototype, chassis, distance)
	local position = dropPoint(chassis, distance)
	if not position then return nil end
	return Geometry.roadFrameAt(prototype, position, 0.5)
end

function Geometry.crosses(frame, size, fromPosition, chassis)
	local first = frame:PointToObjectSpace(fromPosition)
	local last = frame:PointToObjectSpace(chassis.Position)
	-- Project the chassis footprint into the hazard axes (Minkowski expansion).
	local relative = frame:ToObjectSpace(chassis.CFrame)
	local r, u, l = relative.RightVector, relative.UpVector, relative.LookVector
	local c = chassis.Size * 0.5
	local expansion = Vector3.new(
		math.abs(r.X)*c.X + math.abs(u.X)*c.Y + math.abs(l.X)*c.Z,
		math.abs(r.Y)*c.X + math.abs(u.Y)*c.Y + math.abs(l.Y)*c.Z,
		math.abs(r.Z)*c.X + math.abs(u.Z)*c.Y + math.abs(l.Z)*c.Z)
	local half = size * 0.5 + expansion
	local enter, leave = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		local origin, delta, limit = first[axis], last[axis]-first[axis], half[axis]
		if math.abs(delta) < 0.0001 then
			if math.abs(origin) > limit then return false end
		else
			local a, b = (-limit-origin)/delta, (limit-origin)/delta
			enter, leave = math.max(enter, math.min(a,b)), math.min(leave, math.max(a,b))
			if enter > leave then return false end
		end
	end
	return true
end

return Geometry
