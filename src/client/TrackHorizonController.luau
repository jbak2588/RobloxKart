-- Client-only low-poly horizon environment for Figure 8 Racing Track.
-- H1-C4: Full Natural Tree Replacement (16 Natural Trees = 4 original + 12 replacements)
-- & Green Valley Ground Continuity & Mountain Mesh Prototype.
-- Replaces all 12 legacy blocky PracticePines on RACE Track01 with 12 natural deciduous trees,
-- resulting in 16 total natural trees (32 MeshParts) cloned from ReplicatedStorage.KDMHorizonTreePrefabs.
-- Preserves H1-C1 mountain meshes (Mountains: HorizonMountainA & HorizonMountainB)
-- and H1-C2 green ground extension (GroundTransition: 6 seamless non-colliding parts).
-- HUB retains existing 12 PracticePines completely untouched.
-- H1-C3, H1-C2, H1-C1 and H1-B modes fully preserved and switchable via setMode().
-- Strictly isolated to RACE server role and Track01 / PracticeFigure8V1 geometry.
-- Zero server CPU/memory/network overhead; completely non-interactive visual scenery.
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controller = {}
local stop = nil

-- Visual modes:
-- "H1_C4_ALL_NATURAL_TREES": H1-C4 Full 16 Natural Trees (4 H1-C3 + 12 replacements) (default)
-- "H1_C3_NATURAL_TREES": H1-C3 4 Natural trees only
-- "H1_C2_CONTINUITY": H1-C2 Green Valley ground continuity + mountains (without natural trees)
-- "H1_C1_MESH": H1-C1 mountain meshes only
-- "H1_B_WEDGES": H1-B stepped ridge wedges
local MODE_H1_C4_ALL_NATURAL_TREES = "H1_C4_ALL_NATURAL_TREES"
local MODE_H1_C3_NATURAL_TREES = "H1_C3_NATURAL_TREES"
local MODE_H1_C2_CONTINUITY = "H1_C2_CONTINUITY"
local MODE_H1_C1_MESH = "H1_C1_MESH"
local MODE_H1_B_WEDGES = "H1_B_WEDGES"

Controller.ACTIVE_MODE = MODE_H1_C4_ALL_NATURAL_TREES

-- H1-C1 & H1-C2 Mountain/Hill Configurations
-- Submerged anchor parts preserve test contract while Smooth Terrain rolling hills form the natural landscape
local MOUNTAIN_CONFIGS = {
	-- 1. North Submerged Anchor (HorizonMountainA, submerged underground)
	{
		name = "HorizonMountainA",
		prefabName = "HorizonMountainA",
		size = Vector3.new(0.1, 0.1, 0.1),
		pos = Vector3.new(60, -100, 980),
		facingAngle = 180,
		meshId = "rbxassetid://5547037363",
		textureId = "",
		color = Color3.fromRGB(76, 115, 68),
		material = Enum.Material.Plastic,
	},
	-- 2. South Submerged Anchor (HorizonMountainB, submerged underground)
	{
		name = "HorizonMountainB",
		prefabName = "HorizonMountainB",
		size = Vector3.new(0.1, 0.1, 0.1),
		pos = Vector3.new(-60, -100, -820),
		facingAngle = 0,
		meshId = "rbxassetid://5547037419",
		textureId = "",
		color = Color3.fromRGB(76, 115, 68),
		material = Enum.Material.Plastic,
	},
}

-- Plan A: Smooth Terrain Rolling Green Hills (replicating the gentle undulating green hills of screenshot 180843.png)
local ROLLING_HILLS_SPHERES = {
	-- North Ridge (replacing MountainA, along Z = 750 to 1100, spanning X = -350 to +350)
	{ pos = Vector3.new(0, -35, 920), radius = 70 },
	{ pos = Vector3.new(120, -42, 960), radius = 78 },
	{ pos = Vector3.new(-110, -38, 940), radius = 74 },
	{ pos = Vector3.new(230, -48, 910), radius = 78 },
	{ pos = Vector3.new(-220, -48, 900), radius = 78 },
	{ pos = Vector3.new(330, -52, 860), radius = 75 },
	{ pos = Vector3.new(-320, -52, 850), radius = 75 },
	{ pos = Vector3.new(60, -35, 840), radius = 60 },
	{ pos = Vector3.new(-70, -35, 830), radius = 60 },
	{ pos = Vector3.new(170, -40, 850), radius = 62 },
	{ pos = Vector3.new(-180, -40, 840), radius = 62 },

	-- South Ridge (replacing MountainB, along Z = -650 to -1000, spanning X = -350 to +350)
	{ pos = Vector3.new(0, -35, -780), radius = 70 },
	{ pos = Vector3.new(-110, -42, -820), radius = 78 },
	{ pos = Vector3.new(120, -38, -800), radius = 74 },
	{ pos = Vector3.new(-230, -48, -760), radius = 78 },
	{ pos = Vector3.new(220, -48, -750), radius = 78 },
	{ pos = Vector3.new(-330, -52, -720), radius = 75 },
	{ pos = Vector3.new(320, -52, -710), radius = 75 },
	{ pos = Vector3.new(-50, -35, -700), radius = 60 },
	{ pos = Vector3.new(60, -35, -690), radius = 60 },
	{ pos = Vector3.new(-160, -40, -710), radius = 62 },
	{ pos = Vector3.new(170, -40, -700), radius = 62 },

	-- East Flank (outer curve transition, along X = 500 to 750)
	{ pos = Vector3.new(580, -42, 100), radius = 72 },
	{ pos = Vector3.new(620, -46, 280), radius = 76 },
	{ pos = Vector3.new(600, -46, -120), radius = 76 },
	{ pos = Vector3.new(530, -38, 440), radius = 64 },
	{ pos = Vector3.new(510, -38, -320), radius = 64 },
	{ pos = Vector3.new(480, -34, 180), radius = 55 },
	{ pos = Vector3.new(470, -34, -40), radius = 55 },

	-- West Flank (outer straight transition, along X = -500 to -750)
	{ pos = Vector3.new(-560, -42, 100), radius = 72 },
	{ pos = Vector3.new(-610, -46, 280), radius = 76 },
	{ pos = Vector3.new(-590, -46, -120), radius = 76 },
	{ pos = Vector3.new(-520, -38, 440), radius = 64 },
	{ pos = Vector3.new(-500, -38, -320), radius = 64 },
	{ pos = Vector3.new(-470, -34, 180), radius = 55 },
	{ pos = Vector3.new(-460, -34, -40), radius = 55 },
}

