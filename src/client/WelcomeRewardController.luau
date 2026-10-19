-- Starter guidance belongs to the nearby kart, never to Lobby arrival.
local Controller={}
function Controller.start()
 local Players=game:GetService('Players')
 local Prompts=game:GetService('ProximityPromptService')
 local Run=game:GetService('RunService')
 local Workspace=game:GetService('Workspace')
 local p=Players.LocalPlayer
 local pg=p:WaitForChild('PlayerGui')
 if pg:FindFirstChild('KDMWelcomeReward') then return end
 local gui=Instance.new('ScreenGui');gui.Name='KDMWelcomeReward';gui.DisplayOrder=22
 gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.ResetOnSpawn=false;gui.Enabled=false;gui.Parent=pg
 local root=Instance.new('Frame');root.Name='SafeRoot';root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=1;root.Active=false;root.Parent=gui
 local hint=Instance.new('Frame');hint.Name='StarterHint';hint.Size=UDim2.fromOffset(190,76)
 hint.BackgroundColor3=Color3.fromRGB(18,32,49);hint.BackgroundTransparency=.2;hint.BorderSizePixel=0;hint.Active=false;hint.Parent=root
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,8);corner.Parent=hint
 local stroke=Instance.new('UIStroke');stroke.Color=Color3.fromRGB(111,211,245);stroke.Thickness=1;stroke.Parent=hint
 local function text(name,value,y,height,size,color)
  local t=Instance.new('TextLabel');t.Name=name;t.Text=value;t.BackgroundTransparency=1
  t.Position=UDim2.fromOffset(10,y);t.Size=UDim2.new(1,-20,0,height);t.TextWrapped=true
  t.Font=Enum.Font.GothamBold;t.TextSize=size;t.TextColor3=color;t.TextXAlignment=Enum.TextXAlignment.Left;t.Parent=hint
 end
 text('Reward','EARN K$ 5,000',6,22,15,Color3.fromRGB(255,219,65))
 text('Requirement','Drive 30s + travel 300 studs.\nOne starter reward per account.',30,40,12,Color3.fromRGB(238,246,255))
 local prompt=nil;local originalOffset=nil
 local function restoreOffset()
  if prompt and prompt.Parent and originalOffset then prompt.UIOffset=originalOffset end
 end
 local function blocked()
  for _,name in {'KDMGarageShop','KDMMatchRooms'} do local g=pg:FindFirstChild(name);if g and g.Enabled then return true end end
  return p:GetAttribute('RaceState')~='GARAGE' or p:GetAttribute('HubOverlayOpen')==true
   or p:GetAttribute('KDMProfileOpen')==true or p:GetAttribute('KDMShopOpen')==true
   or p:GetAttribute('LobbyDriveActive')==true or p:GetAttribute('LobbyDrivePending')==true
   or (p:GetAttribute('KDMRoutePending')~=nil and p:GetAttribute('KDMRoutePending')~='')
 end
 local connections={}
 table.insert(connections,Prompts.PromptShown:Connect(function(shown)
  local hub=Workspace:FindFirstChild('KDMHub')
  if shown.Name~='LobbyDisplayTestDrive' or not hub or not shown:IsDescendantOf(hub) then return end
  restoreOffset();prompt=shown;originalOffset=shown.UIOffset
 end))
 table.insert(connections,Prompts.PromptHidden:Connect(function(hidden)
  if hidden==prompt then restoreOffset();prompt=nil;originalOffset=nil;gui.Enabled=false end
 end))
 table.insert(connections,Run.RenderStepped:Connect(function()
  local camera=Workspace.CurrentCamera
  if not prompt or not prompt.Parent or not prompt.Enabled or not camera
   or p:GetAttribute('KDMEconomyState')~='GUEST' or blocked() then
   gui.Enabled=false;restoreOffset();return
  end
  local anchor=prompt.Parent
  if not anchor:IsA('BasePart') then gui.Enabled=false;restoreOffset();return end
  local point,onScreen=camera:WorldToScreenPoint(anchor.Position)
  local size=root.AbsoluteSize
  if not onScreen or point.Z<=0 or size.X<220 or size.Y<120 then gui.Enabled=false;restoreOffset();return end
  local x,y=point.X-root.AbsolutePosition.X,point.Y-root.AbsolutePosition.Y
  if size.X>=440 then
   -- Move the native prompt and its explanation as one bounded row.
   local left=math.clamp(x-201,12,size.X-414)
   local top=math.clamp(y-38,8,size.Y-84)
   prompt.UIOffset=originalOffset+Vector2.new(left+100-x,top+38-y)
   hint.Position=UDim2.fromOffset(left+212,top)
  else
   prompt.UIOffset=originalOffset
   hint.Position=UDim2.fromOffset(math.clamp(x-95,12,size.X-202),math.clamp(y+64,8,size.Y-84))
  end
  gui.Enabled=true
 end))
 gui.Destroying:Connect(function()restoreOffset();for _,c in connections do c:Disconnect() end end)
end
return Controller
