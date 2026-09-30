-- Server-only projectile lifecycle. The controller selects a fixed target and resolves attacks.
local Service = {}
Service.__index = Service

local function turn(direction, desired, angleLimit)
	local angle = math.acos(math.clamp(direction:Dot(desired), -1, 1))
	if angle <= angleLimit then return desired end
	local axis = direction:Cross(desired)
	if axis.Magnitude < 0.0001 then
		axis = direction:Cross(if math.abs(direction.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis)
	end
	axis = axis.Unit
	return (direction * math.cos(angleLimit) + axis:Cross(direction) * math.sin(angleLimit)).Unit
end

-- Relative swept segment handles both a fast missile and a moving target.
function Service.sweptHit(from, to, targetFrom, targetTo, radius)
	local a, b = from - targetFrom, to - targetTo
	local segment = b - a
	local t = if segment:Dot(segment) > 0.000001
		then math.clamp(-a:Dot(segment) / segment:Dot(segment), 0, 1) else 0
	return (a + segment * t).Magnitude <= radius
end

function Service.new(config, dependencies)
	return setmetatable({ config = config, deps = dependencies, projectiles = {}, incoming = {}, flashes = {} }, Service)
end

function Service:changeIncoming(target, delta)
	local count = math.max(0, (self.incoming[target] or 0) + delta)
	self.incoming[target] = if count > 0 then count else nil
	target:SetAttribute("RaceMissileIncomingCount", count)
end

function Service:valid(p)
	local d = self.deps
	local sourceKart = d.getKart(p.owner)
	local targetKart, targetChassis = d.getKart(p.target)
	if sourceKart ~= p.sourceKart or targetKart ~= p.targetKart
		or d.getSession(p.owner) ~= p.session or d.getSession(p.target) ~= p.session
		or p.session.roundId ~= p.roundId
		or sourceKart:GetAttribute("RaceResetSerial") ~= p.sourceReset
		or targetKart:GetAttribute("RaceResetSerial") ~= p.targetReset then return nil end
	return targetChassis
end

function Service:launch(owner, target, session, now)
	if #self.projectiles >= self.config.MISSILE_MAX_ACTIVE then return false, "missile_limit" end
	local sourceKart = self.deps.getKart(owner)
	local targetKart = self.deps.getKart(target)
	if not sourceKart or not targetKart or not session then return false, "invalid_target" end
	local p = { owner = owner, target = target, session = session, roundId = session.roundId,
		sourceKart = sourceKart, targetKart = targetKart,
		sourceReset = sourceKart:GetAttribute("RaceResetSerial"), targetReset = targetKart:GetAttribute("RaceResetSerial"),
		born = now, state = "WARNING", launchAt = now + self.config.MISSILE_WARNING_SECONDS }
	table.insert(self.projectiles, p)
	self:changeIncoming(target, 1)
	return true
end

function Service:remove(index)
	local p = self.projectiles[index]
	if p.visual then p.visual:Destroy() end
	self:changeIncoming(p.target, -1)
	table.remove(self.projectiles, index)
end

function Service:clearPlayer(player)
	for index = #self.projectiles, 1, -1 do
		local p = self.projectiles[index]
		if p.owner == player or p.target == player then self:remove(index) end
	end
	for index = #self.flashes, 1, -1 do
		local f = self.flashes[index]
		if f.owner == player or f.target == player then f.visual:Destroy(); table.remove(self.flashes, index) end
	end
end

function Service:clearSession(session)
	for index = #self.projectiles, 1, -1 do
		if self.projectiles[index].session == session then self:remove(index) end
	end
	for index = #self.flashes, 1, -1 do
		if self.flashes[index].session == session then
			self.flashes[index].visual:Destroy(); table.remove(self.flashes, index)
		end
	end
end

function Service:update(now)
	local c, d = self.config, self.deps
	for index = #self.projectiles, 1, -1 do
		local p = self.projectiles[index]
		local target = self:valid(p)
		if not target or (p.visual and not p.visual.Parent) then self:remove(index); continue end
		local targetPosition = target.Position + Vector3.new(0, 2, 0)
		if p.state == "WARNING" then
			if now < p.launchAt then continue end
			local _, source = d.getKart(p.owner)
			p.position = (source.CFrame * CFrame.new(0, 2, -7)).Position
			p.direction = source.CFrame.LookVector
			p.targetPrevious = targetPosition
			p.lastUpdate, p.flightBorn, p.state = now, now, "FLYING"
			p.visual = d.visuals.missile(d.parent, CFrame.lookAt(p.position, p.position + p.direction))
		end
		if now - p.flightBorn >= c.MISSILE_LIFETIME then self:remove(index); continue end
		local dt = math.max(0, now - p.lastUpdate)
		local from = p.position
		local desired = targetPosition - from
		if desired.Magnitude > 0.0001 then p.direction = turn(p.direction, desired.Unit, c.MISSILE_TURN_RATE * dt) end
		local to = from + p.direction * c.MISSILE_SPEED * dt
		if Service.sweptHit(from, to, p.targetPrevious, targetPosition, c.MISSILE_HIT_RADIUS) then
			local accepted, reason = d.resolve(p.target, p.owner, "Missile")
			if accepted and (reason == "hit" or reason == "blocked") then
				table.insert(self.flashes, { visual = d.visuals.missileImpact(d.parent, targetPosition, reason == "blocked"),
					born = now, session = p.session, owner = p.owner, target = p.target })
			end
			self:remove(index)
		else
			p.position, p.targetPrevious, p.lastUpdate = to, targetPosition, now
			p.visual:PivotTo(CFrame.lookAt(to, to + p.direction))
		end
	end
	for index = #self.flashes, 1, -1 do
		local f = self.flashes[index]
		local age = now - f.born
		if age >= 0.2 then f.visual:Destroy(); table.remove(self.flashes, index)
		else f.visual.Size = Vector3.one * (1 + age * 15); f.visual.Transparency = 0.3 + age * 3 end
	end
end

return Service
