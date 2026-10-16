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
		FocusLost = signal(), Activated = signal(), OnClientEvent = signal(), CharacterAdded = signal(), ChildAdded = signal(), CharacterRemoving = signal(), Destroying = signal(), InputBegan = signal(), InputChanged = signal(), InputEnded = signal(), WindowFocusReleased = signal() }
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
function methods:GetBoundingBox()
 if self.Name=="PreviewKart" then return rb.CFrame.identity,rb.Vector3.new(8,2,10) end
 return rb.CFrame.new(0, -.4, 0), rb.Vector3.new(4, 6.5, 2) end
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
function methods:ReleaseFocus() self.FocusLost:Fire(false) end
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
	"KartPreviewFraming", "DriverAppearance", "KDMUiTheme" } do child(shared, "ModuleScript", name) end
local modules = {
 KDMUiTheme=luau.load(fs.readFile("src/shared/KDMUiTheme.luau"),{environment={Color3=rb.Color3}})(),
	DriverCatalog = { DefaultId = "Driver01", Order = { "Driver01", "Driver02" }, Entries = { Driver01 = { DisplayName = "Driver" }, Driver02 = {DisplayName = "Driver Two"} } },
	KartCatalog = { DefaultId="Kart01", Order = { "Kart01", "Kart02" }, Entries = { Kart01 = { Id="Kart01", VisualModelName="SprintV1", DisplayName = "Kart", BodyColor=rb.Color3.new(1,0,0) }, Kart02 = {Id="Kart02", VisualModelName="SprintV1",DisplayName = "Kart Two",BodyColor=rb.Color3.new(1,1,1)} } },
	TrackCatalog = { Order = { "Track01" }, Entries = { Track01 = { Id = "Track01", DisplayName = "Practice",
		MatchType = "SOLO_PRACTICE", GeometryId = "PracticeCircuitV1", TargetLaps=1, MinPlayers=1, MaxPlayers=1 } },
		previewKey = function() return "Track01" end, capabilityLabel = function() return "PRACTICE" end },
	TrackGeometry = { getDefinition = function() return {} end },
	KartVisualFactory = { createVisual = function()
        local model=object("Model"); local part=child(model,"Part","Body"); part.Size=rb.Vector3.new(8,2,10); part.CFrame=rb.CFrame.identity; part.Transparency=0; return model
    end },
	KartPreviewFraming = luau.load(fs.readFile("src/shared/KartPreviewFraming.luau"),{environment={Vector3=rb.Vector3,CFrame=rb.CFrame}})(),
	DriverAppearance = { applyHairStyle = function() end, applyToCharacter = function() end },
	TrackMapRenderer = { create = function() return { destroy = function() end } end },
	TrackDioramaController = { create = function() return {destroy=function() end,cancelInput=function() end} end },
	GaragePresence = luau.load(fs.readFile("src/client/GaragePresence.luau"))(),
	GarageTexturePreload = luau.load(fs.readFile("src/client/GarageTexturePreload.luau"),{environment={Instance=rb.Instance}})(),
	KartInputController = { isTouchPreferred = function() return true end },
	MobileTutorialView = { create = function() return { open = function() end, close = function() end } end },
}
modules.KartCatalog=luau.load(fs.readFile("src/shared/KartCatalog.luau"),{environment={Color3=rb.Color3,Enum=rb.Enum}})()
local environment = { script = { Parent = client }, Instance = { new = object }, UDim2 = rb.UDim2,
	UDim = rb.UDim, Vector2 = rb.Vector2, Vector3 = rb.Vector3, Color3 = rb.Color3, CFrame = rb.CFrame,
 ColorSequence=rb.ColorSequence,NumberSequence=rb.NumberSequence,NumberSequenceKeypoint=rb.NumberSequenceKeypoint,TweenInfo={new=function() return {} end},
	Enum = rb.Enum, game = { PlaceVersion = 1, GetService = function(_, name) return assert(services[name], name) end },
	require = function(module) return assert(modules[module.Name], module.Name) end,
	task = { delay = function() end, defer = function(callback) callback() end, spawn = function(callback) callback() end } }

