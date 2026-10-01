-- Production SmokeEffectView execution; deterministic signals/time, no rendering claims.
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local count, now = 0, 0
local function check(v,label) assert(v,label);count+=1 end
local function signal()
	local listeners={}
	return {Connect=function(_,f)
		local entry={f=f,alive=true};table.insert(listeners,entry)
		return {Disconnect=function() entry.alive=false end}
	end,Fire=function(_,...) for _,entry in listeners do if entry.alive then entry.f(...) end end end}
end
local function object(class)
	local data={ClassName=class,Position=rb.UDim2.fromOffset(0,0),Size=rb.UDim2.fromOffset(0,0),
	 AnchorPoint=rb.Vector2.zero,Visible=true,Destroying=signal(),CharacterRemoving=signal()}
	local attrs,signals,children={},{},{}
	local self
	local methods={}
	function methods:GetAttribute(k) return attrs[k] end
	function methods:SetAttribute(k,v) local old=attrs[k];attrs[k]=v;if old~=v and signals[k] then signals[k]:Fire() end end
	function methods:GetAttributeChangedSignal(k) if not signals[k] then signals[k]=signal() end;return signals[k] end
	function methods:FindFirstChildOfClass(k) for _,c in children do if c.ClassName==k then return c end end end
	function methods:FindFirstChild(k) for _,c in children do if c.Name==k then return c end end end
	function methods:Destroy() self.Destroying:Fire();self.Parent=nil end
	self=setmetatable({}, {__index=function(_,k)
		if methods[k] then return methods[k] end
		if k=="AbsoluteSize" then
			if data.bounds then return data.bounds end
			if class=="ScreenGui" and data.Parent then return data.Parent.AbsoluteSize end
			local p=data.Parent and data.Parent.AbsoluteSize or rb.Vector2.zero
			return rb.Vector2.new(p.X*data.Size.X.Scale+data.Size.X.Offset,p.Y*data.Size.Y.Scale+data.Size.Y.Offset)
		end
		if k=="AbsolutePosition" then
			if data.origin then return data.origin end
			local p=data.Parent and data.Parent.AbsolutePosition or rb.Vector2.zero
			local s=data.Parent and data.Parent.AbsoluteSize or rb.Vector2.zero
			return p+rb.Vector2.new(s.X*data.Position.X.Scale+data.Position.X.Offset-self.AbsoluteSize.X*data.AnchorPoint.X,
			 s.Y*data.Position.Y.Scale+data.Position.Y.Offset-self.AbsoluteSize.Y*data.AnchorPoint.Y)
		end
		return data[k]
	end,__newindex=function(_,k,v) data[k]=v;if k=="Parent" and v then table.insert(v.children,self) end end})
	self.children=children
	return self
end
local heartbeat=signal()
local env={game={GetService=function(_,name) assert(name=="RunService");return {Heartbeat=heartbeat} end},
 Instance={new=object},UDim=rb.UDim,UDim2=rb.UDim2,Vector2=rb.Vector2,Enum=rb.Enum,Color3=rb.Color3,time=function() return now end}
local View=luau.load(fs.readFile("src/client/SmokeEffectView.luau"),{environment=env})()
local playerGui,player,kart,seat,character,human=object("PlayerGui"),object("Player"),object("Model"),object("Seat"),object("Model"),object("Humanoid")
local world=object("Workspace")
kart.Parent=world;seat.Parent=kart;human.Parent=character
human.Health=100;human.SeatPart=seat;player.Character=character
seat:SetAttribute("PrototypeKartSeat",true)
player:SetAttribute("RaceState","RACING");player:SetAttribute("RaceSessionId",1)
kart:SetAttribute("RaceResetSerial",1);kart:SetAttribute("KartSmokeSessionId",1);kart:SetAttribute("KartSmokeResetSerial",1)
local view=View.new(playerGui,player)
local gui=playerGui:FindFirstChild("KDMSmokeHaze");local haze=gui:FindFirstChild("Haze")
local function tick(dt) now+=dt or 0;heartbeat:Fire() end
check(gui.DisplayOrder==2 and not haze.Active,"haze below race HUD/controls and non-interactive")
tick();check(not haze.Visible,"inactive Smoke has no haze")
kart:SetAttribute("KartSmokeObscuredActive",true);tick()
check(haze.Visible,"false to true starts production haze")
tick(.12);check(math.abs(haze.BackgroundTransparency-.55)<.001,"full base opacity 45 percent")
local puffs,central=0,0
for _,p in haze.children do
 if p.ClassName=="Frame" then
  puffs+=1
  check(not p.Active and p.Visible and math.abs(p.BackgroundTransparency-.40)<.001,"visible 60-percent puff never captures touches")
  local pos=p.Position
  if pos.X.Scale>=.20 and pos.X.Scale<=.80 and pos.Y.Scale<=.50 then central+=1 end
 end
