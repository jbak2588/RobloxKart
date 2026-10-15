local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoomDisplay = require(script.Parent:WaitForChild("RoomDisplay"))
local GuidanceState = require(script.Parent:WaitForChild("HubGuidanceState"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KDMUiTheme"))
local Titles = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyTitleCatalog"))
local LobbyCreateView = require(script.Parent:WaitForChild("LobbyCreateView"))
local MatchRoomUiController = {}
local started = false

local function label(parent, name, size, position, text, fontSize)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.Size = size
	item.Position = position
	item.BackgroundTransparency = 1
	item.TextColor3 = Theme.TextPrimary
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
	item.BackgroundColor3 = Theme.Panel
	item.BorderSizePixel = 0
	item.Text = text
	item.TextColor3 = Theme.TextPrimary
	item.TextSize = 19
	item.Font = Enum.Font.GothamBold
	item.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0,8);corner.Parent = item
	local stroke = Instance.new("UIStroke")
	stroke.Color,stroke.Thickness,stroke.Transparency = Theme.TextSecondary,1.5,.65
	stroke.ApplyStrokeMode,stroke.Parent = Enum.ApplyStrokeMode.Border,item
	item.TextWrapped = true
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
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 30
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local shade = Instance.new("Frame")
	shade.Name = "Overlay"
	shade.Active = true
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Theme.Background
	shade.BackgroundTransparency = 0.80
	shade.Parent = gui
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.9, 0, 0.9, 0)
	panel.BackgroundColor3 = Theme.Panel
	panel.BorderSizePixel = 0
	panel.Parent = shade
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0,12);panelCorner.Parent = panel
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color,panelStroke.Transparency,panelStroke.Parent = Theme.TextSecondary,.65,panel
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(650, 650)
	constraint.Parent = panel
	local title = label(panel, "Title", UDim2.new(1, -32, 0, 36), UDim2.fromOffset(16, 4), "RACE LIST", 22)
	title.TextColor3 = Theme.TextPrimary
	local status = label(panel, "Status", UDim2.new(1, -32, 0, 30), UDim2.fromOffset(16, 40), "", 14)
 local guidance = label(panel, "NextAction", UDim2.new(1,-32,0,24), UDim2.fromOffset(16,70), "", 12)
 guidance.AutoLocalize, guidance.TextWrapped, guidance.TextColor3 = true, true, Theme.TextSecondary
 status.TextColor3 = Theme.TextSecondary
	local list = Instance.new("ScrollingFrame")
	list.Name = "RoomList"
	list.Position = UDim2.new(0, 16, 0, 96)
	list.Size = UDim2.new(1, -32, 1, -162)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list
	local primary = button(panel, "CREATE RACE", UDim2.new(0, 16, 1, -60), UDim2.new(0.48, -20, 0, 52), function() end)
	local back = button(panel, "BACK", UDim2.new(0.52, 0, 1, -60), UDim2.new(0.48, -16, 0, 52), function() end)
	back.BackgroundColor3 = Theme.Panel
 primary.BackgroundColor3, primary.TextColor3 = Theme.PrimaryAction, Theme.Background
 local createView
	local primaryConnection, backConnection
	local function bindButtons(primaryText, primaryAction, backText, backAction)
		if primaryConnection then primaryConnection:Disconnect() end
		if backConnection then backConnection:Disconnect() end
		primary.Text = primaryText
		back.Text = backText
  back.BackgroundColor3 = if backText == "LEAVE" then Theme.Danger else Theme.Panel
		primaryConnection = primary.Activated:Connect(function()
   if createView and createView.isOpen() then return end
   primaryAction()
  end)
		backConnection = back.Activated:Connect(function()
   if createView and createView.isOpen() then return end
   backAction()
  end)
	end
	local function clearRows()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then child:Destroy() end
		end
	end
	local function row(text, actionText, callback, detail, identity)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, -8, 0, 56)
		frame.BackgroundColor3 = Theme.Panel
		frame.Parent = list
		local name=label(frame,"Name",UDim2.new(0.63,-8,0,if detail then 26 else 56),UDim2.fromOffset(10,0),text,16)
		name.AutoLocalize=not identity;name.TextTruncate=Enum.TextTruncate.AtEnd
		if detail then
			local metadata=label(frame,"Detail",UDim2.new(.63,-8,0,26),UDim2.fromOffset(10,26),detail,12)
			metadata.TextColor3=Theme.TextSecondary;metadata.TextTruncate=Enum.TextTruncate.AtEnd
		end
		if actionText then
			button(frame, actionText, UDim2.new(0.66, 0, 0, 5), UDim2.new(0.32, 0, 1, -10), function()
    if createView and createView.isOpen() then return end
    callback()
   end)
		end
	end
	local invitation
	local snapshot
	local pendingAction, errorMessage, pendingSerial = nil, nil, 0
	local render
	local function send(action, ...)
		if pendingAction then return end
		pendingAction = action
		errorMessage = nil
		pendingSerial += 1
		local serial = pendingSerial
		remote:FireServer(action, ...)
		render()
		task.delay(15, function()
			if pendingSerial == serial and pendingAction then
				pendingAction = nil
				errorMessage = "RACE LIST UPDATING..."
				render()
			end
		end)
	end
	createView=LobbyCreateView.new(panel,function(mode,value) send("Create",mode,value) end)
	render = function()
		clearRows()
  status.TextColor3 = Theme.TextSecondary
  guidance.Text = GuidanceState.roomHelper(snapshot, player.UserId)
  guidance.Visible = pendingAction == nil and invitation == nil and snapshot ~= nil and snapshot.room ~= nil
   and player:GetAttribute("RaceState") == "GARAGE"
		gui.Enabled = ((snapshot and snapshot.visible == true) or invitation ~= nil)
			and player:GetAttribute("KDMRoutePending") ~= "RACE_LAUNCH"
   and player:GetAttribute("RaceState") == "GARAGE"
		if not gui.Enabled then createView.close();return end
		title.AutoLocalize=true
		if pendingAction then
			status.Text = ({ Create = "CREATING RACE...", Join = "ENTERING RACE...",
				Queue = "JOINING QUEUE...", AcceptInvite = "ENTERING RACE...",
				CancelQueue = "CANCELING QUEUE..." })[pendingAction] or "JOINING RACE..."
			primary.Active = false
			back.Active = false
			return
		end
		primary.Active = true
		back.Active = true
		if invitation and (not snapshot or not snapshot.room) then
			title.Text = "RACE INVITE"
			status.Text = string.format("%s invited you to",invitation.hostName)
			row(Titles.publicTitle(invitation),nil,nil,string.format("RACERS %d / %d",invitation.count,invitation.maxPlayers),true)
			bindButtons(if invitation.state == "WAITING" and invitation.count < invitation.maxPlayers
				then "JOIN" else "QUEUE NEXT", function()
				send("AcceptInvite", player:GetAttribute("SelectedDriverId"), player:GetAttribute("SelectedKartId"))
				invitation = nil
			end, "DECLINE", function() remote:FireServer("DeclineInvite"); invitation = nil; render() end)
			return
		end
		if snapshot and snapshot.room and snapshot.room.membershipKind == "QUEUED" then
			local room = snapshot.room
			title.Text = "QUEUED FOR NEXT RACE"
			status.Text = if room.nextRoundStarting then "JOINING NEXT RACE..."
				else string.format("QUEUE #%d  •  CURRENT %s %d / %d",
					room.queuePosition or 0, RoomDisplay.state(room.state), room.count, room.maxPlayers)
			row(Titles.publicTitle(room),nil,nil,nil,true)
			row(if room.nextRoundStarting then "Moving you to the starting grid..."
				else "You will join when the next round is ready.", nil, nil)
			primary.Visible = false
			back.Visible = not room.nextRoundStarting
			bindButtons("", function() end, "CANCEL QUEUE",
				function() send("CancelQueue") end)
		elseif snapshot and snapshot.room then
			local room = snapshot.room
			title.Text = Titles.publicTitle(room);title.AutoLocalize=false;title.TextTruncate=Enum.TextTruncate.AtEnd
   status.TextColor3 = if room.state == "READY" then Theme.Ready else Theme.TextSecondary
			status.Text = string.format("HOST: %s   RACERS %d / %d  •  %s",
				room.hostName, #room.members, room.maxPlayers,
				if room.hostUserId ~= player.UserId and room.state == "WAITING" then "WAITING FOR HOST" else RoomDisplay.state(room.state))
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
			title.Text = "RACE LIST"
			status.Text = if snapshot.directoryStale then "RACE LIST UPDATING..." else string.format("CREATE OR JOIN A RACE • 1–%d RACERS", snapshot.maxPlayers or 1)
			for _, room in snapshot.rooms do
				local waiting = RoomDisplay.canJoin(room)
				row(Titles.publicTitle(room),
					if waiting then "ENTER RACE" else "QUEUE NEXT",
					function() send(if waiting then "Join" else "Queue", room.id) end,
					string.format("HOST: %s • %s • %d / %d",room.hostName,RoomDisplay.state(room.state),room.count,room.maxPlayers),true)
			end
			if #snapshot.rooms == 0 then row(if snapshot.directoryStale then "RACE LIST UPDATING..." else "NO ACTIVE RACES", nil, nil) end
			primary.Visible = true
			back.Visible = true
			bindButtons("CREATE RACE", function() createView.open() end,
				"BACK", function() remote:FireServer("Back") end)
		end
  status.TextColor3 = if errorMessage then Theme.Danger else status.TextColor3
		if errorMessage then
   status.Text = errorMessage:gsub("LOBBY NAME", "RACE TITLE"):gsub("LOBBY", "RACE")
  end
	end
 local remoteConnection = remote.OnClientEvent:Connect(function(action, data)
		if action == "Snapshot" then
			snapshot = data
			local completed = (pendingAction == "Queue" and data.room ~= nil)
				or (pendingAction == "CancelQueue" and data.room == nil)
				or ((pendingAction == "Create" or pendingAction == "Join"
					or pendingAction == "AcceptInvite") and (data.visible == false or data.room ~= nil))
			if completed then pendingAction = nil; pendingSerial += 1 end
			render()
		elseif action == "Invite" then invitation = data; render()
		elseif action == "Error" then
			pendingAction = nil; pendingSerial += 1
			errorMessage = tostring(data)
			if errorMessage == "LOBBY CLOSED - CHOOSE ANOTHER LOBBY"
				or errorMessage == "INVITE EXPIRED" then invitation = nil end
			render()
		end
	end)
 local raceConnection = player:GetAttributeChangedSignal("RaceState"):Connect(function()
		if player:GetAttribute("RaceState") ~= "GARAGE" then createView.close();gui.Enabled = false end
	end)
 local routeConnection = player:GetAttributeChangedSignal("KDMRoutePending"):Connect(render)
 gui.Destroying:Connect(function()
  remoteConnection:Disconnect(); raceConnection:Disconnect(); routeConnection:Disconnect()
  if primaryConnection then primaryConnection:Disconnect() end
  if backConnection then backConnection:Disconnect() end
  pendingAction=nil; pendingSerial+=1; started=false
 end)
end

return MatchRoomUiController
