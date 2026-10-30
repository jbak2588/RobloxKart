-- Shared safe-area layout and resolution-independent, code-drawn HUD symbols.
-- No uploaded assets, external packages or input handlers.
local View = {}
local screenBottomInset=0
-- Retain Forward/Reverse and AUTO visual sizes; V3 steering fills the center gap.
-- Forward/Reverse alpha bounds and the new full-size artwork remain Fit.
View.artwork={driveWidth=1093/1254,driveHeight=1078/1254,driveBottom=55/1024,
	driveRight=81/1254,autoWidth=1,driftHeight=1,driftBottom=0}
function View.setViewportBottomInset(fullHeight, deviceHeight)
	screenBottomInset=math.clamp(fullHeight-deviceHeight,0,40)
end
local ink = Color3.fromRGB(225, 246, 255)

function View.nitroBar(parent)
 local root=Instance.new('Frame');root.Name='NitroChargeBar';root.BackgroundTransparency=1
 root.Position=UDim2.new(0,0,1,-7);root.Size=UDim2.new(1,0,0,6);root.Visible=false;root.Parent=parent
 local cells={}
 return {root=root,update=function(_,progress,total,enabled)
  root.Visible=enabled==true
  for i=1,total do
   if not cells[i]then
    local b=Instance.new('Frame');b.BorderSizePixel=0;b.Parent=root;cells[i]=b
   end
   local b=cells[i];b.Visible=true;b.Position=UDim2.new((i-1)/total,0,0,0);b.Size=UDim2.new(1/total,-4,1,0)
   b.BackgroundColor3=if i<=progress then Color3.fromRGB(65,225,245)else Color3.fromRGB(45,60,70)
   b.BackgroundTransparency=if i<=progress then .1 else .5
  end
  for i=total+1,#cells do cells[i].Visible=false end
 end}
end

-- Explicit rollout flag for the approved private QA and production Place pairs.
function View.controlsV1Enabled(context)
 local universeId,placeId,flag
 if context then universeId,placeId,flag=context.universeId,context.placeId,context.flag
 elseif game and workspace then universeId,placeId,flag=game.GameId,game.PlaceId,workspace:GetAttribute('KDMControlsV1Preview')end
 return flag==true and ((universeId==10772198697 and placeId==106553302629620)
  or (universeId==10768420544 and placeId==127925465904803))
end
function View.controlsV1Layout(size)
 local w,h=size.X,size.Y
 local scale=math.clamp(math.min(w/1600,h/739),.64,1.15)
 if h<280 then scale=math.min(scale,math.max(.48,(h-40)/360)) end
 local function box(cx,cy,bw,bh)
  local width,height=math.floor(math.max(48,bw*scale)),math.floor(math.max(48,bh*scale))
  cx=math.clamp(cx,12+width/2,w-12-width/2);cy=math.clamp(cy,12+height/2,h-12-height/2)
  return {x=cx-width/2,y=cy-height/2,width=width,height=height}
 end
 -- Bottom edges meet the digital speed's text baseline. Keep a literal 30px
 -- finger gap; safe-area coordinates already exclude the phone notch.
 local floor=h-26;local d=math.floor(math.max(48,108*scale));local g=d
 local brake=math.floor(math.max(48,64*scale));local right=w-12
 local buttons={ForwardLeft=box(12+d/2,floor-d/2,108,108),ForwardRight=box(12+d+30+d/2,floor-d/2,108,108),
  Drift=box(right-d-30-d/2,floor-d/2,108,108),Gas=box(right-d/2,floor-d/2,108,108),
  BrakeReverse=box(right-brake/2,floor-d-12-brake/2,64,64)}
 local drift=buttons.Drift
 local mapSide=math.clamp(math.floor(h*.20),48,112)
 local columns=4
 local slot=if h<280 then 32 elseif h<300 then 36 elseif h<=340 then 40 else 44
 local gap=6;local width=slot*columns+gap*(columns-1);local itemHeight=slot*2+gap
 local map={x=w-12-mapSide,y=8,width=mapSide,height=mapSide}
 local brakeCenter=buttons.BrakeReverse.x+buttons.BrakeReverse.width/2
 local secondTop=buttons.BrakeReverse.y+(buttons.BrakeReverse.height-slot)/2
 local top=math.min(secondTop-slot-gap,buttons.BrakeReverse.y-slot-8);local itemX=w-12-width
 itemX=math.floor(itemX);top=math.floor(math.max(12,top))
 local progressWidth=math.min(220,w*.3)
 local items={x=itemX,top=math.max(12,top),width=width,slot=slot,gap=gap,columns=columns,
  secondTop=math.floor(secondTop),secondX=math.floor(drift.x+drift.width/2-(2*slot+gap)/2),progressX=(w-progressWidth)/2,progressWidth=progressWidth,
  progressTop=h-92,progressHeight=30}
 local clockWidth=math.min(180,w-360)
 local clock={x=w*.5-clockWidth/2,y=8,width=clockWidth,height=44}
 local textWidth=math.floor(progressWidth*.66)
 local gaugeX=items.progressX+textWidth+6
 local gaugeWidth=progressWidth-textWidth-6
 return {buttons=buttons,map=map,items=items,clock=clock,
  notice={x=clock.x,y=58,width=clock.width,height=32},
  gauge={x=gaugeX,y=items.progressTop+3,width=gaugeWidth,height=10},
  speed={x=w*.5-80,y=h-54,width=160,height=42}}
