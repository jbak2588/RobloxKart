-- Server-only, temporary one-slot state. Activation callbacks must not yield.
local RaceItemSlot = {}
RaceItemSlot.__index = RaceItemSlot

function RaceItemSlot.new()
	return setmetatable({ id = "" }, RaceItemSlot)
end

function RaceItemSlot:clear()
	self.id = ""
end

function RaceItemSlot:grant(id: string): boolean
	if self.id ~= "" or id ~= "Nitro" then return false end
	self.id = id
	return true
end

function RaceItemSlot:use(action: unknown, extraCount: number, activate): (boolean, string?)
	if action ~= "Use" or extraCount ~= 0 then return false, "invalid_request" end
	if self.id ~= "Nitro" then return false, "empty_slot" end
	local accepted, reason = activate()
	if accepted then self:clear() end
	return accepted, reason
end

return RaceItemSlot
