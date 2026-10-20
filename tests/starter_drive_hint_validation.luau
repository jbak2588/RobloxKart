local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local nodes=require('./helpers/practice_ui_nodes')
local pg=nodes.object('PlayerGui');pg.bounds=rb.Vector2.new(748,303)
local player=nodes.object('Player');player.WaitForChild=function()return pg end
player:SetAttribute('RaceState','GARAGE');player:SetAttribute('KDMEconomyState','GUEST')
local hub={};local shown,hidden,step=nodes.signal(),nodes.signal(),nodes.signal()
local camera={WorldToScreenPoint=function()return rb.Vector3.new(374,150,10),true end}
local workspace={CurrentCamera=camera,FindFirstChild=function()return hub end}
local services={Players={LocalPlayer=player},Workspace=workspace,RunService={RenderStepped=step},ProximityPromptService={PromptShown=shown,PromptHidden=hidden}}
local controller=luau.load(fs.readFile('src/client/WelcomeRewardController.luau'),{environment={
 game={GetService=function(_,n)return services[n]end},Instance={new=nodes.object},UDim=rb.UDim,UDim2=rb.UDim2,Vector2=rb.Vector2,Color3=rb.Color3,Enum=rb.Enum,
}})()
controller.start();local gui=pg:FindFirstChild('KDMWelcomeReward');local root=gui:FindFirstChild('SafeRoot');local hint=root:FindFirstChild('StarterHint')
local n=0;local function check(v,l)assert(v,l);n+=1 end
check(not gui.Enabled,'no welcome popup on arrival')
check(#hint.children==4,'only border, corner and minimal reward text; no kart or item assets')
local anchor={Position=rb.Vector3.new(0,2,0),IsA=function(_,c)return c=='BasePart'end}
local prompt={Name='LobbyDisplayTestDrive',Parent=anchor,Enabled=true,UIOffset=rb.Vector2.zero,IsDescendantOf=function(_,p)return p==hub end}
shown:Fire(prompt);step:Fire();check(gui.Enabled,'nearby kart prompt reveals reward explanation')
for _,size in {rb.Vector2.new(748,303),rb.Vector2.new(932,430),rb.Vector2.new(320,568),rb.Vector2.new(1920,1080)}do
 pg.bounds=size;step:Fire();local p,s=hint.AbsolutePosition,hint.AbsoluteSize
 check(p.X>=0 and p.Y>=0 and p.X+s.X<=size.X and p.Y+s.Y<=size.Y,'context hint stays in safe mobile/desktop canvas')
end
hidden:Fire(prompt);check(not gui.Enabled and prompt.UIOffset==rb.Vector2.zero,'leaving kart hides helper and restores native prompt')
shown:Fire(prompt);player:SetAttribute('HubOverlayOpen',true);step:Fire();check(not gui.Enabled and prompt.UIOffset==rb.Vector2.zero,'other UI never inherits displaced prompt')
player:SetAttribute('HubOverlayOpen',false);step:Fire();check(gui.Enabled,'nearby prompt resumes after overlay closes')
player:SetAttribute('KDMEconomyState','FOUND');step:Fire();check(not gui.Enabled,'qualified account never receives misleading starter reward')
player:SetAttribute('KDMEconomyState','GUEST');player:SetAttribute('LobbyDriveActive',true);step:Fire();check(not gui.Enabled,'driving hides guidance')
player:SetAttribute('LobbyDriveActive',false)
-- The same bounded helper explains native kiosk prompts to every account.
player:SetAttribute('KDMEconomyState','FOUND')
local action='GARAGE'
local station={Position=rb.Vector3.new(0,2,0),IsA=anchor.IsA,GetAttribute=function(_,name)return if name=='HubAction' then action else nil end}
local kiosk={Name='HubPrompt',Parent=station,Enabled=true,UIOffset=rb.Vector2.new(3,4),IsDescendantOf=prompt.IsDescendantOf}
for _,name in {'GARAGE','RACE','TRACKS'} do
 action=name;shown:Fire(kiosk);step:Fire()
 check(gui.Enabled and hint:FindFirstChild('Reward').Text==name,'nearby kiosk title for qualified account '..name)
 check(hint:FindFirstChild('Requirement').Text~='' and hint.BackgroundTransparency==.70,'quiet kiosk description '..name)
 hidden:Fire(kiosk)
 check(not gui.Enabled and kiosk.UIOffset==rb.Vector2.new(3,4),'leaving kiosk hides explanation and restores E/touch prompt '..name)
end
shown:Fire(kiosk);player:SetAttribute('KDMProfileOpen',true);step:Fire()
check(not gui.Enabled and kiosk.UIOffset==rb.Vector2.new(3,4),'profile modal suppresses kiosk helper')
player:SetAttribute('KDMProfileOpen',false);step:Fire();check(gui.Enabled,'kiosk helper resumes after profile closes')
player:SetAttribute('RaceState','RACING');step:Fire();check(not gui.Enabled,'kiosk helper never follows player into race')
player:SetAttribute('RaceState','GARAGE');hidden:Fire(kiosk)
shown:Fire(prompt);step:Fire();check(not gui.Enabled,'qualified account still cannot see starter grant invitation')
player:SetAttribute('KDMEconomyState','GUEST');step:Fire();check(gui.Enabled and hint:FindFirstChild('Reward').Text=='EARN K$ 5,000','original guest kart grant guidance preserved')
local nav=nodes.object('ScreenGui');nav.Name='KDMHubNavigation';nav.Enabled=true;nav.Parent=pg
local menus=nodes.object('Frame');menus.Name='Shortcuts';menus.Position=rb.UDim2.fromOffset(16,70);menus.Size=rb.UDim2.fromOffset(132,144);menus.Parent=nav
local wallet=nodes.object('Frame');wallet.Name='WalletCapsule';wallet.Position=rb.UDim2.fromOffset(16,16);wallet.Size=rb.UDim2.fromOffset(180,42);wallet.Parent=nav
local safe=nodes.object('Frame');safe.Name='SafeCanvas';safe.Size=rb.UDim2.fromScale(1,1);safe.Parent=nav
local actions=nodes.object('Frame');actions.Name='NextAction';actions.AnchorPoint=rb.Vector2.one;actions.Size=rb.UDim2.fromOffset(180,108);actions.Position=rb.UDim2.new(1,-12,1,-112);actions.Parent=safe
for _,size in {rb.Vector2.new(749,331),rb.Vector2.new(932,352),rb.Vector2.new(1102,407),rb.Vector2.new(1920,1022)} do
 pg.bounds=size
 for _,x in {40,size.X*.5,size.X-40} do
  camera.WorldToScreenPoint=function()return rb.Vector3.new(x,180,10),true end
  step:Fire();local p,s=hint.AbsolutePosition,hint.AbsoluteSize;local a,b=actions.AbsolutePosition,actions.AbsoluteSize
  check(p.X+s.X<=a.X or p.X>=a.X+b.X or p.Y+s.Y<=a.Y or p.Y>=a.Y+b.Y,'native helper clears fixed CTA '..tostring(size)..' x='..x..' p='..tostring(p)..' a='..tostring(a))
  local m,z=menus.AbsolutePosition,menus.AbsoluteSize
  check(p.X+s.X<=m.X or p.X>=m.X+z.X or p.Y+s.Y<=m.Y or p.Y>=m.Y+z.Y,'helper avoids left menu rectangle')
  check(prompt.UIOffset==rb.Vector2.zero,'native E/touch prompt keeps its original anchor')
 end
end
gui:Destroy();check(prompt.UIOffset==rb.Vector2.zero,'teardown restores native prompt')
shown:Fire(prompt);step:Fire();check(gui.Parent==nil,'teardown disconnects prompt and frame events')
print('PASS: '..n..' contextual starter guidance lifecycle and safe-area checks')
