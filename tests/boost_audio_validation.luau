-- Production shared Sound state machine; no simulated claim of audible playback.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local config=luau.load(fs.readFile('src/shared/AudioConfig.luau'))()
local shared={WaitForChild=function(_,name)return name end}
local audio=luau.load(fs.readFile('src/client/AudioRuntime.luau'),{environment={
 game={GetService=function(_,name)return if name=='ReplicatedStorage' then {WaitForChild=function()return shared end} else {} end},
 script={Parent=shared},
 require=function(name)return if name=="BoostFlameEnvelope" then luau.load(fs.readFile("src/client/BoostFlameEnvelope.luau"))() else config end,
}})()
local checks=0;local function check(v,m)checks+=1;assert(v,m)end
local sounds={};local loaded=true
local attrs={};local parent={Parent={GetAttribute=function(_,key)return attrs[key]end},AssemblyLinearVelocity={X=100,Z=0}}
audio.getGroup=function()return {}end;audio.preload=function()end
function audio.createSound(name,asset,_,_,looped,volume)
 local s={Name=name,SoundId=asset,IsLoaded=loaded,Volume=volume,Looped=looped,plays=0,stops=0,IsPlaying=false}
 function s:Play()self.plays+=1;self.IsPlaying=true end
 function s:Stop()self.stops+=1;self.IsPlaying=false end
 function s:Destroy()self.destroyed=true end
 sounds[name]=s;return s
end
for _,prefix in {'Race','Lobby'}do
 attrs={};parent.AssemblyLinearVelocity.X=100
 local voice=audio.createBoostAudio(parent,prefix)
 local mini,nitro,loop=sounds[prefix..'MiniBoostStart'],sounds[prefix..'NitroStart'],sounds[prefix..'MiniBoostLoop']
 check(mini.SoundId=='rbxassetid://5199136449' and math.abs(mini.Volume-2.7980001*.8)<1e-8,'owner-selected boost asset retains approved start volume')
 check(loop.SoundId=='rbxassetid://15548491198' and loop.Looped,'real template sustain loop enabled')
 check(nitro.SoundId=='rbxassetid://83211426606907' and nitro.Volume==.75,'Nitro preserves original KDM onset')
 voice:step(0,false,false,'',true)
 for _=1,10 do
  voice:step(.02,true,false,'',true)
  for _=1,120 do voice:step(1/60,true,false,'',true)end
  attrs.KartBoostEndReason='duration_complete';voice:step(.01,false,false,'',true)
  mini.IsPlaying=false -- Natural full-clip completion before the next separate activation.
 end
 check(mini.plays==10 and nitro.plays==0,'ten Mini activations have ten owner-selected onsets and zero original Nitro onsets')
 check(loop.plays==1 and loop.IsPlaying,'connected boosts retain one continuous loop, no repeated loop attack')
 voice:step(.02,true,false,'',true)
 check(math.abs(loop.Volume-.800000012*.8)<1e-8,'sustain volume is exactly source 80 percent')
 attrs.KartOffTrack=true;parent.AssemblyLinearVelocity.X=80
 voice:step(.1,true,false,'',true)
 check(loop.IsPlaying and loop.Volume>.63,'off-road accepted boost retains full sustain volume')
 attrs.KartOffTrack=false;parent.AssemblyLinearVelocity.X=100
 attrs.KartBoostEndReason='duration_complete';voice:step(.5,false,false,'',true)
 check(loop.IsPlaying and math.abs(loop.Volume-config.BOOST.LOOP_VOLUME*.75)<1e-8,'remaining flame tail sustains and fades audio after boost expiry')
 check(mini.IsPlaying and math.abs(mini.Volume-config.BOOST.START_VOLUME*.75)<1e-8,'long original clip fades by the same flame weight')
 parent.AssemblyLinearVelocity.X=82;voice:step(.1,false,false,'',true)
 check(not loop.IsPlaying and loop.Volume==0,'same flame end-speed stops residual loop')
 check(not mini.IsPlaying and mini.Volume==0,'flame extinction stops the long original clip')
 parent.AssemblyLinearVelocity.X=100;voice:step(.1,true,false,'',true)
 voice:step(.1,true,true,'',true)
 check(nitro.plays==1 and loop.IsPlaying,'Nitro onset remains distinct while Mini loop continues')
 for _=1,120 do voice:step(1/60,true,true,'',true)end
 check(nitro.plays==1,'held Nitro never repeats')
 attrs.KartBoostEndReason='cancelled';voice:step(.01,false,false,'cancelled',true)
 check(not loop.IsPlaying and loop.Volume==0,'cancelled boost has no natural flame/audio tail')
 check(not mini.IsPlaying and mini.Volume==0,'cancelled boost stops the long original clip too')
 voice:step(.1,false,true,'',true)
 check(not loop.IsPlaying,'Nitro alone does not gain new template sustain')
 voice:step(.01,false,false,'cancelled',false)
 check(not mini.IsPlaying and not nitro.IsPlaying and not loop.IsPlaying,'lifecycle gate silences every voice')
 voice:destroy();voice:destroy()
 check(mini.destroyed and nitro.destroyed and loop.destroyed,'bounded instances destroyed idempotently')
 local plays=mini.plays+nitro.plays+loop.plays;voice:step(.1,true,true,'',true)
 check(plays==mini.plays+nitro.plays+loop.plays,'destroyed voice cannot resurrect')
