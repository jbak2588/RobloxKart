-- Original AC6_Stock_Gauges hierarchy and tick/needle formulas, uniformly scaled.
local Gauge={}
function Gauge.layout(width,height,mobile)
	local available=if mobile then math.min(width-176-(math.clamp(height*.15,44,56)*3+24)-28,
		2*(width/2-20-(math.clamp(height*.15,44,56)*3+24)-8)) else 320
	local widthUsed=math.min(300,available)
	return {width=math.max(1,widthUsed),height=math.max(1,widthUsed)*200/640,
		x=width/2,y=height-14,scale=math.max(1,widthUsed)/640,visible=widthUsed>=190 and width>height}
end
function Gauge.new(parent)
	local root=script.Parent:WaitForChild("V2DonorGaugeTemplate"):Clone()
	root.Name="KDM_V2DonorGauge";root.Size=UDim2.fromOffset(640,200)
	root.AnchorPoint=Vector2.new(.5,1);root.Parent=parent
	local scale=Instance.new("UIScale");scale.Parent=root
	local function tick(parentDial,angle,label,major,red)
		local ln=root.ln:Clone();ln.Parent=parentDial;ln.Rotation=angle;ln.Visible=true
		if label~=nil then ln.Num.Text=tostring(label);ln.Num.Rotation=-angle;ln.Num.Visible=true else ln.Num:Destroy() end
		if red then ln.Frame.BackgroundColor3=Color3.new(1,0,0) end
		if major then ln.Frame.Size=UDim2.fromOffset(3,10);ln.Frame.Position=UDim2.fromOffset(-1,100) end
		return ln
	end
	for i=0,20 do
		tick(root.Tach,45+i*225/20,if i%2==0 then i/2 else nil,i%2==0,i>=18)
		if i>=18 and i<20 then tick(root.Tach,45+(i+.5)*225/20,nil,false,true) end
	end
	for i=1,90 do
		local ln=tick(root.Speedo,45+225*i/90,nil,false,false)
		if i%2==0 then ln.Frame.Size=UDim2.fromOffset(2,10);ln.Frame.Position=UDim2.fromOffset(-1,100) end
	end
	for i=0,370,40 do local ln=tick(root.Speedo,45+225*i/370,i,false,false);ln.Num.TextSize=14;ln.Frame:Destroy() end
	root.TMode.Text="A/T"
	local self={root=root}
	function self:update(state,size,mobile,blocked)
		local l=Gauge.layout(size.X,size.Y,mobile)
		scale.Scale=l.scale;root.Position=UDim2.fromOffset(l.x,l.y);root.Visible=l.visible and not blocked
		root.Tach.Needle.Rotation=45+225*math.min(1,state.RPM/10000)
		root.Speedo.Needle.Rotation=45+225*math.min(1,state.speedKmh/370)
		root.Gear.Text=if state.Gear==0 then "N" elseif state.Gear==-1 then "R" else tostring(state.Gear)
		root.Speed.Text=tostring(math.floor(state.speedKmh)).." KM/H"
	end
	function self:destroy() root:Destroy() end
	return self
end
return Gauge
