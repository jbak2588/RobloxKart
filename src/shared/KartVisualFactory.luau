local KartVisualFactory = {}

-- Darker aluminum base leaves room for bright metallic highlights.
local ALUMINUM_COLOR = Color3.fromRGB(148, 156, 164)
local ALUMINUM_REFLECTANCE = 0.18
local function applyAluminum(part)
	part.Material = Enum.Material.Metal
	part.Color = ALUMINUM_COLOR
	part.Reflectance = ALUMINUM_REFLECTANCE
end

function KartVisualFactory.getDriverSeatLocalCFrame(definition): CFrame
	if definition.VisualModelName == "SprintV1" then
		return CFrame.new(0, 1.5, 0.5)
	elseif definition.VisualModelName == "KDMV2" then
		return require(script.Parent.KDMV2VisualDefinition).DriverSeatLocalCFrame
	end
	error("Unknown driver-seat visual model: " .. tostring(definition.VisualModelName))
end

local TRIM = Color3.fromRGB(32, 37, 45)
local METAL = Color3.fromRGB(145, 153, 160)
-- Color identity and surface finish are independent; geometry only tags roles.
local SPRINT_MATERIALS = {
	BodyPrimary = Enum.Material.SmoothPlastic,
	BodySecondary = Enum.Material.SmoothPlastic,
	Accent = Enum.Material.SmoothPlastic,
	Trim = Enum.Material.SmoothPlastic,
	Tire = Enum.Material.Rubber,
	Rim = Enum.Material.Metal,
	Metal = Enum.Material.Metal,
	Seat = Enum.Material.SmoothPlastic,
}
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
local function addPart(parent: Instance, name: string, size: Vector3, offset: CFrame, role: string, shape: Enum.PartType?, wedge: boolean?)
	local part = if wedge then Instance.new("WedgePart") else Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = offset
	if part:IsA("Part") then
		part.Shape = shape or Enum.PartType.Block
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part:SetAttribute("ColorRole", role)
	part:SetAttribute("MaterialRole", role)
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
	pivot:SetAttribute("MaterialRole", nil)
	return pivot :: Part
end

local function addWheel(visual: Model, name: string, radius: number, width: number, center: Vector3, front: boolean, side: string)
	local pivot = addPivot(visual, name .. "Pivot", CFrame.new(center))
	pivot:SetAttribute("VisualMotionRole", if front then "FrontWheel" else "RearWheel")
	pivot:SetAttribute("WheelSide", side)
	pivot:SetAttribute("WheelRadius", radius)
	pivot:SetAttribute("WheelWidth", width)
	local size = Vector3.new(width, radius * 2, radius * 2)
	addPart(pivot, name, size, CFrame.new(center), "Tire", Enum.PartType.Cylinder)

	-- A recessed disc and contrasting elongated hub make spin readable without
	-- adding individual bolts or a separate marker mesh.
	local outer = if side == "Left" then -1 else 1
	addPart(pivot, name .. "Rim", Vector3.new(0.12, radius * 1.22, radius * 1.22),
		CFrame.new(center + Vector3.new(outer * (width / 2 + 0.015), 0, 0)), "Rim", Enum.PartType.Cylinder)
	addPart(pivot, name .. "Hub", Vector3.new(0.14, radius * 0.76, 0.19),
		CFrame.new(center + Vector3.new(outer * (width / 2 + 0.075), 0, 0)), "Metal")
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
			if role == "Body" or role == "BodyPrimary" then
				child.Color = definition.BodyPrimaryColor or definition.BodyColor
			elseif role == "BodySecondary" then
				child.Color = definition.BodySecondaryColor or definition.BodyColor:Lerp(TRIM, 0.5)
			elseif role == "Accent" then
				child.Color = definition.AccentColor
			elseif role == "Tire" then
				child.Color = definition.WheelColor or Color3.fromRGB(23, 24, 27)
			elseif role == "Rim" then
				child.Color = definition.RimColor or Color3.fromRGB(80, 91, 105)
			elseif role == "Metal" then
				child.Color = METAL
			elseif role == "Seat" then
				child.Color = Color3.fromRGB(26, 29, 35)
			else
				child.Color = TRIM
			end
		end
	end
end

function KartVisualFactory.applyMaterials(visual: Model)
	visual:SetAttribute("MaterialProfile", "SprintV1")
	for _, part in visual:GetDescendants() do
		if part:IsA("BasePart") then
			local role = part:GetAttribute("MaterialRole")
			if role then
				local material = SPRINT_MATERIALS[role]
				assert(material, "Unknown MaterialRole on " .. part:GetFullName() .. ": " .. tostring(role))
				part.Material = material
				part.Reflectance = 0
			end
		end
	end
