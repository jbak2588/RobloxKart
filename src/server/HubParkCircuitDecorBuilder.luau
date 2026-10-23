-- Opt-in HUB presentation adapted from Figure-8 circuit structures and visual rails.
-- The RACE controllers remain unchanged. No lights, physics, triggers or update loops.
local Builder={}
-- A3 Lite: 75% of the existing 6-stud chevrons; retain the 20-stud
-- horizontal panel, branding and station count. Chevrons remain dominant.
local AD_RAIL_HEIGHT = 4.5
local AD_RAIL_LENGTH = 20
local ARCH_CONFIG = {
	name = "SponsorArch",
	-- HUB main straight, beyond the Pit exit.
	center = Vector3.new(270, 0, -137),
	tangent = Vector3.new(1, 0, 0),
	span = 116.0, -- 58 studs each side; preserve clear margins around the 68-stud road.
	clearanceHeight = 24.4, -- vertical clearance under top beam
	pillarHeight = 27.0,
	colors = {
		Structure = Color3.fromRGB(35, 38, 43),
		AccentCyan = Color3.fromRGB(0, 210, 215),
		BrandNavy = Color3.fromRGB(15, 20, 28),
		White = Color3.fromRGB(245, 245, 245),
	},
}

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

local function buildSponsorArch(parent: Instance, groundY: number): (Model, Part)
	local archModel = Instance.new("Model")
	archModel.Name = "SponsorArch"

	local forward = ARCH_CONFIG.tangent.Unit
	local right = Vector3.new(forward.Z, 0, -forward.X).Unit
	local up = Vector3.new(0, 1, 0)
	local archCenter = Vector3.new(ARCH_CONFIG.center.X, groundY, ARCH_CONFIG.center.Z)
	-- Use proper 3-arg CFrame.fromMatrix to guarantee right-handed basis (det = +1.0, avoiding GPU backface culling)
	local archBasis = CFrame.fromMatrix(archCenter, right, up)

	local halfSpan = ARCH_CONFIG.span * 0.5 -- HUB span
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

	-- 3. Top Horizontal Truss Beam (spans the widened HUB corridor)
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

local CHEVRON_SIGN_ASSETS = {
	Left = "rbxassetid://125863354300599", -- kdm_sign_chevron_left_1024x512.png
	Right = "rbxassetid://118109633914676", -- kdm_sign_chevron_right_1024x512.png
	LeftCompact = "rbxassetid://71424040130204", -- kdm_sign_chevron_left.png
	RightCompact = "rbxassetid://82868994615753", -- kdm_sign_chevron_right.png
}

local function attachChevronGuidance(railPart: Part, isLeftCurve: boolean)
	local assetId = if isLeftCurve then CHEVRON_SIGN_ASSETS.Left else CHEVRON_SIGN_ASSETS.Right
	railPart:SetAttribute("ChevronDirection", if isLeftCurve then "Left" else "Right")
	railPart:SetAttribute("ChevronAssetId", assetId)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "KDMChevronSurfaceGui_" .. face.Name
		gui.Face = face
		gui.CanvasSize = Vector2.new(1024, 512)
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.LightInfluence = 0
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = railPart

		local panel = Instance.new("Frame")
		panel.Name = "ChevronPanel"
		panel.Size = UDim2.fromScale(1, 1)
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.new(0.5, 0, 0.5, 0)
		panel.BackgroundColor3 = Color3.fromRGB(235, 238, 242)
		panel.BorderSizePixel = 0
		panel.ClipsDescendants = true
		panel.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = panel

		local image = Instance.new("ImageLabel")
		image.Name = "ChevronImage"
		image.Size = UDim2.fromScale(1, 1)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.new(0.5, 0, 0.5, 0)
		image.BackgroundTransparency = 1
		image.Image = assetId
		image.ScaleType = Enum.ScaleType.Stretch
		image.Parent = panel
	end
end

