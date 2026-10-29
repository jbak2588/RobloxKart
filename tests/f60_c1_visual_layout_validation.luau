local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local nodes=require('./helpers/practice_ui_nodes')
local env={Instance={new=nodes.object},Vector2=rb.Vector2,UDim=rb.UDim,UDim2=rb.UDim2,Color3=rb.Color3,Enum=rb.Enum}
local V=luau.load(fs.readFile('src/client/HubGuidanceView.luau'),{environment=env})()
local S=luau.load(fs.readFile('src/client/HubGuidanceState.luau'))()
local E=luau.load(fs.readFile('src/client/EconomyController.luau'),{environment=env})()
local n=0;local function check(v,s)assert(v,s);n+=1 end
for _,size in {rb.Vector2.new(1102,485),rb.Vector2.new(844,390),rb.Vector2.new(932,430),rb.Vector2.new(1920,1080),rb.Vector2.new(749,302)} do
 local root=nodes.object('Frame');root.bounds=size
 for _,kind in {'GUEST','RETURNING_UNACTIVATED','RETURNING_ACTIVE'} do
  local state=S.new()
  if kind=='RETURNING_ACTIVE' then S.profileRestored(state,{completed=true,result='FOUND',restored=true,validKart=true,kartId='Kart05',restoredKartId='Kart05',saveState='SAVE_CONFIRMED'}) end
  local p=S.presentation(state,size,'GARAGE',false,nil,false)
  local clicks=0;local view=V.create(root,{},function()clicks+=1 end,function()clicks+=1 end);view.update(p)
  check(p.visible and view.button.Text=='RACE NOW' and view.testDriveButton.Text=='TIME ATTACK','all visitor states retain both entries')
  check(view.card.BackgroundTransparency>=.9 and view.button.BackgroundTransparency==.58 and view.testDriveButton.BackgroundTransparency==.58,'clear container with translucent action surfaces')
  for _,b in {view.button,view.testDriveButton} do
   check(b.AbsoluteSize.Y>=44 and b.AbsoluteSize.X>=44,'minimum touch bounds')
   check(b.AbsolutePosition.Y>=view.card.AbsolutePosition.Y and b.AbsolutePosition.Y+b.AbsoluteSize.Y<=view.card.AbsolutePosition.Y+view.card.AbsoluteSize.Y,'CTA inside card')
   b.Activated:Fire()
  end
  check(clicks==2,'transparent buttons remain interactive')
  check(not view.card:FindFirstChild('Heading').Visible and view.card.BackgroundTransparency==1,'C2 removes heading and card background')
  check(view.testDriveButton.AbsolutePosition.Y>=view.button.AbsolutePosition.Y+view.button.AbsoluteSize.Y+12,'C2 vertical actions have a 12px gap')
  for _,o in view.card.children do check(o.ClassName~='UIStroke','no parent border')end
  view.destroy()
 end
 -- AbsolutePosition uses the CoreUI origin even for a DeviceSafeInsets GUI.
 local core=rb.Vector2.new(0,58);local origin=rb.Vector2.new(0,-58)
 local x,y=E.profileHeaderLayout(size,origin,rb.Rect.new(208,0,size.X,58),core)
 check(math.abs(origin.Y+y+core.Y+22-29)<.01,'profile center matches native TopBar center')
 check(x-104>=208 and x<=size.X-8,'profile clears left CoreUI and right screen edge')
end
print('PASS: '..n..' F60-C1 visitor, transparency, touch bounds and TopBar geometry checks')
