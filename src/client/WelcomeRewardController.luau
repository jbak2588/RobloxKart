-- Nearby native prompts own contextual guidance; never interrupt Lobby arrival.
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
 hint.BackgroundColor3=Color3.fromRGB(18,32,49);hint.BackgroundTransparency=.70;hint.BorderSizePixel=0;hint.Active=false;hint.Parent=root
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,8);corner.Parent=hint
 local stroke=Instance.new('UIStroke');stroke.Color=Color3.fromRGB(111,211,245);stroke.Thickness=1;stroke.Transparency=.85;stroke.Parent=hint
 local function text(name,value,y,height,size,color)
  local t=Instance.new('TextLabel');t.Name=name;t.Text=value;t.BackgroundTransparency=1
  t.Position=UDim2.fromOffset(10,y);t.Size=UDim2.new(1,-20,0,height);t.TextWrapped=true
  t.Font=Enum.Font.GothamBold;t.TextSize=size;t.TextColor3=color;t.TextXAlignment=Enum.TextXAlignment.Left;t.Parent=hint
 end
 text('Reward','EARN K$ 5,000',6,22,15,Color3.fromRGB(255,219,65))
 text('Requirement','Drive 30s + travel 300 studs.\nOne starter reward per account.',30,40,12,Color3.fromRGB(238,246,255))
 local descriptions={
  GARAGE='Choose your kart and color.',
  RACE='Race with players or a rookie bot.\nFinish races to earn K$.',
  TRACKS='Preview circuits and choose a track.',
 }
 local prompt=nil;local originalOffset=nil;local context=nil
 local function describe()
  local reward=hint:FindFirstChild('Reward')
  local requirement=hint:FindFirstChild('Requirement')
  reward.Text=if context=='TEST_DRIVE' then 'EARN K$ 5,000' else context
  reward.TextColor3=if context=='TEST_DRIVE' then Color3.fromRGB(255,219,65) else Color3.fromRGB(238,246,255)
  requirement.Text=if context=='TEST_DRIVE' then 'Drive 30s + travel 300 studs.\nOne starter reward per account.' else descriptions[context]
 end
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
  if not hub or not shown:IsDescendantOf(hub) then return end
  local action=if shown.Name=='HubPrompt' and shown.Parent then shown.Parent:GetAttribute('HubAction') else nil
  local nextContext=if shown.Name=='LobbyDisplayTestDrive' then 'TEST_DRIVE' elseif descriptions[action] then action else nil
  if not nextContext then return end
  restoreOffset();prompt=shown;originalOffset=shown.UIOffset;context=nextContext
  describe()
 end))
 table.insert(connections,Prompts.PromptHidden:Connect(function(hidden)
  if hidden==prompt then restoreOffset();prompt=nil;originalOffset=nil;gui.Enabled=false end
 end))
 table.insert(connections,Run.RenderStepped:Connect(function()
  local camera=Workspace.CurrentCamera
  if not prompt or not prompt.Parent or not prompt.Enabled or not camera
   or (context=='TEST_DRIVE' and p:GetAttribute('KDMEconomyState')~='GUEST') or blocked() then
   gui.Enabled=false;restoreOffset();return
  end
  local anchor=prompt.Parent
  if not anchor:IsA('BasePart') then gui.Enabled=false;restoreOffset();return end
  local point,onScreen=camera:WorldToScreenPoint(anchor.Position)
  local size=root.AbsoluteSize
  if not onScreen or point.Z<=0 or size.X<220 or size.Y<120 then gui.Enabled=false;restoreOffset();return end
  local x,y=point.X-root.AbsolutePosition.X,point.Y-root.AbsolutePosition.Y
  -- Leave Roblox's E/touch prompt in its native position. Its UI caches the
  -- offset when shown, so moving UIOffset later can separate it from the hint.
  restoreOffset()
  local obstacles={}
  local nav=pg:FindFirstChild('KDMHubNavigation')
  if nav and nav.Enabled then
   for _,name in {'Shortcuts','WalletCapsule'} do
    local item=nav:FindFirstChild(name)
    if item and item.Visible then table.insert(obstacles,item) end
   end
   local safe=nav:FindFirstChild('SafeCanvas')
   local actions=safe and safe:FindFirstChild('NextAction')
   if actions and actions.Visible then table.insert(obstacles,actions) end
  end
  local touch=pg:FindFirstChild('TouchGui')
  local controls=touch and touch:FindFirstChild('TouchControlFrame')
  local stick=controls and controls:FindFirstChild('DynamicThumbstickFrame')
  for _,item in {controls and controls:FindFirstChild('JumpButton'),stick and stick:FindFirstChild('ThumbstickStart')} do
   if item and item.Visible then table.insert(obstacles,item) end
  end
  local function clear(left,top)
   if left<12 or top<8 or left+190>size.X-12 or top+76>size.Y-8 then return false end
   for _,item in obstacles do
    local a=item.AbsolutePosition-root.AbsolutePosition;local b=item.AbsoluteSize
    if left<a.X+b.X+8 and left+190>a.X-8 and top<a.Y+b.Y+8 and top+76>a.Y-8 then return false end
   end
   return true
  end
  local candidates={Vector2.new(x+112,y-38),Vector2.new(x-302,y-38),Vector2.new(x-95,y-122),Vector2.new(x-95,y+64),Vector2.new(size.X*.5-95,y-122),Vector2.new(size.X*.5-95,y+64)}
  local position=nil
  for _,candidate in candidates do
   local clamped=Vector2.new(math.clamp(candidate.X,12,size.X-202),math.clamp(candidate.Y,8,size.Y-84))
   if clear(clamped.X,clamped.Y) then position=clamped;break end
  end
  if not position then
   -- Keep short-screen fallback bounded; the hint never captures input.
   position=Vector2.new(math.clamp(x-95,12,size.X-202),math.clamp(y+64,8,size.Y-84))
  end
  hint.Position=UDim2.fromOffset(position.X,position.Y)
  gui.Enabled=true
 end))
 gui.Destroying:Connect(function()restoreOffset();for _,c in connections do c:Disconnect() end end)
end
return Controller
