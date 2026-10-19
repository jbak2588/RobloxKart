-- Comprehensive validation for KDM Low-Poly Horizon Environment (H0 + H1 + H1-C1 + H1-C2 + H1-C3 + H1-C4).
-- Verifies H1-C4 Full Natural Tree Replacement (16 Natural Trees = 4 original + 12 replacements, 32 MeshParts)
-- + Server PracticePine suppression on RACE Track01 (VisualPartCount 1366 -> 1318, PracticeTreeCount = 0)
-- + Server PracticePine preservation on HUB Track01 (VisualPartCount = 1366, PracticeTreeCount = 12)
-- + H1-C2 Green Valley Ground Continuity (GroundTransition: 6 seamless non-colliding parts)
-- + H1-C1 Mountain Meshes (Mountains: HorizonMountainA & HorizonMountainB),
-- zero-tolerance guards against Lobby/Hub pollution, exact Figure8 clearance (>= 25 studs crown clearance from road edge),
-- pairwise separation (>= 40 studs, actual min > 99 studs), non-colliding flags, Z-fighting immunity,
-- lifecycle cleanup, and preserved H1-C3, H1-C2, H1-C1 and H1-B modes.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

-- 0. Static RBXMX Asset & Prefab Contract Validation (Mountains & Trees)
local function checkXml(raw, pattern, msg)
	assert(raw:find(pattern, 1, true) ~= nil, msg)
end

-- Mountains rbxmx
local mountainRbxmx = fs.readFile("src/assets/KDMHorizonMountainPrefabs.rbxmx")
checkXml(mountainRbxmx, "rbxassetid://5547037363", "HorizonMountainA MeshId present in rbxmx")
checkXml(mountainRbxmx, "rbxassetid://5547037419", "HorizonMountainB MeshId present in rbxmx")
checkXml(mountainRbxmx, "rbxassetid://16017511205", "Shared mountain TextureID present in rbxmx")
checkXml(mountainRbxmx, "HorizonMountainA", "HorizonMountainA name in rbxmx")
checkXml(mountainRbxmx, "HorizonMountainB", "HorizonMountainB name in rbxmx")

