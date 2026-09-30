-- Temporary authoritative race resources. Activation callbacks must not yield.
local RaceLoadout = {}
RaceLoadout.__index = RaceLoadout
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("RaceItemCatalog"))
local Slots = require(Shared:WaitForChild("RaceItemSlots"))
function RaceLoadout.new()
	local self = setmetatable({}, RaceLoadout)
	self:clear()
	return self
end
function RaceLoadout:clear()
	self.slots = {}
	self.counts = {}
	for id in Catalog do self.counts[id] = 0 end
	self.selected = ""
	self.bonusClaimed = false
end
function RaceLoadout:prepare(slotIds, preserveSelection)
	local ids = if slotIds == nil then Slots.DEFAULT else slotIds
	if not Slots.validate(ids) then return false end
	local prepared = table.clone(ids)
	local selected = if preserveSelection then self.selected else nil
	self:clear()
	self.slots = prepared
	for _, id in self.slots do self.counts[id] = Catalog[id].InitialCharges end
	self.selected = self.slots[1]
	if selected then self:select(selected) end
	return true
end
function RaceLoadout:contains(id)
	return Slots.isImplemented(id) and table.find(self.slots, id) ~= nil
end
function RaceLoadout:select(id)
	if not self:contains(id) or (self.counts[id] or 0) <= 0 then return false end
	self.selected = id
	return true
end
function RaceLoadout:grantBonusNitro()
	if not self:contains("Nitro") or self.bonusClaimed or self.counts.Nitro >= Catalog.Nitro.MaxCharges then return false end
	self.counts.Nitro += 1
	self.bonusClaimed = true
	if self.selected == "" then self.selected = "Nitro" end
	return true
end
local function consume(self, id)
	self.counts[id] -= 1
	if self.selected == id and self.counts[id] == 0 then
		self.selected = ""
		local index = table.find(self.slots, id)
		for offset = 1, #self.slots do
			local nextId = self.slots[(index + offset - 1) % #self.slots + 1]
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
	if not self:contains(id) then return false, "invalid_item" end
	if self.counts[id] <= 0 then return false, "empty_charge" end
	local accepted, reason = activate(id)
	if accepted then consume(self, id) end
	return accepted, reason
end
return RaceLoadout
