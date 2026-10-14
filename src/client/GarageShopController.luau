local Controller={}
local openShop
function Controller.open()if openShop then openShop()end end
function Controller.start()
 if workspace:GetAttribute('KDMServerRole')~='HUB' then return end
 local Players,RS=game:GetService('Players'),game:GetService('ReplicatedStorage')
 local p=Players.LocalPlayer;local remote=RS:WaitForChild('KDMShop',10);if not remote then return end
 local Shared=RS.Shared;local C=require(Shared.KDMShopCatalog);local Karts=require(Shared.KartCatalog)
 local Factory=require(Shared.KartVisualFactory);local Framing=require(Shared.KartPreviewFraming)
 local Icons=require(script.Parent.KDMIconCatalog);local Layout=require(script.Parent.ShopLayout)
 local Garage=require(script.Parent.GarageUiController);local Http=game:GetService('HttpService')
 local Market=game:GetService('MarketplaceService')
 local gui=Instance.new('ScreenGui');gui.Name='KDMGarageShop';gui.ResetOnSpawn=false;gui.DisplayOrder=35
 gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Enabled=false;gui.Parent=p:WaitForChild('PlayerGui')
 local root=Instance.new('Frame');root.Name='SafeRoot';root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=1;root.Parent=gui
 local panel=Instance.new('Frame');panel.Name='Shop';panel.BackgroundColor3=Color3.fromRGB(10,20,34);panel.Active=true;panel.Parent=root
 local function label(parent,name,text,y,height)
  local t=Instance.new('TextLabel');t.Name=name;t.Text=text;t.Position=UDim2.fromOffset(8,y);t.Size=UDim2.new(1,-16,0,height or 40)
  t.TextColor3=Color3.fromRGB(235,246,255);t.BackgroundTransparency=1;t.TextWrapped=true;t.Font=Enum.Font.GothamBold;t.TextSize=14;t.Parent=parent;return t
 end
 local function button(parent,name,text,y)
  local b=Instance.new('TextButton');b.Name=name;b.Text=text;b.Position=UDim2.fromOffset(8,y);b.Size=UDim2.new(1,-16,0,44)
  b.BackgroundColor3=Color3.fromRGB(25,49,68);b.TextColor3=Color3.new(1,1,1);b.Font=Enum.Font.GothamBold;b.TextSize=14;b.Parent=parent;return b
 end
 local title=label(panel,'Wallet','GARAGE SHOP · K$ --',0,44);title.TextXAlignment=Enum.TextXAlignment.Left
 local close=button(panel,'Close','×',0);close.Size=UDim2.fromOffset(44,44);close.AnchorPoint=Vector2.new(1,0)
 local tabs={};for _,name in {'WINGS','RACE ITEMS','MY INVENTORY'}do tabs[name]=button(panel,name,name,56)end
 local body=Instance.new('ScrollingFrame');body.Name='Products';body.BackgroundTransparency=1;body.BorderSizePixel=0
 body.ScrollBarThickness=6;body.CanvasSize=UDim2.new();body.Parent=panel
 body.Active=true;body.ScrollingDirection=Enum.ScrollingDirection.Y
 local list=Instance.new('UIListLayout');list.Padding=UDim.new(0,8);list.SortOrder=Enum.SortOrder.LayoutOrder;list.Parent=body
 list:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()body.CanvasSize=UDim2.fromOffset(0,list.AbsoluteContentSize.Y)end)
 -- Own only a shop-list touch. A dragged purchase button must never activate.
 local inputService=game:GetService('UserInputService')
 local scrollTouch,scrollStart,scrollOrigin=nil,0,0
 local draggedAt=-math.huge
 body.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.Touch and not scrollTouch then
   scrollTouch=input;scrollStart=input.Position.Y;scrollOrigin=body.CanvasPosition.Y
  end
 end)
 inputService.InputChanged:Connect(function(input)
  if input~=scrollTouch or not gui.Enabled then return end
  local delta=scrollStart-input.Position.Y
  if math.abs(delta)>8 then
   draggedAt=os.clock()
   body.CanvasPosition=Vector2.new(0,math.clamp(scrollOrigin+delta,0,math.max(0,list.AbsoluteContentSize.Y-body.AbsoluteWindowSize.Y)))
  end
 end)
 inputService.InputEnded:Connect(function(input)if input==scrollTouch then scrollTouch=nil end end)
 local status=label(panel,'Status','',0,40)
 local confirmation=Instance.new('Frame');confirmation.Name='PurchaseConfirmation';confirmation.AnchorPoint=Vector2.new(.5,.5)
 confirmation.Position=UDim2.fromScale(.5,.5);confirmation.BackgroundColor3=Color3.fromRGB(16,33,48);confirmation.Visible=false;confirmation.ZIndex=10;confirmation.Parent=root
 local confirmText=label(confirmation,'Description','',12,80);confirmText.ZIndex=11
 local yes=button(confirmation,'Confirm','CONFIRM',116);yes.ZIndex=11
 local no=button(confirmation,'Cancel','CANCEL',116);no.ZIndex=11
 local data={counts={},canPurchase=false};local busy=false;local pending=nil;local epoch=0;local tab='WINGS'
 local previewWing=true;local variants={};local colorIndex=1;local preview=nil;local viewport=nil;local camera=nil
 local passPrice=nil;local confirmAction=nil;local restoreGarage=false
 for _,id in Karts.Order do if Karts.Entries[id].VisualModelName=='KDMV2' then table.insert(variants,id)end end
 local function fitPreview()
  if preview and viewport and camera then
   local cf=Framing.fit(preview,viewport.AbsoluteSize.X/math.max(1,viewport.AbsoluteSize.Y),camera.FieldOfView,true)
   if cf then camera.CFrame=cf end
  end
 end
 local function clearCards()
  scrollTouch=nil
  preview,viewport,camera=nil,nil,nil
  for _,o in body:GetChildren()do if o~=list then o:Destroy()end end
  body.CanvasPosition=Vector2.zero
 end
 local function card(name,height)
  local f=Instance.new('Frame');f.Name=name;f.Size=UDim2.new(1,-8,0,height);f.BackgroundColor3=Color3.fromRGB(17,31,45);f.Parent=body;return f
 end
 local render,request
 local messages={SAVE_UNCONFIRMED='Save not confirmed. Retry the same purchase.',INSUFFICIENT_FUNDS='Not enough K$.',ALREADY_OWNED='Wing already owned.',
  ACCESS_BLOCKED='Shop preview · purchases unavailable for this account.',RATE_LIMITED='Please wait, then retry.',STOCK_FULL='Inventory is full.',HUB_REQUIRED='Return to the Garage.'}
 local function confirm(action,item,text,value)
  if busy or pending then status.Text='Finish or retry the pending purchase first.';return end
  confirmAction={action=action,item=item,value=value};confirmText.Text=text;confirmation.Visible=true
 end
 request=function(action,item,value)
  if busy then return end
  if pending and (pending.action~=action or pending.item~=item or pending.value~=value) then status.Text='Retry the pending purchase first.';return end
  if action~='PROFILE' and not pending then pending={action=action,item=item,value=value,id=Http:GenerateGUID(false)}end
  local op=pending;busy=true;epoch+=1;local current=epoch;status.Text=if action=='PROFILE' then 'Loading inventory...' else 'Saving...'
  task.delay(12,function()if current==epoch and busy then busy=false;status.Text='Save not confirmed. Retry the same purchase.';render()end end)
  task.spawn(function()
   local ok,r=pcall(function()return remote:InvokeServer(action,item,if op then op.id else nil,value)end)
   if current~=epoch then return end
   busy=false
   if ok and type(r)=='table' and r.status=='FOUND' then
    for key,v in r do data[key]=v end
    if action=='PROFILE' or r.purchaseState=='SAVE_CONFIRMED' then
     if r.purchaseState=='SAVE_CONFIRMED' then pending=nil;status.Text=if action=='BUY_ITEM' or action=='BUY_WING' then 'PURCHASE SUCCESS · SAVE CONFIRMED' else 'ACCOUNT SAVED' else status.Text=''end
    end
   else
    local code=if ok and type(r)=='table' then r.status else 'SAVE_UNCONFIRMED'
    status.Text=messages[code] or 'Account unavailable. Please retry.'
    if code~='SAVE_UNCONFIRMED' and code~='RATE_LIMITED' then pending=nil end
   end
   if data.passAvailable and data.passId and data.passId>0 then
    local priceOK,info=pcall(function()return Market:GetProductInfoAsync(data.passId,Enum.InfoType.GamePass)end)
    passPrice=if priceOK and info.IsForSale and type(info.PriceInRobux)=='number' then info.PriceInRobux else nil
   end
   render()
  end)
 end
 local function buyButton(parent,name,text,y,action,item,value)
  local b=button(parent,name,text,y);b.Active=data.canPurchase and not busy and not pending
  b.TextTransparency=if b.Active then 0 else .5
  b.Activated:Connect(function()if b.Active and os.clock()-draggedAt>.15 then
   local prompt=if action=='SET_AUTO_REFILL' then (if value then 'Enable automatic voucher refills?\nUses owned stock for empty active slots, max 2 per race.' else 'Turn automatic voucher refills OFF?')
    elseif action=='EQUIP_WING' then text..' your owned Wing?' else text..'\nConfirm this purchase?'
   confirm(action,item,prompt,value)
  end end);return b
 end
 render=function()
  title.Text='GARAGE SHOP · K$ '..tostring(data.cash or p:GetAttribute('KDMWalletCash') or '--')..(if root.AbsoluteSize.Y<260 and status.Text~='' then '\n'..status.Text else '')
  if not gui.Enabled then return end
  clearCards();for name,b in tabs do b.BackgroundColor3=if name==tab then Color3.fromRGB(20,95,122) else Color3.fromRGB(25,49,68)end
  if tab=='WINGS' then
   local h=Layout.forSize(root.AbsoluteSize).previewHeight
   local wide=root.AbsoluteSize.X>=600 and root.AbsoluteSize.X>root.AbsoluteSize.Y
   local f=card('WingProduct',if wide then math.max(h,148)+68 else h+282)
   local controls=f
   if wide then
    controls=Instance.new('Frame');controls.Name='WingActions';controls.Position=UDim2.new(.43,0,0,4);controls.Size=UDim2.new(.57,0,0,148);controls.BackgroundTransparency=1;controls.Parent=f
   end
   viewport=Instance.new('ViewportFrame');viewport.Name='ActualWingPreview';viewport.Size=UDim2.new(1,-16,0,h);viewport.Position=UDim2.fromOffset(8,4)
   if wide then viewport.Size=UDim2.new(.43,-16,0,h)end
   viewport.BackgroundColor3=Color3.fromRGB(12,25,39);viewport.Ambient=Color3.new(.8,.8,.8);viewport.LightColor=Color3.new(1,1,1);viewport.Parent=f
   camera=Instance.new('Camera');camera.FieldOfView=36;camera.Parent=viewport;viewport.CurrentCamera=camera
   local world=Instance.new('WorldModel');world.Parent=viewport
   preview=Factory.createVisual(Karts.Entries[variants[colorIndex]],previewWing)
   for _,o in preview:GetDescendants()do if o:IsA('BasePart')then o.Anchored=true;o.CanCollide=false;o.CanTouch=false;o.CanQuery=false end end
   preview.Parent=world
   viewport:GetPropertyChangedSignal('AbsoluteSize'):Connect(fitPreview);task.defer(fitPreview)
   local color=button(controls,'Color','COLOR: '..Karts.Entries[variants[colorIndex]].DisplayName,if wide then 96 else h+8)
   color.Activated:Connect(function()colorIndex=colorIndex%#variants+1;render()end)
   local compare=button(controls,'Compare',if wide then (if previewWing then 'WITH WING' else 'WITHOUT WING') else (if previewWing then 'WITH WING · TAP TO COMPARE' else 'WITHOUT WING · TAP TO COMPARE'),if wide then 96 else h+56)
   if wide then
    color.Size=UDim2.new(.5,-12,0,44);color.TextSize=12
    compare.Position=UDim2.new(.5,4,0,96);compare.Size=UDim2.new(.5,-12,0,44)
   end
   compare.Activated:Connect(function()previewWing=not previewWing;render()end)
   if data.wingOwned then
    label(controls,'Owned','KDM V2 WING · OWNED · ALL V2 COLORS',if wide then 0 else h+104,40)
    local equip=buyButton(controls,'Equip',if data.wingEquipped then 'UNEQUIP' else 'EQUIP',if wide then 48 else h+152,'EQUIP_WING',C.WingId,not data.wingEquipped)
   else
    buyButton(controls,'BuyWing','KDM V2 WING · K$3,000 · PERMANENT',if wide then 0 else h+104,'BUY_WING',C.WingId)
    local pass=button(controls,'Pass',if passPrice then tostring(passPrice)..' Robux · PERMANENT WING' else '50 Robux target · COMING SOON',if wide then 48 else h+152)
    pass.Active=data.canPurchase and data.passAvailable==true and passPrice~=nil and not busy and not pending
    pass.TextTransparency=if pass.Active then 0 else .5
    pass.Activated:Connect(function()if not pass.Active then return end
     confirmAction={pass=true};confirmText.Text='Permanent KDM V2 Wing\n'..tostring(passPrice)..' Robux · Roblox will confirm the final price.';confirmation.Visible=true
    end)
   end
   label(f,'Ownership','One Wing unlock covers every KDM V2 color. No performance bonus.',if wide then math.max(h,148)+4 else h+204,60)
  else
   if tab=='MY INVENTORY' then
    local f=card('RefillPolicy',124)
    label(f,'Limits','Optional empty-slot refill: once per item, max 2 per race. Free starting items and lap refills stay unchanged.',0,68)
    local b=buyButton(f,'AutoRefill',if data.autoRefill then 'AUTO REFILL: ON' else 'AUTO REFILL: OFF',72,'SET_AUTO_REFILL',nil,not data.autoRefill)
   end
   for index,id in C.Order do
    local f=card(id,112);f.LayoutOrder=index
    local icon=Instance.new('ImageLabel');icon.Name='ProductImage';icon.Image=Icons.Items[id];icon.BackgroundTransparency=1;icon.Size=UDim2.fromOffset(56,56);icon.Position=UDim2.fromOffset(8,8);icon.Parent=f
    local name=label(f,'Product',id:upper()..' · K$'..C.Prices[id]..'\nOWNED: '..tostring(data.counts[id] or 0),0,60);name.Position=UDim2.fromOffset(72,0);name.Size=UDim2.new(1,-80,0,60)
    buyButton(f,'Buy','BUY 1 REFILL VOUCHER · K$'..C.Prices[id],64,'BUY_ITEM',id)
   end
  end
  if pending and not busy then
   local f=card('PendingPurchase',52);f.LayoutOrder=-1
   local b=button(f,'Retry','RETRY PENDING PURCHASE',4)
   b.Activated:Connect(function()request(pending.action,pending.item,pending.value)end)
  end
 end
 local function layout()
  local l=Layout.forSize(root.AbsoluteSize);panel.Position=UDim2.fromOffset(8,8);panel.Size=UDim2.fromOffset(l.width,l.height)
  title.Size=UDim2.new(1,-64,0,44);close.Position=UDim2.new(1,-8,0,0)
  for i,name in {'WINGS','RACE ITEMS','MY INVENTORY'}do tabs[name].Position=UDim2.fromOffset(8+(i-1)*(l.tabWidth+4),l.tabsY);tabs[name].Size=UDim2.fromOffset(l.tabWidth,44)end
  body.Position=UDim2.fromOffset(8,l.bodyY);body.Size=UDim2.new(1,-16,0,l.bodyHeight)
  status.Position=UDim2.fromOffset(8,l.footerY-8);status.Size=UDim2.new(1,-16,0,l.footerHeight)
  status.Visible=l.footerHeight>0
  confirmation.Size=UDim2.fromOffset(l.confirmWidth,l.confirmHeight)
  yes.Size,no.Size=UDim2.new(.5,-12,0,44),UDim2.new(.5,-12,0,44);no.Position=UDim2.new(.5,4,0,116)
  if gui.Enabled then render()end
 end
 local function closeShop()
  gui.Enabled=false;confirmation.Visible=false;p:SetAttribute('KDMShopOpen',false)
  clearCards()
  if restoreGarage then restoreGarage=false;Garage.open('KART')end
 end
 openShop=function()
  if p:GetAttribute('RaceState')~='GARAGE' or p:GetAttribute('LobbyDriveActive')==true or p:GetAttribute('KDMRoutePending')=='RACE_LAUNCH' then return end
  restoreGarage=p:GetAttribute('HubOverlayOpen')==true;Garage.close();p:SetAttribute('KDMShopOpen',true);gui.Enabled=true
  colorIndex=table.find(variants,p:GetAttribute('SelectedKartId')) or colorIndex;layout();render();request('PROFILE')
 end
 close.Activated:Connect(closeShop);no.Activated:Connect(function()confirmation.Visible=false;confirmAction=nil end)
 yes.Activated:Connect(function()
  if not confirmation.Visible or not confirmAction then return end
  local a=confirmAction;confirmation.Visible=false;confirmAction=nil
  if a.pass then task.spawn(function()local ok,r=pcall(function()return RS.KDMEconomy:InvokeServer('PASS')end);status.Text=if ok and r.status=='PASS_PROMPTED' then 'Complete the Roblox purchase prompt.' else 'Pass unavailable.'end)
  else request(a.action,a.item,a.value)end
 end)
 for name,b in tabs do b.Activated:Connect(function()confirmation.Visible=false;tab=name;render()end)end
 root:GetPropertyChangedSignal('AbsoluteSize'):Connect(layout)
 for _,attr in {'KDMWalletCash','KDMWingOwned','KDMWingEquipped','KDMInventoryAutoRefill'}do
  p:GetAttributeChangedSignal(attr):Connect(function()
   data.cash=p:GetAttribute('KDMWalletCash');data.wingOwned=p:GetAttribute('KDMWingOwned')==true;data.wingEquipped=p:GetAttribute('KDMWingEquipped')==true
   if gui.Enabled then render()end
  end)
 end
 for _,attr in {'RaceState','LobbyDriveActive','KDMRoutePending'}do p:GetAttributeChangedSignal(attr):Connect(function()
  if p:GetAttribute('RaceState')~='GARAGE' or p:GetAttribute('LobbyDriveActive')==true or p:GetAttribute('KDMRoutePending')=='RACE_LAUNCH' then restoreGarage=false;closeShop()end
 end)end
 layout()
end
return Controller
