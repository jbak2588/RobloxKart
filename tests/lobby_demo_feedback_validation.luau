local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local n=0
local function check(v,label)assert(v,label);n+=1 end
local config=luau.load(fs.readFile('src/shared/AudioConfig.luau'))()
local root={}
local sounds={}
local audio={getGroup=function(name)return name end}
function audio.createSound(name,id,parent,group,looped,volume,spatial)
 local s={Name=name,SoundId=id,Parent=parent,SoundGroup=group,Looped=looped,Volume=volume,spatial=spatial,plays=0}
 function s:Destroy()self.destroyed=true;self.Parent=nil end
 sounds[name]=s;return s
end
function audio.playLoop(s)if s and not s.playing then s.playing=true;s.plays+=1 end end
function audio.playOnce(s)if s then s.playing=true;s.plays+=1 end end
function audio.stop(s)if s then s.playing=false end end
function audio.createEngineLooper(primary,secondary)
 return {step=function(_,_,pitch,volume) primary.PlaybackSpeed=pitch;primary.Volume=volume;secondary.Volume=0 end}
end
local feedback=luau.load(fs.readFile('src/client/LobbyDemoFeedback.luau'),{environment={
 game={GetService=function()return {Shared={AudioConfig='config'}}end},
 script={Parent={AudioRuntime='audio'}},require=function(key)return if key=='audio'then audio else config end,
 Enum=rb.Enum,NumberRange=rb.NumberRange,
}})()
local f=feedback.new(root)
for _,s in sounds do
 check(s.Parent==root and s.spatial,'all sounds originate at moving bot')
 check(s.RollOffMode==rb.Enum.RollOffMode.InverseTapered and s.RollOffMinDistance==12 and s.RollOffMaxDistance==180,'bounded world-distance rolloff')
end
check(sounds.DemoEngineLoop.Volume<config.ENGINE.IDLE_VOLUME,'engine quiet even at startup')
check(sounds.DemoDriftLoop.PlaybackRegion==rb.NumberRange.new(5,8),'same trimmed drift region as human training')
f:update(.016,true,false)
check(sounds.DemoDriftLoop.playing and math.abs(sounds.DemoDriftLoop.Volume-config.DRIFT.MAX_VOLUME*.75*.3)<1e-8,'friction at 30 percent of human training')
f:update(.016,false,true)
check(not sounds.DemoDriftLoop.playing and sounds.DemoBoostStart.plays==1,'release stops friction and dispatches one boost cue')
for i=1,120 do f:update(.016,false,true)end
check(sounds.DemoBoostStart.plays==1,'held boost state never repeats cue')
check(sounds.DemoEngineLoop.Volume==config.ENGINE.NORMAL_VOLUME*.3,'engine stays below direct player mix')
check(sounds.DemoBoostStart.Volume==config.BOOST.START_VOLUME*.3,'boost below direct player mix')
f:update(.016,true,false);f:update(.016,false,true)
check(sounds.DemoBoostStart.plays==2,'next lap can play one new cue')
f:destroy()
for _,s in sounds do check(s.destroyed and not s.playing,'cleanup destroys and stops every sound')end
f=feedback.new(root);f:update(.016,false,true)
check(sounds.DemoBoostStart.plays==0,'late join mid-boost has no stale cue')
f:destroy()
-- Execute the exact profile constructor used by human and bot renderers.
local env={game={GetService=function()return {}end},script={Parent={BoostFlameEnvelope='envelope'}},require=function()return {}end,
 Instance={new=function(class)return {ClassName=class}end},NumberRange=rb.NumberRange,Vector2=rb.Vector2,Vector3=rb.Vector3,
 NumberSequence=rb.NumberSequence,NumberSequenceKeypoint=rb.NumberSequenceKeypoint,ColorSequence=rb.ColorSequence,Color3=rb.Color3,Enum=rb.Enum}
local exhaust=luau.load(fs.readFile('src/client/KartWorldExhaustRenderer.luau'),{environment=env})()
local smoke=exhaust.createDriftSmoke({},true)
check(smoke.Lifetime==rb.NumberRange.new(6.5,8),'shared Lobby smoke persists 6.5-8 seconds')
check(math.abs(smoke.Transparency.Keypoints[1].Value-.06)<1e-6 and smoke.Size.Keypoints[#smoke.Size.Keypoints].Value==11.5,'shared dense white smoke profile')
for _,slip in {0,5,10,18,32,45}do for _,lod in {0,.5,1}do
 check(exhaust.driftSmokeRate(slip,true,lod,true)==math.clamp(32+(slip-6)*2,0,68)*lod,'unchanged human Lobby density and LOD')
 check(exhaust.driftSmokeRate(slip,false,lod,true)==math.clamp(16+(slip-6),0,34)*lod,'unchanged race density')
 check(exhaust.driftSmokeRate(slip,true,lod,false)==0,'no new emission after release')
end end
print('PASS '..n..' shared smoke profile, soft spatial audio, event and cleanup checks')
