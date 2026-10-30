local Controller={}
local show
function Controller.layout(size)
 return {width=math.max(240,math.min(480,size.X-24)),height=math.max(204,math.min(260,size.Y-16))}
end
function Controller.open()
 if not show then Controller.start()end
 return if show then show() else false
end
function Controller.start()
 if show then return end
 local players=game:GetService('Players');local p=players.LocalPlayer
 if workspace:GetAttribute('KDMServerRole')~='HUB' then return end
 local remote=game:GetService('ReplicatedStorage'):WaitForChild('KDMRobuxTopUp',10)
 if not remote then return end
 local market=game:GetService('MarketplaceService');local guiService=game:GetService('GuiService')
 local pg=p:WaitForChild('PlayerGui');if pg:FindFirstChild('KDMRobuxTopUp')then return end
 local gui=Instance.new('ScreenGui');gui.Name='KDMRobuxTopUp';gui.DisplayOrder=40;gui.ResetOnSpawn=false
 gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Enabled=false;gui.Parent=pg
 local root=Instance.new('Frame');root.Name='SafeCanvas';root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=1;root.Parent=gui
 local shade=Instance.new('TextButton');shade.Name='Backdrop';shade.Text='';shade.Size=UDim2.fromScale(1,1)
 shade.BackgroundColor3=Color3.new(0,0,0);shade.BackgroundTransparency=.35;shade.Modal=true;shade.AutoButtonColor=false;shade.Parent=root
 local panel=Instance.new('Frame');panel.Name='Panel';panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5)
 panel.BackgroundColor3=Color3.fromRGB(24,36,52);panel.ZIndex=2;panel.Parent=root
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,12);corner.Parent=panel
 local function text(name,value,y,height)
  local t=Instance.new('TextLabel');t.Name=name;t.Text=value;t.Size=UDim2.new(1,-32,0,height);t.Position=UDim2.fromOffset(16,y)
  t.BackgroundTransparency=1;t.TextColor3=Color3.fromRGB(240,245,252);t.TextWrapped=true;t.Font=Enum.Font.GothamBold;t.TextSize=16;t.ZIndex=3;t.Parent=panel;return t
 end
 local title=text('Title','GET K$',8,28);title.Size=UDim2.new(1,-80,0,28);title.TextXAlignment=Enum.TextXAlignment.Left
 local wallet=text('Wallet','',36,24);wallet.TextSize=13;wallet.TextXAlignment=Enum.TextXAlignment.Left
 local status=text('Status','',0,40);status.TextSize=12;status.AnchorPoint=Vector2.new(0,1);status.Position=UDim2.new(0,16,1,-6)
 local function button(name,value,y)
  local b=Instance.new('TextButton');b.Name=name;b.Text=value;b.Size=UDim2.new(1,-32,0,44);b.Position=UDim2.fromOffset(16,y)
  b.BackgroundColor3=Color3.fromRGB(65,175,205);b.TextColor3=Color3.fromRGB(240,245,252);b.Font=Enum.Font.GothamBold
  b.TextSize=16;b.TextWrapped=true;b.ZIndex=3;b.Parent=panel
  local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,8);c.Parent=b;return b
 end
 local close=button('Close','X',8);close.Size=UDim2.fromOffset(44,44);close.Position=UDim2.new(1,-52,0,4)
 local buttons={button('Cash25000','K$ 25,000',70),button('Cash60000','K$ 60,000',122)}
 local offers={};local busy=false;local epoch=0;local currentProduct=nil;local serialAtPrompt=0
 local function eligible()
  return p:GetAttribute('RaceState')=='GARAGE' and p:GetAttribute('LobbyDriveActive')~=true and p:GetAttribute('LobbyDrivePending')~=true
   and (p:GetAttribute('KDMRoutePending')or '')=='' and p:GetAttribute('HubOverlayOpen')~=true and p:GetAttribute('KDMProfileOpen')~=true
 end
 local function layout()
  local l=Controller.layout(root.AbsoluteSize);panel.Size=UDim2.fromOffset(l.width,l.height)
  for i,b in buttons do b.Position=UDim2.fromOffset(16,60+(i-1)*48)end
 end
 local function render()
  wallet.Text='BALANCE  K$ '..tostring(p:GetAttribute('KDMWalletCash')or 0)
  for i,b in buttons do local offer=offers[i];b.Active=not busy and offer~=nil and offer.available==true
   b.TextTransparency=if b.Active then 0 else .5
  end
 end
 local function closePanel()
  gui.Enabled=false;p:SetAttribute('KDMTopUpOpen',false);epoch+=1
 end
 close.Activated:Connect(function()if not busy then closePanel()end end)
 shade.Activated:Connect(function()if not busy then closePanel()end end)
 for i,b in buttons do b.Activated:Connect(function()
  local offer=offers[i];if busy or not gui.Enabled or not b.Active or not eligible() or not offer then return end
  busy=true;currentProduct=offer.productId;serialAtPrompt=p:GetAttribute('KDMTopUpSerial')or 0
  status.Text='Complete the Roblox purchase prompt.';render()
  task.spawn(function()
   local ok,response=pcall(function()return remote:InvokeServer('PROMPT',offer.sku)end)
   if not ok or type(response)~='table' or response.status~='PROMPTED' then
    busy=false;currentProduct=nil;status.Text=if ok and type(response)=='table' and response.status=='WALLET_FULL' then 'Wallet is full.' else 'Purchase unavailable. Please try again.';render()
   end
  end)
 end)end
 market.PromptProductPurchaseFinished:Connect(function(userId,productId,purchased)
  if userId~=p.UserId or productId~=currentProduct then return end
  busy=false;currentProduct=nil
  status.Text=if (p:GetAttribute('KDMTopUpSerial')or 0)>serialAtPrompt then 'K$ added. Balance saved.' elseif purchased then 'Payment received. Waiting for saved balance...' else 'Purchase cancelled.'
  render() -- Closing a payment prompt NEVER grants currency.
 end)
 p:GetAttributeChangedSignal('KDMTopUpSerial'):Connect(function()
  status.Text='K$ added. Balance saved.';render()
 end)
 p:GetAttributeChangedSignal('KDMWalletCash'):Connect(render)
 for _,attr in {'RaceState','LobbyDriveActive','LobbyDrivePending','KDMRoutePending','HubOverlayOpen','KDMProfileOpen'}do
  p:GetAttributeChangedSignal(attr):Connect(function()if not eligible()then closePanel()end end)
 end
 root:GetPropertyChangedSignal('AbsoluteSize'):Connect(layout)
 guiService.MenuOpened:Connect(function()if not busy then closePanel()end end)
 show=function()
  local rooms=pg:FindFirstChild('KDMMatchRooms')
  if not eligible() or rooms and rooms.Enabled then return false end
  if gui.Enabled then return true end
  gui.Enabled=true;p:SetAttribute('KDMTopUpOpen',true);epoch+=1;local requestEpoch=epoch
  status.Text='Loading Robux prices...';offers={};layout();render()
  task.spawn(function()
   local ok,response=pcall(function()return remote:InvokeServer('LIST')end)
   if not gui.Enabled or epoch~=requestEpoch then return end
   if not ok or type(response)~='table' or type(response.offers)~='table' then status.Text='Store unavailable. Please try again.';return end
   for i,offer in response.offers do
    if i>2 then break end
    local loaded,info=pcall(function()return market:GetProductInfoAsync(offer.productId,Enum.InfoType.Product)end)
    if not gui.Enabled or epoch~=requestEpoch then return end
    local price=if loaded and type(info)=='table' then info.PriceInRobux else nil
    offer.available=response.canPurchase==true and type(price)=='number' and price>0 and info.IsForSale~=false
    offers[i]=offer
    buttons[i].Text='K$ '..(if offer.amount==25000 then '25,000' else '60,000')..'  ·  '..(if type(price)=='number' and price>0 then tostring(price) else tostring(offer.baseRobux))..' Robux'
   end
   status.Text=if response.status=='PREVIEW' then 'Studio preview · Purchases unavailable.' elseif response.canPurchase then 'K$ is added after payment is confirmed.' else 'Return to the Hub to purchase.'
   render()
  end)
  return true
 end
 layout();render()
end
return Controller
