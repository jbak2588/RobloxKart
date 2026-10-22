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
 function self:update(_dt,active,offTrack,speed)
  if self.sound then
   if offTrack and (speed or 0)>=6 then
    local factor=math.clamp((speed or 0)/60,0.3,1.0)
    self.sound.Volume=factor*Config.DRIFT.MAX_VOLUME*0.75
    self.sound.PlaybackSpeed=0.68
    if not self.sound.IsPlaying then self.sound.TimePosition=5 end
    Audio.playLoop(self.sound)
   elseif active then
    self.sound.Volume=Config.DRIFT.MAX_VOLUME*.75
    self.sound.PlaybackSpeed=1.0
    if not self.sound.IsPlaying then self.sound.TimePosition=5 end
    Audio.playLoop(self.sound)
   else
    Audio.stop(self.sound)
   end
  end
 end
 function self:destroy()
  if self.sound then Audio.stop(self.sound);self.sound:Destroy() end
 end
 return self
end
return Feedback
