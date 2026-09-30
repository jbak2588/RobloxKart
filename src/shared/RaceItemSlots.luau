-- Catalog size never determines HUD size. Only the server prepares active slots.
local Catalog = require(script.Parent:WaitForChild("RaceItemCatalog"))
local Slots = {}
Slots.RACE_ITEM_SLOT_COUNT = 4
Slots.DEFAULT = table.freeze({ "Nitro", "Slick", "Shield", "Missile" })

function Slots.isImplemented(id)
	return type(id) == "string" and Catalog[id] ~= nil and Catalog[id].Implemented == true
end

function Slots.validate(ids)
	if type(ids) ~= "table" then return false end
	local seen, count = {}, 0
	for index, id in ids do
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > Slots.RACE_ITEM_SLOT_COUNT
			or not Slots.isImplemented(id) or seen[id] then return false end
		local entry = Catalog[id]
		if type(entry.InitialCharges) ~= "number" or entry.InitialCharges % 1 ~= 0 or entry.InitialCharges < 1
			or type(entry.MaxCharges) ~= "number" or entry.MaxCharges % 1 ~= 0
			or entry.MaxCharges < entry.InitialCharges then return false end
		seen[id] = true
		count += 1
	end
	return count == Slots.RACE_ITEM_SLOT_COUNT
end

function Slots.get(player, index)
	if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > Slots.RACE_ITEM_SLOT_COUNT then return nil end
	local id = player:GetAttribute("RaceItemSlot" .. index)
	return if Slots.isImplemented(id) then id else nil
end

function Slots.contains(player, id)
	if not Slots.isImplemented(id) then return false end
	for index = 1, Slots.RACE_ITEM_SLOT_COUNT do
		if Slots.get(player, index) == id then return true end
	end
	return false
end

return table.freeze(Slots)
