-- Shared safe-area layout and resolution-independent, code-drawn HUD symbols.
-- No uploaded assets, external packages or input handlers.
local View = {}
local ink = Color3.fromRGB(225, 246, 255)

function View.layout(size: Vector2)
	local portrait = size.X < 500 and size.Y > size.X
	local margin = if size.X >= 700 then 20 else 12
	local action = math.clamp(size.Y * 0.18, 52, 68)
	local slot = if size.X >= 700 and size.Y >= 360 then 48 else 44
	local diameter = math.clamp(math.min(size.X * 0.22, size.Y * 0.42), 104, 156)
	local short = size.Y < 340
	local tiny = not portrait and size.X<500 and size.Y<260
	local visual = if tiny then 58 elseif portrait or short then 62 else 68
	local direction = if tiny then 70 elseif portrait or short then 74 else 82
	local forward, brake = direction, direction
	local autoVisual = if portrait or short then 52 else 58
	local autoHit = if tiny then 54 elseif portrait or short then 58 else 64
	local padSpacing = direction+4
	local padWidth = direction+padSpacing*2
	local verticalSpacing = if size.Y < 260 and not portrait then 67 else (direction+autoHit)/2+4
	local padHeight, padGap = direction+verticalSpacing*2, 4
	local compactPad = false
	-- Raise the turn row above the passive gauges and move Forward just left of
	-- the minimap. The four targets remain symmetric around the Auto target.
	local padBottom = if portrait then math.min(112,size.X*.18)*2/3+12 else (if size.Y < 260 then 29 elseif short then 24 else 28)
	local mapSide = if size.Y < 330 then 96 elseif size.Y < 390 then 104 else 112
	local padInset = if portrait then 0 else math.max(12,math.max(100,mapSide)+16-margin-padSpacing)
	local driftWidth = slot*4+8*3
	local driftHeight = driftWidth/2.4
	local driftHitWidth = math.ceil(driftWidth*1.10)
	local driftHitHeight = if size.Y<260 and not portrait then math.ceil(driftHeight)+2 else math.ceil(driftHeight*1.14)
	local driftBottom = if portrait then padBottom+padHeight+8 else 8
	local loadoutBottom = margin + (if portrait then action*2+72 else action+28)
		+ (if not portrait and size.Y >= 360 then 62 else 0)
	if portrait and margin + slot*4 + 8*3 > size.X - margin - padWidth then
		-- Lift only the four-slot group/progress above the narrow portrait driving pad.
		loadoutBottom = math.max(loadoutBottom, padBottom + padHeight + 48)
	end
	return {
		speedTop = math.clamp(size.Y*0.004, 2, 4), speedHeight = 56,
		margin = margin, action = action, slot = slot, gap = 8,
		joystick = diameter, wheel = math.min(112, size.X * 0.18),
		padWidth = padWidth, padHeight = padHeight, direction = direction, forward = forward, brake = brake,
		padBottom = padBottom, padInset=padInset, padSpacing=padSpacing, padVerticalSpacing=verticalSpacing,
		autoVisualSize=autoVisual, autoHitSize=autoHit,
		padAutoRight = portrait,
		padCompact = compactPad,
		padGap = padGap,
		driveVisualSize=visual, driveHitSize=direction,
		driftWidth=driftWidth,driftHeight=driftHeight,
		driftHitWidth=driftHitWidth,driftHitHeight=driftHitHeight,
		-- Align visible Drift artwork with the LAP panel's 12px left edge.
		driftX = 12-(driftHitWidth-driftWidth)/2, driftBottom = driftBottom,
		useX = margin + (if portrait then 0 else action+8), useBottom = margin,
		-- Reserve a separate band for race-long Nitro progress and its award flash.
		loadoutBottom = loadoutBottom,
		gaugeHeight = if size.Y < 320 and not portrait then 8 else 12,
		driftGaugeGap = if size.Y < 320 and not portrait then 4 else 8,
	}
end

-- Align the phone minimap with the speed HUD in the top-right band.
function View.minimapLayout(size: Vector2, speedTop: number?)
	local side = if size.Y < 330 then 96 elseif size.Y < 390 then 104 else 112
	return {x=size.X-12-side, y=speedTop or 0, side=side}
end

-- Keep the driving rail fixed. Short phones use an adjacent lane when the
-- vertical space between the map and pad cannot contain the invite button.
function View.inviteLayout(size: Vector2, mapX: number, mapY: number, mapWidth: number, mapHeight: number, roomVisible: boolean?)
	local l = View.layout(size)
	local width, height = if size.Y < 360 then 108 else 118, if size.Y < 360 then 30 else 32
	local padTop = size.Y - l.padBottom - l.padHeight
	local padLeft=size.X-l.margin-l.padWidth-l.padInset
	local x = size.X - 12 - width
	local y = mapY + mapHeight + (if roomVisible then 34 else 8)
	if y+height > padTop-8 then
		-- A shorter topbar band cannot contain the stack above the thumb rail.
		x = padLeft-width-8
	end
	local panelWidth = 220
	local panelX = if size.X>=600 and size.Y<360 then math.max(12+math.min(170,size.X*.28)+8,12+l.slot*4+l.gap*3+8) else 12+math.min(170,size.X*.28)+8
	local panelTop = if size.X>=600 and size.Y<360 then 58 else 0
	local items=View.itemLayout(size,4)
	if x+width > items.x and x < items.x+items.width
		and y+height > size.Y-items.bottom-l.slot then
		x=panelX; y=size.Y-items.bottom-l.slot-height-4
	end
	local panelBottom = size.Y-items.bottom-l.slot-4
	local rows = math.clamp(math.floor((panelBottom-panelTop-52)/28),1,4)
	return {x=x,y=math.max(8,y),width=width,height=height,
		panelX=panelX,panelY=panelTop,panelWidth=panelWidth,rows=rows}

