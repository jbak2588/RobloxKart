-- Ephemeral HUB discovery only. Records remain owned by LobbyTestDriveService.
local Presence = {}

function Presence.count(records, zone)
 local count = 0
 for player, r in records do
  if player.Parent and player.Character == r.character and r.character.Parent
   and player:GetAttribute("LobbyDriveActive") == true
   and player:GetAttribute("RaceState") == "GARAGE"
   and player:GetAttribute("KDMRoutePending") ~= "RACE_LAUNCH"
   and r.seated and r.kart.Parent == zone and r.body.Parent
   and r.humanoid.Health > 0 and r.seat.Occupant == r.humanoid
   and r.humanoid.SeatPart == r.seat then count += 1 end
 end
 return count
end

function Presence.new(zone, records)
 local last
 local view = {}
 function view:refresh()
  local count = Presence.count(records, zone)
  if count == last then return end
  last = count
  zone:SetAttribute("LobbyDrivePlayerCount", count)
 end
 view:refresh()
 return view
end

return Presence
