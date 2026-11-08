local View = {}

local WIDTH, HEIGHT, GAP = 196, 24, 4

function View.format(milliseconds)
	local ms = math.max(0, math.floor(milliseconds or 0))
	return string.format("%02d:%02d.%03d", math.floor(ms / 60000), math.floor(ms / 1000) % 60, ms % 1000)
end

function View.new(gui)
	local label = Instance.new("TextLabel")
	label.Name = "RaceElapsedTime"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.AutoLocalize = false
	label.Visible = false
	label.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	label.Parent = gui
	return label
end

function View.update(label, milliseconds, topbar, ...)
	label.Visible = milliseconds ~= nil
	if milliseconds == nil then return end

	local gui = label.Parent
	local origin = gui.AbsolutePosition
	local screen = gui.AbsoluteSize
	local width = math.min(WIDTH, math.max(0, screen.X - 16))
	local center = screen.X / 2
	local centerX, y = origin.X + center, 6
	local maxY = math.min(108, math.max(84, screen.Y * 0.25))
	-- On narrow screens keep the timer centered just below the Roblox controls.
	if topbar.Width > 0 and (center - width / 2 < topbar.Min.X or center + width / 2 > topbar.Max.X) then
		y = math.clamp(topbar.Max.Y + GAP, y, maxY)
	end
	for index = 1, select("#", ...) do
		local panel = select(index, ...)
		if panel and panel.Visible then
			local position, size = panel.AbsolutePosition, panel.AbsoluteSize
			local top = position.Y - origin.Y
			local bottom = top + size.Y
			-- An overlapping panel can reserve space only within the top HUD band.
			if bottom > 0 and bottom + GAP <= maxY
				and position.X < centerX + width / 2 and position.X + size.X > centerX - width / 2 then
				y = math.max(y, bottom + GAP)
			end
		end
	end
	label.Position = UDim2.new(0.5, 0, 0, y)
	label.Size = UDim2.fromOffset(width, HEIGHT)
	label.Text = "TOTAL TIME  " .. View.format(milliseconds)
end

return table.freeze(View)
