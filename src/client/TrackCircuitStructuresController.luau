-- Client-only circuit structures for Track01 (Figure 8 Racing Track).
-- H1-D1: KDM Sponsor Arch (1 Finish Straight Gantry) & Lighting Towers (2 Scenic Floodlight Towers).
-- Sponsor Arch: Pure BasePart + SurfaceGui gantry (clearance 24.4 studs over 60-stud road).
-- Lighting Towers: Metal lattice mast + Place2 Spotlights prefab heads (MeshId: 15957581356, 15957589631).
-- Pure non-colliding visual landmarks; zero dynamic lights/shadows/particles to preserve 60FPS mobile performance.
-- Strictly isolated to RACE server role and Track01 / PracticeFigure8V1 geometry.
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controller = {}
local stop = nil

print(string.format("[KDM:ArchBrand] revision=H1-D1-R4 module_loaded=true role=%s", tostring(Workspace:GetAttribute("KDMServerRole"))))

-- Configuration Constants
local ARCH_CONFIG = {
	name = "SponsorArch",
	-- Calculated 35 studs ahead of StartPosition along StartTangent
	center = Vector3.new(-140.37, 0, 169.15),
	tangent = Vector3.new(-0.5822771, 0, 0.8129904),
	span = 76.0, -- 38 studs on each side from centerline (road width is 60, edge at 30)
	clearanceHeight = 24.4, -- vertical clearance under top beam
	pillarHeight = 27.0,
	colors = {
		Structure = Color3.fromRGB(35, 38, 43),
		AccentCyan = Color3.fromRGB(0, 210, 215),
		BrandNavy = Color3.fromRGB(15, 20, 28),
		White = Color3.fromRGB(245, 245, 245),
	},
}

local TOWER_CONFIGS = {
	{
		id = "NorthTower",
		pos = Vector3.new(-260.0, 0, 480.0),
		facingAngle = -45, -- angled inward toward northern curve
		height = 32.0,
		zone = "Northwest Curve Outer Flank",
	},
	{
		id = "SouthTower",
		pos = Vector3.new(172.0, 0, -305.0),
		facingAngle = 135, -- angled inward toward southern curve
		height = 32.0,
		zone = "Southeast Hairpin Exit Flank",
	},
}

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

local function isEligible(testTrack: Instance?): (boolean, string?)
	local role = Workspace:GetAttribute("KDMServerRole")
	if role ~= "RACE" then
		return false, "RoleNotRace:" .. tostring(role)
	end
	if not testTrack or not testTrack:IsA("Model") then
		return false, "InvalidTrackModel"
	end
	local trackId = testTrack:GetAttribute("TrackId")
	if trackId ~= "Track01" and trackId ~= "Track01Desert" then
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

local function createVisualPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local activeGuis = {}

local function cleanupArchBrandingGuis()
	for _, gui in activeGuis do
		if gui and gui.Parent then
			gui:Destroy()
		end
	end
	activeGuis = {}

	local player = Players.LocalPlayer
	if player then
		local pGui = player:FindFirstChild("PlayerGui")
		if pGui then
			local front = pGui:FindFirstChild("KDMArchFrontBranding")
			if front then front:Destroy() end
			local back = pGui:FindFirstChild("KDMArchBackBranding")
			if back then back:Destroy() end
		end
	end
	print("[KDM:ArchBrand] revision=H1-D1-R4 status=cleared")
end

