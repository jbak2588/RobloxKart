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
 local s={Name=name,SoundId=asset,IsLoaded=loaded,Volume=volume,Looped=looped,PlaybackSpeed=1,plays=0,stops=0,IsPlaying=false}
 function s:Play()self.plays+=1;self.IsPlaying=true end
 function s:Stop()self.stops+=1;self.IsPlaying=false end
 function s:Destroy()self.destroyed=true end
 sounds[name]=s;return s
end
for _,prefix in {'Race','Lobby'}do
 attrs={};parent.AssemblyLinearVelocity.X=100
 local voice=audio.createBoostAudio(parent,prefix)
 local mini,nitro=sounds[prefix..'MiniBoostStart'],sounds[prefix..'NitroStart']
 check(mini.SoundId=='rbxassetid://83211426606907' and math.abs(mini.Volume-.75)<1e-8,'original Mini asset and volume restored')
 check(nitro.SoundId==mini.SoundId and nitro.Volume==.75 and nitro.PlaybackSpeed==1,'Nitro original onset unchanged')
 check(math.abs(mini.PlaybackSpeed/nitro.PlaybackSpeed-.8)<1e-8,'Mini pitch is exactly 20 percent lower than Nitro')
 check(not mini.Looped and not sounds[prefix..'MiniBoostLoop'],'no timed looping or template turbine voice')
 voice:step(0,false,false,'',true)
 voice:step(.02,true,false,'',true)
 for _=1,120 do voice:step(1/60,true,false,'',true)end
 check(mini.plays==1 and mini.IsPlaying and math.abs(mini.Volume-.75)<1e-8,'held boost never repeats and preserves full gain')
 attrs.KartOffTrack=true;parent.AssemblyLinearVelocity.X=80
 voice:step(.1,true,false,'',true)
 check(mini.IsPlaying and math.abs(mini.Volume-.75)<1e-8,'off-road active boost retains audio')
 attrs.KartOffTrack=false;parent.AssemblyLinearVelocity.X=100
 attrs.KartBoostEndReason='duration_complete';voice:step(.5,false,false,'',true)
 check(mini.IsPlaying and math.abs(mini.Volume-.75*.75)<1e-8,'flame tail fades the onset gain')
 voice:step(.02,true,false,'',true)
 check(mini.plays==1 and math.abs(mini.Volume-.75)<1e-8,'connected boost keeps original playing clip without restart')
 voice:step(.1,true,true,'',true)
 check(nitro.plays==1 and mini.PlaybackSpeed==.8 and nitro.PlaybackSpeed==1,'overlapping Nitro retains independent normal pitch')
 for _=1,120 do voice:step(1/60,true,true,'',true)end
 check(nitro.plays==1,'held Nitro never repeats')
 attrs.KartBoostEndReason='cancelled';voice:step(.01,false,false,'cancelled',true)
 check(not mini.IsPlaying and mini.Volume==0,'cancelled boost stops onset')
 voice:step(.01,true,false,'',true)
 check(mini.plays==2,'new activation after completed audio starts original clip again')
 voice:step(.01,false,false,'',false)
 check(not mini.IsPlaying and not nitro.IsPlaying,'lifecycle gate silences both voices')
 voice:destroy();voice:destroy()
 check(mini.destroyed and nitro.destroyed,'bounded voices destroyed idempotently')
 local plays=mini.plays+nitro.plays;voice:step(.1,true,true,'',true)
 check(plays==mini.plays+nitro.plays,'destroyed voice cannot resurrect')
end
attrs={};parent.AssemblyLinearVelocity.X=100
local launch=audio.createBoostAudio(parent,'Launch')
launch:step(0,false,false,'',false);launch:step(.016,true,false,'',true)
check(sounds.LaunchMiniBoostStart.plays==1 and sounds.LaunchMiniBoostStart.PlaybackSpeed==.8,'GO launch uses restored lower-pitch onset')
launch:destroy()
loaded=false
local voice=audio.createBoostAudio(parent,'Denied')
voice:step(0,false,false,'',true);voice:step(.2,true,false,'',true);voice:step(.2,true,true,'',true)
for name,s in sounds do if name:match('^Denied')then check(s.plays==0,'unloaded sounds have no wrong-cue fallback')end end
voice:destroy()
check(config.COMBAT.MissileLaunch.Asset==config.ASSETS.NITRO_START and config.COMBAT.MissileLaunch.Volume==.75,'Missile onset config remains unchanged')
print('PASS: '..checks..' original boost, 20-percent lower pitch, no turbine/repeats, fade, Nitro isolation and cleanup checks')
