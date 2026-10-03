-- Studio-only NPC test harness. A Folder is the explicit bot state, never a Player.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Workspace=game:GetService('Workspace')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local World=require(script.Parent:WaitForChild('PrototypeWorld'))
local Session=require(script.Parent:WaitForChild('RaceSession'))
local Steering=require(script.Parent:WaitForChild('RaceBotSteering'))
local TrackCatalog=require(ReplicatedStorage.Shared.TrackCatalog)
local TrackGeometry=require(ReplicatedStorage.Shared.TrackGeometry)
local Controller={}
local active
function Controller.enabled()
	return RunService:IsStudio() and Workspace:GetAttribute('KDMEnableRaceBot')==true
end
function Controller.start()
	if active or not Controller.enabled() then return false end
	local track=TrackCatalog.Entries.Track01Race
	local course=TrackGeometry.getCourse(TrackGeometry.getDefinition(track.GeometryId))
	local folder=Instance.new('Folder');folder.Name='KDMBotRacers';folder.Parent=ReplicatedStorage
	local state=Instance.new('Folder');state.Name='Bot01';state:SetAttribute('BotId','Bot01')
	state:SetAttribute('IsBot',true);state:SetAttribute('DisplayName','KDM Rookie [BOT]')
	state:SetAttribute('ReadyOrder',2);state:SetAttribute('SelectedTrackId',track.Id);state.Parent=folder
	local npc=Players:CreateHumanoidModelFromDescription(Instance.new('HumanoidDescription'),Enum.HumanoidRigType.R15)
	npc.Name='KDM Rookie [BOT]';npc.Parent=Workspace.Prototype
	local humanoid=npc:FindFirstChildOfClass('Humanoid');humanoid.DisplayName=npc.Name
	local lift=CFrame.new(0,Workspace.Prototype.Kart:GetAttribute('RaceStartCFrame').Position.Y,0)
	local context=World.createBotKartContext(state,npc,lift*track.GridSlots[2])
	context.botControl=function()
		local command=Steering.command(course.Samples,context.chassis.CFrame)
		state:SetAttribute('BotTargetSpeed',command.targetSpeed)
		return command
	end
	npc:PivotTo(context.seat.CFrame*CFrame.new(0,2,0));humanoid.Sit=false;context.seat:Sit(humanoid)
	local record={folder=folder,state=state,npc=npc,context=context,connections={},human=nil,added=false}
	active=record
	local function enter(player)
		if active~=record or record.human then return end
		record.human=player
		task.spawn(function()
			local character=player.Character or player.CharacterAdded:Wait()
			local h=character:WaitForChild('Humanoid')
			if active~=record or not Controller.enabled() then return end
			player:SetAttribute('SelectedTrackId',track.Id);player:SetAttribute('SelectedKartId','Kart01')
			player:SetAttribute('ReadyOrder',1)
			local human=World.acquireKartContext(player,lift*track.GridSlots[1],'Kart01')
			character:PivotTo(human.seat.CFrame*CFrame.new(0,3,0));h.Sit=false
			task.wait(.25)
			if active~=record or not Controller.enabled() then return end
			human.seat:Sit(h)
			player:SetAttribute('RaceState','PRE_RACE')
		end)
	end
	table.insert(record.connections,Players.PlayerAdded:Connect(enter))
	for _,player in Players:GetPlayers() do enter(player) end
	table.insert(record.connections,RunService.Heartbeat:Connect(function()
		if not Controller.enabled() or record.human and record.human.Parent~=Players then Controller.stop();return end
		local session=Session.active()
		if record.added and (not npc.Parent or not context.kart.Parent or humanoid.Health<=0
			or context.seat.Occupant~=humanoid or not session or session:humanCount()==0) then Controller.stop();return end
		if session and record.human and session:contains(record.human) then
			if not record.added then record.added=session:addTestBot(state,context) end
			if record.added and session.phase=='WAITING' and record.human:GetAttribute('RaceItemsReady')==true then
				session:startBotTest()
			end
		end
	end))
	table.insert(record.connections,Workspace:GetAttributeChangedSignal('KDMEnableRaceBot'):Connect(function()
		if not Controller.enabled() then Controller.stop() end
	end))
	return true
end
function Controller.stop()
	local record=active;if not record then return end;active=nil
	for _,connection in record.connections do connection:Disconnect() end
	local session=Session.active();if session and record.added then session:removeTestBot(record.state) end
	World.releaseBotKartContext(record.state)
	record.npc:Destroy();record.folder:Destroy()
end
return Controller
