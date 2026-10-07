-- Every client renders the same replicated kart state, including its own kart.
-- Local hit cameras/HUD are deliberately outside this observer.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local Shield=require(script.Parent.ShieldWorldRenderer)
local Exhaust=require(script.Parent.KartWorldExhaustRenderer)
local Controller={}
local stop
function Controller.start()
 if stop then return end
 local prototype=Workspace:WaitForChild("Prototype")
 local records,connections={},{}
 local paused=false
 local function clear(r)
  if r.shield then r.shield:destroy();r.shield=nil end
  if r.source and r.source.Parent then r.source.LocalTransparencyModifier=0 end
  r.source=nil
  if r.exhaust then r.exhaust:destroy();r.exhaust=nil end
 end
 local function remove(k)
  local r=records[k];if not r then return end
  clear(r);records[k]=nil
 end
 local function bind(k)
  if k:IsA("Model") and k:GetAttribute("PrototypeKart")==true and not records[k] then
   records[k]={blocked=0}
  end
 end
 for _,o in prototype:GetDescendants() do bind(o) end
 table.insert(connections,prototype.DescendantAdded:Connect(bind))
 table.insert(connections,prototype.DescendantRemoving:Connect(function(o) if records[o] then remove(o) end end))
 local scan=0
 table.insert(connections,RunService.Heartbeat:Connect(function(dt)
  scan+=dt
  -- Model attributes/visual metadata may arrive after DescendantAdded.
  if scan>=.25 then scan=0;for _,o in prototype:GetChildren() do bind(o) end end
  for kart,r in records do
   if not kart.Parent then remove(kart);continue end
   if paused then clear(r);continue end
   local ownerId=kart:GetAttribute("KartOwnerUserId")
   local owner=if type(ownerId)=="number" then Players:GetPlayerByUserId(ownerId) else nil
   local seat=kart:FindFirstChild("Seat")
   local human=seat and seat.Occupant
   local session=owner and owner:GetAttribute("RaceSessionId")
   local reset=kart:GetAttribute("RaceResetSerial")
   if r.owner~=owner or r.human~=human or r.session~=session or r.reset~=reset then
    clear(r);r.owner,r.human,r.session,r.reset=owner,human,session,reset
    r.blocked=owner and owner:GetAttribute("RaceItemBlockedSerial") or 0
   end
   local enabled=human~=nil and human.Health>0 and kart:GetAttribute("RaceControlsLocked")~=true
    and (not owner or owner:GetAttribute("RaceState")=="RACING")
   local chassis=kart.PrimaryPart
   if not chassis then clear(r);continue end
   if not enabled then clear(r);continue end
   if not r.exhaust then r.exhaust=Exhaust.new(kart) end
   if r.exhaust then r.exhaust:update(dt,true) end
   local shell=kart:FindFirstChild("RaceItemShield")
   local active=kart:GetAttribute("KartShieldActive")==true and shell~=nil
   if active and not r.shield then r.shield=Shield.new(kart,chassis,human.Parent) end
   if r.shield then
    if shell~=r.source then
     if r.source and r.source.Parent then r.source.LocalTransparencyModifier=0 end
     r.source=shell;if shell then shell.LocalTransparencyModifier=1 end
    end
    local serial=owner and owner:GetAttribute("RaceItemBlockedSerial") or r.blocked
    if not r.shield:update(time(),active,serial~=r.blocked) then
     r.shield:destroy();r.shield=nil
     if r.source and r.source.Parent then r.source.LocalTransparencyModifier=0 end;r.source=nil
    end
    r.blocked=serial
   end
  end
 end))
 stop=function()
  for k in records do remove(k) end
  for _,c in connections do c:Disconnect() end
  stop=nil
 end
 table.insert(connections,prototype.Destroying:Connect(function() Controller.destroy() end))
 table.insert(connections,Players.LocalPlayer.OnTeleport:Connect(function(state) paused=state~=Enum.TeleportState.Failed;for _,r in records do clear(r) end end))
 table.insert(connections,Players.LocalPlayer.AncestryChanged:Connect(function(_,parent) if not parent then Controller.destroy() end end))
end
function Controller.destroy() if stop then stop() end end
return Controller
