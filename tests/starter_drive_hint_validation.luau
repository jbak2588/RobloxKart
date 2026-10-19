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
player:SetAttribute('LobbyDriveActive',false);step:Fire();gui:Destroy();check(prompt.UIOffset==rb.Vector2.zero,'teardown restores native prompt')
shown:Fire(prompt);step:Fire();check(gui.Parent==nil,'teardown disconnects prompt and frame events')
print('PASS: '..n..' contextual starter guidance lifecycle and safe-area checks')