local function attachKdmBranding(railPart: Part, normalVector: Vector3)
			local inwardFace = if railPart.CFrame.RightVector:Dot(-normalVector) > 0 then Enum.NormalId.Right else Enum.NormalId.Left
			local gui = Instance.new("SurfaceGui")
			gui.Name = "KDMBrandSurfaceGui"
			gui.Face = inwardFace
			gui.CanvasSize = Vector2.new(512, 128)
			gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			gui.LightInfluence = 0
			gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			gui.Parent = railPart

			local panel = Instance.new("Frame")
			panel.Name = "BrandPanel"
			panel.Size = UDim2.new(0.82, 0, 0.72, 0)
			panel.AnchorPoint = Vector2.new(0.5, 0.5)
			panel.Position = UDim2.new(0.5, 0, 0.5, 0)
			panel.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
			panel.BorderSizePixel = 0
			panel.Parent = gui

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = panel

			local flag = Instance.new("Frame")
			flag.Name = "CheckerFlag"
			flag.Size = UDim2.new(0.20, 0, 0.74, 0)
			flag.AnchorPoint = Vector2.new(0, 0.5)
			flag.Position = UDim2.new(0.04, 0, 0.5, 0)
			flag.BackgroundTransparency = 1
			flag.BorderSizePixel = 0
			flag.Parent = panel

			local rows, cols = 3, 4
			for r = 0, rows - 1 do
				for c = 0, cols - 1 do
					local cell = Instance.new("Frame")
					cell.Name = string.format("Cell_%d_%d", r, c)
					cell.Size = UDim2.new(1 / cols, 0, 1 / rows, 0)
					cell.Position = UDim2.new(c / cols, 0, r / rows, 0)
					cell.BackgroundColor3 = if (r + c) % 2 == 0 then Color3.fromRGB(250, 250, 250) else Color3.fromRGB(18, 20, 24)
					cell.BorderSizePixel = 0
					cell.Parent = flag
				end
			end

			local label = Instance.new("TextLabel")
			label.Name = "KDMText"
			label.Size = UDim2.new(0.68, 0, 0.82, 0)
			label.AnchorPoint = Vector2.new(0, 0.5)
			label.Position = UDim2.new(0.28, 0, 0.5, 0)
			label.BackgroundTransparency = 1
			label.Text = "KDM"
			label.Font = Enum.Font.GothamBold
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
			label.TextScaled = true
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextYAlignment = Enum.TextYAlignment.Center
			label.Parent = panel
		end

