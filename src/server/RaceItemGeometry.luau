-- Server placement and swept contact math; no client position/hit reports.
local Geometry = {}

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

function Geometry.dropFrame(prototype, chassis, distance)
	local look = chassis.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.001 then return nil end
	local forward = flat.Unit
	local position = chassis.Position - forward * distance
	local road, gap = Geometry.roadAt(prototype, position)
	if not road or gap > 0.5 then return nil end
	position = Vector3.new(position.X, road.Position.Y + road.Size.Y * 0.5 + 0.08, position.Z)
	local right = forward:Cross(Vector3.yAxis)
	return CFrame.fromMatrix(position, right, Vector3.yAxis, -forward)
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
