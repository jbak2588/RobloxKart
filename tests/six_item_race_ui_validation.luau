-- Real production input + HUD, reusing Roblox GUI/signal mocks only.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local fixture=fs.readFile('tests/mobile_touch_validation.luau')
local prefix=fixture:sub(1,assert(fixture:find('local input=modules.KartInputController; input.start()',1,true))-1)
local setup=fs.readFile('tests/helpers/six_item_hud_fixture.luau')
local scenario=[=[
local input=modules.KartInputController;input.start()
local ids=modules.RaceItemSlots.DEFAULT
for _,id in ids do player:SetAttribute('RaceCharge'..id,1)end
local function rect(node)
 local p,s=node.AbsolutePosition,node.AbsoluteSize
 return {p.X,p.Y,p.X+s.X,p.Y+s.Y}
end
local function overlap(a,b)return a[1]<b[3]and a[3]>b[1]and a[2]<b[4]and a[4]>b[2]end
for _,size in {V2.new(750,283),V2.new(801,334),V2.new(844,390),V2.new(932,430),V2.new(1280,720),V2.new(389,703)}do
 safeSize=size;itemCamera.ViewportSize=size
 itemHud:GetPropertyChangedSignal('AbsoluteSize'):Fire()
 local boxes={}
 for index,id in ids do
  local button=itemHud:FindFirstChild(id)
  check(button and button.Visible,'six usable item cells: '..id)
  local box=rect(button);boxes[index]=box
  check(box[1]>=0 and box[2]>=0 and box[3]<=size.X and box[4]<=size.Y,'safe bounds '..id)
  local before=#item._p.calls;button.Activated:Fire()
  check(#item._p.calls==before+1 and item._p.calls[#item._p.calls][1]=='UseItem'
   and item._p.calls[#item._p.calls][2]==id,'exact mobile item transport '..id)
 end
 for a=1,6 do for b=a+1,6 do check(not overlap(boxes[a],boxes[b]),'item targets never overlap')end end
 check(boxes[1][2]==boxes[4][2] and boxes[5][2]==boxes[6][2] and boxes[5][2]>boxes[1][4], 'four attacks above Nitro/Shield')
 local progress=rect(itemHud.NitroProgress)
 check(progress[2]>=boxes[6][4] and progress[3]==boxes[4][3],'Nitro progress below both rows')
 local layout=modules.MobileControlView.layout(size)
 local driftTop=size.Y-layout.rightDriftBottom-layout.driftHitHeight
 check(boxes[4][3]==size.X-12,'real six-item HUD uses right safe edge')
 check(progress[4]<=driftTop-25,'real Nitro progress leaves room for Drift charge gauge')
end
ui.PreferredInput=rb.Enum.PreferredInput.KeyboardAndMouse
safeSize=V2.new(1280,720);itemCamera.ViewportSize=safeSize
itemHud:GetPropertyChangedSignal('AbsoluteSize'):Fire()
for _,id in ids do
 local box=rect(itemHud:FindFirstChild(id))
 check(box[2]>=0 and box[4]<=safeSize.Y,'desktop item safe bounds '..id)
end
check(rect(itemHud.NitroProgress)[4]<=safeSize.Y,'desktop Nitro progress stays onscreen')
for index,key in {rb.Enum.KeyCode.One,rb.Enum.KeyCode.Two,rb.Enum.KeyCode.Three,rb.Enum.KeyCode.Four,rb.Enum.KeyCode.Five,rb.Enum.KeyCode.Six}do
 ui.InputBegan:Fire({KeyCode=key},false)
 check(item._p.calls[#item._p.calls][1]=='Select'and item._p.calls[#item._p.calls][2]==ids[index],'desktop keys 1-6 select all items')
end
ui.PreferredInput=rb.Enum.PreferredInput.Touch
player:SetAttribute('RaceMissileIncomingCount',1)
check(itemHud.Shield.SelectedMark.Visible and itemHud.Shield.SelectedMark.Text=='!', 'incoming attack highlights Shield in second row')
local before=#item._p.calls;itemHud.Shield.Activated:Fire()
check(#item._p.calls==before+1 and item._p.calls[#item._p.calls][2]=='Shield','emergency Shield atomic direct use')
player:SetAttribute('RaceMissileIncomingCount',0)
player:SetAttribute('DriftBonusProgress',5);player:SetAttribute('DriftBonusPending',true)
check(itemHud.NitroProgress.NitroCharge.Text:find('BONUS PENDING',1,true)~=nil,'pending Nitro feedback preserved')
player:SetAttribute('DriftBonusPending',false);player:SetAttribute('DriftBonusProgress',0)
player:SetAttribute('DriftBonusAwardCount',1)
check(itemHud.NitroProgress.DriftBonusNitro.Visible,'successful boost award flashes Nitro reward')
player:SetAttribute('RaceState','COUNTDOWN')
check(not itemHud.NitroProgress.DriftBonusNitro.Visible,'new round clears award flash')
player:SetAttribute('RaceState','RACING')
-- Keep the recent Lobby input regression covered through the actual pad adapter.
ui.PreferredInput=rb.Enum.PreferredInput.Touch;player:SetAttribute('RaceState','GARAGE')
player.UserId=123;seat:SetAttribute('PrototypeKartSeat',false);seat:SetAttribute('LobbyKartSeat',true)
kart:SetAttribute('LobbyOwnerUserId',123);player:SetAttribute('LobbyDriveActive',true)
local lobbyCalls={};input.setLobbyInputSender(function(...)table.insert(lobbyCalls,table.pack(...))end)
modules.TouchDrivingController.start()
local pad=pg.RobloxKartTouchDriving.Controls
services.RunService.Heartbeat:Fire(.05)
local finger=object('InputObject');finger.UserInputType=rb.Enum.UserInputType.Touch
finger.UserInputState=rb.Enum.UserInputState.Begin
pad.Forward.InputBegan:Fire(finger)
for i=1,24 do
 services.RunService.Heartbeat:Fire(.05)
 check(lobbyCalls[#lobbyCalls][1]==1,'Lobby held Forward transport survives six-item migration')
end
finger.UserInputState=rb.Enum.UserInputState.End;services.RunService.Heartbeat:Fire(.05)
check(lobbyCalls[#lobbyCalls][1]==0,'Lobby release neutral')
print('PASS '..count..' six-item production HUD/transport/layout checks')
]=]
local loader=require('./helpers/gameplay_config')
luau.load(prefix..setup..scenario,{environment={require=function(path)
 if path=='./helpers/gameplay_config'then return loader end
 return require(path)
end}})()
