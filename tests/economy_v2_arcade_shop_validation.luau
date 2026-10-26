-- lune run tests/garage_transition_validation.luau
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local count = 0
local function check(value, label) assert(value, label); count += 1 end
local function signal()
	local listeners = {}
	return { Connect = function(_, callback)
		local entry = {callback = callback, active = true}
		table.insert(listeners, entry)
		return { Disconnect = function() entry.active = false end }
	end, Fire = function(_, ...) for _, entry in listeners do if entry.active then entry.callback(...) end end end, count = function() local n=0; for _, entry in listeners do if entry.active then n+=1 end end; return n end }
end
local methods = {}
local safeSize = rb.Vector2.new(844, 390)
local cameraScreenSize = safeSize
local camera
local coreInsetY = 58
local function object(class, name)
	local props = { ClassName = class, Name = name or class, Size = rb.UDim2.fromScale(1, 1),
		Position = rb.UDim2.fromScale(0, 0), Visible = true, Enabled = true, CanvasPosition=rb.Vector2.zero,
		FocusLost = signal(), Activated = signal(), OnClientEvent = signal(), CharacterAdded = signal(), ChildAdded = signal(), CharacterRemoving = signal(), Destroying = signal(), InputBegan = signal(), InputChanged = signal(), InputEnded = signal(), WindowFocusReleased = signal() }
	return setmetatable({ _p = props, _children = {}, _attrs = {}, _signals = {}, _properties = {} }, {
		__index = function(self, key)
			if methods[key] then return methods[key] end
			if key == "AbsoluteCanvasSize" then return rb.Vector2.new(props.CanvasSize.X.Offset,props.CanvasSize.Y.Offset)end
 if key == "AbsoluteWindowSize" then return self.AbsoluteSize end
 if key == "AbsoluteContentSize" and class == "UIListLayout" then
				local height, items = 0, 0
				for _, item in props.Parent:GetChildren() do
					if item.ClassName == "TextLabel" or item.ClassName == "Frame" then height += item.AbsoluteSize.Y; items += 1 end
				end
				return rb.Vector2.new(props.Parent.AbsoluteSize.X,
					height + math.max(0, items - 1) * props.Padding.Offset)
			end
            if key == "AbsolutePosition" then
                if class=="ScreenGui" or not props.Parent then
                    if props.Name=="GarageTopHeader" or props.IgnoreGuiInset then
                        local device = if camera then (cameraScreenSize-camera.ViewportSize)*.5 else rb.Vector2.zero
                        return rb.Vector2.new(-device.X,-coreInsetY-device.Y)
                    end
                    return rb.Vector2.zero
                end
                local parent=props.Parent.AbsoluteSize
                local anchor=props.AnchorPoint or rb.Vector2.zero
                return props.Parent.AbsolutePosition+rb.Vector2.new(parent.X*props.Position.X.Scale+props.Position.X.Offset-self.AbsoluteSize.X*anchor.X,
                    parent.Y*props.Position.Y.Scale+props.Position.Y.Offset-self.AbsoluteSize.Y*anchor.Y)
            end
			if key == "AbsoluteSize" then
				if class == "ScreenGui" or not props.Parent then
                    if props.Name == "GarageTopHeader" then
                        if props.Enabled == false and self._lastCanvasSize then return self._lastCanvasSize end
                        rawset(self,"_lastCanvasSize",cameraScreenSize)
                        return cameraScreenSize
                    end
                    return safeSize
                end
				local parent = props.Parent.AbsoluteSize
				local size=rb.Vector2.new(parent.X * props.Size.X.Scale + props.Size.X.Offset,
					parent.Y * props.Size.Y.Scale + props.Size.Y.Offset)
				for _,child in self._children do
					if child.ClassName=="UISizeConstraint" then
						local min=child.MinSize or rb.Vector2.zero
						local max=child.MaxSize or rb.Vector2.new(math.huge,math.huge)
						size=rb.Vector2.new(math.clamp(size.X,min.X,max.X),math.clamp(size.Y,min.Y,max.Y))
					end
				end
				return size
			end
			if props[key] ~= nil then return props[key] end
			return self:FindFirstChild(key)
		end,
		__newindex = function(self, key, value)
			local old = props[key]
			if key == "Parent" then
				if old then local index = table.find(old._children, self); if index then table.remove(old._children, index) end end
				if value then table.insert(value._children, self) end
			end
			props[key] = value
			if class == "ScreenGui" and key == "ScreenInsets" then props.IgnoreGuiInset = value == rb.Enum.ScreenInsets.None end
			if class == "ScreenGui" and key == "IgnoreGuiInset" and value then props.ScreenInsets = rb.Enum.ScreenInsets.None end
			if old ~= value and self._properties[key] then self._properties[key]:Fire() end
			if old ~= value and key == "Size" and self._properties.AbsoluteSize then
				self._properties.AbsoluteSize:Fire()
			end
		end,
	})
