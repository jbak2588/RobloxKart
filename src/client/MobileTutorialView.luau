local MobileView = require(script.Parent:WaitForChild("MobileControlView"))

local ControlIcons = require(script.Parent:WaitForChild("KDMControlIconView"))
local ItemIcons = require(script.Parent:WaitForChild("KDMItemIconView"))
local ContentProvider = game:GetService("ContentProvider")
local Tutorial = {}

function Tutorial.create(parent: Instance, onDismiss)
	local overlay = Instance.new("Frame")
	overlay.Name = "MobileControlsTutorial"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(8, 14, 24)
	overlay.BackgroundTransparency = 0.12
	overlay.BorderSizePixel = 0
	overlay.Active = true
	overlay.Visible = false
	overlay.ZIndex = 30
	overlay.Parent = parent

	local card = Instance.new("Frame")
	card.Name = "TutorialCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.BackgroundColor3 = Color3.fromRGB(22, 32, 48)
	card.BorderSizePixel = 0
	card.ZIndex = 31
	card.Parent = overlay
	MobileView.round(card, UDim.new(0, 12))

	local function label(name, y, height, size, color)
		local item = Instance.new("TextLabel")
		item.Name = name
		item.Position = UDim2.new(0, 18, 0, y)
		item.Size = UDim2.new(1, -36, 0, height)
		item.BackgroundTransparency = 1
		item.Font = Enum.Font.GothamBold
		item.TextColor3 = color
		item.TextSize = size
		item.TextWrapped = true
		item.ZIndex = 32
		item.Parent = card
		return item
	end
	local title = label("Title", 12, 34, 24, Color3.fromRGB(255, 215, 75))
	local diagram = label("Diagram", 54, 35, 21, Color3.fromRGB(225, 246, 255))
	local description = label("Description", 140, 84, 17, Color3.fromRGB(235, 241, 247))
	local iconRow = Instance.new("Frame")
	iconRow.Name = "ActualControlIcons"
	iconRow.AnchorPoint = Vector2.new(0.5, 0)
	iconRow.Position = UDim2.new(0.5, 0, 0, 91)
	iconRow.Size = UDim2.fromOffset(268, 44)
	iconRow.BackgroundTransparency = 1
	iconRow.ZIndex = 32
	iconRow.Parent = card
	local icons = {}
	local controlViews={}
	local cache=ControlIcons.cache(ContentProvider,task)
	local itemViews={}
	local itemCache=ItemIcons.cache(ContentProvider,task)
	local tutorialItemView={icon=function(holder,key)
		return MobileView.icon(holder,key,holder.ZIndex+1)
	end}
	for index = 1, 5 do
		local holder = Instance.new("Frame")
		holder.Name = "IconSlot" .. index
		holder.Position = UDim2.fromOffset((index - 1) * 56, 0)
		holder.Size = UDim2.fromOffset(44, 44)
		holder.BackgroundColor3 = Color3.fromRGB(41, 62, 81)
		holder.BackgroundTransparency = 0.68
		holder.ZIndex = 32
		holder.Parent = iconRow
		MobileView.round(holder, UDim.new(0, 7))
		icons[index] = holder
	end
	local itemCaptions = Instance.new("Frame")
	itemCaptions.Name = "ItemCaptions"
	itemCaptions.AnchorPoint = Vector2.new(0.5, 0)
	itemCaptions.Size = UDim2.fromOffset(220, 18)
	itemCaptions.BackgroundTransparency = 1
	itemCaptions.ZIndex = 32
	itemCaptions.Visible = false
	itemCaptions.Parent = card
	for index, text in { "NITRO", "SLICK", "SHIELD", "MISSILE" } do
		local caption = Instance.new("TextLabel")
		caption.Name = "Caption" .. index
		caption.Position = UDim2.fromOffset((index - 1) * 56, 0)
		caption.Size = UDim2.fromOffset(44, 18)
		caption.BackgroundTransparency = 1
		caption.Font = Enum.Font.GothamBold
		caption.Text = text
		caption.TextColor3 = Color3.fromRGB(225, 246, 255)
		caption.TextSize = 11
		caption.TextXAlignment = Enum.TextXAlignment.Center
		caption.ZIndex = 32
		caption.Parent = itemCaptions
	end
	local gaugeExamples = Instance.new("Frame")
	gaugeExamples.Name = "GaugeExamples"
	gaugeExamples.Size = UDim2.fromOffset(230, 42)
	gaugeExamples.BackgroundTransparency = 1
	gaugeExamples.ZIndex = 32
	gaugeExamples.Visible = false
	gaugeExamples.Parent = card
	local function createTutorialGauge(name: string, y: number, filledCount: number, ready: boolean)
		local row = Instance.new("Frame")
		row.Name = name
		row.Position = UDim2.fromOffset(0, y)
		row.Size = UDim2.fromOffset(230, 18)
		row.BackgroundTransparency = 1
		row.ZIndex = 32
		row.Parent = gaugeExamples
		for index = 1, 5 do
			local segment = Instance.new("Frame")
			segment.Name = "Segment" .. index
			segment.Position = UDim2.fromOffset((index - 1) * 21, 2)
			segment.Size = UDim2.fromOffset(18, 12)
			segment.BackgroundColor3 = if index <= filledCount
				then (if ready then Color3.fromRGB(255, 218, 75) else Color3.fromRGB(65, 225, 245))
				else Color3.fromRGB(45, 60, 70)
			segment.BorderSizePixel = 0
			segment.ZIndex = 33
			segment.Parent = row
			MobileView.round(segment, UDim.new(0, 2))
		end
		local caption = Instance.new("TextLabel")
		caption.Name = "Caption"
		caption.Position = UDim2.fromOffset(112, 0)
		caption.Size = UDim2.fromOffset(110, 18)
		caption.BackgroundTransparency = 1
		caption.Font = Enum.Font.GothamBold
		caption.Text = if ready then "GOLD / READY" else "CHARGING"
		caption.TextColor3 = if ready then Color3.fromRGB(255, 218, 75) else Color3.fromRGB(65, 225, 245)
		caption.TextSize = 13
		caption.TextXAlignment = Enum.TextXAlignment.Left
		caption.ZIndex = 33
		caption.Parent = row
	end
	createTutorialGauge("ChargingGauge", 0, 3, false)
	createTutorialGauge("ReadyGauge", 22, 5, true)
	local function button(name, text, x)
		local item = Instance.new("TextButton")
		item.Name = name
		item.AnchorPoint = Vector2.new(0.5, 1)
		item.Position = UDim2.new(x, 0, 1, -12)
		item.Size = UDim2.fromOffset(118, 40)
		item.BackgroundColor3 = Color3.fromRGB(49, 113, 176)
		item.BorderSizePixel = 0
		item.Font = Enum.Font.GothamBold
		item.Text = text
		item.TextColor3 = Color3.new(1, 1, 1)
		item.TextSize = 18
		item.ZIndex = 32
		item.Parent = card
		MobileView.round(item, UDim.new(0, 7))
		return item
	end
	local back = button("Back", "BACK", 0.28)
	local nextButton = button("Next", "NEXT", 0.72)
	local dismissButton = button("DontShowAgain", "DON'T SHOW AGAIN", 0.83)
	dismissButton.TextSize = 13
	dismissButton.Visible = false
	local page = 1
	local pages = {
		{ "DRIVE", "←   →           DRIFT   ↓", "Auto-Forward is always ON. Left/Right (left thumb): steer.\nBrake/Reverse (right thumb): tap to slow down, hold to reverse (up to 50), release to resume Auto-Forward.", { "ForwardLeft", "ForwardRight", "DriftSquare", "BrakeReverse" } },
		{ "DRIFT & BOOST", "HOLD DRIFT + LEFT / RIGHT", "Exit a READY Drift for MINI BOOST.\nLand 3 boosts in one race for +1 NITRO.", { "DriftSquare", "ForwardLeft", "ForwardRight" } },
		{ "RACE ITEMS", "", "Tap an item once to use it while racing.\nWhen a Missile is incoming, tap Shield to defend.", { "Nitro", "Slick", "Shield", "Missile" } },
	}
	local function layoutContent()
		iconRow.Size=UDim2.fromOffset(if page==1 then 268 else 220,44)
		local compact = card.Size.Y.Offset < 280
		diagram.Position = UDim2.new(0, 18, 0, if compact then 43 else 54)
		diagram.Size = UDim2.new(1, -36, 0, if compact then 30 else 35)
		diagram.TextSize = if compact then 17 else 21
		iconRow.Position = UDim2.new(0.5, 0, 0, if page == 1 then (if compact then 55 else 66)
			else (if compact then (if page == 2 then 76 else 87) else (if page == 2 then 83 else 91)))
		itemCaptions.Position = UDim2.new(0.5, 0, 0, if compact then 65 else 69)
		gaugeExamples.Position = UDim2.new(0.5, -115, 0, if compact then 122 else 140)
		description.Position = UDim2.new(0, 18, 0, if page == 1 then (if compact then 110 else 119)
			else (if page == 2 then (if compact then 167 else 187) else (if compact then 132 else 140)))
		description.Size = UDim2.new(1, -36, 0, if compact then (if page == 2 then 35 else 56) else (if page == 2 then 60 else 84))
		description.TextSize = if compact then 14 else 17
		back.Size = UDim2.fromOffset(if page == #pages then (if compact then 90 else 100) else 118,
			if compact then 35 else 40)
		nextButton.Size = back.Size
		dismissButton.Size = UDim2.fromOffset(if compact then 98 else 112, if compact then 35 else 40)
		back.Position = UDim2.new(if page == #pages then 0.18 else 0.28, 0, 1, -12)
		nextButton.Position = UDim2.new(if page == #pages then 0.5 else 0.72, 0, 1, -12)
		dismissButton.Position = UDim2.new(0.82, 0, 1, -12)
		dismissButton.TextSize = if compact then 11 else 12
	end
	local function render()
		local data = pages[page]
		title.Text = data[1]
		diagram.Text = if page == 1 then "" else data[2]
		diagram.Visible = page == 2
		description.Text = if page==1 and MobileView.controlsV1Enabled() then
   (if workspace:GetAttribute('KDMGasPedalEnabled')==true then 'LEFT / RIGHT · BRAKE / REVERSE · DRIFT\nGAS: HOLD FOR 90 STUDS/S ON TRACK — NO EXTRA BOOST'
    else 'LEFT / RIGHT · BRAKE / REVERSE · DRIFT\nGAS: UI PREVIEW ONLY — SPEED NOT CONNECTED')else data[3]
		itemCaptions.Visible = page == 3
		gaugeExamples.Visible = page == 2
		table.clear(controlViews)
		table.clear(itemViews)
		for index, holder in icons do
			holder.Visible = data[4][index] ~= nil
			for _, child in holder:GetChildren() do
				if child.Name:sub(-4) == "Icon" or child.Name=="KDMControlImage" or child.Name=="KDMItemImage" then child:Destroy() end
			end
			if holder.Visible then
				local key=data[4][index]
				if page<=2 then
					local view=ControlIcons.new(holder,key,cache,MobileView);view:layout(44,44)
					table.insert(controlViews,view)
				else
					local view=ItemIcons.new(holder,key,itemCache,tutorialItemView)
					view:update(true,1,false)
					table.insert(itemViews,view)
				end
			end
		end
		back.Visible = page > 1
		nextButton.Text = if page == #pages then "GOT IT" else "NEXT"
		dismissButton.Visible = page == #pages
		layoutContent()
	end
	local function resize()
		local size = parent.AbsoluteSize
		local width = if size.X > 0 then size.X else 800
		local height = if size.Y > 0 then size.Y else 360
		card.Size = UDim2.fromOffset(math.min(520, width - 24), math.min(310, height - 16))
		layoutContent()
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	back.Activated:Connect(function()
		page = math.max(1, page - 1)
		render()
	end)
	nextButton.Activated:Connect(function()
		if page == #pages then overlay.Visible = false
		else page += 1; render() end
	end)
	dismissButton.Activated:Connect(function()
		if page == #pages then
			overlay.Visible = false
			if onDismiss then onDismiss() end
		end
	end)
	resize()
	render()
	cache:start(function() for _,view in controlViews do view:update(true,false) end end)
	itemCache:start(function() for _,view in itemViews do view:update(true,1,false) end end)
	overlay.Destroying:Connect(function()cache:destroy();itemCache:destroy()end)
	return {
		open = function()
			page = 1
			render()
			overlay.Visible = true
		end,
		close = function() overlay.Visible = false end,
		isOpen = function() return overlay.Visible end,
	}
end

return Tutorial
