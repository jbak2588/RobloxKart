-- Native local haze below every driving/HUD GUI; never changes camera or input.
local RunService = game:GetService("RunService")
local View = {}
function View.new(playerGui, player)
	local gui=Instance.new("ScreenGui")
	gui.Name,gui.ResetOnSpawn,gui.DisplayOrder="KDMSmokeHaze",false,2
	gui.IgnoreGuiInset=true;gui.Parent=playerGui
	local haze=Instance.new("Frame")
	haze.Name="Haze";haze.Size=UDim2.fromScale(1,1)
	haze.BackgroundColor3=Color3.fromRGB(45,48,52);haze.BorderSizePixel=0
	haze.BackgroundTransparency=1;haze.Active=false;haze.Visible=false;haze.Parent=gui
	local puffs={}
	for index,position in {Vector2.new(.05,.25),Vector2.new(.30,.08),Vector2.new(.72,.12),Vector2.new(.94,.38),
		Vector2.new(.84,.83),Vector2.new(.52,.94),Vector2.new(.12,.86)} do
		local puff=Instance.new("Frame")
		puff.Name="Puff"..index;puff.AnchorPoint=Vector2.new(.5,.5)
		puff.Position=UDim2.fromScale(position.X,position.Y);puff.Size=UDim2.fromScale(.42,.62)
		puff.BackgroundColor3=Color3.fromRGB(40,43,48);puff.BorderSizePixel=0;puff.Active=false;puff.Parent=haze
		local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=puff
		table.insert(puffs,puff)
	end
	local kart,session,reset,born,wasActive,fadeUntil
	local connections={}
	local function clear() haze.Visible=false;born=nil;wasActive=false;fadeUntil=nil end
	local function paint(strength)
		haze.Visible=true;haze.BackgroundTransparency=1-.22*strength
		for _,puff in puffs do puff.BackgroundTransparency=1-.42*strength end
	end
	local function update()
		local human=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local seat=human and human.SeatPart
		local current=seat and seat.Parent
		if player:GetAttribute("RaceState") ~= "RACING" or not human or human.Health<=0
			or not seat or seat:GetAttribute("PrototypeKartSeat")~=true or not current or not current.Parent
			or current:GetAttribute("RaceControlsLocked")==true then clear();kart=nil;return end
		local nextSession,nextReset=player:GetAttribute("RaceSessionId"),current:GetAttribute("RaceResetSerial")
		if current:GetAttribute("KartSmokeSessionId") ~= nextSession
			or current:GetAttribute("KartSmokeResetSerial") ~= nextReset then clear();return end
		if current~=kart or nextSession~=session or nextReset~=reset then
			clear();kart,session,reset=current,nextSession,nextReset
		end
		local active=current:GetAttribute("KartSmokeObscuredActive")==true
		if not active then
			if wasActive then fadeUntil=time()+.12;wasActive=false end
			if fadeUntil and time()<fadeUntil then paint((fadeUntil-time())/.12) else clear() end
			return
		end
		if not wasActive then born=time();fadeUntil=nil end
		wasActive=true
		local strength=math.min(1,(time()-born)/.12)
		paint(strength)
	end
	table.insert(connections,RunService.Heartbeat:Connect(update))
	for _,attribute in {"RaceState","RaceSessionId"} do
		table.insert(connections,player:GetAttributeChangedSignal(attribute):Connect(clear))
	end
	table.insert(connections,player.CharacterRemoving:Connect(clear))
	local self={}
	function self:destroy() clear();for _,c in connections do c:Disconnect() end;gui:Destroy() end
	return self
end
return View