end
function methods:FindFirstChild(name, recursive)
	for _, child in self._children do if child.Name == name then return child end end
	if recursive then
		for _, child in self._children do
			local found = child:FindFirstChild(name, true)
			if found then return found end
		end
	end
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name), name) end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants()
 local result={}; for _, item in self:GetChildren() do table.insert(result,item); for _, descendant in item:GetDescendants() do table.insert(result,descendant) end end; return result
end
function methods:HasAppearanceLoaded() return true end
function methods:PivotTo() end
function methods:GetBoundingBox()
 if self.Name=="PreviewKart" then return rb.CFrame.identity,rb.Vector3.new(8,2,10) end
 return rb.CFrame.new(0, -.4, 0), rb.Vector3.new(4, 6.5, 2) end
function methods:Clone()
 local copy = object(self.ClassName, self.Name)
 if self.ClassName=="Part" then copy.Size=self.Size; copy.CFrame=self.CFrame; copy.Transparency=self.Transparency end
 for _, item in self:GetChildren() do item:Clone().Parent = copy end
 return copy
end
function methods:IsA(name) return self.ClassName == name or (name == "BasePart" and self.ClassName == "Part") end
function methods:Destroy() self.Destroying:Fire(); self.Parent = nil end
function methods:GetAttribute(name) return self._attrs[name] end
function methods:SetAttribute(name, value)
	local old = self._attrs[name]
	self._attrs[name] = value
	if old ~= value and self._signals[name] then self._signals[name]:Fire() end
end
function methods:GetAttributeChangedSignal(name)
	if not self._signals[name] then self._signals[name] = signal() end
	return self._signals[name]
end
function methods:GetPropertyChangedSignal(name)
	if not self._properties[name] then self._properties[name] = signal() end
	return self._properties[name]
end
function methods:ReleaseFocus() self.FocusLost:Fire(false) end
function methods:FireServer(...) self.lastFire = { ... }; self.fireCount = (self.fireCount or 0) + 1 end
local function child(parent, class, name) local item = object(class, name); item.Parent = parent; return item end

local function load(path,env)return luau.load(fs.readFile(path),{environment=env or {},debugName=path})()end
local p=object('Player','LocalPlayer');p:SetAttribute('RaceState','GARAGE')
local pg=child(p,'PlayerGui','PlayerGui');local ws=object('Workspace');ws:SetAttribute('KDMServerRole','HUB')
local rs=object('ReplicatedStorage');local shared=child(rs,'Folder','Shared');local remote=child(rs,'RemoteFunction','KDMShop')
local input=object('UserInputService');local queue,delays,calls={}, {}, {};local guid=0
local response={status='FOUND',cash=805,wingOwned=false,wingEquipped=false,ownedKarts={},counts={Nitro=0,Thunder=3},canPurchase=true,autoRefill=false,passAvailable=false}
function remote:InvokeServer(action,...)
 if action=='PREPARE' then guid+=1;return {status='PREPARED',id=string.format('12345678-1234-1234-1234-%012d',guid)} end
 table.insert(calls,{action,...});return response
