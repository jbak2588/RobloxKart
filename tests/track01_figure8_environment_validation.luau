-- Tests real runtime Track01 (PracticeFigure8V1) P0 road color, P1-A SpeedCues,
-- P1-B VisualRails, noncolliding flags, edge clearance, budget and cache lifecycle.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local source = fs.readFile("tests/track_environment_validation.luau")
local prefix = source:sub(1, assert(source:find('local prototype=object("Folder")', 1, true)) - 1)

luau.load(prefix .. [====[
local Color3 = rb.Color3
local Vector2 = rb.Vector2
local checks = 0
local function check(value, label) assert(value, label); checks += 1 end

local catalog = luau.load(fs.readFile("src/shared/TrackCatalog.luau"), { environment = env })()
local track01 = catalog.Entries.Track01
local track01Race = catalog.Entries.Track01Race
local track03 = catalog.Entries.Track03

-- 1. P0 Road Color Isolation
local p0Folder = object("Folder")
local world01 = builder.build(p0Folder, track01, 0)
local world01Race = builder.build(object("Folder"), track01Race, 0)
local world03 = builder.build(object("Folder"), track03, 0)

local road01 = world01:FindFirstChild("Road"):GetChildren()[1]
local road01Race = world01Race:FindFirstChild("Road"):GetChildren()[1]
local road03 = world03:FindFirstChild("Road"):GetChildren()[1]

check(road01.Color == Color3.fromRGB(56, 59, 65), "Track01 road color upgraded to candidate A (56, 59, 65)")
check(road01Race.Color == Color3.fromRGB(48, 51, 56), "Track01Race road color strictly preserved at base (48, 51, 56)")
check(road03.Color == Color3.fromRGB(48, 51, 56), "Track03 road color strictly preserved at base (48, 51, 56)")

-- 2. Track01 Part Budget & Counts
check(world01:GetAttribute("GeometryId") == "PracticeFigure8V1", "Track01 is PracticeFigure8V1")
check(world01:GetAttribute("EnvironmentCueVersion") == 10, "Track01 environment cue version incremented to 10 for dense crossover and cluster layout")
check(world01:GetAttribute("SpeedCueObjectCount") == 0, "Track01 has no legacy SpeedCue objects in current approved builder")
check(world01:GetAttribute("SpeedCuePartCount") == 0, "Track01 has no legacy SpeedCue parts")
check(world01:GetAttribute("VisualRailPartCount") == 88, "Track01 has 88 dense outer VisualRail segments")
check(world01:GetAttribute("BrandedVisualRailCount") == 31, "Track01 has 31 branded KDM VisualRails")
check(world01:GetAttribute("BarrierPartCount") == 0, "Track01 barrier count remains strictly 0 (no physics barrier in Figure8)")
check(world01:GetAttribute("BarrierTriggerPartCount") == 0, "Track01 barrier trigger count remains strictly 0")
check(#world01:FindFirstChild("RaceTriggers"):GetChildren() == 7, "RaceTriggers contains exactly 7 gates (6 CP + 1 Finish)")

local newVisualParts = world01:GetAttribute("VisualPartCount")
check(newVisualParts == 1054, "current approved Green visual part total1054, including88 rails and no legacy SpeedCues")
check(newVisualParts <= 1400, "Track01 strictly adheres to <=1400 mobile part ceiling")

-- 3. P1 Noncolliding & Scenery Flags and SurfaceGui Branding Layout
local speedCues = world01:FindFirstChild("Environment"):FindFirstChild("SpeedCues")
local visualRails = world01:FindFirstChild("Environment"):FindFirstChild("VisualRails")

check(#speedCues:GetChildren() == 0, "SpeedCues folder empty after approved scenery cleanup")
check(#visualRails:GetChildren() == 88, "VisualRails folder contains 88 visual parts")

local brandedCount, plainCount, chevronCount = 0, 0, 0
for _, p in visualRails:GetChildren() do
	check(p.Anchored == true, "visual rail part anchored")
	check(p.CanCollide == false, "visual rail non-collidable")
	check(p.CanTouch == false, "visual rail no touch query")
	check(p.CanQuery == false, "visual rail no raycast query")
	check(p.CastShadow == false, "visual rail no shadow map cost")
	check(p.Material == rb.Enum.Material.SmoothPlastic, "visual rail smooth plastic material")

	local brandGui = p:FindFirstChild("KDMBrandSurfaceGui")
	if brandGui then
		check(brandGui.Face == rb.Enum.NormalId.Right or brandGui.Face == rb.Enum.NormalId.Left, "SurfaceGui faces road interior")
		check(brandGui.LightInfluence == 0, "SurfaceGui has LightInfluence=0 for clarity")
		local panel = brandGui:FindFirstChild("BrandPanel")
		check(panel ~= nil, "BrandPanel frame exists")
		local flag = panel:FindFirstChild("CheckerFlag")
		check(flag ~= nil, "CheckerFlag frame exists")
		check(#flag:GetChildren() == 12, "CheckerFlag has 12 (3x4) alternating cell frames")
		local text = panel:FindFirstChild("KDMText")
		check(text ~= nil and text.Text == "KDM", "KDMText label exists with exact 'KDM' text")
		check(text.Font == rb.Enum.Font.GothamBold, "KDMText uses bold font")
		check(text.TextColor3 == Color3.fromRGB(255, 255, 255), "KDMText is crisp white")
		brandedCount += 1
	elseif p:GetAttribute("ChevronCurveId") then
  chevronCount+=1;check(p:FindFirstChild("KDMChevronSurfaceGui_Left")~=nil or p:FindFirstChild("KDMChevronSurfaceGui_Right")~=nil,"curve guidance has one road-facing chevron surface")
	else
		plainCount += 1
	end
end
check(brandedCount == 19 and chevronCount==12 and brandedCount+chevronCount==world01:GetAttribute("BrandedVisualRailCount"), "exactly 31 branded VisualRails across track")
check(plainCount == 57, "exactly 57 plain red/white VisualRails")

-- 4. Bounding Edge Distance & Safety Clearance
local definition = geometry.getDefinition(track01.GeometryId)
local course = geometry.getCourse(definition)
local samples = course.Samples
local roadWidth = definition.RoadWidth
local crossingPos = definition.Crossover.Position
local crossingVisualLength = definition.Crossover.VisualHalfLength

local minEdgeClearance = math.huge
for _, p in speedCues:GetChildren() do
	-- Calculate nearest road centerline sample
	local nearestRoadDist = math.huge
	for _, roadPt in samples do
		local d = (Vector2.new(p.Position.X - roadPt.X, p.Position.Z - roadPt.Z)).Magnitude
		if d < nearestRoadDist then nearestRoadDist = d end
	end
	-- Actual bounding edge clearance from road edge (roadWidth * 0.5 = 30)
	local partHalfWidth = math.max(p.Size.X, p.Size.Z) * 0.5
	local edgeClear = nearestRoadDist - (roadWidth * 0.5) - partHalfWidth
	if edgeClear < minEdgeClearance then minEdgeClearance = edgeClear end
	check(edgeClear >= 15.0, "SpeedCue bounding edge clearance >= 15 studs from road edge")

	-- Check clearance from crossover structure
	local crossDist = (Vector2.new(p.Position.X - crossingPos.X, p.Position.Z - crossingPos.Z)).Magnitude
	check(crossDist > crossingVisualLength + 10, "SpeedCue strictly clear of crossover half-length")
end

local minRailEdgeClearance = math.huge
local minRailCrossoverDist = math.huge
local driftExitRailNames = { RailSegment14 = true, RailSegment15 = true, RailSegment16 = true }

for _, p in visualRails:GetChildren() do
	local nearestRoadDist = math.huge
	for _, roadPt in samples do
		local d = (Vector2.new(p.Position.X - roadPt.X, p.Position.Z - roadPt.Z)).Magnitude
		if d < nearestRoadDist then nearestRoadDist = d end
	end
	local partHalfThickness = math.min(p.Size.X, p.Size.Z) * 0.5
	local edgeClear = nearestRoadDist - (roadWidth * 0.5) - partHalfThickness
	if edgeClear < minRailEdgeClearance then minRailEdgeClearance = edgeClear end

	if driftExitRailNames[p.Name] then
		check(edgeClear >= 18.0, "Drift exit rail has >= 18.0 studs safety clearance: " .. p.Name .. " (" .. string.format("%.2f", edgeClear) .. ")")
	else
		check(edgeClear >= 16.0, "Standard visual rail has >= 16.0 studs safety clearance: " .. p.Name .. " (" .. string.format("%.2f", edgeClear) .. ")")
	end

	local crossDist = (Vector2.new(p.Position.X - crossingPos.X, p.Position.Z - crossingPos.Z)).Magnitude
	local partHalfLength = math.max(p.Size.X, p.Size.Z) * 0.5
	local crossEdgeDist = crossDist - partHalfLength
	if crossEdgeDist < minRailCrossoverDist then minRailCrossoverDist = crossEdgeDist end
	check(crossEdgeDist > 30.0, "VisualRail strictly clear of crossover central bridge (>30 studs): " .. p.Name)
end

-- 5. Deterministic Cache & Rebuild Lifecycle
check(builder.build(p0Folder, track01, 0) == world01, "track cache reuse on identical attributes")
world01:SetAttribute("EnvironmentCueVersion", 0)
local rebuilt = builder.build(p0Folder, track01, 0)
check(rebuilt ~= world01, "cache invalidation on EnvironmentCueVersion change")
check(#p0Folder:GetChildren() == 1, "prior track cleaned up after rebuild")

print("PASS: " .. checks .. " Track01 Figure8 current road color, retired SpeedCues0, rail safety clearance (Rail=" .. string.format("%.1f", minRailEdgeClearance) .. "), flags and budget checks")
]====])()

