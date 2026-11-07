local fs,luau=require('@lune/fs'),require('@lune/luau')
local fixture=fs.readFile('tests/garage_transition_validation.luau')
local prefix=fixture:sub(1,assert(fixture:find('controller.start()',1,true))-1)
prefix=prefix:gsub('local controller = luau.load',"modules.TrackCatalog.Entries.SuperZ={Id='SuperZ',DisplayName='Super Z-Track',PreviewImageAssetId='rbxassetid://104331982200577',MatchType='PUBLIC_RACE',GeometryId='SuperZV1',TargetLaps=3,MinPlayers=1,MaxPlayers=4}\nlocal controller = luau.load",1)
local scenario=[=[
services.Workspace:SetAttribute('KDMServerRole','HUB');services.Workspace:SetAttribute('HubParkV1Enabled',true)
child(client,'ModuleScript','LobbyTestDriveController')
local requested
modules.TrackCatalog.Entries.SuperZ={Id='SuperZ',DisplayName='Super Z-Track',PreviewImageAssetId='rbxassetid://104331982200577',MatchType='PUBLIC_RACE',GeometryId='SuperZV1',TargetLaps=3,MinPlayers=1,MaxPlayers=4}
modules.LobbyTestDriveController={requestDrive=function(mode)requested=mode;return true end}
controller.start();controller.open('TRACKS')
local gui=playerGui.RobloxKartGarage;local body=gui:FindFirstChild('Frame')
local function findText(value)for _,v in body:GetDescendants()do if v.Text==value then return v end end end
assert(findText('START OVERTAKE'),'existing Overtake remains first')
body.NextChoice.Activated:Fire()
assert(findText('Super Z-Track'),'owner Super Z second preview')
body.NextChoice.Activated:Fire()
local join=findText('JOIN 8-RACER PARK');assert(join,'Park multiplayer retained after Super Z')
assert(findText('Rookie Park Multiplayer'),'new distinct preview identity')
local before=remote.fireCount;join.Activated:Fire()
assert(requested=='MULTIPLAYER'and remote.fireCount==before and not gui.Enabled,'dedicated Park mode request, no official Ready protocol')
print('PASS: actual Garage Overtake -> Super Z -> Park multiplayer launch')
]=]
luau.load(prefix..scenario,{debugName='park_multiplayer_garage'})()
