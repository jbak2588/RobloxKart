local MobileView = require(script.Parent:WaitForChild("MobileControlView"))

local Tutorial = {}

function Tutorial.create(parent: Instance)
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
	iconRow.Size = UDim2.fromOffset(220, 44)
	iconRow.BackgroundTransparency = 1
	iconRow.ZIndex = 32
	iconRow.Parent = card
	local icons = {}
	for index = 1, 4 do
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
	local page = 1
	local pages = {
		{ "DRIVE", "↑       ←   →       ↓", "↑ Accelerate    ← → Steer    ↓ Brake / Reverse\nTap Auto Drive to keep accelerating. Brake overrides it.", { "Forward", "Left", "Right", "Brake" } },
		{ "DRIFT & BOOST", "HOLD DRIFT + STEER", "Hold DRIFT while steering. Fill the gauge.\nRelease when it turns gold for MINI BOOST.", { "Drift", "Left", "Right" } },
		{ "RACE ITEMS", "NITRO       SLICK       SHIELD       USE", "Tap an item to select it.\nTap the Trigger button to use the selected item.", { "Nitro", "Slick", "Shield", "Use" } },
	}
	local function layoutContent()
		local compact = card.Size.Y.Offset < 280
		diagram.Position = UDim2.new(0, 18, 0, if compact then 43 else 54)
		diagram.Size = UDim2.new(1, -36, 0, if compact then 30 else 35)
		diagram.TextSize = if compact then 17 else 21
		iconRow.Position = UDim2.new(0.5, 0, 0, if compact then (if page == 2 then 76 else 87) else (if page == 2 then 83 else 91))
		gaugeExamples.Position = UDim2.new(0.5, -115, 0, if compact then 122 else 140)
		description.Position = UDim2.new(0, 18, 0, if page == 2 then (if compact then 167 else 187) else (if compact then 132 else 140))
		description.Size = UDim2.new(1, -36, 0, if compact then (if page == 2 then 35 else 56) else (if page == 2 then 60 else 84))
		description.TextSize = if compact then 14 else 17
		back.Size = UDim2.fromOffset(118, if compact then 35 else 40)
		nextButton.Size = back.Size
	end
	local function render()
		local data = pages[page]
		title.Text = data[1]
		diagram.Text = data[2]
		description.Text = data[3]
		gaugeExamples.Visible = page == 2
		for index, holder in icons do
			holder.Visible = data[4][index] ~= nil
			for _, child in holder:GetChildren() do
				if child.Name:sub(-4) == "Icon" then child:Destroy() end
			end
			if holder.Visible then MobileView.icon(holder, data[4][index], holder.ZIndex + 1) end
		end
		back.Visible = page > 1
		nextButton.Text = if page == #pages then "GOT IT" else "NEXT"
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
	resize()
	render()
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