child(client,"ModuleScript","TrackDioramaController")
local controller = luau.load(fs.readFile("src/client/GarageUiController.luau"), {environment=environment})()
controller.start()
local gui = playerGui.RobloxKartGarage
local backdrop = gui:FindFirstChild("Frame")
local preview = backdrop.SelectionPreview
local invite = playerGui.HubRaceInvite.RaceInvite
local selectButton, backButton, readyButton
for _, item in backdrop:GetChildren() do
 if item.Text == "SELECT" then selectButton = item
 elseif item.Text == "BACK" then backButton = item
 elseif item.Text == "READY" then readyButton = item end
end
check(not gui.Enabled and not playerGui.RobloxKartGarageBackground.Enabled, "Hub join leaves fullscreen overlay closed")
check(playerGui.HubRaceInvite.Enabled, "invite surface independent of overlay")
check(not preview.PreviewWorld, "closed overlay has no preview/render allocation")
controller.open("KART")
check(gui.Enabled and player:GetAttribute("HubOverlayOpen"), "Garage action opens local overlay")
local background=playerGui.RobloxKartGarageBackground.FullScreenBackground
check(background.BackgroundTransparency==.82 and not background:FindFirstChild('ArcadeDepth'),'live Lobby background replaces opaque gradient')
check(backdrop.Active and background.Active,'selection backdrop sinks world taps')
check(backdrop.GarageStep.Text == "KART GARAGE" and preview.PreviewWorld.PreviewKart, "first step is Kart")
check(backdrop.GarageChoice.Text == "KDM V2 Cyan", "Garage opens on V2 when no V2 is committed")
local kartControls=backdrop.KartControls
check(kartControls.Chassis_KDMV2 and kartControls.Chassis_SprintV1,"actual two chassis tabs")
check(selectButton.BackgroundColor3==modules.KDMUiTheme.PrimaryAction,"Yellow primary CTA")
local beforeChipRequests=remote.fireCount
for _,family in {"KDMV2","SprintV1"} do
 kartControls["Chassis_"..family].Activated:Fire()
 for _,id in modules.KartCatalog.Order do
  local entry=modules.KartCatalog.Entries[id]
  local chip=kartControls.ColorChips["Color_"..id]
  check(chip.Visible==(entry.VisualModelName==family),"valid family chips only")
  if entry.VisualModelName==family then
   chip.Activated:Fire()
   check(backdrop.GarageChoice.Text==entry.DisplayName,"chip previews actual catalog ID")
   check(chip.Text=="✓" and chip.SelectionRing.Transparency==0,"explicit selected check/ring")
   check(chip.AbsoluteSize.X>=44 and chip.AbsoluteSize.Y>=44,"44 px chip target")
   check(player:GetAttribute("SelectedKartId")==nil and remote.fireCount==beforeChipRequests,"chip never commits selection")
  end
 end
