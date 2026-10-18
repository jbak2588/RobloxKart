-- Comprehensive validation for KDM Circuit Structures (H1-D1).
-- Verifies KDM Sponsor Arch (Finish straight gantry with 24.4 studs vertical clearance)
-- and Lighting Towers (2 scenic floodlight towers with Place2 Spotlights prefab heads).
-- Verifies zero-tolerance guards against Lobby/Hub pollution, exact Figure8 clearance,
-- road & camera headroom, 16 natural trees separation, non-colliding flags,
-- zero dynamic lights/shadows/particles, and budget constraints (<= 24 new visual parts).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

-- 0. Static RBXMX Asset & Prefab Contract Validation (Lighting Prefabs)
local function checkXml(raw, pattern, msg)
	assert(raw:find(pattern, 1, true) ~= nil, msg)
end

local lightingRbxmx = fs.readFile("src/assets/KDMTrackLightingPrefabs.rbxmx")
checkXml(lightingRbxmx, "rbxassetid://15957581356", "Spotlight base MeshId present in lighting rbxmx")
checkXml(lightingRbxmx, "rbxassetid://15957589631", "Spotlight canister MeshId present in lighting rbxmx")
checkXml(lightingRbxmx, "rbxassetid://15562221699", "SA_OB_Trim_A ColorMap present in lighting rbxmx")
checkXml(lightingRbxmx, "OB_Spotlight_a", "OB_Spotlight_a model name in lighting rbxmx")

-- Integrity: verify 0 missing SharedString references causing Rojo 7.7.1 crashes
assert(lightingRbxmx:find("<SharedString", 1, true) == nil, "lighting rbxmx has 0 unresolved SharedString references")
assert(lightingRbxmx:find('name="AeroMeshData"', 1, true) == nil, "lighting rbxmx has 0 AeroMeshData references")
assert(lightingRbxmx:find('name="ModelMeshData"', 1, true) == nil, "lighting rbxmx has 0 ModelMeshData references")

-- Zero dynamic lights in prefab
assert(lightingRbxmx:find('class="SpotLight"', 1, true) == nil, "lighting rbxmx has 0 dynamic SpotLights")
assert(lightingRbxmx:find('class="PointLight"', 1, true) == nil, "lighting rbxmx has 0 dynamic PointLights")

