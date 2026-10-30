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
 local StyleHelper=require(script.Parent.KDMUiStyleHelper)

 local playerGui=p:WaitForChild('PlayerGui');if playerGui:FindFirstChild('KDMGarageShop') then return end
 local colors=Layout.colors()
 local gui=Instance.new('ScreenGui');gui.Name='KDMGarageShop';gui.ResetOnSpawn=false;gui.DisplayOrder=35
 gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Enabled=false;gui.Parent=playerGui
 local root=Instance.new('Frame');root.Name='SafeRoot';root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=1;root.Parent=gui
 local scrim=Instance.new('Frame');scrim.Name='ShopScrim';scrim.Position=UDim2.fromScale(-1,-1);scrim.Size=UDim2.fromScale(3,3);scrim.BackgroundColor3=colors.Background;scrim.BackgroundTransparency=.82;scrim.BorderSizePixel=0;scrim.Parent=root
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
 local close=button(panel,'Close','X',0);close.Size=UDim2.fromOffset(40,40);close.AnchorPoint=Vector2.new(1,0)
 close.Position=UDim2.new(1,-8,0,8)
 StyleHelper.applyCloseButton(close)
 local topUp=button(panel,'TopUp','+ K$',0);topUp.Size=UDim2.fromOffset(56,40);topUp.Position=UDim2.new(1,-112,0,8)
 topUp.Activated:Connect(function()require(script.Parent.RobuxTopUpController).open()end)
 local function flatButton(b,color)
  for _,child in b:GetChildren()do if child:IsA('UIGradient') then child:Destroy()end end
  b.BackgroundColor3=color
 end
 flatButton(close,Color3.fromRGB(255,55,55))
 local tabs={};for _,name in {'KARTS','RACE ITEMS','MY INVENTORY'}do tabs[name]=button(panel,name,if name=='KARTS' then 'BUY KARTS' else name,56)end
 local body=Instance.new('ScrollingFrame');body.Name='Products';body.BackgroundTransparency=1;body.BorderSizePixel=0
 body.ScrollBarThickness=6;body.CanvasSize=UDim2.new();body.Parent=panel
 body.Active=true;body.ScrollingDirection=Enum.ScrollingDirection.Y
 local list=Instance.new('UIListLayout');list.Padding=UDim.new(0,8);list.SortOrder=Enum.SortOrder.LayoutOrder;list.Parent=body
 list:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()body.CanvasSize=UDim2.fromOffset(0,list.AbsoluteContentSize.Y)end)
 -- Own only a shop-list touch. A dragged purchase button must never activate.
 local inputService=game:GetService('UserInputService')
 local orbitInput=nil
 local scrollTouch,scrollStart,scrollOrigin=nil,0,0
 local draggedAt=-math.huge
 body.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.Touch and not scrollTouch and not orbitInput then
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
 local modal=Instance.new('TextButton');modal.Name='ConfirmationBackdrop';modal.Text='';modal.Size=UDim2.fromScale(1,1);modal.BackgroundColor3=colors.Background;modal.BackgroundTransparency=.82;modal.ZIndex=9;modal.Modal=true;modal.Visible=false;modal.Parent=root
 confirmation:GetPropertyChangedSignal('Visible'):Connect(function()modal.Visible=confirmation.Visible end)
 local confirmText=label(confirmation,'Description','',12,80);confirmText.ZIndex=11
 local yes=button(confirmation,'Confirm','CONFIRM',116);yes.ZIndex=11
 StyleHelper.apply3DButton(yes, Color3.fromRGB(255, 235, 90), Color3.fromRGB(255, 195, 25), Color3.fromRGB(215, 140, 0), 12, 2.5)
 local no=button(confirmation,'Cancel','CANCEL',116);no.ZIndex=11
 StyleHelper.apply3DButton(no, Color3.fromRGB(120, 140, 170), Color3.fromRGB(70, 90, 120), Color3.fromRGB(40, 60, 90), 12, 2.5)
 flatButton(yes,colors.Yellow);yes.TextColor3=colors.Background
 flatButton(no,colors.Panel)
 local data={counts={},ownedKarts={},canPurchase=false};local busy=false;local pending=nil;local epoch=0;local tab='KARTS'
 local inventorySection='KARTS';local variants={};local colorIndex=1;local preview=nil;local viewport=nil;local camera=nil
 local confirmAction=nil;local restoreGarage=false
 local selectedItem=C.Order[1]
 for _,id in Karts.Order do if Karts.Entries[id].VisualModelName=='KDMV2' then table.insert(variants,id)end end
 local orbitConnection=nil;local orbitX=0;local orbitIdle=0
 local yaw=math.rad(225);local pitch=.22;local center=Vector3.zero;local distance=20
 local function updateCamera()
  if not camera then return end
  local direction=Vector3.new(math.sin(yaw)*math.cos(pitch),math.sin(pitch),math.cos(yaw)*math.cos(pitch))
  local right=Vector3.yAxis:Cross(direction).Unit
  camera.CFrame=CFrame.fromMatrix(center+direction*distance,right,direction:Cross(right),direction)
 end
 local function fitPreview()
  if not preview or not viewport or not camera then return end
  local cf,target=Framing.fit(preview,viewport.AbsoluteSize.X/math.max(1,viewport.AbsoluteSize.Y),camera.FieldOfView,true)
  if not cf or not target then return end
  center=target;distance=(cf.Position-target).Magnitude;pitch=math.asin((cf.Position.Y-target.Y)/distance);updateCamera()
 end
 inputService.InputChanged:Connect(function(input)
  if not orbitInput then return end
  if input~=orbitInput and not (orbitInput.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement) then return end
  local dx=input.Position.X-orbitX;orbitX=input.Position.X;yaw-=math.rad(dx*.32);updateCamera()
  if math.abs(dx)>1 then draggedAt=os.clock() end
 end)
 inputService.InputEnded:Connect(function(input)if input==orbitInput then orbitInput=nil;orbitIdle=2.5 end end)
 inputService.WindowFocusReleased:Connect(function()orbitInput=nil;orbitIdle=2.5 end)
 local function clearCards()
  scrollTouch=nil;orbitInput=nil
  if orbitConnection then orbitConnection:Disconnect();orbitConnection=nil end
  local nav=panel:FindFirstChild('InventorySections');if nav then nav:Destroy() end
  local fixed=panel:FindFirstChild('SelectedItemDetail');if fixed then fixed:Destroy()end
  preview,viewport,camera=nil,nil,nil
  for _,o in body:GetChildren()do if o~=list then o:Destroy()end end
  body.CanvasPosition=Vector2.zero
 end
 local function card(name,height)
  local f=Instance.new('Frame');f.Name=name;f.Size=UDim2.new(1,-8,0,height);f.BackgroundColor3=colors.Card;f.Parent=body;Layout.style(f);return f
 end
 local render,request
 local browseHint='SCROLL DOWN TO VIEW ALL 7 KART COLORS ↓'
 local descriptions={Nitro='A short burst of speed.',Shield='Blocks one incoming attack.',Slick='Leaves a slippery pad behind.',Missile='Targets the racer just ahead.',Smoke='Leaves a cloud that obscures vision.',Thunder='Slows racers ahead of you.'}
 local messages={SAVE_UNCONFIRMED='Save not confirmed. Retry the same purchase.',INSUFFICIENT_FUNDS='Not enough K$.',ALREADY_OWNED='This kart is already owned.',NOT_OWNED='Purchase this kart first.',
  ACCESS_BLOCKED='Shop preview · purchases unavailable for this account.',RATE_LIMITED='Please wait, then retry.',STOCK_FULL='Inventory is full.',HUB_REQUIRED='Return to the Garage.'}
 local function confirm(action,item,text,value)
  if busy or pending then status.Text='Finish or retry the pending purchase first.';return end
  confirmAction={action=action,item=item,value=value};confirmText.Text=text;confirmation.Visible=true
 end
 request=function(action,item,value)
  if busy then return end
  if pending and (pending.action~=action or pending.item~=item or pending.value~=value) then status.Text='Retry the pending purchase first.';return end
  if action~='PROFILE' and not pending then pending={action=action,item=item,value=value}end
  local op=pending;busy=true;epoch+=1;local current=epoch;status.Text=if action=='PROFILE' then 'Loading inventory...' else 'Saving...'
  task.delay(12,function()if current==epoch and busy then busy=false;status.Text='Save not confirmed. Retry the same purchase.';render()end end)
  task.spawn(function()
   local ok,r=pcall(function()
    if op and not op.id then
     local ticket=remote:InvokeServer('PREPARE',{action=op.action,itemId=op.item,value=op.value})
     if type(ticket)~='table' or ticket.status~='PREPARED' then return ticket end
     op.id=ticket.id
    end
    return remote:InvokeServer(action,item,if op then op.id else nil,value)
   end)
   if current~=epoch then return end
   busy=false
   if ok and type(r)=='table' and (r.status=='FOUND' or r.status=='GUEST') then
    for key,v in r do data[key]=v end
    if action=='PROFILE' or r.purchaseState=='SAVE_CONFIRMED' then
     if r.purchaseState=='SAVE_CONFIRMED' then pending=nil;status.Text=if action=='BUY_ITEM' or action=='BUY_KART' then 'PURCHASE COMPLETE' else 'ACCOUNT SAVED' else status.Text='' end
    end
   else
    local code=if ok and type(r)=='table' then r.status else 'SAVE_UNCONFIRMED'
    status.Text=messages[code] or 'Account unavailable. Please retry.'
    if code~='SAVE_UNCONFIRMED' and code~='RATE_LIMITED' then pending=nil end
   end
   render()
  end)
 end
 local function buyButton(parent,name,text,y,action,item,value)
  local b=button(parent,name,text,y);b.Active=data.canPurchase and not busy and not pending
  b.TextTransparency=if b.Active then 0 else .5
  b.Activated:Connect(function()if b.Active and os.clock()-draggedAt>.15 then
   local prompt=if action=='USE_KART' then 'Use this owned kart as your default?' else text..'\nConfirm this purchase?'
   confirm(action,item,prompt,value)
  end end);return b
 end
 render=function()
  if status.Text=='' or status.Text==browseHint then status.Text=if tab=='KARTS' then browseHint else '' end
  title.Text='GARAGE SHOP · K$ '..tostring(data.cash or p:GetAttribute('KDMWalletCash') or '--')..(if root.AbsoluteSize.Y<260 and status.Text~='' then '\n'..status.Text else '')
  if not gui.Enabled then return end
  local full=Layout.forSize(root.AbsoluteSize);body.Size=UDim2.fromOffset(full.width-16,full.bodyHeight)
  local scroll=body.CanvasPosition.Y
  clearCards();for name,b in tabs do b.BackgroundColor3=if name==tab then colors.Blue else colors.Card
   local stroke=b:FindFirstChild('ArcadeStroke');stroke.Color=if name==tab then colors.Cyan else colors.Secondary;stroke.Transparency=if name==tab then 0 else .7
  end
  local compactInventory=tab=='MY INVENTORY' and full.bodyHeight<140
  local inventoryHeader=if tab=='MY INVENTORY' and not compactInventory then 48 else 0
  tabs['MY INVENTORY'].Text=if compactInventory then 'INVENTORY · '..inventorySection..' ↔' else 'MY INVENTORY'
  body.Position=UDim2.fromOffset(8,full.bodyY+inventoryHeader)
  body.Size=UDim2.fromOffset(full.width-16,full.bodyHeight-inventoryHeader)
  if inventoryHeader>0 then
   local nav=Instance.new('Frame');nav.Name='InventorySections';nav.BackgroundTransparency=1
   nav.Position=UDim2.fromOffset(8,full.bodyY);nav.Size=UDim2.new(1,-16,0,44);nav.Parent=panel
   for index,section in {'KARTS','ITEMS'} do
    local b=button(nav,section,if section=='KARTS' then 'OWNED KARTS' else 'OWNED ITEMS',0)
    b.Position=UDim2.new((index-1)*.5,4,0,0);b.Size=UDim2.new(.5,-8,0,44)
    b.BackgroundColor3=if inventorySection==section then colors.Blue else colors.Card
    b.Activated:Connect(function()inventorySection=section;body.CanvasPosition=Vector2.zero;render()end)
   end
  end
  if tab=='KARTS' or (tab=='MY INVENTORY' and inventorySection=='KARTS') then
   local inventory=tab=='MY INVENTORY'
   local ids={}
   for _,id in C.KartOrder do if not inventory or (data.ownedKarts and data.ownedKarts[id]) then table.insert(ids,id) end end
   if inventory and #ids==0 then
    local empty=card('EmptyKartInventory',116)
    label(empty,'Empty','No purchased karts yet. Wingless karts are free rentals.',8,44)
    local browse=button(empty,'Browse','BROWSE 7 KDM V2 KARTS',64)
    browse.Activated:Connect(function()tab='KARTS';render()end)
   else
    if not table.find(ids,variants[colorIndex]) then colorIndex=table.find(variants,ids[1]) or 1 end
    local id=variants[colorIndex];local entry=Karts.Entries[id]
    local owned=data.ownedKarts and data.ownedKarts[id]==true
    local mobile=root.AbsoluteSize.Y<440
    local heroHeight=if mobile then 180 else 238
    local f=card('KartProduct',heroHeight);f.LayoutOrder=1
    local controls=Instance.new('Frame');controls.Name='KartActions';controls.Position=UDim2.new(.58,0,0,0);controls.Size=UDim2.new(.42,-8,1,0);controls.BackgroundTransparency=1;controls.Parent=f
    label(controls,'ProductTitle','KDM V2 · '..entry.DisplayColorName,4,32).TextSize=if mobile then 14 else 20
    label(controls,'Owned',if owned then (if p:GetAttribute('SelectedKartId')==id then 'OWNED · SELECTED' else 'OWNED · PERMANENT') else 'K$50,000 · PERMANENT',40,28).TextColor3=if owned then colors.Cyan else colors.Yellow
    local buy=buyButton(controls,if owned then 'UseKart' else 'BuyKart',if owned then 'USE THIS KART' else 'BUY KART · K$50,000',76,if owned then 'USE_KART' else 'BUY_KART',id)
    buy.BackgroundColor3=if owned then colors.Blue else Color3.fromRGB(72,228,96)
    local hint=label(controls,'Ownership',if inventory then 'Owned permanently · Wing included\nSelect to use this kart.\nWingless karts: free rental.' else 'One color · Wing included\nSelected automatically after purchase.\nWingless karts: free rental.',124,if mobile then 52 else 84);hint.TextSize=if mobile then 10 else 13;hint.TextColor3=colors.Secondary
    viewport=Instance.new('ViewportFrame');viewport.Name='ActualKartPreview';viewport.Size=UDim2.new(.58,-16,1,-28);viewport.Position=UDim2.fromOffset(8,4);viewport.Active=true
    viewport.BackgroundColor3=colors.Panel;viewport.Ambient=Color3.fromRGB(215,225,240);viewport.LightColor=Color3.new(1,1,1);viewport.Parent=f;Layout.style(viewport,'Panel')
    camera=Instance.new('Camera');camera.FieldOfView=36;camera.Parent=viewport;viewport.CurrentCamera=camera
    local world=Instance.new('WorldModel');world.Parent=viewport;preview=Factory.createVisual(entry,true);preview.Parent=world
    for _,o in preview:GetDescendants()do if o:IsA('BasePart')then o.Anchored=true;o.CanCollide=false;o.CanTouch=false;o.CanQuery=false end end
    label(f,'RotateHint','DRAG TO ROTATE',heroHeight-24,20).Size=UDim2.new(.58,-16,0,20)
    viewport.InputBegan:Connect(function(input)
     if confirmation.Visible or orbitInput then return end
     if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
      scrollTouch=nil;orbitInput=input;orbitX=input.Position.X;orbitIdle=2.5
     end
    end)
    viewport:GetPropertyChangedSignal('AbsoluteSize'):Connect(fitPreview);task.defer(fitPreview)
    orbitConnection=game:GetService('RunService').RenderStepped:Connect(function(dt)
     if orbitInput or confirmation.Visible then return end
     if orbitIdle>0 then orbitIdle=math.max(0,orbitIdle-dt);return end
     yaw=(yaw+dt*math.pi*2/7)%(math.pi*2);updateCamera()
    end)
    local columns=if full.width<520 then 2 else 4
    local h=if mobile then 94 else 124
    local gridFrame=card('KartCards',math.ceil(#ids/columns)*(h+8));gridFrame.LayoutOrder=2;gridFrame.BackgroundTransparency=1
    local grid=Instance.new('UIGridLayout');grid.CellSize=UDim2.new(1/columns,-8,0,h);grid.CellPadding=UDim2.fromOffset(8,8);grid.FillDirectionMaxCells=columns;grid.SortOrder=Enum.SortOrder.LayoutOrder;grid.Parent=gridFrame
    for index,kartId in ids do
     local e=Karts.Entries[kartId];local isOwned=data.ownedKarts and data.ownedKarts[kartId]==true
     local tile=Instance.new('TextButton');tile.Name=kartId;tile.Text='';tile.LayoutOrder=index;tile.Parent=gridFrame
     local border=Layout.style(tile);border.Color=if kartId==id then colors.Cyan else colors.Secondary;border.Transparency=if kartId==id then 0 else .7
     local thumb=Instance.new('ViewportFrame');thumb.Name='KartThumbnail';thumb.BackgroundTransparency=1;thumb.Position=UDim2.fromOffset(4,2);thumb.Size=UDim2.new(1,-8,1,-42);thumb.Ambient=Color3.fromRGB(215,225,240);thumb.Parent=tile
     local cam=Instance.new('Camera');cam.FieldOfView=36;cam.Parent=thumb;thumb.CurrentCamera=cam
     local w=Instance.new('WorldModel');w.Parent=thumb;local model=Factory.createVisual(e,true);model.Parent=w
     for _,o in model:GetDescendants()do if o:IsA('BasePart')then o.Anchored=true;o.CanCollide=false;o.CanTouch=false;o.CanQuery=false end end
     local function fitThumb()local cf=Framing.fit(model,thumb.AbsoluteSize.X/math.max(1,thumb.AbsoluteSize.Y),cam.FieldOfView);if cf then cam.CFrame=cf end end
     thumb:GetPropertyChangedSignal('AbsoluteSize'):Connect(fitThumb);task.defer(fitThumb)
     label(tile,'ColorName',e.DisplayColorName,h-42,20).TextSize=12
     label(tile,'Ownership',if isOwned then 'OWNED' else 'K$50,000',h-22,20).TextColor3=if isOwned then colors.Cyan else colors.Yellow
     tile.Activated:Connect(function()if not busy and os.clock()-draggedAt>.25 then colorIndex=table.find(variants,kartId);render()end end)
    end
   end
  else
   local itemLayout=Layout.itemsForSize(root.AbsoluteSize)
   itemLayout.gridHeight-=inventoryHeader;itemLayout.detailY+=inventoryHeader;itemLayout.detailHeight-=inventoryHeader
   itemLayout.height=math.max(44,math.min(164,math.floor((itemLayout.gridHeight-itemLayout.gap)/2)))
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
    border.Color=if chosen then colors.Cyan else colors.Secondary;border.Transparency=if chosen then 0 else .7;border.Thickness=if chosen then 3 else 2
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
   if itemLayout.detailHeight<100 then name.Visible=false;count.Visible=false end
   local desc=label(detail,'Description',descriptions[selectedItem],56,48);desc.TextColor3=colors.Secondary;desc.Visible=not short
   local icon=Instance.new('ImageLabel');icon.Name='SelectedImage';icon.Image=Icons.Items[selectedItem];icon.Size=UDim2.fromOffset(72,72);icon.Position=UDim2.fromOffset(10,112);icon.BackgroundTransparency=1;icon.Parent=detail;icon.Visible=itemLayout.detailHeight>=260
   local y=itemLayout.detailHeight-48
   local buy
   if tab=='MY INVENTORY' then
    buy=button(detail,'StoredOnly','STORED · RACE USE COMING LATER',y);buy.Active=false;buy.TextSize=11
    desc.Text='Purchased stock is saved. Automatic use is paused.'
   else
    buy=buyButton(detail,'Buy','BUY 1 ITEM · K$'..C.Prices[selectedItem],y,'BUY_ITEM',selectedItem)
   end
   buy.BackgroundColor3=if buy.Active then Color3.fromRGB(72,228,96) else colors.Card
   buy.TextColor3=if buy.Active then colors.Background else colors.Secondary
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
  title.Size=UDim2.new(1,-128,0,44);title.TextSize=if root.AbsoluteSize.Y<260 then 14 else 20;close.Position=UDim2.new(1,-8,0,0)
  for i,name in {'KARTS','RACE ITEMS','MY INVENTORY'}do tabs[name].Position=UDim2.fromOffset(8+(i-1)*(l.tabWidth+4),l.tabsY);tabs[name].Size=UDim2.fromOffset(l.tabWidth,44)end
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
  if targetTab=='WINGS' then targetTab='KARTS' end
  if tabs[targetTab] then tab=targetTab end
  colorIndex=table.find(variants,p:GetAttribute('SelectedKartId')) or colorIndex;layout();render();request('PROFILE');return true
 end
 close.Activated:Connect(closeShop);no.Activated:Connect(function()confirmation.Visible=false;confirmAction=nil end)
 yes.Activated:Connect(function()
  if not confirmation.Visible or not confirmAction then return end
  local a=confirmAction;confirmation.Visible=false;confirmAction=nil
  request(a.action,a.item,a.value)
 end)
 for name,b in tabs do b.Activated:Connect(function()
  confirmation.Visible=false
  if name=='MY INVENTORY' and tab==name and Layout.forSize(root.AbsoluteSize).bodyHeight<140 then inventorySection=if inventorySection=='KARTS' then 'ITEMS' else 'KARTS' end
  tab=name;body.CanvasPosition=Vector2.zero;render()
 end)end
 root:GetPropertyChangedSignal('AbsoluteSize'):Connect(layout)
 for _,attr in {'KDMWalletCash','KDMWingOwned','KDMWingEquipped','KDMInventoryAutoRefill'}do
  p:GetAttributeChangedSignal(attr):Connect(function()
   data.cash=p:GetAttribute('KDMWalletCash');data.wingOwned=p:GetAttribute('KDMWingOwned')==true;data.wingEquipped=p:GetAttribute('KDMWingEquipped')==true
   for _,id in C.KartOrder do data.ownedKarts[id]=C.playerOwnsKart(p,id) end
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
