local fs, luau = require('@lune/fs'), require('@lune/luau')
local Presence=luau.load(fs.readFile('src/server/LobbyDrivePresence.luau'))()
local nodes=require('./helpers/practice_ui_nodes')
local checks=0
local function check(v,m) checks+=1;assert(v,m) end
local zone=nodes.object('Model')
local sign=nodes.object('Part');sign.Name='LobbyDriveDiscovery';sign.Parent=zone
local labels={nodes.object('TextLabel'),nodes.object('TextLabel'),nodes.object('TextLabel'),nodes.object('TextLabel')}
for i,label in labels do label.Name=if i%2==1 then 'DrivingCount' else 'DriveHint' end
function sign:GetDescendants() return labels end
for _,label in labels do function label:IsA(c)return c=='TextLabel' end end
local writes=0;local set=zone.SetAttribute
function zone:SetAttribute(k,v) writes+=1;set(self,k,v) end
local records={}
local view=Presence.new(zone,records)
check(zone:GetAttribute('LobbyDrivePlayerCount')==0,'empty HUB publishes zero')
check(labels[1].Text=='LIVE TEST DRIVE' and labels[2].Text=='WATCH THE DEMO · TRY DRIVING','zero shows demo without counting bot')
local players={}
for i=1,4 do
 local p=nodes.object('Player');p.Parent=nodes.object('Players');p.Character={Parent={}}
 p:SetAttribute('RaceState','GARAGE');p:SetAttribute('LobbyDriveActive',true)
 local h={Health=100};local seat={Occupant=h};h.SeatPart=seat
 local r={character=p.Character,seated=true,kart={Parent=zone},body={Parent={}},humanoid=h,seat=seat}
 players[i]=p;records[p]=r;view:refresh()
 check(zone:GetAttribute('LobbyDrivePlayerCount')==i,'independent human admission '..i)
end
check(labels[1].Text=='4 PLAYERS DRIVING' and labels[2].Text=='JOIN THE ACTION','plural and joining cue')
local stableWrites=writes
local begin=os.clock()
for _=1,10000 do view:refresh() end
local elapsed=os.clock()-begin
check(writes==stableWrites,'unchanged counts never republish')
local p=players[1];local r=records[p]
for _,invalidate in {
 function()p:SetAttribute('LobbyDriveActive',false);return function()p:SetAttribute('LobbyDriveActive',true)end end,
 function()r.seated=false;return function()r.seated=true end end,
 function()r.seat.Occupant=nil;return function()r.seat.Occupant=r.humanoid end end,
 function()r.humanoid.SeatPart=nil;return function()r.humanoid.SeatPart=r.seat end end,
 function()r.humanoid.Health=0;return function()r.humanoid.Health=100 end end,
 function()p.Parent=nil;return function()p.Parent=nodes.object('Players')end end,
 function()p.Character={};return function()p.Character=r.character end end,
 function()r.kart.Parent=nil;return function()r.kart.Parent=zone end end,
 function()p:SetAttribute('KDMRoutePending','RACE_LAUNCH');return function()p:SetAttribute('KDMRoutePending',nil)end end,
 function()p:SetAttribute('RaceState','RACING');return function()p:SetAttribute('RaceState','GARAGE')end end,
} do
 local restore=invalidate();view:refresh()
 check(zone:GetAttribute('LobbyDrivePlayerCount')==3,'invalid/transition racer excluded')
 restore();view:refresh();check(zone:GetAttribute('LobbyDrivePlayerCount')==4,'valid re-entry counted')
end
for i=4,2,-1 do records[players[i]]=nil;view:refresh()end
check(labels[3].Text=='1 PLAYER DRIVING' and labels[4].Text=='JOIN THE ACTION','late observer receives current singular state on both replicated sign faces')
records[p]=nil;view:refresh()
check(zone:GetAttribute('LobbyDrivePlayerCount')==0,'all departures return zero')
local service=fs.readFile('src/server/LobbyTestDriveService.luau')
check(service:find('presence=Presence.new(zone,records)',1,true)~=nil,'presence uses authoritative service records')
check(service:find('player:SetAttribute("LobbyDriveActive",true);player:SetAttribute("LobbyDrivePending",false)\n if presence then presence:refresh() end',1,true)~=nil,'publish after accepted seat')
check(service:find('player:SetAttribute("LobbyDrivePending",true);player:SetAttribute("LobbyDriveActive",false)\n if presence then presence:refresh() end',1,true)~=nil,'publish before yielding seat cleanup')
print(string.format('PASS %d H1 presence lifecycle checks; 4-record/10000 refresh CPU %.3fms (mock, not device FPS)',checks,elapsed*1000))
