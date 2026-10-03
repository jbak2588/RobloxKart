-- lune run tests/garage_transition_validation.luau
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local count = 0
local function check(value, label) assert(value, label); count += 1 end
local function signal()
	local listeners = {}
	return { Connect = function(_, callback)
		local entry = {callback = callback, active = true}
		table.insert(listeners, entry)
		return { Disconnect = function() entry.active = false end }
	end, Fire = function(_, ...) for _, entry in listeners do if entry.active then entry.callback(...) end end end, count = function() local n=0; for _, entry in listeners do if entry.active then n+=1 end end; return n end }
end
local methods = {}
local safeSize = rb.Vector2.new(844, 390)
local cameraScreenSize = safeSize
local camera
local coreInsetY = 58
local function object(class, name)
	local props = { ClassName = class, Name = name or class, Size = rb.UDim2.fromScale(1, 1),
		Position = rb.UDim2.fromScale(0, 0), Visible = true, Enabled = true,
		Activated = signal(), OnClientEvent = signal(), CharacterAdded = signal(), ChildAdded = signal(), CharacterRemoving = signal(), Destroying = signal(), InputBegan = signal(), InputChanged = signal(), InputEnded = signal(), WindowFocusReleased = signal() }
	return setmetatable({ _p = props, _children = {}, _attrs = {}, _signals = {}, _properties = {} }, {
		__index = function(self, key)
			if methods[key] then return methods[key] end
			if key == "AbsoluteContentSize" and class == "UIListLayout" then
				local height, items = 0, 0
				for _, item in props.Parent:GetChildren() do
					if item.ClassName == "TextLabel" then height += item.AbsoluteSize.Y; items += 1 end
				end
				return rb.Vector2.new(props.Parent.AbsoluteSize.X,
					height + math.max(0, items - 1) * props.Padding.Offset)
			end
            if key == "AbsolutePosition" then
                if class=="ScreenGui" or not props.Parent then
                    if props.Name=="GarageTopHeader" or props.IgnoreGuiInset then
                        local device = if camera then (cameraScreenSize-camera.ViewportSize)*.5 else rb.Vector2.zero
                        return rb.Vector2.new(-device.X,-coreInsetY-device.Y)
                    end
                    return rb.Vector2.zero
                end
                local parent=props.Parent.AbsoluteSize
                local anchor=props.AnchorPoint or rb.Vector2.zero
                return props.Parent.AbsolutePosition+rb.Vector2.new(parent.X*props.Position.X.Scale+props.Position.X.Offset-self.AbsoluteSize.X*anchor.X,
                    parent.Y*props.Position.Y.Scale+props.Position.Y.Offset-self.AbsoluteSize.Y*anchor.Y)
            end
			if key == "AbsoluteSize" then
				if class == "ScreenGui" or not props.Parent then
                    if props.Name == "GarageTopHeader" then
                        if props.Enabled == false and self._lastCanvasSize then return self._lastCanvasSize end
                        rawset(self,"_lastCanvasSize",cameraScreenSize)
                        return cameraScreenSize
                    end
                    return safeSize
                end
				local parent = props.Parent.AbsoluteSize
				local size=rb.Vector2.new(parent.X * props.Size.X.Scale + props.Size.X.Offset,
					parent.Y * props.Size.Y.Scale + props.Size.Y.Offset)
				for _,child in self._children do
					if child.ClassName=="UISizeConstraint" then
						local min=child.MinSize or rb.Vector2.zero
						local max=child.MaxSize or rb.Vector2.new(math.huge,math.huge)
						size=rb.Vector2.new(math.clamp(size.X,min.X,max.X),math.clamp(size.Y,min.Y,max.Y))
					end
				end
				return size
			end
			if props[key] ~= nil then return props[key] end
			return self:FindFirstChild(key)
		end,
		__newindex = function(self, key, value)
			local old = props[key]
			if key == "Parent" then
				if old then local index = table.find(old._children, self); if index then table.remove(old._children, index) end end
				if value then table.insert(value._children, self) end
			end
			props[key] = value
			if class == "ScreenGui" and key == "ScreenInsets" then props.IgnoreGuiInset = value == rb.Enum.ScreenInsets.None end
			if class == "ScreenGui" and key == "IgnoreGuiInset" and value then props.ScreenInsets = rb.Enum.ScreenInsets.None end
			if old ~= value and self._properties[key] then self._properties[key]:Fire() end
			if old ~= value and key == "Size" and self._properties.AbsoluteSize then
				self._properties.AbsoluteSize:Fire()
			end
		end,
	})
end
function methods:FindFirstChild(name, recursive)
	for _, child in self._children do if child.Name == name then return child end end
	if recursive then
		for _, child in self._children do
			local found = child:FindFirstChild(name, true)
			if found then return found end
		end
	end
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name), name) end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants()
 local result={}; for _, item in self:GetChildren() do table.insert(result,item); for _, descendant in item:GetDescendants() do table.insert(result,descendant) end end; return result
end
function methods:HasAppearanceLoaded() return true end
function methods:PivotTo() end
function methods:GetBoundingBox() return rb.CFrame.new(0, -.4, 0), rb.Vector3.new(4, 6.5, 2) end
function methods:Clone()
 local copy = object(self.ClassName, self.Name)
 if self.ClassName=="Part" then copy.Size=self.Size; copy.CFrame=self.CFrame; copy.Transparency=self.Transparency end
 for _, item in self:GetChildren() do item:Clone().Parent = copy end
 return copy
end
function methods:IsA(name) return self.ClassName == name or (name == "BasePart" and self.ClassName == "Part") end
function methods:Destroy() self.Destroying:Fire(); self.Parent = nil end
function methods:GetAttribute(name) return self._attrs[name] end
function methods:SetAttribute(name, value)
	local old = self._attrs[name]
	self._attrs[name] = value
	if old ~= value and self._signals[name] then self._signals[name]:Fire() end
end
function methods:GetAttributeChangedSignal(name)
	if not self._signals[name] then self._signals[name] = signal() end
	return self._signals[name]
end
function methods:GetPropertyChangedSignal(name)
	if not self._properties[name] then self._properties[name] = signal() end
	return self._properties[name]
end
function methods:FireServer(...) self.lastFire = { ... }; self.fireCount = (self.fireCount or 0) + 1 end
local function child(parent, class, name) local item = object(class, name); item.Parent = parent; return item end
local player = object("Player", "LocalPlayer")
player.UserId = 1; player.DisplayName = "Local Racer"
player:SetAttribute("RaceState", "GARAGE")
player:SetAttribute("KDMRoutePending", "")
player.Character = object("Model", "Character")
local head = child(player.Character, "Part", "Head"); head.Size = rb.Vector3.new(4,6.5,2); head.CFrame = rb.CFrame.new(0,-.4,0); head.Transparency = 0
local playerGui = child(player, "PlayerGui", "PlayerGui")
local players = { player }
local playersService = { LocalPlayer = player, PlayerAdded = signal(), PlayerRemoving = signal(),
	GetPlayers = function() return players end }
