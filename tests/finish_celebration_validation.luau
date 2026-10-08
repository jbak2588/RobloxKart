local h=require('./helpers/finish_controller_harness')()
local c=h.load('src/client/FinishCelebrationController.luau')
local n=0;local function check(v,label)assert(v,label);n+=1 end
local function set(name,value)h.player:SetAttribute(name,value)end
local function emitters()
 local result={};for _,o in h.chassis:GetDescendants()do if o:IsA('ParticleEmitter')then table.insert(result,o)end end;return result
end
local touch=h.child(h.gui,'ScreenGui','TouchGui');touch.Enabled=true
local topbar=h.child(h.gui,'ScreenGui','Topbar');local buttons=h.child(h.gui,'ScreenGui','CustomResults')
c.start();c.start()
check(touch.Enabled and h.gui.ChildAdded.Count()==1,'one controller, native UI unchanged in race')
for round=1,10 do
 set('RaceState','COUNTDOWN');set('RaceFinishPhase','NONE');set('RaceSessionId',900+round)
 set('RaceFinishPosition',if round%2==1 then 1 else 2)
 set('RaceState','FINISHING');set('RaceFinishPhase','ROLL')
 check(not touch.Enabled and topbar.Enabled and buttons.Enabled,'terminal hides only native TouchGui')
 touch.Enabled=true;check(not touch.Enabled,'late native attempt cannot re-enable Jump during finish')
 check(#emitters()==0,'ROLL has no hero particles')
 set('RaceFinishPhase','PRESENT')
 local jets=emitters();local total=0
 check(#jets==2 and #h.chassis:GetChildren()==2,'exact two emitter/two attachment budget')
 for _,e in jets do
  total+=e.emitted
  check(e.emitCalls==1 and not e.Enabled and e.Rate==0,'one Emit, no continuous emission')
  check(e.Texture=='rbxasset://textures/particles/sparkles_main.dds' and e.Lifetime.Max<=1.1,'builtin bounded hero particles')
  check(e.EmissionDirection==h.rb.Enum.NormalId.Top and e.Acceleration.Y<0,'hero origin, distinct from rear exhaust')
 end
 check(total==(if round%2==1 then 32 else 18),'winner stronger than placed')
 local allocated=h.allocated()
 set('RaceState','FINISHED');set('RaceSessionComplete',false);set('RaceSessionComplete',true)
 set('RaceFinishPosition',if round%2==1 then 2 else 1);set('RaceParticipantCount',3)
 check(h.allocated()==allocated and #emitters()==2,'standings updates do not reallocate or re-emit')
 for _,e in jets do check(e.emitCalls==1,'no duplicate burst on result update')end
 local timerEnd=#h.timers
 if round%2==1 then
  for i=timerEnd-4,timerEnd-1 do
   local expected=if (i-(timerEnd-4))%2==0 then .6 else 1.2
   check(math.abs(h.timers[i].seconds-expected)<.00001,'exact winner repeat schedule .6 / 1.2')
   check(h.timers[i].seconds<h.finish.Profiles.WINNER.WaveSeconds,'refresh emission ends before wave hold')
   h.timers[i].fn()
  end
  local refreshed=0;for _,e in jets do
   check(e.emitCalls==3 and not e.Enabled and e.Rate==0,'winner has exactly three bounded pulses')
   refreshed+=e.emitted
  end
  check(refreshed==96,'user-approved winner repeat is bounded to three thirty-two-particle bursts')
  check(math.abs(h.timers[timerEnd].seconds-2.35)<.00001,'winner residual cleanup at 2.35 seconds')
 else
  for _,e in jets do check(e.emitCalls==1,'placed remains one-shot')end
 end
 h.timers[#h.timers].fn();check(#emitters()==0 and #h.chassis:GetChildren()==0,'particle expiry leaves zero residuals')
 set('RaceParticipantCount',2);check(#emitters()==0,'expired finish not replayed')
 set('RaceState','PRE_RACE');check(touch.Enabled,'Rematch restores previous native state')
end
touch.Enabled=false
set('RaceState','DNF');check(not touch.Enabled and #emitters()==0,'DNF no celebration/native Jump')
set('RaceState','GARAGE');check(not touch.Enabled,'originally disabled TouchGui remains disabled')
touch.Enabled=true
set('RaceState','FINISHED')
local late=h.object('ScreenGui','TouchGui');late.Parent=h.gui
check(not late.Enabled,'late/recreated TouchGui suppressed')
late.Parent=nil;late.Parent=h.gui;check(not late.Enabled,'reparented GUI respects original disabled state')
set('RaceState','RACING');check(touch.Enabled and not late.Enabled,'per-instance prior state restored independently')
set('RaceState','FINISHING');set('RaceFinishPhase','PRESENT');set('RaceSessionId',999)
check(#emitters()==2,'new session rearms celebration')
local cancelledJets=emitters();local beforeCancel={cancelledJets[1].emitted,cancelledJets[2].emitted}
h.humanoid.SeatPart=nil;check(#emitters()==0,'seat loss removes particles')
for i=#h.timers-4,#h.timers do h.timers[i].fn()end
for i,e in cancelledJets do check(e.emitted==beforeCancel[i],'seat loss cancels queued winner refreshes')end
h.humanoid.SeatPart=h.seat;check(#emitters()==0,'seat regain does not replay same finish')
set('RaceState','PRE_RACE');set('RaceSessionId',1000);set('RaceFinishPosition',1)
set('RaceState','FINISHING');set('RaceFinishPhase','PRESENT')
local oldSessionJets=emitters();local oldTimerEnd=#h.timers
local oldCounts={oldSessionJets[1].emitted,oldSessionJets[2].emitted}
set('RaceSessionId',1001)
check(#emitters()==2 and oldSessionJets[1].destroyed and oldSessionJets[2].destroyed,'session change removes old burst and rearms new session')
for i=oldTimerEnd-4,oldTimerEnd do h.timers[i].fn()end
for i,e in oldSessionJets do check(e.emitted==oldCounts[i],'session change cancels old queued pulses')end
check(#emitters()==2,'old session expiry cannot destroy new session emitters')
set('RaceState','DNF');check(#emitters()==0,'DNF cancels active replacement session sequence')
h.player.CharacterRemoving:Fire();check(#emitters()==0,'character removal clean')
h.player.OnTeleport:Fire(h.rb.Enum.TeleportState.Started)
check(touch.Enabled,'teleport restores original native state')
h.player.OnTeleport:Fire(h.rb.Enum.TeleportState.Failed);check(not touch.Enabled,'failed teleport resumes terminal suppression')
c.destroy();c.destroy()
check(touch.Enabled and #emitters()==0 and h.gui.ChildAdded.Count()==0,'destroy restores UI and disconnects observers')
for _,timer in h.timers do timer.fn()end
check(#emitters()==0,'stale delayed callbacks cannot recreate effects')
print('PASS: '..n..' bounded finish pulse and terminal TouchGui lifecycle checks')