local function attachArchBrandingGuis(boardPanel: Part)
	cleanupArchBrandingGuis()

	local player = Players.LocalPlayer
	local playerGui = if player then player:FindFirstChild("PlayerGui") else nil

	-- Primary: LocalPlayer.PlayerGui (canonical Roblox architecture for client-side SurfaceGuis)
	-- Fallback: boardPanel (in case environment has no LocalPlayer/PlayerGui, e.g. headless tests)
	local targetParent = playerGui or boardPanel
	-- Task 2-B: AlwaysOnTop = true for initial visual verification (toggleable to false via Workspace attribute)
	local alwaysOnTop = Workspace:GetAttribute("KDMArchAlwaysOnTop") ~= false

	local function createBrandingGui(face: Enum.NormalId, name: string): SurfaceGui
		local existing = targetParent:FindFirstChild(name)
		if existing then existing:Destroy() end

		local gui = Instance.new("SurfaceGui")
		gui.Name = name
		gui.Face = face
		gui.LightInfluence = 0
		gui.CanvasSize = Vector2.new(1920, 168)
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.AlwaysOnTop = alwaysOnTop
		-- H1-D1-R4 Root Cause Fix: Prevent Roblox from purging dynamic SurfaceGuis on CharacterAdded respawn
		gui.ResetOnSpawn = false
		gui.Enabled = true
		gui.Adornee = boardPanel
		gui.Parent = targetParent

		local bg = Instance.new("Frame")
		bg.Name = "Background"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = ARCH_CONFIG.colors.BrandNavy
		bg.BorderSizePixel = 0
		bg.Parent = gui

		-- Bottom KDM Cyan Accent Stripe (10px high on 168px canvas)
		local accentStripe = Instance.new("Frame")
		accentStripe.Name = "AccentStripe"
		accentStripe.Size = UDim2.new(1, 0, 0, 10)
		accentStripe.Position = UDim2.new(0, 0, 1, -10)
		accentStripe.BackgroundColor3 = ARCH_CONFIG.colors.AccentCyan
		accentStripe.BorderSizePixel = 0
		accentStripe.Parent = bg

		-- Checkered flag generator for both flanks
		local function createCheckeredFlag(flagName: string, pos: UDim2, anchor: Vector2)
			local flag = Instance.new("Frame")
			flag.Name = flagName
			flag.Size = UDim2.new(0, 130, 0, 130)
			flag.Position = pos
			flag.AnchorPoint = anchor
			flag.BackgroundTransparency = 1
			flag.BorderSizePixel = 0
			flag.Parent = bg

			local rows, cols = 4, 4
			for r = 0, rows - 1 do
				for c = 0, cols - 1 do
					local cell = Instance.new("Frame")
					cell.Name = string.format("Cell_%d_%d", r, c)
					cell.Size = UDim2.new(1 / cols, 0, 1 / rows, 0)
					cell.Position = UDim2.new(c / cols, 0, r / rows, 0)
					cell.BackgroundColor3 = if (r + c) % 2 == 0 then ARCH_CONFIG.colors.White else ARCH_CONFIG.colors.BrandNavy
					cell.BorderSizePixel = 0
					cell.Parent = flag
				end
			end
		end

		createCheckeredFlag("LeftCheckered", UDim2.new(0, 25, 0.5, -5), Vector2.new(0, 0.5))
		createCheckeredFlag("RightCheckered", UDim2.new(1, -25, 0.5, -5), Vector2.new(1, 0.5))

		-- Central typography container
		local centerBox = Instance.new("Frame")
		centerBox.Name = "CenterBox"
		centerBox.Size = UDim2.new(1, -340, 0, 138)
		centerBox.Position = UDim2.new(0.5, 0, 0.5, -5)
		centerBox.AnchorPoint = Vector2.new(0.5, 0.5)
		centerBox.BackgroundTransparency = 1
		centerBox.BorderSizePixel = 0
		centerBox.Parent = bg

		-- Main large bold KDM text
		local kdmTitle = Instance.new("TextLabel")
		kdmTitle.Name = "KDMMainTitle"
		kdmTitle.Size = UDim2.new(1, 0, 0.62, 0)
		kdmTitle.Position = UDim2.new(0, 0, 0, 0)
		kdmTitle.BackgroundTransparency = 1
		kdmTitle.Text = "KDM"
		kdmTitle.TextColor3 = ARCH_CONFIG.colors.White
		kdmTitle.TextScaled = true
		kdmTitle.Font = Enum.Font.GothamBlack
		kdmTitle.TextXAlignment = Enum.TextXAlignment.Center
		kdmTitle.TextYAlignment = Enum.TextYAlignment.Center
		kdmTitle.Parent = centerBox

		-- Subtitle: KART DRIFT MASTERS text
		local subtitle = Instance.new("TextLabel")
		subtitle.Name = "Title"
		subtitle.Size = UDim2.new(1, 0, 0.32, 0)
		subtitle.Position = UDim2.new(0, 0, 0.65, 0)
		subtitle.BackgroundTransparency = 1
		subtitle.Text = "KART DRIFT MASTERS"
		subtitle.TextColor3 = ARCH_CONFIG.colors.White
		subtitle.TextScaled = true
		subtitle.Font = Enum.Font.GothamBold
		subtitle.TextXAlignment = Enum.TextXAlignment.Center
		subtitle.TextYAlignment = Enum.TextYAlignment.Center
		subtitle.Parent = centerBox

		return gui
	end

	local frontGui = createBrandingGui(Enum.NormalId.Front, "KDMArchFrontBranding")
	local backGui = createBrandingGui(Enum.NormalId.Back, "KDMArchBackBranding")

	table.insert(activeGuis, frontGui)
	table.insert(activeGuis, backGui)

	boardPanel:SetAttribute("ArchBrandingActive", true)
	boardPanel:SetAttribute("ArchBrandingFront", frontGui.Name)
	boardPanel:SetAttribute("ArchBrandingBack", backGui.Name)

	local bg = frontGui:FindFirstChild("Background")
	local centerBox = if bg then bg:FindFirstChild("CenterBox") else nil
	local kdmTitle = if centerBox then centerBox:FindFirstChild("KDMMainTitle") else nil
	local subtitle = if centerBox then centerBox:FindFirstChild("Title") else nil

	local inWorkspace = if boardPanel.IsDescendantOf then boardPanel:IsDescendantOf(Workspace) else (boardPanel.Parent ~= nil)
	print(string.format("[KDM:ArchBrand] revision=H1-D1-R4 stage=SPAWNED inWorkspace=%s frontGui=%s backGui=%s parent=%s adornee=%s frontFace=%s backFace=%s resetOnSpawn=%s enabled=%s alwaysOnTop=%s title='%s' subtitle='%s'",
		tostring(inWorkspace),
		tostring(frontGui ~= nil),
		tostring(backGui ~= nil),
		tostring(frontGui.Parent and frontGui.Parent.Name),
		tostring(frontGui.Adornee and frontGui.Adornee.Name),
		tostring(frontGui.Face),
		tostring(backGui.Face),
		tostring(frontGui.ResetOnSpawn),
		tostring(frontGui.Enabled),
		tostring(frontGui.AlwaysOnTop),
		if kdmTitle then tostring(kdmTitle.Text) else "nil",
		if subtitle then tostring(subtitle.Text) else "nil"
	))
