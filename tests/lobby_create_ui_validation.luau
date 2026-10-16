local fs,luau=require('@lune/fs'),require('@lune/luau')
local fixture=fs.readFile('tests/garage_transition_validation.luau')
local setup=fixture:sub(1,assert(fixture:find('local controller = luau.load',1,true))-1)
setup=setup:gsub('for _, entry in listeners do','for _, entry in table.clone(listeners) do')
setup=setup:gsub('function methods:IsA%(name%) return self.ClassName == name','function methods:IsA(name) return (name=="GuiObject" and (self.ClassName=="Frame" or self.ClassName=="TextLabel" or self.ClassName=="TextButton" or self.ClassName=="ImageLabel")) or self.ClassName == name')
local scenario=[=[
function methods:FindFirstChildOfClass(class)for _,v in self:GetChildren()do if v:IsA(class)then return v end end end
child(shared,'ModuleScript','LobbyTitleCatalog')
modules.LobbyTitleCatalog=luau.load(fs.readFile('src/shared/LobbyTitleCatalog.luau'))()
for _,name in {'KDMUiStyleHelper','RoomDisplay','HubGuidanceState','LobbyCreateView','RaceBrowserLayout'}do
 child(client,'ModuleScript',name)
 modules[name]=luau.load(fs.readFile('src/client/'..name..'.luau'),{environment=environment})()
end
modules.TrackCatalog.Entries.Track01.PreviewImageAssetId='rbxassetid://75369478362729'
local r=child(replicated,'RemoteEvent','MatchRoomControl')
luau.load(fs.readFile('src/client/MatchRoomUiController.luau'),{environment=environment})().start()
local gui=playerGui.KDMMatchRooms;local shade=gui.Overlay;local panel=shade.Frame;local modal=panel.CreateLobbyModal
local box=modal.Content.LobbyTitleInput
local function snapshot(data)r.OnClientEvent:Fire('Snapshot',data or {visible=true,rooms={},allTracks=true,maxPlayers=4})end
local function btn(text)for _,v in panel:GetChildren()do if v.Text==text then return v end end;error('Missing '..text)end
snapshot()
check(panel.Title.Text=='PLAY TOGETHER','global browser replaces track-first list')
check(btn('PLAY NOW').Visible and btn('NEW RACE').Visible,'existing rooms primary, explicit creation secondary')
check(gui.ScreenInsets==rb.Enum.ScreenInsets.CoreUISafeInsets,'browser respects native safe insets')
btn('PLAY NOW').Activated:Fire();check(r.lastFire[1]=='QuickPlay','one action starts server-owned recommendation')
snapshot({visible=false,rooms={}});snapshot()
btn('NEW RACE').Activated:Fire()
local row=panel.RoomList.RaceRow
check(row.TrackIcon.Image=='rbxassetid://75369478362729','catalog preview becomes track thumbnail')
row.TextButton.Activated:Fire()
check(r.lastFire[1]=='Browse'and r.lastFire[4]=='Track01'and modal.Visible,'new race explicitly chooses track')
snapshot({visible=true,rooms={},trackId='Track01',trackName='Practice'})
check(box.Text==''and modal.Content.CharacterCount.Text=='0 / 32','optional title starts blank')
modal.Create.Activated:Fire()
check(r.lastFire[1]=='Create'and r.lastFire[2]=='DEFAULT','empty title uses existing filtered default protocol')
local sent=r.fireCount;modal.Create.Activated:Fire();check(r.fireCount==sent,'duplicate create blocked')
snapshot({visible=false,rooms={}});snapshot({visible=true,rooms={},trackName='Practice'})
btn('CREATE RACE').Activated:Fire();box.Text=string.rep('🚗',33)
check(utf8.len(box.Text)==32,'Unicode title limit retained')
modal.Create.Activated:Fire();check(r.lastFire[2]=='CUSTOM'and utf8.len(r.lastFire[3])==32,'custom title filtering payload retained')
snapshot({visible=false,rooms={}})
snapshot({visible=true,allTracks=true,rooms={{id='real-room',trackId='Track01',hostName='Host',humanCount=1,botCount=1,reservedCount=1,queuedCount=0,count=2,maxPlayers=4,state='WAITING'}}})
row=panel.RoomList.RaceRow
check(row.Detail.Text:find('1 PLAYERS · 1 BOT',1,true)~=nil,'people and bots distinguished')
check(row.Detail.Text:find('1 JOINING',1,true)~=nil,'reserved seat is not reported as an arrived human')
check(row.RaceTitle.AutoLocalize==false and row.RaceTitle.TextTruncate==rb.Enum.TextTruncate.AtEnd,'filtered room identity stays readable without covering status')
check(row.TextButton.Text=='JOIN RACE','joinable room action')
row.TextButton.Activated:Fire();check(r.lastFire[1]=='Join'and r.lastFire[2]=='real-room','specific room identity retained')
snapshot({visible=false,rooms={}})
snapshot({visible=true,allTracks=true,rooms={{id='running',trackId='Track01',hostName='Host',humanCount=2,botCount=0,count=2,maxPlayers=4,state='RACING',queuedCount=1}}})
row=panel.RoomList.RaceRow;check(row.TextButton.Text=='NEXT RACE','human race is queued rather than interrupted')
row.TextButton.Activated:Fire();check(r.lastFire[1]=='Queue'and r.lastFire[2]=='running','queue protocol retained')
snapshot({visible=false,rooms={}})
snapshot({visible=true,rooms={},trackId='Track01',trackName='Practice'})
check(btn('PRACTICE SOLO').Visible,'track-specific browser offers private practice')
btn('PRACTICE SOLO').Activated:Fire();check(r.lastFire[1]=='Practice','practice uses explicit private routing action')
snapshot({visible=false,rooms={}})
for _,screen in {rb.Vector2.new(844,332),rb.Vector2.new(740,302),rb.Vector2.new(390,720),rb.Vector2.new(1920,1022)}do
 safeSize=screen;shade:GetPropertyChangedSignal('AbsoluteSize'):Fire();snapshot()
 local ps=panel.AbsoluteSize
 check(ps.X<=screen.X and ps.Y<=screen.Y,'browser stays inside safe canvas')
 check(panel.Title.TextSize>=22 and panel.Status.TextSize>=14,'mobile and desktop type remains readable')
 check(panel.RoomList.AbsoluteSize.Y>100,'short landscape keeps scrolling viewport')
 btn('NEW RACE').Activated:Fire();panel.RoomList.RaceRow.TextButton.Activated:Fire()
 check(modal.Create.AbsoluteSize.Y>=44 and modal.Cancel.AbsoluteSize.Y>=44,'create targets remain touch-safe')
 input.OnScreenKeyboardPosition=rb.Vector2.new(0,180);input.OnScreenKeyboardVisible=true
 check(modal.Create.AbsolutePosition.Y+modal.Create.AbsoluteSize.Y<180,'keyboard leaves submit reachable')
 input.OnScreenKeyboardVisible=false;modal.Cancel.Activated:Fire()
 snapshot()
end
print('PASS '..count..' responsive global race browser and creation UI checks')
]=]
luau.load(setup..scenario)()
