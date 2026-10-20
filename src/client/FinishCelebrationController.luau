-- Local bounded hero bursts and ownership of native terminal TouchGui suppression.
local Players = game:GetService("Players")
local Finish = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KDMFinishPresentation"))
local Controller = {}
local stop
function Controller.start()
	if stop then return end
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local connections, touchRecords, points = {}, {}, {}
	local seatConnection
	local alive, teleporting, terminal = true, false, false
	local sessionId, emittedSession = player:GetAttribute("RaceSessionId"), nil
	local burstSerial = 0
	local continuingWinner = false
	local function clearBurst()
		burstSerial += 1
		continuingWinner = false
		for _,point in points do point:Destroy() end
		table.clear(points)
	end
	local function releaseTouch(gui)
		local record=touchRecords[gui]
		if not record then return end
		touchRecords[gui]=nil
		record.connection:Disconnect()
		if gui.Parent then gui.Enabled=record.enabled end
	end
	local function suppressTouch(gui)
		if not terminal or gui.Name~="TouchGui" or not gui:IsA("ScreenGui") then return end
		if not touchRecords[gui] then
			local record={enabled=gui.Enabled}
			touchRecords[gui]=record
			record.connection=gui:GetPropertyChangedSignal("Enabled"):Connect(function()
				if alive and terminal and touchRecords[gui]==record and gui.Enabled then gui.Enabled=false end
			end)
		end
		gui.Enabled=false
	end
	local function restoreTouch()
		for gui in touchRecords do releaseTouch(gui) end
	end
	local function getChassis()
		local character=player.Character
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		local seat=humanoid and humanoid.SeatPart
		if not seat or seat:GetAttribute("PrototypeKartSeat")~=true then return nil end
		local kart=seat.Parent
		local chassis=kart and kart.PrimaryPart
		return if chassis and chassis:IsA("BasePart") then chassis else nil
	end
	local function update()
		if not alive then return end
		local current=player:GetAttribute("RaceSessionId")
		if current~=sessionId then clearBurst(); emittedSession=nil; sessionId=current end
		local state=player:GetAttribute("RaceState")
		terminal=not teleporting and (state=="FINISHING" or state=="FINISHED" or state=="DNF")
		if terminal then for _,gui in playerGui:GetChildren() do suppressTouch(gui) end else restoreTouch() end
		local _,_,profile=Finish.resolve(state,player:GetAttribute("RaceFinishPosition"),player:GetAttribute("RaceParticipantCount"))
		if teleporting or not profile or player:GetAttribute("RaceFinishPhase")~="PRESENT" then
			clearBurst()
			if state~="FINISHING" and state~="FINISHED" then emittedSession=nil end
			return
		end
		local chassis=getChassis()
		if not chassis then clearBurst(); return end
		if continuingWinner and player:GetAttribute("RaceWinnerAwaitingRunnerUp") ~= true then clearBurst() end
		if not sessionId or sessionId==0 or emittedSession==sessionId then return end
		emittedSession=sessionId
		clearBurst()
		local serial=burstSerial
		local repeatWinner=profile==Finish.Profiles.WINNER
		local gold=Color3.fromRGB(255,218,75)
		local cyan=Color3.fromRGB(125,235,255)
		for index=1,2 do
			local point=Instance.new("Attachment")
			point.Name="KDMFinishBurst"..index
			point.Position=Vector3.new(if index==1 then -2.2 else 2.2,4.2,-.3)
			point.Parent=chassis
			points[index]=point
			local emitter=Instance.new("ParticleEmitter")
			emitter.Name="KDMFinishSparkles"
			emitter.Texture="rbxasset://textures/particles/sparkles_main.dds"
			emitter.Enabled=false;emitter.Rate=0
			emitter.EmissionDirection=Enum.NormalId.Top
			emitter.Orientation=Enum.ParticleOrientation.FacingCamera
			emitter.Lifetime=NumberRange.new(profile.LifetimeMin,profile.LifetimeMax)
			emitter.Speed=NumberRange.new(profile.SpeedMin,profile.SpeedMax)
			emitter.SpreadAngle=Vector2.new(40,40)
			emitter.Acceleration=Vector3.new(0,-4,0)
			emitter.LightEmission=profile.LightEmission;emitter.LightInfluence=0
			emitter.LockedToPart=false
			emitter.Color=ColorSequence.new(if profile==Finish.Profiles.WINNER then gold else cyan,Color3.new(1,1,1))
			emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,profile.Size),NumberSequenceKeypoint.new(1,0)})
			emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.12),NumberSequenceKeypoint.new(.7,.35),NumberSequenceKeypoint.new(1,1)})
			emitter.Parent=point
			emitter:Emit(if index==1 then profile.PrimaryCount else profile.SecondaryCount)
			if repeatWinner then
				-- Two small refreshes stay visible through the front-camera transition/wave.
				-- Base presentation: three bursts of 32; a waiting winner extends below.
				for pulse=1,2 do
					task.delay(profile.WaveSeconds*pulse/3,function()
						if alive and serial==burstSerial and emitter.Parent then
							emitter:Emit(if index==1 then profile.PrimaryCount else profile.SecondaryCount)
						end
					end)
				end
			end
		end
		if repeatWinner then
			local function continueWinner()
				if not alive or serial~=burstSerial then return end
				if player:GetAttribute("RaceWinnerAwaitingRunnerUp") ~= true then
					if continuingWinner then clearBurst() end
					return
				end
				if getChassis()~=chassis then clearBurst(); return end
				continuingWinner=true
				-- Reuse two emitters, 32 particles per pulse; one pending timer, no frame loop.
				for index,point in points do
					local emitter=point:FindFirstChild("KDMFinishSparkles")
					if emitter then emitter:Emit(if index==1 then profile.PrimaryCount else profile.SecondaryCount) end
				end
				task.delay(profile.WaveSeconds/3,continueWinner)
			end
			task.delay(profile.WaveSeconds,continueWinner)
		end
		local lastPulse=if repeatWinner then profile.WaveSeconds*2/3 else 0
		task.delay(lastPulse+profile.LifetimeMax+.1,function()
			if alive and serial==burstSerial and not continuingWinner then clearBurst() end
		end)
	end
	local function bindCharacter(character)
		clearBurst()
		if seatConnection then seatConnection:Disconnect();seatConnection=nil end
		local humanoid=character:WaitForChild("Humanoid")
		seatConnection=humanoid:GetPropertyChangedSignal("SeatPart"):Connect(update)
		update()
	end
	for _,name in {"RaceState","RaceFinishPhase","RaceFinishPosition","RaceParticipantCount","RaceSessionId","RaceWinnerAwaitingRunnerUp"} do
		table.insert(connections,player:GetAttributeChangedSignal(name):Connect(update))
	end
	table.insert(connections,playerGui.ChildAdded:Connect(suppressTouch))
	table.insert(connections,playerGui.ChildRemoved:Connect(releaseTouch))
	table.insert(connections,player.CharacterAdded:Connect(bindCharacter))
	table.insert(connections,player.CharacterRemoving:Connect(function()
		clearBurst();if seatConnection then seatConnection:Disconnect();seatConnection=nil end
	end))
	table.insert(connections,player.OnTeleport:Connect(function(state)
		teleporting=state~=Enum.TeleportState.Failed;update()
	end))
	stop=function()
		alive=false;terminal=false;clearBurst();restoreTouch()
		if seatConnection then seatConnection:Disconnect() end
		for _,connection in connections do connection:Disconnect() end
		stop=nil
	end
	if player.Character then bindCharacter(player.Character) else update() end
end
function Controller.destroy() if stop then stop() end end
return Controller
