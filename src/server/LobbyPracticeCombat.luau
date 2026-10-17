-- Isolated Hub combat adapters. Never joins RaceSession or invents Player instances.
local RS=game:GetService('ReplicatedStorage')
local Workspace=game:GetService('Workspace')
local Shared=RS:WaitForChild('Shared')
local Config=require(Shared:WaitForChild('RaceItemConfig'))
local Kart=require(Shared:WaitForChild('KartConfig'))
local Policy=require(Shared:WaitForChild('LobbyPracticePolicy'))
local DriveGeometry=require(Shared:WaitForChild('LobbyDriveGeometry')).create(require(Shared:WaitForChild('LobbyDrivePolicy')))
local Route=require(Shared:WaitForChild('LobbyDemoRoute'))
local Loadout=require(script.Parent.RaceLoadout)
local Visuals=require(script.Parent.RaceItemVisuals)
local Geometry=require(script.Parent.RaceItemGeometry)
local Missile=require(script.Parent.HomingMissileService)
local Thunder=require(script.Parent.ThunderStrikeService)
local Smoke=require(script.Parent.SmokeHazardService)
local Slick=require(script.Parent.SlickMotion)
local Drift=require(script.Parent.LobbyDriftSession)
local Combat={};Combat.__index=Combat
local offensive={Slick=true,Missile=true,Smoke=true,Thunder=true}
local messages={empty_charge='RECHARGING',invalid_item='ITEM UNAVAILABLE',missile_limit='TOO MANY MISSILES • TRY AGAIN',
 thunder_limit='THUNDER BUSY • TRY AGAIN',hazard_limit='TOO MANY CLOUDS • TRY AGAIN',no_road_behind='NO GROUND BEHIND',
 invalid_driver='ENTER A PRACTICE KART',invalid_target='NO TARGET AHEAD',no_target_ahead='NO TARGET AHEAD'}

-- Adapter attributes belong to practice actors, not the live race protocol.
local function actor(owner,record)
 local a={owner=owner,record=record,UserId=if owner then owner.UserId else -1,DisplayName=if owner then owner.DisplayName else 'PRACTICE BOT',attrs={},refill={},lastUse=-math.huge}
 function a:GetAttribute(key) return self.attrs[key] end
 function a:SetAttribute(key,value)
  self.attrs[key]=value
  if self.owner then self.owner:SetAttribute(key:gsub('^Race','Lobby'),value) end
  if not self.owner then self.record.kart:SetAttribute(key:gsub('^Race','Lobby'),value)end
 end
 return a
end
function Combat.new(zone,records)
 local self=setmetatable({zone=zone,records=records,actors={},hazards={},session={roundId=1,id='PRACTICE:'..tostring(os.clock())}},Combat)
 self.folder=Instance.new('Folder');self.folder.Name='LobbyPracticeEffects';self.folder.Parent=zone
 local model=Instance.new('Model');model.Name='LobbyPracticeBot';model:SetAttribute('LobbyPracticeBot',true)
 local body=Instance.new('Part');body.Name='Chassis';body.Size=Vector3.new(6,1,8);body.Transparency=1
 body.Anchored=true;body.CanCollide=false;body.CanTouch=false;body.CanQuery=false;body.CastShadow=false;body.Parent=model;model.PrimaryPart=body
 model:SetAttribute('RaceResetSerial',0);model.Parent=zone
 self.bot=actor(nil,{kart=model,body=body});self.botElapsed=nil
 self.bot.attrs.RaceSessionId=self.session.id
 local deps={parent=self.folder,visuals=Visuals,
  getKart=function(a)if self:valid(a)then return a.record.kart,a.record.body end end,
  getSession=function(a)if self:valid(a)then return self.session end end,
  resolve=function(target,source,id)return self:resolve(target,source,id,os.clock())end,
  result=function(source,hits,blocks)
   self:feedback(source,if hits>0 then 'THUNDER HIT '..hits elseif blocks>0 then 'THUNDER BLOCKED' else 'THUNDER NO HIT')
   if hits>0 then self:hitSound(source,'Thunder')end
  end}
 self.missiles=Missile.new(Config,deps);self.thunder=Thunder.new(Config,deps)
 local smokeDeps=table.clone(deps)
 smokeDeps.geometry={crosses=Geometry.crosses,smokeDropFrame=function(_,body,distance)return self:dropFrame(body,distance,Config.SMOKE_WIDTH,Config.SMOKE_LENGTH)end}
 self.smoke=Smoke.new(Config,smokeDeps)
 return self
