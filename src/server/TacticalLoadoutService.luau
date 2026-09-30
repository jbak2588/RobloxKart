-- Choices are temporary server-stay preferences, not race charges or Inventory.
local Slots = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RaceItemSlots"))
local Service = {}
Service.__index = Service
function Service.new(getSession)
	return setmetatable({getSession=getSession, choices={}, lastChange={}}, Service)
end
function Service:get(player)
	local choice=self.choices[player]
	if choice and choice.session ~= self.getSession(player) then self.choices[player]=nil;choice=nil end
	return if choice then choice.slots else Slots.DEFAULT
end
function Service:set(player, tactical, now)
	local session=self.getSession(player)
	if player:GetAttribute("RaceState") ~= "PRE_RACE" or not session or not session.participants[player]
		or (session.phase ~= "WAITING" and session.phase ~= "EMPTY") then return false,"ROUND STARTED - ITEMS LOCKED" end
	if self.lastChange[player] and now-self.lastChange[player] < .20 then return false,"PLEASE WAIT" end
	local slots=Slots.tactical(tactical)
	if not slots or not Slots.validate(slots) then return false,"CHOOSE 3 TACTICAL ITEMS" end
	self.lastChange[player]=now
	self.choices[player]={session=session, slots=slots}
	return true,"ITEMS CONFIRMED"
end
function Service:clear(player)
	self.choices[player],self.lastChange[player]=nil,nil
end
return Service