-- H1-C3 Original Natural Trees (4 trees: 2 on straights, 2 on curves)
local NATURAL_TREE_ORIGINAL_CONFIGS = {
	{
		id = "NaturalTree01",
		prefabName = "NaturalTreeA",
		pos = Vector3.new(-280, 0, 180),
		rotation = 15,
		zone = "West Straight",
	},
	{
		id = "NaturalTree02",
		prefabName = "NaturalTreeA",
		pos = Vector3.new(225, 0, 90),
		rotation = -40,
		zone = "East Straight",
	},
	{
		id = "NaturalTree03",
		prefabName = "NaturalTreeB",
		pos = Vector3.new(0, 0, 575),
		rotation = 180,
		zone = "North Loop Curve",
	},
	{
		id = "NaturalTree04",
		prefabName = "NaturalTreeB",
		pos = Vector3.new(-20, 0, -410),
		rotation = 30,
		zone = "South Loop Curve",
	},
}

-- H1-C4 12 Replacement Natural Trees (replacing PracticePine1..12)
-- Sourced from Place2.rbxlx, displaced outward so exact Leaves OBB has >= 25 studs crown clearance
-- from road edge, strictly outside Crossover (> 135 studs from Crossover center), and pairwise separated (> 40 studs).
local NATURAL_TREE_REPLACEMENT_CONFIGS = {
	{
		id = "NaturalTreeReplacement01",
		prefabName = "NaturalTreeA",
		pos = Vector3.new(-332.6, 0, 293.7),
		rotation = 25,
		zone = "Northwest Straight Outer Flank",
		legacyAnchor = Vector3.new(-319.2, 0, 297.9),
	},
	{
		id = "NaturalTreeReplacement02",
		prefabName = "NaturalTreeB",
		pos = Vector3.new(-226.6, 0, 548.5),
		rotation = -15,
		zone = "Northwest Loop Exit Outer",
		legacyAnchor = Vector3.new(-222.7, 0, 541.5),
	},
	{
		id = "NaturalTreeReplacement03",
		prefabName = "NaturalTreeA",
		pos = Vector3.new(-41.0, 0, 401.0),
		rotation = 190,
		zone = "North Loop Inner Basin",
		legacyAnchor = Vector3.new(-40.7, 0, 407.0),
	},
	{
		id = "NaturalTreeReplacement04",
		prefabName = "NaturalTreeB",
		pos = Vector3.new(199.4, 0, 572.4),
		rotation = 75,
		zone = "Northeast Loop Entry Outer",
		legacyAnchor = Vector3.new(197.1, 0, 559.6),
	},
	{
		id = "NaturalTreeReplacement05",
		prefabName = "NaturalTreeA",
		pos = Vector3.new(355.3, 0, 418.4),
		rotation = -60,
		zone = "Northeast Sweep Outer Flank",
		legacyAnchor = Vector3.new(341.5, 0, 416.1),
	},
	{
		id = "NaturalTreeReplacement06",
		prefabName = "NaturalTreeB",
		pos = Vector3.new(156.6, 0, 337.8),
		rotation = 135,
		zone = "East Sweep Inner Basin",
		legacyAnchor = Vector3.new(162.1, 0, 333.5),
	},
	{
		id = "NaturalTreeReplacement07",
		prefabName = "NaturalTreeA",
		pos = Vector3.new(-170.3, 0, -5.4),
		rotation = 45,
		zone = "West Crossover Approach Outer",
		legacyAnchor = Vector3.new(-112.1, 0, -49.4),
	},
	{
		id = "NaturalTreeReplacement08",
		prefabName = "NaturalTreeB",
		pos = Vector3.new(-214.8, 0, -183.5),
		rotation = -110,
		zone = "Southwest Hairpin Entry Outer",
		legacyAnchor = Vector3.new(-205.7, 0, -187.6),
	},
	{
		id = "NaturalTreeReplacement09",
		prefabName = "NaturalTreeA",
		pos = Vector3.new(-160.9, 0, -375.8),
		rotation = 160,
		zone = "South Hairpin Apex Outer",
		legacyAnchor = Vector3.new(-154.6, 0, -368.1),
	},
	{
		id = "NaturalTreeReplacement10",
		prefabName = "NaturalTreeB",
		pos = Vector3.new(80.5, 0, -408.2),
		rotation = -45,
		zone = "Southeast Hairpin Exit Outer",
		legacyAnchor = Vector3.new(77.7, 0, -394.5),
	},
	{
		id = "NaturalTreeReplacement11",
		prefabName = "NaturalTreeA",
		pos = Vector3.new(212.1, 0, -268.9),
		rotation = 80,
		zone = "Southeast Loop Outer Flank",
		legacyAnchor = Vector3.new(204.3, 0, -267.2),
	},
	{
		id = "NaturalTreeReplacement12",
		prefabName = "NaturalTreeB",
		pos = Vector3.new(169.1, 0, -110.0),
		rotation = -95,
		zone = "East Crossover Return Outer",
		legacyAnchor = Vector3.new(160.0, 0, -116.2),
	},
}

