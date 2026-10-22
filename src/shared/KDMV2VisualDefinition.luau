-- One serialized, sanitized R2E geometry template shared by both liveries.
-- MeshPart.MeshId is read-only at runtime; cloning this source asset avoids
-- asset-loading APIs and any dependency on the Studio audit workspace.
local KDMV2VisualDefinition = {}

-- Seated driver sinks deep into the bucket (-0.79 Y) rather than floating above the rim.
-- SteeringPivot is lowered by 0.65 studs and brought 0.25 studs back to match the seated posture.
KDMV2VisualDefinition.DriverSeatLocalCFrame = CFrame.new(0, -0.79, 0.5)

function KDMV2VisualDefinition.createVisual(): Model
	local template = assert(script.Parent:FindFirstChild("KDMV2Geometry"), "Missing KDM V2 source geometry")
	local visual = template:Clone()
	visual.Name = "Visual"
	visual.PrimaryPart = visual.StaticRoot

	local offset = CFrame.new(0, -0.65, 0.25)

	local steeringPivot = visual:FindFirstChild("SteeringPivot")
	if steeringPivot and steeringPivot:IsA("BasePart") then
		for _, child in steeringPivot:GetDescendants() do
			if child:IsA("BasePart") then
				child.CFrame = child.CFrame * offset
			end
		end
		steeringPivot.CFrame = steeringPivot.CFrame * offset
	end

	local visualSeat = visual.StaticRoot:FindFirstChild("VisualSeat")
	if visualSeat and visualSeat:IsA("BasePart") then
		visualSeat.CFrame = visualSeat.CFrame * offset
	end

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