end

function View.layout(size: Vector2)
	local portrait = size.X < 500 and size.Y > size.X
	local margin = if size.X >= 700 then 20 else 12
	local action = math.clamp(size.Y * 0.18, 52, 68)
	local slot = if size.X >= 700 and size.Y >= 360 then 48 else 44
	local diameter = math.clamp(math.min(size.X * 0.22, size.Y * 0.42), 104, 156)
	local short = size.Y < 340
	local tiny = not portrait and size.X<500 and size.Y<260
	local visual = if tiny then 58 elseif portrait or short then 62 else 68
	local direction = if portrait then 74 else math.ceil(visual*View.artwork.driveWidth)+4
	local forward = direction
	local brake = if portrait then direction else math.round(direction * 0.85)
	local brakeVisualSize = math.round(brake * View.artwork.driveWidth)
	local autoVisual = if portrait or short then 52 else 58
	local autoHit = autoVisual+4
	local sideVisualWidth = visual*1.5
	local sideWidth, sideHeight = math.ceil(sideVisualWidth)+4, visual+4
	local padSpacing = if portrait then direction+4 else (visual*View.artwork.driveWidth+autoVisual*View.artwork.autoWidth)/2+10
	local padWidth = sideWidth*2+8
	local verticalSpacing = (direction+sideHeight)/2+(if short then 2 else 4)
	local padHeight, padGap = direction+verticalSpacing*2, 4
	local compactPad = false
	-- Build upward from Brake's artwork, 10px above the safe bottom edge.
	local padBottom = if portrait then math.min(112,size.X*.18)*2/3+12 else 10-(direction-visual)/2-visual*View.artwork.driveBottom-screenBottomInset
	local mapSide = if size.Y < 330 then 96 elseif size.Y < 390 then 104 else 112
	local padInset = if portrait then 0 else 12-margin-(sideWidth-sideVisualWidth)/2
	local driftHeight = brake
	local driftWidth = math.round(driftHeight * 1536 / 518)
	local wheel = math.min(112, size.X * 0.18)
	local maxDriftWidth = if portrait then 220 else math.max(132, math.floor((size.X - 12) - (size.X * 0.5 + wheel * 0.5 + 8) - brake - 8))
	if driftWidth > maxDriftWidth then
		driftWidth = maxDriftWidth
		driftHeight = math.round(driftWidth * 518 / 1536)
	end
	local driftHitWidth = driftWidth
	local driftHitHeight = driftHeight
	local driftBottom = if portrait then padBottom+padHeight+8 else 10-(driftHitHeight-driftHeight)/2-driftHeight*View.artwork.driftBottom-screenBottomInset
	local steerLeftX = 12
	local steerBottom = math.max(12, padBottom)
	local steerTotalWidth = sideWidth*2+8
	local steerHeight = sideHeight
	local gap = 8
	local rightPadWidth = brake + gap + driftHitWidth
	local rightPadX = size.X - 12 - rightPadWidth
	local rightBrakeX = rightPadX
	local rightBrakeBottom = 12
	if portrait and steerLeftX + steerTotalWidth + 8 > rightPadX then
		rightBrakeBottom = steerBottom + steerHeight + 8
	end
	local rightDriftX = rightPadX + brake + gap
	local rightDriftBottom = rightBrakeBottom
	local loadoutBottom = margin + (if portrait then action*2+72 else action+28)
		+ (if not portrait and size.Y >= 360 then 62 else 0)
	if portrait then
		local highestDriveTop = math.max(steerBottom + steerHeight, rightDriftBottom + driftHitHeight + 28)
		loadoutBottom = math.max(loadoutBottom, highestDriveTop + 12)
	end
	local result = {
		speedTop = math.clamp(size.Y*0.004, 2, 4), speedHeight = 56,
		margin = margin, action = action, slot = slot, gap = 8,
		joystick = diameter, wheel = math.min(112, size.X * 0.18),
		padWidth = padWidth, padHeight = padHeight, direction = direction, forward = forward, brake = brake,
		padBottom = padBottom, padInset=padInset, padSpacing=padSpacing, padVerticalSpacing=verticalSpacing,
		autoVisualSize=autoVisual, autoHitSize=autoHit,
		sideWidth=sideWidth,sideHeight=sideHeight,sideVisualWidth=sideVisualWidth,
		steerLeftX=steerLeftX, steerBottom=steerBottom, steerTotalWidth=steerTotalWidth, steerHeight=steerHeight,
		rightPadWidth=rightPadWidth, rightPadX=rightPadX,
		rightBrakeX=rightBrakeX, rightBrakeBottom=rightBrakeBottom,
		rightDriftX=rightDriftX, rightDriftBottom=rightDriftBottom,
		-- AUTO shares Forward's visible top and the steering row's visible right.
		autoRight=padWidth-(sideWidth-sideVisualWidth)/2+(autoHit-autoVisual)/2,
		autoTop=(direction-visual)/2+visual*(1-View.artwork.driveHeight)/2-(autoHit-autoVisual)/2,
		padAutoRight = portrait,
		padCompact = compactPad,
		padGap = padGap,
		driveVisualSize=visual, driveHitSize=direction, brakeVisualSize=brakeVisualSize,
		driftWidth=driftWidth,driftHeight=driftHeight,
		driftHitWidth=driftHitWidth,driftHitHeight=driftHitHeight,
		-- Align visible Drift artwork with the LAP panel's 12px left edge.
		driftX = 12-(driftHitWidth-driftWidth)/2, driftBottom = driftBottom,
		useX = margin + (if portrait then 0 else action+8), useBottom = margin,
		-- Reserve a separate band for race-long Nitro progress and its award flash.
		loadoutBottom = loadoutBottom,
		gaugeHeight = if size.Y < 320 and not portrait then 8 else 12,
		driftGaugeGap = if size.Y < 320 and not portrait then 0 else 8,
	}
 if View.controlsV1Enabled() and size.X>size.Y and size.X>=600 then
  local v=View.controlsV1Layout(size);local b=v.buttons
  result.controlsV1=v;result.slot=v.items.slot;result.gap=v.items.gap
  result.steerLeftX=b.ForwardLeft.x;result.steerBottom=size.Y-b.ForwardLeft.y-b.ForwardLeft.height
  result.steerTotalWidth=b.ForwardRight.x+b.ForwardRight.width-b.ForwardLeft.x;result.steerHeight=b.ForwardLeft.height
  result.sideWidth=b.ForwardLeft.width;result.sideHeight=b.ForwardLeft.height;result.sideVisualWidth=b.ForwardLeft.width
  result.brake=b.BrakeReverse.width;result.rightBrakeX=b.BrakeReverse.x;result.rightBrakeBottom=size.Y-b.BrakeReverse.y-b.BrakeReverse.height
  result.driftWidth=b.Drift.width;result.driftHeight=b.Drift.height;result.driftHitWidth=b.Drift.width;result.driftHitHeight=b.Drift.height
  result.rightDriftX=b.Drift.x;result.rightDriftBottom=size.Y-b.Drift.y-b.Drift.height;result.driftGaugeGap=13
 end
 return result
