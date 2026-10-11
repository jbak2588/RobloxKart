-- AC6 stock gauge artwork only. Gear and transmission labels intentionally hidden.
local Gauge = {}
function Gauge.layout(width, height, mobile)
	-- Leave the full four-item-width Drift hitbox clear in the left thumb lane.
	local slot=if width>=700 and height>=360 then 48 else 44
	local driftWidth=slot*4+24
	local driftRight=12+driftWidth+(math.ceil(driftWidth*1.10)-driftWidth)/2
	local visual=if width<500 and height<260 then 58 elseif height<340 then 62 else 68
	local autoVisual=if height<340 then 52 else 58
	local spacing=(visual+autoVisual)/2+10
	local padWidth=visual+4+spacing*2
	local margin=if width>=700 then 20 else 12
	local mapSide=if height<330 then 96 elseif height<390 then 104 else 112
	local inset=10-margin
	local padLeft=width-margin-padWidth-inset
	local left,right=driftRight+8,padLeft-4
	local available = if mobile then right-left else 320
	local w = math.min(300, available)
	return {width=math.max(1,w), height=math.max(1,w)*200/640,
		x=if mobile then math.clamp(width/2,left+math.max(1,w)/2,math.max(left+math.max(1,w)/2,right-math.max(1,w)/2)) else width/2,
		y=height-10, scale=math.max(1,w)/640, visible=w>=190 and width>height}
end

local function rotate(point, center, degrees)
	local angle = math.rad(degrees)
	local x, y = point.X-center.X, point.Y-center.Y
	return Vector2.new(center.X+x*math.cos(angle)-y*math.sin(angle),
		center.Y+x*math.sin(angle)+y*math.cos(angle))
end

-- Painted child bounds, including zero-sized donor text and rotated ticks/needles.
-- Transparent root/container padding never counts as visible content.
function Gauge.visualBounds(root, objects)
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, object in objects or root:GetDescendants() do
		if not object:IsA("GuiObject") then continue end
		local visible, ancestor = true, object
		while ancestor and ancestor ~= root.Parent do
			if ancestor:IsA("GuiObject") then
				if not ancestor.Visible then visible=false;break end
			end
			ancestor=ancestor.Parent
		end
		if not visible then continue end
		local position, size = object.AbsolutePosition, object.AbsoluteSize
		local rectangles = {}
		if object.BackgroundTransparency < 1 and size.X > 0 and size.Y > 0 then
			table.insert(rectangles, {position, size})
		end
		if (object:IsA("TextLabel") or object:IsA("TextButton")) and object.Text ~= "" and object.TextTransparency < 1 then
			local text = object.TextBounds
			if text.X > 0 and text.Y > 0 then
				local x = if object.TextXAlignment == Enum.TextXAlignment.Left then 0
					elseif object.TextXAlignment == Enum.TextXAlignment.Right then size.X-text.X else (size.X-text.X)/2
				local y = if object.TextYAlignment == Enum.TextYAlignment.Top then 0
					elseif object.TextYAlignment == Enum.TextYAlignment.Bottom then size.Y-text.Y else (size.Y-text.Y)/2
				table.insert(rectangles, {position+Vector2.new(x,y), text})
			end
		end
		for _, rectangle in rectangles do
			local p, s = rectangle[1], rectangle[2]
			for _, corner in {p,p+Vector2.new(s.X,0),p+s,p+Vector2.new(0,s.Y)} do
				-- AbsolutePosition already includes ancestor rotation in Roblox.
				-- Rotate the painted rectangle once about its world center.
				if object.AbsoluteRotation ~= 0 then
					corner=rotate(corner,position+size/2,object.AbsoluteRotation)
				end
				minX=math.min(minX,corner.X);minY=math.min(minY,corner.Y)
				maxX=math.max(maxX,corner.X);maxY=math.max(maxY,corner.Y)
			end
		end
	end
	return if minX < math.huge then {minX=minX,minY=minY,maxX=maxX,maxY=maxY} else nil
end