local replicated = object("ReplicatedStorage")
local shared = child(replicated, "Folder", "Shared")
local remote = child(replicated, "RemoteEvent", "GarageControl")
local populationRemote = child(replicated, "RemoteEvent", "KDMPopulationStatus")
child(replicated, "RemoteEvent", "ControlsTutorialPreference")
camera = object("Camera"); camera.ViewportSize = rb.Vector2.new(844, 390)
local workspace = object("Workspace"); workspace.CurrentCamera = camera
local input = object("UserInputService"); input.TouchEnabled = true
local guiService = object("GuiService")
guiService.TopbarInset = rb.Rect.new(208,0,770,48)
function guiService:GetGuiInset() return rb.Vector2.new(0,coreInsetY), rb.Vector2.zero end
local runService = {RenderStepped = signal()}
local visualTweens={}
local tweenService={Create=function(_,target,info,goal)
 local tween={cancelled=false,Play=function() end,Cancel=function(self) self.cancelled=true end}
 table.insert(visualTweens,tween); return tween
end}
local services = { Players = playersService, ReplicatedStorage = replicated, Workspace = workspace,
	UserInputService = input, GuiService = guiService, RunService = runService, TweenService=tweenService, ContentProvider={} }
local client = object("Folder", "Client")
for _, name in { "TrackMapRenderer", "GaragePresence", "KartInputController", "MobileTutorialView", "GarageTexturePreload" } do
	child(client, "ModuleScript", name)
end
for _, name in { "DriverCatalog", "KartCatalog", "TrackCatalog", "TrackGeometry", "KartVisualFactory",
	"KartPreviewFraming", "DriverAppearance" } do child(shared, "ModuleScript", name) end
local modules = {
	DriverCatalog = { Order = { "Driver01", "Driver02" }, Entries = { Driver01 = { DisplayName = "Driver" }, Driver02 = {DisplayName = "Driver Two"} } },
	KartCatalog = { Order = { "Kart01", "Kart02" }, Entries = { Kart01 = { DisplayName = "Kart" }, Kart02 = {DisplayName = "Kart Two"} } },
	TrackCatalog = { Order = { "Track01" }, Entries = { Track01 = { Id = "Track01", DisplayName = "Practice",
		MatchType = "SOLO_PRACTICE", GeometryId = "PracticeCircuitV1" } },
		previewKey = function() return "Track01" end, capabilityLabel = function() return "PRACTICE" end },
	TrackGeometry = { getDefinition = function() return {} end },
	KartVisualFactory = { createVisual = function()
        local model=object("Model"); local part=child(model,"Part","Body"); part.Size=rb.Vector3.new(8,2,10); part.CFrame=rb.CFrame.identity; part.Transparency=0; return model
    end },
	KartPreviewFraming = luau.load(fs.readFile("src/shared/KartPreviewFraming.luau"),{environment={Vector3=rb.Vector3,CFrame=rb.CFrame}})(),
	DriverAppearance = { applyHairStyle = function() end, applyToCharacter = function() end },
	TrackMapRenderer = { create = function() return { destroy = function() end } end },
	GaragePresence = luau.load(fs.readFile("src/client/GaragePresence.luau"))(),
	GarageTexturePreload = luau.load(fs.readFile("src/client/GarageTexturePreload.luau"),{environment={Instance=rb.Instance}})(),
	KartInputController = { isTouchPreferred = function() return true end },
	MobileTutorialView = { create = function() return { open = function() end, close = function() end } end },
}
local environment = { script = { Parent = client }, Instance = { new = object }, UDim2 = rb.UDim2,
	UDim = rb.UDim, Vector2 = rb.Vector2, Vector3 = rb.Vector3, Color3 = rb.Color3, CFrame = rb.CFrame,
 ColorSequence=rb.ColorSequence,NumberSequence=rb.NumberSequence,NumberSequenceKeypoint=rb.NumberSequenceKeypoint,TweenInfo={new=function() return {} end},
	Enum = rb.Enum, game = { PlaceVersion = 1, GetService = function(_, name) return assert(services[name], name) end },
	require = function(module) return assert(modules[module.Name], module.Name) end,
	task = { delay = function() end, defer = function(callback) callback() end, spawn = function() end } }
local geometrySnapshots = {}
local function captureGeometry(tag)
 local snapshot={tag=tag,objects={}}
 for _,name in {"SelectionPreview","TrackPreview","ServerPresence","ControlsHint","PreviousChoice","NextChoice","GarageTitle","GarageStep","GarageChoice"} do
  local item=playerGui:FindFirstChild(name,true)
  snapshot.objects[name]={item.AbsolutePosition.X,item.AbsolutePosition.Y,item.AbsoluteSize.X,item.AbsoluteSize.Y}
 end
 for _,item in playerGui:FindFirstChild("RobloxKartGarage"):FindFirstChild("Frame"):GetChildren() do
  if item.ClassName=="TextButton" then snapshot.objects["button:"..item.Text]={item.AbsolutePosition.X,item.AbsolutePosition.Y,item.AbsoluteSize.X,item.AbsoluteSize.Y} end
 end
 table.insert(geometrySnapshots,snapshot)
end
local controller = luau.load(fs.readFile(require("@lune/process").args[1] or "src/client/GarageUiController.luau"), { environment = environment })()
controller.start()
local gui = playerGui.RobloxKartGarage
local backdrop = gui:FindFirstChild("Frame")
local shell=backdrop.PreviewVisualShell
local visualInstances=1+#shell:GetDescendants()+1+#backdrop.ReadySummaryCard:GetDescendants()
for _,item in playerGui:GetDescendants() do
 if (item.Name=="ArcadeStroke" or item.Name=="ArcadeDepth") and item.Parent~=shell and item.Parent~=backdrop.ReadySummaryCard then visualInstances+=1 end
end
check(visualInstances==30,"bounded visual layer: 30 native UI instances across Phase 1C-A/B")
local backStyle,primaryStyle
for _,item in backdrop:GetChildren() do if item.Text=="BACK" then backStyle=item elseif item.Text=="SELECT" then primaryStyle=item end end
check(backStyle.BackgroundColor3~=primaryStyle.BackgroundColor3 and backStyle.AutoButtonColor and primaryStyle.AutoButtonColor,
 "primary and secondary chrome differ with native hover/press feedback")
local presencePanel = backdrop.ServerPresence
local list = presencePanel.OnlineList
local populationLabel = playerGui:FindFirstChild("KDMPopulation",true)
populationRemote.OnClientEvent:Fire({ online = 7, lobby = 3, inRace = 4, stale = false })
check(populationLabel.Text == "KDM ONLINE 7 • LOBBY 3 • IN RACE 4", "experience counts remain separate from local list")
populationRemote.OnClientEvent:Fire({ stale = true })
check(populationLabel.Text == "KDM STATUS UPDATING...", "failed population query never shows zero")
local function rows()
	local found = {}
	for _, item in list:GetChildren() do if item.ClassName == "TextLabel" then table.insert(found, item) end end
	return found
end
check(list.ClassName == "ScrollingFrame" and list.ScrollingDirection == rb.Enum.ScrollingDirection.Y
	and presencePanel.Size.Y.Offset == backdrop.SelectionPreview.AbsoluteSize.Y and list.AbsoluteSize.Y == presencePanel.AbsoluteSize.Y-32
	and list.AutomaticCanvasSize == rb.Enum.AutomaticSize.None and list.ClipsDescendants,
	"one mobile name receives a complete explicit viewport and manual canvas")
local function checkPopulationRows(expected)
	local contentHeight = modules.GaragePresence.canvasHeight(expected, 16, 2)
	check(#rows() == expected and list.CanvasSize.Y.Offset == contentHeight,
		"local list contains exactly " .. expected .. " names without blank rows")
	if contentHeight <= list.AbsoluteSize.Y then
		check(list.ScrollBarThickness == 0 and presencePanel.Size.Y.Offset == backdrop.SelectionPreview.AbsoluteSize.Y,
			tostring(expected) .. " names visible in stage-height sidebar without scrolling")
	else
		check(contentHeight > list.AbsoluteSize.Y and list.ScrollBarThickness > 0 and list.ScrollingEnabled ~= false,
			tostring(expected) .. " names retain vertical scrolling")
	end
