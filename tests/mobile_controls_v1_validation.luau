-- Private QA v1: production geometry, touch ownership, fallback and unchanged transport.
local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local checks=0
local function check(v,m)assert(v,m);checks+=1 end
local view=luau.load(fs.readFile('src/client/MobileControlView.luau'),{environment={Color3=rb.Color3}})()
check(not view.controlsV1Enabled(),'default flag OFF')
for _,c in {{flag=true,universeId=10768420544,placeId=106553302629620},{flag=false,universeId=10772198697,placeId=106553302629620},{flag=true,universeId=10772198697,placeId=1}} do check(not view.controlsV1Enabled(c),'exact QA target and explicit flag required') end
check(view.controlsV1Enabled({flag=true,universeId=10768420544,placeId=127925465904803}),'approved production rollout enabled')
check(view.controlsV1Enabled({flag=true,universeId=10772198697,placeId=106553302629620}),'private QA flag enabled')
local function overlap(a,b)return a.x<b.x+b.width and a.x+a.width>b.x and a.y<b.y+b.height and a.y+a.height>b.y end
for _,screen in {{1600,739},{1280,720},{926,428},{852,393},{812,375},{740,360},{750,332},{666,280},{600,240}} do
 for _,inset in {{0,0,0,0},{44,0,0,21},{0,44,18,0},{59,27,28,21}} do
  local size=rb.Vector2.new(math.max(600,screen[1]-inset[1]-inset[2]),math.max(240,screen[2]-inset[3]-inset[4]))
  local l=view.controlsV1Layout(size);local boxes={}
  for name,b in l.buttons do
   check(b.width>=48 and b.height>=48,'minimum input hitbox '..name)
   check(b.x>=12-1e-6 and b.y>=12-1e-6 and b.x+b.width<=size.X-12+1e-6 and b.y+b.height<=size.Y-12+1e-6,'complete safe hitbox '..name)
   for _,o in boxes do check(not overlap(b,o),'five controls never overlap '..name..'/'..tostring(o.name)..' '..tostring(size))end;b.name=name;table.insert(boxes,b)
   check(not overlap(b,l.map) and not overlap(b,l.gauge) and not overlap(b,l.speed),'map gauge speed do not obstruct '..name..' '..tostring(size))
  end
  check(l.gauge.x>l.items.progressX+l.items.progressWidth*.6 and l.gauge.y==l.items.progressTop+3,'Drift charge beside Nitro text')
  local itemBoxes={}
  for i=0,5 do
   local row=math.floor(i/l.items.columns)
   local b={x=(if row==1 then l.items.secondX else l.items.x)+(i%l.items.columns)*(l.items.slot+6),y=if row==1 then l.items.secondTop else l.items.top,width=l.items.slot,height=l.items.slot}
   check(b.x+b.width<=size.X-12+1e-6,'items remain inside right safe edge')
   -- Map uses DeviceSafeInsets; item coordinates start below the native topbar.
   local map={x=l.map.x,y=l.map.y-58,width=l.map.width,height=l.map.height}
   check(not overlap(b,map),'items clear minimap across safe-area layers')
   check(not overlap(b,l.clock),'items clear clock lane')
   for _,o in boxes do check(not overlap(b,o),'items clear finger zones '..tostring(size)..' item'..i..' '..o.name)end
   for _,o in itemBoxes do check(not overlap(b,o),'six item targets distinct')end;table.insert(itemBoxes,b)
  end
  local n={x=l.items.progressX,y=l.items.progressTop,width=l.items.progressWidth,height=l.items.progressHeight}
  check(l.items.x>size.X*.6 and math.abs(l.items.secondX+l.items.slot+3-l.buttons.Drift.x-l.buttons.Drift.width/2)<1,'Shield Nitro above Drift on right side')
  check(math.abs(n.x+n.width/2-size.X/2)<1e-6 and n.y+n.height<=l.speed.y,'Nitro centered above digital speed')
  check(l.map.x+l.map.width==size.X-12 and l.map.y==8,'minimap top right safe corner')
  for _,o in boxes do check(not overlap(n,o),'Nitro progress clears finger zones')end
 end