-- Combined list of all 16 natural trees for H1-C4
local ALL_NATURAL_TREE_CONFIGS = {}
for _, t in NATURAL_TREE_ORIGINAL_CONFIGS do
	table.insert(ALL_NATURAL_TREE_CONFIGS, t)
end
for _, t in NATURAL_TREE_REPLACEMENT_CONFIGS do
	table.insert(ALL_NATURAL_TREE_CONFIGS, t)
end

-- Ground Extension outer bounds covering past Mountain A (Z: 1236), Mountain B (Z: -1076), and Baseplate (±1024)
local GROUND_OUTER_BOUNDS = {
	minX = -1250,
	maxX = 1250,
	minZ = -1200,
	maxZ = 1400,
	underlap = 2.0, -- 2 studs underlap under Infield perimeter
	thickness = 0.02,
}

-- H1-B Preserved: Visual color palette for KDM Green Valley Racing Circuit
local COLORS = {
	LightGreenHill = Color3.fromRGB(76, 109, 76),
	MidGreenHill = Color3.fromRGB(62, 94, 68),
	DarkForestRidge = Color3.fromRGB(47, 77, 57),
	DarkForestMid = Color3.fromRGB(42, 68, 50),
	DistantMountainBase = Color3.fromRGB(81, 100, 113),
	DistantMountainLight = Color3.fromRGB(96, 114, 126),
	InfieldGrass = Color3.fromRGB(84, 125, 79),
}

-- H1-B Preserved: 6 terrain clusters strictly outside Figure 8 Infield (grassMargin = 180 studs)
local CLUSTER_CONFIGS = {
	{
		name = "Cluster1_NorthMountain",
		kind = "Mountain",
		pos = Vector3.new(100, 0, 740),
		facingAngle = 185,
		parts = {
			{ name = "MainPeak", offset = Vector3.new(0, 0, 0), size = Vector3.new(80, 95, 110), color = COLORS.DistantMountainBase, angle = 0 },
			{ name = "LeftShoulder", offset = Vector3.new(-55, 0, 15), size = Vector3.new(65, 68, 90), color = COLORS.DistantMountainLight, angle = -12 },
			{ name = "RightShoulder", offset = Vector3.new(50, 0, 20), size = Vector3.new(70, 52, 80), color = COLORS.DistantMountainBase, angle = 10 },
		},
	},
	{
		name = "Cluster2_NorthForest",
		kind = "Forest",
		pos = Vector3.new(-270, 0, 710),
		facingAngle = 145,
		parts = {
			{ name = "CanopyMid", offset = Vector3.new(0, 0, 0), size = Vector3.new(65, 54, 75), color = COLORS.DarkForestRidge, angle = 0 },
			{ name = "CanopyLeft", offset = Vector3.new(-45, 0, 10), size = Vector3.new(55, 40, 60), color = COLORS.DarkForestMid, angle = -8 },
			{ name = "CanopyRight", offset = Vector3.new(45, 0, -10), size = Vector3.new(60, 46, 65), color = COLORS.DarkForestRidge, angle = 12 },
		},
	},
	{
		name = "Cluster3_EastHill",
		kind = "Hill",
		pos = Vector3.new(510, 0, 80),
		facingAngle = -95,
		parts = {
			{ name = "MainDome", offset = Vector3.new(0, 0, 0), size = Vector3.new(95, 38, 95), color = COLORS.LightGreenHill, angle = 0 },
			{ name = "LowSlope", offset = Vector3.new(10, 0, 35), size = Vector3.new(80, 24, 80), color = COLORS.MidGreenHill, angle = 15 },
		},
	},
	{
		name = "Cluster4_SouthMountain",
		kind = "Mountain",
		pos = Vector3.new(-80, 0, -580),
		facingAngle = 15,
		parts = {
			{ name = "MainPeak", offset = Vector3.new(0, 0, 0), size = Vector3.new(75, 88, 100), color = COLORS.DistantMountainBase, angle = 0 },
			{ name = "EastPeak", offset = Vector3.new(50, 0, 10), size = Vector3.new(60, 62, 85), color = COLORS.DistantMountainLight, angle = 8 },
			{ name = "WestShoulder", offset = Vector3.new(-50, 0, 20), size = Vector3.new(65, 48, 75), color = COLORS.DistantMountainBase, angle = -14 },
		},
	},
	{
		name = "Cluster5_SouthHill",
		kind = "Hill",
		pos = Vector3.new(380, 0, -560),
		facingAngle = 40,
		parts = {
			{ name = "MainDome", offset = Vector3.new(0, 0, 0), size = Vector3.new(85, 36, 85), color = COLORS.MidGreenHill, angle = 0 },
			{ name = "SubSlope", offset = Vector3.new(-30, 0, 15), size = Vector3.new(70, 22, 70), color = COLORS.LightGreenHill, angle = -10 },
		},
	},
	{
		name = "Cluster6_WestForest",
		kind = "Forest",
		pos = Vector3.new(-490, 0, 120),
		facingAngle = 85,
		parts = {
			{ name = "CanopyMid", offset = Vector3.new(0, 0, 0), size = Vector3.new(60, 50, 70), color = COLORS.DarkForestRidge, angle = 0 },
			{ name = "CanopyNorth", offset = Vector3.new(10, 0, 45), size = Vector3.new(50, 38, 55), color = COLORS.DarkForestMid, angle = 10 },
			{ name = "CanopySouth", offset = Vector3.new(-10, 0, -45), size = Vector3.new(55, 42, 60), color = COLORS.DarkForestRidge, angle = -8 },
		},
	},
}

