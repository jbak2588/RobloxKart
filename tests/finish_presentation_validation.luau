-- lune run tests/finish_presentation_validation.luau
-- Runs the production camera controller against a seated kart and race phases.
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local count = 0
local function check(value, name) assert(value, name); count += 1 end
local function signal()
	local listeners = {}
	return {Connect = function(_, callback)
		table.insert(listeners, callback)
		return {Disconnect = function() end}
	end, Fire = function(_, ...)
		for _, callback in listeners do callback(...) end
	end}
end
local modules = {KartConfig = {CAMERA_DISTANCE = 18, CAMERA_HEIGHT = 8,
	CAMERA_LOOK_AHEAD = 12, CAMERA_RESPONSE = 6, CAMERA_FOV = 75},
	RaceConfig = {FINISH_CAMERA_TRANSITION_SECONDS = 0.9},
	ChaseCameraMotion = luau.load(fs.readFile("src/shared/ChaseCameraMotion.luau"))()}
local touchPreferred = false
modules.KartInputController = {isTouchPreferred = function() return touchPreferred end}
local client = {WaitForChild = function(_, name) return {Name = name} end}
local shared = {WaitForChild = function(_, name) return {Name = name} end}
local replicated = {WaitForChild = function(_, name) assert(name == "Shared"); return shared end}
local chassis = {Position = rb.Vector3.zero, CFrame = rb.CFrame.identity,
	AssemblyLinearVelocity = rb.Vector3.zero, Parent = true}
function chassis:IsA(name) return name == "BasePart" end
local kart = {PrimaryPart = chassis, Parent = true}
function kart:IsA(name) return name == "Model" end
local seat = {Parent = kart}
function seat:GetAttribute(name) return name == "PrototypeKartSeat" end
local humanoid = {SeatPart = seat, Seated = signal()}
function humanoid:GetPropertyChangedSignal() return signal() end
local character = {}
function character:WaitForChild(name) assert(name == "Humanoid"); return humanoid end
local player = {Character = character, CharacterAdded = signal(), CharacterRemoving = signal(),
	attrs = {RaceState = "RACING", RaceFinishPhase = "NONE"}}
function player:GetAttribute(name) return self.attrs[name] end
local camera = {CameraType = rb.Enum.CameraType.Custom, FieldOfView = 70,
	CFrame = rb.CFrame.identity, Focus = rb.CFrame.identity, ViewportSize = rb.Vector2.new(1280, 720)}
local workspace = {CurrentCamera = camera}
local render
local runService = {Heartbeat = signal(), BindToRenderStep = function(_, _, _, callback) render = callback end,
	UnbindFromRenderStep = function() render = nil end}
local services = {Players = {LocalPlayer = player}, ReplicatedStorage = replicated,
	RunService = runService, Workspace = workspace}
local controller = luau.load(fs.readFile("src/client/KartCameraController.luau"), {environment = {
	game = {GetService = function(_, name) return services[name] end},
	require = function(module) return assert(modules[module.Name], module.Name) end,
	Vector3 = rb.Vector3, CFrame = rb.CFrame, Enum = rb.Enum,
	script = {Parent = client},
	task = {spawn = function(callback, ...) callback(...) end,
		defer = function(callback, ...) callback(...) end},
}})()
controller.start()
check(render ~= nil, "seated kart owns camera")
render(1 / 60)
check(camera.CFrame.Position.Z > 10, "RACING uses rear chase")
player.attrs.RaceState = "FINISHING"
player.attrs.RaceFinishPhase = "ROLL"
render(0.3)
check(camera.CFrame.Position.Z > 10, "ROLL retains rear chase")
player.attrs.RaceFinishPhase = "PRESENT"
local start = camera.CFrame
render(0.3)
check(camera.CFrame ~= start and camera.CFrame.Position.Z > -11,
	"PRESENT moves smoothly from captured chase pose")
render(0.6)
check(camera.CFrame.Position.Z < -10, "transition reaches front of kart")
player.attrs.RaceState = "FINISHED"
render(0.2)
check(camera.CFrame.Position.Z < -10 and camera.CameraType == rb.Enum.CameraType.Scriptable,
	"FINISHED holds front camera")
local desktopFront = camera.CFrame
touchPreferred = true
camera.ViewportSize = rb.Vector2.new(800, 320)
render(0.1)
check(camera.CFrame.Position == desktopFront.Position and camera.CFrame.LookVector ~= desktopFront.LookVector,
	"touch finish offsets composition without moving desktop camera position")
camera.ViewportSize = rb.Vector2.new(640, 360)
render(0.1)
check((camera.CFrame.LookVector-desktopFront.LookVector).Magnitude<0.001,
	"narrow touch view keeps centered fallback")
touchPreferred = false
camera.ViewportSize = rb.Vector2.new(1280, 720)
player.attrs.RaceState = "COUNTDOWN"
player.attrs.RaceFinishPhase = "NONE"
render(0.1)
check(camera.CFrame.Position.Z > 10, "Rematch restores chase")
player.attrs.RaceState = "FINISHED"
player.attrs.RaceFinishPhase = "PRESENT"
render(1)
player.attrs.RaceState = "GARAGE"
player.attrs.RaceFinishPhase = "NONE"
render(0.1)
check(camera.CFrame.Position.Z > 10, "Garage clears front camera")
humanoid.SeatPart = nil
runService.Heartbeat:Fire(0.25)
check(render == nil and camera.CameraType == rb.Enum.CameraType.Custom,
	"seat loss restores Custom camera")
player.CharacterRemoving:Fire()
check(render == nil and camera.CameraType == rb.Enum.CameraType.Custom,
	"character removal keeps Custom fallback")
print("PASS: " .. count .. " production finish camera lifecycle checks")
