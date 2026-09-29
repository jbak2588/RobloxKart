local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchRoomUiController = {}
local started = false

local function label(parent, name, size, position, text, fontSize)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.Size = size
	item.Position = position
	item.BackgroundTransparency = 1
	item.TextColor3 = Color3.fromRGB(245, 246, 250)
	item.TextSize = fontSize or 20
	item.Font = Enum.Font.GothamBold
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Text = text
	item.Parent = parent
	return item
end

local function button(parent, text, position, size, callback)
	local item = Instance.new("TextButton")
	item.Size = size
	item.Position = position
	item.BackgroundColor3 = Color3.fromRGB(43, 128, 226)
	item.BorderSizePixel = 0
	item.Text = text
	item.TextColor3 = Color3.new(1, 1, 1)
	item.TextSize = 18
	item.Font = Enum.Font.GothamBold
	item.Parent = parent
	item.Activated:Connect(callback)
	return item
end

function MatchRoomUiController.start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local remote = ReplicatedStorage:WaitForChild("MatchRoomControl")
	local gui = Instance.new("ScreenGui")
	gui.Name = "KDMMatchRooms"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(8, 15, 26)
	shade.BackgroundTransparency = 0.1
	shade.Parent = gui
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.9, 0, 0.8, 0)
	panel.BackgroundColor3 = Color3.fromRGB(18, 29, 44)
	panel.Parent = shade
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(650, 650)
	constraint.Parent = panel
	local title = label(panel, "Title", UDim2.new(1, -32, 0, 48), UDim2.fromOffset(16, 10), "BASE CIRCUIT ROOMS", 26)
	title.TextColor3 = Color3.fromRGB(255, 218, 73)
	local status = label(panel, "Status", UDim2.new(1, -32, 0, 38), UDim2.fromOffset(16, 55), "", 17)
	local list = Instance.new("ScrollingFrame")
	list.Name = "RoomList"
	list.Position = UDim2.new(0, 16, 0, 100)
	list.Size = UDim2.new(1, -32, 1, -182)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list
	local primary = button(panel, "CREATE ROOM", UDim2.new(0, 16, 1, -68), UDim2.new(0.48, -20, 0, 52), function() end)
	local back = button(panel, "BACK", UDim2.new(0.52, 0, 1, -68), UDim2.new(0.48, -16, 0, 52), function() end)
	back.BackgroundColor3 = Color3.fromRGB(84, 68, 75)
	local primaryConnection, backConnection
	local function bindButtons(primaryText, primaryAction, backText, backAction)
		if primaryConnection then primaryConnection:Disconnect() end
		if backConnection then backConnection:Disconnect() end
		primary.Text = primaryText
		back.Text = backText
		primaryConnection = primary.Activated:Connect(primaryAction)
		backConnection = back.Activated:Connect(backAction)
	end
	local function clearRows()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then child:Destroy() end
		end
	end
	local function row(text, actionText, callback)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, -8, 0, 56)
		frame.BackgroundColor3 = Color3.fromRGB(29, 44, 62)
		frame.Parent = list
		label(frame, "Name", UDim2.new(0.63, -8, 1, 0), UDim2.fromOffset(10, 0), text, 16)
		if actionText then
			button(frame, actionText, UDim2.new(0.66, 0, 0, 5), UDim2.new(0.32, 0, 1, -10), callback)
		end
	end
	local invitation
	local snapshot
	local function render()
		clearRows()
		gui.Enabled = ((snapshot and snapshot.visible == true) or invitation ~= nil)
			and player:GetAttribute("KDMRoutePending") ~= "RACE_LAUNCH"
		if not gui.Enabled then return end
		if invitation and (not snapshot or not snapshot.room) then
			title.Text = "RACE INVITE"
			status.Text = string.format("%s invited you to Base Circuit  •  %d / %d",
				invitation.hostName, invitation.count, invitation.maxPlayers)
			bindButtons(if invitation.state == "WAITING" and invitation.count < invitation.maxPlayers
				then "JOIN" else "QUEUE NEXT", function()
				remote:FireServer("AcceptInvite", player:GetAttribute("SelectedDriverId"), player:GetAttribute("SelectedKartId"))
				invitation = nil
			end, "DECLINE", function() remote:FireServer("DeclineInvite"); invitation = nil; render() end)
			return
		end
		if snapshot and snapshot.room and snapshot.room.membershipKind == "QUEUED" then
			local room = snapshot.room
			title.Text = "QUEUED FOR NEXT RACE"
			status.Text = if room.nextRoundStarting then "JOINING ROOM STAGING"
				else string.format("%s'S ROOM  •  QUEUE %d  •  CURRENT %s %d / %d",
					room.hostName, room.queuePosition or 0, room.state, room.count, room.maxPlayers)
			row(if room.nextRoundStarting then "Moving you to the starting grid..."
				else "You will join when the next round is ready.", nil, nil)
			primary.Visible = false
			back.Visible = not room.nextRoundStarting
			bindButtons("", function() end, "CANCEL QUEUE",
				function() remote:FireServer("CancelQueue") end)
		elseif snapshot and snapshot.room then
			local room = snapshot.room
			title.Text = "BASE CIRCUIT ROOM"
			status.Text = string.format("HOST: %s   RACERS %d / %d  •  %s",
				room.hostName, #room.members, room.maxPlayers,
				if room.hostUserId ~= player.UserId and room.state == "WAITING" then "WAITING FOR HOST" else room.state)
			for _, member in room.members do row(member.name, nil, nil) end
			if room.hostUserId == player.UserId then
				for _, available in room.available do
					row(available.name, "INVITE", function() remote:FireServer("Invite", available.userId) end)
				end
			end
			local host = room.hostUserId == player.UserId
			primary.Visible = host and room.state == "WAITING" and #room.members < room.maxPlayers
			back.Visible = room.state == "WAITING"
			bindButtons(if #room.members == 1 then "START SOLO" else "START RACE",
				function() remote:FireServer("Start") end, "LEAVE", function() remote:FireServer("Leave") end)
		else
			title.Text = "BASE CIRCUIT ROOMS"
			status.Text = "CREATE OR JOIN A 1–4 RACER ROOM"
			for _, room in snapshot.rooms do
				local waiting = room.state == "WAITING" and room.count < room.maxPlayers
				row(string.format("%s  •  %s  %d / %d  •  QUEUED %d",
					room.hostName, room.state, room.count, room.maxPlayers, room.queuedCount),
					if waiting then "JOIN" else "QUEUE NEXT",
					function() remote:FireServer(if waiting then "Join" else "Queue", room.id) end)
			end
			if #snapshot.rooms == 0 then row("NO ACTIVE ROOMS", nil, nil) end
			primary.Visible = true
			back.Visible = true
			bindButtons("CREATE ROOM", function() remote:FireServer("Create") end,
				"BACK", function() remote:FireServer("Back") end)
		end
	end
	remote.OnClientEvent:Connect(function(action, data)
		if action == "Snapshot" then snapshot = data; render()
		elseif action == "Invite" then invitation = data; render()
		elseif action == "Error" then status.Text = tostring(data) end
	end)
	player:GetAttributeChangedSignal("RaceState"):Connect(function()
		if player:GetAttribute("RaceState") ~= "GARAGE" then gui.Enabled = false end
	end)
	player:GetAttributeChangedSignal("KDMRoutePending"):Connect(render)
end

return MatchRoomUiController
