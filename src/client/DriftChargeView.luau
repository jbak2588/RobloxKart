-- Server attributes are the only source of charge. Local timers animate feedback only.
local View = require(script.Parent:WaitForChild("MobileControlView"))
local Gauge = {}

function Gauge.segmentCount(progress: number): number
	return math.floor(math.clamp(progress,0,1)*5)
end

function Gauge.create(root, debugEnabled, player)
	local frame=Instance.new("Frame")
	frame.Name="DriftChargeGauge"
	frame.AnchorPoint=Vector2.new(0.5,1)
	frame.Position=UDim2.fromOffset(0,-6)
	frame.BackgroundColor3=Color3.fromRGB(13,24,32)
	frame.BackgroundTransparency=0.15
	frame.BorderSizePixel=0
	frame.Active=false
	frame.Selectable=false
	frame.Visible=false
	frame.Parent=root
	View.round(frame,UDim.new(0,3))
	local streakLabel=Instance.new("TextLabel")
	streakLabel.Name="DriftStreak"
	streakLabel.AnchorPoint=Vector2.new(0.5,1)
	streakLabel.Size=UDim2.fromOffset(165,20)
	streakLabel.BackgroundTransparency=1
	streakLabel.Font=Enum.Font.GothamBold
	streakLabel.TextColor3=Color3.fromRGB(65,225,245)
	streakLabel.TextSize=13
	streakLabel.Visible=false
	streakLabel.Parent=root
	local bonusLabel=Instance.new("TextLabel")
	bonusLabel.Name="DriftBonusNitro"
	bonusLabel.AnchorPoint=Vector2.new(0.5,1)
	bonusLabel.Size=UDim2.fromOffset(165,24)
	bonusLabel.BackgroundTransparency=1
	bonusLabel.Font=Enum.Font.GothamBlack
	bonusLabel.TextColor3=Color3.fromRGB(255,218,75)
	bonusLabel.TextSize=17
	bonusLabel.Text="NITRO +1"
	bonusLabel.Visible=false
	bonusLabel.Parent=root
	local border=View.stroke(frame,1)
	local segments, fills={},{}
	for i=1,5 do
		local cell=Instance.new("Frame")
		cell.Name="Segment"..i
		cell.Position=UDim2.new((i-1)/5,2,0,2)
		cell.Size=UDim2.new(1/5,-3,1,-4)
		cell.BorderSizePixel=0
		cell.Active=false
		cell.Selectable=false
		cell.Parent=frame
		View.round(cell,UDim.new(0,1))
		local fill=Instance.new("Frame")
		fill.Name="Fill"
		fill.Size=UDim2.fromScale(0,1)
		fill.BorderSizePixel=0
		fill.Active=false
		fill.Selectable=false
		fill.Parent=cell
		View.round(fill,UDim.new(0,1))
		table.insert(fills,fill)
		table.insert(segments,cell)
	end
	local diagnostic=nil
	if debugEnabled then
		diagnostic=Instance.new("TextLabel")
		diagnostic.Name="DriftDiagnostic"
		diagnostic.AnchorPoint=Vector2.new(0,0)
		diagnostic.BackgroundColor3=Color3.fromRGB(10,18,25)
		diagnostic.BackgroundTransparency=0.40
		diagnostic.BorderSizePixel=0
		diagnostic.TextColor3=Color3.fromRGB(225,246,255)
		diagnostic.Font=Enum.Font.Code
		diagnostic.TextSize=11
		diagnostic.TextXAlignment=Enum.TextXAlignment.Left
		diagnostic.TextYAlignment=Enum.TextYAlignment.Center
		diagnostic.Text=""
		diagnostic.Active=false
		diagnostic.Selectable=false
		diagnostic.Visible=false
		diagnostic.Parent=root
		View.round(diagnostic,UDim.new(0,4))
	end
	local self={frame=frame,diagnostic=diagnostic,pulse=0,feedback=0,endTime=0,opacity=0,
		wasActive=false,wasReady=false,wasBoosting=false,lastProgress=0,lastSerial=nil,lastText="",success=false,
		bonusTime=0,lastAwarded=false}
	function self:layout(size,mobile,wheel,origin)
		local l=View.layout(size)
		if mobile then
			frame.Size=UDim2.fromOffset(l.action,l.gaugeHeight)
			-- Leave room for the three-pixel READY border pulse on real displays.
			frame.Position=UDim2.new(0,l.driftX+l.action/2,1,-l.driftBottom-l.action-l.driftGaugeGap)
		else
			frame.Size=UDim2.fromOffset(math.clamp(size.X*0.12,140,160),if size.Y<=650 then 18 else 20)
			if wheel then
				local position=wheel.AbsolutePosition-origin
				frame.Position=UDim2.fromOffset(position.X+wheel.AbsoluteSize.X/2,position.Y-10)
			else
				local diameter=if size.Y<=650 then 84 else 112
				frame.Position=UDim2.new(.5,0,1,-diameter*2/3-10)
			end
		end
		streakLabel.Position=UDim2.new(frame.Position.X.Scale,frame.Position.X.Offset,
			frame.Position.Y.Scale,frame.Position.Y.Offset-frame.Size.Y.Offset-5)
		bonusLabel.Position=UDim2.new(streakLabel.Position.X.Scale,streakLabel.Position.X.Offset,
			streakLabel.Position.Y.Scale,streakLabel.Position.Y.Offset-20)
		if diagnostic then
			local width=math.min(184,size.X/2-60)
			local x,y=size.X-width-12,size.Y-116
			if mobile then
				if size.X<500 and size.Y>size.X then
					x,y=12,116
				elseif size.X<700 then
					width=math.min(144,size.X-l.margin-l.padWidth-8-(l.margin+l.slot*3+24))
					x,y=l.margin+l.slot*3+24,64
				else
					-- Fit between the 160px speed panel and minimap, including phone safe insets.
					width=math.min(width,size.X-112-8-(size.X/2+80+8))
					x,y=size.X-112-width-8,8
				end
			end
			diagnostic.Size=UDim2.fromOffset(width,104)
			diagnostic.Position=UDim2.fromOffset(x,y)
			diagnostic.TextSize=if width<160 then 10 else 11
		end
	end
	function self:reset(kart)
		self.pulse,self.feedback,self.endTime,self.opacity=0,0,0,0
		self.wasActive,self.wasReady,self.wasBoosting=false,false,false
		self.lastProgress,self.lastText,self.success=0,"",false
		self.lastSerial=kart and kart:GetAttribute("KartDriftDiagEndSerial")
		self.bonusTime=0
		self.lastAwarded=player and player:GetAttribute("DriftBonusNitroAwarded")==true or false
		frame.Visible=false
		streakLabel.Visible=false
		bonusLabel.Visible=false
		frame:SetAttribute("LitSegments",0)
		border.Thickness=1
		for i,cell in segments do
			cell.BackgroundColor3=Color3.fromRGB(45,60,70)
			fills[i].Size=UDim2.fromScale(0,1)
		end
		if diagnostic then diagnostic.Visible=false; diagnostic.Text="" end
	end
	function self:updateCharge(progress,ready,active,held,boosting,delta)
		self.pulse=math.max(0,self.pulse-delta)
		self.feedback=math.max(0,self.feedback-delta)
		if ready and not self.wasReady then self.pulse=0.20 end
		if self.wasActive and not active then self.feedback=0.30 end
		if boosting and not self.wasBoosting and (self.wasActive or self.feedback>0) then
			self.success=true;self.lastProgress=1;self.feedback=0.30;self.pulse=0.20
		end
		if active then
			self.lastProgress=if ready then 1 else progress
			self.feedback=0
			self.success=false
		end
		local display=if active then self.lastProgress elseif self.feedback>0 then self.lastProgress else 0
		if active or held then self.opacity=math.min(1,self.opacity+delta/0.12)
		elseif self.feedback>0 then self.opacity=math.min(self.opacity,self.feedback/0.30)
		else self.opacity=0;self.lastProgress=0 end
		local color=if ready or self.success then Color3.fromRGB(255,218,75) else Color3.fromRGB(65,225,245)
		frame.Visible=self.opacity>0
		frame.BackgroundTransparency=1-0.85*self.opacity
		border.Thickness=if self.pulse>0 then 3 else 1
		border.Color=color
		border.Transparency=1-self.opacity
		for i,cell in segments do
			cell.BackgroundColor3=Color3.fromRGB(45,60,70)
			cell.BackgroundTransparency=1-self.opacity
			local fill=fills[i]
			fill.Size=UDim2.fromScale(math.clamp(display*5-(i-1),0,1),1)
			fill.BackgroundColor3=color
			fill.BackgroundTransparency=1-self.opacity
		end
		frame:SetAttribute("LitSegments",Gauge.segmentCount(display))
		self.wasActive,self.wasReady,self.wasBoosting=active,ready,boosting
	end
	function self:updateDiagnostic(kart,active,held,delta)
		if not diagnostic then return end
		local function attr(key) return kart:GetAttribute("KartDriftDiag"..key) end
		local function number(key) local v=attr(key);return if type(v)=="number" then v else 0 end
		local function snapshot()
			return string.format("D %.2f Q %.2f\nS %.1f\nIA %.2f/%.2f\nDT %.3f/%.3f\nV %.0f T %.1f St %.2f\nIV %s R %.2f",
				number("Duration"),number("Qualified"),number("SlipDegrees"),number("InputAge"),number("MaxInputAge"),
				number("ServerDelta"),number("MaxServerDelta"),number("Speed"),number("Throttle"),number("Steering"),
				if attr("InputValid")==true then "Y" else "N",number("RawSteering"))
		end
		self.endTime=math.max(0,self.endTime-delta)
		local serial=attr("EndSerial")
		if serial~=nil and self.lastSerial~=nil and serial~=self.lastSerial then
			self.endTime=2
			self.endSnapshot=snapshot()..string.format("\nEND %s\nBOOST %s",attr("EndReason") or "?",if attr("BoostEligible")==true then "YES" else "NO")
		end
		self.lastSerial=serial
		if active then self.endTime=0 end
		diagnostic.Visible=held or active or self.endTime>0
		diagnostic.Text=if self.endTime>0 then self.endSnapshot else snapshot()
	end
	function self:update(enabled,kart,held,delta)
		if not enabled or not kart then self:reset(kart); return end
		local count=if player then player:GetAttribute("DriftStreakCount") else 0
		local awarded=player and player:GetAttribute("DriftBonusNitroAwarded")==true or false
		if awarded and not self.lastAwarded then self.bonusTime=1 end
		self.lastAwarded=awarded
		self.bonusTime=math.max(0,self.bonusTime-delta)
		streakLabel.Visible=true
		streakLabel.Text=if awarded then "DRIFT STREAK  BONUS EARNED"
			else string.format("DRIFT STREAK  %d / 4",if type(count)=="number" then count else 0)
		bonusLabel.Visible=self.bonusTime>0
		local progress=math.clamp(kart:GetAttribute("KartDriftChargeProgress") or 0,0,1)
		local ready=kart:GetAttribute("KartDriftChargeReady")==true
		local active=kart:GetAttribute("KartDrifting")==true or progress>0 or ready
		self:updateCharge(progress,ready,active,held,kart:GetAttribute("KartBoosting")==true,delta)
		self:updateDiagnostic(kart,active,held,delta)
	end
	self:reset(nil)
	return self
end

return Gauge