end

-- Digital-only reverse AUTO occupies the unused lower-right pad corner.
-- Keep normal geometry; reserve full hitboxes only when the safe bottom is short.
function View.autoBackwardLayout(l, size)
	local hit=math.max(44,l.autoHitSize)
	l.padBottom=math.max(l.padBottom,8+math.max(0,(hit-l.brake)/2))
	l.padHeight=math.max(l.padHeight,l.sideHeight+l.brake+hit+8)
	local right=size.X-l.margin-l.padInset-(l.sideWidth-l.sideVisualWidth)/2+(hit-l.autoVisualSize)/2
	right=math.min(size.X-8,right)
	return {right=right,bottom=l.padBottom+(l.brake-hit)/2,hit=hit,visual=math.min(l.autoVisualSize,hit-4)}
end

-- Align the phone minimap with the speed HUD in the top-right band.
function View.minimapLayout(size: Vector2, speedTop: number?)
 if View.controlsV1Enabled() and size.X>size.Y and size.X>=600 then
  local r=View.controlsV1Layout(size).map;return {x=r.x,y=r.y,side=r.width}
 end
	local side = if size.Y < 330 then 96 elseif size.Y < 390 then 104 else 112
	return {x=size.X-12-side, y=(speedTop or 0)+2, side=side}
end