end
checkPopulationRows(1)
local function addPlayer(index)
	local other = object("Player", "Player" .. index)
	other.UserId = index; other.DisplayName = "Racer " .. index
	other:SetAttribute("RaceState", "GARAGE")
	table.insert(players, other)
	playersService.PlayerAdded:Fire(other)
	return other
end
local second = addPlayer(2)
checkPopulationRows(2)
local third = addPlayer(3)
checkPopulationRows(3)
check(#rows() == 3 and presencePanel:FindFirstChild("TextLabel").Text == "LOBBY 3"
	and list.CanvasSize.Y.Offset <= list.AbsoluteSize.Y,
	"three Lobby names are visible without scrolling")
addPlayer(4); checkPopulationRows(4)
addPlayer(5); checkPopulationRows(5)
for index = 6, 10 do addPlayer(index) end
checkPopulationRows(10)
check(#rows() == 10 and list.CanvasSize.Y.Offset == modules.GaragePresence.canvasHeight(10, 16, 2)
	and presencePanel.Size.Y.Offset == backdrop.SelectionPreview.AbsoluteSize.Y, "ten players fit fixed mobile panel with scroll canvas")
for index = 11, 50 do addPlayer(index) end
checkPopulationRows(50)
check(#rows() == 50 and list.CanvasSize.Y.Offset == modules.GaragePresence.canvasHeight(50, 16, 2)
	and presencePanel.Size.Y.Offset == backdrop.SelectionPreview.AbsoluteSize.Y, "50 players remain represented without expanding panel")
list.CanvasPosition = rb.Vector2.new(0, 120)
third:SetAttribute("RaceState", "RACING")
check(#rows() == 50 and list.CanvasPosition.Y == 120,
	"RaceState update retains presence rows and scroll position")
local index = table.find(players, second); table.remove(players, index)
playersService.PlayerRemoving:Fire(second)
check(#rows() == 49 and list:FindFirstChild("Player2") == nil and list.CanvasPosition.Y == 120
	and list.CanvasSize.Y.Offset == modules.GaragePresence.canvasHeight(49, 16, 2),
	"PlayerRemoving deletes only departed row, retains scroll and updates canvas")
local replacement = addPlayer(51)
check(#rows() == 50 and list.Player51.Text == replacement.DisplayName and list.CanvasPosition.Y == 120,
	"join adds one current name without jumping scroll position")
safeSize = rb.Vector2.new(1280, 720); input.TouchEnabled = false
camera.ViewportSize = safeSize
cameraScreenSize = camera.ViewportSize
guiService.TopbarInset = rb.Rect.new(208,0,cameraScreenSize.X-74,48)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
check(presencePanel.Size.Y.Offset == backdrop.SelectionPreview.AbsoluteSize.Y and presencePanel.Size.X.Offset==220
	and list.CanvasSize.Y.Offset == modules.GaragePresence.canvasHeight(50, 20, 2),
	"desktop stage-height sidebar represents all players in scroll canvas")
check(string.find(list.Player3.Text, "RACING", 1, true) ~= nil,
	"desktop presence updates the changed racer status")
safeSize = rb.Vector2.new(844, 390); input.TouchEnabled = true
camera.ViewportSize = safeSize
cameraScreenSize = camera.ViewportSize
guiService.TopbarInset = rb.Rect.new(208,0,cameraScreenSize.X-74,48)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
local selectButton = backdrop:FindFirstChild("TextButton", true)
local function bounds(item)
	local position = item.AbsolutePosition - backdrop.AbsolutePosition
	return { x = position.X, y = position.Y, w = item.AbsoluteSize.X, h = item.AbsoluteSize.Y }
end
local function verifyPreviewLimits(maximum,tag)
    local limits=0
    for _,panel in backdrop:GetChildren() do
        for _,child in panel:GetChildren() do if child.ClassName=="UISizeConstraint" then
            limits+=1
            check(child.MaxSize==maximum,"actual preview constraint "..tag)
        end end
    end
    check(limits==3,"preview, loading and map constraints checked "..tag)
