-- Exercise the production eligibility predicate and render-frame cue dispatch.
local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local n=0;local function check(v,m)assert(v,m);n+=1 end
local source=fs.readFile('src/client/KDMDriverGripController.luau')
local grip=luau.load(source:gsub('return KDMDriverGripController%s*$','KDMDriverGripController.context=findGripContext;return KDMDriverGripController'),{environment={
 game={GetService=function()return{}end},Vector3=rb.Vector3,CFrame=rb.CFrame,
}})()
local kart=rb.Instance.new('Model');kart:SetAttribute('LobbyKart',true);kart:SetAttribute('LobbyOwnerUserId',42)
local seat=rb.Instance.new('Seat');seat:SetAttribute('LobbyKartSeat',true);seat.Parent=kart
local visual=rb.Instance.new('Model');visual.Name='Visual';visual:SetAttribute('VisualModelName','KDMV2');visual.Parent=kart
local pivot=rb.Instance.new('Part');pivot.Name='SteeringPivot';pivot.Parent=visual
local attrs={RaceState='GARAGE',LobbyDriveActive=true}
local player={UserId=42,GetAttribute=function(_,k)return attrs[k]end}
local humanoid={SeatPart=seat}
local function active()local s,p=grip.context(player,humanoid);return s==seat and p==pivot end
check(active(),'Park seated owner uses the same KDM V2 wheel grip')
attrs.LobbyDriveActive=false;check(not active(),'return Lobby releases hands even before seat replication')
attrs.LobbyDriveActive=true;kart:SetAttribute('LobbyOwnerUserId',43);check(not active(),'another owner kart rejected')
kart:SetAttribute('LobbyOwnerUserId',42)
visual:SetAttribute('VisualModelName','Other');check(not active(),'other visual models unchanged')
visual:SetAttribute('VisualModelName','KDMV2')
humanoid.SeatPart=nil;check(not active(),'seat loss releases grip');humanoid.SeatPart=seat
for _,state in {'PRE_RACE','COUNTDOWN','RACING','FINISHING','FINISHED','DNF'}do
 attrs.RaceState=state;check(not active(),'Lobby kart cannot enter race grip path: '..state)
end
kart:SetAttribute('PrototypeKart',true);seat:SetAttribute('PrototypeKartSeat',true)
attrs.LobbyDriveActive=false
for _,state in {'PRE_RACE','COUNTDOWN','RACING'}do attrs.RaceState=state;check(active(),'official race grip retained: '..state)end
for _,state in {'GARAGE','FINISHING','FINISHED','DNF'}do attrs.RaceState=state;check(not active(),'inactive race state releases hands: '..state)end

local drive=fs.readFile('src/client/LobbyTestDriveController.luau')
check(drive:find("Audio.createBoostAudio(body,'Lobby')",1,true)~=nil,'Park uses shared distinct boost/Nitro audio')
check(drive:find("boostAudio:step(dt,miniBoost,nitro",1,true)~=nil,'Park supplies independent Mini/Nitro state')
check(drive:find('boostAudio:destroy();boostAudio=nil',1,true)~=nil,'detach destroys shared boost voices')
check(not drive:find('Audio.playOnce(boostCue)',1,true),'Mini Boost one-shot removed')
local serviceSource=fs.readFile('src/server/LobbyTestDriveService.luau')
check(serviceSource:find('practice:isNitro(player,now,throttle,not isRookieLoop and clearance<=Policy.FootprintMargin)',1,true)~=nil,
 'RookieLoop off-track clearance does not cancel active Nitro as a wall hit')
local combatSource=fs.readFile('src/server/LobbyPracticeCombat.luau')
check(combatSource:find('local atEdge=if self.isRookie then not self.driveGeometry.inside(pos.X,pos.Z,7) else self.driveGeometry.contact(pos.X,pos.Z)<=7',1,true)~=nil,
 'RookieLoop allows Nitro near road edge and on grass inside island boundary')
print('PASS: '..n..' Park/race driver grip and overlapping boost audio checks')