local function createVisualWedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = name
	wedge.Size = size
	wedge.CFrame = cf
	wedge.Color = color
	wedge.Material = Enum.Material.SmoothPlastic
	wedge.Anchored = true
	wedge.CanCollide = false
	wedge.CanTouch = false
	wedge.CanQuery = false
	wedge.CastShadow = false
	wedge.Parent = parent
	return wedge
end

local function getGroundTop(testTrack: Model): number
	local road = testTrack:FindFirstChild("Road")
	if road then
		for _, child in road:GetChildren() do
			if child:IsA("BasePart") then
				return child.Position.Y
			end
		end
	end
	local safetyGround = testTrack:FindFirstChild("SafetyGround")
	if safetyGround and safetyGround:IsA("BasePart") then
		return safetyGround.Position.Y + safetyGround.Size.Y * 0.5
	end
	return 0
end

local function getPhysicalGroundTop(testTrack: Model): number
	local safetyGround = testTrack:FindFirstChild("SafetyGround")
	if safetyGround and safetyGround:IsA("BasePart") then
		return safetyGround.Position.Y + safetyGround.Size.Y * 0.5
	end
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		return baseplate.Position.Y + baseplate.Size.Y * 0.5
	end
	return 0
end

local function getInfieldBounds(testTrack: Model)
	local env = testTrack:FindFirstChild("Environment")
	local infield = env and env:FindFirstChild("Infield")
	if infield and infield:IsA("BasePart") then
		local pos = infield.Position
		local size = infield.Size
		return {
			minX = pos.X - size.X * 0.5,
			maxX = pos.X + size.X * 0.5,
			minZ = pos.Z - size.Z * 0.5,
			maxZ = pos.Z + size.Z * 0.5,
		}
	end
	return {
		minX = -432.925,
		maxX = 447.147,
		minZ = -500.000,
		maxZ = 665.039,
	}
end

local function isEligible(testTrack: Instance?): (boolean, string?)
	local role = Workspace:GetAttribute("KDMServerRole")
	if role ~= "RACE" then
		return false, "RoleNotRace:" .. tostring(role)
	end
	if not testTrack or not testTrack:IsA("Model") then
		return false, "InvalidTrackModel"
	end
	local trackId = testTrack:GetAttribute("TrackId")
	if trackId ~= "Track01" then
		return false, "TrackNotTrack01:" .. tostring(trackId)
	end
	local geometryId = testTrack:GetAttribute("GeometryId")
	if geometryId ~= "PracticeFigure8V1" then
		return false, "GeometryNotPracticeFigure8V1:" .. tostring(geometryId)
	end
	if not testTrack:FindFirstChild("Road") then
		return false, "MissingRoad"
	end
	return true, nil
end

local function buildGroundTransition(parent: Instance, infieldBounds: any, groundY: number): number
	local outer = GROUND_OUTER_BOUNDS
	local underlap = outer.underlap
	local thickness = outer.thickness
	local posY = groundY + thickness * 0.5

	local groundPartDefs = {
		{
			name = "GreenNorthWest",
			minX = outer.minX, maxX = 0,
			minZ = infieldBounds.maxZ - underlap, maxZ = outer.maxZ,
		},
		{
			name = "GreenNorthEast",
			minX = 0, maxX = outer.maxX,
			minZ = infieldBounds.maxZ - underlap, maxZ = outer.maxZ,
		},
		{
			name = "GreenSouthWest",
			minX = outer.minX, maxX = 0,
			minZ = outer.minZ, maxZ = infieldBounds.minZ + underlap,
		},
		{
			name = "GreenSouthEast",
			minX = 0, maxX = outer.maxX,
			minZ = outer.minZ, maxZ = infieldBounds.minZ + underlap,
		},
		{
			name = "GreenWest",
			minX = outer.minX, maxX = infieldBounds.minX + underlap,
			minZ = infieldBounds.minZ + underlap, maxZ = infieldBounds.maxZ - underlap,
		},
		{
			name = "GreenEast",
			minX = infieldBounds.maxX - underlap, maxX = outer.maxX,
			minZ = infieldBounds.minZ + underlap, maxZ = infieldBounds.maxZ - underlap,
		},
	}

	local count = 0
	for _, def in groundPartDefs do
		local sizeX = def.maxX - def.minX
		local sizeZ = def.maxZ - def.minZ
		local posX = (def.minX + def.maxX) * 0.5
		local posZ = (def.minZ + def.maxZ) * 0.5

		local part = Instance.new("Part")
		part.Name = def.name
		part.Size = Vector3.new(sizeX, thickness, sizeZ)
		part.CFrame = CFrame.new(posX, posY, posZ)
		part.Color = COLORS.InfieldGrass
		part.Material = Enum.Material.Grass
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Parent = parent
		count += 1
	end

	return count
