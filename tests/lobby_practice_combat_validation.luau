-- Production practice orchestrator + real projectile/Thunder/Smoke/Slick/loadout modules.
-- Native instances hold geometry; only Player transport, time and physics integration are mocked.
local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local n,now=0,0
local function check(v,l)assert(v,l);n+=1 end
local modules={}
local parent=setmetatable({WaitForChild=function(_,k)return k end},{__index=function(_,k)return k end})
local world={GetServerTimeNow=function()return 1000+now end}
local env={game={GetService=function(_,name)if name=='Workspace'then return world end;return {WaitForChild=function()return parent end}end},
 script={Parent=parent},require=function(k)return assert(modules[k],k)end,
 Instance=rb.Instance,Vector3=rb.Vector3,CFrame=rb.CFrame,Color3=rb.Color3,ColorSequence=rb.ColorSequence,NumberSequence=rb.NumberSequence,Enum=rb.Enum,
 os={clock=function()return now end}}
local function module(name,path)modules[name]=luau.load(fs.readFile(path),{environment=env})();return modules[name]end
module('KDMGameplayBalance','src/shared/KDMGameplayBalance.luau')
modules.KartConfig=require('./helpers/gameplay_config')('src/shared/KartConfig.luau')
module('RaceItemConfig','src/shared/RaceItemConfig.luau')
module('RaceItemCatalog','src/shared/RaceItemCatalog.luau');module('RaceItemSlots','src/shared/RaceItemSlots.luau')
module('RaceLoadout','src/server/RaceLoadout.luau')
for _,name in {'LobbyDrivePolicy','LobbyDriveGeometry','LobbyDemoRoute','LobbyPracticePolicy','KDMItemVFXConfig'}do module(name,'src/shared/'..name..'.luau')end
for _,name in {'RaceItemVisuals','RaceItemGeometry','HomingMissileService','ThunderStrikeService','SmokeHazardService','SlickMotion'}do module(name,'src/server/'..name..'.luau')end
-- Lune exposes native properties, not Studio Model:PivotTo physics integration.
local nativeMissile=modules.RaceItemVisuals.missile
modules.RaceItemVisuals.missile=function(...)
 local m=nativeMissile(...);local proxy={Parent=m.Parent}
 function proxy:PivotTo(cf)
  local delta=cf*m.PrimaryPart.CFrame:Inverse()
  for _,p in m:GetChildren()do if p:IsA('BasePart')then p.CFrame=delta*p.CFrame end end
 end
 function proxy:Destroy()m:Destroy();self.Parent=nil end
 function proxy:FindFirstChild(name)return m:FindFirstChild(name)end
 return proxy
end
modules.LobbyDriftSession=require('./helpers/lobby_drift_session')
local Combat=module('Combat','src/server/LobbyPracticeCombat.luau')
local cfg=modules.RaceItemConfig
local scene
local function player(id)
 local attrs={RaceState='GARAGE'}
 return {UserId=id,DisplayName='Human'..id,Parent=true,GetAttribute=function(_,k)return attrs[k]end,SetAttribute=function(_,k,v)attrs[k]=v end}
end
local function pose(r,x,z)
 r.body.CFrame=rb.CFrame.new(x,1.75,z);r.body.Position=r.body.CFrame.Position
