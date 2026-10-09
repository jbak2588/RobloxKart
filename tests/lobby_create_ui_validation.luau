local fs,luau=require("@lune/fs"),require("@lune/luau")
local fixture=fs.readFile("tests/garage_transition_validation.luau")
local setup=fixture:sub(1,assert(fixture:find("local controller = luau.load",1,true))-1)
local scenario=[=[
child(shared,"ModuleScript","LobbyTitleCatalog")
modules.LobbyTitleCatalog=luau.load(fs.readFile("src/shared/LobbyTitleCatalog.luau"))()
for _,name in {"RoomDisplay","HubGuidanceState","LobbyCreateView"} do
 child(client,"ModuleScript",name);modules[name]=luau.load(fs.readFile("src/client/"..name..".luau"),{environment=environment})()
end
local r=child(replicated,"RemoteEvent","MatchRoomControl")
local c=luau.load(fs.readFile("src/client/MatchRoomUiController.luau"),{environment=environment})()
c.start()
local gui=playerGui.KDMMatchRooms;local panel=gui.Frame.Frame;local modal=panel.CreateLobbyModal
local box=modal.Content.LobbyTitleInput
local function snapshot(data)r.OnClientEvent:Fire("Snapshot",data or {visible=true,rooms={},maxPlayers=4})end
local function opener()
 for _,item in panel:GetChildren() do if item.Text=="CREATE RACE" then return item end end
 error("Create button absent")
end
local function open()snapshot();opener().Activated:Fire();check(modal.Visible,"modal opened")end
local function acknowledged()snapshot({visible=false,rooms={}});snapshot()end
snapshot();check(panel.Title.Text=="RACE LIST","browser wording")
check(panel.Status.Text=="CREATE OR JOIN A RACE • 1–4 RACERS" and not panel.NextAction.Visible,"browser capacity without duplicate guidance")
check(gui.ScreenInsets==rb.Enum.ScreenInsets.CoreUISafeInsets,"native safe insets")
check(gui.Frame.BackgroundTransparency==.82 and gui.Frame.Active,'directory reveals live world and blocks world input')
check(math.abs(panel.Size.Y.Scale-.9)<.00001,'directory leaves safe world margin')
check(opener().BackgroundColor3==modules.KDMUiTheme.PrimaryAction and opener().Font==rb.Enum.Font.GothamBold,'shared primary style')
check(opener():FindFirstChild('UICorner').CornerRadius==rb.UDim.new(0,8),'shared eight pixel button corners')
local before=r.fireCount or 0;open();modal.Cancel.Activated:Fire()
check(modal.Heading.Text=="CREATE RACE" and modal.Content.TitleLabel.Text=="RACE TITLE (OPTIONAL)" and box.PlaceholderText=="Your Race Title","modal name terminology")
check(modal.Content.Hint.Text=="Leave blank to use your racer name." and modal.Content.QuickTitles.Text=="QUICK TITLES","modal help preserved")
check(modal.Content.CharacterCount.Text=="0 / 32","empty input count")
check(modal.Create.Text=='CREATE RACE' and modal.Create.TextSize==19 and modal.Cancel.TextSize==19,'consistent footer hierarchy')
open();local clicks=r.fireCount or 0
opener().Activated:Fire()
for _,item in panel:GetChildren() do if item.Text=='BACK' then item.Activated:Fire() end end
check(modal.Visible and (r.fireCount or 0)==clicks,'Create modal prevents background actions')
modal.Cancel.Activated:Fire()
check(not modal.Visible and (r.fireCount or 0)==before,"cancel no remote/reserve")
open();modal.Create.Activated:Fire()
check(r.lastFire[1]=="Create" and r.lastFire[2]=="DEFAULT","blank default")
local sent=r.fireCount;modal.Create.Activated:Fire();check(r.fireCount==sent,"double tap once")
acknowledged()
for _,id in modules.LobbyTitleCatalog.Order do
 open();modal.Content[id].Activated:Fire()
 check(box.Text==modules.LobbyTitleCatalog.Presets[id] and modal.Content[id].AutoLocalize==false,"preset editable identity")
 modal.Create.Activated:Fire();check(r.lastFire[2]=="PRESET" and r.lastFire[3]==id,"preset payload allowlist ID")
 acknowledged()
end
open();modal.Content.LETS_RACE.Activated:Fire();box.Text="My lobby"
modal.Create.Activated:Fire();check(r.lastFire[2]=="CUSTOM" and r.lastFire[3]=="My lobby","edited preset custom")
acknowledged();open();box.Text=string.rep("🚗",33)
check(utf8.len(box.Text)==32 and modal.Content.CharacterCount.Text=="32 / 32","Unicode codepoint clamp")
check(box.AutoLocalize==false and modal.Heading.AutoLocalize~=false,"identity versus system localization")
box.FocusLost:Fire(true);check(r.lastFire[2]=="CUSTOM" and utf8.len(r.lastFire[3])==32,"Enter submits")
acknowledged()
local function bounds(item,parent,label)
 local p,s=item.AbsolutePosition,item.AbsoluteSize;local a,b=parent.AbsolutePosition,parent.AbsoluteSize
 check(p.X>=a.X-.01 and p.Y>=a.Y-.01 and p.X+s.X<=a.X+b.X+.01 and p.Y+s.Y<=a.Y+b.Y+.01,label)
end
for _,screen in {rb.Vector2.new(844,332),rb.Vector2.new(740,302),rb.Vector2.new(705,302),rb.Vector2.new(390,720),rb.Vector2.new(1920,1022)} do
 safeSize=screen;open()
 bounds(panel,gui,"panel safe bounds");bounds(modal.Create,panel,"Create safe bounds");bounds(modal.Cancel,panel,"Cancel safe bounds")
 check(panel.RoomList.AbsoluteSize.Y>=100,"short screen retains usable scrolling rows")
 bounds(panel.RoomList,panel,"browser list safe bounds")
 local counter=modal.Content.CharacterCount;local hint=modal.Content.Hint
 check(counter.AbsolutePosition.Y>=box.AbsolutePosition.Y+box.AbsoluteSize.Y and counter.AbsolutePosition.Y+counter.AbsoluteSize.Y<=hint.AbsolutePosition.Y,"counter directly between input and hint")
 check(math.abs(counter.AbsolutePosition.X+counter.AbsoluteSize.X-box.AbsolutePosition.X-box.AbsoluteSize.X)<.01 and counter.TextXAlignment==rb.Enum.TextXAlignment.Right,"counter aligned with input right edge")
 for _,id in modules.LobbyTitleCatalog.Order do
  local b=modal.Content[id];check(b.AbsoluteSize.X>=44 and b.AbsoluteSize.Y>=44,"preset touch target")
 end
 input.OnScreenKeyboardPosition=rb.Vector2.new(0,180);input.OnScreenKeyboardVisible=true
 bounds(panel,gui,"keyboard panel safe bounds")
 check(modal.Create.AbsolutePosition.Y+modal.Create.AbsoluteSize.Y<180,"keyboard never covers footer")
 input.OnScreenKeyboardVisible=false;modal.Cancel.Activated:Fire()
end
snapshot({visible=true,rooms={{id="a",hostName="Host",count=1,maxPlayers=4,state="WAITING",lobbyTitleKind="CUSTOM",lobbyTitle="Filtered custom title"}},maxPlayers=4})
local row=panel.RoomList:FindFirstChild("Frame")
check(row:FindFirstChild("Name").Text=="Filtered custom title" and not row:FindFirstChild("Name").AutoLocalize,"public title row identity")
check(row.Detail.Text:find("HOST: Host",1,true) and row:FindFirstChild("Name").TextTruncate==rb.Enum.TextTruncate.AtEnd,"two line metadata/truncate")
local entry=row:FindFirstChild("TextButton")
check(entry.Text=="ENTER RACE" and not panel.NextAction.Visible,"available lobby action wording")
entry.Activated:Fire();check(r.lastFire[1]=="Join" and r.lastFire[2]=="a","entry retains Join protocol")
acknowledged()
snapshot({visible=true,rooms={{id="b",hostName="Host",count=2,maxPlayers=4,state="RACING",lobbyTitleKind="CUSTOM",lobbyTitle=string.rep("W",32)}},maxPlayers=4})
row=panel.RoomList:FindFirstChild("Frame");entry=row:FindFirstChild("TextButton")
check(entry.Text=="QUEUE NEXT" and row:FindFirstChild("Name").TextTruncate==rb.Enum.TextTruncate.AtEnd,"queue and long name truncation preserved")
entry.Activated:Fire();check(r.lastFire[1]=="Queue" and r.lastFire[2]=="b","queue protocol preserved")
acknowledged()
snapshot({visible=true,room={hostName="NewHost",hostUserId=2,state="WAITING",members={},available={},maxPlayers=4,lobbyTitleKind="PRESET",lobbyTitle="Drift Practice"}})
check(panel.Title.Text=="Drift Practice" and panel.Title.AutoLocalize==false,"owned lobby main title")
check(panel.NextAction.Visible and panel.NextAction.Text=="WAIT FOR HOST • ITEMS NEXT","nonhost useful guidance retained")
snapshot({visible=true,room={hostName="QueueHost",membershipKind="QUEUED",state="RACING",count=2,maxPlayers=4,queuePosition=1,lobbyTitleKind="DEFAULT"}})
check(panel.RoomList:FindFirstChild("Frame"):FindFirstChild("Name").Text=="QueueHost's Race","queue default title fallback")
check(panel.NextAction.Visible and panel.NextAction.Text=="WAITING FOR NEXT RACE","queue useful guidance retained")
open();player:SetAttribute("RaceState","RACING")
check(not gui.Enabled and not modal.Visible,"race closes keyboard/modal")
gui:Destroy()
print("PASS: "..count.." production mobile modal/title/preset/input/safe-area/lifecycle contracts")
]=]
setup=setup:gsub('function methods:IsA%(name%) return self.ClassName == name', 'function methods:IsA(name) return (name=="GuiObject" and (self.ClassName=="Frame" or self.ClassName=="TextLabel" or self.ClassName=="TextButton")) or self.ClassName == name')
luau.load(setup..scenario)()
