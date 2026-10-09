-- Lobby-only cosmetic skid feedback; no charge/boost/race state ownership.
local Workspace=game:GetService("Workspace")
local RS=game:GetService("ReplicatedStorage")
local Config=require(RS.Shared.AudioConfig)
local Audio=require(script.Parent.AudioRuntime)
local Feedback={}
function Feedback.new(body,kart,zone)
 local self={marks={},previous={},clock=0,index=0,body=body,wheels={},zone=zone}
 for _,part in kart:GetDescendants() do
  if part:IsA("BasePart") and part:GetAttribute("VisualMotionRole")=="RearWheel" then table.insert(self.wheels,part) end
 end
 self.folder=Instance.new("Folder");self.folder.Name="LobbySkidMarks";self.folder.Parent=Workspace
 self.sound=Audio.createSound("LobbyDriftLoop",Config.ASSETS.DRIFT_LOOP,body,Audio.getGroup("RobloxKartSFX"),true,0,true)
 if self.sound then
  self.sound.PlaybackRegionsEnabled=true;self.sound.PlaybackRegion=NumberRange.new(5,8);self.sound.LoopRegion=NumberRange.new(5,8)
 end
 self.params=RaycastParams.new();self.params.FilterType=Enum.RaycastFilterType.Include;self.params.FilterDescendantsInstances={zone:FindFirstChild("LobbyFrontSmoothFloor")}
 function self:update(dt,active)
  if self.sound then
   self.sound.Volume=if active then Config.DRIFT.MAX_VOLUME*.75 else 0
   if active then Audio.playLoop(self.sound) else Audio.stop(self.sound) end
  end
  self.clock+=dt;if self.clock<.08 then return end;self.clock=0
  local now=os.clock()
  for _,mark in self.marks do if now>(mark:GetAttribute("Expires") or 0) then mark.Transparency=1 end end
  if not active then table.clear(self.previous);return end
  for i,wheel in self.wheels do
   local hit=Workspace:Raycast(wheel.Position+Vector3.new(0,3,0),Vector3.new(0,-10,0),self.params)
   local point=hit and hit.Position+Vector3.new(0,.025,0)
   local last=self.previous[i];self.previous[i]=point
   if point and last then
    local distance=(point-last).Magnitude
    if distance>.1 and distance<12 then
     self.index=self.index%96+1;local mark=self.marks[self.index]
     if not mark then
      mark=Instance.new("Part");mark.Name="LobbySkidMark";mark.Anchored=true;mark.CanCollide=false;mark.CanTouch=false;mark.CanQuery=false;mark.CastShadow=false
      mark.Material=Enum.Material.SmoothPlastic;mark.Color=Color3.fromRGB(15,16,18);mark.Parent=self.folder;self.marks[self.index]=mark
     end
     mark.Size=Vector3.new(.45,.02,distance+.08);mark.CFrame=CFrame.lookAt((point+last)/2,point);mark.Transparency=.15;mark:SetAttribute("Expires",now+4)
    end
   end
  end
 end
 function self:destroy()
  if self.sound then Audio.stop(self.sound);self.sound:Destroy() end
  self.folder:Destroy();table.clear(self.marks);table.clear(self.previous)
 end
 return self
end
return Feedback
