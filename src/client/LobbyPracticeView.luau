local RS=game:GetService('ReplicatedStorage')
local Workspace=game:GetService('Workspace')
local UIS=game:GetService('UserInputService')
local GuiService=game:GetService('GuiService')
local Policy=require(RS.Shared.LobbyPracticePolicy)
local Layout=require(RS.Shared.LobbyPracticeLayout)
local Icon=require(script.Parent.KDMItemIconView)
local Mobile=require(script.Parent.MobileControlView)
local CombatFeedback=require(script.Parent.CombatFeedbackView)
local View={}
function View.new(canvas,player,remote,canUse)
 local scroll=Instance.new('ScrollingFrame');scroll.Name='PracticeItems';scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0
 scroll.ScrollingDirection=Enum.ScrollingDirection.X;scroll.ScrollBarThickness=3;scroll.Parent=canvas
 local cache=Icon.cache(game:GetService('ContentProvider'),task)
 local cells={};local lastSerial=-1;local messageUntil=0
 local info=Instance.new('TextLabel');info.Name='PracticeFeedback';info.BackgroundColor3=Color3.fromRGB(16,25,35);info.BackgroundTransparency=.15
 info.TextColor3=Color3.fromRGB(65,225,245);info.Font=Enum.Font.GothamBold;info.TextSize=12;info.TextXAlignment=Enum.TextXAlignment.Left
 info.BorderSizePixel=0;info.TextTruncate=Enum.TextTruncate.AtEnd;info.Parent=canvas
 local function use(id)
  if not canvas.Parent.Enabled or not scroll.Visible or not canUse()or GuiService.MenuIsOpen or UIS:GetFocusedTextBox()then return end
  remote:FireServer('UseItem',player:GetAttribute('LobbyDriveGeneration'),id)
 end
 for _,id in Policy.Items do
  local b=Instance.new('TextButton');b.Name=id;b.Text='';b.BorderSizePixel=0;b.BackgroundColor3=Color3.fromRGB(19,39,54);b.Parent=scroll
  local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,6);corner.Parent=b
  local icon=Icon.new(b,id,cache,Mobile)
  local caption=Instance.new('TextLabel');caption.Name='Caption';caption.BackgroundColor3=Color3.fromRGB(9,20,30);caption.BackgroundTransparency=.1
  caption.Position=UDim2.new(0,0,1,-14);caption.Size=UDim2.new(1,0,0,14);caption.Font=Enum.Font.GothamBold;caption.TextSize=10;caption.TextColor3=Color3.new(1,1,1);caption.BorderSizePixel=0;caption.ZIndex=5;caption.Parent=b
  b.Activated:Connect(function()use(id)end);table.insert(cells,{id=id,button=b,icon=icon,caption=caption})
 end
 cache:start(function()end)
 -- Keyboard clicks are direct in practice; the race's 1-4/Q bindings remain untouched.
 local keys={N='Nitro',Z='Slick',X='Shield',C='Missile',V='Smoke',B='Thunder'}
 local input=UIS.InputBegan:Connect(function(key,processed)
  if not processed then local id=keys[key.KeyCode.Name];if id then use(id)end end
 end)
 local self={}
 function self:update(active,drive,walletBottom,kart)
  local l=Layout.compute(canvas.AbsoluteSize,drive,walletBottom)
  scroll.Visible=active;info.Visible=active
  scroll.Position=UDim2.fromOffset(l.x,l.y);scroll.Size=UDim2.fromOffset(l.width,l.height)
  scroll.CanvasSize=UDim2.fromOffset(l.content,l.height)
  info.Position=UDim2.fromOffset(l.x,l.messageY);info.Size=UDim2.fromOffset(l.width,l.messageHeight);info.TextSize=if l.compact then 10 else 12
  local now=Workspace:GetServerTimeNow()
  for _,c in cells do
   local x,y=Layout.itemPosition(c.id,l.cell)
   c.button.Position=UDim2.fromOffset(x,y);c.button.Size=UDim2.fromOffset(l.cell,l.cell)
   local count=player:GetAttribute('LobbyCharge'..c.id)or 0
   local wait=math.max(0,(player:GetAttribute('LobbyReadyAt'..c.id)or 0)-now)
   c.icon:update(true,count,false);c.button.Active=count>0
   c.caption.Text=if wait>0 then c.id:upper()..' '..math.ceil(wait)..'s'else c.id:upper()..' '..count
  end
  local serial=player:GetAttribute('LobbyPracticeMessageSerial')or 0
  if serial~=lastSerial then lastSerial=serial;messageUntil=now+1.4 end
  local incoming=(player:GetAttribute('LobbyMissileIncomingCount')or 0)+(player:GetAttribute('LobbyThunderIncomingCount')or 0)
  local progress=player:GetAttribute('LobbyBonusProgress')or 0
  local state=if kart and kart:GetAttribute('LobbyDriftReady')then 'BOOST READY • RELEASE'elseif kart and kart:GetAttribute('KartBoosting')then 'MINI BOOST'else 'NITRO '..(player:GetAttribute('LobbyChargeNitro')or 0)..' • BOOST '..progress..'/3'..(if player:GetAttribute('LobbyBonusPending')then ' PENDING'else '')
  local message=player:GetAttribute('LobbyPracticeMessage')or ''
  info.Text=if incoming>0 then 'INCOMING! • SHIELD'elseif now<messageUntil and not CombatFeedback.isPracticeResult(message) then message else state
  return l
 end
 function self:destroy()input:Disconnect();cache:destroy();scroll:Destroy();info:Destroy()end
 canvas.Destroying:Connect(function()self:destroy()end)
 return self
end
return View
