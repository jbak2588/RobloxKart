local h=require('./helpers/finish_controller_harness')()
local c=h.load('src/client/DriverCelebrationController.luau')
local n=0;local function check(v,label)assert(v,label);n+=1 end
local function set(name,value)h.player:SetAttribute(name,value)end
c.start();c.start();check(h.pre.Count()==1,'one existing PreSimulation owner')
for _,rig in {{'UpperTorso','RightShoulder'},{'Torso','Right Shoulder'},
 {'UpperTorso','RightShoulder','Motor6D',true},{'UpperTorso','RightShoulder','AnimationConstraint',true}} do
 for _,place in {1,2,3,4}do
  set('RaceState','COUNTDOWN');set('RaceFinishPhase','NONE');set('RaceParticipantCount',4);set('RaceFinishPosition',place)
  local model,joint,human=h.character(rig[1],rig[2],rig[3],rig[4]);h.player.CharacterAdded:Fire(model)
  local original=joint.Transform
  set('RaceState','FINISHING');set('RaceFinishPhase','ROLL');h.pre:Fire(.25)
  check(joint.Transform==original,'ROLL shoulder unchanged')
  set('RaceFinishPhase','PRESENT');h.pre:Fire(.25)
  local raised=joint.Transform
  check(raised~=original and human.SeatPart==h.seat,'additive seated raise')
  h.pre:Fire(.125);check(joint.Transform~=raised,'wave begins')
  -- Attribute/result updates must not reset elapsed pose progression.
  set('RaceState','FINISHED');h.pre:Fire(3)
  local hold=joint.Transform
  h.pre:Fire(.5);check(joint.Transform==hold,'final raised hold, no cumulative transform')
  set('RaceFinishPosition',if place==1 then 2 else 1);h.pre:Fire(.1)
  check(joint.Transform==hold,'place update does not restart or replace started profile')
  human.SeatPart=nil;h.pre:Fire(.1);check(joint.Transform==original,'seat loss restores exact original')
  for _,state in {'PRE_RACE','COUNTDOWN','RACING','GARAGE','DNF'}do
   human.SeatPart=h.seat;set('RaceState','FINISHING');set('RaceFinishPhase','PRESENT');h.pre:Fire(.4)
   set('RaceState',state);check(joint.Transform==original,'restore '..state)
  end
  set('RaceState','FINISHING');h.pre:Fire(.4);h.player.CharacterRemoving:Fire(model)
  check(joint.Transform==original,'character removal restores')
 end
end
local model,joint=h.character('UpperTorso','Missing');h.player.CharacterAdded:Fire(model)
set('RaceState','FINISHING');set('RaceFinishPhase','PRESENT');h.pre:Fire(.3)
check(joint.Transform==h.rb.CFrame.Angles(.03,.04,.05),'missing joint safely skipped')
set('RaceFinishPosition',0);h.pre:Fire(.3);check(true,'unauthoritative finish skipped safely')
print('PASS: '..n..' actual R6/R15 finish shoulder lifecycle/dedupe checks')
