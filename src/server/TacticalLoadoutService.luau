-- Choices are temporary server-stay preferences, not race charges or Inventory.
local Slots = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RaceItemSlots"))
local Service = {}
Service.__index = Service
function Service.new(getSession)
	return setmetatable({getSession=getSession, choices={}, lastChange={}}, Service)
end
function Service:get(player)
	return Slots.DEFAULT
end
function Service:set(player, tactical, now)
	local session=self.getSession(player)
	if player:GetAttribute("RaceState") ~= "PRE_RACE" or not session or not session.participants[player]
		or session.phase ~= "WAITING" then return false,"ROUND STARTED - ITEMS LOCKED" end
	if session.itemsReady and session.itemsReady[player] then return false,"ITEMS LOCKED FOR THIS ROUND" end
	local deadline=session.itemPrepareDeadlines and session.itemPrepareDeadlines[player]
	if not deadline or now >= deadline or not session.confirmItems then return false,"ITEMS LOCKED FOR THIS ROUND" end
	if self.lastChange[player] and now-self.lastChange[player] < .20 then return false,"PLEASE WAIT" end
	local slots=Slots.tactical(tactical)
	if not slots or not Slots.validate(slots) then return false,"CHOOSE 3 TACTICAL ITEMS" end
	local previous=self.choices[player]
	self.choices[player]={session=session, slots=slots}
	if not session.confirmItems(player,now) then
		self.choices[player]=previous
		return false,"ITEMS LOCKED FOR THIS ROUND"
	end
	self.lastChange[player]=now
	return true,"ITEMS READY"
end
function Service:clear(player)
	self.choices[player],self.lastChange[player]=nil,nil
end
return Service
