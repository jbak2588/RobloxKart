-- One serialized, sanitized R2E geometry template shared by both liveries.
-- MeshPart.MeshId is read-only at runtime; cloning this source asset avoids
-- asset-loading APIs and any dependency on the Studio audit workspace.
local KDMV2VisualDefinition = {}

-- Original DriveSeat is (0, 1.5, .5) in the sanitized source frame.
-- The approved bucket is 1.440000057 studs below that source bucket:
-- source bucket Y=2.455938339, approved bucket Y=1.015938282.
-- Carry the original Seat-to-bucket relationship into the approved geometry.
-- This is a live Seat contract, not the old Garage render-proxy offset.
KDMV2VisualDefinition.DriverSeatLocalCFrame = CFrame.new(0, 0.06000018119812012, 0.5)

function KDMV2VisualDefinition.createVisual(): Model
	local template = assert(script.Parent:FindFirstChild("KDMV2Geometry"), "Missing KDM V2 source geometry")
	local visual = template:Clone()
	visual.Name = "Visual"
	visual.PrimaryPart = visual.StaticRoot
	for _, part in visual:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			if part.Parent:IsA("BasePart") then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "VisualWeld"
				weld.Part0 = part.Parent
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	return visual
end

return table.freeze(KDMV2VisualDefinition)