end
local catalog=load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum})
local shopCatalog=load('src/shared/KDMShopCatalog.luau')
local style=load('src/client/ShopLayout.luau',{Color3=rb.Color3,Instance={new=object},UDim=rb.UDim,Enum=rb.Enum})
local icons=load('src/client/KDMIconCatalog.luau')
local previews={};local garageOpen=0
local modules={Helper={applyCloseButton=function()end,apply3DButton=function()end},C=shopCatalog,K=catalog,Style=style,Icons=icons,G={close=function()end,open=function()garageOpen+=1 end},
 Factory={createVisual=function(entry,wing)table.insert(previews,{id=entry.Id,wing=wing});return object('Model','PreviewKart')end},
 Framing={fit=function()return rb.CFrame.identity end}}
shared.KDMShopCatalog='C';shared.KartCatalog='K';shared.KartVisualFactory='Factory';shared.KartPreviewFraming='Framing'
local env={game={GetService=function(_,name)
 if name=='Players'then return {LocalPlayer=p}elseif name=='ReplicatedStorage'then return rs elseif name=='UserInputService'then return input
 elseif name=='HttpService'then return {GenerateGUID=function()guid+=1;return string.format('12345678-1234-1234-1234-%012d',guid)end}
 elseif name=='RunService' then return {RenderStepped=signal()} elseif name=='MarketplaceService'then return {GetProductInfoAsync=function()error('disabled payments must not load')end}end;error(name)end},
 workspace=ws,Instance={new=object},UDim2=rb.UDim2,UDim=rb.UDim,Vector2=rb.Vector2,Vector3=rb.Vector3,CFrame=rb.CFrame,Color3=rb.Color3,Enum=rb.Enum,
 script={Parent={KDMIconCatalog='Icons',ShopLayout='Style',GarageUiController='G',KDMUiStyleHelper='Helper'}},require=function(id)return assert(modules[id],tostring(id))end,
 task={defer=function(fn)fn()end,spawn=function(fn)table.insert(queue,fn)end,delay=function(_,fn)table.insert(delays,fn)end}}
