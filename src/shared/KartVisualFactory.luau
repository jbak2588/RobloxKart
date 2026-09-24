local KartVisualFactory = {}

local TRIM = Color3.fromRGB(32, 37, 45)
local METAL = Color3.fromRGB(145, 153, 160)
-- The 1-stud Chassis rests on the collidable ground. The non-colliding road
-- has its top 0.065 studs above that ground, so leave a small visual gap.
local CHASSIS_REST_CENTER_HEIGHT = 0.5
local ROAD_TOP_HEIGHT = 0.04 + 0.05 / 2
local TIRE_GROUND_GAP = 0.025

local function wheelCenterHeight(diameter: number): number
	return diameter / 2 + ROAD_TOP_HEIGHT + TIRE_GROUND_GAP - CHASSIS_REST_CENTER_HEIGHT
end

local function addPart(model: Model, name: string, size: Vector3, offset: CFrame, role: string, shape: Enum.PartType?)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = offset
	part.Shape = shape or Enum.PartType.Block
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part:SetAttribute("ColorRole", role)
	part.Parent = model
	return part
end

local function addWheel(visual: Model, name: string, size: Vector3, center: Vector3, front: boolean, side: string)
	local wheel = addPart(visual, name, size, CFrame.new(center), "Tire", Enum.PartType.Cylinder)
	wheel:SetAttribute("VisualMotionRole", if front then "FrontWheel" else "RearWheel")
	wheel:SetAttribute("WheelSide", side)

	-- A small accent marker makes rotation of the otherwise uniform tire readable.
	local outer = if side == "Left" then -1 else 1
	local mark = addPart(
		visual,
		name .. "Mark",
		Vector3.new(0.08, 0.42, 0.18),
		CFrame.new(center + Vector3.new(outer * (size.X / 2 + 0.05), size.Y * 0.28, 0)),
		"Accent"
	)
	mark:SetAttribute("VisualParentWheel", name)
end

function KartVisualFactory.applyColors(visual: Model, definition: { [string]: any })
	for _, child in visual:GetChildren() do
		if child:IsA("BasePart") then
			local role = child:GetAttribute("ColorRole")
			if role == "Body" then
				child.Color = definition.BodyColor
			elseif role == "Accent" then
				child.Color = definition.AccentColor
			elseif role == "Tire" then
				child.Color = definition.WheelColor or Color3.fromRGB(23, 24, 27)
			elseif role == "Metal" then
				child.Color = METAL
			else
				child.Color = TRIM
			end
		end
	end
end

function KartVisualFactory.createVisual(definition: { [string]: any }): Model
	local visual = Instance.new("Model")
	visual.Name = "Visual"
	visual:SetAttribute("VisualModelName", definition.VisualModelName)

	-- The origin is the invisible physics Chassis center; the kart faces local -Z.
	addPart(visual, "BodyMain", Vector3.new(4.25, 0.55, 4.6), CFrame.new(0, 0.05, 0.15), "Body")
	addPart(visual, "Nose", Vector3.new(2.05, 0.46, 2.55), CFrame.new(0, -0.05, -2.5), "Body")
	addPart(visual, "NoseStripe", Vector3.new(0.5, 0.06, 2.2), CFrame.new(0, 0.21, -2.55), "Accent")
	addPart(visual, "SidePodL", Vector3.new(1.1, 0.73, 2.9), CFrame.new(-2.35, -0.08, -0.35), "Body")
	addPart(visual, "SidePodR", Vector3.new(1.1, 0.73, 2.9), CFrame.new(2.35, -0.08, -0.35), "Body")
	addPart(visual, "RearBody", Vector3.new(4.5, 1.05, 1.6), CFrame.new(0, 0.45, 2.65), "Body")
	addPart(visual, "RearStripe", Vector3.new(4.1, 0.07, 0.42), CFrame.new(0, 1.01, 2.65), "Accent")
	addPart(visual, "FrontBumper", Vector3.new(5.5, 0.33, 0.42), CFrame.new(0, -0.2, -3.9), "Trim")
	addPart(visual, "RearBumper", Vector3.new(6.0, 0.35, 0.45), CFrame.new(0, -0.16, 3.78), "Trim")
	addPart(visual, "SteeringColumn", Vector3.new(0.2, 1.25, 0.2), CFrame.new(0, 1.05, -1.05), "Metal")
	addPart(visual, "SteeringWheel", Vector3.new(1.45, 0.2, 0.24), CFrame.new(0, 1.65, -1.05), "Trim")
	addWheel(visual, "WheelFL", Vector3.new(0.9, 1.85, 1.85), Vector3.new(-3.25, wheelCenterHeight(1.85), -2.55), true, "Left")
	addWheel(visual, "WheelFR", Vector3.new(0.9, 1.85, 1.85), Vector3.new(3.25, wheelCenterHeight(1.85), -2.55), true, "Right")
	addWheel(visual, "WheelRL", Vector3.new(1.05, 2.05, 2.05), Vector3.new(-3.3, wheelCenterHeight(2.05), 2.65), false, "Left")
	addWheel(visual, "WheelRR", Vector3.new(1.05, 2.05, 2.05), Vector3.new(3.3, wheelCenterHeight(2.05), 2.65), false, "Right")
	addPart(visual, "ExhaustL", Vector3.new(0.35, 0.35, 0.8), CFrame.new(-1.45, 0.18, 3.75), "Metal", Enum.PartType.Cylinder)
	addPart(visual, "ExhaustR", Vector3.new(0.35, 0.35, 0.8), CFrame.new(1.45, 0.18, 3.75), "Metal", Enum.PartType.Cylinder)

	KartVisualFactory.applyColors(visual, definition)
	return visual
end

return KartVisualFactory
