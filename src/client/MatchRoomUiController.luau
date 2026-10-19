local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoomDisplay = require(script.Parent:WaitForChild("RoomDisplay"))
local GuidanceState = require(script.Parent:WaitForChild("HubGuidanceState"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KDMUiTheme"))
local Titles = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyTitleCatalog"))
local LobbyCreateView = require(script.Parent:WaitForChild("LobbyCreateView"))
local StyleHelper = require(script.Parent:WaitForChild("KDMUiStyleHelper"))
local TrackCatalog=require(ReplicatedStorage.Shared:WaitForChild('TrackCatalog'))
local BrowserLayout=require(script.Parent:WaitForChild('RaceBrowserLayout'))
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
	item.Font = Enum.Font.GothamBlack
	item.TextStrokeTransparency = 0.15
	item.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	item.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0,12);corner.Parent = item
	local stroke = Instance.new("UIStroke")
	stroke.Color,stroke.Thickness = Color3.fromRGB(10, 15, 25), 2.5
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
	StyleHelper.applyModalPanel(panel)
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0,14);panelCorner.Parent = panel
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color,panelStroke.Thickness,panelStroke.Transparency = Color3.fromRGB(60, 110, 180),3,0
	panelStroke.ApplyStrokeMode,panelStroke.Parent = Enum.ApplyStrokeMode.Border,panel
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(960, 700)
	constraint.Parent = panel
	local title = label(panel, "Title", UDim2.new(1, -32, 0, 36), UDim2.fromOffset(16, 4), "RACE LIST", 22)
	title.TextColor3 = Theme.TextPrimary
	local status = label(panel, "Status", UDim2.new(1, -32, 0, 30), UDim2.fromOffset(16, 40), "", 14)
 local guidance = label(panel, "NextAction", UDim2.new(1,-32,0,24), UDim2.fromOffset(16,70), "", 12)
 guidance.AutoLocalize, guidance.TextWrapped, guidance.TextColor3 = true, true, Theme.TextSecondary
 status.TextColor3 = Theme.TextSecondary
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.fromOffset(36, 36)
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.new(1, -12, 0, 10)
	closeBtn.Parent = panel
	StyleHelper.applyCloseButton(closeBtn)
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
	local practice=button(panel,'PRACTICE SOLO',UDim2.new(1,-224,0,42),UDim2.fromOffset(160,44),function()end)
	practice.Name='PracticeSolo'
	practice.Font=Enum.Font.GothamBold;practice.TextStrokeTransparency=1
	back.BackgroundColor3 = Theme.Panel
 primary.BackgroundColor3, primary.TextColor3 = Theme.PrimaryAction, Theme.Background
 local createView
	local metrics=BrowserLayout.measure(shade.AbsoluteSize.X,shade.AbsoluteSize.Y)
	panel.Size=UDim2.fromOffset(metrics.width,metrics.height)
	local choosingTrack=false
	local primaryConnection, backConnection
	local function bindButtons(primaryText, primaryAction, backText, backAction)
		if primaryConnection then primaryConnection:Disconnect() end
		if backConnection then backConnection:Disconnect() end
		primary.Text = primaryText
		back.Text = backText
  back.BackgroundColor3 = if backText == "LEAVE" then Theme.Danger else Theme.Panel
		primary.BackgroundColor3=Theme.PrimaryAction
		back.BackgroundColor3=if backText=='LEAVE'then Theme.Danger else Theme.Panel
		for _,item in {primary,back}do item.Font=Enum.Font.GothamBold;item.TextStrokeTransparency=1 end
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
	local function row(text, actionText, callback, detail, identity,trackId,recommended,roomTitle)
		local frame = Instance.new("Frame")
		frame.Name='RaceRow'
		frame.Size = UDim2.new(1, -8, 0, metrics.row)
		frame.BackgroundColor3 = Theme.Panel
		frame.Parent = list
		local left=10
		local track=trackId and TrackCatalog.Entries[trackId]
		if track then
			local icon=Instance.new('ImageLabel');icon.Name='TrackIcon';icon.Image=track.PreviewImageAssetId or ''
			icon.Size=UDim2.fromOffset(metrics.thumb,metrics.thumb);icon.Position=UDim2.fromOffset(8,10)
			icon.ScaleType=Enum.ScaleType.Fit;icon.BackgroundColor3=Theme.Background;icon.BorderSizePixel=0;icon.Parent=frame
			left=metrics.thumb+20
		end
		local right=if metrics.stacked or not actionText then 12 else metrics.action+24
		local name=label(frame,"Name",UDim2.new(1,-left-right,0,28),UDim2.fromOffset(left,8),text,metrics.body)
		name.AutoLocalize=not identity;name.TextTruncate=Enum.TextTruncate.AtEnd
		if recommended then name.TextColor3=Theme.PrimaryAction end
		if roomTitle then
			local identityLabel=label(frame,'RaceTitle',UDim2.new(1,-left-right,0,20),UDim2.fromOffset(left,34),roomTitle,metrics.detail)
			identityLabel.AutoLocalize=false;identityLabel.TextTruncate=Enum.TextTruncate.AtEnd
		end
		if detail then
			local metadata=label(frame,"Detail",UDim2.new(1,-left-right,0,if roomTitle then 44 else 60),UDim2.fromOffset(left,if roomTitle then 56 else 36),detail,metrics.detail)
			metadata.AutoLocalize=not identity
			metadata.TextColor3=Theme.TextSecondary;metadata.TextWrapped=true;metadata.TextYAlignment=Enum.TextYAlignment.Top
		end
		if actionText then
			local action=button(frame, actionText, if metrics.stacked then UDim2.new(0,8,1,-52)else UDim2.new(1,-metrics.action-8,.5,-22), if metrics.stacked then UDim2.new(1,-16,0,44)else UDim2.fromOffset(metrics.action,44), function()
    if createView and createView.isOpen() then return end
    callback()
   end)
			action.TextSize=metrics.button;action.Font=Enum.Font.GothamBold;action.TextStrokeTransparency=1
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
	practice.Activated:Connect(function()if not createView.isOpen()then send('Practice')end end)
	render = function()
		clearRows()
  status.TextColor3 = Theme.TextSecondary
  guidance.Text = GuidanceState.roomHelper(snapshot, player.UserId)
  guidance.Visible = pendingAction == nil and invitation == nil and snapshot ~= nil and snapshot.room ~= nil
   and player:GetAttribute("RaceState") == "GARAGE"
		gui.Enabled = ((snapshot and snapshot.visible == true) or invitation ~= nil or pendingAction ~= nil)
			and player:GetAttribute("KDMRoutePending") ~= "RACE_LAUNCH"
   and player:GetAttribute("RaceState") == "GARAGE"
		if not gui.Enabled then createView.close();return end
		practice.Visible=not pendingAction and not choosingTrack and snapshot and not snapshot.allTracks and not snapshot.room and not invitation
		status.Size=UDim2.new(1,if practice.Visible then -260 else -32,0,44)
		title.AutoLocalize=true
		if pendingAction then
			status.Text = ({ Practice='ENTERING PRIVATE PRACTICE...',QuickPlay="FINDING PLAYERS ACROSS LOBBIES...",Create = "CREATING RACE...", Join = "ENTERING RACE...",
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
			status.Text = errorMessage or string.format("%s invited you to",invitation.hostName)
			row(Titles.publicTitle(invitation),nil,nil,string.format("RACERS %d / %d",invitation.count,invitation.maxPlayers),true)
			bindButtons(if invitation.state == "WAITING" and invitation.count < invitation.maxPlayers
				then "JOIN" else "QUEUE NEXT", function()
				send("AcceptInvite", player:GetAttribute("SelectedDriverId"), player:GetAttribute("SelectedKartId"))
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
			title.Text = if choosingTrack then 'NEW RACE · CHOOSE TRACK'elseif snapshot.allTracks then "PLAY TOGETHER"else 'RACE THIS TRACK'
			status.Text = if snapshot.directoryStale then "RACE INFORMATION UNAVAILABLE · RETRYING" elseif choosingTrack then 'Choose a track for your new race'elseif snapshot.allTracks then 'Join players across all lobbies and tracks'else snapshot.trackName or 'Choose a race'
			if choosingTrack then
				for _,id in TrackCatalog.Order do local track=TrackCatalog.Entries[id]
					row(track.DisplayName,'SELECT',function()
						choosingTrack=false;send('Browse',player:GetAttribute('SelectedDriverId'),player:GetAttribute('SelectedKartId'),id)
						createView.open(track.DisplayName)
					end,'Create a race on this track',false,id)
				end
			else for index, room in snapshot.rooms do
				local waiting = RoomDisplay.canJoin(room)
				local track=TrackCatalog.Entries[room.trackId]
				row((if index==1 then '★ 'else '')..(track and track.DisplayName or Titles.publicTitle(room)),
					if waiting then "JOIN RACE" else "NEXT RACE",
					function() send(if waiting then "Join" else "Queue", room.id) end,
					string.format("%s · %d PLAYERS · %d BOT\n%d JOINING · %d NEXT",if room.quickWarmup then 'BOT WARM-UP'else RoomDisplay.state(room.state),room.humanCount or room.count,room.botCount or 0,room.reservedCount or 0,room.queuedCount or 0),true,room.trackId,index==1,Titles.publicTitle(room))
			end end
			if #snapshot.rooms == 0 and not choosingTrack then row(if snapshot.directoryStale then "CHECKING RACES..." else "BE THE FIRST RACER", nil, nil,'PLAY NOW opens a race for other players to join.') end
			primary.Visible = true
			back.Visible = true
			bindButtons(if choosingTrack then 'CANCEL'elseif snapshot.allTracks then 'PLAY NOW'else 'CREATE RACE', function()
				if choosingTrack then choosingTrack=false;render()elseif snapshot.allTracks then send('QuickPlay')else createView.open()end
			end,if snapshot.allTracks then "NEW RACE"else 'ALL RACES', function()
				if snapshot.allTracks then choosingTrack=true;render()else send('BrowseAll',player:GetAttribute('SelectedDriverId'),player:GetAttribute('SelectedKartId'))end
			end)
		end
  status.TextColor3 = if errorMessage then Theme.Danger else status.TextColor3
		if errorMessage then
   status.Text = errorMessage:gsub("LOBBY NAME", "RACE TITLE"):gsub("LOBBY", "RACE")
  end
	end
 local remoteConnection = remote.OnClientEvent:Connect(function(action, data)
		if action == "Snapshot" then
			snapshot = data
			local completed = ((pendingAction == "Queue"or pendingAction=='QuickPlay') and (data.room ~= nil or data.visible==false))
				or (pendingAction=='Browse'or pendingAction=='BrowseAll')
				or (pendingAction == "CancelQueue" and data.room == nil)
				or ((pendingAction == "Create" or pendingAction == "Join"or pendingAction=='Practice') and (data.visible == false or data.room ~= nil))
				or (pendingAction == "AcceptInvite" and data.room ~= nil)
			if completed then
				if pendingAction == "AcceptInvite" then invitation = nil end
				pendingAction = nil; pendingSerial += 1
			end
			render()
		elseif action == "Invite" then
			if pendingAction ~= "AcceptInvite" then invitation = data; render() end
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
	closeBtn.Size=UDim2.fromOffset(44,44)
	closeBtn.TextSize=20;closeBtn.TextStrokeTransparency=1
	local closeGradient=closeBtn:FindFirstChildOfClass('UIGradient');if closeGradient then closeGradient:Destroy()end
	closeBtn.Activated:Connect(function()
		if pendingAction or (snapshot and snapshot.room)then return end
		choosingTrack=false;remote:FireServer('Back')
	end)
	local function resize()
		metrics=BrowserLayout.measure(shade.AbsoluteSize.X,shade.AbsoluteSize.Y)
		panel.Size=UDim2.fromOffset(metrics.width,metrics.height)
		if createView and createView.resize then createView.resize(panel.Size)end
		title.Size=UDim2.new(1,-76,0,34);title.TextSize=metrics.title
		status.Position=UDim2.fromOffset(16,40);status.Size=UDim2.new(1,-32,0,44);status.TextWrapped=true;status.TextSize=metrics.detail
		guidance.Visible=false
		list.Position=UDim2.fromOffset(16,metrics.listTop);list.Size=UDim2.new(1,-32,1,-metrics.listTop-metrics.listBottom)
		primary.TextSize=metrics.button;back.TextSize=metrics.button
		practice.TextSize=metrics.button
		if snapshot then render()end
	end
	local resizeConnection=shade:GetPropertyChangedSignal('AbsoluteSize'):Connect(resize);resize()
 gui.Destroying:Connect(function()
  resizeConnection:Disconnect()
  remoteConnection:Disconnect(); raceConnection:Disconnect(); routeConnection:Disconnect()
  if primaryConnection then primaryConnection:Disconnect() end
  if backConnection then backConnection:Disconnect() end
  pendingAction=nil; pendingSerial+=1; started=false
 end)
end

return MatchRoomUiController