end
for _,size in {rb.Vector2.new(1600,739),rb.Vector2.new(750,332),rb.Vector2.new(600,240)}do
 local l=view.controlsV1Layout(size);local b=l.buttons
 check(math.abs(b.ForwardRight.x-b.ForwardLeft.x-b.ForwardLeft.width-15)<.01,'15 pixel steering gap')
 check(b.Gas.width==b.Drift.width and b.Gas.height==b.Drift.height,'Gas matches Drift size')
 check(b.ForwardLeft.width==b.Drift.width and b.ForwardLeft.height==b.Drift.height,'steering matches Drift size')
 check(math.abs(b.Gas.x+b.Gas.width-size.X+12)<.01,'Gas at right safe edge')
 check(math.abs(b.BrakeReverse.x+b.BrakeReverse.width-b.Gas.x-b.Gas.width)<.01,'Brake Gas Missile share right edge')
 check(b.BrakeReverse.y+b.BrakeReverse.height<b.Gas.y,'separate Brake and Gas')
 for _,name in {'ForwardLeft','ForwardRight','Gas','Drift'}do check(math.abs(b[name].y+b[name].height-size.Y+26)<.01,'button bottom at speed underline')end
end
-- Reuse only the Roblox mock setup, then run the actual new controller and item HUD.
local fixture=fs.readFile('tests/mobile_touch_validation.luau')
local prefix=fixture:sub(1,assert(fixture:find('local input=modules.KartInputController; input.start()',1,true))-1)
local setup=[=[
env.game.GameId=10772198697;env.game.PlaceId=106553302629620;env.game.CreatorId=1;player.UserId=1
env.workspace=object('Workspace');env.workspace:SetAttribute('KDMControlsV1Preview',true)
for _,name in {'MobileControlView','TouchDrivingController','DriftChargeView'} do modules[name]=luau.load(fs.readFile('src/client/'..name..'.luau'),{environment=env})() end
]=]
local hud=fs.readFile('tests/helpers/six_item_hud_fixture.luau')
local scenario=[=[
local input=modules.KartInputController;input.start()
modules.TouchDrivingController.start();modules.DriftChargeController.start()
local gui=pg.RobloxKartTouchDriving;local root=gui.Controls
local function tick()services.RunService.Heartbeat:Fire(.05)end
local function latest()return control._p.calls[#control._p.calls]end
local function finger(target)
 local f=object('InputObject');f.UserInputType=rb.Enum.UserInputType.Touch;f.UserInputState=rb.Enum.UserInputState.Begin;f.KeyCode=rb.Enum.KeyCode.Unknown
 f.Position=V3.new(0,0,0);target.InputBegan:Fire(f);tick();return f
end
local function release(f)f.UserInputState=rb.Enum.UserInputState.End;tick()end
tick();check(root.Visible and root.Gas.Visible and not defaultGui.Enabled,'QA five controls hide stock TouchGui')
local visible=0;for _,c in root:GetChildren()do if c.ClassName=='TextButton' and c.Visible then visible+=1 end end;check(visible==5,'exactly five visible driving buttons')
check(root.ForwardLeft.ControlsV1Glyph.Text=='◀' and root.ForwardRight.ControlsV1Glyph.Text=='▶','filled triangle steering labels')
check(root.ForwardLeft.ControlsV1Glyph.Font==rb.Enum.Font.GothamBlack,'heavy steering glyph weight')
check(root.BrakeReverse.ControlsV1Glyph.TextSize<root.Gas.ControlsV1Glyph.TextSize,'secondary Brake has smaller text')
check(math.abs(root.Gas:FindFirstChildOfClass('UICorner').CornerRadius.Scale-.28)<.0001,'rounded rectangle Gas')
local gas=finger(root.Gas);check(gui:GetAttribute('GasPreviewHeld') and latest()[1]==1 and latest().n==3,'GAS holds only UI state; original three-argument transport')
root.ForwardLeft.InputBegan:Fire(gas);tick();check(latest()[2]==0,'one finger cannot own GAS and steer')
local steer=finger(root.ForwardLeft);local drift=finger(root.Drift)
check(latest()[1]==1 and latest()[2]==-1 and latest()[3],'separate steer GAS Drift fingers coexist')
release(drift);check(gui:GetAttribute('GasPreviewHeld') and latest()[2]==-1 and not latest()[3],'Drift release leaves GAS/steering owners')
local center=root.Drift.AbsolutePosition+root.Drift.AbsoluteSize/2;gas.Position=V3.new(center.X,center.Y,0);ui.InputChanged:Fire(gas);tick()
check(not gui:GetAttribute('GasPreviewHeld') and latest()[3],'GAS slide transfers ownership to DRIFT')
local brake=finger(root.BrakeReverse);check(latest()[1]==-1 and not latest()[3],'brake retains authoritative reverse priority')
release(brake);release(gas);release(steer)
local held=finger(root.Gas);ui.WindowFocusReleased:Fire();check(not gui:GetAttribute('GasPreviewHeld'),'focus loss clears GAS preview')
ui.WindowFocused:Fire();tick();release(held)
local slideBrake=finger(root.Gas)
local brakeCenter=root.BrakeReverse.AbsolutePosition+root.BrakeReverse.AbsoluteSize/2
slideBrake.Position=V3.new(brakeCenter.X,brakeCenter.Y,0);ui.InputChanged:Fire(slideBrake);tick()
check(latest()[1]==-1 and not gui:GetAttribute('GasPreviewHeld'),'held GAS finger slides to BRAKE and begins negative throttle')
release(slideBrake)
env.workspace:SetAttribute('KDMGasPedalEnabled',true)
services.Workspace:SetAttribute('KDMGasPedalEnabled',true)
local pedalModel=modules.TouchDrivingModel.new('Buttons');pedalModel.autoForward=false
local owner={};pedalModel:pressGas(owner);check(select(1,pedalModel:actions())==1,'GAS accelerates even when auto-forward is off')
pedalModel:release(owner);check(select(1,pedalModel:actions())==0,'release preserves previous auto-forward setting')
local pedal=finger(root.Gas)
check(latest().n==4 and latest()[4]==true,'enabled private QA sends held GAS boolean on existing transport')
release(pedal);check(latest()[4]==false,'release sends GAS false immediately')
pedal=finger(root.Gas);ui.WindowFocusReleased:Fire()
check(latest()[4]==false and latest()[1]==0,'focus loss sends neutral GAS false')
ui.WindowFocused:Fire();tick();release(pedal)
env.workspace:SetAttribute('KDMGasPedalEnabled',false);services.Workspace:SetAttribute('KDMGasPedalEnabled',false);tick()
for _,id in modules.RaceItemSlots.DEFAULT do player:SetAttribute('RaceCharge'..id,1)end
for _,size in {V2.new(1600,739),V2.new(926,428),V2.new(852,393),V2.new(812,375),V2.new(750,332)}do
 safeSize=size;itemCamera.ViewportSize=size;root:GetPropertyChangedSignal('AbsoluteSize'):Fire();itemHud:GetPropertyChangedSignal('AbsoluteSize'):Fire();tick()
 local l=modules.MobileControlView.layout(size).controlsV1;local ordered={'Smoke','Slick','Thunder','Missile','Shield','Nitro'}
 for i,id in ordered do
  local b=itemHud[id];local p=b.AbsolutePosition
  local rowX=if i>4 then l.items.secondX else l.items.x
  check(math.abs(p.X-(rowX+(i-1)%l.items.columns*(l.items.slot+6)))<.01,'visual item order '..id)
  check(math.abs(p.Y-(if i>4 then l.items.secondTop else l.items.top))<.01,'four-plus-two item rows '..id..' actual '..tostring(p.Y)..' expected '..tostring(if i>4 then l.items.secondTop else l.items.top)..' size '..tostring(size))
  local outline=b:FindFirstChild('ItemOutline');check(outline~=nil,'item has independent inset outline '..id)
  check(math.abs(b.BackgroundTransparency-.52)<.001,'item background matches controls '..id)
  check(outline.Position.X.Offset==1 and outline.Size.X.Offset==-2 and outline.ZIndex>b.KDMItemImage.ZIndex,'outline inset and above image '..id)
  check(math.abs(outline:FindFirstChildOfClass('UICorner').CornerRadius.Scale-.28)<.001,'round item outline '..id)
  local before=#item._p.calls;b.Activated:Fire();check(#item._p.calls==before+1 and item._p.calls[#item._p.calls][2]==id,'exact item action '..id)
 end
end
-- Park's higher DisplayOrder must not leave a transparent scrolling hitbox over BRAKE.
for _,name in {'LobbyPracticePolicy','LobbyPracticeLayout'}do child(shared,'ModuleScript',name)end
modules.LobbyPracticePolicy=luau.load(fs.readFile('src/shared/LobbyPracticePolicy.luau'),{environment={Color3=rb.Color3}})()
modules.LobbyPracticeLayout=luau.load(fs.readFile('src/shared/LobbyPracticeLayout.luau'))()
local practiceEnv=table.clone(itemEnv);practiceEnv.script={Parent=modulesFolder}
services.Workspace.GetServerTimeNow=function()return 1000 end
local Practice=luau.load(fs.readFile('src/client/LobbyPracticeView.luau'),{environment=practiceEnv})()
local parkGui=child(pg,'ScreenGui','ParkHitTest');parkGui.Enabled=true;parkGui.DisplayOrder=21
local canvas=child(parkGui,'Frame','SafeCanvas');canvas.Size=rb.UDim2.fromScale(1,1)
local parkRemote=object('RemoteEvent');parkRemote._p.calls={}
local park=Practice.new(canvas,player,parkRemote,function()return true end)
for _,size in {V2.new(1600,739),V2.new(750,332),V2.new(600,240)}do
 safeSize=size;local l=modules.MobileControlView.layout(size)
 for _,id in modules.LobbyPracticePolicy.Items do player:SetAttribute('LobbyCharge'..id,1)end
 park:update(true,l,0,nil)
 local scroll=canvas.PracticeItems
 check(not scroll.Visible and not scroll.Active and not scroll.ScrollingEnabled,'fixed Park has no scrolling hit target')
 for _,id in modules.LobbyPracticePolicy.Items do
  local b=canvas:FindFirstChild(id);check(b~=nil and b.Parent==canvas and b.Visible,'fixed item is independent of scroll '..id)
  check(b.Caption.Text=='1' and b.Caption.AnchorPoint==V2.new(1,1) and b.Caption.TextSize==14,'Park icons show count only like official HUD '..id)
  local p,s=b.AbsolutePosition,b.AbsoluteSize;local brake=l.controlsV1.buttons.BrakeReverse
  check(not(p.X<brake.x+brake.width and p.X+s.X>brake.x and p.Y<brake.y+brake.height and p.Y+s.Y>brake.y),'item hit target never covers BRAKE '..id)
  local before=#parkRemote._p.calls;b.Activated:Fire();check(#parkRemote._p.calls==before+1,'direct Park item action retained '..id)
 end
end
park:destroy();check(canvas:FindFirstChild('Nitro')==nil,'detached fixed items are cleaned up')
player:SetAttribute('RaceState','GARAGE');humanoid.SeatPart=nil;tick();check(defaultGui.Enabled and not root.Visible and not gui:GetAttribute('GasPreviewHeld'),'Hub restores native avatar TouchGui')
print('PASS QA production controller/HUD: '..count..' checks')
]=]
local loader=require('./helpers/gameplay_config')
luau.load(prefix..setup..hud..scenario,{environment={require=function(path)if path=='./helpers/gameplay_config' then return loader end;return require(path)end}})()
print('PASS private QA geometry / flag: '..checks..' checks; gated GAS transport checked')
