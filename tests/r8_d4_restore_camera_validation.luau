local fs,luau,rb=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local function trace(cameraSource,touch,dt)
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
modules.DriftCameraHeading = luau.load(fs.readFile("src/shared/DriftCameraHeading.luau"),
	{environment={Vector3=rb.Vector3,CFrame=rb.CFrame}})()
local balance=luau.load(fs.readFile('src/shared/KDMGameplayBalance.luau'))()
modules.KartConfig=luau.load(fs.readFile('src/shared/KartConfig.luau'),
	{environment={script={Parent={WaitForChild=function()end}},require=function()return balance end}})()
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
function kart:FindFirstChild() return nil end
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
	IsStudio = function() return false end,
	UnbindFromRenderStep = function() render = nil end}
local services = {Players = {LocalPlayer = player}, ReplicatedStorage = replicated,
	RunService = runService, Workspace = workspace}
local controller = luau.load(cameraSource, {environment = {
	game = {GetService = function(_, name) return services[name] end},
	require = function(module) return assert(modules[module.Name], module.Name) end,
	Vector3 = rb.Vector3, CFrame = rb.CFrame, Enum = rb.Enum,
	script = {Parent = client}, time=function()return 0 end,
	task = {spawn = function(callback, ...) callback(...) end,
		defer = function(callback, ...) callback(...) end},
}})()

controller.start();touchPreferred=touch;player.attrs.RaceState="RACING"
local rows={}
for i=1,600 do
 local t=i*dt;local yaw=.3*t;local cf=rb.CFrame.new(20*math.sin(t),0,-50*t)*rb.CFrame.Angles(0,yaw,0)
 chassis.Position=cf.Position;chassis.CFrame=cf
 kart.attrs.KartDrifting=i>=60 and i<300
 kart.attrs.KartBoosting=i>=300 and i<420
 local slip=if kart.attrs.KartDrifting then math.rad(-41) else 0
 chassis.AssemblyLinearVelocity=cf:VectorToWorldSpace(rb.Vector3.new(-64*math.sin(slip),0,-64*math.cos(slip)))
 render(dt);table.insert(rows,{camera.CFrame,camera.FieldOfView,camera.Focus})
end
return rows
end
local a=fs.readFile("tests/fixtures/r8_d4_pv633_camera.luau")
local b=fs.readFile("src/client/KartCameraController.luau")
local n=0
for _,touch in {false,true}do for _,rate in {30,60,120}do
 local x,y=trace(a,touch,1/rate),trace(b,touch,1/rate)
 for i=1,#x do assert(x[i][1]==y[i][1] and x[i][2]==y[i][2] and x[i][3]==y[i][3],"PV633 camera trajectory mismatch");n+=1 end
end end
print("PASS: "..n.." exact production camera frames match PV633 across PC/mobile normal/drift/exit/boost")