end
attrs={};parent.AssemblyLinearVelocity.X=70
local climb=audio.createBoostAudio(parent,'Climb')
climb:step(0,false,false,'',true);climb:step(.01,true,false,'',true)
for _=1,3 do climb:step(.3,true,false,'',true)end
check(sounds.ClimbMiniBoostStart.plays==1 and not sounds.ClimbMiniBoostStart.Looped,'full launch clip plays once without timed looping')
parent.AssemblyLinearVelocity.X=100;climb:step(.3,true,false,'',true)
parent.AssemblyLinearVelocity.X=80;climb:step(.6,true,false,'',true)
check(sounds.ClimbMiniBoostStart.plays==1,'speed changes never restart the full clip')
parent.AssemblyLinearVelocity.X=100;attrs.KartBoostEndReason='duration_complete'
climb:step(.5,false,false,'duration_complete',true)
check(sounds.ClimbMiniBoostStart.IsPlaying and math.abs(sounds.ClimbMiniBoostStart.Volume-config.BOOST.START_VOLUME*.75)<1e-8,'long clip follows shrinking flame instead of ending at active timer expiry')
climb:step(.01,true,false,'',true)
check(sounds.ClimbMiniBoostStart.plays==1,'connected boost lets the current full clip finish')
climb:step(.3,true,true,'',true)
check(sounds.ClimbMiniBoostStart.IsPlaying and sounds.ClimbNitroStart.plays==1,'Nitro onset leaves the full Mini clip intact')
sounds.ClimbMiniBoostStart.IsPlaying=false
climb:step(.01,false,false,'',true);climb:step(.01,true,false,'',true)
check(sounds.ClimbMiniBoostStart.plays==2,'new boost after natural audio completion plays a new full clip')
climb:step(.01,false,false,'',false)
check(not sounds.ClimbMiniBoostStart.IsPlaying,'lifecycle disable stops audio immediately')
climb:destroy();parent.AssemblyLinearVelocity.X=100
local launch=audio.createBoostAudio(parent,'Launch')
launch:step(0,false,false,'',false);launch:step(.016,true,false,'',true)
check(sounds.LaunchMiniBoostStart.plays==1 and sounds.LaunchMiniBoostLoop.IsPlaying,'countdown GO starts onset and sustain')
launch:destroy()
loaded=false
local voice=audio.createBoostAudio(parent,'Denied')
voice:step(0,false,false,'',true);voice:step(.2,true,false,'',true);voice:step(.2,true,true,'',true)
for name,s in sounds do if name:match('^Denied')then check(s.plays==0,'unloaded sounds have no wrong-cue fallback')end end
voice:destroy()
print('PASS: '..checks..' source-volume, sustained Mini, exact flame-tail, Nitro isolation and cleanup checks')