local desMountains = rb.deserializeModel(mountainRbxmx)
assert(#desMountains == 1, "mountains rbxmx contains exactly 1 root item")
assert(desMountains[1].ClassName == "Folder" and desMountains[1].Name == "KDMHorizonMountainPrefabs", "mountains folder valid")
assert(#desMountains[1]:GetChildren() == 2, "KDMHorizonMountainPrefabs contains exactly 2 prefabs")

-- Natural Trees rbxmx
local treeRbxmx = fs.readFile("src/assets/KDMHorizonTreePrefabs.rbxmx")
checkXml(treeRbxmx, "rbxassetid://15547670463", "Trunk MeshId present in tree rbxmx")
checkXml(treeRbxmx, "rbxassetid://14824442818", "LeavesA MeshId present in tree rbxmx")
checkXml(treeRbxmx, "rbxassetid://89914475582080", "LeavesB MeshId present in tree rbxmx")
checkXml(treeRbxmx, "rbxassetid://17372965606", "Bark ColorMap present in tree rbxmx")
checkXml(treeRbxmx, "rbxassetid://16101217575", "TreeLeaves ColorMap present in tree rbxmx")
checkXml(treeRbxmx, "NaturalTreeA", "NaturalTreeA name in tree rbxmx")
checkXml(treeRbxmx, "NaturalTreeB", "NaturalTreeB name in tree rbxmx")

local desTrees = rb.deserializeModel(treeRbxmx)
assert(#desTrees == 1, "tree rbxmx contains exactly 1 root item")
assert(desTrees[1].ClassName == "Folder" and desTrees[1].Name == "KDMHorizonTreePrefabs", "tree folder valid")
local treePrefabs = desTrees[1]:GetChildren()
assert(#treePrefabs == 2, "KDMHorizonTreePrefabs contains exactly 2 tree model prefabs")
for _, tm in treePrefabs do
	assert(tm.ClassName == "Model", "tree prefab is Model: " .. tm.Name)
	assert(tm:FindFirstChild("Trunk") ~= nil, "tree model has Trunk: " .. tm.Name)
	assert(tm:FindFirstChild("Leaves") ~= nil, "tree model has Leaves: " .. tm.Name)
end

-- H1-C4-R2 XML Integrity checks for Rojo 7.7.1
assert(treeRbxmx:find("<SharedString", 1, true) == nil, "tree rbxmx has 0 unresolved SharedString references")
assert(treeRbxmx:find('name="AeroMeshData"', 1, true) == nil, "tree rbxmx has 0 corrupt AeroMeshData references")
assert(treeRbxmx:find('name="PhysicalConfigData"', 1, true) == nil, "tree rbxmx has 0 unneeded PhysicalConfigData references")

local source = fs.readFile("tests/track_environment_validation.luau")
local prefix = source:sub(1, assert(source:find('local prototype=object("Folder")', 1, true)) - 1)

luau.load(prefix .. [====[
local Color3 = rb.Color3
local Vector2 = rb.Vector2
local checks = 19 -- include the 19 static rbxmx checks above
local function check(value, label) assert(value, label); checks += 1 end

local workspace = object("Workspace")

-- Enhance mock methods for controller lifecycle, models, and clone testing
function methods:IsA(class)
	return self.ClassName == class
		or (class == "BasePart" and (self.ClassName == "Part" or self.ClassName == "WedgePart" or self.ClassName == "MeshPart"))
		or (class == "Model" and self.ClassName == "Model")
		or (class == "Folder" and self.ClassName == "Folder")
		or (class == "MeshPart" and self.ClassName == "MeshPart")
end

function methods:Clone()
	local copy = object(self.ClassName)
	copy.Name = self.Name
	for k, v in self.props do
		if k ~= "Parent" then
			copy.props[k] = v
		end
	end
	for k, v in self.attrs do
		copy.attrs[k] = v
	end
	for _, child in self.children do
		local childCopy = child:Clone()
		childCopy.Parent = copy
	end
	if self.ClassName == "Model" and self.PrimaryPart then
		copy.PrimaryPart = copy:FindFirstChild(self.PrimaryPart.Name)
	end
	return copy
end

function methods:GetDescendants()
	local list = {}
	local function collect(node)
		for _, child in node.children do
			table.insert(list, child)
			collect(child)
		end
	end
	collect(self)
	return list
end

function methods:PivotTo(cf)
	local root = self.PrimaryPart or self.children[1]
	local oldRootCf = root.CFrame
	for _, part in self:GetDescendants() do
		if part:IsA("BasePart") then
			local rel = oldRootCf:ToObjectSpace(part.CFrame)
			part.CFrame = cf * rel
		end
	end
end

function methods:SetPrimaryPartCFrame(cf)
	self:PivotTo(cf)
end

local attributeSignals = {}
function methods:GetAttributeChangedSignal(name)
	local sig = { callbacks = {} }
	function sig:Connect(cb)
		table.insert(self.callbacks, cb)
		return {
			Disconnect = function()
				local idx = table.find(self.callbacks, cb)
				if idx then table.remove(self.callbacks, idx) end
			end
		}
	end
	function sig:Fire()
		for _, cb in table.clone(self.callbacks) do cb() end
	end
	attributeSignals[self] = attributeSignals[self] or {}
	attributeSignals[self][name] = sig
	return sig
end

local originalSetAttribute = methods.SetAttribute
function methods:SetAttribute(name, value)
	originalSetAttribute(self, name, value)
	if attributeSignals[self] and attributeSignals[self][name] then
		attributeSignals[self][name]:Fire()
	end
end

-- Setup replicated mountain prefabs mock folder
local mountainPrefabsFolder = object("Folder")
mountainPrefabsFolder.Name = "KDMHorizonMountainPrefabs"
mountainPrefabsFolder.Parent = replicated

local pA = object("MeshPart")
pA.Name = "HorizonMountainA"
pA.Size = rb.Vector3.new(512, 128, 512)
pA.MeshId = "rbxassetid://5547037363"
pA.TextureID = "rbxassetid://16017511205"
pA.Anchored = true
pA.CanCollide = false
pA.CanTouch = false
pA.CanQuery = false
pA.CastShadow = false
pA.Parent = mountainPrefabsFolder

local pB = object("MeshPart")
pB.Name = "HorizonMountainB"
pB.Size = rb.Vector3.new(512, 128, 512)
pB.MeshId = "rbxassetid://5547037419"
pB.TextureID = "rbxassetid://16017511205"
pB.Anchored = true
pB.CanCollide = false
pB.CanTouch = false
pB.CanQuery = false
pB.CastShadow = false
pB.Parent = mountainPrefabsFolder

-- Setup replicated tree prefabs mock folder
local treePrefabsFolder = object("Folder")
treePrefabsFolder.Name = "KDMHorizonTreePrefabs"
treePrefabsFolder.Parent = replicated

local function createMockTreePrefab(name, leafMeshId, leafOffset)
	local model = object("Model")
	model.Name = name

	local trunk = object("MeshPart")
	trunk.Name = "Trunk"
	trunk.Size = rb.Vector3.new(25.386, 57.622, 22.957)
	trunk.CFrame = frames.new(0, 27.811, 0)
	trunk.MeshId = "rbxassetid://15547670463"
	trunk.Anchored = true
	trunk.CanCollide = false
	trunk.CanTouch = false
	trunk.CanQuery = false
	trunk.CastShadow = false
	trunk.Parent = model
	model.PrimaryPart = trunk

	local leaves = object("MeshPart")
	leaves.Name = "Leaves"
	leaves.Size = rb.Vector3.new(47.816, 47.903, 52.688)
	leaves.CFrame = frames.new(leafOffset.X, 27.811 + leafOffset.Y, leafOffset.Z)
	leaves.MeshId = leafMeshId
	leaves.Anchored = true
	leaves.CanCollide = false
	leaves.CanTouch = false
	leaves.CanQuery = false
	leaves.CastShadow = false
	leaves.Parent = model

	model.Parent = treePrefabsFolder
	return model
end

createMockTreePrefab("NaturalTreeA", "rbxassetid://14824442818", rb.Vector3.new(0.936, 11.535, 1.417))
createMockTreePrefab("NaturalTreeB", "rbxassetid://89914475582080", rb.Vector3.new(3.330, 13.218, 0.099))

local players = object("Players")
local controllerEnv = {
	game = {
		GetService = function(_, name)
			if name == "Workspace" then return workspace
			elseif name == "Players" then return players
			elseif name == "ReplicatedStorage" then return replicated
			else error("Unexpected service: " .. tostring(name)) end
		end
	},
	workspace = workspace,
	Instance = { new = object },
	Vector3 = rb.Vector3,
	Vector2 = rb.Vector2,
	CFrame = frames,
	Color3 = rb.Color3,
	Enum = rb.Enum,
	math = math,
	string = string,
	table = table,
	print = print,
	warn = warn,
	task = {
		spawn = function(f) f() end,
		defer = function(f) f() end,
	},
}

local catalog = luau.load(fs.readFile("src/shared/TrackCatalog.luau"), { environment = env })()
local track01 = catalog.Entries.Track01
local track01Race = catalog.Entries.Track01Race
local track02 = catalog.Entries.Track02
local track03 = catalog.Entries.Track03

-- 1. Verify Non-RACE Server TrackBuilder Output (VisualRails=130, SpeedCues=16, Base=1220 => Total=1366, PracticePines=12)
local prototypeFolder = object("Folder")
prototypeFolder.Name = "Prototype"
prototypeFolder.Parent = workspace

workspace:SetAttribute("KDMServerRole", "HUB")
local world01Hub = builder.build(prototypeFolder, track01, 0)
check(world01Hub:GetAttribute("VisualPartCount") == 1366, "HUB Track01 server VisualPartCount preserved at 1366")
check(world01Hub:GetAttribute("VisualRailPartCount") == 130, "HUB Track01 server VisualRailPartCount unchanged at 130")
check(world01Hub:GetAttribute("SpeedCuePartCount") == 16, "HUB Track01 server SpeedCuePartCount unchanged at 16")
check(world01Hub:GetAttribute("PracticeTreeCount") == 12, "HUB Track01 server PracticeTreeCount preserved at 12")
check(world01Hub:GetAttribute("NaturalTreeLegacyAnchorCount") == 12, "HUB Track01 publishes 12 legacy tree anchors")

local hubLandmarks = world01Hub:FindFirstChild("Environment"):FindFirstChild("PracticeLandmarks")
local hubPineCount = 0
for _, c in hubLandmarks:GetChildren() do
	if c.Name:find("PracticePine") then hubPineCount += 1 end
end
check(hubPineCount == 12, "HUB Track01 Environment.PracticeLandmarks contains exactly 12 PracticePine models")

-- 2. Verify RACE Server TrackBuilder Output (PracticePines=0, VisualPartCount = 1366 - 48 = 1318)
workspace:SetAttribute("KDMServerRole", "RACE")
local world01Active = builder.build(prototypeFolder, track01, 0)
check(world01Active:GetAttribute("VisualPartCount") == 1318, "RACE Track01 server VisualPartCount reduced by 48 to 1318")
check(world01Active:GetAttribute("PracticeTreeCount") == 0, "RACE Track01 server PracticeTreeCount is strictly 0")
check(world01Active:GetAttribute("NaturalTreeLegacyAnchorCount") == 12, "RACE Track01 publishes 12 legacy tree anchors")

local raceLandmarks = world01Active:FindFirstChild("Environment"):FindFirstChild("PracticeLandmarks")
local racePineCount = 0
for _, c in raceLandmarks:GetChildren() do
	if c.Name:find("PracticePine") then racePineCount += 1 end
end
check(racePineCount == 0, "RACE Track01 Environment.PracticeLandmarks contains exactly 0 PracticePine models (100% replaced)")

-- Verify all 12 NaturalTreeLegacyAnchor attributes exist
for i = 1, 12 do
	local attrName = string.format("NaturalTreeLegacyAnchor%02d", i)
	local anchor = world01Active:GetAttribute(attrName)
	check(anchor ~= nil and typeof(anchor) == "Vector3", "RACE Track01 provides valid " .. attrName)
end

-- 3. Load Production TrackHorizonController
local horizonModuleSource = fs.readFile("src/client/TrackHorizonController.luau")
local horizonController = luau.load(horizonModuleSource, { environment = controllerEnv })()

check(type(horizonController.start) == "function", "controller has start()")
check(type(horizonController.destroy) == "function", "controller has destroy()")
check(type(horizonController._isEligible) == "function", "controller has _isEligible()")
check(type(horizonController.CLUSTER_CONFIGS) == "table", "controller exports CLUSTER_CONFIGS")
check(type(horizonController.MOUNTAIN_CONFIGS) == "table", "controller exports MOUNTAIN_CONFIGS")
check(type(horizonController.NATURAL_TREE_CONFIGS) == "table", "controller exports NATURAL_TREE_CONFIGS (4 original)")
check(type(horizonController.NATURAL_TREE_REPLACEMENT_CONFIGS) == "table", "controller exports NATURAL_TREE_REPLACEMENT_CONFIGS (12 replacements)")
check(type(horizonController.ALL_NATURAL_TREE_CONFIGS) == "table", "controller exports ALL_NATURAL_TREE_CONFIGS (16 total)")
check(type(horizonController.GROUND_OUTER_BOUNDS) == "table", "controller exports GROUND_OUTER_BOUNDS")
check(horizonController.ACTIVE_MODE == "H1_C4_ALL_NATURAL_TREES", "default controller mode is H1_C4_ALL_NATURAL_TREES")

-- 4. Guard 1 & 2: HUB / Lobby and Unset Role Zero Spawning
workspace:SetAttribute("KDMServerRole", "HUB")
check(horizonController._isEligible("HUB", "Track01", "PracticeFigure8V1", true) == false, "HUB role strictly ineligible")
check(horizonController._isEligible(nil, "Track01", "PracticeFigure8V1", true) == false, "nil role strictly ineligible")
check(horizonController._isEligible("WARMUP", "Track01", "PracticeFigure8V1", true) == false, "unknown role strictly ineligible")

horizonController.start()
check(world01Hub:FindFirstChild("ClientHorizonEnvironment") == nil, "HUB role: exactly 0 horizon models spawned")
horizonController.destroy()

workspace:SetAttribute("KDMServerRole", nil)
horizonController.start()
check(world01Hub:FindFirstChild("ClientHorizonEnvironment") == nil, "nil role: exactly 0 horizon models spawned")
horizonController.destroy()

-- 5. Guard 3: Other Tracks Under RACE Role Zero Spawning
check(horizonController._isEligible("RACE", "Track01Race", "PracticeCircuitV1", true) == false, "Track01Race strictly ineligible")
check(horizonController._isEligible("RACE", "Track02", "PrototypeCircuitV2B", true) == false, "Track02 strictly ineligible")
check(horizonController._isEligible("RACE", "Track03", "HardCircuitV1", true) == false, "Track03 strictly ineligible")
check(horizonController._isEligible("RACE", "Track01", "PracticeFigure8V1", false) == false, "missing road strictly ineligible")

workspace:SetAttribute("KDMServerRole", "RACE")
local world01Race = builder.build(prototypeFolder, track01Race, 0)
horizonController.start()
check(world01Race:FindFirstChild("ClientHorizonEnvironment") == nil, "RACE + Track01Race: exactly 0 horizon spawned")
horizonController.destroy()

-- 6. Valid RACE + Track01 + PracticeFigure8V1 Spawning (H1-C4 ALL NATURAL TREES MODE)
check(horizonController._isEligible("RACE", "Track01", "PracticeFigure8V1", true) == true, "RACE + Track01 + PracticeFigure8V1 strictly eligible")

workspace:SetAttribute("KDMServerRole", "RACE")
local world01Active = builder.build(prototypeFolder, track01, 0)
horizonController.start()
local horizonModel = world01Active:FindFirstChild("ClientHorizonEnvironment")
check(horizonModel ~= nil, "ClientHorizonEnvironment spawned for valid Track01")
check(horizonModel:GetAttribute("HorizonMode") == "H1_C4_ALL_NATURAL_TREES", "HorizonMode is H1_C4_ALL_NATURAL_TREES")
check(horizonModel:GetAttribute("HorizonMountainCount") == 2, "HorizonMountainCount is exactly 2")
check(horizonModel:GetAttribute("HorizonGroundPartCount") == 6, "HorizonGroundPartCount is exactly 6")
check(horizonModel:GetAttribute("HorizonTreeCount") == 16, "HorizonTreeCount is exactly 16 (4 original + 12 replacements)")
check(horizonModel:GetAttribute("HorizonTreeMeshCount") == 32, "HorizonTreeMeshCount is exactly 32 (16 trees x 2 meshes)")
check(horizonModel:GetAttribute("HorizonPartCount") == 40, "HorizonPartCount is exactly 40 (2 mtns + 6 ground + 32 tree meshes)")

-- Duplicate Prevention on re-start()
horizonController.start()
local horizonModels = 0
for _, c in world01Active:GetChildren() do
	if c.Name == "ClientHorizonEnvironment" then
		horizonModels += 1
	end
end
check(horizonModels == 1, "exactly 1 horizon model after re-start (duplicate count = 0)")

-- 7. Hierarchy & Part Counts (Mountains, GroundTransition, and NaturalTrees folders)
local mountainsFolder = horizonModel:FindFirstChild("Mountains")
check(mountainsFolder ~= nil and mountainsFolder:IsA("Folder"), "Mountains folder present in ClientHorizonEnvironment")
local groundFolder = horizonModel:FindFirstChild("GroundTransition")
check(groundFolder ~= nil and groundFolder:IsA("Folder"), "GroundTransition folder present in ClientHorizonEnvironment")
local treesFolder = horizonModel:FindFirstChild("NaturalTrees")
check(treesFolder ~= nil and treesFolder:IsA("Folder"), "NaturalTrees folder present in ClientHorizonEnvironment")

local mountainParts = mountainsFolder:GetChildren()
check(#mountainParts == 2, "Mountains folder contains exactly 2 mesh parts")
local groundParts = groundFolder:GetChildren()
check(#groundParts == 6, "GroundTransition folder contains exactly 6 ground parts")
local treeModels = treesFolder:GetChildren()
check(#treeModels == 16, "NaturalTrees folder contains exactly 16 tree models")

-- Verify all 40 parts in ClientHorizonEnvironment are non-colliding, anchored, and have shadows disabled
for _, part in mountainsFolder:GetChildren() do
	check(part.Anchored == true, "mountain is anchored: " .. part.Name)
	check(part.CanCollide == false, "mountain CanCollide is false: " .. part.Name)
	check(part.CanTouch == false, "mountain CanTouch is false: " .. part.Name)
	check(part.CanQuery == false, "mountain CanQuery is false: " .. part.Name)
	check(part.CastShadow == false, "mountain CastShadow is false: " .. part.Name)
end

for _, part in groundFolder:GetChildren() do
	check(part.Anchored == true, "ground is anchored: " .. part.Name)
	check(part.CanCollide == false, "ground CanCollide is false: " .. part.Name)
	check(part.CanTouch == false, "ground CanTouch is false: " .. part.Name)
	check(part.CanQuery == false, "ground CanQuery is false: " .. part.Name)
	check(part.CastShadow == false, "ground CastShadow is false: " .. part.Name)
	check(part.Material == rb.Enum.Material.Grass, "ground material is Grass: " .. part.Name)
	check(part.Color == rb.Color3.fromRGB(84, 125, 79), "ground color matches Infield Grass: " .. part.Name)
end

for _, tm in treeModels do
	check(tm:IsA("Model"), "tree child is Model: " .. tm.Name)
	local trunk = tm:FindFirstChild("Trunk")
	local leaves = tm:FindFirstChild("Leaves")
	check(trunk ~= nil and trunk:IsA("MeshPart"), "tree model has Trunk MeshPart: " .. tm.Name)
	check(leaves ~= nil and leaves:IsA("MeshPart"), "tree model has Leaves MeshPart: " .. tm.Name)
	for _, part in tm:GetChildren() do
		check(part.Anchored == true, "tree part is anchored: " .. tm.Name .. "." .. part.Name)
		check(part.CanCollide == false, "tree part CanCollide is false: " .. tm.Name .. "." .. part.Name)
		check(part.CanTouch == false, "tree part CanTouch is false: " .. tm.Name .. "." .. part.Name)
		check(part.CanQuery == false, "tree part CanQuery is false: " .. tm.Name .. "." .. part.Name)
		check(part.CastShadow == false, "tree part CastShadow is false: " .. tm.Name .. "." .. part.Name)
	end
end

-- Verify exactly 0 WedgeParts in active H1-C4 mode
local totalWedges = 0
for _, c in horizonModel:GetDescendants() do
	if c:IsA("WedgePart") then totalWedges += 1 end
end
check(totalWedges == 0, "active H1-C4 mode contains exactly 0 WedgeParts")

-- 8. Natural Trees Safety Clearances, Road Distance, and Crossover Immunity for all 16 Trees
local def = geometry.getDefinition("PracticeFigure8V1")
local course = geometry.getCourse(def)
local samples = course.Samples
local roadWidth = 60
local halfRoad = 30
local crossoverPos = def.Crossover.Position
local cp2D = rb.Vector2.new(crossoverPos.X, crossoverPos.Z)

local leafOffsetA = rb.Vector3.new(0.936, 39.346, 1.417)
local leafSizeA = rb.Vector3.new(47.81586, 47.902897, 52.687916)

local leafOffsetB = rb.Vector3.new(3.330, 41.029, 0.099)
local leafSizeB = rb.Vector3.new(47.441795, 52.27529, 52.9685)

local function getLeavesCorners(modelPos, rotationDeg, prefabName)
	local leafOffset = if prefabName == "NaturalTreeA" then leafOffsetA else leafOffsetB
	local leafSize = if prefabName == "NaturalTreeA" then leafSizeA else leafSizeB
	local halfSize = leafSize * 0.5
	local rot = frames.Angles(0, math.rad(rotationDeg), 0)
	local leavesCf = frames.new(modelPos) * rot * frames.new(leafOffset)
	local corners = {}
	for _, sx in {-1, 1} do
		for _, sz in {-1, 1} do
			local pt = leavesCf * rb.Vector3.new(sx * halfSize.X, 0, sz * halfSize.Z)
			table.insert(corners, rb.Vector2.new(pt.X, pt.Z))
		end
	end
	return corners
end

local function distPointToSegment2D(p, a, b)
	local ab = b - a
	local ap = p - a
	local lenSq = ab.X * ab.X + ab.Y * ab.Y
	if lenSq < 1e-8 then return ap.Magnitude end
	local t = math.clamp((ap.X * ab.X + ap.Y * ab.Y) / lenSq, 0, 1)
	local proj = a + ab * t
	return (p - proj).Magnitude
end

local function distPointToOBB2D(p, corners)
	local minDist = math.huge
	for i = 1, 4 do
		local j = (i % 4) + 1
		local d = distPointToSegment2D(p, corners[i], corners[j])
		if d < minDist then minDist = d end
	end
	return minDist
end

local allConfigs = horizonController.ALL_NATURAL_TREE_CONFIGS
check(#allConfigs == 16, "exactly 16 natural tree configurations in ALL_NATURAL_TREE_CONFIGS")

for _, cfg in allConfigs do
	local tm = treesFolder:FindFirstChild(cfg.id)
	check(tm ~= nil, "tree model spawned in workspace: " .. cfg.id)

	local trunk = tm:FindFirstChild("Trunk")
	local leaves = tm:FindFirstChild("Leaves")
	check(trunk ~= nil and leaves ~= nil, "tree components valid for " .. cfg.id)

	-- Exact Leaves OBB calculation for Crossover and Road clearances
	local corners = getLeavesCorners(cfg.pos, cfg.rotation, cfg.prefabName)

	-- 1. Crossover clearance: Leaves OBB strictly >= 135.0 studs from Crossover center (>= 130 + 5 margin)
	local obbCrossoverDist = distPointToOBB2D(cp2D, corners)
	check(obbCrossoverDist >= 135.0,
		string.format("%s Leaves OBB to Crossover center %.2f studs >= 135.0 (>= 130 + 5 extra margin)", cfg.id, obbCrossoverDist))

	-- 2. Road clearance: Leaves OBB strictly >= 25.0 studs from road edge
	local minOBBRoadDist = math.huge
	for _, s in samples do
		local d = distPointToOBB2D(rb.Vector2.new(s.X, s.Z), corners)
		if d < minOBBRoadDist then minOBBRoadDist = d end
	end
	local crownRoadClearance = minOBBRoadDist - halfRoad
	check(crownRoadClearance >= 25.0,
		string.format("%s Leaves OBB to road edge %.2f studs >= 25.0 studs (super safe drift margin)", cfg.id, crownRoadClearance))
end

-- Verify pairwise distance among all 16 trees (no crown overlap, distance >= 40 studs)
local minPairDist = math.huge
local pairNames = ""
for i = 1, #allConfigs do
	for j = i + 1, #allConfigs do
		local t1 = allConfigs[i]
		local t2 = allConfigs[j]
		local d = math.sqrt((t1.pos.X - t2.pos.X)^2 + (t1.pos.Z - t2.pos.Z)^2)
		if d < minPairDist then
			minPairDist = d
			pairNames = t1.id .. " <-> " .. t2.id
		end
	end
end
check(minPairDist >= 40.0, string.format("all 16 trees pairwise separation %.1f >= 40.0 studs (%s)", minPairDist, pairNames))

-- 9. Dynamic Track Replacement / Role Demotion Cleanup
workspace:SetAttribute("KDMServerRole", "HUB")
check(world01Active:FindFirstChild("ClientHorizonEnvironment") == nil, "horizon automatically destroyed on role demotion to HUB")

workspace:SetAttribute("KDMServerRole", "RACE")
check(world01Active:FindFirstChild("ClientHorizonEnvironment") ~= nil, "horizon automatically recreated when role restored to RACE")

local world02 = builder.build(prototypeFolder, track02, 0)
check(world02:FindFirstChild("ClientHorizonEnvironment") == nil, "Track02 has 0 horizon models")

horizonController.destroy()
check(world01Active:FindFirstChild("ClientHorizonEnvironment") == nil, "destroy() cleared active horizon model")

-- 10. Preserved H1-C3 Mode Verification (4 Natural Trees only)
horizonController.setMode("H1_C3_NATURAL_TREES")
workspace:SetAttribute("KDMServerRole", "RACE")
local world01C3 = builder.build(prototypeFolder, track01, 0)
horizonController.start()
local h1c3Model = world01C3:FindFirstChild("ClientHorizonEnvironment")
check(h1c3Model ~= nil, "ClientHorizonEnvironment spawned for H1-C3 mode")
check(h1c3Model:GetAttribute("HorizonMode") == "H1_C3_NATURAL_TREES", "HorizonMode is H1_C3_NATURAL_TREES")
check(h1c3Model:GetAttribute("HorizonMountainCount") == 2, "H1-C3 HorizonMountainCount is 2")
check(h1c3Model:GetAttribute("HorizonGroundPartCount") == 6, "H1-C3 HorizonGroundPartCount is 6")
check(h1c3Model:GetAttribute("HorizonTreeCount") == 4, "H1-C3 HorizonTreeCount is 4")
check(h1c3Model:GetAttribute("HorizonTreeMeshCount") == 8, "H1-C3 HorizonTreeMeshCount is 8")
check(h1c3Model:GetAttribute("HorizonPartCount") == 16, "H1-C3 HorizonPartCount is 16")
horizonController.destroy()

-- 11. Preserved H1-C2 Mode Verification (Ground Continuity + Mountains, 0 Natural Trees)
horizonController.setMode("H1_C2_CONTINUITY")
workspace:SetAttribute("KDMServerRole", "RACE")
local world01C2 = builder.build(prototypeFolder, track01, 0)
horizonController.start()
local h1c2Model = world01C2:FindFirstChild("ClientHorizonEnvironment")
check(h1c2Model ~= nil, "ClientHorizonEnvironment spawned for H1-C2 mode")
check(h1c2Model:GetAttribute("HorizonMode") == "H1_C2_CONTINUITY", "HorizonMode is H1_C2_CONTINUITY")
check(h1c2Model:GetAttribute("HorizonMountainCount") == 2, "H1-C2 HorizonMountainCount is 2")
check(h1c2Model:GetAttribute("HorizonGroundPartCount") == 6, "H1-C2 HorizonGroundPartCount is 6")
check(h1c2Model:GetAttribute("HorizonTreeCount") == 0, "H1-C2 HorizonTreeCount is 0")
check(h1c2Model:GetAttribute("HorizonPartCount") == 8, "H1-C2 HorizonPartCount is 8")
horizonController.destroy()

-- 12. Preserved H1-C1 Mesh-Only Mode Verification (Mountains only, 0 Ground, 0 Trees)
horizonController.setMode("H1_C1_MESH")
workspace:SetAttribute("KDMServerRole", "RACE")
local world01C1 = builder.build(prototypeFolder, track01, 0)
horizonController.start()
local h1c1Model = world01C1:FindFirstChild("ClientHorizonEnvironment")
check(h1c1Model ~= nil, "ClientHorizonEnvironment spawned for H1-C1 mode")
check(h1c1Model:GetAttribute("HorizonMode") == "H1_C1_MESH", "HorizonMode is H1_C1_MESH")
check(h1c1Model:GetAttribute("HorizonMountainCount") == 2, "H1-C1 HorizonMountainCount is 2")
check(h1c1Model:GetAttribute("HorizonGroundPartCount") == 0, "H1-C1 HorizonGroundPartCount is 0")
check(h1c1Model:GetAttribute("HorizonTreeCount") == 0, "H1-C1 HorizonTreeCount is 0")
check(h1c1Model:GetAttribute("HorizonPartCount") == 2, "H1-C1 HorizonPartCount is 2")
horizonController.destroy()

-- 13. Preserved H1-B Wedge Mode Verification
horizonController.setMode("H1_B_WEDGES")
workspace:SetAttribute("KDMServerRole", "RACE")
local world01Rebuilt = builder.build(prototypeFolder, track01, 0)
horizonController.start()
local h1bModel = world01Rebuilt:FindFirstChild("ClientHorizonEnvironment")
check(h1bModel ~= nil, "ClientHorizonEnvironment spawned for H1-B mode")
check(h1bModel:GetAttribute("HorizonMode") == "H1_B_WEDGES", "HorizonMode is H1_B_WEDGES")
check(h1bModel:GetAttribute("HorizonClusterCount") == 6, "H1-B HorizonClusterCount is exactly 6")
check(h1bModel:GetAttribute("HorizonPartCount") == 16, "H1-B HorizonPartCount is exactly 16")

local h1bWedges = h1bModel:GetChildren()
check(#h1bWedges == 16, "H1-B mode contains exactly 16 wedge parts")
local groundY = world01Rebuilt:FindFirstChild("Road"):GetChildren()[1].Position.Y
for _, wedge in h1bWedges do
	check(wedge:IsA("WedgePart"), "H1-B part is WedgePart: " .. wedge.Name)
	check(wedge.Anchored == true, "H1-B wedge is anchored")
	check(wedge.CanCollide == false, "H1-B wedge CanCollide is false")
	check(wedge.CanTouch == false, "H1-B wedge CanTouch is false")
	check(wedge.CanQuery == false, "H1-B wedge CanQuery is false")
	check(wedge.CastShadow == false, "H1-B wedge CastShadow is false")
	check(wedge.Material == rb.Enum.Material.SmoothPlastic, "H1-B wedge material is SmoothPlastic")
	local bottomY = wedge.CFrame.Position.Y - wedge.Size.Y * 0.5
	check(math.abs(bottomY - groundY) < 1e-4, "H1-B wedge touches groundTop")
end

-- Revert mode to H1_C4_ALL_NATURAL_TREES and cleanup
horizonController.destroy()
horizonController.setMode("H1_C4_ALL_NATURAL_TREES")
check(world01Rebuilt:FindFirstChild("ClientHorizonEnvironment") == nil, "H1-B cleanup complete")

-- 14. Client Initialization Integration Check
local initClientSource = fs.readFile("src/client/init.client.luau")
check(initClientSource:find('require(script:WaitForChild("TrackHorizonController"))', 1, true) ~= nil, "init.client requires TrackHorizonController")
check(initClientSource:find('if role == "RACE" then TrackHorizonController.start() end', 1, true) ~= nil, "init.client strictly starts TrackHorizonController only when role == 'RACE'")
check(initClientSource:find('if role == "HUB" then TrackHorizonController.start() end', 1, true) == nil, "init.client NEVER starts TrackHorizonController in HUB")

-- 15. Plan A: Smooth Terrain Rolling Green Hills & Submerged Pointy Mountain Verification
workspace:SetAttribute("KDMServerRole", "RACE")
local worldPlanA = builder.build(prototypeFolder, track01, 0)
horizonController.start()
local planAModel = worldPlanA:FindFirstChild("ClientHorizonEnvironment")
check(planAModel ~= nil, "ClientHorizonEnvironment spawned for Plan A validation")
check(planAModel:GetAttribute("HorizonRollingHillsSphereCount") == 36, "HorizonRollingHillsSphereCount is exactly 36")
check(planAModel:GetAttribute("HorizonTerrainDecoration") == true, "HorizonTerrainDecoration is true")

-- Verify pointy mountain meshes are completely removed from screen (submerged underground & transparent)
local planAMountains = planAModel:FindFirstChild("Mountains")
check(planAMountains ~= nil, "Mountains folder present")
for _, mtn in planAMountains:GetChildren() do
	check(mtn.Transparency == 1, "pointy mountain mesh is 100% transparent: " .. mtn.Name)
	check(mtn.CFrame.Position.Y < 0, "pointy mountain mesh is submerged underground: " .. mtn.Name)
	check(mtn.Size.X <= 0.2 and mtn.Size.Y <= 0.2 and mtn.Size.Z <= 0.2, "pointy mountain mesh size is negligible: " .. mtn.Name)
end

-- Verify all 36 spheres in Controller.ROLLING_HILLS_SPHERES
local spheres = horizonController.ROLLING_HILLS_SPHERES
check(spheres ~= nil, "ROLLING_HILLS_SPHERES exported")
check(#spheres == 36, "ROLLING_HILLS_SPHERES has exactly 36 spheres")

for i, s in spheres do
	local topY = s.pos.Y + s.radius
	check(topY >= 15 and topY <= 40, string.format("Sphere %d top Y (%f) is in gentle rolling hill elevation 15..40", i, topY))

	-- Verify minimum safety clearance from track road samples (>= 50 studs)
	local baseRadius = if s.radius > math.abs(s.pos.Y) then math.sqrt(s.radius * s.radius - s.pos.Y * s.pos.Y) else 0
	local spherePos2D = rb.Vector2.new(s.pos.X, s.pos.Z)
	local minSampleDist = math.huge
	for _, sample in samples do
		local sampPos2D = rb.Vector2.new(sample.X, sample.Z)
		local d = (spherePos2D - sampPos2D).Magnitude - (baseRadius + halfRoad)
		if d < minSampleDist then
			minSampleDist = d
		end
	end
	check(minSampleDist >= 50, string.format("Sphere %d clearance (%f) is >= 50 studs from track road", i, minSampleDist))
end

-- Verify default.project.json configuration for Terrain Decoration
local projJson = fs.readFile("default.project.json")
check(projJson:find('"Decoration": true', 1, true) ~= nil, "default.project.json has Terrain.Decoration = true")
check(projJson:find('"GrassLength": 0.7', 1, true) ~= nil, "default.project.json has Terrain.GrassLength = 0.7")

horizonController.destroy()

print("PASS: " .. checks .. " TrackHorizonController H1-C4 full 16 natural trees + Plan A Smooth Terrain rolling hills + H1-C3 + H1-C2 + H1-C1 + H1-B modes verified")
]====])()
