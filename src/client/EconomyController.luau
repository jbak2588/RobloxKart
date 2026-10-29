local Controller = {}
-- Header uses the device-safe canvas; the modal retains CoreUISafeInsets.
function Controller.profileHeaderLayout(size, origin, topbar, coreInset)
 coreInset=coreInset or Vector2.zero
 local right=math.min(size.X-12,topbar.Max.X-coreInset.X-origin.X-8)
 local y=topbar.Min.Y+(topbar.Max.Y-topbar.Min.Y-44)*.5-coreInset.Y-origin.Y
 return math.max(104,right),math.clamp(y,0,math.max(0,size.Y-44))
end
-- Presentation only: values remain authoritative server attributes, never client balances.
function Controller.presentation(attributes, catalog)
 local revision = attributes.KDMWalletRevision
 local confirmed = (attributes.KDMEconomyState == 'FOUND' or attributes.KDMEconomyState == 'GUEST') and type(revision) == 'number'
  and revision >= 0 and revision < math.huge and revision % 1 == 0
 local function amount(value)
  return if confirmed and type(value) == 'number' and value >= 0 and value < math.huge and value % 1 == 0 then tostring(value) else '--'
 end
 local owned = if confirmed and type(attributes.KDMWingOwned) == 'boolean' then attributes.KDMWingOwned else nil
 local equipped = if owned ~= nil and type(attributes.KDMWingEquipped) == 'boolean' then attributes.KDMWingEquipped else nil
 local kart = catalog.Entries[attributes.SelectedKartId]
 return {
  cash = amount(attributes.KDMWalletCash), earned = amount(attributes.KDMLifetimeEarned),
  owned = owned, equipped = equipped,
  wing = if owned == nil then 'UNAVAILABLE' elseif not owned then 'NOT OWNED' elseif equipped == nil then 'OWNED / EQUIPMENT UNKNOWN' elseif equipped then 'OWNED / EQUIPPED' else 'OWNED / UNEQUIPPED',
  kart = if kart then kart.DisplayName else 'UNAVAILABLE',
  color = if kart then kart.DisplayColorName else '--',
 }