end
local function fresh()
 if scene then scene.combat:destroy();scene.root:Destroy()end
 now=0
 local root=rb.Instance.new('Folder');local zone=rb.Instance.new('Model');zone.Parent=root;zone:SetAttribute('Center',rb.Vector3.new(120,0,766))
 local state=rb.Instance.new('Folder');state.Name='LobbyDemoState';state:SetAttribute('StartedAt',1000);state.Parent=zone
 local records={};local humans={}
 for i=1,2 do
  local p=player(i);local kart=rb.Instance.new('Model');kart.Parent=zone
  local body=rb.Instance.new('Part');body.Size=rb.Vector3.new(6,1,8);body.Parent=kart
  local human={Health=100};local seat={Occupant=human};human.SeatPart=seat
  local character={};p.Character=character
  local r={kart=kart,body=body,humanoid=human,seat=seat,character=character,seated=true,generation=1,lastInput=now,throttle=1,
   speed=60,yaw=0,training=modules.LobbyDriftSession.new()}
  pose(r,0,780-(i-1)*50);body.AssemblyLinearVelocity=rb.Vector3.new(0,0,-60)
  records[p]=r;humans[i]=p
 end
 local c=Combat.new(zone,records)
 c.bot.record.body.Position=rb.Vector3.new(0,1.75,816)
 for _,p in humans do c:add(p,records[p])end
 scene={root=root,zone=zone,records=records,humans=humans,combat=c}
 return c,humans[1],humans[2],records[humans[1]],records[humans[2]]
end
local function tick(seconds)
 for _=1,math.ceil(seconds/.01)do
  now+=.01
  for _,r in scene.records do r.lastInput=now end
  scene.combat:update(now,.01)
  -- Lune native properties do not mirror CFrame -> Position like Studio physics.
  scene.combat.bot.record.body.Position=scene.combat.bot.record.body.CFrame.Position
 end
