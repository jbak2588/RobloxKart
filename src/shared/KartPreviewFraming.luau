-- Event-driven Garage camera fit. All visible oriented-part corners participate;
-- invisible pivots and attachments cannot distort the framing.
local KartPreviewFraming = {}

function KartPreviewFraming.fit(visual: Model, aspect: number, fieldOfView: number): CFrame?
	if aspect <= 0 then return nil end
	local points = {}
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, part in visual:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local point = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
						table.insert(points, point)
						low = low:Min(point)
						high = high:Max(point)
					end
				end
			end
		end
	end
	if #points == 0 then return nil end
	local center = (low + high) * 0.5
	local direction = Vector3.new(-1, 0.25, -1).Unit
	local right = Vector3.yAxis:Cross(direction).Unit
	local up = direction:Cross(right)
	local orientation = CFrame.fromMatrix(center, right, up, direction)
	local projectedLow = Vector3.new(math.huge, math.huge, math.huge)
	local projectedHigh = -projectedLow
	for _, point in points do
		local p = orientation:PointToObjectSpace(point)
		projectedLow = projectedLow:Min(p)
		projectedHigh = projectedHigh:Max(p)
	end
	local midpoint = (projectedLow + projectedHigh) * 0.5
	center += right * midpoint.X + up * midpoint.Y
	orientation = CFrame.fromMatrix(center, right, up, direction)
	local tangent = math.tan(math.rad(fieldOfView) * 0.5)
	local distance = 0.1
	for _, point in points do
		local p = orientation:PointToObjectSpace(point)
		-- Aim at 65% width; height safety takes priority on wide/short panels.
		distance = math.max(distance, p.Z + math.abs(p.X) / (tangent * aspect * 0.65),
			p.Z + math.abs(p.Y) / (tangent * 0.88), p.Z + 0.1)
	end
	return CFrame.fromMatrix(center + direction * distance, right, up, direction)
end

return KartPreviewFraming
