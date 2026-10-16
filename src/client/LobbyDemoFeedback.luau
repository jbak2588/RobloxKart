-- Each connected client hears the shared bot at its world position. Existing
-- player audio settings/assets stay authoritative; ambient output is 30% volume.
local RS=game:GetService("ReplicatedStorage")
local Config=require(RS.Shared.AudioConfig)
local Audio=require(script.Parent.AudioRuntime)
local Feedback={}
Feedback.VolumeScale=.3
Feedback.MinDistance=12
Feedback.MaxDistance=180

function Feedback.new(root)
 local sounds={}
 local function sound(name,id,looped,volume,group)
  local s=Audio.createSound(name,id,root,Audio.getGroup(group),looped,volume,true)
  if s then
   s.RollOffMode=Enum.RollOffMode.InverseTapered
   s.RollOffMinDistance=Feedback.MinDistance;s.RollOffMaxDistance=Feedback.MaxDistance
   table.insert(sounds,s)
  end
  return s
 end
 local engine=sound("DemoEngineLoop",Config.ASSETS.ENGINE_LOOP,true,Config.ENGINE.NORMAL_VOLUME*Feedback.VolumeScale,"RobloxKartEngine")
 local secondary=sound("DemoEngineLoopB",Config.ASSETS.ENGINE_LOOP,true,0,"RobloxKartEngine")
 if engine then engine.PlaybackSpeed=Config.ENGINE.NORMAL_PLAYBACK_SPEED end
 if secondary then secondary.PlaybackSpeed=Config.ENGINE.NORMAL_PLAYBACK_SPEED*Config.ENGINE.SECONDARY_DETUNE end
 local looper=Audio.createEngineLooper(engine,secondary)
 Audio.playLoop(engine)
 looper:step(0,Config.ENGINE.NORMAL_PLAYBACK_SPEED,Config.ENGINE.NORMAL_VOLUME*Feedback.VolumeScale,1)
 local drift=sound("DemoDriftLoop",Config.ASSETS.DRIFT_LOOP,true,0,"RobloxKartSFX")
 if drift then
  drift.PlaybackRegionsEnabled=true;drift.PlaybackRegion=NumberRange.new(5,8);drift.LoopRegion=NumberRange.new(5,8)
 end
 local boost=sound("DemoBoostStart",Config.ASSETS.BOOST_START,false,Config.BOOST.START_VOLUME*Feedback.VolumeScale,"RobloxKartSFX")
 local previousBoost
 local self={}
 function self:update(dt,drifting,boosting)
  looper:step(dt,Config.ENGINE.NORMAL_PLAYBACK_SPEED+(if boosting then Config.ENGINE.BOOST_PLAYBACK_BONUS else 0),
   Config.ENGINE.NORMAL_VOLUME*Feedback.VolumeScale,math.clamp(dt*Config.ENGINE.RESPONSE,0,1))
  if drift then
   drift.Volume=if drifting then Config.DRIFT.MAX_VOLUME*.75*Feedback.VolumeScale else 0
   if drifting then Audio.playLoop(drift) else Audio.stop(drift) end
  end
  -- A joining client does not replay a boost that already began before arrival.
  if boosting and previousBoost==false then Audio.playOnce(boost) end
  previousBoost=boosting
 end
 function self:destroy()
  for _,s in sounds do Audio.stop(s);s:Destroy() end
 end
 return self
end
return Feedback
