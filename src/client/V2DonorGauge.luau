-- AC6 stock gauge artwork only. Gear and transmission labels intentionally hidden.
local Gauge = {}
function Gauge.layout(width, height, mobile)
	local available = if mobile then math.min(width-176-(math.clamp(height*.15,44,56)*3+24)-28,
		2*(width/2-20-(math.clamp(height*.15,44,56)*3+24)-8)) else 320
	local w = math.min(300, available)
	return {width=math.max(1,w), height=math.max(1,w)*200/640,
		x=width/2, y=height-10, scale=math.max(1,w)/640, visible=w>=190 and width>height}
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
		if object:IsA("TextLabel") and object.Text ~= "" and object.TextTransparency < 1 then
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
	root.Gear.Visible=false;root.TMode.Visible=false
	local scale=Instance.new("UIScale");scale.Parent=root
	local function tick(dial,angle,label,major,red)
		local line=root.ln:Clone();line.Parent=dial;line.Rotation=angle;line.Visible=true
		if label~=nil then line.Num.Text=tostring(label);line.Num.Rotation=-angle;line.Num.Visible=true
		else line.Num:Destroy() end
		if red then line.Frame.BackgroundColor3=Color3.new(1,0,0) end
		if major then line.Frame.Size=UDim2.fromOffset(3,10);line.Frame.Position=UDim2.fromOffset(-1,100) end
		return line
	end
	for i=0,20 do
		tick(root.Tach,45+i*225/20,if i%2==0 then i/2 else nil,i%2==0,i>=18)
		if i>=18 and i<20 then tick(root.Tach,45+(i+.5)*225/20,nil,false,true) end
	end
	for i=1,90 do
		local line=tick(root.Speedo,45+225*i/90,nil,false,false)
		if i%2==0 then line.Frame.Size=UDim2.fromOffset(2,10);line.Frame.Position=UDim2.fromOffset(-1,100) end
	end
	for i=0,370,40 do
		local line=tick(root.Speedo,45+225*i/370,i,false,false)
		line.Num.TextSize=14;line.Frame:Destroy()
	end
	local objects=root:GetDescendants()
	for _, object in {root,table.unpack(objects)} do
		if object:IsA("GuiObject") then object.Active=false;object.Selectable=false end
	end
	local self={root=root}
	function self:update(state,size,mobile,blocked)
		local l=Gauge.layout(size.X,size.Y,mobile)
		scale.Scale=l.scale
		root.Visible=l.visible and not blocked
		root.Tach.Needle.Rotation=45+225*math.clamp(state.rpm/10000,0,1)
		root.Speedo.Needle.Rotation=45+225*math.clamp(state.speedKmh/370,0,1)
		root.Speed.Text=tostring(math.floor(state.speedKmh+.5)).." KM/H"
		local bounds=Gauge.visualBounds(root,objects)
		local offset=if bounds then bounds.maxY-(root.AbsolutePosition.Y+root.AbsoluteSize.Y) else 0
		root.Position=UDim2.fromOffset(l.x,l.y-offset)
		return root.Visible
	end
	function self:destroy() root:Destroy() end
	return self
end
return Gauge