end
controller.close();controller.open("KART")
local populationLabel = playerGui:FindFirstChild("KDMPopulation", true)
populationRemote.OnClientEvent:Fire({online=7,lobby=3,inRace=4,stale=false})
check(populationLabel.Text:find("7",1,true) and populationLabel.Text:find("3",1,true), "experience population retained")
backdrop.NextChoice.Activated:Fire()
check(backdrop.GarageChoice.Text == "KDM V2 Red", "V2 first preview cycles through V2 colors")
backButton.Activated:Fire()
check(not gui.Enabled and runService.RenderStepped.count()==0, "Kart Back closes and stops render")
remote.OnClientEvent:Fire("Invite", "Host", "Track01", 1, 4)
check(invite.Visible and playerGui.HubRaceInvite.Enabled and not gui.Enabled, "Invite appears while Hub overlay closed")
invite:FindFirstChild("TextButton").Activated:Fire()
check(remote.lastFire[1] == "DeclineInvite" and not invite.Visible, "closed-overlay Decline works")
remote.OnClientEvent:Fire("Invite", "Host", "Track01", 1, 4)
for _,button in invite:GetChildren() do if button.Text == "JOIN" then button.Activated:Fire() end end
check(remote.lastFire[1] == "JoinInvite" and remote.lastFire[2]=="Driver01" and remote.lastFire[3]==modules.KartCatalog.DefaultId, "Join retains default Kart and compatibility DriverId")
controller.open("TRACK")
check(backdrop.GarageStep.Text=="STEP 1 / 2 · TRACK SELECT" and backdrop.TrackPreview.Visible, "Tracks opens second step")
backButton.Activated:Fire()
check(not gui.Enabled, "Track Back returns Hub directly")
controller.open("KART")
kartControls.Chassis_SprintV1.Activated:Fire()
backdrop.NextChoice.Activated:Fire()
selectButton.Activated:Fire()
check(remote.lastFire[1]=="SelectKart" and remote.lastFire[2]=="Kart02" and gui.Enabled,"CTA requests server commit")
player:SetAttribute("SelectedKartId","Kart02")
remote.OnClientEvent:Fire("KartSelected","Kart02")
check(not gui.Enabled,"server confirmation returns Hub")
controller.open("TRACK")
selectButton.Activated:Fire()
check(backdrop.GarageStep.Text=="2 / 2   READY" and backdrop.GarageChoice.Text=="Sprint V1 White / Practice", "Ready contains Kart/Track only")
backButton.Activated:Fire(); check(backdrop.TrackPreview.Visible, "Ready Back opens Track")
selectButton.Activated:Fire()
local before = remote.fireCount
readyButton.Activated:Fire(); readyButton.Activated:Fire()
check(remote.fireCount==before+1 and remote.lastFire[1]=="Ready" and remote.lastFire[2]=="Driver01" and remote.lastFire[3]=="Kart02" and remote.lastFire[4]=="Track01", "Solo ready validates unchanged payload, one request")
check(gui.RouteTransition.Visible and not readyButton.Active, "pending launch locks navigation")
controller.close(); check(gui.Enabled, "cannot close an ongoing launch")
remote.OnClientEvent:Fire("RouteLaunchFailed"); check(not gui.RouteTransition.Visible and readyButton.Active, "failed launch unlocks overlay")
player:SetAttribute("RaceState","PRE_RACE"); player:SetAttribute("RaceState","GARAGE")
check(not gui.Enabled and not player:GetAttribute("HubOverlayOpen"), "Return Hub defaults closed")
-- Retain responsive layout and full-yaw Kart framing checks across phone/notch/desktop.
local resolutions={{705,280},{831,348},{751,361},{844,390},{812,332},{932,430},{760,390},{390,844},{1280,720},{1366,768},{1600,900},{1920,1080},{2048,1035},{2560,1080},{2560,1440}}
for _,resolution in resolutions do
 safeSize=rb.Vector2.new(resolution[1],resolution[2]); cameraScreenSize=safeSize; camera.ViewportSize=safeSize
 input.TouchEnabled=resolution[1]<1000
 guiService.TopbarInset=rb.Rect.new(208,0,math.max(208,resolution[1]-74),48)
 camera:GetPropertyChangedSignal("ViewportSize"):Fire()
 controller.open("KART")
 for step=1,3 do
  local tag=string.format("%dx%d step %d",resolution[1],resolution[2],step)
  check(backdrop.GarageStep.Text==({"KART GARAGE","STEP 1 / 2 · TRACK SELECT","2 / 2   READY"})[step], "separate Garage and Tracks headings "..tag)
  check(preview.Visible==(step==1) and backdrop.TrackPreview.Visible==(step==2), "step visibility "..tag)
  check(backButton.Visible and selectButton.Visible==(step<3) and readyButton.Visible==(step==3), "Back/Select/Ready navigation "..tag)
  local action=if step==3 then readyButton else selectButton
  for _,item in {backButton,action,backdrop.GarageChoice} do
   local position,size=item.AbsolutePosition,item.AbsoluteSize
   check(position.X>=0 and position.Y>=0 and position.X+size.X<=safeSize.X+.1 and position.Y+size.Y<=safeSize.Y+.1,"safe responsive target "..tag)
  end
  check(backButton.AbsoluteSize.Y>=40 and action.AbsoluteSize.Y>=40,"touch target size "..tag)
  if step==1 then
   if input.TouchEnabled and safeSize.X>safeSize.Y then
    local vp,vs=preview.AbsolutePosition,preview.AbsoluteSize
    local cp,cs=kartControls.AbsolutePosition,kartControls.AbsoluteSize
    check(vp.X>=0 and vp.Y>=0 and vp.X+vs.X<=safeSize.X and vp.Y+vs.Y<=backdrop.GarageChoice.AbsolutePosition.Y,"expanded mobile kart safe and above name "..tag)
    check(vs.X>safeSize.X*.42 and cs.X<=208,"compact sidebar releases preview width "..tag)
    check(cp.X>=vp.X+vs.X+52 and cp.X+cs.X<=safeSize.X,"sidebar clears preview arrow and safe edge "..tag)
    check(cp.Y+cs.Y<=safeSize.Y,"sidebar within safe height "..tag)
    for _,chip in kartControls.ColorChips:GetChildren() do
     if chip:IsA("TextButton") and chip.Visible then
      check(chip.AbsoluteSize.X>=44 and chip.AbsoluteSize.Y>=44 and chip.Swatch.AbsoluteSize.X==32,"small swatch keeps touch target "..tag)
     end
    end
   end
   local model=preview.PreviewWorld.PreviewKart
   local box,size=model:GetBoundingBox()
   local fitted=preview.CurrentCamera.CFrame
   local target=box.Position
   local offset=fitted.Position-target
   local distance,pitch=offset.Magnitude,math.asin(offset.Y/offset.Magnitude)
   for degrees=0,345,15 do
    local yaw=math.rad(degrees)
    local direction=rb.Vector3.new(math.sin(yaw)*math.cos(pitch),math.sin(pitch),math.cos(yaw)*math.cos(pitch))
    local right=rb.Vector3.yAxis:Cross(direction).Unit
    local orbit=rb.CFrame.fromMatrix(target+direction*distance,right,direction:Cross(right),direction)
    for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
     local point=orbit:PointToObjectSpace(box*rb.Vector3.new(x*size.X/2,y*size.Y/2,z*size.Z/2))
     check(point.Z<0,"Kart corner in front "..tag)
     local tangent=math.tan(math.rad(preview.CurrentCamera.FieldOfView/2))
     local aspect=preview.AbsoluteSize.X/preview.AbsoluteSize.Y
     check(math.abs(point.X)/(-point.Z*tangent*aspect)<=.95 and math.abs(point.Y)/(-point.Z*tangent)<=.95,"full orbit stays framed "..tag)
    end end end
   end
  end
  if step==1 then controller.close();controller.open("TRACK") elseif step==2 then selectButton.Activated:Fire() end
 end
 controller.close();check(not gui.Enabled and runService.RenderStepped.count()==0,"close cleans every resolution")
