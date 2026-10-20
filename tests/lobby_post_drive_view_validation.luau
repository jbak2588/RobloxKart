local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local nodes=require('./helpers/practice_ui_nodes')
local View=luau.load(fs.readFile('src/client/LobbyPostDriveView.luau'),{environment={
 Instance={new=nodes.object},UDim=rb.UDim,UDim2=rb.UDim2,Vector2=rb.Vector2,Color3=rb.Color3,Enum=rb.Enum,
}})()
local n=0;local function check(v,l)assert(v,l);n+=1 end
local parent=nodes.object('PlayerGui');parent.bounds=rb.Vector2.new(748,303)
local eligible=true;local opened=0
local view=View.new(parent,function()return eligible end,function()opened+=1 end)
local gui=view.gui;local shade=gui:FindFirstChild('Modal');local panel=shade:FindFirstChild('Panel')
local play,later=panel:FindFirstChild('PlayNow'),panel:FindFirstChild('Later')
check(not gui.Enabled,'no popup on login, respawn or default construction')
check(gui.ScreenInsets==rb.Enum.ScreenInsets.CoreUISafeInsets and shade.ClassName=='Frame' and shade.BackgroundTransparency==1 and not shade.Active,'transparent nonmodal safe canvas preserves Lobby input')
check(panel.BackgroundTransparency>=.4 and not panel.Active,'Lobby remains visible through the small card')
check((play.Text=='Play now' or play.Text=='RACE NOW') and (later.Text=='Later' or later.Text=='LATER'),'requested English actions')
check(panel:FindFirstChild('Message').Text:find('other players',1,true)~=nil,'requested global competition message')
for _,size in {rb.Vector2.new(748,303),rb.Vector2.new(932,430),rb.Vector2.new(320,568),rb.Vector2.new(1920,1080)}do
 parent.bounds=size;view:show();view:update()
 local pos,s=panel.AbsolutePosition,panel.AbsoluteSize
 check(pos.X>=12 and pos.Y>=12 and pos.X+s.X<=size.X*.5 and pos.Y+s.Y<=size.Y-12,'panel stays entirely in left safe half')
 local title,body=panel:FindFirstChild('Title'),panel:FindFirstChild('Message')
 check(title.AbsolutePosition.Y+title.AbsoluteSize.Y<body.AbsolutePosition.Y,'title/body separated')
 check(body.AbsolutePosition.Y+body.AbsoluteSize.Y<play.AbsolutePosition.Y,'body clears actions')
 check(play.AbsoluteSize.Y>=44 and later.AbsoluteSize.Y>=44,'touch targets at least 44px')
 check(play.AbsolutePosition.X+play.AbsoluteSize.X<later.AbsolutePosition.X or play.AbsolutePosition.Y+play.AbsoluteSize.Y<later.AbsolutePosition.Y,'side-by-side or stacked actions do not overlap')
end
later.Activated:Fire();check(not gui.Enabled and opened==0,'Later closes and stays in Lobby')
play.Activated:Fire();check(opened==0,'hidden stale activation ignored')
view:show();play.Activated:Fire();check(not gui.Enabled and opened==1,'Play now closes before one Race navigation')
play.Activated:Fire();check(opened==1,'double activation cannot open Race twice')
view:show();eligible=false;play.Activated:Fire();check(not gui.Enabled and opened==1,'state change blocks stale Race navigation')
view:show();check(not gui.Enabled,'unavailable Lobby never shows popup')
eligible=true;view:show();eligible=false;view:update();check(not gui.Enabled,'new driving/overlay/launch eligibility change dismisses')
view:destroy();check(gui.Parent==nil,'popup teardown')
print('PASS: '..n..' post-drive nonmodal actions / responsive safe layout / eligibility / cleanup checks')