end

local function buildSponsorArch(parent: Instance, groundY: number): (Model, Part)
	local archModel = Instance.new("Model")
	archModel.Name = "SponsorArch"

	local forward = ARCH_CONFIG.tangent.Unit
	local right = Vector3.new(forward.Z, 0, -forward.X).Unit
	local up = Vector3.new(0, 1, 0)
	local archCenter = Vector3.new(ARCH_CONFIG.center.X, groundY, ARCH_CONFIG.center.Z)
	-- Use proper 3-arg CFrame.fromMatrix to guarantee right-handed basis (det = +1.0, avoiding GPU backface culling)
	local archBasis = CFrame.fromMatrix(archCenter, right, up)

	local halfSpan = ARCH_CONFIG.span * 0.5 -- 38.0 studs
	local pillarHeight = ARCH_CONFIG.pillarHeight -- 27.0 studs
	local pillarY = pillarHeight * 0.5

	-- 1. Left Pillar & Base Pad (offset -halfSpan along right vector)
	createVisualPart(archModel, "LeftBasePad", Vector3.new(4.5, 0.8, 4.5),
		archBasis * CFrame.new(-halfSpan, 0.4, 0), ARCH_CONFIG.colors.Structure, Enum.Material.Concrete)
	createVisualPart(archModel, "LeftPillar", Vector3.new(2.4, pillarHeight, 2.4),
		archBasis * CFrame.new(-halfSpan, pillarY, 0), ARCH_CONFIG.colors.Structure, Enum.Material.Metal)

	-- 2. Right Pillar & Base Pad (offset +halfSpan along right vector)
	createVisualPart(archModel, "RightBasePad", Vector3.new(4.5, 0.8, 4.5),
		archBasis * CFrame.new(halfSpan, 0.4, 0), ARCH_CONFIG.colors.Structure, Enum.Material.Concrete)
	createVisualPart(archModel, "RightPillar", Vector3.new(2.4, pillarHeight, 2.4),
		archBasis * CFrame.new(halfSpan, pillarY, 0), ARCH_CONFIG.colors.Structure, Enum.Material.Metal)

	-- 3. Top Horizontal Truss Beam (spans 78.4 studs from pillar to pillar)
	local beamY = ARCH_CONFIG.clearanceHeight + 1.1 -- center at 25.5, bottom at 24.4
	createVisualPart(archModel, "TopBeam", Vector3.new(ARCH_CONFIG.span + 2.4, 2.2, 2.4),
		archBasis * CFrame.new(0, beamY, 0), ARCH_CONFIG.colors.Structure, Enum.Material.Metal)

	-- 4. KDM Branding Board (Panel mounted on beam, physically protruding front and back)
	local boardWidth = 48.0
	local boardHeight = 4.2
	local boardDepth = 3.4 -- Protrudes 0.5 studs front (-Z) and 0.5 studs back (+Z) clear of TopBeam (depth 2.4)
	local boardCenterY = ARCH_CONFIG.clearanceHeight + (boardHeight * 0.5) -- exactly 24.4 + 2.1 = 26.5; bottom flush at 24.4
	local boardPanel = createVisualPart(archModel, "BrandPanel", Vector3.new(boardWidth, boardHeight, boardDepth),
		archBasis * CFrame.new(0, boardCenterY, 0), ARCH_CONFIG.colors.BrandNavy, Enum.Material.SmoothPlastic)

	-- 5. Physical KDM Cyan Bottom Trim (guarantees 100% visible physical color marker independent of SurfaceGui)
	createVisualPart(archModel, "BrandCyanTrim", Vector3.new(boardWidth, 0.35, boardDepth + 0.1),
		archBasis * CFrame.new(0, ARCH_CONFIG.clearanceHeight + 0.175, 0), ARCH_CONFIG.colors.AccentCyan, Enum.Material.SmoothPlastic)

	archModel.Parent = parent
	return archModel, boardPanel