end
function Combat:valid(a)
 if not a or self.stopped or not self.zone.Parent then return false end
 if a==self.bot then return self.zone:FindFirstChild('LobbyDemoState')~=nil and a.record.kart.Parent~=nil and self.botElapsed~=nil end
 local p,r=a.owner,a.record
 return self.actors[p]==a and self.records[p]==r and r.seated and r.body.Parent~=nil
  and p.Parent~=nil and p.Character==r.character and r.humanoid.Health>0
  and r.humanoid.SeatPart==r.seat and r.seat.Occupant==r.humanoid
  and p:GetAttribute('RaceState')=='GARAGE' and p:GetAttribute('KDMRoutePending')~='RACE_LAUNCH'
end
function Combat:feedback(a,message)
 if not a then return end
 a:SetAttribute('RacePracticeMessage',message)
 a:SetAttribute('RacePracticeMessageAt',Workspace:GetServerTimeNow())
 a:SetAttribute('RacePracticeMessageSerial',(a:GetAttribute('RacePracticeMessageSerial')or 0)+1)
end
function Combat:hitSound(a,id)
 if not self:valid(a)or not a.owner then return end
 local p=a.owner
 p:SetAttribute('LobbyCombatHitItem',id)
 p:SetAttribute('LobbyCombatHitSessionId',self.session.id)
 p:SetAttribute('LobbyCombatHitGeneration',a.record.generation)
 p:SetAttribute('LobbyCombatHitResetSerial',a.record.kart:GetAttribute('RaceResetSerial'))
 p:SetAttribute('LobbyCombatHitSerial',(p:GetAttribute('LobbyCombatHitSerial')or 0)+1)
end
function Combat:publish(a,now)
 if not a.owner then return end
 local p,l=a.owner,a.loadout
 p:SetAttribute('LobbyCombatSessionId',self.session.id)
 for _,id in Policy.Items do
  p:SetAttribute('LobbyCharge'..id,l.counts[id])
  p:SetAttribute('LobbyReadyAt'..id,if a.refill[id]then Workspace:GetServerTimeNow()+math.max(0,a.refill[id]-now)else 0)
 end
 p:SetAttribute('LobbyBonusProgress',l.bonusProgress);p:SetAttribute('LobbyBonusPending',l.bonusPending)
end
function Combat:add(player,record)
 self:remove(player)
 local a=actor(player,record);a.loadout=Loadout.new();a.loadout:preparePractice()
 a.attrs.RaceSessionId=self.session.id;self.actors[player]=a
 record.kart:SetAttribute('RaceResetSerial',0)
 self:publish(a,os.clock())
 self:feedback(a,'PRACTICE • ITEMS REFILL IN 6s')
end
function Combat:clearTransient(a)
 self.missiles:clearPlayer(a);self.thunder:clearPlayer(a);self.smoke:clearPlayer(a)
 for i=#self.hazards,1,-1 do if self.hazards[i].owner==a then self.hazards[i].model:Destroy();table.remove(self.hazards,i)end end
 if a.shield then a.shield:Destroy();a.shield=nil end
 a.shieldEnd=nil;a.effect=nil;a.immune=nil;a.nitroEnd=nil;a.previous=nil
 a.record.kart:SetAttribute('KartNitroEndReason','cancelled')
 if a.slick then a.slick:stop()end
 for _,key in {'KartShieldActive','KartNitroActive','KartSlickActive','KartMissileHitActive','KartThunderHitActive','KartSmokeObscuredActive'}do a.record.kart:SetAttribute(key,false)end
end
function Combat:remove(player)
 local a=self.actors[player];if not a then return end
 self:clearTransient(a);a.loadout:clear();self.actors[player]=nil
 for _,id in Policy.Items do player:SetAttribute('LobbyCharge'..id,0);player:SetAttribute('LobbyReadyAt'..id,0)end
 player:SetAttribute('LobbyBonusProgress',0);player:SetAttribute('LobbyBonusPending',false);player:SetAttribute('LobbyCombatSessionId',nil)
 for _,key in {'LobbyMissileIncomingCount','LobbyThunderIncomingCount'}do player:SetAttribute(key,0)end
 self:feedback(a,'')
end
function Combat:recover(player)
 local a=self.actors[player];if not a then return end
 self:clearTransient(a)
 local k=a.record.kart;k:SetAttribute('RaceResetSerial',(k:GetAttribute('RaceResetSerial')or 0)+1)
 -- Inventory, refill deadlines, successful BOOST progress and pending survive.
