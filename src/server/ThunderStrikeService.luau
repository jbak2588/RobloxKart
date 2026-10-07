-- Fixed logical target snapshots; no projectile, geometry hits or client targeting.
local Service = {}
Service.__index = Service
function Service.new(config, deps)
	return setmetatable({config=config, deps=deps, events={}, incoming={}, flashes={}}, Service)
end
function Service:changeIncoming(player, delta)
	local count = math.max(0, (self.incoming[player] or 0)+delta)
	self.incoming[player] = if count > 0 then count else nil
	player:SetAttribute("RaceThunderIncomingCount", count)
end
function Service:valid(event, player, kart, reset)
	return self.deps.getKart(player) == kart and kart.Parent ~= nil
		and self.deps.getSession(player) == event.session
		and event.session.roundId == event.roundId
		and kart:GetAttribute("RaceResetSerial") == reset
end
function Service:removeTarget(event, index)
	local target = event.targets[index]
	target.visual:Destroy()
	self:changeIncoming(target.player, -1)
	table.remove(event.targets, index)
end
function Service:remove(index)
	local event = self.events[index]
	for i=#event.targets,1,-1 do self:removeTarget(event,i) end
	table.remove(self.events,index)
end
function Service:launch(owner, targets, session, now)
	if #self.events >= self.config.THUNDER_MAX_ACTIVE then return false,"thunder_limit" end
	local kart = self.deps.getKart(owner)
	if not kart or not session or #targets == 0 then return false,"no_target_ahead" end
	local event = {owner=owner, kart=kart, reset=kart:GetAttribute("RaceResetSerial"), session=session,
		roundId=session.roundId, strikeAt=now+self.config.THUNDER_WARNING_SECONDS, targets={}}
	for _,player in targets do
		local targetKart,chassis = self.deps.getKart(player)
		if player ~= owner and targetKart and self.deps.getSession(player) == session then
			table.insert(event.targets,{player=player,kart=targetKart,reset=targetKart:GetAttribute("RaceResetSerial"),
				visual=self.deps.visuals.thunderWarning(self.deps.parent,chassis)})
			self:changeIncoming(player,1)
		end
	end
	if #event.targets == 0 then return false,"no_target_ahead" end
	table.insert(self.events,event)
	return true
end
function Service:clearPlayer(player)
	for i=#self.events,1,-1 do
		local event=self.events[i]
		if event.owner == player then self:remove(i)
		else
			for j=#event.targets,1,-1 do
				if event.targets[j].player == player then self:removeTarget(event,j) end
			end
			if #event.targets == 0 then self:remove(i) end
		end
	end
	for i=#self.flashes,1,-1 do
		local f=self.flashes[i]
		if f.owner == player or f.target == player then f.visual:Destroy();table.remove(self.flashes,i) end
	end
end
function Service:clearSession(session)
	for i=#self.events,1,-1 do if self.events[i].session == session then self:remove(i) end end
	for i=#self.flashes,1,-1 do
		if self.flashes[i].session == session then self.flashes[i].visual:Destroy();table.remove(self.flashes,i) end
	end
end
function Service:update(now)
	for i=#self.flashes,1,-1 do
		local f=self.flashes[i]
		if now >= f.untilTime or not self:valid(f,f.target,f.kart,f.reset)
			or not self:valid(f,f.owner,f.sourceKart,f.sourceReset) then
			f.visual:Destroy();table.remove(self.flashes,i)
		else
			self.deps.visuals.updateThunderStrike(f.visual,now-(f.untilTime-self.deps.visuals.thunderStrikeLifetime()))
		end
	end
	for i=#self.events,1,-1 do
		local event=self.events[i]
		if not self:valid(event,event.owner,event.kart,event.reset) then self:remove(i);continue end
		local hits,blocks=0,0
		for j=#event.targets,1,-1 do
			local target=event.targets[j]
			local valid=self:valid(event,target.player,target.kart,target.reset)
			local _,chassis=self.deps.getKart(target.player)
			if not valid or not target.visual.Parent then self:removeTarget(event,j)
			elseif now < event.strikeAt then self.deps.visuals.updateThunderWarning(target.visual,chassis)
			else
				local _,reason=self.deps.resolve(target.player,event.owner,"Thunder")
				if reason == "hit" then hits+=1 elseif reason == "blocked" then blocks+=1 end
				if reason == "hit" or reason == "blocked" then
					if #self.flashes >= 24 then self.flashes[1].visual:Destroy();table.remove(self.flashes,1) end
					table.insert(self.flashes,{owner=event.owner,target=target.player,session=event.session,roundId=event.roundId,
						kart=target.kart,reset=target.reset,sourceKart=event.kart,sourceReset=event.reset,
						untilTime=now+self.deps.visuals.thunderStrikeLifetime(),visual=self.deps.visuals.thunderStrike(self.deps.parent,chassis,reason=="blocked")})
				end
				self:removeTarget(event,j)
			end
		end
		if now >= event.strikeAt then self.deps.result(event.owner,hits,blocks);self:remove(i)
		elseif #event.targets == 0 then self:remove(i) end
	end
end
return Service
