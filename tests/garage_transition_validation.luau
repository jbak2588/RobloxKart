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
local function rows()
	local found = {}
	for _, item in list:GetChildren() do if item.ClassName == "TextLabel" then table.insert(found, item) end end
	return found
end
check(list.ClassName == "ScrollingFrame" and list.ScrollingDirection == rb.Enum.ScrollingDirection.Y
	and presencePanel.Size.Y.Offset == 62, "mobile presence uses fixed-height vertical scrolling")
local function addPlayer(index)
	local other = object("Player", "Player" .. index)
	other.UserId = index; other.DisplayName = "Racer " .. index
	other:SetAttribute("RaceState", "GARAGE")
	table.insert(players, other)
	playersService.PlayerAdded:Fire(other)
	return other
end
local second, third = addPlayer(2), addPlayer(3)
check(#rows() == 3 and presencePanel:FindFirstChild("TextLabel").Text == "ONLINE 3"
	and list.CanvasSize.Y.Offset > list.Size.Y.Offset,
	"three online names are represented and the third is reachable by scroll")
for index = 4, 10 do addPlayer(index) end
check(#rows() == 10 and list.CanvasSize.Y.Offset == modules.GaragePresence.canvasHeight(10, 16, 2)
	and presencePanel.Size.Y.Offset == 62, "ten players fit fixed mobile panel with scroll canvas")
for index = 11, 50 do addPlayer(index) end
check(#rows() == 50 and list.CanvasSize.Y.Offset == modules.GaragePresence.canvasHeight(50, 16, 2)
	and presencePanel.Size.Y.Offset == 62, "50 players remain represented without expanding panel")
list.CanvasPosition = rb.Vector2.new(0, 120)
third:SetAttribute("RaceState", "RACING")
check(#rows() == 50 and list.CanvasPosition.Y == 120,
	"RaceState update retains presence rows and scroll position")
local index = table.find(players, second); table.remove(players, index)
playersService.PlayerRemoving:Fire(second)
check(#rows() == 49 and list:FindFirstChild("Player2") == nil, "PlayerRemoving deletes only departed row")
safeSize = rb.Vector2.new(1280, 720); input.TouchEnabled = false
camera.ViewportSize = safeSize
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
check(presencePanel.Size.Y.Offset == 121 and list.CanvasSize.Y.Offset == modules.GaragePresence.canvasHeight(49, 20, 2),
	"desktop shows four rows with all remaining players scrollable")
check(string.find(list.Player3.Text, "RACING", 1, true) ~= nil,
	"desktop presence updates the changed racer status")
safeSize = rb.Vector2.new(844, 390); input.TouchEnabled = true
camera.ViewportSize = safeSize
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
local selectButton = backdrop:FindFirstChild("TextButton", true)
for _ = 1, 3 do
	-- SELECT is the only button whose text changes neither with the step nor the track.
	for _, item in backdrop:GetChildren() do if item.Text == "SELECT" then selectButton = item end end
	selectButton.Activated:Fire()
end
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
