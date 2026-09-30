-- lune run tests/garage_transition_validation.luau
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local count = 0
local function check(value, label) assert(value, label); count += 1 end
local function signal()
	local listeners = {}
	return { Connect = function(_, callback)
		table.insert(listeners, callback)
		return { Disconnect = function() end }
	end, Fire = function(_, ...) for _, callback in listeners do callback(...) end end }
end
local methods = {}
local safeSize = rb.Vector2.new(844, 390)
local function object(class, name)
	local props = { ClassName = class, Name = name or class, Size = rb.UDim2.fromScale(1, 1),
		Position = rb.UDim2.fromScale(0, 0), Visible = true, Enabled = true,
		Activated = signal(), OnClientEvent = signal(), CharacterAdded = signal(), Destroying = signal() }
	return setmetatable({ _p = props, _children = {}, _attrs = {}, _signals = {}, _properties = {} }, {
		__index = function(self, key)
			if methods[key] then return methods[key] end
			if key == "AbsoluteSize" then
				if class == "ScreenGui" or not props.Parent then return safeSize end
				local parent = props.Parent.AbsoluteSize
				return rb.Vector2.new(parent.X * props.Size.X.Scale + props.Size.X.Offset,
					parent.Y * props.Size.Y.Scale + props.Size.Y.Offset)
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
			if old ~= value and self._properties[key] then self._properties[key]:Fire() end
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
function methods:GetDescendants() return {} end
function methods:IsA(name) return self.ClassName == name end
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
local playerGui = child(player, "PlayerGui", "PlayerGui")
local players = { player }
local playersService = { LocalPlayer = player, PlayerAdded = signal(), PlayerRemoving = signal(),
	GetPlayers = function() return players end }
local replicated = object("ReplicatedStorage")
local shared = child(replicated, "Folder", "Shared")
local remote = child(replicated, "RemoteEvent", "GarageControl")
local populationRemote = child(replicated, "RemoteEvent", "KDMPopulationStatus")
child(replicated, "RemoteEvent", "ControlsTutorialPreference")
local camera = object("Camera"); camera.ViewportSize = rb.Vector2.new(844, 390)
local workspace = object("Workspace"); workspace.CurrentCamera = camera
local input = object("UserInputService"); input.TouchEnabled = true
local services = { Players = playersService, ReplicatedStorage = replicated, Workspace = workspace,
	UserInputService = input }
local client = object("Folder", "Client")
for _, name in { "TrackMapRenderer", "GaragePresence", "KartInputController", "MobileTutorialView" } do
	child(client, "ModuleScript", name)
end
for _, name in { "DriverCatalog", "KartCatalog", "TrackCatalog", "TrackGeometry", "KartVisualFactory",
	"KartPreviewFraming", "DriverAppearance" } do child(shared, "ModuleScript", name) end
local modules = {
	DriverCatalog = { Order = { "Driver01" }, Entries = { Driver01 = { DisplayName = "Driver" } } },
	KartCatalog = { Order = { "Kart01" }, Entries = { Kart01 = { DisplayName = "Kart" } } },
	TrackCatalog = { Order = { "Track01" }, Entries = { Track01 = { Id = "Track01", DisplayName = "Practice",
		MatchType = "SOLO_PRACTICE", GeometryId = "PracticeCircuitV1" } },
		previewKey = function() return "Track01" end, capabilityLabel = function() return "PRACTICE" end },
	TrackGeometry = { getDefinition = function() return {} end },
	KartVisualFactory = { createVisual = function() return object("Model") end },
	KartPreviewFraming = { fit = function() return nil end },
	DriverAppearance = { applyHairStyle = function() end },
	TrackMapRenderer = { create = function() return { destroy = function() end } end },
	GaragePresence = luau.load(fs.readFile("src/client/GaragePresence.luau"))(),
	KartInputController = { isTouchPreferred = function() return true end },
	MobileTutorialView = { create = function() return { open = function() end, close = function() end } end },
}
local environment = { script = { Parent = client }, Instance = { new = object }, UDim2 = rb.UDim2,
	UDim = rb.UDim, Vector2 = rb.Vector2, Vector3 = rb.Vector3, Color3 = rb.Color3, CFrame = rb.CFrame,
	Enum = rb.Enum, game = { PlaceVersion = 1, GetService = function(_, name) return assert(services[name], name) end },
	require = function(module) return assert(modules[module.Name], module.Name) end,
	task = { delay = function() end, defer = function(callback) callback() end, spawn = function() end } }
local controller = luau.load(fs.readFile("src/client/GarageUiController.luau"), { environment = environment })()
controller.start()
local gui = playerGui.RobloxKartGarage
local backdrop = gui:FindFirstChild("Frame")
local presencePanel = backdrop.ServerPresence
local list = presencePanel.OnlineList
local populationLabel = backdrop.KDMPopulation
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
	and presencePanel.Size.Y.Offset == 102 and list.AbsoluteSize.Y == 70,
	"mobile presence reserves four 16px rows with 2px gaps")
local function checkPopulationRows(expected)
	local contentHeight = modules.GaragePresence.canvasHeight(expected, 16, 2)
	check(#rows() == expected and list.CanvasSize.Y.Offset == contentHeight,
		"local list contains exactly " .. expected .. " names without blank rows")
	if expected <= 4 then
		check(contentHeight <= list.AbsoluteSize.Y, tostring(expected) .. " names visible without scrolling")
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
	and presencePanel.Size.Y.Offset == 102, "ten players fit fixed mobile panel with scroll canvas")
