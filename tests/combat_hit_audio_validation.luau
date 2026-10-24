local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local nodes=require('./helpers/practice_ui_nodes');local object=nodes.object
local config=luau.load(fs.readFile('src/shared/AudioConfig.luau'))()
local sounds,played,stops={}, {},0
local audio={getGroup=function()return {}end,preload=function()end,
 createSound=function(name,asset,parent,group,looped,volume,spatial)
  local s={Name=name,SoundId=asset,Volume=volume,Looped=looped,spatial=spatial,Parent=parent}
  function s:Destroy()self.Parent=nil end
  table.insert(sounds,s);return s
 end,playOnce=function(s)table.insert(played,s.Name)end,stop=function()stops+=1 end}
local shared;shared={WaitForChild=function(_,k)return if k=='Shared'then shared else k end}
local Controller=luau.load(fs.readFile('src/client/CombatHitAudioController.luau'),{environment={
 game={GetService=function(_,k)return if k=='ReplicatedStorage'then shared else {}end},
 script={Parent=shared},require=function(k)return if k=='AudioConfig'then config else audio end,
}})()
local n=0;local function check(v,l)assert(v,l);n+=1 end
local p,kart,seat,char,h=object('Player'),object('Model'),object('Seat'),object('Model'),object('Humanoid')
p.UserId=12;p.Character=char;h.Parent=char;h.Health=100;h.SeatPart=seat;seat.Parent=kart;kart.Parent=object('Workspace')
seat:SetAttribute('PrototypeKartSeat',true);kart:SetAttribute('PrototypeKart',true);kart:SetAttribute('RaceResetSerial',0)
p:SetAttribute('RaceState','RACING');p:SetAttribute('RaceCombatFeedbackSerial',9)
local view=Controller.new(p)
check(#played==0,'initial stale feedback never replays')
check(#sounds==3 and not sounds[1].spatial and not sounds[2].spatial and not sounds[3].spatial,'attacker local audio independent of target distance')
check(sounds[1].SoundId~=config.ASSETS.BOOST_START and sounds[2].SoundId~=config.ASSETS.BOOST_START,'no boost sound substituted')
check(sounds[1].PlaybackSpeed~=sounds[2].PlaybackSpeed,'explosion and lower thunder rumble have distinct playback')
local serial=9
local function race(code)
 serial+=1;p:SetAttribute('RaceCombatFeedbackCode',code);p:SetAttribute('RaceCombatFeedbackSerial',serial)
end
race('MISSILE_HIT');check(#played==1 and played[1]=='AttackerMissileHit','race missile actual hit plays explosion')
p:GetAttributeChangedSignal('RaceCombatFeedbackSerial'):Fire();check(#played==1,'same server serial does not replay')
for _,code in {'MISSILE_BLOCKED','SLICK_HIT','SMOKE_HIT','MISSILE_MISS'}do race(code)end
check(#played==1,'block and unrelated item feedback silent')
kart:SetAttribute('KartMissileHitActive',true);kart:SetAttribute('KartThunderHitActive',true)
check(#played==1,'victim state does not masquerade as attacker confirmation')
p:SetAttribute('RaceThunderHitCount',3);p:SetAttribute('RaceThunderResultSerial',1)
check(#played==2 and played[2]=='AttackerThunderHit','three Thunder targets produce one attacker rumble')
p:SetAttribute('RaceThunderHitCount',0);p:SetAttribute('RaceThunderResultSerial',2)
check(#played==2,'Thunder all-blocked/no-hit summary silent')
p:SetAttribute('RaceState','GARAGE');race('MISSILE_HIT');check(#played==2,'race result ignored in Lobby')
p:SetAttribute('LobbyDriveActive',true);p:SetAttribute('LobbyDriveGeneration',4);p:SetAttribute('LobbyCombatSessionId','P')
seat:SetAttribute('LobbyKartSeat',true);kart:SetAttribute('LobbyOwnerUserId',12)
p:SetAttribute('LobbyCombatHitSessionId','P');p:SetAttribute('LobbyCombatHitGeneration',4);p:SetAttribute('LobbyCombatHitResetSerial',0)
local seq=0
local function practice(kind)
 seq+=1;p:SetAttribute('LobbyCombatHitItem',kind);p:SetAttribute('LobbyCombatHitSerial',seq)
end
for _,kind in {'Missile','Thunder'}do
 practice(kind);check(played[#played]=='Attacker'..kind..'Hit','practice uses same sound as race '..kind)
end
check(#played==4,'one sound per practice confirmed hit')
practice('Smoke');check(#played==4,'unsupported practice sound ignored')
for _,attribute in {'LobbyCombatHitSessionId','LobbyCombatHitGeneration','LobbyCombatHitResetSerial'}do
 local previous=p:GetAttribute(attribute);p:SetAttribute(attribute,'stale');practice('Missile')
 check(#played==4,'stale practice event rejected: '..attribute);p:SetAttribute(attribute,previous)
end
kart:SetAttribute('RaceResetSerial',1);practice('Thunder');check(#played==4,'fall recovery invalidates old hit audio')
kart:SetAttribute('RaceResetSerial',0);h.Health=0;practice('Missile');check(#played==4,'dead driver silent')
h.Health=100;h.SeatPart=nil;practice('Missile');check(#played==4,'unseated driver silent')
h.SeatPart=seat;p:SetAttribute('LobbyDriveActive',false);practice('Missile');check(#played==4,'finished drive ignores delayed hit')
check(stops>0,'lifecycle transitions stop prior sounds')
check(sounds[3].SoundId=='rbxassetid://83211426606907' and sounds[3].SoundId==config.ASSETS.NITRO_START and sounds[3].SoundId~=config.ASSETS.BOOST_START and sounds[3].Volume==.75 and not sounds[3].Looped,'Missile launch preserves original KDM explosion independently of turbine tuning')
p:SetAttribute('RaceState','RACING');p:SetAttribute('RaceSessionId','r')
p:SetAttribute('RaceMissileFiredSessionId','r');p:SetAttribute('RaceMissileFiredResetSerial',0)
p:SetAttribute('RaceMissileLaunchSerial',1);check(#played==4,'warning/activation serial alone does not play launch audio')
p:SetAttribute('RaceMissileFiredSerial',1);check(#played==5 and played[5]=='AttackerMissileLaunch','actual race flight start plays launch sound')
p:GetAttributeChangedSignal('RaceMissileFiredSerial'):Fire();check(#played==5,'duplicate launch serial ignored')
p:SetAttribute('RaceMissileFiredResetSerial',-1);p:SetAttribute('RaceMissileFiredSerial',2);check(#played==5,'stale launch after recovery ignored')
p:SetAttribute('RaceMissileFiredResetSerial',0);p:SetAttribute('RaceMissileFiredSessionId','old');p:SetAttribute('RaceMissileFiredSerial',3);check(#played==5,'stale launch from previous race ignored')
p:SetAttribute('RaceState','GARAGE');p:SetAttribute('LobbyDriveActive',true);practice('MissileLaunch')
check(#played==6 and played[6]=='AttackerMissileLaunch','practice flight uses same onset sound')
view:destroy();view:destroy();p:SetAttribute('LobbyDriveActive',true);practice('Thunder')
check(#played==6 and not sounds[1].Parent and not sounds[2].Parent and not sounds[3].Parent,'idempotent teardown disconnects events and destroys sounds')
print('PASS: '..n..' actual attacker hit audio / Race and practice / no duplicate / no block / lifecycle checks')
