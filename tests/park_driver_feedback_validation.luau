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
local block=assert(drive:match('(  local miniBoost=.-previousBoost,previousNitro=miniBoost,nitro)'),'separate production onset dispatch')
local mini,nitro,plays,stops=false,false,0,0
local tick=luau.load('local previousBoost,previousNitro=false,false;local boostCue={};return function()\n'..block..'\nend',{environment={
 kart={GetAttribute=function(_,k)return if k=='KartBoosting'then mini else nitro end},
 Audio={playOnce=function()plays+=1 end,stop=function()stops+=1 end},
}})()
tick();check(plays==0,'idle has no onset')
mini=true;tick();check(plays==1,'successful Drift starts Mini Boost cue')
nitro=true;tick();check(plays==2,'Nitro during Mini Boost has its own launch cue')
for _=1,120 do tick()end;check(plays==2,'held active states never repeat cue')
mini=false;tick();check(stops==0,'ending Mini Boost leaves overlapping Nitro cue alone')
nitro=false;tick();check(stops==1,'both effects ended stops cue')
mini=true;nitro=true;tick();check(plays==3,'same-frame Mini Boost and Nitro play once')
mini=false;tick();mini=true;tick();check(plays==4,'Mini Boost during Nitro has its own cue')
mini=false;nitro=false;tick();nitro=true;tick();check(plays==5,'later Nitro reactivation sounds')
check(drive:find('previousBoost=false;previousNitro=false',1,true)~=nil,'detach resets both onset histories')
local serviceSource=fs.readFile('src/server/LobbyTestDriveService.luau')
check(serviceSource:find('practice:isNitro(player,now,throttle,not isRookieLoop and clearance<=Policy.FootprintMargin)',1,true)~=nil,
 'RookieLoop off-track clearance does not cancel active Nitro as a wall hit')
local combatSource=fs.readFile('src/server/LobbyPracticeCombat.luau')
check(combatSource:find('local atEdge=if self.isRookie then not self.driveGeometry.inside(pos.X,pos.Z,7) else self.driveGeometry.contact(pos.X,pos.Z)<=7',1,true)~=nil,
 'RookieLoop allows Nitro near road edge and on grass inside island boundary')
print('PASS: '..n..' Park/race driver grip and overlapping boost audio checks')