end
controller.open("KART")
local function touch(x) return {UserInputType=rb.Enum.UserInputType.Touch,Position=rb.Vector3.new(x,100,0)} end
local initial=preview.CurrentCamera.CFrame
local gesture=touch(100)
preview.InputBegan:Fire(gesture); gesture.Position=rb.Vector3.new(180,100,0); input.InputChanged:Fire(gesture)
check(preview.CurrentCamera.CFrame~=initial,"Kart touch drag rotates")
input.InputEnded:Fire(gesture)
local dragged=preview.CurrentCamera.CFrame
runService.RenderStepped:Fire(2);check(preview.CurrentCamera.CFrame==dragged,"idle waits after drag")
runService.RenderStepped:Fire(.6);runService.RenderStepped:Fire(.1)
check(preview.CurrentCamera.CFrame~=dragged,"idle resumes after release")
for _=1,5 do controller.close();controller.open("KART");check(runService.RenderStepped.count()==1,"reopen owns one render connection") end
controller.close()
player:SetAttribute("RaceState","RACING");controller.open("KART")
check(not gui.Enabled and not playerGui.HubRaceInvite.Enabled,"race state rejects Hub navigation")

-- Execute HUB-only client shortcuts and native prompt bridge against the same UI.
player:SetAttribute("RaceState","GARAGE")
function methods:IsDescendantOf(ancestor)
 local parent=self.Parent
 while parent do if parent==ancestor then return true end;parent=parent.Parent end
 return false
