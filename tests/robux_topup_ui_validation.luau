local fs,luau=require('@lune/fs'),require('@lune/luau')
local fixture=fs.readFile('tests/mobile_touch_validation.luau')
local prefix=fixture:sub(1,assert(fixture:find('local input=modules.KartInputController; input.start()',1,true))-1)
local loader=require('./helpers/gameplay_config')
luau.load(prefix..[=[
env.workspace=object('Workspace');env.workspace:SetAttribute('KDMServerRole','HUB')
player.UserId=7;player:SetAttribute('RaceState','GARAGE');player:SetAttribute('KDMWalletCash',1000)
local topup=child(services.ReplicatedStorage,'RemoteFunction','KDMRobuxTopUp')
local prompts=0
topup.InvokeServer=function(_,action,sku)
 if action=='LIST' then return {canPurchase=true,status='READY',offers={{sku='Cash25000',amount=25000,productId=1,baseRobux=50},{sku='Cash60000',amount=60000,productId=2,baseRobux=100}}}end
 check(action=='PROMPT' and (sku=='Cash25000' or sku=='Cash60000'),'client selects SKU only');prompts+=1;return {status='PROMPTED'}
end
services.MarketplaceService={GetProductInfoAsync=function(_,id)return {PriceInRobux=if id==1 then 50 else 100,IsForSale=true}end,PromptProductPurchaseFinished=signal()}
env.task.spawn=function(f)f()end
local C=luau.load(fs.readFile('src/client/RobuxTopUpController.luau'),{environment=env})()
check(C.open(),'Hub wallet opens top-up')
local g=pg.KDMRobuxTopUp;local panel=g.SafeCanvas.Panel
check(g.DisplayOrder>35,'modal above existing shop')
check(panel.Cash25000.Text=='K$ 25,000  ·  50 Robux' and panel.Cash60000.Text=='K$ 60,000  ·  100 Robux','confirmed offerings and fetched Robux prices')
for _,size in {V2.new(600,240),V2.new(740,360),V2.new(320,600),V2.new(1600,739)}do
 safeSize=size;g.SafeCanvas:GetPropertyChangedSignal('AbsoluteSize'):Fire()
 check(panel.Cash25000.AbsoluteSize.Y==44 and panel.Cash60000.AbsoluteSize.Y==44,'44px purchase hitboxes')
 check(panel.Cash25000.AbsolutePosition.Y+44<=panel.Cash60000.AbsolutePosition.Y,'targets separate')
 check(panel.Cash60000.AbsolutePosition.Y+44<=panel.Status.AbsolutePosition.Y,'status clears lower purchase target')
 check(panel.AbsolutePosition.X>=12 and panel.AbsolutePosition.X+panel.AbsoluteSize.X<=size.X-12,'safe horizontal placement')
end
panel.Cash25000.Activated:Fire();check(prompts==1 and player:GetAttribute('KDMWalletCash')==1000,'click does not credit local balance')
panel.Cash60000.Activated:Fire();check(prompts==1,'busy blocks double prompt')
services.MarketplaceService.PromptProductPurchaseFinished:Fire(7,1,false)
check(player:GetAttribute('KDMWalletCash')==1000 and panel.Status.Text=='Purchase cancelled.','cancel never grants')
panel.Cash60000.Activated:Fire();services.MarketplaceService.PromptProductPurchaseFinished:Fire(7,2,true)
check(player:GetAttribute('KDMWalletCash')==1000 and panel.Status.Text:find('Waiting',1,true),'prompt success awaits receipt')
player:SetAttribute('KDMWalletCash',61000);player:SetAttribute('KDMTopUpSerial',1)
check(panel.Status.Text=='K$ added. Balance saved.' and panel.Wallet.Text:find('61000',1,true),'only server saved attributes update view')
panel.Close.Activated:Fire();check(not g.Enabled and player:GetAttribute('KDMTopUpOpen')==false,'close lifecycle')
player:SetAttribute('KDMShopOpen',true);check(C.open(),'top-up can overlay shop')
player:SetAttribute('LobbyDriveActive',true);check(not g.Enabled and not C.open(),'no purchases during driving')
player:SetAttribute('LobbyDriveActive',false);player:SetAttribute('RaceState','RACING');check(not C.open(),'no race opening')
player:SetAttribute('RaceState','GARAGE');player:SetAttribute('HubOverlayOpen',true);check(not C.open(),'other full Hub overlay guarded')
print('PASS '..count..' top-up actual-controller UI, mobile bounds, cancellation, receipt wait and lifecycle checks')
]=],{environment={require=function(path)if path=='./helpers/gameplay_config'then return loader end;return require(path)end}})()