end

function KartVisualFactory.applyAppearance(visual: Model, definition: { [string]: any })
	if definition.VisualModelName == "KDMV2" then
		assert(visual:GetAttribute("VisualModelName") == "KDMV2", "V2 appearance requires V2 geometry")
		local body = visual.StaticRoot.CurvedBody
		body.TextureID = definition.BodyTextureId
		body.Material = definition.BodyMaterial
		body.Color = Color3.new(1, 1, 1)
		body.Reflectance = 0
		-- Source Engine includes the exposed engine/exhaust and right-seat intake.
		-- VisualSeat also contains the fuel tank: never tint that combined mesh.
		local black = definition.MechanicalPalette == "Black"
		local engine = visual.StaticRoot.Engine
		engine.Material = Enum.Material.Metal
		if definition.EnginePalette == "Black" then
			engine.Color = Color3.fromRGB(18, 20, 24)
			engine.Reflectance = 0.06
		else
			engine.Color = Color3.fromRGB(255, 200, 0)
			engine.Reflectance = 0
		end
		local frame = visual.StaticRoot.Frame
		frame.Material = Enum.Material.Metal
		if black then
			frame.Color = Color3.fromRGB(18, 20, 24)
			frame.Reflectance = 0
		else
			applyAluminum(frame)
		end
		local link = visual.StaticRoot.Link
		link.Material = Enum.Material.Metal
		if black then
			link.Color = Color3.fromRGB(18, 20, 24)
			link.Reflectance = 0
		else
			applyAluminum(link)
		end
		applyAluminum(visual.StaticRoot.Routers)
		for _, name in { "WheelFLPivot", "WheelFRPivot", "WheelRLPivot", "WheelRRPivot" } do
			applyAluminum(visual[name].AluminumHubCover)
		end
		visual:SetAttribute("VisualVariant", definition.VisualVariant)
	else
		KartVisualFactory.applyColors(visual, definition)
	end
end

