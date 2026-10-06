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
	self.bonusProgress = 0
	self.bonusPending = false
	self.bonusAwardCount = 0
	self.bonusEverAwarded = false
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
-- Inventory-only transition; never starts, extends or clears an item effect.
function RaceLoadout:refillLapItems(policy)
	local changedIds = {}
	if not policy.Enabled then return changedIds, 0 end
	for _, id in self.slots do
		-- Nitro exclusion and empty-only behavior are hard prototype invariants.
		if id ~= "Nitro" and policy.Eligible[id] == true and self:contains(id) and self.counts[id] == 0 then
			local amount = math.min(policy.RefillTo, Catalog[id].MaxCharges)
			if amount > 0 then self.counts[id] = amount; table.insert(changedIds, id) end
		end
	end
	if self.selected == "" and #changedIds > 0 then
		for _, id in self.slots do
			if self.counts[id] > 0 then self.selected = id; break end
		end
	end
	return changedIds, #changedIds
end
function RaceLoadout:select(id)
	if not self:contains(id) or (self.counts[id] or 0) <= 0 then return false end
	self.selected = id
	return true
end
function RaceLoadout:grantBonusNitro()
	-- Only a completed server-observed BOOST cycle can grant a bonus.
	if not self.bonusPending or not self:contains("Nitro") or self.counts.Nitro >= Catalog.Nitro.MaxCharges then return false end
	self.counts.Nitro += 1
	self.bonusProgress = 0
	self.bonusPending = false
	self.bonusAwardCount += 1
	self.bonusEverAwarded = true
	if self.selected == "" then self.selected = "Nitro" end
	return true
end
function RaceLoadout:recordBoost(requiredBoosts)
	if not self:contains("Nitro") or self.bonusPending then return false end
	assert(type(requiredBoosts) == "number" and requiredBoosts >= 1 and requiredBoosts % 1 == 0)
	self.bonusProgress = math.min(self.bonusProgress + 1, requiredBoosts)
	if self.bonusProgress == requiredBoosts then
		self.bonusPending = true
		self:grantBonusNitro()
	end
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
	if accepted then
		consume(self, id)
		if id == "Nitro" then self:grantBonusNitro() end
	end
	return accepted, reason
end
return RaceLoadout
