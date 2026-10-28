-- Run the actual camera owner, using the preserved finish-controller fixture setup.
local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local source=fs.readFile('tests/finish_presentation_validation.luau')
local cut=assert(source:find('controller.start()',1,true))
local scenario=[====[
controller.start();controller.start()
check(render~=nil,'one existing chase binding')
for _,state in {{70,false,false,77.5},{80,false,false,79.21875},{90,false,false,80},{100,true,false,81},{100,false,true,85},{100,true,true,85}} do
 chassis.AssemblyLinearVelocity=rb.Vector3.new(0,0,-state[1])
 kart.attrs.KartBoosting=state[2];kart.attrs.KartNitroActive=state[3]
 for _=1,180 do render(1/60) end
 check(math.abs(camera.FieldOfView-state[4])<.001,'actual owner resolves state FOV')
 local expected=rb.CFrame.lookAt(rb.Vector3.new(0,8,18),rb.Vector3.new(0,2,-12))
 check((camera.CFrame.Position-expected.Position).Magnitude<.001,'chase distance/height unchanged')
 local before=camera.FieldOfView;kart.attrs.KartShieldActive=true;render(1/60)
 check(math.abs(camera.FieldOfView-before)<.001,'Shield ON same speed FOV')
 kart.attrs.KartShieldActive=false
end
kart.attrs.KartNitroActive=false;kart.attrs.KartBoosting=false
render(.1);check(camera.FieldOfView>80 and camera.FieldOfView<85,'Nitro decays into physical High rather than snap')
for _=1,180 do render(1/60)end
for _,reason in {'RaceControlsLocked','KartOffTrack'} do
 kart.attrs[reason]=true;for _=1,180 do render(1/60)end
 check(math.abs(camera.FieldOfView-75)<.001,'suppressed '..reason)
 kart.attrs[reason]=false
end
chassis.AssemblyLinearVelocity=rb.Vector3.new(0,0,20)
for _=1,180 do render(1/60)end
check(math.abs(camera.FieldOfView-75)<.001,'reverse has baseline')
chassis.AssemblyLinearVelocity=rb.Vector3.new(0,0,-100);kart.attrs.KartNitroActive=true
for _,phase in {'COUNTDOWN','WAITING','FINISHING','FINISHED','DNF','GARAGE'}do
 player.attrs.RaceState='RACING';player.attrs.RaceFinishPhase='NONE'
 for _=1,120 do render(1/60)end
 player.attrs.RaceState=phase;player.attrs.RaceFinishPhase=if phase=='FINISHED' then 'PRESENT' else 'NONE'
 render(1/60);check(camera.FieldOfView==75,'immediate non-racing baseline '..phase)
end
player.attrs.RaceState='RACING';player.attrs.RaceFinishPhase='NONE';for _=1,120 do render(1/60)end
kart.attrs.RaceResetSerial=1;render(1/60);check(camera.FieldOfView==75,'fall/reset serial clears smoothing state')
humanoid.SeatPart=nil;runService.Heartbeat:Fire(.25)
check(render==nil and camera.FieldOfView==70,'seat loss restores saved FOV')
humanoid.SeatPart=seat;runService.Heartbeat:Fire(.25)
check(camera.FieldOfView==75,'replacement seat starts baseline')
player.CharacterRemoving:Fire();check(render==nil and camera.FieldOfView==70,'respawn clean restore')
player.CharacterAdded:Fire(character);check(render~=nil and camera.FieldOfView==75,'character rebind baseline')
player.OnTeleport:Fire(rb.Enum.TeleportState.Started);check(render==nil and camera.FieldOfView==70,'teleport disable clean restore')
runService.Heartbeat:Fire(.25);check(render==nil,'no stale teleport re-enable')
player.OnTeleport:Fire(rb.Enum.TeleportState.Failed);runService.Heartbeat:Fire(.25);check(render~=nil,'failed teleport resumes existing chase')
check(chassis.AssemblyLinearVelocity==rb.Vector3.new(0,0,-100),'visuals never modify physical velocity')
print('PASS: '..count..' actual camera speed profile, independent Shield, finish/reset/seat/respawn/teleport checks')
]====]
luau.load(source:sub(1,cut-1)..scenario)()