end
function Controller.start()
 local player = game:GetService('Players').LocalPlayer
 if workspace:GetAttribute('KDMServerRole') ~= 'HUB' then return end
 local playerGui = player:WaitForChild('PlayerGui')
 if playerGui:FindFirstChild('KDMMyProfile') then return end
 local remote = game:GetService('ReplicatedStorage'):WaitForChild('KDMEconomy', 10)
 if not remote then return end
 -- A second startup may have yielded on the same remote.
 if playerGui:FindFirstChild('KDMMyProfile') then return end
 local catalog = require(game:GetService('ReplicatedStorage').Shared.KartCatalog)
 local Style = require(script.Parent.ShopLayout)
 local StyleHelper = {
  applyCloseButton = function() end,
  apply3DButton = function() end,
  applyModalPanel = function() end,
 }
 pcall(function()
  local real = require(script.Parent.KDMUiStyleHelper)
  if real then StyleHelper = real end
 end)
 local colors = Style.colors()
 local gui = Instance.new('ScreenGui'); gui.Name = 'KDMMyProfile'; gui.ResetOnSpawn = false; gui.DisplayOrder = 26
 gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets; gui.Parent = playerGui
 local headerGui=Instance.new('ScreenGui');headerGui.Name='KDMProfileHeader';headerGui.ResetOnSpawn=false;headerGui.DisplayOrder=26
 headerGui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets;headerGui.Parent=playerGui
 local headerCanvas=Instance.new('Frame');headerCanvas.Name='DeviceSafeCanvas';headerCanvas.Size=UDim2.fromScale(1,1)
 headerCanvas.BackgroundTransparency=1;headerCanvas.BorderSizePixel=0;headerCanvas.Parent=headerGui
 local function label(parent, name, text, y, height, size)
  local t = Instance.new('TextLabel'); t.Name = name; t.Text = text
  t.Position = UDim2.fromOffset(16, y); t.Size = UDim2.new(1, -40, 0, height)
  t.BackgroundTransparency = 1; t.TextColor3 = colors.White
  t.TextWrapped = true; t.TextXAlignment = Enum.TextXAlignment.Left
  t.Font = Enum.Font.Gotham; t.TextSize = size or 15; t.ZIndex = 11; t.Parent = parent
  return t
 end
 local function button(parent, name, text, y)
  local b = Instance.new('TextButton'); b.Name = name; b.Text = text
  b.Position = UDim2.fromOffset(16, y); b.Size = UDim2.new(1, -40, 0, 44)
  b.BackgroundColor3 = colors.Card; b.TextColor3 = Color3.new(1, 1, 1)
  b.Font = Enum.Font.GothamBold; b.TextSize = 14; b.TextWrapped = true; b.ZIndex = 11; b.Parent = parent
  Style.style(b)
  return b
 end
 -- Align with the native TopBar row without changing the profile modal's insets.
 local badge = Instance.new('TextButton')
 badge.Name = 'Profile'
 badge.Text = 'MY PROFILE'
 badge.AnchorPoint = Vector2.new(1, 0)
 badge.Position = UDim2.fromOffset(0, 0)
 badge.Size = UDim2.fromOffset(104, 44)
 badge.BackgroundTransparency = 1
 badge.BorderSizePixel = 0
 badge.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
 badge.TextColor3 = Color3.fromRGB(240, 245, 252)
 badge.Font = Enum.Font.GothamBold
 badge.TextSize = 13
 badge.TextStrokeTransparency = 1
 badge.ZIndex = 1
 badge.Parent = headerCanvas
 local guiService=game:GetService('GuiService')
 local function layoutHeader()
  local x,y=Controller.profileHeaderLayout(headerCanvas.AbsoluteSize,headerCanvas.AbsolutePosition,guiService.TopbarInset,guiService:GetGuiInset())
  badge.Position=UDim2.fromOffset(x,y)
  badge.TextSize=if headerCanvas.AbsoluteSize.X>=1200 then 15 else 13
 end
 local headerConnections={headerCanvas:GetPropertyChangedSignal('AbsoluteSize'):Connect(layoutHeader),
  headerCanvas:GetPropertyChangedSignal('AbsolutePosition'):Connect(layoutHeader),guiService:GetPropertyChangedSignal('TopbarInset'):Connect(layoutHeader)}
 gui.Destroying:Connect(function()
  for _,c in headerConnections do c:Disconnect() end
  headerGui:Destroy()
 end)
 layoutHeader()
 local shade = Instance.new('TextButton'); shade.Name = 'Backdrop'; shade.Text = ''; shade.Position=UDim2.fromScale(-1,-1);shade.Size = UDim2.fromScale(3, 3)
 shade.BackgroundColor3 = Color3.fromRGB(18, 34, 64); shade.BackgroundTransparency = .82
 shade.Visible = false; shade.Modal = true; shade.AutoButtonColor = false; shade.ZIndex = 9; shade.Parent = gui
 local panel = Instance.new('Frame'); panel.Name = 'DriverCard'; panel.AnchorPoint = Vector2.new(.5, .5)
 panel.Position = UDim2.fromScale(.5, .5); panel.Size = UDim2.fromScale(.92, .94)
 panel.BackgroundColor3 = colors.Background; panel.BorderSizePixel = 0
 panel.Visible = false; panel.ZIndex = 10; panel.Parent = gui; Style.style(panel, 'Background')
 local limit = Instance.new('UISizeConstraint'); limit.MaxSize = Vector2.new(760, 650); limit.Parent = panel
 local title = label(panel, 'Title', 'MY PROFILE', 5, 26, 21); title.Font = Enum.Font.GothamBold
 title.Size = UDim2.new(1, -80, 0, 28)
 local subtitle = label(panel, 'Subtitle', 'DRIVER CARD  /  FREE COLOR COLLECTION', 30, 18, 11)
 local dismiss = button(panel, 'Dismiss', 'X', 6); dismiss.AnchorPoint = Vector2.new(1, 0)
 dismiss.Position = UDim2.new(1, -8, 0, 6); dismiss.Size = UDim2.fromOffset(40, 40); dismiss.ZIndex = 12
 StyleHelper.applyCloseButton(dismiss)
 local body = Instance.new('ScrollingFrame'); body.Name = 'Details'; body.Position = UDim2.fromOffset(0, 54)
 body.Size = UDim2.new(1, 0, 1, -114); body.BackgroundTransparency = 1; body.BorderSizePixel = 0
 body.CanvasSize = UDim2.fromOffset(0, 658); body.ScrollBarThickness = 6
 body.ScrollingDirection = Enum.ScrollingDirection.Y; body.Active = true; body.ZIndex = 11; body.Parent = panel
 -- Match the Shop's owned-touch scrolling, including short simulator gestures.
 local inputService = game:GetService('UserInputService')
 local scrollTouch, scrollStart, scrollOrigin = nil, 0, 0
 local draggedAt = -math.huge
 body.InputBegan:Connect(function(input)
  if input.UserInputType == Enum.UserInputType.Touch and not scrollTouch then
   scrollTouch = input; scrollStart = input.Position.Y; scrollOrigin = body.CanvasPosition.Y
  end
 end)
 inputService.InputChanged:Connect(function(input)
  if input ~= scrollTouch or not gui.Enabled or not panel.Visible then return end
  local delta = scrollStart - input.Position.Y
  if math.abs(delta) > 8 then
   draggedAt = os.clock()
   body.CanvasPosition = Vector2.new(0, math.clamp(scrollOrigin + delta, 0, math.max(0, body.AbsoluteCanvasSize.Y - body.AbsoluteWindowSize.Y)))
  end
 end)
 inputService.InputEnded:Connect(function(input) if input == scrollTouch then scrollTouch = nil end end)
 local function actionTap() return os.clock() - draggedAt > .25 end
 local function surface(name,y,height)
  local f=Instance.new('Frame');f.Name=name;f.Position=UDim2.fromOffset(12,y);f.Size=UDim2.new(1,-32,0,height)
  f.ZIndex=10;f.Parent=body;Style.style(f);return f
 end
 local driver = label(body, 'Driver', '', 0, 24, 20); driver.Font = Enum.Font.GothamBold
 local kart = label(body, 'Kart', '', 24, 24, 14);kart.TextColor3=colors.Secondary
 local identity=Instance.new('Frame');identity.Name='DriverIdentity';identity.Size=UDim2.fromOffset(40,40);identity.Position=UDim2.fromOffset(16,0);identity.ZIndex=11;identity.Parent=body;Style.style(identity,'Light')
 local initials=label(identity,'Fallback','',0,40,20);initials.Position=UDim2.fromOffset(0,0);initials.Size=UDim2.fromScale(1,1);initials.TextXAlignment=Enum.TextXAlignment.Center;initials.TextColor3=colors.Cyan;initials.ZIndex=12
 local avatar=Instance.new('ImageLabel');avatar.Name='RobloxAvatar';avatar.Size=UDim2.fromScale(1,1);avatar.BackgroundTransparency=1;avatar.Visible=false;avatar.ZIndex=12;avatar.Parent=identity
 local thumbnailRequested=false
 local function loadThumbnail()
  if thumbnailRequested or type(player.UserId)~='number' or player.UserId<=0 then return end
  thumbnailRequested=true
  task.spawn(function()
   local ok,content,ready=pcall(function()return game:GetService('Players'):GetUserThumbnailAsync(player.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150)end)
   if not avatar.Parent or not ok or not ready or type(content)~='string' or content=='' then return end
   avatar.Image=content
   local function loaded()if avatar.Parent then avatar.Visible=avatar.IsLoaded;initials.Visible=not avatar.IsLoaded end end
   avatar:GetPropertyChangedSignal('IsLoaded'):Connect(loaded);loaded()
  end)
 end
 local availableCard=surface('AvailableCashCard',54,66);availableCard.Size=UDim2.new(.5,-20,0,66)
 local lifetimeCard=surface('RaceEarningsCard',54,66);lifetimeCard.Position=UDim2.new(.5,0,0,54);lifetimeCard.Size=UDim2.new(.5,-20,0,66)
 local wallet = label(body, 'Wallet', '', 58, 58, 20); wallet.Font = Enum.Font.GothamBold
 wallet.Size=UDim2.new(.5,-28,0,58);wallet.TextColor3=colors.Yellow
 local earnings = label(body, 'LifetimeRaceEarnings', '', 58, 58, 16);earnings.Font=Enum.Font.GothamBold
 earnings.Position=UDim2.new(.5,8,0,58);earnings.Size=UDim2.new(.5,-36,0,58)
 local wing = label(body, 'Wing', '', 126, 28, 13)
 local heading = label(body, 'Collection', 'KDM V2 · KART COLLECTION', 166, 28, 14); heading.Font = Enum.Font.GothamBold
 local variants = {}
 for _, id in catalog.Order do
  local entry = catalog.Entries[id]
  if entry.VisualModelName == 'KDMV2' then
   local index = #variants
   local tile = Instance.new('Frame'); tile.Name = id; tile.Size = UDim2.new(.25, -16, 0, 68)
   tile.Position = UDim2.new((index % 4) * .25, 12, 0, 204 + math.floor(index / 4) * 78)
   tile.ZIndex = 11; tile.Parent = body;local border=Style.style(tile)
   local swatch = Instance.new('Frame'); swatch.Name = 'Swatch'; swatch.BackgroundColor3 = entry.DisplayColor
   swatch.BorderSizePixel = 0; swatch.Size = UDim2.new(1, -12, 0, 18); swatch.Position = UDim2.fromOffset(6, 6); swatch.ZIndex = 12; swatch.Parent = tile
   local name = label(tile, 'ColorName', entry.DisplayColorName, 25, 25, 12)
   name.Position = UDim2.fromOffset(3,25); name.Size = UDim2.new(1, -6, 0, 25); name.ZIndex = 12
   name.TextXAlignment = Enum.TextXAlignment.Center
   local free=label(tile,'Availability','FREE',49,16,10);free.Position=UDim2.fromOffset(3,49);free.Size=UDim2.new(1,-6,0,16)
   free.TextXAlignment=Enum.TextXAlignment.Center;free.ZIndex=12;free.TextColor3=colors.Secondary
   table.insert(variants, {id = id, tile = tile, name = name, entry = entry, border=border})
  end
 end
 local selection = label(body, 'Selection', '', 358, 28, 13)
 surface('WingEquipmentCard',396,184)
 label(body,'WingEquipmentTitle','PERMANENT KDM V2 KARTS',402,24,16).Font=Enum.Font.GothamBold
 local wingPrice=label(body,'WingPrice','K$50,000 per color · Wing included',430,24,14);wingPrice.TextColor3=colors.Yellow
 local shop = button(body, 'OpenShop', 'GO TO SHOP', 464);shop.Size=UDim2.new(.5,-24,0,44)
 local buy = button(body, 'BuyWing', 'BUY · K$50,000', 464);buy.Position=UDim2.new(.5,0,0,464);buy.Size=UDim2.new(.5,-24,0,44)
 StyleHelper.apply3DButton(buy, Color3.fromRGB(255, 235, 90), Color3.fromRGB(255, 195, 25), Color3.fromRGB(215, 140, 0), 12, 2.5)
 local equip = button(body, 'EquipWing', 'EQUIP WING', 464);equip.Position=buy.Position;equip.Size=buy.Size
 StyleHelper.apply3DButton(equip, Color3.fromRGB(80, 190, 255), Color3.fromRGB(0, 140, 240), Color3.fromRGB(0, 95, 200), 12, 2.5)
 local pass = button(body, 'GamePass', '50 Robux target · COMING SOON', 522)
 label(body, 'Career', 'CAREER · COMING SOON\nRanks and achievements are not active yet.', 596, 48, 13).TextColor3=colors.Secondary
 local statusLabel = label(panel, 'Status', '', 0, 48, 12)
 statusLabel.Position = UDim2.new(0, 16, 1, -56); statusLabel.Size = UDim2.new(1, -112, 0, 48)
 local close = button(panel, 'Close', 'CLOSE', 0); close.AnchorPoint = Vector2.new(1, 1)
 close.Position = UDim2.new(1, -12, 1, -10); close.Size = UDim2.fromOffset(90, 44)
 StyleHelper.apply3DButton(close, Color3.fromRGB(120, 140, 170), Color3.fromRGB(70, 90, 120), Color3.fromRGB(40, 60, 90), 12, 2.5)
 local function layoutProfile()
  local compact=panel.AbsoluteSize.Y<440
  body.Position=UDim2.fromOffset(0,if compact then 44 else 54)
  body.Size=UDim2.new(1,0,1,if compact then -100 else -114)
  subtitle.Position=UDim2.fromOffset(16,if compact then 28 else 30)
  subtitle.Size=UDim2.new(1,-40,0,if compact then 12 else 18);subtitle.TextSize=if compact then 10 else 11
  driver.TextSize=if compact then 18 else 20;driver.Position=UDim2.fromOffset(68,0);driver.Size=UDim2.new(1,-92,0,24)
  kart.Position=UDim2.fromOffset(68,24);kart.Size=UDim2.new(1,-92,0,if compact then 20 else 24)
  availableCard.Position=UDim2.fromOffset(12,if compact then 46 else 54);availableCard.Size=UDim2.new(.5,-20,0,if compact then 44 else 66)
  lifetimeCard.Position=UDim2.new(.5,0,0,if compact then 46 else 54);lifetimeCard.Size=availableCard.Size
  wallet.Position=UDim2.fromOffset(22,if compact then 48 else 58);wallet.Size=UDim2.new(.5,-34,0,if compact then 40 else 58);wallet.TextSize=if compact then 18 else 24
  earnings.Position=UDim2.new(.5,8,0,if compact then 48 else 58);earnings.Size=UDim2.new(.5,-36,0,if compact then 40 else 58);earnings.TextSize=if compact then 12 else 16
  wing.Position=UDim2.fromOffset(16,if compact then 94 else 126);wing.Size=UDim2.new(1,-40,0,if compact then 14 else 28);wing.TextSize=if compact then 11 else 13
  heading.Position=UDim2.fromOffset(16,if compact then 124 else 166)
  for index,v in variants do v.tile.Position=UDim2.new(((index-1)%4)*.25,12,0,(if compact then 158 else 204)+math.floor((index-1)/4)*78)end
 end
 panel:GetPropertyChangedSignal('AbsoluteSize'):Connect(layoutProfile)
 layoutProfile()
 local busy, passAvailable, passPrice, status = false, false, nil, ''
 local messages = {GUEST='Finish 2 TIME ATTACK laps to earn K$5,000.', FOUND = '', SAVE_CONFIRMED = 'ACCOUNT SAVED', SAVE_UNCONFIRMED = 'Save not confirmed. Please try again.',
  INSUFFICIENT_FUNDS = 'You need K$50,000.', ALREADY_OWNED = 'Wing already owned.', NOT_OWNED = 'Unlock the Wing first.',
  ACCESS_BLOCKED = 'Account unavailable. Shop preview is still available.', RATE_LIMITED = 'Please wait a moment.',
  PASS_PROMPTED = 'Complete the Roblox purchase prompt.', HUB_REQUIRED = 'Return to the Lobby to purchase.'}
 local attributes = {'KDMWalletCash', 'KDMLifetimeEarned', 'KDMWingOwned', 'KDMWingEquipped', 'KDMWalletRevision', 'KDMEconomyState', 'SelectedKartId'}
 local function render()
  local a = {}; for _, name in attributes do a[name] = player:GetAttribute(name) end
  local view = Controller.presentation(a, catalog)
  badge.Text = 'MY PROFILE'
  driver.Text = player.DisplayName
  initials.Text=string.upper(string.sub(player.DisplayName,1,1))
  kart.Text = 'KART · '..view.kart
  wallet.Text = 'AVAILABLE K$\n'..view.cash
  earnings.Text = 'LIFETIME EARNINGS\nK$ '..view.earned
  wing.Text = if view.owned==nil then 'SELECTED KART · UNAVAILABLE' elseif view.owned then 'SELECTED KART · OWNED PERMANENTLY' else 'SELECTED KART · FREE RENTAL'
  selection.Text = 'SELECTED COLOR · '..view.color..'  /  '..(if view.owned then 'OWNED KART' else 'FREE RENTAL')
  for _, v in variants do
   local selected = a.SelectedKartId == v.id
   v.tile.BackgroundColor3 = if selected then colors.Light else colors.Card
   v.border.Color=if selected then colors.Cyan else colors.Secondary
   v.border.Thickness=if selected then 2 else 1;v.border.Transparency=if selected then 0 else .7
   local owned=player:GetAttribute('KDMOwned'..v.id)==true
   v.tile.Availability.Text=if owned then 'OWNED · WITH WING' else 'FREE RENTAL'
   v.name.Text = (if selected then '✓ ' else '')..v.entry.DisplayColorName
  end
  buy.Active = not busy and view.owned == false and view.cash ~= '--' and tonumber(view.cash) >= 50000
  buy.Text = 'BUY · K$50,000'
  buy.Visible=view.owned~=true;equip.Visible=view.owned==true
  equip.Active = not busy and view.owned == true and view.equipped ~= nil
  equip.Text = if view.equipped == true then 'UNEQUIP WING' else 'EQUIP WING'
  pass.Active = not busy and view.owned == false and passAvailable and passPrice ~= nil
  pass.Text = if passAvailable and passPrice then 'PERMANENT WING · '..passPrice..' Robux' else '50 Robux target · COMING SOON'
  buy.Visible=false;equip.Visible=false;pass.Visible=false
  buy.Active=false;equip.Active=false;pass.Active=false
  shop.Size=UDim2.new(1,-32,0,44);shop.Text='VIEW KARTS / BUY'
  shop.Active = not busy
  for _, b in {buy, equip, pass, shop} do b.TextTransparency = if b.Active then 0 else .5 end
  statusLabel.Text = if status ~= '' then status elseif view.cash == '--' then 'ACCOUNT UNAVAILABLE · --' else 'SERVER-CONFIRMED ACCOUNT'
 end
 local function closeProfile()
  scrollTouch = nil
  panel.Visible = false; shade.Visible = false; badge.Visible = true; player:SetAttribute('KDMProfileOpen', false)
 end
 local function invoke(action, value)
  if busy then return end
  busy = true; status = if action == 'PROFILE' then 'Loading saved account...' else 'Saving...'; render()
  task.spawn(function()
   local ok, response = pcall(function() return remote:InvokeServer(action, value) end)
   local code = if ok and type(response) == 'table' then (response.purchaseState or response.status) else 'SAVE_UNCONFIRMED'
   status = messages[code] or 'Account unavailable. Please try again.'
   if ok and type(response) == 'table' and response.passAvailable ~= nil then passAvailable = response.passAvailable == true end
   if passAvailable and ok and type(response) == 'table' and type(response.passId) == 'number' and response.passId > 0 then
    local loaded, info = pcall(function() return game:GetService('MarketplaceService'):GetProductInfoAsync(response.passId, Enum.InfoType.GamePass) end)
    passPrice = if loaded and type(info) == 'table' and info.IsForSale and type(info.PriceInRobux) == 'number' then info.PriceInRobux else nil
   elseif not passAvailable then passPrice = nil end
   busy = false; render()
  end)
 end
 badge.Activated:Connect(function()
  if not gui.Enabled then return end
  panel.Visible = true; shade.Visible = true; badge.Visible = false; body.CanvasPosition = Vector2.zero
  loadThumbnail()
  player:SetAttribute('KDMProfileOpen', true); invoke('PROFILE')
 end)
 close.Activated:Connect(closeProfile); dismiss.Activated:Connect(closeProfile)
 local function openShop()
  closeProfile(); require(script.Parent.GarageShopController).open('KARTS')
 end
 shop.Activated:Connect(function() if shop.Active and actionTap() then openShop() end end)
 buy.Activated:Connect(function() if buy.Active and actionTap() then openShop() end end)
 equip.Activated:Connect(function() if equip.Active and actionTap() then openShop() end end)
 pass.Activated:Connect(function() if pass.Active and actionTap() then openShop() end end)
 local function update()
  gui.Enabled = player:GetAttribute('RaceState') == 'GARAGE' and player:GetAttribute('HubOverlayOpen') ~= true
   and player:GetAttribute('KDMShopOpen') ~= true and player:GetAttribute('LobbyDriveActive') ~= true
   and player:GetAttribute('KDMRoutePending') ~= 'RACE_LAUNCH'
  headerGui.Enabled=gui.Enabled
  if not gui.Enabled then closeProfile() end
  render()
 end
 for _, name in {'RaceState', 'HubOverlayOpen', 'KDMShopOpen', 'LobbyDriveActive', 'KDMRoutePending'} do
  player:GetAttributeChangedSignal(name):Connect(update)
 end
 for _, name in attributes do player:GetAttributeChangedSignal(name):Connect(update) end
 player:GetPropertyChangedSignal('DisplayName'):Connect(render)
 update()
end
return Controller