end

local function buildMountains(parent: Instance, groundY: number): number
	local prefabsFolder = ReplicatedStorage:FindFirstChild("KDMHorizonMountainPrefabs")
	if not prefabsFolder and ReplicatedStorage.WaitForChild then
		prefabsFolder = ReplicatedStorage:WaitForChild("KDMHorizonMountainPrefabs", 3)
	end
	if not prefabsFolder then
		warn("[KDM:Horizon] ReplicatedStorage.KDMHorizonMountainPrefabs not found; cannot spawn mountains")
		return 0
	end

	local count = 0
	for _, cfg in MOUNTAIN_CONFIGS do
		local prefab = prefabsFolder:FindFirstChild(cfg.prefabName)
		if prefab and (prefab:IsA("MeshPart") or prefab:IsA("BasePart")) then
			local mountain = prefab:Clone()
			mountain.Name = cfg.name
			mountain.Size = cfg.size

			-- Submerged anchor: Pointy mountain mesh completely removed from view, replaced by Smooth Terrain rolling hills
			mountain.TextureID = cfg.textureId or ""
			mountain.Color = cfg.color or Color3.fromRGB(85, 120, 80)
			mountain.Material = cfg.material or Enum.Material.Plastic
			mountain.Transparency = 1

			local rot = CFrame.Angles(0, math.rad(cfg.facingAngle), 0)
			local posY = groundY + cfg.pos.Y
			mountain.CFrame = CFrame.new(cfg.pos.X, posY, cfg.pos.Z) * rot

			mountain.Anchored = true
			mountain.CanCollide = false
			mountain.CanTouch = false
			mountain.CanQuery = false
			mountain.CastShadow = false
			mountain.Parent = parent
			count += 1
		else
			warn(string.format("[KDM:Horizon] Prefab '%s' missing or invalid in KDMHorizonMountainPrefabs", cfg.prefabName))
		end
	end

	return count
end

local function getTerrain(): any?
	if typeof(Workspace) ~= "table" and typeof(Workspace) ~= "userdata" then
		return nil
	end
	if typeof((Workspace :: any).FindFirstChildOfClass) == "function" then
		local ok, res = pcall(function()
			return (Workspace :: any):FindFirstChildOfClass("Terrain")
		end)
		if ok and res then
			return res
		end
	end
	if typeof((Workspace :: any).FindFirstChild) == "function" then
		local ok, res = pcall(function()
			return (Workspace :: any):FindFirstChild("Terrain")
		end)
		if ok and res then
			return res
		end
	end
	return (Workspace :: any).Terrain
end

local function buildRollingHills(groundY: number): number
	local terrain = getTerrain()
	if not terrain then
		return 0
	end

	-- Plan A: Activate 3D procedural grass decoration and grass length
	pcall(function()
		terrain.Decoration = true
		if (terrain :: any).GrassLength ~= nil then
			(terrain :: any).GrassLength = 0.7
		end
	end)

	local count = 0
	if typeof((terrain :: any).FillBall) == "function" then
		for _, sphere in ROLLING_HILLS_SPHERES do
			local center = Vector3.new(sphere.pos.X, groundY + sphere.pos.Y, sphere.pos.Z)
			pcall(function()
				(terrain :: any):FillBall(center, sphere.radius, Enum.Material.Grass)
			end)
			count += 1
		end
	end

	return count
end

local function clearRollingHills(groundY: number)
	local terrain = getTerrain()
	if not terrain or typeof((terrain :: any).FillBall) ~= "function" then
		return
	end

	for _, sphere in ROLLING_HILLS_SPHERES do
		local center = Vector3.new(sphere.pos.X, groundY + sphere.pos.Y, sphere.pos.Z)
		pcall(function()
			(terrain :: any):FillBall(center, sphere.radius + 2, Enum.Material.Air)
		end)
	end
end

local function buildNaturalTreesFromList(parent: Instance, treeConfigList: { any }, groundY: number): (number, number)
	local prefabsFolder = ReplicatedStorage:FindFirstChild("KDMHorizonTreePrefabs")
	if not prefabsFolder and ReplicatedStorage.WaitForChild then
		prefabsFolder = ReplicatedStorage:WaitForChild("KDMHorizonTreePrefabs", 3)
	end
	if not prefabsFolder then
		warn("[KDM:Horizon] ReplicatedStorage.KDMHorizonTreePrefabs not found; cannot spawn natural trees")
		return 0, 0
	end

	local treeCount = 0
	local meshPartCount = 0

	for _, cfg in treeConfigList do
		local prefab = prefabsFolder:FindFirstChild(cfg.prefabName)
		if prefab and (prefab:IsA("Model") or prefab:IsA("BasePart")) then
			local treeModel = prefab:Clone()
			treeModel.Name = cfg.id

			local rot = CFrame.Angles(0, math.rad(cfg.rotation or 0), 0)
			local targetCf = CFrame.new(cfg.pos.X, groundY, cfg.pos.Z) * rot

			if treeModel.PivotTo then
				treeModel:PivotTo(targetCf)
			elseif treeModel.SetPrimaryPartCFrame and treeModel.PrimaryPart then
				treeModel:SetPrimaryPartCFrame(targetCf)
			else
				for _, child in treeModel:GetChildren() do
					if child:IsA("BasePart") then
						child.CFrame = targetCf * child.CFrame
					end
				end
			end

			for _, desc in treeModel:GetDescendants() do
				if desc:IsA("BasePart") then
					desc.Anchored = true
					desc.CanCollide = false
					desc.CanTouch = false
					desc.CanQuery = false
					desc.CastShadow = false
					meshPartCount += 1
				end
			end

			treeModel.Parent = parent
			treeCount += 1
		else
			warn(string.format("[KDM:Horizon] Tree prefab '%s' missing or invalid in KDMHorizonTreePrefabs", cfg.prefabName))
		end
	end

	return treeCount, meshPartCount
