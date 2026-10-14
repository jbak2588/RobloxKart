local Controller={}
function Controller.start()
 local player=game:GetService('Players').LocalPlayer
 if workspace:GetAttribute('KDMServerRole')~='HUB' then return end
 local remote=game:GetService('ReplicatedStorage'):WaitForChild('KDMEconomy',10)
 if not remote then return end
 local gui=Instance.new('ScreenGui');gui.Name='KDMMyProfile';gui.ResetOnSpawn=false;gui.DisplayOrder=26
 gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Parent=player:WaitForChild('PlayerGui')
 local function button(parent,name,text,y)
  local b=Instance.new('TextButton');b.Name=name;b.Text=text;b.Size=UDim2.new(1,-24,0,44);b.Position=UDim2.fromOffset(12,y)
  b.BackgroundColor3=Color3.fromRGB(25,43,60);b.TextColor3=Color3.new(1,1,1);b.Font=Enum.Font.GothamBold;b.TextSize=14;b.Parent=parent
  return b
 end
 local badge=button(gui,'Profile','MY PROFILE / 내정보',12);badge.AnchorPoint=Vector2.new(1,0)
 badge.Size=UDim2.fromOffset(160,44);badge.Position=UDim2.new(1,-156,0,12)
 local panel=Instance.new('ScrollingFrame');panel.Name='Profile';panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5)
 panel.Size=UDim2.fromScale(.86,.82);panel.BackgroundColor3=Color3.fromRGB(15,25,39);panel.Visible=false
 panel.CanvasSize=UDim2.fromOffset(0,362);panel.ScrollBarThickness=6;panel.Parent=gui
 local limit=Instance.new('UISizeConstraint');limit.MaxSize=Vector2.new(440,362);limit.Parent=panel
 local text=Instance.new('TextLabel');text.Name='Account';text.Size=UDim2.new(1,-24,0,132);text.Position=UDim2.fromOffset(12,8)
 text.BackgroundTransparency=1;text.TextColor3=Color3.new(1,1,1);text.TextWrapped=true;text.TextXAlignment=Enum.TextXAlignment.Left
 text.Font=Enum.Font.Gotham;text.TextSize=16;text.Parent=panel
 local buy=button(panel,'BuyWing','KDM V2 WING · K$3,000',148)
 local equip=button(panel,'EquipWing','EQUIP WING',198)
 local pass=button(panel,'GamePass','50 Robux · COMING SOON',248)
 local close=button(panel,'Close','CLOSE',302)
 local dismiss=button(gui,'Dismiss','×',0);dismiss.Size=UDim2.fromOffset(44,44);dismiss.Visible=false;dismiss.ZIndex=4
 local busy,passAvailable=false,false
 local passPrice=nil
 local status=''
 local messages={FOUND='',SAVE_CONFIRMED='ACCOUNT SAVED',SAVE_UNCONFIRMED='Save not confirmed. Please try again.',
  INSUFFICIENT_FUNDS='You need K$3,000.',ALREADY_OWNED='Wing already owned.',NOT_OWNED='Unlock the Wing first.',
  ACCESS_BLOCKED='Economy preview is unavailable for this account.',RATE_LIMITED='Please wait a moment.',
  PASS_PROMPTED='Complete the Roblox purchase prompt.',HUB_REQUIRED='Return to the Lobby to purchase.'}
 local catalog=require(game:GetService('ReplicatedStorage').Shared.KartCatalog)
 local function render()
  local cash=player:GetAttribute('KDMWalletCash')
  badge.Text='MY PROFILE / 내정보\nK$ '..(if cash~=nil then tostring(cash) else '--')
  local id=player:GetAttribute('SelectedKartId') or catalog.DefaultId
  local kart=catalog.Entries[id]
  local owned=player:GetAttribute('KDMWingOwned')==true
  text.Text='MY PROFILE / 내정보\nK$ '..(if cash~=nil then tostring(cash) else '--')..'  |  EARNED K$ '..tostring(player:GetAttribute('KDMLifetimeEarned') or 0)
   ..'\nKART  '..(kart and kart.DisplayName or id)..'\nWING  '..(if owned then 'KDM V2 WING' else 'None')..'\n'..status
  buy.Active=not busy and not owned and cash~=nil and cash>=3000
  buy.Text=if owned then 'KDM V2 WING · OWNED' else 'KDM V2 WING · K$3,000'
  equip.Active=not busy and owned;equip.Text=if player:GetAttribute('KDMWingEquipped')==true then 'UNEQUIP WING' else 'EQUIP WING'
  pass.Active=not busy and not owned and passAvailable
  pass.Text=if passAvailable and passPrice then 'PERMANENT WING · '..passPrice..' Robux' else '50 Robux target · COMING SOON'
  pass.Active=pass.Active and passPrice~=nil
  for _,b in {buy,equip,pass} do b.TextTransparency=if b.Active then 0 else .5 end
 end
 local function invoke(action,value)
  if busy then return end
  busy=true;status=if action=='PROFILE' then 'Loading saved account...' else 'Saving...';render()
  task.spawn(function()
   local ok,r=pcall(function()return remote:InvokeServer(action,value)end)
   local code=if ok and type(r)=='table' then (r.purchaseState or r.status) else 'SAVE_UNCONFIRMED'
   status=messages[code] or 'Account unavailable. Please try again.'
   if ok and type(r)=='table' and r.passAvailable~=nil then passAvailable=r.passAvailable end
   if passAvailable and ok and type(r)=='table' and r.passId and r.passId>0 then
    local loaded,info=pcall(function()return game:GetService('MarketplaceService'):GetProductInfoAsync(r.passId,Enum.InfoType.GamePass)end)
    passPrice=if loaded and info.IsForSale and type(info.PriceInRobux)=='number' then info.PriceInRobux else nil
   end
   busy=false;render()
  end)
 end
 local function positionDismiss()
  dismiss.Visible=panel.Visible
  dismiss.Position=UDim2.fromOffset(panel.AbsolutePosition.X+panel.AbsoluteSize.X-48,panel.AbsolutePosition.Y+4)
 end
 panel:GetPropertyChangedSignal('AbsolutePosition'):Connect(positionDismiss)
 panel:GetPropertyChangedSignal('AbsoluteSize'):Connect(positionDismiss)
 panel:GetPropertyChangedSignal('Visible'):Connect(positionDismiss)
 badge.Activated:Connect(function()panel.Visible=not panel.Visible;player:SetAttribute('KDMProfileOpen',panel.Visible);if panel.Visible then invoke('PROFILE') end end)
 local function closeProfile()panel.Visible=false;player:SetAttribute('KDMProfileOpen',false)end
 close.Activated:Connect(closeProfile);dismiss.Activated:Connect(closeProfile)
 buy.Activated:Connect(function()if buy.Active then closeProfile();require(script.Parent.GarageShopController).open() end end)
 equip.Activated:Connect(function()if equip.Active then invoke('EQUIP_WING',player:GetAttribute('KDMWingEquipped')~=true) end end)
 pass.Activated:Connect(function()if pass.Active then invoke('PASS') end end)
 local function update()
  gui.Enabled=player:GetAttribute('RaceState')=='GARAGE' and player:GetAttribute('HubOverlayOpen')~=true
   and player:GetAttribute('KDMShopOpen')~=true
   and player:GetAttribute('LobbyDriveActive')~=true and player:GetAttribute('KDMRoutePending')~='RACE_LAUNCH'
  if not gui.Enabled then panel.Visible=false;player:SetAttribute('KDMProfileOpen',false) end
  render()
 end
 for _,name in {'RaceState','HubOverlayOpen','KDMShopOpen','LobbyDriveActive','KDMRoutePending','KDMWalletCash','KDMLifetimeEarned','KDMWingOwned','KDMWingEquipped','SelectedKartId'} do
  player:GetAttributeChangedSignal(name):Connect(update)
 end
 update()
end
return Controller