end

function View.itemAccent(id: string): Color3
	local accents = {Nitro=Color3.fromRGB(255,215,75), Shield=Color3.fromRGB(65,225,245),
		Slick=Color3.fromRGB(180,125,235), Missile=Color3.fromRGB(255,140,95),
		Thunder=Color3.fromRGB(205,155,255), Smoke=Color3.fromRGB(175,185,195)}
	return accents[id] or ink
end

function View.speedTopbarPosition(fullSize: Vector2, topbar: Rect, panelWidth: number, panelHeight: number): Vector2
	local halfWidth = panelWidth * 0.5
	local centerX = fullSize.X * 0.5
	if topbar.Width >= panelWidth + 16 then
		centerX = math.clamp(centerX, topbar.Min.X + halfWidth + 8, topbar.Max.X - halfWidth - 8)
	elseif topbar.Width > 0 then
		centerX = (topbar.Min.X + topbar.Max.X) * 0.5
	end
	local topY = math.max(topbar.Min.Y, (topbar.Min.Y + topbar.Max.Y - panelHeight) * 0.5)
	return Vector2.new(centerX, topY)
end

-- Keep the complete group in the left HUD lane, including short safe viewports.
function View.itemLayout(size: Vector2, slotCount: number)
	local l = View.layout(size)
	local width = l.slot * slotCount + l.gap * (slotCount - 1)
	local x = 12
	local bottom = l.loadoutBottom
	local progressGap = if size.X >= 600 and size.Y < 360 then 5 else 6
	local progressHeight=if size.Y<320 and size.X>=600 then 32 else 34
	local progressTop = size.Y - bottom + progressGap
	local progressBottom = size.Y - l.driftBottom - l.driftHitHeight - 1
	if x < l.driftX + l.driftHitWidth and x + width > l.driftX then
		progressBottom -= l.driftGaugeGap + l.gaugeHeight + 3
	end
	local wheelLeft, wheelTop = size.X * 0.5 - l.wheel * 0.5, size.Y - 3 - l.wheel * 2/3
	if x + width > wheelLeft and x < wheelLeft + l.wheel then progressBottom = math.min(progressBottom, wheelTop - 3) end
	if progressBottom - progressTop < progressHeight then
		-- Keep both NITRO CHARGE / BONUS EARNED lines readable above the wheel.
		bottom += progressHeight - (progressBottom - progressTop)
		progressTop = progressBottom - progressHeight
	end
	-- The short LAP layout places Quit beside its text, leaving this lane free.
	return { x = x, width = width, bottom = bottom, progressTop = progressTop, progressHeight = progressHeight }
end

-- The full wheel remains unchanged; only its upper two-thirds are visible.
-- Shared by desktop and touch, and intentionally accepts no input.
function View.layoutSteeringWheel(clip, wheel, ringScale, size: Vector2, mobile: boolean)
	local diameter = if mobile then View.layout(size).wheel else (if size.Y <= 650 then 84 else 112)
	clip.AnchorPoint = Vector2.new(0.5, 1)
	clip.Position = UDim2.new(0.5, 0, 1, -3)
	clip.Size = UDim2.fromOffset(diameter, diameter*2/3)
	clip.ClipsDescendants = true
	clip.Active = false
	clip.Visible = wheel.Visible and not (mobile and size.X<600 and size.X>size.Y)
	wheel.Parent = clip
	wheel.AnchorPoint = Vector2.new(0.5, 0)
	wheel.Position = UDim2.fromScale(0.5, 0)
	wheel.Size = UDim2.fromOffset(diameter, diameter)
	ringScale.Scale = if mobile then diameter/112 else (if size.Y <= 650 then 0.72 else 1)
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

function View.icon(parent: Instance, kind: string, zIndex: number?)
	local root = Instance.new("Frame")
	root.Name = kind .. "Icon"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(40, 40)
	root.BackgroundTransparency = 1
	root.Active = false
	if zIndex then root.ZIndex = zIndex end
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
		if zIndex then part.ZIndex = zIndex + 1 end
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
	if kind == "Forward" or kind == "ForwardLeft" or kind == "ForwardRight" or kind == "BrakeReverse" or kind == "Left" or kind == "Right" or kind == "Brake" then
		line(20,32,20,8,4); line(20,8,9,19,4); line(20,8,31,19,4)
		root.Rotation = if kind == "Left" then -90 elseif kind == "Right" then 90 elseif kind == "Brake" or kind == "BrakeReverse" then 180 elseif kind == "ForwardLeft" then -45 elseif kind == "ForwardRight" then 45 else 0
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
	elseif kind == "Missile" then
		shape(21,20,27,10,0,true)
		shape(33,20,10,10,0,true)
		shape(10,13,12,4,-35,true); shape(10,27,12,4,35,true)
		shape(4,20,5,4,0,true)
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
	elseif kind == "Thunder" then
		-- Cloud plus downward zigzag: distinct from Nitro's solid bolt.
		shape(11,12,14,10,0,true);shape(21,8,17,14,0,true);shape(30,13,12,10,0,true)
		line(23,18,17,25,3);line(17,25,24,25,3);line(24,25,18,35,3)
	elseif kind == "Smoke" then
		shape(6,17,18,16,0,true);shape(15,10,19,21,0,true);shape(23,18,13,13,0,true)
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
