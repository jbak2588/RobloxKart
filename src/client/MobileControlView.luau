-- Shared safe-area layout and resolution-independent, code-drawn HUD symbols.
-- No uploaded assets, external packages or input handlers.
local View = {}
local ink = Color3.fromRGB(225, 246, 255)

function View.layout(size: Vector2)
	local portrait = size.X < 500 and size.Y > size.X
	local margin = if size.X >= 700 then 20 else 12
	local action = math.clamp(size.Y * 0.18, 52, 68)
	local slot = if size.X >= 700 then 48 else 44
	local diameter = math.clamp(math.min(size.X * 0.22, size.Y * 0.42), 104, 156)
	local direction = if portrait then 44 else math.clamp(size.Y * 0.15, 44, 56)
	local forward = direction + 10
	local brake = direction
	local padWidth = direction * 3 + 24
	local compactPad = not portrait and size.Y < 300
	local padHeight = if compactPad then forward + brake + 14 else forward + direction + brake + 12
	return {
		speedTop = math.clamp(size.Y*0.004, 2, 4), speedHeight = 56,
		margin = margin, action = action, slot = slot, gap = 8,
		joystick = diameter, wheel = math.min(112, size.X * 0.18),
		padWidth = padWidth, padHeight = padHeight, direction = direction, forward = forward, brake = brake,
		padBottom = if portrait then math.min(112, size.X * 0.18)*2/3+12 else margin,
		padAutoRight = portrait,
		padCompact = compactPad,
		driftX = margin, driftBottom = margin + (if portrait then action+8 else 0),
		useX = margin + (if portrait then 0 else action+8), useBottom = margin,
		loadoutBottom = margin + (if portrait then action*2+16 else action+8),
	}
end

function View.round(parent, radius: UDim?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UDim.new(1, 0)
	corner.Parent = parent
end

function View.stroke(parent, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = ink
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function View.icon(parent: Instance, kind: string)
	local root = Instance.new("Frame")
	root.Name = kind .. "Icon"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(40, 40)
	root.BackgroundTransparency = 1
	root.Active = false
	root.Parent = parent
	local shapes, outlines = {}, {}
	local lockShackle
	local function shape(x, y, w, h, angle, round)
		local part = Instance.new("Frame")
		part.AnchorPoint = Vector2.new(0.5, 0.5)
		part.Position = UDim2.fromOffset(x, y)
		part.Size = UDim2.fromOffset(w, h)
		part.Rotation = angle or 0
		part.BackgroundColor3 = ink
		part.BorderSizePixel = 0
		part.Active = false
		part.Parent = root
		if round then View.round(part) end
		table.insert(shapes, part)
		return part
	end
	local function line(x1, y1, x2, y2, width)
		local cap = if kind == "Slick" or kind == "Use" or kind == "Nitro" then (width or 3) else 0
		return shape((x1+x2)/2, (y1+y2)/2, math.sqrt((x2-x1)^2+(y2-y1)^2)+cap, width or 3,
			math.deg(math.atan2(y2-y1, x2-x1)), true)
	end
	if kind == "Forward" or kind == "Left" or kind == "Right" or kind == "Brake" then
		line(20,32,20,8,4); line(20,8,9,19,4); line(20,8,31,19,4)
		root.Rotation = if kind == "Left" then -90 elseif kind == "Right" then 90 elseif kind == "Brake" then 180 else 0
	elseif kind == "Nitro" then
		-- Original solid lightning silhouette, filled with short native UI strips.
		local points = {{25,2},{8,23},{18,23},{14,38},{33,16},{22,16}}
		for y = 2.5, 37.5, 1 do
			local crossings = {}
			for i, a in points do
				local b = points[i % #points + 1]
				if (a[2] <= y and b[2] > y) or (b[2] <= y and a[2] > y) then
					table.insert(crossings,a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2]))
				end
			end
			table.sort(crossings)
			for i = 1, #crossings-1, 2 do shape((crossings[i]+crossings[i+1])/2,y,crossings[i+1]-crossings[i],1.2) end
		end
		for i,a in points do local b=points[i % #points + 1]; line(a[1],a[2],b[1],b[2],1) end
	elseif kind == "Slick" then
		-- Our own small front-view car and two winding tracks, not a road-sign asset.
		local car = shape(21,16,23,11,0,true)
		car.BackgroundTransparency = 1
		table.insert(outlines, View.stroke(car,2.5))
		line(11,11,15,4,2.5); line(15,4,27,4,2.5); line(27,4,31,11,2.5)
		shape(14,16,4,3,0,true); shape(28,16,4,3,0,true)
		shape(12,24,4,5,0,true); shape(30,24,4,5,0,true)
		for _, x in {11,28} do
			local lastX,lastY=x,27
			for i=1,8 do
				local t=i/8
				local nextX,nextY=x-4*math.sin(t*math.pi*2),27+t*11
				line(lastX,lastY,nextX,nextY,2.5)
				lastX,lastY=nextX,nextY
			end
		end
	elseif kind == "Shield" then
		for _, edge in {{7,7,20,3},{20,3,33,7},{33,7,31,24},{31,24,20,36},{20,36,9,24},{9,24,7,7}} do
			line(table.unpack(edge))
		end
		line(13,19,18,24); line(18,24,27,14)
	elseif kind == "Drift" then
		local tyre = shape(25, 12, 14, 19, 28, true)
		tyre.BackgroundTransparency = 1
		table.insert(outlines, View.stroke(tyre, 3))
		line(22,6,28,17,2)
		for _, offset in {0, 10} do
			line(19+offset,21,12+offset,27)
			line(12+offset,27,16+offset,31)
			line(16+offset,31,7+offset,37)
		end
	elseif kind == "AutoForward" then
		-- Arrow plus visibly open/closed shackle; no text is needed.
		line(12,30,12,7,4); line(12,7,4,15,4); line(12,7,20,15,4)
		local lock = shape(29,27,15,14,0,false)
		View.round(lock, UDim.new(0, 2))
		lock.BackgroundTransparency = 1
		table.insert(outlines, View.stroke(lock,2))
		line(24,20,24,15,2); line(24,15,34,15,2)
		lockShackle = line(34,15,34,20,2)
		lockShackle.Name = "LockShackle"
	elseif kind == "Use" then
		-- Fingertip contacting a circular trigger with three activation rays.
		local trigger = shape(17,11,13,13,0,true)
		trigger.BackgroundTransparency = 1
		table.insert(outlines, View.stroke(trigger,2))
		local path={{10,26},{15,31},{17,36},{30,36},{34,28},{34,22},{30,20},{27,22},{26,18},{22,20},{22,13},{20,10},{17,11},{17,26},{13,23},{10,23},{10,26}}
		for i=1,#path-1 do line(path[i][1],path[i][2],path[i+1][1],path[i+1][2],2.5) end
		line(5,11,2,11,2); line(8,3,6,1,2); line(27,5,30,3,2)
	end
	return {
		root = root,
		setLatched = function(_, latched)
			if lockShackle then
				lockShackle.Position = UDim2.fromOffset(if latched then 34 else 36, if latched then 17.5 else 13)
				lockShackle.Rotation = if latched then 90 else -35
			end
		end,
		setEnabled = function(_, enabled)
			local color = if enabled then ink else Color3.fromRGB(113, 128, 141)
			for _, part in shapes do part.BackgroundColor3 = color end
			for _, stroke in outlines do stroke.Color = color end
		end,
	}
end

return View
