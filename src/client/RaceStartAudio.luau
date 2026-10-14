-- Only the original one-shot player is imported. No template race scripts or bus.
local RS=game:GetService('ReplicatedStorage')
local SoundService=game:GetService('SoundService')
local M={}
function M.new()
 local resources=RS:FindFirstChild('KDMRacePresentationResources')
 local source=resources and resources:FindFirstChild('StartPlayer')
 if not source then return nil end
 local folder=Instance.new('Folder');folder.Name='KDMRaceStartAudio';folder.Parent=SoundService
 local player=source:Clone();player.Parent=folder;player.Looping=false;player.AutoPlay=false
 local output=Instance.new('AudioDeviceOutput');output.Parent=folder
 local wire=Instance.new('Wire');wire.SourceInstance=player;wire.TargetInstance=output;wire.Parent=folder
 local self={player=player}
 function self:play()
  if not player.IsReady or player.TimeLength<=0 then return false end
  return pcall(function()player:Stop();player.TimePosition=0;player:Play()end)
 end
 function self:stop()player:Stop()end
 function self:destroy()player:Stop();folder:Destroy()end
 return self
end
return M
