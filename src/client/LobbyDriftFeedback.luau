-- Training audio only; shared exhaust renderer owns both tire trails and smoke.
local RS=game:GetService("ReplicatedStorage")
local Config=require(RS.Shared.AudioConfig)
local Audio=require(script.Parent.AudioRuntime)
local Feedback={}
function Feedback.new(body,_kart,_zone)
 local self={}
 self.sound=Audio.createSound("LobbyDriftLoop",Config.ASSETS.DRIFT_LOOP,body,Audio.getGroup("RobloxKartSFX"),true,0,true)
 if self.sound then
  self.sound.PlaybackRegionsEnabled=true;self.sound.PlaybackRegion=NumberRange.new(5,8);self.sound.LoopRegion=NumberRange.new(5,8)
 end
 function self:update(_dt,active)
  if self.sound then
   self.sound.Volume=if active then Config.DRIFT.MAX_VOLUME*.75 else 0
   if active then if not self.sound.IsPlaying then self.sound.TimePosition=5 end;Audio.playLoop(self.sound) else Audio.stop(self.sound) end
  end

 end
 function self:destroy()
  if self.sound then Audio.stop(self.sound);self.sound:Destroy() end
 end
 return self
end
return Feedback
