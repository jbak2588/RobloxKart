-- Execute production practice input/UI; icon asset loading and platform input are injected.
local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local nodes=require('./helpers/practice_ui_nodes');local object,signal=nodes.object,nodes.signal
local n=0;local function check(v,l)assert(v,l);n+=1 end
local now,focused,canUse=1000,false,true
local menu={MenuIsOpen=false}
local input={InputBegan=signal(),GetFocusedTextBox=function()return if focused then {}else nil end}
local policy=luau.load(fs.readFile('src/shared/LobbyPracticePolicy.luau'),{environment={Color3=rb.Color3}})()
local layout=luau.load(fs.readFile('src/shared/LobbyPracticeLayout.luau'))()
local mobile=luau.load(fs.readFile('src/client/MobileControlView.luau'),{environment={Color3=rb.Color3,Vector2=rb.Vector2,UDim2=rb.UDim2,UDim=rb.UDim,Enum=rb.Enum,Instance={new=object}}})()
local drive=luau.load(fs.readFile('src/client/LobbyDriveLayout.luau'))()
local alive=true
local icon={cache=function()return {start=function()end,destroy=function()alive=false end}end,
 new=function()return {update=function()end}end}
local parent=setmetatable({},{__index=function(_,k)return k end})
local modules={CombatFeedbackView={new=function()return {update=function()end,destroy=function()end}end},LobbyPracticePolicy=policy,LobbyPracticeLayout=layout,KDMItemIconView=icon,MobileControlView=mobile}
local view=luau.load(fs.readFile('src/client/LobbyPracticeView.luau'),{environment={
 game={GetService=function(_,name)
  if name=='ReplicatedStorage'then return {Shared=parent}elseif name=='Workspace'then return {GetServerTimeNow=function()return now end}
  elseif name=='UserInputService'then return input elseif name=='GuiService'then return menu else return {}end
 end},script={Parent=parent},require=function(k)return modules[k]end,Instance={new=object},UDim=rb.UDim,UDim2=rb.UDim2,
 Vector2=rb.Vector2,Color3=rb.Color3,Enum=rb.Enum,task={},
}})()
local gui,canvas,player=object('ScreenGui'),object('Frame'),object('Player')
gui.Enabled=true;canvas.Parent=gui;canvas.bounds=rb.Vector2.new(748,303)
player:SetAttribute('LobbyDriveGeneration',7)
for _,id in policy.Items do player:SetAttribute('LobbyCharge'..id,1)end
local sent={};local remote={FireServer=function(_,...)table.insert(sent,{...})end}
local v=view.new(canvas,player,remote,function()return canUse end)
local l=drive.apply(mobile.layout(canvas.bounds),canvas.bounds)
local actualLayout=v:update(true,l,58,nil)
check(actualLayout.boostY>actualLayout.y+actualLayout.height and actualLayout.gaugeY>actualLayout.boostY,'production view returns item-relative Boost placement on compact mobile')
local panel=canvas:FindFirstChild('PracticeItems');local info=canvas:FindFirstChild('PracticeFeedback')
for index,id in {'Slick','Missile','Smoke','Thunder'}do
 local position=panel:FindFirstChild(id).Position
 check(position.Y.Offset==0 and position.X.Offset==(index-1)*(actualLayout.cell+6),'production attack row ordering '..id)
end
for index,id in {'Nitro','Shield'}do
 local position=panel:FindFirstChild(id).Position
 check(position.Y.Offset==actualLayout.cell+6 and position.X.Offset==(index-1)*(actualLayout.cell+6),'production utility row ordering '..id)
end
for _,id in policy.Items do
 local b=panel:FindFirstChild(id);check(b~=nil and b.Active,'visible direct practice item '..id)
 b.Activated:Fire();check(sent[#sent][1]=='UseItem'and sent[#sent][2]==7 and sent[#sent][3]==id and #sent[#sent]==3,'one generation-bound request per direct tap')
end
local before=#sent
for _,key in {'N','Z','X','C','V','B'}do input.InputBegan:Fire({KeyCode={Name=key}},false)end
check(#sent==before+6,'practice keyboard direct actions')
before=#sent
for _,key in {'One','Two','Three','Four','Five','Q'}do input.InputBegan:Fire({KeyCode={Name=key}},false)end
check(#sent==before,'race item shortcuts untouched')
input.InputBegan:Fire({KeyCode={Name='N'}},true);check(#sent==before,'processed input ignored')
for _,mode in {'focus','menu','disabled','inactive','gate'}do
 focused=mode=='focus';menu.MenuIsOpen=mode=='menu';gui.Enabled=mode~='disabled';canUse=mode~='gate'
 v:update(mode~='inactive',l,58,nil);panel:FindFirstChild('Missile').Activated:Fire()
 check(#sent==before,'UI input suppressed for '..mode)
end
focused=false;menu.MenuIsOpen=false;gui.Enabled=true;canUse=true;v:update(true,l,58,nil)
player:SetAttribute('LobbyMissileIncomingCount',1);v:update(true,l,58,nil)
check(not info.Text:find('INCOMING',1,true) and info.Text:find('/3',1,true),'charge widget never displays combat warnings; shared top feedback owns them')
player:SetAttribute('LobbyMissileIncomingCount',0);player:SetAttribute('LobbyBonusProgress',3);player:SetAttribute('LobbyBonusPending',true)
now+=2;v:update(true,l,58,nil);check(info.Text:find('3/3',1,true)and info.Text:find('PENDING',1,true),'Nitro pending progress visible')
player:SetAttribute('LobbyChargeSmoke',0);player:SetAttribute('LobbyReadyAtSmoke',now+5.2);v:update(true,l,58,nil)
check(not panel:FindFirstChild('Smoke').Active and panel:FindFirstChild('Smoke'):FindFirstChild('Caption').Text=='SMOKE 6s','refill countdown follows authoritative server time')
for _=1,50 do v:update(true,l,58,nil)end
before=#sent;panel:FindFirstChild('Nitro').Activated:Fire();check(#sent==before+1,'render updates never add duplicate handlers')
v:destroy();before=#sent;input.InputBegan:Fire({KeyCode={Name='N'}},false)
check(#sent==before and not alive and not panel.Parent and not info.Parent,'teardown disconnects input and assets')
print('PASS: '..n..' actual practice view / six direct items / guarded dispatch / warnings / refill / cleanup checks')
