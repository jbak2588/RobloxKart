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
	RaceConfig = luau.load(fs.readFile("src/shared/RaceConfig.luau"))(),
	ChaseCameraMotion = luau.load(fs.readFile("src/shared/ChaseCameraMotion.luau"))()}
modules.KDMSpeedSensation = luau.load(fs.readFile("src/shared/KDMSpeedSensation.luau"))()
modules.FinishCameraComposition = luau.load(fs.readFile("src/client/FinishCameraComposition.luau"),
	{environment = {Vector3 = rb.Vector3}})()
local touchPreferred = false
check(modules.RaceConfig.TARGET_FINISH_SCREEN_X == 0.70,
	"ROLL retains approved 70 percent target")
check(modules.RaceConfig.MOBILE_FINISH_PRESENT_SCREEN_X == 0.64,
	"mobile PRESENT owns separate approved 64 percent target")
modules.KartInputController = {isTouchPreferred = function() return touchPreferred end}
local client = {WaitForChild = function(_, name) return {Name = name} end}
local shared = {WaitForChild = function(_, name) return {Name = name} end}
local replicated = {WaitForChild = function(_, name) assert(name == "Shared"); return shared end}
local chassis = {Position = rb.Vector3.zero, CFrame = rb.CFrame.identity,
	AssemblyLinearVelocity = rb.Vector3.zero, Parent = true}
function chassis:IsA(name) return name == "BasePart" end
local kart = {PrimaryPart = chassis, Parent = true}
kart.attrs = {}
function kart:GetAttribute(name) return self.attrs[name] end
chassis.Parent = kart
function kart:IsA(name) return name == "Model" end
local seat = {Parent = kart}
function seat:GetAttribute(name) return name == "PrototypeKartSeat" end
local humanoid = {SeatPart = seat, Seated = signal()}
function humanoid:GetPropertyChangedSignal() return signal() end
local character = {}
function character:WaitForChild(name) assert(name == "Humanoid"); return humanoid end
local player = {Character = character, CharacterAdded = signal(), CharacterRemoving = signal(), OnTeleport = signal(),
	attrs = {RaceState = "RACING", RaceFinishPhase = "NONE"}}
function player:GetAttribute(name) return self.attrs[name] end
local safeWidth = 1280
function player:FindFirstChildOfClass(name)
	if name == "PlayerGui" then return {FindFirstChild = function(_, childName)
		if childName == "RobloxKartRaceHud" then return {AbsoluteSize = rb.Vector2.new(safeWidth,320)} end
	end} end
end
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
local expectedDesktop = rb.CFrame.lookAt(rb.Vector3.new(2.5,4.5,-11),rb.Vector3.new(0,2.25,0))
check((desktopFront.Position-expectedDesktop.Position).Magnitude<0.001
	and (desktopFront.LookVector-expectedDesktop.LookVector).Magnitude<0.001,
	"desktop front composition remains unchanged")
player.attrs.RaceState = "COUNTDOWN"
player.attrs.RaceFinishPhase = "NONE"
render(0.1)
touchPreferred = true
camera.ViewportSize = rb.Vector2.new(800, 320)
safeWidth = 800
player.attrs.RaceState = "RACING"
render(0.1)
player.attrs.RaceState = "FINISHING"
player.attrs.RaceFinishPhase = "ROLL"
local function screenX()
	-- Lune's CFrame.lookAt basis differs from Studio; project using the same
	-- position/focus vectors passed to the production camera instead.
	local position = camera.CFrame.Position
	local forward = (camera.Focus.Position-position).Unit
	local right = forward:Cross(rb.Vector3.yAxis).Unit
	local subject = rb.Vector3.new(0,2.25,0)-position
	local tangent = math.tan(math.rad(camera.FieldOfView)*0.5)*camera.ViewportSize.X/camera.ViewportSize.Y
	return 0.5 + subject:Dot(right)/(subject:Dot(forward)*tangent*2)
end
for _ = 1, 48 do render(1/60) end
check(math.abs(screenX()-0.5)<0.03,"early mobile ROLL keeps kart near center")
for _ = 1, 96 do render(1/60) end
check(screenX()>0.66 and screenX()<0.74,"late ROLL settles kart near right target")
player.attrs.RaceFinishPhase = "PRESENT"
render(0.45)
check(camera.CFrame.Position.Z> -11,"PRESENT transitions from shifted chase to front")
render(0.45)
player.attrs.RaceState = "FINISHED"
render(0.1)
check(math.abs(screenX()-modules.RaceConfig.MOBILE_FINISH_PRESENT_SCREEN_X)<0.015,
	"FINISHED holds mobile PRESENT target rather than ROLL target")
check(camera.CFrame.Position.Y == 4.5 and camera.Focus.Position.Y == 2.25
	and camera.FieldOfView == 75,"mobile PRESENT preserves vertical camera and FOV")
camera.ViewportSize = rb.Vector2.new(932, 430)
safeWidth = 932
render(0.1)
check(math.abs(screenX()-modules.RaceConfig.MOBILE_FINISH_PRESENT_SCREEN_X)<0.015,
	"wide phone aspect keeps PRESENT composition")
safeWidth = 720
render(0.1)
check(math.abs(screenX()-modules.RaceConfig.MOBILE_FINISH_PRESENT_SCREEN_X)<0.015,
	"720 safe-width boundary uses mobile PRESENT target")
safeWidth = 719
render(0.1)
check(math.abs(screenX()-0.5)<0.03,"below 720 safe-width remains centered")
camera.ViewportSize = rb.Vector2.new(430,932)
safeWidth = 932
render(0.1)
check(math.abs(screenX()-0.5)<0.03,"portrait touch keeps approved front fallback")
camera.ViewportSize = rb.Vector2.new(640, 360)
safeWidth = 640
render(0.1)
check(math.abs(screenX()-0.5)<0.03,"narrow touch view keeps centered fallback")
camera.ViewportSize = rb.Vector2.new(800, 320)
render(0.1)
check(math.abs(screenX()-0.5)<0.03,"safe-width fallback matches centered mobile HUD")
touchPreferred = false
camera.ViewportSize = rb.Vector2.new(1280, 720)
safeWidth = 1280
render(0.1)
check((camera.CFrame.Position-desktopFront.Position).Magnitude<0.001,
	"switching to desktop restores approved front position")
check((camera.CFrame.LookVector-desktopFront.LookVector).Magnitude<0.001,
	"switching to desktop restores approved front orientation")
check(chassis.Position == rb.Vector3.zero and chassis.CFrame == rb.CFrame.identity,
	"mobile composition never writes kart world transform")
player.attrs.RaceState = "PRE_RACE"
player.attrs.RaceFinishPhase = "NONE"
render(0.1)
check(camera.CFrame.Position.Z > 10, "Solo Rematch waiting restores chase")
player.attrs.RaceState = "COUNTDOWN"
render(0.1)
check(camera.CFrame.Position.Z > 10, "waiting to countdown retains chase")
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