end
check(puffs==9 and central>=4,"bounded nine-puff view covers central horizon/corridor")
local center=haze:FindFirstChild("Puff3")
check(center.Position.X.Scale==.5 and math.abs(center.Position.Y.Scale-.42)<.0001 and center.Size.X.Scale>=.4,"vanishing point has real visible central puff")
for _,size in {rb.Vector2.new(932,430),rb.Vector2.new(844,390),rb.Vector2.new(748,303),rb.Vector2.new(390,844)} do
 playerGui.bounds=size
 check(haze.AbsoluteSize==size and haze.AbsolutePosition==rb.Vector2.zero,"haze fills landscape/portrait without moving other HUDs")
 check(not haze.Active,"mobile haze never captures input")
end
tick(2.87);check(haze.Visible and math.abs(haze.BackgroundTransparency-.55)<.001,"haze remains full while server active through approximately 3 seconds")
-- Client follows the server flag; fade does not extend gameplay authority.
kart:SetAttribute("KartSmokeObscuredActive",false);tick()
check(haze.Visible,"server expiry starts cosmetic fade-out")
tick(.14);check(haze.Visible and math.abs(haze.BackgroundTransparency-.775)<.001,"half of .28-second fade reaches half strength")
tick(.15);check(not haze.Visible,"fade-out completes near .28 seconds")
check(not kart:GetAttribute("KartSmokeObscuredActive"),"cosmetic fade never reactivates gameplay state")
for _,boundary in {"FINISHED","FINISHING","DNF","GARAGE","COUNTDOWN","PRE_RACE","session","reset","seat","locked","character","destroy"} do
 kart.Parent=world;player.Character=character;human.SeatPart=seat;human.Health=100
 player:SetAttribute("RaceState","RACING");kart:SetAttribute("RaceControlsLocked",false)
 kart:SetAttribute("KartSmokeSessionId",player:GetAttribute("RaceSessionId"));kart:SetAttribute("KartSmokeResetSerial",kart:GetAttribute("RaceResetSerial"))
 kart:SetAttribute("KartSmokeObscuredActive",false);tick();kart:SetAttribute("KartSmokeObscuredActive",true);tick(.13)
 check(haze.Visible,"active haze fixture "..boundary)
 if boundary=="session" then player:SetAttribute("RaceSessionId",player:GetAttribute("RaceSessionId")+1)
 elseif boundary=="reset" then kart:SetAttribute("RaceResetSerial",kart:GetAttribute("RaceResetSerial")+1)
 elseif boundary=="seat" then human.SeatPart=nil
 elseif boundary=="locked" then kart:SetAttribute("RaceControlsLocked",true)
 elseif boundary=="character" then player.CharacterRemoving:Fire();player.Character=nil
 elseif boundary=="destroy" then kart.Parent=nil
 else player:SetAttribute("RaceState",boundary) end
 tick();check(not haze.Visible,"immediate lifecycle cleanup "..boundary)
end
view:destroy();check(not gui.Parent,"view destruction cleans native UI/connections")
print("PASS: "..count.." production SmokeEffectView checks (mocked; device visibility required)")