end

local function buildLightingTower(parent: Instance, cfg: any, groundY: number, spotlightPrefab: Model?): Model
	local towerModel = Instance.new("Model")
	towerModel.Name = cfg.id

	local rot = CFrame.Angles(0, math.rad(cfg.facingAngle), 0)
	local towerBasis = CFrame.new(cfg.pos.X, groundY, cfg.pos.Z) * rot

	-- 1. Base Pad
	createVisualPart(towerModel, "BasePad", Vector3.new(6.0, 0.8, 6.0),
		towerBasis * CFrame.new(0, 0.4, 0), Color3.fromRGB(45, 48, 52), Enum.Material.Concrete)

	-- 2. Vertical Lattice Mast (height 32.0 studs)
	local mastHeight = cfg.height
	local mastY = mastHeight * 0.5
	local mast = Instance.new("TrussPart")
	mast.Name = "Mast"
	mast.Size = Vector3.new(2, mastHeight, 2)
	mast.CFrame = towerBasis * CFrame.new(0, mastY, 0)
	mast.Color = Color3.fromRGB(110, 115, 120)
	mast.Material = Enum.Material.Metal
	mast.Anchored = true
	mast.CanCollide = false
	mast.CanTouch = false
	mast.CanQuery = false
	mast.CastShadow = false
	mast.Parent = towerModel

	-- 3. Top Platform Crossbar
	local platformY = mastHeight + 0.4
	createVisualPart(towerModel, "Platform", Vector3.new(7.0, 0.8, 2.2),
		towerBasis * CFrame.new(0, platformY, 0), Color3.fromRGB(40, 44, 48), Enum.Material.Metal)

	-- 4. Spotlights Assembly (2 spotlight heads cloned from prefab)
	if spotlightPrefab then
		local function addSpotlightHead(offsetRight: number, headName: string)
			local head = spotlightPrefab:Clone()
			head.Name = headName
			local headCf = towerBasis * CFrame.new(offsetRight, platformY + 0.8, -0.4) * CFrame.Angles(math.rad(-25), 0, 0)
			if head.PivotTo then
				head:PivotTo(headCf)
			elseif head.SetPrimaryPartCFrame and head.PrimaryPart then
				head:SetPrimaryPartCFrame(headCf)
			else
				for _, p in head:GetChildren() do
					if p:IsA("BasePart") then p.CFrame = headCf * p.CFrame end
				end
			end
			for _, desc in head:GetDescendants() do
				if desc:IsA("BasePart") then
					desc.Anchored = true
					desc.CanCollide = false
					desc.CanTouch = false
					desc.CanQuery = false
					desc.CastShadow = false
					if desc.Name == "canister" or desc.Name == "base" then
						desc.Color = Color3.fromRGB(200, 205, 210)
						desc.Material = Enum.Material.Metal
					end
				end
			end
			head.Parent = towerModel
		end

		addSpotlightHead(-2.2, "SpotlightLeft")
		addSpotlightHead(2.2, "SpotlightRight")
	else
		-- Fallback procedural lamp head if prefab not yet replicated
		createVisualPart(towerModel, "LampHeadLeft", Vector3.new(1.8, 2.2, 1.8),
			towerBasis * CFrame.new(-2.2, platformY + 1.2, -0.4), Color3.fromRGB(230, 230, 230), Enum.Material.Neon)
		createVisualPart(towerModel, "LampHeadRight", Vector3.new(1.8, 2.2, 1.8),
			towerBasis * CFrame.new(2.2, platformY + 1.2, -0.4), Color3.fromRGB(230, 230, 230), Enum.Material.Neon)
	end

	towerModel.Parent = parent
	return towerModel
