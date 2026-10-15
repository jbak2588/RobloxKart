local Controller={}
local openShop
function Controller.open(targetTab)if openShop then return openShop(targetTab)end return false end
function Controller.start()
 if workspace:GetAttribute('KDMServerRole')~='HUB' then return end
 local Players,RS=game:GetService('Players'),game:GetService('ReplicatedStorage')
 local p=Players.LocalPlayer;local remote=RS:WaitForChild('KDMShop',10);if not remote then return end
 local Shared=RS.Shared;local C=require(Shared.KDMShopCatalog);local Karts=require(Shared.KartCatalog)
 local Factory=require(Shared.KartVisualFactory);local Framing=require(Shared.KartPreviewFraming)
 local Icons=require(script.Parent.KDMIconCatalog);local Layout=require(script.Parent.ShopLayout)
 local Garage=require(script.Parent.GarageUiController);local Http=game:GetService('HttpService')
 local Market=game:GetService('MarketplaceService')
 local playerGui=p:WaitForChild('PlayerGui');if playerGui:FindFirstChild('KDMGarageShop') then return end
 local colors=Layout.colors()
 local gui=Instance.new('ScreenGui');gui.Name='KDMGarageShop';gui.ResetOnSpawn=false;gui.DisplayOrder=35
 gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Enabled=false;gui.Parent=playerGui
 local root=Instance.new('Frame');root.Name='SafeRoot';root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=1;root.Parent=gui
 local scrim=Instance.new('Frame');scrim.Name='ShopScrim';scrim.Position=UDim2.fromScale(-1,-1);scrim.Size=UDim2.fromScale(3,3);scrim.BackgroundColor3=colors.Background;scrim.BackgroundTransparency=.08;scrim.BorderSizePixel=0;scrim.Parent=root
 local panel=Instance.new('Frame');panel.Name='Shop';panel.BackgroundColor3=colors.Background;panel.Active=true;panel.Parent=root;Layout.style(panel,'Background')
 local function label(parent,name,text,y,height)
  local t=Instance.new('TextLabel');t.Name=name;t.Text=text;t.Position=UDim2.fromOffset(8,y);t.Size=UDim2.new(1,-16,0,height or 40)
  t.TextColor3=colors.White;t.BackgroundTransparency=1;t.TextWrapped=true;t.Font=Enum.Font.GothamBold;t.TextSize=14;t.Parent=parent;return t
 end
 local function button(parent,name,text,y)
  local b=Instance.new('TextButton');b.Name=name;b.Text=text;b.Position=UDim2.fromOffset(8,y);b.Size=UDim2.new(1,-16,0,44)
  b.BackgroundColor3=colors.Card;b.TextColor3=Color3.new(1,1,1);b.Font=Enum.Font.GothamBold;b.TextSize=14;b.TextWrapped=true;b.Parent=parent;Layout.style(b);return b
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
   body.CanvasPosition=Vector2.new(0,math.clamp(scrollOrigin+delta,0,math.max(0,body.AbsoluteCanvasSize.Y-body.AbsoluteWindowSize.Y)))
  end
 end)
 inputService.InputEnded:Connect(function(input)if input==scrollTouch then scrollTouch=nil end end)
 local status=label(panel,'Status','',0,40)
 local confirmation=Instance.new('Frame');confirmation.Name='PurchaseConfirmation';confirmation.AnchorPoint=Vector2.new(.5,.5)
 confirmation.Position=UDim2.fromScale(.5,.5);confirmation.BackgroundColor3=colors.Panel;confirmation.Visible=false;confirmation.ZIndex=10;confirmation.Parent=root;Layout.style(confirmation,'Panel')
 local modal=Instance.new('TextButton');modal.Name='ConfirmationBackdrop';modal.Text='';modal.Size=UDim2.fromScale(1,1);modal.BackgroundColor3=colors.Background;modal.BackgroundTransparency=.15;modal.ZIndex=9;modal.Modal=true;modal.Visible=false;modal.Parent=root
 confirmation:GetPropertyChangedSignal('Visible'):Connect(function()modal.Visible=confirmation.Visible end)
 local confirmText=label(confirmation,'Description','',12,80);confirmText.ZIndex=11
 local yes=button(confirmation,'Confirm','CONFIRM',116);yes.ZIndex=11;yes.BackgroundColor3=colors.Yellow;yes.TextColor3=colors.Background
 local no=button(confirmation,'Cancel','CANCEL',116);no.ZIndex=11
 local data={counts={},canPurchase=false};local busy=false;local pending=nil;local epoch=0;local tab='WINGS'
 local previewWing=true;local variants={};local colorIndex=1;local preview=nil;local viewport=nil;local camera=nil
 local passPrice=nil;local confirmAction=nil;local restoreGarage=false
 local selectedItem=C.Order[1]
 for _,id in Karts.Order do if Karts.Entries[id].VisualModelName=='KDMV2' then table.insert(variants,id)end end
 local function fitPreview()
  if preview and viewport and camera then
   -- Static hero, not an orbit: fit this viewing angle's actual visible corners.
   local cf
   local low,high=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
   local points={}
   for _,part in preview:GetDescendants()do if part:IsA('BasePart') and part.Transparency<1 then
    for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do
     local point=part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z)*.5)
     low=low:Min(point);high=high:Max(point);table.insert(points,point)
    end end end
   end end
   if #points>0 and viewport.AbsoluteSize.X>0 and viewport.AbsoluteSize.Y>0 then
    local center=(low+high)*.5;local direction=Vector3.new(-1,.18,-1).Unit
    local right=Vector3.yAxis:Cross(direction).Unit;local up=direction:Cross(right)
    local orientation=CFrame.fromMatrix(center,right,up,direction)
    local tangent=math.tan(math.rad(camera.FieldOfView)*.5);local aspect=viewport.AbsoluteSize.X/viewport.AbsoluteSize.Y
    local distance=.1
    for _,point in points do local p=orientation:PointToObjectSpace(point)
     distance=math.max(distance,p.Z+math.abs(p.X)/(tangent*aspect*.88),p.Z+math.abs(p.Y)/(tangent*.90),p.Z+.1)
    end
    cf=CFrame.fromMatrix(center+direction*distance,right,up,direction)
   else cf=Framing.fit(preview,viewport.AbsoluteSize.X/math.max(1,viewport.AbsoluteSize.Y),camera.FieldOfView,true)end
   if cf then camera.CFrame=cf end
  end
 end
 local function clearCards()
  scrollTouch=nil
  local fixed=panel:FindFirstChild('SelectedItemDetail');if fixed then fixed:Destroy()end
  preview,viewport,camera=nil,nil,nil
  for _,o in body:GetChildren()do if o~=list then o:Destroy()end end
  body.CanvasPosition=Vector2.zero
 end
 local function card(name,height)
  local f=Instance.new('Frame');f.Name=name;f.Size=UDim2.new(1,-8,0,height);f.BackgroundColor3=colors.Card;f.Parent=body;Layout.style(f);return f
 end
 local render,request
 local descriptions={Nitro='A short burst of speed.',Shield='Blocks one incoming attack.',Slick='Leaves a slippery pad behind.',Missile='Targets the racer just ahead.',Smoke='Leaves a cloud that obscures vision.',Thunder='Slows racers ahead of you.'}
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
     if r.purchaseState=='SAVE_CONFIRMED' then pending=nil;status.Text=if action=='BUY_ITEM' or action=='BUY_WING' then 'PURCHASE COMPLETE' else 'ACCOUNT SAVED' else status.Text=''end
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
  local full=Layout.forSize(root.AbsoluteSize);body.Size=UDim2.fromOffset(full.width-16,full.bodyHeight)
  local scroll=body.CanvasPosition.Y
  clearCards();for name,b in tabs do b.BackgroundColor3=if name==tab then colors.Blue else colors.Card
   local stroke=b:FindFirstChild('ArcadeStroke');stroke.Color=if name==tab then colors.Cyan else colors.Secondary;stroke.Transparency=if name==tab then 0 else .7
  end
  if tab=='WINGS' then
   local l=Layout.forSize(root.AbsoluteSize)
   local wide=true
   local mobile=root.AbsoluteSize.Y<440
   local h=if mobile then math.max(80,l.bodyHeight-8) else math.max(240,l.previewHeight)
   local f=card('WingProduct',if mobile then math.max(l.bodyHeight,224) else math.max(h+40,326))
   local productTitle=label(f,'ProductTitle','KDM V2 WING',4,28);productTitle.TextSize=20;productTitle.Visible=not mobile
   local controls=f
   if wide then
    controls=Instance.new('Frame');controls.Name='WingActions';controls.Position=UDim2.new(.60,0,0,40);controls.Size=UDim2.new(.40,-8,0,if mobile then 176 else 280);controls.BackgroundTransparency=1;controls.Parent=f
   end
   viewport=Instance.new('ViewportFrame');viewport.Name='ActualWingPreview';viewport.Size=UDim2.new(1,-16,0,h);viewport.Position=UDim2.fromOffset(8,38)
   if mobile then viewport.Position=UDim2.fromOffset(8,4)end
   if wide then viewport.Size=UDim2.new(.60,-16,0,h)end
   viewport.BackgroundColor3=colors.Panel;viewport.Ambient=Color3.new(.8,.8,.8);viewport.LightColor=Color3.new(1,1,1);viewport.Parent=f;Layout.style(viewport,'Panel')
   camera=Instance.new('Camera');camera.FieldOfView=36;camera.Parent=viewport;viewport.CurrentCamera=camera
   local world=Instance.new('WorldModel');world.Parent=viewport
   preview=Factory.createVisual(Karts.Entries[variants[colorIndex]],previewWing)
   for _,o in preview:GetDescendants()do if o:IsA('BasePart')then o.Anchored=true;o.CanCollide=false;o.CanTouch=false;o.CanQuery=false end end
   preview.Parent=world
   viewport:GetPropertyChangedSignal('AbsoluteSize'):Connect(fitPreview);task.defer(fitPreview)
   local y=if mobile then -38 else 0
   local state=if data.wingOwned then (if data.wingEquipped then 'OWNED · EQUIPPED' else 'OWNED · UNEQUIPPED') elseif data.status=='FOUND' then 'NOT OWNED' else 'UNAVAILABLE'
   label(controls,'Owned',state..(if mobile then ' · K$3,000' else ''),y,if mobile then 22 else 28).TextColor3=colors.Cyan
   local price=label(controls,'WingPrice','K$3,000 · PERMANENT',y+30,32);price.TextSize=20;price.TextColor3=colors.Yellow;price.Visible=not mobile
   if data.wingOwned then
    buyButton(controls,'Equip',if data.wingEquipped then 'UNEQUIP' else 'EQUIP',(if mobile then y+26 else y+68),'EQUIP_WING',C.WingId,not data.wingEquipped).BackgroundColor3=colors.Blue
   else
    local buy=buyButton(controls,'BuyWing','BUY · K$3,000',(if mobile then y+26 else y+68),'BUY_WING',C.WingId);buy.BackgroundColor3=if buy.Active then colors.Yellow else colors.Card;buy.TextColor3=if buy.Active then colors.Background else colors.Secondary
   end
   local color=button(controls,'Color','COLOR · '..Karts.Entries[variants[colorIndex]].DisplayColorName,if mobile then y+76 else y+120)
   color.Activated:Connect(function()if os.clock()-draggedAt>.25 then colorIndex=colorIndex%#variants+1;render()end end)
   local compare=button(controls,'Compare',if previewWing then '✓ WITH WING · COMPARE' else 'WITHOUT WING · COMPARE',if mobile then y+124 else y+172)
   compare.BackgroundColor3=colors.Blue
   compare.Activated:Connect(function()if os.clock()-draggedAt>.25 then previewWing=not previewWing;render()end end)
   if not data.wingOwned then
    local pass=button(controls,'Pass',if passPrice then tostring(passPrice)..' Robux · PERMANENT WING' else 'Robux · COMING SOON',if mobile then y+172 else y+224)
    pass.Active=data.canPurchase and data.passAvailable==true and passPrice~=nil and not busy and not pending
    pass.TextTransparency=if pass.Active then 0 else .5
    pass.Activated:Connect(function()if not pass.Active or os.clock()-draggedAt<=.25 then return end
     confirmAction={pass=true};confirmText.Text='Permanent KDM V2 Wing\n'..tostring(passPrice)..' Robux · Roblox will confirm the final price.';confirmation.Visible=true
    end)
   end
   label(f,'Ownership','One Wing · All 7 V2 colors · No performance bonus',if mobile then 178 elseif wide then math.max(h+8,286) else h+274,44).TextColor3=colors.Secondary
  else
   local itemLayout=Layout.itemsForSize(root.AbsoluteSize)
   body.Size=UDim2.fromOffset(itemLayout.gridWidth,itemLayout.gridHeight)
   local gridFrame=card('ItemGrid',0);gridFrame.LayoutOrder=1;gridFrame.BackgroundTransparency=1
   local grid=Instance.new('UIGridLayout');grid.Name='ItemSlots';grid.SortOrder=Enum.SortOrder.LayoutOrder;grid.Parent=gridFrame
   local gridConfig
   local function gridLayout()
    local config=itemLayout
    gridConfig=config
    grid.CellPadding=UDim2.fromOffset(config.gap,config.gap);grid.CellSize=UDim2.fromOffset(config.width,config.height)
    grid.FillDirectionMaxCells=config.columns
    gridFrame.Size=UDim2.new(1,-8,0,math.ceil(#C.Order/config.columns)*(config.height+config.gap)-config.gap)
   end
   grid:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()gridFrame.Size=UDim2.new(1,-8,0,grid.AbsoluteContentSize.Y)end)
   gridLayout()
   local function quantity(id)
    return if type(data.counts[id])=='number' then tostring(data.counts[id]) elseif data.status=='FOUND' then '0' else '--'
   end
   for index,id in C.Order do
    local f=Instance.new('TextButton');f.Name=id;f.Text='';f.LayoutOrder=index;f.Parent=gridFrame
    local border=Layout.style(f);local chosen=id==selectedItem
    border.Color=if chosen then colors.Cyan else colors.Secondary;border.Transparency=if chosen then 0 else .7;border.Thickness=if chosen then 2 else 1
    local compact=gridConfig.height<100
    local inventory=tab=='MY INVENTORY'
    local iconSize=if compact then math.max(28,gridConfig.height-8) else math.min(104,gridConfig.height-58)
    local well=Instance.new('Frame');well.Name='IconWell';well.BackgroundColor3=colors.Panel;well.BorderSizePixel=0;well.Parent=f
    well.Position=UDim2.fromOffset(4,4);well.Size=if compact then UDim2.fromOffset(iconSize,iconSize) else UDim2.new(1,-8,0,iconSize+4)
    local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,6);corner.Parent=well
    local icon=Instance.new('ImageLabel');icon.Name='ProductImage';icon.Image=Icons.Items[id];icon.BackgroundTransparency=1;icon.Size=UDim2.fromOffset(iconSize,iconSize);icon.Parent=f
    icon.ScaleType=Enum.ScaleType.Fit
    icon.Position=if compact then UDim2.fromOffset(4,4) else UDim2.new(.5,-iconSize/2,0,6)
    local textX=if compact then iconSize+8 else 8
    local name=label(f,'Product',(if chosen then '✓ ' else '')..id:upper(),if compact then 2 else 74,if compact then 20 else 24)
    name.Position=UDim2.fromOffset(textX,if compact then 2 else 74);name.Size=UDim2.new(1,-textX-4,0,if compact then 20 else 24);name.TextSize=if compact then 11 else 14
    local count=label(f,'Quantity','OWNED: '..quantity(id),if compact then 22 else 100,if compact then 18 else 20);count.TextSize=if compact then 10 else 12;count.TextColor3=colors.Secondary
    count.Position=UDim2.fromOffset(textX,if compact then 22 else 100);count.Size=UDim2.new(1,-textX-4,0,if compact then 18 else 20)
    local price=label(f,'Price','K$ '..C.Prices[id],if compact then 40 else 126,if compact then 16 else 26);price.TextColor3=colors.Yellow
    price.Position=UDim2.fromOffset(textX,if compact then 40 else 126);price.Size=UDim2.new(1,-textX-4,0,if compact then 16 else 26);price.TextSize=if compact then 10 else 14
    if gridConfig.height<60 then count.Text='×'..quantity(id)..'  ·  K$'..C.Prices[id];price.Visible=false end
    -- Short landscape slots reserve their area for art/name. The fixed detail
    -- always retains authoritative stock and price; tapping still only selects.
    if compact then
     name.Position=UDim2.fromOffset(iconSize+8,if gridConfig.height<60 then 4 else 8)
     name.Size=UDim2.new(1,-iconSize-12,0,20);name.TextSize=if gridConfig.height<60 then 10 else 11
     count.Visible=inventory;count.Text='× '..quantity(id);count.TextSize=if gridConfig.height<60 then 14 else 18
     count.TextColor3=colors.Cyan;count.Position=UDim2.fromOffset(iconSize+8,24);count.Size=UDim2.new(1,-iconSize-12,0,20)
     price.Visible=false
    else
     name.Position=UDim2.fromOffset(6,iconSize+10);name.Size=UDim2.new(1,-12,0,20)
     count.Position=UDim2.fromOffset(6,iconSize+30);count.Size=UDim2.new(.5,-6,0,20)
     price.Position=UDim2.new(.5,0,0,iconSize+30);price.Size=UDim2.new(.5,-6,0,20)
     if inventory then count.Text='× '..quantity(id);count.TextSize=20;count.TextColor3=colors.Cyan;count.Size=UDim2.new(1,-12,0,24);price.Visible=false end
    end
    f.BackgroundColor3=if chosen then colors.Light else colors.Card
    f.Activated:Connect(function()if busy or os.clock()-draggedAt<=.25 then return end;selectedItem=id;render()end)
   end
   local detail=card('SelectedItemDetail',itemLayout.detailHeight);detail.Parent=panel
   detail.Position=UDim2.fromOffset(itemLayout.detailX,itemLayout.detailY);detail.Size=UDim2.fromOffset(itemLayout.detailWidth,itemLayout.detailHeight)
   local short=itemLayout.detailHeight<150;local bottom=itemLayout.mode=='B'
   local name=label(detail,'SelectedName',selectedItem:upper()..(if tab=='MY INVENTORY' then '' else ' · K$ '..C.Prices[selectedItem]),4,24);name.TextSize=if short then 13 else 18
   local count=label(detail,'SelectedQuantity','OWNED: '..quantity(selectedItem),28,20);count.TextSize=12
   local desc=label(detail,'Description',descriptions[selectedItem],56,48);desc.TextColor3=colors.Secondary;desc.Visible=not short
   local icon=Instance.new('ImageLabel');icon.Name='SelectedImage';icon.Image=Icons.Items[selectedItem];icon.Size=UDim2.fromOffset(72,72);icon.Position=UDim2.fromOffset(10,112);icon.BackgroundTransparency=1;icon.Parent=detail;icon.Visible=itemLayout.detailHeight>=260
   local y=itemLayout.detailHeight-48
   local buy
   if tab=='MY INVENTORY' then
    buy=buyButton(detail,'AutoRefill',if data.autoRefill then 'AUTO REFILL: ON' else 'AUTO REFILL: OFF',y,'SET_AUTO_REFILL',nil,not data.autoRefill)
    desc.Text='Owned vouchers only.\n1 per item · max 2 per race.'
   else
    buy=buyButton(detail,'Buy','BUY 1 VOUCHER · K$'..C.Prices[selectedItem],y,'BUY_ITEM',selectedItem)
   end
   buy.BackgroundColor3=if tab=='MY INVENTORY' then colors.Blue else colors.Yellow;buy.TextColor3=if tab=='MY INVENTORY' then colors.White else colors.Background
   if not buy.Active then buy.BackgroundColor3=colors.Card;buy.TextColor3=colors.Secondary end
   if bottom then
    name.Size=UDim2.new(.45,-16,0,24);count.Position=UDim2.fromOffset(8,24);count.Size=UDim2.new(.45,-16,0,18)
    buy.Position=UDim2.new(.45,4,0,0);buy.Size=UDim2.new(.55,-12,0,44)
   end

  end

  if pending and not busy then
   local f=card('PendingPurchase',52);f.LayoutOrder=-1
   local b=button(f,'Retry','RETRY PENDING PURCHASE',4)
   b.Activated:Connect(function()request(pending.action,pending.item,pending.value)end)
  end
  task.defer(function()if gui.Enabled then body.CanvasPosition=Vector2.new(0,math.clamp(scroll,0,math.max(0,body.AbsoluteCanvasSize.Y-body.AbsoluteWindowSize.Y)))end end)
 end
 local function layout()
  local l=Layout.forSize(root.AbsoluteSize);panel.Position=UDim2.fromOffset(math.floor((root.AbsoluteSize.X-l.width)/2),math.floor((root.AbsoluteSize.Y-l.height)/2));panel.Size=UDim2.fromOffset(l.width,l.height)
  title.Size=UDim2.new(1,-64,0,44);title.TextSize=if root.AbsoluteSize.Y<260 then 14 else 20;close.Position=UDim2.new(1,-8,0,0)
  for i,name in {'WINGS','RACE ITEMS','MY INVENTORY'}do tabs[name].Position=UDim2.fromOffset(8+(i-1)*(l.tabWidth+4),l.tabsY);tabs[name].Size=UDim2.fromOffset(l.tabWidth,44)end
  body.Position=UDim2.fromOffset(8,l.bodyY);body.Size=UDim2.new(1,-16,0,l.bodyHeight)
  status.Position=UDim2.fromOffset(8,l.footerY-8);status.TextSize=12;status.Size=UDim2.new(1,-16,0,l.footerHeight)
  status.Visible=l.footerHeight>0
  confirmation.Size=UDim2.fromOffset(l.confirmWidth,l.confirmHeight)
  yes.Size,no.Size=UDim2.new(.5,-12,0,44),UDim2.new(.5,-12,0,44);no.Position=UDim2.new(.5,4,0,116)
  if gui.Enabled then render()end
 end
 local function closeShop()
  gui.Enabled=false;confirmation.Visible=false;p:SetAttribute('KDMShopOpen',false)
  clearCards()
  if restoreGarage then restoreGarage=false;if Garage.resumeAfterShop then Garage.resumeAfterShop()else Garage.open('KART')end end
 end
 openShop=function(targetTab)
  local rooms=playerGui:FindFirstChild('KDMMatchRooms')
  local context=if Garage.shopContext then Garage.shopContext() else (if p:GetAttribute('HubOverlayOpen')==true then 'KART' else 'LOBBY')
  if gui.Enabled then return true end
  if p:GetAttribute('RaceState')~='GARAGE' or p:GetAttribute('LobbyDriveActive')==true or p:GetAttribute('LobbyDrivePending')==true
   or (p:GetAttribute('KDMRoutePending')~=nil and p:GetAttribute('KDMRoutePending')~='') or (rooms and rooms.Enabled) or context==nil then return false end
  body.CanvasPosition=Vector2.zero;restoreGarage=context=='KART';if restoreGarage then Garage.close()end;p:SetAttribute('KDMProfileOpen',false);p:SetAttribute('KDMShopOpen',true);gui.Enabled=true
  if tabs[targetTab] then tab=targetTab end
  colorIndex=table.find(variants,p:GetAttribute('SelectedKartId')) or colorIndex;layout();render();request('PROFILE');return true
 end
 close.Activated:Connect(closeShop);no.Activated:Connect(function()confirmation.Visible=false;confirmAction=nil end)
 yes.Activated:Connect(function()
  if not confirmation.Visible or not confirmAction then return end
  local a=confirmAction;confirmation.Visible=false;confirmAction=nil
  if a.pass then task.spawn(function()local ok,r=pcall(function()return RS.KDMEconomy:InvokeServer('PASS')end);status.Text=if ok and r.status=='PASS_PROMPTED' then 'Complete the Roblox purchase prompt.' else 'Pass unavailable.'end)
  else request(a.action,a.item,a.value)end
 end)
 for name,b in tabs do b.Activated:Connect(function()confirmation.Visible=false;tab=name;body.CanvasPosition=Vector2.zero;render()end)end
 root:GetPropertyChangedSignal('AbsoluteSize'):Connect(layout)
 for _,attr in {'KDMWalletCash','KDMWingOwned','KDMWingEquipped','KDMInventoryAutoRefill'}do
  p:GetAttributeChangedSignal(attr):Connect(function()
   data.cash=p:GetAttribute('KDMWalletCash');data.wingOwned=p:GetAttribute('KDMWingOwned')==true;data.wingEquipped=p:GetAttribute('KDMWingEquipped')==true
   if gui.Enabled then render()end
  end)
 end
 for _,attr in {'RaceState','LobbyDriveActive','LobbyDrivePending','KDMRoutePending','HubOverlayOpen','KDMProfileOpen'}do p:GetAttributeChangedSignal(attr):Connect(function()
  if p:GetAttribute('RaceState')~='GARAGE' or p:GetAttribute('LobbyDriveActive')==true or p:GetAttribute('LobbyDrivePending')==true or (p:GetAttribute('KDMRoutePending')~=nil and p:GetAttribute('KDMRoutePending')~='') or (gui.Enabled and (p:GetAttribute('HubOverlayOpen')==true or p:GetAttribute('KDMProfileOpen')==true)) then restoreGarage=false;closeShop()end
 end)end
 local function watchRooms(child)
  if child.Name=='KDMMatchRooms' then child:GetPropertyChangedSignal('Enabled'):Connect(function()if child.Enabled and gui.Enabled then restoreGarage=false;closeShop()end end)end
 end
 for _,child in playerGui:GetChildren()do watchRooms(child)end
 playerGui.ChildAdded:Connect(watchRooms)
 layout()
end
return Controller