end
local c,p,q,r,s=fresh();tick(.01)
check(#c.actors[p].loadout.slots==6,'all five tactics plus Nitro, server constructed')
local normal=modules.RaceLoadout.new();check(normal:prepare()and #normal.slots==4,'race defaults remain four')
check(not normal:prepare({'Nitro','Slick','Shield','Missile','Smoke','Thunder'}),'race rejects arbitrary six-slot prepare')
for _,id in modules.LobbyPracticePolicy.Items do check(p:GetAttribute('LobbyCharge'..id)==1,'practice initial charge '..id)end
for _,payload in {{0,'Thunder'},{2,'Thunder'},{1,'Unknown'},{1,{}}}do check(not c:use(p,payload[1],payload[2]),'stale generation or unknown payload rejected')end
check(not c:use(p,1,'Thunder',{}),'client extra target rejected')
check(c:targets(c.actors[p])[1].actor==c.actors[q],'forward human is server-selected nearest target')
pose(s,0,820);check(#c:targets(c.actors[p])==0,'behind human and bot are not ahead targets')
check(not c:use(p,1,'Missile')and p:GetAttribute('LobbyChargeMissile')==1,'no target keeps charge')
pose(s,0,730);tick(.3)
check(c:use(q,1,'Shield')and s.kart:GetAttribute('KartShieldActive')and s.kart:FindFirstChild('RaceItemShield'),'native visible Shield')
check(c:use(p,1,'Missile')and q:GetAttribute('LobbyMissileIncomingCount')==1,'real missile warning targets other seated human')
tick(.85);check(not s.kart:GetAttribute('KartMissileHitActive'),'no premature missile hit')
tick(.8);check(not s.kart:GetAttribute('KartShieldActive')and not s.kart:GetAttribute('KartMissileHitActive'),'one-hit Shield blocks actual projectile')
check(q:GetAttribute('LobbyMissileIncomingCount')==0,'incoming count balanced')
tick(5);check(p:GetAttribute('LobbyChargeMissile')==1 and q:GetAttribute('LobbyChargeShield')==1,'six-second tactical refill')
c,p,q,r,s=fresh();tick(.01)
check(c:use(p,1,'Missile'),'unshielded missile accepted');tick(1.5)
check(s.kart:GetAttribute('KartMissileHitActive'),'actual projectile resolves human hit')
local victim=c.actors[q];local ended=victim.effect.untilTime
while now<ended-.01 do
 local v=c:motion(q,now,.01,rb.Vector3.new(0,0,-1),rb.Vector3.xAxis,rb.Vector3.new(70,0,-100),0)
 check(v.Magnitude<=55.00001 and math.abs(s.speed-v:Dot(rb.Vector3.new(0,0,-1)))<1e-6,'55 cap and commanded speed synchronized through effect')
 tick(.01)
end
tick(.03);check(not c:physical(q,now),'Missile expires at configured duration')
c,p,q,r,s=fresh();tick(.01)
pose(s,0,740);check(c:use(p,1,'Thunder'),'Thunder fixed snapshot accepted')
check(q:GetAttribute('LobbyThunderIncomingCount')==1,'Thunder incoming warning')
tick(.95);check(not s.kart:GetAttribute('KartThunderHitActive'),'full warning retained')
pose(s,30,750);tick(.1);check(s.kart:GetAttribute('KartThunderHitActive'),'snapshot follows moving seated target')
for i=1,150 do
 local v=c:motion(q,now,.01,rb.Vector3.new(0,0,-1),rb.Vector3.xAxis,rb.Vector3.new(0,0,-100),0)
 check(v.Magnitude<=60.00001,'Thunder cap while active');tick(.01)
end
check(q:GetAttribute('LobbyThunderIncomingCount')==0,'Thunder warning balanced after strike')
tick(.6);check(not c:physical(q,now),'Thunder expires after two seconds')
c,p,q,r,s=fresh();tick(.01)
pose(s,0,810);check(c:use(p,1,'Slick'),'Slick rear deployment')
pose(s,0,790);tick(.01);check(s.kart:GetAttribute('KartSlickActive'),'swept Slick hits seated human')
check(not c:resolve(c.actors[q],c.actors[p],'Thunder',now),'shared one-second immunity')
local v,y=c:motion(q,now,.01,rb.Vector3.new(0,0,-1),rb.Vector3.xAxis,rb.Vector3.new(0,0,-60),0)
check(v.Magnitude<=33.001 and math.abs(y)<=cfg.SLICK_MAX_YAW_RATE,'same bounded Slick motion')
c,p,q,r,s=fresh();tick(.01)
pose(s,0,810);check(c:use(p,1,'Smoke'),'actual world Smoke deployment')
pose(s,0,790);tick(.01);check(s.kart:GetAttribute('KartSmokeObscuredActive'),'Smoke victim metadata')
check(not c:physical(q,now)and s.body.AssemblyLinearVelocity==rb.Vector3.new(0,0,-60),'Smoke is vision only')
check(s.kart:GetAttribute('KartSmokeSessionId')==q:GetAttribute('LobbyCombatSessionId'),'local haze session marker')
tick(.8);check(r.kart:GetAttribute('KartSmokeObscuredActive'),'own cloud affects owner only after grace')
tick(3.1);check(not s.kart:GetAttribute('KartSmokeObscuredActive'),'Smoke expires without rehit from same cloud')
c,p,q,r,s=fresh();tick(.01)
local a=c.actors[p];a.loadout.counts.Nitro=2
for _=1,5 do c:boost(p)end
check(a.loadout.bonusPending and a.loadout.bonusProgress==5 and a.loadout.counts.Nitro==2,'held two plus five BOOST latches one pending')
for _=1,9 do c:boost(p)end
check(a.loadout.bonusProgress==5 and a.loadout.bonusAwardCount==0,'extra BOOSTs freeze, no hidden charge')
r.throttle=0;check(not c:use(p,1,'Nitro')and a.loadout.bonusPending,'rejected Nitro neither consumes nor settles')
tick(.3);r.throttle=1;check(c:use(p,1,'Nitro'),'Nitro accepted')
check(a.loadout.counts.Nitro==2 and not a.loadout.bonusPending and a.loadout.bonusProgress==0 and a.loadout.bonusAwardCount==1,'atomic consume and pending refill')
check(c:isNitro(p,now,1,false),'three-second Nitro active')
check(not c:isNitro(p,now,0,false),'brake cancels Nitro')
check(r.kart:GetAttribute('KartNitroEndReason')=='cancelled','brake ends visual Nitro without natural tail')
for _=1,3 do c:boost(p)end
local count=a.loadout.counts.Nitro;c:recover(p)
check(a.loadout.bonusProgress==3 and a.loadout.counts.Nitro==count,'same-drive recovery preserves bonus and charges')
check(not a.nitroEnd and #c.missiles.projectiles==0,'recovery clears transients')
-- Bot has an authoritative proxy and can be a fixed target; it never attacks.
pose(r,0,850);pose(s,100,850);tick(.3)
local targets=c:targets(a);check(#targets>0 and targets[1].actor==c.bot,'server bot target')
check(c:use(p,1,'Thunder'),'Thunder can target practice bot');tick(1.1)
check(c.bot.record.kart:GetAttribute('KartThunderHitActive'),'bot hit shares actual warning/strike service')
check(c.bot.speed<=cfg.THUNDER_SPEED_CAP,'bot route speed obeys Thunder cap')
-- No walking/exited/other-session victim and no stale projectile can survive.
tick(.3);c:recover(p);pose(r,0,780);pose(s,0,730)
scene.zone.LobbyDemoState:Destroy();tick(.01)
a.loadout.counts.Missile=1;check(c:use(p,1,'Missile'),'pending departure projectile')
check(c.missiles.projectiles[1].target==c.actors[q],'departure case fixes human target')
q:SetAttribute('RaceState','RACING');tick(.01)
check(c.actors[q]==nil and #c.missiles.projectiles==0,'race handoff removes target and pending attack')
check(not c:use(q,1,'Thunder'),'departed driver cannot use practice items')
c:remove(p);check(p:GetAttribute('LobbyChargeNitro')==0 and p:GetAttribute('LobbyBonusProgress')==0,'exit clears temporary state')
c:add(p,r);check(p:GetAttribute('LobbyChargeNitro')==1 and p:GetAttribute('LobbyBonusProgress')==0,'new practice starts fresh')
c:destroy();check(not c.folder.Parent and not c.bot.record.kart.Parent,'teardown removes hazards, proxy, projectiles and effects')
scene=nil
c,p,q,r,s=fresh();c:remove(q);scene.records[q]=nil;pose(r,0,860);tick(.01)
check(c:use(p,1,'Missile'),'actual missile launch against moving authoritative bot')
while not c.bot.effect and now<8 do tick(.01)end
check(c.bot.effect and c.bot.effect.kind=='Missile','real homing projectile hits moving bot')
tick(.01);check(c.bot.speed<=cfg.MISSILE_SPEED_CAP,'bot missile hit uses real speed cap')
c:clearTransient(c.bot);c.bot.speed=70
check(c:resolve(c.bot,c.actors[p],'Slick',now),'bot Slick accepted')
tick(.01);check(c.bot.record.kart:GetAttribute('KartSlickActive')and c.bot.speed<=70*cfg.SLICK_SPEED_RETAIN+.01,'bot Slick has visible spin metadata and retained speed')
c:clearTransient(c.bot);local beforeSmoke=c.bot.speed
check(c:resolve(c.bot,c.actors[p],'Smoke',now),'bot Smoke accepted')
check(c.bot.record.kart:GetAttribute('KartSmokeObscuredActive')and c.bot.speed==beforeSmoke and not c.bot.effect,'bot Smoke has vision status without invented slowing')
c,p,q,r,s=fresh();tick(.01)
check(c:use(p,1,'Shield'),'standalone Shield visual accepted without bot attacks')
tick(4.95);check(r.kart:GetAttribute('KartShieldActive'),'Shield lasts five seconds')
tick(.1);check(not r.kart:GetAttribute('KartShieldActive'),'Shield visual expires at five seconds')
tick(.95);check(c:use(p,1,'Nitro'),'practice Nitro after Shield')
tick(2.9);check(c:isNitro(p,now,1,false),'Nitro stays active through 2.9 seconds')
tick(.11);check(not c:isNitro(p,now,1,false),'Nitro expires at three seconds')
check(r.kart:GetAttribute('KartNitroEndReason')=='duration_complete','natural Nitro end uses shared flame fade')
c:destroy();scene.root:Destroy()
scene=nil
print('PASS: '..n..' production practice loadout / PvP / bot / warning / hit / immunity / Smoke / Nitro / lifecycle checks')