local desLighting = rb.deserializeModel(lightingRbxmx)
assert(#desLighting == 1, "lighting rbxmx contains exactly 1 root item")
assert(desLighting[1].ClassName == "Folder" and desLighting[1].Name == "KDMTrackLightingPrefabs", "lighting folder valid")
local spotModel = desLighting[1]:FindFirstChild("OB_Spotlight_a")
assert(spotModel ~= nil and spotModel.ClassName == "Model", "OB_Spotlight_a model present in prefab")
assert(spotModel:FindFirstChild("base") ~= nil, "spotlight base MeshPart present")
assert(spotModel:FindFirstChild("canister") ~= nil, "spotlight canister MeshPart present")

local source = fs.readFile("tests/track_environment_validation.luau")
local prefix = source:sub(1, assert(source:find('local prototype=object("Folder")', 1, true)) - 1)

luau.load(prefix .. [====[
local Color3 = rb.Color3
local Vector2 = rb.Vector2
local checks = 12 -- include static rbxmx checks above
local function check(value, label) assert(value, label); checks += 1 end

local workspace = object("Workspace")

-- Mock setup for classes
function methods:IsA(class)
	return self.ClassName == class
		or (class == "BasePart" and (self.ClassName == "Part" or self.ClassName == "WedgePart" or self.ClassName == "MeshPart" or self.ClassName == "TrussPart"))
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

-- Setup mock replicated prefabs for lighting
local lightingPrefabsFolder = object("Folder")
lightingPrefabsFolder.Name = "KDMTrackLightingPrefabs"
lightingPrefabsFolder.Parent = replicated

local mockSpotModel = object("Model")
mockSpotModel.Name = "OB_Spotlight_a"
local sBase = object("MeshPart")
sBase.Name = "base"
sBase.Size = rb.Vector3.new(5.0, 0.846, 5.0)
sBase.CFrame = frames.new(0, 0.423, 0)
sBase.MeshId = "rbxassetid://15957581356"
sBase.Anchored = true
sBase.CanCollide = false
sBase.Parent = mockSpotModel
mockSpotModel.PrimaryPart = sBase

local sCanister = object("MeshPart")
sCanister.Name = "canister"
sCanister.Size = rb.Vector3.new(1.072, 2.414, 1.072)
sCanister.CFrame = frames.new(0, 1.63, 0)
sCanister.MeshId = "rbxassetid://15957589631"
sCanister.Anchored = true
sCanister.CanCollide = false
sCanister.Parent = mockSpotModel

local sLens = object("Part")
sLens.Name = "Part"
sLens.Size = rb.Vector3.new(0.8, 0.8, 0.2)
sLens.Material = rb.Enum.Material.Neon
sLens.Anchored = true
sLens.CanCollide = false
sLens.Parent = sCanister

mockSpotModel.Parent = lightingPrefabsFolder

local players = object("Players")
local localPlayer = object("Player")
localPlayer.Name = "LocalPlayer"
local playerGui = object("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = localPlayer
localPlayer.Parent = players
players.LocalPlayer = localPlayer
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
	UDim2 = rb.UDim2,
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

local prototypeFolder = object("Folder")
prototypeFolder.Name = "Prototype"
prototypeFolder.Parent = workspace

-- 1. Load Production TrackCircuitStructuresController
local structuresModuleSource = fs.readFile("src/client/TrackCircuitStructuresController.luau")
local structuresController = luau.load(structuresModuleSource, { environment = controllerEnv })()

check(type(structuresController.start) == "function", "controller has start()")
check(type(structuresController.destroy) == "function", "controller has destroy()")
check(type(structuresController._isEligible) == "function", "controller has _isEligible()")
check(type(structuresController.ARCH_CONFIG) == "table", "controller exports ARCH_CONFIG")
check(type(structuresController.TOWER_CONFIGS) == "table", "controller exports TOWER_CONFIGS")

-- 2. Guard 1 & 2: HUB / Lobby and Unset Role Zero Spawning
workspace:SetAttribute("KDMServerRole", "HUB")
check(structuresController._isEligible(nil) == false, "nil track ineligible")
check(structuresController._isEligible(object("Model")) == false, "HUB role strictly ineligible")

local world01Hub = builder.build(prototypeFolder, track01, 0)
structuresController.start()
check(world01Hub:FindFirstChild("ClientTrackStructures") == nil, "HUB role: exactly 0 circuit structure models spawned")
structuresController.destroy()

workspace:SetAttribute("KDMServerRole", nil)
structuresController.start()
check(world01Hub:FindFirstChild("ClientTrackStructures") == nil, "nil role: exactly 0 circuit structure models spawned")
structuresController.destroy()

-- 3. Guard 3: Other Tracks Under RACE Role Zero Spawning
workspace:SetAttribute("KDMServerRole", "RACE")
local world01Race = builder.build(prototypeFolder, track01Race, 0)
structuresController.start()
check(world01Race:FindFirstChild("ClientTrackStructures") == nil, "RACE + Track01Race: exactly 0 structures spawned")
structuresController.destroy()

local world02 = builder.build(prototypeFolder, track02, 0)
structuresController.start()
check(world02:FindFirstChild("ClientTrackStructures") == nil, "RACE + Track02: exactly 0 structures spawned")
structuresController.destroy()

-- 4. Valid RACE + Track01 + PracticeFigure8V1 Spawning
local world01Active = builder.build(prototypeFolder, track01, 0)
check(structuresController._isEligible(world01Active) == true, "RACE + Track01 + PracticeFigure8V1 strictly eligible")

structuresController.start()
local rootModel = world01Active:FindFirstChild("ClientTrackStructures")
check(rootModel ~= nil, "ClientTrackStructures spawned for RACE Track01")
check(rootModel:GetAttribute("StructureArchCount") == 1, "StructureArchCount is exactly 1")
check(rootModel:GetAttribute("StructureTowerCount") == 2, "StructureTowerCount is exactly 2")

local partCount = rootModel:GetAttribute("StructurePartCount")
local meshPartCount = rootModel:GetAttribute("StructureMeshPartCount")
check(partCount <= 25, string.format("total structure parts %d <= 25 budget limit (24 original + 1 BrandCyanTrim physical marker)", partCount))
check(meshPartCount == 8, string.format("structure MeshParts %d == 8 (2 towers x 2 spotlights x 2 meshes)", meshPartCount))

-- Duplicate Prevention on re-start()
structuresController.start()
local structureModels = 0
for _, c in world01Active:GetChildren() do
	if c.Name == "ClientTrackStructures" then structureModels += 1 end
end
check(structureModels == 1, "exactly 1 structures model after re-start (duplicate count = 0)")

-- 5. Hierarchy and Sponsor Arch Verification
local archModel = rootModel:FindFirstChild("SponsorArch")
check(archModel ~= nil and archModel:IsA("Model"), "SponsorArch Model exists in ClientTrackStructures")

local leftPillar = archModel:FindFirstChild("LeftPillar")
local rightPillar = archModel:FindFirstChild("RightPillar")
local topBeam = archModel:FindFirstChild("TopBeam")
local brandPanel = archModel:FindFirstChild("BrandPanel")
local cyanTrim = archModel:FindFirstChild("BrandCyanTrim")
check(leftPillar ~= nil, "LeftPillar exists in SponsorArch")
check(rightPillar ~= nil, "RightPillar exists in SponsorArch")
check(topBeam ~= nil, "TopBeam exists in SponsorArch")
check(brandPanel ~= nil, "BrandPanel exists in SponsorArch")
check(cyanTrim ~= nil, "BrandCyanTrim physical marker exists in SponsorArch")
check(cyanTrim.Color == rb.Color3.fromRGB(0, 210, 215), "BrandCyanTrim has KDM Cyan color RGB(0,210,215)")

-- CFrame.fromMatrix right-handed orthonormal basis check (det = +1.0, 0 reflection, 0 GPU backface culling)
local bpCf = brandPanel.CFrame
local det = bpCf.XVector:Dot(bpCf.YVector:Cross(bpCf.ZVector))
check(math.abs(det - 1.0) < 0.001, string.format("BrandPanel CFrame determinant %.3f == +1.0 (right-handed, non-inverted)", det))
check(bpCf.LookVector:Dot(structuresController.ARCH_CONFIG.tangent) < -0.99, "BrandPanel Front face points towards oncoming kart (-StartTangent)")

-- Check vertical clearance of Arch over road:
-- Road surface Y = 0.04 studs. TopBeam bottom Y should be >= 24.4 studs!
local topBeamBottomY = topBeam.CFrame.Position.Y - topBeam.Size.Y * 0.5
local brandPanelBottomY = brandPanel.CFrame.Position.Y - brandPanel.Size.Y * 0.5
check(topBeamBottomY >= 24.39, string.format("Arch TopBeam vertical clearance %.2f studs >= 24.4 studs", topBeamBottomY))
check(brandPanelBottomY >= 24.39, string.format("Arch BrandPanel vertical clearance %.2f studs >= 24.4 studs", brandPanelBottomY))

-- Check physical protrusion: BrandPanel must protrude beyond TopBeam on both front and back
local zProtrusion = (brandPanel.Size.Z - topBeam.Size.Z) * 0.5
check(zProtrusion >= 0.4, string.format("BrandPanel depth protrusion %.2f studs >= 0.4 studs (prevents Z-fighting/occlusion)", zProtrusion))

-- Check Arch span across 60-stud road:
-- Pillar distance across road should be >= 70 studs
local pillarSpan = (leftPillar.CFrame.Position - rightPillar.CFrame.Position).Magnitude
check(pillarSpan >= 70.0, string.format("Arch pillar span %.1f studs >= 70.0 studs (60-stud road)", pillarSpan))

-- Check pillar clearance from road centerline (must be outside 30-stud road edge)
local def = geometry.getDefinition("PracticeFigure8V1")
local course = geometry.getCourse(def)
local samples = course.Samples
local halfRoad = 30.0

for _, pillar in { leftPillar, rightPillar } do
	local minD = math.huge
	for _, s in samples do
		local d = math.sqrt((pillar.CFrame.Position.X - s.X)^2 + (pillar.CFrame.Position.Z - s.Z)^2)
		if d < minD then minD = d end
	end
	local edgeDist = minD - halfRoad
	check(edgeDist >= 6.0, string.format("%s clearance from road edge %.1f >= 6.0 studs", pillar.Name, edgeDist))
end

-- Comprehensive SurfaceGui branding verification in PlayerGui with Adornee (H1-D1-R3)
local frontGui = playerGui:FindFirstChild("KDMArchFrontBranding")
local backGui = playerGui:FindFirstChild("KDMArchBackBranding")
check(frontGui ~= nil and frontGui:IsA("SurfaceGui"), "KDMArchFrontBranding SurfaceGui exists in PlayerGui")
check(backGui ~= nil and backGui:IsA("SurfaceGui"), "KDMArchBackBranding SurfaceGui exists in PlayerGui")

check(frontGui.Adornee == brandPanel, "FrontBranding Adornee points to BrandPanel")
check(backGui.Adornee == brandPanel, "BackBranding Adornee points to BrandPanel")
check(frontGui.Face == rb.Enum.NormalId.Front, "FrontBranding Face is Front (-Z, rear view)")
check(backGui.Face == rb.Enum.NormalId.Back, "BackBranding Face is Back (+Z, facing oncoming kart)")
check(frontGui.Enabled == true, "FrontBranding Enabled is true")
check(backGui.Enabled == true, "BackBranding Enabled is true")
check(frontGui.LightInfluence == 0, "FrontBranding LightInfluence is 0 (unshaded emissive)")
check(backGui.LightInfluence == 0, "BackBranding LightInfluence is 0 (unshaded emissive)")

for _, gui in { frontGui, backGui } do
	local bg = gui:FindFirstChild("Background")
	check(bg ~= nil and bg:IsA("Frame"), gui.Name .. " contains Background Frame")
	check(bg.Size.X.Scale == 1 and bg.Size.Y.Scale == 1, gui.Name .. " Background fills canvas")

	local accent = bg:FindFirstChild("AccentStripe")
	check(accent ~= nil and accent:IsA("Frame"), gui.Name .. " contains AccentStripe")
	check(accent.BackgroundColor3 == rb.Color3.fromRGB(0, 210, 215), gui.Name .. " AccentStripe has KDM Cyan RGB(0,210,215)")
	check(accent.Size.Y.Offset >= 6, gui.Name .. " AccentStripe has visible height")

	local leftCheck = bg:FindFirstChild("LeftCheckered")
	local rightCheck = bg:FindFirstChild("RightCheckered")
	check(leftCheck ~= nil and leftCheck:IsA("Frame"), gui.Name .. " contains LeftCheckered flag")
	check(rightCheck ~= nil and rightCheck:IsA("Frame"), gui.Name .. " contains RightCheckered flag")
	check(#leftCheck:GetChildren() >= 12, gui.Name .. " LeftCheckered has checkered pattern cells")
	check(#rightCheck:GetChildren() >= 12, gui.Name .. " RightCheckered has checkered pattern cells")

	local centerBox = bg:FindFirstChild("CenterBox")
	check(centerBox ~= nil and centerBox:IsA("Frame"), gui.Name .. " contains CenterBox")

	local kdmMain = centerBox:FindFirstChild("KDMMainTitle")
	check(kdmMain ~= nil and kdmMain:IsA("TextLabel"), gui.Name .. " contains KDMMainTitle TextLabel")
	check(kdmMain.Text == "KDM", gui.Name .. " KDMMainTitle text is exactly 'KDM'")
	check(kdmMain.TextScaled == true, gui.Name .. " KDMMainTitle has TextScaled=true for maximum readability")
	check(kdmMain.TextColor3 == rb.Color3.fromRGB(245, 245, 245) or kdmMain.TextColor3 == rb.Color3.fromRGB(255, 255, 255), gui.Name .. " KDMMainTitle is crisp white")

	local subTitle = centerBox:FindFirstChild("Title")
	check(subTitle ~= nil and subTitle:IsA("TextLabel"), gui.Name .. " contains Subtitle Title TextLabel")
	check(subTitle.Text:find("KART DRIFT MASTERS") ~= nil, gui.Name .. " Subtitle text displays 'KART DRIFT MASTERS'")
	check(subTitle.TextScaled == true, gui.Name .. " Subtitle has TextScaled=true")
end

-- 6. Lighting Towers Verification
local towersFolder = rootModel:FindFirstChild("LightingTowers")
check(towersFolder ~= nil and towersFolder:IsA("Folder"), "LightingTowers folder exists")

local northTower = towersFolder:FindFirstChild("NorthTower")
local southTower = towersFolder:FindFirstChild("SouthTower")
check(northTower ~= nil and northTower:IsA("Model"), "NorthTower exists")
check(southTower ~= nil and southTower:IsA("Model"), "SouthTower exists")

for _, tower in { northTower, southTower } do
	local mast = tower:FindFirstChild("Mast")
	local platform = tower:FindFirstChild("Platform")
	local spotLeft = tower:FindFirstChild("SpotlightLeft")
	local spotRight = tower:FindFirstChild("SpotlightRight")
	check(mast ~= nil, "Mast exists in " .. tower.Name)
	check(platform ~= nil, "Platform exists in " .. tower.Name)
	check(spotLeft ~= nil, "SpotlightLeft exists in " .. tower.Name)
	check(spotRight ~= nil, "SpotlightRight exists in " .. tower.Name)

	-- Verify spotlight parts contain base and canister with proper MeshIds
	local basePart = spotLeft:FindFirstChild("base")
	local canPart = spotLeft:FindFirstChild("canister")
	check(basePart ~= nil and basePart.MeshId == "rbxassetid://15957581356", "Spotlight base MeshId verified")
	check(canPart ~= nil and canPart.MeshId == "rbxassetid://15957589631", "Spotlight canister MeshId verified")
end

-- Check Tower distances from road edge and crossover
local crossoverPos = def.Crossover.Position
for _, cfg in structuresController.TOWER_CONFIGS do
	local minD = math.huge
	for _, s in samples do
		local d = math.sqrt((cfg.pos.X - s.X)^2 + (cfg.pos.Z - s.Z)^2)
		if d < minD then minD = d end
	end
	local edgeDist = minD - halfRoad
	check(edgeDist >= 18.0, string.format("%s road edge clearance %.1f >= 18.0 studs", cfg.id, edgeDist))

	local distCross = math.sqrt((cfg.pos.X - crossoverPos.X)^2 + (cfg.pos.Z - crossoverPos.Z)^2)
	check(distCross > 200.0, string.format("%s clear of crossover: %.1f > 200.0 studs", cfg.id, distCross))
end

-- 7. Verification of Separation from 16 Natural Trees
local horizonModuleSource = fs.readFile("src/client/TrackHorizonController.luau")
local horizonController = luau.load(horizonModuleSource, { environment = controllerEnv })()
local all16Trees = horizonController.ALL_NATURAL_TREE_CONFIGS

for _, tCfg in structuresController.TOWER_CONFIGS do
	local minTreeDist = math.huge
	local closestTree = ""
	for _, tree in all16Trees do
		local d = math.sqrt((tCfg.pos.X - tree.pos.X)^2 + (tCfg.pos.Z - tree.pos.Z)^2)
		if d < minTreeDist then
			minTreeDist = d
			closestTree = tree.id
		end
	end
	check(minTreeDist >= 50.0, string.format("%s separation from %s is %.1f >= 50.0 studs", tCfg.id, closestTree, minTreeDist))
end

-- 8. Visual Flags & Zero Dynamic Lights / Shadows / Particles Check
for _, part in rootModel:GetDescendants() do
	if part:IsA("BasePart") then
		check(part.Anchored == true, "part anchored: " .. part.Name)
		check(part.CanCollide == false, "part CanCollide is false: " .. part.Name)
		check(part.CanTouch == false, "part CanTouch is false: " .. part.Name)
		check(part.CanQuery == false, "part CanQuery is false: " .. part.Name)
		check(part.CastShadow == false, "part CastShadow is false: " .. part.Name)
	end
	check(not part:IsA("Light"), "no dynamic lights in structures: " .. part.Name)
	check(not part:IsA("ParticleEmitter"), "no particle emitters in structures: " .. part.Name)
end

for _, gui in { frontGui, backGui } do
	check(gui.ResetOnSpawn == false, gui.Name .. " ResetOnSpawn is false (survives character respawn)")
	for _, desc in gui:GetDescendants() do
		check(not desc:IsA("Light"), "no dynamic lights in branding: " .. desc.Name)
		check(not desc:IsA("ParticleEmitter"), "no particle emitters in branding: " .. desc.Name)
		if desc.ClassName == "Frame" or desc.ClassName == "TextLabel" then
			check(desc.Visible ~= false, desc.Name .. " is not hidden")
		end
	end
end

-- 9. Dynamic Lifecycle Cleanup (Workspace structures + PlayerGui SurfaceGuis)
workspace:SetAttribute("KDMServerRole", "HUB")
check(world01Active:FindFirstChild("ClientTrackStructures") == nil, "structures destroyed on demotion to HUB")
check(playerGui:FindFirstChild("KDMArchFrontBranding") == nil, "PlayerGui FrontBranding destroyed on demotion to HUB")
check(playerGui:FindFirstChild("KDMArchBackBranding") == nil, "PlayerGui BackBranding destroyed on demotion to HUB")

workspace:SetAttribute("KDMServerRole", "RACE")
check(world01Active:FindFirstChild("ClientTrackStructures") ~= nil, "structures recreated on restoration to RACE")
check(playerGui:FindFirstChild("KDMArchFrontBranding") ~= nil, "PlayerGui FrontBranding recreated on restoration to RACE")
check(playerGui:FindFirstChild("KDMArchBackBranding") ~= nil, "PlayerGui BackBranding recreated on restoration to RACE")

structuresController.destroy()
check(world01Active:FindFirstChild("ClientTrackStructures") == nil, "destroy() cleared all structures")
check(playerGui:FindFirstChild("KDMArchFrontBranding") == nil, "destroy() cleared FrontBranding from PlayerGui")
check(playerGui:FindFirstChild("KDMArchBackBranding") == nil, "destroy() cleared BackBranding from PlayerGui")

-- 10. Client Initialization Integration Check
local initClientSource = fs.readFile("src/client/init.client.luau")
check(initClientSource:find('require(script:WaitForChild("TrackCircuitStructuresController"))', 1, true) ~= nil, "init.client requires TrackCircuitStructuresController")
check(initClientSource:find('if role == "RACE" then TrackCircuitStructuresController.start() end', 1, true) ~= nil, "init.client strictly starts TrackCircuitStructuresController when role == 'RACE'")
check(initClientSource:find('if role == "HUB" then TrackCircuitStructuresController.start() end', 1, true) == nil, "init.client NEVER starts TrackCircuitStructuresController in HUB")

print("PASS: " .. checks .. " TrackCircuitStructuresController H1-D1 sponsor arch and lighting towers verified")
]====])()
