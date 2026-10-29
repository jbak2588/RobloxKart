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
 local cells={};local lastSerial=-1;local messageUntil=0;local showing=false;local destroyed=false
 local info=Instance.new('TextLabel');info.Name='PracticeFeedback';info.BackgroundColor3=Color3.fromRGB(16,25,35);info.BackgroundTransparency=.15
 info.TextColor3=Color3.fromRGB(65,225,245);info.Font=Enum.Font.GothamBold;info.TextSize=12;info.TextXAlignment=Enum.TextXAlignment.Left
 info.BorderSizePixel=0;info.TextTruncate=Enum.TextTruncate.AtEnd;info.Parent=canvas
 local nitroBar=if Mobile.nitroBar then Mobile.nitroBar(info)else nil
 local function use(id)
  if not canvas.Parent.Enabled or not showing or not canUse()or GuiService.MenuIsOpen or UIS:GetFocusedTextBox()then return end
  remote:FireServer('UseItem',player:GetAttribute('LobbyDriveGeneration'),id)
 end
 for _,id in Policy.Items do
  local b=Instance.new('TextButton');b.Name=id;b.Text='';b.BorderSizePixel=0;b.BackgroundColor3=Color3.fromRGB(19,39,54);b.Parent=scroll
  local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,6);corner.Parent=b
  local border=Mobile.stroke(b,1);border.Color=Color3.new(1,1,1);border.Transparency=.35;border.Enabled=false
  local icon=Icon.new(b,id,cache,Mobile)
  local caption=Instance.new('TextLabel');caption.Name='Caption';caption.BackgroundColor3=Color3.fromRGB(9,20,30);caption.BackgroundTransparency=.1
  caption.Position=UDim2.new(0,0,1,-14);caption.Size=UDim2.new(1,0,0,14);caption.Font=Enum.Font.GothamBold;caption.TextSize=10;caption.TextColor3=Color3.new(1,1,1);caption.BorderSizePixel=0;caption.ZIndex=5;caption.Parent=b
  b.Activated:Connect(function()use(id)end);table.insert(cells,{id=id,button=b,icon=icon,caption=caption,border=border})
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
  local v=drive.controlsV1
  if v then
   local i=v.items;l.x=i.x;l.y=i.top;l.width=i.width;l.height=i.secondTop-i.top+i.slot;l.content=i.width;l.cell=i.slot
   l.messageY=i.progressTop;l.messageHeight=i.progressHeight
  end
  showing=active;scroll.Visible=active and not v;info.Visible=active
  scroll.ScrollingEnabled=not v;scroll.Active=not v
  scroll.Position=UDim2.fromOffset(l.x,l.y);scroll.Size=UDim2.fromOffset(l.width,l.height)
  scroll.CanvasSize=UDim2.fromOffset(l.content,l.height)
  info.Position=UDim2.fromOffset(if v then v.items.progressX else l.x,l.messageY);info.Size=UDim2.fromOffset(if v then v.items.progressWidth else l.width,l.messageHeight);info.TextSize=if l.compact then 10 else 12
  info.BackgroundTransparency=if v then 1 else .15
  local now=Workspace:GetServerTimeNow()
  for _,c in cells do
   local x,y=Layout.itemPosition(c.id,l.cell)
   if v then
    local index=table.find({'Smoke','Slick','Thunder','Missile','Shield','Nitro'},c.id)-1
    local row=math.floor(index/v.items.columns)
    x=(index%v.items.columns)*(l.cell+6)+(if row==1 then v.items.secondX-v.items.x else 0);y=if row==1 then v.items.secondTop-v.items.top else 0
   end
   local challenge=player:GetAttribute('ParkOvertakeActive')==true
   local available=not challenge or c.id=='Nitro'or c.id=='Shield'
   c.button.Parent=if v then canvas else scroll;c.button.Visible=active and available
   c.button.Position=UDim2.fromOffset(x+(if v then l.x else 0),y+(if v then l.y else 0));c.button.Size=UDim2.fromOffset(l.cell,l.cell)
   c.button.BackgroundTransparency=if v then .52 else 0
   if v then Mobile.styleItem(c.button)end
   c.border.Enabled=false
   c.caption.BackgroundTransparency=if v then 1 else .1
   local count=player:GetAttribute('LobbyCharge'..c.id)or 0
   local wait=math.max(0,(player:GetAttribute('LobbyReadyAt'..c.id)or 0)-now)
   c.icon:update(true,count,false);c.button.Active=count>0 and available
   if v then
    c.caption.AnchorPoint=Vector2.new(1,1);c.caption.Position=UDim2.new(1,-2,1,-2);c.caption.Size=UDim2.fromOffset(18,18)
    c.caption.TextSize=14;c.caption.TextStrokeColor3=Color3.fromRGB(9,20,30);c.caption.TextStrokeTransparency=.2
    c.caption.Text=tostring(count)
   else
    c.caption.AnchorPoint=Vector2.zero;c.caption.Position=UDim2.new(0,0,1,-14);c.caption.Size=UDim2.new(1,0,0,14)
    c.caption.TextSize=10;c.caption.TextStrokeTransparency=1
    c.caption.Text=if wait>0 then c.id:upper()..' '..math.ceil(wait)..'s'else c.id:upper()..' '..count
   end
  end
  local serial=player:GetAttribute('LobbyPracticeMessageSerial')or 0
  if serial~=lastSerial then lastSerial=serial;messageUntil=now+1.4 end
  local incoming=(player:GetAttribute('LobbyMissileIncomingCount')or 0)+(player:GetAttribute('LobbyThunderIncomingCount')or 0)
  local progress=player:GetAttribute('LobbyBonusProgress')or 0
  if nitroBar then nitroBar:update(progress,3,v~=nil)end
  local state=if kart and kart:GetAttribute('LobbyDriftReady')then 'BOOST READY • RELEASE'elseif kart and kart:GetAttribute('KartBoosting')then 'MINI BOOST'else 'NITRO '..(player:GetAttribute('LobbyChargeNitro')or 0)..' • BOOST '..progress..'/3'..(if player:GetAttribute('LobbyBonusPending')then ' PENDING'else '')
  if v then state='NITRO CHARGE '..progress..'/3'..(if player:GetAttribute('LobbyBonusPending')then ' PENDING'else '');info.TextYAlignment=Enum.TextYAlignment.Top;info.TextXAlignment=Enum.TextXAlignment.Left end
  local message=player:GetAttribute('LobbyPracticeMessage')or ''
  info.Text=state -- CombatFeedbackView exclusively owns every event message in the top band.
  return l
 end
 function self:destroy()
  if destroyed then return end;destroyed=true;showing=false
  input:Disconnect();cache:destroy()
  for _,c in cells do c.button:Destroy()end
  scroll:Destroy();info:Destroy()
 end
 canvas.Destroying:Connect(function()self:destroy()end)
 return self
end
return View
