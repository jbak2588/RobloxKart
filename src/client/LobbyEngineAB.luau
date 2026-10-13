-- Studio-only user listening. The published/default engine remains KDM Sound.
local Run=game:GetService('RunService')
local RS=game:GetService('ReplicatedStorage')
local M={}
function M.new(body,parent)
 if not Run:IsStudio() then return nil end
 local template=RS:WaitForChild('KDMTemplateResources'):WaitForChild('EngineAudio')
 local graph=template:Clone();graph.Name='StudioEngineAB';graph.Parent=body
 local player=graph.EngineLoopPlayer;local compressor=graph.EngineCompressor;local fader=graph.EngineFader
 local output=Instance.new('AudioDeviceOutput');output.Name='ListeningOutput';output.Parent=graph
 local function wire(a,b)local w=Instance.new('Wire');w.SourceInstance=a;w.TargetInstance=b;w.Parent=graph end
 wire(player,compressor);wire(compressor,fader);wire(fader,output)
 local button=Instance.new('TextButton');button.Name='StudioEngineAB';button.Size=UDim2.fromOffset(290,44);button.Position=UDim2.fromOffset(12,66)
 button.BackgroundColor3=Color3.fromRGB(26,40,56);button.TextColor3=Color3.fromRGB(235,246,250);button.Font=Enum.Font.GothamBold;button.TextSize=13;button.Parent=parent
 local self={buggy=false}
 button.Activated:Connect(function()
  self.buggy=not self.buggy
  if self.buggy then player:Play() else player:Stop() end
 end)
 function self:update(sound,pitch,volume)
  player.PlaybackSpeed=pitch;fader.Volume=volume/math.max(player.Volume,.01)
  if sound then
   if self.buggy then sound:Stop() else if not sound.IsPlaying then sound:Play() end end
  end
  button.Text=if self.buggy then (if player.IsReady then 'ENGINE B: BUGGY • LOOP' else 'ENGINE B: LOADING / CHECK OUTPUT') else 'ENGINE A: KDM • TAP TO COMPARE'
 end
 function self:destroy()player:Stop();graph:Destroy();button:Destroy()end
 return self
end
return M
