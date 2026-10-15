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
		Position = rb.UDim2.fromScale(0, 0), Visible = true, Enabled = true,
		FocusLost = signal(), Activated = signal(), OnClientEvent = signal(), CharacterAdded = signal(), ChildAdded = signal(), CharacterRemoving = signal(), Destroying = signal(), InputBegan = signal(), InputChanged = signal(), InputEnded = signal(), WindowFocusReleased = signal() }
	return setmetatable({ _p = props, _children = {}, _attrs = {}, _signals = {}, _properties = {} }, {
		__index = function(self, key)
			if methods[key] then return methods[key] end
			if key == "AbsoluteContentSize" and class == "UIListLayout" then
				local height, items = 0, 0
				for _, item in props.Parent:GetChildren() do
					if item.ClassName == "TextLabel" then height += item.AbsoluteSize.Y; items += 1 end
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

local player=object('Player','LocalPlayer');player.DisplayName='Mock Driver'
local pg=child(player,'PlayerGui','PlayerGui')
local ws=object('Workspace');ws:SetAttribute('KDMServerRole','HUB')
player:SetAttribute('RaceState','GARAGE')
local rs=object('ReplicatedStorage');local shared=child(rs,'Folder','Shared');local token=child(shared,'ModuleScript','KartCatalog')
local remote=child(rs,'RemoteFunction','KDMEconomy')
local input=object('UserInputService')
local calls,shops={},0
local reply={status='FOUND',passAvailable=false,cash=999999}
function remote:InvokeServer(action,value)table.insert(calls,{action,value});return reply end
local catalog=luau.load(fs.readFile('src/shared/KartCatalog.luau'),{environment={Color3=rb.Color3,Enum=rb.Enum}})()
local style=luau.load(fs.readFile('src/client/ShopLayout.luau'),{environment={Instance={new=object},Color3=rb.Color3,UDim=rb.UDim,Enum=rb.Enum}})()
local controller=luau.load(fs.readFile('src/client/EconomyController.luau'),{environment={
 game={GetService=function(_,name)if name=='Players' then return {LocalPlayer=player} elseif name=='ReplicatedStorage' then return rs elseif name=='UserInputService' then return input else error(name)end end},
 workspace=ws,Instance={new=object},Color3=rb.Color3,Vector2=rb.Vector2,UDim2=rb.UDim2,Enum=rb.Enum,
 script={Parent={GarageShopController='SHOP',ShopLayout='STYLE'}},require=function(mod)if mod==token then return catalog elseif mod=='STYLE' then return style elseif mod=='SHOP' then return {open=function()shops+=1 end} else error(tostring(mod))end end,
 task={spawn=function(fn)fn()end},
}})()
controller.start();local gui=pg.KDMMyProfile;local card=gui.DriverCard;local body=card.Details
check(gui.ScreenInsets==rb.Enum.ScreenInsets.CoreUISafeInsets,'one safe-area coordinate system')
check(body.Active and body.ScrollingDirection==rb.Enum.ScrollingDirection.Y,'native vertical touch scrolling')
local function activate(b)b.Activated:Fire()end
activate(gui.Profile)
check(card.Visible and player:GetAttribute('KDMProfileOpen'),'open profile')
check(body.Wallet.Text=='AVAILABLE K$\n--' and body.LifetimeRaceEarnings.Text:find('K%$ %-%-'),'missing attributes never become zero')
check(body.Wing.Text:find('UNAVAILABLE') and not body.EquipWing.Active and not body.BuyWing.Active,'unknown ownership fails closed')
check(not body.GamePass.Active,'payments remain unavailable')
check(body.Wallet.Text~='AVAILABLE K$\n999999','remote response cannot inject display balance')
local attrs={KDMEconomyState='FOUND',KDMWalletRevision=74,KDMWalletCash=940,KDMLifetimeEarned=900,KDMWingOwned=false,KDMWingEquipped=false,SelectedKartId='Kart09'}
for k,v in attrs do player:SetAttribute(k,v)end
check(body.Wallet.Text=='AVAILABLE K$\n940','wallet attribute')
check(body.BuyWing.Visible and not body.EquipWing.Visible,'unowned action never covered by equip')
check(body.LifetimeRaceEarnings.Text:find('900') and not body.LifetimeRaceEarnings.Text:find('940'),'race earnings independent from wallet/grant')
check(body.Kart.Text:find('Metal Blue') and body.Kart09.ColorName.Text=='✓ Metal Blue','catalog selection highlighted')
local variants=0
for _,c in body:GetChildren()do if c.ClassName=='Frame' and catalog.Entries[c.Name] then variants+=1;check(c.Swatch~=nil,'catalog color swatch')end end
check(variants==7 and #catalog.Order==11,'seven free V2 variants and Sprint preserved')
for _,id in catalog.Order do
 player:SetAttribute('SelectedKartId',id)
 check(body.Kart.Text:find(catalog.Entries[id].DisplayName,1,true)~=nil,'all current karts '..id)
end
player:SetAttribute('SelectedKartId','missing');check(body.Kart.Text:find('UNAVAILABLE'),'unknown selected kart not fabricated')
player:SetAttribute('SelectedKartId','Kart09')
for _,state in {'ACCESS_BLOCKED','READ_ONLY','SAVE_PENDING','ABSENT'}do
 player:SetAttribute('KDMEconomyState',state)
 check(body.Wallet.Text=='AVAILABLE K$\n--' and body.Wing.Text:find('UNAVAILABLE'),'blocked state hides stale attributes '..state)
end
player:SetAttribute('KDMEconomyState','FOUND')
for _,value in {-1,math.huge,0/0,12.5,'940'}do
 player:SetAttribute('KDMWalletCash',value);check(body.Wallet.Text=='AVAILABLE K$\n--','malformed currency fails closed')
end
player:SetAttribute('KDMWalletCash',0);check(body.Wallet.Text=='AVAILABLE K$\n0','confirmed actual zero preserved')
player:SetAttribute('KDMWalletCash',26000);check(body.BuyWing.Active,'existing Wing purchase route available')
activate(body.BuyWing);check(shops==1 and not card.Visible,'buy routes to existing Shop confirmation')
activate(gui.Profile);activate(body.OpenShop);check(shops==2 and not card.Visible,'shop preview independent of affordability')
activate(gui.Profile)
player:SetAttribute('KDMWingOwned',true);check(body.EquipWing.Active and not body.BuyWing.Active,'owned Wing enables equip only')
check(body.EquipWing.Visible and not body.BuyWing.Visible,'owned equipment action replaces purchase')
activate(body.EquipWing);check(calls[#calls][1]=='EQUIP_WING' and calls[#calls][2]==true,'existing server equip request')
check(player:GetAttribute('KDMWingEquipped')==false,'client never grants equipment')
player:SetAttribute('KDMWingEquipped',true);activate(body.EquipWing)
check(calls[#calls][2]==false and body.Wing.Text:find('OWNED / EQUIPPED'),'server equipped state / unequip request')
player:SetAttribute('KDMWingEquipped',nil);check(not body.EquipWing.Active and body.Wing.Text:find('UNKNOWN'),'missing equipment not inferred false')
local listeners=player:GetAttributeChangedSignal('KDMWalletCash'):count()
controller.start();check(#pg:GetChildren()==1 and player:GetAttributeChangedSignal('KDMWalletCash'):count()==listeners,'idempotent startup')
local before=#calls
for _=1,20 do activate(card.Close);activate(gui.Profile)end
check(#calls==before+20,'one PROFILE request per open, no duplicate handlers')
for _,gate in {{'RaceState','RACING','GARAGE'},{'HubOverlayOpen',true,false},{'KDMShopOpen',true,false},{'LobbyDriveActive',true,false},{'KDMRoutePending','RACE_LAUNCH',''}}do
 player:SetAttribute(gate[1],gate[2]);check(not gui.Enabled and not card.Visible and not player:GetAttribute('KDMProfileOpen'),'auto-close '..gate[1])
 player:SetAttribute(gate[1],gate[3]);activate(gui.Profile)
end
activate(card.Dismiss);check(not card.Visible,'fixed dismiss works')
local function within(a,b)
 return a.AbsolutePosition.X>=b.AbsolutePosition.X-0.01 and a.AbsolutePosition.Y>=b.AbsolutePosition.Y-0.01
 and a.AbsolutePosition.X+a.AbsoluteSize.X<=b.AbsolutePosition.X+b.AbsoluteSize.X+0.01
 and a.AbsolutePosition.Y+a.AbsoluteSize.Y<=b.AbsolutePosition.Y+b.AbsoluteSize.Y+0.01
end
local layouts={}
for _,size in {rb.Vector2.new(750,382),rb.Vector2.new(706,339),rb.Vector2.new(648,281),rb.Vector2.new(648,223),rb.Vector2.new(1920,1080),rb.Vector2.new(1280,720)}do
 safeSize=size;card:GetPropertyChangedSignal('AbsoluteSize'):Fire()
 check(within(card,gui) and within(card.Close,card) and within(card.Dismiss,card),'safe fixed controls '..tostring(size))
 check(body.AbsoluteSize.Y>100 and body.AbsolutePosition.Y+body.AbsoluteSize.Y<=card.Close.AbsolutePosition.Y,'scroll and footer no overlap')
 for _,v in body:GetChildren()do
  if v.ClassName=='TextButton' then check(v.AbsoluteSize.Y>=44 and v.Position.Y.Offset+v.AbsoluteSize.Y<=body.CanvasSize.Y.Offset,'scroll buttons reachable '..v.Name)end
 end
 table.insert(layouts,{safe={size.X,size.Y},panel={card.AbsoluteSize.X,card.AbsoluteSize.Y},scrollHeight=body.AbsoluteSize.Y})
end
local serde=require('@lune/serde')
activate(gui.Profile)
body.CanvasPosition=rb.Vector2.zero;body.AbsoluteCanvasSize=rb.Vector2.new(560,706);body.AbsoluteWindowSize=rb.Vector2.new(560,138)
local touch={UserInputType=rb.Enum.UserInputType.Touch,Position=rb.Vector3.new(200,180,0)}
body.InputBegan:Fire(touch);touch.Position=rb.Vector3.new(200,88,0);input.InputChanged:Fire(touch)
check(body.CanvasPosition.Y==92,'short owned touch drag scrolls 92px')
local shopBefore=shops;activate(body.OpenShop);check(shops==shopBefore,'scroll release cannot activate Shop')
local foreign={UserInputType=rb.Enum.UserInputType.Touch,Position=rb.Vector3.new(200,0,0)}
input.InputChanged:Fire(foreign);check(body.CanvasPosition.Y==92,'foreign finger cannot move owned scroll')
input.InputEnded:Fire(touch);touch.Position=rb.Vector3.new(200,0,0);input.InputChanged:Fire(touch)
check(body.CanvasPosition.Y==92,'released touch cannot keep scrolling')
body.InputBegan:Fire(touch);touch.Position=rb.Vector3.new(200,-1000,0);input.InputChanged:Fire(touch)
check(body.CanvasPosition.Y==568,'touch drag clamps to canvas bottom')
activate(card.Close);touch.Position=rb.Vector3.new(200,500,0);input.InputChanged:Fire(touch)
check(body.CanvasPosition.Y==568,'closing cancels scroll ownership')
fs.writeFile('artifacts/economy-v2-ui2-r1/profile-mock-results.json',serde.encode('json',{checks=count,layouts=layouts,productionWrites=0}))
print('PASS Driver Card: '..count..' checks (isolated mocks, no DataStore)')