local shop=load('src/client/GarageShopController.luau',env)
local function flush()while #queue>0 do table.remove(queue,1)()end end
local function tap(b)assert(b,'missing button');b.Activated:Fire()end
shop.start();shop.start();check(#pg:GetChildren()==1,'idempotent Shop startup')
shop.open();flush();local gui=pg.KDMGarageShop;local panel=gui.SafeRoot.Shop;local body=panel.Products
check(gui.Enabled and p:GetAttribute('KDMShopOpen') and #calls==1 and calls[1][1]=='PROFILE','only profile read on open')
check(previews[1].id=='Kart05' and previews[1].wing,'actual wing-equipped factory preview')
check(panel.Status.Text:find('SCROLL DOWN',1,true),'footer guides users to the lower color list')
local product=body.KartProduct
check(product.KartActions.Owned.Text:find('50,000',1,true) and product.KartActions.BuyKart.Text:find('50,000',1,true),'hero and buy action show current kart price')
check(product.ActualKartPreview~=nil and product.KartActions.Ownership.Text:find('One color'),'one permanent color-specific kart')
local function controls()return body.KartProduct.KartActions end
local cards=0
for _,id in shopCatalog.KartOrder do check(body.KartCards[id]~=nil,'one card per purchasable color '..id);cards+=1 end
check(cards==7 and #catalog.Order==11,'seven purchase cards with free rental catalog preserved')
tap(body.KartCards.Kart11);check(controls().ProductTitle.Text:find('Black'),'card selects black hero')
tap(controls().BuyKart);check(gui.SafeRoot.PurchaseConfirmation.Visible and #calls==1,'kart BUY opens confirmation only')
tap(gui.SafeRoot.PurchaseConfirmation.Cancel);check(not gui.SafeRoot.PurchaseConfirmation.Visible,'cancel purchase')
tap(panel['RACE ITEMS']);check(#calls==1,'tab switch never buys')
local grid=body.ItemGrid;check(grid.ItemSlots.ClassName=='UIGridLayout' and grid.FindFirstChildOfClass==nil,'native grid in own container')
local cards=0
for _,id in shopCatalog.Order do
 local card=grid[id];cards+=1
 check(card and card.ProductImage.Image==icons.Items[id],'original artwork '..id)
 check(card.Price.Text=='K$ '..shopCatalog.Prices[id],'unchanged price '..id)
 check(card.AbsoluteSize.Y>=44,'selectable card target '..id)
end
check(cards==6 and grid.ItemSlots.Parent~=body.UIListLayout.Parent,'list/grid never share parent')
tap(grid.Thunder);check(#calls==1 and panel.SelectedItemDetail.SelectedName.Text:find('THUNDER'),'selection shows detail without purchase')
check(body.ItemGrid.Thunder.ArcadeStroke.Thickness==3 and body.ItemGrid.Thunder.Product.Text:find('✓'),'border and check selection')
check(panel.SelectedItemDetail.SelectedQuantity.Text=='OWNED: 3','real snapshot voucher count')
for _,size in {rb.Vector2.new(750,324),rb.Vector2.new(706,281),rb.Vector2.new(648,223),rb.Vector2.new(1142,628),rb.Vector2.new(1920,1022)}do
 safeSize=size;gui.SafeRoot:GetPropertyChangedSignal('AbsoluteSize'):Fire()
 check(panel.SelectedItemDetail.SelectedName.Text:find('THUNDER') and #calls==1,'resize keeps selection, no calls')
 local c=style.itemsForSize(size);check(c.width>=120 and c.width<=220 and c.height>=44,'bounded readable six-slot grid');check(c.height*2+c.gap<=c.gridHeight,'six slots visible without scrolling');check(panel.SelectedItemDetail.Buy.AbsoluteSize.Y>=44,'fixed BUY touch target')
 check(c.columns*c.width+(c.columns-1)*c.gap<=body.AbsoluteSize.X-8,'grid fits actual safe body')
 check(panel.Position.X.Offset+panel.Size.X.Offset<=size.X and panel.Position.Y.Offset+panel.Size.Y.Offset<=size.Y,'safe panel')
end
local confirm=gui.SafeRoot.PurchaseConfirmation
check(confirm.AbsoluteSize.X<=safeSize.X and confirm.AbsoluteSize.Y<=safeSize.Y,'confirmation safe')
tap(panel.SelectedItemDetail.Buy);check(confirm.Visible and #calls==1,'voucher BUY only opens confirmation')
response={status='SAVE_UNCONFIRMED'};tap(confirm.Confirm);tap(confirm.Confirm);check(#calls==1 and #queue==1,'double confirm queues once')
flush();check(calls[2][1]=='BUY_ITEM' and calls[2][2]=='Thunder','selected server item contract')
local pendingId=calls[2][3];check(body.PendingPurchase and panel.Status.Text:find('not confirmed'),'uncertain save retains pending operation')
tap(body.ItemGrid.Shield);check(panel.SelectedItemDetail.SelectedName.Text:find('SHIELD'),'selection survives pending state')
check(not panel.SelectedItemDetail.Buy.Active,'different purchase blocked while pending')
response={status='FOUND',cash=765,counts={Thunder=4,Nitro=0},wingOwned=false,canPurchase=true,autoRefill=false,purchaseState='SAVE_CONFIRMED'}
tap(body.PendingPurchase.Retry);flush();check(calls[3][1]=='BUY_ITEM' and calls[3][2]=='Thunder' and calls[3][3]==pendingId,'retry same item and GUID despite selected Shield')
check(not body.PendingPurchase and panel.Status.Text=='PURCHASE COMPLETE','success only after confirmed save')
check(panel.SelectedItemDetail.SelectedName.Text:find('SHIELD'),'confirmation/retry preserves current selected item')
tap(panel['MY INVENTORY']);check(body.EmptyKartInventory~=nil,'empty owned-kart inventory explains free rentals')
tap(panel.InventorySections.ITEMS)
check(panel.SelectedItemDetail.StoredOnly.Text:find('STORED') and not panel.SelectedItemDetail.StoredOnly.Active,'purchased items stored without automatic consumption control')
check(panel.SelectedItemDetail.AutoRefill==nil,'automatic refill control removed')
tap(panel['RACE ITEMS'])
local before=#calls
local touch={UserInputType=rb.Enum.UserInputType.Touch,Position=rb.Vector3.new(100,160,0)}
body.AbsoluteCanvasSize=rb.Vector2.new(600,1200);body.AbsoluteWindowSize=rb.Vector2.new(600,130)
body.InputBegan:Fire(touch);touch.Position=rb.Vector3.new(100,60,0);input.InputChanged:Fire(touch)
tap(body.ItemGrid.Nitro);tap(panel.SelectedItemDetail.Buy)
check(#calls==before and not confirm.Visible,'drag cannot select/buy/confirm')
input.InputEnded:Fire(touch)
p:SetAttribute('RaceState','RACING');check(not gui.Enabled and not p:GetAttribute('KDMShopOpen'),'race transition closes Shop')
p:SetAttribute('RaceState','GARAGE');response={status='FOUND',cash=0,counts={},canPurchase=false,wingOwned=false};shop.open();flush()
tap(panel.KARTS)
check(panel.Wallet.Text:find('K%$ 0') and not controls().BuyKart.Active,'confirmed zero distinct, purchase blocked')
for _,o in pg:GetDescendants()do if o.ClassName=='TextButton' and (o.Name=='Pass')then check(not o.Active,'Robux stays inactive')end end
for _,size in {{750,324},{706,281},{648,223},{1142,628},{1280,662},{1920,1022}}do
 local l=style.forSize({X=size[1],Y=size[2]});local c=style.gridForWidth(l.width-24,l.bodyHeight)
 check(c.height<=l.bodyHeight,'a full item card fits the scroll viewport')
 check(c.priceY+(if c.icon==72 then 26 else 18)<=c.height,'price never overlaps/escapes the card')
 check(c.nameY+18<=c.countY and c.countY+16<=c.priceY,'name quantity and price do not overlap')
end
-- Short safe canvases keep a usable item action and scroll full-size choices.
p:SetAttribute('RaceState','GARAGE');shop.open('MY INVENTORY');flush()
for _,size in {rb.Vector2.new(473,182),rb.Vector2.new(473,240)} do
 safeSize=size;gui.SafeRoot:GetPropertyChangedSignal('AbsoluteSize'):Fire()
 if not panel.SelectedItemDetail then tap(panel['MY INVENTORY']) end
 check(panel.Products.AbsoluteSize.Y>=44 and panel.SelectedItemDetail.AbsoluteSize.Y>=44,'short inventory viewport and detail remain usable')
 check(panel.SelectedItemDetail.StoredOnly.AbsoluteSize.Y>=44,'stored-only action remains full-size')
 check(body.ItemGrid.Nitro.AbsoluteSize.Y>=44,'short inventory scrolls full-size item choices')
end
local current=fs.readFile('src/client/GarageShopController.luau')
check(current:find("remote:InvokeServer('PREPARE'",1,true) and current:find('op.id=ticket.id',1,true),'server-issued identity before purchase')
check(current:find("request(pending.action,pending.item,pending.value)",1,true),'uncertain request keeps original identity')
fs.writeFile('artifacts/economy-v2-ui2-r1/shop-mock-results.json',require('@lune/serde').encode('json',{checks=count,requests=#calls,liveDataStoreCalls=0}))
print('PASS UI2 actual Shop controller: '..count..' checks; isolated mocks, live calls ZERO')