end
-- Theme already registered above.
child(client,"ModuleScript","GarageUiController")
modules.GarageUiController=controller
for _, name in {"HubGuidanceState", "HubGuidanceView", "HubWorldGuidanceView"} do
 child(client,"ModuleScript",name)
 modules[name]=luau.load(fs.readFile("src/client/"..name..".luau"),{environment=environment})()
end
child(replicated,"RemoteEvent","MatchRoomControl")
modules.KDMUiTheme=luau.load(fs.readFile("src/shared/KDMUiTheme.luau"),{environment={Color3=rb.Color3}})()
services.ProximityPromptService={PromptTriggered=signal()}
local hub=child(workspace,"Model","KDMHub")
local anchors=child(hub,"Folder","Anchors")
local displayAnchor=child(anchors,"Part","MyKartDisplayAnchor");displayAnchor.CFrame=rb.CFrame.new(4,.08,900)
local spawnAnchor=child(hub,"Part","HubSpawn");spawnAnchor.CFrame=rb.CFrame.new(-12,.5,900)*rb.CFrame.Angles(0,-math.pi/2,0)
for _,d in {{"GaragePromptAnchor",9,-17},{"RacePromptAnchor",25,0},{"TracksPromptAnchor",9,17}} do
 child(anchors,"Part",d[1]).CFrame=rb.CFrame.new(d[2],2,900+d[3])
end
local stations=child(hub,"Folder","Stations")
local station=child(stations,"Part","GarageStation");station:SetAttribute("HubAction","GARAGE")
local prompt=child(station,"ProximityPrompt","HubPrompt")
prompt.Enabled=true
-- Hub shortcuts now consume the existing Lobby layout; inject real pure view modules.
for _,name in {"LobbyDriveLayout","MobileControlView","KDMUiStyleHelper","HubRaceBoardView"} do
 child(client,"ModuleScript",name)
 modules[name]=luau.load(fs.readFile("src/client/"..name..".luau"),{environment=environment})()
end
local hubController=luau.load(fs.readFile("src/client/HubUiController.luau"),{environment=environment})()
workspace:SetAttribute("KDMServerRole","RACE");hubController.start()
check(not playerGui:FindFirstChild("KDMHubNavigation"),"RACE has no Hub shortcuts")
workspace:SetAttribute("KDMServerRole","HUB");hubController.start();hubController.start()
local hubGui=playerGui.KDMHubNavigation
check(hubGui.Enabled and hubGui.ScreenInsets==rb.Enum.ScreenInsets.CoreUISafeInsets,"Hub safe navigation enabled")
check(hub.KDMClientShowroom.ShowroomBay1.KDMClientMyKartDisplay:GetAttribute("SelectedKartId")=="Kart05" and player:GetAttribute("SelectedKartId")=="Kart02","Sprint selection preserved while V2 Cyan is exhibited")
local firstDisplay=hub.KDMClientShowroom
player:SetAttribute("SelectedKartId","Kart01")
check(firstDisplay.Parent==nil and hub.KDMClientShowroom.ShowroomBay1.KDMClientMyKartDisplay:GetAttribute("SelectedKartId")=="Kart05" and player:GetAttribute("SelectedKartId")=="Kart01","attribute refresh replaces showroom without changing Sprint selection")
player.CharacterAdded:Fire(player.Character)
check(#hub:GetChildren()==5,"respawn has exactly one local display and world guidance")
player:SetAttribute("RaceState","RACING")
check(not hub:FindFirstChild("KDMClientShowroom"),"race transition removes Hub display")
player:SetAttribute("RaceState","GARAGE")
check(hub.KDMClientShowroom.ShowroomBay1.KDMClientMyKartDisplay:GetAttribute("SelectedKartId")=="Kart05" and player:GetAttribute("SelectedKartId")=="Kart01","Return Hub preserves committed selection and V2 exhibit")
local showroomIds={};local showroomCount=0
for _,bay in hub.KDMClientShowroom:GetChildren() do
 local kart=bay.KDMClientMyKartDisplay;local id=kart:GetAttribute("SelectedKartId")
 check(not showroomIds[id] and kart:GetAttribute("ShowroomStatic"),"unique static exhibit")
 showroomIds[id]=true;showroomCount+=1
 local drivePrompt=kart:FindFirstChild("LobbyDisplayTestDrive",true)
 check(drivePrompt and drivePrompt.Parent:GetAttribute("ShowroomKartId")==id,"every bay prompt requests its exhibited color")
 check(drivePrompt.ObjectText==modules.KartCatalog.Entries[id].DisplayName,"every bay prompt names its exhibited kart")
 for _,part in kart:GetDescendants()do if part:IsA("BasePart")then check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,"exhibit has no active collision")end end
