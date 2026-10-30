-- Real input transport: desktop auto/GAS and differential mobile parity vs PV1275.
local fs,luau,rb,process,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/process'),require('@lune/serde')
local fixture=fs.readFile('tests/mobile_touch_validation.luau')
local prefix=fixture:sub(1,assert(fixture:find('local input=modules.KartInputController; input.start()',1,true))-1)
local path='src/client/KartInputController.luau'
local baseline=process.exec('git',{'show','70392de969caf7e56d232b9f35e33c035d4f432d:'..path}).stdout
local function run(source,scenario)
 local proxy=table.clone(fs);proxy.readFile=function(p)return if p==path then source else fs.readFile(p)end
 return luau.load(prefix..[=[
env.game.GameId=10768420544;env.game.PlaceId=127925465904803
local world=object('Workspace');services.Workspace=world;world:SetAttribute('KDMGasPedalEnabled',true)
services.GuiService.MenuClosed=signal()
local input=modules.KartInputController;input.start()
local function tick()services.RunService.Heartbeat:Fire(.3)end
local function latest()return control._p.calls[#control._p.calls]end
local function key(code,down)
 keys[tostring(code)]=down
 ui[if down then 'InputBegan' else 'InputEnded']:Fire({KeyCode=code},false);tick()
end
]=]..scenario,{environment={require=function(name)return if name=='@lune/fs' then proxy else require(name)end}})()
end
local current=fs.readFile(path)
local result=run(current,[=[
ui.TouchEnabled=false;ui.PreferredInput=rb.Enum.PreferredInput.KeyboardAndMouse
check(input.desktopAutoEnabled(),'desktop exact production gate');tick()
check(latest()[1]==1 and latest()[4]==false,'no keys auto drive at ordinary cap')
key(rb.Enum.KeyCode.W,true);check(latest()[1]==1 and latest()[4]==true,'W requests existing GAS90 transport')
key(rb.Enum.KeyCode.A,true);key(rb.Enum.KeyCode.LeftShift,true)
check(latest()[2]==-1 and latest()[3] and latest()[4],'steer/drift independent of GAS')
key(rb.Enum.KeyCode.S,true);check(latest()[1]==-1 and not latest()[4],'S overrides W with brake/reverse')
key(rb.Enum.KeyCode.S,false);key(rb.Enum.KeyCode.W,false)
check(latest()[1]==1 and not latest()[4],'W release returns ordinary auto drive')
key(rb.Enum.KeyCode.W,true);focused={};ui.TextBoxFocused:Fire();tick()
check(latest()[1]==0 and latest()[2]==0 and not latest()[3] and not latest()[4],'typing is neutral')
focused=nil;ui.TextBoxFocusReleased:Fire();tick();check(latest()[4],'typing end resumes W')
ui.WindowFocusReleased:Fire();for _=1,4 do tick()end
check(latest()[1]==0 and not latest()[4],'blur stays neutral across keepalives')
ui.WindowFocused:Fire();tick();check(latest()[1]==1 and latest()[4],'focus restores current keys')
services.GuiService.MenuIsOpen=true;services.GuiService.MenuOpened:Fire();tick()
check(latest()[1]==0 and not latest()[4],'native menu neutral')
services.GuiService.MenuIsOpen=false;services.GuiService.MenuClosed:Fire();tick()
check(latest()[1]==1 and latest()[4],'native menu close restores current keys')
humanoid.SeatPart=nil;tick();check(latest()[1]==0 and not latest()[4],'unseated neutral')
humanoid.SeatPart=seat;seat:SetAttribute('PrototypeKartSeat',false);seat:SetAttribute('LobbyKartSeat',true)
player.UserId=1;kart:SetAttribute('LobbyOwnerUserId',1);player:SetAttribute('LobbyDriveActive',true)
local lobby={};input.setLobbyInputSender(function(...)table.insert(lobby,table.pack(...))end)
tick();check(lobby[#lobby][1]==1 and lobby[#lobby][4],'Park uses same desktop GAS')
key(rb.Enum.KeyCode.S,true);check(lobby[#lobby][1]==-1 and not lobby[#lobby][4],'Park brake priority')
ui.WindowFocusReleased:Fire();tick();check(lobby[#lobby][1]==0 and not lobby[#lobby][4],'Park focus neutral')
ui.WindowFocused:Fire();key(rb.Enum.KeyCode.S,false);key(rb.Enum.KeyCode.W,false)
world:SetAttribute('KDMGasPedalEnabled',false);tick();check(lobby[#lobby][1]==0 and lobby[#lobby].n==3,'disabled rollout preserves legacy PC transport')
world:SetAttribute('KDMGasPedalEnabled',true);env.game.PlaceId=1;tick()
check(lobby[#lobby][1]==0 and lobby[#lobby].n==3,'unapproved place remains manual')
return count
]=])
local mobile=[=[
local log={};local function capture()tick();table.insert(log,table.clone(latest()))end
input.setTouchEnabled(true);input.setTouchActions(1,-.5,true);capture()
input.setGasHeld(true);capture();key(rb.Enum.KeyCode.W,true);capture()
input.setTouchActions(-1,.5,false);input.setGasHeld(false);capture()
ui.WindowFocusReleased:Fire();capture();ui.WindowFocused:Fire();capture()
input.setTouchActions(1,1,true);input.setGasHeld(true);capture()
services.GuiService.MenuIsOpen=true;services.GuiService.MenuOpened:Fire();capture()
services.GuiService.MenuIsOpen=false;services.GuiService.MenuClosed:Fire();capture()
focused={};ui.TextBoxFocused:Fire();capture();focused=nil;ui.TextBoxFocusReleased:Fire();capture()
-- A phone with a physical keyboard still retains its preexisting keyboard path.
ui.PreferredInput=rb.Enum.PreferredInput.KeyboardAndMouse;capture()
key(rb.Enum.KeyCode.W,false);capture();key(rb.Enum.KeyCode.S,true);capture()
input.setTouchEnabled(false);capture();humanoid.SeatPart=nil;capture()
return log
]=]
assert(serde.encode('json',run(baseline,mobile))==serde.encode('json',run(current,mobile)),'mobile payload/lifecycle must match PV1275 byte for byte')
local policy=luau.load(fs.readFile('src/shared/GasPedalPolicy.luau'))()
assert(policy.cap(70,true,true,true,true,1,false,false,false)==90,'existing server permits keyboard GAS90')
assert(policy.cap(70,false,true,true,true,1,false,false,false)==70,'W release restores70')
assert(policy.cap(70,true,true,true,true,-1,false,false,false)==70,'reverse cannot receive GAS')
print('PASS: '..result..' desktop/transport checks, production-policy cap90 and byte-identical mobile lifecycle vs PV1275')
