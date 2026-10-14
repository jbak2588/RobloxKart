-- Client-only next-gate guidance. Never writes gates, progress, or server objects.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Workspace=game:GetService('Workspace')
local RunService=game:GetService('RunService')
local State=require(script.Parent.RacePresentationState)
local Controller={}
local active
local renderSerial=0
-- SizeOffset anchors the bottom centre (pin tip) at the floating world point.
-- Scale with perspective rather than drawing the same 210px sign at any depth.
function Controller.markerMetrics(depth,viewportHeight,fov,distance)
 if depth<=0 or distance<=26 or distance>350 then return 0,0,0 end
 local focal=viewportHeight/(2*math.tan(math.rad(fov)*.5))
 local width=math.min(focal*24/depth,200,viewportHeight*.36)
 local nearAlpha=math.clamp((distance-26)/24,0,1)
 local farAlpha=math.clamp((350-distance)/100,0,1)
 return width,width*7/16,nearAlpha*farAlpha
end
function Controller.markerOverlaps(tipX,tipY,width,height,bounds)
 return bounds~=nil and tipX+width/2>bounds[1] and tipX-width/2<bounds[3]
  and tipY>bounds[2] and tipY-height<bounds[4]
end
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
 local currentGate,currentTrack,folder,markerGui,markerFrame
 local cachedSeat,cachedChassis,cachedCorners
 local connections={};local closed=false;local pending=false
 local function clear()
  if folder then folder:Destroy();folder=nil end;currentGate=nil;currentTrack=nil
  markerGui=nil;markerFrame=nil
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
  local bannerHeight=0
  for _,side in {-1,1} do
   local flag=resources[if index==0 then 'FinishFlag' else 'CheckpointFlag']:Clone()
   flag.Name=if side<0 then 'LeftBanner' else 'RightBanner';flag:ScaleTo(.65)
   for _,o in flag:GetDescendants() do if o:IsA('BasePart') then safe(o) elseif o:IsA('Light') then o.Enabled=false elseif o:IsA('TextLabel') then o.AutoLocalize=false end end
   local cf,bounds=flag:GetBoundingBox();local pivot=flag:GetPivot()
   bannerHeight=math.max(bannerHeight,bounds.Y)
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
  -- Float the pin tip between the upper portions of the original banners.
  -- Both banner sizes and the road surface determine height, including FINISH.
  anchor.CFrame=base*CFrame.new(0,bannerHeight*.8,0);safe(anchor);anchor.Parent=folder
  local gui=Instance.new('BillboardGui');gui.Name='CheckpointMarker';gui.Size=UDim2.fromOffset(120,52.5);gui.MaxDistance=350
  gui.SizeOffset=Vector2.new(0,.5);gui.StudsOffset=Vector3.zero;gui.StudsOffsetWorldSpace=Vector3.zero
  gui.AlwaysOnTop=false;gui.LightInfluence=0;gui.Enabled=false;gui.Parent=anchor
  local frame=resources.CheckpointFrame:Clone();frame.Visible=true;frame.AnchorPoint=Vector2.zero
  frame.AutomaticSize=Enum.AutomaticSize.None
  frame.Position=UDim2.fromScale(0,0);frame.Size=UDim2.fromScale(1,1);frame.Parent=gui
  for _,o in frame:GetDescendants() do
   if o:IsA('GuiObject') then o.AutomaticSize=Enum.AutomaticSize.None end
   if o:IsA('UIPadding') then o:Destroy() end
  end
  frame.TextLabel.AnchorPoint=Vector2.zero;frame.TextLabel.Position=UDim2.fromScale(0,0)
  frame.TextLabel.Size=UDim2.fromScale(1,.38)
  frame.TextLabel.Text=if index==0 then 'FINISH' else 'CHECKPOINT';frame.TextLabel.AutoLocalize=false;frame.TextLabel.TextScaled=true
  frame.ImageLabel.AnchorPoint=Vector2.new(.5,1);frame.ImageLabel.Position=UDim2.fromScale(.5,1)
  frame.ImageLabel.Size=UDim2.fromScale(.19,.55)
  markerGui,markerFrame=gui,frame
  gui:SetAttribute('MarkerBaseBackground',frame.TextLabel.BackgroundTransparency)
  gui:SetAttribute('MarkerBaseStroke',frame.TextLabel.TextStrokeTransparency)
  folder.Parent=Workspace;currentGate,currentTrack=gate,track
 end
 local function markerView()
  local camera=Workspace.CurrentCamera
  if closed or not markerGui or not camera then return end
  local character=player.Character;local humanoid=character and character:FindFirstChildOfClass('Humanoid')
  local seat=humanoid and humanoid.SeatPart
  if seat~=cachedSeat then
   cachedSeat=seat;cachedChassis=nil;cachedCorners=nil
   local kart=seat and seat.Parent
   local body=kart and kart:FindFirstChild('Chassis')
   if body and kart:IsA('Model') then
    cachedChassis=body;cachedCorners={}
    local cf,size=kart:GetBoundingBox();local half=size*.5
    for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do
     table.insert(cachedCorners,body.CFrame:PointToObjectSpace(cf:PointToWorldSpace(Vector3.new(x*half.X,y*half.Y,z*half.Z))))
    end end end
   end
  end
  local anchor=markerGui.Parent.Position
  local point,onScreen=camera:WorldToViewportPoint(anchor)
  local origin=cachedChassis and cachedChassis.Position or camera.CFrame.Position
  local width,height,alpha=Controller.markerMetrics(point.Z,camera.ViewportSize.Y,camera.FieldOfView,(origin-anchor).Magnitude)
  local bounds
  local function protect(worldPoint)
   local v=camera:WorldToViewportPoint(worldPoint)
   if v.Z<=0 then return end
   if not bounds then bounds={v.X-6,v.Y-6,v.X+6,v.Y+6}
   else bounds[1]=math.min(bounds[1],v.X-6);bounds[2]=math.min(bounds[2],v.Y-6)
    bounds[3]=math.max(bounds[3],v.X+6);bounds[4]=math.max(bounds[4],v.Y+6) end
  end
  if cachedChassis and cachedChassis.Parent then
   for _,corner in cachedCorners do protect(cachedChassis.CFrame:PointToWorldSpace(corner)) end
   local head=character and character:FindFirstChild('Head')
   if head and head:IsA('BasePart') then
    local half=head.Size*.5
    for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do protect(head.CFrame:PointToWorldSpace(Vector3.new(x*half.X,y*half.Y,z*half.Z)))end end end
   end
  end
  if not onScreen or Controller.markerOverlaps(point.X,point.Y,width,height,bounds) then alpha=0 end
  markerGui.Enabled=alpha>0
  if alpha<=0 then return end
  local pixels=math.floor(width+.5)
  if markerGui.Size.X.Offset~=pixels then markerGui.Size=UDim2.fromOffset(pixels,pixels*7/16)end
  markerFrame.TextLabel.TextTransparency=1-alpha
  markerFrame.TextLabel.TextStrokeTransparency=1-alpha*(1-markerGui:GetAttribute('MarkerBaseStroke'))
  markerFrame.TextLabel.BackgroundTransparency=1-alpha*(1-markerGui:GetAttribute('MarkerBaseBackground'))
  markerFrame.ImageLabel.ImageTransparency=1-alpha
 end
 renderSerial+=1
 local renderName='KDMCheckpointMarker'..renderSerial
 RunService:BindToRenderStep(renderName,Enum.RenderPriority.Camera.Value+3,markerView)
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
  local function attach(h)
   table.insert(characterConnections,h:GetPropertyChangedSignal('SeatPart'):Connect(schedule))
   table.insert(characterConnections,h.Died:Connect(schedule));schedule()
  end
  local h=character and character:FindFirstChildOfClass('Humanoid')
  if h then attach(h)
  elseif character then table.insert(characterConnections,character.ChildAdded:Connect(function(o)
   if o:IsA('Humanoid') then attach(o) end
  end)) end
  schedule()
 end
 if player.CharacterAdded then table.insert(connections,player.CharacterAdded:Connect(character));character(player.Character)end
 local self={refresh=update}
 function self:destroy()
  closed=true;RunService:UnbindFromRenderStep(renderName);clear();for _,c in connections do c:Disconnect()end;for _,c in characterConnections do c:Disconnect()end
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
