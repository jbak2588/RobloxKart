-- Execute the production Shop with the existing UI fixture, then exercise route ownership.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local shopFixture=fs.readFile('tests/economy_v2_arcade_shop_validation.luau')
local extra=[[
tap(panel.Close)
local context='LOBBY'
modules.G.shopContext=function()return if context=='BLOCKED' then nil else context end
modules.G.close=function()p:SetAttribute('HubOverlayOpen',false)end
modules.G.open=function(action)check(action=='KART','restore only kart Garage');garageOpen+=1;p:SetAttribute('HubOverlayOpen',true)end
local initial=garageOpen
check(shop.open('WINGS')==true,'Main Lobby opens existing Shop');flush();tap(panel.Close)
check(garageOpen==initial and not gui.Enabled,'Main Lobby close never opens Garage')
context='KART';p:SetAttribute('HubOverlayOpen',true)
check(shop.open('WINGS')==true and not p:GetAttribute('HubOverlayOpen'),'Garage suspends while Shop owns overlay');flush();tap(panel.Close)
check(garageOpen==initial+1 and p:GetAttribute('HubOverlayOpen'),'Garage close restores Kart context')
p:SetAttribute('HubOverlayOpen',false);context='BLOCKED'
check(shop.open()==false,'Track/Ready/pending selection context rejects Shop')
context='LOBBY'
for _,case in {{'RaceState','RACING','GARAGE'},{'LobbyDriveActive',true,false},{'LobbyDrivePending',true,false},{'KDMRoutePending','RACE_LAUNCH',''},{'KDMRoutePending','HUB_RETURN',''}}do
 p:SetAttribute(case[1],case[2]);local n=#calls
 check(shop.open()==false and not gui.Enabled and #calls==n,'unsafe route never opens or requests profile '..case[1])
 p:SetAttribute(case[1],case[3])
end
local rooms=child(pg,'ScreenGui','KDMMatchRooms');pg.ChildAdded:Fire(rooms);rooms.Enabled=true
check(shop.open()==false,'Room modal rejects Shop');rooms.Enabled=false
shop.open();flush();rooms.Enabled=true
check(not gui.Enabled and not p:GetAttribute('KDMShopOpen'),'Room opening closes Shop without Garage restore');rooms.Enabled=false
context='KART';p:SetAttribute('HubOverlayOpen',true);shop.open();flush();local beforeRestore=garageOpen
p:SetAttribute('KDMRoutePending','RACE_LAUNCH')
check(not gui.Enabled and garageOpen==beforeRestore,'launch closes Shop without resurrecting Garage');p:SetAttribute('KDMRoutePending','')
context='LOBBY';p:SetAttribute('HubOverlayOpen',false)
for _=1,8 do shop.open();flush();tap(panel.Close)end
check(#pg:GetChildren()==2,'repeated open has one Shop plus Room GUI only')
]]
local marker="local current=fs.readFile('src/client/GarageShopController.luau')"
assert(shopFixture:find(marker,1,true))
shopFixture=shopFixture:gsub(marker:gsub('([^%w])','%%%1'),function()return extra..'\n'..marker end,1)
shopFixture=shopFixture:gsub('artifacts/economy%-v2%-ui2%-r1/shop%-mock%-results.json','artifacts/economy-v2-ui2-r1/navigation-shop-results.json')
luau.load(shopFixture)()

-- Actual Hub buttons and original Garage context; no copied routing implementation.
local fixture=fs.readFile('tests/garage_transition_validation.luau')
local inject=[[
controller.close()
local shopCalls=0
child(client,'ModuleScript','GarageShopController')
modules.GarageShopController={open=function(target)check(target=='WINGS','Hub targets existing Wing tab');shopCalls+=1 end}
check(shortcuts.SHOP and shortcuts.SHOP.Activated.count()==1,'single Main Lobby SHOP handler')
check(controller.shopContext()=='LOBBY','Main Lobby distinct from Garage despite GARAGE RaceState')
shortcuts.SHOP.Activated:Fire();check(shopCalls==1,'Main Lobby directly calls single Shop API')
player:SetAttribute('LobbyDriveActive',true);shortcuts.SHOP.Activated:Fire()
check(shopCalls==1 and not shortcuts.SHOP.Visible,'driving retains old two shortcuts; no Shop')
player:SetAttribute('LobbyDriveActive',false)
player:SetAttribute('KDMRoutePending','HUB_RETURN');shortcuts.SHOP.Activated:Fire();check(shopCalls==1,'all pending routes reject Shop');player:SetAttribute('KDMRoutePending','')
controller.open('TRACKS');check(controller.shopContext()==nil,'Track overlay cannot be replaced with Shop');controller.close()
controller.open('KART');check(controller.shopContext()=='KART','Kart Garage has explicit return context')
backdrop.NextChoice.Activated:Fire();local previewBefore=backdrop.GarageChoice.Text;controller.close();controller.resumeAfterShop()
check(backdrop.GarageChoice.Text==previewBefore,'Shop return preserves uncommitted Kart preview');controller.close()
for _,size in {{706,281},{750,324},{648,223},{1142,628},{1280,662},{1920,1022}}do
 safeSize=rb.Vector2.new(unpack(size));hubGui.SafeCanvas:GetPropertyChangedSignal('AbsoluteSize'):Fire()
 local b=shortcuts.SHOP
 check(b.AbsoluteSize.Y>=44 and b.AbsoluteSize.X>=44,'44px Lobby Shop touch target')
 check(b.AbsolutePosition.X>=0 and b.AbsolutePosition.Y>=0 and b.AbsolutePosition.X+b.AbsoluteSize.X<=safeSize.X and b.AbsolutePosition.Y+b.AbsoluteSize.Y<=safeSize.Y,'Lobby Shop safe bounds')
 local guide=hubGui.SafeCanvas.NextAction
 check(guide.AbsolutePosition.Y+guide.AbsoluteSize.Y+8<=shortcuts.AbsolutePosition.Y,'guidance preserved above shortcuts')
end
]]
assert(fixture:find('hubGui:Destroy()',1,true))
fixture=fixture:gsub('hubGui:Destroy%(%)',function()return inject..'\nhubGui:Destroy()'end,1)
luau.load(fixture)()