end
check(showroomCount==7,"exactly seven catalog V2 colors")
local shortcuts=hubGui.Shortcuts
shortcuts.GARAGE.Activated:Fire()
check(gui.Enabled and not hubGui.Enabled and backdrop.GarageStep.Text=="KART GARAGE","Garage shortcut opens correct local step")
check(not prompt.Enabled,'modal disables world navigation prompts locally')
local stepBefore=backdrop.GarageStep.Text
services.ProximityPromptService.PromptTriggered:Fire(prompt,player)
check(backdrop.GarageStep.Text==stepBefore,'prompt through open modal cannot switch selection')
check(backdrop.GarageChoice.Text=="KDM V2 Cyan" and player:GetAttribute("SelectedKartId")=="Kart01","V2 first preview preserves committed Sprint until USE KART")
controller.close();shortcuts.TRACKS.Activated:Fire()
check(backdrop.TrackPreview.Visible and not hubGui.Enabled,"Tracks shortcut navigates without launching")
controller.close()
local sent=remote.fireCount
check(prompt.Enabled,'closing modal restores prior prompt state')
services.ProximityPromptService.PromptTriggered:Fire(prompt,player)
check(gui.Enabled and remote.fireCount==sent,"native station prompt only navigates")
controller.close()
services.ProximityPromptService.PromptTriggered:Fire(prompt,{})
check(not gui.Enabled,"other player's prompt rejected locally")
local foreign=object("ProximityPrompt");foreign.Parent=workspace
services.ProximityPromptService.PromptTriggered:Fire(foreign,player)
check(not gui.Enabled,"non-Hub prompt ignored")
station:SetAttribute("HubAction","RACE")
services.ProximityPromptService.PromptTriggered:Fire(prompt,player)
check(not gui.Enabled and replicated.MatchRoomControl.lastFire[1]=='BrowseAll',"Race station opens cross-track browser directly")
controller.close()
for _,resolution in resolutions do
 safeSize=rb.Vector2.new(resolution[1],resolution[2])
 for _,button in {shortcuts.GARAGE,shortcuts.TRACKS} do
  local position,size=button.AbsolutePosition,button.AbsoluteSize
  check(position.X>=0 and position.Y>=0 and position.X+size.X<=safeSize.X and position.Y+size.Y<=safeSize.Y,"Hub shortcut within safe canvas")
  check(size.Y>=44,"Hub minimum touch target")
 end
end
hubGui:Destroy()
check(services.ProximityPromptService.PromptTriggered.count()==0 and not hub:FindFirstChild("KDMClientShowroom"),"Hub destruction cleans prompt and display")

gui:Destroy()
check(runService.RenderStepped.count()==0 and input.InputChanged.count()==0 and input.InputEnded.count()==0,"destroy disconnects render/global input")
print(string.format("PASS: %d H2 Garage transition / layout / invite / orbit checks",count))