function KartVisualFactory.createVisual(definition: { [string]: any },wingEquipped: boolean?): Model
	if definition.VisualModelName == "KDMV2" then
		local visual = require(script.Parent.KDMV2VisualDefinition).createVisual()
		KartVisualFactory.applyAppearance(visual, definition)
		require(script.Parent.KDMV2WingDefinition).attach(visual,definition,wingEquipped==true)
		local valid, errors = KartVisualFactory.validateVisual(visual)
		assert(valid, table.concat(errors, "; "))
		return visual
	end
	assert(definition.VisualModelName == "SprintV1", "Unknown kart visual model")
	local visual = Instance.new("Model")
	visual.Name = "Visual"
	visual:SetAttribute("VisualModelName", definition.VisualModelName)

	local staticRoot = addPivot(visual, "StaticRoot", CFrame.identity)
	visual.PrimaryPart = staticRoot

	-- Sprint V1: 19 static + 12 wheel + 9 steering visible parts = 40.
	-- Origin/forward (-Z), wheel anchors and the Physics Seat are PV1-A locked.
	addPart(staticRoot, "FloorPan", Vector3.new(3.9, 0.22, 5.35), CFrame.new(0, -0.18, 0), "BodySecondary")
	for _, side in { -1, 1 } do
		addPart(staticRoot, "FrameRail" .. side, Vector3.new(5.75, 0.18, 0.18),
			CFrame.new(side * 1.87, -0.02, 0.12) * CFrame.Angles(0, math.pi / 2, 0), "Trim", Enum.PartType.Cylinder)
	end
	addPart(staticRoot, "FrontBumper", Vector3.new(3.65, 0.4, 0.52), CFrame.new(0, -0.11, -3.84), "BodyPrimary")
	for _, side in { -1, 1 } do
		addPart(staticRoot, "BumperWing" .. side, Vector3.new(1.12, 0.4, 0.52),
			CFrame.new(side * 2.26, -0.11, -3.65) * CFrame.Angles(0, -side * math.rad(22), 0), "Trim")
	end
	-- Wedge rises from the front tip toward the column; white nose is the accent.
	addPart(staticRoot, "Nose", Vector3.new(1.65, 0.68, 2.18), CFrame.new(0, 0.21, -2.55), "Accent", nil, true)
	for _, side in { -1, 1 } do
		addPart(staticRoot, "SidePod" .. side, Vector3.new(0.95, 0.82, 2.7),
			CFrame.new(side * 2.17, 0.08, 0.05), "BodyPrimary", nil, true)
	end
	-- Visual shell surrounds Seat center (0, 1.5, 0.5), without changing it.
	addPart(staticRoot, "SeatBack", Vector3.new(2.55, 1.45, 0.22),
		CFrame.new(0, 1.75, 1.91) * CFrame.Angles(math.rad(8), 0, 0), "Seat")
	for _, side in { -1, 1 } do
		addPart(staticRoot, "SeatBolster" .. side, Vector3.new(0.2, 0.9, 2.35),
			CFrame.new(side * 1.37, 1.45, 0.5), "Seat", nil, true)
	end
	addPart(staticRoot, "EngineBlock", Vector3.new(1.65, 0.8, 1.1), CFrame.new(0, 0.72, 2.88), "Trim"):SetAttribute("MaterialRole", "Metal")
	addPart(staticRoot, "CoolingHead", Vector3.new(1.8, 0.24, 1.18), CFrame.new(0, 1.24, 2.88), "Metal")
	addPart(staticRoot, "IntakeFilter", Vector3.new(0.85, 0.63, 0.63), CFrame.new(0.38, 1.67, 2.88), "Trim", Enum.PartType.Cylinder)
	for _, side in { -1, 1 } do
		-- Cylinder axis is local X; rotate it to Z, with its rear tip at Z=4.15.
		addPart(staticRoot, "Exhaust" .. side, Vector3.new(1.15, 0.46, 0.46),
			CFrame.new(side * 1.45, 0.18, 3.575) * CFrame.Angles(0, math.pi / 2, 0), "Metal", Enum.PartType.Cylinder)
	end
	addPart(staticRoot, "RearBumper", Vector3.new(5.85, 0.3, 0.3), CFrame.new(0, -0.16, 3.92), "Trim", Enum.PartType.Cylinder)
	addPart(staticRoot, "SteeringColumn", Vector3.new(0.2, 1.25, 0.2), CFrame.new(0, 1.05, -1.05), "Metal")
	local steeringCenter = Vector3.new(0, 1.65, -1.05)
	local steeringPivot = addPivot(visual, "SteeringPivot", CFrame.new(steeringCenter))
	steeringPivot:SetAttribute("VisualMotionRole", "SteeringWheel")
	addPart(steeringPivot, "SteeringWheel", Vector3.new(0.27, 0.27, 0.16), CFrame.new(steeringCenter), "BodyPrimary")
	for index = 1, 6 do
		local angle = (index - 1) * 2 * math.pi / 6
		addPart(steeringPivot, "SteeringRim" .. index, Vector3.new(0.62, 0.15, 0.16),
			CFrame.new(steeringCenter + Vector3.new(math.cos(angle) * 0.54, math.sin(angle) * 0.54, 0))
				* CFrame.Angles(0, 0, angle + math.pi / 2), "Trim")
	end
	addPart(steeringPivot, "SteeringCrossSpoke", Vector3.new(1.0, 0.1, 0.1), CFrame.new(steeringCenter), "Metal")
	addPart(steeringPivot, "SteeringLowerSpoke", Vector3.new(0.1, 0.47, 0.1), CFrame.new(steeringCenter + Vector3.new(0, -0.25, 0)), "Metal")
	addWheel(visual, "WheelFL", 0.925, 0.9, Vector3.new(-3.25, wheelCenterHeight(1.85), -2.55), true, "Left")
	addWheel(visual, "WheelFR", 0.925, 0.9, Vector3.new(3.25, wheelCenterHeight(1.85), -2.55), true, "Right")
	addWheel(visual, "WheelRL", 1.025, 1.05, Vector3.new(-3.3, wheelCenterHeight(2.05), 2.65), false, "Left")
	addWheel(visual, "WheelRR", 1.025, 1.05, Vector3.new(3.3, wheelCenterHeight(2.05), 2.65), false, "Right")

	-- Preserve the old exhaust tips (+0.4 local Z) independently of mesh bounds.
	addExhaustAnchor(staticRoot, "ExhaustLeft", Vector3.new(-1.45, 0.18, 4.15))
	addExhaustAnchor(staticRoot, "ExhaustRight", Vector3.new(1.45, 0.18, 4.15))

	KartVisualFactory.applyColors(visual, definition)
	KartVisualFactory.applyMaterials(visual)
	local valid, diagnostics = KartVisualFactory.validateVisual(visual)
	if not valid then
		visual:Destroy()
		error("[KartVisualFactory] Invalid visual " .. tostring(definition.VisualModelName)
			.. "\n" .. table.concat(diagnostics, "\n"))
	end
	return visual
end

return KartVisualFactory