end
function Combat:boost(player)
 local a=self.actors[player];if not a or not self:valid(a)then return end
 local awards,pending=a.loadout.bonusAwardCount,a.loadout.bonusPending
 a.loadout:recordBoost(Config.DRIFT_BONUS_REQUIRED_BOOSTS);self:publish(a,os.clock())
 if a.loadout.bonusAwardCount>awards then self:feedback(a,'NITRO +1 • FIVE BOOSTS')
 elseif not pending and a.loadout.bonusPending then self:feedback(a,'NITRO PENDING • USE NITRO')end
end
function Combat:physical(player,now)
 local a=self.actors[player];return a and a.effect and now<a.effect.untilTime
end
function Combat:isNitro(player,now,throttle,wall)
 local a=self.actors[player];if not a then return false end
 if a.nitroEnd and (now>=a.nitroEnd or throttle<=0 or wall or self:physical(player,now))then
  a.record.kart:SetAttribute('KartNitroEndReason',if now>=a.nitroEnd and throttle>0 and not wall and not self:physical(player,now)then 'duration_complete'else 'cancelled')
  a.nitroEnd=nil
 end
 local active=a.nitroEnd~=nil;a.record.kart:SetAttribute('KartNitroActive',active);return active
end
function Combat:targets(source)
 local candidates={self.bot};for _,a in self.actors do table.insert(candidates,a)end
 local out={};local body=source.record.body
 for _,a in candidates do if a~=source and self:valid(a)then
  local delta=a.record.body.Position-body.Position;delta=Vector3.new(delta.X,0,delta.Z)
  local d=delta.Magnitude
  if d>1 and d<=Policy.TargetRange and body.CFrame.LookVector:Dot(delta.Unit)>=Policy.ForwardDot then table.insert(out,{actor=a,distance=d})end
 end end
 table.sort(out,function(a,b)if math.abs(a.distance-b.distance)<.001 then return a.actor.UserId<b.actor.UserId end;return a.distance<b.distance end)
 return out
end
function Combat:dropFrame(body,distance,width,length)
 local f=body.CFrame.LookVector;f=Vector3.new(f.X,0,f.Z)
 if f.Magnitude<.001 then return nil end
 local c=self.zone:GetAttribute('Center');local pos=body.Position-f.Unit*distance
 if not DriveGeometry.inside(pos.X-c.X,pos.Z-c.Z,7)then return nil end
 pos=Vector3.new(pos.X,c.Y+.25,pos.Z)
 local frame=CFrame.lookAt(pos,pos+f.Unit)
 for _,x in {-(width or Config.SLICK_WIDTH)/2,(width or Config.SLICK_WIDTH)/2}do
  for _,z in {-(length or Config.SLICK_LENGTH)/2,(length or Config.SLICK_LENGTH)/2}do
   local corner=frame*Vector3.new(x,0,z)
   if not DriveGeometry.inside(corner.X-c.X,corner.Z-c.Z)then return nil end
  end
 end
 return frame
end
function Combat:use(player,generation,id,extra)
 local a=self.actors[player];local now=os.clock()
 if not a or not self:valid(a)or generation~=a.record.generation or extra~=nil
  or type(id)~='string' or not table.find(Policy.Items,id)or now-a.lastUse<Policy.UseInterval then return false end
 a.lastUse=now
 local accepted,reason=a.loadout:useItem(id,function(item)
  if item=='Nitro'then
   local r=a.record
   if a.nitroEnd or r.throttle<=0 or now-r.lastInput>.5 or r.crashEnd or self:physical(player,now)then return false,'NITRO UNAVAILABLE'end
   local c=self.zone:GetAttribute('Center');local pos=r.body.Position-c
   if DriveGeometry.contact(pos.X,pos.Z)<=7 then return false,'MOVE AWAY FROM EDGE'end
   a.nitroEnd=now+Kart.NITRO_DURATION;r.kart:SetAttribute('KartNitroEndReason','');return true
  elseif item=='Shield'then
   if a.shieldEnd and now<a.shieldEnd then return false,'SHIELD ACTIVE'end
   if a.shield then a.shield:Destroy();a.shield=nil end
   a.shield=Visuals.shield(a.record.kart,a.record.body);a.shieldEnd=now+Config.SHIELD_DURATION
   a.record.kart:SetAttribute('KartShieldActive',true);return true
  elseif item=='Missile'or item=='Thunder'then
   local targets=self:targets(a);if #targets==0 then return false,'NO TARGET AHEAD'end
   if item=='Missile'then return self.missiles:launch(a,targets[1].actor,self.session,now)end
   local list={};for _,v in targets do table.insert(list,v.actor)end
   return self.thunder:launch(a,list,self.session,now)
  elseif item=='Smoke'then return self.smoke:deploy(a,self.zone,now)
  else
   if #self.hazards>=Config.SLICK_MAX_HAZARDS then return false,'HAZARD LIMIT'end
   local frame=self:dropFrame(a.record.body,Config.SLICK_DROP_DISTANCE);if not frame then return false,'NO GROUND BEHIND'end
   local model,trigger,deploy=Visuals.slick(self.folder,frame,Config,a.record.body.CFrame)
   table.insert(self.hazards,{owner=a,kart=a.record.kart,reset=a.record.kart:GetAttribute('RaceResetSerial'),model=model,trigger=trigger,deploy=deploy,born=now,handled={}})
   return true
  end
 end)
 if accepted and id~='Nitro'then a.refill[id]=now+Policy.RefillSeconds end
 self:publish(a,now);self:feedback(a,if accepted then string.upper(id)..' USED'else (messages[reason]or string.upper(reason or 'ITEM UNAVAILABLE')))
 return accepted