function Builder.build(root,origin,layout,spotlightPrefab)
 local existing=root:FindFirstChild('ParkCircuitStructures');if existing then return existing end
 local folder=Instance.new('Model');folder.Name='ParkCircuitStructures'
 -- Build in local coordinates, then translate once into the existing HUB datum.
 local arch,panel=buildSponsorArch(folder,0)
 for _,face in {Enum.NormalId.Front,Enum.NormalId.Back}do
  local gui=Instance.new('SurfaceGui');gui.Name='KDMArchBranding';gui.Face=face
  gui.CanvasSize=Vector2.new(960,84);gui.LightInfluence=0;gui.Parent=panel
  local text=Instance.new('TextLabel');text.Size=UDim2.fromScale(1,1)
  text.BackgroundTransparency=1;text.Text='KDM  /  ROOKIE RACING PARK'
  text.Font=Enum.Font.GothamBold;text.TextScaled=true;text.TextColor3=ARCH_CONFIG.colors.White
  text.Parent=gui
 end
 local towers=Instance.new('Folder');towers.Name='LightingTowers';towers.Parent=folder
 for i,s in {{-320,-210,-30},{670,-450,90},{-765,-900,-90},{250,-1040,160}}do
  buildLightingTower(towers,{id='ParkTower'..i,pos=Vector3.new(s[1],0,s[2]),height=32,facingAngle=s[3]},0,spotlightPrefab)
 end
 local rails=Instance.new('Folder');rails.Name='VisualRails';rails.Parent=folder
 local points=layout.sample(layout.Segments);local distance,nextStation,count=0,100,0
 local chevronClusters,chevronParts=0,0
 for i=2,#points-1 do
  local a,b=points[i-1],points[i];distance+=math.sqrt((b.x-a.x)^2+(b.z-a.z)^2)
  if distance<nextStation then continue end
  nextStation=distance+360
  -- Straightaway rail panels follow actual centerline samples on straight sections.
  for j=i,math.min(i+12,#points-1),6 do
   local p=points[j]
   if p.section~='StartStraight' and not p.section:find('Link$')then continue end
   local right=Vector3.new(-p.fz,0,p.fx)
   local railHeight=AD_RAIL_HEIGHT
   for _,side in {-1,1}do
    -- Keep the complete pit apron and entry/exit unoccluded.
    if p.section=='StartStraight' and side==1 then continue end
    local center=Vector3.new(p.x,2.02+railHeight*0.5,p.z)+right*(side*(layout.RoadWidth/2+layout.KerbWidth+2.1))
    local frame=CFrame.lookAt(center,center+Vector3.new(p.fx,0,p.fz))
    count+=1
    local rail=createVisualPart(rails,'RailSegment'..count,Vector3.new(.5,railHeight,AD_RAIL_LENGTH),frame,
     if ((j-i)/6)%2==0 then Color3.fromRGB(180,65,65)else Color3.fromRGB(220,225,230),Enum.Material.SmoothPlastic)
    attachKdmBranding(rail, right * side)
   end
  end
 end
 -- Dedicated corner chevron sign clusters on the outer wall of every curve section.
 local sections,curSec,secStart={},nil,1
 for i=1,#points do
  if points[i].section~=curSec then
   if curSec then table.insert(sections,{name=curSec,first=secStart,last=i-1})end
   curSec=points[i].section;secStart=i
  end
 end
 table.insert(sections,{name=curSec,first=secStart,last=#points})
 for _,sec in sections do
  if sec.name~='StartStraight' and not sec.name:find('Link$')then
   local len=sec.last-sec.first+1
   local mid=math.floor(sec.first+len*0.45)
   local pMid=points[mid];local rightMid=Vector3.new(-pMid.fz,0,pMid.fx)
   local pMidNext=points[math.min(mid+4,#points)]
   -- right = (-fz, 0, fx) is the driver's left normal.
   -- Left turn (turnSide < 0, turning toward -right) -> outer wall across from turn is +right (outerSide = 1).
   -- Right turn (turnSide > 0, turning toward +right) -> outer wall across from turn is -right (outerSide = -1).
   local turnSide=pMidNext.fx*rightMid.X+pMidNext.fz*rightMid.Z
   local isLeftCurve=turnSide<0
   local outerSide=if isLeftCurve then 1 else -1
   local railHeight=6.0
   local step=5
   local indices={math.max(sec.first+1,mid-step),mid,math.min(sec.last-1,mid+step)}
   chevronClusters+=1
   for k,idx in indices do
    local p=points[idx];local right=Vector3.new(-p.fz,0,p.fx)
    local center=Vector3.new(p.x,2.02+railHeight*0.5,p.z)+right*(outerSide*(layout.RoadWidth/2+layout.KerbWidth+2.1))
    local frame=CFrame.lookAt(center,center+Vector3.new(p.fx,0,p.fz))
    count+=1;chevronParts+=1
    local rail=createVisualPart(rails,'RailSegment'..count,Vector3.new(.5,railHeight,12),frame,
     if k%2==1 then Color3.fromRGB(180,65,65)else Color3.fromRGB(220,225,230),Enum.Material.SmoothPlastic)
    attachChevronGuidance(rail,isLeftCurve)
   end
  end
 end
 for _,p in folder:GetDescendants()do if p:IsA('BasePart')then p.CFrame+=origin end end
 folder:SetAttribute('ArchCount',1);folder:SetAttribute('TowerCount',4);folder:SetAttribute('RailCount',count)
 folder:SetAttribute('ChevronClusterCount',chevronClusters);folder:SetAttribute('ChevronPartCount',chevronParts)
 folder.Parent=root;return folder
end
return Builder
