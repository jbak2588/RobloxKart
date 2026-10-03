-- Passive native twin semicircles; geometry is confined to the free center lane.
local Gauge={}
function Gauge.layout(width,height,mobile)
	local left=if mobile then 240 else width*.5-160
	local right=if mobile then width-20-(math.clamp(height*.15,44,56)*3+24)-8 else width*.5+160
	local w=math.min(300,right-left)
	local wheel=if mobile then math.min(112,width*.18) else (if height<=650 then 84 else 112)
	return {x=(left+right-w)*.5,y=height-3-wheel*2/3-8-64,width=w,height=64,
		visible=w>=190 and height>=240 and width>height and (mobile or width>=1000)}
end
function Gauge.new(parent)
	local root=Instance.new("Frame");root.Name="KDM_PowertrainGauge"
	root.BackgroundColor3=Color3.fromRGB(13,25,38);root.BackgroundTransparency=.18
	root.BorderSizePixel=0;root.Active=false;root.Selectable=false;root.ZIndex=2;root.Parent=parent
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,8);corner.Parent=root
	local function label(name,text,x,w,size)
		local l=Instance.new("TextLabel");l.Name=name;l.Text=text;l.BackgroundTransparency=1
		l.Position=UDim2.new(x,0,0,44);l.Size=UDim2.new(w,0,0,18);l.Font=Enum.Font.GothamBold
		l.TextSize=size or 11;l.TextColor3=Color3.new(1,1,1);l.Active=false;l.Selectable=false;l.ZIndex=3;l.Parent=root;return l
	end
	local needles={}
	for dial,cx in {.23,.77} do
		for i=0,10 do
			local a=math.pi+i*math.pi/10
			local tick=Instance.new("Frame");tick.Name="Tick"..dial.."_"..i;tick.Active=false;tick.Selectable=false
			tick.AnchorPoint=Vector2.new(.5,.5);tick.Position=UDim2.new(cx,math.cos(a)*35,0,40+math.sin(a)*35)
			tick.Size=UDim2.fromOffset(2,5);tick.Rotation=i*18-90;tick.BorderSizePixel=0
			tick.BackgroundColor3=if dial==1 and i>=9 then Color3.fromRGB(255,90,70) else Color3.fromRGB(70,210,240)
			tick.ZIndex=3;tick.Parent=root
		end
		local pivot=Instance.new("Frame");pivot.Name=if dial==1 then "RPMNeedle" else "SpeedNeedle"
		pivot.Position=UDim2.new(cx,0,0,40);pivot.Size=UDim2.fromOffset(0,0);pivot.BackgroundTransparency=1;pivot.Active=false;pivot.Selectable=false;pivot.Parent=root
		local needle=Instance.new("Frame");needle.Active=false;needle.Selectable=false;needle.Size=UDim2.fromOffset(30,2)
		needle.BackgroundColor3=Color3.new(1,1,1);needle.BorderSizePixel=0;needle.ZIndex=4;needle.Parent=pivot
		needles[dial]=pivot
	end
	label("RPMScale","0   2   4   6   8  10",.01,.44,9).Position=UDim2.new(.01,0,0,0)
	label("SpeedScale","0      60      120",.55,.44,9).Position=UDim2.new(.55,0,0,0)
	local rpm=label("RPM","x1000 RPM",.01,.44)
	local speed=label("Speed","0 km/h",.55,.44)
	local gear=label("Gear","1",.44,.12,26);gear.Position=UDim2.new(.44,0,0,9);gear.Size=UDim2.new(.12,0,0,30)
	label("Auto","AUTO",.44,.12,9)
	local self={root=root,elapsed=0}
	function self:update(state,topSpeedText,displaySpeed,dt,size,mobile,blocked)
		if self.width~=size.X or self.height~=size.Y or self.mobile~=mobile then
			self.width,self.height,self.mobile=size.X,size.Y,mobile
			self.layout=Gauge.layout(size.X,size.Y,mobile)
			root.Position=UDim2.fromOffset(self.layout.x,self.layout.y)
			root.Size=UDim2.fromOffset(math.max(1,self.layout.width),self.layout.height)
		end
		root.Visible=self.layout.visible and not blocked
		needles[1].Rotation=180+math.clamp(state.rpm/10000,0,1)*180
		needles[2].Rotation=180+math.clamp(displaySpeed/120,0,1)*180
		gear.TextSize=if state.shiftActive then 29 else 26
		if self.lastSpeedText~=topSpeedText then
			self.lastSpeedText=topSpeedText;speed.Text=topSpeedText.." km/h"
		end
		self.elapsed+=dt
		if self.elapsed>=.08 then
			self.elapsed=0;gear.Text=tostring(state.gear)
			rpm.Text=string.format("%.1f x1000 RPM",state.rpm/1000)
		end
	end
	function self:destroy() root:Destroy() end
	return self
end
return Gauge