end
function Combat:resolve(target,source,id,now)
 if not offensive[id]then return false,'unsupported_item'end
 if not self:valid(source)or not self:valid(target)or (source==target and id~='Slick'and id~='Smoke')then return false,'invalid_target'end
 if target.immune and now<target.immune then return false,'immune'end
 if target.shieldEnd and now<target.shieldEnd then
  if target.shield then target.shield:Destroy();target.shield=nil end
  target.shieldEnd=nil;target.record.kart:SetAttribute('KartShieldActive',false)
  self:feedback(target,'BLOCKED!');if source~=target then self:feedback(source,string.upper(id)..' BLOCKED')end;return true,'blocked'
 end
 if target.effect and now<target.effect.untilTime and id~='Smoke'then return false,'effect_rejected'end
 if id=='Smoke'then
  self.smoke:apply(target,now) -- Vision only, including the bot. No speed penalty.
 else
  local r=target.record;local f=r.body.CFrame.LookVector;f=Vector3.new(f.X,0,f.Z).Unit
  if target.owner then Drift.clear(r.training)end
  target.nitroEnd=nil;r.kart:SetAttribute('KartNitroEndReason','cancelled');r.kart:SetAttribute('KartNitroActive',false);r.kart:SetAttribute('KartBoosting',false)
  target.effect={kind=id,started=now,untilTime=now+(if id=='Slick'then Config.SLICK_EFFECT_DURATION elseif id=='Missile'then Config.MISSILE_EFFECT_DURATION else Config.THUNDER_EFFECT_DURATION)}
  if id=='Slick'then
   target.slick=target.slick or Slick.new(Config)
   target.slick:start(target,now,f,f,if target.owner then math.abs(r.body.AssemblyLinearVelocity:Dot(f))else target.speed or Route.Speed)
   r.kart:SetAttribute('LobbySlickStartedAt',Workspace:GetServerTimeNow())
  end
  r.kart:SetAttribute(if id=='Slick'then 'KartSlickActive'elseif id=='Missile'then 'KartMissileHitActive'else 'KartThunderHitActive',true)
 end
 target.immune=now+Config.RACE_ITEM_HIT_IMMUNITY
 self:feedback(target,if id=='Smoke'then 'SMOKED!'elseif id=='Thunder'then 'SHOCKED!'else string.upper(id)..' HIT!')
 if source~=target then self:feedback(source,string.upper(id)..' HIT: '..target.DisplayName)end
 if id=='Missile'and source~=target then self:hitSound(source,id)end
 return true,'hit'
end
function Combat:motion(player,now,dt,f,right,velocity,yaw)
 local a=self.actors[player];if not a or not a.effect or now>=a.effect.untilTime then return velocity,yaw end
 local effect=a.effect
 if effect.kind=='Slick'then velocity,yaw=a.slick:sample(now,f)
 else
  local cap=if effect.kind=='Missile'then Config.MISSILE_SPEED_CAP else Config.THUNDER_SPEED_CAP
  if effect.kind=='Missile'then
   local side=a.record.body.AssemblyLinearVelocity:Dot(right)*math.exp(-Kart.LATERAL_GRIP*Config.MISSILE_LATERAL_GRIP_MULTIPLIER*dt)
   velocity=f*velocity:Dot(f)+right*side
  end
  if velocity.Magnitude>cap then velocity=velocity.Unit*cap end
 end
 a.record.speed=velocity:Dot(f)
 return velocity,yaw