end
local function intersects(a, b)
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
local function verifyShowroom(step, tag)
 local preview=backdrop.SelectionPreview
 local world=preview:FindFirstChild("PreviewWorld")
 check(backdrop.ReadySummaryCard.Visible==(step==4),"Ready card step visibility "..tag)
 if step<=2 then
  local podium=assert(world:FindFirstChild("ShowcasePodium"))
  local model=assert(world:FindFirstChild(if step==1 then "PreviewDriver" else "PreviewKart"))
  check(podium.Parent==world and not model:FindFirstChild("ShowcasePodium",true),"podium isolated from fitted model "..tag)
  check(#podium:GetChildren()==2,"two bounded podium parts "..tag)
  local box,size=model:GetBoundingBox()
  for _,part in podium:GetChildren() do
   check(part.Shape==rb.Enum.PartType.Cylinder and part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow,"preview-only podium flags "..tag)
   check(part.CFrame.Position.Y+part.Size.X*.5<box.Position.Y-size.Y*.5,"podium top below model "..tag)
  end
  local frame=preview.CurrentCamera.CFrame
  podium.Parent=nil
  preview:GetPropertyChangedSignal("AbsoluteSize"):Fire()
  check((frame.Position-preview.CurrentCamera.CFrame.Position).Magnitude<.00001 and (frame.LookVector-preview.CurrentCamera.CFrame.LookVector).Magnitude<.00001,"camera fit equal without podium "..tag)
  podium.Parent=world
  preview:GetPropertyChangedSignal("AbsoluteSize"):Fire()
  check((frame.Position-preview.CurrentCamera.CFrame.Position).Magnitude<.00001 and (frame.LookVector-preview.CurrentCamera.CFrame.LookVector).Magnitude<.00001,"camera fit equal with podium "..tag)
 else
  check(not world,"no podium world on Track/Ready "..tag)
 end
 if step==4 then
  local card=bounds(backdrop.ReadySummaryCard)
  for _,item in backdrop:GetChildren() do
   if (item.ClassName=="TextButton" or item.Name=="ServerPresence" or item.Name=="ControlsHint") and item.Visible then
    local rect=bounds(item)
    check(not intersects(card,rect),"Ready card clears "..item.Name.." "..tag.." card="..card.x..","..card.y..","..card.w..","..card.h.." other="..rect.x..","..rect.y..","..rect.w..","..rect.h)
   end
  end
 end
end
-- Screen width/height, approved aggregate width, local Lobby width, visible rows.
local resolutions = { {1600,739,560,140,4}, {1280,720,560,108,4},
	{844,390,511,65,4}, {932,430,511,65,4,120,79},
	-- Notch + home-indicator stress: old 72px gutter breakpoint chose one row.
	{844,390,455,56,4,120,79}, {390,844,326,54,4}, {390,600,326,54,1} }
for step = 1, 4 do
	for _, resolution in resolutions do
		-- Already-safe parent bounds: ordinary margins or larger notch/home insets.
		safeSize = rb.Vector2.new(resolution[1] - (resolution[6] or 32), resolution[2] - (resolution[7] or 58))
		input.TouchEnabled = true
		camera.ViewportSize = rb.Vector2.new(resolution[1], resolution[2])
		cameraScreenSize = camera.ViewportSize
guiService.TopbarInset = rb.Rect.new(208,0,cameraScreenSize.X-74,48)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
		local tag = string.format("%dx%d step %d", resolution[1], resolution[2], step)
        captureGeometry(tag)
        verifyShowroom(step,tag)
        local shell=backdrop.PreviewVisualShell
        local target=if step==3 then backdrop.TrackPreview else backdrop.SelectionPreview
        check(shell.Position==target.Position and shell.Size==target.Size,"shell inherits exact preview bounds "..tag)
        check(shell.Active==false and shell.Visible==(step<=3),"non-interactive stage shell follows step "..tag)
        check(not shell.ShowcasePlatform.Visible and shell.ShowcaseHalo.Visible==(step<=2) and shell.ZIndex<backdrop.SelectionPreview.ZIndex,"3D podium replaces pill; halo behind model, Driver/Kart only "..tag)
        check(#shell.CheckerAccent:GetChildren()==8,"one bounded reusable checker "..tag)
        local preview = backdrop.SelectionPreview
        verifyPreviewLimits(rb.Vector2.new(800,410),"mobile restores original limit "..tag)
        local rectangle = bounds(preview)
        local stage = if step==3 then backdrop.TrackPreview else preview
        rectangle = bounds(stage)
        local safeStatus = bounds(populationLabel)
        check(backdrop.GarageStep.Parent==backdrop and populationLabel.Parent==backdrop,
            "only title may leave CoreUISafeInsets " .. tag)
        if step<=3 and not resolution[6] and resolution[1]>=844 then
            check(rectangle.h >= (if resolution[1]>=1280 then 330 else 165),
                "R1 increases actual stage height over Phase 1B " .. tag)
        end
        if step<=3 then
            check(rectangle.y+rectangle.h<bounds(backdrop.GarageChoice).y,"preview ends before name " .. tag)
        end
        check(rectangle.w/rectangle.h <= 2.67 and rectangle.h > math.min(safeSize.Y*.30,170),
            "visual stage taller than previous production geometry " .. tag)
        check(rectangle.x>=0 and rectangle.y>=0 and rectangle.x+rectangle.w<=safeSize.X and rectangle.y+rectangle.h<=safeSize.Y,
            "visual stage inside safe area " .. tag)
        check(backdrop.GarageDetail.Visible == (step>=3) and (step>=3 or backdrop.GarageDetail.Text==""),
            "Driver/Kart developer descriptions removed " .. tag)
        check(preview.Visible == (step<=2) and backdrop.TrackPreview.Visible == (step==3), "step visibility preserved " .. tag)
        if step<=2 then
            local framing=preview.CurrentCamera
            local model=if step==1 then preview.PreviewWorld.PreviewDriver else preview.PreviewWorld.PreviewKart
            local box,size=model:GetBoundingBox()
            if step==1 then
                local maxY=0
                for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
                    local point=framing.CFrame:PointToObjectSpace(box:PointToWorldSpace(size*rb.Vector3.new(x,y,z)*.5))
                    check(point.Z<0,"driver corners in front of camera " .. tag)
                    local tangent=math.tan(math.rad(framing.FieldOfView*.5))
                    maxY=math.max(maxY,math.abs(point.Y)/(-point.Z*tangent))
                    check(math.abs(point.X)/(-point.Z*tangent*rectangle.w/rectangle.h)<=.90,"driver hair/body unclipped " .. tag)
                end end end
                check(maxY>=.81 and maxY<=.90,"driver framing fills taller stage " .. tag .. " " .. maxY)
            end
        end
        for _, control in {backdrop.PreviousChoice,backdrop.NextChoice,presencePanel,populationLabel,backdrop.GarageChoice} do
            check((step==4 and control==backdrop.GarageChoice) or not intersects(rectangle,bounds(control)),"visible stage clears arrows/Lobby/header/name " .. tag)
        end
        for _, control in backdrop:GetChildren() do
            if control.ClassName=="TextButton" or (control.ClassName=="TextLabel" and string.sub(control.Text or "",1,8)=="BUILD PV") then
                check(not intersects(rectangle,bounds(control)),"stage clears bottom controls/build " .. tag)
            end
        end
		local status = bounds(populationLabel)
        if step==1 and ((resolution[1]==1600) or (resolution[1]==844 and not resolution[6])) then
            local title=gui.Parent:FindFirstChild("GarageTitle",true)
            print(string.format("GEOMETRY %dx%d: titleTop=%s stage=%sx%s previewTop=%s",resolution[1],resolution[2],title.Position.Y.Offset,rectangle.w,rectangle.h,rectangle.y))
        end
		local lobby = bounds(presencePanel)
		check(lobby.x >= 0 and lobby.y >= 0 and lobby.x + lobby.w <= safeSize.X
			and lobby.y + lobby.h <= safeSize.Y, "local Lobby stays inside Core UI safe bounds " .. tag)
		local landscape=safeSize.X>safeSize.Y and step<=3
		local visibleRows = if landscape then math.floor((list.AbsoluteSize.Y+2)/18) else resolution[5]
		check((if landscape then presencePanel.Size.X.Offset>=120 and presencePanel.Size.X.Offset<=150
			and math.abs(lobby.y-rectangle.y)<.01 and math.abs(lobby.h-rectangle.h)<.01
			and list.AbsoluteSize.Y==rectangle.h-32 else presencePanel.Size.X.Offset == resolution[4]
			and presencePanel.Size.Y.Offset == 30 + visibleRows * 18
			and list.AbsoluteSize.Y == visibleRows * 16 + (visibleRows - 1) * 2),
			tostring(visibleRows) .. " local Lobby rows visible " .. tag)
		check(list.CanvasPosition.Y == 120 and #rows() == 50
			and list.CanvasSize.Y.Offset == modules.GaragePresence.canvasHeight(50, 16, 2),
			"resize preserves names, canvas and scroll position " .. tag)
		local allPlayers = players
		for _, lobbyCount in {1, 2, 3, 4, 5, 10, 50} do
			players = {}
			for i = 1, lobbyCount do table.insert(players, allPlayers[i]) end
			player:GetAttributeChangedSignal("ReadyOrder"):Fire()
			local expectedRows = math.min(lobbyCount, visibleRows)
			local viewportHeight = if landscape then rectangle.h-32 else modules.GaragePresence.canvasHeight(expectedRows, 16, 2)
			local canvasHeight = modules.GaragePresence.canvasHeight(lobbyCount, 16, 2)
			check(#rows() == lobbyCount and list.AbsoluteSize.Y == viewportHeight
				and list.CanvasSize.Y.Offset == canvasHeight
				and list.UIListLayout.AbsoluteContentSize.Y == canvasHeight
				and presencePanel.Size.Y.Offset == 32 + viewportHeight,
				"count-derived viewport/canvas " .. lobbyCount .. " " .. tag)
			check(list.ScrollBarThickness == (if lobbyCount > visibleRows then 4 else 0),
				"scrollbar only consumes name width when needed " .. lobbyCount .. " " .. tag)
			for _, row in rows() do
				check(row.AbsoluteSize.X == list.AbsoluteSize.X - (if lobbyCount > visibleRows then 6 else 0)
					and row.TextTruncate == rb.Enum.TextTruncate.AtEnd,
					"name fits panel and clears scrollbar " .. lobbyCount .. " " .. tag)
			end
			check((if landscape then viewportHeight>=expectedRows*16+math.max(0,expectedRows-1)*2 else viewportHeight == expectedRows * 16 + (expectedRows - 1) * 2),
				"last visible row fully inside clipped viewport " .. lobbyCount .. " " .. tag)
			if lobbyCount <= visibleRows then
				check(not list.CanvasPosition or list.CanvasPosition.Y == 0,
					"shrinking list removes obsolete scroll offset " .. lobbyCount .. " " .. tag)
			end
		end
		players = allPlayers
		player:GetAttributeChangedSignal("ReadyOrder"):Fire()
		list.CanvasPosition = rb.Vector2.new(0, 120)
		check(status.w == resolution[3], "approved aggregate width preserved " .. tag)
		check(gui.ScreenInsets == rb.Enum.ScreenInsets.CoreUISafeInsets and (populationLabel.Parent == backdrop or populationLabel.Parent.Name == "GarageTopHeader"),
			"safe-area mobile header " .. tag)
		check(status.x >= 0 and status.y >= 0 and status.x + status.w <= safeSize.X
			and status.y + status.h <= safeSize.Y, "status stays below Core UI and within safe bounds " .. tag)
		check(math.abs(status.x + status.w * 0.5 - safeSize.X * 0.5) < 0.01,
			"status centered " .. tag)
		local heading = bounds(gui.Parent:FindFirstChild("GarageStep",true))
        local title=gui.Parent:FindFirstChild("GarageTitle",true)
        check(not intersects(bounds(title),heading) and not intersects(bounds(title),status), "all header lines separated " .. tag)
        if resolution[1]==390 then check(title.Parent==backdrop,"portrait header fallback " .. tag)
        else
            check(title.Parent.Name=="GarageTopHeader", "wide header uses vacant Core UI band " .. tag)
            local rectangle=bounds(title)
            check(not title.Active and not title.Selectable,"title cannot capture Core UI input")
            local physical = title.AbsolutePosition-title.Parent.AbsolutePosition
            local deviceOrigin = (cameraScreenSize-camera.ViewportSize)*.5
            check(math.abs(physical.Y+title.AbsoluteSize.Y*.5-(guiService.TopbarInset.Min.Y+guiService.TopbarInset.Max.Y)*.5-deviceOrigin.Y)<=.01,
                "title center follows TopbarInset center")
            check(physical.Y>=0 and physical.Y+rectangle.h<=cameraScreenSize.Y,
                "top header stays inside full viewport")
            check(math.abs(physical.X+rectangle.w*.5-cameraScreenSize.X*.5)<=1,"header centered across different GUI origins " .. tag)
            check(physical.X>=guiService.TopbarInset.Min.X+deviceOrigin.X+8 and physical.X+rectangle.w<=guiService.TopbarInset.Max.X+deviceOrigin.X-8,
                "header fits free Core UI band " .. tag)
        end
		check(status.y >= heading.y + heading.h + 2, "status below step header " .. tag)
		for _, item in backdrop:GetChildren() do
			if item == backdrop.PreviousChoice or item == backdrop.NextChoice
				or item == backdrop.SelectionPreview or item == backdrop.TrackPreview
				or item == presencePanel
				or item.ClassName == "TextButton" or item == backdrop.GarageStep
				or (item.ClassName == "TextLabel" and string.sub(item.Text or "", 1, 8) == "BUILD PV") then
					check(not item.Visible or not intersects(status, bounds(item)), "status clears " .. item.Name .. " " .. tag)
				if item ~= presencePanel then
						check(not item.Visible or not intersects(lobby, bounds(item)), "local Lobby clears " .. item.Name .. " " .. tag)
				end
			end
			if item.ClassName == "TextLabel" and item ~= populationLabel and item.Visible then
				check(not intersects(lobby, bounds(item)), "local Lobby clears Garage text " .. item.Name .. " " .. tag)
			end
		end
		for _, snapshot in { { online = 3, lobby = 2, inRace = 1 }, { online = 50, lobby = 38, inRace = 12 } } do
			populationRemote.OnClientEvent:Fire(snapshot)
			local expected = string.format("KDM ONLINE %d%sLOBBY %d • IN RACE %d", snapshot.online,
				if resolution[1] == 390 then "\n" else " • ", snapshot.lobby, snapshot.inRace)
			check(populationLabel.Text == expected and populationLabel.TextSize == 14
				and populationLabel.TextScaled == false, "readable counts without shrinking " .. tag)
			local lines = string.split(populationLabel.Text, "\n")
			-- Conservative glyph budget, not a Roblox font-rendering claim.
			for _, line in lines do
				check(utf8.len(line) * populationLabel.TextSize * 0.75 <= status.w,
					"long count text has width budget " .. tag)
			end
			check(#lines * 18 <= status.h, "all count lines have height budget " .. tag)
		end
		populationRemote.OnClientEvent:Fire({ stale = true })
		check(populationLabel.Text == "KDM STATUS UPDATING...", "stale message retained " .. tag)
		backdrop.RaceInvite.Visible = true
		check(not populationLabel.Visible, "mobile invite modal hides status " .. tag)
		backdrop.RaceInvite.Visible = false
		check(populationLabel.Visible, "status restored after modal " .. tag)
	end
	-- Desktop restores the original right-side panel and the latest snapshot.
	input.TouchEnabled = false; safeSize = rb.Vector2.new(1280, 720); camera.ViewportSize = safeSize
	cameraScreenSize = camera.ViewportSize
guiService.TopbarInset = rb.Rect.new(208,0,cameraScreenSize.X-74,48)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
	populationRemote.OnClientEvent:Fire({ online = 50, lobby = 38, inRace = 12 })
	check(populationLabel.Parent == presencePanel and populationLabel.TextSize == 12
		and populationLabel.Text == "KDM ONLINE 50\nLOBBY 38 • IN RACE 12", "desktop restored step " .. step)
    local desktopPreview=bounds(backdrop.SelectionPreview)
    check(desktopPreview.h>720*.32 and desktopPreview.w<=720*.44*2.65,
        "desktop tall stage on each step " .. step)
    for _, control in {backdrop.PreviousChoice,backdrop.NextChoice,presencePanel} do
        check(not intersects(desktopPreview,bounds(control)),"desktop stage clears arrows and Lobby")
    end
	-- SELECT is the only button whose text changes neither with the step nor the track.
	for _, item in backdrop:GetChildren() do if item.Text == "SELECT" then selectButton = item end end
	if step < 4 then selectButton.Activated:Fire() end
end
local roomUiSource = fs.readFile("src/client/MatchRoomUiController.luau")
local roomDisplayOrder = tonumber(string.match(roomUiSource, "gui.DisplayOrder = (%d+)"))
check(roomDisplayOrder and roomDisplayOrder > gui.DisplayOrder, "Room modal remains above Garage population GUI")
safeSize = rb.Vector2.new(812, 332); input.TouchEnabled = true
camera.ViewportSize = rb.Vector2.new(844, 390); cameraScreenSize = camera.ViewportSize
guiService.TopbarInset = rb.Rect.new(208,0,cameraScreenSize.X-74,48)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
local ready
for _, item in backdrop:GetChildren() do if item.Text == "READY" then ready = item end end
check(ready and ready.Visible, "Garage reaches Solo READY step")
ready.Activated:Fire()
check(remote.fireCount == 1 and gui.RouteTransition.Visible and gui.RouteTransition.Message.Text == "JOINING RACE..."
	and not ready.Active, "READY gives immediate transition feedback and locks controls")
ready.Activated:Fire()
check(remote.fireCount == 1, "pending launch rejects repeated READY")
player:SetAttribute("KDMRoutePending", "RACE_LAUNCH")
check(gui.RouteTransition.Visible, "server route attribute owns ongoing launch overlay")
player:SetAttribute("KDMRoutePending", "")
remote.OnClientEvent:Fire("RouteLaunchFailed")
check(not gui.RouteTransition.Visible and ready.Active, "launch failure restores Garage controls")
-- Re-enter Driver after the full transition flow; exercise actual desktop resolutions.
player:SetAttribute("RaceState", "PRE_RACE")
player:SetAttribute("RaceState", "GARAGE")
for _, dimensions in {{1366,768}, {1600,900}, {1920,1080}, {2048,1035}, {2560,1080}, {2560,1440}} do
 input.TouchEnabled = false
 safeSize = rb.Vector2.new(dimensions[1], dimensions[2])
 camera.ViewportSize = safeSize
 cameraScreenSize = camera.ViewportSize
guiService.TopbarInset = rb.Rect.new(208,0,cameraScreenSize.X-74,48)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
 player:SetAttribute("RaceState", "PRE_RACE")
 player:SetAttribute("RaceState", "GARAGE")
 for desktopStep=1,4 do
  local tag=string.format("%dx%d step %d",dimensions[1],dimensions[2],desktopStep)
  captureGeometry(tag)
  verifyShowroom(desktopStep,tag)
  local shell=backdrop.PreviewVisualShell
  local target=if desktopStep==3 then backdrop.TrackPreview else backdrop.SelectionPreview
  check(shell.Position==target.Position and shell.Size==target.Size,"desktop shell inherits exact bounds "..tag)
  local rectangle=bounds(if desktopStep==3 then backdrop.TrackPreview else backdrop.SelectionPreview)
  verifyPreviewLimits(rb.Vector2.new(1100,500),"desktop enlarged limit "..tag)
  local name=bounds(backdrop.GarageChoice)
  local detail=bounds(backdrop.GarageDetail)
  local action=bounds(if desktopStep==4 then ready else selectButton)
  local sidebar=bounds(presencePanel)
  local controls=bounds(backdrop.ControlsHint)
  local groupWidth=sidebar.x+sidebar.w-rectangle.x
  local groupCenter=rectangle.x+groupWidth*.5
  local contentTop=if desktopStep==4 then name.y else rectangle.y
  local contentBottom=action.y+action.h
  local contentCenter=(contentTop+contentBottom)*.5
  check(rectangle.h>=330 and rectangle.h<=500 and rectangle.w<=1100
   and math.abs(rectangle.w-rectangle.h*2.2)<=2,"bounded desktop stage (pixel rounding) "..tag)
  local expectedSize=if dimensions[2]==768 then {720,780,320,350}
   elseif dimensions[2]==900 then {820,880,360,395}
   elseif dimensions[2]==1035 then {920,980,410,450}
   elseif dimensions[2]==1440 then {1000,1100,450,500}
   else {900,1000,400,440}
  check(rectangle.w>=expectedSize[1] and rectangle.w<=expectedSize[2]
   and rectangle.h>=expectedSize[3] and rectangle.h<=expectedSize[4],"acceptance size range "..tag)
  check(math.abs(groupCenter-safeSize.X*.5)<=1,"Preview plus Sidebar horizontal center "..tag)
  check(sidebar.w>=220 and sidebar.w<=280 and math.abs(sidebar.h-rectangle.h)<.01
   and math.abs(sidebar.y-rectangle.y)<=1,"Lobby matches stage "..tag)
  check(controls.x==sidebar.x and controls.w==sidebar.w and controls.h==184
   and math.abs(controls.y-sidebar.y-sidebar.h-12)<=1,"Controls follows Lobby "..tag)
  check(contentCenter/safeSize.Y>=.43 and contentCenter/safeSize.Y<=.48,
   "actual selection block vertically centered "..tag)
  check(action.w>=190 and action.w<=240 and action.h>=52 and action.h<=64,
   "desktop actions enlarged "..tag)
  check(backdrop.GarageChoice.TextSize>=30 and backdrop.GarageChoice.TextSize<=40,
   "desktop name scale "..tag)
  local preceding=if desktopStep>=3 then detail else name
  check(action.y-preceding.y-preceding.h>=24 and action.y-preceding.y-preceding.h<=32,
   "name/detail/action stay together "..tag)
  if desktopStep<=3 then
   check(math.abs(name.y-rectangle.y-rectangle.h-10)<=1,"name follows preview "..tag)
   for _,control in {backdrop.PreviousChoice,backdrop.NextChoice,presencePanel} do
    check(not intersects(rectangle,bounds(control)),"stage clears arrows and Lobby "..tag)
   end
  end
  for _,box in {rectangle,name,detail,action,sidebar,controls} do
   check(box.x>=0 and box.y>=0 and box.x+box.w<=safeSize.X and box.y+box.h<=safeSize.Y,
    "desktop composition stays in canvas "..tag)
  end
  local selectionCenter=rectangle.x+rectangle.w*.5
  if desktopStep==1 then
   check(math.abs(action.x+action.w*.5-selectionCenter)<=1,"single action centered "..tag)
  else
   local back
   for _,item in backdrop:GetChildren() do if item.Text=="BACK" then back=bounds(item) end end
   check(math.abs(action.x-back.x-back.w-20)<=1
    and math.abs((back.x+action.x+action.w)*.5-selectionCenter)<=1,"paired actions centered "..tag)
  end
  print(string.format("DESKTOP %s preview=(%.2f,%.2f %.2fx%.2f) lobby=(%.2f,%.2f %.2fx%.2f) nameY=%.2f button=(%.2f,%.2f %.2fx%.2f) content=%.2f..%.2f center=%.2f group=%.2f centerX=%.2f",
   tag,rectangle.x,rectangle.y,rectangle.w,rectangle.h,sidebar.x,sidebar.y,sidebar.w,sidebar.h,
   name.y,action.x,action.y,action.w,action.h,contentTop,contentBottom,contentCenter,groupWidth,groupCenter))
  if desktopStep<4 then selectButton.Activated:Fire() end
 end
end
-- Restore Driver for the existing mobile/header/orbit fixtures.
player:SetAttribute("RaceState", "PRE_RACE")
player:SetAttribute("RaceState", "GARAGE")
-- A wide non-notch 932 screen also puts only the title in the Core band.
input.TouchEnabled=true; safeSize=rb.Vector2.new(900,372)
camera.ViewportSize=rb.Vector2.new(932,430); cameraScreenSize=camera.ViewportSize
guiService.TopbarInset=rb.Rect.new(208,0,858,48)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
check(playerGui:FindFirstChild("GarageTitle",true).Parent.Name=="GarageTopHeader",
    "932 non-notch title uses TopbarInset")
check(backdrop.GarageStep.Parent==backdrop and populationLabel.Parent==backdrop,"932 safe secondary header lines")
-- None-inset GUI geometry can settle after the camera/safe-parent signals.
cameraScreenSize=rb.Vector2.new(960,450)
local headerGui=playerGui:FindFirstChild("GarageTopHeader")
headerGui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
local lateTitle=playerGui:FindFirstChild("GarageTitle",true)
check(math.abs(lateTitle.AbsolutePosition.X-headerGui.AbsolutePosition.X+lateTitle.AbsoluteSize.X*.5-480)<=1,
    "late top-header size event recenters title")
headerGui:GetPropertyChangedSignal("AbsolutePosition"):Fire()
backdrop:GetPropertyChangedSignal("AbsolutePosition"):Fire()
cameraScreenSize=camera.ViewportSize
headerGui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
-- Real AbsolutePosition semantics: None-inset GUI origins include a negative
-- Core UI offset. Compare the actual label bounds against the physical canvas,
-- rather than reconstructing Position and accidentally cancelling the bug.
local function verifyHeader(mode, label)
    local title = playerGui:FindFirstChild("GarageTitle",true)
    local physical = title.AbsolutePosition-headerGui.AbsolutePosition
    local size = title.AbsoluteSize
    check(title.Visible and title.Parent.Enabled ~= false, label.." visible")
    check(headerGui:GetAttribute("GarageHeaderMode")==mode,label.." mode")
    check(physical.X>=0 and physical.Y>=0 and physical.X+size.X<=cameraScreenSize.X
        and physical.Y+size.Y<=cameraScreenSize.Y,label.." actual bounds within physical screen")
    check(title.AnchorPoint==rb.Vector2.new(.5,.5) and title.Parent.ClipsDescendants~=true,
        label.." explicit center anchor and unclipped parent")
    if mode=="TOPBAR" then
        local device=(cameraScreenSize-camera.ViewportSize)*.5
        check(math.abs(physical.Y+size.Y*.5-device.Y-(guiService.TopbarInset.Min.Y+guiService.TopbarInset.Max.Y)*.5)<.01,
            label.." actual center in normalized topbar")
        check(math.abs(physical.X+size.X*.5-cameraScreenSize.X*.5)<.01,label.." physical screen center")
    end
end
for _,dimensions in {{1600,739},{1920,1080},{844,390},{1600,739},{932,430},{1280,720}} do
    input.TouchEnabled=dimensions[1]<1000
    cameraScreenSize=rb.Vector2.new(dimensions[1],dimensions[2])
    camera.ViewportSize=cameraScreenSize
    safeSize=cameraScreenSize-rb.Vector2.new(32,58)
    guiService.TopbarInset=rb.Rect.new(208,0,camera.ViewportSize.X-74,58)
    camera:GetPropertyChangedSignal("ViewportSize"):Fire()
    verifyHeader("TOPBAR","resize "..dimensions[1])
end
-- A real notch camera excludes device insets separately from CoreUISafeInsets.
cameraScreenSize=rb.Vector2.new(874,402)
camera.ViewportSize=rb.Vector2.new(750,362)
safeSize=rb.Vector2.new(750,304)
input.TouchEnabled=true
guiService.TopbarInset=rb.Rect.new(208,0,750,58)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
verifyHeader("TOPBAR","device safe viewport with notch")
check(headerGui.AbsolutePosition==rb.Vector2.new(-62,-78),"independent device plus Core UI raw origin")
check(playerGui:FindFirstChild("GarageTitle",true).AbsolutePosition.Y<0,
    "negative raw AbsolutePosition can still be physically visible")
guiService.TopbarInset=rb.Rect.new(0,0,0,0)
guiService:GetPropertyChangedSignal("TopbarInset"):Fire()
verifyHeader("SAFE_HEADER","late topbar initial empty")
check(headerGui.Enabled,"fallback keeps empty header canvas measuring live geometry")
cameraScreenSize=rb.Vector2.new(956,440); camera.ViewportSize=rb.Vector2.new(832,400)
safeSize=rb.Vector2.new(832,342)
headerGui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
check(headerGui.AbsoluteSize==cameraScreenSize,"fallback canvas follows later device resize")
cameraScreenSize=rb.Vector2.new(874,402); camera.ViewportSize=rb.Vector2.new(750,362)
safeSize=rb.Vector2.new(750,304)
guiService.TopbarInset=rb.Rect.new(208,0,750,58)
guiService:GetPropertyChangedSignal("TopbarInset"):Fire()
verifyHeader("TOPBAR","late topbar settles")
local stableTitle=playerGui:FindFirstChild("GarageTitle",true).Position
local validViewport=camera.ViewportSize
camera.ViewportSize=rb.Vector2.zero
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
check(playerGui:FindFirstChild("GarageTitle",true).Position==stableTitle,"zero initial viewport preserves last valid title")
camera.ViewportSize=validViewport
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
local oldCamera=camera
camera=object("Camera"); camera.ViewportSize=validViewport
workspace.CurrentCamera=camera
check(oldCamera:GetPropertyChangedSignal("ViewportSize").count()==0
    and camera:GetPropertyChangedSignal("ViewportSize").count()==1,"camera replacement owns exactly one viewport listener")
verifyHeader("TOPBAR","replacement camera")
check(guiService:GetPropertyChangedSignal("TopbarInset").count()==1,"one topbar listener after resize sequence")
-- Restore the existing orbit/lifecycle test fixture.
cameraScreenSize=rb.Vector2.new(932,430); camera.ViewportSize=cameraScreenSize
safeSize=rb.Vector2.new(900,372)
guiService.TopbarInset=rb.Rect.new(208,0,858,48)
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
-- Actual controller input / RenderStepped lifecycle, including ownership outside the preview.
local preview=backdrop.SelectionPreview
local function previewFrame() return preview.CurrentCamera.CFrame end
local function inputObject(kind,x,y) return {UserInputType=kind,Position=rb.Vector3.new(x,y,0)} end
check(runService.RenderStepped.count()==1,"one idle connection after repeated layouts")
gui.Enabled=false; check(runService.RenderStepped.count()==0,"hidden Garage stops idle rotation")
gui.Enabled=true; check(runService.RenderStepped.count()==1,"visible Garage resumes one loop")
local initial=previewFrame()
runService.RenderStepped:Fire(.25)
check(previewFrame()~=initial,"idle rotation advances at seven seconds per turn")
local touch=inputObject(rb.Enum.UserInputType.Touch,100,100)
preview.InputBegan:Fire(touch)
local beforeDrag=previewFrame()
runService.RenderStepped:Fire(.3)
check(previewFrame()==beforeDrag,"touch ownership pauses idle immediately")
touch.Position=rb.Vector3.new(100,180,0); input.InputChanged:Fire(touch)
check(previewFrame()==beforeDrag,"vertical-only drag ignored")
local otherTouch=inputObject(rb.Enum.UserInputType.Touch,300,100)
preview.InputBegan:Fire(otherTouch); otherTouch.Position=rb.Vector3.new(500,100,0); input.InputChanged:Fire(otherTouch)
check(previewFrame()==beforeDrag,"second touch cannot steal ownership")
touch.Position=rb.Vector3.new(1100,180,0); input.InputChanged:Fire(touch)
check(previewFrame()~=beforeDrag,"horizontal owned drag rotates outside preview")
check(math.abs((previewFrame().Position-rb.Vector3.new(0,-.4,0)).Magnitude-(beforeDrag.Position-rb.Vector3.new(0,-.4,0)).Magnitude)<.001,
    "drag retains fixed camera distance without zoom pumping")
local dragged=previewFrame()
input.InputEnded:Fire(touch); runService.RenderStepped:Fire(2); check(previewFrame()==dragged,"idle waits after release")
runService.RenderStepped:Fire(.6); runService.RenderStepped:Fire(.1)
check(previewFrame()~=dragged,"idle resumes after 2.5 seconds")
local oldCamera=preview.CurrentCamera
backdrop.NextChoice.Activated:Fire()
local firstPulse=visualTweens[#visualTweens]
backdrop.NextChoice.Activated:Fire()
check(firstPulse.cancelled,"rapid selection replaces prior visual tween without delay")
backdrop.NextChoice.Activated:Fire()
check(backdrop.GarageChoice.Text=="Driver Two" and preview.CurrentCamera~=oldCamera,
    "arrow changes Driver ID and rebuilds preview")
local resetFrame=previewFrame()
check(resetFrame==initial and runService.RenderStepped.count()==1,"selection resets showcase angle and replaces idle connection")
local mouse=inputObject(rb.Enum.UserInputType.MouseButton1,100,100)
preview.InputBegan:Fire(mouse)
input.InputChanged:Fire(inputObject(rb.Enum.UserInputType.MouseMovement,200,400))
check(previewFrame()~=resetFrame,"mouse drag rotates preview")
input.WindowFocusReleased:Fire()
local focusedFrame=previewFrame(); input.InputChanged:Fire(inputObject(rb.Enum.UserInputType.MouseMovement,900,100))
check(previewFrame()==focusedFrame,"focus loss clears drag ownership")
player:SetAttribute("KDMRoutePending","RACE_LAUNCH")
check(runService.RenderStepped.count()==0,"pending launch stops idle and drag")
player:SetAttribute("KDMRoutePending","")
check(runService.RenderStepped.count()==1,"failed/cleared launch restores one idle connection")
player.CharacterRemoving:Fire(player.Character)
check(runService.RenderStepped.count()==0,"character removal clears rotation")
player.CharacterAdded:Fire(player.Character)
check(runService.RenderStepped.count()==1,"appearance rebuild owns one new connection")
for iteration=1,5 do
 local buttons={}; for _,item in backdrop:GetChildren() do if item.Text=="SELECT" then table.insert(buttons,item) end end
 buttons[1].Activated:Fire()
 check(runService.RenderStepped.count()==1 and preview.PreviewWorld.PreviewKart~=nil,"Kart owns one idle loop")
 local kartFrame=previewFrame(); local kartTouch=inputObject(rb.Enum.UserInputType.Touch,100,100)
 preview.InputBegan:Fire(kartTouch); kartTouch.Position=rb.Vector3.new(180,100,0); input.InputChanged:Fire(kartTouch)
 check(previewFrame()~=kartFrame,"Kart touch rotates without changing selection")
 buttons[1].Activated:Fire()
 check(runService.RenderStepped.count()==0 and not preview.Visible,"Track stops rotation and hides 3D preview")
 input.InputChanged:Fire(kartTouch)
 buttons[1].Activated:Fire()
 check(runService.RenderStepped.count()==0 and not preview.Visible,"Ready has no rotation loop")
 player:SetAttribute("RaceState","PRE_RACE"); player:SetAttribute("RaceState","GARAGE")
 check(runService.RenderStepped.count()==1,"Garage reopen restores one loop without accumulating")
end
local preservedFrame=previewFrame()
input.InputBegan:Fire(inputObject(rb.Enum.UserInputType.Touch,10,10))
input.InputChanged:Fire(inputObject(rb.Enum.UserInputType.Touch,500,100))
check(previewFrame()==preservedFrame,"touch outside preview does not rotate or intercept controls")
-- Crowded Core UI must force the safe fallback even on a wide viewport.
guiService.TopbarInset=rb.Rect.new(700,0,850,48)
guiService:GetPropertyChangedSignal("TopbarInset"):Fire()
check(playerGui:FindFirstChild("GarageTitle",true).Parent==backdrop,"occupied Core UI forces safe header fallback")
gui:Destroy()
check(guiService:GetPropertyChangedSignal("TopbarInset").count()==0
    and workspace:GetPropertyChangedSignal("CurrentCamera").count()==0
    and camera:GetPropertyChangedSignal("ViewportSize").count()==0,"layout listeners disconnect on destruction")
check(runService.RenderStepped.count()==0 and input.InputChanged.count()==0 and input.InputEnded.count()==0,
    "GUI destruction disconnects render and global input listeners")
-- Exercise the production helper with tall/wide/rotated bounds and changed FOV.
local source = fs.readFile("src/client/GarageUiController.luau")
local helperSource = string.match(source, "(local function fitDriverPreview.-)\nfunction GarageUiController.start")
local fitDriver = luau.load(assert(helperSource) .. "\nreturn fitDriverPreview", {
    environment = { Vector3 = rb.Vector3, CFrame = rb.CFrame } })()
local priorDriver = luau.load(assert(helperSource):gsub("tangent%*%.89","tangent*.85"):gsub("math.max%(aspect,%.1%)%*%.89","math.max(aspect,.1)*.85") .. "\nreturn fitDriverPreview", {
    environment = { Vector3 = rb.Vector3, CFrame = rb.CFrame } })()
local comparisonModel={GetBoundingBox=function() return rb.CFrame.identity,rb.Vector3.new(4,6.5,2) end,GetDescendants=function() return {} end}
local oldFit=priorDriver(comparisonModel,2.65,40)
local newFit=fitDriver(comparisonModel,2.26,40)
check(newFit.Position.Magnitude<oldFit.Position.Magnitude,"R1 driver distance expands actual avatar occupancy")
for _, size in {rb.Vector3.new(4,6.5,2), rb.Vector3.new(3,9,3), rb.Vector3.new(9,5,4)} do
 for _, aspect in { .9, 1.4, 3.5, 5.2 } do
  for _, fov in {30,40,55} do
   local box = rb.CFrame.new(2,-1,3) * rb.CFrame.Angles(0,.4,0)
   local fitted = fitDriver({GetBoundingBox = function() return box,size end, GetDescendants=function() return {} end}, aspect, fov)
   local fill = 0
   local offset=fitted.Position-box.Position
   local distance,pitch=offset.Magnitude,math.asin(offset.Y/offset.Magnitude)
   for degrees=0,345,15 do
    local yaw=math.rad(degrees)
    local direction=rb.Vector3.new(math.sin(yaw)*math.cos(pitch),math.sin(pitch),math.cos(yaw)*math.cos(pitch))
    local right=rb.Vector3.yAxis:Cross(direction).Unit
    local orbit=rb.CFrame.fromMatrix(box.Position+direction*distance,right,direction:Cross(right),direction)
    for _, x in {-1,1} do for _, y in {-1,1} do for _, z in {-1,1} do
     local point=orbit:PointToObjectSpace(box:PointToWorldSpace(size*rb.Vector3.new(x,y,z)*.5))
     check(point.Z<0,"varied avatar corners remain ahead throughout full orbit")
     local tangent=math.tan(math.rad(fov*.5))
     local projected=math.max(math.abs(point.X)/(-point.Z*tangent*aspect),math.abs(point.Y)/(-point.Z*tangent))
     check(projected<=.90,"full yaw orbit preserves hair/body safety")
     fill=math.max(fill,projected)
    end end end
   end
   check(fill>=.84,"orbit envelope fills limiting axis without zoom pumping")
  end
 end
end
print("PASS: " .. count .. " Garage transition and scrolling presence checks")
local serde=require("@lune/serde")
if require("@lune/process").args[2] then
 fs.writeFile(require("@lune/process").args[2],serde.encode("json",geometrySnapshots))
else
 local baseline=serde.decode("json",fs.readFile("tests/fixtures/garage_phase1b_geometry.json"))
 assert(#baseline==#geometrySnapshots,"geometry scenario count")
 for index,snapshot in geometrySnapshots do
  assert(snapshot.tag==baseline[index].tag,"geometry scenario order")
  for name,rectangle in snapshot.objects do
   -- Vector2 is float32; compare the saved coordinates at that same precision
   -- rather than the JSON decoder's double-precision round-trip.
   local saved=baseline[index].objects[name]
   local savedPosition,savedSize=rb.Vector2.new(saved[1],saved[2]),rb.Vector2.new(saved[3],saved[4])
   assert(rb.Vector2.new(rectangle[1],rectangle[2])==savedPosition and rb.Vector2.new(rectangle[3],rectangle[4])==savedSize,"Phase 1B geometry changed: "..snapshot.tag.." "..name)
  end
 end
 print("PASS: "..#geometrySnapshots.." Phase 1B exact absolute geometry snapshots")
end
