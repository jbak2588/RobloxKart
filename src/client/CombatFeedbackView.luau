-- Local presentation only. Outcomes come from server serials / Kart attributes.
local RunService = game:GetService("RunService")
local View = {}
function View.new(gui, player, onClear)
	local cue = Instance.new("TextLabel")
	cue.Name = "CombatResult"
	cue.AnchorPoint = Vector2.new(0.5, 0)
	cue.BackgroundTransparency = 1
	cue.Font, cue.TextSize = Enum.Font.GothamBold, 14
	cue.TextStrokeColor3, cue.TextStrokeTransparency = Color3.fromRGB(16, 25, 35), 0.35
	cue.TextTruncate = Enum.TextTruncate.AtEnd
	cue.Active, cue.Visible, cue.Parent = false, false, gui
	local edges = {}
	for i = 1, 2 do
		local edge = Instance.new("Frame")
		edge.Name = "CombatEdge" .. i
		edge.Position = UDim2.new(i-1, if i == 2 then -3 else 0, 0.1, 0)
		edge.Size = UDim2.new(0, 3, 0.8, 0)
		edge.BorderSizePixel, edge.Active, edge.Visible, edge.Parent = 0, false, false, gui
		table.insert(edges, edge)
	end
	local untilTime, flashUntil = 0, 0
	local kart, session, reset, wasMissile, wasSlick
	local connections = {}
	local stopped = false
	local function clear(notify)
		untilTime, flashUntil = 0, 0
		cue.Visible, cue.Text = false, ""
		for _, edge in edges do edge.Visible = false end
		if notify and onClear then onClear() end
	end
	local function activeKart()
		if player:GetAttribute("RaceState") ~= "RACING" then return nil end
		local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local seat = human and human.SeatPart
		local candidate = seat and seat.Parent
		if not human or human.Health <= 0 or not seat or seat:GetAttribute("PrototypeKartSeat") ~= true
			or not candidate or not candidate.Parent or candidate:GetAttribute("PrototypeKart") ~= true
			or candidate:GetAttribute("RaceControlsLocked") == true then return nil end
		return candidate
	end
	local function sync()
		local current = activeKart()
		local currentSession = player:GetAttribute("RaceSessionId")
		local currentReset = current and current:GetAttribute("RaceResetSerial")
		if current ~= kart or currentSession ~= session or currentReset ~= reset then
			clear(kart ~= nil) -- Initial seat binding must not erase a just-authored launch notice.
			kart, session, reset = current, currentSession, currentReset
			wasMissile = current and current:GetAttribute("KartMissileHitActive") == true
			wasSlick = current and current:GetAttribute("KartSlickActive") == true
		end
		if not current then clear() end
		return current
	end
	local function show(text, color, duration, flash)
		cue.Text, cue.TextColor3, untilTime = text, color, time()+duration
		cue.Visible = true
		if flash then
			flashUntil = time()+0.45
			for _, edge in edges do edge.BackgroundColor3, edge.BackgroundTransparency, edge.Visible = color, 0.4, true end
		end
	end
	local orange = Color3.fromRGB(255, 200, 75)
	local cyan = Color3.fromRGB(65, 225, 255)
	local purple = Color3.fromRGB(185, 125, 255)
	table.insert(connections, player:GetAttributeChangedSignal("RaceCombatFeedbackSerial"):Connect(function()
		if not sync() then return end
		local code = player:GetAttribute("RaceCombatFeedbackCode")
		local name = player:GetAttribute("RaceCombatFeedbackTargetName") or ""
		if code == "MISSILE_HIT" then show("HIT: "..name, orange, 0.8, false)
		elseif code == "MISSILE_BLOCKED" then show("SHIELD BLOCKED", cyan, 0.8, false)
		elseif code == "SLICK_HIT" then show("SLICK HIT: "..name, purple, 0.8, false)
		elseif code == "SLICK_BLOCKED" then show("SLICK BLOCKED", cyan, 0.8, false) end
	end))
	table.insert(connections, player:GetAttributeChangedSignal("RaceItemBlockedSerial"):Connect(function()
		if sync() then show("BLOCKED!", cyan, 0.45, true) end
	end))
	for _, attr in {"RaceState", "RaceSessionId"} do
		table.insert(connections, player:GetAttributeChangedSignal(attr):Connect(function() clear(true); kart=nil end))
	end
	table.insert(connections, player.CharacterRemoving:Connect(function() clear(true); kart=nil end))
	table.insert(connections, RunService.Heartbeat:Connect(function()
		local current = sync()
		if current then
			local missile = current:GetAttribute("KartMissileHitActive") == true
			local slick = current:GetAttribute("KartSlickActive") == true
			if missile and not wasMissile then show("MISSILE HIT", orange, 0.45, true)
			elseif slick and not wasSlick then show("SLICK!", purple, 0.45, true) end
			wasMissile, wasSlick = missile, slick
		end
		cue.Visible = current ~= nil and time() < untilTime
		for _, edge in edges do
			edge.Visible = current ~= nil and time() < flashUntil
			if edge.Visible then edge.BackgroundTransparency = 0.4 + 0.6 * (1-(flashUntil-time())/0.45) end
		end
	end))
	local self = {}
	function self:layout(position, size)
		cue.Position, cue.Size = position + UDim2.fromOffset(0, 44), UDim2.fromOffset(size.X.Offset, 22)
	end
	function self:destroy()
		if stopped then return end
		stopped=true; clear()
		for _, connection in connections do connection:Disconnect() end
		cue:Destroy(); for _, edge in edges do edge:Destroy() end
	end
	table.insert(connections, gui.Destroying:Connect(function() self:destroy() end))
	return self
end
return View