for index = 11, 50 do addPlayer(index) end
checkPopulationRows(50)
check(#rows() == 50 and list.CanvasSize.Y.Offset == modules.GaragePresence.canvasHeight(50, 16, 2)
	and presencePanel.Size.Y.Offset == 102, "50 players remain represented without expanding panel")
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
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
check(presencePanel.Size.Y.Offset == 155 and list.CanvasSize.Y.Offset == modules.GaragePresence.canvasHeight(50, 20, 2),
	"desktop shows four rows with all remaining players scrollable")
check(string.find(list.Player3.Text, "RACING", 1, true) ~= nil,
	"desktop presence updates the changed racer status")
safeSize = rb.Vector2.new(844, 390); input.TouchEnabled = true
camera.ViewportSize = safeSize
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
local selectButton = backdrop:FindFirstChild("TextButton", true)
local function bounds(item)
	local parentSize = item.Parent.AbsoluteSize
	local size = item.AbsoluteSize
	local anchor = item.AnchorPoint or rb.Vector2.zero
	local x = parentSize.X * item.Position.X.Scale + item.Position.X.Offset - size.X * anchor.X
	local y = parentSize.Y * item.Position.Y.Scale + item.Position.Y.Offset - size.Y * anchor.Y
	return { x = x, y = y, w = size.X, h = size.Y }
end
local function intersects(a, b)
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
-- Screen width/height, approved aggregate width, local Lobby width, visible rows.
local resolutions = { {1600,739,560,140,4}, {1280,720,560,108,4},
	{844,390,511,65,4}, {390,844,326,54,4}, {390,600,326,54,1} }
for step = 1, 4 do
	for _, resolution in resolutions do
		-- Model a 58px Core UI top inset and 16px side safe margins.
		safeSize = rb.Vector2.new(resolution[1] - 32, resolution[2] - 58)
		input.TouchEnabled = true
		camera.ViewportSize = rb.Vector2.new(resolution[1], resolution[2])
		camera:GetPropertyChangedSignal("ViewportSize"):Fire()
		local tag = string.format("%dx%d step %d", resolution[1], resolution[2], step)
		local status = bounds(populationLabel)
		local lobby = bounds(presencePanel)
		check(lobby.x >= 0 and lobby.y >= 0 and lobby.x + lobby.w <= safeSize.X
			and lobby.y + lobby.h <= safeSize.Y, "local Lobby stays inside Core UI safe bounds " .. tag)
		local visibleRows = resolution[5]
		check(presencePanel.Size.X.Offset == resolution[4]
			and presencePanel.Size.Y.Offset == 30 + visibleRows * 18
			and list.AbsoluteSize.Y == visibleRows * 16 + (visibleRows - 1) * 2,
			tostring(visibleRows) .. " local Lobby rows visible " .. tag)
		check(list.CanvasPosition.Y == 120 and #rows() == 50
			and list.CanvasSize.Y.Offset == modules.GaragePresence.canvasHeight(50, 16, 2),
			"resize preserves names, canvas and scroll position " .. tag)
		check(status.w == resolution[3] and populationLabel.Position.Y.Scale == rb.UDim2.new(0, 0, 0.13, 0).Y.Scale
			and populationLabel.Position.Y.Offset == 22, "approved aggregate placement unchanged " .. tag)
		check(gui.ScreenInsets == rb.Enum.ScreenInsets.CoreUISafeInsets and populationLabel.Parent == backdrop,
			"safe-area mobile header " .. tag)
		check(status.x >= 0 and status.y >= 0 and status.x + status.w <= safeSize.X
			and status.y + status.h <= safeSize.Y, "status stays below Core UI and within safe bounds " .. tag)
		check(math.abs(status.x + status.w * 0.5 - safeSize.X * 0.5) < 0.01,
			"status centered " .. tag)
		local heading = bounds(backdrop.GarageStep)
		check(status.y >= heading.y + heading.h + 2, "status below step header " .. tag)
		for _, item in backdrop:GetChildren() do
			if item == backdrop.PreviousChoice or item == backdrop.NextChoice
				or item == backdrop.SelectionPreview or item == backdrop.TrackPreview
				or item == presencePanel
				or item.ClassName == "TextButton" or item == backdrop.GarageStep
				or (item.ClassName == "TextLabel" and string.sub(item.Text or "", 1, 8) == "BUILD PV") then
				check(not intersects(status, bounds(item)), "status clears " .. item.Name .. " " .. tag)
				if item ~= presencePanel then
					check(not intersects(lobby, bounds(item)), "local Lobby clears " .. item.Name .. " " .. tag)
				end
			end
			if item.ClassName == "TextLabel" and item ~= populationLabel then
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
	camera:GetPropertyChangedSignal("ViewportSize"):Fire()
	populationRemote.OnClientEvent:Fire({ online = 50, lobby = 38, inRace = 12 })
	check(populationLabel.Parent == presencePanel and populationLabel.TextSize == 12
		and populationLabel.Text == "KDM ONLINE 50\nLOBBY 38 • IN RACE 12", "desktop restored step " .. step)
	-- SELECT is the only button whose text changes neither with the step nor the track.
	for _, item in backdrop:GetChildren() do if item.Text == "SELECT" then selectButton = item end end
	if step < 4 then selectButton.Activated:Fire() end
end
local roomUiSource = fs.readFile("src/client/MatchRoomUiController.luau")
local roomDisplayOrder = tonumber(string.match(roomUiSource, "gui.DisplayOrder = (%d+)"))
check(roomDisplayOrder and roomDisplayOrder > gui.DisplayOrder, "Room modal remains above Garage population GUI")
safeSize = rb.Vector2.new(812, 332); input.TouchEnabled = true
camera.ViewportSize = rb.Vector2.new(844, 390); camera:GetPropertyChangedSignal("ViewportSize"):Fire()
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
print("PASS: " .. count .. " Garage transition and scrolling presence checks")
