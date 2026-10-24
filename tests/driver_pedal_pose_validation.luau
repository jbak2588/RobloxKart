local fs,luau=require('@lune/fs'),require('@lune/luau')
local h=require('./helpers/finish_controller_harness')();local rb=h.rb
local function signal()
 local fs={};return {Connect=function(_,fn)table.insert(fs,fn);return {Disconnect=function()end}end,Fire=function(_,...)for _,fn in fs do fn(...)end end,Count=function()return #fs end}
end
local heartbeat,removing=signal(),signal();local players={h.player}
local source=fs.readFile('src/client/KDMDriverPedalController.luau')
local C=luau.load(source,{environment={CFrame=rb.CFrame,game={GetService=function(_,name)return if name=='Players'then {GetPlayers=function()return players end,PlayerRemoving=removing}else {PreSimulation=h.pre,Heartbeat=heartbeat}end}}})()
local n=0;local function check(v,m)n+=1;assert(v,m)end
h.player.UserId=42;h.kart:SetAttribute('PrototypeKart',true);h.seat:SetAttribute('PrototypeKartSeat',true)
local visual=h.child(h.kart,'Model','Visual');visual:SetAttribute('VisualModelName','KDMV2')
for _,model in {'KDMV2','SprintV1'}do
 check(C.pose('Hip','Left',model).LookVector:Dot(rb.CFrame.Angles(math.rad(90),0,0).LookVector)>.999,'hip extends exactly forward')
 check(C.pose('Knee','Left',model)==rb.CFrame.identity,'straight knee')
 check(C.pose('Ankle','Left',model)==rb.CFrame.identity,'sole faces forward with straight leg')
end
C.start();C.start();check(h.pre.Count()==1 and heartbeat.Count()==1,'one bounded simulation and polling owner')
for _,jointClass in {'Motor6D','AnimationConstraint'}do
 for _,model in {'KDMV2','SprintV1'}do
  visual:SetAttribute('VisualModelName',model)
  for cycle=1,6 do
   local character,shoulder,human=h.character('UpperTorso','RightShoulder');character.Parent=h.object('Folder','World');human.Health=100
   local originals={};local legs={}
   for _,side in {'Left','Right'}do
    for _,kind in {'Hip','Knee','Ankle'}do
     local part=h.child(character,'Part',side..(if kind=='Hip'then 'UpperLeg'elseif kind=='Knee'then 'LowerLeg'else 'Foot'))
     local joint=h.child(part,jointClass,side..kind);joint.Transform=rb.CFrame.Angles(.03,.04,.05)
     table.insert(originals,joint.Transform);table.insert(legs,joint)
    end
   end
   h.player:SetAttribute('RaceState','RACING');heartbeat:Fire(.25);h.pre:Fire(.016)
   check(legs[1].Transform~=originals[1] and legs[4].Transform~=originals[4],'both hips extend forward for '..model..'/'..jointClass)
   check(shoulder.Transform==rb.CFrame.Angles(.03,.04,.05),'wheel grip and celebration shoulder untouched')
   h.player:SetAttribute('RaceState','FINISHED');heartbeat:Fire(.25);h.pre:Fire(.016)
   check(legs[1].Transform~=originals[1],'pedal pose persists for front-camera results')
   h.player:SetAttribute('RaceState','GARAGE');h.player:SetAttribute('LobbyDriveActive',false);heartbeat:Fire(.25)
   for i,joint in legs do check(joint.Transform==originals[i],'exit restores original transform without accumulation')end
   h.seat:SetAttribute('LobbyKartSeat',true);h.kart:SetAttribute('LobbyOwnerUserId',42);h.player:SetAttribute('LobbyDriveActive',true);heartbeat:Fire(.25);h.pre:Fire(.016)
   check(legs[1].Transform~=originals[1],'Park seated context uses the same presentation')
   human.SeatPart=nil;h.pre:Fire(.016)
   for i,joint in legs do check(joint.Transform==originals[i],'seat loss restores all leg joints')end
  end
 end
end
local character,shoulder,human=h.character('Torso','Right Shoulder');character.Parent=h.object('Folder','World');human.Health=100
local hips={};local torso=character:FindFirstChild('Torso')
for _,side in {'Left','Right'}do
 local joint=h.child(torso,'Motor6D',side..' Hip');joint.C0=rb.CFrame.Angles(0,math.rad(90),0);joint.C1=joint.C0
 joint.Transform=rb.CFrame.identity;table.insert(hips,joint)
end
h.player:SetAttribute('RaceState','RACING');heartbeat:Fire(.25);h.pre:Fire(.016)
check(hips[1].Transform~=rb.CFrame.identity and hips[2].Transform~=rb.CFrame.identity,'R6 uses native hip frames without artificial limbs')
removing:Fire(h.player);check(hips[1].Transform==rb.CFrame.identity and hips[2].Transform==rb.CFrame.identity,'departure restores R6')
check(not source:find('SetNetworkOwner',1,true)and not source:find('AssemblyLinearVelocity',1,true)and not source:find('SeatWeld',source:find('local Players')),'no ownership, velocity or seat weld writes')
check(fs.readFile('src/client/init.client.luau'):find('KDMDriverPedalController.start()',1,true)~=nil,'client startup wired')
print('PASS: '..n..' seated R15/R6 joint, both kart families, finish, reseating and restoration checks')