end

local function buildH1C4AllNaturalTreesHorizon(testTrack: Model, model: Model, groundY: number): Model
	local physicalGroundY = getPhysicalGroundTop(testTrack)

	local mountainsFolder = Instance.new("Folder")
	mountainsFolder.Name = "Mountains"
	mountainsFolder.Parent = model
	local mountainCount = buildMountains(mountainsFolder, physicalGroundY)

	local groundFolder = Instance.new("Folder")
	groundFolder.Name = "GroundTransition"
	groundFolder.Parent = model
	local infieldBounds = getInfieldBounds(testTrack)
	local groundPartCount = buildGroundTransition(groundFolder, infieldBounds, physicalGroundY)

	local treesFolder = Instance.new("Folder")
	treesFolder.Name = "NaturalTrees"
	treesFolder.Parent = model
	local treeCount, treeMeshCount = buildNaturalTreesFromList(treesFolder, ALL_NATURAL_TREE_CONFIGS, physicalGroundY)

	-- Plan A: Smooth Terrain rolling hills (36 spheres creating undulating green ridges + 3D grass decoration)
	local rollingHillsCount = buildRollingHills(physicalGroundY)

	local totalLocalParts = mountainCount + groundPartCount + treeMeshCount
	model:SetAttribute("HorizonMode", MODE_H1_C4_ALL_NATURAL_TREES)
	model:SetAttribute("HorizonMountainCount", mountainCount)
	model:SetAttribute("HorizonGroundPartCount", groundPartCount)
	model:SetAttribute("HorizonTreeCount", treeCount)
	model:SetAttribute("HorizonTreeMeshCount", treeMeshCount)
	model:SetAttribute("HorizonRollingHillsSphereCount", #ROLLING_HILLS_SPHERES)
	model:SetAttribute("HorizonTerrainDecoration", true)
	model:SetAttribute("HorizonPartCount", totalLocalParts)
	model:SetAttribute("HorizonClusterCount", mountainCount)
	model.Parent = testTrack

	print(string.format("[KDM:Horizon] role=RACE track=Track01 geometry=PracticeFigure8V1 mode=H1_C4_ALL_NATURAL_TREES mountains=%d groundParts=%d naturalTrees=%d treeMeshes=%d terrainSpheres=%d localParts=%d spawned=true",
		mountainCount, groundPartCount, treeCount, treeMeshCount, #ROLLING_HILLS_SPHERES, totalLocalParts))

	return model
end

local function buildH1C3NaturalTreesHorizon(testTrack: Model, model: Model, groundY: number): Model
	local physicalGroundY = getPhysicalGroundTop(testTrack)

	local mountainsFolder = Instance.new("Folder")
	mountainsFolder.Name = "Mountains"
	mountainsFolder.Parent = model
	local mountainCount = buildMountains(mountainsFolder, physicalGroundY)

	local groundFolder = Instance.new("Folder")
	groundFolder.Name = "GroundTransition"
	groundFolder.Parent = model
	local infieldBounds = getInfieldBounds(testTrack)
	local groundPartCount = buildGroundTransition(groundFolder, infieldBounds, physicalGroundY)

	local treesFolder = Instance.new("Folder")
	treesFolder.Name = "NaturalTrees"
	treesFolder.Parent = model
	local treeCount, treeMeshCount = buildNaturalTreesFromList(treesFolder, NATURAL_TREE_ORIGINAL_CONFIGS, physicalGroundY)

	local rollingHillsCount = buildRollingHills(physicalGroundY)

	local totalLocalParts = mountainCount + groundPartCount + treeMeshCount
	model:SetAttribute("HorizonMode", MODE_H1_C3_NATURAL_TREES)
	model:SetAttribute("HorizonMountainCount", mountainCount)
	model:SetAttribute("HorizonGroundPartCount", groundPartCount)
	model:SetAttribute("HorizonTreeCount", treeCount)
	model:SetAttribute("HorizonTreeMeshCount", treeMeshCount)
	model:SetAttribute("HorizonRollingHillsSphereCount", #ROLLING_HILLS_SPHERES)
	model:SetAttribute("HorizonTerrainDecoration", true)
	model:SetAttribute("HorizonPartCount", totalLocalParts)
	model:SetAttribute("HorizonClusterCount", mountainCount)
	model.Parent = testTrack

	print(string.format("[KDM:Horizon] role=RACE track=Track01 geometry=PracticeFigure8V1 mode=H1_C3_NATURAL_TREES mountains=%d groundParts=%d naturalTrees=%d treeMeshes=%d terrainSpheres=%d localParts=%d spawned=true",
		mountainCount, groundPartCount, treeCount, treeMeshCount, #ROLLING_HILLS_SPHERES, totalLocalParts))

	return model
end

local function buildH1C2ContinuityHorizon(testTrack: Model, model: Model, groundY: number): Model
	local physicalGroundY = getPhysicalGroundTop(testTrack)

	local mountainsFolder = Instance.new("Folder")
	mountainsFolder.Name = "Mountains"
	mountainsFolder.Parent = model
	local mountainCount = buildMountains(mountainsFolder, physicalGroundY)

	local groundFolder = Instance.new("Folder")
	groundFolder.Name = "GroundTransition"
	groundFolder.Parent = model
	local infieldBounds = getInfieldBounds(testTrack)
	local groundPartCount = buildGroundTransition(groundFolder, infieldBounds, physicalGroundY)

	local rollingHillsCount = buildRollingHills(physicalGroundY)

	local totalLocalParts = mountainCount + groundPartCount
	model:SetAttribute("HorizonMode", MODE_H1_C2_CONTINUITY)
	model:SetAttribute("HorizonMountainCount", mountainCount)
	model:SetAttribute("HorizonGroundPartCount", groundPartCount)
	model:SetAttribute("HorizonTreeCount", 0)
	model:SetAttribute("HorizonTreeMeshCount", 0)
	model:SetAttribute("HorizonRollingHillsSphereCount", #ROLLING_HILLS_SPHERES)
	model:SetAttribute("HorizonTerrainDecoration", true)
	model:SetAttribute("HorizonPartCount", totalLocalParts)
	model:SetAttribute("HorizonClusterCount", mountainCount)
	model.Parent = testTrack

	print(string.format("[KDM:Horizon] role=RACE track=Track01 geometry=PracticeFigure8V1 mode=H1_C2_CONTINUITY mountains=%d groundParts=%d terrainSpheres=%d localParts=%d spawned=true",
		mountainCount, groundPartCount, #ROLLING_HILLS_SPHERES, totalLocalParts))

	return model
end

local function buildH1C1MeshHorizon(testTrack: Model, model: Model, groundY: number): Model
	local physicalGroundY = getPhysicalGroundTop(testTrack)

	local mountainsFolder = Instance.new("Folder")
	mountainsFolder.Name = "Mountains"
	mountainsFolder.Parent = model
	local mountainCount = buildMountains(mountainsFolder, physicalGroundY)

	model:SetAttribute("HorizonMode", MODE_H1_C1_MESH)
	model:SetAttribute("HorizonClusterCount", mountainCount)
	model:SetAttribute("HorizonMountainCount", mountainCount)
	model:SetAttribute("HorizonGroundPartCount", 0)
	model:SetAttribute("HorizonTreeCount", 0)
	model:SetAttribute("HorizonTreeMeshCount", 0)
	model:SetAttribute("HorizonPartCount", mountainCount)
	model.Parent = testTrack

	print(string.format("[KDM:Horizon] role=RACE track=Track01 geometry=PracticeFigure8V1 mode=H1_C1_MESH mountains=%d localParts=%d spawned=true",
		mountainCount, mountainCount))

	return model
end

local function buildH1BWedgeHorizon(testTrack: Model, model: Model, groundY: number): Model
	local partCount = 0

	for _, cfg in CLUSTER_CONFIGS do
		local baseRot = CFrame.Angles(0, math.rad(cfg.facingAngle), 0)
		for _, pDef in cfg.parts do
			local localOffset = baseRot * CFrame.new(pDef.offset)
			local partWorldPos = cfg.pos + Vector3.new(localOffset.X, 0, localOffset.Z)
			local partY = groundY + pDef.size.Y * 0.5
			local partCf = CFrame.new(partWorldPos.X, partY, partWorldPos.Z)
				* baseRot
				* CFrame.Angles(0, math.rad(pDef.angle), 0)

			createVisualWedge(model, string.format("%s_%s", cfg.name, pDef.name), pDef.size, partCf, pDef.color)
			partCount += 1
		end
	end

	model:SetAttribute("HorizonMode", MODE_H1_B_WEDGES)
	model:SetAttribute("HorizonClusterCount", #CLUSTER_CONFIGS)
	model:SetAttribute("HorizonMountainCount", 0)
	model:SetAttribute("HorizonGroundPartCount", 0)
	model:SetAttribute("HorizonTreeCount", 0)
	model:SetAttribute("HorizonTreeMeshCount", 0)
	model:SetAttribute("HorizonPartCount", partCount)
	model.Parent = testTrack

	print(string.format("[KDM:Horizon] role=RACE track=Track01 geometry=PracticeFigure8V1 mode=H1_B_WEDGES clusters=%d localParts=%d spawned=true",
		#CLUSTER_CONFIGS, partCount))

	return model
end

local function buildHorizon(testTrack: Model): Model
	local existing = testTrack:FindFirstChild("ClientHorizonEnvironment")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "ClientHorizonEnvironment"

	local groundY = getGroundTop(testTrack)

	if Controller.ACTIVE_MODE == MODE_H1_C4_ALL_NATURAL_TREES then
		return buildH1C4AllNaturalTreesHorizon(testTrack, model, groundY)
	elseif Controller.ACTIVE_MODE == MODE_H1_C3_NATURAL_TREES then
		return buildH1C3NaturalTreesHorizon(testTrack, model, groundY)
	elseif Controller.ACTIVE_MODE == MODE_H1_C2_CONTINUITY then
		return buildH1C2ContinuityHorizon(testTrack, model, groundY)
	elseif Controller.ACTIVE_MODE == MODE_H1_C1_MESH then
		return buildH1C1MeshHorizon(testTrack, model, groundY)
	else
		return buildH1BWedgeHorizon(testTrack, model, groundY)
	end
end

function Controller.start()
	if stop then
		return
	end

	local connections = {}
	local activeHorizonModel = nil
	local lastGroundY = 0

	local function clearHorizon()
		clearRollingHills(lastGroundY)
		if activeHorizonModel then
			activeHorizonModel:Destroy()
			activeHorizonModel = nil
		end
		local prototype = Workspace:FindFirstChild("Prototype")
		if prototype then
			local testTrack = prototype:FindFirstChild("TestTrack")
			if testTrack then
				local orphaned = testTrack:FindFirstChild("ClientHorizonEnvironment")
				if orphaned then
					orphaned:Destroy()
				end
			end
		end
	end

	local function evaluateTrack(testTrack: Instance?)
		local eligible, _ = isEligible(testTrack)
		if eligible and testTrack and testTrack:IsA("Model") then
			if not activeHorizonModel or activeHorizonModel.Parent ~= testTrack then
				clearHorizon()
				lastGroundY = getPhysicalGroundTop(testTrack)
				activeHorizonModel = buildHorizon(testTrack)
			end
		else
			clearHorizon()
		end
	end

	local prototype = Workspace:FindFirstChild("Prototype")
	if not prototype and Workspace.WaitForChild then
		task.spawn(function()
			local p = Workspace:WaitForChild("Prototype", 5)
			if p and not stop then
				evaluateTrack(p:FindFirstChild("TestTrack"))
			end
		end)
	elseif prototype then
		evaluateTrack(prototype:FindFirstChild("TestTrack"))
	end

	-- Track lifecycle listeners
	if prototype and prototype.ChildAdded then
		table.insert(connections, prototype.ChildAdded:Connect(function(child)
			if child.Name == "TestTrack" then
				evaluateTrack(child)
			end
		end))
	end

	if prototype and prototype.ChildRemoved then
		table.insert(connections, prototype.ChildRemoved:Connect(function(child)
			if child.Name == "TestTrack" then
				clearHorizon()
			end
		end))
	end

	-- Role change guard
	if Workspace.GetAttributeChangedSignal then
		table.insert(connections, Workspace:GetAttributeChangedSignal("KDMServerRole"):Connect(function()
			local currentRole = Workspace:GetAttribute("KDMServerRole")
			if currentRole ~= "RACE" then
				clearHorizon()
			else
				local proto = Workspace:FindFirstChild("Prototype")
				if proto then
					evaluateTrack(proto:FindFirstChild("TestTrack"))
				end
			end
		end))
	end

	stop = function()
		clearHorizon()
		for _, conn in connections do
			conn:Disconnect()
		end
		connections = {}
		stop = nil
	end

	if prototype and prototype.Destroying then
		table.insert(connections, prototype.Destroying:Connect(function()
			Controller.destroy()
		end))
	end

	if Players.LocalPlayer and Players.LocalPlayer.AncestryChanged then
		table.insert(connections, Players.LocalPlayer.AncestryChanged:Connect(function(_, parent)
			if not parent then
				Controller.destroy()
			end
		end))
	end
end

function Controller.destroy()
	if stop then
		stop()
	end
end

function Controller.setMode(mode: string)
	if mode == MODE_H1_C4_ALL_NATURAL_TREES
		or mode == MODE_H1_C3_NATURAL_TREES
		or mode == MODE_H1_C2_CONTINUITY
		or mode == MODE_H1_C1_MESH
		or mode == MODE_H1_B_WEDGES then
		Controller.ACTIVE_MODE = mode
	else
		error("Unknown TrackHorizonController mode: " .. tostring(mode))
	end
end

-- Exported pure evaluation helper for test harnesses
function Controller._isEligible(role: string?, trackId: string?, geometryId: string?, hasRoad: boolean): boolean
	return role == "RACE" and trackId == "Track01" and geometryId == "PracticeFigure8V1" and hasRoad == true
end

-- Exported configurations for geometry / clearance tests
Controller.MODE_H1_C4_ALL_NATURAL_TREES = MODE_H1_C4_ALL_NATURAL_TREES
Controller.MODE_H1_C3_NATURAL_TREES = MODE_H1_C3_NATURAL_TREES
Controller.MODE_H1_C2_CONTINUITY = MODE_H1_C2_CONTINUITY
Controller.MODE_H1_C1_MESH = MODE_H1_C1_MESH
Controller.MODE_H1_B_WEDGES = MODE_H1_B_WEDGES
Controller.CLUSTER_CONFIGS = table.freeze(CLUSTER_CONFIGS)
Controller.MOUNTAIN_CONFIGS = table.freeze(MOUNTAIN_CONFIGS)
Controller.NATURAL_TREE_CONFIGS = table.freeze(NATURAL_TREE_ORIGINAL_CONFIGS)
Controller.NATURAL_TREE_REPLACEMENT_CONFIGS = table.freeze(NATURAL_TREE_REPLACEMENT_CONFIGS)
Controller.ALL_NATURAL_TREE_CONFIGS = table.freeze(ALL_NATURAL_TREE_CONFIGS)
Controller.GROUND_OUTER_BOUNDS = table.freeze(GROUND_OUTER_BOUNDS)
Controller.ROLLING_HILLS_SPHERES = table.freeze(ROLLING_HILLS_SPHERES)

return Controller
