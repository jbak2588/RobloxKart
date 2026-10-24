local harness=require('./helpers/finish_controller_harness')
local n=0;local function check(v,label)assert(v,label);n+=1 end
for _,boundary in {'runner-up','DNF','GARAGE','COUNTDOWN','session','seat','character','teleport','destroy'} do
 local h=harness();local p=h.player
 local particles=h.load('src/client/FinishCelebrationController.luau')
 local driver=h.load('src/client/DriverCelebrationController.luau')
 particles.start();driver.start()
 local function set(name,value)p:SetAttribute(name,value)end
 set('RaceWinnerAwaitingRunnerUp',true);set('RaceState','FINISHING');set('RaceFinishPhase','PRESENT')
 local jets={};for _,d in h.chassis:GetDescendants()do if d:IsA('ParticleEmitter')then table.insert(jets,d)end end
 local allocated=h.allocated()
 h.advance(6);set('RaceState','FINISHED');h.advance(6)
 h.pre:Fire(12.31);local wave=h.joint.Transform;h.pre:Fire(.125)
 check(h.joint.Transform~=wave,'winner keeps waving beyond fixed sequence: '..boundary)
 check(#jets==2 and not jets[1].destroyed and h.allocated()==allocated,'two emitters reused during long wait: '..boundary)
 check(jets[1].emitCalls>3 and jets[2].emitCalls==jets[1].emitCalls,'bounded repeated paired pulses: '..boundary)
 check(not jets[1].Enabled and jets[1].Rate==0,'no continuous unbounded emission')
 if boundary=='runner-up' then set('RaceWinnerAwaitingRunnerUp',false);h.advance(2);check(not jets[1].destroyed,'runner-up arrival does not end the displayed result celebration');set('RaceState','GARAGE')
 elseif boundary=='session' then set('RaceState','COUNTDOWN');set('RaceSessionId',902)
 elseif boundary=='seat' then h.humanoid.SeatPart=nil
 elseif boundary=='character' then p.CharacterRemoving:Fire(h.player.Character)
 elseif boundary=='teleport' then p.OnTeleport:Fire(h.rb.Enum.TeleportState.Started)
 elseif boundary=='destroy' then particles.destroy()
 else set('RaceState',boundary)end
 h.pre:Fire(.125)
 local afterStop=h.joint.Transform
 h.pre:Fire(.125)
 -- Teleport/explicit particle-controller teardown own particle cleanup only;
 -- the separate driver controller restores on its character/race lifecycle.
 if boundary~='teleport' and boundary~='destroy' then
  check(h.joint.Transform==afterStop,'wave ends or restores on boundary: '..boundary)
 end
 local count=jets[1].emitted+jets[2].emitted
 h.advance(10)
 check(jets[1].destroyed and jets[2].destroyed,'boundary removes extended particles: '..boundary)
 check(jets[1].emitted+jets[2].emitted==count,'stale callback emits nothing: '..boundary)
 particles.destroy()
end
-- Solo and placed racers also keep celebrating until leaving results.
for _,entry in {{1,1},{2,4}} do
 local h=harness();local p=h.player;local c=h.load('src/client/FinishCelebrationController.luau');c.start()
 p:SetAttribute('RaceParticipantCount',entry[2]);p:SetAttribute('RaceFinishPosition',entry[1])
 p:SetAttribute('RaceState','FINISHING');p:SetAttribute('RaceFinishPhase','PRESENT')
 local jets={};for _,d in h.chassis:GetDescendants()do if d:IsA('ParticleEmitter')then table.insert(jets,d)end end
 h.advance(5)
 check(not jets[1].destroyed and not jets[2].destroyed,'solo/placed repeats while result remains visible')
 check(jets[1].emitCalls>3,'solo/placed uses bounded repeated pulses');p:SetAttribute('RaceState','COUNTDOWN');check(jets[1].destroyed,'new countdown cleans up particles')
 c.destroy()
end
print('PASS: '..n..' result persistence, runner-up arrival, bounded emissions and lifecycle checks')
