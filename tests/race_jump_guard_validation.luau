local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local nodes=require('./helpers/practice_ui_nodes')
local signal=nodes.signal
local function object(class)
 local o=nodes.object(class);o.Name=class;o.ChildAdded=signal();o.CharacterAdded=signal();o.DescendantAdded=signal()
 o.IsA=function(_,c)return c==class or (class=='ImageButton' and c=='GuiButton')end
 local props={};o.GetPropertyChangedSignal=function(_,k)if not props[k]then props[k]=signal()end;return props[k]end
 o.GetDescendants=function()return o.children end
 return o
end
local function humanoid()
 local h=object('Humanoid');h.JumpPower=50;h.JumpHeight=7.2;h.Jump=false;h.AutoJumpEnabled=true
 local enabled=true;h.StateEnabledChanged=signal()
 h.GetStateEnabled=function()return enabled end
 h.SetStateEnabled=function(_,s,v)local old=enabled;enabled=v;if v~=old then h.StateEnabledChanged:Fire(s,v)end end
 return h
end
local player=object('Player');local character=object('Model');local h=humanoid();h.Parent=character;player.Character=character
local pg=object('PlayerGui');pg.Parent=player
local workspace=object('Workspace');local scriptNode=object('LocalScript')
local binding=nil;local unbound=false;local focus=nil
local actions={BindActionAtPriority=function(_,name,f,touch,priority,...)
 binding={name=name,callback=f,touch=touch,priority=priority,keys={...}}
end,UnbindAction=function()unbound=true end}
local input={GetFocusedTextBox=function()return focus end}
local services={Players={LocalPlayer=player},Workspace=workspace,ContextActionService=actions,UserInputService=input}
luau.load(fs.readFile('src/replicatedFirst/RaceJumpGuard.client.luau'),{environment={game={GetService=function(_,n)return services[n]end},script=scriptNode,Enum=rb.Enum}})()
local n=0;local function check(v,l)assert(v,l);n+=1 end
check(binding and binding.priority>rb.Enum.ContextActionPriority.High.Value and not binding.touch,'early high-priority binding without another touch button')
check(table.find(binding.keys,rb.Enum.KeyCode.Space) and table.find(binding.keys,rb.Enum.PlayerActions.CharacterJump),'keyboard and default jump action both covered')
check(not h:GetStateEnabled() and h.JumpPower==0 and h.JumpHeight==0 and not h.AutoJumpEnabled,'role not replicated yet locks both jump modes and auto-jump')
check(binding.callback()==rb.Enum.ContextActionResult.Sink,'Space sunk before any race state or digital pad exists')
local jump=object('ImageButton');jump.Name='JumpButton';jump.Visible=true;jump.Parent=pg;jump.FindFirstAncestor=function(_,name)return if name=='TouchGui' then pg else nil end
pg.DescendantAdded:Fire(jump);check(not jump.Visible,'late native mobile jump button hidden')
jump.Visible=true;jump:GetPropertyChangedSignal('Visible'):Fire();check(not jump.Visible,'native controls cannot re-show race jump button')
local custom=object('ImageButton');custom.Name='Forward';custom.Visible=true;pg.DescendantAdded:Fire(custom);check(custom.Visible,'custom digital pad untouched')
workspace:SetAttribute('KDMServerRole','RACE')
for _,phase in {'PRE_RACE','WAITING','COUNTDOWN','RACING','FINISHING','FINISHED'}do
 player:SetAttribute('RaceState',phase);check(binding.callback()==rb.Enum.ContextActionResult.Sink and not h:GetStateEnabled(),'seat lock retained during '..phase)
end
h.Jump=true;h:GetPropertyChangedSignal('Jump'):Fire();check(not h.Jump,'direct mobile jump request cleared')
h.JumpPower=50;h:GetPropertyChangedSignal('JumpPower'):Fire();check(h.JumpPower==0,'late jump-power initialization cannot reopen seat escape')
h.JumpHeight=7.2;h:GetPropertyChangedSignal('JumpHeight'):Fire();check(h.JumpHeight==0,'height mode cannot reopen seat escape')
h:SetStateEnabled(rb.Enum.HumanoidStateType.Jumping,true);check(not h:GetStateEnabled(),'late enabled-state write re-locked')
focus={};check(binding.callback()==rb.Enum.ContextActionResult.Pass and not h:GetStateEnabled(),'chat accepts spaces while physical jumping stays disabled');focus=nil
workspace:SetAttribute('KDMServerRole','HUB');check(h:GetStateEnabled() and h.JumpPower==50 and h.JumpHeight==7.2 and h.AutoJumpEnabled,'Hub restores original avatar jump settings')
check(jump.Visible and binding.callback()==rb.Enum.ContextActionResult.Pass,'Hub restores touch jump and keyboard input')
workspace:SetAttribute('KDMServerRole','RACE');local replacement=object('Model');player.Character=replacement;player.CharacterAdded:Fire(replacement)
local h2=humanoid();h2.Parent=replacement;replacement.ChildAdded:Fire(h2);check(not h2:GetStateEnabled() and h2.JumpPower==0,'late respawn Humanoid protected')
scriptNode.Destroying:Fire();check(unbound and h2:GetStateEnabled() and h2.JumpPower==50 and jump.Visible,'teardown unbinds and restores original controls')
print('PASS: '..n..' race-arrival jump guard / mobile visibility / lifecycle checks')