function Gauge.new(parent)
	local root=script.Parent:WaitForChild("V2DonorGaugeTemplate"):Clone()
	root.Name="KDM_V2Gauge"
	root.Size=UDim2.fromOffset(640,200)
	root.AnchorPoint=Vector2.new(.5,1)
	root.Parent=parent
	root.Gear.Visible=false;root.TMode.Visible=true
	root.TMode.Text="A/T"
	root.TMode.AnchorPoint=Vector2.new(.5,.5)
	root.TMode.Position=UDim2.fromOffset(137,173)
	root.TMode.Size=UDim2.fromOffset(60,20)
	root.TMode.TextSize=18
	local scale=Instance.new("UIScale");scale.Parent=root
	-- Preserve the outer left/right edges and lower edge while shrinking each dial.
	root.Tach.Position=UDim2.new(.5,-183,1,-67)
	root.Speedo.Position=UDim2.new(.5,183,1,-67)
	for _,dial in {root.Tach,root.Speedo} do
		local dialScale=Instance.new("UIScale");dialScale.Scale=.7;dialScale.Parent=dial
	end
	root.Speed.Visible=false
	local digital=Instance.new("Frame")
	digital.Name="DigitalSpeedGroup";digital.AnchorPoint=Vector2.new(.5,1)
	digital.BackgroundTransparency=1;digital.Size=UDim2.fromOffset(200,40);digital.Parent=root
	local value=Instance.new("TextLabel");value.Name="SpeedValue"
	value.Font=Enum.Font.GothamBlack;value.TextSize=40;value.Text="0";value.Parent=digital
	local unit=Instance.new("TextLabel");unit.Name="SpeedUnit"
	unit.Font=root.Speed.Font;unit.TextSize=28;unit.Text="KM/H";unit.Parent=digital
	for _,label in {value,unit} do
		label.BackgroundTransparency=1;label.TextColor3=root.Speed.TextColor3
		label.TextYAlignment=Enum.TextYAlignment.Bottom;label.TextXAlignment=Enum.TextXAlignment.Center
		label.AnchorPoint=Vector2.new(0,1)
	end
	local function tick(dial,angle,label,major,red)
		local line=root.ln:Clone();line.Parent=dial;line.Rotation=angle;line.Visible=true
		if label~=nil then line.Num.Text=tostring(label);line.Num.Rotation=-angle;line.Num.Visible=true
		else line.Num:Destroy() end
		if red then line.Frame.BackgroundColor3=Color3.new(1,0,0) end
		if major then line.Frame.Size=UDim2.fromOffset(3,10);line.Frame.Position=UDim2.fromOffset(-1,100) end
		return line
	end
	for i=0,28 do
		local rpm=i*250
		tick(root.Tach,45+225*rpm/7000,if i%4==0 then rpm/1000 else nil,i%4==0,rpm>=5000)
	end
	for speed=0,150,5 do
		local line=tick(root.Speedo,45+225*speed/150,if speed%20==0 or speed==150 then speed else nil,speed%10==0,speed>=80)
		if line:FindFirstChild("Num") then line.Num.TextSize=18 end
	end
	local objects=root:GetDescendants()
	local dialObjects={}
	for _,object in objects do if object~=digital and not object:IsDescendantOf(digital) then table.insert(dialObjects,object) end end
	for _, object in {root,table.unpack(objects)} do
		if object:IsA("GuiObject") then object.Active=false;object.Selectable=false end
	end
	local self={root=root}
	local lastWidth,lastHeight,lastMobile,lastVisible=nil,nil,nil,nil
	local settle=0
	local cachedLayout,lastNumberWidth,lastUnitWidth=nil,nil,nil
	local cachedDigitalY,cachedOffset=nil,0
	function self:update(state,size,mobile,blocked)
		if not cachedLayout or size.X~=lastWidth or size.Y~=lastHeight or mobile~=lastMobile then
			cachedLayout=Gauge.layout(size.X,size.Y,mobile)
			scale.Scale=cachedLayout.scale
		end
		local l=cachedLayout
		root.Visible=l.visible and not blocked
		if size.X~=lastWidth or size.Y~=lastHeight or mobile~=lastMobile or root.Visible~=lastVisible then
			lastWidth,lastHeight,lastMobile,lastVisible=size.X,size.Y,mobile,root.Visible
			settle=3 -- Let Roblox resolve newly resized text and absolute bounds.
		end
		if not root.Visible then return false end
		root.Tach.Needle.Rotation=45+225*math.clamp(state.rpm/7000,0,1)
		root.Speedo.Needle.Rotation=45+225*math.clamp(state.speedKmh/150,0,1)
		local text=tostring(math.floor(state.speedKmh+.5))
		if value.Text~=text then value.Text=text end
		local numberWidth=value.TextBounds.X/l.scale
		local unitWidth=unit.TextBounds.X/l.scale
		if numberWidth~=lastNumberWidth or unitWidth~=lastUnitWidth then
			lastNumberWidth,lastUnitWidth=numberWidth,unitWidth
			local total=numberWidth+5+unitWidth
			digital.Size=UDim2.fromOffset(total,40)
			value.Size=UDim2.fromOffset(numberWidth,40);value.Position=UDim2.new(0,0,1,0)
			unit.Size=UDim2.fromOffset(unitWidth,28);unit.Position=UDim2.new(0,numberWidth+5,1,0)
		end
		if settle>0 then
			settle-=1
			local dialBounds=Gauge.visualBounds(root,dialObjects)
			if dialBounds then cachedDigitalY=(dialBounds.maxY-root.AbsolutePosition.Y)/l.scale end
			if cachedDigitalY then digital.Position=UDim2.fromOffset(320,cachedDigitalY) end
			local bounds=Gauge.visualBounds(root,objects)
			cachedOffset=if bounds then bounds.maxY-(root.AbsolutePosition.Y+root.AbsoluteSize.Y) else 0
		end
		local position=UDim2.fromOffset(l.x,l.y-cachedOffset)
		if root.Position~=position then root.Position=position end
		return root.Visible
	end
	function self:destroy() root:Destroy() end
	return self
end
return Gauge
