local KartVisualFactory = {}

local TRIM = Color3.fromRGB(32, 37, 45)
local METAL = Color3.fromRGB(145, 153, 160)
-- The 1-stud Chassis rests on the collidable ground. The non-colliding road
-- has its top 0.065 studs above that ground, so leave a small visual gap.
local CHASSIS_REST_CENTER_HEIGHT = 0.5
local ROAD_TOP_HEIGHT = 0.04 + 0.05 / 2
local TIRE_GROUND_GAP = 0.025

local ROOT_CONTRACT = {
	StaticRoot = {},
	WheelFLPivot = { Role = "FrontWheel", Side = "Left" },
	WheelFRPivot = { Role = "FrontWheel", Side = "Right" },
	WheelRLPivot = { Role = "RearWheel", Side = "Left" },
	WheelRRPivot = { Role = "RearWheel", Side = "Right" },
	SteeringPivot = { Role = "SteeringWheel" },
}

-- Checks the visual asset before chassis binding or Garage anchoring. No
-- mutation: callers can also inspect an already anchored Garage preview.
function KartVisualFactory.validateVisual(visual: Instance): (boolean, { string })
	local diagnostics: { string } = {}
	if not visual:IsA("Model") then
		return false, { "Visual must be a Model" }
	end
	local roots: { [Instance]: boolean } = {}
	local function fail(instance: Instance, message: string)
		table.insert(diagnostics, instance:GetFullName() .. ": " .. message)
	end
	for name, expected in ROOT_CONTRACT do
		local matches = {}
		for _, child in visual:GetChildren() do
			if child.Name == name then
				table.insert(matches, child)
			end
		end
		if #matches ~= 1 then
			fail(visual, string.format("expected exactly one direct %s; found %d", name, #matches))
		end
		local pivot = matches[1]
		if pivot then
			if not pivot:IsA("BasePart") then
				fail(pivot, "must be a BasePart")
			else
				roots[pivot] = true
				if pivot.Transparency ~= 1 then
					fail(pivot, "structural root/pivot must be invisible (Transparency = 1)")
				end
				if pivot:GetAttribute("VisualMotionRole") ~= expected.Role then
					fail(pivot, "VisualMotionRole must be " .. tostring(expected.Role))
				end
				if expected.Side then
					if pivot:GetAttribute("WheelSide") ~= expected.Side then
						fail(pivot, "WheelSide must be " .. expected.Side)
					end
					for _, attribute in { "WheelRadius", "WheelWidth" } do
						local value = pivot:GetAttribute(attribute)
						if type(value) ~= "number" or not (value > 0 and value < math.huge) then
							fail(pivot, attribute .. " must be a finite number > 0")
						end
					end
				end
			end
		end
	end
	if visual.PrimaryPart ~= visual:FindFirstChild("StaticRoot") or not visual.PrimaryPart then
		fail(visual, "PrimaryPart must be StaticRoot (chassis-local origin)")
	end
	local exhaustCounts = { ExhaustLeft = 0, ExhaustRight = 0 }
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			for property, expected in { CanCollide = false, CanTouch = false, CanQuery = false, Massless = true } do
				if (descendant :: any)[property] ~= expected then
					fail(descendant, property .. " must be " .. tostring(expected))
				end
			end
			if descendant:IsA("Seat") or descendant:IsA("VehicleSeat") then
				fail(descendant, "physics seats must not be part of the Visual asset")
			end
			if not roots[descendant] then
				local ancestor = descendant.Parent
				while ancestor and ancestor ~= visual and not roots[ancestor] do
					ancestor = ancestor.Parent
				end
				if not ancestor or not roots[ancestor] then
					fail(descendant, "visual geometry must be nested under a contracted root/pivot")
				end
				if descendant:GetAttribute("VisualMotionRole") ~= nil then
					fail(descendant, "VisualMotionRole belongs only on contracted pivots")
				end
			end
		end
		local effectRole = descendant:GetAttribute("EffectRole")
		if effectRole == "ExhaustLeft" or effectRole == "ExhaustRight" then
			if not descendant:IsA("Attachment") then
				fail(descendant, effectRole .. " must be an Attachment")
			else
				exhaustCounts[effectRole] += 1
				if not descendant.Parent or not descendant.Parent:IsA("BasePart") then
					fail(descendant, "exhaust anchor must be parented to a BasePart")
				end
			end
		end
	end
	for role, count in exhaustCounts do
		if count ~= 1 then
			fail(visual, string.format("expected exactly one %s Attachment; found %d", role, count))
		end
	end
	table.sort(diagnostics)
	return #diagnostics == 0, diagnostics
end

local function wheelCenterHeight(diameter: number): number
	return diameter / 2 + ROAD_TOP_HEIGHT + TIRE_GROUND_GAP - CHASSIS_REST_CENTER_HEIGHT
end

-- Factory CFrames are all in chassis-local space, including nested children.
local function addPart(parent: Instance, name: string, size: Vector3, offset: CFrame, role: string, shape: Enum.PartType?)
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
	part.Parent = parent
	if parent:IsA("BasePart") then
		local weld = Instance.new("WeldConstraint")
		weld.Name = "VisualWeld"
		weld.Part0 = parent
		weld.Part1 = part
		weld.Parent = part
	end
	return part
end

local function addPivot(visual: Model, name: string, offset: CFrame): Part
	local pivot = addPart(visual, name, Vector3.new(0.2, 0.2, 0.2), offset, "Trim")
	pivot.Transparency = 1
	pivot:SetAttribute("ColorRole", nil)
	return pivot
end

local function addWheel(visual: Model, name: string, radius: number, width: number, center: Vector3, front: boolean, side: string)
	local pivot = addPivot(visual, name .. "Pivot", CFrame.new(center))
	pivot:SetAttribute("VisualMotionRole", if front then "FrontWheel" else "RearWheel")
	pivot:SetAttribute("WheelSide", side)
	pivot:SetAttribute("WheelRadius", radius)
	pivot:SetAttribute("WheelWidth", width)
	local size = Vector3.new(width, radius * 2, radius * 2)
	addPart(pivot, name, size, CFrame.new(center), "Tire", Enum.PartType.Cylinder)

	-- A small accent marker makes rotation of the otherwise uniform tire readable.
	local outer = if side == "Left" then -1 else 1
	addPart(
		pivot,
		name .. "Mark",
		Vector3.new(0.08, 0.42, 0.18),
		CFrame.new(center + Vector3.new(outer * (size.X / 2 + 0.05), size.Y * 0.28, 0)),
		"Accent"
	)
end

local function addExhaustAnchor(root: BasePart, role: string, position: Vector3)
	local point = Instance.new("Attachment")
	point.Name = role
	point:SetAttribute("EffectRole", role)
	point.Position = position
	point.Parent = root
end

function KartVisualFactory.applyColors(visual: Model, definition: { [string]: any })
	for _, child in visual:GetDescendants() do
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

	local staticRoot = addPivot(visual, "StaticRoot", CFrame.identity)
	visual.PrimaryPart = staticRoot

	-- The origin is the invisible physics Chassis center; the kart faces local -Z.
	addPart(staticRoot, "BodyMain", Vector3.new(4.25, 0.55, 4.6), CFrame.new(0, 0.05, 0.15), "Body")
	addPart(staticRoot, "Nose", Vector3.new(2.05, 0.46, 2.55), CFrame.new(0, -0.05, -2.5), "Body")
	addPart(staticRoot, "NoseStripe", Vector3.new(0.5, 0.06, 2.2), CFrame.new(0, 0.21, -2.55), "Accent")
	addPart(staticRoot, "SidePodL", Vector3.new(1.1, 0.73, 2.9), CFrame.new(-2.35, -0.08, -0.35), "Body")
	addPart(staticRoot, "SidePodR", Vector3.new(1.1, 0.73, 2.9), CFrame.new(2.35, -0.08, -0.35), "Body")
	addPart(staticRoot, "RearBody", Vector3.new(4.5, 1.05, 1.6), CFrame.new(0, 0.45, 2.65), "Body")
	addPart(staticRoot, "RearStripe", Vector3.new(4.1, 0.07, 0.42), CFrame.new(0, 1.01, 2.65), "Accent")
	addPart(staticRoot, "FrontBumper", Vector3.new(5.5, 0.33, 0.42), CFrame.new(0, -0.2, -3.9), "Trim")
	addPart(staticRoot, "RearBumper", Vector3.new(6.0, 0.35, 0.45), CFrame.new(0, -0.16, 3.78), "Trim")
	addPart(staticRoot, "SteeringColumn", Vector3.new(0.2, 1.25, 0.2), CFrame.new(0, 1.05, -1.05), "Metal")
	local steeringCenter = Vector3.new(0, 1.65, -1.05)
	local steeringPivot = addPivot(visual, "SteeringPivot", CFrame.new(steeringCenter))
	steeringPivot:SetAttribute("VisualMotionRole", "SteeringWheel")
	addPart(steeringPivot, "SteeringWheel", Vector3.new(0.3, 0.3, 0.18), CFrame.new(steeringCenter), "Metal")
	for index = 1, 10 do
		local angle = (index - 1) * 2 * math.pi / 10
		addPart(
			steeringPivot,
			"SteeringRim" .. index,
			Vector3.new(0.47, 0.13, 0.14),
			CFrame.new(steeringCenter + Vector3.new(math.cos(angle) * 0.68, math.sin(angle) * 0.68, 0))
				* CFrame.Angles(0, 0, angle + math.pi / 2),
			"Trim"
		)
	end
	for index, angle in { 0, math.pi, -math.pi / 2 } do
		addPart(
			steeringPivot,
			"SteeringSpoke" .. index,
			Vector3.new(0.58, 0.09, 0.1),
			CFrame.new(steeringCenter + Vector3.new(math.cos(angle) * 0.33, math.sin(angle) * 0.33, 0))
				* CFrame.Angles(0, 0, angle),
			"Metal"
		)
	end
	addWheel(visual, "WheelFL", 0.925, 0.9, Vector3.new(-3.25, wheelCenterHeight(1.85), -2.55), true, "Left")
	addWheel(visual, "WheelFR", 0.925, 0.9, Vector3.new(3.25, wheelCenterHeight(1.85), -2.55), true, "Right")
	addWheel(visual, "WheelRL", 1.025, 1.05, Vector3.new(-3.3, wheelCenterHeight(2.05), 2.65), false, "Left")
	addWheel(visual, "WheelRR", 1.025, 1.05, Vector3.new(3.3, wheelCenterHeight(2.05), 2.65), false, "Right")
	addPart(staticRoot, "ExhaustL", Vector3.new(0.35, 0.35, 0.8), CFrame.new(-1.45, 0.18, 3.75), "Metal", Enum.PartType.Cylinder)
	addPart(staticRoot, "ExhaustR", Vector3.new(0.35, 0.35, 0.8), CFrame.new(1.45, 0.18, 3.75), "Metal", Enum.PartType.Cylinder)

	-- Preserve the old exhaust tips (+0.4 local Z) independently of mesh bounds.
	addExhaustAnchor(staticRoot, "ExhaustLeft", Vector3.new(-1.45, 0.18, 4.15))
	addExhaustAnchor(staticRoot, "ExhaustRight", Vector3.new(1.45, 0.18, 4.15))

	KartVisualFactory.applyColors(visual, definition)
	local valid, diagnostics = KartVisualFactory.validateVisual(visual)
	if not valid then
		visual:Destroy()
		error("[KartVisualFactory] Invalid visual " .. tostring(definition.VisualModelName)
			.. "\n" .. table.concat(diagnostics, "\n"))
	end
	return visual
end

return KartVisualFactory
