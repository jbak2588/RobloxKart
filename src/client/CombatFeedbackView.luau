-- Local presentation only. Outcomes come from server serials / Kart attributes.
local RunService = game:GetService("RunService")
local KartConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KartConfig"))
local View = {}
function View.isPracticeResult(text)
	return type(text) == "string" and (text:find("HIT", 1, true) ~= nil
		or text:find("BLOCKED", 1, true) ~= nil or text == "SHOCKED!" or text == "SMOKED!")
end
function View.new(gui, player, onClear, practice)
	local cue = Instance.new("TextLabel")
	cue.Name = "CombatResult"
	cue.AnchorPoint = Vector2.new(0.5, 0)
	cue.BackgroundColor3 = Color3.fromRGB(16, 25, 35)
	cue.BackgroundTransparency = 0.25
	cue.BorderSizePixel, cue.ZIndex = 0, 20
	cue.Font, cue.TextSize = Enum.Font.GothamBold, 17
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0, 8), cue
	cue.TextStrokeColor3, cue.TextStrokeTransparency = Color3.fromRGB(16, 25, 35), 0.35
	cue.TextTruncate = Enum.TextTruncate.AtEnd
	cue.Active, cue.Visible, cue.Parent = false, false, gui
	local edges = {}
	for i = 1, 2 do
		local edge = Instance.new("Frame")
		edge.Name = "CombatEdge" .. i
		edge.Position = UDim2.new(i-1, if i == 2 then -6 else 0, 0.1, 0)
		edge.Size = UDim2.new(0, 6, 0.8, 0)
		edge.BorderSizePixel, edge.Active, edge.Visible, edge.Parent = 0, false, false, gui
		table.insert(edges, edge)
	end
	local untilTime, flashUntil = 0, 0
	local kart, session, reset, wasMissile, wasSlick, wasSmoke, wasThunder
	local kartSignals = {}
	local observeHits
	local boundBefore = false
	local connections = {}
	local stopped = false
	local function clear(notify)
		untilTime, flashUntil = 0, 0
		cue.Visible, cue.Text = false, ""
		for _, edge in edges do edge.Visible = false end
		if notify and onClear then onClear() end
	end
	local function activeKart()
		if practice then
			if player:GetAttribute("RaceState") ~= "GARAGE" or player:GetAttribute("LobbyDriveActive") ~= true then return nil end
		elseif player:GetAttribute("RaceState") ~= "RACING" then return nil end
		local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local seat = human and human.SeatPart
		local candidate = seat and seat.Parent
		if not human or human.Health <= 0 or not seat
			or seat:GetAttribute(if practice then "LobbyKartSeat" else "PrototypeKartSeat") ~= true
			or not candidate or not candidate.Parent
			or candidate:GetAttribute(if practice then "LobbyKart" else "PrototypeKart") ~= true
			or (practice and candidate:GetAttribute("LobbyOwnerUserId") ~= player.UserId)
			or candidate:GetAttribute("RaceControlsLocked") == true then return nil end
		return candidate
	end
	local function sync()
		local current = activeKart()
		local currentSession = player:GetAttribute(if practice then "LobbyCombatSessionId" else "RaceSessionId")
		local currentReset = current and current:GetAttribute("RaceResetSerial")
		if current ~= kart or currentSession ~= session or currentReset ~= reset then
			for _, connection in kartSignals do connection:Disconnect() end
			kartSignals = {}
			clear(kart ~= nil) -- Initial seat binding must not erase a just-authored launch notice.
			kart, session, reset = current, currentSession, currentReset
			-- The first replicated hit can arrive with the initial seat/Kart binding.
			-- Observe that active edge instead of treating it as already displayed.
			wasMissile = boundBefore and current and current:GetAttribute("KartMissileHitActive") == true
			wasSlick = boundBefore and current and current:GetAttribute("KartSlickActive") == true
			wasThunder = boundBefore and current and current:GetAttribute("KartThunderHitActive") == true
			wasSmoke = boundBefore and current and current:GetAttribute("KartSmokeObscuredActive") == true
			if current then
				boundBefore = true
				for _, attribute in {"KartMissileHitActive", "KartSlickActive", "KartSmokeObscuredActive", "KartThunderHitActive"} do
					table.insert(kartSignals, current:GetAttributeChangedSignal(attribute):Connect(function()
						if activeKart() == current and current:GetAttribute("RaceResetSerial") == reset and observeHits then observeHits(current) end
					end))
				end
			end
		end
		if not current then clear() end
		return current
	end
	local function show(text, color, duration, flash)
		-- One style for actual combat results, matching the accepted cyan BLOCKED cue.
		cue.Text, cue.TextColor3, untilTime = text, Color3.fromRGB(65, 225, 245), time()+duration
		cue.Visible = true
		if flash then
			flashUntil = time()+0.60
			for _, edge in edges do edge.BackgroundColor3, edge.BackgroundTransparency, edge.Visible = color, 0.4, true end
		end
	end
	local orange = Color3.fromRGB(255, 200, 75)
	local cyan = Color3.fromRGB(65, 225, 255)
	local purple = Color3.fromRGB(185, 125, 255)
	if practice then
		table.insert(connections, player:GetAttributeChangedSignal("LobbyPracticeMessageSerial"):Connect(function()
			local text = player:GetAttribute("LobbyPracticeMessage")
			if type(text) ~= "string" or not sync() then return end
			if View.isPracticeResult(text) then
				show(text, cyan, 1.2, false)
			end
		end))
	end
	local function diagnostic(message)
		if KartConfig.DEBUG_TELEMETRY then print("[CombatFeedbackView] "..message) end
	end
	observeHits = function(current)
		local missile = current:GetAttribute("KartMissileHitActive") == true
		local slick = current:GetAttribute("KartSlickActive") == true
		local shocked = current:GetAttribute("KartThunderHitActive") == true
		local smoked = current:GetAttribute("KartSmokeObscuredActive") == true
		if missile and not wasMissile then show("MISSILE HIT!", orange, 1.0, true); diagnostic("victim=MISSILE_HIT")
		elseif slick and not wasSlick then show("SLICK HIT!", purple, 1.0, true); diagnostic("victim=SLICK_HIT")
		elseif shocked and not wasThunder then show("SHOCKED!", orange, 1.0, true); diagnostic("victim=THUNDER_HIT")
		elseif smoked and not wasSmoke then show("SMOKED!", cyan, 1.0, true); diagnostic("victim=SMOKED") end
		wasMissile, wasSlick, wasSmoke, wasThunder = missile, slick, smoked, shocked
	end
	table.insert(connections, player:GetAttributeChangedSignal("RaceCombatFeedbackSerial"):Connect(function()
		local code = player:GetAttribute("RaceCombatFeedbackCode")
		local name = player:GetAttribute("RaceCombatFeedbackTargetName") or ""
		if code ~= "MISSILE_HIT" and code ~= "MISSILE_BLOCKED" and code ~= "SLICK_HIT" and code ~= "SLICK_BLOCKED"
			and code ~= "SMOKE_HIT" and code ~= "SMOKE_BLOCKED" then return end
		diagnostic("code="..code.." serial="..tostring(player:GetAttribute("RaceCombatFeedbackSerial")))
		if not sync() then diagnostic("suppressed=INACTIVE_KART"); return end
		if code == "MISSILE_HIT" then show("HIT: "..name, orange, 1.2, false)
		elseif code == "MISSILE_BLOCKED" then show("SHIELD BLOCKED", cyan, 1.2, false)
		elseif code == "SLICK_HIT" then show("SLICK HIT: "..name, purple, 1.2, false)
		elseif code == "SLICK_BLOCKED" then show("SLICK BLOCKED", cyan, 1.2, false)
		elseif code == "SMOKE_HIT" then show("SMOKE HIT: "..name, cyan, 1.2, false)
		elseif code == "SMOKE_BLOCKED" then show("SMOKE BLOCKED", cyan, 1.2, false)
		else return end
	end))
	table.insert(connections, player:GetAttributeChangedSignal("RaceThunderResultSerial"):Connect(function()
		if not sync() then return end
		local hits=player:GetAttribute("RaceThunderHitCount") or 0
		local blocks=player:GetAttribute("RaceThunderBlockedCount") or 0
		local text=if hits>0 then "THUNDER HIT "..hits..(if blocks>0 then " • BLOCK "..blocks else "")
			elseif blocks>0 then "THUNDER BLOCKED "..blocks else "THUNDER NO HIT"
		show(text,orange,1.2,false)
	end))
	table.insert(connections, player:GetAttributeChangedSignal("RaceItemBlockedSerial"):Connect(function()
		if sync() then show("BLOCKED!", cyan, 1.0, true); diagnostic("victim=BLOCKED") end
	end))
	for _, attr in (if practice then {"RaceState", "LobbyCombatSessionId", "LobbyDriveActive"} else {"RaceState", "RaceSessionId"}) do
		table.insert(connections, player:GetAttributeChangedSignal(attr):Connect(function() clear(true); kart=nil; sync() end))
	end
	table.insert(connections, player.CharacterRemoving:Connect(function() clear(true); kart=nil end))
	local warning, speedPanel
	local fallbackPosition = UDim2.new(0.5, 0, 0, 6)
	local function placeBadge()
		local size = gui.AbsoluteSize
		local x = size.X * fallbackPosition.X.Scale + fallbackPosition.X.Offset
		local y = if size.X < 600 then 180 else 6
		if speedPanel and speedPanel.Parent then
			x = speedPanel.AbsolutePosition.X + speedPanel.AbsoluteSize.X/2 - gui.AbsolutePosition.X
			y = math.max(y, speedPanel.AbsolutePosition.Y + speedPanel.AbsoluteSize.Y - gui.AbsolutePosition.Y + 6)
		end
		if warning and warning.Visible then
			y = math.max(y, warning.AbsolutePosition.Y + warning.AbsoluteSize.Y - gui.AbsolutePosition.Y + 6)
		end
		local width = math.min(240, math.max(0, size.X-24))
		cue.Position = UDim2.fromOffset(math.clamp(x, width/2+12, math.max(width/2+12, size.X-width/2-12)),
			math.clamp(y, 0, math.max(0, size.Y-34)))
		cue.Size = UDim2.fromOffset(width, 34)
	end
	table.insert(connections, RunService.Heartbeat:Connect(function()
		local current = sync()
		if current then observeHits(current) end
		cue.Visible = current ~= nil and time() < untilTime
		for _, edge in edges do
			edge.Visible = current ~= nil and time() < flashUntil
			if edge.Visible then edge.BackgroundTransparency = 0.4 + 0.6 * (1-(flashUntil-time())/0.60) end
		end
		placeBadge()
	end))
	local self = {}
	function self:layout(position, _size, incoming, speed)
		fallbackPosition, warning, speedPanel = position, incoming, speed
		placeBadge()
	end
	function self:destroy()
		if stopped then return end
		stopped=true; clear()
		for _, connection in connections do connection:Disconnect() end
		for _, connection in kartSignals do connection:Disconnect() end
		cue:Destroy(); for _, edge in edges do edge:Destroy() end
	end
	table.insert(connections, gui.Destroying:Connect(function() self:destroy() end))
	return self
end
return View
