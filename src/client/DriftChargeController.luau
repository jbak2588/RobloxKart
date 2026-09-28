-- One display for every input type; it never sends gameplay actions.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local Config=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KartConfig"))
local Input=require(script.Parent:WaitForChild("KartInputController"))
local View=require(script.Parent:WaitForChild("DriftChargeView"))
local Controller={}
local started=false

function Controller.start()
	if started then return end
	started=true
	local player=Players.LocalPlayer
	local gui=Instance.new("ScreenGui")
	gui.Name="RobloxKartDriftCharge"
	gui.ResetOnSpawn=false
	gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder=11
	gui.Parent=player:WaitForChild("PlayerGui")
	local root=Instance.new("Frame")
	root.Name="SharedDriftDisplay"
	root.Size=UDim2.fromScale(1,1)
	root.BackgroundTransparency=1
	root.Active=false
	root.Selectable=false
	root.Parent=gui
	local view=View.create(root,Config.DEBUG_TELEMETRY,player)
	local connections={}
	local focused,removing=true,false
	local previousKart,previousSerial,previousRace=nil,nil,nil
	local function connect(event,callback) table.insert(connections,event:Connect(callback)) end
	local function reset() view:reset(previousKart) end
	connect(UserInputService.WindowFocusReleased,function() focused=false;reset() end)
	connect(UserInputService.WindowFocused,function() focused=true end)
	connect(player.CharacterRemoving,function() removing=true;reset() end)
	connect(player.CharacterAdded,function() removing=false;reset() end)
	connect(RunService.Heartbeat,function(delta)
		local character=not removing and player.Character
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		local seat=humanoid and humanoid.SeatPart
		local kart=if humanoid and humanoid.Health>0 and seat and seat:GetAttribute("PrototypeKartSeat")==true then seat.Parent else nil
		local race=player:GetAttribute("RaceState")
		local serial=kart and kart:GetAttribute("RaceResetSerial")
		local changed=kart~=previousKart or serial~=previousSerial or race~=previousRace
		if changed then view:reset(kart) end
		previousKart,previousSerial,previousRace=kart,serial,race
		local hud=player.PlayerGui:FindFirstChild("RobloxKartRaceHud")
		if hud then gui.ScreenInsets=hud.ScreenInsets end
		local mobile=Input.isTouchPreferred()
		local wheel=not mobile and hud and hud:FindFirstChild("SteeringDisplay",true)
		view:layout(root.AbsoluteSize,mobile,wheel,root.AbsolutePosition)
		local enabled=gui.Enabled and focused and not GuiService.MenuIsOpen
			and UserInputService:GetFocusedTextBox()==nil and kart~=nil and race=="RACING"
			and kart:GetAttribute("RaceControlsLocked")~=true
		view:update(enabled,kart,mobile and Input.isTouchDriftHeld(),delta)
	end)
	connect(gui.Destroying,function()
		reset()
		for _,connection in connections do connection:Disconnect() end
		started=false
	end)
end

return Controller
