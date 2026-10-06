local Builder=require(script.Parent:WaitForChild("TrackPreviewBuilder"))
local Orbit=require(script.Parent:WaitForChild("TrackDioramaOrbit"))
local Theme=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KDMUiTheme"))
local Input=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local Controller={}

function Controller.create(parent,track,canInteract)
 local data=Builder.build(track)
 local viewport=Instance.new("ViewportFrame")
 viewport.Name="TrackDiorama"
 viewport.Size=UDim2.fromScale(1,1)
 viewport.BackgroundColor3=Theme.Panel
 viewport.BackgroundTransparency=.15
 viewport.BorderSizePixel=0
 viewport.Ambient=Color3.fromRGB(180,190,200)
 viewport.LightColor=Color3.fromRGB(255,248,230)
 viewport.LightDirection=Vector3.new(-1,-1,-.5)
 viewport.Active=true;viewport.ZIndex=2
 data.world.Parent=viewport
 local camera=Instance.new("Camera");camera.Name="DioramaCamera";camera.FieldOfView=Orbit.FOV;camera.Parent=viewport;viewport.CurrentCamera=camera
 local yaw=math.rad(35+(track.PreviewRotationDegrees or 0))
 local connections={}
 local buttons={}
 local animation=nil
 local active=nil
 local startX,startY,lastX=0,0,0
 local dragging=false
 local dead=false
 local distance=1
 local function allowed() return not dead and canInteract() end
 local function render()
  camera.CFrame=Orbit.frame(data.center,yaw,distance);camera.Focus=CFrame.new(data.center)
  viewport:SetAttribute("OrbitYaw",yaw)
 end
 local function resize()
  distance=Orbit.fit(data,viewport.AbsoluteSize.X/math.max(1,viewport.AbsoluteSize.Y));render()
 end
 local function stopTween() if animation then animation:Disconnect();animation=nil end end
 local function cancelInput() active=nil;dragging=false;stopTween() end
 local function rotate(direction)
  if not allowed() then return end
  cancelInput()
  local from,target,elapsed=yaw,yaw+direction*Orbit.STEP,0
  animation=Run.RenderStepped:Connect(function(dt)
   if not allowed() then cancelInput();return end
   elapsed+=dt
   local alpha=math.min(elapsed/.2,1)
   yaw=from+(target-from)*alpha*alpha*(3-2*alpha)
   render()
   if alpha==1 then stopTween() end
  end)
 end
 for _,d in {{"OrbitLeft",utf8.char(9664),-1},{"OrbitRight",utf8.char(9654),1}} do
  local button=Instance.new("TextButton")
  button.Name,button.Text=d[1],d[2]
  button.Size=UDim2.fromOffset(44,44)
  button.AnchorPoint=Vector2.new(if d[3]<0 then 0 else 1,1)
  button.Position=UDim2.new(if d[3]<0 then 0 else 1,if d[3]<0 then 4 else -4,1,-4)
  button.BackgroundColor3,button.TextColor3,button.TextSize=Theme.Background,Theme.Selection,24
  button.Font,button.BorderSizePixel,button.ZIndex=Enum.Font.GothamBold,0,4
  -- Keep interactive GUI controls beside the ViewportFrame: its input surface
  -- owns gestures while normal sibling buttons own tap/Activated reliably.
  button.Parent=parent;table.insert(buttons,button)
  table.insert(connections,button.Activated:Connect(function() rotate(d[3]) end))
 end
 table.insert(connections,viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
 table.insert(connections,viewport.InputBegan:Connect(function(input)
  if active or not allowed() then return end
  if input.UserInputType~=Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
  stopTween();active=input;startX,startY,lastX=input.Position.X,input.Position.Y,input.Position.X;dragging=false
 end))
 table.insert(connections,Input.InputChanged:Connect(function(input)
  if not active then return end
  if not allowed() then cancelInput();return end
  if input~=active and not (active.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement) then return end
  local x,y=input.Position.X,input.Position.Y
  if not dragging then
   if math.abs(x-startX)<Orbit.THRESHOLD or math.abs(x-startX)<math.abs(y-startY) then return end
   dragging=true;lastX=startX
  end
  yaw=Orbit.drag(yaw,x-lastX);lastX=x;render()
 end))
 table.insert(connections,Input.InputEnded:Connect(function(input) if input==active then active=nil;dragging=false end end))
 table.insert(connections,Input.WindowFocusReleased:Connect(cancelInput))
 viewport.Parent=parent;resize()
 local handle={data=data,viewport=viewport,rotate=rotate,cancelInput=cancelInput}
 function handle:destroy()
  if dead then return end
  dead=true;cancelInput()
  for _,connection in connections do connection:Disconnect() end
  for _,button in buttons do button:Destroy() end
  viewport:Destroy()
 end
 return handle
end

return Controller