-- Social controls occupy the former left item lane, away from the right thumb.
function View.inviteLayout(size: Vector2, mapX: number, mapY: number, mapWidth: number, mapHeight: number, roomVisible: boolean?)
	local l = View.layout(size)
 if l.controlsV1 then
  local top=l.controlsV1.buttons.ForwardLeft.y
  return {x=12,y=72,width=118,height=30,statusY=44,panelX=12,panelY=108,panelWidth=176,
   rows=math.clamp(math.floor((top-108-52-8)/28),1,4)}
 end
 local width, height = if size.Y < 360 then 108 else 118, if size.Y < 360 then 30 else 32
	local x = 12
	local statusY = if size.Y < 360 then 60 else 100
	local y = statusY + (if roomVisible then 26 else 0)
	local panelX, panelTop = 200, 60
	local items=View.itemLayout(size,6)
	local panelWidth = math.min(220,math.max(120,items.x-panelX-8))
	local panelBottom = size.Y-l.steerBottom-l.steerHeight-4
	local rows = math.clamp(math.floor((panelBottom-panelTop-52)/28),1,4)
	return {x=x,y=math.max(8,y),width=width,height=height,
		statusY=statusY,panelX=panelX,panelY=panelTop,panelWidth=panelWidth,rows=rows}

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

-- Six-item race HUD belongs above the right thumb controls and charge gauge.
function View.itemLayout(size: Vector2, slotCount: number)
 local l = View.layout(size)
 if l.controlsV1 and slotCount==6 then
  local items=table.clone(l.controlsV1.items);items.bottom=size.Y-items.secondTop-items.slot;return items
 end
	if slotCount == 6 then
		local controlTop=size.Y-l.rightDriftBottom-math.max(l.brake,l.driftHitHeight)
		local progressHeight=24
		local progressTop=controlTop-10-12-6-progressHeight
		local top=progressTop-4-l.slot*2-6
		local rowGap = 6
		local secondTop = top + l.slot + rowGap
		local width=l.slot*4+l.gap*3
		return {x=size.X-12-width, width=width, bottom=size.Y-secondTop-l.slot,
			top=top, secondTop=secondTop, progressTop=progressTop, progressHeight=progressHeight}
	end
	local width = l.slot * slotCount + l.gap * (slotCount - 1)
	local x = 12
	local bottom = l.loadoutBottom
	local progressGap = if size.X >= 600 and size.Y < 360 then 5 else 6
	local progressHeight=if size.Y<320 and size.X>=600 then 32 else 34
	local progressTop = size.Y - bottom + progressGap
	local progressBottom = size.Y - l.driftBottom - l.driftHitHeight - 1
	if x < l.driftX + l.driftHitWidth and x + width > l.driftX then
		-- Reserve the gauge above the complete Fit image, not only its smaller
		-- touch target. The 3px READY stroke also needs its own clear band.
		local portrait=size.X<500 and size.Y>size.X
		local artworkOverhang=math.max(0,(l.driftHeight-l.driftHitHeight)/2)
		-- Separate ScreenGui insets can put the gauge above the 320px breakpoint
		-- while controls remain below it. Reserve its existing maximum 12px height.
		local reserve=if portrait then l.driftGaugeGap+l.gaugeHeight else artworkOverhang+10+12
		if size.X>=600 and not portrait and progressBottom-reserve-3-progressHeight-progressGap-l.slot<8+110+3 then
			-- Preserve the accepted short LAP/Item lane; the gauge uses a lateral
			-- clearance fallback when this vertical stack cannot fit.
			reserve=l.driftGaugeGap+l.gaugeHeight
		end
		progressBottom -= reserve+3
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

-- Inset overlay keeps a full outline inside clipped ScrollingFrames and above art.
function View.styleItem(button)
 button.BackgroundColor3=Color3.fromRGB(28,30,34);button.BackgroundTransparency=.52
 local corner=button:FindFirstChildOfClass('UICorner')
 if not corner then View.round(button,UDim.new(.28,0))else corner.CornerRadius=UDim.new(.28,0)end
 local frame=button:FindFirstChild('ItemOutline')
 if not frame then
  frame=Instance.new('Frame');frame.Name='ItemOutline';frame.BackgroundTransparency=1;frame.BorderSizePixel=0
  frame.Position=UDim2.fromOffset(1,1);frame.Size=UDim2.new(1,-2,1,-2);frame.Active=false;frame.ZIndex=button.ZIndex+6
  View.round(frame,UDim.new(.28,0));local stroke=View.stroke(frame,1)
  stroke.Color=Color3.new(1,1,1);stroke.Transparency=.35;frame.Parent=button
 end
 return frame
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
	elseif kind == "AutoForward" or kind == "AutoBackward" then
		-- Arrow plus visibly open/closed shackle; no text is needed.
		if kind == "AutoBackward" then
			line(12,7,12,30,4);line(12,30,4,22,4);line(12,30,20,22,4)
		else line(12,30,12,7,4); line(12,7,4,15,4); line(12,7,20,15,4) end
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
