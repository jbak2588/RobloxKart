-- Client-only next-gate guidance. Never writes gates, progress, or server objects.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Workspace=game:GetService('Workspace')
local State=require(script.Parent.RacePresentationState)
local Controller={}
local active
local function safe(part)
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
end
local function surfaceRoad(track,gate)
 local folder=track:FindFirstChild('Road');if not folder then return nil end
 local best,score
 for _,road in folder:GetChildren() do if road:IsA('BasePart') then
  local p=road.CFrame:PointToObjectSpace(gate.Position)
  local dx=math.max(0,math.abs(p.X)-road.Size.X/2);local dz=math.max(0,math.abs(p.Z)-road.Size.Z/2)
  local value=dx*dx+dz*dz+(road.Position.Y-(gate.Position.Y-8))^2
   +(1-math.abs(road.CFrame.LookVector:Dot(gate.CFrame.LookVector)))*4
  if not score or value<score then best,score=road,value end
 end end
 return best
end
local function surfaceY(road,x,z)
 local top=road.CFrame:PointToWorldSpace(Vector3.new(0,road.Size.Y/2,0));local n=road.CFrame.UpVector
 return top.Y-(n.X*(x-top.X)+n.Z*(z-top.Z))/math.max(n.Y,.1)
end
function Controller.new(player,isDriving)
 local currentGate,currentTrack,folder
 local connections={};local closed=false;local pending=false
 local function clear()
  if folder then folder:Destroy();folder=nil end;currentGate=nil;currentTrack=nil
 end
 local function update()
  if closed then return end
  local index=State.gateIndex(player:GetAttribute('RaceState'),player:GetAttribute('RaceNextCheckpoint'),player:GetAttribute('RaceCheckpointCount'))
  if not index or (isDriving and not isDriving()) or player:GetAttribute('KDMRoutePending')=='HUB_RETURN' then clear();return end
  local prototype=Workspace:FindFirstChild('Prototype');local track=prototype and prototype:FindFirstChild('TestTrack')
  local triggers=track and track:FindFirstChild('RaceTriggers');local gate
  if triggers then for _,o in triggers:GetChildren() do
   if o:IsA('BasePart') and ((index==0 and o:GetAttribute('GateType')=='StartFinish') or (index>0 and o:GetAttribute('CheckpointIndex')==index)) then gate=o;break end
  end end
  if not gate then clear();return end
  if currentGate==gate and currentTrack==track then return end
  clear()
  local road=surfaceRoad(track,gate);local resources=RS:FindFirstChild('KDMRacePresentationResources')
  if not road or not resources then return end
  folder=Instance.new('Folder');folder.Name='KDMNextCheckpoint';folder:SetAttribute('CheckpointIndex',index)
  folder:SetAttribute('OwnerUserId',player.UserId or 0)
  local width=track:GetAttribute('RoadWidth') or math.max(8,gate.Size.X-20)
  local base=gate.CFrame;local y=surfaceY(road,base.Position.X,base.Position.Z)
  base=base+Vector3.new(0,y-base.Position.Y,0)
  for _,side in {-1,1} do
   local flag=resources[if index==0 then 'FinishFlag' else 'CheckpointFlag']:Clone()
   flag.Name=if side<0 then 'LeftBanner' else 'RightBanner';flag:ScaleTo(.65)
   for _,o in flag:GetDescendants() do if o:IsA('BasePart') then safe(o) elseif o:IsA('Light') then o.Enabled=false elseif o:IsA('TextLabel') then o.AutoLocalize=false end end
   local cf,bounds=flag:GetBoundingBox();local pivot=flag:GetPivot()
   local target=base*CFrame.new(side*(width/2+3),bounds.Y/2,0)
   flag:PivotTo(target*(cf:ToObjectSpace(pivot)));flag.Parent=folder
  end
  for row=1,2 do for column=1,16 do
   local offsetX=(column-.5-8)*width/16;local offsetZ=(row-1.5)*1.5
   local pos=base:PointToWorldSpace(Vector3.new(offsetX,0,offsetZ))
   local part=Instance.new('Part');part.Name='CheckpointChecker';part.Size=Vector3.new(width/16,.025,1.5)
   part.CFrame=base*CFrame.new(offsetX,surfaceY(road,pos.X,pos.Z)-y+.065,offsetZ)
   part.Color=if (row+column)%2==0 then Color3.fromRGB(245,245,245) else Color3.fromRGB(12,14,18)
   part.Material=Enum.Material.SmoothPlastic;safe(part);part.Parent=folder
  end end
  local anchor=Instance.new('Part');anchor.Name='MarkerAnchor';anchor.Size=Vector3.one;anchor.Transparency=1
  anchor.CFrame=base*CFrame.new(0,12,0);safe(anchor);anchor.Parent=folder
  local gui=Instance.new('BillboardGui');gui.Name='CheckpointMarker';gui.Size=UDim2.fromOffset(210,115);gui.MaxDistance=350
  gui.AlwaysOnTop=true;gui.LightInfluence=0;gui.Parent=anchor
  local frame=resources.CheckpointFrame:Clone();frame.Visible=true;frame.AnchorPoint=Vector2.zero
  frame.Position=UDim2.fromScale(0,0);frame.Size=UDim2.new(1,0,0,46);frame.Parent=gui
  frame.TextLabel.Text=if index==0 then 'FINISH' else 'CHECKPOINT';frame.TextLabel.AutoLocalize=false;frame.TextLabel.TextScaled=true
  frame.ImageLabel.Position=UDim2.new(.5,0,1,8);frame.ImageLabel.Size=UDim2.fromOffset(48,60)
  folder.Parent=Workspace;currentGate,currentTrack=gate,track
 end
 local function schedule()
  if pending or closed then return end;pending=true
  task.defer(function()pending=false;update()end)
 end
 for _,key in {'RaceState','RaceNextCheckpoint','RaceCheckpointCount','RaceCurrentLap','RaceCompletedLaps','RaceSessionId','RaceResetSerial','SelectedTrackId','KDMRoutePending'} do
  table.insert(connections,player:GetAttributeChangedSignal(key):Connect(schedule))
 end
 table.insert(connections,Workspace.DescendantAdded:Connect(function(o)if o.Name=='RaceTriggers' or o:GetAttribute('RaceGate')==true then schedule()end end))
 table.insert(connections,Workspace.DescendantRemoving:Connect(function(o)if o==currentGate or o==currentTrack then clear();schedule()end end))
 local characterConnections={}
 local function character(character)
  for _,c in characterConnections do c:Disconnect()end;table.clear(characterConnections)
  local h=character and character:FindFirstChildOfClass('Humanoid')
  if h then table.insert(characterConnections,h:GetPropertyChangedSignal('SeatPart'):Connect(schedule));table.insert(characterConnections,h.Died:Connect(schedule))end
  schedule()
 end
 if player.CharacterAdded then table.insert(connections,player.CharacterAdded:Connect(character));character(player.Character)end
 local self={refresh=update}
 function self:destroy()
  closed=true;clear();for _,c in connections do c:Disconnect()end;for _,c in characterConnections do c:Disconnect()end
 end
 table.insert(connections,player.AncestryChanged:Connect(function(_,parent)if not parent then self:destroy()end end))
 update();return self
end
function Controller.start()
 if active then return end
 local player=Players.LocalPlayer
 active=Controller.new(player,function()
  local h=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
  return h and h.Health>0 and h.SeatPart and h.SeatPart:GetAttribute('PrototypeKartSeat')==true
 end)
end
function Controller.destroy()if active then active:destroy();active=nil end end
return Controller
