-- Temporary authoritative race resources. Activation callbacks must not yield.
local RaceLoadout = {}
RaceLoadout.__index = RaceLoadout
local ORDER = { "Nitro", "Slick", "Shield", "Missile" }
local MAX = { Nitro=2, Slick=1, Shield=1, Missile=1 }
function RaceLoadout.new()
	local self = setmetatable({}, RaceLoadout)
	self:clear()
	return self
end
function RaceLoadout:clear()
	self.counts = { Nitro=0, Slick=0, Shield=0, Missile=0, Smoke=0 }
	self.selected = ""
	self.bonusClaimed = false
end
function RaceLoadout:prepare(preserveSelection)
	local selected = if preserveSelection then self.selected else nil
	self:clear()
	for _, id in ORDER do self.counts[id] = 1 end
	self.selected = "Nitro"
	if selected then self:select(selected) end
end
function RaceLoadout:select(id)
	if type(id) ~= "string" or not MAX[id] or self.counts[id] <= 0 then return false end
	self.selected = id
	return true
end
function RaceLoadout:grantBonusNitro()
	if self.bonusClaimed or self.counts.Nitro >= MAX.Nitro then return false end
	self.counts.Nitro += 1
	self.bonusClaimed = true
	if self.selected == "" then self.selected = "Nitro" end
	return true
end
local function consume(self, id)
	self.counts[id] -= 1
	if self.selected == id and self.counts[id] == 0 then
		self.selected = ""
		local index = table.find(ORDER, id)
		for offset = 1, #ORDER do
			local nextId = ORDER[(index + offset - 1) % #ORDER + 1]
			if self.counts[nextId] > 0 then self.selected = nextId; break end
		end
	end
end
function RaceLoadout:use(action, extraCount, activate)
	if action ~= "Use" or extraCount ~= 0 then return false, "invalid_request" end
	return self:useItem(self.selected, activate)
end
-- Direct atomic use shares desktop activation/consumption; callbacks never yield.
function RaceLoadout:useItem(id, activate)
	if type(id) ~= "string" or not MAX[id] then return false, "invalid_item" end
	if self.counts[id] <= 0 then return false, "empty_charge" end
	local accepted, reason = activate(id)
	if accepted then consume(self, id) end
	return accepted, reason
end
return RaceLoadout
