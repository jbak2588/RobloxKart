local Controller={}
function Controller.digitalLayout(size,layout)
 if layout and layout.controlsV1 then return {width=160,bottom=12,textSize=24} end
	local bottom,width=8,180
	if layout then
		local left=layout.driftX+layout.driftHitWidth+8
		local right=size.X-layout.margin-layout.padWidth-layout.padInset-8
		local centeredWidth=2*math.min(size.X*.5-left,right-size.X*.5)
		if centeredWidth<110 then
			bottom=math.max(layout.padBottom+layout.padHeight,layout.driftBottom+layout.driftHitHeight)+8
		else width=math.min(width,centeredWidth) end
	end
	return {width=width,bottom=bottom,textSize=math.min(28,math.floor(width/6.4))}
end
function Controller.new(playerGui,mode,layoutView)
	local gui=Instance.new("ScreenGui")
	gui.Name="KDMV2GaugeHud"
	gui.ResetOnSpawn=false
	-- Physical-screen bottom, including donor transparent padding correction.
	-- The centered passive artwork fits outside side cutouts; portrait is suppressed.
	gui.ScreenInsets=Enum.ScreenInsets.None
	gui.ClipToDeviceSafeArea=false
	gui.DisplayOrder=10
	gui.Parent=playerGui
	if mode=="DIGITAL" then
		gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
		gui.ClipToDeviceSafeArea=true
		local label=Instance.new("TextLabel")
		label.Name="DigitalSpeedOnly";label.AnchorPoint=Vector2.new(.5,1)
		label.Position=UDim2.new(.5,0,1,-8);label.Size=UDim2.fromOffset(180,38)
		label.BackgroundTransparency=1;label.Font=Enum.Font.GothamBlack;label.TextSize=28
		label.TextColor3=Color3.new(1,1,1);label.TextStrokeTransparency=.4
		label.Active=false;label.Text="0 KM/H";label.Parent=gui
		local elapsed,lastSize,lastMobile=0,nil,nil
		return {gui=gui,update=function(_,chassis,speed,dt,mobile,active)
			local size=gui.AbsoluteSize
			if size and (size~=lastSize or mobile~=lastMobile) then
				lastSize,lastMobile=size,mobile
				local l=Controller.digitalLayout(size,if mobile and layoutView then layoutView.layout(size) else nil)
				label.Position=UDim2.new(.5,0,1,-l.bottom);label.Size=UDim2.fromOffset(l.width,38);label.TextSize=l.textSize
			end
			label.Visible=active and chassis~=nil
			elapsed+=dt
			if elapsed>=.08 then
				elapsed=0
				local text=tostring(math.floor(speed*1.008+.5)).." KM/H"
				if label.Text~=text then label.Text=text end
			end
			return label.Visible
		end,destroy=function()gui:Destroy()end}
	end
	local Gauge=require(script.Parent:WaitForChild("V2DonorGauge"))
	local Presentation=require(script.Parent:WaitForChild("V2GaugePresentation"))
	local gauge=Gauge.new(gui)
	local model=Presentation.new()
	local owner=nil
	local wasActive=false
	local idleState={rpm=700,speedKmh=0}
	local self={gui=gui,gauge=gauge}
	function self:update(chassis,speed,dt,mobile,active)
		if chassis~=owner or (wasActive and not active) then model=Presentation.new();owner=chassis end
		wasActive=active
		if not active or chassis==nil then return gauge:update(idleState,gui.AbsoluteSize,mobile,true) end
		local kart=chassis and chassis.Parent
		return gauge:update(model:update(speed,dt,kart and kart:GetAttribute("KartBoosting")==true,
			kart and kart:GetAttribute("KartNitroActive")==true),gui.AbsoluteSize,mobile,not active or chassis==nil)
	end
	function self:destroy() gui:Destroy() end
	return self
end
return Controller
