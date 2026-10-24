local h=require('./helpers/finish_controller_harness')()
local c=h.load('src/client/FinishCelebrationController.luau')
local n=0;local function check(v,m)assert(v,m);n+=1 end
local function set(k,v)h.player:SetAttribute(k,v)end
local function emitters()local r={};for _,v in h.chassis:GetDescendants()do if v:IsA('ParticleEmitter')then table.insert(r,v)end end;return r end
local touch=h.child(h.gui,'ScreenGui','TouchGui');touch.Enabled=true
c.start();c.start()
for round=1,12 do
 local park=round%2==0
 h.seat:SetAttribute('PrototypeKartSeat',not park);h.seat:SetAttribute('LobbyKartSeat',park)
 set('RaceState',if park then 'GARAGE'else 'COUNTDOWN');set('RaceFinishPhase','NONE')
 set('LobbyDriveActive',park);set('ParkTrialPhase',if park then 'COUNTDOWN'else nil);set('ParkTrialGoAt',round*100)
 set('RaceSessionId',round+100);set('RaceFinishPosition',if round%3==0 then 2 else 1);set('RaceParticipantCount',2)
 if park then set('ParkTrialPhase','FINISHING');set('ParkTrialFinishPhase','ROLL')else set('RaceState','FINISHING');set('RaceFinishPhase','ROLL')end
 check(not touch.Enabled and #emitters()==0,'ROLL suppresses native controls without particles')
 set(if park then 'ParkTrialFinishPhase'else 'RaceFinishPhase','PRESENT')
 local jets=emitters();check(#jets==2,'bounded two-emitter finish for Park and Race round '..round..' count '..#jets)
 for _,e in jets do check(not e.Enabled and e.Rate==0 and e.Lifetime.Max<=1.1,'bounded native pulse emitter')end
 local allocated=h.allocated();h.advance(12)
 check(h.allocated()==allocated and #emitters()==2,'long results reuse same emitters without allocations')
 for _,e in jets do check(e.emitCalls>4,'celebration persists beyond initial burst')end
 set(if park then 'ParkTrialPhase'else 'RaceState',if park then 'COUNTDOWN'else 'PRE_RACE')
 check(#emitters()==0 and touch.Enabled,'Replay/Rematch clears effects and restores controls')
 h.advance(4);check(#emitters()==0,'stale scheduled bursts cannot affect new countdown')
end
set('LobbyDriveActive',true);set('ParkTrialPhase','FINISHED');set('ParkTrialFinishPhase','PRESENT');set('ParkTrialGoAt',9999)
check(#emitters()==2,'Park results can attach while already presented')
set('LobbyDriveActive',false);set('ParkTrialPhase',nil)
check(#emitters()==0 and touch.Enabled,'Return Lobby tears down Park effects')
c.destroy();check(h.gui.ChildAdded.Count()==0,'controller releases listeners')
print('PASS '..n..' Park/Race persistent bounded finish bursts and repeated cleanup checks')
