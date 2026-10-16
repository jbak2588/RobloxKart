-- Owns one shared demonstration timeline, never a racer, loadout or player kart.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local Route=require(game:GetService("ReplicatedStorage").Shared.LobbyDemoRoute)
local Service={}
local stopCurrent

function Service.start(zone)
 if stopCurrent or not zone or Workspace:GetAttribute("KDMServerRole")~="HUB" or game.PrivateServerId~="" then return end
 local connections,watched={},{}
 local state
 local function refresh(departing)
  local active=zone.Parent~=nil and Route.hasAudience(Players:GetPlayers(),departing)
  if active and not state then
   state=Instance.new("Folder");state.Name="LobbyDemoState"
   state:SetAttribute("StartedAt",Workspace:GetServerTimeNow())
   state:SetAttribute("KartId","Kart05")
   state.Parent=zone
  elseif not active and state then state:Destroy();state=nil end
 end
 local function watch(player)
  if watched[player] then return end
  watched[player]={player:GetAttributeChangedSignal("RaceState"):Connect(function() refresh() end),
   player:GetAttributeChangedSignal("KDMRoutePending"):Connect(function() refresh() end)}
  refresh()
 end
 stopCurrent=function()
  for _,connection in connections do connection:Disconnect() end
  for _,list in watched do for _,connection in list do connection:Disconnect() end end
  if state then state:Destroy();state=nil end
  stopCurrent=nil
 end
 table.insert(connections,Players.PlayerAdded:Connect(watch))
 table.insert(connections,Players.PlayerRemoving:Connect(function(player)
  if watched[player] then for _,connection in watched[player] do connection:Disconnect() end;watched[player]=nil end
  refresh(player)
 end))
 table.insert(connections,zone.Destroying:Connect(function() Service.stop() end))
 for _,player in Players:GetPlayers() do watch(player) end
end

function Service.stop() if stopCurrent then stopCurrent() end end
return Service
