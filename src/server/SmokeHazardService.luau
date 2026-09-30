-- Server-local vision metadata only: never writes velocity, controls or boost state.
local Smoke = {}
Smoke.__index = Smoke
function Smoke.new(config, deps)
	return setmetatable({config=config, deps=deps, hazards={}, effects={}}, Smoke)
end
function Smoke:apply(player, now)
	local kart = self.deps.getKart(player)
	local session = self.deps.getSession(player)
	if not kart or not session then return false end
	local old = self.effects[player]
	if old and old.kart ~= kart then old.kart:SetAttribute("KartSmokeObscuredActive", false) end
	self.effects[player] = {kart=kart, session=session, round=session.roundId,
		reset=kart:GetAttribute("RaceResetSerial"), untilTime=now+self.config.SMOKE_EFFECT_DURATION}
	kart:SetAttribute("KartSmokeSessionId", player:GetAttribute("RaceSessionId"))
	kart:SetAttribute("KartSmokeResetSerial", kart:GetAttribute("RaceResetSerial"))
	kart:SetAttribute("KartSmokeObscuredActive", true)
	return true
end
function Smoke:deploy(player, prototype, now)
	local kart, chassis = self.deps.getKart(player)
	local session = self.deps.getSession(player)
	if not kart or not session or kart:GetAttribute("KartOffTrack") == true then return false, "invalid_driver" end
	if #self.hazards >= self.config.SMOKE_MAX_HAZARDS then return false, "hazard_limit" end
	local frame = self.deps.geometry.dropFrame(prototype, chassis, self.config.SMOKE_DROP_DISTANCE)
	if not frame then return false, "no_road_behind" end
	local model, trigger = self.deps.visuals.smoke(self.deps.parent, frame, self.config)
	model:SetAttribute("SmokeOwnerUserId", player.UserId)
	model:SetAttribute("RaceSessionId", player:GetAttribute("RaceSessionId"))
	model:SetAttribute("RaceRoundId", session.roundId)
	table.insert(self.hazards, {model=model, trigger=trigger, owner=player, kart=kart,
		session=session, round=session.roundId, reset=kart:GetAttribute("RaceResetSerial"), born=now, handled={}})
	return true
end
function Smoke:clearPlayer(player)
	local effect = self.effects[player]
	if effect then effect.kart:SetAttribute("KartSmokeObscuredActive", false); self.effects[player]=nil end
	for index=#self.hazards,1,-1 do
		if self.hazards[index].owner == player then self.hazards[index].model:Destroy(); table.remove(self.hazards,index) end
	end
end
function Smoke:clearSession(session)
	for player,effect in self.effects do if effect.session == session then self:clearPlayer(player) end end
	for index=#self.hazards,1,-1 do
		if self.hazards[index].session == session then self.hazards[index].model:Destroy();table.remove(self.hazards,index) end
	end
end
function Smoke:update(now, targets)
	for player,effect in self.effects do
		if now >= effect.untilTime or self.deps.getKart(player) ~= effect.kart
			or self.deps.getSession(player) ~= effect.session or effect.session.roundId ~= effect.round
			or effect.kart:GetAttribute("RaceResetSerial") ~= effect.reset then
			effect.kart:SetAttribute("KartSmokeObscuredActive", false);self.effects[player]=nil
		end
	end
	for index=#self.hazards,1,-1 do
		local hazard=self.hazards[index]
		if now-hazard.born >= self.config.SMOKE_LIFETIME or not hazard.model.Parent
			or self.deps.getKart(hazard.owner) ~= hazard.kart or self.deps.getSession(hazard.owner) ~= hazard.session
			or hazard.session.roundId ~= hazard.round or hazard.kart:GetAttribute("RaceResetSerial") ~= hazard.reset then
			hazard.model:Destroy();table.remove(self.hazards,index)
		else
			for _,target in targets do
				if not hazard.handled[target.player] and self.deps.getSession(target.player) == hazard.session
					and (target.player ~= hazard.owner or now-hazard.born >= self.config.SMOKE_OWNER_GRACE)
					and self.deps.geometry.crosses(hazard.trigger.CFrame,hazard.trigger.Size,target.previous,target.chassis) then
					local accepted,reason=self.deps.resolve(target.player,hazard.owner,"Smoke")
					if accepted or reason == "immune" then hazard.handled[target.player]=true end
				end
			end
		end
	end
end
return Smoke