end
function Combat:update(now,dt)
 if self.stopped then return end
 for p,a in self.actors do if not self:valid(a)then self:remove(p)end end
 local state=self.zone:FindFirstChild('LobbyDemoState')
 if state then
  if not self.botElapsed then self.botElapsed=math.max(0,Workspace:GetServerTimeNow()-state:GetAttribute('StartedAt'))end
  local b=self.bot
  local _,_,_,_,_,_,_,boosting=Route.sample(self.botElapsed,Kart.MINI_BOOST_DURATION)
  local targetSpeed=if next(self.actors)then (if boosting then Kart.MINI_BOOST_MAX_SPEED else Kart.MAX_FORWARD_SPEED)else Route.Speed
  b.speed=b.speed or Route.Speed
  if b.effect and now<b.effect.untilTime then
   if b.effect.kind=='Slick'then targetSpeed=b.slick.speed
   else targetSpeed=math.min(targetSpeed,if b.effect.kind=='Missile'then Config.MISSILE_SPEED_CAP else Config.THUNDER_SPEED_CAP)end
   b.speed=math.min(b.speed,targetSpeed)
  end
  local accel=if b.speed>targetSpeed then Kart.BOOST_EXIT_DECELERATION elseif boosting then Kart.MINI_BOOST_ACCELERATION else Kart.ACCELERATION
  b.speed+=math.clamp(targetSpeed-b.speed,-accel*dt,accel*dt)
  local rate=b.speed/Route.Speed
  self.botElapsed+=math.max(0,dt)*rate
  local x,z,dx,dz=Route.sample(self.botElapsed,Kart.MINI_BOOST_DURATION)
  local pos=self.zone:GetAttribute('Center')+Vector3.new(x,1.75,z)
  b.record.body.CFrame=CFrame.lookAt(pos,pos+Vector3.new(dx,0,dz))
  if not self.nextBotSync or now>=self.nextBotSync then
   local k=b.record.kart;k:SetAttribute('RouteElapsed',self.botElapsed);k:SetAttribute('SampledAt',Workspace:GetServerTimeNow());k:SetAttribute('RouteRate',rate)
   self.nextBotSync=now+Policy.BotSyncSeconds
  end
 elseif self.botElapsed then
  self:clearTransient(self.bot);self.botElapsed=nil;self.bot.speed=nil
  self.bot.record.kart:SetAttribute('SampledAt',nil);self.bot.record.kart:SetAttribute('RouteElapsed',nil)
 end
 local targets={}
 for _,a in self.actors do table.insert(targets,a)end
 if self:valid(self.bot)then table.insert(targets,self.bot)end
 local swept={}
 for _,a in targets do
  local r=a.record;local k=r.kart
  if a.effect and now>=a.effect.untilTime then a.effect=nil;if a.slick then a.slick:stop()end end
  for id,key in {Slick='KartSlickActive',Missile='KartMissileHitActive',Thunder='KartThunderHitActive'}do k:SetAttribute(key,a.effect~=nil and a.effect.kind==id)end
  if a.shieldEnd and now>=a.shieldEnd then if a.shield then a.shield:Destroy();a.shield=nil end;a.shieldEnd=nil;k:SetAttribute('KartShieldActive',false)end
  if a.owner then
   local changed=false
   for id,untilTime in a.refill do if now>=untilTime then a.loadout.counts[id]=1;a.refill[id]=nil;changed=true end end
   if changed then self:publish(a,now)end
  end
  table.insert(swept,{player=a,chassis=r.body,previous=a.previous or r.body.Position})
 end
 self.missiles:update(now);self.thunder:update(now);self.smoke:update(now,swept)
 for i=#self.hazards,1,-1 do
  local h=self.hazards[i]
  if now-h.born>=Config.SLICK_LIFETIME or not self:valid(h.owner)or h.kart~=h.owner.record.kart or h.reset~=h.kart:GetAttribute('RaceResetSerial')then h.model:Destroy();table.remove(self.hazards,i)
  else
   Visuals.updateSlick(h.deploy,now-h.born)
   for _,t in swept do if (t.player~=h.owner or now-h.born>=Config.SLICK_OWNER_GRACE)and not h.handled[t.player]and Geometry.crosses(h.trigger.CFrame,h.trigger.Size,t.previous,t.chassis)then
    local ok,why=self:resolve(t.player,h.owner,'Slick',now);if ok or why=='immune'then h.handled[t.player]=true end
   end end
  end
 end
 for _,a in targets do a.previous=a.record.body.Position end
end
function Combat:destroy()
 if self.stopped then return end
 for p in self.actors do self:remove(p)end
 self:clearTransient(self.bot);self.stopped=true
 self.missiles:clearSession(self.session);self.thunder:clearSession(self.session);self.smoke:clearSession(self.session)
 self.folder:Destroy();self.bot.record.kart:Destroy()
end
return Combat