end

local function buildCircuitStructures(testTrack: Model): Model
	local existing = testTrack:FindFirstChild("ClientTrackStructures")
	if existing then
		existing:Destroy()
	end

	local rootModel = Instance.new("Model")
	rootModel.Name = "ClientTrackStructures"

	local groundY = getPhysicalGroundTop(testTrack)

	-- 1. Build KDM Sponsor Arch
	local _arch, brandPanel = buildSponsorArch(rootModel, groundY)

	-- 2. Build 2 Lighting Towers
	local towersFolder = Instance.new("Folder")
	towersFolder.Name = "LightingTowers"
	towersFolder.Parent = rootModel

	local prefabsFolder = ReplicatedStorage:FindFirstChild("KDMTrackLightingPrefabs")
	if not prefabsFolder and ReplicatedStorage.WaitForChild then
		prefabsFolder = ReplicatedStorage:WaitForChild("KDMTrackLightingPrefabs", 2)
	end
	local spotlightPrefab = if prefabsFolder then prefabsFolder:FindFirstChild("OB_Spotlight_a") else nil

	for _, cfg in TOWER_CONFIGS do
		buildLightingTower(towersFolder, cfg, groundY, spotlightPrefab)
	end

	-- Count all parts
	local partCount = 0
	local meshPartCount = 0
	for _, desc in rootModel:GetDescendants() do
		if desc:IsA("BasePart") then
			partCount += 1
			if desc:IsA("MeshPart") then
				meshPartCount += 1
			end
		end
	end

	rootModel:SetAttribute("StructureArchCount", 1)
	rootModel:SetAttribute("StructureTowerCount", #TOWER_CONFIGS)
	rootModel:SetAttribute("StructurePartCount", partCount)
	rootModel:SetAttribute("StructureMeshPartCount", meshPartCount)
	rootModel.Parent = testTrack

	-- Attach PlayerGui SurfaceGuis with Adornee pointing to brandPanel
	attachArchBrandingGuis(brandPanel)

	print(string.format("[KDM:Structures] role=RACE track=Track01 arch=1 towers=%d totalParts=%d meshParts=%d spawned=true",
		#TOWER_CONFIGS, partCount, meshPartCount))

	return rootModel
end

function Controller.start()
	if stop then
		return
	end

	local connections = {}
	local activeStructuresModel = nil

	local function clearStructures()
		cleanupArchBrandingGuis()
		if activeStructuresModel then
			activeStructuresModel:Destroy()
			activeStructuresModel = nil
		end
		local prototype = Workspace:FindFirstChild("Prototype")
		if prototype then
			local testTrack = prototype:FindFirstChild("TestTrack")
			if testTrack then
				local orphaned = testTrack:FindFirstChild("ClientTrackStructures")
				if orphaned then
					orphaned:Destroy()
				end
			end
		end
	end

	local function rebindArchGuisIfNeeded()
		if activeStructuresModel and activeStructuresModel.Parent then
			local arch = activeStructuresModel:FindFirstChild("SponsorArch")
			local panel = if arch then arch:FindFirstChild("BrandPanel") else nil
			if panel then
				local pGui = if Players.LocalPlayer then Players.LocalPlayer:FindFirstChild("PlayerGui") else nil
				local hasFront = pGui and pGui:FindFirstChild("KDMArchFrontBranding")
				local hasBack = pGui and pGui:FindFirstChild("KDMArchBackBranding")
				if not hasFront or not hasBack then
					attachArchBrandingGuis(panel)
					print("[KDM:ArchBrand] revision=H1-D1-R4 stage=CHARACTER_SPAWN guisRetained=false rebind=SUCCESS")
				else
					print("[KDM:ArchBrand] revision=H1-D1-R4 stage=CHARACTER_SPAWN guisRetained=true frontInPlayerGui=true backInPlayerGui=true")
				end
			end
		end
	end

	local function evaluateTrack(testTrack: Instance?)
		local eligible, _ = isEligible(testTrack)
		if eligible and testTrack and testTrack:IsA("Model") then
			if not activeStructuresModel or activeStructuresModel.Parent ~= testTrack then
				clearStructures()
				activeStructuresModel = buildCircuitStructures(testTrack)
			else
				rebindArchGuisIfNeeded()
			end
		else
			clearStructures()
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
				clearStructures()
			end
		end))
	end

	-- Role change guard
	if Workspace.GetAttributeChangedSignal then
		table.insert(connections, Workspace:GetAttributeChangedSignal("KDMServerRole"):Connect(function()
			local currentRole = Workspace:GetAttribute("KDMServerRole")
			if currentRole ~= "RACE" then
				clearStructures()
			else
				local proto = Workspace:FindFirstChild("Prototype")
				if proto then
					evaluateTrack(proto:FindFirstChild("TestTrack"))
				end
			end
		end))
	end

	stop = function()
		clearStructures()
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

	if Players.LocalPlayer and Players.LocalPlayer.CharacterAdded then
		table.insert(connections, Players.LocalPlayer.CharacterAdded:Connect(function()
			task.defer(rebindArchGuisIfNeeded)
		end))
	end
end

function Controller.destroy()
	if stop then
		stop()
	end
end

-- Exported configurations for geometry and safety test harnesses
Controller.ARCH_CONFIG = table.freeze(ARCH_CONFIG)
Controller.TOWER_CONFIGS = table.freeze(TOWER_CONFIGS)
Controller._isEligible = isEligible
Controller.getArchGuis = function()
	return {
		Front = activeGuis[1],
		Back = activeGuis[2],
	}
end

return Controller
